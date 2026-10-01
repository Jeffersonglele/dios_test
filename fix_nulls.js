require('dotenv').config();
const { Client } = require('pg');

async function main() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });
  
  await client.connect();
  console.log('Connected to DB. Fixing NULL legacy IDs...');

  const tables = [
    { table: 'categories', idCol: 'categoryId', pk: 'id' },
    { table: 'comments', idCol: 'commentId', pk: 'id' },
    { table: 'dishes', idCol: 'dishId', pk: 'id' },
    { table: 'identities', idCol: 'identityId', pk: 'id' },
    { table: 'payment_methods', idCol: 'id_moyen', pk: 'id' },
    { table: 'pro_documents', idCol: 'documentId', pk: 'id' },
    { table: 'restaurants', idCol: 'restaurantId', pk: 'id' },
    { table: 'roles', idCol: 'roleId', pk: 'id' },
    { table: 'users', idCol: 'userId', pk: 'id' }
  ];

  for (const t of tables) {
    console.log(`Processing table ${t.table}...`);
    // Find rows with null legacy ID
    const resNulls = await client.query(`SELECT "${t.pk}" FROM "${t.table}" WHERE "${t.idCol}" IS NULL`);
    const rowsWithNull = resNulls.rows;
    
    if (rowsWithNull.length > 0) {
      console.log(`  Found ${rowsWithNull.length} rows with NULL ${t.idCol}. Updating...`);
      // Get max ID
      const resMax = await client.query(`SELECT COALESCE(MAX("${t.idCol}"), 0) as max_id FROM "${t.table}" WHERE "${t.idCol}" IS NOT NULL`);
      let maxId = Number(resMax.rows[0].max_id || 0);
      
      for (const row of rowsWithNull) {
        maxId++;
        await client.query(`UPDATE "${t.table}" SET "${t.idCol}" = $1 WHERE "${t.pk}" = $2`, [maxId, row[t.pk]]);
      }
      console.log(`  Updated ${t.table} successfully.`);
    } else {
      console.log(`  No NULLs in ${t.table}.`);
    }
  }

  console.log('Done!');
  await client.end();
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
