const http = require('http');
const { initDB } = require('./lib/schema');
const { startPolling } = require('./lib/ai-engine');
const { isWorker } = require('./lib/runtime');
const app = require('./app');

const PORT = process.env.PORT || 3007;

function createServer() {
  return initDB()
    .then(() => {
      // In Worker context, httpServerHandler manages the server lifecycle.
      // Calling .listen() breaks the handler — just create the server.
      const server = isWorker()
        ? http.createServer(app)
        : app.listen(PORT, () => console.log(`[App] Turso Backend running on port ${PORT}`));
      startPolling();
      return server;
    })
    .catch((error) => {
      console.error('[App BOOT ERROR]', error);
      try {
        require('./lib/error-log').logError({
          type: 'boot',
          message: error.message,
          stack: error.stack,
        });
      } catch (e) { /* DB may itself be down */ }
      if (isWorker()) throw error;
      process.exit(1);
    });
}

module.exports = { createServer };
