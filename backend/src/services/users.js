const { prisma } = require('../db');
const { sendPush } = require('./push');

function toUser(u) {
  return {
    id: u.id,
    name: u.name,
    phone: u.phone,
    role: u.role,
    status: u.status,
    trustScore: u.trustScore,
    district: u.district,
    estateName: u.estateName,
  };
}

async function notifyUser(userId, title, body) {
  const saved = await prisma.notification.create({
    data: { userId, title, body },
  });
  const user = await prisma.user.findUnique({ where: { id: userId } });
  sendPush(user?.fcmToken, title, body);
  return saved;
}

module.exports = { toUser, notifyUser };
