const { nicError, normalizeNic } = require('./providerValidation');
const {
  districts,
  regionalOffices,
  formatAreas,
} = require('./cdoDistrictAreas');

const supplierRadii = [1, 5, 10];
const shopTypes = ['Physical shop', 'Delivery-only'];

const emailOk = (value, { required = false } = {}) => {
  const email = String(value || '').trim();
  if (!email) return required ? 'Enter a valid email address.' : null;
  if (
    email.length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    return 'Enter a valid email address.';
  }
  return null;
};

const validateFertilizerSupplier = (body, role, phone, coords) => {
  const errors = {};
  const supplier = body.fertilizer_supplier;
  if (!supplier || typeof supplier !== 'object' || Array.isArray(supplier)) {
    return { fertilizer_supplier: 'Supplier registration details are required.' };
  }
  if (role !== 'FERTILIZER_SUPPLIER') {
    errors.role = 'Choose a Supplier account.';
  }
  if (!/^07\d{8}$/.test(phone)) {
    errors.phone = 'Enter a valid Sri Lankan mobile number, e.g. 0771234567.';
  }
  if (!coords) {
    errors.latitude = 'Select your shop location on the map.';
  }
  if (String(body.password || '').length < 8) {
    errors.password = 'Use at least 8 characters for your password.';
  }
  const shopName = String(supplier.shop_name || '').trim();
  if (!shopName) errors.shop_name = 'Enter your shop name.';
  if (typeof supplier.identity_number !== 'string') {
    errors.identity_number = 'Enter your NIC number.';
  } else {
    const problem = nicError(supplier.identity_number);
    if (problem) errors.identity_number = problem;
  }
  const emailProblem = emailOk(supplier.email);
  if (emailProblem) errors.email = emailProblem;
  if (!districts.includes(supplier.district)) {
    errors.district = 'Select your operating district.';
  }
  if (!supplierRadii.includes(supplier.radius_km)) {
    errors.radius_km = 'Choose a service radius of 1, 5 or 10 km.';
  }
  if (
    supplier.shop_type != null &&
    !shopTypes.includes(supplier.shop_type)
  ) {
    errors.shop_type = 'Choose Physical shop or Delivery-only.';
  }
  if (supplier.terms_accepted !== true) {
    errors.terms_accepted = 'Please accept the registration agreement.';
  }
  if (typeof supplier.willing_far !== 'boolean') {
    errors.willing_far = 'Set whether you are willing to deliver far.';
  }
  return errors;
};

const validateCdo = (body, role, phone, coords) => {
  const errors = {};
  const cdo = body.cdo;
  if (!cdo || typeof cdo !== 'object' || Array.isArray(cdo)) {
    return { cdo: 'CDO registration details are required.' };
  }
  if (role !== 'CDO') errors.role = 'Choose a CDO account.';
  if (!/^07\d{8}$/.test(phone)) {
    errors.phone = 'Enter a valid Sri Lankan mobile number, e.g. 0771234567.';
  }
  if (!coords) {
    errors.latitude = 'Select your office location on the map.';
  }
  if (String(body.password || '').length < 8) {
    errors.password = 'Use at least 8 characters for your password.';
  }
  if (typeof cdo.identity_number !== 'string') {
    errors.identity_number = 'Enter your NIC number.';
  } else {
    const problem = nicError(cdo.identity_number);
    if (problem) errors.identity_number = problem;
  }
  const emailProblem = emailOk(cdo.email, { required: true });
  if (emailProblem) errors.email = emailProblem;
  if (!String(cdo.employee_id || '').trim()) {
    errors.employee_id = 'Enter your CCB employee ID.';
  }
  if (!String(cdo.designation || '').trim()) {
    errors.designation = 'Enter your designation.';
  }
  if (!regionalOffices.includes(cdo.regional_office)) {
    errors.regional_office = 'Select your regional office.';
  }
  if (!districts.includes(cdo.assigned_district)) {
    errors.assigned_district = 'Select your assigned district.';
  }
  const expectedAreas = formatAreas(cdo.assigned_district);
  const areas = String(cdo.assigned_divisional_areas || '').trim();
  if (!areas) {
    errors.assigned_divisional_areas =
      'Assigned divisional areas are required for the selected district.';
  } else if (expectedAreas && areas !== expectedAreas) {
    // Allow the auto-filled list; also allow a non-empty custom edit that
    // still mentions at least one known area for that district.
    const known = expectedAreas.split(', ');
    const hasKnown = known.some((a) => areas.includes(a));
    if (!hasKnown) {
      errors.assigned_divisional_areas =
        'Choose a district so divisional areas can be filled correctly.';
    }
  }
  if (!String(cdo.id_card_filename || '').trim()) {
    errors.id_card_filename = 'Upload your official CCB ID card.';
  }
  if (!String(cdo.employment_doc_filename || '').trim()) {
    errors.employment_doc_filename =
      'Upload your appointment letter or employment confirmation.';
  }
  if (cdo.terms_accepted !== true) {
    errors.terms_accepted = 'Please accept the registration agreement.';
  }
  return errors;
};

module.exports = {
  supplierRadii,
  shopTypes,
  validateFertilizerSupplier,
  validateCdo,
  normalizeNic,
};
