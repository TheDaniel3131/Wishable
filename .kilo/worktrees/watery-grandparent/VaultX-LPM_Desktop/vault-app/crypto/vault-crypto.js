/**
 * vault-crypto.js
 *
 * Pure-JS crypto — no native modules, works on any Node version / OS.
 *
 * Key derivation : Argon2id via @noble/hashes (pure JS)
 * Encryption     : AES-256-GCM via Node built-in crypto
 * Password gen   : crypto.randomBytes (CSPRNG)
 */

const crypto = require('crypto')
const { argon2id } = require('@noble/hashes/argon2')

const SALT_LENGTH = 32
const IV_LENGTH   = 12   // 96-bit IV for GCM
const TAG_LENGTH  = 16   // 128-bit auth tag
const KEY_LENGTH  = 32   // 256-bit key

const ARGON2_PARAMS = {
  t: 3,          // time cost
  m: 65536,      // memory cost (64 MB)
  p: 4,          // parallelism
  dkLen: KEY_LENGTH,
}

/**
 * Derive a 256-bit key from a master password using Argon2id.
 */
async function deriveKey(password, salt) {
  const saltBuf = Buffer.isBuffer(salt) ? salt : Buffer.from(salt)
  const passBuf = Buffer.from(password, 'utf8')

  const key = await new Promise((resolve, reject) => {
    setImmediate(() => {
      try {
        const hash = argon2id(passBuf, saltBuf, ARGON2_PARAMS)
        resolve(Buffer.from(hash))
      } catch (err) {
        reject(err)
      }
    })
  })
  return key
}

/**
 * Generate a cryptographically random salt.
 */
function generateSalt() {
  return crypto.randomBytes(SALT_LENGTH)
}

/**
 * Encrypt a plaintext string with AES-256-GCM.
 * Returns a Buffer: [iv (12)] [authTag (16)] [ciphertext].
 */
function encrypt(key, plaintext) {
  const iv     = crypto.randomBytes(IV_LENGTH)
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv)
  const enc    = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  const tag    = cipher.getAuthTag()
  return Buffer.concat([iv, tag, enc])
}

/**
 * Decrypt a Buffer produced by encrypt().
 * Throws if the authentication tag doesn't match.
 */
function decrypt(key, data) {
  const buf      = Buffer.isBuffer(data) ? data : Buffer.from(data)
  const iv       = buf.slice(0, IV_LENGTH)
  const tag      = buf.slice(IV_LENGTH, IV_LENGTH + TAG_LENGTH)
  const ctxt     = buf.slice(IV_LENGTH + TAG_LENGTH)
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv)
  decipher.setAuthTag(tag)
  return decipher.update(ctxt).toString('utf8') + decipher.final('utf8')
}

/**
 * Encrypt a JS object → hex string (for SQLite TEXT column).
 */
function encryptObject(key, obj) {
  return encrypt(key, JSON.stringify(obj)).toString('hex')
}

/**
 * Decrypt a hex string → JS object.
 */
function decryptObject(key, hex) {
  return JSON.parse(decrypt(key, Buffer.from(hex, 'hex')))
}

/**
 * Generate a random password using CSPRNG with rejection sampling.
 */
function generatePassword(length = 20, opts = {}) {
  const { uppercase = true, lowercase = true, numbers = true, symbols = true } = opts

  let charset = ''
  if (lowercase) charset += 'abcdefghijkmnopqrstuvwxyz'
  if (uppercase) charset += 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  if (numbers)   charset += '23456789'
  if (symbols)   charset += '!@#$%^&*-_=+?'
  if (!charset)  charset  = 'abcdefghijkmnopqrstuvwxyz'

  const max    = 256 - (256 % charset.length)
  let password = ''
  while (password.length < length) {
    const bytes = crypto.randomBytes(length * 2)
    for (let i = 0; i < bytes.length && password.length < length; i++) {
      if (bytes[i] < max) password += charset[bytes[i] % charset.length]
    }
  }
  return password
}

/**
 * Zero-fill a Buffer before releasing it.
 */
function zeroBuffer(buf) {
  if (buf && Buffer.isBuffer(buf)) buf.fill(0)
}

module.exports = {
  deriveKey,
  generateSalt,
  encrypt,
  decrypt,
  encryptObject,
  decryptObject,
  generatePassword,
  zeroBuffer,
}
