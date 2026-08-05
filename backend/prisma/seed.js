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
  // Sample pending estate so admin Verification queue is not empty on first run
  await seedUser(
    '0715550200',
    'Green Palms Estate',
    'ESTATE',
    'PENDING',
    'Puttalam',
    'Green Palms'
  );

  if ((await prisma.buyRequest.count()) === 0) {
    await prisma.buyRequest.create({
      data: {
        buyerId: buyer.id,
        category: 'RAW',
        quantity: 500,
        bidPrice: 85,
        needDate: new Date(Date.now() + 14 * 86400000),
        location: 'Kurunegala town',
        district: 'Kurunegala',
      },
    });
  }

  if ((await prisma.sellListing.count()) === 0) {
    await prisma.sellListing.create({
      data: {
        estateId: estate.id,
        category: 'RAW',
        quantity: 1000,
        offerPrice: 90,
        availableAt: new Date(Date.now() + 7 * 86400000),
        location: 'ABC Estates',
        district: 'Kurunegala',
        verified: true,
      },
    });
  }

  console.log('KapConnect seed users ready. OTP demo code = 123456');
  console.log({ admin: admin.phone, buyer: buyer.phone, estate: estate.phone });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
