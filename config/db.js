const { Pool } = require("pg");
require("dotenv").config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.DATABASE_SSL === "false"
      ? false
      : { rejectUnauthorized: false },
});

pool.on("connect", () => {
  console.log("Connected to Supabase PostgreSQL");
});

pool.on("error", (err) => {
  console.error("PostgreSQL error:", err);
});

module.exports = pool;