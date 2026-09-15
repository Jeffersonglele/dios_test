-- Initial local Dios Delices schema.
-- PostGIS is enabled before PostgreSQL creates geography/geometry fields.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateTable
CREATE TABLE "auth_users" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "username" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "email" TEXT,
    "emailVerified" BOOLEAN NOT NULL DEFAULT false,
    "authData" JSONB,
    "acl" JSONB,
    "firstname" TEXT,
    "lastname" TEXT,
    "telephone" TEXT,
    "telephoneLocal" TEXT,
    "telephoneE164" TEXT,
    "legacyUserId" INTEGER,
    "image" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "auth_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_roles" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "name" TEXT NOT NULL,
    "acl" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "auth_roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_user_roles" (
    "userId" UUID NOT NULL,
    "roleId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_user_roles_pkey" PRIMARY KEY ("userId","roleId")
);

-- CreateTable
CREATE TABLE "auth_role_links" (
    "parentRoleId" UUID NOT NULL,
    "childRoleId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_role_links_pkey" PRIMARY KEY ("parentRoleId","childRoleId")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "userId" INTEGER,
    "firstname" TEXT,
    "lastname" TEXT,
    "username" TEXT,
    "email" TEXT,
    "password" TEXT,
    "telephone" TEXT,
    "telephoneLocal" TEXT,
    "telephoneE164" TEXT,
    "roleId" INTEGER,
    "country" TEXT,
    "status" TEXT,
    "identity" TEXT,
    "addressId" INTEGER,
    "lastLogin" TIMESTAMP(3),
    "image" TEXT,
    "parrain" TEXT,
    "cityId" INTEGER,
    "courier_status" TEXT,
    "location" geography(Point,4326),
    "location_updated_at" TIMESTAMP(3),
    "phoneVerified" BOOLEAN NOT NULL DEFAULT false,
    "accountType" TEXT,
    "otpPhone" TEXT,
    "ageConfirmed" BOOLEAN NOT NULL DEFAULT false,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "roleId" INTEGER,
    "name" TEXT,
    "nbUsers" INTEGER,
    "nbWaiting" INTEGER,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gallery" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "fileUrl" TEXT NOT NULL,
    "name" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gallery_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "restaurants" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "restaurantId" INTEGER,
    "userId" INTEGER,
    "categories" TEXT,
    "description" TEXT,
    "adress" TEXT,
    "addressId" INTEGER,
    "name" TEXT,
    "note" DOUBLE PRECISION,
    "image" TEXT,
    "dateCreation" TIMESTAMP(3),
    "valid" INTEGER,
    "nb_orders" INTEGER,
    "openingHours" TEXT,
    "deliveryFee" DECIMAL(14,2),
    "isOpen" INTEGER,
    "professionalType" TEXT,
    "trainingCompleted" BOOLEAN NOT NULL DEFAULT false,
    "reviewRemark" TEXT,
    "currency" TEXT,
    "openingDays" TEXT,
    "minOrderAmount" DECIMAL(14,2),
    "deliveryRadius" DOUBLE PRECISION,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "location" geography(Point,4326),
    "location_updated_at" TIMESTAMP(3),
    "closedDates" TEXT,
    "recoveryMode" TEXT,
    "country" TEXT,
    "isPro" BOOLEAN NOT NULL DEFAULT false,
    "cityId" INTEGER,
    "rccm" TEXT,
    "paymentMethod" TEXT,
    "mobileMoneyPhone" TEXT,
    "iban" TEXT,
    "bankName" TEXT,
    "accountHolder" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "restaurants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dishes" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "dishId" INTEGER,
    "userId" INTEGER,
    "restau_id" INTEGER,
    "name" TEXT,
    "categories" TEXT,
    "image" TEXT,
    "images" TEXT,
    "nb_orders" INTEGER,
    "price" DECIMAL(14,2),
    "description" TEXT,
    "nb_servings" INTEGER,
    "status" INTEGER,
    "note" DOUBLE PRECISION,
    "option1" TEXT,
    "option2" TEXT,
    "option3" TEXT,
    "currency" TEXT,
    "country" TEXT,
    "cityId" INTEGER,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dishes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "comments" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "commentId" INTEGER,
    "userId" INTEGER,
    "target" INTEGER,
    "targetId" INTEGER,
    "description" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "addresses" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "addressId" INTEGER NOT NULL,
    "object" TEXT,
    "objectId" INTEGER,
    "numero" INTEGER,
    "city" TEXT,
    "state" TEXT,
    "country" TEXT,
    "fullAddress" TEXT,
    "lat" DOUBLE PRECISION,
    "long" DOUBLE PRECISION,
    "cityId" INTEGER,
    "location" geography(Point,4326),
    "location_source" TEXT,
    "location_updated_at" TIMESTAMP(3),
    "nominatim_place_id" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "identities" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "identityId" INTEGER,
    "userId" INTEGER,
    "piece_identite" TEXT,
    "photo" TEXT,
    "status" TEXT,
    "remark" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "identities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_methods" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "id_moyen" INTEGER,
    "id_moyen_paiement" TEXT,
    "nom" TEXT,
    "libelle" TEXT,
    "userId" INTEGER,
    "stripe_pm_id" TEXT,
    "brand" TEXT,
    "last4" INTEGER,
    "exp_month" INTEGER,
    "exp_year" INTEGER,
    "type" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "commande_id" INTEGER,
    "id_commande" TEXT,
    "userId" INTEGER,
    "id_user" INTEGER,
    "restau_id" INTEGER,
    "id_restau" INTEGER,
    "restaurateurId" INTEGER,
    "id_restaurateur" INTEGER,
    "moyen_paiement_id" INTEGER,
    "id_moyen_paiement" TEXT,
    "frais_livraison" DECIMAL(14,2),
    "fraisLivraison" DECIMAL(14,2),
    "reduction" DECIMAL(14,2),
    "reduction_globale" DECIMAL(14,2),
    "date_commande" TIMESTAMP(3),
    "dateCommande" TIMESTAMP(3),
    "heure" TEXT,
    "addressId" INTEGER,
    "id_adresse_livraison" INTEGER,
    "note" DOUBLE PRECISION,
    "commentaire" TEXT,
    "status" TEXT,
    "statut" TEXT,
    "statut_commande" TEXT,
    "currency" TEXT,
    "promo_code" TEXT,
    "deliveryMode" TEXT,
    "subtotalAmount" DECIMAL(14,2),
    "totalAmount" DECIMAL(14,2),
    "livreur_id" INTEGER,
    "deliveryStatus" TEXT,
    "country" TEXT,
    "isPro" TEXT,
    "livreur_nom" TEXT,
    "livraisonStatus" TEXT,
    "livraisonDate" TEXT,
    "livreur_lat" DOUBLE PRECISION,
    "livreur_lng" DOUBLE PRECISION,
    "cityId" INTEGER,
    "paymentProvider" TEXT,
    "tipAmount" DECIMAL(14,2),
    "delivererBasePay" DECIMAL(14,2),
    "delivererDistancePay" DECIMAL(14,2),
    "delivererEarningsStatus" TEXT,
    "delivery_distance_km" DECIMAL(10,3),
    "delivery_quote_snapshot" JSONB,
    "delivery_address_snapshot" JSONB,
    "pickup_snapshot" JSONB,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_lines" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "ligne_id" TEXT,
    "id_ligne_commande" TEXT,
    "commande_id" TEXT,
    "id_commande" TEXT,
    "plat_id" INTEGER,
    "id_plat" INTEGER,
    "quantity" INTEGER,
    "prix_unitaire" DECIMAL(14,2),
    "prixUnitaire" DECIMAL(14,2),
    "reduction" DECIMAL(14,2),
    "note" DOUBLE PRECISION,
    "commentaire" TEXT,
    "options" JSONB,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "order_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "messages" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "fromUserId" INTEGER,
    "toUserId" INTEGER,
    "text" TEXT,
    "commande_id" INTEGER,
    "read" BOOLEAN NOT NULL DEFAULT false,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_logins" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "userId" INTEGER,
    "username" TEXT,
    "ip" TEXT,
    "loginAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_logins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reports" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "reporterUserId" INTEGER,
    "targetType" INTEGER,
    "targetId" INTEGER,
    "reason" TEXT,
    "details" TEXT,
    "status" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pro_documents" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "documentId" INTEGER,
    "userId" INTEGER,
    "restaurantId" INTEGER,
    "siretUrl" TEXT,
    "kbisUrl" TEXT,
    "piece_identite_url" TEXT,
    "description" TEXT,
    "status" TEXT,
    "remark" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pro_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "verification_codes" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "email" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "phone" TEXT,
    "purpose" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "blockedUntil" TIMESTAMP(3),
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "verification_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "promo_codes" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "code" TEXT NOT NULL,
    "description" TEXT,
    "discountPercent" DOUBLE PRECISION,
    "discountFixed" DECIMAL(14,2),
    "minOrder" DECIMAL(14,2),
    "validFrom" TIMESTAMP(3),
    "validUntil" TIMESTAMP(3),
    "active" BOOLEAN NOT NULL DEFAULT true,
    "maxUses" INTEGER,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "promo_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "categoryId" INTEGER,
    "name" TEXT,
    "image" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cities" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "cityId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "country" TEXT,
    "country_code" TEXT NOT NULL DEFAULT 'CD',
    "boundary" geometry(MultiPolygon,4326),
    "delivery_enabled" BOOLEAN NOT NULL DEFAULT true,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_zones" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "zoneId" INTEGER NOT NULL,
    "cityId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "polygon" TEXT NOT NULL,
    "boundary" geometry(MultiPolygon,4326),
    "delivery_time_min" INTEGER,
    "delivery_time_max" INTEGER,
    "delivery_fee_level" TEXT,
    "priority" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "delivery_zones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "transactions" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "transactionId" TEXT NOT NULL,
    "commande_id" INTEGER NOT NULL,
    "provider" TEXT NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "currency" TEXT,
    "status" TEXT,
    "providerRef" TEXT,
    "operator" TEXT,
    "phone" TEXT,
    "paymentMethod" TEXT,
    "providerData" JSONB,
    "settlementStatus" TEXT,
    "commissionRate" DOUBLE PRECISION,
    "subtotalAmount" DECIMAL(14,2),
    "commissionAmount" DECIMAL(14,2),
    "restaurantShare" DECIMAL(14,2),
    "deliveryFeeShare" DECIMAL(14,2),
    "settledAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_configs" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "configId" INTEGER NOT NULL,
    "city_id" INTEGER,
    "baseFee" DECIMAL(14,2) NOT NULL,
    "perKmRate" DECIMAL(14,2) NOT NULL,
    "included_distance_km" DECIMAL(10,3),
    "max_distance_km" DECIMAL(10,3),
    "fuel_price_per_litre" DECIMAL(14,2),
    "fuel_surcharge" DECIMAL(14,2),
    "demand_multiplier" DECIMAL(6,3) DEFAULT 1,
    "weather_multiplier" DECIMAL(6,3) DEFAULT 1,
    "rounding_increment" DECIMAL(14,2) DEFAULT 50,
    "currency" TEXT,
    "minFee" DECIMAL(14,2),
    "updatedBy" INTEGER,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "commissionRate" DOUBLE PRECISION,
    "exchangeRate" DECIMAL(18,6),
    "delivererBasePay" DECIMAL(14,2),
    "delivererPerKm" DECIMAL(14,2),
    "subscriptionsEnabled" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "delivery_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deliveries" (
    "id" UUID NOT NULL,
    "delivery_id" TEXT NOT NULL,
    "commande_id" INTEGER NOT NULL,
    "city_id" INTEGER NOT NULL,
    "restaurant_id" INTEGER,
    "livreur_id" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'SEARCHING',
    "dispatch_attempt" INTEGER NOT NULL DEFAULT 0,
    "pickup_latitude" DOUBLE PRECISION,
    "pickup_longitude" DOUBLE PRECISION,
    "delivery_latitude" DOUBLE PRECISION,
    "delivery_longitude" DOUBLE PRECISION,
    "quoted_distance_km" DECIMAL(10,3),
    "accepted_at" TIMESTAMP(3),
    "picked_up_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "cancellation_reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_offers" (
    "id" UUID NOT NULL,
    "delivery_id" TEXT NOT NULL,
    "livreur_id" INTEGER NOT NULL,
    "rank" INTEGER NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "expires_at" TIMESTAMP(3),
    "responded_at" TIMESTAMP(3),
    "distance_to_pickup_km" DECIMAL(10,3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "delivery_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "courier_locations" (
    "id" UUID NOT NULL,
    "livreur_id" INTEGER NOT NULL,
    "city_id" INTEGER,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "location" geography(Point,4326),
    "accuracy_m" DOUBLE PRECISION,
    "recorded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "courier_locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mobile_money_accounts" (
    "id" UUID NOT NULL,
    "user_id" INTEGER NOT NULL,
    "operator" TEXT NOT NULL,
    "phone_e164" TEXT NOT NULL,
    "label" TEXT,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "mobile_money_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_accounts" (
    "id" UUID NOT NULL,
    "user_id" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'CDF',
    "status" TEXT NOT NULL DEFAULT 'DISABLED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wallet_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_ledger_entries" (
    "id" UUID NOT NULL,
    "wallet_account_id" UUID NOT NULL,
    "direction" TEXT NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'CDF',
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "reference_type" TEXT NOT NULL,
    "reference_id" TEXT NOT NULL,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "posted_at" TIMESTAMP(3),

    CONSTRAINT "wallet_ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tips" (
    "id" UUID NOT NULL,
    "commande_id" INTEGER NOT NULL,
    "delivery_id" TEXT,
    "customer_id" INTEGER NOT NULL,
    "livreur_id" INTEGER NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'CDF',
    "payment_method" TEXT,
    "transaction_id" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "paid_at" TIMESTAMP(3),

    CONSTRAINT "tips_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_webhook_events" (
    "id" UUID NOT NULL,
    "provider" TEXT NOT NULL,
    "external_event_id" TEXT,
    "transaction_id" TEXT,
    "payload" JSONB NOT NULL,
    "signature_valid" BOOLEAN NOT NULL,
    "processed_at" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "action" TEXT,
    "details" TEXT,
    "userName" TEXT,
    "country" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "invoices" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "invoiceId" TEXT NOT NULL,
    "commande_id" INTEGER NOT NULL,
    "restaurantId" INTEGER,
    "restaurantName" TEXT,
    "restaurantAddress" TEXT,
    "rccm" TEXT,
    "restaurantPhone" TEXT,
    "customerName" TEXT,
    "invoiceDate" TIMESTAMP(3),
    "items" JSONB,
    "subtotal" DECIMAL(14,2),
    "deliveryFee" DECIMAL(14,2),
    "total_cdf" DECIMAL(14,2),
    "total_usd" DECIMAL(14,2),
    "exchangeRate" DECIMAL(18,6),
    "currency" TEXT,
    "pdfUrl" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "restaurant_payouts" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "paiement_id" INTEGER NOT NULL,
    "restaurantId" INTEGER NOT NULL,
    "restaurateurId" INTEGER,
    "restaurantName" TEXT,
    "weekStart" TIMESTAMP(3) NOT NULL,
    "weekEnd" TIMESTAMP(3) NOT NULL,
    "totalOrders" INTEGER,
    "totalSubtotal" DECIMAL(14,2),
    "totalDeliveryFees" DECIMAL(14,2),
    "commissionRate" DOUBLE PRECISION,
    "totalCommission" DECIMAL(14,2),
    "netAmount" DECIMAL(14,2),
    "status" TEXT,
    "payoutMethod" TEXT,
    "mobileMoneyPhone" TEXT,
    "iban" TEXT,
    "payoutRef" TEXT,
    "paidAt" TIMESTAMP(3),
    "errorMessage" TEXT,
    "cityId" INTEGER,
    "commissionInvoiceUrl" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "restaurant_payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deliverer_payouts" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "paiement_id" INTEGER NOT NULL,
    "delivererId" INTEGER NOT NULL,
    "delivererName" TEXT,
    "weekStart" TIMESTAMP(3) NOT NULL,
    "weekEnd" TIMESTAMP(3) NOT NULL,
    "totalDeliveries" INTEGER,
    "totalBasePay" DECIMAL(14,2),
    "totalDistancePay" DECIMAL(14,2),
    "totalTips" DECIMAL(14,2),
    "netAmount" DECIMAL(14,2),
    "status" TEXT,
    "payoutMethod" TEXT,
    "mobileMoneyPhone" TEXT,
    "iban" TEXT,
    "payoutRef" TEXT,
    "paidAt" TIMESTAMP(3),
    "errorMessage" TEXT,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "deliverer_payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL,
    "parseObjectId" TEXT,
    "subscriptionId" INTEGER NOT NULL,
    "restaurantId" INTEGER NOT NULL,
    "restaurantName" TEXT,
    "plan" TEXT,
    "price" DECIMAL(14,2),
    "currency" TEXT,
    "startDate" TIMESTAMP(3),
    "endDate" TIMESTAMP(3),
    "status" TEXT,
    "autoRenew" BOOLEAN NOT NULL DEFAULT false,
    "paymentMethod" TEXT,
    "paymentRef" TEXT,
    "features" JSONB,
    "cityId" INTEGER,
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "auth_users_parseObjectId_key" ON "auth_users"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "auth_users_username_key" ON "auth_users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "auth_users_email_key" ON "auth_users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "auth_users_legacyUserId_key" ON "auth_users"("legacyUserId");

-- CreateIndex
CREATE INDEX "auth_users_firstname_idx" ON "auth_users"("firstname");

-- CreateIndex
CREATE UNIQUE INDEX "auth_roles_parseObjectId_key" ON "auth_roles"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "auth_roles_name_key" ON "auth_roles"("name");

-- CreateIndex
CREATE UNIQUE INDEX "users_parseObjectId_key" ON "users"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "users_userId_key" ON "users"("userId");

-- CreateIndex
CREATE INDEX "users_firstname_idx" ON "users"("firstname");

-- CreateIndex
CREATE INDEX "users_cityId_idx" ON "users"("cityId");

-- CreateIndex
CREATE INDEX "users_email_telephone_username_idx" ON "users"("email", "telephone", "username");

-- CreateIndex
CREATE INDEX "users_roleId_idx" ON "users"("roleId");

-- CreateIndex
CREATE UNIQUE INDEX "roles_parseObjectId_key" ON "roles"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "roles_roleId_key" ON "roles"("roleId");

-- CreateIndex
CREATE UNIQUE INDEX "gallery_parseObjectId_key" ON "gallery"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "restaurants_parseObjectId_key" ON "restaurants"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "restaurants_restaurantId_key" ON "restaurants"("restaurantId");

-- CreateIndex
CREATE INDEX "restaurants_userId_idx" ON "restaurants"("userId");

-- CreateIndex
CREATE INDEX "restaurants_name_idx" ON "restaurants"("name");

-- CreateIndex
CREATE INDEX "restaurants_cityId_idx" ON "restaurants"("cityId");

-- CreateIndex
CREATE UNIQUE INDEX "dishes_parseObjectId_key" ON "dishes"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "dishes_dishId_key" ON "dishes"("dishId");

-- CreateIndex
CREATE INDEX "dishes_restau_id_name_idx" ON "dishes"("restau_id", "name");

-- CreateIndex
CREATE INDEX "dishes_cityId_idx" ON "dishes"("cityId");

-- CreateIndex
CREATE INDEX "dishes_userId_idx" ON "dishes"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "comments_parseObjectId_key" ON "comments"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "comments_commentId_key" ON "comments"("commentId");

-- CreateIndex
CREATE INDEX "comments_target_targetId_idx" ON "comments"("target", "targetId");

-- CreateIndex
CREATE INDEX "comments_userId_idx" ON "comments"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "addresses_parseObjectId_key" ON "addresses"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "addresses_addressId_key" ON "addresses"("addressId");

-- CreateIndex
CREATE INDEX "addresses_lat_long_object_objectId_idx" ON "addresses"("lat", "long", "object", "objectId");

-- CreateIndex
CREATE UNIQUE INDEX "identities_parseObjectId_key" ON "identities"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "identities_identityId_key" ON "identities"("identityId");

-- CreateIndex
CREATE INDEX "identities_userId_idx" ON "identities"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "payment_methods_parseObjectId_key" ON "payment_methods"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "payment_methods_id_moyen_key" ON "payment_methods"("id_moyen");

-- CreateIndex
CREATE INDEX "payment_methods_userId_idx" ON "payment_methods"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "orders_parseObjectId_key" ON "orders"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "orders_commande_id_key" ON "orders"("commande_id");

-- CreateIndex
CREATE INDEX "orders_userId_idx" ON "orders"("userId");

-- CreateIndex
CREATE INDEX "orders_restau_id_idx" ON "orders"("restau_id");

-- CreateIndex
CREATE INDEX "orders_restaurateurId_idx" ON "orders"("restaurateurId");

-- CreateIndex
CREATE INDEX "orders_livreur_id_idx" ON "orders"("livreur_id");

-- CreateIndex
CREATE INDEX "orders_cityId_idx" ON "orders"("cityId");

-- CreateIndex
CREATE INDEX "orders_status_idx" ON "orders"("status");

-- CreateIndex
CREATE UNIQUE INDEX "order_lines_parseObjectId_key" ON "order_lines"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "order_lines_ligne_id_key" ON "order_lines"("ligne_id");

-- CreateIndex
CREATE INDEX "order_lines_commande_id_idx" ON "order_lines"("commande_id");

-- CreateIndex
CREATE INDEX "order_lines_plat_id_idx" ON "order_lines"("plat_id");

-- CreateIndex
CREATE UNIQUE INDEX "messages_parseObjectId_key" ON "messages"("parseObjectId");

-- CreateIndex
CREATE INDEX "messages_fromUserId_idx" ON "messages"("fromUserId");

-- CreateIndex
CREATE INDEX "messages_toUserId_idx" ON "messages"("toUserId");

-- CreateIndex
CREATE INDEX "messages_commande_id_idx" ON "messages"("commande_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_logins_parseObjectId_key" ON "user_logins"("parseObjectId");

-- CreateIndex
CREATE INDEX "user_logins_userId_idx" ON "user_logins"("userId");

-- CreateIndex
CREATE INDEX "user_logins_loginAt_idx" ON "user_logins"("loginAt");

-- CreateIndex
CREATE UNIQUE INDEX "reports_parseObjectId_key" ON "reports"("parseObjectId");

-- CreateIndex
CREATE INDEX "reports_reporterUserId_idx" ON "reports"("reporterUserId");

-- CreateIndex
CREATE INDEX "reports_targetType_targetId_idx" ON "reports"("targetType", "targetId");

-- CreateIndex
CREATE UNIQUE INDEX "pro_documents_parseObjectId_key" ON "pro_documents"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "pro_documents_documentId_key" ON "pro_documents"("documentId");

-- CreateIndex
CREATE INDEX "pro_documents_userId_idx" ON "pro_documents"("userId");

-- CreateIndex
CREATE INDEX "pro_documents_restaurantId_idx" ON "pro_documents"("restaurantId");

-- CreateIndex
CREATE UNIQUE INDEX "verification_codes_parseObjectId_key" ON "verification_codes"("parseObjectId");

-- CreateIndex
CREATE INDEX "verification_codes_email_purpose_idx" ON "verification_codes"("email", "purpose");

-- CreateIndex
CREATE INDEX "verification_codes_phone_purpose_idx" ON "verification_codes"("phone", "purpose");

-- CreateIndex
CREATE INDEX "verification_codes_expiresAt_idx" ON "verification_codes"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "promo_codes_parseObjectId_key" ON "promo_codes"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "promo_codes_code_key" ON "promo_codes"("code");

-- CreateIndex
CREATE INDEX "promo_codes_active_validUntil_idx" ON "promo_codes"("active", "validUntil");

-- CreateIndex
CREATE UNIQUE INDEX "categories_parseObjectId_key" ON "categories"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "categories_categoryId_key" ON "categories"("categoryId");

-- CreateIndex
CREATE INDEX "categories_name_idx" ON "categories"("name");

-- CreateIndex
CREATE UNIQUE INDEX "cities_parseObjectId_key" ON "cities"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "cities_cityId_key" ON "cities"("cityId");

-- CreateIndex
CREATE INDEX "cities_country_active_idx" ON "cities"("country", "active");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_zones_parseObjectId_key" ON "delivery_zones"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_zones_zoneId_key" ON "delivery_zones"("zoneId");

-- CreateIndex
CREATE INDEX "delivery_zones_cityId_idx" ON "delivery_zones"("cityId");

-- CreateIndex
CREATE INDEX "delivery_zones_active_idx" ON "delivery_zones"("active");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_parseObjectId_key" ON "transactions"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "transactions_transactionId_key" ON "transactions"("transactionId");

-- CreateIndex
CREATE INDEX "transactions_commande_id_idx" ON "transactions"("commande_id");

-- CreateIndex
CREATE INDEX "transactions_status_idx" ON "transactions"("status");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_configs_parseObjectId_key" ON "delivery_configs"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_configs_configId_key" ON "delivery_configs"("configId");

-- CreateIndex
CREATE INDEX "delivery_configs_city_id_active_idx" ON "delivery_configs"("city_id", "active");

-- CreateIndex
CREATE UNIQUE INDEX "deliveries_delivery_id_key" ON "deliveries"("delivery_id");

-- CreateIndex
CREATE UNIQUE INDEX "deliveries_commande_id_key" ON "deliveries"("commande_id");

-- CreateIndex
CREATE INDEX "deliveries_city_id_status_idx" ON "deliveries"("city_id", "status");

-- CreateIndex
CREATE INDEX "deliveries_livreur_id_status_idx" ON "deliveries"("livreur_id", "status");

-- CreateIndex
CREATE INDEX "delivery_offers_livreur_id_status_idx" ON "delivery_offers"("livreur_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_offers_delivery_id_livreur_id_key" ON "delivery_offers"("delivery_id", "livreur_id");

-- CreateIndex
CREATE INDEX "courier_locations_livreur_id_recorded_at_idx" ON "courier_locations"("livreur_id", "recorded_at");

-- CreateIndex
CREATE INDEX "courier_locations_city_id_recorded_at_idx" ON "courier_locations"("city_id", "recorded_at");

-- CreateIndex
CREATE INDEX "mobile_money_accounts_user_id_is_default_idx" ON "mobile_money_accounts"("user_id", "is_default");

-- CreateIndex
CREATE UNIQUE INDEX "mobile_money_accounts_user_id_operator_phone_e164_key" ON "mobile_money_accounts"("user_id", "operator", "phone_e164");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_accounts_user_id_key" ON "wallet_accounts"("user_id");

-- CreateIndex
CREATE INDEX "wallet_ledger_entries_wallet_account_id_createdAt_idx" ON "wallet_ledger_entries"("wallet_account_id", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_ledger_entries_wallet_account_id_reference_type_refe_key" ON "wallet_ledger_entries"("wallet_account_id", "reference_type", "reference_id", "direction");

-- CreateIndex
CREATE UNIQUE INDEX "tips_transaction_id_key" ON "tips"("transaction_id");

-- CreateIndex
CREATE INDEX "tips_commande_id_status_idx" ON "tips"("commande_id", "status");

-- CreateIndex
CREATE INDEX "tips_livreur_id_status_idx" ON "tips"("livreur_id", "status");

-- CreateIndex
CREATE INDEX "payment_webhook_events_transaction_id_idx" ON "payment_webhook_events"("transaction_id");

-- CreateIndex
CREATE UNIQUE INDEX "payment_webhook_events_provider_external_event_id_key" ON "payment_webhook_events"("provider", "external_event_id");

-- CreateIndex
CREATE UNIQUE INDEX "audit_logs_parseObjectId_key" ON "audit_logs"("parseObjectId");

-- CreateIndex
CREATE INDEX "audit_logs_createdAt_idx" ON "audit_logs"("createdAt");

-- CreateIndex
CREATE INDEX "audit_logs_action_idx" ON "audit_logs"("action");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_parseObjectId_key" ON "invoices"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_invoiceId_key" ON "invoices"("invoiceId");

-- CreateIndex
CREATE INDEX "invoices_commande_id_idx" ON "invoices"("commande_id");

-- CreateIndex
CREATE INDEX "invoices_restaurantId_idx" ON "invoices"("restaurantId");

-- CreateIndex
CREATE UNIQUE INDEX "restaurant_payouts_parseObjectId_key" ON "restaurant_payouts"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "restaurant_payouts_paiement_id_key" ON "restaurant_payouts"("paiement_id");

-- CreateIndex
CREATE INDEX "restaurant_payouts_restaurantId_idx" ON "restaurant_payouts"("restaurantId");

-- CreateIndex
CREATE INDEX "restaurant_payouts_status_idx" ON "restaurant_payouts"("status");

-- CreateIndex
CREATE INDEX "restaurant_payouts_weekStart_weekEnd_idx" ON "restaurant_payouts"("weekStart", "weekEnd");

-- CreateIndex
CREATE UNIQUE INDEX "deliverer_payouts_parseObjectId_key" ON "deliverer_payouts"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "deliverer_payouts_paiement_id_key" ON "deliverer_payouts"("paiement_id");

-- CreateIndex
CREATE INDEX "deliverer_payouts_delivererId_idx" ON "deliverer_payouts"("delivererId");

-- CreateIndex
CREATE INDEX "deliverer_payouts_status_idx" ON "deliverer_payouts"("status");

-- CreateIndex
CREATE INDEX "deliverer_payouts_weekStart_weekEnd_idx" ON "deliverer_payouts"("weekStart", "weekEnd");

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_parseObjectId_key" ON "subscriptions"("parseObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_subscriptionId_key" ON "subscriptions"("subscriptionId");

-- CreateIndex
CREATE INDEX "subscriptions_restaurantId_idx" ON "subscriptions"("restaurantId");

-- CreateIndex
CREATE INDEX "subscriptions_status_idx" ON "subscriptions"("status");

-- AddForeignKey
ALTER TABLE "auth_user_roles" ADD CONSTRAINT "auth_user_roles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "auth_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_user_roles" ADD CONSTRAINT "auth_user_roles_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "auth_roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_role_links" ADD CONSTRAINT "auth_role_links_parentRoleId_fkey" FOREIGN KEY ("parentRoleId") REFERENCES "auth_roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_role_links" ADD CONSTRAINT "auth_role_links_childRoleId_fkey" FOREIGN KEY ("childRoleId") REFERENCES "auth_roles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

