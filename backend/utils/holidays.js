// Approved Sri Lankan public holidays shown by the app's calendars.
// The supplied third table duplicated 2027, so the approved years are 2026
// and 2027. Dates outside this list are intentionally not marked as holidays.
const APPROVED_HOLIDAYS = Object.freeze([
  { date: "2026-01-03", name: "Duruthu Full Moon Poya Day", type: "public" },
  { date: "2026-01-15", name: "Tamil Thai Pongal Day", type: "public" },
  { date: "2026-02-01", name: "Navam Full Moon Poya Day", type: "public" },
  { date: "2026-02-04", name: "Independence Day", type: "public" },
  { date: "2026-02-15", name: "Maha Sivarathri Day", type: "public" },
  { date: "2026-03-02", name: "Medin Full Moon Poya Day", type: "public" },
  { date: "2026-03-21", name: "Id-Ul-Fitre / Ramazan Festival Day", type: "public" },
  { date: "2026-04-01", name: "Bak Full Moon Poya Day", type: "public" },
  { date: "2026-04-03", name: "Good Friday", type: "public" },
  { date: "2026-04-13", name: "Day Prior to Sinhala & Tamil New Year", type: "public" },
  { date: "2026-04-14", name: "Sinhala & Tamil New Year Day", type: "public" },
  { date: "2026-05-01", name: "Vesak Full Moon Poya Day", type: "public" },
  { date: "2026-05-01", name: "May Day", type: "public" },
  { date: "2026-05-02", name: "Day Following Vesak Full Moon Poya Day", type: "public" },
  { date: "2026-05-28", name: "Id-Ul-Alha / Hadji Festival Day", type: "public" },
  { date: "2026-05-30", name: "Adhi Poson Full Moon Poya Day", type: "public" },
  { date: "2026-06-29", name: "Poson Full Moon Poya Day", type: "public" },
  { date: "2026-07-29", name: "Esala Full Moon Poya Day", type: "public" },
  { date: "2026-08-26", name: "Milad-Un-Nabi / Holy Prophet's Birthday", type: "public" },
  { date: "2026-08-27", name: "Nikini Full Moon Poya Day", type: "public" },
  { date: "2026-09-26", name: "Binara Full Moon Poya Day", type: "public" },
  { date: "2026-10-25", name: "Vap Full Moon Poya Day", type: "public" },
  { date: "2026-11-08", name: "Deepawali Festival Day", type: "public" },
  { date: "2026-11-24", name: "Il Full Moon Poya Day", type: "public" },
  { date: "2026-12-23", name: "Unduvap Full Moon Poya Day", type: "public" },
  { date: "2026-12-25", name: "Christmas Day", type: "public" },

  { date: "2027-01-15", name: "Tamil Thai Pongal Day", type: "public" },
  { date: "2027-01-22", name: "Duruthu Full Moon Poya Day", type: "public" },
  { date: "2027-02-04", name: "Independence Day", type: "public" },
  { date: "2027-02-20", name: "Navam Full Moon Poya Day", type: "public" },
  { date: "2027-03-06", name: "Maha Sivarathri Day", type: "public" },
  { date: "2027-03-10", name: "Id-Ul-Fitre / Ramazan Festival Day", type: "public" },
  { date: "2027-03-22", name: "Medin Full Moon Poya Day", type: "public" },
  { date: "2027-03-26", name: "Good Friday", type: "public" },
  { date: "2027-04-13", name: "Day Prior to Sinhala & Tamil New Year", type: "public" },
  { date: "2027-04-14", name: "Sinhala & Tamil New Year Day", type: "public" },
  { date: "2027-04-20", name: "Bak Full Moon Poya Day", type: "public" },
  { date: "2027-05-01", name: "May Day", type: "public" },
  { date: "2027-05-17", name: "Id-Ul-Alha / Hadji Festival Day", type: "public" },
  { date: "2027-05-19", name: "Vesak Full Moon Poya Day", type: "public" },
  { date: "2027-05-20", name: "Day Following Vesak Full Moon Poya Day", type: "public" },
  { date: "2027-06-18", name: "Poson Full Moon Poya Day", type: "public" },
  { date: "2027-07-18", name: "Esala Full Moon Poya Day", type: "public" },
  { date: "2027-08-15", name: "Milad-Un-Nabi / Holy Prophet's Birthday", type: "public" },
  { date: "2027-08-16", name: "Nikini Full Moon Poya Day", type: "public" },
  { date: "2027-09-15", name: "Binara Full Moon Poya Day", type: "public" },
  { date: "2027-10-15", name: "Vap Full Moon Poya Day", type: "public" },
  { date: "2027-10-28", name: "Deepawali Festival Day", type: "public" },
  { date: "2027-11-13", name: "Il Full Moon Poya Day", type: "public" },
  { date: "2027-12-13", name: "Unduvap Full Moon Poya Day", type: "public" },
  { date: "2027-12-25", name: "Christmas Day", type: "public" },
]);

const getHolidays = async ({ year } = {}) => {
  const holidays = year
    ? APPROVED_HOLIDAYS.filter((holiday) => holiday.date.startsWith(`${year}-`))
    : [...APPROVED_HOLIDAYS];
  return { stale: false, fetched_at: null, holidays };
};

module.exports = { getHolidays, APPROVED_HOLIDAYS };
