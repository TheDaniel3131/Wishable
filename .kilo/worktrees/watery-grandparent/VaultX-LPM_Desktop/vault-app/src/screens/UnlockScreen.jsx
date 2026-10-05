import { useState, useRef, useEffect } from 'react'

const ShieldIcon = () => (
  <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
    <path d="M24 4L8 10V22C8 31.4 15.1 40.2 24 42C32.9 40.2 40 31.4 40 22V10L24 4Z" fill="var(--accent-bg)" stroke="var(--accent)" strokeWidth="1.5"/>
    <path d="M18 24L22 28L30 20" stroke="var(--accent)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
)

export default function UnlockScreen({ isSetup, onUnlocked }) {
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [showPass, setShowPass] = useState(false)
  const inputRef = useRef(null)
  const formRef = useRef(null)

  useEffect(() => {
    setTimeout(() => inputRef.current?.focus(), 100)
  }, [])

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')

    if (isSetup) {
      if (password.length < 8) { setError('Password must be at least 8 characters'); shake(); return }
      if (password !== confirm) { setError('Passwords do not match'); shake(); return }
      setLoading(true)
      const res = await window.vault.create(password)
      if (res.ok) onUnlocked()
      else { setError(res.error || 'Failed to create vault'); setLoading(false); shake() }
    } else {
      if (!password) return
      setLoading(true)
      const res = await window.vault.unlock(password)
      if (res.ok) onUnlocked()
      else { setError(res.error || 'Wrong password'); setLoading(false); shake(); setPassword('') }
    }
  }

  function shake() {
    formRef.current?.classList.add('shake')
    setTimeout(() => formRef.current?.classList.remove('shake'), 500)
  }

  return (
    <div style={styles.root}>
      <div className="titlebar" />
      <div style={styles.center}>
        <div ref={formRef} style={styles.card} className="animate-pop-in" onAnimationEnd={e => e.target.classList.remove('animate-pop-in')}>
          <div style={styles.logo}><ShieldIcon /></div>
          <h1 style={styles.title}>Vault</h1>
          <p style={styles.subtitle}>
            {isSetup ? 'Create a master password to protect your vault.' : 'Enter your master password to unlock.'}
          </p>

          <form onSubmit={handleSubmit} style={styles.form}>
            <div style={styles.fieldWrap}>
              <input
                ref={inputRef}
                type={showPass ? 'text' : 'password'}
                placeholder="Master password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                style={styles.input}
                autoComplete={isSetup ? 'new-password' : 'current-password'}
                disabled={loading}
              />
              <button type="button" onClick={() => setShowPass(v => !v)} style={styles.eyeBtn} tabIndex={-1}>
                {showPass ? <EyeOffIcon /> : <EyeIcon />}
              </button>
            </div>

            {isSetup && (
              <input
                type={showPass ? 'text' : 'password'}
                placeholder="Confirm password"
                value={confirm}
                onChange={e => setConfirm(e.target.value)}
                style={styles.input}
                autoComplete="new-password"
                disabled={loading}
              />
            )}

            {error && <p style={styles.error}>{error}</p>}

            <button type="submit" disabled={loading || !password} style={{ ...styles.btn, opacity: (!password || loading) ? 0.6 : 1 }}>
              {loading
                ? <span style={styles.spinner} />
                : isSetup ? 'Create vault' : 'Unlock'
              }
            </button>
          </form>

          {isSetup && (
            <p style={styles.hint}>
              This password cannot be recovered. Store it somewhere safe.
            </p>
          )}
        </div>
      </div>

      <style>{`
        @keyframes spin { to { transform: rotate(360deg); } }
        .shake { animation: shake 0.4s ease; }
      `}</style>
    </div>
  )
}

const styles = {
  root: {
    display: 'flex', flexDirection: 'column', height: '100%',
    background: 'var(--bg)',
  },
  center: {
    flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
    padding: '24px',
  },
  card: {
    background: 'var(--bg-card)', borderRadius: 'var(--radius-lg)',
    border: '1px solid var(--border)', boxShadow: 'var(--shadow-md)',
    padding: '40px 36px', width: '100%', maxWidth: 380,
    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
  },
  logo: { marginBottom: 4 },
  title: { fontSize: 26, fontWeight: 600, letterSpacing: '-0.5px', color: 'var(--text)' },
  subtitle: { fontSize: 13.5, color: 'var(--text-2)', textAlign: 'center', lineHeight: 1.6, marginBottom: 8 },
  form: { width: '100%', display: 'flex', flexDirection: 'column', gap: 10, marginTop: 8 },
  fieldWrap: { position: 'relative' },
  input: {
    width: '100%', padding: '10px 14px', fontSize: 14,
    background: 'var(--bg-input)', border: '1.5px solid var(--border)',
    borderRadius: 'var(--radius)', color: 'var(--text)',
    transition: 'border-color 0.15s',
  },
  eyeBtn: {
    position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
    background: 'none', color: 'var(--text-3)', padding: 4, display: 'flex', alignItems: 'center',
  },
  btn: {
    marginTop: 4, padding: '11px 0', fontSize: 14, fontWeight: 500,
    background: 'var(--accent)', color: '#fff', borderRadius: 'var(--radius)',
    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    transition: 'opacity 0.15s, transform 0.1s',
    cursor: 'pointer',
  },
  spinner: {
    width: 16, height: 16, border: '2px solid rgba(255,255,255,0.3)',
    borderTopColor: '#fff', borderRadius: '50%',
    animation: 'spin 0.7s linear infinite', display: 'inline-block',
  },
  error: { fontSize: 13, color: 'var(--danger)', textAlign: 'center' },
  hint: { fontSize: 12, color: 'var(--text-3)', textAlign: 'center', marginTop: 8, lineHeight: 1.6 },
}

const EyeIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>
  </svg>
)
const EyeOffIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <path d="M17.94 17.94A10.07 10.07 0 0112 20c-7 0-11-8-11-8a18.45 18.45 0 015.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0112 4c7 0 11 8 11 8a18.5 18.5 0 01-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/>
  </svg>
)
