const pool = require("../config/db");
const { parseCoords, parseRadius, withDistance, byDistance } = require("../utils/geo");

const workerForUser = async (userId) => {
  const result = await pool.query(
    "SELECT * FROM worker WHERE user_id = $1",
    [userId]
  );
  if (result.rows.length > 0) {
    return result.rows[0];
  }

  const user = await pool.query(
    "SELECT name FROM users WHERE id = $1",
    [userId]
  );
  if (user.rows.length === 0) {
    return null;
  }

  const created = await pool.query(
    `INSERT INTO worker (user_id, worker_name, job_category, jobs)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId, JSON.stringify(user.rows[0].name), "[]", "[]"]
  );
  return created.rows[0] || null;
};

const getAvailableJobs = async (req, res) => {
  try {
    const worker = await workerForUser(req.user.id);
    if (!worker) {
      return res.status(404).json({ message: "Worker profile not found" });
    }

    const result = await pool.query(
      `SELECT
         dj.*,
         eo.estate_name,
         eo.name AS estate_owner_name,
         u.latitude AS estate_latitude,
         u.longitude AS estate_longitude,
         dja.id AS application_id,
         dja.status AS application_status
       FROM day_jobs dj
       JOIN estate_owners eo ON eo.id = dj.estate_owner_id
       LEFT JOIN users u ON u.id = eo.user_id
       LEFT JOIN day_job_applications dja
         ON dja.day_job_id = dj.id AND dja.worker_id = $1
       WHERE (
           (
             UPPER(COALESCE(dj.status, 'OPEN')) = 'OPEN'
             AND dj.required_date >= CURRENT_DATE
           )
           OR dja.id IS NOT NULL
         )
       ORDER BY
         CASE WHEN dja.id IS NOT NULL THEN 0 ELSE 1 END,
         dj.required_date DESC,
         dj.created_at DESC,
         dj.id DESC`,
      [worker.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    console.error("Get worker jobs error:", error);
    if (error.code === "42703" || error.code === "42P01") {
      return res.status(500).json({
        message:
          "Worker database is not configured. Run backend/sql/009_worker_accounts_and_applications.sql in Supabase.",
      });
    }
    return res.status(500).json({ message: "Server error" });
  }
};

const getEstates = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT eo.id, eo.estate_name, eo.name AS estate_owner_name,
              eo.location, u.latitude AS estate_latitude,
              u.longitude AS estate_longitude
       FROM estate_owners eo
       LEFT JOIN users u ON u.id = eo.user_id
       ORDER BY eo.estate_name`
    );
    return res.status(200).json(result.rows);
  } catch (error) {
    console.error("Get estates error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const getNearbyEstates = async (req, res) => {
  try {
    const worker = await pool.query(
      "SELECT latitude, longitude FROM users WHERE id = $1",
      [req.user.id]
    );
    const origin = parseCoords(worker.rows[0]?.latitude, worker.rows[0]?.longitude);
    if (!origin) {
      return res.status(400).json({ message: "Worker location is not set" });
    }
    const radiusKm = parseRadius(req.query.radiusKm) || 20;
    const result = await pool.query(
      `SELECT eo.id, eo.estate_name, eo.name AS estate_owner_name,
              eo.location, u.latitude, u.longitude
       FROM estate_owners eo
       LEFT JOIN users u ON u.id = eo.user_id
       WHERE u.latitude IS NOT NULL AND u.longitude IS NOT NULL`
    );
    return res.status(200).json(
      withDistance(result.rows, origin, radiusKm).sort(byDistance)
    );
  } catch (error) {
    console.error("Get nearby estates error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const applyForJob = async (req, res) => {
  let client;
  try {
    const worker = await workerForUser(req.user.id);
    const jobId = Number(req.params.id);
    if (!worker || !Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid worker or job" });
    }

    client = await pool.connect();
    await client.query("BEGIN");

    const job = await client.query(
      `SELECT id, workers_needed, confirmed_workers
       FROM day_jobs
       WHERE id = $1 AND UPPER(COALESCE(status, 'OPEN')) = 'OPEN'
       FOR UPDATE`,
      [jobId]
    );
    if (job.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Job not found or closed" });
    }

    if (Number(job.rows[0].confirmed_workers) >= Number(job.rows[0].workers_needed)) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "This job is already full" });
    }

    const existing = await client.query(
      `SELECT id, status
       FROM day_job_applications
       WHERE day_job_id = $1 AND worker_id = $2
       FOR UPDATE`,
      [jobId, worker.id]
    );
    if (
      existing.rows.length > 0 &&
      String(existing.rows[0].status).toUpperCase() === "ACCEPTED"
    ) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "You already accepted this job" });
    }

    const result = existing.rows.length > 0
      ? await client.query(
          `UPDATE day_job_applications
           SET status = 'ACCEPTED'
           WHERE id = $1
           RETURNING *`,
          [existing.rows[0].id]
        )
      : await client.query(
          `INSERT INTO day_job_applications (day_job_id, worker_id, status)
           VALUES ($1, $2, 'ACCEPTED')
           RETURNING *`,
          [jobId, worker.id]
        );

    await client.query(
      `UPDATE day_jobs
       SET confirmed_workers = confirmed_workers + 1,
           status = CASE
             WHEN confirmed_workers + 1 >= workers_needed THEN 'FULL'
             ELSE status
           END
       WHERE id = $1`,
      [jobId]
    );
    await client.query("COMMIT");

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    if (client) {
      await client.query("ROLLBACK").catch(() => {});
    }
    console.error("Apply for worker job error:", error);
    if (error.code === "42703" || error.code === "42P01") {
      return res.status(500).json({
        message:
          "Worker database is not configured. Run backend/sql/009_worker_accounts_and_applications.sql in Supabase.",
      });
    }
    return res.status(500).json({ message: "Server error" });
  } finally {
    client?.release();
  }
};

module.exports = { getAvailableJobs, getEstates, getNearbyEstates, applyForJob };
