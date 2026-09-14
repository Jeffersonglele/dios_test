const prisma = require('../config/prisma');

async function getHealth() {
  try {
    await prisma.$queryRawUnsafe('SELECT 1');
    return { status: 'ok', database: 'connected', timestamp: new Date().toISOString() };
  } catch (_) {
    return { status: 'degraded', database: 'unavailable', timestamp: new Date().toISOString() };
  }
}

module.exports = { getHealth };
