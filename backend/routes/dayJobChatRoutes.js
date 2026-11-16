const express = require("express");
const { requireAuth } = require("../middleware/auth");
const {
  createChat,
  getChats,
  getChat,
  sendMessage,
} = require("../controllers/dayJobChatController");

const router = express.Router();
router.use(requireAuth);
router.get("/day-job-chats", getChats);
router.post("/day-job-chats", createChat);
router.get("/day-job-chats/:id", getChat);
router.post("/day-job-chats/:id/messages", sendMessage);

module.exports = router;
