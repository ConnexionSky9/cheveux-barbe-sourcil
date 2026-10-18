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

const RSC7 = 0x37435352;
const SKIP_DIRS = new Set(['windows', 'program files', 'program files (x86)', 'programdata', '$recycle.bin', 'system volume information', 'node_modules', '.git', 'appdata']);
const PED_LABEL = { mp_m_freemode_01: 'Homme', mp_f_freemode_01: 'Femme' };

/**
 * Devine le personnage à partir d'un nom de dossier (ou de fichier) :
 * « mp_m_freemode_01 », « mp_f_freemode_01_p », « mp_m_freemode_01.rpf », « Copie de mp_f_freemode_01 (2) »,
 * ou à défaut les mots « homme / male / men » et « femme / female / women ».
 */
export function inferPed(name) {
  const n = String(name).toLowerCase();
  const m = /mp_[mf]_freemode_01[a-z0-9_]*/.exec(n);
  if (m) {
    const pf = parsePedFolder(m[0].replace(/_+$/, ''));
    if (pf) return pf;
  }
  const words = n.split(/[^a-zà-ÿ]+/).filter(Boolean);
  const has = (list) => words.some((w) => list.includes(w));
  if (has(['femme', 'femmes', 'female', 'females', 'women', 'woman', 'feminin', 'féminin', 'fille', 'filles'])) return pedOnly('mp_f_freemode_01');
  if (has(['homme', 'hommes', 'male', 'males', 'men', 'man', 'masculin', 'garcon', 'garçon'])) return pedOnly('mp_m_freemode_01');
  return null;
}
const pedOnly = (ped) => ({ prefix: ped, ped, props: false, collection: null, guessed: true });

/** Préfixe de diffusion correct pour un fichier, en tenant compte des accessoires (dossier « _p »). */
function prefixFor(pf, kind) {
  const coll = pf.collection ? `_${pf.collection}` : '';
  return kind === 'prop' ? `${pf.ped}_p${coll}` : `${pf.ped}${coll}`;
}

function magicOf(file) {
  let fd;
  try { fd = fs.openSync(file, 'r'); const b = Buffer.alloc(4); return fs.readSync(fd, b, 0, 4, 0) === 4 ? b.readUInt32LE(0) : 0; }
  catch { return 0; } finally { if (fd !== undefined) fs.closeSync(fd); }
}

/**
 * Parcourt `root` (récursif, liens symboliques ignorés) et regroupe les .ydd / .ytd par vêtement.
 * Options : defaultPed ('mp_m_freemode_01' | 'mp_f_freemode_01' | 'skip') pour les fichiers dont le
 * personnage ne peut pas être deviné.
 * Renvoie { root, scannedAt, items, stats, report } ; un item :
 *   { key, root, ped, prefix, collection, kind, slot, index, ydd, textures: [{ letter, suffix, file }] }
 * `report` décrit ce qui a été trouvé et pourquoi des fichiers ont été écartés (voir diagnoseScan).
 */
export function scanCatalog(root, { onProgress, maxFiles = 400000, maxEntries = 3000000, defaultPed = null } = {}) {
  const byKey = new Map();
  let files = 0, entries = 0;
  const report = { root, ydd: 0, ytd: 0, rpf: 0, xml: 0, images: 0, others: 0, dirs: 0,
    unknownNames: 0, orphans: 0, notRsc7: 0, otherTextures: 0,
    samples: { unknown: [], orphans: [], rpf: [], xml: [], notRsc7: [] }, gtaInstall: false, guessedFolders: [] };
  const sample = (k, v) => { if (report.samples[k].length < 6) report.samples[k].push(v); };
  const stack = [[root, inferPed(path.basename(root))]];
  while (stack.length) {
    const [dir, folderPed] = stack.pop();
    let list;
    try { list = fs.readdirSync(dir, { withFileTypes: true }); } catch { continue; }
    for (const e of list) {
      if (++entries > maxEntries) throw new Error('Ce dossier contient trop de fichiers : choisissez le dossier où vous avez extrait les vêtements, pas un disque entier.');
      const p = path.join(dir, e.name);
      const lower = e.name.toLowerCase();
      if (e.isSymbolicLink()) continue;
      if (e.isDirectory()) {
        if (SKIP_DIRS.has(lower)) continue;
        report.dirs++;
        const inferred = inferPed(e.name);
        if (inferred?.guessed && report.guessedFolders.length < 6) report.guessedFolders.push(path.relative(root, p) || e.name);
        stack.push([p, inferred || folderPed]);
        continue;
      }
      if (lower === 'gta5.exe' || lower === 'x64v.rpf' || lower === 'playgtav.exe') report.gtaInstall = true;
      if (lower.endsWith('.rpf')) { report.rpf++; sample('rpf', path.relative(root, p)); continue; }
      if (/\.(ydd|ytd|yft|ymt)\.xml$/.test(lower)) { report.xml++; sample('xml', path.relative(root, p)); continue; }
      if (/\.(dds|png|jpe?g|tga)$/.test(lower)) { report.images++; continue; }
      if (!/\.(ydd|ytd)$/.test(lower)) { report.others++; continue; }
      if (lower.endsWith('.ydd')) report.ydd++; else report.ytd++;
      if (++files > maxFiles) throw new Error(`Plus de ${maxFiles} fichiers : choisissez un dossier plus précis.`);
      if (onProgress && files % 500 === 0) onProgress(files);
      const g = parseGarmentFileName(e.name);
      if (!g || !slotInfo(g.kind, g.slot)) {
        // Textures secondaires (_n, _s…) et objets non vêtements : normal, compté à part
        const slotLike = /^(?:mp_[mf]_freemode_01[a-z0-9_]*\^)?(p_[a-z]+|[a-z]{4})_/.exec(lower);
        if (slotLike && (slotInfo('component', slotLike[1]) || slotInfo('prop', slotLike[1]))) report.otherTextures++;
        else { report.unknownNames++; sample('unknown', e.name); }
        continue;
      }
      if (magicOf(p) !== RSC7) { report.notRsc7++; sample('notRsc7', path.relative(root, p)); continue; }
      let pf = g.prefix ? parsePedFolder(g.prefix) : folderPed;
      if (!pf) {
        if (defaultPed && defaultPed !== 'skip') pf = pedOnly(defaultPed);
        else { report.orphans++; sample('orphans', path.relative(root, p)); continue; }
      }
      const prefix = g.prefix || prefixFor(pf, g.kind);
      const key = `${prefix}|${g.kind}|${g.slot}|${g.index}`;
      let it = byKey.get(key);
      if (!it) {
        it = { key, root, ped: pf.ped, prefix, collection: pf.collection ?? null,
          kind: g.kind, slot: g.slot, index: g.index, ydd: null, textures: [] };
        byKey.set(key, it);
      }
      const rel = path.relative(root, p);
      // Nom de diffusion FiveM : <préfixe>^<nom du fichier sans préfixe>
      const streamName = `${prefix}^${e.name.includes('^') ? e.name.split('^').pop() : e.name}`.toLowerCase();
      if (g.ext === 'ydd') { it.ydd = rel; it.yddStream = streamName; }
      else if (g.isTexture && !it.textures.some((t) => t.stream === streamName)) it.textures.push({ letter: g.letter, suffix: g.suffix, file: rel, stream: streamName });
    }
  }
  const items = [...byKey.values()].filter((i) => i.ydd || i.textures.length);
  for (const i of items) i.textures.sort((a, b) => (a.letter || '').localeCompare(b.letter || '') || (a.suffix || '').localeCompare(b.suffix || ''));
  sortItems(items);
  const stats = statsOf(items);
  stats.files = files;
  stats.ignored = report.unknownNames + report.orphans + report.notRsc7;
  report.items = items.length;
  return { root, roots: [root], scannedAt: new Date().toISOString(), items, stats, report };
}

function sortItems(items) {
  items.sort((a, b) => a.ped.localeCompare(b.ped) || (a.collection || '').localeCompare(b.collection || '') || a.slot.localeCompare(b.slot) || a.index - b.index);
}
function statsOf(items) {
  const stats = { items: items.length, mp_m_freemode_01: 0, mp_f_freemode_01: 0 };
  for (const i of items) stats[i.ped] = (stats[i.ped] || 0) + 1;
  for (const c of CATALOG_CATEGORIES) stats[c.id] = items.filter((i) => i.slot === c.id).length;
  return stats;
}

/** Ajoute un nouveau dossier à un catalogue existant (les vêtements déjà présents sont remplacés). */
export function mergeCatalogs(old, add) {
  if (!old) return add;
  const map = new Map(old.items.map((i) => [i.key, { ...i, root: i.root || old.root }]));
  for (const i of add.items) map.set(i.key, i);
  const items = [...map.values()];
  sortItems(items);
  const roots = [...new Set([...(old.roots || [old.root]), ...(add.roots || [add.root])])];
  return { root: roots[0], roots, scannedAt: add.scannedAt, items, stats: { ...statsOf(items), files: (old.stats?.files || 0) + (add.stats?.files || 0) }, report: add.report };
}

/**
 * Explications en français, classées par importance, à partir d'un rapport d'indexation.
 * Chaque conseil : { level: 'error' | 'warning' | 'info', title, text }.
 */
export function diagnoseScan(r) {
  const out = [];
  const total = r.ydd + r.ytd;
  if (r.gtaInstall) out.push({ level: 'error', title: 'Vous avez choisi le dossier d\'installation de GTA V',
    text: 'Les vêtements y sont enfermés dans des archives .rpf chiffrées que l\'application ne peut pas ouvrir. Il faut les sortir une fois avec CodeWalker (voir les étapes ci-dessous), puis choisir le dossier où vous les avez extraits.' });
  else if (r.rpf && !r.items) out.push({ level: 'error', title: `${r.rpf} archive(s) .rpf trouvée(s), mais pas de vêtement extrait`,
    text: `Les fichiers .rpf (${r.samples.rpf.slice(0, 3).join(', ')}) sont des archives : il faut les ouvrir dans CodeWalker et en extraire le contenu (clic droit › « Extract Raw »). L'application ne lit pas les .rpf (archives chiffrées du jeu).` });
  if (r.xml) out.push({ level: r.items ? 'warning' : 'error', title: `${r.xml} fichier(s) .xml exportés par CodeWalker`,
    text: `Ces fichiers (${r.samples.xml.slice(0, 2).join(', ')}) viennent de « Export XML ». Utilisez plutôt « Extract Raw » dans CodeWalker : il faut les vrais .ydd / .ytd.` });
  if (r.notRsc7) out.push({ level: r.items ? 'warning' : 'error', title: `${r.notRsc7} fichier(s) .ydd / .ytd extraits dans le mauvais mode`,
    text: `Ces fichiers (${r.samples.notRsc7.slice(0, 2).join(', ')}) ne sont pas au format du jeu : ils ont sans doute été extraits avec « Extract Uncompressed ». Ré-extrayez-les avec « Extract Raw ».` });
  if (r.orphans) out.push({ level: 'question', title: `${r.orphans} fichier(s) de vêtements : homme ou femme ?`,
    text: 'Ces fichiers ne sont pas dans un dossier « mp_m_freemode_01 » (homme) ou « mp_f_freemode_01 » (femme), donc l\'application ne peut pas savoir pour quel personnage ils sont. Indiquez-le ci-dessous.' });
  if (r.unknownNames && !r.items) out.push({ level: 'warning', title: `${r.unknownNames} fichier(s) .ydd / .ytd qui ne sont pas des vêtements de personnage`,
    text: `Exemples : ${r.samples.unknown.slice(0, 4).join(', ')}. Un vêtement s'appelle par exemple jbib_000_u.ydd et jbib_diff_000_a_uni.ytd. Vérifiez que vous avez extrait « mp_m_freemode_01 » / « mp_f_freemode_01 » (dans streamedpeds_mp.rpf) et pas un autre dossier.` });
  if (!total && !r.rpf && !r.xml) out.push({ level: 'error', title: 'Aucun fichier .ydd ni .ytd dans ce dossier',
    text: r.dirs || r.others || r.images ? `Le dossier contient ${r.dirs} sous-dossier(s) et ${r.others + r.images} autre(s) fichier(s), mais aucun fichier de vêtement. Choisissez le dossier où CodeWalker a extrait les fichiers.` : 'Le dossier est vide. Extrayez d\'abord les vêtements avec CodeWalker (étapes ci-dessous).' });
  if (r.items && r.guessedFolders.length) out.push({ level: 'info', title: 'Personnage deviné d\'après le nom des dossiers',
    text: `Dossiers : ${r.guessedFolders.join(', ')}.` });
  return out;
}

export const pedLabel = (ped) => PED_LABEL[ped] || ped;

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
