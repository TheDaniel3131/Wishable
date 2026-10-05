const router  = require('express').Router();
const multer  = require('multer');
const sharp   = require('sharp');
const axios   = require('axios');
const path    = require('path');
const fs      = require('fs');
const { authenticate } = require('../middleware/auth');
const { query }        = require('../db/pool');
const logger           = require('../middleware/logger');

router.use(authenticate);

// ── Multer config (memory storage — pass to sharp then Claude) ─────────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits:  { fileSize: 15 * 1024 * 1024 }, // 15MB
  fileFilter: (_, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    cb(null, allowed.includes(file.mimetype));
  },
});

// ── POST /api/scan/receipt ────────────────────────────────────────────────────
router.post('/receipt', upload.single('receipt'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No receipt image provided' });
  }

  // Resize & convert to JPEG for Claude
  const processedBuffer = await sharp(req.file.buffer)
    .resize({ width: 1500, height: 2000, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 90 })
    .toBuffer();

  const base64Image = processedBuffer.toString('base64');

  const prompt = `You are a receipt parser. Analyze this receipt image carefully.
Extract all line items and totals. Respond ONLY with a valid JSON object — no markdown, no explanation:
{
  "merchant": "store or restaurant name",
  "items": [
    { "name": "item name", "price": 0.00, "quantity": 1 }
  ],
  "subtotal": 0.00,
  "tax": 0.00,
  "discount": 0.00,
  "total": 0.00,
  "currency": "MYR"
}
If a field cannot be determined, use 0 for numbers or "" for strings.
Always return valid parseable JSON.`;

  const claudeRes = await axios.post(
    'https://api.anthropic.com/v1/messages',
    {
      model:      'claude-sonnet-4-20250514',
      max_tokens: 1500,
      messages: [{
        role: 'user',
        content: [
          {
            type:   'image',
            source: { type: 'base64', media_type: 'image/jpeg', data: base64Image },
          },
          { type: 'text', text: prompt },
        ],
      }],
    },
    {
      headers: {
        'x-api-key':         process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Type':      'application/json',
      },
      timeout: 30000,
    }
  );

  const rawText = claudeRes.data.content
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('');

  // Strip markdown fences if Claude included them
  const cleaned = rawText.replace(/```json|```/g, '').trim();
  const parsed  = JSON.parse(cleaned);

  // Ensure total is a number
  if (!parsed.total || parsed.total === 0) {
    parsed.total = parsed.subtotal + (parsed.tax || 0) - (parsed.discount || 0);
  }

  // Audit log in DB
  await query(
    `INSERT INTO receipt_scans (user_id, raw_response, total_extracted)
     VALUES ($1, $2, $3)`,
    [req.user.id, JSON.stringify(parsed), parsed.total]
  ).catch((err) => logger.warn('Receipt scan audit log failed:', err.message));

  res.json({ data: parsed });
});

// ── POST /api/scan/qr ─────────────────────────────────────────────────────────
router.post('/qr', async (req, res) => {
  const { raw } = req.body;
  if (!raw) return res.status(400).json({ error: 'No QR data provided' });

  let result = { amount: null, description: 'QR Payment', merchant: null, raw };

  // Try JSON parse first (DuitNow, GrabPay, etc.)
  try {
    const obj = JSON.parse(raw);
    result.amount      = parseFloat(obj.amount ?? obj.total ?? obj.billTotal ?? obj.amt ?? 0) || null;
    result.description = obj.merchant ?? obj.merchantName ?? obj.description ?? obj.name ?? 'QR Payment';
    result.merchant    = obj.merchant ?? obj.merchantName ?? null;
    result.category    = obj.category ?? null;
  } catch {
    // Not JSON — try regex patterns

    // Malaysian DuitNow format: contains amount after specific patterns
    const amtPatterns = [
      /amount[=:]\s*([\d]+\.?[\d]*)/i,
      /total[=:]\s*([\d]+\.?[\d]*)/i,
      /rm\s*([\d]+\.?[\d]*)/i,
      /([\d]+\.\d{2})/,          // any decimal number
    ];
    for (const pattern of amtPatterns) {
      const m = raw.match(pattern);
      if (m) { result.amount = parseFloat(m[1]); break; }
    }

    // Try to get a name
    const nameMatch = raw.match(/merchant[=:]([^&\n]+)/i) ||
                      raw.match(/name[=:]([^&\n]+)/i);
    if (nameMatch) result.description = nameMatch[1].trim();
  }

  res.json({ data: result });
});

module.exports = router;
