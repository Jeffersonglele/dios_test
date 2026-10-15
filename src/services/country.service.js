// Pays pris en charge par Dios Délices et règles qui en dépendent
// (libellé canonique, devise locale). Une seule source pour l'inscription,
// le portefeuille et la tarification.

const COUNTRIES = Object.freeze({
  CD: { code: 'CD', name: 'RDC', currency: 'CDF' },
  BJ: { code: 'BJ', name: 'Bénin', currency: 'XOF' },
});

/// Code pays (CD, BJ) déduit d'une valeur libre : « RDC », « Bénin »,
/// « BENIN », « BJ », « XOF », « République démocratique du Congo »…
function countryCode(value) {
  const hint = String(value || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim()
    .toUpperCase();
  if (!hint) return null;
  if (hint === 'BJ' || hint === 'XOF' || hint.includes('BENIN')) return 'BJ';
  if (hint === 'CD' || hint === 'CDF' || hint === 'RDC' || hint.includes('CONGO')) return 'CD';
  return null;
}

/// Libellé enregistré en base (« RDC », « Bénin »), ou null si inconnu.
function canonicalCountry(value) {
  const code = countryCode(value);
  return code ? COUNTRIES[code].name : null;
}

/// Devise locale du pays ; CDF par défaut (marché principal).
function currencyForCountry(value) {
  const code = countryCode(value);
  return code ? COUNTRIES[code].currency : 'CDF';
}

module.exports = { COUNTRIES, canonicalCountry, countryCode, currencyForCountry };
