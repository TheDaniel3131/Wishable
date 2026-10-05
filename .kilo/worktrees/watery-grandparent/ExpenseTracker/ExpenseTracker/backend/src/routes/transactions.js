const router = require('express').Router();
const { body, query: qv, validationResult } = require('express-validator');
const { authenticate } = require('../middleware/auth');
const { query }        = require('../db/pool');

router.use(authenticate);

// ── GET /api/transactions ─────────────────────────────────────────────────────
router.get('/', [
  qv('type').optional().isIn(['income','expense']),
  qv('category').optional().isString(),
  qv('startDate').optional().isISO8601(),
  qv('endDate').optional().isISO8601(),
  qv('page').optional().isInt({ min: 1 }),
  qv('limit').optional().isInt({ min: 1, max: 200 }),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { type, category, startDate, endDate } = req.query;
  const page  = parseInt(req.query.page  || '1');
  const limit = parseInt(req.query.limit || '50');
  const offset = (page - 1) * limit;

  const conditions = ['t.user_id = $1'];
  const params     = [req.user.id];
  let   p          = 2;

  if (type)      { conditions.push(`t.type = $${p++}`);                      params.push(type); }
  if (category)  { conditions.push(`t.category = $${p++}`);                  params.push(category); }
  if (startDate) { conditions.push(`t.date >= $${p++}`);                     params.push(startDate); }
  if (endDate)   { conditions.push(`t.date <= $${p++}`);                     params.push(endDate); }

  const where = conditions.join(' AND ');

  const [dataRes, countRes] = await Promise.all([
    query(
      `SELECT * FROM transactions t WHERE ${where}
       ORDER BY t.date DESC, t.created_at DESC
       LIMIT $${p} OFFSET $${p+1}`,
      [...params, limit, offset]
    ),
    query(`SELECT COUNT(*) FROM transactions t WHERE ${where}`, params),
  ]);

  res.json({
    data:  dataRes.rows.map(toClient),
    meta:  {
      total: parseInt(countRes.rows[0].count),
      page, limit,
      pages: Math.ceil(parseInt(countRes.rows[0].count) / limit),
    },
  });
});

// ── GET /api/transactions/:id ─────────────────────────────────────────────────
router.get('/:id', async (req, res) => {
  const result = await query(
    'SELECT * FROM transactions WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.id]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Transaction not found' });
  res.json({ data: toClient(result.rows[0]) });
});

// ── POST /api/transactions ────────────────────────────────────────────────────
router.post('/', [
  body('type').isIn(['income','expense']),
  body('amount').isFloat({ gt: 0 }),
  body('description').trim().isLength({ min: 1, max: 255 }),
  body('category').isString().notEmpty(),
  body('date').isISO8601(),
  body('notes').optional().isString(),
  body('isScanned').optional().isBoolean(),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  const { type, amount, description, category, date, notes, isScanned, receiptUrl, qrData } = req.body;

  const result = await query(
    `INSERT INTO transactions
      (user_id, type, amount, description, category, date, notes, is_scanned, receipt_url, qr_data)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [req.user.id, type, amount, description, category, date, notes || null, isScanned || false, receiptUrl || null, qrData || null]
  );
  res.status(201).json({ data: toClient(result.rows[0]) });
});

// ── PUT /api/transactions/:id ─────────────────────────────────────────────────
router.put('/:id', [
  body('type').optional().isIn(['income','expense']),
  body('amount').optional().isFloat({ gt: 0 }),
  body('description').optional().trim().isLength({ min: 1, max: 255 }),
  body('category').optional().isString(),
  body('date').optional().isISO8601(),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

  // Check ownership
  const existing = await query(
    'SELECT id FROM transactions WHERE id = $1 AND user_id = $2',
    [req.params.id, req.user.id]
  );
  if (!existing.rows.length) return res.status(404).json({ error: 'Transaction not found' });

  const fields  = [];
  const values  = [];
  let   idx     = 1;
  const allowed = ['type','amount','description','category','date','notes'];

  for (const field of allowed) {
    if (req.body[field] !== undefined) {
      fields.push(`${toSnake(field)} = $${idx++}`);
      values.push(req.body[field]);
    }
  }
  if (!fields.length) return res.status(400).json({ error: 'No fields to update' });

  values.push(req.params.id);
  const result = await query(
    `UPDATE transactions SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
    values
  );
  res.json({ data: toClient(result.rows[0]) });
});

// ── DELETE /api/transactions/:id ──────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  const result = await query(
    'DELETE FROM transactions WHERE id = $1 AND user_id = $2 RETURNING id',
    [req.params.id, req.user.id]
  );
  if (!result.rows.length) return res.status(404).json({ error: 'Transaction not found' });
  res.json({ message: 'Transaction deleted', id: result.rows[0].id });
});

// ── Helpers ───────────────────────────────────────────────────────────────────
const toClient = (row) => ({
  id:          row.id,
  type:        row.type,
  amount:      parseFloat(row.amount),
  description: row.description,
  category:    row.category,
  date:        row.date,
  receiptUrl:  row.receipt_url,
  qrData:      row.qr_data,
  notes:       row.notes,
  isScanned:   row.is_scanned,
  createdAt:   row.created_at,
  updatedAt:   row.updated_at,
});

const toSnake = (s) => s.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);

module.exports = router;
