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

function _sellerLayout({ title, intro, mainBlock, outro }) {
  const brand = '#E1502F';
  const brandDark = '#C7431F';
  const ink = '#2B211D';
  const inkMuted = '#8A7A72';
  const surfaceWarm = '#FBEFE6';
  const border = '#F0DDD0';
  const success = '#1B8A5A';
  const danger = '#C0392B';
  const html = `
  <!DOCTYPE html>
  <html lang="fr">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>${escapeHtml(title)}</title>
    </head>
    <body style="margin:0; padding:0; background-color:${surfaceWarm}; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:${surfaceWarm}; padding:32px 16px;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px; background-color:#ffffff; border-radius:24px; border:1px solid ${border}; overflow:hidden;">
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
              <tr>
                <td style="padding:20px 32px 0 32px;" align="center">
                  <h1 style="margin:0; font-size:22px; line-height:1.3; font-weight:800; color:${ink};">
                    ${title}
                  </h1>
                </td>
              </tr>
              <tr>
                <td style="padding:16px 32px 0 32px;">
                  <p style="margin:0; font-size:15px; line-height:1.65; color:${inkMuted}; text-align:left;">
                    ${intro}
                  </p>
                </td>
              </tr>
              <tr>
                <td style="padding:20px 32px 0 32px;">
                  ${mainBlock}
                </td>
              </tr>
              ${outro ? `
              <tr>
                <td style="padding:16px 32px 0 32px;">
                  <p style="margin:0; font-size:14px; line-height:1.6; color:${inkMuted};">
                    ${outro}
                  </p>
                </td>
              </tr>` : ''}
              <tr>
                <td style="padding:28px 32px 0 32px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="height:1px; line-height:1px; font-size:1px; background-color:${border};">&nbsp;</td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="padding:20px 32px 32px 32px;" align="center">
                  <p style="margin:0; font-size:12px; line-height:1.6; color:${inkMuted};">
                    Une question&nbsp;? Contactez-nous directement depuis l’application.<br />
                    Merci de votre confiance, l’équipe Dios Délices.
                  </p>
                </td>
              </tr>
            </table>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px; margin-top:20px;">
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
  return { html, success, danger, brand, brandDark, ink, inkMuted, surfaceWarm, border };
}

async function sendSellerApprovedEmail({ to, firstname }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const intro = `
    ${hello}<br /><br />
    Nous avons le plaisir de vous annoncer que <strong style="color:#1B8A5A">votre demande de statut vendeur / restaurateur a été validée</strong> par notre équipe.
  `;
  const { html, success, brandDark } = _sellerLayout({
    title: 'Demande vendeur acceptée',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#EAF7EF; border:1.5px solid #BEE3CE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${success};">
            ✔ Votre compte est désormais un compte Restaurateur / Vendeur
          </td>
        </tr>
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            Vous pouvez dès à présent :
            <ul style="margin:8px 0 0 20px; padding:0;">
              <li>Créer et gérer votre restaurant sur l’application</li>
              <li>Ajouter vos plats et gérer votre carte</li>
              <li>Recevoir et traiter les commandes clients</li>
            </ul>
          </td>
        </tr>
      </table>
      <p style="margin:18px 0 0 0; font-size:14px; line-height:1.6; color:#2B211D;">
        ⚠️ Pour activer vos accès vendeur, <strong>veuillez vous déconnecter puis reconnecter</strong> à l’application Dios Délices. Votre rôle sera alors automatiquement mis à jour.
      </p>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre demande de statut vendeur / restaurateur a été validée par l'équipe Dios Délices.

Votre compte est désormais un compte Restaurateur / Vendeur.
Vous pouvez créer et gérer votre restaurant, ajouter vos plats et recevoir des commandes.

⚠️ IMPORTANT : Déconnectez-vous puis reconnectez-vous pour que votre nouveau rôle soit pris en compte.

Merci de votre confiance.
— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Votre statut vendeur a été validé',
    text,
    html,
  });
}

async function sendSellerRejectedEmail({ to, firstname, reason }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const safeReason = reason && String(reason).trim() ? escapeHtml(String(reason).trim()) : null;
  const intro = `
    ${hello}<br /><br />
    Nous avons étudié votre demande de statut vendeur / restaurateur et regrettons de vous informer qu’elle n’a pas été retenue à ce stade.
  `;
  const { html, danger } = _sellerLayout({
    title: 'Demande vendeur — Réponse de l’équipe',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FDECEA; border:1.5px solid #F2C2BE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${danger};">
            ✕ Demande non validée
          </td>
        </tr>
        ${safeReason ? `
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            <strong>Motif&nbsp;:</strong><br />
            ${safeReason}
          </td>
        </tr>` : ''}
      </table>
      <p style="margin:18px 0 0 0; font-size:14px; line-height:1.6; color:#2B211D;">
        Vous pouvez soumettre une nouvelle demande en complétant les documents demandés, ou nous contacter depuis l’application pour obtenir plus de précisions.
      </p>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre demande de statut vendeur / restaurateur n'a pas été validée à ce stade.
${safeReason ? `\nMotif :\n${safeReason}\n` : ''}
Vous pouvez soumettre une nouvelle demande ou contacter l'équipe depuis l'application Dios Délices.

— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Demande vendeur — Réponse de l’équipe',
    text,
    html,
  });
}

async function sendRestaurantApprovedEmail({ to, firstname, restaurantName }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const resto = restaurantName ? ` <strong>« ${escapeHtml(restaurantName)} »</strong>` : ' votre établissement';
  const intro = `
    ${hello}<br /><br />
    Excellente nouvelle&nbsp;:${resto} a été <strong style="color:#1B8A5A">validé et est désormais visible publiquement</strong> sur Dios Délices&nbsp;!
  `;
  const { html, success } = _sellerLayout({
    title: 'Restaurant validé ✔',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#EAF7EF; border:1.5px solid #BEE3CE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${success};">
            🍽 Votre restaurant est en ligne
          </td>
        </tr>
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            Les clients peuvent désormais découvrir votre carte et passer commande. Pensez à vérifier vos horaires, vos informations de contact et à activer les notifications pour ne manquer aucune commande.
          </td>
        </tr>
      </table>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre restaurant ${restaurantName ? '« ' + restaurantName + ' »' : ''} a été validé et est désormais visible sur Dios Délices.

Les clients peuvent découvrir votre carte et passer commande.
Vérifiez régulièrement vos commandes et gérez votre activité depuis l'application.

— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: `Dios Délices — ${restaurantName ? restaurantName + ' est en ligne' : 'Votre restaurant est validé'}`,
    text,
    html,
  });
}

async function sendRestaurantRejectedEmail({ to, firstname, restaurantName, reason }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const resto = restaurantName ? ` <strong>« ${escapeHtml(restaurantName)} »</strong>` : ' votre établissement';
  const safeReason = reason && String(reason).trim() ? escapeHtml(String(reason).trim()) : null;
  const intro = `
    ${hello}<br /><br />
    Nous avons étudié la fiche de${resto} et regrettons de vous informer qu’elle n’a pas été validée dans sa version actuelle.
  `;
  const { html, danger } = _sellerLayout({
    title: 'Restaurant — Avis de l’équipe',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FDECEA; border:1.5px solid #F2C2BE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${danger};">
            ✕ Fiche restaurant non validée
          </td>
        </tr>
        ${safeReason ? `
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            <strong>Motif&nbsp;:</strong><br />
            ${safeReason}
          </td>
        </tr>` : ''}
      </table>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre fiche restaurant ${restaurantName ? '« ' + restaurantName + ' »' : ''} n'a pas été validée dans sa version actuelle.
${safeReason ? `\nMotif :\n${safeReason}\n` : ''}
Vous pouvez la modifier et la soumettre à nouveau, ou contacter l'équipe depuis l'application.

— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Votre fiche restaurant',
    text,
    html,
  });
}

async function sendCourierApprovedEmail({ to, firstname }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const intro = `
    ${hello}<br /><br />
    Bonne nouvelle&nbsp;: <strong style="color:#1B8A5A">votre dossier livreur a été validé</strong>. Vous pouvez dès à présent prendre en charge des livraisons sur Dios Délices.
  `;
  const { html, success } = _sellerLayout({
    title: 'Dossier livreur validé ✔',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#EAF7EF; border:1.5px solid #BEE3CE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${success};">
            🛵 Vous êtes désormais livreur Dios Délices
          </td>
        </tr>
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            ⚠️ <strong>Veuillez vous déconnecter puis reconnecter</strong> pour que votre nouveau statut soit pris en compte. Passez ensuite en mode « disponible » pour recevoir des propositions de courses.
          </td>
        </tr>
      </table>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre dossier livreur a été validé. Vous pouvez désormais prendre en charge des livraisons sur Dios Délices.

⚠️ IMPORTANT : Déconnectez-vous puis reconnectez-vous pour que votre nouveau rôle soit pris en compte.

Bonnes courses !
— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Votre dossier livreur est validé',
    text,
    html,
  });
}

async function sendCourierRejectedEmail({ to, firstname, reason }) {
  const name = firstname ? escapeHtml(firstname) : '';
  const hello = name ? `Bonjour ${name},` : 'Bonjour,';
  const safeReason = reason && String(reason).trim() ? escapeHtml(String(reason).trim()) : null;
  const intro = `
    ${hello}<br /><br />
    Nous avons étudié votre dossier livreur et regrettons de vous informer qu’il n’a pas été retenu à ce stade.
  `;
  const { html, danger } = _sellerLayout({
    title: 'Dossier livreur — Réponse de l’équipe',
    intro,
    mainBlock: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FDECEA; border:1.5px solid #F2C2BE; border-radius:16px; padding:18px 20px;">
        <tr>
          <td style="font-size:16px; font-weight:700; color:${danger};">
            ✕ Dossier non validé
          </td>
        </tr>
        ${safeReason ? `
        <tr>
          <td style="padding-top:10px; font-size:14px; line-height:1.6; color:#2B211D;">
            <strong>Motif&nbsp;:</strong><br />
            ${safeReason}
          </td>
        </tr>` : ''}
      </table>
    `,
  });
  const text = `Bonjour${firstname ? ' ' + firstname : ''},

Votre dossier livreur n'a pas été validé à ce stade.
${safeReason ? `\nMotif :\n${safeReason}\n` : ''}
Vous pouvez soumettre à nouveau ou contacter l'équipe depuis l'application.

— L’équipe Dios Délices`;

  return sendEmail({
    to,
    subject: 'Dios Délices — Votre dossier livreur',
    text,
    html,
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
  sendSellerApprovedEmail,
  sendSellerRejectedEmail,
  sendRestaurantApprovedEmail,
  sendRestaurantRejectedEmail,
  sendCourierApprovedEmail,
  sendCourierRejectedEmail,
};
