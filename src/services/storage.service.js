const path = require('path');
const { randomUUID } = require('crypto');

const sharp = require('sharp');

const localStorage = require('./local-storage.service');
const minioStorage = require('./minio-storage.service');

const ACCEPTED_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

function driver() {
  return String(process.env.STORAGE_DRIVER || 'local').trim().toLowerCase();
}

function inferMimeTypeFromMagicBytes(buffer) {
  if (!buffer || buffer.length < 12) return null;
  if (buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) {
    return 'image/jpeg';
  }
  if (buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4E &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0D &&
      buffer[5] === 0x0A &&
      buffer[6] === 0x1A &&
      buffer[7] === 0x0A) {
    return 'image/png';
  }
  if (buffer[0] === 0x52 &&
      buffer[1] === 0x49 &&
      buffer[2] === 0x46 &&
      buffer[3] === 0x46 &&
      buffer[8] === 0x57 &&
      buffer[9] === 0x45 &&
      buffer[10] === 0x42 &&
      buffer[11] === 0x50) {
    return 'image/webp';
  }
  return null;
}

function normalizeMimeType(file) {
  const fromMagic = inferMimeTypeFromMagicBytes(file.buffer);
  if (fromMagic) {
    file.mimetype = fromMagic;
    return fromMagic;
  }
  if (ACCEPTED_TYPES.has(file.mimetype)) {
    return file.mimetype;
  }
  return file.mimetype || null;
}

function assertImage(file) {
  if (!file?.buffer?.length) {
    const error = new Error('Aucun fichier image reçu.');
    error.statusCode = 400;
    throw error;
  }
  if (file.size > MAX_IMAGE_BYTES) {
    const error = new Error('Une image ne peut pas dépasser 5 Mo.');
    error.statusCode = 413;
    throw error;
  }
  const detected = normalizeMimeType(file);
  if (!ACCEPTED_TYPES.has(detected)) {
    const error = new Error('Format non pris en charge. Utilisez JPEG, PNG ou WebP.');
    error.statusCode = 415;
    throw error;
  }
}

async function normalizeImage(file) {
  try {
    const buffer = await sharp(file.buffer, { failOn: 'error' })
      .rotate()
      .resize({ width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 84 })
      .toBuffer();
    return { buffer, mimeType: 'image/webp' };
  } catch (_) {
    const error = new Error('Le fichier ne contient pas une image valide.');
    error.statusCode = 415;
    throw error;
  }
}

async function uploadImage(file, scope = 'images') {
  assertImage(file);
  const image = await normalizeImage(file);
  const safeScope = String(scope).replace(/[^a-z0-9/_-]/gi, '').replace(/^\/+|\/+$/g, '') || 'images';
  const key = path.posix.join(safeScope, new Date().toISOString().slice(0, 10), `${randomUUID()}.webp`);
  const activeDriver = driver();
  const storage = activeDriver === 'minio' ? minioStorage : localStorage;
  const saved = await storage.save(key, image.buffer, image.mimeType);
  return { ...saved, driver: activeDriver, mimeType: image.mimeType, size: image.buffer.length };
}

async function uploadRawMedia(file, folder = 'chat_media') {
  if (!file?.buffer?.length) {
    const error = new Error('Aucun fichier média reçu.');
    error.statusCode = 400;
    throw error;
  }

  let ext = path.extname(file.originalname || '');
  if (!ext) {
    const mime = (file.mimetype || '').toLowerCase();
    if (mime.includes('m4a') || mime === 'audio/mp4') ext = '.m4a';
    else if (mime.includes('aac')) ext = '.aac';
    else if (mime.includes('ogg')) ext = '.ogg';
    else if (mime.includes('wav')) ext = '.wav';
    else if (mime.includes('webm')) ext = '.webm';
    else if (mime.includes('mp3') || mime.includes('mpeg')) ext = '.mp3';
    else if (mime.includes('jpeg') || mime.includes('jpg')) ext = '.jpg';
    else if (mime.includes('png')) ext = '.png';
    else if (mime.includes('webp')) ext = '.webp';
    else ext = '.bin';
  }

  const safeFolder = String(folder).replace(/[^a-z0-9/_-]/gi, '').replace(/^\/+|\/+$/g, '') || 'chat_media';
  const key = path.posix.join(safeFolder, new Date().toISOString().slice(0, 10), `${randomUUID()}${ext}`);
  const activeDriver = driver();
  const storage = activeDriver === 'minio' ? minioStorage : localStorage;
  const mimeType = file.mimetype || 'application/octet-stream';
  const saved = await storage.save(key, file.buffer, mimeType);
  return { ...saved, driver: activeDriver, mimeType, size: file.buffer.length };
}

module.exports = { MAX_IMAGE_BYTES, uploadImage, uploadRawMedia };
