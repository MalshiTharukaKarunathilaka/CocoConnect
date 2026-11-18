import '../models.dart';

const worker = Worker(
  name: 'Nihal Bandara',
  district: 'Kurunegala District',
  rating: 4.8,
  ratingCount: 64,
  verified: true,
);

/// Days listed here are shown as holidays and cannot be selected. Edit freely.
final holidays = <DateTime>[
  DateTime(2026, 11, 14),
  DateTime(2026, 11, 15),
  DateTime(2026, 12, 25),
  DateTime(2026, 12, 26),
];

const estates = <Estate>[
  Estate(
    id: 'e1',
    name: 'Green Valley Estate',
    initials: 'GV',
    owner: 'Nimal Perera',
    district: 'Kurunegala District',
    distanceKm: 2.4,
    everyDay: true,
  ),
  Estate(
    id: 'e2',
    name: 'Sunrise Plantation',
    initials: 'SP',
    owner: 'Kamal Silva',
    district: 'Kurunegala District',
    distanceKm: 4.1,
    everyDay: false, // only publishes jobs on even dates in this demo
  ),
];

const jobs = <Job>[
  Job(
    id: 'j1',
    estateId: 'e1',
    category: JobCategory.general,
    title: 'Manual Worker',
    description: 'Help with general estate work, clearing and daily maintenance.',
    rate: 2200,
    capacity: 10,
    baseAccepted: 3,
    duration: 'Full day',
  ),
  Job(
    id: 'j2',
    estateId: 'e1',
    category: JobCategory.nut,
    title: 'Nut gatherer',
    description: 'Gather fallen coconuts and sort them for collection.',
    rate: 2800,
    capacity: 8,
    baseAccepted: 6,
    duration: 'Full day',
  ),
  Job(
    id: 'j3',
    estateId: 'e2',
    category: JobCategory.machine,
    title: 'Machine Operator',
    description: 'Operate the estate tractor for hauling and ground preparation.',
    rate: 3500,
    capacity: 3,
    baseAccepted: 1,
    duration: 'Full day',
  ),
  Job(
    id: 'j4',
    estateId: 'e2',
    category: JobCategory.general,
    title: 'Manual Worker',
    description: 'Weeding, pruning support and loading of harvested produce.',
    rate: 2400,
    capacity: 6,
    baseAccepted: 2,
    duration: 'Full day',
  ),
];

Estate getEstate(String id) => estates.firstWhere((e) => e.id == id);
Job getJob(String id) => jobs.firstWhere((j) => j.id == id);
List<Job> jobsForEstate(String estateId) =>
    jobs.where((j) => j.estateId == estateId).toList();
List<JobCategory> categoriesForEstate(String estateId) =>
    jobsForEstate(estateId).map((j) => j.category).toSet().toList();

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dateOnly(DateTime.now());

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String formatDMY(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

bool isHoliday(DateTime d) => holidays.any((h) => dateOnly(h) == dateOnly(d));

/// Selectable: today or later, not a holiday, not a Sunday.
bool isDateAvailable(DateTime d) =>
    !isHoliday(d) &&
    !dateOnly(d).isBefore(today()) &&
    d.weekday != DateTime.sunday;

/// Estates that published jobs for [d], optionally filtered by [category].
List<Estate> estatesForDate(DateTime d, [JobCategory? category]) {
  if (!isDateAvailable(d)) return [];
  return estates
      .where((e) => e.everyDay || d.day.isEven)
      .where((e) =>
          category == null ||
          jobsForEstate(e.id).any((j) => j.category == category))
      .toList();
}
