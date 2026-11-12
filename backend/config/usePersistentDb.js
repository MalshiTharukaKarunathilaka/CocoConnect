// Explicit persistent mode. Never falls back to the disposable preview DB.
const path = require('node:path');
require('dotenv').config({path: path.join(__dirname, '../.env'), quiet: true});
if (!process.env.DATABASE_URL || !process.env.JWT_SECRET) {
  throw new Error('Configure DATABASE_URL and JWT_SECRET in backend/.env before starting the Supabase backend.');
}
process.env.DB_MODE = 'postgres';
