require('dotenv').config();
const { pool } = require('./pool');

const migrations = [
  // ── Users ──────────────────────────────────────────────────────────────────
  `CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`,

  `CREATE TABLE IF NOT EXISTS users (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(255) UNIQUE NOT NULL,
    password     VARCHAR(255) NOT NULL,
    currency     VARCHAR(10)  DEFAULT 'MYR',
    avatar_url   TEXT,
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
  )`,

  // ── Transactions ───────────────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS transactions (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type         VARCHAR(10) NOT NULL CHECK (type IN ('income','expense')),
    amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    description  VARCHAR(255) NOT NULL,
    category     VARCHAR(50)  NOT NULL,
    date         DATE         NOT NULL,
    receipt_url  TEXT,
    qr_data      TEXT,
    notes        TEXT,
    is_scanned   BOOLEAN      DEFAULT FALSE,
    created_at   TIMESTAMPTZ  DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  DEFAULT NOW()
  )`,

  `CREATE INDEX IF NOT EXISTS idx_transactions_user_id   ON transactions(user_id)`,
  `CREATE INDEX IF NOT EXISTS idx_transactions_date       ON transactions(date DESC)`,
  `CREATE INDEX IF NOT EXISTS idx_transactions_category   ON transactions(category)`,
  `CREATE INDEX IF NOT EXISTS idx_transactions_type       ON transactions(type)`,

  // ── Budgets ────────────────────────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS budgets (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category      VARCHAR(50)   NOT NULL,
    limit_amount  NUMERIC(12,2) NOT NULL CHECK (limit_amount > 0),
    period        VARCHAR(20)   DEFAULT 'monthly' CHECK (period IN ('weekly','monthly','yearly')),
    created_at    TIMESTAMPTZ   DEFAULT NOW(),
    updated_at    TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE(user_id, category, period)
  )`,

  `CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON budgets(user_id)`,

  // ── Receipt scans (audit log) ──────────────────────────────────────────────
  `CREATE TABLE IF NOT EXISTS receipt_scans (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    image_path     TEXT,
    raw_response   JSONB,
    total_extracted NUMERIC(12,2),
    created_at     TIMESTAMPTZ DEFAULT NOW()
  )`,

  // ── Updated_at trigger function ────────────────────────────────────────────
  `CREATE OR REPLACE FUNCTION update_updated_at_column()
   RETURNS TRIGGER AS $$
   BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
   $$ language 'plpgsql'`,

  `DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_users_updated_at') THEN
      CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END $$`,

  `DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_transactions_updated_at') THEN
      CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END $$`,

  `DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_budgets_updated_at') THEN
      CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END $$`,
];

async function migrate() {
  const client = await pool.connect();
  try {
    console.log('Running migrations...');
    for (const sql of migrations) {
      await client.query(sql);
      console.log(`✓ ${sql.substring(0, 60).replace(/\n/g, ' ')}...`);
    }
    console.log('✅ All migrations complete.');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();
