// Preloaded with `node -r` so the memory database works the same way on
// Windows and Mac/Linux shells.
process.env.DB_MODE = "memory";
// Login tokens need a secret; memory mode works even without a .env file.
process.env.JWT_SECRET = process.env.JWT_SECRET || "local-memory-dev-secret";
