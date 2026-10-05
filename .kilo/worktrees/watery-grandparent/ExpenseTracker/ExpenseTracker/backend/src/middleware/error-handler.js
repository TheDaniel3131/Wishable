const logger = require('./logger');

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  logger.error(err);

  // Axios errors (Claude API, etc.)
  if (err.isAxiosError) {
    const status  = err.response?.status || 502;
    const message = err.response?.data?.error?.message || 'External service error';
    return res.status(status).json({ error: message });
  }

  // JSON parse errors (malformed request body)
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Invalid JSON in request body' });
  }

  // Postgres errors
  if (err.code) {
    if (err.code === '23505') { // unique_violation
      return res.status(409).json({ error: 'Resource already exists', detail: err.detail });
    }
    if (err.code === '23503') { // foreign_key_violation
      return res.status(400).json({ error: 'Referenced resource not found' });
    }
    if (err.code === '22P02') { // invalid_text_representation (bad UUID etc.)
      return res.status(400).json({ error: 'Invalid ID format' });
    }
  }

  // Multer errors
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: 'File too large. Maximum 15MB.' });
  }

  // Default
  const statusCode = err.statusCode || err.status || 500;
  res.status(statusCode).json({
    error: statusCode === 500 ? 'Internal server error' : err.message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

module.exports = errorHandler;
