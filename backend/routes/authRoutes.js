const express = require("express");

const { signup, login, me, updateMe } = require("../controllers/authController");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

/**
 * @swagger
 * /api/auth/signup:
 *   post:
 *     summary: Create an account (any role)
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SignupInput'
 *     responses:
 *       201:
 *         description: Account created; returns a token and the user
 *       400:
 *         description: Missing or invalid fields
 *       409:
 *         description: Phone number already registered
 */
router.post("/signup", signup);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Log in with phone and password
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/LoginInput'
 *     responses:
 *       200:
 *         description: Logged in; returns a token and the user
 *       401:
 *         description: Incorrect phone number or password
 */
router.post("/login", login);

/**
 * @swagger
 * /api/auth/me:
 *   get:
 *     summary: Get the logged-in user
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: The current user
 *       401:
 *         description: Login required
 */
router.get("/me", requireAuth, me);

/**
 * @swagger
 * /api/auth/me:
 *   patch:
 *     summary: Update my name and location
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name: { type: string, example: "Senuji Perera" }
 *               location: { type: string, example: "Kandy" }
 *     responses:
 *       200:
 *         description: Updated user
 *       400:
 *         description: Name is required
 */
router.patch("/me", requireAuth, updateMe);

module.exports = router;
