'use strict';

const CLASS = {
  users: 'Users',
  restaurants: 'Restaurant',
  dishes: 'Dish',
  addresses: 'Adress',
  identities: 'Identity',
  paymentMethods: 'MoyenPaiement',
  commandes: 'Commande',
  lignesCommande: 'LigneCommande',
  comments: 'Comment',
  roles: 'Role',
};

const COMMANDE_STATUS = {
  pending: 'En attente',
  paid: 'Payée',
  confirmed: 'Confirmée',
  cancelled: 'Annulée',
};

function hasParam(request, key) {
  return Object.prototype.hasOwnProperty.call(request.params || {}, key);
}

function toNumber(value, fallback = 0) {
  if (value === null || typeof value === 'undefined' || value === '') {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function toStringValue(value, fallback = '') {
  if (value === null || typeof value === 'undefined') {
    return fallback;
  }

  return String(value);
}

function toBoolean(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'true' || normalized === '1') {
      return true;
    }
    if (normalized === 'false' || normalized === '0') {
      return false;
    }
  }

  if (typeof value === 'number') {
    return value === 1;
  }

  return fallback;
}

function toDateValue(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Date) {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  if (typeof value === 'object' && value.iso) {
    const parsed = new Date(value.iso);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  return null;
}

function toIsoString(value) {
  const parsed = toDateValue(value);
  return parsed ? parsed.toISOString() : null;
}

function normalizeCommandeStatus(value) {
  const normalized = toStringValue(value).trim().toLowerCase();

  if (!normalized) {
    return COMMANDE_STATUS.pending;
  }

  if (['en attente', 'attente', 'pending'].includes(normalized)) {
    return COMMANDE_STATUS.pending;
  }

  if (['payée', 'payee', 'paid'].includes(normalized)) {
    return COMMANDE_STATUS.paid;
  }

  if (['confirmée', 'confirmee', 'confirmed'].includes(normalized)) {
    return COMMANDE_STATUS.confirmed;
  }

  if (['annulée', 'annulee', 'cancelled', 'canceled'].includes(normalized)) {
    return COMMANDE_STATUS.cancelled;
  }

  return value;
}

function normalizeCurrency(value) {
  const normalized = toStringValue(value, 'xof').trim().toLowerCase();
  return normalized === 'eur' ? 'eur' : 'xof';
}

async function nextNumericId(className, fieldName, fallback = 1) {
  const query = new Parse.Query(className);
  query.descending(fieldName);
  query.limit(1);

  const lastObject = await query.first({ useMasterKey: true });
  if (!lastObject) {
    return fallback;
  }

  return toNumber(lastObject.get(fieldName), fallback - 1) + 1;
}

async function findAll(className, sortField, direction = 'ascending') {
  const query = new Parse.Query(className);
  query.limit(1000);

  if (sortField) {
    if (direction === 'descending') {
      query.descending(sortField);
    } else {
      query.ascending(sortField);
    }
  }

  return query.find({ useMasterKey: true });
}

function serializeUser(user) {
  const json = user.toJSON();
  return {
    ...json,
    userID: toNumber(user.get('userID')),
    firstname: toStringValue(user.get('firstname')),
    lastname: toStringValue(user.get('lastname')),
    username: toStringValue(user.get('username')),
    email: toStringValue(user.get('email')),
    telephone: toNumber(user.get('telephone')),
    roleID: toNumber(user.get('roleID')),
    country: toStringValue(user.get('country')),
    status: toStringValue(user.get('status')),
    identity: toStringValue(user.get('identity')),
    addressID: toNumber(user.get('addressID')),
    image: toStringValue(user.get('image')),
    last_login: user.get('last_login')
      ? { __type: 'Date', iso: user.get('last_login').toISOString() }
      : null,
  };
}

function serializeRestaurant(restaurant) {
  const json = restaurant.toJSON();
  return {
    ...json,
    restaurantID: toNumber(restaurant.get('restaurantID')),
    userID: toNumber(restaurant.get('userID')),
    categories: toStringValue(restaurant.get('categories')),
    description: toStringValue(restaurant.get('description')),
    adress: toStringValue(restaurant.get('adress')),
    addressID: toNumber(restaurant.get('addressID')),
    name: toStringValue(restaurant.get('name')),
    note: toNumber(restaurant.get('note')),
    image: toStringValue(restaurant.get('image')),
    date_creation: restaurant.get('date_creation')
      ? { __type: 'Date', iso: restaurant.get('date_creation').toISOString() }
      : null,
    valid: toNumber(restaurant.get('valid')),
    nb_orders: toNumber(restaurant.get('nb_orders')),
    openingHours: toStringValue(restaurant.get('openingHours'), '09:00 - 20:00'),
    deliveryFee: toNumber(restaurant.get('deliveryFee')),
    isOpen: toNumber(restaurant.get('isOpen'), 1),
    professionalType: toStringValue(restaurant.get('professionalType')),
    trainingCompleted: toBoolean(restaurant.get('trainingCompleted')),
    reviewRemark: toStringValue(restaurant.get('reviewRemark')),
  };
}

function serializeDish(dish) {
  const json = dish.toJSON();
  return {
    ...json,
    dishID: toNumber(dish.get('dishID')),
    userID: toNumber(dish.get('userID')),
    restauID: toNumber(dish.get('restauID')),
    name: toStringValue(dish.get('name')),
    categories: toStringValue(dish.get('categories')),
    image: toStringValue(dish.get('image')),
    nb_orders: toNumber(dish.get('nb_orders')),
    price: toNumber(dish.get('price')),
    description: toStringValue(dish.get('description')),
    nb_servings: toNumber(dish.get('nb_servings')),
    status: toNumber(dish.get('status')),
    note: toNumber(dish.get('note')),
    option1: toStringValue(dish.get('option1')),
    option2: toStringValue(dish.get('option2')),
    option3: toStringValue(dish.get('option3')),
  };
}

function serializeAddress(address) {
  const json = address.toJSON();
  return {
    ...json,
    addressID: toNumber(address.get('addressID')),
    object: toStringValue(address.get('object')),
    objectID: toNumber(address.get('objectID')),
    numero: toNumber(address.get('numero')),
    city: toStringValue(address.get('city')),
    state: toStringValue(address.get('state')),
    country: toStringValue(address.get('country')),
    fullAddress: toStringValue(address.get('fullAddress')),
    lat: toStringValue(address.get('lat')),
    long: toStringValue(address.get('long')),
  };
}

function serializeIdentity(identity) {
  const json = identity.toJSON();
  return {
    ...json,
    identityID: toNumber(identity.get('identityID')),
    userID: toNumber(identity.get('userID')),
    piece_identite: toStringValue(identity.get('piece_identite')),
    photo: toStringValue(identity.get('photo')),
    status: toStringValue(identity.get('status')),
    remark: toStringValue(identity.get('remark')),
  };
}

function serializePaymentMethod(moyen) {
  const json = moyen.toJSON();
  const legacyId = toNumber(moyen.get('idMoyen'));
  const modernId = toStringValue(moyen.get('id_moyen_paiement'));
  const label =
    toStringValue(moyen.get('libelle')) ||
    toStringValue(moyen.get('nom')) ||
    `${toStringValue(moyen.get('brand'))} ****${toStringValue(moyen.get('last4'))}`.trim();

  return {
    ...json,
    idMoyen: legacyId,
    nom: label,
    libelle: label,
    id_moyen_paiement: modernId || String(legacyId),
    userID: toNumber(moyen.get('userID')),
    stripe_pm_id: toStringValue(moyen.get('stripe_pm_id')),
    brand: toStringValue(moyen.get('brand')),
    last4: toNumber(moyen.get('last4')),
    exp_month: toNumber(moyen.get('exp_month')),
    exp_year: toNumber(moyen.get('exp_year')),
    type: toStringValue(moyen.get('type')),
    is_default: toBoolean(moyen.get('is_default')),
  };
}

function serializeCommande(commande) {
  const json = commande.toJSON();
  const commandeID = toNumber(commande.get('commandeID'));
  const commandeCode = toStringValue(commande.get('id_commande'), String(commandeID));
  const status = normalizeCommandeStatus(
    commande.get('status') || commande.get('statut') || commande.get('statut_commande'),
  );

  return {
    ...json,
    commandeID,
    id_commande: commandeCode,
    userID: toNumber(commande.get('userID') ?? commande.get('id_user')),
    id_user: toNumber(commande.get('id_user') ?? commande.get('userID')),
    restauID: toNumber(commande.get('restauID') ?? commande.get('id_restau')),
    id_restau: toNumber(commande.get('id_restau') ?? commande.get('restauID')),
    restaurateurID: toNumber(
      commande.get('restaurateurID') ?? commande.get('id_restaurateur'),
    ),
    id_restaurateur: toNumber(
      commande.get('id_restaurateur') ?? commande.get('restaurateurID'),
    ),
    moyenPaiementID: toNumber(commande.get('moyenPaiementID')),
    id_moyen_paiement: toStringValue(commande.get('id_moyen_paiement')),
    fraisLivraison: toNumber(commande.get('fraisLivraison') ?? commande.get('frais_livraison')),
    frais_livraison: toNumber(
      commande.get('frais_livraison') ?? commande.get('fraisLivraison'),
    ),
    reduction: toNumber(commande.get('reduction') ?? commande.get('reduction_globale')),
    reduction_globale: toNumber(
      commande.get('reduction_globale') ?? commande.get('reduction'),
    ),
    dateCommande: toIsoString(commande.get('dateCommande') ?? commande.get('date_commande')),
    date_commande: toIsoString(commande.get('date_commande') ?? commande.get('dateCommande')),
    heure: toStringValue(commande.get('heure')),
    addressID: toNumber(commande.get('addressID') ?? commande.get('id_adresse_livraison')),
    id_adresse_livraison: toNumber(
      commande.get('id_adresse_livraison') ?? commande.get('addressID'),
    ),
    note: toNumber(commande.get('note')),
    commentaire: toStringValue(commande.get('commentaire')),
    status,
    statut: status,
    statut_commande: status,
    currency: normalizeCurrency(commande.get('currency')),
    promo_code: toStringValue(commande.get('promo_code')),
    deliveryMode: toStringValue(commande.get('deliveryMode')),
    subtotalAmount: toNumber(commande.get('subtotalAmount')),
    totalAmount: toNumber(commande.get('totalAmount')),
  };
}

function serializeLigneCommande(ligne) {
  const json = ligne.toJSON();
  const ligneID = toStringValue(ligne.get('ligneID') || ligne.get('id_ligne_commande'));
  const commandeID = toStringValue(ligne.get('commandeID') || ligne.get('id_commande'));

  return {
    ...json,
    ligneID,
    id_ligne_commande: ligneID,
    commandeID,
    id_commande: commandeID,
    platID: toNumber(ligne.get('platID') ?? ligne.get('id_plat')),
    id_plat: toNumber(ligne.get('id_plat') ?? ligne.get('platID')),
    quantite: toNumber(ligne.get('quantite')),
    prixUnitaire: toNumber(ligne.get('prixUnitaire') ?? ligne.get('prix_unitaire')),
    prix_unitaire: toNumber(ligne.get('prix_unitaire') ?? ligne.get('prixUnitaire')),
    reduction: toNumber(ligne.get('reduction')),
    note: toNumber(ligne.get('note')),
    commentaire: toStringValue(ligne.get('commentaire')),
    options: ligne.get('options') || {},
  };
}

async function ensureUserUniqueness(params, currentObjectId = null) {
  const queries = [];

  if (params.email) {
    const emailQuery = new Parse.Query(CLASS.users);
    emailQuery.equalTo('email', params.email);
    queries.push(emailQuery);
  }

  if (hasParam({ params }, 'telephone')) {
    const telephoneQuery = new Parse.Query(CLASS.users);
    telephoneQuery.equalTo('telephone', toNumber(params.telephone));
    queries.push(telephoneQuery);
  }

  if (params.username) {
    const usernameQuery = new Parse.Query(CLASS.users);
    usernameQuery.equalTo('username', params.username);
    queries.push(usernameQuery);
  }

  if (!queries.length) {
    return;
  }

  const combinedQuery = Parse.Query.or(...queries);
  const matches = await combinedQuery.find({ useMasterKey: true });
  const duplicate = matches.find((item) => item.id !== currentObjectId);

  if (duplicate) {
    throw new Error(
      'Un utilisateur avec le même email, le même numéro ou le même username existe déjà.',
    );
  }
}

async function ensureRestaurantUniqueness(userID, currentObjectId = null) {
  const query = new Parse.Query(CLASS.restaurants);
  query.equalTo('userID', toNumber(userID));

  const restaurants = await query.find({ useMasterKey: true });
  const duplicate = restaurants.find((item) => item.id !== currentObjectId);
  if (duplicate) {
    throw new Error('Un restaurant existe déjà pour cet utilisateur.');
  }
}

async function ensureDishUniqueness(restauID, name, currentObjectId = null) {
  const query = new Parse.Query(CLASS.dishes);
  query.equalTo('restauID', toNumber(restauID));
  query.equalTo('name', toStringValue(name));

  const dishes = await query.find({ useMasterKey: true });
  const duplicate = dishes.find((item) => item.id !== currentObjectId);
  if (duplicate) {
    throw new Error('Un plat avec ce nom existe déjà pour ce restaurant.');
  }
}

async function ensureAddressUniqueness(params, currentObjectId = null) {
  const query = new Parse.Query(CLASS.addresses);
  query.equalTo('lat', toStringValue(params.lat));
  query.equalTo('long', toStringValue(params.long));
  query.equalTo('objectID', toNumber(params.objectID));
  query.equalTo('object', toStringValue(params.object));

  const addresses = await query.find({ useMasterKey: true });
  const duplicate = addresses.find((item) => item.id !== currentObjectId);
  if (duplicate) {
    const error = new Error("Cette adresse existe déjà pour l'utilisateur.");
    error.code = 'ADDRESS_EXISTS';
    throw error;
  }
}

function setIfPresent(request, key, setter) {
  if (hasParam(request, key)) {
    setter(request.params[key]);
  }
}

Parse.Cloud.define('getAllUsers', async () => {
  const users = await findAll(CLASS.users, 'firstname', 'ascending');
  return users.map(serializeUser);
});

Parse.Cloud.define('add1User', async (request) => {
  try {
    await ensureUserUniqueness(request.params);

    const nextUserID = await nextNumericId(CLASS.users, 'userID');
    const user = new Parse.Object(CLASS.users);

    user.set('userID', nextUserID);
    user.set('firstname', toStringValue(request.params.firstname));
    user.set('lastname', toStringValue(request.params.lastname));
    user.set('username', toStringValue(request.params.username));
    user.set('email', toStringValue(request.params.email));
    user.set('password', toStringValue(request.params.password_crypte || request.params.password));
    user.set('telephone', toNumber(request.params.telephone));
    user.set('roleID', toNumber(request.params.roleID, 2));
    user.set('country', toStringValue(request.params.country));
    user.set('status', toStringValue(request.params.status));
    user.set('identity', toStringValue(request.params.identity));
    user.set('addressID', toNumber(request.params.addressID));

    const lastLogin = toDateValue(request.params.last_login);
    if (lastLogin) {
      user.set('last_login', lastLogin);
    }

    if (request.params.image) {
      user.set('image', toStringValue(request.params.image));
    }

    await user.save(null, { useMasterKey: true });
    return { success: true, message: 'User ajouté', userID: nextUserID };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('update1User', async (request) => {
  try {
    const query = new Parse.Query(CLASS.users);
    query.equalTo('userID', toNumber(request.params.userID));
    const user = await query.first({ useMasterKey: true });

    if (!user) {
      return { success: false, error: 'Aucun user trouvé avec cet ID.' };
    }

    await ensureUserUniqueness(request.params, user.id);

    setIfPresent(request, 'firstname', (value) => user.set('firstname', toStringValue(value)));
    setIfPresent(request, 'lastname', (value) => user.set('lastname', toStringValue(value)));
    setIfPresent(request, 'password', (value) => user.set('password', toStringValue(value)));
    setIfPresent(request, 'password_crypte', (value) => user.set('password', toStringValue(value)));
    setIfPresent(request, 'email', (value) => user.set('email', toStringValue(value)));
    setIfPresent(request, 'roleID', (value) => user.set('roleID', toNumber(value)));
    setIfPresent(request, 'username', (value) => user.set('username', toStringValue(value)));
    setIfPresent(request, 'telephone', (value) => user.set('telephone', toNumber(value)));
    setIfPresent(request, 'image', (value) => user.set('image', toStringValue(value)));
    setIfPresent(request, 'country', (value) => user.set('country', toStringValue(value)));
    setIfPresent(request, 'status', (value) => user.set('status', toStringValue(value)));
    setIfPresent(request, 'identity', (value) => user.set('identity', toStringValue(value)));
    setIfPresent(request, 'addressID', (value) => user.set('addressID', toNumber(value)));
    setIfPresent(request, 'last_login', (value) => {
      const parsed = toDateValue(value);
      if (parsed) {
        user.set('last_login', parsed);
      }
    });

    await user.save(null, { useMasterKey: true });
    return { success: true, message: "Informations de l'user mises à jour." };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('suppr1User', async (request) => {
  try {
    const query = new Parse.Query(CLASS.users);
    query.equalTo('userID', toNumber(request.params.userID));
    const user = await query.first({ useMasterKey: true });

    if (!user) {
      return { success: false, error: 'User not found.' };
    }

    await user.destroy({ useMasterKey: true });
    return { success: true, message: 'User supprimé' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllRestaurants', async () => {
  const restaurants = await findAll(CLASS.restaurants, 'name', 'ascending');
  return restaurants.map(serializeRestaurant);
});

Parse.Cloud.define('add1Restaurant', async (request) => {
  try {
    await ensureRestaurantUniqueness(request.params.userID);

    const nextRestaurantID = await nextNumericId(CLASS.restaurants, 'restaurantID');
    const restaurant = new Parse.Object(CLASS.restaurants);

    restaurant.set('restaurantID', nextRestaurantID);
    restaurant.set('userID', toNumber(request.params.userID));
    restaurant.set('note', toNumber(request.params.note));
    restaurant.set('nb_orders', toNumber(request.params.nb_orders));
    restaurant.set('valid', toNumber(request.params.valid));
    restaurant.set('description', toStringValue(request.params.description));
    restaurant.set('categories', toStringValue(request.params.categories));
    restaurant.set('adress', toStringValue(request.params.adress));
    restaurant.set('addressID', toNumber(request.params.addressID));
    restaurant.set('name', toStringValue(request.params.name));
    restaurant.set('image', toStringValue(request.params.image));
    restaurant.set('openingHours', toStringValue(request.params.openingHours, '09:00 - 20:00'));
    restaurant.set('deliveryFee', toNumber(request.params.deliveryFee));
    restaurant.set('isOpen', toNumber(request.params.isOpen, 1));
    restaurant.set('professionalType', toStringValue(request.params.professionalType));
    restaurant.set('trainingCompleted', toBoolean(request.params.trainingCompleted));
    restaurant.set('reviewRemark', toStringValue(request.params.reviewRemark));

    const creationDate = toDateValue(request.params.date_creation);
    if (creationDate) {
      restaurant.set('date_creation', creationDate);
    }

    await restaurant.save(null, { useMasterKey: true });
    return {
      success: true,
      message: 'Restaurant ajouté',
      restaurantID: nextRestaurantID,
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('update1Restaurant', async (request) => {
  try {
    const query = new Parse.Query(CLASS.restaurants);
    query.equalTo('restaurantID', toNumber(request.params.restaurantID));
    const restaurant = await query.first({ useMasterKey: true });

    if (!restaurant) {
      return { success: false, error: 'Aucun restaurant trouvé avec cet ID.' };
    }

    if (hasParam(request, 'userID')) {
      await ensureRestaurantUniqueness(request.params.userID, restaurant.id);
      restaurant.set('userID', toNumber(request.params.userID));
    }

    setIfPresent(request, 'note', (value) => restaurant.set('note', toNumber(value)));
    setIfPresent(request, 'valid', (value) => restaurant.set('valid', toNumber(value)));
    setIfPresent(request, 'description', (value) => restaurant.set('description', toStringValue(value)));
    setIfPresent(request, 'adress', (value) => restaurant.set('adress', toStringValue(value)));
    setIfPresent(request, 'addressID', (value) => restaurant.set('addressID', toNumber(value)));
    setIfPresent(request, 'name', (value) => restaurant.set('name', toStringValue(value)));
    setIfPresent(request, 'image', (value) => restaurant.set('image', toStringValue(value)));
    setIfPresent(request, 'categories', (value) => restaurant.set('categories', toStringValue(value)));
    setIfPresent(request, 'nb_orders', (value) => restaurant.set('nb_orders', toNumber(value)));
    setIfPresent(request, 'openingHours', (value) => restaurant.set('openingHours', toStringValue(value)));
    setIfPresent(request, 'deliveryFee', (value) => restaurant.set('deliveryFee', toNumber(value)));
    setIfPresent(request, 'isOpen', (value) => restaurant.set('isOpen', toNumber(value, 1)));
    setIfPresent(request, 'professionalType', (value) => restaurant.set('professionalType', toStringValue(value)));
    setIfPresent(request, 'trainingCompleted', (value) => restaurant.set('trainingCompleted', toBoolean(value)));
    setIfPresent(request, 'reviewRemark', (value) => restaurant.set('reviewRemark', toStringValue(value)));
    setIfPresent(request, 'date_creation', (value) => {
      const parsed = toDateValue(value);
      if (parsed) {
        restaurant.set('date_creation', parsed);
      }
    });

    await restaurant.save(null, { useMasterKey: true });
    return {
      success: true,
      message: 'Informations du restaurant mises à jour.',
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('suppr1Restaurant', async (request) => {
  try {
    const query = new Parse.Query(CLASS.restaurants);
    query.equalTo('restaurantID', toNumber(request.params.restaurantID));
    const restaurant = await query.first({ useMasterKey: true });

    if (!restaurant) {
      return { success: false, error: 'Restaurant not found.' };
    }

    await restaurant.destroy({ useMasterKey: true });
    return { success: true, message: 'Restaurant supprimé' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllDishes', async () => {
  const dishes = await findAll(CLASS.dishes, 'name', 'ascending');
  return dishes.map(serializeDish);
});

Parse.Cloud.define('add1Dish', async (request) => {
  try {
    await ensureDishUniqueness(request.params.restauID, request.params.name);

    const nextDishID = await nextNumericId(CLASS.dishes, 'dishID');
    const dish = new Parse.Object(CLASS.dishes);

    dish.set('dishID', nextDishID);
    dish.set('userID', toNumber(request.params.userID));
    dish.set('note', toNumber(request.params.note));
    dish.set('nb_orders', toNumber(request.params.nb_orders));
    dish.set('description', toStringValue(request.params.description));
    dish.set('categories', toStringValue(request.params.categories));
    dish.set('name', toStringValue(request.params.name));
    dish.set('image', toStringValue(request.params.image));
    dish.set('price', toNumber(request.params.price));
    dish.set('nb_servings', toNumber(request.params.nb_servings));
    dish.set('restauID', toNumber(request.params.restauID));
    dish.set('status', toNumber(request.params.status, 1));
    dish.set('option1', toStringValue(request.params.option1));
    dish.set('option2', toStringValue(request.params.option2));
    dish.set('option3', toStringValue(request.params.option3));

    await dish.save(null, { useMasterKey: true });
    return { success: true, message: 'Plat ajouté', dishID: nextDishID };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('update1Dish', async (request) => {
  try {
    const query = new Parse.Query(CLASS.dishes);
    query.equalTo('dishID', toNumber(request.params.dishID));
    const dish = await query.first({ useMasterKey: true });

    if (!dish) {
      return { success: false, error: 'Aucun plat trouvé avec cet ID.' };
    }

    const nextName = hasParam(request, 'name') ? request.params.name : dish.get('name');
    const nextRestauID = hasParam(request, 'restauID')
      ? request.params.restauID
      : dish.get('restauID');
    await ensureDishUniqueness(nextRestauID, nextName, dish.id);

    setIfPresent(request, 'note', (value) => dish.set('note', toNumber(value)));
    setIfPresent(request, 'nb_orders', (value) => dish.set('nb_orders', toNumber(value)));
    setIfPresent(request, 'description', (value) => dish.set('description', toStringValue(value)));
    setIfPresent(request, 'categories', (value) => dish.set('categories', toStringValue(value)));
    setIfPresent(request, 'name', (value) => dish.set('name', toStringValue(value)));
    setIfPresent(request, 'image', (value) => dish.set('image', toStringValue(value)));
    setIfPresent(request, 'price', (value) => dish.set('price', toNumber(value)));
    setIfPresent(request, 'nb_servings', (value) => dish.set('nb_servings', toNumber(value)));
    setIfPresent(request, 'restauID', (value) => dish.set('restauID', toNumber(value)));
    setIfPresent(request, 'userID', (value) => dish.set('userID', toNumber(value)));
    setIfPresent(request, 'status', (value) => dish.set('status', toNumber(value, 1)));
    setIfPresent(request, 'option1', (value) => dish.set('option1', toStringValue(value)));
    setIfPresent(request, 'option2', (value) => dish.set('option2', toStringValue(value)));
    setIfPresent(request, 'option3', (value) => dish.set('option3', toStringValue(value)));

    await dish.save(null, { useMasterKey: true });
    return { success: true, message: 'Informations du plat mises à jour.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('suppr1Dish', async (request) => {
  try {
    const query = new Parse.Query(CLASS.dishes);
    query.equalTo('dishID', toNumber(request.params.dishID));
    const dish = await query.first({ useMasterKey: true });

    if (!dish) {
      return { success: false, error: 'Plat non trouvé.' };
    }

    await dish.destroy({ useMasterKey: true });
    return { success: true, message: 'Plat supprimé' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllAdresses', async () => {
  const addresses = await findAll(CLASS.addresses, 'addressID', 'ascending');
  return addresses.map(serializeAddress);
});

Parse.Cloud.define('addAddress', async (request) => {
  try {
    await ensureAddressUniqueness(request.params);

    const nextAddressID = await nextNumericId(CLASS.addresses, 'addressID');
    const address = new Parse.Object(CLASS.addresses);

    address.set('addressID', nextAddressID);
    address.set('object', toStringValue(request.params.object));
    address.set('objectID', toNumber(request.params.objectID));
    address.set('city', toStringValue(request.params.city));
    address.set('state', toStringValue(request.params.state));
    address.set('country', toStringValue(request.params.country || request.params.state));
    address.set('fullAddress', toStringValue(request.params.fullAddress));
    address.set('lat', toStringValue(request.params.lat));
    address.set('long', toStringValue(request.params.long));
    address.set('numero', toNumber(request.params.numero || request.params.flatNumber));

    await address.save(null, { useMasterKey: true });
    return { success: true, message: 'Adresse ajoutée', addressID: nextAddressID };
  } catch (error) {
    if (error.code === 'ADDRESS_EXISTS') {
      return { success: false, exist: true, error: error.message };
    }
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('updateAddress', async (request) => {
  try {
    const query = new Parse.Query(CLASS.addresses);
    query.equalTo('addressID', toNumber(request.params.addressID));
    const address = await query.first({ useMasterKey: true });

    if (!address) {
      return { success: false, error: 'Aucune adresse trouvée avec cet ID.' };
    }

    await ensureAddressUniqueness(
      {
        lat: hasParam(request, 'lat') ? request.params.lat : address.get('lat'),
        long: hasParam(request, 'long') ? request.params.long : address.get('long'),
        objectID: hasParam(request, 'objectID') ? request.params.objectID : address.get('objectID'),
        object: hasParam(request, 'object') ? request.params.object : address.get('object'),
      },
      address.id,
    );

    setIfPresent(request, 'city', (value) => address.set('city', toStringValue(value)));
    setIfPresent(request, 'state', (value) => address.set('state', toStringValue(value)));
    setIfPresent(request, 'country', (value) => address.set('country', toStringValue(value)));
    setIfPresent(request, 'fullAddress', (value) => address.set('fullAddress', toStringValue(value)));
    setIfPresent(request, 'lat', (value) => address.set('lat', toStringValue(value)));
    setIfPresent(request, 'long', (value) => address.set('long', toStringValue(value)));
    setIfPresent(request, 'numero', (value) => address.set('numero', toNumber(value)));

    await address.save(null, { useMasterKey: true });
    return { success: true, message: 'Adresse mise à jour avec succès.' };
  } catch (error) {
    if (error.code === 'ADDRESS_EXISTS') {
      return { success: false, exist: true, error: error.message };
    }
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('deleteAddress', async (request) => {
  try {
    const query = new Parse.Query(CLASS.addresses);
    query.equalTo('addressID', toNumber(request.params.addressID));
    query.equalTo('object', toStringValue(request.params.object));
    query.equalTo('objectID', toNumber(request.params.objectID));
    const address = await query.first({ useMasterKey: true });

    if (!address) {
      return { success: false, error: 'Adresse introuvable.' };
    }

    await address.destroy({ useMasterKey: true });
    return { success: true, message: 'Adresse supprimée avec succès.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllIdentities', async () => {
  const identities = await findAll(CLASS.identities, 'identityID', 'ascending');
  return identities.map(serializeIdentity);
});

Parse.Cloud.define('addIdentity', async (request) => {
  try {
    const existingQuery = new Parse.Query(CLASS.identities);
    existingQuery.equalTo('userID', toNumber(request.params.userID));
    const existing = await existingQuery.first({ useMasterKey: true });
    if (existing) {
      return {
        success: false,
        error: "L'identité est déjà enregistrée pour l'utilisateur.",
      };
    }

    const nextIdentityID = await nextNumericId(CLASS.identities, 'identityID');
    const identity = new Parse.Object(CLASS.identities);

    identity.set('identityID', nextIdentityID);
    identity.set('userID', toNumber(request.params.userID));
    identity.set('piece_identite', toStringValue(request.params.piece_identite));
    identity.set('photo', toStringValue(request.params.photo));
    identity.set('status', toStringValue(request.params.status, 'pending'));
    identity.set('remark', toStringValue(request.params.remark));

    await identity.save(null, { useMasterKey: true });
    return {
      success: true,
      message: 'Identité ajoutée avec succès.',
      identityID: nextIdentityID,
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('updateIdentity', async (request) => {
  try {
    const query = new Parse.Query(CLASS.identities);
    query.equalTo('identityID', toNumber(request.params.identityID));
    const identity = await query.first({ useMasterKey: true });

    if (!identity) {
      return { success: false, error: 'Aucune identité trouvée avec cet ID.' };
    }

    setIfPresent(request, 'piece_identite', (value) => identity.set('piece_identite', toStringValue(value)));
    setIfPresent(request, 'photo', (value) => identity.set('photo', toStringValue(value)));
    setIfPresent(request, 'status', (value) => identity.set('status', toStringValue(value)));
    setIfPresent(request, 'remark', (value) => identity.set('remark', toStringValue(value)));

    await identity.save(null, { useMasterKey: true });
    return { success: true, message: 'Identité mise à jour avec succès.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('deleteIdentity', async (request) => {
  try {
    const query = new Parse.Query(CLASS.identities);
    query.equalTo('identityID', toNumber(request.params.identityID));
    const identity = await query.first({ useMasterKey: true });

    if (!identity) {
      return { success: false, error: 'Identité introuvable.' };
    }

    await identity.destroy({ useMasterKey: true });
    return { success: true, message: 'Identité supprimée avec succès.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('addMoyenPaiement', async (request) => {
  try {
    const nextLegacyId = await nextNumericId(CLASS.paymentMethods, 'idMoyen');
    const modernId = toStringValue(request.params.id_moyen_paiement, String(nextLegacyId));
    const stripePmId = toStringValue(request.params.stripe_pm_id);

    if (stripePmId) {
      const existingQuery = new Parse.Query(CLASS.paymentMethods);
      existingQuery.equalTo('stripe_pm_id', stripePmId);
      const existing = await existingQuery.first({ useMasterKey: true });
      if (existing) {
        return { success: false, error: 'Ce moyen de paiement existe déjà.' };
      }
    }

    const moyen = new Parse.Object(CLASS.paymentMethods);
    const label =
      toStringValue(request.params.libelle) ||
      toStringValue(request.params.nom) ||
      `${toStringValue(request.params.brand)} ****${toStringValue(request.params.last4)}`.trim();

    moyen.set('idMoyen', nextLegacyId);
    moyen.set('id_moyen_paiement', modernId);
    moyen.set('nom', label);
    moyen.set('libelle', label);
    moyen.set('userID', toNumber(request.params.userID));
    moyen.set('stripe_pm_id', stripePmId);
    moyen.set('brand', toStringValue(request.params.brand));
    moyen.set('last4', toNumber(request.params.last4));
    moyen.set('exp_month', toNumber(request.params.exp_month));
    moyen.set('exp_year', toNumber(request.params.exp_year));
    moyen.set('type', toStringValue(request.params.type, 'card'));
    moyen.set('is_default', toBoolean(request.params.is_default, true));

    await moyen.save(null, { useMasterKey: true });
    return {
      success: true,
      message: 'Ajouté',
      idMoyen: nextLegacyId,
      id_moyen_paiement: modernId,
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('updateMoyenPaiement', async (request) => {
  try {
    const query = new Parse.Query(CLASS.paymentMethods);

    if (hasParam(request, 'id_moyen_paiement')) {
      query.equalTo('id_moyen_paiement', toStringValue(request.params.id_moyen_paiement));
    } else {
      query.equalTo('idMoyen', toNumber(request.params.idMoyen));
    }

    const moyen = await query.first({ useMasterKey: true });
    if (!moyen) {
      return { success: false, error: 'Moyen introuvable.' };
    }

    setIfPresent(request, 'nom', (value) => moyen.set('nom', toStringValue(value)));
    setIfPresent(request, 'libelle', (value) => moyen.set('libelle', toStringValue(value)));
    setIfPresent(request, 'brand', (value) => moyen.set('brand', toStringValue(value)));
    setIfPresent(request, 'last4', (value) => moyen.set('last4', toNumber(value)));
    setIfPresent(request, 'exp_month', (value) => moyen.set('exp_month', toNumber(value)));
    setIfPresent(request, 'exp_year', (value) => moyen.set('exp_year', toNumber(value)));
    setIfPresent(request, 'type', (value) => moyen.set('type', toStringValue(value)));
    setIfPresent(request, 'is_default', (value) => moyen.set('is_default', toBoolean(value)));

    await moyen.save(null, { useMasterKey: true });
    return { success: true, message: 'Moyen mis à jour.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllMoyensPaiement', async () => {
  const moyens = await findAll(CLASS.paymentMethods, 'createdAt', 'descending');
  return moyens.map(serializePaymentMethod);
});

Parse.Cloud.define('add1Commande', async (request) => {
  try {
    const nextCommandeID = await nextNumericId(CLASS.commandes, 'commandeID');
    const commande = new Parse.Object(CLASS.commandes);
    const status = normalizeCommandeStatus(
      request.params.status || request.params.statut || request.params.statut_commande,
    );

    commande.set('commandeID', nextCommandeID);
    commande.set('id_commande', toStringValue(request.params.id_commande, String(nextCommandeID)));
    commande.set('userID', toNumber(request.params.userID ?? request.params.id_user));
    commande.set('id_user', toNumber(request.params.id_user ?? request.params.userID));
    commande.set('restauID', toNumber(request.params.restauID ?? request.params.id_restau));
    commande.set('id_restau', toNumber(request.params.id_restau ?? request.params.restauID));
    commande.set(
      'restaurateurID',
      toNumber(request.params.restaurateurID ?? request.params.id_restaurateur),
    );
    commande.set(
      'id_restaurateur',
      toNumber(request.params.id_restaurateur ?? request.params.restaurateurID),
    );
    commande.set('moyenPaiementID', toNumber(request.params.moyenPaiementID));
    commande.set('id_moyen_paiement', toStringValue(request.params.id_moyen_paiement));
    commande.set(
      'fraisLivraison',
      toNumber(request.params.fraisLivraison ?? request.params.frais_livraison),
    );
    commande.set(
      'frais_livraison',
      toNumber(request.params.frais_livraison ?? request.params.fraisLivraison),
    );
    commande.set('reduction', toNumber(request.params.reduction ?? request.params.reduction_globale));
    commande.set(
      'reduction_globale',
      toNumber(request.params.reduction_globale ?? request.params.reduction),
    );
    commande.set('heure', toStringValue(request.params.heure));
    commande.set('note', toNumber(request.params.note));
    commande.set('commentaire', toStringValue(request.params.commentaire));
    commande.set('status', status);
    commande.set('statut', status);
    commande.set('statut_commande', status);
    commande.set('currency', normalizeCurrency(request.params.currency));
    commande.set('promo_code', toStringValue(request.params.promo_code));
    commande.set('deliveryMode', toStringValue(request.params.deliveryMode));
    commande.set('subtotalAmount', toNumber(request.params.subtotalAmount));
    commande.set('totalAmount', toNumber(request.params.totalAmount));
    commande.set(
      'addressID',
      toNumber(request.params.addressID ?? request.params.id_adresse_livraison),
    );
    commande.set(
      'id_adresse_livraison',
      toNumber(request.params.id_adresse_livraison ?? request.params.addressID),
    );

    const commandeDate = toDateValue(
      request.params.dateCommande || request.params.date_commande || new Date(),
    );
    commande.set('dateCommande', commandeDate || new Date());
    commande.set('date_commande', commandeDate || new Date());

    await commande.save(null, { useMasterKey: true });
    return {
      success: true,
      message: 'Commande ajoutée',
      commandeID: nextCommandeID,
      id_commande: toStringValue(request.params.id_commande, String(nextCommandeID)),
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllCommandes', async () => {
  const commandes = await findAll(CLASS.commandes, 'date_commande', 'descending');
  return commandes.map(serializeCommande);
});

Parse.Cloud.define('updateCommande', async (request) => {
  try {
    const query = new Parse.Query(CLASS.commandes);

    if (hasParam(request, 'commandeID')) {
      query.equalTo('commandeID', toNumber(request.params.commandeID));
    } else if (hasParam(request, 'id_commande')) {
      query.equalTo('id_commande', toStringValue(request.params.id_commande));
    } else {
      return { success: false, error: 'commandeID ou id_commande est requis.' };
    }

    const commande = await query.first({ useMasterKey: true });
    if (!commande) {
      return { success: false, error: 'Commande introuvable.' };
    }

    setIfPresent(request, 'userID', (value) => {
      commande.set('userID', toNumber(value));
      commande.set('id_user', toNumber(value));
    });
    setIfPresent(request, 'id_user', (value) => {
      commande.set('id_user', toNumber(value));
      commande.set('userID', toNumber(value));
    });
    setIfPresent(request, 'restauID', (value) => {
      commande.set('restauID', toNumber(value));
      commande.set('id_restau', toNumber(value));
    });
    setIfPresent(request, 'id_restau', (value) => {
      commande.set('id_restau', toNumber(value));
      commande.set('restauID', toNumber(value));
    });
    setIfPresent(request, 'restaurateurID', (value) => {
      commande.set('restaurateurID', toNumber(value));
      commande.set('id_restaurateur', toNumber(value));
    });
    setIfPresent(request, 'id_restaurateur', (value) => {
      commande.set('id_restaurateur', toNumber(value));
      commande.set('restaurateurID', toNumber(value));
    });
    setIfPresent(request, 'moyenPaiementID', (value) => commande.set('moyenPaiementID', toNumber(value)));
    setIfPresent(request, 'id_moyen_paiement', (value) => commande.set('id_moyen_paiement', toStringValue(value)));
    setIfPresent(request, 'fraisLivraison', (value) => {
      commande.set('fraisLivraison', toNumber(value));
      commande.set('frais_livraison', toNumber(value));
    });
    setIfPresent(request, 'frais_livraison', (value) => {
      commande.set('frais_livraison', toNumber(value));
      commande.set('fraisLivraison', toNumber(value));
    });
    setIfPresent(request, 'reduction', (value) => {
      commande.set('reduction', toNumber(value));
      commande.set('reduction_globale', toNumber(value));
    });
    setIfPresent(request, 'reduction_globale', (value) => {
      commande.set('reduction_globale', toNumber(value));
      commande.set('reduction', toNumber(value));
    });
    setIfPresent(request, 'dateCommande', (value) => {
      const parsed = toDateValue(value);
      if (parsed) {
        commande.set('dateCommande', parsed);
        commande.set('date_commande', parsed);
      }
    });
    setIfPresent(request, 'date_commande', (value) => {
      const parsed = toDateValue(value);
      if (parsed) {
        commande.set('date_commande', parsed);
        commande.set('dateCommande', parsed);
      }
    });
    setIfPresent(request, 'heure', (value) => commande.set('heure', toStringValue(value)));
    setIfPresent(request, 'addressID', (value) => {
      commande.set('addressID', toNumber(value));
      commande.set('id_adresse_livraison', toNumber(value));
    });
    setIfPresent(request, 'id_adresse_livraison', (value) => {
      commande.set('id_adresse_livraison', toNumber(value));
      commande.set('addressID', toNumber(value));
    });
    setIfPresent(request, 'note', (value) => commande.set('note', toNumber(value)));
    setIfPresent(request, 'commentaire', (value) => commande.set('commentaire', toStringValue(value)));
    setIfPresent(request, 'currency', (value) => commande.set('currency', normalizeCurrency(value)));
    setIfPresent(request, 'promo_code', (value) => commande.set('promo_code', toStringValue(value)));
    setIfPresent(request, 'deliveryMode', (value) => commande.set('deliveryMode', toStringValue(value)));
    setIfPresent(request, 'subtotalAmount', (value) => commande.set('subtotalAmount', toNumber(value)));
    setIfPresent(request, 'totalAmount', (value) => commande.set('totalAmount', toNumber(value)));

    if (
      hasParam(request, 'status') ||
      hasParam(request, 'statut') ||
      hasParam(request, 'statut_commande')
    ) {
      const status = normalizeCommandeStatus(
        request.params.status || request.params.statut || request.params.statut_commande,
      );
      commande.set('status', status);
      commande.set('statut', status);
      commande.set('statut_commande', status);
    }

    await commande.save(null, { useMasterKey: true });
    return { success: true, message: 'Commande mise à jour.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('addLigneCommande', async (request) => {
  try {
    const nextLigneNumber = await nextNumericId(CLASS.lignesCommande, 'ligneID');
    const ligneId = toStringValue(request.params.ligneID, String(nextLigneNumber));
    const commandeID = toStringValue(
      request.params.commandeID || request.params.id_commande,
      '',
    );

    const ligne = new Parse.Object(CLASS.lignesCommande);
    ligne.set('ligneID', ligneId);
    ligne.set('id_ligne_commande', ligneId);
    ligne.set('commandeID', commandeID);
    ligne.set('id_commande', commandeID);
    ligne.set('platID', toNumber(request.params.platID ?? request.params.id_plat));
    ligne.set('id_plat', toNumber(request.params.id_plat ?? request.params.platID));
    ligne.set('quantite', toNumber(request.params.quantite));
    ligne.set(
      'prixUnitaire',
      toNumber(request.params.prixUnitaire ?? request.params.prix_unitaire),
    );
    ligne.set(
      'prix_unitaire',
      toNumber(request.params.prix_unitaire ?? request.params.prixUnitaire),
    );
    ligne.set('reduction', toNumber(request.params.reduction));
    ligne.set('note', toNumber(request.params.note));
    ligne.set('commentaire', toStringValue(request.params.commentaire));
    ligne.set('options', request.params.options || {});

    await ligne.save(null, { useMasterKey: true });
    return { success: true, message: 'Ligne ajoutée', ligneID: ligneId };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getLignesCommande', async (request) => {
  const commandeID = toStringValue(request.params.commandeID || request.params.id_commande);
  const query = new Parse.Query(CLASS.lignesCommande);
  query.equalTo('commandeID', commandeID);
  query.limit(1000);
  const lignes = await query.find({ useMasterKey: true });
  return lignes.map(serializeLigneCommande);
});

Parse.Cloud.define('getAllLignesCommande', async () => {
  const lignes = await findAll(CLASS.lignesCommande, 'createdAt', 'ascending');
  return lignes.map(serializeLigneCommande);
});

Parse.Cloud.define('updateLigneCommande', async (request) => {
  try {
    const query = new Parse.Query(CLASS.lignesCommande);
    query.equalTo(
      hasParam(request, 'ligneID') ? 'ligneID' : 'id_ligne_commande',
      toStringValue(request.params.ligneID || request.params.id_ligne_commande),
    );
    const ligne = await query.first({ useMasterKey: true });

    if (!ligne) {
      return { success: false, error: 'Ligne introuvable.' };
    }

    setIfPresent(request, 'commandeID', (value) => {
      ligne.set('commandeID', toStringValue(value));
      ligne.set('id_commande', toStringValue(value));
    });
    setIfPresent(request, 'id_commande', (value) => {
      ligne.set('id_commande', toStringValue(value));
      ligne.set('commandeID', toStringValue(value));
    });
    setIfPresent(request, 'platID', (value) => {
      ligne.set('platID', toNumber(value));
      ligne.set('id_plat', toNumber(value));
    });
    setIfPresent(request, 'id_plat', (value) => {
      ligne.set('id_plat', toNumber(value));
      ligne.set('platID', toNumber(value));
    });
    setIfPresent(request, 'quantite', (value) => ligne.set('quantite', toNumber(value)));
    setIfPresent(request, 'prixUnitaire', (value) => {
      ligne.set('prixUnitaire', toNumber(value));
      ligne.set('prix_unitaire', toNumber(value));
    });
    setIfPresent(request, 'prix_unitaire', (value) => {
      ligne.set('prix_unitaire', toNumber(value));
      ligne.set('prixUnitaire', toNumber(value));
    });
    setIfPresent(request, 'reduction', (value) => ligne.set('reduction', toNumber(value)));
    setIfPresent(request, 'note', (value) => ligne.set('note', toNumber(value)));
    setIfPresent(request, 'commentaire', (value) => ligne.set('commentaire', toStringValue(value)));
    setIfPresent(request, 'options', (value) => ligne.set('options', value || {}));

    await ligne.save(null, { useMasterKey: true });
    return { success: true, message: 'Ligne mise à jour.' };
  } catch (error) {
    return { success: false, error: error.message };
  }
});

Parse.Cloud.define('getAllRoles', async () => {
  const roles = await findAll(CLASS.roles, 'roleID', 'ascending');
  return roles.map((role) => role.toJSON());
});

Parse.Cloud.define('getAllComments', async () => {
  const comments = await findAll(CLASS.comments, 'createdAt', 'descending');
  return comments.map((comment) => comment.toJSON());
});

