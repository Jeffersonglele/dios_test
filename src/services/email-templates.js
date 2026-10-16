/// Gabarits des e-mails Dios Délices.
///
/// Chaque fonction `build*` est pure et renvoie `{ subject, text, html }`.
/// Le HTML suit les contraintes des clients mail : tableaux, styles en ligne,
/// largeur 600 px, aucune feuille de style externe. La version texte reprend
/// le même contenu pour les clients qui n'affichent pas le HTML.

const BRAND_NAME = 'Dios Délices';

const COLORS = Object.freeze({
  brand: '#C84C2F',
  brandDark: '#8E2F1B',
  page: '#F5EEE8',
  card: '#FFFCFA',
  panel: '#FEF0EB',
  border: '#E8D4C8',
  ink: '#261814',
  inkMuted: '#6D5B54',
  inkSubtle: '#9B8B84',
  success: '#2E7D50',
  successBg: '#EDF6F0',
  successBorder: '#C5E1CF',
  danger: '#B03A2E',
  dangerBg: '#FCEFEC',
  dangerBorder: '#F0C9C2',
});

const FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
const MONO = "'SFMono-Regular',Menlo,Consolas,'Courier New',monospace";

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function supportEmail() {
  return String(process.env.SUPPORT_EMAIL || 'contact@diosdelices.com').trim();
}

function logoUrl() {
  return String(process.env.EMAIL_LOGO_URL || '').trim();
}

function cleanReason(reason) {
  const value = reason == null ? '' : String(reason).trim();
  return value || null;
}

function greeting(firstname) {
  const name = firstname == null ? '' : String(firstname).trim();
  return name ? `Bonjour ${name},` : 'Bonjour,';
}

// ---------------------------------------------------------------------------
// Blocs HTML
// ---------------------------------------------------------------------------

function paragraph(html, { muted = false, small = false, spaceBefore = 16 } = {}) {
  const size = small ? 13 : 15;
  const color = muted ? COLORS.inkMuted : COLORS.ink;
  return `<p style="margin:${spaceBefore}px 0 0 0; font-family:${FONT}; font-size:${size}px; line-height:1.6; color:${color};">${html}</p>`;
}

/// Code à usage unique, bien visible et facile à sélectionner.
function codeBlock(code, caption) {
  return `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:24px;">
  <tr>
    <td align="center" style="background-color:${COLORS.panel}; border:1px solid ${COLORS.border}; border-radius:8px; padding:22px 16px;">
      <div style="font-family:${FONT}; font-size:12px; letter-spacing:1px; text-transform:uppercase; color:${COLORS.inkMuted};">${escapeHtml(caption)}</div>
      <div style="margin-top:8px; font-family:${MONO}; font-size:34px; font-weight:700; letter-spacing:8px; color:${COLORS.brandDark};">${escapeHtml(code)}</div>
    </td>
  </tr>
</table>`;
}

/// Encadré de statut. `tone` : 'success' | 'danger' | 'neutral'.
function noticeBlock({ tone = 'neutral', title, bodyHtml }) {
  const palette = {
    success: [COLORS.successBg, COLORS.successBorder, COLORS.success],
    danger: [COLORS.dangerBg, COLORS.dangerBorder, COLORS.danger],
    neutral: [COLORS.panel, COLORS.border, COLORS.ink],
  }[tone] || [COLORS.panel, COLORS.border, COLORS.ink];
  const [bg, border, accent] = palette;
  return `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:24px;">
  <tr>
    <td style="background-color:${bg}; border:1px solid ${border}; border-left:4px solid ${accent}; border-radius:6px; padding:16px 20px;">
      ${title ? `<div style="font-family:${FONT}; font-size:14px; font-weight:700; color:${accent};">${title}</div>` : ''}
      ${bodyHtml ? `<div style="margin-top:${title ? 6 : 0}px; font-family:${FONT}; font-size:14px; line-height:1.6; color:${COLORS.ink};">${bodyHtml}</div>` : ''}
    </td>
  </tr>
</table>`;
}

/// Liste d'étapes numérotées (sans balises <ol>, mal rendues par Outlook).
function stepsBlock(title, steps) {
  const rows = steps.map((step, index) => `
  <tr>
    <td valign="top" width="28" style="padding:8px 0 0 0;">
      <div style="width:22px; height:22px; line-height:22px; border-radius:11px; background-color:${COLORS.brand}; color:#FFFFFF; text-align:center; font-family:${FONT}; font-size:12px; font-weight:700;">${index + 1}</div>
    </td>
    <td valign="top" style="padding:8px 0 0 10px; font-family:${FONT}; font-size:14px; line-height:1.6; color:${COLORS.ink};">${step}</td>
  </tr>`).join('');
  return `
<div style="margin-top:28px; font-family:${FONT}; font-size:13px; font-weight:700; letter-spacing:0.5px; text-transform:uppercase; color:${COLORS.inkMuted};">${escapeHtml(title)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:4px;">${rows}
</table>`;
}

/// Tableau libellé / valeur (identifiants, détails d'un dossier…).
function detailsBlock(rows, { monoValues = false } = {}) {
  const body = rows.map(([label, value], index) => `
  <tr>
    <td valign="top" width="38%" style="padding:10px 12px 10px 16px; ${index ? `border-top:1px solid ${COLORS.border};` : ''} font-family:${FONT}; font-size:13px; color:${COLORS.inkMuted};">${escapeHtml(label)}</td>
    <td valign="top" style="padding:10px 16px 10px 0; ${index ? `border-top:1px solid ${COLORS.border};` : ''} font-family:${monoValues ? MONO : FONT}; font-size:14px; font-weight:600; color:${COLORS.ink}; word-break:break-word;">${escapeHtml(value)}</td>
  </tr>`).join('');
  return `
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:24px; background-color:${COLORS.panel}; border:1px solid ${COLORS.border}; border-radius:6px;">${body}
</table>`;
}

// ---------------------------------------------------------------------------
// Mise en page commune
// ---------------------------------------------------------------------------

function header() {
  const logo = logoUrl();
  const mark = logo
    ? `<img src="${escapeHtml(logo)}" alt="${BRAND_NAME}" height="36" style="display:block; height:36px; width:auto; border:0; outline:none; text-decoration:none;" />`
    : `<span style="font-family:Georgia,'Times New Roman',serif; font-size:22px; font-weight:700; color:#FFFFFF; letter-spacing:0.3px;">${BRAND_NAME}</span>`;
  return `
<tr>
  <td style="background-color:${COLORS.brand}; padding:22px 40px; border-radius:8px 8px 0 0;" class="px">
    ${mark}
  </td>
</tr>`;
}

function footer(reason) {
  const support = escapeHtml(supportEmail());
  const year = new Date().getFullYear();
  return `
<tr>
  <td style="padding:24px 40px 0 40px;" class="px">
    <p style="margin:0; font-family:${FONT}; font-size:12px; line-height:1.6; color:${COLORS.inkMuted};">
      <strong style="color:${COLORS.ink};">${BRAND_NAME}</strong> · Livraison de repas<br />
      Une question&nbsp;? Écrivez-nous à <a href="mailto:${support}" style="color:${COLORS.brand}; text-decoration:underline;">${support}</a> ou utilisez l’assistance dans l’application.
    </p>
    <p style="margin:12px 0 0 0; font-family:${FONT}; font-size:12px; line-height:1.6; color:${COLORS.inkSubtle};">
      ${reason}<br />
      © ${year} ${BRAND_NAME}
    </p>
  </td>
</tr>`;
}

/// Enveloppe HTML commune à tous les e-mails.
function renderLayout({ title, preheader, heading, bodyHtml, reason }) {
  return `<!DOCTYPE html>
<html lang="fr" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta http-equiv="X-UA-Compatible" content="IE=edge" />
<meta name="color-scheme" content="light" />
<meta name="supported-color-schemes" content="light" />
<title>${escapeHtml(title)}</title>
<style>
  @media only screen and (max-width:620px) {
    .container { width:100% !important; }
    .px { padding-left:24px !important; padding-right:24px !important; }
  }
</style>
</head>
<body style="margin:0; padding:0; background-color:${COLORS.page}; -webkit-text-size-adjust:100%; -ms-text-size-adjust:100%;">
<div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:${COLORS.page};">${escapeHtml(preheader || '')}&#8199;&#65279;&#847;&#8199;&#65279;&#847;&#8199;&#65279;&#847;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${COLORS.page};">
  <tr>
    <td align="center" style="padding:32px 12px;">
      <table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px; max-width:600px;">
        ${header()}
        <tr>
          <td class="px" style="background-color:${COLORS.card}; border:1px solid ${COLORS.border}; border-top:0; border-radius:0 0 8px 8px; padding:36px 40px 40px 40px;">
            <h1 style="margin:0; font-family:${FONT}; font-size:22px; line-height:1.35; font-weight:700; color:${COLORS.ink};">${escapeHtml(heading)}</h1>
            ${bodyHtml}
            ${paragraph(`L’équipe ${BRAND_NAME}`, { spaceBefore: 28 })}
          </td>
        </tr>
        ${footer(reason)}
      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
}

/// Version texte : même contenu, même pied de page.
function renderText({ lines, reason }) {
  const support = supportEmail();
  return [
    ...lines,
    '',
    `L’équipe ${BRAND_NAME}`,
    '',
    '--',
    `${BRAND_NAME} · Livraison de repas`,
    `Une question ? Écrivez-nous à ${support} ou utilisez l’assistance dans l’application.`,
    reason,
  ].join('\n');
}

function textParagraphsToHtml(text) {
  return String(text)
    .split(/\n{2,}/)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => paragraph(escapeHtml(block).replaceAll('\n', '<br />')))
    .join('');
}

// ---------------------------------------------------------------------------
// E-mails
// ---------------------------------------------------------------------------

const REASON_ACCOUNT = `Vous recevez cet e-mail parce que cette adresse est associée à un compte ${BRAND_NAME}.`;

function buildVerificationCodeEmail({ code, firstname }) {
  const reason = `Vous recevez cet e-mail parce qu’une inscription à ${BRAND_NAME} a été faite avec cette adresse.`;
  const html = renderLayout({
    title: 'Confirmez votre adresse e-mail',
    preheader: `Votre code de vérification : ${code}. Il est valable 15 minutes.`,
    heading: 'Confirmez votre adresse e-mail',
    reason,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph('Pour terminer la création de votre compte, saisissez le code ci-dessous dans l’application.'),
      codeBlock(code, 'Code de vérification'),
      paragraph('Ce code est valable <strong>15 minutes</strong>. Passé ce délai, vous pourrez en demander un nouveau depuis l’application.', { muted: true, small: true }),
      paragraph('Si vous n’avez pas créé de compte, ignorez simplement ce message : aucun compte ne sera activé sans ce code.', { muted: true, small: true, spaceBefore: 12 }),
    ].join(''),
  });
  const text = renderText({
    reason,
    lines: [
      greeting(firstname),
      '',
      'Pour terminer la création de votre compte, saisissez ce code dans l’application :',
      '',
      `    ${code}`,
      '',
      'Ce code est valable 15 minutes.',
      'Si vous n’avez pas créé de compte, ignorez simplement ce message : aucun compte ne sera activé sans ce code.',
    ],
  });
  return { subject: `Votre code de vérification ${BRAND_NAME}`, text, html };
}

function buildPasswordResetCodeEmail({ code }) {
  const reason = `Vous recevez cet e-mail parce qu’une réinitialisation de mot de passe a été demandée pour le compte ${BRAND_NAME} associé à cette adresse.`;
  const html = renderLayout({
    title: 'Réinitialisation de votre mot de passe',
    preheader: 'Votre code pour choisir un nouveau mot de passe. Il est valable 15 minutes.',
    heading: 'Réinitialisation de votre mot de passe',
    reason,
    bodyHtml: [
      paragraph('Bonjour,', { spaceBefore: 20 }),
      paragraph('Nous avons reçu une demande de réinitialisation du mot de passe de votre compte. Saisissez le code ci-dessous dans l’application pour en choisir un nouveau.'),
      codeBlock(code, 'Code de réinitialisation'),
      paragraph('Ce code est valable <strong>15 minutes</strong>.', { muted: true, small: true }),
      noticeBlock({
        tone: 'neutral',
        title: 'Vous n’êtes pas à l’origine de cette demande ?',
        bodyHtml: 'Ignorez ce message : votre mot de passe actuel reste inchangé. Ne communiquez jamais ce code, notre équipe ne vous le demandera pas.',
      }),
    ].join(''),
  });
  const text = renderText({
    reason,
    lines: [
      'Bonjour,',
      '',
      'Nous avons reçu une demande de réinitialisation du mot de passe de votre compte. Saisissez ce code dans l’application pour en choisir un nouveau :',
      '',
      `    ${code}`,
      '',
      'Ce code est valable 15 minutes.',
      '',
      'Vous n’êtes pas à l’origine de cette demande ? Ignorez ce message : votre mot de passe actuel reste inchangé. Ne communiquez jamais ce code, notre équipe ne vous le demandera pas.',
    ],
  });
  return { subject: `Réinitialisation de votre mot de passe ${BRAND_NAME}`, text, html };
}

function reasonBlock(reason) {
  return noticeBlock({
    tone: 'danger',
    title: 'Motif indiqué par notre équipe',
    bodyHtml: escapeHtml(reason).replaceAll('\n', '<br />'),
  });
}

function reasonText(reason) {
  return reason ? ['', 'Motif indiqué par notre équipe :', reason] : [];
}

function buildSellerApprovedEmail({ firstname }) {
  const steps = [
    'Déconnectez-vous puis reconnectez-vous à l’application. Vos accès vendeur seront alors actifs.',
    'Complétez la fiche de votre restaurant et ajoutez vos plats.',
    'Activez les notifications pour être averti de chaque nouvelle commande.',
  ];
  const html = renderLayout({
    title: 'Votre demande vendeur est acceptée',
    preheader: 'Votre compte peut désormais gérer un restaurant sur Dios Délices.',
    heading: 'Votre demande vendeur est acceptée',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph('Notre équipe a examiné et validé votre demande. Votre compte dispose maintenant des accès vendeur : vous pouvez gérer votre restaurant, votre carte et vos commandes depuis l’application.'),
      stepsBlock('Pour commencer', steps),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      'Notre équipe a examiné et validé votre demande. Votre compte dispose maintenant des accès vendeur : vous pouvez gérer votre restaurant, votre carte et vos commandes depuis l’application.',
      '',
      'Pour commencer :',
      ...steps.map((step, i) => `${i + 1}. ${step}`),
    ],
  });
  return { subject: 'Votre demande vendeur est acceptée', text, html };
}

function buildSellerRejectedEmail({ firstname, reason }) {
  const motif = cleanReason(reason);
  const html = renderLayout({
    title: 'Votre demande vendeur',
    preheader: 'Votre demande n’a pas pu être acceptée en l’état.',
    heading: 'Votre demande vendeur n’a pas été acceptée',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph('Nous avons examiné votre demande de compte vendeur et ne pouvons pas l’accepter en l’état.'),
      motif ? reasonBlock(motif) : '',
      paragraph('Vous pouvez corriger les éléments concernés et envoyer une nouvelle demande depuis l’application. Si un point n’est pas clair, contactez-nous : nous vous indiquerons ce qu’il manque.'),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      'Nous avons examiné votre demande de compte vendeur et ne pouvons pas l’accepter en l’état.',
      ...reasonText(motif),
      '',
      'Vous pouvez corriger les éléments concernés et envoyer une nouvelle demande depuis l’application. Si un point n’est pas clair, contactez-nous : nous vous indiquerons ce qu’il manque.',
    ],
  });
  return { subject: 'Votre demande vendeur', text, html };
}

function buildRestaurantApprovedEmail({ firstname, restaurantName }) {
  const name = restaurantName ? String(restaurantName).trim() : '';
  const label = name ? `« ${name} »` : 'votre restaurant';
  const checks = [
    'vos horaires d’ouverture sont à jour ;',
    'vos coordonnées et votre adresse sont exactes ;',
    'les notifications de l’application sont activées.',
  ];
  const html = renderLayout({
    title: 'Votre restaurant est en ligne',
    preheader: `${name || 'Votre restaurant'} est désormais visible par les clients.`,
    heading: 'Votre restaurant est en ligne',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph(`La fiche de <strong>${escapeHtml(label)}</strong> a été validée. Elle est désormais visible dans l’application : les clients peuvent consulter votre carte et passer commande.`),
      noticeBlock({
        tone: 'success',
        title: 'Avant vos premières commandes, vérifiez que :',
        bodyHtml: checks.map((c) => `&ndash;&nbsp;${escapeHtml(c)}`).join('<br />'),
      }),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      `La fiche de ${label} a été validée. Elle est désormais visible dans l’application : les clients peuvent consulter votre carte et passer commande.`,
      '',
      'Avant vos premières commandes, vérifiez que :',
      ...checks.map((c) => `- ${c}`),
    ],
  });
  return {
    subject: name ? `${name} est en ligne sur ${BRAND_NAME}` : `Votre restaurant est en ligne sur ${BRAND_NAME}`,
    text,
    html,
  };
}

function buildRestaurantRejectedEmail({ firstname, restaurantName, reason }) {
  const name = restaurantName ? String(restaurantName).trim() : '';
  const label = name ? `« ${name} »` : 'votre restaurant';
  const motif = cleanReason(reason);
  const html = renderLayout({
    title: 'Votre fiche restaurant',
    preheader: 'Votre fiche restaurant doit être modifiée avant publication.',
    heading: 'Votre fiche restaurant n’a pas été validée',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph(`Nous avons examiné la fiche de <strong>${escapeHtml(label)}</strong>. Elle ne peut pas être publiée dans sa version actuelle.`),
      motif ? reasonBlock(motif) : '',
      paragraph('Modifiez la fiche depuis l’application puis renvoyez-la : notre équipe l’examinera de nouveau.'),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      `Nous avons examiné la fiche de ${label}. Elle ne peut pas être publiée dans sa version actuelle.`,
      ...reasonText(motif),
      '',
      'Modifiez la fiche depuis l’application puis renvoyez-la : notre équipe l’examinera de nouveau.',
    ],
  });
  return { subject: 'Votre fiche restaurant doit être modifiée', text, html };
}

function buildCourierApprovedEmail({ firstname }) {
  const steps = [
    'Déconnectez-vous puis reconnectez-vous à l’application pour activer votre profil livreur.',
    'Passez en mode « Disponible » pour recevoir des propositions de course.',
  ];
  const html = renderLayout({
    title: 'Votre dossier livreur est validé',
    preheader: 'Vous pouvez désormais effectuer des livraisons avec Dios Délices.',
    heading: 'Votre dossier livreur est validé',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph(`Notre équipe a vérifié vos documents. Vous pouvez désormais effectuer des livraisons avec ${BRAND_NAME}.`),
      stepsBlock('Pour recevoir vos premières courses', steps),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      `Notre équipe a vérifié vos documents. Vous pouvez désormais effectuer des livraisons avec ${BRAND_NAME}.`,
      '',
      'Pour recevoir vos premières courses :',
      ...steps.map((step, i) => `${i + 1}. ${step}`),
    ],
  });
  return { subject: 'Votre dossier livreur est validé', text, html };
}

function buildCourierRejectedEmail({ firstname, reason }) {
  const motif = cleanReason(reason);
  const html = renderLayout({
    title: 'Votre dossier livreur',
    preheader: 'Votre dossier livreur doit être complété.',
    heading: 'Votre dossier livreur n’a pas été validé',
    reason: REASON_ACCOUNT,
    bodyHtml: [
      paragraph(escapeHtml(greeting(firstname)), { spaceBefore: 20 }),
      paragraph('Nous avons examiné votre dossier livreur et ne pouvons pas le valider en l’état.'),
      motif ? reasonBlock(motif) : '',
      paragraph('Vous pouvez renvoyer vos documents depuis l’application. Vérifiez que les photos sont nettes, que les documents sont en cours de validité et qu’ils sont à votre nom.'),
    ].join(''),
  });
  const text = renderText({
    reason: REASON_ACCOUNT,
    lines: [
      greeting(firstname),
      '',
      'Nous avons examiné votre dossier livreur et ne pouvons pas le valider en l’état.',
      ...reasonText(motif),
      '',
      'Vous pouvez renvoyer vos documents depuis l’application. Vérifiez que les photos sont nettes, que les documents sont en cours de validité et qu’ils sont à votre nom.',
    ],
  });
  return { subject: 'Votre dossier livreur', text, html };
}

function buildAdminAccountEmail({ name, accessLabel, username, temporaryPassword }) {
  const reason = `Vous recevez cet e-mail parce qu’un accès d’administration ${BRAND_NAME} a été créé pour cette adresse.`;
  const html = renderLayout({
    title: 'Votre accès administrateur',
    preheader: 'Vos identifiants de connexion à l’administration Dios Délices.',
    heading: 'Votre accès administrateur',
    reason,
    bodyHtml: [
      paragraph(escapeHtml(greeting(name)), { spaceBefore: 20 }),
      paragraph(`Un accès ${escapeHtml(accessLabel)} vient de vous être attribué. Voici vos identifiants de première connexion.`),
      detailsBlock([
        ['Identifiant', username],
        ['Mot de passe temporaire', temporaryPassword],
      ], { monoValues: true }),
      paragraph('À la première connexion, vous devrez choisir un nouveau mot de passe. Le mot de passe temporaire ne fonctionnera plus ensuite.', { muted: true, small: true }),
      paragraph('Si vous n’attendiez pas cet accès, prévenez-nous sans l’utiliser.', { muted: true, small: true, spaceBefore: 8 }),
    ].join(''),
  });
  const text = renderText({
    reason,
    lines: [
      greeting(name),
      '',
      `Un accès ${accessLabel} vient de vous être attribué. Voici vos identifiants de première connexion :`,
      '',
      `Identifiant : ${username}`,
      `Mot de passe temporaire : ${temporaryPassword}`,
      '',
      'À la première connexion, vous devrez choisir un nouveau mot de passe. Le mot de passe temporaire ne fonctionnera plus ensuite.',
      'Si vous n’attendiez pas cet accès, prévenez-nous sans l’utiliser.',
    ],
  });
  return { subject: `Votre accès administrateur ${BRAND_NAME}`, text, html };
}

/// Alerte interne : les lignes « Libellé : valeur » deviennent un tableau.
function buildAdminNotificationEmail({ subject, text }) {
  const reason = `Notification interne envoyée à l’équipe ${BRAND_NAME} (ADMIN_NOTIFICATION_EMAIL).`;
  const lines = String(text || '').split('\n');
  const detailPattern = /^([^:]{1,40}?)\s:\s(.*)$/;
  const intro = [];
  const details = [];
  for (const line of lines) {
    const match = line.match(detailPattern);
    if (match) details.push([match[1].trim(), match[2].trim()]);
    else if (line.trim()) intro.push(line.trim());
  }
  const heading = String(subject || '').replace(new RegExp(`^${BRAND_NAME}\\s*[—-]\\s*`), '') || 'Notification';
  const html = renderLayout({
    title: heading,
    preheader: intro[0] || heading,
    heading,
    reason,
    bodyHtml: [
      ...intro.map((line, i) => paragraph(escapeHtml(line), { spaceBefore: i ? 8 : 20 })),
      details.length ? detailsBlock(details) : '',
      paragraph('Le dossier est à traiter depuis l’espace d’administration.', { muted: true, small: true, spaceBefore: 20 }),
    ].join(''),
  });
  return { subject, text: renderText({ reason, lines: [String(text || '')] }), html };
}

/// Message libre écrit par un administrateur.
function buildDirectMessageEmail({ subject, text }) {
  const html = renderLayout({
    title: subject,
    preheader: String(text).split('\n')[0].slice(0, 120),
    heading: subject,
    reason: REASON_ACCOUNT,
    bodyHtml: `<div style="margin-top:4px;">${textParagraphsToHtml(text)}</div>`,
  });
  return { subject, text: renderText({ reason: REASON_ACCOUNT, lines: [String(text)] }), html };
}

module.exports = {
  COLORS,
  escapeHtml,
  renderLayout,
  buildVerificationCodeEmail,
  buildPasswordResetCodeEmail,
  buildSellerApprovedEmail,
  buildSellerRejectedEmail,
  buildRestaurantApprovedEmail,
  buildRestaurantRejectedEmail,
  buildCourierApprovedEmail,
  buildCourierRejectedEmail,
  buildAdminAccountEmail,
  buildAdminNotificationEmail,
  buildDirectMessageEmail,
};
