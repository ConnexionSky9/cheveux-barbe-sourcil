// Dictionnaires de textures GTA V (.ytd, PC, version 13).
//  - lecture de la liste des textures (nom, taille, format, mipmaps) ;
//  - décodage d'une texture (DXT1, DXT3, DXT5, A8R8G8B8, A8, L8) ;
//  - REMPLACEMENT d'une texture par une image : réencodée dans le MÊME format, la même taille
//    et le même nombre de mipmaps, écrite à la même place. La structure du fichier n'est pas
//    modifiée ; on ne crée jamais de .ytd de toutes pièces.
//
// Structures (d'après la documentation publique du format, CodeWalker) :
//   TextureDictionary (0x40) : … +0x20 liste des hachages, +0x30 liste de pointeurs de textures
//   Texture (0x90) : +0x28 nom, +0x50 largeur, +0x52 hauteur, +0x54 profondeur, +0x56 pas,
//                    +0x58 format, +0x5D niveaux, +0x70 pointeur des pixels (segment graphique)
// ⚠ Expérimental : contrôlé sur des fichiers synthétiques ; tout écart est refusé avec un message.
import { openResource, packResource, ResourceError } from './resource.js';
import { surfaceBytes, decodeSurface, encodeSurface, buildMipmaps } from '../image/dds.js';
import { resize } from '../image/ops.js';

export const D3DFMT = {
  21: 'bgra8',        // A8R8G8B8
  22: 'bgrx8',        // X8R8G8B8 (lu comme BGRA opaque)
  28: 'a8',
  50: 'l8',
  0x31545844: 'dxt1', // « DXT1 »
  0x33545844: 'dxt3',
  0x35545844: 'dxt5',
  0x31495441: 'bc4',  // ATI1
  0x32495441: 'bc5',  // ATI2
  0x20374342: 'bc7',  // « BC7 »
};
const READABLE = ['dxt1', 'dxt3', 'dxt5', 'bgra8', 'bgrx8', 'a8', 'l8'];
const WRITABLE = ['dxt1', 'dxt5', 'bgra8', 'bgrx8', 'a8', 'l8'];

const surf = (f) => (f === 'bgrx8' ? 'bgra8' : f);

function chainBytes(format, w, h, levels) {
  let n = 0;
  for (let i = 0; i < levels; i++) n += surfaceBytes(surf(format), Math.max(1, w >> i), Math.max(1, h >> i));
  return n;
}

/** Liste des textures d'un .ytd. Lève ResourceError si la structure n'est pas reconnue. */
export function readYtd(buf) {
  const r = openResource(buf);
  if (r.version !== 13) throw new ResourceError(`Version ${r.version} : ce n'est pas un dictionnaire de textures PC (version 13 attendue).`);
  const listPtr = r.u64(0x30), count = r.u16(0x38), capacity = r.u16(0x3a);
  const listOff = r.resolve(listPtr);
  if (listOff === null || count === 0 || count > 4096 || capacity < count) throw new ResourceError('Liste de textures introuvable dans ce .ytd.');
  const textures = [];
  for (let i = 0; i < count; i++) {
    const so = r.resolve(r.u64(listOff + i * 8));
    if (so === null || so + 0x90 > r.sysSize) throw new ResourceError(`Texture ${i + 1} : pointeur invalide.`);
    const nameOff = r.resolve(r.u64(so + 0x28));
    const name = nameOff === null ? '' : r.cstring(nameOff, 128);
    const width = r.u16(so + 0x50), height = r.u16(so + 0x52), depth = r.u16(so + 0x54), stride = r.u16(so + 0x56);
    const fmtCode = r.u32(so + 0x58), levels = r.u8(so + 0x5d);
    const dataOff = r.resolve(r.u64(so + 0x70));
    const format = D3DFMT[fmtCode] || `inconnu_0x${fmtCode.toString(16)}`;
    const t = { index: i, name, width, height, depth, stride, levels, format, fmtCode, structOffset: so, dataOffset: dataOff };
    const plausible = /^[\x20-\x7e]{1,128}$/.test(name) && width > 0 && height > 0 && width <= 16384 && height <= 16384 && levels >= 1 && levels <= 16 && depth === 1 && dataOff !== null && dataOff >= r.sysSize;
    if (!plausible) throw new ResourceError(`Texture ${i + 1} : structure non reconnue (nom « ${name.slice(0, 40)} », ${width}×${height}, ${levels} niveaux).`);
    t.readable = READABLE.includes(format);
    t.writable = WRITABLE.includes(format);
    if (t.readable) {
      t.dataSize = chainBytes(format, width, height, levels);
      if (dataOff + t.dataSize > r.data.length) throw new ResourceError(`Texture « ${name} » : données hors du fichier.`);
    }
    textures.push(t);
  }
  return { resource: r, textures };
}

/** Décode une texture (niveau `level`, 0 = pleine taille). */
export function decodeYtdTexture(ytd, nameOrIndex, level = 0) {
  const t = typeof nameOrIndex === 'number' ? ytd.textures[nameOrIndex] : ytd.textures.find((x) => x.name.toLowerCase() === String(nameOrIndex).toLowerCase());
  if (!t) throw new ResourceError('Texture introuvable dans ce .ytd.');
  if (!t.readable) throw new ResourceError(`Texture « ${t.name} » au format ${t.format.toUpperCase()} : lecture non prise en charge.`);
  level = Math.max(0, Math.min(t.levels - 1, level));
  let off = t.dataOffset;
  for (let i = 0; i < level; i++) off += surfaceBytes(surf(t.format), Math.max(1, t.width >> i), Math.max(1, t.height >> i));
  const img = decodeSurface(surf(t.format), ytd.resource.data, off, Math.max(1, t.width >> level), Math.max(1, t.height >> level));
  if (t.format === 'bgrx8') for (let i = 3; i < img.data.length; i += 4) img.data[i] = 255;
  return img;
}

/** Niveau le plus petit dont le côté reste ≥ `min` (vignettes rapides). */
export function thumbnailLevel(t, min = 64) {
  let l = 0;
  while (l + 1 < t.levels && Math.max(t.width >> (l + 1), t.height >> (l + 1)) >= min) l++;
  return l;
}

/**
 * Remplace des textures : { nom: RGBAImage }. L'image est redimensionnée à la taille d'origine
 * et réencodée dans le format d'origine avec ses mipmaps. Renvoie { buffer, replaced, warnings }.
 */
export function patchYtd(buf, replacements) {
  const ytd = readYtd(buf);
  const data = Buffer.from(ytd.resource.data);
  const warnings = [], replaced = [];
  for (const [name, img] of Object.entries(replacements)) {
    const t = ytd.textures.find((x) => x.name.toLowerCase() === name.toLowerCase());
    if (!t) throw new ResourceError(`Texture « ${name} » absente du .ytd.`);
    if (!t.writable) throw new ResourceError(`Texture « ${t.name} » au format ${t.format.toUpperCase()} : réécriture non prise en charge (formats acceptés : DXT1, DXT5, A8R8G8B8, A8, L8).`);
    let src = img;
    if (img.width !== t.width || img.height !== t.height) {
      src = resize(img, t.width, t.height);
      warnings.push(`« ${t.name} » redimensionnée en ${t.width} × ${t.height} (taille d'origine du jeu).`);
    }
    if (t.format === 'dxt1' && src.hasAlpha()) warnings.push(`« ${t.name} » est en DXT1 : la transparence progressive n'est pas conservée.`);
    const mips = buildMipmaps(src, t.levels);
    let off = t.dataOffset;
    for (const m of mips) {
      const bytes = encodeSurface(m, surf(t.format));
      data.set(bytes, off);
      off += bytes.length;
    }
    if (off - t.dataOffset !== t.dataSize) throw new ResourceError(`« ${t.name} » : taille des données réécrites incohérente.`);
    replaced.push(t.name);
  }
  const out = packResource(buf, data);
  // Relecture de contrôle
  const check = readYtd(out);
  if (check.textures.length !== ytd.textures.length) throw new ResourceError('Contrôle après écriture échoué.');
  return { buffer: out, replaced, warnings };
}
