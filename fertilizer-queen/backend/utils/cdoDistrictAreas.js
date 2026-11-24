// District → CCB divisional / DS areas used to auto-fill CDO registration.
// Keep in sync with lib/utils/cdo_district_areas.dart

const districts = [
  'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo', 'Galle',
  'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara', 'Kandy', 'Kegalle',
  'Kilinochchi', 'Kurunegala', 'Mannar', 'Matale', 'Matara', 'Monaragala',
  'Mullaitivu', 'Nuwara Eliya', 'Polonnaruwa', 'Puttalam', 'Ratnapura',
  'Trincomalee', 'Vavuniya',
];

const regionalOffices = [
  'Kurunegala Regional Office',
  'Puttalam Regional Office',
  'Gampaha Regional Office',
  'Colombo Regional Office',
  'Galle Regional Office',
  'Hambantota Regional Office',
  'Anuradhapura Regional Office',
  'Polonnaruwa Regional Office',
  'Kandy Regional Office',
  'Batticaloa Regional Office',
  'Jaffna Regional Office',
  'Ratnapura Regional Office',
];

/** @type {Record<string, string[]>} */
const areasByDistrict = {
  Kurunegala: [
    'Mawathagama',
    'Kuliyapitiya',
    'Narammala',
    'Polgahawela',
    'Ibbagamuwa',
    'Wariyapola',
    'Pannala',
    'Alawwa',
  ],
  Puttalam: [
    'Chilaw',
    'Wennappuwa',
    'Nattandiya',
    'Puttalam',
    'Anamaduwa',
    'Mundalama',
  ],
  Gampaha: [
    'Negombo',
    'Minuwangoda',
    'Divulapitiya',
    'Mirigama',
    'Gampaha',
    'Ja-Ela',
  ],
  Colombo: [
    'Homagama',
    'Kaduwela',
    'Kesbewa',
    'Maharagama',
    'Kolonnawa',
  ],
  Galle: ['Galle', 'Habaraduwa', 'Akmeemana', 'Baddegama', 'Elpitiya'],
  Hambantota: ['Hambantota', 'Tangalle', 'Ambalantota', 'Beliatta', 'Tissamaharama'],
  Anuradhapura: [
    'Anuradhapura',
    'Thambuttegama',
    'Kekirawa',
    'Nochchiyagama',
    'Medawachchiya',
  ],
  Polonnaruwa: ['Polonnaruwa', 'Hingurakgoda', 'Dimbulagala', 'Lankapura'],
  Kandy: ['Kandy', 'Akurana', 'Harispattuwa', 'Pathadumbara', 'Udunuwara'],
  Matale: ['Matale', 'Dambulla', 'Galewela', 'Ukuwela'],
  Kegalle: ['Kegalle', 'Mawanella', 'Rambukkana', 'Warakapola'],
  Kalutara: ['Kalutara', 'Panadura', 'Horana', 'Beruwala', 'Matugama'],
  Ratnapura: ['Ratnapura', 'Embilipitiya', 'Balangoda', 'Eheliyagoda'],
  Badulla: ['Badulla', 'Bandarawela', 'Mahiyanganaya', 'Welimada'],
  Monaragala: ['Monaragala', 'Wellawaya', 'Bibile', 'Buttala'],
  Matara: ['Matara', 'Weligama', 'Akuressa', 'Hakmana'],
  Ampara: ['Ampara', 'Kalmunai', 'Akkaraipattu', 'Sainthamaruthu'],
  Batticaloa: ['Batticaloa', 'Eravur', 'Kattankudy', 'Valachchenai'],
  Trincomalee: ['Trincomalee', 'Kinniya', 'Mutur', 'Kuchchaveli'],
  Jaffna: ['Jaffna', 'Nallur', 'Chavakachcheri', 'Point Pedro'],
  Kilinochchi: ['Kilinochchi', 'Poonakary', 'Karachchi'],
  Mannar: ['Mannar', 'Nanattan', 'Musali'],
  Mullaitivu: ['Mullaitivu', 'Oddusuddan', 'Puthukkudiyiruppu'],
  Vavuniya: ['Vavuniya', 'Vavuniya South', 'Vengalacheddikulam'],
  'Nuwara Eliya': ['Nuwara Eliya', 'Hatton', 'Walapane', 'Hanguranketha'],
};

const areasForDistrict = (district) => {
  const list = areasByDistrict[String(district || '').trim()];
  return Array.isArray(list) ? [...list] : [];
};

const formatAreas = (district) => areasForDistrict(district).join(', ');

module.exports = {
  districts,
  regionalOffices,
  areasByDistrict,
  areasForDistrict,
  formatAreas,
};
