// Preloaded with `node -r` so the memory database works the same way on
// Windows and Mac/Linux shells.
process.env.DB_MODE = "memory";

// Local preview only; production must configure its own JWT_SECRET.
process.env.JWT_SECRET = process.env.JWT_SECRET || "kapconnect-local-memory-preview-only";
