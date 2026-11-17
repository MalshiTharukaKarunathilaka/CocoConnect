const pool = require("../config/db");
const {
  parseCoords,
  parseRadius,
  withDistance,
  byDistance,
  dayOf,
} = require("../utils/geo");

const localToday = () => {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
};

const dayJobRatingsReady = async () => {
  if (pool.databaseMode === "memory") return true;
  const result = await pool.query(
    `SELECT COUNT(*)::integer AS count
     FROM information_schema.columns
     WHERE table_name = 'day_job_applications'
       AND column_name IN ('rating', 'rated_at')`
  );
  return Number(result.rows[0]?.count || 0) === 2;
};

const estateOwnerRatingsReady = async () => {
  if (pool.databaseMode === "memory") return true;
  const result = await pool.query(
    `SELECT COUNT(*)::integer AS count
     FROM information_schema.columns
     WHERE table_name = 'day_job_applications'
       AND column_name IN ('estate_owner_rating', 'estate_owner_rated_at')`
  );
  return Number(result.rows[0]?.count || 0) === 2;
};

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

const getProfile = async (req, res) => {
  try {
    const worker = await workerForUser(req.user.id);
    if (!worker) {
      return res.status(404).json({ message: "Worker profile not found" });
    }

    const ratingsReady = await dayJobRatingsReady();
    const ratingColumn = ratingsReady ? "dja.rating" : "NULL::smallint";
    const profile = await pool.query(
      `SELECT w.id, u.name, u.phone, u.location
       FROM worker w
       JOIN users u ON u.id = w.user_id
       WHERE w.id = $1`,
      [worker.id]
    );
    const stats = await pool.query(
      `SELECT
         COUNT(*)::integer AS accepted_jobs,
         COALESCE(SUM(
           CASE WHEN UPPER(COALESCE(dj.status, 'OPEN')) = 'COMPLETED'
             THEN 1 ELSE 0 END
         ), 0)::integer AS completed_jobs,
         COALESCE(SUM(
           CASE WHEN UPPER(COALESCE(dj.status, 'OPEN')) = 'COMPLETED'
             THEN COALESCE(${ratingColumn}, 0) ELSE 0 END
         ), 0)::integer AS total_rating_marks
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       WHERE dja.worker_id = $1
         AND UPPER(dja.status) IN ('ACCEPTED', 'COMPLETED')`,
      [worker.id]
    );
    const categories = await pool.query(
      `SELECT DISTINCT dj.category
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       WHERE dja.worker_id = $1
         AND UPPER(dja.status) IN ('ACCEPTED', 'COMPLETED')
       ORDER BY dj.category`,
      [worker.id]
    );

    const acceptedJobs = Number(stats.rows[0]?.accepted_jobs || 0);
    const completedJobs = Number(stats.rows[0]?.completed_jobs || 0);
    const totalRatingMarks = Number(stats.rows[0]?.total_rating_marks || 0);
    return res.status(200).json({
      ...profile.rows[0],
      accepted_jobs: acceptedJobs,
      active_jobs: Math.max(acceptedJobs - completedJobs, 0),
      completed_jobs: completedJobs,
      total_rating_marks: totalRatingMarks,
      average_rating:
        completedJobs > 0 ? totalRatingMarks / completedJobs : null,
      work_categories: categories.rows.map((row) => row.category),
    });
  } catch (error) {
    console.error("Get worker profile error:", error);
    if (error.code === "42703" || error.code === "42P01") {
      return res.status(500).json({
        message:
          "Worker database is not configured. Run worker and day-job migrations.",
      });
    }
    return res.status(500).json({ message: "Server error" });
  }
};

const getAvailableJobs = async (req, res) => {
  try {
    const worker = await workerForUser(req.user.id);
    if (!worker) {
      return res.status(404).json({ message: "Worker profile not found" });
    }

    const ratingsReady = await dayJobRatingsReady();
    const ratingColumn = ratingsReady ? "dja.rating" : "NULL::smallint";
    const ownerRatingsReady = await estateOwnerRatingsReady();
    const ownerRatingColumn = ownerRatingsReady
      ? "dja.estate_owner_rating"
      : "NULL::smallint";
    const result = await pool.query(
      `SELECT
         dj.*,
         eo.estate_name,
         eo.name AS estate_owner_name,
         eo.location AS estate_location,
         u.latitude AS estate_latitude,
         u.longitude AS estate_longitude,
         dja.id AS application_id,
         CASE
           WHEN UPPER(COALESCE(dja.status, '')) = 'COMPLETED' THEN 'ACCEPTED'
           ELSE dja.status
         END AS application_status,
         ${ratingColumn} AS rating,
         ${ownerRatingColumn} AS estate_owner_rating,
         dj.status AS worker_status,
         (UPPER(COALESCE(dja.status, '')) = 'COMPLETED'
           AND ${ownerRatingColumn} IS NOT NULL)
           AS completion_acknowledged,
         CASE
           WHEN UPPER(COALESCE(dja.status, '')) = 'ACCEPTED'
             AND dj.required_date > CURRENT_DATE
             AND UPPER(COALESCE(dj.status, 'OPEN')) <> 'COMPLETED'
           THEN TRUE
           ELSE FALSE
         END AS can_decline
       FROM day_jobs dj
       JOIN estate_owners eo ON eo.id = dj.estate_owner_id
       LEFT JOIN users u ON u.id = eo.user_id
       LEFT JOIN day_job_applications dja
         ON dja.day_job_id = dj.id AND dja.worker_id = $1
       WHERE (
           (
             (
               UPPER(COALESCE(dj.status, 'OPEN')) = 'OPEN'
               OR (
                 UPPER(COALESCE(dj.status, 'OPEN')) = 'COMPLETED'
                 AND dj.confirmed_workers < dj.workers_needed
               )
             )
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

    const user = await pool.query(
      "SELECT latitude, longitude FROM users WHERE id = $1",
      [req.user.id]
    );
    const origin = parseCoords(
      user.rows[0]?.latitude,
      user.rows[0]?.longitude
    );
    const jobsWithDistance = withDistance(
      result.rows.map((row) => ({
        ...row,
        latitude: row.estate_latitude,
        longitude: row.estate_longitude,
      })),
      origin
    );

    return res.status(200).json(jobsWithDistance);
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

const getEstateOwnerProfile = async (req, res) => {
  try {
    const jobId = Number(req.params.id);
    const worker = await workerForUser(req.user.id);
    if (!worker || !Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid worker or job" });
    }

    const ratingsReady = await estateOwnerRatingsReady();
    const ratingColumn = ratingsReady
      ? "dja.estate_owner_rating"
      : "NULL::smallint";
    const profile = await pool.query(
      `SELECT eo.id, eo.name AS owner_name, eo.estate_name, eo.location,
              eo.total_land_area, eo.primary_crop, eo.year_established,
              u.phone, ${ratingColumn} AS current_job_rating
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       JOIN estate_owners eo ON eo.id = dj.estate_owner_id
       LEFT JOIN users u ON u.id = eo.user_id
       WHERE dj.id = $1
         AND dja.worker_id = $2
         AND UPPER(dja.status) IN ('ACCEPTED', 'COMPLETED')`,
      [jobId, worker.id]
    );
    if (profile.rows.length === 0) {
      return res.status(404).json({ message: "Land owner profile not found" });
    }

    const estateId = profile.rows[0].id;
    const ratingValue = ratingsReady
      ? "dja.estate_owner_rating"
      : "NULL::smallint";
    const stats = await pool.query(
      `SELECT COUNT(*)::integer AS completed_jobs,
              COUNT(${ratingValue})::integer AS rating_count,
              COALESCE(SUM(${ratingValue}), 0)::integer AS total_rating_marks
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       WHERE dj.estate_owner_id = $1
         AND UPPER(dj.status) = 'COMPLETED'
         AND UPPER(dja.status) IN ('ACCEPTED', 'COMPLETED')`,
      [estateId]
    );
    const completedJobs = Number(stats.rows[0]?.completed_jobs || 0);
    const ratingCount = Number(stats.rows[0]?.rating_count || 0);
    const totalRatingMarks = Number(stats.rows[0]?.total_rating_marks || 0);

    return res.status(200).json({
      ...profile.rows[0],
      current_job_rating:
        profile.rows[0].current_job_rating == null
          ? null
          : Number(profile.rows[0].current_job_rating),
      completed_jobs: completedJobs,
      rating_count: ratingCount,
      total_rating_marks: totalRatingMarks,
      average_rating:
        completedJobs > 0 ? totalRatingMarks / completedJobs : null,
    });
  } catch (error) {
    console.error("Get estate owner profile error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const rateEstateOwner = async (req, res) => {
  try {
    const jobId = Number(req.params.id);
    const rating = Number(req.body.rating);
    const worker = await workerForUser(req.user.id);
    if (!worker || !Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid worker or job" });
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({ message: "Rating must be from 1 to 5" });
    }
    if (!(await estateOwnerRatingsReady())) {
      return res.status(503).json({
        message:
          "Land owner ratings are not configured. Run backend/sql/014_day_job_estate_owner_ratings.sql.",
      });
    }

    const application = await pool.query(
      `SELECT dja.id, dj.estate_owner_id
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       WHERE dj.id = $1
         AND dja.worker_id = $2
         AND UPPER(dj.status) = 'COMPLETED'
         AND UPPER(dja.status) IN ('ACCEPTED', 'COMPLETED')`,
      [jobId, worker.id]
    );
    if (application.rows.length === 0) {
      return res.status(404).json({
        message: "Completed job land owner not found",
      });
    }

    const result = await pool.query(
      `UPDATE day_job_applications
       SET estate_owner_rating = $2,
           estate_owner_rated_at = CURRENT_TIMESTAMP
       WHERE id = $1
       RETURNING estate_owner_rating, estate_owner_rated_at`,
      [application.rows[0].id, rating]
    );
    return res.status(200).json({
      estate_owner_id: application.rows[0].estate_owner_id,
      job_id: jobId,
      rating: Number(result.rows[0].estate_owner_rating),
      rated_at: result.rows[0].estate_owner_rated_at,
    });
  } catch (error) {
    console.error("Rate estate owner error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const getEstates = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT eo.id, eo.estate_name, eo.name AS estate_owner_name,
              eo.location, u.latitude AS estate_latitude,
              u.longitude AS estate_longitude,
              (u.latitude IS NOT NULL AND u.longitude IS NOT NULL)
                AS has_map_location
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

const getEstateLocation = async (req, res) => {
  try {
    const estateId = Number(req.params.id);
    if (!Number.isInteger(estateId)) {
      return res.status(400).json({ message: "Invalid estate" });
    }
    const result = await pool.query(
      `SELECT eo.id, eo.estate_name, eo.name AS estate_owner_name,
              eo.location, u.latitude AS estate_latitude,
              u.longitude AS estate_longitude
       FROM estate_owners eo
       LEFT JOIN users u ON u.id = eo.user_id
       WHERE eo.id = $1`,
      [estateId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Land owner estate not found" });
    }
    const estate = result.rows[0];
    if (!parseCoords(estate.estate_latitude, estate.estate_longitude)) {
      return res.status(409).json({
        message: "This estate does not have a saved map location",
      });
    }
    return res.status(200).json(estate);
  } catch (error) {
    console.error("Get estate location error:", error);
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

    // Serialize accept attempts for this worker so two simultaneous requests
    // cannot both reserve jobs scheduled for the same day.
    await client.query(
      `SELECT id
       FROM worker
       WHERE id = $1
       FOR UPDATE`,
      [worker.id]
    );

    const job = await client.query(
      `SELECT id, workers_needed, confirmed_workers, required_date
       FROM day_jobs
       WHERE id = $1
         AND (
           UPPER(COALESCE(status, 'OPEN')) = 'OPEN'
           OR (
             UPPER(COALESCE(status, 'OPEN')) = 'COMPLETED'
             AND confirmed_workers < workers_needed
           )
         )
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

    const sameDayJob = await client.query(
      `SELECT dj.id, dj.category
       FROM day_job_applications dja
       JOIN day_jobs dj ON dj.id = dja.day_job_id
       WHERE dja.worker_id = $1
         AND UPPER(COALESCE(dja.status, 'PENDING')) = 'ACCEPTED'
         AND dj.required_date = $2
         AND dj.id <> $3
       LIMIT 1`,
      [worker.id, job.rows[0].required_date, jobId]
    );
    if (sameDayJob.rows.length > 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message:
          "You already accepted another job on this day. Decline that job before accepting this one.",
      });
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
             ELSE 'OPEN'
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

const declineJob = async (req, res) => {
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
      `SELECT id, status, confirmed_workers, workers_needed, required_date
       FROM day_jobs
       WHERE id = $1
       FOR UPDATE`,
      [jobId]
    );
    if (job.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Job not found" });
    }
    const requiredDay = dayOf(job.rows[0].required_date);
    if (
      String(job.rows[0].status).toUpperCase() === "COMPLETED" ||
      !requiredDay ||
      requiredDay <= localToday()
    ) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "Only future jobs can be declined",
      });
    }

    const application = await client.query(
      `SELECT id, status
       FROM day_job_applications
       WHERE day_job_id = $1 AND worker_id = $2
       FOR UPDATE`,
      [jobId, worker.id]
    );
    if (
      application.rows.length === 0 ||
      String(application.rows[0].status).toUpperCase() !== "ACCEPTED"
    ) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "You have not accepted this job" });
    }

    const result = await client.query(
      `UPDATE day_job_applications
       SET status = 'DECLINED'
       WHERE id = $1
       RETURNING *`,
      [application.rows[0].id]
    );
    await client.query(
      `UPDATE day_jobs
       SET confirmed_workers = GREATEST(confirmed_workers - 1, 0),
           status = 'OPEN'
       WHERE id = $1`,
      [jobId]
    );
    await client.query("COMMIT");

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    if (client) {
      await client.query("ROLLBACK").catch(() => {});
    }
    console.error("Decline worker job error:", error);
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

const acknowledgeJobCompletion = async (req, res) => {
  let client;
  try {
    const worker = await workerForUser(req.user.id);
    const jobId = Number(req.params.id);
    const rating = Number(req.body.rating);
    if (!worker || !Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid worker or job" });
    }
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({
        message: "Rate the land owner from 1 to 5 before completing the job",
      });
    }
    if (!(await estateOwnerRatingsReady())) {
      return res.status(503).json({
        message:
          "Land owner ratings are not configured. Run backend/sql/014_day_job_estate_owner_ratings.sql.",
      });
    }

    client = await pool.connect();
    await client.query("BEGIN");
    const job = await client.query(
      `SELECT id, status
       FROM day_jobs
       WHERE id = $1
       FOR UPDATE`,
      [jobId]
    );
    if (job.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Job not found" });
    }
    if (String(job.rows[0].status).toUpperCase() !== "AWAITING_WORKER_ACK") {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: String(job.rows[0].status).toUpperCase() === "COMPLETED"
          ? "This job is already completed"
          : "The land owner has not requested completion yet",
      });
    }

    const application = await client.query(
      `UPDATE day_job_applications
       SET status = 'COMPLETED',
           estate_owner_rating = $3,
           estate_owner_rated_at = CURRENT_TIMESTAMP
       WHERE day_job_id = $1
         AND worker_id = $2
         AND UPPER(status) IN ('ACCEPTED', 'COMPLETED')
         AND estate_owner_rating IS NULL
       RETURNING *`,
      [jobId, worker.id, rating]
    );
    if (application.rows.length === 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "You are not an accepted worker for this acknowledgement",
      });
    }

    const pending = await client.query(
      `SELECT COUNT(*)::integer AS count
       FROM day_job_applications
       WHERE day_job_id = $1
         AND UPPER(status) IN ('ACCEPTED', 'COMPLETED')
         AND (
           UPPER(status) <> 'COMPLETED'
           OR estate_owner_rating IS NULL
         )`,
      [jobId]
    );
    const completed = Number(pending.rows[0]?.count || 0) === 0;
    if (completed) {
      await client.query(
        `UPDATE day_jobs SET status = 'COMPLETED' WHERE id = $1`,
        [jobId]
      );
    }
    await client.query("COMMIT");
    return res.status(200).json({
      job_id: jobId,
      rating,
      status: completed ? "COMPLETED" : "AWAITING_WORKER_ACK",
      message: completed
        ? "Job completed"
        : "Completion acknowledged; waiting for the other accepted workers",
    });
  } catch (error) {
    if (client) await client.query("ROLLBACK").catch(() => {});
    console.error("Acknowledge worker job completion error:", error);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client?.release();
  }
};

module.exports = {
  getProfile,
  getAvailableJobs,
  getEstates,
  getEstateLocation,
  getNearbyEstates,
  getEstateOwnerProfile,
  rateEstateOwner,
  applyForJob,
  declineJob,
  acknowledgeJobCompletion,
};
