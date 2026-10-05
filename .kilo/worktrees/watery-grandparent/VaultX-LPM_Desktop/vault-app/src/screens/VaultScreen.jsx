import { useState, useEffect, useMemo } from 'react'
import CredentialCard from '../components/CredentialCard.jsx'
import CredentialForm from '../components/CredentialForm.jsx'
import Generator from '../components/Generator.jsx'

export default function VaultScreen({ onLocked }) {
  const [credentials, setCredentials] = useState([])
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState(null)   // credential being viewed/edited
  const [isAdding, setIsAdding] = useState(false)
  const [showGen, setShowGen] = useState(false)
  const [toastMsg, setToastMsg] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => { loadCredentials() }, [])

  async function loadCredentials() {
    setLoading(true)
    const list = await window.vault.list()
    setCredentials(list)
    setLoading(false)
  }

  const filtered = useMemo(() => {
    const q = search.toLowerCase()
    if (!q) return credentials
    return credentials.filter(c =>
      c.title?.toLowerCase().includes(q) ||
      c.username?.toLowerCase().includes(q) ||
      c.url?.toLowerCase().includes(q)
    )
  }, [credentials, search])

  function toast(msg) {
    setToastMsg(msg)
    setTimeout(() => setToastMsg(null), 2500)
  }

  async function handleLock() {
    await window.vault.lock()
    onLocked()
  }

  async function handleSave(credential) {
    await window.vault.save(credential)
    await loadCredentials()
    setSelected(null)
    setIsAdding(false)
    toast(credential.id ? 'Changes saved' : 'Credential added')
  }

  async function handleDelete(id) {
    await window.vault.delete(id)
    await loadCredentials()
    setSelected(null)
    toast('Credential deleted')
  }

  async function handleCopy(text, label) {
    await window.clipboard.copy(text)
    toast(`${label} copied — clears in 30s`)
  }

  const panel = isAdding
    ? <CredentialForm key="new" onSave={handleSave} onCancel={() => setIsAdding(false)} onCopy={handleCopy} />
    : selected
    ? <CredentialForm key={selected.id} credential={selected} onSave={handleSave} onCancel={() => setSelected(null)} onDelete={handleDelete} onCopy={handleCopy} />
    : showGen
    ? <Generator onCopy={handleCopy} onClose={() => setShowGen(false)} />
    : <EmptyState onAdd={() => setIsAdding(true)} onGen={() => setShowGen(true)} />

  return (
    <div style={styles.root}>
      <div className="titlebar" />

      {/* Sidebar */}
      <div style={styles.body}>
        <aside style={styles.sidebar}>
          <div style={styles.sidebarTop}>
            <div style={styles.appName}>
              <ShieldIcon />
              <span style={{ fontWeight: 600, fontSize: 15 }}>Vault</span>
            </div>
            <div style={styles.sidebarActions}>
              <button style={styles.iconBtn} onClick={() => { setIsAdding(true); setSelected(null); setShowGen(false) }} title="Add credential">
                <PlusIcon />
              </button>
              <button style={styles.iconBtn} onClick={() => { setShowGen(true); setSelected(null); setIsAdding(false) }} title="Password generator">
                <DiceIcon />
              </button>
              <button style={{ ...styles.iconBtn, color: 'var(--text-3)' }} onClick={handleLock} title="Lock vault">
                <LockIcon />
              </button>
            </div>
          </div>

          <div style={styles.searchWrap}>
            <SearchIcon />
            <input
              style={styles.searchInput}
              placeholder="Search…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
            {search && (
              <button style={styles.clearBtn} onClick={() => setSearch('')}>×</button>
            )}
          </div>

          <div style={styles.list}>
            {loading ? (
              <div style={styles.listEmpty}>Loading…</div>
            ) : filtered.length === 0 ? (
              <div style={styles.listEmpty}>
                {search ? 'No results' : 'No credentials yet'}
              </div>
            ) : (
              filtered.map((c, i) => (
                <CredentialCard
                  key={c.id}
                  credential={c}
                  active={selected?.id === c.id}
                  style={{ animationDelay: `${i * 0.03}s` }}
                  onClick={() => { setSelected(c); setIsAdding(false); setShowGen(false) }}
                />
              ))
            )}
          </div>

          <div style={styles.sidebarFooter}>
            <span style={{ color: 'var(--text-3)', fontSize: 12 }}>
              {credentials.length} item{credentials.length !== 1 ? 's' : ''}
            </span>
          </div>
        </aside>

        {/* Detail panel */}
        <main style={styles.main}>
          {panel}
        </main>
      </div>

      {/* Toast */}
      {toastMsg && (
        <div style={styles.toast} className="animate-slide-up">
          <CheckIcon /> {toastMsg}
        </div>
      )}
    </div>
  )
}

function EmptyState({ onAdd, onGen }) {
  return (
    <div style={{ display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', height:'100%', gap:16, padding:40 }}>
      <div style={{ fontSize:40, opacity:0.15 }}>🔐</div>
      <p style={{ color:'var(--text-2)', textAlign:'center', lineHeight:1.7, maxWidth:260, fontSize:13.5 }}>
        Select a credential to view it, or add a new one to get started.
      </p>
      <div style={{ display:'flex', gap:8, marginTop:4 }}>
        <button onClick={onAdd} style={btnStyle('primary')}>Add credential</button>
        <button onClick={onGen} style={btnStyle('secondary')}>Generate password</button>
      </div>
    </div>
  )
}

function btnStyle(variant) {
  return {
    padding: '8px 16px', fontSize: 13.5, fontWeight: 500,
    borderRadius: 'var(--radius)', cursor: 'pointer',
    background: variant === 'primary' ? 'var(--accent)' : 'var(--bg-hover)',
    color: variant === 'primary' ? '#fff' : 'var(--text)',
    border: variant === 'secondary' ? '1px solid var(--border)' : 'none',
  }
}

const styles = {
  root: { display:'flex', flexDirection:'column', height:'100%', overflow:'hidden' },
  body: { display:'flex', flex:1, overflow:'hidden' },

  sidebar: {
    width: 260, flexShrink: 0, borderRight: '1px solid var(--border)',
    background: 'var(--bg)', display: 'flex', flexDirection: 'column', overflow: 'hidden',
  },
  sidebarTop: {
    display:'flex', alignItems:'center', justifyContent:'space-between',
    padding:'10px 14px 8px', borderBottom:'1px solid var(--border)',
  },
  appName: { display:'flex', alignItems:'center', gap:8, color:'var(--text)' },
  sidebarActions: { display:'flex', gap:2 },
  iconBtn: {
    background:'none', color:'var(--text-2)', padding:6,
    borderRadius:'var(--radius)', display:'flex', alignItems:'center',
    transition:'background 0.12s, color 0.12s',
  },

  searchWrap: {
    display:'flex', alignItems:'center', gap:8, margin:'10px 10px 6px',
    background:'var(--bg-input)', border:'1.5px solid var(--border)',
    borderRadius:'var(--radius)', padding:'7px 10px',
  },
  searchInput: {
    flex:1, background:'none', border:'none', fontSize:13.5,
    color:'var(--text)', '::placeholder': { color:'var(--text-3)' },
  },
  clearBtn: {
    background:'none', color:'var(--text-3)', fontSize:16,
    lineHeight:1, padding:'0 2px', cursor:'pointer',
  },

  list: { flex:1, overflowY:'auto', padding:'4px 8px' },
  listEmpty: { padding:'32px 16px', color:'var(--text-3)', fontSize:13, textAlign:'center' },

  sidebarFooter: {
    padding:'8px 14px', borderTop:'1px solid var(--border)',
    display:'flex', alignItems:'center', justifyContent:'flex-end',
  },

  main: {
    flex:1, overflowY:'auto', background:'var(--bg)',
  },

  toast: {
    position:'fixed', bottom:20, left:'50%', transform:'translateX(-50%)',
    background:'var(--text)', color:'var(--bg)', borderRadius:99,
    padding:'8px 18px', fontSize:13, fontWeight:500,
    display:'flex', alignItems:'center', gap:7, pointerEvents:'none',
    boxShadow:'0 4px 16px rgba(0,0,0,0.18)',
    zIndex:1000,
  },
}

const ShieldIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round">
    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
  </svg>
)
const PlusIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
  </svg>
)
const DiceIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <rect x="2" y="2" width="20" height="20" rx="4"/>
    <circle cx="8" cy="8" r="1.2" fill="currentColor"/><circle cx="16" cy="8" r="1.2" fill="currentColor"/>
    <circle cx="12" cy="12" r="1.2" fill="currentColor"/>
    <circle cx="8" cy="16" r="1.2" fill="currentColor"/><circle cx="16" cy="16" r="1.2" fill="currentColor"/>
  </svg>
)
const LockIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <rect x="3" y="11" width="18" height="11" rx="2"/>
    <path d="M7 11V7a5 5 0 0110 0v4"/>
  </svg>
)
const SearchIcon = () => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="var(--text-3)" strokeWidth="2" strokeLinecap="round" style={{flexShrink:0}}>
    <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
  </svg>
)
const CheckIcon = () => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
    <polyline points="20 6 9 17 4 12"/>
  </svg>
)
