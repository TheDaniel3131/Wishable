<template>
  <div 
    class="fixed inset-0 w-full h-[100dvh] bg-[#0E0E0E] text-[#F5F5F5] font-sans overflow-hidden transition-all duration-75 selection:bg-[#D6C4B0] selection:text-[#0E0E0E]"
    :class="{ 'animate-heavy-shake': isShaking }"
  >
    <div v-if="isFlashing" class="fixed inset-0 bg-[#F5F5F5] opacity-20 z-[100] pointer-events-none mix-blend-overlay"></div>
    
    <div v-if="phase === 'input'" class="w-full h-full flex flex-col p-4 md:p-12 max-w-6xl mx-auto">
      <div class="text-center mb-4 md:mb-6 pb-4 border-b border-[#363432]">
        <h1 class="text-4xl md:text-7xl font-black italic tracking-tighter text-[#F5F5F5] drop-shadow-[0_0_15px_rgba(214,196,176,0.3)]">
          ELIMINATED_
        </h1>
        <p class="text-[#7E8083] font-mono text-[10px] md:text-xs tracking-widest uppercase mt-2 md:mt-3">Made By Zephrous</p>
      </div>

      <div class="flex flex-col md:flex-row gap-3 md:gap-4 mb-4 z-20">
        <div class="flex-1 flex gap-2 md:gap-3 relative">
          <input 
            v-model="newItem" 
            @keydown.enter="addItem"
            type="text" 
            class="flex-1 bg-[#363432] border-2 border-[#7E8083] rounded-xl px-4 md:px-6 py-3 md:py-4 text-lg md:text-xl font-bold text-[#F5F5F5] focus:outline-none focus:border-[#D6C4B0] transition-colors placeholder:text-[#7E8083]"
            placeholder="Add New Item"
          />
          <button 
            @click="addItem"
            class="px-6 md:px-8 bg-[#D6C4B0] text-[#0E0E0E] font-black uppercase tracking-widest rounded-xl hover:bg-[#F5F5F5] transition-colors shadow-[0_0_15px_rgba(214,196,176,0.2)]"
          >
            Add
          </button>
        </div>

        <div class="flex gap-2 md:gap-4 relative">
          <div class="relative flex-1 md:flex-none md:w-64 z-50">
            <div 
              @click="isDropdownOpen = !isDropdownOpen" 
              class="flex justify-between items-center h-full bg-[#363432] border-2 border-[#7E8083] rounded-xl px-4 py-3 cursor-pointer hover:border-[#D6C4B0] transition-colors"
            >
              <span class="text-[#D6C4B0] font-bold uppercase tracking-wider text-xs md:text-sm">{{ activeFormatLabel }}</span>
              <svg class="w-5 h-5 text-[#7E8083] transition-transform duration-200" :class="{'rotate-180 text-[#D6C4B0]': isDropdownOpen}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M19 9l-7 7-7-7"></path></svg>
            </div>
            
            <div v-if="isDropdownOpen" @click="isDropdownOpen = false" class="fixed inset-0 z-40 cursor-default"></div>
            <div v-if="isDropdownOpen" class="absolute top-full left-0 w-full mt-2 bg-[#0E0E0E] border-2 border-[#D6C4B0] rounded-xl overflow-hidden z-50 shadow-[0_0_30px_rgba(214,196,176,0.15)] animate-slide-down origin-top">
              <div 
                v-for="opt in formatOptions" 
                :key="opt.value" 
                @click="bestOf = opt.value; isDropdownOpen = false" 
                class="px-4 py-4 text-[#F5F5F5] font-bold text-xs md:text-sm uppercase tracking-wider cursor-pointer hover:bg-[#363432] hover:text-[#D6C4B0] transition-colors border-b border-[#363432] last:border-none"
              >
                {{ opt.label }}
              </div>
            </div>
          </div>

          <button 
            @click="clearAll"
            class="px-4 md:px-6 border-2 border-[#7E8083] text-[#7E8083] font-black text-xs md:text-sm uppercase tracking-widest rounded-xl hover:border-red-500 hover:bg-red-500/10 hover:text-red-500 transition-colors"
          >
            Clear
          </button>
        </div>
      </div>

      <div class="flex-1 flex flex-col bg-[#363432]/50 border-2 border-[#7E8083]/50 rounded-2xl p-3 md:p-4 overflow-hidden relative">
        <div v-if="items.length === 0" class="absolute inset-0 flex items-center justify-center text-[#7E8083] font-mono text-xs md:text-sm uppercase tracking-widest text-center px-4">
          No entries found. Input parameters above.
        </div>
        
        <div class="overflow-y-auto flex-1 pr-2 space-y-2 md:space-y-3 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          <div 
            v-for="(item, index) in items" 
            :key="index"
            class="group flex justify-between items-center bg-[#363432] border-2 border-[#7E8083] rounded-xl p-3 md:p-4 transition-all hover:border-[#D6C4B0]"
          >
            <span class="text-lg md:text-2xl font-bold text-[#F5F5F5] break-all mr-4">{{ item }}</span>
            <button 
              @click="removeItem(index)" 
              class="w-10 h-10 shrink-0 flex items-center justify-center rounded-lg bg-[#0E0E0E] text-[#7E8083] border-2 border-[#7E8083] hover:border-red-500 hover:bg-red-500/10 hover:text-red-500 transition-colors font-black text-lg"
            >
              X
            </button>
          </div>
        </div>
      </div>
      
      <div class="mt-4 md:mt-6 flex flex-col-reverse md:flex-row justify-between items-center gap-4">
        <div class="text-xs md:text-sm text-[#7E8083] font-normal text-center md:text-left">
          Entries: <span class="text-[#D6C4B0] font-bold">{{ items.length }}</span> (Min 2)  
        </div>
        <button 
          @click="initiateTournament"
          :disabled="items.length < 2 || simulationRunning"
          class="w-full md:w-auto px-10 md:px-16 py-5 md:py-6 rounded-full font-black text-xl md:text-2xl tracking-widest uppercase transition-all duration-200 disabled:opacity-30 disabled:cursor-not-allowed bg-[#D6C4B0] text-[#0E0E0E] hover:scale-[1.02] active:scale-[0.98] shadow-[0_0_30px_rgba(214,196,176,0.3)] hover:shadow-[0_0_50px_rgba(214,196,176,0.6)]"
        >
          Start Battle
        </button>
      </div>
    </div>

    <div v-else-if="phase === 'battle' && currentMatch" class="w-full h-full flex flex-col p-4 md:p-12 z-10 relative">
      
      <div class="flex justify-between items-center text-[#7E8083] uppercase tracking-widest border-b-2 border-[#363432] pb-3 md:pb-4 mb-4 z-10">
        
        <div class="flex-1 text-left font-black text-xs md:text-2xl text-[#D6C4B0]">
          Round {{ currentRound }}
        </div>
        
        <div class="flex-1 flex justify-center">
          <div v-if="bestOf > 1" class="text-[#F5F5F5] font-black text-lg md:text-3xl tracking-tighter bg-[#363432] px-4 md:px-6 py-1 md:py-2 rounded-xl border border-[#7E8083] flex flex-col items-center justify-center whitespace-nowrap shadow-xl">
            <span class="text-[#7E8083] text-[8px] md:text-sm block text-center mb-0 md:mb-1 leading-none">SCORE</span>
            <div class="flex items-center leading-none mt-1">
              <span :class="{'text-[#D6C4B0]': matchScores[0] > matchScores[1]}">{{ matchScores[0] }}</span> 
              <span class="text-[#7E8083] mx-2 md:mx-3">-</span> 
              <span :class="{'text-[#D6C4B0]': matchScores[1] > matchScores[0]}">{{ matchScores[1] }}</span>
            </div>
          </div>
        </div>

        <div class="flex-1 text-right font-black text-xs md:text-2xl text-[#D6C4B0]">
          Match {{ matchIndex + 1 }} <span class="text-[#7E8083] text-[10px] md:text-lg font-bold hidden sm:inline">of {{ totalMatchesInRound }}</span>
        </div>

      </div>

      <div class="w-full min-h-[80px] md:min-h-[100px] flex items-center justify-center mb-4 z-40 relative">
        <div v-if="rouletteActive" class="bg-[#363432] border-2 border-[#7E8083] text-[#D6C4B0] flex items-center gap-3 md:gap-4 text-lg md:text-2xl font-black uppercase tracking-widest px-6 md:px-8 py-3 md:py-4 rounded-2xl shadow-xl">
          <!-- <span class="w-3 h-3 md:w-4 md:h-4 bg-[#D6C4B0] rounded-full animate-ping"></span> -->
          BATTLE!
        </div>
        <div v-else-if="winnerDeclared !== null" class="bg-[#D6C4B0] border-4 border-[#F5F5F5] px-6 py-3 md:px-10 md:py-5 rounded-3xl flex flex-col items-center justify-center animate-aggressive-pop shadow-[0_0_50px_rgba(214,196,176,0.6)] w-full max-w-sm md:max-w-2xl text-center">
          <span class="text-[#0E0E0E] font-black text-xl md:text-4xl tracking-tighter uppercase truncate max-w-full drop-shadow-sm leading-tight">
            {{ currentMatch[winnerDeclared - 1] }}
          </span>
          <span class="text-[#363432] font-black text-xs md:text-lg tracking-widest uppercase mt-1 opacity-90 border-t border-[#363432]/20 pt-1 w-full">
            {{ isMatchOver ? 'Wins The Match!' : 'Wins This Round!' }}
          </span>
        </div>
      </div>

      <div class="flex flex-col md:flex-row flex-1 items-stretch justify-center gap-4 md:gap-12 relative w-full pb-4">
        
        <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-20 w-16 h-16 md:w-32 md:h-32 bg-[#0E0E0E] border-4 border-[#D6C4B0] rounded-full flex items-center justify-center shadow-[0_0_50px_rgba(214,196,176,0.6)]">
          <span class="text-[#D6C4B0] font-black italic text-2xl md:text-5xl drop-shadow-lg">VS</span>
        </div>

        <div 
          class="w-full md:w-1/2 flex-1 flex flex-col items-center justify-center rounded-3xl transition-all duration-100 relative overflow-hidden border-4"
          :class="getCardClasses(1)"
        >
          <span class="text-3xl md:text-6xl font-bold text-center p-6 md:p-8 break-words z-10 drop-shadow-2xl max-h-full overflow-hidden" :class="getTextColor(1)">
            {{ currentMatch[0] }}
          </span>
        </div>

        <div 
          class="w-full md:w-1/2 flex-1 flex flex-col items-center justify-center rounded-3xl transition-all duration-100 relative overflow-hidden border-4"
          :class="getCardClasses(2)"
        >
          <span class="text-3xl md:text-6xl font-bold text-center p-6 md:p-8 break-words z-10 drop-shadow-2xl max-h-full overflow-hidden" :class="getTextColor(2)">
            {{ currentMatch[1] }}
          </span>
        </div>

      </div>
    </div>

    <div v-else-if="phase === 'complete'" class="w-full h-full flex flex-col justify-center items-center text-center p-6 z-10 relative">
      <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-[#D6C4B0]/10 via-[#0E0E0E] to-[#0E0E0E] pointer-events-none"></div>
      
      <h3 class="text-2xl md:text-5xl text-[#D6C4B0] font-black italic uppercase tracking-widest mb-8 md:mb-12 drop-shadow-[0_0_15px_rgba(214,196,176,0.8)] z-10">
        The Winner
      </h3>
      
      <div class="p-8 md:p-24 border-4 md:border-8 border-[#D6C4B0] bg-[#363432] rounded-[2rem] md:rounded-[3rem] shadow-[0_0_100px_rgba(214,196,176,0.4)] animate-tilt w-full max-w-6xl z-10 relative overflow-hidden">
        <div class="absolute -inset-10 bg-[#D6C4B0] opacity-10 blur-3xl animate-pulse"></div>
        <span class="relative text-4xl md:text-9xl font-black text-[#F5F5F5] break-words drop-shadow-2xl leading-tight">
          {{ grandWinner }}
        </span>
      </div>
      
      <button 
        @click="reset"
        class="mt-16 md:mt-24 px-10 md:px-16 py-5 md:py-6 rounded-full border-4 border-[#D6C4B0] text-[#D6C4B0] transition-all font-black text-xl md:text-2xl tracking-widest uppercase hover:bg-[#D6C4B0] hover:text-[#0E0E0E] hover:scale-105 z-10 shadow-[0_0_40px_rgba(214,196,176,0.3)] hover:shadow-[0_0_60px_rgba(214,196,176,0.6)]"
      >
        Battle Again
      </button>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

const CACHE_KEY = 'ELIMINATED__task_list';
type Phase = 'input' | 'battle' | 'complete'

const items = ref<string[]>([])
const newItem = ref('')
const phase = ref<Phase>('input')
const simulationRunning = ref(false)

const bestOf = ref<number>(1)
const isDropdownOpen = ref(false)
const formatOptions = [
  { value: 1, label: 'BO1 (Sudden Death)' },
  { value: 3, label: 'BO3 (First to 2)' },
  { value: 5, label: 'BO5 (First to 3)' }
]
const activeFormatLabel = computed(() => {
  return formatOptions.find(opt => opt.value === bestOf.value)?.label || 'Format'
})

const currentRound = ref(1)
const upcomingMatches = ref<string[][]>([])
const nextRoundPlayers = ref<string[]>([])
const currentMatch = ref<string[] | null>(null)
const matchIndex = ref(0)
const totalMatchesInRound = ref(0)
const grandWinner = ref<string | null>(null)
const matchScores = ref<number[]>([0, 0])
const isMatchOver = ref(false)

const rouletteActive = ref(false)
const activeRouletteIndex = ref<1 | 2>(1) 
const winnerDeclared = ref<1 | 2 | null>(null)
const isShaking = ref(false)
const isFlashing = ref(false) 

onMounted(() => {
  const cached = localStorage.getItem(CACHE_KEY);
  if (cached) {
    try {
      items.value = JSON.parse(cached);
    } catch (e) {
      items.value = [];
    }
  }
});

const saveItems = () => {
  localStorage.setItem(CACHE_KEY, JSON.stringify(items.value));
}

const addItem = () => {
  const val = newItem.value.trim()
  if (val) {
    items.value.unshift(val) 
    newItem.value = ''
    saveItems()
  }
}

const removeItem = (index: number) => {
  items.value.splice(index, 1)
  saveItems()
}

const clearAll = () => {
  items.value = []
  saveItems()
}

let audioCtx: AudioContext | null = null;

const initAudio = () => {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
  }
}

const playTone = (freq: number, type: OscillatorType, duration: number, vol: number) => {
  if (!audioCtx) return;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  
  osc.type = type;
  osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
  gain.gain.setValueAtTime(vol, audioCtx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
  
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start();
  osc.stop(audioCtx.currentTime + duration);
}

const sfx = {
  click: () => playTone(300, 'square', 0.05, 0.1),
  tick: () => playTone(800, 'sine', 0.03, 0.3), 
  hit: () => {
    playTone(100, 'sawtooth', 0.4, 0.4); 
    playTone(800, 'square', 0.15, 0.2); 
  },
  win: () => {
    setTimeout(() => playTone(440, 'square', 0.15, 0.3), 0);
    setTimeout(() => playTone(554, 'square', 0.15, 0.3), 150);
    setTimeout(() => playTone(659, 'square', 0.15, 0.3), 300);
    setTimeout(() => playTone(880, 'square', 0.8, 0.3), 450);
  }
}

const initiateTournament = () => {
  initAudio();
  sfx.click();
  
  let players = [...items.value];
  
  for (let i = players.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [players[i], players[j]] = [players[j], players[i]];
  }

  currentRound.value = 1;
  nextRoundPlayers.value = [];
  buildRound(players);
  
  phase.value = 'battle';
  simulationRunning.value = true;
  executeNextMatch();
}

const buildRound = (players: string[]) => {
  upcomingMatches.value = [];
  matchIndex.value = 0;
  let pool = [...players];
  
  while (pool.length >= 2) {
    upcomingMatches.value.push([pool.pop()!, pool.pop()!]);
  }
  
  if (pool.length === 1) {
    nextRoundPlayers.value.push(pool[0]); 
  }
  
  totalMatchesInRound.value = upcomingMatches.value.length;
}

const executeNextMatch = () => {
  winnerDeclared.value = null;
  matchScores.value = [0, 0];
  isMatchOver.value = false;
  
  if (upcomingMatches.value.length > 0) {
    currentMatch.value = upcomingMatches.value.shift() || null;
    startDramaticRoulette();
  } else {
    if (nextRoundPlayers.value.length === 1) {
      grandWinner.value = nextRoundPlayers.value[0];
      phase.value = 'complete';
      simulationRunning.value = false;
      sfx.win();
    } else {
      currentRound.value++;
      buildRound([...nextRoundPlayers.value]);
      nextRoundPlayers.value = [];
      executeNextMatch();
    }
  }
}

const startDramaticRoulette = () => {
  rouletteActive.value = true;
  let ticks = 0;
  const maxTicks = Math.floor(Math.random() * 10) + 20; 
  let tickInterval = 60; 

  const spinNode = () => {
    activeRouletteIndex.value = activeRouletteIndex.value === 1 ? 2 : 1;
    sfx.tick();
    ticks++;

    if (ticks > maxTicks - 5) tickInterval += 30;

    if (ticks < maxTicks) {
      setTimeout(spinNode, tickInterval);
    } else {
      resolveMatchWithRNG();
    }
  }
  
  spinNode();
}

const resolveMatchWithRNG = () => {
  rouletteActive.value = false;
  
  const winIndex = Math.random() < 0.5 ? 1 : 2;
  winnerDeclared.value = winIndex;
  matchScores.value[winIndex - 1]++;
  
  sfx.hit();
  triggerHeavyImpact();

  const requiredWins = Math.ceil(bestOf.value / 2);

  if (matchScores.value[winIndex - 1] >= requiredWins) {
    isMatchOver.value = true;
    const winnerName = currentMatch.value![winIndex - 1];
    nextRoundPlayers.value.push(winnerName);

    setTimeout(() => {
      matchIndex.value++;
      executeNextMatch();
    }, 2500); 
  } else {
    setTimeout(() => {
      winnerDeclared.value = null;
      startDramaticRoulette();
    }, 1800);
  }
}

const triggerHeavyImpact = () => {
  isShaking.value = true;
  isFlashing.value = true;
  
  setTimeout(() => isFlashing.value = false, 50); 
  setTimeout(() => isShaking.value = false, 400); 
}

const getCardClasses = (playerIndex: 1 | 2) => {
  const base = "bg-[#363432] shadow-2xl"
  
  if (rouletteActive.value) {
    if (activeRouletteIndex.value === playerIndex) {
      return `${base} border-[#F5F5F5] scale-105 z-10 shadow-[0_0_40px_rgba(245,245,245,0.3)]`
    }
    return `${base} border-[#7E8083]/40 scale-[0.98] opacity-70 blur-[2px]`
  }
  
  if (winnerDeclared.value) {
    if (winnerDeclared.value === playerIndex) {
      return `${base} border-[#D6C4B0] bg-[#D6C4B0]/10 scale-105 z-30 shadow-[0_0_80px_rgba(214,196,176,0.6)]`
      // return `${base} border-[#D6C4B0] bg-[#D6C4B0]/10 scale-105 z-30 opacity-40 filter-grayscale blur-[2px]`
    }
    return `${base} border-[#7E8083] scale-90 opacity-20 filter-grayscale blur-[6px]`
  }
  
  return `${base} border-[#7E8083]` 
}

const getTextColor = (playerIndex: 1 | 2) => {
  if (winnerDeclared.value === playerIndex) return 'text-[#F5F5F5]'; 
  if (rouletteActive.value && activeRouletteIndex.value === playerIndex) return 'text-[#F5F5F5]'; 
  return 'text-[#F5F5F5]'; 
}

const reset = () => {
  phase.value = 'input';
  grandWinner.value = null;
  currentMatch.value = null;
  matchScores.value = [0,0];
}
</script>

<style>
@keyframes heavyShake {
  0% { transform: translate(4px, 4px) rotate(0deg); }
  10% { transform: translate(-4px, -6px) rotate(-1deg); }
  20% { transform: translate(-8px, 0px) rotate(1deg); }
  30% { transform: translate(8px, 4px) rotate(0deg); }
  40% { transform: translate(4px, -4px) rotate(1deg); }
  50% { transform: translate(-4px, 6px) rotate(-1deg); }
  60% { transform: translate(-8px, 2px) rotate(0deg); }
  70% { transform: translate(8px, 2px) rotate(-1deg); }
  80% { transform: translate(-4px, -4px) rotate(1deg); }
  90% { transform: translate(4px, 6px) rotate(0deg); }
  100% { transform: translate(2px, -4px) rotate(-1deg); }
}

.animate-heavy-shake {
  animation: heavyShake 0.4s cubic-bezier(.36,.07,.19,.97) both;
}

@keyframes aggressivePop {
  0% { transform: scale(0.5) rotate(-5deg); opacity: 0; }
  50% { transform: scale(1.1) rotate(2deg); opacity: 1; }
  100% { transform: scale(1) rotate(0deg); opacity: 1; }
}

.animate-aggressive-pop {
  animation: aggressivePop 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275) both;
}

@keyframes slideDown {
  from { opacity: 0; transform: scaleY(0.9); }
  to { opacity: 1; transform: scaleY(1); }
}

.animate-slide-down {
  animation: slideDown 0.15s ease-out forwards;
}

@keyframes tilt {
  0%, 50%, 100% { transform: rotate(0deg); }
  25% { transform: rotate(0.4deg); }
  75% { transform: rotate(-0.4deg); }
}

.animate-tilt {
  animation: tilt 8s infinite linear;
}
</style>