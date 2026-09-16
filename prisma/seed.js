require('dotenv').config();

const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');
const prisma = require('../src/config/prisma');

const KINSHASA = {
  cityId: 1,
  name: 'Kinshasa',
  country: 'RDC',
  countryCode: 'CD',
  // Centre fourni par la relation administrative OSM 5646651.
  latitude: -4.3196982,
  longitude: 15.3424196,
};

// Localité renvoyée par la recherche inverse Nominatim fournie pour le test.
const NZILO = {
  cityId: 2,
  name: 'Nzilo',
  country: 'RDC',
  countryCode: 'CD',
  latitude: -10.509500589146018,
  longitude: 25.47007041219479,
};

// Frontière administrative OSM 5646651, simplifiée à environ 200 m pour le seed.
// Source : OpenStreetMap contributors, licence ODbL 1.0.
const KINSHASA_BOUNDARY_WKT = fs.readFileSync(path.join(__dirname, 'kinshasa-boundary.wkt'), 'utf8').trim();
// Emprise de démonstration autour de la position du client à Nzilo.
const NZILO_BOUNDARY_WKT = 'MULTIPOLYGON (((25.40 -10.58, 25.55 -10.58, 25.55 -10.45, 25.40 -10.45, 25.40 -10.58)))';
// Frontière administrative réelle de la commune de Gombe, relation OSM 388098.
// Géométrie simplifiée à environ 20-25 m pour rester légère dans le seed.
// Source : OpenStreetMap contributors, licence ODbL 1.0.
const KINSHASA_ZONE_BOUNDARY_WKT = fs.readFileSync(path.join(__dirname, 'gombe-boundary.wkt'), 'utf8').trim();
const KINSHASA_ZONE_POLYGON = fs.readFileSync(path.join(__dirname, 'gombe-boundary.json'), 'utf8').trim();

const categories = [
  { categoryId: 1, name: 'Cuisine congolaise' },
  { categoryId: 2, name: 'Afro-fusion' },
  { categoryId: 3, name: 'Méditerranéenne' },
  { categoryId: 4, name: 'Grillades' },
  { categoryId: 5, name: 'Pizza' },
  { categoryId: 6, name: 'Boissons' },
  { categoryId: 7, name: 'Desserts' },
];

const roles = [
  { roleId: 1, name: 'ADMIN' },
  { roleId: 2, name: 'CLIENT' },
  { roleId: 3, name: 'RESTAURATEUR' },
  { roleId: 4, name: 'LIVREUR' },
];

// Les noms et adresses correspondent à des restaurants existants à Kinshasa.
const restaurants = [
  {
    restaurantId: 1,
    ownerUserId: 2,
    name: 'KANYA Restaurant',
    categories: 'Cuisine congolaise, Afro-fusion',
    description: 'Cuisine traditionnelle congolaise et afro-fusion.',
    address: '43 Tombalbaye, Kinshasa',
    latitude: -4.306399420400104,
    longitude: 15.30997739167166,
    image: null,
  },
  {
    restaurantId: 2,
    ownerUserId: 3,
    name: 'Kiros Restaurant',
    categories: 'Méditerranéenne, Grillades',
    description: 'Cuisine libanaise, moyen-orientale et méditerranéenne.',
    address: '22 Avenue de la République du Tchad, Kinshasa',
    latitude: -4.304774617145705,
    longitude: 15.312844630303426,
    image: null,
  },
];

const dishes = [
  { dishId: 1, restaurantId: 1, name: 'Poulet à la moambe', categories: 'Cuisine congolaise', price: '12000', description: 'Poulet mijoté dans une sauce à base de noix de palme.', image: null },
  { dishId: 2, restaurantId: 1, name: 'Poisson braisé et banane plantain', categories: 'Cuisine congolaise, Grillades', price: '15000', description: 'Poisson braisé servi avec banane plantain.', image: null },
  { dishId: 3, restaurantId: 2, name: 'Assiette de mezze', categories: 'Méditerranéenne', price: '18000', description: 'Sélection de spécialités méditerranéennes à partager.', image: null },
  { dishId: 4, restaurantId: 2, name: 'Pizza maison', categories: 'Pizza', price: '16000', description: 'Pizza préparée sur place.', image: null },
];

const accounts = [
  { userId: 1, username: 'admin_seed', email: 'admin.seed@dios.cd', firstname: 'Administrateur', lastname: 'Dios', roleId: 1, accountType: 'ADMIN' },
  { userId: 2, username: 'kanya_owner_seed', email: 'kanya.owner.seed@dios.cd', firstname: 'Gérant', lastname: 'Kanya', roleId: 3, accountType: 'RESTAURATEUR' },
  { userId: 3, username: 'kiros_owner_seed', email: 'kiros.owner.seed@dios.cd', firstname: 'Gérant', lastname: 'Kiros', roleId: 3, accountType: 'RESTAURATEUR' },
  { userId: 4, username: 'livreur_one_seed', email: 'livreur.one.seed@dios.cd', firstname: 'Livreur', lastname: 'Un', roleId: 4, accountType: 'LIVREUR', telephoneE164: '+243810000001' },
  { userId: 5, username: 'livreur_two_seed', email: 'livreur.two.seed@dios.cd', firstname: 'Livreur', lastname: 'Deux', roleId: 4, accountType: 'LIVREUR', telephoneE164: '+243810000002' },
  {
    userId: 6,
    username: 'pierre',
    email: 'pierre.seed@dios.cd',
    firstname: 'Pierre',
    lastname: 'Nzilo',
    roleId: 2,
    accountType: 'CLIENT',
    cityId: NZILO.cityId,
    latitude: NZILO.latitude,
    longitude: NZILO.longitude,
  },
];

function requireSeedPassword() {
  const password = String(process.env.SEED_PASSWORD || '').trim();
  if (!password || password.length < 8) {
    throw new Error('Définissez SEED_PASSWORD avec au moins 8 caractères avant de lancer le seed.');
  }
  return password;
}

async function seedRoles() {
  const authRoles = {};
  for (const role of roles) {
    const authRole = await prisma.authRole.upsert({
      where: { name: role.name },
      update: {},
      create: { name: role.name },
    });
    authRoles[role.roleId] = authRole;

    await prisma.role.upsert({
      where: { roleId: role.roleId },
      update: { name: role.name },
      create: { roleId: role.roleId, name: role.name, nbUsers: 0, nbWaiting: 0 },
    });
  }
  return authRoles;
}

async function seedAccount(account, authRoles, passwordHash) {
  // On réutilise un compte trouvé par son identifiant historique ou son nom.
  // Cela évite un doublon si une ancienne version du seed utilisait un autre username.
  const existingAuthUser = await prisma.authUser.findFirst({
    where: { OR: [{ legacyUserId: account.userId }, { username: account.username }] },
    select: { id: true },
  });

  const authUser = existingAuthUser
    ? await prisma.authUser.update({
      where: { id: existingAuthUser.id },
      data: {
        username: account.username,
        email: account.email,
        password: passwordHash,
        legacyUserId: account.userId,
        firstname: account.firstname,
        lastname: account.lastname,
        telephoneE164: account.telephoneE164,
        deletedAt: null,
      },
    })
    : await prisma.authUser.create({
      data: {
        username: account.username,
        email: account.email,
        password: passwordHash,
        legacyUserId: account.userId,
        firstname: account.firstname,
        lastname: account.lastname,
        telephoneE164: account.telephoneE164,
        emailVerified: true,
      },
    });

  const user = await prisma.user.upsert({
    where: { userId: account.userId },
    update: {
      username: account.username,
      email: account.email,
      password: passwordHash,
      firstname: account.firstname,
      lastname: account.lastname,
      roleId: account.roleId,
      country: account.country || 'RDC',
      status: 'ACTIVE',
      accountType: account.accountType,
      cityId: account.cityId || KINSHASA.cityId,
      phoneVerified: Boolean(account.telephoneE164),
      deletedAt: null,
      ...(account.roleId === 4 ? { courierStatus: 'ACTIVE', locationUpdatedAt: new Date() } : {}),
    },
    create: {
      userId: account.userId,
      username: account.username,
      email: account.email,
      password: passwordHash,
      firstname: account.firstname,
      lastname: account.lastname,
      roleId: account.roleId,
      country: account.country || 'RDC',
      status: 'ACTIVE',
      accountType: account.accountType,
      cityId: account.cityId || KINSHASA.cityId,
      phoneVerified: Boolean(account.telephoneE164),
      ...(account.roleId === 4 ? { courierStatus: 'ACTIVE', locationUpdatedAt: new Date() } : {}),
    },
  });

  await prisma.authUserRole.upsert({
    where: { userId_roleId: { userId: authUser.id, roleId: authRoles[account.roleId].id } },
    update: {},
    create: { userId: authUser.id, roleId: authRoles[account.roleId].id },
  });

  if (account.latitude !== undefined && account.longitude !== undefined) {
    await prisma.$executeRaw`
      UPDATE "users"
      SET "location" = ST_SetSRID(ST_MakePoint(${account.longitude}, ${account.latitude}), 4326)::geography,
          "location_updated_at" = NOW()
      WHERE "userId" = ${account.userId}
    `;
  }

  return user;
}

async function seedCityAndDelivery() {
  await prisma.city.upsert({
    where: { cityId: KINSHASA.cityId },
    update: { name: KINSHASA.name, country: KINSHASA.country, countryCode: KINSHASA.countryCode, active: true, deliveryEnabled: true },
    create: { cityId: KINSHASA.cityId, name: KINSHASA.name, country: KINSHASA.country, countryCode: KINSHASA.countryCode, active: true, deliveryEnabled: true },
  });

  await prisma.$executeRaw`UPDATE "cities" SET "boundary" = ST_SetSRID(ST_GeomFromText(${KINSHASA_BOUNDARY_WKT}), 4326) WHERE "cityId" = ${KINSHASA.cityId}`;

  await prisma.city.upsert({
    where: { cityId: NZILO.cityId },
    update: { name: NZILO.name, country: NZILO.country, countryCode: NZILO.countryCode, active: true, deliveryEnabled: true },
    create: { cityId: NZILO.cityId, name: NZILO.name, country: NZILO.country, countryCode: NZILO.countryCode, active: true, deliveryEnabled: true },
  });

  await prisma.$executeRaw`UPDATE "cities" SET "boundary" = ST_SetSRID(ST_GeomFromText(${NZILO_BOUNDARY_WKT}), 4326) WHERE "cityId" = ${NZILO.cityId}`;

  await prisma.deliveryZone.upsert({
    where: { zoneId: 1 },
    update: { cityId: KINSHASA.cityId, name: 'Gombe', polygon: KINSHASA_ZONE_POLYGON, active: true, priority: '1' },
    create: { zoneId: 1, cityId: KINSHASA.cityId, name: 'Gombe', polygon: KINSHASA_ZONE_POLYGON, active: true, priority: '1' },
  });

  await prisma.$executeRaw`UPDATE "delivery_zones" SET "boundary" = ST_SetSRID(ST_GeomFromText(${KINSHASA_ZONE_BOUNDARY_WKT}), 4326) WHERE "zoneId" = 1`;

  await prisma.deliveryConfig.upsert({
    where: { configId: 1 },
    update: {
      cityId: KINSHASA.cityId,
      baseFee: '1000',
      perKmRate: '500',
      includedDistanceKm: '2',
      maxDistanceKm: '25',
      roundingIncrement: '50',
      currency: 'CDF',
      minFee: '1000',
      active: true,
      commissionRate: 0.15,
      exchangeRate: '2800',
      delivererBasePay: '1500',
      delivererPerKm: '300',
      subscriptionsEnabled: false,
    },
    create: {
      configId: 1,
      cityId: KINSHASA.cityId,
      baseFee: '1000',
      perKmRate: '500',
      includedDistanceKm: '2',
      maxDistanceKm: '25',
      roundingIncrement: '50',
      currency: 'CDF',
      minFee: '1000',
      active: true,
      commissionRate: 0.15,
      exchangeRate: '2800',
      delivererBasePay: '1500',
      delivererPerKm: '300',
      subscriptionsEnabled: false,
    },
  });
}

async function seedCatalog() {
  for (const category of categories) {
    await prisma.category.upsert({
      where: { categoryId: category.categoryId },
      update: { name: category.name, deletedAt: null },
      create: category,
    });
  }

  for (const restaurant of restaurants) {
    await prisma.restaurant.upsert({
      where: { restaurantId: restaurant.restaurantId },
      update: {
        userId: restaurant.ownerUserId,
        name: restaurant.name,
        categories: restaurant.categories,
        description: restaurant.description,
        address: restaurant.address,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
        image: restaurant.image,
        rating: 4.5,
        valid: 1,
        isOpen: 1,
        currency: 'CDF',
        country: 'RDC',
        cityId: KINSHASA.cityId,
        deletedAt: null,
      },
      create: {
        restaurantId: restaurant.restaurantId,
        userId: restaurant.ownerUserId,
        name: restaurant.name,
        categories: restaurant.categories,
        description: restaurant.description,
        address: restaurant.address,
        latitude: restaurant.latitude,
        longitude: restaurant.longitude,
        image: restaurant.image,
        rating: 4.5,
        valid: 1,
        isOpen: 1,
        currency: 'CDF',
        country: 'RDC',
        cityId: KINSHASA.cityId,
      },
    });

    await prisma.$executeRaw`
      UPDATE "restaurants"
      SET "location" = ST_SetSRID(ST_MakePoint(${restaurant.longitude}, ${restaurant.latitude}), 4326)::geography,
          "location_updated_at" = NOW()
      WHERE "restaurantId" = ${restaurant.restaurantId}
    `;
  }

  for (const dish of dishes) {
    await prisma.dish.upsert({
      where: { dishId: dish.dishId },
      update: {
        restaurantId: dish.restaurantId,
        name: dish.name,
        categories: dish.categories,
        price: dish.price,
        description: dish.description,
        image: dish.image,
        currency: 'CDF',
        country: 'RDC',
        cityId: KINSHASA.cityId,
        status: 1,
        deletedAt: null,
      },
      create: {
        dishId: dish.dishId,
        restaurantId: dish.restaurantId,
        name: dish.name,
        categories: dish.categories,
        price: dish.price,
        description: dish.description,
        image: dish.image,
        currency: 'CDF',
        country: 'RDC',
        cityId: KINSHASA.cityId,
        status: 1,
      },
    });
  }
}

async function seedCourierLocations() {
  const courierCoordinates = [
    { userId: 4, latitude: -4.3145, longitude: 15.3035 },
    { userId: 5, latitude: -4.3120, longitude: 15.3070 },
  ];

  for (const courier of courierCoordinates) {
    const existing = await prisma.courierLocation.findFirst({ where: { delivererId: courier.userId } });
    if (!existing) {
      const location = await prisma.courierLocation.create({
        data: { delivererId: courier.userId, cityId: KINSHASA.cityId, latitude: courier.latitude, longitude: courier.longitude, accuracyM: 10 },
      });
      await prisma.$executeRaw`
        UPDATE "courier_locations"
        SET "location" = ST_SetSRID(ST_MakePoint(${courier.longitude}, ${courier.latitude}), 4326)::geography
        WHERE "id" = ${location.id}::uuid
      `;
    }

    await prisma.$executeRaw`
      UPDATE "users"
      SET "location" = ST_SetSRID(ST_MakePoint(${courier.longitude}, ${courier.latitude}), 4326)::geography,
          "location_updated_at" = NOW(),
          "courier_status" = 'ACTIVE'
      WHERE "userId" = ${courier.userId}
    `;
  }
}

async function main() {
  const passwordHash = await bcrypt.hash(requireSeedPassword(), 12);
  const authRoles = await seedRoles();

  for (const account of accounts) {
    await seedAccount(account, authRoles, passwordHash);
  }

  await seedCityAndDelivery();
  await seedCatalog();
  await seedCourierLocations();

  console.log('Seed terminé : rôles, comptes de test, Kinshasa, Nzilo, restaurants, plats et livraison de démonstration créés.');
  console.log('Compte client de test créé à Nzilo : pierre');
}

main()
  .catch((error) => {
    console.error('Échec du seed :', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
