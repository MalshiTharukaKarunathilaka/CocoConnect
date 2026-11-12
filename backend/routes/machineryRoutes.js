const express = require("express");

const {
  listMachines,
  getMachineSchedule,
  createBooking,
  listMyBookings,
  cancelBooking,
  createMachine,
  updateMachine,
  listMyMachines,
  listProviderBookings,
} = require("../controllers/machineryController");
const { requireAuth, requireAnyRole } = require("../middleware/auth");

const router = express.Router();

const owners = requireAnyRole("ESTATE_OWNER", "ESTATE_MANAGER");
const providers = requireAnyRole("SERVICE_PROVIDER");

// Every route here needs a login.
router.use(requireAuth);

/**
 * @swagger
 * /api/machinery/machines:
 *   get:
 *     summary: Machines on the map, nearest first
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema: { type: string, enum: [TRACTOR, BACKHOE, HAND_TRACTOR] }
 *       - in: query
 *         name: lat
 *         schema: { type: number }
 *         description: Where to measure from (defaults to the account's saved location)
 *       - in: query
 *         name: lng
 *         schema: { type: number }
 *       - in: query
 *         name: radius
 *         schema: { type: number }
 *         description: Only machines within this many km
 *     responses:
 *       200:
 *         description: Active machines with distance_km
 *   post:
 *     summary: A service provider lists a machine
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       201:
 *         description: The new machine
 */
router.get("/machines", listMachines);
router.post("/machines", providers, createMachine);

/**
 * @swagger
 * /api/machinery/machines/mine:
 *   get:
 *     summary: The machines I listed (service providers)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: My machines, including hidden ones
 */
router.get("/machines/mine", providers, listMyMachines);

/**
 * @swagger
 * /api/machinery/machines/{id}:
 *   patch:
 *     summary: Change or hide one of my machines (service providers)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: The updated machine
 */
router.patch("/machines/:id", providers, updateMachine);

/**
 * @swagger
 * /api/machinery/machines/{id}/schedule:
 *   get:
 *     summary: A machine's calendar (confirmed bookings from yesterday on)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Bookings with date, time and services. Prices only on my own.
 */
router.get("/machines/:id/schedule", getMachineSchedule);

/**
 * @swagger
 * /api/machinery/bookings:
 *   get:
 *     summary: My machinery bookings (estate owners)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: My confirmed bookings with the machine
 *   post:
 *     summary: Book a machine once the price is agreed (estate owners)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [machineId, items, agreedTotal, date, time]
 *             properties:
 *               machineId: { type: integer }
 *               items:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     name: { type: string }
 *                     unit: { type: string, enum: [acre, hour, day] }
 *                     qty: { type: number }
 *                     rate: { type: integer }
 *               agreedTotal: { type: integer }
 *               date: { type: string, example: "2026-11-20" }
 *               time: { type: string, example: "06:00 AM" }
 *               estate: { type: string }
 *               chat: { type: array, items: { type: object } }
 *     responses:
 *       201:
 *         description: The booking
 *       409:
 *         description: A service is already booked that day
 */
router.get("/bookings", owners, listMyBookings);
router.post("/bookings", owners, createBooking);

/**
 * @swagger
 * /api/machinery/bookings/{id}/cancel:
 *   patch:
 *     summary: Cancel one of my bookings (estate owners)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: The booking is cancelled
 */
router.patch("/bookings/:id/cancel", owners, cancelBooking);

/**
 * @swagger
 * /api/machinery/provider/bookings:
 *   get:
 *     summary: Bookings on my machines (service providers)
 *     tags: [Machinery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Confirmed bookings on my machines
 */
router.get("/provider/bookings", providers, listProviderBookings);

module.exports = router;
