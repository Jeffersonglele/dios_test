const Minio = require('minio');

function configuration() {
  return {
    endpoint: String(process.env.MINIO_ENDPOINT || '').trim(),
    port: Number.parseInt(process.env.MINIO_PORT, 10) || 9000,
    useSSL: String(process.env.MINIO_USE_SSL || 'false').toLowerCase() === 'true',
    accessKey: String(process.env.MINIO_ACCESS_KEY || ''),
    secretKey: String(process.env.MINIO_SECRET_KEY || ''),
    bucket: String(process.env.MINIO_BUCKET || 'dios-delices-media'),
    publicUrl: String(process.env.MINIO_PUBLIC_URL || '').replace(/\/$/, ''),
  };
}

function client() {
  const config = configuration();
  const required = ['endpoint', 'accessKey', 'secretKey'];
  const missing = required.filter((key) => !config[key]);
  if (missing.length) {
    const error = new Error(`Configuration MinIO incomplète : ${missing.join(', ')}.`);
    error.statusCode = 503;
    throw error;
  }
  return { config, client: new Minio.Client({
    endPoint: config.endpoint,
    port: config.port,
    useSSL: config.useSSL,
    accessKey: config.accessKey,
    secretKey: config.secretKey,
  }) };
}

async function ensureBucket(minio, bucket) {
  if (!await minio.bucketExists(bucket)) await minio.makeBucket(bucket, 'us-east-1');
}

async function save(key, buffer, mimeType) {
  const { config, client: minio } = client();
  await ensureBucket(minio, config.bucket);
  await minio.putObject(config.bucket, key, buffer, buffer.length, { 'Content-Type': mimeType });
  if (!config.publicUrl) {
    const error = new Error('MINIO_PUBLIC_URL doit être configuré pour fournir une URL média publique.');
    error.statusCode = 503;
    throw error;
  }
  return { key, url: `${config.publicUrl}/${config.bucket}/${key}` };
}

async function remove(key) {
  const { config, client: minio } = client();
  await minio.removeObject(config.bucket, key);
}

module.exports = { remove, save };
