const { PrismaClient } = require('@prisma/client');

// One client for the whole process. Creating a client per request exhausts
// PostgreSQL connections very quickly in development and production.
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
});

module.exports = prisma;
