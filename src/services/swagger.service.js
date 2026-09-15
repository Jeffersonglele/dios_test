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
    '/api/v1/payments/cinetpay/initialize': { post: { tags: ['Paiements'], summary: 'Initialiser un paiement CinetPay', description: 'Mode mock par défaut ; le montant provient toujours de la commande enregistrée.', security: [{ bearerAuth: [] }], responses: { 201: { description: 'Tentative créée.' }, 400: { description: 'Commande non payable.' }, 401: commonResponses.Unauthorized, 503: { description: 'Configuration de paiement indisponible.' } } } },
    '/api/v1/payments/cinetpay/tips/initialize': { post: { tags: ['Paiements'], summary: 'Initialiser un pourboire numérique après livraison', description: 'Disponible uniquement après une livraison réussie. Le montant est une transaction séparée, due intégralement au livreur.', security: [{ bearerAuth: [] }], responses: { 201: { description: 'Tentative de pourboire créée.' }, 400: { description: 'Livraison ou montant invalide.' } } } },
    '/api/v1/payments/cinetpay/{transactionId}': { get: { tags: ['Paiements'], summary: 'Consulter le statut d’un paiement CinetPay', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Statut du paiement.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } } },
    '/api/v1/payments/cinetpay/mock/{transactionId}/confirm': { post: { tags: ['Paiements'], summary: 'Simuler la confirmation CinetPay', description: 'Disponible seulement si CINETPAY_MODE=mock.', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Paiement simulé confirmé ou refusé.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } } },
    '/api/v1/payments/cinetpay/webhook': { post: { tags: ['Paiements'], summary: 'Webhook CinetPay', description: 'Endpoint prestataire : signature HMAC puis vérification serveur de la transaction.', responses: { 200: { description: 'Notification traitée.' }, 401: { description: 'Signature invalide.' } } } },
    '/api/v1/orders/{id}/cash-collection': { post: { tags: ['Paiements'], summary: 'Confirmer l’encaissement espèces à la livraison', description: 'Réservé au livreur assigné après livraison. Le montant ne peut pas être modifié.', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Encaissement confirmé.' }, 400: { description: 'Course ou montant invalide.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/wallet/me': { get: { tags: ['Portefeuille'], summary: 'Consulter le portefeuille Dios', description: 'Le portefeuille reste désactivé tant que son activation n’est pas validée.', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Solde calculé depuis le grand livre ou statut désactivé.' } } } },
    '/api/v1/wallet/me/ledger': { get: { tags: ['Portefeuille'], summary: 'Lister le grand livre portefeuille', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Historique paginé.' } } } },
    '/api/v1/wallet/top-ups': { post: { tags: ['Portefeuille'], summary: 'Demander une recharge portefeuille', description: 'Retourne indisponible tant que le montage réglementaire et le prestataire ne sont pas validés.', security: [{ bearerAuth: [] }], responses: { 503: { description: 'Portefeuille non activé.' } } } },
    '/api/v1/mobile-money-accounts': { get: { tags: ['Portefeuille'], summary: 'Lister les numéros Mobile Money RDC', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Numéros du client connecté.' } } }, post: { tags: ['Portefeuille'], summary: 'Ajouter un numéro Mobile Money RDC', security: [{ bearerAuth: [] }], responses: { 201: { description: 'Numéro ajouté sans être débité.' }, 400: { description: 'Opérateur ou numéro invalide.' } } } },
    '/api/v1/mobile-money-accounts/{id}/default': { patch: { tags: ['Portefeuille'], summary: 'Choisir le numéro Mobile Money par défaut', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Numéro par défaut mis à jour.' } } } },
    '/api/v1/transactions/{id}/status': { patch: { tags: ['Transactions'], summary: 'Recevoir un statut de paiement', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Transaction mise à jour.' } } } },
    '/api/v1/promo-codes/validate': { post: { tags: ['Codes promo'], summary: 'Valider un code promo', responses: { 200: { description: 'Réduction calculée.' }, 400: { description: 'Code invalide.' } } } },
    '/api/v1/delivery-zones/resolve': { post: { tags: ['Zones de livraison'], summary: 'Résoudre une zone par coordonnées', responses: { 200: { description: 'Zone trouvée.' }, 404: commonResponses.NotFound } } },
    '/api/v1/geocoding/search': { get: { tags: ['Géocodage'], summary: 'Rechercher une adresse RDC avec Nominatim', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Adresses proposées, avec cache éventuel.' }, 503: { description: 'Nominatim non configuré.' } } } },
    '/api/v1/geocoding/reverse': { get: { tags: ['Géocodage'], summary: 'Obtenir une adresse RDC depuis des coordonnées', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Adresse inverse proposée.' }, 400: { description: 'Coordonnées hors RDC ou invalides.' } } } },
    '/api/v1/uploads/image': { post: { tags: ['Médias'], summary: 'Téléverser une image', description: 'JPEG, PNG ou WebP, 5 Mo maximum. Les images sont réencodées en WebP.', security: [{ bearerAuth: [] }], requestBody: { required: true, content: { 'multipart/form-data': { schema: { type: 'object', required: ['image'], properties: { image: { type: 'string', format: 'binary' }, scope: { type: 'string', example: 'restaurants' } } } } } }, responses: { 201: { description: 'Média téléversé.' }, 413: { description: 'Fichier trop volumineux.' }, 415: { description: 'Format non accepté.' } } } },
    '/api/v1/uploads/images': { post: { tags: ['Médias'], summary: 'Téléverser jusqu’à cinq images', security: [{ bearerAuth: [] }], responses: { 201: { description: 'Médias téléversés.' } } } },
    '/api/v1/delivery/quote': { post: { tags: ['Livraison'], summary: 'Obtenir le devis de livraison serveur', description: 'Vérifie les deux positions dans la même ville RDC, estime la distance routière et calcule le prix CDF.', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Devis ou indisponibilité.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/addresses/{addressId}/location': { patch: { tags: ['Livraison'], summary: 'Actualiser l’adresse de livraison GPS', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Adresse et ville résolues par PostGIS.' }, 400: { description: 'Position hors zone.' } } } },
    '/api/v1/restaurants/{restaurantId}/location': { patch: { tags: ['Livraison'], summary: 'Définir la position fixe du point de vente', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Restaurant géolocalisé.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/cities/{cityId}/boundary': { patch: { tags: ['Livraison'], summary: 'Importer la limite GeoJSON d’une ville', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Limite PostGIS enregistrée.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/couriers/me/availability': { patch: { tags: ['Livraison'], summary: 'Passer livreur disponible ou indisponible', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Disponibilité modifiée.' }, 400: { description: 'Position GPS requise pour devenir actif.' } } } },
    '/api/v1/couriers/me/location': { post: { tags: ['Livraison'], summary: 'Enregistrer une position livreur active', security: [{ bearerAuth: [] }], responses: { 201: { description: 'Position et ville enregistrées.' } } } },
    '/api/v1/couriers/me/offers': { get: { tags: ['Livraison'], summary: 'Consulter les propositions de course actives', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Propositions classées par proximité.' } } } },
    '/api/v1/delivery-offers/{id}/accept': { post: { tags: ['Livraison'], summary: 'Accepter une course proposée', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Course attribuée atomiquement.' }, 409: { description: 'Course déjà prise ou expirée.' } } } },
    '/api/v1/delivery-offers/{id}/reject': { post: { tags: ['Livraison'], summary: 'Refuser une course proposée', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Proposition refusée.' } } } },
    '/api/v1/deliveries/{id}/status': { patch: { tags: ['Livraison'], summary: 'Faire progresser une livraison', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Statut avancé.' }, 409: { description: 'Transition non autorisée.' } } } },
  });

  return swaggerJsdoc({
    definition: {
      openapi: '3.0.3',
      info: { title: 'Dios Delices API', version: '1.0.0', description: 'API Node.js de Dios Delices.' },
      servers: [{ url: process.env.API_BASE_URL || 'http://localhost:3000', description: 'Serveur local' }],
      tags: resourcePaths.map(([, name]) => ({ name })).concat([{ name: 'Authentification' }, { name: 'Paiements' }, { name: 'Livraison' }, { name: 'Géocodage' }, { name: 'Médias' }, { name: 'Portefeuille' }, { name: 'Système' }]),
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
