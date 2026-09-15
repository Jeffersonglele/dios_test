require('dotenv').config();

const cors = require('cors');
const express = require('express');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const morgan = require('morgan');

const apiRoutes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlware/error.middleware');
const { getHealth } = require('./services/health.service');
const { uploadDirectory } = require('./services/local-storage.service');
const { setupSwagger } = require('./swagger');

const app = express();
const allowedOrigins = String(process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.disable('x-powered-by');
app.set('trust proxy', 1);
app.use(helmet());
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origine non autorisée par CORS.'));
  },
  credentials: true,
}));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '1mb' }));
app.use(express.urlencoded({ extended: false, limit: process.env.JSON_BODY_LIMIT || '1mb' }));
app.use('/uploads', express.static(uploadDirectory(), { fallthrough: false, maxAge: '7d' }));
app.use(rateLimit({
  windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  limit: Number(process.env.RATE_LIMIT_MAX) || 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { message: 'Trop de requêtes. Réessayez plus tard.' } },
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
