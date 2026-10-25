// Application Express : API + site web compilé (même origine → cookies et CSRF simples).
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import cookieParser from 'cookie-parser';
import express from 'express';
import helmet from 'helmet';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import { adminRoutes } from '../routes/admin.js';
import { gameRoutes } from '../routes/game.js';
import { publicRoutes } from '../routes/public.js';
import { webhookRoutes } from '../routes/webhook.js';
import type { TebexClient } from '../services/tebex.js';
import { errorHandler, loadSessions } from './middleware.js';

export function createApp(deps: { pool: Db; cfg: AppConfig; tebex: TebexClient; log?: (m: string) => void }) {
  const { pool, cfg, tebex } = deps;
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', cfg.TRUST_PROXY);
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
        fontSrc: ["'self'", 'https://fonts.gstatic.com'],
        scriptSrc: ["'self'"],
        connectSrc: ["'self'"],
        frameAncestors: ["'none'"],
        formAction: ["'self'"],
      },
    },
    crossOriginEmbedderPolicy: false,
  }));

  // Webhooks : corps brut indispensable à la vérification de signature → avant express.json()
  app.use('/api/webhooks', webhookRoutes(pool, cfg));

  app.use(express.json({ limit: '64kb' }));
  app.use(cookieParser());
  app.use('/api/game', gameRoutes(pool, cfg, tebex));
  app.use('/api', loadSessions(pool));
  app.use('/api/admin', adminRoutes(pool, cfg, tebex));
  app.use('/api', publicRoutes(pool, cfg, tebex));
  app.use('/api', (_req, res) => { res.status(404).json({ error: 'Route inconnue.', code: 'not_found' }); });

  // Site web compilé (web/dist) : fichiers statiques + routage côté client
  const dist = resolve(process.cwd(), cfg.WEB_DIST);
  if (existsSync(resolve(dist, 'index.html'))) {
    app.use(express.static(dist, { index: false, maxAge: '1h', setHeaders: (res, path) => { if (/\/assets\//.test(path)) res.setHeader('Cache-Control', 'public, max-age=31536000, immutable'); } }));
    app.get(/^(?!\/api\/).*/, (_req, res) => { res.setHeader('Cache-Control', 'no-cache'); res.sendFile(resolve(dist, 'index.html')); });
  }

  app.use(errorHandler(deps.log));
  return app;
}
