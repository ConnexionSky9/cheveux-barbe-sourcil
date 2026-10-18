// Fichiers ressources GTA V (« RSC7 ») : .ydd, .ytd, .ydr, .yft, .ymt…
// L'application LIT l'en-tête et VÉRIFIE l'intégrité (décompression complète du flux),
// mais ne décode PAS le contenu (modèles, textures) : cela demande un outil spécialisé
// (CodeWalker, Sollumz pour Blender). Voir docs/FORMATS.md.
import zlib from 'node:zlib';

// Versions de ressource habituelles (relevées sur les fichiers du jeu ; écart = avertissement, pas erreur)
export const EXPECTED_VERSION = { ytd: 13, ydd: 165, ydr: 165, yft: 162, ymt: 2 };

/**
 * Analyse un fichier RSC7. Renvoie { ok, version, systemFlags, graphicsFlags, compressedSize,
 * decompressedSize, issues[] }. `maxInflate` évite les « bombes » de décompression.
 */
export function inspectRsc7(buf, { ext = '', maxInflate = 512 * 1024 * 1024 } = {}) {
  const issues = [];
  if (buf.length < 16 || buf.toString('latin1', 0, 4) !== 'RSC7') {
    return { ok: false, issues: [{ level: 'error', message: 'Ce fichier n\'est pas une ressource GTA V (signature RSC7 absente).' }] };
  }
  const version = buf.readUInt32LE(4);
  const systemFlags = buf.readUInt32LE(8);
  const graphicsFlags = buf.readUInt32LE(12);
  const e = String(ext).toLowerCase();
  if (EXPECTED_VERSION[e] !== undefined && EXPECTED_VERSION[e] !== version) {
    issues.push({ level: 'warning', message: `Version de ressource ${version} inhabituelle pour un .${e} (attendu : ${EXPECTED_VERSION[e]}). Le fichier vient peut-être d'une autre plateforme ou d'un outil différent.` });
  }
  let decompressedSize = null;
  try {
    decompressedSize = zlib.inflateRawSync(buf.subarray(16), { maxOutputLength: maxInflate }).length;
  } catch (err) {
    issues.push({ level: 'error', message: `Données de la ressource illisibles ou tronquées (${err.code || err.message}).` });
  }
  return { ok: !issues.some((i) => i.level === 'error'), version, systemFlags, graphicsFlags,
    compressedSize: buf.length, decompressedSize, issues };
}
