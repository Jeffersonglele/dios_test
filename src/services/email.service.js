const nodemailer = require('nodemailer');

let cachedTransporter = null;
let cachedTransporterKey = null;

function emailConfig() {
  const port = Number.parseInt(process.env.SMTP_PORT || '465', 10);
  return {
    host: String(process.env.SMTP_HOST || 'smtp.gmail.com').trim(),
    port: Number.isInteger(port) ? port : 465,
    secure: String(process.env.SMTP_SECURE || (port === 465 ? 'true' : 'false')).toLowerCase() === 'true',
    user: String(process.env.SMTP_USER || '').trim(),
    // Google affiche parfois le mot de passe d’application avec des espaces.
    // Ils sont uniquement visuels et ne doivent pas être transmis à Gmail.
    pass: String(process.env.SMTP_PASS || '').replace(/\s+/g, ''),
    from: String(process.env.SMTP_FROM || process.env.SMTP_USER || '').trim(),
  };
}

function isEmailConfigured() {
  const config = emailConfig();
  return Boolean(config.host && config.user && config.pass && config.from);
}

function getTransporter() {
  const config = emailConfig();
  if (!isEmailConfigured()) {
    const error = new Error('La configuration SMTP est incomplète.');
    error.statusCode = 503;
    throw error;
  }

  const key = `${config.host}:${config.port}:${config.secure}:${config.user}:${config.from}`;
  if (!cachedTransporter || cachedTransporterKey !== key) {
    cachedTransporter = nodemailer.createTransport({
      host: config.host,
      port: config.port,
      secure: config.secure,
      auth: { user: config.user, pass: config.pass },
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

async function sendEmail({ to, subject, text, html }) {
  if (!to || !String(to).trim()) throw new Error('Destinataire e-mail obligatoire.');
  const { config, transporter } = getTransporter();
  try {
    return await transporter.sendMail({
      from: config.from,
      to: String(to).trim(),
      subject,
      text,
      html,
    });
  } catch (error) {
    console.error('[email] Échec d’envoi SMTP', {
      code: error.code,
      responseCode: error.responseCode,
      command: error.command,
      message: error.message,
    });
    const wrapped = new Error('Impossible d’envoyer l’e-mail.');
    wrapped.statusCode = 503;
    wrapped.cause = error;
    throw wrapped;
  }
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
  emailConfig,
  isEmailConfigured,
  sendEmail,
  sendPasswordResetCodeEmail,
  sendVerificationCodeEmail,
};
