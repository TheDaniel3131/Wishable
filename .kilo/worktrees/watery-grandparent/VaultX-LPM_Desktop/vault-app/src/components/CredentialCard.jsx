import { useState } from 'react'

function getFavicon(url) {
  if (!url) return null
  try {
    const u = url.startsWith('http') ? url : 'https://' + url
    const host = new URL(u).hostname
    return `https://www.google.com/s2/favicons?domain=${host}&sz=32`
  } catch { return null }
}

function getInitials(title) {
  return (title || '?').slice(0, 2).toUpperCase()
}

function getColor(title) {
  const colors = ['#2E6AF6','#7C3AED','#0891B2','#059669','#D97706','#DC2626','#DB2777']
  let hash = 0
  for (const c of (title || '')) hash = (hash * 31 + c.charCodeAt(0)) & 0xffffffff
  return colors[Math.abs(hash) % colors.length]
}

export default function CredentialCard({ credential, active, onClick, style }) {
  const [imgError, setImgError] = useState(false)
  const favicon = !imgError && getFavicon(credential.url)
  const color = getColor(credential.title)

  return (
    <div
      onClick={onClick}
      className="animate-fade-in"
      style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '9px 8px', borderRadius: 'var(--radius)',
        cursor: 'pointer', marginBottom: 2,
        background: active ? 'var(--accent-bg)' : 'transparent',
        transition: 'background 0.12s',
        ...style,
      }}
      onMouseEnter={e => { if (!active) e.currentTarget.style.background = 'var(--bg-hover)' }}
      onMouseLeave={e => { if (!active) e.currentTarget.style.background = 'transparent' }}
    >
      {/* Avatar */}
      <div style={{
        width: 32, height: 32, borderRadius: 8, flexShrink: 0,
        background: favicon ? '#fff' : color,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        overflow: 'hidden', border: '1px solid rgba(0,0,0,0.06)',
      }}>
        {favicon
          ? <img src={favicon} width={16} height={16} onError={() => setImgError(true)} alt="" />
          : <span style={{ color:'#fff', fontSize:11, fontWeight:600 }}>{getInitials(credential.title)}</span>
        }
      </div>

      {/* Text */}
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{
          fontSize: 13.5, fontWeight: 500, color: active ? 'var(--accent-text)' : 'var(--text)',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>
          {credential.title || 'Untitled'}
        </div>
        <div style={{
          fontSize: 12, color: active ? 'var(--accent)' : 'var(--text-3)',
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
          marginTop: 1,
        }}>
          {credential.username || credential.url || '—'}
        </div>
      </div>
    </div>
  )
}
