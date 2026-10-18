// Opérations de retouche. Module PUR : renvoie toujours une NOUVELLE image
// (l'historique annuler / rétablir garde les versions précédentes intactes).
import { RGBAImage, ImageError } from './rgba.js';

const clamp = (v) => (v < 0 ? 0 : v > 255 ? 255 : v);

function mapPixels(img, fn, mask) {
  const out = img.clone();
  const d = out.data;
  for (let i = 0, p = 0; i < d.length; i += 4, p++) {
    if (mask && !mask(p % img.width, (p / img.width) | 0)) continue;
    fn(d, i);
  }
  return out;
}

/** Luminosité : -100 … +100 (ajout linéaire). */
export function brightness(img, amount) {
  const k = (Number(amount) || 0) * 2.55;
  return mapPixels(img, (d, i) => { d[i] = clamp(d[i] + k); d[i + 1] = clamp(d[i + 1] + k); d[i + 2] = clamp(d[i + 2] + k); });
}

/** Contraste : -100 … +100 (autour du gris moyen). */
export function contrast(img, amount) {
  const c = Math.max(-100, Math.min(100, Number(amount) || 0)) * 2.55;
  const f = (259 * (c + 255)) / (255 * (259 - c));
  return mapPixels(img, (d, i) => {
    d[i] = clamp(f * (d[i] - 128) + 128); d[i + 1] = clamp(f * (d[i + 1] - 128) + 128); d[i + 2] = clamp(f * (d[i + 2] - 128) + 128);
  });
}

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  let h = 0, s = 0;
  const l = (max + min) / 2;
  if (max !== min) {
    const dd = max - min;
    s = l > 0.5 ? dd / (2 - max - min) : dd / (max + min);
    if (max === r) h = (g - b) / dd + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / dd + 2;
    else h = (r - g) / dd + 4;
    h /= 6;
  }
  return [h, s, l];
}
function hue2rgb(p, q, t) {
  if (t < 0) t += 1; if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}
function hslToRgb(h, s, l) {
  if (s === 0) return [l * 255, l * 255, l * 255];
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  return [hue2rgb(p, q, h + 1 / 3) * 255, hue2rgb(p, q, h) * 255, hue2rgb(p, q, h - 1 / 3) * 255];
}

/** Teinte (-180 … 180°), saturation (-100 … +100). */
export function hueSaturation(img, hueDeg = 0, sat = 0) {
  const dh = (Number(hueDeg) || 0) / 360;
  const ds = (Number(sat) || 0) / 100;
  return mapPixels(img, (d, i) => {
    let [h, s, l] = rgbToHsl(d[i], d[i + 1], d[i + 2]);
    h = (h + dh + 1) % 1;
    s = ds >= 0 ? s + (1 - s) * ds : s * (1 + ds);
    const [r, g, b] = hslToRgb(h, Math.max(0, Math.min(1, s)), l);
    d[i] = r; d[i + 1] = g; d[i + 2] = b;
  });
}

/** Colorer : remplace la teinte en gardant la luminosité (recolorer un vêtement). force 0 … 100. */
export function colorize(img, [r, g, b], force = 100) {
  const [th, ts] = rgbToHsl(r, g, b);
  const k = Math.max(0, Math.min(100, Number(force))) / 100;
  return mapPixels(img, (d, i) => {
    const [, , l] = rgbToHsl(d[i], d[i + 1], d[i + 2]);
    const [nr, ng, nb] = hslToRgb(th, ts, l);
    d[i] = d[i] + (nr - d[i]) * k; d[i + 1] = d[i + 1] + (ng - d[i + 1]) * k; d[i + 2] = d[i + 2] + (nb - d[i + 2]) * k;
  });
}

export function invert(img) {
  return mapPixels(img, (d, i) => { d[i] = 255 - d[i]; d[i + 1] = 255 - d[i + 1]; d[i + 2] = 255 - d[i + 2]; });
}

/** Recadrer (le rectangle est borné à l'image). */
export function crop(img, x, y, w, h) {
  x = Math.max(0, Math.floor(x)); y = Math.max(0, Math.floor(y));
  w = Math.min(img.width - x, Math.floor(w)); h = Math.min(img.height - y, Math.floor(h));
  if (w <= 0 || h <= 0) throw new ImageError('Zone de recadrage vide.');
  const out = new RGBAImage(w, h);
  for (let row = 0; row < h; row++) {
    const s = ((y + row) * img.width + x) * 4;
    out.data.set(img.data.subarray(s, s + w * 4), row * w * 4);
  }
  return out;
}

/** Effacer une zone (transparence totale) — rectangle ou ellipse. */
export function erase(img, x, y, w, h, shape = 'rect') {
  const cx = x + w / 2, cy = y + h / 2, rx = w / 2, ry = h / 2;
  const inside = shape === 'ellipse'
    ? (px, py) => ((px + 0.5 - cx) ** 2) / (rx * rx) + ((py + 0.5 - cy) ** 2) / (ry * ry) <= 1
    : (px, py) => px >= x && px < x + w && py >= y && py < y + h;
  return mapPixels(img, (d, i) => { d[i + 3] = 0; }, inside);
}

/** Rotation par quarts de tour (sans perte). */
export function rotate90(img, turns = 1) {
  turns = ((turns % 4) + 4) % 4;
  let cur = img;
  for (let t = 0; t < turns; t++) {
    const out = new RGBAImage(cur.height, cur.width);
    for (let y = 0; y < cur.height; y++) for (let x = 0; x < cur.width; x++) {
      const s = (y * cur.width + x) * 4, nx = cur.height - 1 - y, ny = x;
      out.data.set(cur.data.subarray(s, s + 4), (ny * out.width + nx) * 4);
    }
    cur = out;
  }
  return turns ? cur : img.clone();
}

export function flip(img, horizontal = true) {
  const out = new RGBAImage(img.width, img.height);
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const sx = horizontal ? img.width - 1 - x : x, sy = horizontal ? y : img.height - 1 - y;
    const s = (sy * img.width + sx) * 4;
    out.data.set(img.data.subarray(s, s + 4), (y * img.width + x) * 4);
  }
  return out;
}

/** Échantillonnage bilinéaire (alpha prémultiplié pour éviter les halos sur la transparence). */
function sample(img, fx, fy) {
  const x0 = Math.max(0, Math.min(img.width - 1, Math.floor(fx))), y0 = Math.max(0, Math.min(img.height - 1, Math.floor(fy)));
  const x1 = Math.min(img.width - 1, x0 + 1), y1 = Math.min(img.height - 1, y0 + 1);
  const tx = Math.max(0, Math.min(1, fx - x0)), ty = Math.max(0, Math.min(1, fy - y0));
  const d = img.data, out = [0, 0, 0, 0];
  const pts = [[x0, y0, (1 - tx) * (1 - ty)], [x1, y0, tx * (1 - ty)], [x0, y1, (1 - tx) * ty], [x1, y1, tx * ty]];
  for (const [px, py, w] of pts) {
    const i = (py * img.width + px) * 4, a = d[i + 3] / 255;
    out[0] += d[i] * a * w; out[1] += d[i + 1] * a * w; out[2] += d[i + 2] * a * w; out[3] += a * w;
  }
  if (out[3] > 0) { out[0] /= out[3]; out[1] /= out[3]; out[2] /= out[3]; }
  out[3] *= 255;
  return out;
}

/** Redimensionner (bilinéaire ; réduction par moyenne de boîtes pour garder la netteté). */
export function resize(img, w, h) {
  w = Math.round(w); h = Math.round(h);
  if (w < 1 || h < 1 || w > 8192 || h > 8192) throw new ImageError('Dimensions de redimensionnement invalides.');
  if (w * 2 <= img.width && h * 2 <= img.height && img.width % 2 === 0 && img.height % 2 === 0) {
    return resize(halve(img), w, h);
  }
  const out = new RGBAImage(w, h);
  const sx = img.width / w, sy = img.height / h;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = sample(img, (x + 0.5) * sx - 0.5, (y + 0.5) * sy - 0.5);
    out.data.set(p, (y * w + x) * 4);
  }
  return out;
}

/** Divise par deux (moyenne 2×2 pondérée par l'alpha) : utilisé pour les mipmaps. */
export function halve(img) {
  const w = Math.max(1, img.width >> 1), h = Math.max(1, img.height >> 1);
  const out = new RGBAImage(w, h), d = img.data;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let r = 0, g = 0, b = 0, a = 0, n = 0;
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
      const sx = Math.min(img.width - 1, x * 2 + dx), sy = Math.min(img.height - 1, y * 2 + dy);
      const i = (sy * img.width + sx) * 4, al = d[i + 3];
      r += d[i] * al; g += d[i + 1] * al; b += d[i + 2] * al; a += al; n++;
    }
    const o = (y * w + x) * 4;
    if (a > 0) { out.data[o] = r / a; out.data[o + 1] = g / a; out.data[o + 2] = b / a; }
    out.data[o + 3] = a / n;
  }
  return out;
}

/**
 * Dessine `src` sur `dst` (composition « normal » avec alpha), avec position, échelle,
 * rotation (degrés, autour du centre de la source) et opacité 0…1. Modifie `dst`.
 */
export function drawImage(dst, src, { x = 0, y = 0, scale = 1, scaleX, scaleY, rotation = 0, opacity = 1 } = {}) {
  const kx = scaleX ?? scale, ky = scaleY ?? scale;
  if (kx <= 0 || ky <= 0 || opacity <= 0) return dst;
  const w = src.width * kx, h = src.height * ky;
  const cx = x + w / 2, cy = y + h / 2;
  const rad = (rotation * Math.PI) / 180, cos = Math.cos(rad), sin = Math.sin(rad);
  // Boîte englobante dans la destination
  const hw = w / 2, hh = h / 2;
  const ex = Math.abs(hw * cos) + Math.abs(hh * sin), ey = Math.abs(hw * sin) + Math.abs(hh * cos);
  const x0 = Math.max(0, Math.floor(cx - ex)), x1 = Math.min(dst.width, Math.ceil(cx + ex));
  const y0 = Math.max(0, Math.floor(cy - ey)), y1 = Math.min(dst.height, Math.ceil(cy + ey));
  const d = dst.data;
  for (let py = y0; py < y1; py++) for (let px = x0; px < x1; px++) {
    const rx = px + 0.5 - cx, ry = py + 0.5 - cy;
    const ux = (rx * cos + ry * sin + hw) / kx, uy = (-rx * sin + ry * cos + hh) / ky;
    if (ux < 0 || uy < 0 || ux >= src.width || uy >= src.height) continue;
    const s = sample(src, ux - 0.5, uy - 0.5);
    const sa = (s[3] / 255) * opacity;
    if (sa <= 0) continue;
    const i = (py * dst.width + px) * 4;
    const da = d[i + 3] / 255;
    const oa = sa + da * (1 - sa);
    d[i] = (s[0] * sa + d[i] * da * (1 - sa)) / oa;
    d[i + 1] = (s[1] * sa + d[i + 1] * da * (1 - sa)) / oa;
    d[i + 2] = (s[2] * sa + d[i + 2] * da * (1 - sa)) / oa;
    d[i + 3] = oa * 255;
  }
  return dst;
}

/** Pinceau rond (couleur RGBA, dureté 0…1). `erase` = gomme. Modifie `img` et le renvoie. */
export function brushStroke(img, points, { size = 10, color = [255, 255, 255, 255], hardness = 0.8, erase: eraseMode = false } = {}) {
  const r = Math.max(0.5, size / 2), d = img.data;
  const stamp = (cx, cy) => {
    const x0 = Math.max(0, Math.floor(cx - r)), x1 = Math.min(img.width, Math.ceil(cx + r));
    const y0 = Math.max(0, Math.floor(cy - r)), y1 = Math.min(img.height, Math.ceil(cy + r));
    for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
      const dist = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r;
      if (dist > 1) continue;
      const f = dist <= hardness ? 1 : 1 - (dist - hardness) / (1 - hardness + 1e-6);
      const i = (y * img.width + x) * 4;
      if (eraseMode) { d[i + 3] = d[i + 3] * (1 - f); continue; }
      const sa = (color[3] / 255) * f, da = d[i + 3] / 255, oa = sa + da * (1 - sa);
      if (oa <= 0) continue;
      d[i] = (color[0] * sa + d[i] * da * (1 - sa)) / oa;
      d[i + 1] = (color[1] * sa + d[i + 1] * da * (1 - sa)) / oa;
      d[i + 2] = (color[2] * sa + d[i + 2] * da * (1 - sa)) / oa;
      d[i + 3] = oa * 255;
    }
  };
  for (let k = 0; k < points.length; k++) {
    const [x, y] = points[k];
    if (k === 0) { stamp(x, y); continue; }
    const [px, py] = points[k - 1];
    const steps = Math.max(1, Math.ceil(Math.hypot(x - px, y - py) / Math.max(1, r / 3)));
    for (let s = 1; s <= steps; s++) stamp(px + ((x - px) * s) / steps, py + ((y - py) * s) / steps);
  }
  return img;
}

/**
 * Pot de peinture : remplit la zone de couleur proche (tolérance 0…255) autour de (x, y).
 * Renvoie une NOUVELLE image. `global` = toutes les zones de cette couleur, contiguës ou non.
 */
export function floodFill(img, x, y, [r, g, b, a = 255], { tolerance = 32, global = false } = {}) {
  x = Math.floor(x); y = Math.floor(y);
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return img.clone();
  const out = img.clone(), d = out.data, w = img.width, h = img.height;
  const i0 = (y * w + x) * 4, ref = [d[i0], d[i0 + 1], d[i0 + 2], d[i0 + 3]];
  const tol = tolerance * tolerance * 4;
  const match = (i) => { const dr = d[i] - ref[0], dg = d[i + 1] - ref[1], db = d[i + 2] - ref[2], da = d[i + 3] - ref[3]; return dr * dr + dg * dg + db * db + da * da <= tol; };
  const seen = new Uint8Array(w * h);
  const paint = (p) => { const i = p * 4; d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = a; };
  if (global) { for (let p = 0; p < w * h; p++) if (match(p * 4)) paint(p); return out; }
  const stack = [y * w + x];
  const marks = [];
  while (stack.length) {
    const p = stack.pop();
    if (seen[p]) continue;
    seen[p] = 1;
    if (!match(p * 4)) continue;
    marks.push(p);
    const px = p % w, py = (p / w) | 0;
    if (px > 0) stack.push(p - 1); if (px < w - 1) stack.push(p + 1);
    if (py > 0) stack.push(p - w); if (py < h - 1) stack.push(p + w);
  }
  for (const p of marks) paint(p);
  return out;
}

export const OPS = { floodFill, brightness, contrast, hueSaturation, colorize, invert, crop, erase, rotate90, flip, resize };
