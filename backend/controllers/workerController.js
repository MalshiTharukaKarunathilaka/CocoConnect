const pool = require("../config/db");

const workerForUser = async (userId) => {
  const result = await pool.query(
    "SELECT * FROM worker WHERE user_id = $1",
    [userId]
  );
  return result.rows[0] || null;
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
         dja.id AS application_id,
         dja.status AS application_status
       FROM day_jobs dj
       LEFT JOIN day_job_applications dja
         ON dja.day_job_id = dj.id AND dja.worker_id = $1
       WHERE UPPER(COALESCE(dj.status, 'OPEN')) = 'OPEN'
         AND dj.required_date >= CURRENT_DATE
       ORDER BY dj.required_date, dj.created_at DESC, dj.id DESC`,
      [worker.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    console.error("Get worker jobs error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const applyForJob = async (req, res) => {
  try {
    const worker = await workerForUser(req.user.id);
    const jobId = Number(req.params.id);
    if (!worker || !Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid worker or job" });
    }

    const job = await pool.query(
      `SELECT id, workers_needed, confirmed_workers
       FROM day_jobs
       WHERE id = $1 AND UPPER(COALESCE(status, 'OPEN')) = 'OPEN'`,
      [jobId]
    );
    if (job.rows.length === 0) {
      return res.status(404).json({ message: "Job not found or closed" });
    }

    if (Number(job.rows[0].confirmed_workers) >= Number(job.rows[0].workers_needed)) {
      return res.status(409).json({ message: "This job is already full" });
    }

    const result = await pool.query(
      `INSERT INTO day_job_applications (day_job_id, worker_id)
       VALUES ($1, $2)
       ON CONFLICT (day_job_id, worker_id) DO NOTHING
       RETURNING *`,
      [jobId, worker.id]
    );
    if (result.rows.length === 0) {
      return res.status(409).json({ message: "You already applied for this job" });
    }

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error("Apply for worker job error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

module.exports = { getAvailableJobs, applyForJob };
