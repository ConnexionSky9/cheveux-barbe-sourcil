// Chemins et noms de fichiers sûrs (Windows et Linux).
// Toutes les entrées utilisateur et les noms venant de fichiers importés passent par ici.
import path from 'node:path';

const WINDOWS_RESERVED = new Set(['CON', 'PRN', 'AUX', 'NUL',
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9']);

/** Retire les accents : « Été » → « Ete ». */
export function stripAccents(s) {
  return String(s ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '');
}

/**
 * Nom de fichier affichable et sûr (accents et espaces conservés).
 * Interdit les séparateurs, les caractères réservés de Windows, « .. » et les noms réservés.
 */
export function safeFileName(name, fallback = 'sans_nom') {
  let s = String(name ?? '').replace(/[\u0000-\u001f<>:"/\\|?*]/g, '_').trim();
  s = s.replace(/[. ]+$/g, '');           // Windows refuse les noms finissant par un point ou un espace
  if (!s || s === '.' || s === '..') s = fallback;
  const base = s.split('.')[0].toUpperCase();
  if (WINDOWS_RESERVED.has(base)) s = `_${s}`;
  return s.slice(0, 120);
}

/**
 * Nom technique de ressource FiveM : minuscules, chiffres, « _ » et « - ».
 * « Mon Pack Été 2024 » → « mon_pack_ete_2024 ».
 */
export function toResourceName(name) {
  const s = stripAccents(name).toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '_').replace(/_+/g, '_').replace(/^[_-]+|[_-]+$/g, '');
  return s.slice(0, 48) || 'pack_vetements';
}

/** Vrai si le nom de ressource est accepté par l'exportateur. */
export function isValidResourceName(name) {
  return typeof name === 'string' && /^[a-z0-9][a-z0-9_-]{1,47}$/.test(name);
}

/**
 * Joint `rel` à `root` en refusant toute sortie du dossier racine
 * (« ../ », chemins absolus, lecteurs Windows, chemins UNC).
 */
export function safeJoin(root, rel) {
  const r = String(rel ?? '');
  if (!r || path.isAbsolute(r) || /^[a-zA-Z]:/.test(r) || r.startsWith('\\\\') || r.includes('\0')) {
    throw new PathError(`Chemin refusé : « ${r} »`);
  }
  const rootAbs = path.resolve(root);
  const full = path.resolve(rootAbs, r);
  if (!isInside(rootAbs, full)) throw new PathError(`Chemin hors du dossier autorisé : « ${r} »`);
  return full;
}

/** Vrai si `child` est `parent` ou se trouve dedans. */
export function isInside(parent, child) {
  const rel = path.relative(path.resolve(parent), path.resolve(child));
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/** Chemin relatif au format « / » (manifeste FiveM, fichiers de projet). */
export function toPosix(p) { return String(p).split(path.sep).join('/').replace(/\\/g, '/'); }

export class PathError extends Error {
  constructor(msg) { super(msg); this.name = 'PathError'; this.code = 'E_PATH'; }
}
