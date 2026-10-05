const app = require('./app');
const prisma = require('./config/prisma');
const { validateRuntimeConfig } = require('./config/env');
const { verifySmtpReachability } = require('./services/email.service');
const cacheCron = require('./cron/cache.cron');
const { initializeSocketIO } = require('./sockets/socket.manager');

const runtimeConfig = validateRuntimeConfig();
runtimeConfig.warnings.forEach((warning) => console.warn(`[configuration] ${warning}`));
if (runtimeConfig.errors.length > 0) {
  runtimeConfig.errors.forEach((error) => console.error(`[configuration] ${error}`));
  process.exit(1);
}

cacheCron.startScheduler({ runOnBoot: false, loud: true });

const http = require('http');
const { Server } = require('socket.io');

const port = Number.parseInt(process.env.PORT, 10) || 3000;
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    credentials: true,
  },
});

initializeSocketIO(io);

server.listen(port, async () => {
  console.log(`Dios Delices API is listening on http://localhost:${port}`);
  console.log(`Swagger UI is available at http://localhost:${port}/api-docs`);
  console.log(`WebSocket server is running`);
  try {
    await verifySmtpReachability({ loud: true });
  } catch (err) {
    console.warn('[email] Diagnostic SMTP ignoré :', err?.message || err);
  }
});

async function shutdown(signal) {
  console.log(`${signal} reçu : arrêt du serveur…`);
  try {
    cacheCron.stopScheduler();
  } catch (_) {}
  server.close(async (error) => {
    try {
      await prisma.$disconnect();
    } finally {
      process.exitCode = error ? 1 : 0;
    }
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
