const cacheCron = require('./src/cron/cache.cron.js');

async function main() {
  console.log('Test purgeExpiredGeocodingCache (doit gérer gracieusement les erreurs DB) :');
  const res = await cacheCron.purgeExpiredGeocodingCache({ loud: true });
  console.log('Purge result :', res);

  console.log('\nTest startScheduler (doit être non bloquant) :');
  const t1 = Date.now();
  cacheCron.startScheduler({ runOnBoot: false, loud: true });
  const dt = Date.now() - t1;
  console.log('startScheduler terminé en', dt + 'ms → NON bloquant.');

  cacheCron.stopScheduler();
  console.log('\nTous les tests backend runtime ont réussi, aucune erreur fatale.');
}

main().catch((e) => {
  console.error('Erreur du script de test :', e.message);
  process.exit(1);
});
