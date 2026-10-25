// Crée (ou réinitialise) un compte administrateur.
// Usage : npm run admin:create -- <identifiant> <owner|admin|support>
// Le mot de passe est demandé au clavier (jamais passé en argument : il resterait dans l'historique du terminal).
import { createInterface } from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import { loadConfig } from '../config.js';
import { createPool } from '../db.js';
import { upsertAdmin } from '../services/admins.js';

const [username, role = 'owner'] = process.argv.slice(2);
if (!username || !['owner', 'admin', 'support'].includes(role)) {
  console.error('Usage : npm run admin:create -- <identifiant> <owner|admin|support>');
  process.exit(1);
}
const rl = createInterface({ input: stdin, output: stdout });
const password = await rl.question('Mot de passe (12 caractères minimum) : ');
rl.close();
const cfg = loadConfig();
const pool = createPool(cfg.DATABASE_URL);
try {
  await upsertAdmin(pool, username, password, role as 'owner' | 'admin' | 'support');
  console.log(`Administrateur « ${username} » (${role}) enregistré.`);
} catch (err) {
  console.error(err instanceof Error ? err.message : err);
  process.exitCode = 1;
} finally {
  await pool.end();
}
