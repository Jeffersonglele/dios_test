const dns = require('dns');
const nodemailer = require('nodemailer');
const axios = require('axios');
const { promisify } = require('util');

const resolve4Async = promisify(dns.resolve4);

let cachedTransporter = null;
let cachedTransporterKey = null;

const EMAIL_PROVIDERS = Object.freeze({
  BREVO: 'brevo',
  SMTP: 'smtp',
});

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
  };
}

function preferredProvider() {
  const explicit = String(process.env.EMAIL_PROVIDER || '').trim().toLowerCase();
  if (explicit && Object.values(EMAIL_PROVIDERS).includes(explicit)) return explicit;
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
        rejectUnauthorized: true,
      },
    });
    cachedTransporterKey = key;
  }
  return { config, transporter: cachedTransporter };
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
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
    console.error('[email] Échec d’envoi SMTP', {
      code: error.code,
      responseCode: error.responseCode,
      command: error.command,
      message: error.message,
    });
    const wrapped = new Error('Impossible d’envoyer l’e-mail via SMTP.');
    wrapped.statusCode = 503;
    wrapped.cause = error;
    throw wrapped;
  }
}

async function sendEmail({ to, subject, text, html }) {
  if (!to || !String(to).trim()) throw new Error('Destinataire e-mail obligatoire.');
  const provider = preferredProvider();

  if (provider === EMAIL_PROVIDERS.BREVO && isBrevoConfigured()) {
    const { from } = emailConfig();
    try {
      return await sendEmailViaBrevo({ from, to, subject, text, html });
    } catch (brevoError) {
      if (isSmtpConfigured()) {
        console.warn('[email] Fallback Brevo → SMTP après échec Brevo', {
          cause: brevoError?.cause?.message || brevoError?.message,
        });
        return sendEmailViaSmtp({ to, subject, text, html });
      }
      throw brevoError;
    }
  }

  if (isSmtpConfigured()) {
    return sendEmailViaSmtp({ to, subject, text, html });
  }

  const error = new Error('Aucun fournisseur d’e-mail n’est configuré (BREVO_API_KEY ou SMTP_*).');
  error.statusCode = 503;
  throw error;
}

async function sendVerificationCodeEmail({ to, code, firstname }) {
  const name = firstname ? ` ${escapeHtml(firstname)}` : '';
  return sendEmail({
    to,
    subject: 'Dios Délices — Vérification de votre adresse e-mail',
    text: `Bonjour${firstname ? ` ${firstname}` : ''},\n\nVotre code de vérification Dios Délices est : ${code}\n\nCe code expire dans 15 minutes.`,
    html: `<p>Bonjour${name},</p><p>Votre code de vérification Dios Délices est :</p><p style="font-size:28px;font-weight:700;letter-spacing:6px">${escapeHtml(code)}</p><p>Ce code expire dans 15 minutes.</p>`,
  });
}

async function sendPasswordResetCodeEmail({ to, code }) {
  return sendEmail({
    to,
    subject: 'Dios Délices — Réinitialisation du mot de passe',
    text: `Votre code de réinitialisation Dios Délices est : ${code}\n\nCe code expire dans 15 minutes.`,
    html: `<p>Votre code de réinitialisation Dios Délices est :</p><p style="font-size:28px;font-weight:700;letter-spacing:6px">${escapeHtml(code)}</p><p>Ce code expire dans 15 minutes.</p>`,
  });
}

module.exports = {
  EMAIL_PROVIDERS,
  emailConfig,
  brevoConfig,
  preferredProvider,
  isBrevoConfigured,
  isSmtpConfigured,
  isEmailConfigured,
  sendEmail,
  sendPasswordResetCodeEmail,
  sendVerificationCodeEmail,
};
