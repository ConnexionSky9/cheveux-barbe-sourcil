import { loadConfig } from '../config.js';
import { migrate } from '../migrate.js';

const cfg = loadConfig();
migrate(cfg.DATABASE_URL)
  .then(() => process.exit(0))
  .catch((err: unknown) => { console.error('Échec de la migration :', err instanceof Error ? err.message : err); process.exit(1); });
