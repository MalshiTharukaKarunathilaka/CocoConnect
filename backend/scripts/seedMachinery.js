// Adds eight sample machines (tractors, hand tractors, backhoes around
// Kurunegala) with made-up providers, so the machinery map has plenty to show.
// It writes to the database in backend/.env, so only run it on purpose.
//
//   cd backend
//   node scripts/seedMachinery.js            add the sample machines
//   node scripts/seedMachinery.js --remove   take them out again
//
// Safe to run twice: providers that are already there are skipped. Only the
// made-up providers (phones 0700900001 to 0700900008) are ever touched, so
// real providers and their machines stay as they are.
require("dotenv").config();
const pool = require("../config/db");
const { seedDemoMachines, removeDemoMachines } = require("../utils/demoMachines");

(async () => {
  try {
    if (process.argv.includes("--remove")) {
      const removed = await removeDemoMachines(pool);
      console.log(removed ? `Removed ${removed} sample providers and their machines` : "No sample machines to remove");
    } else {
      const added = await seedDemoMachines(pool);
      console.log(added ? `Added ${added} sample machines` : "Sample machines are already there");
    }
  } catch (error) {
    console.error("Could not finish:", error.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
})();
