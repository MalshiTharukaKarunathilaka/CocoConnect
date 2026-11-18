class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function errorHandler(err, req, res, next) {
  if (err.name === 'ZodError') {
    const msg = err.issues?.[0]?.message || 'Validation failed';
    return res.status(400).json({ error: msg });
  }
  if (err instanceof ApiError) {
    return res.status(err.status).json({ error: err.message, time: new Date().toISOString() });
  }
  console.error(err);
  return res.status(500).json({ error: err.message || 'Server error' });
}

module.exports = { ApiError, asyncHandler, errorHandler };
