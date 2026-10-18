// Transparence (canal alpha) des textures de vêtements : analyse et réparation ciblée.
// Module PUR (aucune API Node).
//
// En jeu, un pixel dont l'alpha est sous la moitié (< 128) est découpé par les shaders de
// vêtements « cutout » : on voit au travers (peau, sous-vêtements). Une texture de vêtement
// peut avoir des transparences VOULUES (dentelle, franges) : on ne rend jamais tout opaque,
// on ne touche qu'aux pixels désignés par un masque.
import { RGBAImage, ImageError } from '../image/rgba.js';

export const CUT = 128;

/** Statistiques du canal alpha : opaque / partiel / découpé, et zone englobante des découpes. */
export function analyseAlpha(img) {
  const d = img.data, total = img.width * img.height;
  let opaque = 0, partial = 0, cut = 0, x0 = Infinity, y0 = Infinity, x1 = -1, y1 = -1;
  let r = 0, g = 0, b = 0;
  for (let p = 0; p < total; p++) {
    const a = d[p * 4 + 3];
    if (a === 255) { opaque++; continue; }
    if (a >= CUT) { partial++; continue; }
    cut++;
    r += d[p * 4]; g += d[p * 4 + 1]; b += d[p * 4 + 2];
    const x = p % img.width, y = (p / img.width) | 0;
    if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
  }
  const pct = (n) => Math.round((n / total) * 10000) / 100;
  return {
    width: img.width, height: img.height, total,
    opaque, partial, cut, opaquePct: pct(opaque), partialPct: pct(partial), cutPct: pct(cut),
    cutBox: cut ? { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 } : null,
    cutColor: cut ? [Math.round(r / cut), Math.round(g / cut), Math.round(b / cut)] : null,
  };
}

/** Couleur seule, rendue opaque (ce que contient la texture SOUS les zones transparentes). */
export function colorOnly(img) {
  const out = img.clone();
  for (let i = 3; i < out.data.length; i += 4) out.data[i] = 255;
  return out;
}

/** Canal alpha en niveaux de gris : blanc = opaque, noir = invisible. Sert aussi de base au masque. */
export function alphaMap(img) {
  const out = new RGBAImage(img.width, img.height);
  for (let i = 0; i < img.data.length; i += 4) {
    const a = img.data[i + 3];
    out.data[i] = out.data[i + 1] = out.data[i + 2] = a; out.data[i + 3] = 255;
  }
  return out;
}

/** Aperçu : texture sur damier, zones découpées en jeu surlignées en magenta. */
export function alphaPreview(img) {
  const out = new RGBAImage(img.width, img.height);
  for (let y = 0; y < img.height; y++) for (let x = 0; x < img.width; x++) {
    const i = (y * img.width + x) * 4, a = img.data[i + 3] / 255;
    const bg = ((x >> 3) + (y >> 3)) & 1 ? 200 : 140;
    for (let c = 0; c < 3; c++) out.data[i + c] = img.data[i + c] * a + bg * (1 - a);
    if (img.data[i + 3] < CUT) { out.data[i] = 255; out.data[i + 1] = 0; out.data[i + 2] = 255; }
    out.data[i + 3] = 255;
  }
  return out;
}

/** Masque rectangulaire (blanc dans la zone) à la taille de l'image. */
export function rectMask(width, height, { x, y, w, h }) {
  const m = RGBAImage.filled(width, height, [0, 0, 0, 255]);
  for (let yy = Math.max(0, y); yy < Math.min(height, y + h); yy++)
    for (let xx = Math.max(0, x); xx < Math.min(width, x + w); xx++) m.data.set([255, 255, 255, 255], (yy * width + xx) * 4);
  return m;
}

/**
 * Rend opaques les pixels BLANCS du masque (luminance ≥ 128), et seulement eux.
 * fill = true : la couleur des pixels réparés qui étaient découpés est reprise des pixels opaques
 * voisins (sinon on verrait la couleur « cachée » sous la transparence, souvent blanche ou noire).
 * Renvoie { image, changed, refilled }.
 */
export function makeOpaque(img, mask, { fill = true } = {}) {
  if (mask.width !== img.width || mask.height !== img.height)
    throw new ImageError(`Le masque fait ${mask.width} × ${mask.height}, la texture ${img.width} × ${img.height} : ils doivent avoir la même taille.`);
  const W = img.width, H = img.height, out = img.clone(), d = out.data;
  const todo = new Uint8Array(W * H);   // 1 = pixel découpé à recolorer
  let changed = 0;
  for (let p = 0; p < W * H; p++) {
    const m = mask.data[p * 4] * 0.299 + mask.data[p * 4 + 1] * 0.587 + mask.data[p * 4 + 2] * 0.114;
    if (m < 128 || d[p * 4 + 3] === 255) continue;
    if (d[p * 4 + 3] < CUT) todo[p] = 1;
    d[p * 4 + 3] = 255;
    changed++;
  }
  let refilled = 0;
  if (fill) {
    // Remplissage par diffusion : chaque passe colore les pixels à recolorer qui touchent un pixel connu
    let rest = [];
    for (let p = 0; p < W * H; p++) if (todo[p]) rest.push(p);
    while (rest.length) {
      const next = [];
      for (const p of rest) {
        const x = p % W, y = (p / W) | 0;
        let r = 0, g = 0, b = 0, n = 0;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
          const q = ny * W + nx;
          if (todo[q] || d[q * 4 + 3] < CUT) continue;
          r += d[q * 4]; g += d[q * 4 + 1]; b += d[q * 4 + 2]; n++;
        }
        if (n) next.push([p, r / n, g / n, b / n]);
      }
      if (!next.length) break;   // zone sans aucun voisin opaque : couleur d'origine conservée
      for (const [p, r, g, b] of next) { d[p * 4] = r; d[p * 4 + 1] = g; d[p * 4 + 2] = b; todo[p] = 0; refilled++; }
      rest = rest.filter((p) => todo[p]);
    }
  }
  return { image: out, changed, refilled };
}
