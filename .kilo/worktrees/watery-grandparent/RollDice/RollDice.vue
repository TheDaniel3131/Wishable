<template>
  <div class="dice-container" ref="containerRef">
    <div class="ui-layer">
      <button @click="rollDice" class="neon-btn">
        <span class="btn-icon">🎲</span>
        Roll The Dice
      </button>
      <div class="result-display" v-if="lastResult">
        <span class="result-label">Result:</span>
        <span class="result-value">{{ lastResult }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import * as THREE from 'three';
import * as CANNON from 'cannon-es';

const containerRef = ref(null);
const lastResult = ref(null);

// Core instances
let scene, camera, renderer, world;
let diceMesh, diceBody;
let animationFrameId;
let isRolling = false;

// Audio setup - using Web Audio API to generate dice roll sound
const audioContext = new (window.AudioContext || window.webkitAudioContext)();

const playDiceRollSound = () => {
  const now = audioContext.currentTime;
  
  // Create multiple quick impacts for rolling sound
  for (let i = 0; i < 8; i++) {
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    // Randomize frequency for realistic tumbling sound
    oscillator.frequency.value = 80 + Math.random() * 120;
    oscillator.type = 'triangle';
    
    const startTime = now + i * 0.08;
    gainNode.gain.setValueAtTime(0.15, startTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, startTime + 0.1);
    
    oscillator.start(startTime);
    oscillator.stop(startTime + 0.1);
  }
};

const playBounceSound = (intensity) => {
  const oscillator = audioContext.createOscillator();
  const gainNode = audioContext.createGain();
  
  oscillator.connect(gainNode);
  gainNode.connect(audioContext.destination);
  
  oscillator.frequency.value = 120 + intensity * 80;
  oscillator.type = 'sine';
  
  const now = audioContext.currentTime;
  gainNode.gain.setValueAtTime(Math.min(intensity * 0.3, 0.2), now);
  gainNode.gain.exponentialRampToValueAtTime(0.01, now + 0.15);
  
  oscillator.start(now);
  oscillator.stop(now + 0.15);
};

// Dynamic Texture Generator for Dice Faces
const createDiceFace = (text, bgColor, textColor) => {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');

  // Background with gradient
  const gradient = ctx.createLinearGradient(0, 0, 512, 512);
  gradient.addColorStop(0, bgColor);
  gradient.addColorStop(1, lightenColor(bgColor, 10));
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 512, 512);

  // Outer border
  ctx.strokeStyle = textColor;
  ctx.lineWidth = 20;
  ctx.strokeRect(10, 10, 492, 492);

  // Inner border
  ctx.strokeStyle = lightenColor(textColor, -20);
  ctx.lineWidth = 8;
  ctx.strokeRect(40, 40, 432, 432);

  // Text with shadow
  ctx.shadowColor = 'rgba(0, 0, 0, 0.3)';
  ctx.shadowBlur = 10;
  ctx.shadowOffsetX = 5;
  ctx.shadowOffsetY = 5;
  
  ctx.font = 'bold 280px Arial, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = textColor;
  ctx.fillText(text, 256, 256);

  const texture = new THREE.CanvasTexture(canvas);
  texture.anisotropy = 16;
  return texture;
};

// Helper to lighten/darken colors
const lightenColor = (hex, percent) => {
  const num = parseInt(hex.replace('#', ''), 16);
  const amt = Math.round(2.55 * percent);
  const R = Math.min(255, Math.max(0, (num >> 16) + amt));
  const G = Math.min(255, Math.max(0, (num >> 8 & 0x00FF) + amt));
  const B = Math.min(255, Math.max(0, (num & 0x0000FF) + amt));
  return '#' + (0x1000000 + (R << 16) + (G << 8) + B).toString(16).slice(1);
};

const initEngine = () => {
  // 1. Three.js Setup
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0xf0f4f8); // Light blue-gray background
  scene.fog = new THREE.FogExp2(0xe0e8f0, 0.02);

  camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);
  camera.position.set(0, 8, 12);
  camera.lookAt(0, 0, 0);

  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  
  if (containerRef.value) {
    containerRef.value.appendChild(renderer.domElement);
  }

  // Lighting - bright and clear
  const ambient = new THREE.AmbientLight(0xffffff, 0.8);
  scene.add(ambient);

  const mainLight = new THREE.DirectionalLight(0xffffff, 1.2);
  mainLight.position.set(10, 15, 10);
  mainLight.castShadow = true;
  mainLight.shadow.camera.near = 0.1;
  mainLight.shadow.camera.far = 50;
  mainLight.shadow.camera.left = -15;
  mainLight.shadow.camera.right = 15;
  mainLight.shadow.camera.top = 15;
  mainLight.shadow.camera.bottom = -15;
  mainLight.shadow.mapSize.width = 2048;
  mainLight.shadow.mapSize.height = 2048;
  mainLight.shadow.bias = -0.0001;
  scene.add(mainLight);

  const fillLight = new THREE.PointLight(0xffd700, 0.6);
  fillLight.position.set(-8, 8, -8);
  scene.add(fillLight);

  const backLight = new THREE.PointLight(0x87ceeb, 0.5);
  backLight.position.set(0, 5, -10);
  scene.add(backLight);

  // 2. Cannon.js Setup
  world = new CANNON.World({
    gravity: new CANNON.Vec3(0, -30, 0),
  });
  world.broadphase = new CANNON.SAPBroadphase(world);

  // 3. Environment (Floor)
  const floorMat = new CANNON.Material();
  const floorBody = new CANNON.Body({
    mass: 0,
    shape: new CANNON.Plane(),
    material: floorMat,
  });
  floorBody.quaternion.setFromEuler(-Math.PI / 2, 0, 0);
  world.addBody(floorBody);

  // Visual floor with bright gradient
  const floorMesh = new THREE.Mesh(
    new THREE.PlaneGeometry(50, 50),
    new THREE.MeshStandardMaterial({ 
      color: 0xd4e4f7,
      roughness: 0.4, 
      metalness: 0.2
    })
  );
  floorMesh.rotation.x = -Math.PI / 2;
  floorMesh.receiveShadow = true;
  scene.add(floorMesh);

  // Add a subtle grid
  const gridHelper = new THREE.GridHelper(30, 30, 0xa8c5e0, 0xcce0f2);
  gridHelper.position.y = 0.01;
  scene.add(gridHelper);

  // 4. Dice Construction
  const diceSize = 2;
  const diceHalfExtents = new CANNON.Vec3(diceSize / 2, diceSize / 2, diceSize / 2);
  
  const dicePhysMat = new CANNON.Material();
  diceBody = new CANNON.Body({
    mass: 1.5,
    shape: new CANNON.Box(diceHalfExtents),
    material: dicePhysMat,
  });
  
  // Add collision listener for bounce sounds
  diceBody.addEventListener('collide', (event) => {
    const impactVelocity = event.contact.getImpactVelocityAlongNormal();
    if (Math.abs(impactVelocity) > 0.5) {
      playBounceSound(Math.min(Math.abs(impactVelocity) / 10, 1));
    }
  });
  
  world.addBody(diceBody);

  // Physics Contact Rules
  const contactMaterial = new CANNON.ContactMaterial(floorMat, dicePhysMat, {
    friction: 0.2,
    restitution: 0.5,
  });
  world.addContactMaterial(contactMaterial);

  // Bright, vibrant dice colors
  const materials = [
    new THREE.MeshStandardMaterial({ map: createDiceFace('1', '#ff6b9d', '#ffffff'), roughness: 0.2, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace('6', '#4ecdc4', '#ffffff'), roughness: 0.2, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace('2', '#ffd93d', '#2d3748'), roughness: 0.2, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace('5', '#95e1d3', '#2d3748'), roughness: 0.2, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace('3', '#c77dff', '#ffffff'), roughness: 0.2, metalness: 0.1 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace('4', '#06ffa5', '#2d3748'), roughness: 0.2, metalness: 0.1 }),
  ];

  const geometry = new THREE.BoxGeometry(diceSize, diceSize, diceSize);
  diceMesh = new THREE.Mesh(geometry, materials);
  diceMesh.castShadow = true;
  diceMesh.receiveShadow = true;
  scene.add(diceMesh);
};

// Function to determine which face is up
const getDiceResult = () => {
  if (!diceBody) return null;
  
  const quaternion = diceBody.quaternion;
  const upVector = new CANNON.Vec3(0, 1, 0);
  
  // Transform the up vector by the dice rotation
  const rotatedUp = quaternion.vmult(upVector);
  
  // Face normals in local space
  const faces = [
    { normal: new CANNON.Vec3(1, 0, 0), value: 1 },   // right
    { normal: new CANNON.Vec3(-1, 0, 0), value: 6 },  // left
    { normal: new CANNON.Vec3(0, 1, 0), value: 2 },   // top
    { normal: new CANNON.Vec3(0, -1, 0), value: 5 },  // bottom
    { normal: new CANNON.Vec3(0, 0, 1), value: 3 },   // front
    { normal: new CANNON.Vec3(0, 0, -1), value: 4 },  // back
  ];
  
  let maxDot = -Infinity;
  let result = 1;
  
  faces.forEach(face => {
    const worldNormal = quaternion.vmult(face.normal);
    const dot = worldNormal.dot(upVector);
    if (dot > maxDot) {
      maxDot = dot;
      result = face.value;
    }
  });
  
  return result;
};

const rollDice = () => {
  if (!diceBody || isRolling) return;
  
  isRolling = true;
  lastResult.value = null;
  
  // Play rolling sound
  playDiceRollSound();

  diceBody.position.set(0, 10, 0);
  
  diceBody.velocity.set(
    (Math.random() - 0.5) * 15,
    8,
    (Math.random() - 0.5) * 15
  );
  
  diceBody.angularVelocity.set(
    (Math.random() - 0.5) * 20,
    (Math.random() - 0.5) * 20,
    (Math.random() - 0.5) * 20
  );
  
  // Check when dice has settled
  setTimeout(() => {
    const checkSettled = setInterval(() => {
      if (diceBody.velocity.length() < 0.1 && diceBody.angularVelocity.length() < 0.1) {
        clearInterval(checkSettled);
        lastResult.value = getDiceResult();
        isRolling = false;
      }
    }, 100);
  }, 1000);
};

const animate = () => {
  animationFrameId = requestAnimationFrame(animate);
  
  // Step physics forward
  world.step(1 / 60);
  
  // Sync Mesh to Body
  if (diceMesh && diceBody) {
    diceMesh.position.copy(diceBody.position);
    diceMesh.quaternion.copy(diceBody.quaternion);
  }
  
  renderer.render(scene, camera);
};

const handleResize = () => {
  if (camera && renderer) {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
  }
};

onMounted(() => {
  initEngine();
  animate();
  rollDice();
  window.addEventListener('resize', handleResize);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
  cancelAnimationFrame(animationFrameId);
  if (renderer && renderer.domElement) {
    renderer.domElement.remove();
    renderer.dispose();
  }
  if (audioContext) {
    audioContext.close();
  }
});
</script>

<style scoped>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

.dice-container {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  position: fixed;
  top: 0;
  left: 0;
  background: linear-gradient(135deg, #e3f2fd 0%, #fff3e0 100%);
}

.ui-layer {
  position: fixed;
  bottom: 40px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
}

.neon-btn {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: #ffffff;
  border: none;
  padding: 18px 45px;
  font-size: 1.3rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 2px;
  cursor: pointer;
  border-radius: 50px;
  box-shadow: 
    0 4px 15px rgba(102, 126, 234, 0.4),
    0 8px 25px rgba(118, 75, 162, 0.3);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  align-items: center;
  gap: 12px;
  position: relative;
  overflow: hidden;
}

.neon-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
  transition: left 0.5s;
}

.neon-btn:hover::before {
  left: 100%;
}

.btn-icon {
  font-size: 1.5rem;
  animation: rotate 2s linear infinite;
}

@keyframes rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.neon-btn:hover {
  transform: translateY(-3px);
  box-shadow: 
    0 6px 20px rgba(102, 126, 234, 0.5),
    0 12px 35px rgba(118, 75, 162, 0.4);
}

.neon-btn:active {
  transform: translateY(-1px);
  box-shadow: 
    0 3px 10px rgba(102, 126, 234, 0.4),
    0 5px 15px rgba(118, 75, 162, 0.3);
}

.result-display {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 20px 40px;
  border-radius: 20px;
  box-shadow: 
    0 4px 20px rgba(0, 0, 0, 0.1),
    0 0 0 1px rgba(102, 126, 234, 0.2);
  display: flex;
  align-items: center;
  gap: 15px;
  animation: slideUp 0.4s cubic-bezier(0.4, 0, 0.2, 1);
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.result-label {
  font-size: 1.1rem;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.result-value {
  font-size: 2.5rem;
  font-weight: 800;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  animation: pulse 0.6s cubic-bezier(0.4, 0, 0.2, 1);
}

@keyframes pulse {
  0%, 100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.2);
  }
}

/* Prevent scrollbars */
html, body {
  overflow: hidden;
  width: 100%;
  height: 100%;
  margin: 0;
  padding: 0;
}
</style>