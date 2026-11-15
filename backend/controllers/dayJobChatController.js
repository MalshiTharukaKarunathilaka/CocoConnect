const pool = require("../config/db");

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  if (error.code === "42P01" || error.code === "42703") {
    return res.status(503).json({
      message:
        "Day-job chat is not configured. Run backend/sql/010_day_job_chats.sql in Supabase, then restart the backend.",
    });
  }
  return res.status(500).json({ message: "Server error" });
};

const workerForUser = async (db, userId) => {
  const result = await db.query(
    "SELECT id FROM worker WHERE user_id = $1",
    [userId]
  );
  return result.rows[0] || null;
};

const chatForUser = async (db, chatId, userId) => {
  const result = await db.query(
    `SELECT
       c.*,
       dj.category,
       dj.required_date,
       dj.daily_rate,
       eo.estate_name,
       eo.name AS owner_name,
       w.user_id AS worker_user_id,
       wu.name AS worker_name
     FROM day_job_chats c
     JOIN day_jobs dj ON dj.id = c.day_job_id
     JOIN estate_owners eo ON eo.id = dj.estate_owner_id
     JOIN worker w ON w.id = c.worker_id
     JOIN users wu ON wu.id = w.user_id
     WHERE c.id = $1
       AND (c.owner_user_id = $2 OR w.user_id = $2)`,
    [chatId, userId]
  );
  return result.rows[0] || null;
};

const ensureJobApplication = async (db, jobId, workerId, ownerUserId) => {
  const result = await db.query(
    `SELECT dja.id
     FROM day_jobs dj
     JOIN estate_owners eo ON eo.id = dj.estate_owner_id
     JOIN day_job_applications dja ON dja.day_job_id = dj.id
     WHERE dj.id = $1
       AND dja.worker_id = $2
       AND eo.user_id = $3
       AND UPPER(COALESCE(dja.status, 'PENDING')) IN ('PENDING', 'ACCEPTED')`,
    [jobId, workerId, ownerUserId]
  );
  return result.rows.length > 0;
};

const createChat = async (req, res) => {
  try {
    const jobId = Number(req.body.jobId);
    let workerId = Number(req.body.workerId);
    let ownerUserId = req.user.id;

    if (!Number.isInteger(jobId)) {
      return res.status(400).json({ message: "Invalid day job" });
    }

    if (req.user.role === "WORKER") {
      const worker = await workerForUser(pool, req.user.id);
      if (!worker) return res.status(404).json({ message: "Worker profile not found" });
      workerId = worker.id;
      const owner = await pool.query(
        `SELECT eo.user_id
         FROM day_jobs dj
         JOIN estate_owners eo ON eo.id = dj.estate_owner_id
         WHERE dj.id = $1`,
        [jobId]
      );
      if (owner.rows.length === 0) return res.status(404).json({ message: "Job not found" });
      ownerUserId = owner.rows[0].user_id;
    } else if (req.user.role === "ESTATE_OWNER") {
      if (!Number.isInteger(workerId)) {
        return res.status(400).json({ message: "Worker is required" });
      }
    } else {
      return res.status(403).json({ message: "Only workers and estate owners can chat" });
    }

    if (!(await ensureJobApplication(pool, jobId, workerId, ownerUserId))) {
      return res.status(403).json({
        message: "Apply for this job before negotiating with the estate owner",
      });
    }

    const result = await pool.query(
      `INSERT INTO day_job_chats (day_job_id, worker_id, owner_user_id)
       VALUES ($1, $2, $3)
       ON CONFLICT (day_job_id, worker_id)
       DO UPDATE SET owner_user_id = EXCLUDED.owner_user_id
       RETURNING id`,
      [jobId, workerId, ownerUserId]
    );
    return res.status(200).json({ id: result.rows[0].id });
  } catch (error) {
    return serverError(res, "Create day job chat", error);
  }
};

const getChats = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         c.id,
         c.day_job_id,
         dj.category,
         CASE WHEN c.owner_user_id = $1 THEN wu.name ELSE eo.estate_name END AS counterpart_name,
         last.message AS last_message,
         last.created_at AS last_activity_at
       FROM day_job_chats c
       JOIN day_jobs dj ON dj.id = c.day_job_id
       JOIN estate_owners eo ON eo.id = dj.estate_owner_id
       JOIN worker w ON w.id = c.worker_id
       JOIN users wu ON wu.id = w.user_id
       LEFT JOIN LATERAL (
         SELECT message, created_at
         FROM day_job_chat_messages
         WHERE chat_id = c.id
         ORDER BY created_at DESC, id DESC
         LIMIT 1
       ) last ON true
       WHERE c.owner_user_id = $1 OR w.user_id = $1
       ORDER BY last.created_at DESC NULLS LAST, c.id DESC`,
      [req.user.id]
    );
    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get day job chats", error);
  }
};

const getChat = async (req, res) => {
  try {
    const chat = await chatForUser(pool, req.params.id, req.user.id);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    const messages = await pool.query(
      `SELECT id, sender_id, message, created_at
       FROM day_job_chat_messages
       WHERE chat_id = $1
       ORDER BY created_at, id`,
      [chat.id]
    );
    await pool.query(
      `UPDATE day_job_chats
       SET ${chat.owner_user_id === req.user.id
         ? "owner_last_read_at"
         : "worker_last_read_at"} = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [chat.id]
    );
    return res.status(200).json({
      id: chat.id,
      job_id: chat.day_job_id,
      category: chat.category,
      required_date: chat.required_date,
      daily_rate: chat.daily_rate,
      counterpart_name:
        chat.owner_user_id === req.user.id ? chat.worker_name : chat.estate_name,
      counterpart_role: chat.owner_user_id === req.user.id ? "WORKER" : "ESTATE_OWNER",
      messages: messages.rows.map((message) => ({
        ...message,
        is_mine: message.sender_id === req.user.id,
      })),
    });
  } catch (error) {
    return serverError(res, "Get day job chat", error);
  }
};

const sendMessage = async (req, res) => {
  try {
    const message = String(req.body.message || "").trim();
    if (!message) return res.status(400).json({ message: "Message is required" });
    const chat = await chatForUser(pool, req.params.id, req.user.id);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    const result = await pool.query(
      `INSERT INTO day_job_chat_messages (chat_id, sender_id, message)
       VALUES ($1, $2, $3)
       RETURNING id, sender_id, message, created_at`,
      [chat.id, req.user.id, message]
    );
    return res.status(201).json({
      ...result.rows[0],
      is_mine: true,
    });
  } catch (error) {
    return serverError(res, "Send day job message", error);
  }
};

module.exports = { createChat, getChats, getChat, sendMessage };
