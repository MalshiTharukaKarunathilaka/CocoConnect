// Field-specific validation shared by the signup controller and its tests.
const machineryTypes = ['Tractor', 'Backhoe', 'Hand Tractor'];
const districts = ['Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar', 'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya', 'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'];


// Sri Lankan NIC numbers, old and new format.
//   Old: 9 digits + V or X       YY DDD SSS C V   (YY = birth year 19YY)
//   New: 12 digits               YYYY DDD SSSS C  (YYYY = birth year)
// DDD counts days from 1 January, with 500 added for women. The count treats
// every year as having 366 days, so day 60 (29 Feb) only exists in leap years.
const NIC_FORMAT_MESSAGE =
  'Enter a valid NIC: 9 digits and V or X (like 821940129V), or 12 digits (like 198219400129).';
const isLeapYear = (year) => (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
const MIN_NIC_AGE = 16; // NICs are issued from age 16

/** "821940129v" -> "821940129V". Anything else is only trimmed. */
const normalizeNic = (value) => String(value || '').replace(/\s+/g, '').toUpperCase();

/** null when the NIC is valid, otherwise a message for the person. */
const nicError = (value, now = new Date()) => {
  const nic = normalizeNic(value);
  if (!nic) return 'Enter your NIC number.';
  let year;
  let dayCode;
  if (/^\d{9}[VX]$/.test(nic)) {
    year = 1900 + Number(nic.slice(0, 2));
    dayCode = Number(nic.slice(2, 5));
  } else if (/^\d{12}$/.test(nic)) {
    year = Number(nic.slice(0, 4));
    dayCode = Number(nic.slice(4, 7));
  } else {
    return NIC_FORMAT_MESSAGE;
  }
  const day = dayCode > 500 ? dayCode - 500 : dayCode;
  if (day < 1 || day > 366 || (day === 60 && !isLeapYear(year))) {
    return 'This NIC has an invalid birth date. Check the digits.';
  }
  if (year < 1900 || year > now.getFullYear() - MIN_NIC_AGE) {
    return 'This NIC has an invalid birth year. Check the digits.';
  }
  return null;
};

const validateProvider = (body, role, phone, coords) => {
  const errors = {};
  const provider = body.service_provider;
  if (!provider || typeof provider !== 'object' || Array.isArray(provider)) {
    return {service_provider: 'Machinery registration details are required.'};
  }
  if (role !== 'SERVICE_PROVIDER') errors.role = 'Choose a Service Provider account.';
  if (provider.category !== 'Machinery') errors.category = 'Choose the Machinery service category.';
  if (provider.machinery_type != null && !machineryTypes.includes(provider.machinery_type)) errors.machinery_type = 'Choose Tractor, Backhoe or Hand Tractor.';
  if (!districts.includes(provider.district)) errors.district = 'Select your operating district.';
  if (!/^07\d{8}$/.test(phone)) errors.phone = 'Enter a valid Sri Lankan mobile number, e.g. 0771234567.';
  if (typeof provider.identity_number !== 'string') {
    errors.identity_number = 'Enter your NIC number.';
  } else {
    const problem = nicError(provider.identity_number);
    if (problem) errors.identity_number = problem;
  }
  if (provider.email != null && (typeof provider.email !== 'string' ||
      (provider.email.trim() && (provider.email.trim().length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(provider.email.trim()))))) {
    errors.email = 'Enter a valid email address of at most 254 characters, or leave it blank.';
  }
  if (String(body.password || '').length < 8) errors.password = 'Use at least 8 characters for your password.';
  if (typeof provider.address !== 'string' || !provider.address.trim()) errors.address = 'Enter your base yard or dispatch address.';
  if (!coords) errors.latitude = 'Select your operating base using GPS or the map.';
  if (![5, 10, 15, 25].includes(provider.radius_km)) errors.radius_km = 'Choose a service radius of 5, 10, 15 or 25 km.';
  if (provider.terms_accepted !== true) errors.terms_accepted = 'Please accept the registration agreement.';
  return errors;
};

module.exports = {validateProvider, nicError, normalizeNic};
