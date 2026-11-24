// Why: the CDO has to open the NIC and land-title photos the estate owner uploaded.
// The gov-request table only has text columns for them (nic_copy, land_title_copy), so the
// file name and the image (base64) are kept together in the same column, split by \u0001.
// No schema change is needed. Everything outside this file still sees only the file name.
const SEP = "\u0001";

const packDoc = (name, data) => {
  const n = String(name || "");
  const d = String(data || "");
  return d ? `${n}${SEP}${d}` : n;
};

const unpackDoc = (stored) => {
  const s = String(stored || "");
  const i = s.indexOf(SEP);
  return i < 0 ? { name: s, data: "" } : { name: s.slice(0, i), data: s.slice(i + 1) };
};

// The value to store: the new image if one was sent, otherwise keep the one already saved for the same file.
const mergeDoc = (name, data, previousStored) => {
  if (data) return packDoc(name, data);
  const prev = unpackDoc(previousStored);
  return prev.data && prev.name === String(name || "") ? packDoc(name, prev.data) : String(name || "");
};

module.exports = { packDoc, unpackDoc, mergeDoc };
