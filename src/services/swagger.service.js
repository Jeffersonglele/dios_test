const swaggerJsdoc = require('swagger-jsdoc');

const commonResponses = {
  Unauthorized: { description: 'Jeton absent, invalide ou expiré.' },
  Forbidden: { description: 'Droits insuffisants.' },
  NotFound: { description: 'Ressource introuvable.' },
  ValidationError: { description: 'Données de requête invalides.' },
};

function crudPaths(path, tag, readProtected = false) {
  const readSecurity = readProtected ? { security: [{ bearerAuth: [] }] } : {};
  return {
    [path]: {
      get: { tags: [tag], summary: `Lister les ${tag.toLowerCase()}`, ...readSecurity, responses: { 200: { description: 'Liste paginée.' }, ...(readProtected ? { 401: commonResponses.Unauthorized } : {}) } },
      post: { tags: [tag], summary: `Créer un ${tag.toLowerCase().replace(/s$/, '')}`, security: [{ bearerAuth: [] }], responses: { 201: { description: 'Créé.' }, 401: commonResponses.Unauthorized, 422: commonResponses.ValidationError } },
    },
    [`${path}/{id}`]: {
      get: { tags: [tag], summary: 'Obtenir par UUID', ...readSecurity, responses: { 200: { description: 'Ressource.' }, 404: commonResponses.NotFound, ...(readProtected ? { 401: commonResponses.Unauthorized } : {}) } },
      patch: { tags: [tag], summary: 'Mettre à jour', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Mis à jour.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } },
      delete: { tags: [tag], summary: 'Supprimer logiquement', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Supprimé.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } },
    },
  };
}

function buildSwaggerSpec() {
  const resourcePaths = [
    ['/api/v1/users', 'Utilisateurs', true], ['/api/v1/roles', 'Rôles', true], ['/api/v1/addresses', 'Adresses', true],
    ['/api/v1/restaurants', 'Restaurants'], ['/api/v1/dishes', 'Plats'], ['/api/v1/categories', 'Catégories'],
    ['/api/v1/gallery', 'Médias'], ['/api/v1/orders', 'Commandes', true], ['/api/v1/order-lines', 'Lignes de commande', true],
    ['/api/v1/payment-methods', 'Moyens de paiement', true], ['/api/v1/transactions', 'Transactions', true],
    ['/api/v1/promo-codes', 'Codes promo'], ['/api/v1/cities', 'Villes'], ['/api/v1/delivery-zones', 'Zones de livraison'],
    ['/api/v1/delivery-configs', 'Configuration livraison', true], ['/api/v1/identities', 'Identités', true],
    ['/api/v1/pro-documents', 'Documents professionnels', true], ['/api/v1/verification-codes', 'Codes de vérification', true],
    ['/api/v1/messages', 'Messages', true], ['/api/v1/comments', 'Commentaires', true], ['/api/v1/reports', 'Signalements', true],
    ['/api/v1/invoices', 'Factures', true], ['/api/v1/restaurant-payouts', 'Paiements restaurateurs', true],
    ['/api/v1/deliverer-payouts', 'Paiements livreurs', true], ['/api/v1/subscriptions', 'Abonnements', true],
    ['/api/v1/audit-logs', 'Audit', true], ['/api/v1/user-logins', 'Connexions', true],
  ];
  const paths = Object.assign({}, ...resourcePaths.map(([path, tag, readProtected]) => crudPaths(path, tag, readProtected)));
  Object.assign(paths, {
    '/health': { get: { tags: ['Système'], summary: 'État de santé du service', responses: { 200: { description: 'Service disponible.' } } } },
    '/api/v1/auth/register': { post: { tags: ['Authentification'], summary: 'Créer un compte', responses: { 201: { description: 'Compte créé avec jeton.' }, 409: { description: 'Email ou username déjà utilisé.' }, 422: commonResponses.ValidationError } } },
    '/api/v1/auth/login': { post: { tags: ['Authentification'], summary: 'Se connecter', responses: { 200: { description: 'Profil et jeton JWT.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/auth/me': { get: { tags: ['Authentification'], summary: 'Profil de la session', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Profil.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/auth/password/reset-request': { post: { tags: ['Authentification'], summary: 'Demander un code de réinitialisation', responses: { 200: { description: 'Réponse neutre.' } } } },
    '/api/v1/auth/password/reset': { post: { tags: ['Authentification'], summary: 'Réinitialiser le mot de passe', responses: { 200: { description: 'Mot de passe changé.' }, 422: commonResponses.ValidationError } } },
    '/api/v1/restaurants/{restaurantId}/menu': { get: { tags: ['Restaurants'], summary: 'Menu d’un restaurant', responses: { 200: { description: 'Restaurant et plats.' }, 404: commonResponses.NotFound } } },
    '/api/v1/restaurants/{id}/availability': { patch: { tags: ['Restaurants'], summary: 'Ouvrir ou fermer un restaurant', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Disponibilité mise à jour.' } } } },
    '/api/v1/orders/{id}/details': { get: { tags: ['Commandes'], summary: 'Commande, lignes et transactions', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Détails.' }, 404: commonResponses.NotFound } } },
    '/api/v1/orders/{id}/status': { patch: { tags: ['Commandes'], summary: 'Changer le statut de commande', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Statut mis à jour.' } } } },
    '/api/v1/transactions/{id}/status': { patch: { tags: ['Transactions'], summary: 'Recevoir un statut de paiement', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Transaction mise à jour.' } } } },
    '/api/v1/promo-codes/validate': { post: { tags: ['Codes promo'], summary: 'Valider un code promo', responses: { 200: { description: 'Réduction calculée.' }, 400: { description: 'Code invalide.' } } } },
    '/api/v1/delivery-zones/resolve': { post: { tags: ['Zones de livraison'], summary: 'Résoudre une zone par coordonnées', responses: { 200: { description: 'Zone trouvée.' }, 404: commonResponses.NotFound } } },
  });

  return swaggerJsdoc({
    definition: {
      openapi: '3.0.3',
      info: { title: 'Dios Delices API', version: '1.0.0', description: 'API Node.js de Dios Delices.' },
      servers: [{ url: process.env.API_BASE_URL || 'http://localhost:3000', description: 'Serveur local' }],
      tags: resourcePaths.map(([, name]) => ({ name })).concat([{ name: 'Authentification' }, { name: 'Système' }]),
      components: {
        securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
        schemas: {
          Error: { type: 'object', properties: { error: { type: 'object', properties: { message: { type: 'string' } } } } },
          PageMeta: { type: 'object', properties: { page: { type: 'integer' }, pageSize: { type: 'integer' }, total: { type: 'integer' }, totalPages: { type: 'integer' } } },
        },
      },
      paths,
    },
    apis: [],
  });
}

module.exports = { buildSwaggerSpec };
