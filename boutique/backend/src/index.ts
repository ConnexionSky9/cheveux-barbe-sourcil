// Démarrage : configuration, base de données, tâches périodiques, serveur HTTP.
import { loadConfig } from './config.js';
import { createPool } from './db.js';
import { createApp } from './http/app.js';
import { sweepExpired } from './services/deliveries.js';
import { purgeExpiredSessions } from './services/sessions.js';
import { HttpTebexClient } from './services/tebex.js';

const cfg = loadConfig();
const pool = createPool(cfg.DATABASE_URL);
await pool.query('SELECT 1');   // échoue tout de suite si la base est injoignable
const tebex = new HttpTebexClient(cfg.TEBEX_PUBLIC_TOKEN, cfg.TEBEX_PRIVATE_KEY);
const app = createApp({ pool, cfg, tebex });

// Toutes les minutes : fin des produits à durée ; toutes les heures : sessions expirées
const every = (ms: number, fn: () => Promise<unknown>, name: string) =>
  setInterval(() => { fn().catch((e: unknown) => console.error(`[${name}]`, e instanceof Error ? e.message : e)); }, ms).unref();
every(60_000, () => sweepExpired(pool), 'expiration');
every(3_600_000, () => purgeExpiredSessions(pool), 'sessions');

const server = app.listen(cfg.PORT, () => console.log(`Boutique ${cfg.SERVER_NAME} : http://localhost:${cfg.PORT} (public : ${cfg.PUBLIC_URL})`));
const stop = () => { server.close(() => { pool.end().finally(() => process.exit(0)); }); };
process.on('SIGINT', stop);
process.on('SIGTERM', stop);
