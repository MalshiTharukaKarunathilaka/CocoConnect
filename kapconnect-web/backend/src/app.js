const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./errors');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const marketRoutes = require('./routes/marketplace');
const orderRoutes = require('./routes/orders');
const adminRoutes = require('./routes/admin');
const notificationRoutes = require('./routes/notifications');

const app = express();

app.use(cors({ origin: true, credentials: true }));
app.use(express.json());

app.get('/api/v1/health', (_req, res) => {
  res.json({ ok: true, service: 'KapConnect API', stack: 'Node.js + Express' });
});

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1', marketRoutes);
app.use('/api/v1/orders', orderRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/notifications', notificationRoutes);

app.use(errorHandler);

module.exports = { app };
