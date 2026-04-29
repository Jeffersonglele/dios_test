import fs from 'node:fs/promises';
import path from 'node:path';

const [, , seedArg] = process.argv;

if (!seedArg) {
  console.error(
    'Usage: node scripts/import_back4app_seed.mjs docs/back4app/seed_initial.json',
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

const seedPath = path.resolve(process.cwd(), seedArg);
const raw = await fs.readFile(seedPath, 'utf8');
const seedDefinitions = JSON.parse(raw);

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

function buildWhereFromRecord(record) {
  if ('roleID' in record) {
    return { roleID: record.roleID };
  }

  if ('idMoyen' in record) {
    return { idMoyen: record.idMoyen };
  }

  if ('commentID' in record) {
    return { commentID: record.commentID };
  }

  throw new Error(
    `Cannot infer unique key for seed record: ${JSON.stringify(record)}`,
  );
}

async function upsertRecord(className, record) {
  const where = buildWhereFromRecord(record);
  const queryResponse = await request(
    'GET',
    `${serverUrl}/classes/${encodeURIComponent(className)}?where=${encodeURIComponent(
      JSON.stringify(where),
    )}`,
  );

  if (!queryResponse.ok) {
    throw new Error(
      `Failed to query ${className}: ${queryResponse.status} ${JSON.stringify(queryResponse.payload)}`,
    );
  }

  const existing = queryResponse.payload?.results?.[0];

  if (existing?.objectId) {
    const updateResponse = await request(
      'PUT',
      `${serverUrl}/classes/${encodeURIComponent(className)}/${existing.objectId}`,
      record,
    );

    if (!updateResponse.ok) {
      throw new Error(
        `Failed to update ${className}: ${updateResponse.status} ${JSON.stringify(updateResponse.payload)}`,
      );
    }

    console.log(`Updated ${className} ${existing.objectId}`);
    return;
  }

  const createResponse = await request(
    'POST',
    `${serverUrl}/classes/${encodeURIComponent(className)}`,
    record,
  );

  if (!createResponse.ok) {
    throw new Error(
      `Failed to create ${className}: ${createResponse.status} ${JSON.stringify(createResponse.payload)}`,
    );
  }

  console.log(`Created ${className} ${createResponse.payload?.objectId ?? ''}`.trim());
}

for (const [className, records] of Object.entries(seedDefinitions)) {
  for (const record of records) {
    await upsertRecord(className, record);
  }
}

console.log('Seed import finished successfully.');
