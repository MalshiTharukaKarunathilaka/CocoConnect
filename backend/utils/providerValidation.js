// Field-specific validation shared by the signup controller and its tests.
const machineryTypes = ['Tractor', 'Backhoe', 'Hand Tractor'];
const districts = ['Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar', 'Matale', 'Matara', 'Monaragala', 'Mullaitivu', 'Nuwara Eliya', 'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'];

const validateProvider = (body, role, phone, coords) => {
  const errors = {};
  const provider = body.service_provider;
  if (!provider || typeof provider !== 'object' || Array.isArray(provider)) {
    return {service_provider: 'Machinery registration details are required.'};
  }
  if (role !== 'SERVICE_PROVIDER') errors.role = 'Choose a Service Provider account.';
  if (provider.category !== 'Machinery') errors.category = 'Choose the Machinery service category.';
  if (!machineryTypes.includes(provider.machinery_type)) errors.machinery_type = 'Choose Tractor, Backhoe or Hand Tractor.';
  if (!districts.includes(provider.district)) errors.district = 'Select your operating district.';
  if (!/^07\d{8}$/.test(phone)) errors.phone = 'Enter a valid Sri Lankan mobile number, e.g. 0771234567.';
  if (typeof provider.identity_number !== 'string' || !provider.identity_number.trim()) {
    errors.identity_number = 'Enter your NIC or driving license number.';
  } else if (provider.identity_number.trim().length > 40) {
    errors.identity_number = 'NIC or driving license number must be at most 40 characters.';
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

module.exports = {validateProvider};
