/// District → CDO divisional areas for CDO registration auto-fill.
/// Keep in sync with backend/utils/cdoDistrictAreas.js
const List<String> kCdoRegionalOffices = [
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

const Map<String, List<String>> kCdoAreasByDistrict = {
  'Kurunegala': [
    'Mawathagama',
    'Kuliyapitiya',
    'Narammala',
    'Polgahawela',
    'Ibbagamuwa',
    'Wariyapola',
    'Pannala',
    'Alawwa',
  ],
  'Puttalam': [
    'Chilaw',
    'Wennappuwa',
    'Nattandiya',
    'Puttalam',
    'Anamaduwa',
    'Mundalama',
  ],
  'Gampaha': [
    'Negombo',
    'Minuwangoda',
    'Divulapitiya',
    'Mirigama',
    'Gampaha',
    'Ja-Ela',
  ],
  'Colombo': ['Homagama', 'Kaduwela', 'Kesbewa', 'Maharagama', 'Kolonnawa'],
  'Galle': ['Galle', 'Habaraduwa', 'Akmeemana', 'Baddegama', 'Elpitiya'],
  'Hambantota': [
    'Hambantota',
    'Tangalle',
    'Ambalantota',
    'Beliatta',
    'Tissamaharama',
  ],
  'Anuradhapura': [
    'Anuradhapura',
    'Thambuttegama',
    'Kekirawa',
    'Nochchiyagama',
    'Medawachchiya',
  ],
  'Polonnaruwa': ['Polonnaruwa', 'Hingurakgoda', 'Dimbulagala', 'Lankapura'],
  'Kandy': ['Kandy', 'Akurana', 'Harispattuwa', 'Pathadumbara', 'Udunuwara'],
  'Matale': ['Matale', 'Dambulla', 'Galewela', 'Ukuwela'],
  'Kegalle': ['Kegalle', 'Mawanella', 'Rambukkana', 'Warakapola'],
  'Kalutara': ['Kalutara', 'Panadura', 'Horana', 'Beruwala', 'Matugama'],
  'Ratnapura': ['Ratnapura', 'Embilipitiya', 'Balangoda', 'Eheliyagoda'],
  'Badulla': ['Badulla', 'Bandarawela', 'Mahiyanganaya', 'Welimada'],
  'Monaragala': ['Monaragala', 'Wellawaya', 'Bibile', 'Buttala'],
  'Matara': ['Matara', 'Weligama', 'Akuressa', 'Hakmana'],
  'Ampara': ['Ampara', 'Kalmunai', 'Akkaraipattu', 'Sainthamaruthu'],
  'Batticaloa': ['Batticaloa', 'Eravur', 'Kattankudy', 'Valachchenai'],
  'Trincomalee': ['Trincomalee', 'Kinniya', 'Mutur', 'Kuchchaveli'],
  'Jaffna': ['Jaffna', 'Nallur', 'Chavakachcheri', 'Point Pedro'],
  'Kilinochchi': ['Kilinochchi', 'Poonakary', 'Karachchi'],
  'Mannar': ['Mannar', 'Nanattan', 'Musali'],
  'Mullaitivu': ['Mullaitivu', 'Oddusuddan', 'Puthukkudiyiruppu'],
  'Vavuniya': ['Vavuniya', 'Vavuniya South', 'Vengalacheddikulam'],
  'Nuwara Eliya': ['Nuwara Eliya', 'Hatton', 'Walapane', 'Hanguranketha'],
};

List<String> cdoAreasForDistrict(String? district) {
  if (district == null) return const [];
  return List<String>.from(kCdoAreasByDistrict[district] ?? const []);
}

String formatCdoAreas(String? district) =>
    cdoAreasForDistrict(district).join(', ');
