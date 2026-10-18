// TGA (Truevision) : lecture des types 2, 3, 10, 11 (24 / 32 / 8 bits gris) et écriture 32 bits.
// Module PUR. Les TGA à palette (types 1 et 9) sont refusés avec un message clair.
import { RGBAImage, ImageError } from './rgba.js';

export function readTgaHeader(u8) {
  if (u8.length < 18) throw new ImageError('Fichier TGA trop court.');
  const idLen = u8[0], cmapType = u8[1], type = u8[2];
  const width = u8[12] | (u8[13] << 8), height = u8[14] | (u8[15] << 8);
  const bpp = u8[16], desc = u8[17];
  const plausible = [1, 2, 3, 9, 10, 11].includes(type) && width > 0 && height > 0 && [8, 15, 16, 24, 32].includes(bpp) && cmapType <= 1;
  if (!plausible) throw new ImageError('En-tête TGA invalide.');
  return { idLen, cmapType, type, width, height, bpp, topLeft: (desc & 0x20) !== 0, rightToLeft: (desc & 0x10) !== 0,
    cmapLen: u8[5] | (u8[6] << 8), cmapBits: u8[7], hasAlpha: bpp === 32 && (desc & 0x0f) > 0 };
}

export function decodeTga(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const h = readTgaHeader(u8);
  if (h.type === 1 || h.type === 9) throw new ImageError('Les TGA à palette ne sont pas pris en charge : enregistrez-le en 24 ou 32 bits.');
  const gray = h.type === 3 || h.type === 11;
  if (gray ? h.bpp !== 8 : (h.bpp !== 24 && h.bpp !== 32)) throw new ImageError(`Profondeur TGA non prise en charge : ${h.bpp} bits.`);
  const bpp = h.bpp / 8;
  let o = 18 + h.idLen + (h.cmapType ? h.cmapLen * Math.ceil(h.cmapBits / 8) : 0);
  const n = h.width * h.height;
  const raw = new Uint8Array(n * bpp);
  if (h.type === 2 || h.type === 3) {
    if (o + raw.length > u8.length) throw new ImageError('Données TGA tronquées.');
    raw.set(u8.subarray(o, o + raw.length));
  } else {
    let p = 0;
    while (p < raw.length) {
      if (o >= u8.length) throw new ImageError('Données TGA (RLE) tronquées.');
      const c = u8[o++], count = (c & 0x7f) + 1;
      if (c & 0x80) {
        if (o + bpp > u8.length) throw new ImageError('Données TGA (RLE) tronquées.');
        for (let k = 0; k < count && p < raw.length; k++) { raw.set(u8.subarray(o, o + bpp), p); p += bpp; }
        o += bpp;
      } else {
        const len = Math.min(count * bpp, raw.length - p);
        if (o + len > u8.length) throw new ImageError('Données TGA (RLE) tronquées.');
        raw.set(u8.subarray(o, o + len), p); p += len; o += count * bpp;
      }
    }
  }
  const img = new RGBAImage(h.width, h.height);
  const d = img.data;
  for (let y = 0; y < h.height; y++) {
    const sy = h.topLeft ? y : h.height - 1 - y;
    for (let x = 0; x < h.width; x++) {
      const sx = h.rightToLeft ? h.width - 1 - x : x;
      const s = (sy * h.width + sx) * bpp, t = (y * h.width + x) * 4;
      if (gray) { d[t] = d[t + 1] = d[t + 2] = raw[s]; d[t + 3] = 255; }
      else { d[t] = raw[s + 2]; d[t + 1] = raw[s + 1]; d[t + 2] = raw[s]; d[t + 3] = bpp === 4 && h.hasAlpha ? raw[s + 3] : 255; }
    }
  }
  return { image: img, header: h };
}

/** TGA 32 bits non compressé, origine en haut à gauche. */
export function encodeTga(img) {
  const out = new Uint8Array(18 + img.width * img.height * 4);
  out[2] = 2; out[12] = img.width & 255; out[13] = img.width >> 8; out[14] = img.height & 255; out[15] = img.height >> 8;
  out[16] = 32; out[17] = 0x28;
  const d = img.data;
  for (let i = 0, o = 18; i < d.length; i += 4, o += 4) { out[o] = d[i + 2]; out[o + 1] = d[i + 1]; out[o + 2] = d[i]; out[o + 3] = d[i + 3]; }
  return out;
}
