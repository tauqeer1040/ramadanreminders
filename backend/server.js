const { initDB } = require('./lib/schema');
const { startPolling } = require('./lib/ai-engine');
const { isWorker } = require('./lib/runtime');
const app = require('./app');

const PORT = process.env.PORT || 3007;

function createServer() {
  return initDB()
    .then(() => {
      const server = app.listen(PORT, () => console.log(`[App] Turso Backend running on port ${PORT}`));
      startPolling();
      return server;
    })
    .catch((error) => {
      console.error('[App BOOT ERROR]', error);
      if (isWorker()) throw error;
      process.exit(1);
    });
}

module.exports = { createServer };
