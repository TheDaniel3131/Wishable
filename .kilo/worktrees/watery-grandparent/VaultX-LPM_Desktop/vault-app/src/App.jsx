import { useState, useEffect } from 'react'
import UnlockScreen from './screens/UnlockScreen.jsx'
import VaultScreen from './screens/VaultScreen.jsx'

export default function App() {
  const [appState, setAppState] = useState('loading') // loading | setup | locked | unlocked

  useEffect(() => {
    async function boot() {
      const { initialised, unlocked } = await window.vault.status()
      if (!initialised) setAppState('setup')
      else if (unlocked) setAppState('unlocked')
      else setAppState('locked')
    }
    boot()

    // Listen for auto-lock events
    window.vault.onLocked(() => setAppState('locked'))
  }, [])

  if (appState === 'loading') {
    return (
      <div style={{ display:'flex', alignItems:'center', justifyContent:'center', height:'100%' }}>
        <div style={{ width:24, height:24, border:'2px solid var(--border)', borderTopColor:'var(--accent)', borderRadius:'50%', animation:'spin 0.7s linear infinite' }} />
      </div>
    )
  }

  if (appState === 'setup' || appState === 'locked') {
    return (
      <UnlockScreen
        isSetup={appState === 'setup'}
        onUnlocked={() => setAppState('unlocked')}
      />
    )
  }

  return <VaultScreen onLocked={() => setAppState('locked')} />
}
