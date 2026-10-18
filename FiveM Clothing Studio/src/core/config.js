// Configuration centralisée : app.config.json (valeurs par défaut, livré avec l'application)
// + copie utilisateur modifiable (dossier de données de l'utilisateur).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const DEFAULT_CONFIG_PATH = path.resolve(HERE, '../../app.config.json');

function deepMerge(base, over) {
  if (Array.isArray(base) || typeof base !== 'object' || base === null) return over === undefined ? base : over;
  const out = { ...base };
  for (const [k, v] of Object.entries(over || {})) {
    out[k] = (typeof v === 'object' && v !== null && !Array.isArray(v) && typeof base[k] === 'object') ? deepMerge(base[k], v) : v;
  }
  return out;
}

export function loadDefaults() {
  return JSON.parse(fs.readFileSync(DEFAULT_CONFIG_PATH, 'utf8'));
}

/**
 * Charge la configuration effective. `userFile` est créé s'il n'existe pas
 * (copie des valeurs par défaut) pour que l'utilisateur puisse le modifier.
 * Un fichier utilisateur illisible n'empêche pas l'application de démarrer.
 */
export function loadConfig(userFile, logger) {
  const defaults = loadDefaults();
  if (!userFile) return defaults;
  try {
    if (!fs.existsSync(userFile)) {
      fs.mkdirSync(path.dirname(userFile), { recursive: true });
      fs.writeFileSync(userFile, JSON.stringify(defaults, null, 2), 'utf8');
      return defaults;
    }
    return deepMerge(defaults, JSON.parse(fs.readFileSync(userFile, 'utf8')));
  } catch (e) {
    logger?.error('Configuration utilisateur illisible, valeurs par défaut utilisées', e);
    return defaults;
  }
}

export function saveUserConfig(userFile, cfg) {
  const tmp = `${userFile}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2), 'utf8');
  fs.renameSync(tmp, userFile);
}
