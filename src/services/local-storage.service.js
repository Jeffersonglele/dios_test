const fs = require('fs/promises');
const path = require('path');

function uploadDirectory() {
  return path.resolve(process.env.UPLOAD_DIR || path.join(process.cwd(), 'uploads'));
}

function publicBaseUrl() {
  return String(process.env.API_PUBLIC_URL || process.env.API_BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
}

async function save(key, buffer) {
  const baseDirectory = uploadDirectory();
  const target = path.resolve(baseDirectory, key);
  if (!target.startsWith(`${baseDirectory}${path.sep}`)) {
    throw new Error('Chemin de stockage invalide.');
  }
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, buffer, { flag: 'wx' });
  return { key, url: `${publicBaseUrl()}/uploads/${key}` };
}

async function remove(key) {
  const baseDirectory = uploadDirectory();
  const target = path.resolve(baseDirectory, key);
  if (!target.startsWith(`${baseDirectory}${path.sep}`)) return;
  await fs.rm(target, { force: true });
}

module.exports = { publicBaseUrl, remove, save, uploadDirectory };
