import { useState, useEffect } from 'react'
import Generator from './Generator.jsx'

export default function CredentialForm({ credential, onSave, onCancel, onDelete, onCopy }) {
  const isNew = !credential?.id
  const [form, setForm] = useState({
    title: '', url: '', username: '', password: '', notes: '',
    ...credential,
  })
  const [showPass, setShowPass] = useState(false)
  const [showGen, setShowGen] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [strength, setStrength] = useState(0)

  useEffect(() => {
    setStrength(calcStrength(form.password))
  }, [form.password])

  function set(field, value) {
    setForm(f => ({ ...f, [field]: value }))
  }

  async function handleSubmit(e) {
    e.preventDefault()
    if (!form.title) return
    onSave(form)
  }

  function handleGenerated(password) {
    set('password', password)
    setShowGen(false)
  }

  const strengthLabel = ['', 'Weak', 'Fair', 'Good', 'Strong'][strength]
  const strengthColor = ['', 'var(--danger)', 'var(--warning)', '#2CA05A', 'var(--success)'][strength]

  return (
    <div style={styles.root} className="animate-fade-in">
      {/* Header */}
      <div style={styles.header}>
        <h2 style={styles.heading}>{isNew ? 'New credential' : form.title || 'Edit'}</h2>
        <button onClick={onCancel} style={styles.ghostBtn}>Cancel</button>
      </div>

      <div style={styles.body}>
        <form onSubmit={handleSubmit} style={styles.form}>
          <Field label="Title" required>
            <input style={styles.input} value={form.title} onChange={e => set('title', e.target.value)} placeholder="e.g. GitHub" autoFocus={isNew} />
          </Field>

          <Field label="Website URL">
            <input style={styles.input} value={form.url} onChange={e => set('url', e.target.value)} placeholder="https://github.com" type="url" />
          </Field>

          <Field label="Username / email">
            <div style={{ position:'relative' }}>
              <input style={styles.input} value={form.username} onChange={e => set('username', e.target.value)} placeholder="you@example.com" autoComplete="off" />
              {form.username && (
                <CopyBtn onClick={() => onCopy(form.username, 'Username')} />
              )}
            </div>
          </Field>

          <Field label="Password">
            <div style={{ position:'relative' }}>
              <input
                style={{ ...styles.input, fontFamily: showPass ? 'var(--font)' : 'var(--font-mono)', paddingRight: 76 }}
                type={showPass ? 'text' : 'password'}
                value={form.password}
                onChange={e => set('password', e.target.value)}
                placeholder="••••••••••••"
                autoComplete="new-password"
              />
              <div style={{ position:'absolute', right:6, top:'50%', transform:'translateY(-50%)', display:'flex', gap:2 }}>
                {form.password && <CopyBtn onClick={() => onCopy(form.password, 'Password')} />}
                <button type="button" onClick={() => setShowPass(v => !v)} style={styles.inlineIconBtn}>
                  {showPass ? <EyeOffIcon /> : <EyeIcon />}
                </button>
              </div>
            </div>

            {/* Strength bar */}
            {form.password && (
              <div style={{ marginTop:6, display:'flex', alignItems:'center', gap:8 }}>
                <div style={{ flex:1, height:3, background:'var(--border)', borderRadius:99, overflow:'hidden' }}>
                  <div style={{ height:'100%', width:`${strength * 25}%`, background:strengthColor, borderRadius:99, transition:'width 0.3s, background 0.3s' }} />
                </div>
                <span style={{ fontSize:11, color:strengthColor, fontWeight:500, minWidth:36 }}>{strengthLabel}</span>
              </div>
            )}

            <button type="button" onClick={() => setShowGen(v => !v)} style={{ ...styles.ghostBtn, marginTop:6, fontSize:12, color:'var(--accent)' }}>
              <DiceIcon /> Generate password
            </button>
          </Field>

          {showGen && (
            <div style={styles.genInline}>
              <Generator inline onCopy={onCopy} onUse={handleGenerated} />
            </div>
          )}

          <Field label="Notes">
            <textarea
              style={{ ...styles.input, minHeight:80, resize:'vertical', lineHeight:1.6 }}
              value={form.notes}
              onChange={e => set('notes', e.target.value)}
              placeholder="Any extra info…"
            />
          </Field>

          <div style={styles.actions}>
            <button type="submit" disabled={!form.title} style={{ ...styles.btn('primary'), opacity: !form.title ? 0.5 : 1 }}>
              {isNew ? 'Add credential' : 'Save changes'}
            </button>

            {!isNew && !confirmDelete && (
              <button type="button" onClick={() => setConfirmDelete(true)} style={styles.btn('danger-ghost')}>
                Delete
              </button>
            )}
            {confirmDelete && (
              <div style={{ display:'flex', alignItems:'center', gap:8 }}>
                <span style={{ fontSize:13, color:'var(--danger)' }}>Delete this?</span>
                <button type="button" onClick={() => onDelete(credential.id)} style={styles.btn('danger')}>Yes, delete</button>
                <button type="button" onClick={() => setConfirmDelete(false)} style={styles.btn('secondary')}>No</button>
              </div>
            )}
          </div>
        </form>
      </div>
    </div>
  )
}

function Field({ label, children, required }) {
  return (
    <div style={{ display:'flex', flexDirection:'column', gap:5 }}>
      <label style={{ fontSize:12, fontWeight:500, color:'var(--text-2)', letterSpacing:'0.02em' }}>
        {label}{required && <span style={{color:'var(--danger)'}}> *</span>}
      </label>
      {children}
    </div>
  )
}

function CopyBtn({ onClick }) {
  return (
    <button type="button" onClick={onClick} style={{
      background:'none', color:'var(--text-3)', padding:5, display:'flex', alignItems:'center',
      borderRadius:6, transition:'color 0.12s, background 0.12s', cursor:'pointer',
    }}
    onMouseEnter={e => { e.currentTarget.style.color='var(--accent)'; e.currentTarget.style.background='var(--accent-bg)' }}
    onMouseLeave={e => { e.currentTarget.style.color='var(--text-3)'; e.currentTarget.style.background='none' }}
    >
      <CopyIcon />
    </button>
  )
}

function calcStrength(password) {
  if (!password || password.length < 4) return 0
  let score = 0
  if (password.length >= 8)  score++
  if (password.length >= 14) score++
  if (/[A-Z]/.test(password) && /[a-z]/.test(password)) score++
  if (/[0-9]/.test(password)) score += 0.5
  if (/[^A-Za-z0-9]/.test(password)) score += 0.5
  return Math.min(4, Math.floor(score))
}

const styles = {
  root: { height:'100%', display:'flex', flexDirection:'column', overflow:'hidden' },
  header: {
    display:'flex', alignItems:'center', justifyContent:'space-between',
    padding:'18px 28px 14px', borderBottom:'1px solid var(--border)',
    flexShrink:0,
  },
  heading: { fontSize:18, fontWeight:600, letterSpacing:'-0.3px' },
  body: { flex:1, overflowY:'auto', padding:'24px 28px' },
  form: { display:'flex', flexDirection:'column', gap:18, maxWidth:500 },
  input: {
    width:'100%', padding:'9px 12px', fontSize:14,
    background:'var(--bg-input)', border:'1.5px solid var(--border)',
    borderRadius:'var(--radius)', color:'var(--text)',
    transition:'border-color 0.15s',
  },
  actions: { display:'flex', flexWrap:'wrap', gap:8, paddingTop:8 },
  ghostBtn: {
    background:'none', color:'var(--text-2)', fontSize:13.5, fontWeight:500,
    padding:'4px 2px', cursor:'pointer', display:'flex', alignItems:'center', gap:5,
  },
  inlineIconBtn: {
    background:'none', color:'var(--text-3)', padding:4, display:'flex', alignItems:'center', cursor:'pointer',
  },
  btn: (v) => ({
    padding:'8px 16px', fontSize:13.5, fontWeight:500,
    borderRadius:'var(--radius)', cursor:'pointer', transition:'opacity 0.15s',
    ...(v === 'primary'      && { background:'var(--accent)', color:'#fff', border:'none' }),
    ...(v === 'secondary'    && { background:'var(--bg-hover)', color:'var(--text)', border:'1px solid var(--border)' }),
    ...(v === 'danger'       && { background:'var(--danger)', color:'#fff', border:'none' }),
    ...(v === 'danger-ghost' && { background:'none', color:'var(--danger)', border:'1px solid var(--danger-bg)' }),
  }),
  genInline: {
    background:'var(--bg-hover)', borderRadius:'var(--radius-lg)',
    border:'1px solid var(--border)', padding:'16px', marginTop:'-8px',
  },
}

const EyeIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
  </svg>
)
const EyeOffIcon = () => (
  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"/>
    <path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19"/>
    <line x1="1" y1="1" x2="23" y2="23"/>
  </svg>
)
const CopyIcon = () => (
  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
  </svg>
)
const DiceIcon = () => (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <rect x="2" y="2" width="20" height="20" rx="4"/>
    <circle cx="8" cy="8" r="1.2" fill="currentColor"/><circle cx="16" cy="8" r="1.2" fill="currentColor"/>
    <circle cx="12" cy="12" r="1.2" fill="currentColor"/>
    <circle cx="8" cy="16" r="1.2" fill="currentColor"/><circle cx="16" cy="16" r="1.2" fill="currentColor"/>
  </svg>
)
