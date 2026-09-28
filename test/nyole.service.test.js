const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

const { parseSignature, verifyWebhookSignature } = require('../src/services/nyole.service');

test('vérifie la signature HMAC-SHA256 d’un webhook Nyole', () => {
  const previous = process.env.NYOLE_TEST_SECRET_KEY;
  const secret = 'test-nyole-secret';
  const body = JSON.stringify({ event: 'payment.completed', livemode: false });
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const digest = crypto.createHmac('sha256', secret).update(`${timestamp}.${body}`).digest('hex');
  process.env.NYOLE_TEST_SECRET_KEY = secret;

  try {
    const signature = `t=${timestamp},v1=${digest}`;
    assert.deepEqual(parseSignature(signature), { timestamp, signature: digest });
    assert.equal(verifyWebhookSignature(body, { 'x-afriflow-signature': signature }, false), true);
    assert.equal(verifyWebhookSignature(`${body}.`, { 'x-afriflow-signature': signature }, false), false);
  } finally {
    if (previous === undefined) delete process.env.NYOLE_TEST_SECRET_KEY;
    else process.env.NYOLE_TEST_SECRET_KEY = previous;
  }
});
