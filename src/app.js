require('dotenv').config({ quiet: true });

const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const apiRoutes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlware/error.middleware');
const { getHealth } = require('./services/health.service');
const { uploadDirectory } = require('./services/local-storage.service');
const { setupSwagger } = require('./swagger');
const { configuredOrigins, trustProxy } = require('./config/env');

const app = express();
const allowedOrigins = configuredOrigins();

app.disable('x-powered-by');
app.set('trust proxy', trustProxy());
app.use(helmet());
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    const error = new Error('Origine non autorisée par CORS.');
    error.statusCode = 403;
    return callback(error);
  },
  credentials: true,
}));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
// Nyole inscrit exactement le request body. Garder cette route avant le express.json.
app.use('/api/v1/payments/nyole/webhook', express.raw({
  type: 'application/json',
  limit: process.env.JSON_BODY_LIMIT || '1mb',
}));
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '1mb' }));
app.use(express.urlencoded({ extended: false, limit: process.env.JSON_BODY_LIMIT || '1mb' }));
app.use('/uploads', express.static(uploadDirectory(), { fallthrough: false, maxAge: '7d' }));

// Configuration spécifique pour le dossier des cartes PMTiles
app.use('/maps', cors(), express.static(path.join(__dirname, 'public/maps'), {
  acceptRanges: true, // TRÈS IMPORTANT : Permet à Flutter de ne télécharger que les morceaux (tuiles) dont il a besoin
  setHeaders: (res, path) => {
    res.set('Access-Control-Allow-Origin', '*');
  }
}));

app.get('/health', async (req, res) => {
  const health = await getHealth();
  return res.status(health.status === 'ok' ? 200 : 503).json({ data: health });
});

setupSwagger(app);
app.use('/api/v1', apiRoutes);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
