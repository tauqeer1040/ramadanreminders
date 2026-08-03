require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');

const { verifyAuth, verifyAppVersion } = require('./middleware/auth');
const { logError } = require('./lib/error-log');

const app = express();
app.use(helmet());
app.set('trust proxy', 1);
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(s => s.trim())
  : ['http://localhost:3000', 'http://localhost:3007', 'https://meowmin.app'];
app.use(cors({
  origin: (origin, cb) => cb(null, !origin || ALLOWED_ORIGINS.includes(origin)),
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-App-Version'],
}));

app.use((req, res, next) => {
  if (req.url === '/api/v2/superwall-webhook') {
    let data = [];
    req.on('data', chunk => data.push(chunk));
    req.on('end', () => {
      req.rawBody = Buffer.concat(data).toString();
      next();
    });
  } else {
    next();
  }
});
// Final error middleware for uncaught errors / next(err) paths.
app.use((err, req, res, next) => {
  logError({
    type: 'uncaught',
    message: err.message,
    stack: err.stack,
    uid: req.uid,
    route: req.path,
    method: req.method,
    body: req.body,
  });
  if (res.headersSent) return next(err);
  res.status(500).json({ error: err.message });
});

app.use(express.json());
app.use((req, res, next) => {
  console.log(`[API] ${req.method} ${req.url}`);
  next();
});

// Auth middleware
app.use('/api/v2', (req, res, next) => {
  if (req.url === '/ayah' || req.url === '/shop/items' || req.url === '/app-version' || req.url === '/superwall-webhook' || req.url === '/internal/poll-ai') return next();
  return verifyAuth(req, res, next);
});

// App-version middleware
app.use('/api/v2', (req, res, next) => {
  const p = req.url;
  if (p === '/ayah' || p === '/shop/items' || p === '/superwall-webhook' || p === '/app-version') return next();
  if (!req.uid) return next();
  return verifyAppVersion(req, res, next);
});

// Rate limiters
const clientIp = (req) => req.headers['cf-connecting-ip'] || req.socket.remoteAddress;
const apiLimiter = rateLimit({ windowMs: 60 * 1000, max: 20, validate: { xForwardedForHeader: false } });
const aiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  keyGenerator: (req) => req.uid || clientIp(req),
  validate: { xForwardedForHeader: false },
});
const generalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  keyGenerator: (req) => clientIp(req),
  validate: { xForwardedForHeader: false },
});

app.use((req, res, next) => {
  const exempt = ['/api/v2/shop/purchase', '/api/v2/shop/items'];
  if (exempt.includes(req.path)) return next();
  return generalLimiter(req, res, next);
});

// Mount routes
require('./routes/users')(app);
require('./routes/journals')(app, apiLimiter);
require('./routes/ai')(app, aiLimiter);
require('./routes/misc')(app);
require('./routes/stars')(app);
require('./routes/shop')(app);
require('./routes/superwall')(app);
require('./routes/trial')(app);
require('./routes/subscription')(app);
require('./routes/internal')(app);

// Capture 5xx responses (routes catch their own errors and return them as
// JSON, so an error middleware alone never fires for those). Only the first
// body-serialization per response is intercepted.
app.use((req, res, next) => {
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    if (res.statusCode >= 500) {
      const message = body && typeof body === 'object' ? body.error : undefined;
      logError({
        type: 'http_5xx',
        message: message || `HTTP ${res.statusCode}`,
        uid: req.uid,
        route: req.path,
        method: req.method,
        body: req.body,
      });
    }
    return originalJson(body);
  };
  next();
});

// Final error middleware for uncaught errors / next(err) paths.
app.use((err, req, res, next) => {
  logError({
    type: 'uncaught',
    message: err.message,
    stack: err.stack,
    uid: req.uid,
    route: req.path,
    method: req.method,
    body: req.body,
  });
  if (res.headersSent) return next(err);
  res.status(500).json({ error: err.message });
});

module.exports = app;
