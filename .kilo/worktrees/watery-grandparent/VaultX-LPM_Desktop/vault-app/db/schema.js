/**
 * db/schema.js
 *
 * Uses sql.js — SQLite compiled to WebAssembly.
 * No native module compilation required. Works on Node 18/20/22/24, any OS.
 *
 * The database is loaded into memory on startup and flushed to disk after
 * every mutating operation.
 */

const fs   = require('fs')
const path = require('path')

let db     = null
let dbPath = null
let SQL    = null

async function initDb(app) {
  if (db) return db

  const initSqlJs = require('sql.js')
  const wasmPath  = path.join(
    path.dirname(require.resolve('sql.js')),
    'sql-wasm.wasm'
  )

  SQL = await initSqlJs({ locateFile: () => wasmPath })

  const dir = app.getPath('userData')
  fs.mkdirSync(dir, { recursive: true })
  dbPath = path.join(dir, 'vault.db')

  if (fs.existsSync(dbPath)) {
    const fileBuffer = fs.readFileSync(dbPath)
    db = new SQL.Database(fileBuffer)
  } else {
    db = new SQL.Database()
  }

  db.run('PRAGMA foreign_keys = ON;')

  db.run(`
    CREATE TABLE IF NOT EXISTS vault_meta (
      id         INTEGER PRIMARY KEY CHECK (id = 1),
      salt       TEXT    NOT NULL,
      check_blob TEXT    NOT NULL
    );

    CREATE TABLE IF NOT EXISTS credentials (
      id         TEXT    PRIMARY KEY,
      data_enc   TEXT    NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );
  `)

  flush()
  return db
}

/**
 * Write the in-memory database back to disk after mutations.
 */
function flush() {
  if (!db || !dbPath) return
  const data = db.export()
  fs.writeFileSync(dbPath, Buffer.from(data))
}

function getDb() {
  if (!db) throw new Error('DB not initialised — call initDb() first')
  return db
}

function closeDb() {
  if (db) {
    flush()
    db.close()
    db = null; SQL = null
  }
}

module.exports = { initDb, getDb, flush, closeDb }
