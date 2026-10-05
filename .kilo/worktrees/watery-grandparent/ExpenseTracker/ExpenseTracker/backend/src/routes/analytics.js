const router = require('express').Router();
const dayjs  = require('dayjs');
const { authenticate } = require('../middleware/auth');
const { query }        = require('../db/pool');

router.use(authenticate);

// ── GET /api/analytics?period=week|month|year ─────────────────────────────────
router.get('/', async (req, res) => {
  const period = req.query.period || 'month';

  let startDate;
  const now = dayjs();
  if (period === 'week')  startDate = now.subtract(7,  'day').format('YYYY-MM-DD');
  if (period === 'month') startDate = now.subtract(30, 'day').format('YYYY-MM-DD');
  if (period === 'year')  startDate = now.subtract(1,  'year').format('YYYY-MM-DD');
  if (!startDate) return res.status(400).json({ error: 'Invalid period. Use week|month|year' });

  const endDate = now.format('YYYY-MM-DD');
  const uid     = req.user.id;

  // Run all queries in parallel
  const [totalsRes, byCategoryRes, dailyRes] = await Promise.all([
    // Overall income vs expense
    query(
      `SELECT
         SUM(CASE WHEN type='income'  THEN amount ELSE 0 END) AS total_income,
         SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS total_expenses
       FROM transactions
       WHERE user_id=$1 AND date BETWEEN $2 AND $3`,
      [uid, startDate, endDate]
    ),

    // By category (expenses only)
    query(
      `SELECT category, SUM(amount) AS total
       FROM transactions
       WHERE user_id=$1 AND type='expense' AND date BETWEEN $2 AND $3
       GROUP BY category
       ORDER BY total DESC`,
      [uid, startDate, endDate]
    ),

    // Daily totals
    query(
      `SELECT
         date::TEXT,
         SUM(CASE WHEN type='income'  THEN amount ELSE 0 END) AS income,
         SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS expense
       FROM transactions
       WHERE user_id=$1 AND date BETWEEN $2 AND $3
       GROUP BY date
       ORDER BY date ASC`,
      [uid, startDate, endDate]
    ),
  ]);

  const totals       = totalsRes.rows[0];
  const totalIncome  = parseFloat(totals.total_income  || 0);
  const totalExpenses= parseFloat(totals.total_expenses|| 0);

  const byCategory = {};
  byCategoryRes.rows.forEach((r) => {
    byCategory[r.category] = parseFloat(r.total);
  });

  const dailyTotals = dailyRes.rows.map((r) => ({
    date:    r.date,
    income:  parseFloat(r.income),
    expense: parseFloat(r.expense),
  }));

  res.json({
    data: {
      totalIncome,
      totalExpenses,
      balance: totalIncome - totalExpenses,
      byCategory,
      dailyTotals,
    },
  });
});

// ── GET /api/analytics/summary ────────────────────────────────────────────────
// All-time summary for dashboard hero
router.get('/summary', async (req, res) => {
  const uid = req.user.id;
  const result = await query(
    `SELECT
       SUM(CASE WHEN type='income'  THEN amount ELSE 0 END) AS total_income,
       SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS total_expenses,
       COUNT(*) AS transaction_count
     FROM transactions WHERE user_id=$1`,
    [uid]
  );
  const row = result.rows[0];
  const income   = parseFloat(row.total_income   || 0);
  const expenses = parseFloat(row.total_expenses || 0);
  res.json({
    data: {
      totalIncome:       income,
      totalExpenses:     expenses,
      balance:           income - expenses,
      transactionCount:  parseInt(row.transaction_count),
    },
  });
});

module.exports = router;
