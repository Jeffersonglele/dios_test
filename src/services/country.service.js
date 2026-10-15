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

/// Ville d'un compte ou d'un restaurant : celle demandée si elle existe et
/// appartient au pays, sinon l'unique ville active du pays (ex. Cotonou).
/// S'il y a plusieurs villes (RDC), renvoie null : la position GPS tranchera.
async function resolveCityId(db, country, requestedCityId) {
  const code = countryCode(country);
  const cityId = Number.parseInt(requestedCityId, 10);
  if (Number.isInteger(cityId)) {
    const city = await db.city.findFirst({ where: { cityId, active: true, deletedAt: null } });
    if (city && (!code || countryCode(city.countryCode) === code)) return city.cityId;
  }
  if (!code) return null;
  const cities = await db.city.findMany({
    where: { countryCode: code, active: true, deletedAt: null },
    select: { cityId: true },
    take: 2,
  });
  return cities.length === 1 ? cities[0].cityId : null;
}

module.exports = { COUNTRIES, canonicalCountry, countryCode, currencyForCountry, resolveCityId };
