// Sri Lankan public holidays and observances, from Google's free public
// holiday calendar (no account or key needed). The server downloads the feed,
// keeps a copy for a day, and falls back to the last good copy if Google
// cannot be reached, so the app's calendars always have something to mark.
const FEED_URL =
  "https://calendar.google.com/calendar/ical/en.lk%23holiday%40group.v.calendar.google.com/public/basic.ics";
const TTL_MS = 24 * 60 * 60 * 1000;
const RETRY_MS = 10 * 60 * 1000; // after a failed download, wait before trying again

let cache = { at: 0, items: [], good: false, failedAt: 0 };
let fetcher = null; // tests replace this

const setFetcher = (fn) => {
  fetcher = fn;
  cache = { at: 0, items: [], good: false, failedAt: 0 };
};

// ICS text escapes commas, semicolons, backslashes and new lines with a backslash.
const unescapeText = (value) =>
  String(value || "")
    .replace(/\\n/gi, "\n")
    .replace(/\\([,;\\])/g, "$1")
    .trim();

const toDay = (yyyymmdd) => `${yyyymmdd.slice(0, 4)}-${yyyymmdd.slice(4, 6)}-${yyyymmdd.slice(6, 8)}`;
const addDay = (day, n) => {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};

/** Turns the text of a Google .ics feed into [{ date, name, type }], sorted by date. */
const parseIcs = (text) => {
  // Long lines are folded onto the next line with a leading space.
  const lines = String(text || "").replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "").split("\n");
  const out = [];
  let ev = null;
  for (const line of lines) {
    if (line === "BEGIN:VEVENT") ev = {};
    else if (line === "END:VEVENT") {
      if (ev && ev.start && ev.name) {
        const type = /^public holiday/i.test(ev.description || "") ? "public" : "observance";
        const last = ev.end && ev.end > ev.start ? addDay(ev.end, -1) : ev.start; // DTEND is the day after
        for (let day = ev.start, guard = 0; day <= last && guard < 14; day = addDay(day, 1), guard++) {
          out.push({ date: day, name: ev.name, type });
        }
      }
      ev = null;
    } else if (ev) {
      const colon = line.indexOf(":");
      if (colon < 0) continue;
      const key = line.slice(0, colon).split(";")[0];
      const value = line.slice(colon + 1);
      if (key === "DTSTART" && /^\d{8}$/.test(value)) ev.start = toDay(value);
      else if (key === "DTEND" && /^\d{8}$/.test(value)) ev.end = toDay(value);
      else if (key === "SUMMARY") ev.name = unescapeText(value);
      else if (key === "DESCRIPTION") ev.description = unescapeText(value);
    }
  }
  return out.sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name));
};

const download = async () => {
  const run = fetcher || ((url) => fetch(url, { signal: AbortSignal.timeout(8000) }));
  const response = await run(FEED_URL);
  if (!response.ok) throw new Error(`Holiday feed answered ${response.status}`);
  return parseIcs(await response.text());
};

/**
 * All holidays, optionally for one year. `stale` is true when Google could not
 * be reached and the last good copy (or nothing) is being served.
 */
const getHolidays = async ({ year, now = Date.now() } = {}) => {
  const fresh = cache.good && now - cache.at < TTL_MS;
  const waiting = cache.failedAt && now - cache.failedAt < RETRY_MS;
  let stale = false;
  if (!fresh && !waiting) {
    try {
      cache = { at: now, items: await download(), good: true, failedAt: 0 };
    } catch (error) {
      console.error("Holiday feed error:", error.message);
      cache = { ...cache, failedAt: now };
      stale = true;
    }
  } else if (!fresh) {
    stale = true;
  }
  const items = year ? cache.items.filter((h) => h.date.startsWith(`${year}-`)) : cache.items;
  return { stale, fetched_at: cache.at ? new Date(cache.at).toISOString() : null, holidays: items };
};

module.exports = { getHolidays, parseIcs, setFetcher, FEED_URL };
