const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  console.log('Enabling PostGIS extension via Prisma...');
  
  try {
    await prisma.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS postgis;');
    console.log('PostGIS extension enabled!');
  } catch (err) {
    console.error('Error enabling PostGIS:', err);
  } finally {
    await prisma.$disconnect();
  }
}

main();
