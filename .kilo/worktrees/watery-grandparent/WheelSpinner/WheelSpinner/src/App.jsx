import React, { useState, useEffect, useRef } from 'react';
import Wheel from './Wheel';

const App = () => {
  const [list, setList] = useState(() => {
    const saved = localStorage.getItem('spinnerList');
    return saved ? JSON.parse(saved) : ['React', 'Vue', 'Angular', 'Svelte'];
  });
  const [newItem, setNewItem] = useState('');
  const [winner, setWinner] = useState(null);
  const [isSpinning, setIsSpinning] = useState(false);
  const wheelRef = useRef(null);

  // Save list to local storage
  useEffect(() => {
    localStorage.setItem('spinnerList', JSON.stringify(list));
  }, [list]);

  // --- NEW: Keyboard & Scroll Lock Hook for Modal ---
  useEffect(() => {
    if (!winner) return;

    // 1. Lock the background from scrolling on mobile
    document.body.style.overflow = 'hidden';

    // 2. Listen for the Enter key
    const handleKeyDown = (e) => {
      if (e.key === 'Enter') {
        e.preventDefault(); // Stop it from accidentally submitting the 'Add' form
        setWinner(null);
      }
    };

    window.addEventListener('keydown', handleKeyDown);

    // Cleanup: Unlock scrolling and remove listener when modal closes
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [winner]);

  const addItem = (e) => {
    e.preventDefault();
    if (newItem.trim()) {
      setList([...list, newItem.trim()]);
      setNewItem('');
    }
  };

  const removeItem = (indexToRemove) => {
    setList(list.filter((_, idx) => idx !== indexToRemove));
  };

  return (
    <div className="min-h-[100dvh] lg:h-[100dvh] w-full bg-[#1c2030] text-[#A8C4EC] flex flex-col lg:flex-row font-sans selection:bg-[#0474C4] selection:text-white relative overflow-x-hidden">
      
      {/* --- UPDATED WINNER MODAL --- */}
      {winner && (
        // Changed "absolute" to "fixed" and added "touch-none z-[100]"
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-[#1c2030]/90 backdrop-blur-md transition-all touch-none">
          <div className="bg-[#262B40] border-2 border-[#0474C4] p-8 md:p-12 rounded-3xl shadow-[0_0_100px_rgba(4,116,196,0.5)] flex flex-col items-center max-w-lg w-full text-center animate-in zoom-in duration-300">
            <h3 className="text-[#5379AE] uppercase tracking-widest font-bold mb-4 text-sm md:text-base">We have a winner!</h3>
            <h2 className="text-4xl md:text-6xl font-black text-white mb-8 break-words w-full">{winner}</h2>
            <button 
              onClick={() => setWinner(null)}
              className="w-full py-4 rounded-xl bg-[#0474C4] text-white text-lg font-black uppercase tracking-widest hover:bg-[#06457F] active:scale-[0.98] transition-all shadow-lg flex flex-col items-center justify-center gap-1"
            >
              <span>Continue</span>
              {/* <span className="text-xs text-[#A8C4EC]/70 font-medium normal-case tracking-normal">(Press Enter)</span> */}
            </button>
          </div>
        </div>
      )}

      {/* Left Area: Responsive Wheel Space */}
      <div className="w-full lg:flex-1 relative flex items-center justify-center p-4 py-12 lg:p-8 min-h-[50vh] lg:h-full bg-gradient-to-br from-[#262B40] to-[#1c2030]">
        <Wheel 
          ref={wheelRef} 
          items={list} 
          onSpinStart={() => {
            setWinner(null);
            setIsSpinning(true);
          }}
          onFinished={(winningItem) => {
            setWinner(winningItem);
            setIsSpinning(false);
          }}
        />
      </div>
      
      {/* Right Area: Control Panel */}
      <div className="w-full lg:w-[450px] lg:h-full bg-[#262B40] border-t lg:border-t-0 lg:border-l border-[#2C444C] flex flex-col shadow-2xl z-10 p-5 lg:p-8 flex-1">
        
        <div className="flex justify-between items-end mb-6 pt-4 lg:pt-0">
          <h2 className="text-2xl lg:text-3xl font-black text-white tracking-tight">
            WHEEL SPINNER
          </h2>
          <span className="text-xs font-bold text-[#A8C4EC] bg-[#A8C4EC]/10 px-3 py-1 rounded-full border border-[#A8C4EC]/20">
            {list.length} ITEMS
          </span>
        </div>

        <button 
          onClick={() => wheelRef.current?.spin()}
          disabled={list.length < 2 || isSpinning}
          className="w-full mb-6 py-4 rounded-xl bg-[#0474C4] text-white text-lg font-black uppercase tracking-widest hover:bg-[#06457F] active:scale-[0.98] transition-all disabled:opacity-40 disabled:cursor-not-allowed shadow-[0_0_20px_rgba(4,116,196,0.3)] shrink-0"
        >
          {list.length < 2 ? 'Need more items' : isSpinning ? 'Spinning...' : 'Spin The Wheel'}
        </button>

        <form onSubmit={addItem} className="mb-4 relative shrink-0">
          <input 
            className="w-full p-4 pr-24 bg-[#1c2030] text-white text-base border border-[#2C444C] focus:outline-none focus:border-[#5379AE] focus:ring-1 focus:ring-[#5379AE] transition-colors placeholder:text-[#5379AE]/60 rounded-xl"
            placeholder="Enter new target..."
            value={newItem}
            onChange={(e) => setNewItem(e.target.value)}
            disabled={isSpinning}
          />
          <button 
            disabled={isSpinning}
            className="absolute right-2 top-2 bottom-2 bg-[#5379AE] hover:bg-[#A8C4EC] hover:text-[#262B40] disabled:opacity-50 text-white px-5 font-bold uppercase text-sm tracking-wider transition-colors rounded-lg"
          >
            Add
          </button>
        </form>

        <div className="flex-1 overflow-y-auto pr-2 space-y-2 slim-scrollbar min-h-[250px] lg:min-h-0">
          {list.map((item, i) => (
            <div key={i} className="flex justify-between items-center bg-[#1c2030] border border-[#2C444C]/50 hover:border-[#5379AE] p-4 rounded-xl transition-colors group">
              <span className="font-semibold text-white truncate pr-4">{item}</span>
              <button 
                onClick={() => !isSpinning && removeItem(i)} 
                disabled={isSpinning}
                className="text-[#5379AE] hover:text-white disabled:hover:text-[#5379AE] transition-colors p-2 -mr-2"
              >
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          ))}
        </div>

        <button 
          onClick={() => { if(!isSpinning) { setList([]); localStorage.removeItem('spinnerList'); } }} 
          disabled={isSpinning}
          className="mt-6 pt-4 pb-4 lg:pb-0 border-t border-[#2C444C] w-full text-[#5379AE] hover:text-white disabled:hover:text-[#5379AE] text-sm font-bold uppercase tracking-widest transition-colors shrink-0"
        >
          Clear Items
        </button>
      </div>
    </div>
  );
};

export default App;