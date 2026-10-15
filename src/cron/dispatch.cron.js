const { redispatchPendingDeliveries } = require('../services/delivery-dispatch.service');

const TASK_NAME = 'delivery-redispatch';
// Au plus une relance anticipée (kick) toutes les 5 s, quel que soit le nombre de livreurs.
const KICK_MIN_GAP_MS = 5_000;

let running = false;
let timer = null;
let kickTimer = null;
let lastRunAt = 0;

/// Relance les courses SEARCHING dont toutes les propositions ont expiré ou
/// ont été refusées (et celles qui n'en ont jamais eu faute de livreur).
async function runOnce({ loud = false } = {}) {
  if (running) return null;
  running = true;
  lastRunAt = Date.now();
  try {
    const result = await redispatchPendingDeliveries();
    if (result.offers > 0 || loud) {
      console.log(`[cron:${TASK_NAME}] ${result.deliveries} course(s) relancée(s), ${result.offers} proposition(s) en attente.`);
    }
    return result;
  } catch (error) {
    console.error(`[cron:${TASK_NAME}] échec :`, error?.message || error);
    return { error: error?.message || String(error) };
  } finally {
    running = false;
  }
}

/// Relance anticipée, par exemple quand un livreur passe en ligne ou envoie sa
/// position. Regroupe les appels rapprochés.
function kick() {
  if (!timer || kickTimer) return;
  const wait = Math.max(500, KICK_MIN_GAP_MS - (Date.now() - lastRunAt));
  kickTimer = setTimeout(() => {
    kickTimer = null;
    runOnce();
  }, wait);
  kickTimer.unref?.();
}

function startScheduler({ loud = true } = {}) {
  if (timer) return timer;
  const intervalSeconds = Number.parseInt(process.env.DISPATCH_SWEEP_INTERVAL_SECONDS, 10);
  const seconds = Number.isInteger(intervalSeconds) ? intervalSeconds : 15;
  if (seconds <= 0) {
    if (loud) console.log(`[cron:${TASK_NAME}] désactivé (DISPATCH_SWEEP_INTERVAL_SECONDS=${seconds}).`);
    return null;
  }
  timer = setInterval(() => { runOnce(); }, Math.max(5, seconds) * 1000);
  timer.unref?.();
  if (loud) console.log(`[cron:${TASK_NAME}] relance des propositions toutes les ${Math.max(5, seconds)} s.`);
  return timer;
}

function stopScheduler() {
  if (timer) clearInterval(timer);
  if (kickTimer) clearTimeout(kickTimer);
  timer = null;
  kickTimer = null;
}

module.exports = { kick, runOnce, startScheduler, stopScheduler };
