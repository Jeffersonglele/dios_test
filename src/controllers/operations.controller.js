const { createCrudController } = require('./crud.controller');

const invoice = createCrudController({
  delegate: 'invoice', resource: 'Facture',
  fields: [
    'invoiceId', 'orderId', 'restaurantId', 'restaurantName', 'restaurantAddress',
    'rccm', 'restaurantPhone', 'customerName', 'invoiceDate', 'items', 'subtotal',
    'deliveryFee', 'totalCdf', 'totalUsd', 'exchangeRate', 'currency', 'pdfUrl',
  ],
});

const restaurantPayout = createCrudController({
  delegate: 'restaurantPayout', resource: 'Paiement restaurateur',
  fields: [
    'payoutId', 'restaurantId', 'restaurateurId', 'restaurantName', 'weekStart',
    'weekEnd', 'totalOrders', 'totalSubtotal', 'totalDeliveryFees', 'commissionRate',
    'totalCommission', 'netAmount', 'status', 'payoutMethod', 'mobileMoneyPhone',
    'iban', 'payoutRef', 'paidAt', 'errorMessage', 'cityId', 'commissionInvoiceUrl',
  ],
  filterFields: ['restaurantId', 'status', 'cityId'],
});

const delivererPayout = createCrudController({
  delegate: 'delivererPayout', resource: 'Paiement livreur',
  fields: [
    'payoutId', 'delivererId', 'delivererName', 'weekStart', 'weekEnd',
    'totalDeliveries', 'totalBasePay', 'totalDistancePay', 'totalTips', 'netAmount',
    'status', 'payoutMethod', 'mobileMoneyPhone', 'iban', 'payoutRef', 'paidAt',
    'errorMessage',
  ],
  filterFields: ['delivererId', 'status'],
});

const subscription = createCrudController({
  delegate: 'subscription', resource: 'Abonnement',
  fields: [
    'subscriptionId', 'restaurantId', 'restaurantName', 'plan', 'price', 'currency',
    'startDate', 'endDate', 'status', 'autoRenew', 'paymentMethod', 'paymentRef',
    'features', 'cityId',
  ],
  filterFields: ['restaurantId', 'status', 'plan', 'cityId'],
});

const auditLog = createCrudController({
  delegate: 'auditLog', resource: 'Journal d’audit',
  fields: ['action', 'details', 'userName', 'country'],
  filterFields: ['action', 'country'],
});

const userLogin = createCrudController({
  delegate: 'userLogin', resource: 'Historique de connexion',
  fields: ['userId', 'username', 'ip', 'loginAt'],
  filterFields: ['userId', 'username'],
});

module.exports = {
  auditLog,
  delivererPayout,
  invoice,
  restaurantPayout,
  subscription,
  userLogin,
};
