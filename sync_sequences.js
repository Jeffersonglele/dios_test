require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();
  console.log('Syncing PostgreSQL sequences for legacy IDs...');

  const tables = [
    { table: 'categories', idCol: 'categoryId' },
    { table: 'comments', idCol: 'commentId' },
    { table: 'dishes', idCol: 'dishId' },
    { table: 'identities', idCol: 'identityId' },
    { table: 'payment_methods', idCol: 'id_moyen' },
    { table: 'pro_documents', idCol: 'documentId' },
    { table: 'restaurants', idCol: 'restaurantId' },
    { table: 'roles', idCol: 'roleId' },
    { table: 'users', idCol: 'userId' },
    { table: 'auth_users', idCol: 'legacyUserId' },
    { table: 'addresses', idCol: 'addressId' },
    { table: 'cities', idCol: 'cityId' },
    { table: 'delivery_zones', idCol: 'zoneId' },
    { table: 'delivery_configs', idCol: 'configId' },
    { table: 'orders', idCol: 'commande_id' }
  ];

  for (const t of tables) {
    try {
      console.log(`Syncing sequence for ${t.table}.${t.idCol}...`);
      await prisma.$executeRawUnsafe(`
        SELECT setval(
          pg_get_serial_sequence('"${t.table}"', '${t.idCol}'),
          COALESCE((SELECT MAX("${t.idCol}") FROM "${t.table}"), 1),
          (SELECT MAX("${t.idCol}") FROM "${t.table}") IS NOT NULL
        );
      `);
      console.log(`  -> Synced!`);
    } catch (e) {
      console.error(`  -> Error on ${t.table}:`, e.message);
    }
  }

  console.log('Done syncing sequences!');
  await prisma.$disconnect();
}

main();
