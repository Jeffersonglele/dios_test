const cron = require('node-cron');

const prisma = require('../config/prisma');

const CRON_SCHEDULE = process.env.GEOCODING_CACHE_CRON || '0 3 * * *';
const TASK_NAME = 'geocoding-cache-purge';

let running = false;
let registeredTask = null;

async function purgeExpiredGeocodingCache({ loud = false } = {}) {
  if (running) {
    if (loud) console.warn(`[cron:${TASK_NAME}] déjà en cours d’exécution, skip.`);
    return null;
  }
  running = true;
  const startedAt = Date.now();
  try {
    const cutoff = new Date();
    const { count } = await prisma.geocodingCache.deleteMany({
      where: { expiresAt: { lt: cutoff } },
    });
    const durationMs = Date.now() - startedAt;
    if (count > 0 || loud) {
      console.log(
        `[cron:${TASK_NAME}] ${count} entrée(s) expirée(s) supprimée(s) en ${durationMs}ms (cutoff=${cutoff.toISOString()}).`,
      );
    }
    return { count, durationMs, cutoff: cutoff.toISOString() };
  } catch (error) {
    const durationMs = Date.now() - startedAt;
    console.error(
      `[cron:${TASK_NAME}] échec après ${durationMs}ms :`,
      error?.message || error,
    );
    return { error: error?.message || String(error), durationMs };
  } finally {
    running = false;
  }
}

function startScheduler({ runOnBoot = false, loud = true } = {}) {
  if (registeredTask) {
    if (loud) console.warn(`[cron:${TASK_NAME}] scheduleur déjà démarré.`);
    return registeredTask;
  }
  const envDisabled = String(process.env.GEOCODING_CACHE_CRON_DISABLED || '')
    .trim()
    .toLowerCase();
  if (envDisabled === '1' || envDisabled === 'true' || envDisabled === 'yes') {
    if (loud) console.log(`[cron:${TASK_NAME}] désactivé via variable d’environnement.`);
    return null;
  }

  try {
    registeredTask = cron.schedule(
      CRON_SCHEDULE,
      async () => {
        try {
          await purgeExpiredGeocodingCache();
        } catch (_) {}
      },
      {
        scheduled: true,
        timezone: process.env.TZ || 'Africa/Kinshasa',
        name: TASK_NAME,
      },
    );
    if (loud) {
      console.log(
        `[cron:${TASK_NAME}] planifié (expression="${CRON_SCHEDULE}", tz=${
          process.env.TZ || 'Africa/Kinshasa'
        }).`,
      );
    }
  } catch (error) {
    console.error(
      `[cron:${TASK_NAME}] impossible de démarrer le scheduleur :`,
      error?.message || error,
    );
    registeredTask = null;
  }

  if (runOnBoot) {
    setImmediate(() => purgeExpiredGeocodingCache({ loud: true }).catch(() => {}));
  }
  return registeredTask;
}

function stopScheduler() {
  if (registeredTask) {
    try {
      registeredTask.stop();
      registeredTask.destroy?.();
    } catch (_) {}
    registeredTask = null;
  }
}

module.exports = {
  purgeExpiredGeocodingCache,
  startScheduler,
  stopScheduler,
  TASK_NAME,
  CRON_SCHEDULE,
};
