// Catalogue des vêtements du jeu, construit à partir des fichiers que VOUS avez extraits de
// votre copie de GTA V (par exemple avec CodeWalker : dossiers mp_m_freemode_01 / mp_f_freemode_01
// et leurs accessoires). L'application ne contient et ne distribue aucun fichier du jeu.
import fs from 'node:fs';
import path from 'node:path';
import { parseGarmentFileName, parsePedFolder, slotInfo } from './naming.js';

// Catégories visibles, dans l'ordre d'affichage. Les gants font partie des « bras » (uppr) dans GTA V.
export const CATALOG_CATEGORIES = [
  { id: 'jbib', label: 'Hauts', kind: 'component' },
  { id: 'accs', label: 'Sous-hauts / t-shirts', kind: 'component' },
  { id: 'uppr', label: 'Bras et gants', kind: 'component' },
  { id: 'lowr', label: 'Pantalons / jupes', kind: 'component' },
  { id: 'feet', label: 'Chaussures', kind: 'component' },
  { id: 'p_head', label: 'Chapeaux / casques', kind: 'prop' },
  { id: 'p_eyes', label: 'Lunettes', kind: 'prop' },
  { id: 'berd', label: 'Masques', kind: 'component' },
  { id: 'teef', label: 'Accessoires de cou', kind: 'component' },
  { id: 'task', label: 'Gilets / armures', kind: 'component' },
  { id: 'hand', label: 'Sacs / parachutes', kind: 'component' },
  { id: 'decl', label: 'Badges / décals', kind: 'component' },
  { id: 'p_ears', label: 'Oreilles', kind: 'prop' },
  { id: 'p_lwrist', label: 'Montres', kind: 'prop' },
  { id: 'p_rwrist', label: 'Bracelets', kind: 'prop' },
  { id: 'hair', label: 'Cheveux', kind: 'component' },
  { id: 'head', label: 'Têtes', kind: 'component' },
];

/**
 * Parcourt `root` (récursif, liens symboliques ignorés) et regroupe les .ydd / .ytd par vêtement.
 * Renvoie { root, scannedAt, items, stats } ; un item :
 *   { key, ped, prefix, collection, kind, slot, index, ydd, textures: [{ letter, suffix, file }] }
 */
export function scanCatalog(root, { onProgress, maxFiles = 400000 } = {}) {
  const byKey = new Map();
  let files = 0, ignored = 0;
  const stack = [[root, null]];
  while (stack.length) {
    const [dir, folderPed] = stack.pop();
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { continue; }
    for (const e of entries) {
      const p = path.join(dir, e.name);
      if (e.isSymbolicLink()) continue;
      if (e.isDirectory()) { stack.push([p, parsePedFolder(e.name) || folderPed]); continue; }
      if (!/\.(ydd|ytd)$/i.test(e.name)) continue;
      if (++files > maxFiles) throw new Error(`Plus de ${maxFiles} fichiers : choisissez un dossier plus précis.`);
      const g = parseGarmentFileName(e.name);
      if (!g || !slotInfo(g.kind, g.slot)) { ignored++; continue; }
      // Sans préfixe dans le nom : préfixe = dossier du personnage (forme des fichiers extraits du jeu)
      if (!g.prefix) {
        if (!folderPed) { ignored++; continue; }
        g.prefix = folderPed.prefix; g.ped = folderPed.ped;
      }
      const key = `${g.prefix}|${g.kind}|${g.slot}|${g.index}`;
      let it = byKey.get(key);
      if (!it) {
        const pf = parsePedFolder(g.prefix);
      it = { key, ped: g.ped, prefix: g.prefix, collection: pf?.collection ?? null,
          kind: g.kind, slot: g.slot, index: g.index, ydd: null, textures: [] };
        byKey.set(key, it);
      }
      const rel = path.relative(root, p);
      // Nom de diffusion FiveM : <préfixe>^<nom du fichier sans préfixe>
      const streamName = `${g.prefix}^${e.name.includes('^') ? e.name.split('^')[1] : e.name}`.toLowerCase();
      if (g.ext === 'ydd') { it.ydd = rel; it.yddStream = streamName; }
      else if (g.isTexture) it.textures.push({ letter: g.letter, suffix: g.suffix, file: rel, stream: streamName });
      if (onProgress && files % 500 === 0) onProgress(files);
    }
  }
  const items = [...byKey.values()].filter((i) => i.ydd || i.textures.length);
  for (const i of items) i.textures.sort((a, b) => (a.letter || '').localeCompare(b.letter || '') || (a.suffix || '').localeCompare(b.suffix || ''));
  items.sort((a, b) => a.ped.localeCompare(b.ped) || (a.collection || '').localeCompare(b.collection || '') || a.slot.localeCompare(b.slot) || a.index - b.index);
  const stats = { files, ignored, items: items.length };
  for (const c of CATALOG_CATEGORIES) stats[c.id] = items.filter((i) => i.slot === c.id).length;
  return { root, scannedAt: new Date().toISOString(), items, stats };
}

/** Filtre / pagination pour l'interface. */
export function queryCatalog(cat, { ped, slot, collection, q, offset = 0, limit = 60 } = {}) {
  let list = cat.items;
  if (ped) list = list.filter((i) => i.ped === ped);
  if (slot) list = list.filter((i) => i.slot === slot);
  if (collection !== undefined && collection !== null && collection !== '*') list = list.filter((i) => (i.collection || '') === collection);
  if (q) {
    const s = String(q).toLowerCase().trim();
    list = list.filter((i) => String(i.index) === s || i.key.toLowerCase().includes(s));
  }
  return { total: list.length, items: list.slice(offset, offset + limit) };
}

export function collectionsOf(cat) {
  return [...new Set(cat.items.map((i) => i.collection || ''))].sort();
}
