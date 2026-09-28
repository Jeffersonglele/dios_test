const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');

const app = require('../src/app');

function request(server, path, options = {}) {
  return new Promise((resolve, reject) => {
    const address = server.address();
    const requestInstance = http.request({
      hostname: '127.0.0.1',
      port: address.port,
      path,
      method: options.method || 'GET',
      headers: options.headers || {},
    }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => resolve({ statusCode: response.statusCode, body }));
    });
    requestInstance.on('error', reject);
    requestInstance.end(options.body);
  });
}

test('expose la documentation OpenAPI', async () => {
  const server = http.createServer(app).listen(0);
  try {
    const response = await request(server, '/api-docs.json');
    assert.equal(response.statusCode, 200);
    const document = JSON.parse(response.body);
    assert.equal(document.openapi, '3.0.3');
    assert.ok(document.paths['/api/v1/auth/login']);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('rejette une origine CORS inconnue', async () => {
  const server = http.createServer(app).listen(0);
  try {
    const response = await request(server, '/api-docs.json', {
      headers: { Origin: 'https://un-site-inconnu.example' },
    });
    assert.equal(response.statusCode, 403);
    assert.equal(JSON.parse(response.body).error.message, 'Origine non autorisée par CORS.');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('retourne 400 pour un JSON invalide', async () => {
  const server = http.createServer(app).listen(0);
  try {
    const response = await request(server, '/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{invalid',
    });
    assert.equal(response.statusCode, 400);
    assert.equal(JSON.parse(response.body).error.message, 'Le corps JSON est invalide.');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('protège le webhook Nyole avec sa signature', async () => {
  const server = http.createServer(app).listen(0);
  try {
    const body = JSON.stringify({ event: 'payment.completed', livemode: false, data: { id: 'session-test' } });
    const response = await request(server, '/api/v1/payments/nyole/webhook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    });
    assert.equal(response.statusCode, 401);
    assert.equal(JSON.parse(response.body).error.message, 'Signature Nyole invalide ou expirée.');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('retourne une erreur JSON pour une route inconnue', async () => {
  const server = http.createServer(app).listen(0);
  try {
    const response = await request(server, '/route-inconnue');
    assert.equal(response.statusCode, 404);
    assert.equal(JSON.parse(response.body).error.message, 'Route introuvable : GET /route-inconnue');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
