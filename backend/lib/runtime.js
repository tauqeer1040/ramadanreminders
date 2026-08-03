const path = require('path');

const isWorker = () => process.env.WORKER_RUNTIME === '1';

const assetRoot = () =>
  process.env.SHOP_ASSETS_DIR ||
  (isWorker() ? null : path.join(__dirname, '..', 'public', 'assets'));

module.exports = { isWorker, assetRoot };
