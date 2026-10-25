// Copie le thème commun (shared/theme.css) dans la NUI de la ressource FiveM.
// Usage : node tools/sync-theme.mjs          (copie)
//         node tools/sync-theme.mjs --check  (échoue si les deux fichiers diffèrent)
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const src = resolve(root, 'shared/theme.css');
const dst = resolve(root, 'fivem/server_shop/html/theme.css');
const a = readFileSync(src, 'utf8');
if (process.argv.includes('--check')) {
  let b = '';
  try { b = readFileSync(dst, 'utf8'); } catch { /* absent */ }
  if (a !== b) { console.error('Le thème de la NUI n\'est pas à jour : lancez node tools/sync-theme.mjs'); process.exit(1); }
  console.log('Thème NUI à jour.');
} else {
  writeFileSync(dst, a);
  console.log('Thème copié vers', dst);
}
