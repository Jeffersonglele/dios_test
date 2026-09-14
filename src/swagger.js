const swaggerUi = require('swagger-ui-express');
const { buildSwaggerSpec } = require('./services/swagger.service');

function setupSwagger(app) {
  const spec = buildSwaggerSpec();
  app.get('/api-docs.json', (req, res) => res.status(200).json(spec));
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(spec, {
    customSiteTitle: 'Dios Delices API – Swagger',
    swaggerOptions: { persistAuthorization: true },
  }));
}

module.exports = { setupSwagger };
