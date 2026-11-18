const { test } = require('node:test');
const assert = require('node:assert/strict');
process.env.DB_MODE = 'memory';
process.env.JWT_SECRET = 'fertilizer-roles-test-secret';

const pool = require('../config/db');
const {
  signup,
  login,
  me,
  getSupplierProfile,
  updateSupplierProfile,
  getCdoProfile,
  listCdoDistrictMeta,
} = require('../controllers/authController');

async function call(handler, { body = {}, user } = {}) {
  const req = { body, user };
  const res = {
    status(code) {
      this.code = code;
      return this;
    },
    json(data) {
      this.data = data;
      return this;
    },
  };
  await handler(req, res);
  return res;
}

test('supplier registration stores fertilizer_suppliers row and role', async () => {
  const phone = '0773001001';
  const body = {
    name: 'Amal Shop Agent',
    phone,
    password: 'password1',
    role: 'Supplier',
    location: 'Mawathagama',
    latitude: 7.5,
    longitude: 80.35,
    fertilizer_supplier: {
      shop_name: 'Amal Agro',
      identity_number: '851234567V',
      email: 'amal@agro.lk',
      district: 'Kurunegala',
      radius_km: 5,
      willing_far: true,
      shop_type: 'Physical shop',
      brands: 'CIC, Baurs',
      coverage_note: 'Delivers within 5 km',
      terms_accepted: true,
    },
  };
  const created = await call(signup, { body });
  assert.equal(created.code, 201, JSON.stringify(created.data));
  assert.equal(created.data.user.role, 'FERTILIZER_SUPPLIER');
  assert.equal(created.data.fertilizer_supplier.shop_name, 'Amal Agro');
  assert.equal(created.data.fertilizer_supplier.willing_far, true);

  const row = (
    await pool.query(
      'SELECT * FROM fertilizer_suppliers WHERE user_id = $1',
      [created.data.user.id]
    )
  ).rows[0];
  assert.equal(row.radius_km, 5);

  const session = await call(login, {
    body: { phone, password: 'password1' },
  });
  assert.equal(session.code, 200);
  assert.equal(session.data.user.role, 'FERTILIZER_SUPPLIER');

  const profile = await call(getSupplierProfile, {
    user: { id: created.data.user.id, role: 'FERTILIZER_SUPPLIER' },
  });
  assert.equal(profile.code, 200);
  assert.equal(profile.data.shop_name, 'Amal Agro');

  const patched = await call(updateSupplierProfile, {
    user: { id: created.data.user.id, role: 'FERTILIZER_SUPPLIER' },
    body: {
      agent_name: 'Amal Updated',
      phone,
      willing_far: false,
      coverage_note: 'Only near shop',
    },
  });
  assert.equal(patched.code, 200, JSON.stringify(patched.data));
  assert.equal(patched.data.fertilizer_supplier.willing_far, false);
});

test('cdo registration stores cdo_officers and district areas meta', async () => {
  const phone = '0773002002';
  const body = {
    name: 'Saman CDO',
    phone,
    password: 'password1',
    role: 'CDO',
    location: 'Kurunegala',
    latitude: 7.48,
    longitude: 80.36,
    cdo: {
      identity_number: '801234567V',
      email: 'saman.cdo@ccb.gov.lk',
      employee_id: 'CCB-KUR-2099',
      designation: 'Coconut Development Officer',
      regional_office: 'Kurunegala Regional Office',
      assigned_district: 'Kurunegala',
      assigned_divisional_areas:
        'Mawathagama, Kuliyapitiya, Narammala, Polgahawela, Ibbagamuwa, Wariyapola, Pannala, Alawwa',
      id_card_filename: 'ccb_id_card.pdf',
      employment_doc_filename: 'appointment_letter.pdf',
      terms_accepted: true,
    },
  };
  const created = await call(signup, { body });
  assert.equal(created.code, 201, JSON.stringify(created.data));
  assert.equal(created.data.user.role, 'CDO');
  assert.match(created.data.cdo.assigned_divisional_areas, /Mawathagama/);

  const meta = await call(listCdoDistrictMeta);
  assert.equal(meta.code, 200);
  assert.ok(meta.data.areas_by_district.Kurunegala.includes('Kuliyapitiya'));

  const profile = await call(getCdoProfile, {
    user: { id: created.data.user.id, role: 'CDO' },
  });
  assert.equal(profile.code, 200);
  assert.equal(profile.data.employee_id, 'CCB-KUR-2099');

  const current = await call(me, {
    user: { id: created.data.user.id, role: 'CDO' },
  });
  assert.equal(current.code, 200);
  assert.equal(current.data.cdo.designation, 'Coconut Development Officer');
});
