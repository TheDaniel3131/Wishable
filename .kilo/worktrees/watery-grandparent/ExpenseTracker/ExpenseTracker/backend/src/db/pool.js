const { Pool } = require('pg');
const logger   = require('../middleware/logger');

const pool = new Pool({
  host:               process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT)     || 5432,
  database:           process.env.DB_NAME     || 'moneytracker',
  user:               process.env.DB_USER     || 'postgres',
  password:           process.env.DB_PASSWORD || 'postgres',
  max:      parseInt(process.env.DB_POOL_MAX) || 20,
  idleTimeoutMillis:  30000,
  connectionTimeoutMillis: 5000,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

pool.on('error', (err) => {
  logger.error('Unexpected PostgreSQL error:', err);
});

// ── Helpers ────────────────────────────────────────────────────────────────────
const query = (text, params) => pool.query(text, params);

const getClient = () => pool.connect();

const withTransaction = async (fn) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

const testConnection = async () => {
  try {
    const res = await pool.query('SELECT NOW()');
    logger.info(`Database connected: ${res.rows[0].now}`);
    return true;
  } catch (err) {
    logger.error('Database connection failed:', err.message);
    return false;
  }
};

module.exports = { pool, query, getClient, withTransaction, testConnection };
