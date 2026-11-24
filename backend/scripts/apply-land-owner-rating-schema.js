// Applies only the two additive tables used by combined land-owner ratings.
const fs = require('node:fs');
const path = require('node:path');
const pool = require('../config/db');
(async () => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (const file of ['015_machinery_land_owner_feedback.sql','016_fertilizer_orders_and_feedback.sql']) {
      await client.query(fs.readFileSync(path.join(__dirname,'../sql',file),'utf8'));
      console.log('Applied '+file);
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); await pool.end(); }
})().catch(error => { console.error(error.message); process.exitCode=1; });
