const pool = require('../config/db');

const storageInfo = () => ({
  mode: pool.databaseMode,
  persistent: pool.databaseMode !== 'memory',
});

const getHealth = async (_req, res) => {
  try {
    await pool.query('SELECT id FROM public.users LIMIT 0');
    await pool.query('SELECT user_id FROM public.service_providers LIMIT 0');
    let workflowReady = false;
    try {
      const tables = await pool.query(`SELECT table_name FROM information_schema.tables
        WHERE table_schema='public' AND table_name IN
        ('machinery','machinery_services','machinery_availability','machinery_bookings','machinery_booking_items','machinery_messages')`);
      workflowReady = tables.rows.length === 6;
      if (workflowReady && pool.databaseMode !== 'memory') {
        const constraint = await pool.query(`SELECT c.convalidated FROM pg_constraint c
          JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace
          WHERE n.nspname='public' AND t.relname='machinery_bookings'
          AND c.conname='machinery_no_overlapping_confirmed'`);
        workflowReady = constraint.rows[0]?.convalidated === true;
      }
    } catch (_) {
      // Registration can remain available while machinery setup is pending.
    }
    return res.json({storage: storageInfo(), provider_registration_ready: true,
      machinery_workflow_ready: workflowReady});
  } catch (error) {
    return res.json({storage: storageInfo(), provider_registration_ready: false,
      machinery_workflow_ready: false,
      message: error.code === '42P01'
        ? 'Provider registration database setup is incomplete. Contact the project administrator.'
        : 'The registration database is unavailable. Check the backend connection.'});
  }
};
module.exports = {getHealth, storageInfo};
