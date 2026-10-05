const router = require('express').Router();
const { body, validationResult } = require('express-validator');
const { authenticate } = require('../middleware/auth');
const { query }        = require('../db/pool');
const dayjs            = require('dayjs');

router.use(authenticate);

// ── GET /api/budgets ──────────────────────────────────────────────────────────
router.get('/', async (req, res) => {
  const uid = req.user.id;

  // Get budgets and join with current-period spending
  const now        = dayjs();
  const monthStart = now.startOf('month').format('YYYY-MM-DD');
  const monthEnd   = now.endOf('month').format('YYYY-MM-DD');
  const weekStart  = now.startOf('week').format('YYYY-MM-DD');
  const weekEnd    = now.endOf('week').format('YYYY-MM-DD');

  const result = await query(
    `SELECT
       b.*,
       COALESCE(SUM(
         CASE
           WHEN b.period='monthly' AND t.date BETWEEN $2 AND $3 THEN t.amount
           WHEN b.period='weekly'  AND t.date BETWEEN $4 AND $5 THEN t.amount
           ELSE 0
         END
       ), 0) AS spent
     FROM budgets b
     LEFT JOIN transactions t
       ON t.user_id = b.user_id
       AND t.category = b.category
       AND t.type = 'expense'
     WHERE b.user_id = $1
     GROUP BY b.id
     ORDER BY b.created_at ASC`,
    [uid, monthStart, monthEnd, weekStart, weekEnd]
  );

  res.json({ data: result.rows.map(toClient) });
});

// ── POST /api/budgets ─────────────────────────────────────────────────────────
router.post('/', [
  body('category').isString().notEmpty(),
  body('limitAmount').isFloat({ gt: 0 }),
  body('period').optional().isIn(['weekly','monthly','yearly']),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { category, limitAmount, period = 'monthly' } = req.body;

  // Upsert — update if category+period already exists for user
  const result = await query(
    `INSERT INTO budgets (user_id, category, limit_amount, period)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, category, period)
     DO UPDATE SET limit_amount = EXCLUDED.limit_amount, updated_at = NOW()
     RETURNING *`,
    [req.user.id, category, limitAmount, period]
  );
  res.status(201).json({ data: toClient(result.rows[0]) });
});

// ── PUT /api/budgets/:id ──────────────────────────────────────────────────────
router.put('/:id', [
  body('limitAmount').optional().isFloat({ gt: 0 }),
  body('period').optional().isIn(['weekly','monthly','yearly']),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { limitAmount, period } = req.body;

  const fields = [], values = [];
  let idx = 1;
  if (limitAmount !== undefined) { fields.push(`limit_amount = $${idx++}`); values.push(limitAmount); }
  if (period !== undefined)      { fields.push(`period = $${idx++}`);       values.push(period); }
  if (!fields.length) return res.status(400).json({ error: 'No fields to update' });

  values.push(req.params.id, req.user.id);
  const result = await query(
    `UPDATE budgets SET ${fields.join(', ')} WHERE id = $${idx} AND user_id = $${idx+1} RETURNING *`,
    values
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Budget not found' });
  res.json({ data: toClient(result.rows[0]) });
});

// ── DELETE /api/budgets/:id ───────────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  const result = await query(
    'DELETE FROM budgets WHERE id = $1 AND user_id = $2 RETURNING id',
    [req.params.id, req.user.id]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Budget not found' });
  res.json({ message: 'Budget deleted' });
});

// ── Helper ────────────────────────────────────────────────────────────────────
const toClient = (row) => ({
  id:          row.id,
  category:    row.category,
  limitAmount: parseFloat(row.limit_amount),
  period:      row.period,
  spent:       parseFloat(row.spent || 0),
  createdAt:   row.created_at,
  updatedAt:   row.updated_at,
});

module.exports = router;
