const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function seedUser(phone, name, role, status, district, estateName) {
  const existing = await prisma.user.findUnique({ where: { phone } });
  if (existing) return existing;
  return prisma.user.create({
    data: {
      phone,
      name,
      role,
      status,
      district,
      estateName,
      trustScore: 4.8,
    },
  });
}

async function ensureBuyRequest(buyerId, category, data) {
  const existing = await prisma.buyRequest.findFirst({
    where: { buyerId, category, status: { in: ['OPEN', 'MATCHED'] } },
  });
  if (existing) return existing;
  return prisma.buyRequest.create({
    data: { buyerId, category, ...data },
  });
}

async function ensureListing(estateId, category, data) {
  const existing = await prisma.sellListing.findFirst({
    where: { estateId, category, status: 'ACTIVE' },
  });
  if (existing) return existing;
  return prisma.sellListing.create({
    data: { estateId, category, ...data },
  });
}

async function main() {
  const admin = await seedUser('0700000000', 'KapConnect Admin', 'ADMIN', 'VERIFIED', 'Colombo', null);
  const buyer = await seedUser('0771234567', 'Mudalali A', 'BUYER', 'VERIFIED', 'Kurunegala', null);
  const estate = await seedUser(
    '0715550199',
    'ABC Estate Owner',
    'ESTATE',
    'VERIFIED',
    'Kurunegala',
    'ABC Estates'
  );
  await seedUser(
    '0715550200',
    'Green Palms Estate',
    'ESTATE',
    'PENDING',
    'Puttalam',
    'Green Palms'
  );

  await ensureBuyRequest(buyer.id, 'RAW', {
    quantity: 500,
    bidPrice: 85,
    needDate: new Date(Date.now() + 14 * 86400000),
    location: 'Kurunegala town',
    district: 'Kurunegala',
  });

  await ensureBuyRequest(buyer.id, 'DEHUSKED', {
    quantity: 800,
    bidPrice: 135,
    needDate: new Date(Date.now() + 10 * 86400000),
    location: 'Kurunegala processing yard',
    district: 'Kurunegala',
  });

  await ensureBuyRequest(buyer.id, 'HUSKS', {
    quantity: 2500,
    bidPrice: 16,
    needDate: new Date(Date.now() + 12 * 86400000),
    location: 'Kurunegala',
    district: 'Kurunegala',
  });

  await ensureListing(estate.id, 'RAW', {
    quantity: 1000,
    offerPrice: 90,
    availableAt: new Date(Date.now() + 7 * 86400000),
    location: 'ABC Estates',
    district: 'Kurunegala',
    verified: true,
  });

  await ensureListing(estate.id, 'DEHUSKED', {
    quantity: 750,
    offerPrice: 138,
    availableAt: new Date(Date.now() + 5 * 86400000),
    location: 'ABC Estates dehusking unit',
    district: 'Kurunegala',
    verified: true,
  });

  await ensureListing(estate.id, 'HUSKS', {
    quantity: 4000,
    offerPrice: 18,
    availableAt: new Date(Date.now() + 4 * 86400000),
    location: 'ABC Estates',
    district: 'Kurunegala',
    verified: false,
  });

  console.log('KapConnect seed ready. OTP demo code = 123456');
  console.log({
    admin: admin.phone,
    buyer: buyer.phone,
    estate: estate.phone,
    categories: ['RAW', 'DEHUSKED', 'HUSKS'],
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
