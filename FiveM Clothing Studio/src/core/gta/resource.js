// Ressources RSC7 de GTA V (PC) : décompression complète, accès aux deux segments
// (« système » à l'adresse virtuelle 0x50000000, « graphique » à 0x60000000) et
// recompression à l'identique après modification EN PLACE (taille inchangée).
//
// Taille des segments déduite des drapeaux de l'en-tête (même calcul que CodeWalker).
// ⚠ Expérimental : vérifié sur des fichiers synthétiques, pas encore sur des fichiers réels du jeu.
import zlib from 'node:zlib';

export class ResourceError extends Error {
  constructor(msg) { super(msg); this.name = 'ResourceError'; this.code = 'E_RESOURCE'; }
}

/** Taille d'un segment à partir de ses drapeaux. */
export function sizeFromFlags(flags) {
  const f = flags >>> 0;
  const s0 = ((f >>> 27) & 0x1) << 0;
  const s1 = ((f >>> 26) & 0x1) << 1;
  const s2 = ((f >>> 25) & 0x1) << 2;
  const s3 = ((f >>> 24) & 0x1) << 3;
  const s4 = ((f >>> 17) & 0x7f) << 4;
  const s5 = ((f >>> 11) & 0x3f) << 5;
  const s6 = ((f >>> 7) & 0xf) << 6;
  const s7 = ((f >>> 5) & 0x3) << 7;
  const s8 = ((f >>> 4) & 0x1) << 8;
  const base = 0x200 << (f & 0xf);
  return base * (s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8);
}

/** Ouvre une ressource : renvoie un lecteur d'adresses virtuelles sur les données décompressées. */
export function openResource(buf, { maxInflate = 512 * 1024 * 1024 } = {}) {
  if (buf.length < 16 || buf.toString('latin1', 0, 4) !== 'RSC7') throw new ResourceError('Signature RSC7 absente.');
  const version = buf.readUInt32LE(4), systemFlags = buf.readUInt32LE(8), graphicsFlags = buf.readUInt32LE(12);
  let data;
  try { data = zlib.inflateRawSync(buf.subarray(16), { maxOutputLength: maxInflate }); }
  catch (e) { throw new ResourceError(`Décompression impossible (${e.code || e.message}).`); }
  const sysSize = sizeFromFlags(systemFlags), gfxSize = sizeFromFlags(graphicsFlags);
  if (sysSize <= 0 || sysSize + gfxSize > data.length) {
    throw new ResourceError(`Taille des segments incohérente (attendu ${sysSize + gfxSize} octets, ${data.length} décompressés).`);
  }
  const r = {
    version, systemFlags, graphicsFlags, sysSize, gfxSize, data,
    /** Adresse virtuelle → position dans `data` (null si invalide). */
    resolve(ptr) {
      const p = typeof ptr === 'bigint' ? ptr : BigInt(ptr);
      const seg = Number((p >> 28n) & 0xfn), off = Number(p & 0x0fffffffn);
      if (seg === 5 && off < sysSize) return off;
      if (seg === 6 && off < gfxSize) return sysSize + off;
      return null;
    },
    u8: (o) => data[o], u16: (o) => data.readUInt16LE(o), u32: (o) => data.readUInt32LE(o), u64: (o) => data.readBigUInt64LE(o),
    /** Chaîne ASCII terminée par 0. */
    cstring(o, max = 256) {
      let e = o;
      while (e < data.length && data[e] !== 0 && e - o < max) e++;
      return data.toString('latin1', o, e);
    },
  };
  return r;
}

/** Recompresse une ressource (en-tête d'origine conservé : la taille des segments n'a pas changé). */
export function packResource(original, data) {
  const head = Buffer.from(original.subarray(0, 16));
  return Buffer.concat([head, zlib.deflateRawSync(data, { level: 9 })]);
}
