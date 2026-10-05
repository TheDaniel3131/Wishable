<template>
  <div class="dice-container" ref="containerRef">
    <div class="ui-layer">
      <button @click="rollDice" class="rtd-btn" :disabled="isRolling">
        <span class="btn-icon">🎲</span>
        <span class="btn-content">
          <span class="btn-text">Roll The Dice</span>
          <span class="btn-hint">Press <kbd>Space</kbd> to roll</span>
        </span>
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

// Detect mobile device
const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || window.innerWidth < 768;

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

// Dynamic Texture Generator for Dice Faces with Dots
const createDiceFace = (number) => {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');

  // White background
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, 512, 512);

  // Subtle border
  ctx.strokeStyle = '#e0e0e0';
  ctx.lineWidth = 4;
  ctx.strokeRect(2, 2, 508, 508);

  // Dot color - red for 1 and 4, black for others
  ctx.fillStyle = (number === 1 || number === 4) ? '#d32f2f' : '#1a1a1a';
  
  const dotRadius = 35;
  const positions = {
    center: { x: 256, y: 256 },
    topLeft: { x: 150, y: 150 },
    topRight: { x: 362, y: 150 },
    middleLeft: { x: 150, y: 256 },
    middleRight: { x: 362, y: 256 },
    bottomLeft: { x: 150, y: 362 },
    bottomRight: { x: 362, y: 362 },
  };

  const drawDot = (pos) => {
    ctx.beginPath();
    ctx.arc(pos.x, pos.y, dotRadius, 0, Math.PI * 2);
    ctx.fill();
  };

  // Draw dots based on number
  switch (number) {
    case 1:
      drawDot(positions.center);
      break;
    case 2:
      drawDot(positions.topLeft);
      drawDot(positions.bottomRight);
      break;
    case 3:
      drawDot(positions.topLeft);
      drawDot(positions.center);
      drawDot(positions.bottomRight);
      break;
    case 4:
      drawDot(positions.topLeft);
      drawDot(positions.topRight);
      drawDot(positions.bottomLeft);
      drawDot(positions.bottomRight);
      break;
    case 5:
      drawDot(positions.topLeft);
      drawDot(positions.topRight);
      drawDot(positions.center);
      drawDot(positions.bottomLeft);
      drawDot(positions.bottomRight);
      break;
    case 6:
      drawDot(positions.topLeft);
      drawDot(positions.topRight);
      drawDot(positions.middleLeft);
      drawDot(positions.middleRight);
      drawDot(positions.bottomLeft);
      drawDot(positions.bottomRight);
      break;
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.anisotropy = 16;
  return texture;
};

// Create rounded box geometry
const createRoundedBox = (width, height, depth, radius, smoothness) => {
  const shape = new THREE.Shape();
  const eps = 0.00001;
  const radius0 = radius - eps;
  
  shape.absarc(eps, eps, eps, -Math.PI / 2, -Math.PI, true);
  shape.absarc(eps, height - radius * 2, eps, Math.PI, Math.PI / 2, true);
  shape.absarc(width - radius * 2, height - radius * 2, eps, Math.PI / 2, 0, true);
  shape.absarc(width - radius * 2, eps, eps, 0, -Math.PI / 2, true);
  
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth: depth - radius * 2,
    bevelEnabled: true,
    bevelSegments: smoothness,
    steps: 1,
    bevelSize: radius0,
    bevelThickness: radius,
    curveSegments: smoothness
  });
  
  geometry.center();
  return geometry;
};

const initEngine = () => {
  // 1. Three.js Setup
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0xb0c4d8); // Match the floor color (grayish-blue)
  scene.fog = new THREE.FogExp2(0xb0c4d8, 0.015);

  // Adjust camera for mobile vs desktop
  camera = new THREE.PerspectiveCamera(
    isMobile ? 50 : 45, // Wider FOV for mobile
    window.innerWidth / window.innerHeight, 
    0.1, 
    100
  );
  
  // Pull camera back more on mobile for better view
  if (isMobile) {
    camera.position.set(0, 14, 22);
  } else {
    camera.position.set(0, 12, 18);
  }
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

  // Create invisible walls to keep dice in bounds
  // Smaller arena for mobile
  const wallMaterial = new CANNON.Material();
  const wallHeight = 10;
  const wallThickness = 0.5;
  const arenaSize = isMobile ? 8 : 12; // Smaller arena for mobile

  // Front wall
  const frontWall = new CANNON.Body({
    mass: 0,
    shape: new CANNON.Box(new CANNON.Vec3(arenaSize, wallHeight, wallThickness)),
    material: wallMaterial,
  });
  frontWall.position.set(0, wallHeight, -arenaSize);
  world.addBody(frontWall);

  // Back wall
  const backWall = new CANNON.Body({
    mass: 0,
    shape: new CANNON.Box(new CANNON.Vec3(arenaSize, wallHeight, wallThickness)),
    material: wallMaterial,
  });
  backWall.position.set(0, wallHeight, arenaSize);
  world.addBody(backWall);

  // Left wall
  const leftWall = new CANNON.Body({
    mass: 0,
    shape: new CANNON.Box(new CANNON.Vec3(wallThickness, wallHeight, arenaSize)),
    material: wallMaterial,
  });
  leftWall.position.set(-arenaSize, wallHeight, 0);
  world.addBody(leftWall);

  // Right wall
  const rightWall = new CANNON.Body({
    mass: 0,
    shape: new CANNON.Box(new CANNON.Vec3(wallThickness, wallHeight, arenaSize)),
    material: wallMaterial,
  });
  rightWall.position.set(arenaSize, wallHeight, 0);
  world.addBody(rightWall);

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

  // Wall contact material
  const wallContactMaterial = new CANNON.ContactMaterial(wallMaterial, dicePhysMat, {
    friction: 0.1,
    restitution: 0.7,
  });
  world.addContactMaterial(wallContactMaterial);

  // Classic white dice with black dots
  const materials = [
    new THREE.MeshStandardMaterial({ map: createDiceFace(1), roughness: 0.3, metalness: 0.05 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace(6), roughness: 0.3, metalness: 0.05 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace(2), roughness: 0.3, metalness: 0.05 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace(5), roughness: 0.3, metalness: 0.05 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace(3), roughness: 0.3, metalness: 0.05 }),
    new THREE.MeshStandardMaterial({ map: createDiceFace(4), roughness: 0.3, metalness: 0.05 }),
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
  
  // Reduce velocity on mobile for smaller arena
  const velocityMultiplier = isMobile ? 10 : 15;
  
  diceBody.velocity.set(
    (Math.random() - 0.5) * velocityMultiplier,
    8,
    (Math.random() - 0.5) * velocityMultiplier
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

const handleKeyPress = (event) => {
  if (event.code === 'Space' && !isMobile) {
    event.preventDefault();
    rollDice();
  }
};

onMounted(() => {
  initEngine();
  animate();
  rollDice();
  window.addEventListener('resize', handleResize);
  if (!isMobile) {
    window.addEventListener('keydown', handleKeyPress);
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
  if (!isMobile) {
    window.removeEventListener('keydown', handleKeyPress);
  }
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
  background: linear-gradient(135deg, #b0c4d8 0%, #c0d0e0 100%);
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

.rtd-btn {
  background: linear-gradient(135deg, #6baeff 0%, #5aa4ee 50%, #456dc4 100%);
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
    0 4px 15px rgba(107, 169, 255, 0.4),
    0 8px 25px rgba(69, 94, 196, 0.3);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  align-items: center;
  gap: 15px;
  position: relative;
  overflow: hidden;
}

.rtd-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.3), transparent);
  transition: left 0.5s;
}

.rtd-btn:hover::before {
  left: 100%;
}

.btn-icon {
  font-size: 1.8rem;
  animation: rotate 2s linear infinite;
  flex-shrink: 0;
}

.btn-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
}

.btn-text {
  font-size: 1.3rem;
  font-weight: 750;
  line-height: 1.1;
}

.btn-hint {
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: none;
  letter-spacing: 0.5px;
  opacity: 0.9;
  display: flex;
  align-items: center;
  gap: 5px;
}

.btn-hint kbd {
  background: rgba(255, 255, 255, 0.25);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 4px;
  padding: 2px 8px;
  font-family: monospace;
  font-weight: 600;
  font-size: 0.7rem;
  color: #ffffff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

@keyframes rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.rtd-btn:hover {
  transform: translateY(-3px);
  box-shadow: 
    0 6px 20px rgba(107, 213, 255, 0.5),
    0 12px 35px rgba(69, 160, 196, 0.4);
}

.rtd-btn:active {
  transform: translateY(-1px);
  box-shadow: 
    0 3px 10px rgba(107, 228, 255, 0.4),
    0 5px 15px rgba(69, 171, 196, 0.3);
}

.rtd-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.rtd-btn:disabled:hover {
  transform: none;
  box-shadow: 
    0 4px 15px rgba(107, 166, 255, 0.4),
    0 8px 25px rgba(69, 166, 196, 0.3);
}

.result-display {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 20px 40px;
  border-radius: 20px;
  box-shadow: 
    0 4px 20px rgba(0, 0, 0, 0.1),
    0 0 0 1px rgba(107, 161, 255, 0.2);
  display: flex;
  align-items: center;
  justify-content: center;
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
  font-size: 1.5rem;
  font-weight: 600;
  color: #64748b;
  align-items: center;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.result-value {
  font-size: 3rem;
  font-weight: 800;
  background: linear-gradient(135deg, #ff6b6b 0%, #c44569 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  align-items: center;
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

/* Mobile Responsive Styles */
@media (max-width: 768px) {
  .ui-layer {
    bottom: 30px;
  }

  .rtd-btn {
    padding: 14px 30px;
    font-size: 1.1rem;
    gap: 12px;
  }

  .btn-icon {
    font-size: 1.5rem;
  }

  .btn-text {
    font-size: 1.1rem;
  }

  /* Hide the keyboard hint on mobile */
  .btn-hint {
    display: none;
  }

  .result-display {
    padding: 15px 30px;
  }

  .result-label {
    font-size: 1.2rem;
  }

  .result-value {
    font-size: 2.5rem;
  }
}

@media (max-width: 480px) {
  .rtd-btn {
    padding: 12px 24px;
    font-size: 1rem;
  }

  .btn-icon {
    font-size: 1.3rem;
  }

  .btn-text {
    font-size: 1rem;
  }

  .result-display {
    padding: 12px 24px;
  }

  .result-label {
    font-size: 1rem;
  }

  .result-value {
    font-size: 2rem;
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