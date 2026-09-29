const dns = require('dns');
const nodemailer = require('nodemailer');
const axios = require('axios');
const { promisify } = require('util');

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
  const name = firstname ? ` ${escapeHtml(firstname)}` : '';
  const safeCode = escapeHtml(code);
  const brand = '#E1502F';
  const brandDark = '#C7431F';
  const ink = '#2B211D';
  const inkMuted = '#8A7A72';
  const surfaceWarm = '#FBEFE6';
  const border = '#F0DDD0';

  const html = `
  <!DOCTYPE html>
  <html lang="fr">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Vérification de votre adresse e-mail</title>
    </head>
    <body style="margin:0; padding:0; background-color:${surfaceWarm}; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${surfaceWarm}; padding:32px 16px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; background-color:#ffffff; border-radius:24px; border:1px solid ${border}; overflow:hidden;">

              <!-- En-tête marque -->
              <tr>
                <td style="padding:32px 32px 0 32px;" align="center">
                  <table role="presentation" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="width:8px; height:8px; border-radius:99px; background-color:${brand};"></td>
                      <td style="width:8px;"></td>
                      <td style="font-size:12px; font-weight:700; letter-spacing:2px; color:${brand}; text-transform:uppercase;">
                        Dios Délices
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Titre -->
              <tr>
                <td style="padding:20px 32px 0 32px;" align="center">
                  <h1 style="margin:0; font-size:22px; line-height:1.3; font-weight:800; color:${ink};">
                    Vérifiez votre adresse e-mail
                  </h1>
                </td>
              </tr>

              <!-- Texte d'intro -->
              <tr>
                <td style="padding:12px 32px 0 32px;" align="center">
                  <p style="margin:0; font-size:15px; line-height:1.6; color:${inkMuted};">
                    Bonjour${name},<br />
                    Voici votre code de vérification pour confirmer votre compte Dios Délices&nbsp;:
                  </p>
                </td>
              </tr>

              <!-- Code -->
              <tr>
                <td style="padding:28px 32px 4px 32px;" align="center">
                  <table role="presentation" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="background-color:${surfaceWarm}; border:1.5px solid ${border}; border-radius:16px; padding:18px 28px;">
                        <span style="font-size:32px; font-weight:800; letter-spacing:10px; color:${brandDark}; font-family:'Courier New',Courier,monospace;">
                          ${safeCode}
                        </span>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Expiration -->
              <tr>
                <td style="padding:16px 32px 0 32px;" align="center">
                  <p style="margin:0; font-size:13px; color:${inkMuted};">
                    Ce code expire dans <strong style="color:${ink};">15 minutes</strong>.
                  </p>
                </td>
              </tr>

              <!-- Séparateur -->
              <tr>
                <td style="padding:28px 32px 0 32px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="height:1px; line-height:1px; font-size:1px; background-color:${border};">&nbsp;</td>
                    </tr>
                  </table>
                </td>
              </tr>

              <!-- Note sécurité -->
              <tr>
                <td style="padding:20px 32px 32px 32px;" align="center">
                  <p style="margin:0; font-size:12px; line-height:1.6; color:${inkMuted};">
                    Vous n'êtes pas à l'origine de cette demande&nbsp;? Vous pouvez ignorer cet e-mail en toute sécurité.<br />
                    Pensez aussi à vérifier votre dossier spam si vous ne voyez pas nos e-mails.
                  </p>
                </td>
              </tr>
            </table>

            <!-- Pied de page -->
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; margin-top:20px;">
              <tr>
                <td align="center">
                  <p style="margin:0; font-size:12px; color:${inkMuted};">
                    © ${new Date().getFullYear()} Dios Délices. Tous droits réservés.
                  </p>
                </td>
              </tr>
            </table>

          </td>
        </tr>
      </table>
    </body>
  </html>
  `;

  const text = `Bonjour${firstname ? ` ${firstname}` : ''},

Votre code de vérification Dios Délices est : ${code}

Ce code expire dans 15 minutes.

Vous n'êtes pas à l'origine de cette demande ? Vous pouvez ignorer cet e-mail.`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Vérification de votre adresse e-mail',
    text,
    html,
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
  verifySmtpReachability,
  getCachedSmtpReachability,
  invalidateTransporterCache,
  sendEmail,
  sendPasswordResetCodeEmail,
  sendVerificationCodeEmail,
};
