const swaggerJsdoc = require('swagger-jsdoc');

const commonResponses = {
  Unauthorized: { description: 'Jeton absent, invalide ou expiré.' },
  Forbidden: { description: 'Droits insuffisants.' },
  NotFound: { description: 'Ressource introuvable.' },
  ValidationError: { description: 'Données de requête invalides.' },
};

function pathParameter(name, description, schema = { type: 'string', format: 'uuid' }) {
  return { name, in: 'path', required: true, description, schema };
}

function queryParameter(name, description, schema, required = false) {
  return { name, in: 'query', description, required, schema };
}

function paginationParameters(filterFields = [], includeDeleted = true) {
  return [
    queryParameter('page', 'Numéro de page.', { type: 'integer', minimum: 1, default: 1 }),
    queryParameter('pageSize', 'Nombre d’éléments par page.', { type: 'integer', minimum: 1, maximum: 100, default: 20 }),
    queryParameter('limit', 'Alias de pageSize.', { type: 'integer', minimum: 1, maximum: 100 }),
    ...(includeDeleted ? [queryParameter('includeDeleted', 'Inclure les ressources supprimées logiquement.', { type: 'boolean', default: false })] : []),
    ...filterFields.map((field) => queryParameter(field, `Filtrer par ${field}.`, filterSchema(field))),
  ];
}

function filterSchema(field) {
  if (['active', 'isOpen', 'read', 'verified'].includes(field)) return { type: 'boolean' };
  if (['cityId', 'userId', 'restaurantId', 'restaurateurId', 'delivererId', 'roleId'].includes(field)) {
    return { type: 'integer', minimum: 1 };
  }
  return { type: 'string' };
}

function jsonRequestBody(description = 'Corps JSON de la requête.', example = {}, required = true) {
  return {
    required,
    description,
    content: {
      'application/json': {
        schema: { type: 'object', additionalProperties: true },
        example,
      },
    },
  };
}

function crudPaths({ path, tag, singular, article, readProtected = false, softDelete = true, filterFields = [], bodyExample = {} }) {
  const readSecurity = readProtected ? { security: [{ bearerAuth: [] }] } : {};
  const resourceName = singular.toLowerCase();
  const deleteDescription = softDelete
    ? 'Suppression logique : la ressource est marquée comme supprimée et n’apparaît plus dans les listes actives.'
    : 'Suppression définitive de la ressource.';

  return {
    [path]: {
      get: { tags: [tag], summary: `Lister les ${tag.toLowerCase()}`, parameters: paginationParameters(filterFields, softDelete), ...readSecurity, responses: { 200: { description: 'Liste paginée.' }, ...(readProtected ? { 401: commonResponses.Unauthorized } : {}) } },
      post: { tags: [tag], summary: `Créer ${article} ${resourceName}`, security: [{ bearerAuth: [] }], requestBody: jsonRequestBody(`Données de création pour ${resourceName}.`, bodyExample), responses: { 201: { description: 'Ressource créée.' }, 401: commonResponses.Unauthorized, 422: commonResponses.ValidationError } },
    },
    [`${path}/{id}`]: {
      get: { tags: [tag], summary: 'Obtenir par UUID', parameters: [pathParameter('id', `UUID ${resourceName}.`)], ...readSecurity, responses: { 200: { description: 'Ressource.' }, 404: commonResponses.NotFound, ...(readProtected ? { 401: commonResponses.Unauthorized } : {}) } },
      patch: { tags: [tag], summary: 'Mettre à jour', parameters: [pathParameter('id', `UUID ${resourceName}.`)], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody(`Champs à modifier pour ${resourceName}.`, bodyExample), responses: { 200: { description: 'Mis à jour.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } },
      delete: { tags: [tag], summary: `Supprimer ${article} ${resourceName}`, description: deleteDescription, parameters: [pathParameter('id', `UUID ${resourceName}.`)], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Ressource supprimée.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } },
    },
  };
}

function buildSwaggerSpec() {
  const resourcePaths = [
    { path: '/api/v1/users', tag: 'Utilisateurs', singular: 'Utilisateur', article: 'un', readProtected: true, filterFields: ['country', 'status', 'roleId', 'cityId', 'accountType'], bodyExample: { username: 'demo', email: 'demo@example.com' } },
    { path: '/api/v1/roles', tag: 'Rôles', singular: 'Rôle', article: 'un', readProtected: true, filterFields: ['name'], bodyExample: { name: 'LIVREUR' } },
    { path: '/api/v1/addresses', tag: 'Adresses', singular: 'Adresse', article: 'une', readProtected: true, bodyExample: { fullAddress: '10 avenue de la Paix', city: 'Kinshasa', country: 'RDC' } },
    { path: '/api/v1/restaurants', tag: 'Restaurants', singular: 'Restaurant', article: 'un', filterFields: ['cityId', 'userId', 'isOpen', 'q'], bodyExample: { name: 'Dios Délices', userId: 1, cityId: 1, address: 'Kinshasa' } },
    { path: '/api/v1/dishes', tag: 'Plats', singular: 'Plat', article: 'un', filterFields: ['restaurantId', 'userId', 'cityId', 'status', 'q'], bodyExample: { name: 'Poulet braisé', restaurantId: 1, price: 10000, currency: 'CDF' } },
    { path: '/api/v1/categories', tag: 'Catégories', singular: 'Catégorie', article: 'une', filterFields: ['name'], bodyExample: { name: 'Plats africains' } },
    { path: '/api/v1/gallery', tag: 'Médias', singular: 'Média', article: 'un', bodyExample: { fileUrl: 'https://example.com/image.webp', name: 'Photo du plat' } },
    { path: '/api/v1/orders', tag: 'Commandes', singular: 'Commande', article: 'une', readProtected: true, filterFields: ['status', 'country', 'deliveryMode', 'paymentProvider', 'userId', 'restaurantId', 'restaurateurId', 'delivererId', 'cityId'], bodyExample: { restaurantId: 1, lines: [{ dishId: 1, quantity: 1 }], deliveryMode: 'PICKUP', paymentMethod: 'CASH' } },
    { path: '/api/v1/order-lines', tag: 'Lignes de commande', singular: 'Ligne de commande', article: 'une', readProtected: true, bodyExample: { orderId: '1', dishId: 1, quantity: 1 } },
    { path: '/api/v1/payment-methods', tag: 'Moyens de paiement', singular: 'Moyen de paiement', article: 'un', readProtected: true, filterFields: ['userId', 'type'], bodyExample: { type: 'MOBILE_MONEY', label: 'M-Pesa' } },
    { path: '/api/v1/transactions', tag: 'Transactions', singular: 'Transaction', article: 'une', readProtected: true, filterFields: ['provider', 'status', 'settlementStatus'], bodyExample: { orderId: 1, provider: 'cash', amount: 10000, currency: 'CDF' } },
    { path: '/api/v1/promo-codes', tag: 'Codes promo', singular: 'Code promo', article: 'un', filterFields: ['code', 'active'], bodyExample: { code: 'BIENVENUE10', discountPercent: 10, active: true } },
    { path: '/api/v1/cities', tag: 'Villes', singular: 'Ville', article: 'une', filterFields: ['country', 'active'], bodyExample: { name: 'Kinshasa', country: 'RDC', active: true } },
    { path: '/api/v1/delivery-zones', tag: 'Zones de livraison', singular: 'Zone de livraison', article: 'une', filterFields: ['cityId', 'active', 'deliveryFeeLevel'], bodyExample: { cityId: 1, name: 'Gombe', polygon: '[[[-4.3,15.2],[-4.4,15.2],[-4.4,15.3]]]' } },
    { path: '/api/v1/delivery-configs', tag: 'Configurations de livraison', singular: 'Configuration de livraison', article: 'une', readProtected: true, softDelete: false, filterFields: ['active'], bodyExample: { cityId: 1, baseFee: 1000, currency: 'CDF', active: true } },
    { path: '/api/v1/identities', tag: 'Identités', singular: 'Vérification d’identité', article: 'une', readProtected: true, filterFields: ['status'], bodyExample: { userId: 1, identityFileUrl: 'https://example.com/id.pdf', status: 'pending' } },
    { path: '/api/v1/pro-documents', tag: 'Documents professionnels', singular: 'Document professionnel', article: 'un', readProtected: true, filterFields: ['status'], bodyExample: { userId: 1, restaurantId: 1, description: 'Document professionnel' } },
    { path: '/api/v1/verification-codes', tag: 'Codes de vérification', singular: 'Code de vérification', article: 'un', readProtected: true, softDelete: false, filterFields: ['email', 'phone', 'purpose', 'verified'], bodyExample: { email: 'demo@example.com', code: '123456', purpose: 'password_reset' } },
    { path: '/api/v1/messages', tag: 'Messages', singular: 'Message', article: 'un', readProtected: true, filterFields: ['fromUserId', 'toUserId', 'orderId'], bodyExample: { toUserId: 1, text: 'Bonjour' } },
    { path: '/api/v1/comments', tag: 'Commentaires', singular: 'Commentaire', article: 'un', readProtected: true, filterFields: ['userId', 'target', 'targetId'], bodyExample: { target: 'DISH', targetId: '1', description: 'Très bon plat' } },
    { path: '/api/v1/reports', tag: 'Signalements', singular: 'Signalement', article: 'un', readProtected: true, filterFields: ['targetType', 'status'], bodyExample: { targetType: 'DISH', targetId: '1', reason: 'Contenu incorrect' } },
    { path: '/api/v1/invoices', tag: 'Factures', singular: 'Facture', article: 'une', readProtected: true, bodyExample: { orderId: 1, totalCdf: 10000, currency: 'CDF' } },
    { path: '/api/v1/restaurant-payouts', tag: 'Paiements restaurateurs', singular: 'Paiement restaurateur', article: 'un', readProtected: true, filterFields: ['restaurantId', 'status', 'cityId'], bodyExample: { restaurantId: 1, status: 'PENDING' } },
    { path: '/api/v1/deliverer-payouts', tag: 'Paiements livreurs', singular: 'Paiement livreur', article: 'un', readProtected: true, filterFields: ['delivererId', 'status'], bodyExample: { delivererId: 1, status: 'PENDING' } },
    { path: '/api/v1/subscriptions', tag: 'Abonnements', singular: 'Abonnement', article: 'un', readProtected: true, filterFields: ['restaurantId', 'status', 'plan', 'cityId'], bodyExample: { restaurantId: 1, plan: 'BASIC', status: 'ACTIVE' } },
    { path: '/api/v1/audit-logs', tag: 'Journaux d’audit', singular: 'Journal d’audit', article: 'un', readProtected: true, filterFields: ['action', 'country'], bodyExample: { action: 'LOGIN', country: 'RDC' } },
    { path: '/api/v1/user-logins', tag: 'Connexions', singular: 'Connexion', article: 'une', readProtected: true, filterFields: ['userId', 'username'], bodyExample: { userId: 1, username: 'demo' } },
  ];
  const paths = Object.assign({}, ...resourcePaths.map((resource) => crudPaths(resource)));
  Object.assign(paths, {
    '/health': { get: { tags: ['Système'], summary: 'État de santé du service', responses: { 200: { description: 'Service disponible.' } } } },
    '/api/v1/auth/register': { post: { tags: ['Authentification'], summary: 'Créer un compte', requestBody: jsonRequestBody('Informations du nouveau compte.', { username: 'demo', email: 'demo@example.com', password: 'MotDePasse123!' }), responses: { 201: { description: 'Compte créé avec jeton.' }, 409: { description: 'Email ou username déjà utilisé.' }, 422: commonResponses.ValidationError } } },
    '/api/v1/auth/login': { post: { tags: ['Authentification'], summary: 'Se connecter', requestBody: jsonRequestBody('Identifiants de connexion.', { identifier: 'demo@example.com', password: 'MotDePasse123!' }), responses: { 200: { description: 'Profil et jeton JWT.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/auth/me': { get: { tags: ['Authentification'], summary: 'Profil de la session', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Profil.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/auth/password/reset-request': { post: { tags: ['Authentification'], summary: 'Demander un code de réinitialisation', requestBody: jsonRequestBody('Adresse email du compte.', { email: 'demo@example.com' }), responses: { 200: { description: 'Réponse neutre.' } } } },
    '/api/v1/auth/password/reset': { post: { tags: ['Authentification'], summary: 'Réinitialiser le mot de passe', requestBody: jsonRequestBody('Email, code reçu et nouveau mot de passe.', { email: 'demo@example.com', code: '123456', password: 'NouveauMotDePasse123!' }), responses: { 200: { description: 'Mot de passe changé.' }, 422: commonResponses.ValidationError } } },
    '/api/v1/users/{id}/profile': { patch: { tags: ['Utilisateurs'], summary: 'Modifier son profil', parameters: [pathParameter('id', 'UUID de l’utilisateur.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Champs du profil à modifier.', { firstname: 'Jean', lastname: 'Dupont', telephone: '+243810000000' }), responses: { 200: { description: 'Profil mis à jour.' }, 401: commonResponses.Unauthorized, 403: commonResponses.Forbidden, 404: commonResponses.NotFound } } },
    '/api/v1/users/{id}/identity-status': { patch: { tags: ['Utilisateurs'], summary: 'Modifier le statut d’identité', parameters: [pathParameter('id', 'UUID de l’utilisateur.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Nouveau statut d’identité.', { identity: 'Vérifiée', status: 'verified' }), responses: { 200: { description: 'Statut d’identité mis à jour.' }, 401: commonResponses.Unauthorized, 403: commonResponses.Forbidden, 404: commonResponses.NotFound } } },
    '/api/v1/restaurants/{restaurantId}/menu': { get: { tags: ['Restaurants'], summary: 'Menu d’un restaurant', parameters: [pathParameter('restaurantId', 'Identifiant numérique du restaurant.', { type: 'integer', minimum: 1 }), ...paginationParameters()], responses: { 200: { description: 'Restaurant et plats.' }, 404: commonResponses.NotFound } } },
    '/api/v1/restaurants/{id}/availability': { patch: { tags: ['Restaurants'], summary: 'Ouvrir ou fermer un restaurant', parameters: [pathParameter('id', 'UUID du restaurant.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Nouvel état de disponibilité.', { isOpen: true }), responses: { 200: { description: 'Disponibilité mise à jour.' } } } },
    '/api/v1/orders/{id}/details': { get: { tags: ['Commandes'], summary: 'Commande, lignes et transactions', parameters: [pathParameter('id', 'UUID de la commande.')], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Détails.' }, 404: commonResponses.NotFound } } },
    '/api/v1/orders/{id}/status': { patch: { tags: ['Commandes'], summary: 'Changer le statut de commande', parameters: [pathParameter('id', 'UUID de la commande.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Nouveau statut de commande.', { status: 'EN_PREPARATION', orderStatus: 'EN_PREPARATION' }), responses: { 200: { description: 'Statut mis à jour.' } } } },
    '/api/v1/payments/cinetpay/initialize': { post: { tags: ['Paiements'], summary: 'Initialiser un paiement CinetPay', description: 'Mode mock par défaut ; le montant provient toujours de la commande enregistrée.', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Commande à payer.', { orderId: 'UUID_DE_LA_COMMANDE', channels: 'ALL' }), responses: { 201: { description: 'Tentative créée.' }, 400: { description: 'Commande non payable.' }, 401: commonResponses.Unauthorized, 503: { description: 'Configuration de paiement indisponible.' } } } },
    '/api/v1/payments/cinetpay/tips/initialize': { post: { tags: ['Paiements'], summary: 'Initialiser un pourboire numérique après livraison', description: 'Disponible uniquement après une livraison réussie. Le montant est une transaction séparée, due intégralement au livreur.', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Commande, montant du pourboire et canaux de paiement.', { orderId: 'UUID_DE_LA_COMMANDE', amount: 1000, channels: 'ALL' }), responses: { 201: { description: 'Tentative de pourboire créée.' }, 400: { description: 'Livraison ou montant invalide.' } } } },
    '/api/v1/payments/cinetpay/{transactionId}': { get: { tags: ['Paiements'], summary: 'Consulter le statut d’un paiement CinetPay', parameters: [pathParameter('transactionId', 'Référence de transaction CinetPay.', { type: 'string' })], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Statut du paiement.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } } },
    '/api/v1/payments/cinetpay/mock/{transactionId}/confirm': { post: { tags: ['Paiements'], summary: 'Simuler la confirmation CinetPay', description: 'Disponible seulement si CINETPAY_MODE=mock.', parameters: [pathParameter('transactionId', 'Référence de transaction CinetPay.', { type: 'string' })], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Résultat simulé du paiement.', { success: true }), responses: { 200: { description: 'Paiement simulé confirmé ou refusé.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } } },
    '/api/v1/payments/cinetpay/return': { get: { tags: ['Paiements'], summary: 'Retour après paiement CinetPay', responses: { 200: { description: 'Résultat du retour de paiement.' } } } },
    '/api/v1/payments/cinetpay/webhook': { post: { tags: ['Paiements'], summary: 'Webhook CinetPay', description: 'Endpoint prestataire : signature HMAC puis vérification serveur de la transaction.', parameters: [{ name: 'x-token', in: 'header', required: true, description: 'Signature HMAC fournie par CinetPay.', schema: { type: 'string' } }], requestBody: jsonRequestBody('Notification envoyée par CinetPay.', { cpm_trans_id: 'DD-123-abc', cpm_site_id: '123456', cpm_trans_date: '2026-09-16 12:00:00' }), responses: { 200: { description: 'Notification traitée.' }, 401: { description: 'Signature invalide.' } } } },
    '/api/v1/orders/{id}/cash-collection': { post: { tags: ['Paiements'], summary: 'Confirmer l’encaissement espèces à la livraison', description: 'Réservé au livreur assigné après livraison. Le montant ne peut pas être modifié.', parameters: [pathParameter('id', 'UUID de la commande.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Montant encaissé. Laisser vide pour utiliser le total de la commande.', { collectedAmount: 10000 }, false), responses: { 200: { description: 'Encaissement confirmé.' }, 400: { description: 'Course ou montant invalide.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/wallet/me': { get: { tags: ['Portefeuille'], summary: 'Consulter le portefeuille Dios', description: 'Le portefeuille reste désactivé tant que son activation n’est pas validée.', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Solde calculé depuis le grand livre ou statut désactivé.' } } } },
    '/api/v1/wallet/me/ledger': { get: { tags: ['Portefeuille'], summary: 'Lister le grand livre portefeuille', parameters: paginationParameters(), security: [{ bearerAuth: [] }], responses: { 200: { description: 'Historique paginé.' } } } },
    '/api/v1/wallet/top-ups': { post: { tags: ['Portefeuille'], summary: 'Demander une recharge portefeuille', description: 'Retourne indisponible tant que le montage réglementaire et le prestataire ne sont pas validés.', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Montant de la recharge et moyen de paiement.', { amount: 10000, mobileMoneyAccountId: 'UUID_DU_COMPTE' }), responses: { 503: { description: 'Portefeuille non activé.' } } } },
    '/api/v1/mobile-money-accounts': { get: { tags: ['Portefeuille'], summary: 'Lister les numéros Mobile Money RDC', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Numéros du client connecté.' } } }, post: { tags: ['Portefeuille'], summary: 'Ajouter un numéro Mobile Money RDC', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Numéro Mobile Money à enregistrer.', { operator: 'MPESA', phoneE164: '+243810000000', label: 'Téléphone principal', isDefault: true }), responses: { 201: { description: 'Numéro ajouté sans être débité.' }, 400: { description: 'Opérateur ou numéro invalide.' } } } },
    '/api/v1/mobile-money-accounts/{id}': { delete: { tags: ['Portefeuille'], summary: 'Supprimer un numéro Mobile Money RDC', description: 'Suppression définitive du numéro enregistré.', parameters: [pathParameter('id', 'UUID du compte Mobile Money.')], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Numéro supprimé.' }, 401: commonResponses.Unauthorized, 404: commonResponses.NotFound } } },
    '/api/v1/mobile-money-accounts/{id}/default': { patch: { tags: ['Portefeuille'], summary: 'Choisir le numéro Mobile Money par défaut', parameters: [pathParameter('id', 'UUID du compte Mobile Money.')], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Numéro par défaut mis à jour.' } } } },
    '/api/v1/transactions/{id}/status': { patch: { tags: ['Transactions'], summary: 'Recevoir un statut de paiement', parameters: [pathParameter('id', 'UUID de la transaction.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Nouveau statut et informations prestataire.', { status: 'PAID', providerRef: 'REF-123' }), responses: { 200: { description: 'Transaction mise à jour.' } } } },
    '/api/v1/promo-codes/validate': { post: { tags: ['Codes promo'], summary: 'Valider un code promo', requestBody: jsonRequestBody('Code promotionnel et montant de commande.', { code: 'BIENVENUE10', orderAmount: 10000 }), responses: { 200: { description: 'Réduction calculée.' }, 400: { description: 'Code invalide.' } } } },
    '/api/v1/delivery-zones/resolve': { post: { tags: ['Zones de livraison'], summary: 'Résoudre une zone par coordonnées', requestBody: jsonRequestBody('Ville et coordonnées GPS.', { cityId: 1, latitude: -4.325, longitude: 15.322 }), responses: { 200: { description: 'Zone trouvée.' }, 404: commonResponses.NotFound } } },
    '/api/v1/delivery-configs/active': { get: { tags: ['Configurations de livraison'], summary: 'Consulter la configuration de livraison active', parameters: [queryParameter('cityId', 'Identifiant numérique de la ville.', { type: 'integer', minimum: 1 })], responses: { 200: { description: 'Configuration active.' }, 404: commonResponses.NotFound } } },
    '/api/v1/geocoding/search': { get: { tags: ['Géocodage'], summary: 'Rechercher une adresse RDC avec Nominatim', parameters: [queryParameter('q', 'Texte de recherche (3 à 200 caractères).', { type: 'string', minLength: 3, maxLength: 200 }, true), queryParameter('limit', 'Nombre de résultats (1 à 10).', { type: 'integer', minimum: 1, maximum: 10, default: 5 })], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Adresses proposées, avec cache éventuel.' }, 503: { description: 'Nominatim non configuré.' } } } },
    '/api/v1/geocoding/reverse': { get: { tags: ['Géocodage'], summary: 'Obtenir une adresse RDC depuis des coordonnées', parameters: [queryParameter('latitude', 'Latitude GPS.', { type: 'number', minimum: -90, maximum: 90 }, true), queryParameter('longitude', 'Longitude GPS.', { type: 'number', minimum: -180, maximum: 180 }, true)], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Adresse inverse proposée.' }, 400: { description: 'Coordonnées hors RDC ou invalides.' } } } },
    '/api/v1/uploads/image': { post: { tags: ['Médias'], summary: 'Téléverser une image', description: 'JPEG, PNG ou WebP, 5 Mo maximum. Les images sont réencodées en WebP.', security: [{ bearerAuth: [] }], requestBody: { required: true, content: { 'multipart/form-data': { schema: { type: 'object', required: ['image'], properties: { image: { type: 'string', format: 'binary' }, scope: { type: 'string', example: 'restaurants' } } } } } }, responses: { 201: { description: 'Média téléversé.' }, 413: { description: 'Fichier trop volumineux.' }, 415: { description: 'Format non accepté.' } } } },
    '/api/v1/uploads/images': { post: { tags: ['Médias'], summary: 'Téléverser jusqu’à cinq images', security: [{ bearerAuth: [] }], requestBody: { required: true, content: { 'multipart/form-data': { schema: { type: 'object', required: ['images'], properties: { images: { type: 'array', maxItems: 5, items: { type: 'string', format: 'binary' } }, scope: { type: 'string', example: 'restaurants' } } } } } }, responses: { 201: { description: 'Médias téléversés.' } } } },
    '/api/v1/delivery/quote': { post: { tags: ['Livraison'], summary: 'Obtenir le devis de livraison serveur', description: 'Vérifie les deux positions dans la même ville RDC, estime la distance routière et calcule le prix CDF.', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Restaurant et adresse de livraison.', { restaurantId: 1, addressId: 1 }), responses: { 200: { description: 'Devis ou indisponibilité.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/addresses/{addressId}/location': { patch: { tags: ['Livraison'], summary: 'Actualiser l’adresse de livraison GPS', parameters: [pathParameter('addressId', 'Identifiant numérique de l’adresse.', { type: 'integer', minimum: 1 })], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Position GPS et adresse éventuellement corrigée.', { latitude: -4.325, longitude: 15.322, fullAddress: '10 avenue de la Paix', nominatimPlaceId: '12345' }), responses: { 200: { description: 'Adresse et ville résolues par PostGIS.' }, 400: { description: 'Position hors zone.' } } } },
    '/api/v1/restaurants/{restaurantId}/location': { patch: { tags: ['Livraison'], summary: 'Définir la position fixe du point de vente', parameters: [pathParameter('restaurantId', 'Identifiant numérique du restaurant.', { type: 'integer', minimum: 1 })], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Coordonnées GPS du point de vente.', { latitude: -4.325, longitude: 15.322, address: 'Kinshasa' }), responses: { 200: { description: 'Restaurant géolocalisé.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/cities/{cityId}/boundary': { patch: { tags: ['Livraison'], summary: 'Importer la limite GeoJSON d’une ville', parameters: [pathParameter('cityId', 'Identifiant numérique de la ville.', { type: 'integer', minimum: 1 })], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Géométrie GeoJSON Polygon ou MultiPolygon.', { type: 'Polygon', coordinates: [[[15.2, -4.3], [15.3, -4.3], [15.3, -4.4], [15.2, -4.3]]] }), responses: { 200: { description: 'Limite PostGIS enregistrée.' }, 403: commonResponses.Forbidden } } },
    '/api/v1/couriers/me/availability': { patch: { tags: ['Livraison'], summary: 'Passer livreur disponible ou indisponible', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('État de disponibilité du livreur.', { status: 'ACTIVE' }), responses: { 200: { description: 'Disponibilité modifiée.' }, 400: { description: 'Position GPS requise pour devenir actif.' } } } },
    '/api/v1/couriers/me/location': { post: { tags: ['Livraison'], summary: 'Enregistrer une position livreur active', security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Position GPS du livreur.', { latitude: -4.325, longitude: 15.322, accuracyM: 10 }), responses: { 201: { description: 'Position et ville enregistrées.' } } } },
    '/api/v1/couriers/me/offers': { get: { tags: ['Livraison'], summary: 'Consulter les propositions de course actives', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Propositions classées par proximité.' } } } },
    '/api/v1/couriers/me/deliveries': { get: { tags: ['Livraison'], summary: 'Consulter ses livraisons', security: [{ bearerAuth: [] }], responses: { 200: { description: 'Livraisons du livreur connecté.' }, 401: commonResponses.Unauthorized } } },
    '/api/v1/delivery-offers/{id}/accept': { post: { tags: ['Livraison'], summary: 'Accepter une course proposée', parameters: [pathParameter('id', 'UUID de la proposition de course.')], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Course attribuée atomiquement.' }, 409: { description: 'Course déjà prise ou expirée.' } } } },
    '/api/v1/delivery-offers/{id}/reject': { post: { tags: ['Livraison'], summary: 'Refuser une course proposée', parameters: [pathParameter('id', 'UUID de la proposition de course.')], security: [{ bearerAuth: [] }], responses: { 200: { description: 'Proposition refusée.' } } } },
    '/api/v1/deliveries/{id}/status': { patch: { tags: ['Livraison'], summary: 'Faire progresser une livraison', parameters: [pathParameter('id', 'UUID de la livraison.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Nouveau statut de livraison.', { status: 'PICKED_UP' }), responses: { 200: { description: 'Statut avancé.' }, 409: { description: 'Transition non autorisée.' } } } },
    '/api/v1/identities/{id}/review': { patch: { tags: ['Identités'], summary: 'Examiner une vérification d’identité', parameters: [pathParameter('id', 'UUID de la vérification.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Décision et remarque de vérification.', { status: 'approved', remark: 'Document conforme.' }), responses: { 200: { description: 'Vérification examinée.' }, 401: commonResponses.Unauthorized, 403: commonResponses.Forbidden, 404: commonResponses.NotFound } } },
    '/api/v1/pro-documents/{id}/review': { patch: { tags: ['Documents professionnels'], summary: 'Examiner un document professionnel', parameters: [pathParameter('id', 'UUID du document professionnel.')], security: [{ bearerAuth: [] }], requestBody: jsonRequestBody('Décision et remarque de vérification.', { status: 'approved', remark: 'Document conforme.' }), responses: { 200: { description: 'Document examiné.' }, 401: commonResponses.Unauthorized, 403: commonResponses.Forbidden, 404: commonResponses.NotFound } } },
  });

  return swaggerJsdoc({
    definition: {
      openapi: '3.0.3',
      info: { title: 'Dios Delices API', version: '1.0.0', description: 'API Node.js de Dios Delices.' },
      servers: [{ url: process.env.API_BASE_URL || 'http://localhost:3000', description: 'Serveur local' }],
      tags: resourcePaths.map(({ tag: name }) => ({ name })).concat([{ name: 'Authentification' }, { name: 'Paiements' }, { name: 'Livraison' }, { name: 'Géocodage' }, { name: 'Médias' }, { name: 'Portefeuille' }, { name: 'Système' }]),
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
