require('dotenv').config();
require('express-async-errors');

const express     = require('express');
const cors        = require('cors');
const helmet      = require('helmet');
const morgan      = require('morgan');
const compression = require('compression');
const rateLimit   = require('express-rate-limit');

const { testConnection } = require('./db/pool');
const logger             = require('./middleware/logger');
const errorHandler       = require('./middleware/error-handler');

// Routes
const authRoutes         = require('./routes/auth');
const transactionRoutes  = require('./routes/transactions');
const analyticsRoutes    = require('./routes/analytics');
const budgetRoutes       = require('./routes/budgets');
const scanRoutes         = require('./routes/scan');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Security & middleware ─────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:*'],
  credentials: true,
}));
app.use(compression());
app.use(morgan('combined', { stream: { write: (msg) => logger.info(msg.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later.' },
}));

// Stricter limit for auth routes
app.use('/api/auth', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { error: 'Too many auth attempts.' },
}));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', async (req, res) => {
  const db = await testConnection();
  res.json({ status: 'ok', db, timestamp: new Date().toISOString() });
});

// ── API Routes ────────────────────────────────────────────────────────────────
app.use('/api/auth',         authRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/analytics',    analyticsRoutes);
app.use('/api/budgets',      budgetRoutes);
app.use('/api/scan',         scanRoutes);

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Error handler ─────────────────────────────────────────────────────────────
app.use(errorHandler);

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, async () => {
  await testConnection();
  logger.info(`MoneyTracker API running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
