const LOCAL_ORIGINS = ['http://localhost:3000', 'http://localhost:5173'];

function originFrom(value) {
  if (!value) return null;
  try {
    return new URL(String(value).trim()).origin;
  } catch (_) {
    return null;
  }
}

function isProduction() {
  return String(process.env.NODE_ENV || 'development').toLowerCase() === 'production';
}

function configuredOrigins() {
  const configured = String(process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const serviceOrigins = [
    process.env.RENDER_EXTERNAL_URL,
    process.env.API_PUBLIC_URL,
    process.env.API_BASE_URL,
  ].map(originFrom).filter(Boolean);
  const value = [...new Set([...configured, ...serviceOrigins])];

  return value.length > 0 ? value : (isProduction() ? [] : LOCAL_ORIGINS);
}

function trustProxy() {
  const value = String(process.env.TRUST_PROXY || '').trim().toLowerCase();
  if (!value) return isProduction() ? 1 : false;
  if (value === 'true') return true;
  if (value === 'false') return false;
  const hops = Number.parseInt(value, 10);
  return Number.isInteger(hops) && hops >= 0 ? hops : false;
}

function detectEmailProvider() {
  const explicit = String(process.env.EMAIL_PROVIDER || '').trim().toLowerCase();
  const brevoKey = String(process.env.BREVO_API_KEY || '').trim();
  const smtpHost = String(process.env.SMTP_HOST || '').trim();
  const smtpUser = String(process.env.SMTP_USER || '').trim();
  const smtpPass = String(process.env.SMTP_PASS || '').trim();
  const smtpFrom = String(process.env.SMTP_FROM || process.env.SMTP_USER || '').trim();
  const smtpOk = Boolean(smtpHost && smtpUser && smtpPass && smtpFrom);
  const brevoOk = Boolean(brevoKey && smtpFrom);

  let provider = 'smtp';
  if (explicit === 'brevo' || explicit === 'smtp') {
    provider = explicit;
  } else if (smtpOk) {
    provider = 'smtp';
  } else if (brevoOk) {
    provider = 'brevo';
  }
  return { explicit, provider, smtpOk, brevoOk, smtpFrom, brevoKey: brevoKey ? '***' : '' };
}

function validateRuntimeConfig() {
  const errors = [];
  const warnings = [];
  const production = isProduction();
  const databaseUrl = String(process.env.DATABASE_URL || '').trim();
  const jwtSecret = String(process.env.JWT_SECRET || '').trim();
  const storageDriver = String(process.env.STORAGE_DRIVER || 'local').trim().toLowerCase();
  const nyoleMode = String(process.env.NYOLE_MODE || 'test').trim().toLowerCase();
  const nyoleSecret = nyoleMode === 'live'
    ? String(process.env.NYOLE_LIVE_SECRET_KEY || '').trim()
    : String(process.env.NYOLE_TEST_SECRET_KEY || '').trim();

  if (!databaseUrl) {
    (production ? errors : warnings).push('DATABASE_URL est obligatoire.');
  }
  if (!jwtSecret) {
    (production ? errors : warnings).push('JWT_SECRET est obligatoire.');
  } else if (jwtSecret.length < 32) {
    (production ? errors : warnings).push('JWT_SECRET doit contenir au moins 32 caractères.');
  }
  if (production && configuredOrigins().length === 0) {
    errors.push('CORS_ORIGINS doit déclarer au moins une origine en production.');
  }
  if (!['local', 'minio'].includes(storageDriver)) {
    errors.push('STORAGE_DRIVER doit valoir local ou minio.');
  }
  if (storageDriver === 'minio' && (!process.env.MINIO_ENDPOINT || !process.env.MINIO_BUCKET)) {
    errors.push('MINIO_ENDPOINT et MINIO_BUCKET sont obligatoires avec STORAGE_DRIVER=minio.');
  }
  if (!['test', 'live'].includes(nyoleMode)) {
    errors.push('NYOLE_MODE doit valoir test ou live.');
  } else if (!nyoleSecret) {
    (production ? errors : warnings).push(`NYOLE_${nyoleMode === 'live' ? 'LIVE' : 'TEST'}_SECRET_KEY est obligatoire pour les paiements Nyole.`);
  }

  const email = detectEmailProvider();
  if (email.provider === 'brevo') {
    const brevoKey = String(process.env.BREVO_API_KEY || '').trim();
    if (!brevoKey) {
      (production ? errors : warnings).push('EMAIL_PROVIDER=brevo mais BREVO_API_KEY est vide.');
    }
    if (!email.smtpFrom) {
      (production ? errors : warnings).push('EMAIL_PROVIDER=brevo mais SMTP_FROM est vide (expéditeur requis).');
    }
    console.log(`[email] Provider actif : BREVO (API HTTPS) ${brevoKey && email.smtpFrom ? '✔︎ configuré (from=' + email.smtpFrom + ')' : '⚠︎ incomplet'}`);
  } else if (email.provider === 'smtp') {
    if (email.smtpOk) {
      console.log('[email] Provider actif : SMTP (⚠︎ peut échouer sur Render à cause des ports bloqués).');
    } else if (email.brevoOk) {
      console.log('[email] Provider actif : SMTP, mais BREVO_API_KEY est disponible — définis EMAIL_PROVIDER=brevo pour utiliser l’API HTTPS.');
    } else {
      (production ? errors : warnings).push('Aucun fournisseur d’e-mail n’est configuré (BREVO_API_KEY ou SMTP_*).');
    }
  } else if (!email.smtpOk && !email.brevoOk) {
    (production ? errors : warnings).push('Aucun fournisseur d’e-mail n’est configuré (BREVO_API_KEY ou SMTP_*).');
  }

  return { errors, warnings };
}

module.exports = { configuredOrigins, isProduction, trustProxy, validateRuntimeConfig, detectEmailProvider };
