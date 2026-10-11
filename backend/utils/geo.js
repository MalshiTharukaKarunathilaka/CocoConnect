// Distances between users, from the coordinates they pick at sign-up.

/** { lat, lng } from two inputs, or null unless both are valid. */
const parseCoords = (lat, lng) => {
  if (lat === undefined || lat === null || lat === "") return null;
  if (lng === undefined || lng === null || lng === "") return null;
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return null;
  return { lat: latitude, lng: longitude };
};

/** Great-circle distance in km (haversine). */
const distanceKm = (a, b) => {
  const rad = (deg) => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
};

/** A positive radius in km from a query value, or null for "any distance". */
const parseRadius = (value) => {
  const radius = Number(value);
  return Number.isFinite(radius) && radius > 0 ? radius : null;
};

/**
 * Adds distance_km to each row (null when either side has no location) and,
 * with a radius, keeps only rows within it.
 */
const withDistance = (rows, origin, radiusKm) => {
  const measured = rows.map((row) => {
    const point = parseCoords(row.latitude, row.longitude);
    const km = origin && point ? distanceKm(origin, point) : null;
    return { ...row, distance_km: km === null ? null : Math.round(km * 10) / 10 };
  });
  if (!radiusKm || !origin) return measured;
  return measured.filter(
    (row) => row.distance_km !== null && row.distance_km <= radiusKm
  );
};

/** Nearest first; rows without a distance go last. */
const byDistance = (a, b) =>
  (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity);

/** "YYYY-MM-DD" from a pg date (string or Date), for comparing days. */
const dayOf = (value) => {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString().slice(0, 10);
  }
  return String(value).slice(0, 10);
};

/** "YYYY-MM-DD" plus a number of days. */
const addDays = (day, days) => {
  const date = new Date(`${day}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
};

/**
 * When an order is due: the customer's required date for orders from a
 * buyer request, otherwise the listing's (or offer's) available date.
 * Picked in JS: the in-memory test database mixes up COALESCE over dates
 * from several LEFT JOINs.
 */
const dueDateOf = (row) =>
  dayOf(row.br_required_date) ?? dayOf(row.pl_available_date) ?? dayOf(row.sr_available_date);

const DUE_DATE_COLUMNS = `
  br.required_date AS br_required_date,
  pl.available_date AS pl_available_date,
  sr.available_date AS sr_available_date
`;

/** Replaces the three raw date columns with due_date. */
const withDueDate = ({ br_required_date, pl_available_date, sr_available_date, ...row }) => ({
  ...row,
  due_date: dueDateOf({ br_required_date, pl_available_date, sr_available_date }),
});

module.exports = {
  dueDateOf,
  withDueDate,
  DUE_DATE_COLUMNS,
  parseCoords,
  distanceKm,
  parseRadius,
  withDistance,
  byDistance,
  dayOf,
  addDays,
};
