// Conventions de nommage des vêtements des personnages freemode (GTA V / FiveM).
// Module PUR. Les identifiants de slot ne sont JAMAIS déduits d'une catégorie
// d'organisation : l'utilisateur les choisit, l'application les valide.

export const PED_MODELS = ['mp_m_freemode_01', 'mp_f_freemode_01'];

// Composants (SetPedComponentVariation) : identifiant numérique et nom de fichier du slot
export const COMPONENTS = [
  { id: 0, key: 'head', label: 'Tête (0)' },
  { id: 1, key: 'berd', label: 'Masques (1)' },
  { id: 2, key: 'hair', label: 'Cheveux (2)' },
  { id: 3, key: 'uppr', label: 'Bras / torse (3)' },
  { id: 4, key: 'lowr', label: 'Jambes / pantalons (4)' },
  { id: 5, key: 'hand', label: 'Sacs / parachutes (5)' },
  { id: 6, key: 'feet', label: 'Chaussures (6)' },
  { id: 7, key: 'teef', label: 'Accessoires de cou (7)' },
  { id: 8, key: 'accs', label: 'Sous-hauts (8)' },
  { id: 9, key: 'task', label: 'Gilets / armures (9)' },
  { id: 10, key: 'decl', label: 'Décals / badges (10)' },
  { id: 11, key: 'jbib', label: 'Hauts (11)' },
];

// Accessoires (SetPedPropIndex)
export const PROPS = [
  { id: 0, key: 'p_head', label: 'Chapeaux / casques (0)' },
  { id: 1, key: 'p_eyes', label: 'Lunettes (1)' },
  { id: 2, key: 'p_ears', label: 'Oreilles (2)' },
  { id: 6, key: 'p_lwrist', label: 'Montres (6)' },
  { id: 7, key: 'p_rwrist', label: 'Bracelets (7)' },
];

/** Préfixe de remplacement d'un vêtement du jeu (dossier du personnage, « _p » pour les accessoires). */
export const replacePrefix = (ped, kind) => (kind === 'prop' ? `${ped}_p` : ped);

export const slotInfo = (kind, key) => (kind === 'prop' ? PROPS : COMPONENTS).find((s) => s.key === key) || null;

const pad3 = (n) => String(n).padStart(3, '0');
export const VARIANT_LETTERS = 'abcdefghijklmnopqrstuvwxyz'.split('');

/**
 * Noms de fichiers attendus pour un vêtement.
 *  prefix : « mp_m_freemode_01 » (remplacement d'un vêtement du jeu)
 *           ou « mp_m_freemode_01_<collection> » (vêtement additionnel, nom du .ymt sans extension).
 * Composant : <prefix>^jbib_005_u.ydd   et  <prefix>^jbib_diff_005_a_uni.ytd
 * Accessoire : <prefix>^p_head_002.ydd  et  <prefix>^p_head_diff_002_a.ytd
 *   (pour les accessoires du jeu, le préfixe est le dossier des accessoires : « mp_m_freemode_01_p »)
 * (Seule la variante « universelle » _u / _uni est prise en charge dans cette version.)
 */
export function garmentFileNames({ prefix, kind, slot, index }) {
  if (!slotInfo(kind, slot)) throw new NamingError(`Slot inconnu : ${slot}`);
  if (!Number.isInteger(index) || index < 0 || index > 999) throw new NamingError('Le numéro de modèle doit être entre 0 et 999.');
  const base = `${prefix}^${slot}`;
  if (kind === 'prop') {
    return { ydd: `${base}_${pad3(index)}.ydd`, ytd: (letter) => `${base}_diff_${pad3(index)}_${letter}.ytd`,
      textureName: (letter) => `${slot}_diff_${pad3(index)}_${letter}` };
  }
  return { ydd: `${base}_${pad3(index)}_u.ydd`, ytd: (letter) => `${base}_diff_${pad3(index)}_${letter}_uni.ytd`,
    textureName: (letter) => `${slot}_diff_${pad3(index)}_${letter}_uni` };
}

/**
 * Analyse un nom de fichier de vêtement freemode, avec préfixe (« mp_m_freemode_01^jbib_000_u.ydd »,
 * forme utilisée par FiveM) ou sans (« jbib_000_u.ydd », forme des fichiers extraits du jeu,
 * le préfixe étant alors le nom du dossier). prefix / ped valent null sans préfixe.
 */
export function parseGarmentFileName(name) {
  const m = /^(?:(mp_[mf]_freemode_01(?:_[a-z0-9_]+)?)\^)?(p_[a-z]+|[a-z]{4})(_diff)?_(\d{3})(?:_([a-z]))?(?:_(u|r|uni|whi|bla|chi|lat|ara|bal|pak|grn))?\.(ydd|ytd)$/i.exec(name);
  if (!m) return null;
  const [, prefix, slot, diff, idx, letter, suffix, ext] = m;
  const kind = slot.startsWith('p_') ? 'prop' : 'component';
  if (!slotInfo(kind, slot.toLowerCase())) return null;
  if (ext.toLowerCase() === 'ytd' && !diff) return null;   // .ytd sans « _diff » : pas une texture de variante
  return { prefix: prefix ? prefix.toLowerCase() : null, ped: prefix ? prefix.slice(0, 16).toLowerCase() : null, kind, slot: slot.toLowerCase(), index: Number(idx),
    letter: letter?.toLowerCase() ?? null, suffix: suffix?.toLowerCase() ?? null, isTexture: Boolean(diff) && ext.toLowerCase() === 'ytd', ext: ext.toLowerCase() };
}

/** Dossier de vêtements du jeu : « mp_m_freemode_01 », « mp_f_freemode_01_p », « mp_m_freemode_01_mp_m_business_01 »… */
export function parsePedFolder(name) {
  const m = /^(mp_[mf]_freemode_01)(_p)?(?:_([a-z0-9_]+))?$/i.exec(name);
  if (!m) return null;
  return { prefix: name.toLowerCase(), ped: m[1].toLowerCase(), props: Boolean(m[2]), collection: m[3] ? m[3].toLowerCase() : null };
}

/** Nom de collection additionnelle : minuscules, chiffres, « _ ». */
export const isValidCollection = (c) => /^[a-z0-9_]{2,40}$/.test(String(c));

export class NamingError extends Error {
  constructor(msg) { super(msg); this.name = 'NamingError'; this.code = 'E_NAMING'; }
}
