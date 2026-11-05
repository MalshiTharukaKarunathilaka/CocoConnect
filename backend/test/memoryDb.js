// In-memory Postgres for local testing, so trying the app never touches the
// team's Supabase data. Enabled with DB_MODE=memory; wiped on every restart.
const fs = require("fs");
const path = require("path");
const { newDb } = require("pg-mem");

const db = newDb();

const readSql = (file) => fs.readFileSync(path.join(__dirname, file), "utf8");

db.public.none(readSql("schema.sql"));

// Every migration in sql/, in order. pg-mem has no row level security;
// that part only matters on Supabase.
for (const file of fs.readdirSync(path.join(__dirname, "../sql")).sort()) {
  db.public.none(
    readSql(`../sql/${file}`)
      .split(/\r?\n/)
      .filter((line) => !/row level security/i.test(line))
      .join("\n")
  );
}

db.public.none(`
  INSERT INTO estate_owners (name, estate_name, location, trust_score) VALUES
    ('Nimal Perera', 'Green Valley Estate', 'Kurunegala', 4.8),
    ('Kamala Silva', 'Silva Plantations', 'Puttalam', 4.2),
    ('Ruwan Jayasinghe', 'Coconut Grove', 'Gampaha', NULL);

  INSERT INTO product_listings
    (estate_owner_id, product_type, quantity, available_date, offer_price_per_unit) VALUES
    (1, 'RAW_COCONUT', 1200, '2026-11-18', 130),
    (2, 'RAW_COCONUT', 600, '2026-11-25', 125.50),
    (3, 'RAW_COCONUT', 2000, '2026-12-01', 140),
    (1, 'HUSKED_COCONUT', 800, '2026-11-20', 150),
    (2, 'DEHUSKED_COCONUT', 500, '2026-12-05', 165);

  INSERT INTO product_listings
    (estate_owner_id, product_type, quantity, available_date, offer_price_per_unit, status) VALUES
    (3, 'RAW_COCONUT', 999, '2026-11-01', 99, 'SOLD');

  INSERT INTO buyer_requests
    (buyer_name, location, product_type, requested_quantity, required_date, bidding_price_per_unit) VALUES
    ('Mudalali A', 'Kurunegala', 'RAW_COCONUT', 1200, '2026-12-18', 136);
`);

// A demo admin for reviewing price disputes: 0700000000 / admin123.
db.public.none(`
  INSERT INTO users (name, phone, password_hash, role, location) VALUES
    ('CocoConnect Admin', '0700000000',
     '${require("bcryptjs").hashSync("admin123", 10)}', 'ADMIN', 'Colombo');
`);

const { Pool } = db.adapters.createPg();

module.exports = new Pool();
module.exports.memoryDb = db;
