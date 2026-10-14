require("dotenv").config();
const bcrypt = require("bcryptjs");
const pool = require("../config/db");

async function main() {
  const phone = process.env.ADMIN_PHONE || "0700000001";
  const password = process.env.ADMIN_PASSWORD || "admin123";
  const hash = await bcrypt.hash(password, 10);
  const existing = await pool.query("SELECT id FROM users WHERE phone = $1", [phone]);

  if (existing.rows[0]) {
    await pool.query(
      `UPDATE users
       SET role = 'ADMIN', status = 'ACTIVE', password_hash = $2, name = COALESCE(name, 'CocoConnect Admin')
       WHERE phone = $1`,
      [phone, hash]
    );
    console.log(`Updated admin account ${phone}`);
  } else {
    await pool.query(
      `INSERT INTO users (name, phone, password_hash, role, location, status)
       VALUES ('CocoConnect Admin', $1, $2, 'ADMIN', 'Colombo', 'ACTIVE')`,
      [phone, hash]
    );
    console.log(`Created admin account ${phone}`);
  }

  console.log(`Password: ${password}`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
