// « Créer à partir d'un vêtement du jeu » : copie le .ydd et les .ytd du catalogue dans le
// projet et crée le vêtement avec son emplacement et ses noms de diffusion d'origine.
import path from 'node:path';
import { importAsset } from './store.js';
import { newId, addHistory } from './schema.js';
import { safeJoin } from '../paths.js';
import { slotInfo } from '../gta/naming.js';
import { CATALOG_CATEGORIES } from '../gta/catalog.js';

const CAT_TO_PROJECT = { jbib: 'Hauts', accs: 'T-shirts', uppr: 'Gants', lowr: 'Pantalons', feet: 'Chaussures', p_head: 'Chapeaux', p_eyes: 'Accessoires',
  berd: 'Masques', hand: 'Sacs', teef: 'Accessoires', task: 'Vestes', decl: 'Autres', p_ears: 'Accessoires', p_lwrist: 'Accessoires', p_rwrist: 'Accessoires' };

export function garmentFromCatalog(dir, project, catalogRoot, item, { name } = {}) {
  const src = (rel) => safeJoin(catalogRoot, rel);
  const label = CATALOG_CATEGORIES.find((c) => c.id === item.slot)?.label || item.slot;
  const g = {
    id: newId(), name: name || `${label} ${item.index}${item.collection ? ` (${item.collection})` : ''} — modifié`,
    description: `Créé à partir du vêtement du jeu ${item.prefix}^${item.slot} n° ${item.index}.`,
    category: project.categories.includes(CAT_TO_PROJECT[item.slot]) ? CAT_TO_PROJECT[item.slot] : 'Autres',
    ped: item.ped, kind: item.kind, slot: item.slot, drawableIndex: item.index,
    basePrefix: item.prefix, streamNames: { ydd: item.yddStream || null },
    fromCatalog: { key: item.key, root: catalogRoot },
    yddAssetId: null, modelAssetId: null, materials: [], variants: [],
  };
  if (!slotInfo(g.kind, g.slot)) throw new Error('Emplacement inconnu.');
  if (item.ydd) {
    g.yddAssetId = importAsset(dir, project, src(item.ydd), { kind: 'gta', format: 'rsc7', info: { role: 'ydd', summary: 'Modèle du jeu (catalogue)', status: { readable: true, exportable: true } } }).asset.id;
  }
  for (const t of item.textures) {
    const a = importAsset(dir, project, src(t.file), { kind: 'gta', format: 'rsc7', info: { role: 'ytd', summary: `Textures du jeu, variante ${t.letter}${t.suffix ? ` (${t.suffix})` : ''}`, status: { readable: true, exportable: true } } }).asset;
    g.variants.push({ id: newId(), name: '', letter: t.letter || 'a', suffix: t.suffix && t.suffix !== 'uni' ? t.suffix : null, ytdAssetId: a.id, textureDocId: null, streamName: t.stream || path.basename(t.file) });
  }
  project.garments.push(g);
  addHistory(project, `Vêtement créé depuis le jeu : ${item.key}`);
  return g;
}
