const dns = require('dns');
const nodemailer = require('nodemailer');
const axios = require('axios');
const { promisify } = require('util');
const templates = require('./email-templates');

const resolve4Async = promisify(dns.resolve4);

let cachedTransporter = null;
let cachedTransporterKey = null;
let smtpReachability = null;

const EMAIL_PROVIDERS = Object.freeze({
  BREVO: 'brevo',
  SMTP: 'smtp',
});

const SMTP_UNREACHABLE_CODES = new Set([
  'ECONNREFUSED',
  'ECONNRESET',
  'ETIMEDOUT',
  'ENETUNREACH',
  'EHOSTUNREACH',
  'EAI_AGAIN',
]);

function brevoConfig() {
  return {
    apiKey: String(process.env.BREVO_API_KEY || '').trim(),
    baseUrl: String(process.env.BREVO_BASE_URL || 'https://api.brevo.com/v3').trim(),
    timeout: Number.parseInt(process.env.BREVO_TIMEOUT_MS || '15000', 10) || 15000,
  };
}

function emailConfig() {
  const port = Number.parseInt(process.env.SMTP_PORT || '465', 10);
  return {
    host: String(process.env.SMTP_HOST || 'smtp.gmail.com').trim(),
    port: Number.isInteger(port) ? port : 465,
    secure: String(process.env.SMTP_SECURE || (port === 465 ? 'true' : 'false')).toLowerCase() === 'true',
    user: String(process.env.SMTP_USER || '').trim(),
    pass: String(process.env.SMTP_PASS || '').replace(/\s+/g, ''),
    from: String(process.env.SMTP_FROM || process.env.SMTP_USER || '').trim(),
    rejectUnauthorized: String(process.env.SMTP_REJECT_UNAUTHORIZED || 'true').toLowerCase() === 'true',
  };
}

function preferredProvider() {
  const explicit = String(process.env.EMAIL_PROVIDER || '').trim().toLowerCase();
  if (explicit && Object.values(EMAIL_PROVIDERS).includes(explicit)) return explicit;
  if (isSmtpConfigured()) return EMAIL_PROVIDERS.SMTP;
  if (brevoConfig().apiKey) return EMAIL_PROVIDERS.BREVO;
  return EMAIL_PROVIDERS.SMTP;
}

function isBrevoConfigured() {
  const cfg = brevoConfig();
  const emailCfg = emailConfig();
  return Boolean(cfg.apiKey && emailCfg.from);
}

function isSmtpConfigured() {
  const config = emailConfig();
  return Boolean(config.host && config.user && config.pass && config.from);
}

function isEmailConfigured() {
  const provider = preferredProvider();
  if (provider === EMAIL_PROVIDERS.BREVO) return isBrevoConfigured();
  return isSmtpConfigured();
}

function invalidateTransporterCache() {
  cachedTransporter = null;
  cachedTransporterKey = null;
}

const IPV4_REGEX = /^(?:\d{1,3}\.){3}\d{1,3}$/;

async function resolveHostToIpv4(host) {
  if (IPV4_REGEX.test(host)) return host;
  try {
    const addresses = await resolve4Async(host);
    if (addresses && addresses.length > 0) return addresses[0];
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('[email] Résolution IPv4 échouée, fallback host natif :', {
        host,
        cause: err?.message,
      });
    }
  }
  return host;
}

function parseFromHeader(from) {
  const match = /^\s*(?:"?([^"<]*)"?\s*<?\s*)?([^\s<>]+@[^\s<>]+)\s*>?\s*$/i.exec(String(from || ''));
  if (!match) {
    return { name: '', email: String(from || '').trim() };
  }
  const [, name, email] = match;
  return {
    name: (name || '').trim(),
    email: (email || '').trim(),
  };
}

async function getTransporter() {
  const config = emailConfig();
  if (!isSmtpConfigured()) {
    const error = new Error('La configuration SMTP est incomplète.');
    error.statusCode = 503;
    throw error;
  }

  const key = `${config.host}:${config.port}:${config.secure}:${config.user}:${config.from}`;
  if (!cachedTransporter || cachedTransporterKey !== key) {
    const resolvedHost = await resolveHostToIpv4(config.host);
    cachedTransporter = nodemailer.createTransport({
      host: resolvedHost,
      port: config.port,
      secure: config.secure,
      auth: { user: config.user, pass: config.pass },
      family: 4,
      connectionTimeout: 10 * 1000,
      greetingTimeout: 10 * 1000,
      socketTimeout: 15 * 1000,
      dnsTimeout: 5 * 1000,
      tls: {
        family: 4,
        servername: config.host,
        rejectUnauthorized: config.rejectUnauthorized,
      },
    });
    cachedTransporterKey = key;
  }
  return { config, transporter: cachedTransporter };
}

async function verifySmtpReachability({ loud = false } = {}) {
  if (!isSmtpConfigured()) {
    smtpReachability = { ok: false, reason: 'non configuré', checkedAt: new Date() };
    return smtpReachability;
  }
  const label = '[email] Diagnostic SMTP au démarrage';
  try {
    const { transporter, config } = await getTransporter();
    await transporter.verify();
    smtpReachability = { ok: true, checkedAt: new Date() };
    if (loud) {
      console.log(`${label} : ✔︎ SMTP joignable et authentifié (${config.host}:${config.port})`);
    }
  } catch (error) {
    invalidateTransporterCache();
    const code = error?.code || error?.errno || 'UNKNOWN';
    const isNetwork = SMTP_UNREACHABLE_CODES.has(String(code));
    smtpReachability = {
      ok: false,
      code,
      message: error?.message,
      isNetwork,
      checkedAt: new Date(),
    };
    if (loud) {
      console.warn(`${label} : ⚠︎ SMTP INJOIGNABLE`, {
        host: emailConfig().host,
        port: emailConfig().port,
        code,
        message: error?.message,
      });
      if (isNetwork) {
        console.warn(`${label} : ce type d’erreur est typique d’un port SMTP bloqué par l’hébergeur (Render ferme 465/587/25 en sortie sur les plans gratuits / partagés). Le fallback Brevo sera utilisé automatiquement.`);
      }
    }
  }
  return smtpReachability;
}

function getCachedSmtpReachability() {
  return smtpReachability;
}

async function sendEmailViaBrevo({ from, to, subject, text, html }) {
  const cfg = brevoConfig();
  if (!cfg.apiKey) {
    const error = new Error('Clé API Brevo manquante (BREVO_API_KEY).');
    error.statusCode = 503;
    throw error;
  }
  const sender = parseFromHeader(from);
  const recipients = String(to || '')
    .split(/[,;]/)
    .map((e) => e.trim())
    .filter(Boolean)
    .map((email) => ({ email }));

  if (recipients.length === 0) {
    throw new Error('Destinataire e-mail obligatoire.');
  }

  const payload = {
    sender,
    to: recipients,
    subject,
  };
  if (html && String(html).trim()) payload.htmlContent = html;
  if (text && String(text).trim()) payload.textContent = text;

  try {
    const response = await axios.post(`${cfg.baseUrl}/smtp/email`, payload, {
      timeout: cfg.timeout,
      headers: {
        'api-key': cfg.apiKey,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });
    return {
      provider: EMAIL_PROVIDERS.BREVO,
      messageId: response?.data?.messageId,
      status: response.status,
    };
  } catch (error) {
    const status = error?.response?.status;
    const details = error?.response?.data || error?.cause;
    console.error('[email] Échec d’envoi Brevo', {
      status,
      message: error?.message,
      details,
    });
    const wrapped = new Error('Impossible d’envoyer l’e-mail via Brevo.');
    wrapped.statusCode = status && status >= 400 && status < 500 ? 400 : 503;
    wrapped.cause = error;
    throw wrapped;
  }
}

async function sendEmailViaSmtp({ to, subject, text, html }) {
  const { config, transporter } = await getTransporter();
  try {
    const result = await transporter.sendMail({
      from: config.from,
      to: String(to).trim(),
      subject,
      text,
      html,
    });
    return {
      provider: EMAIL_PROVIDERS.SMTP,
      messageId: result?.messageId,
      response: result?.response,
    };
  } catch (error) {
    invalidateTransporterCache();
    const code = error?.code || error?.errno || 'UNKNOWN';
    const isNetwork = SMTP_UNREACHABLE_CODES.has(String(code));
    if (isNetwork) {
      smtpReachability = {
        ok: false,
        code,
        message: error?.message,
        isNetwork: true,
        failedAt: new Date(),
      };
    }
    console.error('[email] Échec d’envoi SMTP', {
      code,
      responseCode: error.responseCode,
      command: error.command,
      message: error.message,
      isNetwork,
    });
    const wrapped = new Error('Impossible d’envoyer l’e-mail via SMTP.');
    wrapped.statusCode = 503;
    wrapped.cause = error;
    wrapped.smtpNetworkFailure = isNetwork;
    throw wrapped;
  }
}

async function sendEmail({ to, subject, text, html }) {
  if (!to || !String(to).trim()) throw new Error('Destinataire e-mail obligatoire.');
  const provider = preferredProvider();
  const brevoReady = isBrevoConfigured();
  const smtpReady = isSmtpConfigured();
  const smtpCfg = emailConfig();
  const brevoCfg = brevoConfig();

  if (provider === EMAIL_PROVIDERS.SMTP && smtpReady) {
    try {
      const result = await sendEmailViaSmtp({ to, subject, text, html });
      console.log('[email] Envoi réussi via SMTP', {
        to: String(to).trim(),
        subject,
        messageId: result?.messageId,
      });
      return result;
    } catch (smtpError) {
      const shouldFallback = Boolean(smtpError?.smtpNetworkFailure)
        || smtpError?.statusCode === 503;
      const fallbackReady = brevoReady;
      console.warn('[email] Tentative SMTP échouée', {
        to: String(to).trim(),
        subject,
        cause: smtpError?.cause?.message || smtpError?.message,
        networkFailure: Boolean(smtpError?.smtpNetworkFailure),
        shouldFallback,
        fallbackReady,
        fallbackProvider: fallbackReady
          ? `BREVO (from="${smtpCfg.from}", key=${brevoCfg.apiKey ? 'OK' : 'MANQUANTE'})`
          : '(aucun — vérifie BREVO_API_KEY et SMTP_FROM sur Render)',
      });
      if (shouldFallback && fallbackReady) {
        console.warn('[email] Fallback SMTP → Brevo après échec SMTP');
        const { from } = smtpCfg;
        const brevoResult = await sendEmailViaBrevo({ from, to, subject, text, html });
        console.log('[email] Envoi réussi via Brevo (fallback SMTP KO)', {
          to: String(to).trim(),
          subject,
          messageId: brevoResult?.messageId,
          status: brevoResult?.status,
        });
        return brevoResult;
      }
      if (!fallbackReady) {
        console.error('[email] Fallback Brevo IMPOSSIBLE : configuration manquante. Rends-toi sur Render Environment et vérifie BREVO_API_KEY + SMTP_FROM.');
      }
      throw smtpError;
    }
  }

  if (provider === EMAIL_PROVIDERS.BREVO && brevoReady) {
    const { from } = smtpCfg;
    try {
      const result = await sendEmailViaBrevo({ from, to, subject, text, html });
      console.log('[email] Envoi réussi via Brevo', {
        to: String(to).trim(),
        subject,
        messageId: result?.messageId,
        status: result?.status,
      });
      return result;
    } catch (brevoError) {
      if (smtpReady) {
        console.warn('[email] Fallback Brevo → SMTP après échec Brevo', {
          cause: brevoError?.cause?.message || brevoError?.message,
        });
        const smtpResult = await sendEmailViaSmtp({ to, subject, text, html });
        console.log('[email] Envoi réussi via SMTP (fallback Brevo KO)', {
          to: String(to).trim(),
          subject,
          messageId: smtpResult?.messageId,
        });
        return smtpResult;
      }
      throw brevoError;
    }
  }

  if (smtpReady) {
    return sendEmailViaSmtp({ to, subject, text, html });
  }

  const error = new Error('Aucun fournisseur d’e-mail n’est configuré (BREVO_API_KEY ou SMTP_*).');
  error.statusCode = 503;
  throw error;
}

async function sendVerificationCodeEmail({ to, code, firstname }) {
  return sendEmail({ to, ...templates.buildVerificationCodeEmail({ code, firstname }) });
}

async function sendPasswordResetCodeEmail({ to, code }) {
  return sendEmail({ to, ...templates.buildPasswordResetCodeEmail({ code }) });
}

async function sendSellerApprovedEmail({ to, firstname }) {
  return sendEmail({ to, ...templates.buildSellerApprovedEmail({ firstname }) });
}

async function sendSellerRejectedEmail({ to, firstname, reason }) {
  return sendEmail({ to, ...templates.buildSellerRejectedEmail({ firstname, reason }) });
}

async function sendRestaurantApprovedEmail({ to, firstname, restaurantName }) {
  return sendEmail({ to, ...templates.buildRestaurantApprovedEmail({ firstname, restaurantName }) });
}

async function sendRestaurantRejectedEmail({ to, firstname, restaurantName, reason }) {
  return sendEmail({ to, ...templates.buildRestaurantRejectedEmail({ firstname, restaurantName, reason }) });
}

async function sendCourierApprovedEmail({ to, firstname }) {
  return sendEmail({ to, ...templates.buildCourierApprovedEmail({ firstname }) });
}

async function sendCourierRejectedEmail({ to, firstname, reason }) {
  return sendEmail({ to, ...templates.buildCourierRejectedEmail({ firstname, reason }) });
}

/// Identifiants d'un nouvel administrateur (mot de passe temporaire).
async function sendAdminAccountEmail({ to, name, accessLabel, username, temporaryPassword }) {
  return sendEmail({ to, ...templates.buildAdminAccountEmail({ name, accessLabel, username, temporaryPassword }) });
}

/// Message libre envoyé par un administrateur depuis le back-office.
async function sendDirectMessageEmail({ to, subject, text }) {
  return sendEmail({ to, ...templates.buildDirectMessageEmail({ subject, text }) });
}

/// Alerte l'équipe (ADMIN_NOTIFICATION_EMAIL, adresses séparées par des
/// virgules). Sans destinataire configuré, ne fait rien. Non bloquant.
function sendAdminNotification({ subject, text }) {
  const recipients = String(process.env.ADMIN_NOTIFICATION_EMAIL || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  if (recipients.length === 0) return;
  setImmediate(() => {
    sendEmail({ to: recipients.join(','), ...templates.buildAdminNotificationEmail({ subject, text }) })
      .catch((err) => console.error('[email] Notification admin impossible', { message: err?.message }));
  });
}

module.exports = {
  EMAIL_PROVIDERS,
  sendAdminNotification,
  emailConfig,
  brevoConfig,
  preferredProvider,
  isBrevoConfigured,
  isSmtpConfigured,
  isEmailConfigured,
  verifySmtpReachability,
  getCachedSmtpReachability,
  invalidateTransporterCache,
  sendEmail,
  sendPasswordResetCodeEmail,
  sendVerificationCodeEmail,
  sendSellerApprovedEmail,
  sendSellerRejectedEmail,
  sendRestaurantApprovedEmail,
  sendRestaurantRejectedEmail,
  sendCourierApprovedEmail,
  sendCourierRejectedEmail,
  sendAdminAccountEmail,
  sendDirectMessageEmail,
};
