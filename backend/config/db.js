const { Pool, types, defaults } = require("pg");
require("dotenv").config();

// Return DATE columns as plain "YYYY-MM-DD" strings. By default pg turns
// them into midnight local time, which serialises as the previous day in UTC
// (2026-07-18 came back as 2026-07-17T18:30:00.000Z in Sri Lanka).
const DATE_OID = 1082;
types.setTypeParser(DATE_OID, (value) => value);

// TIMESTAMP (without time zone) columns hold UTC from Supabase's
// current_timestamp, but pg reads them as local time, shifting them 5.5h.
const TIMESTAMP_OID = 1114;
types.setTypeParser(TIMESTAMP_OID, (value) =>
  new Date(value.replace(" ", "T") + "Z")
);

// ...and write JS Dates as UTC to match, so timestamps set from code (like
// completed_at) agree with ones Postgres sets itself.
defaults.parseInputDatesAsUTC = true;

// DB_MODE=memory swaps Supabase for a throwaway in-memory database
// (npm run dev:memory) so features can be tried without touching team data.
if (process.env.DB_MODE === "memory") {
  console.log("Using in-memory test database - nothing is saved to Supabase");
  module.exports = require("../test/memoryDb");
  return;
}

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