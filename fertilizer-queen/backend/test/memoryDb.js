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
  // PostgreSQL's GiST exclusion constraint is verified separately in real PG.
  if (file === '010_machinery_overlap_constraint.sql') continue;
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

// Demo logins for local testing (memory DB only — not written to Supabase).
// Password for all demo accounts below: demo123  (admin: admin123)
// Estate owners:
//   0711000001  Demo Estate Owner (Kurunegala / Mawathagama)
//   0712000011  Nushrath Silva (Colombo Palm Estate)  ← "nush"
//   0712000022  Kamal Fernando (Puttalam Coast Estate)
// Colombo suppliers: 0772100001 … 0772100005
// Puttalam suppliers: 0772200001 … 0772200005
// CDOs: 0772300001 Colombo, 0772300002 Puttalam (+ 0372223344 Mawathagama)
const hash = (pw) => require("bcryptjs").hashSync(pw, 10);
const demoPw = hash("demo123");
db.public.none(`
  INSERT INTO users (name, phone, password_hash, role, location, latitude, longitude) VALUES
    ('KapConnect Admin', '0700000000', '${hash("admin123")}', 'ADMIN', 'Colombo', NULL, NULL),
    ('Demo Estate Owner', '0711000001', '${demoPw}', 'ESTATE_OWNER', 'Kurunegala', 7.4863, 80.3647),
    ('Nushrath Silva', '0712000011', '${demoPw}', 'ESTATE_OWNER', 'Colombo', 6.9271, 79.8612),
    ('Kamal Fernando', '0712000022', '${demoPw}', 'ESTATE_OWNER', 'Puttalam', 8.0362, 79.8283),
    ('Nadeesha Perera', '0771112233', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Kurunegala', 7.4980, 80.3560),
    ('Ravi Jayasuriya', '0772100001', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Colombo', 6.9350, 79.8700),
    ('Sithara Perera', '0772100002', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Colombo', 6.9150, 79.8800),
    ('Nuwan Dias', '0772100003', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Colombo', 6.9450, 79.8500),
    ('Malsha Fernando', '0772100004', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Colombo', 6.9000, 79.8900),
    ('Ishara Gunasekara', '0772100005', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Colombo', 6.9600, 79.8700),
    ('Ajith Bandara', '0772200001', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Puttalam', 8.0400, 79.8350),
    ('Dilani Wijesinghe', '0772200002', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Puttalam', 8.0200, 79.8500),
    ('Pradeep Silva', '0772200003', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Puttalam', 8.0550, 79.8200),
    ('Nadeeka Rathnayake', '0772200004', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Puttalam', 8.0100, 79.8600),
    ('Kasun Mendis', '0772200005', '${demoPw}', 'FERTILIZER_SUPPLIER', 'Puttalam', 8.0700, 79.8400),
    ('CDO Mawathagama', '0372223344', '${demoPw}', 'CDO', 'Kurunegala', 7.5400, 80.4000),
    ('CDO Colombo', '0772300001', '${demoPw}', 'CDO', 'Colombo', 6.9300, 79.8650),
    ('CDO Puttalam', '0772300002', '${demoPw}', 'CDO', 'Puttalam', 8.0350, 79.8300),
    ('Demo Buyer', '0771000001', '${demoPw}', 'BUYER', 'Colombo', 6.9271, 79.8612);

  INSERT INTO fertilizer_suppliers
    (user_id, shop_name, identity_number, email, district, radius_km, willing_far, shop_type, brands, coverage_note)
  SELECT id, 'Nadeesha Stores', '851234567V', 'nadeesha@stores.lk', 'Kurunegala', 5, false,
         'Physical shop', 'CIC, Baurs', 'Delivers within 2 km of Mawathagama.'
  FROM users WHERE phone = '0771112233';

  INSERT INTO fertilizer_suppliers
    (user_id, shop_name, identity_number, email, district, radius_km, willing_far, shop_type, brands, coverage_note)
  SELECT u.id, v.shop, v.nic, v.email, v.district, v.radius, v.far, 'Physical shop', v.brands, v.note
  FROM (VALUES
    ('0772100001', 'Colombo Agro Mart', '861234567V', 'ravi@colomboagro.lk', 'Colombo', 5, false, 'CIC, Baurs', 'Near Kaduwela / Colombo estates'),
    ('0772100002', 'Green Leaf Colombo', '871234567V', 'sithara@greenleaf.lk', 'Colombo', 5, false, 'Hayleys', 'Colombo city delivery'),
    ('0772100003', 'CIC Point Colombo', '881234567V', 'nuwan@cicpoint.lk', 'Colombo', 10, true, 'CIC', 'Willing to deliver farther in Western Province'),
    ('0772100004', 'Baurs Depot Colombo', '891234567V', 'malsha@baursdepot.lk', 'Colombo', 5, false, 'Baurs', 'Depot coverage around Colombo'),
    ('0772100005', 'Hayleys Colombo Hub', '901234567V', 'ishara@hayleyshub.lk', 'Colombo', 5, false, 'Hayleys, CIC', 'Hub stock for Colombo estates'),
    ('0772200001', 'Puttalam Fertilizer', '911234567V', 'ajith@puttalamfert.lk', 'Puttalam', 5, false, 'CIC', 'Around Puttalam town'),
    ('0772200002', 'Chilaw Agro', '921234567V', 'dilani@chilawagro.lk', 'Puttalam', 5, false, 'Baurs, Hayleys', 'Chilaw / coastal belt'),
    ('0772200003', 'Coastline Supplies', '931234567V', 'pradeep@coastline.lk', 'Puttalam', 10, true, 'CIC, Hayleys', 'Will travel farther along the coast'),
    ('0772200004', 'Palm Care Puttalam', '941234567V', 'nadeeka@palmcare.lk', 'Puttalam', 5, false, 'Baurs', 'Palm estates near Puttalam'),
    ('0772200005', 'Wennappuwa Agro', '951234567V', 'kasun@wennappuwa.lk', 'Puttalam', 5, false, 'Hayleys', 'Wennappuwa area shops')
  ) AS v(phone, shop, nic, email, district, radius, far, brands, note)
  JOIN users u ON u.phone = v.phone;

  INSERT INTO cdo_officers
    (user_id, identity_number, email, employee_id, designation, regional_office,
     assigned_district, assigned_divisional_areas, id_card_filename, employment_doc_filename)
  SELECT id, '801234567V', 'cdo.mawathagama@ccb.gov.lk', 'CCB-KUR-0142',
         'Coconut Development Officer', 'Kurunegala Regional Office', 'Kurunegala',
         'Mawathagama, Kuliyapitiya, Narammala, Polgahawela, Ibbagamuwa, Wariyapola, Pannala, Alawwa',
         'ccb_id_card.pdf', 'appointment_letter.pdf'
  FROM users WHERE phone = '0372223344';

  INSERT INTO cdo_officers
    (user_id, identity_number, email, employee_id, designation, regional_office,
     assigned_district, assigned_divisional_areas, id_card_filename, employment_doc_filename)
  SELECT id, '821234567V', 'cdo.colombo@ccb.gov.lk', 'CCB-COL-0201',
         'Coconut Development Officer', 'Colombo Regional Office', 'Colombo',
         'Homagama, Kaduwela, Kesbewa, Maharagama, Kolonnawa',
         'ccb_id_card_colombo.pdf', 'appointment_letter_colombo.pdf'
  FROM users WHERE phone = '0772300001';

  INSERT INTO cdo_officers
    (user_id, identity_number, email, employee_id, designation, regional_office,
     assigned_district, assigned_divisional_areas, id_card_filename, employment_doc_filename)
  SELECT id, '831234567V', 'cdo.puttalam@ccb.gov.lk', 'CCB-PUT-0311',
         'Coconut Development Officer', 'Puttalam Regional Office', 'Puttalam',
         'Chilaw, Wennappuwa, Nattandiya, Puttalam, Anamaduwa, Mundalama',
         'ccb_id_card_puttalam.pdf', 'appointment_letter_puttalam.pdf'
  FROM users WHERE phone = '0772300002';
`);

const { Pool } = db.adapters.createPg();

module.exports = new Pool();
module.exports.memoryDb = db;
