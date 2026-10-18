// Lecture / écriture des images sur disque (processus principal uniquement).
import fs from 'node:fs';
import { PNG } from 'pngjs';
import jpeg from 'jpeg-js';
import { RGBAImage, ImageError } from './rgba.js';
import { decodeDds, encodeDds, readDdsHeader } from './dds.js';
import { decodeTga, encodeTga } from './tga.js';
import { sniff } from '../detect.js';

export const IMAGE_READ_FORMATS = ['png', 'jpeg', 'tga', 'dds'];
export const IMAGE_WRITE_FORMATS = ['png', 'jpeg', 'tga', 'dds'];

/** Décode un tampon dont le format RÉEL est détecté par signature (pas par extension). */
export function decodeImage(buf, extHint = '') {
  const kind = sniff(buf, extHint).format;
  try {
    switch (kind) {
      case 'png': {
        const p = PNG.sync.read(Buffer.from(buf));
        return { image: new RGBAImage(p.width, p.height, p.data), format: 'png', info: { bitDepth: p.depth, colorType: p.colorType, hasAlphaChannel: p.alpha } };
      }
      case 'jpeg': {
        const j = jpeg.decode(buf, { useTArray: true, formatAsRGBA: true, maxMemoryUsageInMB: 1024, maxResolutionInMP: 70 });
        return { image: new RGBAImage(j.width, j.height, j.data), format: 'jpeg', info: { bitDepth: 8, hasAlphaChannel: false } };
      }
      case 'tga': {
        const t = decodeTga(buf);
        return { image: t.image, format: 'tga', info: { bitDepth: t.header.bpp, hasAlphaChannel: t.header.hasAlpha, rle: t.header.type >= 9 } };
      }
      case 'dds': {
        const d = decodeDds(buf);
        return { image: d.image, format: 'dds', info: { ddsFormat: d.header.format, mipCount: d.header.mipCount, hasAlphaChannel: d.header.hasAlpha } };
      }
      default: throw new ImageError('Ce fichier n\'est pas une image prise en charge (PNG, JPEG, TGA, DDS).');
    }
  } catch (e) {
    if (e instanceof ImageError) throw e;
    throw new ImageError(`Image illisible ou corrompue (${kind.toUpperCase()}) : ${e.message}`);
  }
}

export function readImageFile(file) {
  return decodeImage(fs.readFileSync(file), file.split('.').pop());
}

/** Infos sans décodage complet quand c'est possible (DDS) — utile pour l'écran d'import. */
export function probeImage(buf, extHint = '') {
  const s = sniff(buf, extHint);
  if (s.format === 'dds') { const h = readDdsHeader(buf); return { format: 'dds', width: h.width, height: h.height, ddsFormat: h.format, mipCount: h.mipCount, hasAlphaChannel: h.hasAlpha }; }
  const d = decodeImage(buf, extHint);
  return { format: d.format, width: d.image.width, height: d.image.height, ...d.info, usesAlpha: d.image.hasAlpha() };
}

/**
 * Encode une image. options : { format: 'png'|'jpeg'|'tga'|'dds', quality (jpeg), dds: { format, mipmaps } }
 * Renvoie { buffer, lossy, warnings }.
 */
export function encodeImage(img, { format = 'png', quality = 92, dds = {} } = {}) {
  const warnings = [];
  switch (format) {
    case 'png': {
      const p = new PNG({ width: img.width, height: img.height });
      p.data = Buffer.from(img.data.buffer, img.data.byteOffset, img.data.byteLength);
      return { buffer: PNG.sync.write(p), lossy: false, warnings };
    }
    case 'jpeg': {
      if (img.hasAlpha()) warnings.push('Le JPEG ne conserve pas la transparence : elle sera perdue.');
      warnings.push('Le JPEG est un format avec perte de qualité.');
      const raw = jpeg.encode({ data: Buffer.from(img.data), width: img.width, height: img.height }, Math.max(1, Math.min(100, quality)));
      return { buffer: raw.data, lossy: true, warnings };
    }
    case 'tga': return { buffer: Buffer.from(encodeTga(img)), lossy: false, warnings };
    case 'dds': {
      const fmt = dds.format || (img.hasAlpha() ? 'dxt5' : 'dxt1');
      if (fmt === 'dxt1' && img.hasAlpha()) warnings.push('DXT1 ne garde pas la transparence progressive : utilisez DXT5.');
      if (fmt !== 'bgra8') warnings.push(`${fmt.toUpperCase()} est un format compressé avec perte (standard pour les textures du jeu).`);
      return { buffer: Buffer.from(encodeDds(img, { format: fmt, mipmaps: dds.mipmaps !== false })), lossy: fmt !== 'bgra8', warnings };
    }
    default: throw new ImageError(`Format d'export inconnu : ${format}`);
  }
}
