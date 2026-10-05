/**
 * electron/ipc/vault.js
 *
 * IPC handlers for vault operations.
 * Uses sql.js (WebAssembly SQLite) — no native modules needed.
 */

const { ipcMain } = require('electron')
const { deriveKey, generateSalt, encryptObject, decryptObject, zeroBuffer } = require('../../crypto/vault-crypto')
const { getDb, flush } = require('../../db/schema')

let sessionKey  = null
let lockTimer   = null
const LOCK_TIMEOUT_MS = 5 * 60 * 1000

function clearSession() {
  zeroBuffer(sessionKey)
  sessionKey = null
  if (lockTimer) { clearTimeout(lockTimer); lockTimer = null }
}

function resetLockTimer(win) {
  if (lockTimer) clearTimeout(lockTimer)
  lockTimer = setTimeout(() => {
    clearSession()
    win.webContents.send('vault:locked')
  }, LOCK_TIMEOUT_MS)
}

function requireSession() {
  if (!sessionKey) throw new Error('Vault is locked')
  return sessionKey
}

function queryOne(sql, params = {}) {
  const db   = getDb()
  const stmt = db.prepare(sql)
  stmt.bind(params)
  if (stmt.step()) {
    const row = stmt.getAsObject()
    stmt.free()
    return row
  }
  stmt.free()
  return null
}

function queryAll(sql, params = {}) {
  const db      = getDb()
  const stmt    = db.prepare(sql)
  const results = []
  stmt.bind(params)
  while (stmt.step()) results.push(stmt.getAsObject())
  stmt.free()
  return results
}

function exec(sql, params = {}) {
  getDb().run(sql, params)
  flush()
}

function registerVaultHandlers(win) {
  ipcMain.handle('vault:status', () => {
    const meta = queryOne('SELECT id FROM vault_meta WHERE id = 1')
    return { initialised: !!meta, unlocked: !!sessionKey }
  })

  ipcMain.handle('vault:create', async (_e, password) => {
    const salt      = generateSalt()
    const key       = await deriveKey(password, salt)
    const checkBlob = encryptObject(key, { check: 'vault-ok' })

    exec(
      `INSERT INTO vault_meta (id, salt, check_blob) VALUES (1, $salt, $check)
       ON CONFLICT(id) DO UPDATE SET salt = $salt, check_blob = $check`,
      { $salt: salt.toString('hex'), $check: checkBlob }
    )

    sessionKey = key
    resetLockTimer(win)
    return { ok: true }
  })

  ipcMain.handle('vault:unlock', async (_e, password) => {
    const meta = queryOne('SELECT salt, check_blob FROM vault_meta WHERE id = 1')
    if (!meta) return { ok: false, error: 'Vault not initialised' }

    try {
      const saltBuf = Buffer.from(meta.salt, 'hex')
      const key     = await deriveKey(password, saltBuf)
      const check   = decryptObject(key, meta.check_blob)
      if (check.check !== 'vault-ok') throw new Error('Bad check')

      sessionKey = key
      resetLockTimer(win)
      return { ok: true }
    } catch {
      return { ok: false, error: 'Wrong master password' }
    }
  })

  ipcMain.handle('vault:lock', () => {
    clearSession()
    return { ok: true }
  })

  ipcMain.handle('vault:list', () => {
    const key  = requireSession()
    resetLockTimer(win)
    const rows = queryAll('SELECT id, data_enc, created_at, updated_at FROM credentials ORDER BY updated_at DESC')
    return rows.map(row => ({
      id: row.id,
      ...decryptObject(key, row.data_enc),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }))
  })

  ipcMain.handle('vault:save', (_e, credential) => {
    const key = requireSession()
    resetLockTimer(win)

    const id  = credential.id || require('crypto').randomUUID()
    const now = Date.now()
    const { id: _id, createdAt, updatedAt, ...data } = credential
    const dataEnc = encryptObject(key, data)

    const existing = queryOne('SELECT id FROM credentials WHERE id = $id', { $id: id })
    if (existing) {
      exec(
        'UPDATE credentials SET data_enc = $enc, updated_at = $now WHERE id = $id',
        { $enc: dataEnc, $now: now, $id: id }
      )
    } else {
      exec(
        'INSERT INTO credentials (id, data_enc, created_at, updated_at) VALUES ($id, $enc, $now, $now)',
        { $id: id, $enc: dataEnc, $now: now }
      )
    }

    return { ok: true, id }
  })

  ipcMain.handle('vault:delete', (_e, id) => {
    requireSession()
    resetLockTimer(win)
    exec('DELETE FROM credentials WHERE id = $id', { $id: id })
    return { ok: true }
  })
}

module.exports = { registerVaultHandlers, clearSession }
