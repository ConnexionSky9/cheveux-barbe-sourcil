// DDS (DirectDraw Surface) : lecture des formats courants des textures de jeu et écriture
// avec mipmaps. Module PUR (travaille sur des Uint8Array).
//
// Lecture : non compressé 32 / 24 bits (masques RGBA quelconques), DXT1 (BC1), DXT3 (BC2),
//           DXT5 (BC3), en-tête DX10 avec BC1/BC2/BC3 et R8G8B8A8 / B8G8R8A8.
// Écriture : B8G8R8A8 non compressé, DXT1 (sans alpha) et DXT5 (avec alpha), mipmaps complètes.
// Non pris en charge (message explicite) : BC4, BC5, BC6H, BC7, cubemaps, volumes.
import { RGBAImage, ImageError } from './rgba.js';
import { halve } from './ops.js';

const MAGIC = 0x20534444; // « DDS »
const FOURCC = (s) => s.charCodeAt(0) | (s.charCodeAt(1) << 8) | (s.charCodeAt(2) << 16) | (s.charCodeAt(3) << 24);
const FCC_DXT1 = FOURCC('DXT1'), FCC_DXT3 = FOURCC('DXT3'), FCC_DXT5 = FOURCC('DXT5'), FCC_DX10 = FOURCC('DX10');
const DXGI = { 71: 'dxt1', 72: 'dxt1', 74: 'dxt3', 75: 'dxt3', 77: 'dxt5', 78: 'dxt5', 28: 'rgba8', 29: 'rgba8', 87: 'bgra8', 91: 'bgra8',
  80: 'bc4', 81: 'bc4', 83: 'bc5', 84: 'bc5', 95: 'bc6h', 96: 'bc6h', 98: 'bc7', 99: 'bc7' };

function fccName(v) { return String.fromCharCode(v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >>> 24) & 255); }

/** Lit l'en-tête sans décoder les pixels (informations d'import). */
export function readDdsHeader(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  if (u8.length < 128) throw new ImageError('Fichier DDS trop court.');
  const dv = new DataView(u8.buffer, u8.byteOffset, u8.byteLength);
  if (dv.getUint32(0, true) !== MAGIC || dv.getUint32(4, true) !== 124) throw new ImageError('En-tête DDS invalide.');
  const height = dv.getUint32(12, true), width = dv.getUint32(16, true);
  const mipCount = Math.max(1, dv.getUint32(28, true));
  const pfFlags = dv.getUint32(80, true), fourCC = dv.getUint32(84, true), bits = dv.getUint32(88, true);
  const masks = [dv.getUint32(92, true), dv.getUint32(96, true), dv.getUint32(100, true), dv.getUint32(104, true)];
  const caps2 = dv.getUint32(112, true);
  let format = null, dataOffset = 128;
  if (pfFlags & 0x4) {
    if (fourCC === FCC_DXT1) format = 'dxt1';
    else if (fourCC === FCC_DXT3) format = 'dxt3';
    else if (fourCC === FCC_DXT5) format = 'dxt5';
    else if (fourCC === FCC_DX10) {
      if (u8.length < 148) throw new ImageError('En-tête DX10 incomplet.');
      const dxgi = dv.getUint32(128, true);
      format = DXGI[dxgi] || `dxgi_${dxgi}`;
      dataOffset = 148;
    } else format = `fourcc_${fccName(fourCC).trim()}`;
  } else if (pfFlags & 0x40 && (bits === 32 || bits === 24)) {
    format = `rgb${bits}`;
  } else if (pfFlags & 0x20000 && bits === 8) {
    format = 'lum8';
  }
  const hasAlpha = format === 'dxt3' || format === 'dxt5' || ((pfFlags & 0x1) && masks[3] !== 0) || format === 'rgba8' || format === 'bgra8';
  return { width, height, mipCount, format, bits, masks, hasAlpha, cubemap: (caps2 & 0x200) !== 0, volume: (caps2 & 0x200000) !== 0, dataOffset };
}

export const DDS_DECODABLE = ['dxt1', 'dxt3', 'dxt5', 'rgb32', 'rgb24', 'rgba8', 'bgra8', 'lum8'];

function rgb565(c) {
  return [((c >> 11) & 31) * 255 / 31, ((c >> 5) & 63) * 255 / 63, (c & 31) * 255 / 31];
}

function decodeColorBlock(u8, o, out, ox, oy, w, h, dxt1) {
  const c0 = u8[o] | (u8[o + 1] << 8), c1 = u8[o + 2] | (u8[o + 3] << 8);
  const a = rgb565(c0), b = rgb565(c1);
  const pal = [[...a, 255], [...b, 255]];
  if (!dxt1 || c0 > c1) {
    pal.push([(2 * a[0] + b[0]) / 3, (2 * a[1] + b[1]) / 3, (2 * a[2] + b[2]) / 3, 255]);
    pal.push([(a[0] + 2 * b[0]) / 3, (a[1] + 2 * b[1]) / 3, (a[2] + 2 * b[2]) / 3, 255]);
  } else {
    pal.push([(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, 255]);
    pal.push([0, 0, 0, 0]);
  }
  const idx = u8[o + 4] | (u8[o + 5] << 8) | (u8[o + 6] << 16) | (u8[o + 7] << 24);
  for (let p = 0; p < 16; p++) {
    const x = ox + (p & 3), y = oy + (p >> 2);
    if (x >= w || y >= h) continue;
    const c = pal[(idx >>> (p * 2)) & 3], i = (y * w + x) * 4;
    out[i] = c[0]; out[i + 1] = c[1]; out[i + 2] = c[2]; out[i + 3] = c[3];
  }
}

function decodeDxt5Alpha(u8, o, out, ox, oy, w, h) {
  const a0 = u8[o], a1 = u8[o + 1];
  const pal = [a0, a1];
  if (a0 > a1) for (let k = 1; k <= 6; k++) pal.push(((7 - k) * a0 + k * a1) / 7);
  else { for (let k = 1; k <= 4; k++) pal.push(((5 - k) * a0 + k * a1) / 5); pal.push(0, 255); }
  let bits = 0n;
  for (let k = 0; k < 6; k++) bits |= BigInt(u8[o + 2 + k]) << BigInt(8 * k);
  for (let p = 0; p < 16; p++) {
    const x = ox + (p & 3), y = oy + (p >> 2);
    if (x >= w || y >= h) continue;
    out[(y * w + x) * 4 + 3] = pal[Number((bits >> BigInt(3 * p)) & 7n)];
  }
}

/** Décode le premier niveau (mipmap 0) en RGBA. */
export function decodeDds(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const hd = readDdsHeader(u8);
  if (hd.cubemap || hd.volume) throw new ImageError('Les DDS cubemap / volume ne sont pas pris en charge.');
  if (!DDS_DECODABLE.includes(hd.format)) throw new ImageError(`Format DDS non pris en charge : ${hd.format}. Convertissez la texture en DXT1, DXT5 ou RGBA.`);
  const { width: w, height: h } = hd;
  const img = new RGBAImage(w, h);
  const out = img.data;
  let o = hd.dataOffset;
  const need = (n) => { if (o + n > u8.length) throw new ImageError('Données DDS tronquées.'); };
  if (hd.format.startsWith('dxt')) {
    const bw = Math.ceil(w / 4), bh = Math.ceil(h / 4), bsz = hd.format === 'dxt1' ? 8 : 16;
    need(bw * bh * bsz);
    for (let by = 0; by < bh; by++) for (let bx = 0; bx < bw; bx++) {
      if (hd.format === 'dxt1') { decodeColorBlock(u8, o, out, bx * 4, by * 4, w, h, true); }
      else {
        decodeColorBlock(u8, o + 8, out, bx * 4, by * 4, w, h, false);
        if (hd.format === 'dxt5') decodeDxt5Alpha(u8, o, out, bx * 4, by * 4, w, h);
        else for (let p = 0; p < 16; p++) {
          const x = bx * 4 + (p & 3), y = by * 4 + (p >> 2);
          if (x < w && y < h) out[(y * w + x) * 4 + 3] = ((u8[o + (p >> 1)] >> ((p & 1) * 4)) & 15) * 17;
        }
      }
      o += bsz;
    }
  } else if (hd.format === 'rgba8' || hd.format === 'bgra8') {
    need(w * h * 4);
    for (let i = 0; i < w * h; i++, o += 4) {
      const t = i * 4;
      if (hd.format === 'rgba8') { out[t] = u8[o]; out[t + 1] = u8[o + 1]; out[t + 2] = u8[o + 2]; }
      else { out[t] = u8[o + 2]; out[t + 1] = u8[o + 1]; out[t + 2] = u8[o]; }
      out[t + 3] = u8[o + 3];
    }
  } else if (hd.format === 'lum8') {
    need(w * h);
    for (let i = 0; i < w * h; i++) { const v = u8[o++]; out.set([v, v, v, 255], i * 4); }
  } else {
    const bpp = hd.bits / 8;
    need(w * h * bpp);
    const [rm, gm, bm, am] = hd.masks;
    const ch = (v, m) => { if (!m) return null; let s = 0; while (!((m >>> s) & 1)) s++; const max = m >>> s; return ((v & m) >>> s) * 255 / max; };
    for (let i = 0; i < w * h; i++, o += bpp) {
      const v = (u8[o] | (u8[o + 1] << 8) | (u8[o + 2] << 16) | (bpp === 4 ? u8[o + 3] << 24 : 0)) >>> 0;
      const t = i * 4;
      out[t] = ch(v, rm); out[t + 1] = ch(v, gm); out[t + 2] = ch(v, bm);
      const a = ch(v, am); out[t + 3] = a === null || !(hd.masks[3]) ? 255 : a;
    }
  }
  return { image: img, header: hd };
}

// ------------------------------------------------------------------ écriture
const to565 = (r, g, b) => ((Math.round(r * 31 / 255) << 11) | (Math.round(g * 63 / 255) << 5) | Math.round(b * 31 / 255));

function blockPixels(img, bx, by) {
  const px = [];
  for (let p = 0; p < 16; p++) {
    const x = Math.min(img.width - 1, bx * 4 + (p & 3)), y = Math.min(img.height - 1, by * 4 + (p >> 2));
    const i = (y * img.width + x) * 4;
    px.push([img.data[i], img.data[i + 1], img.data[i + 2], img.data[i + 3]]);
  }
  return px;
}

/** Bloc couleur BC1 (4 couleurs) : extrêmes sur l'axe principal approximé par la boîte englobante. */
function encodeColorBlock(px, out, o) {
  let min = [255, 255, 255], max = [0, 0, 0];
  for (const p of px) for (let c = 0; c < 3; c++) { if (p[c] < min[c]) min[c] = p[c]; if (p[c] > max[c]) max[c] = p[c]; }
  // Léger retrait vers l'intérieur pour réduire l'erreur moyenne
  const inset = max.map((v, c) => (v - min[c]) / 16);
  min = min.map((v, c) => Math.min(255, v + inset[c])); max = max.map((v, c) => Math.max(0, v - inset[c]));
  let c0 = to565(...max), c1 = to565(...min);
  if (c0 < c1) [c0, c1] = [c1, c0];
  const a = rgb565(c0), b = rgb565(c1);
  const pal = [a, b, a.map((v, k) => (2 * v + b[k]) / 3), a.map((v, k) => (v + 2 * b[k]) / 3)];
  let idx = 0;
  if (c0 !== c1) {
    px.forEach((p, n) => {
      let best = 0, bd = Infinity;
      for (let k = 0; k < 4; k++) {
        const d = (p[0] - pal[k][0]) ** 2 + (p[1] - pal[k][1]) ** 2 + (p[2] - pal[k][2]) ** 2;
        if (d < bd) { bd = d; best = k; }
      }
      idx |= best << (n * 2);
    });
  }
  out[o] = c0 & 255; out[o + 1] = c0 >> 8; out[o + 2] = c1 & 255; out[o + 3] = c1 >> 8;
  out[o + 4] = idx & 255; out[o + 5] = (idx >>> 8) & 255; out[o + 6] = (idx >>> 16) & 255; out[o + 7] = (idx >>> 24) & 255;
}

function encodeAlphaBlock(px, out, o) {
  let a0 = 0, a1 = 255;
  for (const p of px) { if (p[3] > a0) a0 = p[3]; if (p[3] < a1) a1 = p[3]; }
  const pal = [a0, a1];
  if (a0 === a1) { out.fill(0, o + 2, o + 8); out[o] = a0; out[o + 1] = a1; return; }
  for (let k = 1; k <= 6; k++) pal.push(((7 - k) * a0 + k * a1) / 7);
  let bits = 0n;
  px.forEach((p, n) => {
    let best = 0, bd = Infinity;
    for (let k = 0; k < 8; k++) { const d = Math.abs(p[3] - pal[k]); if (d < bd) { bd = d; best = k; } }
    bits |= BigInt(best) << BigInt(3 * n);
  });
  out[o] = a0; out[o + 1] = a1;
  for (let k = 0; k < 6; k++) out[o + 2 + k] = Number((bits >> BigInt(8 * k)) & 255n);
}

function levelSize(w, h, format) {
  if (format === 'bgra8') return w * h * 4;
  return Math.ceil(w / 4) * Math.ceil(h / 4) * (format === 'dxt1' ? 8 : 16);
}

/** Liste des niveaux de mipmaps jusqu'à 1×1 (ou `levels` niveaux). */
export function buildMipmaps(img, levels = Infinity) {
  const out = [img];
  let cur = img;
  while (out.length < levels && (cur.width > 1 || cur.height > 1)) { cur = halve(cur); out.push(cur); }
  return out;
}

/**
 * Encode un DDS. format : 'dxt1' | 'dxt5' | 'bgra8'. mipmaps : true = chaîne complète.
 * Renvoie un Uint8Array prêt à écrire.
 */
export function encodeDds(img, { format = 'dxt5', mipmaps = true } = {}) {
  if (!['dxt1', 'dxt5', 'bgra8'].includes(format)) throw new ImageError(`Format d'écriture DDS inconnu : ${format}`);
  if (format !== 'bgra8' && (img.width % 4 || img.height % 4)) {
    throw new ImageError('Les formats compressés DXT exigent des dimensions multiples de 4.');
  }
  const levels = mipmaps ? buildMipmaps(img) : [img];
  const total = 128 + levels.reduce((s, l) => s + levelSize(l.width, l.height, format), 0);
  const out = new Uint8Array(total);
  const dv = new DataView(out.buffer);
  dv.setUint32(0, MAGIC, true);
  dv.setUint32(4, 124, true);
  let flags = 0x1 | 0x2 | 0x4 | 0x1000;
  flags |= format === 'bgra8' ? 0x8 : 0x80000;
  if (levels.length > 1) flags |= 0x20000;
  dv.setUint32(8, flags, true);
  dv.setUint32(12, img.height, true);
  dv.setUint32(16, img.width, true);
  dv.setUint32(20, format === 'bgra8' ? img.width * 4 : levelSize(img.width, img.height, format), true);
  dv.setUint32(28, levels.length, true);
  dv.setUint32(76, 32, true);
  if (format === 'bgra8') {
    dv.setUint32(80, 0x40 | 0x1, true);
    dv.setUint32(88, 32, true);
    dv.setUint32(92, 0x00ff0000, true); dv.setUint32(96, 0x0000ff00, true);
    dv.setUint32(100, 0x000000ff, true); dv.setUint32(104, 0xff000000, true);
  } else {
    dv.setUint32(80, 0x4, true);
    dv.setUint32(84, format === 'dxt1' ? FCC_DXT1 : FCC_DXT5, true);
  }
  dv.setUint32(108, 0x1000 | (levels.length > 1 ? 0x400000 | 0x8 : 0), true);
  let o = 128;
  for (const lv of levels) {
    if (format === 'bgra8') {
      const d = lv.data;
      for (let i = 0; i < d.length; i += 4, o += 4) { out[o] = d[i + 2]; out[o + 1] = d[i + 1]; out[o + 2] = d[i]; out[o + 3] = d[i + 3]; }
      continue;
    }
    const bw = Math.ceil(lv.width / 4), bh = Math.ceil(lv.height / 4);
    for (let by = 0; by < bh; by++) for (let bx = 0; bx < bw; bx++) {
      const px = blockPixels(lv, bx, by);
      if (format === 'dxt5') { encodeAlphaBlock(px, out, o); encodeColorBlock(px, out, o + 8); o += 16; }
      else { encodeColorBlock(px, out, o); o += 8; }
    }
  }
  return out;
}
