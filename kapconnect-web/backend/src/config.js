require('dotenv').config();
const path = require('path');
const fs = require('fs');

// Ensure SQLite data folder exists
const dataDir = path.join(__dirname, '..', 'data');
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

module.exports = {
  port: Number(process.env.PORT || 8080),
  databaseUrl: process.env.DATABASE_URL || 'file:../data/kapconnect.db',
  jwtSecret: process.env.JWT_SECRET || 'kapconnect-dev-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  otpDemoCode: process.env.OTP_DEMO_CODE || '123456',
  otpExpireMinutes: Number(process.env.OTP_EXPIRE_MINUTES || 10),
  firebaseEnabled: String(process.env.FIREBASE_ENABLED || 'false') === 'true',
};
