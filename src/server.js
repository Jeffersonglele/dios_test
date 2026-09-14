const app = require('./app');
const prisma = require('./config/prisma');

const port = Number.parseInt(process.env.PORT, 10) || 3000;
const server = app.listen(port, () => {
  console.log(`Dios Delices API is listening on http://localhost:${port}`);
  console.log(`Swagger UI is available at http://localhost:${port}/api-docs`);
});

async function shutdown(signal) {
  console.log(`${signal} reçu : arrêt du serveur…`);
  server.close(async () => {
    await prisma.$disconnect();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
