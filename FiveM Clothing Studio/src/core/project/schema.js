// Format de projet FiveM Clothing Studio : versionné et migrable.
// Un projet est un DOSSIER « <nom>.fcsproj » contenant project.json et les fichiers de travail.
// Il n'est jamais confondu avec la ressource FiveM exportée.
import crypto from 'node:crypto';

export const PROJECT_FORMAT = 'fivem-clothing-studio-project';
export const PROJECT_VERSION = 2;
export const PROJECT_EXT = '.fcsproj';

export const PEDS = {
  mp_m_freemode_01: { label: 'Homme (mp_m_freemode_01)', short: 'Homme' },
  mp_f_freemode_01: { label: 'Femme (mp_f_freemode_01)', short: 'Femme' },
};

// Catégories d'ORGANISATION seulement : elles ne déterminent jamais le slot GTA V.
export const DEFAULT_CATEGORIES = ['T-shirts', 'Hauts', 'Vestes', 'Pantalons', 'Chaussures', 'Accessoires',
  'Chapeaux', 'Masques', 'Gants', 'Sacs', 'Autres'];

export const newId = () => crypto.randomUUID();

export function emptyProject(name, { peds = ['mp_m_freemode_01'], description = '', appVersion = '0.0.0' } = {}) {
  const now = new Date().toISOString();
  return {
    format: PROJECT_FORMAT,
    formatVersion: PROJECT_VERSION,
    appVersion,
    id: newId(),
    name: String(name),
    description,
    createdAt: now,
    updatedAt: now,
    targetPeds: peds.filter((p) => PEDS[p]),
    categories: [...DEFAULT_CATEGORIES],
    assets: [],        // fichiers importés (copies, l'original n'est jamais modifié)
    textureDocs: [],   // textures de travail en calques
    garments: [],      // vêtements et variantes
    exportSettings: { packName: String(name), resourceName: '', mode: 'replace', destination: '', collections: {} },
    referenceModels: {}, // personnage de référence par modèle freemode (fichier fourni par l'utilisateur)
    reports: [],       // rapports de validation / export (chemins relatifs)
    history: [],
  };
}

// ---------------------------------------------------------------------------
// Migrations. v1 = format des préversions 0.0.x :
//   { version: 1, title, gender: 'male'|'female', items: [{ name, type, files: [{ path, role }] }] }
// ---------------------------------------------------------------------------
const MIGRATIONS = {
  1: (old) => {
    const ped = old.gender === 'female' ? 'mp_f_freemode_01' : 'mp_m_freemode_01';
    const p = emptyProject(old.title || 'Projet importé', { peds: [ped] });
    if (old.createdAt) p.createdAt = old.createdAt;
    for (const it of old.items || []) {
      p.garments.push({
        id: newId(), name: it.name || 'Vêtement', description: '', category: it.type || 'Autres', ped,
        kind: 'component', slot: null, drawableIndex: null, modelAssetId: null, yddAssetId: null,
        materials: [], variants: [], notes: (it.files || []).map((f) => `Fichier v1 non rattaché : ${f.path}`).join('\n'),
      });
    }
    p.history.push({ t: new Date().toISOString(), action: 'Projet migré depuis le format v1' });
    return p;
  },
};

/** Valide la structure minimale et migre vers PROJECT_VERSION. Lève une erreur claire sinon. */
export function migrateProject(raw) {
  if (!raw || typeof raw !== 'object') throw new ProjectError('Fichier de projet illisible.');
  let p = raw;
  let v = p.format === PROJECT_FORMAT ? p.formatVersion : p.version;
  if (typeof v !== 'number') throw new ProjectError('Ce fichier n\'est pas un projet FiveM Clothing Studio.');
  if (v > PROJECT_VERSION) throw new ProjectError(`Projet créé par une version plus récente (format ${v}). Mettez l'application à jour.`);
  const migrated = v < PROJECT_VERSION;
  while (v < PROJECT_VERSION) {
    const m = MIGRATIONS[v];
    if (!m) throw new ProjectError(`Migration du format ${v} impossible.`);
    p = m(p);
    v = p.formatVersion;
  }
  // Champs ajoutés au fil des versions mineures : valeurs par défaut
  const d = emptyProject(p.name);
  for (const k of Object.keys(d)) if (p[k] === undefined) p[k] = d[k];
  return { project: p, migrated };
}

export function addHistory(p, action) {
  p.history.push({ t: new Date().toISOString(), action });
  if (p.history.length > 300) p.history.splice(0, p.history.length - 300);
}

export class ProjectError extends Error {
  constructor(msg) { super(msg); this.name = 'ProjectError'; this.code = 'E_PROJECT'; }
}
