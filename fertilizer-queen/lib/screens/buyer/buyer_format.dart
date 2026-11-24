// Display formatting shared by the buyer screens.

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// 1200 -> "1,200"
String withCommas(num value) {
  final String whole = value.truncate().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  final double cents = (value - value.truncate()).toDouble();
  return cents == 0 ? whole : '$whole${cents.toStringAsFixed(2).substring(1)}';
}

/// 130.0 -> "Rs. 130", 130.5 -> "Rs. 130.50"
String rupees(num value) => 'Rs. ${withCommas(value)}';

/// 2026-07-18 -> "18 Jul 2026"
String shortDate(DateTime? date) =>
    date == null ? '-' : '${date.day} ${_months[date.month - 1]} ${date.year}';

/// 14:05 -> "2:05 PM"
String clockTime(DateTime? time) {
  if (time == null) return '';
  final int hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}
