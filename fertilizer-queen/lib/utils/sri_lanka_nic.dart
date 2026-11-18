/// Sri Lankan NIC numbers, old and new format. The same rules as
/// backend/utils/providerValidation.js, so the app and the server agree.
///
///   Old: 9 digits + V or X       YY DDD SSS C V   (YY = birth year 19YY)
///   New: 12 digits               YYYY DDD SSSS C  (YYYY = birth year)
///
/// DDD counts days from 1 January, with 500 added for women. The count treats
/// every year as having 366 days, so day 60 (29 Feb) only exists in leap years.
const String nicFormatMessage =
    'Enter a valid NIC: 9 digits and V or X (like 821940129V), or 12 digits '
    '(like 198219400129).';

/// NICs are issued from age 16.
const int minNicAge = 16;

bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// "821940129v" -> "821940129V". Spaces are removed.
String normalizeNic(String? value) =>
    (value ?? '').replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Null when the NIC is valid, otherwise a message for the person.
String? nicError(String? value, {DateTime? now}) {
  final String nic = normalizeNic(value);
  if (nic.isEmpty) return 'Enter your NIC number.';
  final int year;
  final int dayCode;
  if (RegExp(r'^\d{9}[VX]$').hasMatch(nic)) {
    year = 1900 + int.parse(nic.substring(0, 2));
    dayCode = int.parse(nic.substring(2, 5));
  } else if (RegExp(r'^\d{12}$').hasMatch(nic)) {
    year = int.parse(nic.substring(0, 4));
    dayCode = int.parse(nic.substring(4, 7));
  } else {
    return nicFormatMessage;
  }
  final int day = dayCode > 500 ? dayCode - 500 : dayCode;
  if (day < 1 || day > 366 || (day == 60 && !_isLeapYear(year))) {
    return 'This NIC has an invalid birth date. Check the digits.';
  }
  final int thisYear = (now ?? DateTime.now()).year;
  if (year < 1900 || year > thisYear - minNicAge) {
    return 'This NIC has an invalid birth year. Check the digits.';
  }
  return null;
}
