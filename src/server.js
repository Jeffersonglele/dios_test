const app = require('./app');
const prisma = require('./config/prisma');
const { validateRuntimeConfig } = require('./config/env');
const { verifySmtpReachability } = require('./services/email.service');

const runtimeConfig = validateRuntimeConfig();
runtimeConfig.warnings.forEach((warning) => console.warn(`[configuration] ${warning}`));
if (runtimeConfig.errors.length > 0) {
  runtimeConfig.errors.forEach((error) => console.error(`[configuration] ${error}`));
  process.exit(1);
}

const port = Number.parseInt(process.env.PORT, 10) || 3000;
const server = app.listen(port, async () => {
  console.log(`Dios Delices API is listening on http://localhost:${port}`);
  console.log(`Swagger UI is available at http://localhost:${port}/api-docs`);
  try {
    await verifySmtpReachability({ loud: true });
  } catch (err) {
    console.warn('[email] Diagnostic SMTP ignoré :', err?.message || err);
  }
});

async function shutdown(signal) {
  console.log(`${signal} reçu : arrêt du serveur…`);
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
