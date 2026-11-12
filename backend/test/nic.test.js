// Sri Lankan NIC checks used when a service provider registers.
// The same cases as test/sri_lanka_nic_test.dart in the app.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { nicError, normalizeNic, validateProvider } = require("../utils/providerValidation");

const FORMAT = "Enter a valid NIC: 9 digits and V or X (like 821940129V), or 12 digits (like 198219400129).";
const DATE = "This NIC has an invalid birth date. Check the digits.";
const YEAR = "This NIC has an invalid birth year. Check the digits.";

test("old and new format NICs are accepted", () => {
  for (const nic of [
    "821940129V", "821940129v", "853400937 V", "858400937x",
    "198219400129", "200012300045", "199850600123", "840600129V",
  ]) {
    assert.equal(nicError(nic), null, nic);
  }
});

test("wrong shapes are refused", () => {
  assert.equal(nicError(""), "Enter your NIC number.");
  assert.equal(nicError(null), "Enter your NIC number.");
  for (const nic of ["82194012V", "8219401299", "821940129A", "12345", "ABCDEFGHIJKL", "19821940012"]) {
    assert.equal(nicError(nic), FORMAT, nic);
  }
});

test("impossible birth dates are refused", () => {
  for (const nic of ["820000129V", "823670129V", "825000129V", "828670129V", "830600129V"]) {
    assert.equal(nicError(nic), DATE, nic);
  }
});

test("impossible birth years are refused", () => {
  assert.equal(nicError("203012300045"), YEAR);
  assert.equal(nicError("189912300045"), YEAR);
  const now = new Date(2026, 5, 1);
  assert.equal(nicError("201112300045", now), YEAR); // 15 years old
  assert.equal(nicError("201012300045", now), null); // 16
});

test("NICs are stored in capitals without spaces", () => {
  assert.equal(normalizeNic(" 821940129v "), "821940129V");
  assert.equal(normalizeNic("1982 1940 0129"), "198219400129");
});

test("provider registration reports a bad NIC on the NIC field", () => {
  const body = {
    password: "secret123",
    service_provider: {
      identity_number: "12345", category: "Machinery", machinery_type: "Tractor",
      district: "Kurunegala", address: "Yard", radius_km: 10, terms_accepted: true,
    },
  };
  const coords = { lat: 7.4863, lng: 80.3647 };
  const bad = validateProvider(body, "SERVICE_PROVIDER", "0771234567", coords);
  assert.equal(bad.identity_number, FORMAT);
  body.service_provider.identity_number = "821940129v";
  assert.deepEqual(validateProvider(body, "SERVICE_PROVIDER", "0771234567", coords), {});
  body.service_provider.identity_number = 821940129;
  assert.equal(validateProvider(body, "SERVICE_PROVIDER", "0771234567", coords).identity_number, "Enter your NIC number.");
});

test("a lower-case NIC is saved in capitals when a provider registers", async () => {
  process.env.DB_MODE = "memory";
  process.env.JWT_SECRET = process.env.JWT_SECRET || "nic-test-secret";
  const pool = require("../config/db");
  const { signup } = require("../controllers/authController");
  const res = { status(code) { this.code = code; return this; }, json(data) { this.data = data; return this; } };
  await signup({ body: {
    name: "Nimal Provider", phone: "0771239999", password: "secret123", role: "Service Provider",
    location: "Kurunegala", latitude: 7.4863, longitude: 80.3647,
    service_provider: { identity_number: " 821940129v ", category: "Machinery", machinery_type: "Tractor",
      district: "Kurunegala", address: "Yard", radius_km: 10, terms_accepted: true },
  } }, res);
  assert.equal(res.code, 201, JSON.stringify(res.data));
  const saved = await pool.query("SELECT identity_number FROM service_providers WHERE user_id = $1", [res.data.user.id]);
  assert.equal(saved.rows[0].identity_number, "821940129V");
});
