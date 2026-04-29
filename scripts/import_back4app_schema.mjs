import fs from 'node:fs/promises';
import path from 'node:path';

const [, , schemaArg] = process.argv;

if (!schemaArg) {
  console.error(
    'Usage: node scripts/import_back4app_schema.mjs docs/back4app/schema_corrected.json',
  );
  process.exit(1);
}

async function loadDotEnvFile() {
  const envPath = path.resolve(process.cwd(), '.env');

  try {
    const rawEnv = await fs.readFile(envPath, 'utf8');

    for (const line of rawEnv.split(/\r?\n/)) {
      const trimmed = line.trim();

      if (!trimmed || trimmed.startsWith('#')) {
        continue;
      }

      const separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      const key = trimmed.slice(0, separatorIndex).trim();
      const value = trimmed.slice(separatorIndex + 1).trim();

      if (!process.env[key]) {
        process.env[key] = value;
      }
    }
  } catch (error) {
    if (error.code !== 'ENOENT') {
      throw error;
    }
  }
}

await loadDotEnvFile();

const appId = process.env.BACK4APP_APP_ID;
const masterKey = process.env.BACK4APP_MASTER_KEY;
const serverUrl =
  process.env.BACK4APP_SERVER_URL || 'https://parseapi.back4app.com';

if (!appId || !masterKey) {
  console.error(
    'Set BACK4APP_APP_ID and BACK4APP_MASTER_KEY before running this script.',
  );
  process.exit(1);
}

const schemaPath = path.resolve(process.cwd(), schemaArg);
const raw = await fs.readFile(schemaPath, 'utf8');
const schemaDefinitions = JSON.parse(raw);

const headers = {
  'X-Parse-Application-Id': appId,
  'X-Parse-Master-Key': masterKey,
  'Content-Type': 'application/json',
};

async function request(method, url, body) {
  const response = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await response.text();
  let payload = null;

  try {
    payload = text ? JSON.parse(text) : null;
  } catch {
    payload = text;
  }

  return { ok: response.ok, status: response.status, payload };
}

async function classExists(className) {
  const response = await request(
    'GET',
    `${serverUrl}/schemas/${encodeURIComponent(className)}`,
  );

  if (response.ok) {
    return true;
  }

  if (response.status === 404) {
    return false;
  }

  throw new Error(
    `Unable to check schema ${className}: ${response.status} ${JSON.stringify(response.payload)}`,
  );
}

function stripSystemIndexes(indexes = {}) {
  return Object.fromEntries(
    Object.entries(indexes).filter(([indexName]) => indexName !== '_id_'),
  );
}

function buildSchemaPayload(definition, { includeIndexes = true } = {}) {
  return {
    className: definition.className,
    fields: definition.fields || {},
    classLevelPermissions: definition.classLevelPermissions || {},
    ...(includeIndexes
      ? { indexes: stripSystemIndexes(definition.indexes || {}) }
      : {}),
  };
}

for (const definition of schemaDefinitions) {
  const className = definition.className;
  const exists = await classExists(className);
  const payload = buildSchemaPayload(definition);
  const url = `${serverUrl}/schemas/${encodeURIComponent(className)}`;

  let response = await request(exists ? 'PUT' : 'POST', url, payload);

  if (
    !response.ok &&
    response.status === 400 &&
    response.payload?.code === 102
  ) {
    response = await request(
      exists ? 'PUT' : 'POST',
      url,
      buildSchemaPayload(definition, { includeIndexes: false }),
    );
  }

  if (!response.ok) {
    throw new Error(
      `Failed to ${exists ? 'update' : 'create'} ${className}: ${response.status} ${JSON.stringify(response.payload)}`,
    );
  }

  console.log(`${exists ? 'Updated' : 'Created'} schema ${className}`);
}

console.log('Schema import finished successfully.');
