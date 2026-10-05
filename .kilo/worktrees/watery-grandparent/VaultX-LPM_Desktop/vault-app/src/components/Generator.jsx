import { useState, useEffect } from 'react'

const DEFAULT_OPTS = {
  length: 20,
  uppercase: true,
  lowercase: true,
  numbers: true,
  symbols: true,
}

export default function Generator({ inline, onCopy, onUse, onClose }) {
  const [opts, setOpts] = useState(DEFAULT_OPTS)
  const [password, setPassword] = useState('')
  const [copied, setCopied] = useState(false)

  useEffect(() => { generate() }, [])

  async function generate() {
    const { password: pw } = await window.generator.generate(opts)
    setPassword(pw)
    setCopied(false)
  }

  function setOpt(key, value) {
    setOpts(o => ({ ...o, [key]: value }))
  }

  useEffect(() => { generate() }, [opts])

  async function handleCopy() {
    await onCopy(password, 'Password')
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div style={{ display:'flex', flexDirection:'column', gap:16 }}>
      {!inline && (
        <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'18px 28px 14px', borderBottom:'1px solid var(--border)', flexShrink:0 }}>
          <h2 style={{ fontSize:18, fontWeight:600, letterSpacing:'-0.3px' }}>Password generator</h2>
          <button onClick={onClose} style={{ background:'none', color:'var(--text-2)', fontSize:13.5, fontWeight:500, cursor:'pointer' }}>Close</button>
        </div>
      )}

      <div style={{ padding: inline ? 0 : '24px 28px', display:'flex', flexDirection:'column', gap:16, maxWidth:440 }}>
        {/* Generated password display */}
        <div style={styles.passDisplay}>
          <span style={{ fontFamily:'var(--font-mono)', fontSize:15, letterSpacing:'0.04em', color:'var(--text)', wordBreak:'break-all', flex:1, lineHeight:1.6 }}>
            {password}
          </span>
          <div style={{ display:'flex', gap:4, flexShrink:0 }}>
            <button onClick={generate} style={styles.iconAction} title="Regenerate">
              <RefreshIcon />
            </button>
            <button onClick={handleCopy} style={{ ...styles.iconAction, color: copied ? 'var(--success)' : undefined }} title="Copy">
              {copied ? <CheckIcon /> : <CopyIcon />}
            </button>
          </div>
        </div>

        {/* Length slider */}
        <div>
          <div style={{ display:'flex', justifyContent:'space-between', marginBottom:8 }}>
            <span style={styles.optLabel}>Length</span>
            <span style={{ fontSize:13, fontWeight:600, color:'var(--accent)' }}>{opts.length}</span>
          </div>
          <input
            type="range" min={8} max={64} value={opts.length}
            onChange={e => setOpt('length', Number(e.target.value))}
            style={{ width:'100%', accentColor:'var(--accent)' }}
          />
        </div>

        {/* Toggles */}
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:8 }}>
          {[
            ['uppercase', 'Uppercase (A–Z)'],
            ['lowercase', 'Lowercase (a–z)'],
            ['numbers',   'Numbers (0–9)'],
            ['symbols',   'Symbols (!@#…)'],
          ].map(([key, label]) => (
            <Toggle key={key} label={label} checked={opts[key]} onChange={v => setOpt(key, v)} />
          ))}
        </div>

        {/* Use this password (when inline) */}
        {onUse && (
          <button onClick={() => onUse(password)} style={styles.useBtn}>
            Use this password
          </button>
        )}
      </div>
    </div>
  )
}

function Toggle({ label, checked, onChange }) {
  return (
    <label style={{ display:'flex', alignItems:'center', gap:8, cursor:'pointer', padding:'8px 10px', borderRadius:'var(--radius)', background: checked ? 'var(--accent-bg)' : 'var(--bg-hover)', border:`1.5px solid ${checked ? 'var(--accent-bg)' : 'var(--border)'}`, transition:'all 0.15s', userSelect:'none' }}>
      <div style={{
        width:16, height:16, borderRadius:4, flexShrink:0,
        background: checked ? 'var(--accent)' : 'var(--bg-card)',
        border: `1.5px solid ${checked ? 'var(--accent)' : 'var(--border)'}`,
        display:'flex', alignItems:'center', justifyContent:'center',
        transition:'all 0.15s',
      }}>
        {checked && <CheckSmIcon />}
      </div>
      <input type="checkbox" checked={checked} onChange={e => onChange(e.target.checked)} style={{ display:'none' }} />
      <span style={{ fontSize:12.5, fontWeight:500, color: checked ? 'var(--accent-text)' : 'var(--text-2)' }}>{label}</span>
    </label>
  )
}

const styles = {
  passDisplay: {
    display:'flex', alignItems:'flex-start', gap:10,
    background:'var(--bg-card)', border:'1.5px solid var(--border)',
    borderRadius:'var(--radius-lg)', padding:'12px 14px',
    boxShadow:'var(--shadow)',
  },
  iconAction: {
    background:'none', color:'var(--text-2)', padding:7,
    borderRadius:'var(--radius)', display:'flex', alignItems:'center',
    transition:'background 0.12s, color 0.12s', cursor:'pointer',
  },
  optLabel: { fontSize:13, fontWeight:500, color:'var(--text-2)' },
  useBtn: {
    padding:'9px 0', fontSize:13.5, fontWeight:500,
    background:'var(--accent)', color:'#fff', borderRadius:'var(--radius)',
    cursor:'pointer', transition:'opacity 0.15s',
  },
}

const RefreshIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
  </svg>
)
const CopyIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
  </svg>
)
const CheckIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round">
    <polyline points="20 6 9 17 4 12"/>
  </svg>
)
const CheckSmIcon = () => (
  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round">
    <polyline points="20 6 9 17 4 12"/>
  </svg>
)
