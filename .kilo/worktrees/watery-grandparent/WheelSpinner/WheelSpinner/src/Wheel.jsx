import React, { useRef, useEffect, useState, forwardRef, useImperativeHandle } from 'react';

const Wheel = forwardRef(({ items, onFinished, onSpinStart }, ref) => {
  const canvasRef = useRef(null);
  const [isSpinning, setIsSpinning] = useState(false);
  const rotation = useRef(0);
  const audioCtxRef = useRef(null); 
  
  const colors = ['#0474C4', '#5379AE', '#2C444C', '#A8C4EC', '#06457F', '#262B40'];

  const initAudio = () => {
    // 1. Create the audio context if it doesn't exist
    if (!audioCtxRef.current) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      audioCtxRef.current = new AudioContext();

      // --- THE MOBILE UNLOCK HACK ---
      // We must immediately play a sound of 0 volume during the user's tap
      // to prove to iOS/Android that the user gave us permission to use the speakers.
      const unlockOsc = audioCtxRef.current.createOscillator();
      const unlockGain = audioCtxRef.current.createGain();
      
      unlockGain.gain.value = 0; // Make it completely silent
      unlockOsc.connect(unlockGain);
      unlockGain.connect(audioCtxRef.current.destination);
      
      unlockOsc.start(audioCtxRef.current.currentTime);
      unlockOsc.stop(audioCtxRef.current.currentTime + 0.001); // Stop it instantly
    }

    // 2. Wake it up if the browser suspended it
    if (audioCtxRef.current.state === 'suspended') {
      audioCtxRef.current.resume();
    }
  };

  const playTick = () => {
    if (!audioCtxRef.current) return;
    const ctx = audioCtxRef.current;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(800, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(50, ctx.currentTime + 0.03);
    
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.03);
    
    osc.start();
    osc.stop(ctx.currentTime + 0.03);
  };

  const playWinSound = () => {
    if (!audioCtxRef.current) return;
    const ctx = audioCtxRef.current;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    
    osc.type = 'sine';
    osc.frequency.setValueAtTime(523.25, ctx.currentTime); 
    osc.frequency.setValueAtTime(659.25, ctx.currentTime + 0.1); 
    osc.frequency.setValueAtTime(783.99, ctx.currentTime + 0.2); 
    osc.frequency.setValueAtTime(1046.50, ctx.currentTime + 0.3); 
    
    gain.gain.setValueAtTime(0, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0.2, ctx.currentTime + 0.1);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 1.5);
    
    osc.start();
    osc.stop(ctx.currentTime + 1.5);
  };

  useImperativeHandle(ref, () => ({
    spin: () => {
      initAudio();
      if (!isSpinning && items.length >= 2) startSpin();
    }
  }));

  const draw = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const radius = centerX - 10; 
    
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (items.length === 0) return;

    const arcSize = (2 * Math.PI) / items.length;

    items.forEach((item, i) => {
      const angle = rotation.current + i * arcSize;
      
      ctx.fillStyle = colors[i % colors.length];
      ctx.beginPath();
      ctx.moveTo(centerX, centerY);
      ctx.arc(centerX, centerY, radius, angle, angle + arcSize);
      ctx.fill();
      
      ctx.strokeStyle = '#262B40'; 
      ctx.lineWidth = 6;
      ctx.stroke();
      
      ctx.save();
      ctx.translate(centerX, centerY);
      
      const sliceCenterAngle = angle + arcSize / 2;
      ctx.rotate(sliceCenterAngle);
      
      const normalizedAngle = sliceCenterAngle % (2 * Math.PI);
      const isLeftHalf = normalizedAngle > Math.PI / 2 && normalizedAngle < (3 * Math.PI) / 2;

      ctx.fillStyle = "#ffffff";
      ctx.font = "bold 32px Inter, system-ui, sans-serif"; 
      
      const displayText = item.length > 20 ? item.slice(0, 18) + '...' : item;

      if (isLeftHalf) {
        ctx.rotate(Math.PI);
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";
        ctx.fillText(displayText, -radius + 40, 0); 
      } else {
        ctx.textAlign = "right";
        ctx.textBaseline = "middle";
        ctx.fillText(displayText, radius - 40, 0);
      }
      ctx.restore();
    });

    ctx.fillStyle = '#262B40';
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius * 0.12, 0, 2 * Math.PI);
    ctx.fill();
    
    ctx.fillStyle = '#A8C4EC';
    ctx.beginPath();
    ctx.arc(centerX, centerY, radius * 0.04, 0, 2 * Math.PI);
    ctx.fill();
  };

  const startSpin = () => {
    setIsSpinning(true);
    if(onSpinStart) onSpinStart();
    
    const spinPower = 30 + Math.random() * 40;
    let currentPower = spinPower;
    const arcSize = (2 * Math.PI) / items.length;
    
    let lastSlice = Math.floor(rotation.current / arcSize);
    
    const animate = () => {
      rotation.current += currentPower * 0.05;
      currentPower *= 0.985; 
      
      const currentSlice = Math.floor(rotation.current / arcSize);
      if (currentSlice > lastSlice) {
        playTick();
        lastSlice = currentSlice;
      }

      draw();
      
      if (currentPower > 0.01) {
        requestAnimationFrame(animate);
      } else {
        setIsSpinning(false);
        playWinSound();
        
        const normalizedRotation = rotation.current % (2 * Math.PI);
        const pointerAngle = (1.5 * Math.PI - normalizedRotation + 2 * Math.PI) % (2 * Math.PI);
        const winningIndex = Math.floor(pointerAngle / arcSize);
        if(onFinished) onFinished(items[winningIndex]);
      }
    };
    animate();
  };

  useEffect(() => draw(), [items]);

  return (
    <div className="relative w-[85vw] max-w-[450px] lg:max-w-[700px] aspect-square flex flex-shrink-0 items-center justify-center mx-auto mt-4 lg:mt-0">
      <svg 
        className="absolute -top-3 md:-top-5 lg:-top-6 left-1/2 -translate-x-1/2 z-20 w-8 h-12 md:w-10 md:h-14 lg:w-12 lg:h-16 drop-shadow-[0_10px_8px_rgba(0,0,0,0.6)]" 
        viewBox="0 0 384 512" 
        fill="#A8C4EC"
      >
        <path 
          d="M384 192c0 87.4-117 243-168.3 307.2c-12.3 15.3-35.1 15.3-47.4 0C117 435 0 279.4 0 192C0 86 86 0 192 0S384 86 384 192z" 
          stroke="#262B40" 
          strokeWidth="16"
        />
        <circle cx="192" cy="192" r="64" fill="#262B40" />
      </svg>
      <canvas 
        ref={canvasRef} 
        width={1000} 
        height={1000} 
        className="w-full h-full object-contain rounded-full shadow-[0_0_60px_rgba(4,116,196,0.2)] border-[8px] lg:border-[12px] border-[#2C444C]" 
      />
    </div>
  );
});

export default Wheel;