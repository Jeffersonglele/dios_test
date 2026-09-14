const { address } = require('../controllers');
const { authenticate } = require('../middlware/auth.middleware');
const { createResourceRouter } = require('./resource.routes');

module.exports = createResourceRouter(address, { readMiddlewares: [authenticate] });
