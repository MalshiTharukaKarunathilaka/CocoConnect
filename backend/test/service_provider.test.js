const { test } = require('node:test');
const assert = require('node:assert/strict');
process.env.DB_MODE = 'memory';
process.env.JWT_SECRET = 'provider-test-secret';
const pool = require('../config/db');
const { signup, login } = require('../controllers/authController');
const body = {
  name: 'Sunil Mendis', phone: '0771234567', password: 'secret123',
  role: 'Service Provider', location: 'Kurunegala', latitude: 7.4863, longitude: 80.3647,
  service_provider: {identity_number: '821940129V', email: '', category: 'Machinery', machinery_type: 'Tractor', district: 'Kurunegala', address: '42 Dambokka', radius_km: 5, terms_accepted: true}
};
async function call(handler, payload) {
  const res = {status(code) {this.code = code; return this;}, json(data) {this.data = data; return this;}};
  await handler({body: payload}, res);
  return res;
}
test('machinery registration validates details, persists a profile, and allows login', async () => {
  for (const change of [{terms_accepted: false}, {radius_km: 100}, {district: 'Invalid'}, {category: 'Labour'}, {identity_number: ''}, {machinery_type: 'Excavator'}, {machinery_type: 'Rotavator'}]) {
    const bad = await call(signup, {...body, service_provider: {...body.service_provider, ...change}});
    assert.equal(bad.code, 400);
  }
  assert.equal((await pool.query('SELECT id FROM users WHERE phone = $1', [body.phone])).rows.length, 0);
  const created = await call(signup, body);
  assert.equal(created.code, 201, JSON.stringify(created.data));
  assert.deepEqual(created.data.storage, {mode: 'memory', persistent: false});
  const profile = (await pool.query('SELECT * FROM service_providers WHERE user_id = $1', [created.data.user.id])).rows[0];
  assert.equal(profile.machinery_type, 'Tractor');
  assert.equal(profile.radius_km, 5);
  assert.equal(profile.identity_number, '821940129V');
  assert.equal((await call(signup, body)).code, 409);
  const session = await call(login, {phone: body.phone, password: body.password});
  assert.equal(session.code, 200);
  assert.equal(session.data.user.role, 'SERVICE_PROVIDER');
});


test('Backhoe and Hand Tractor providers can register and log in', async () => {
  for (const [index, type] of ['Backhoe', 'Hand Tractor'].entries()) {
    const phone = `077123457${index}`;
    const result = await call(signup, {...body, phone,
      service_provider: {...body.service_provider, machinery_type: type}});
    assert.equal(result.code, 201, JSON.stringify(result.data));
    const profile = (await pool.query('SELECT * FROM service_providers WHERE user_id = $1', [result.data.user.id])).rows[0];
    assert.equal(profile.machinery_type, type);
    assert.equal((await call(login, {phone, password: body.password})).code, 200);
  }
});


test('provider errors identify the invalid field instead of blaming the agreement', async () => {
  const cases = [
    ['district', null, 'Select your operating district.'],
    ['machinery_type', 'Excavator', 'Choose Tractor, Backhoe or Hand Tractor.'],
    ['identity_number', '', 'Enter your NIC or driving license number.'],
    ['identity_number', 'A'.repeat(41), 'NIC or driving license number must be at most 40 characters.'],
    ['email', 'invalid', 'Enter a valid email address of at most 254 characters, or leave it blank.'],
    ['address', '', 'Enter your base yard or dispatch address.'],
    ['radius_km', 12, 'Choose a service radius of 5, 10, 15 or 25 km.'],
    ['terms_accepted', false, 'Please accept the registration agreement.'],
  ];
  for (const [field, value, message] of cases) {
    const result = await call(signup, {...body, service_provider: {...body.service_provider, [field]: value}});
    assert.equal(result.code, 400);
    assert.equal(result.data.message, message);
    assert.equal(result.data.fieldErrors[field], message);
    if (field !== 'terms_accepted') assert.equal(result.data.fieldErrors.terms_accepted, undefined);
  }
});

test('provider international phone format is normalized for registration and login', async () => {
  const phone = '+94 77 123 4599';
  const result = await call(signup, {...body, phone});
  assert.equal(result.code, 201, JSON.stringify(result.data));
  assert.equal(result.data.user.phone, '0771234599');
  assert.equal((await call(login, {phone: '0771234599', password: body.password})).code, 200);
});
