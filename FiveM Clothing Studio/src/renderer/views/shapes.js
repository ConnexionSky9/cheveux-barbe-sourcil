// Formes à poser sur une texture (chaque forme devient un calque modifiable) :
// boutons, fermeture éclair, coutures, poche, rayures, formes géométriques…
import { RGBAImage } from '../../core/image/rgba.js';

export const SHAPES = [
  { id: 'button', label: 'Bouton', defaults: { w: 64, h: 64, fill: '#2b2b2b', stroke: '#111111', strokeWidth: 3, count: 4 } },
  { id: 'zipper', label: 'Fermeture éclair', defaults: { w: 28, h: 400, fill: '#9a9a9a', stroke: '#444444', strokeWidth: 2 } },
  { id: 'stitches', label: 'Couture', defaults: { w: 400, h: 8, fill: '#f2f2f2', stroke: '#f2f2f2', strokeWidth: 3, dash: 10 } },
  { id: 'pocket', label: 'Poche', defaults: { w: 160, h: 180, fill: '#00000000', stroke: '#e8e8e8', strokeWidth: 3, dash: 8 } },
  { id: 'stripes', label: 'Rayures', defaults: { w: 512, h: 120, fill: '#ffffff', stroke: '#00000000', strokeWidth: 0, count: 3 } },
  { id: 'rect', label: 'Rectangle', defaults: { w: 200, h: 120, fill: '#d23c3c', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'rounded', label: 'Arrondi', defaults: { w: 200, h: 120, fill: '#3c6fd2', stroke: '#00000000', strokeWidth: 0, radius: 24 } },
  { id: 'ellipse', label: 'Cercle', defaults: { w: 160, h: 160, fill: '#f0b429', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'triangle', label: 'Triangle', defaults: { w: 160, h: 140, fill: '#3ccf8e', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'star', label: 'Étoile', defaults: { w: 160, h: 160, fill: '#ffd400', stroke: '#00000000', strokeWidth: 0, count: 5 } },
  { id: 'heart', label: 'Cœur', defaults: { w: 160, h: 150, fill: '#e0245e', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'chevron', label: 'Chevron', defaults: { w: 200, h: 100, fill: '#ffffff', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'line', label: 'Bande', defaults: { w: 512, h: 24, fill: '#111111', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'arrow', label: 'Flèche', defaults: { w: 200, h: 100, fill: '#ffffff', stroke: '#00000000', strokeWidth: 0 } },
  { id: 'badge', label: 'Écusson', defaults: { w: 160, h: 190, fill: '#1e3a8a', stroke: '#f0b429', strokeWidth: 8 } },
  { id: 'cross', label: 'Croix', defaults: { w: 140, h: 140, fill: '#ffffff', stroke: '#00000000', strokeWidth: 0 } },
];

const transparent = (c) => !c || /^#[0-9a-f]{6}00$/i.test(c);

function path(ctx, type, w, h, o) {
  ctx.beginPath();
  const cx = w / 2, cy = h / 2;
  switch (type) {
    case 'rect': case 'line': ctx.rect(0, 0, w, h); break;
    case 'rounded': ctx.roundRect(0, 0, w, h, Math.min(o.radius ?? 20, w / 2, h / 2)); break;
    case 'ellipse': ctx.ellipse(cx, cy, w / 2, h / 2, 0, 0, Math.PI * 2); break;
    case 'triangle': ctx.moveTo(cx, 0); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath(); break;
    case 'star': {
      const n = Math.max(3, o.count || 5);
      for (let i = 0; i < n * 2; i++) {
        const r = i % 2 ? 0.42 : 1, a = (Math.PI * i) / n - Math.PI / 2;
        ctx.lineTo(cx + Math.cos(a) * (w / 2) * r, cy + Math.sin(a) * (h / 2) * r);
      }
      ctx.closePath(); break;
    }
    case 'heart':
      ctx.moveTo(cx, h * 0.95);
      ctx.bezierCurveTo(w * 0.05, h * 0.6, w * -0.05, h * 0.15, w * 0.27, h * 0.08);
      ctx.bezierCurveTo(w * 0.42, h * 0.04, cx, h * 0.18, cx, h * 0.28);
      ctx.bezierCurveTo(cx, h * 0.18, w * 0.58, h * 0.04, w * 0.73, h * 0.08);
      ctx.bezierCurveTo(w * 1.05, h * 0.15, w * 0.95, h * 0.6, cx, h * 0.95);
      ctx.closePath(); break;
    case 'chevron': { const t = h * 0.45; ctx.moveTo(0, 0); ctx.lineTo(cx, h - t); ctx.lineTo(w, 0); ctx.lineTo(w, t); ctx.lineTo(cx, h); ctx.lineTo(0, t); ctx.closePath(); break; }
    case 'arrow': { const t = h * 0.3; ctx.moveTo(0, cy - t / 2); ctx.lineTo(w * 0.6, cy - t / 2); ctx.lineTo(w * 0.6, 0); ctx.lineTo(w, cy); ctx.lineTo(w * 0.6, h); ctx.lineTo(w * 0.6, cy + t / 2); ctx.lineTo(0, cy + t / 2); ctx.closePath(); break; }
    case 'badge': ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h * 0.6); ctx.quadraticCurveTo(w, h * 0.85, cx, h); ctx.quadraticCurveTo(0, h * 0.85, 0, h * 0.6); ctx.closePath(); break;
    case 'cross': { const t = Math.min(w, h) * 0.3; ctx.rect(cx - t / 2, 0, t, h); ctx.rect(0, cy - t / 2, w, t); break; }
    default: ctx.rect(0, 0, w, h);
  }
}

/** Dessine la forme et renvoie une image RGBA (fond transparent). */
export function renderShape(type, o) {
  const pad = Math.ceil((o.strokeWidth || 0) / 2) + 2;
  const w = Math.max(2, Math.round(o.w)), h = Math.max(2, Math.round(o.h));
  const c = document.createElement('canvas');
  c.width = w + pad * 2; c.height = h + pad * 2;
  const ctx = c.getContext('2d');
  ctx.translate(pad, pad);
  ctx.lineWidth = o.strokeWidth || 0; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  ctx.fillStyle = o.fill; ctx.strokeStyle = o.stroke;
  if (type === 'button') {
    const r = Math.min(w, h) / 2;
    ctx.beginPath(); ctx.arc(w / 2, h / 2, r - 1, 0, Math.PI * 2);
    const g = ctx.createRadialGradient(w * 0.4, h * 0.35, r * 0.1, w / 2, h / 2, r);
    g.addColorStop(0, shade(o.fill, 40)); g.addColorStop(1, o.fill);
    ctx.fillStyle = g; ctx.fill();
    if (o.strokeWidth) ctx.stroke();
    ctx.beginPath(); ctx.arc(w / 2, h / 2, r * 0.72, 0, Math.PI * 2); ctx.strokeStyle = shade(o.fill, -30); ctx.lineWidth = Math.max(1, r * 0.06); ctx.stroke();
    const n = o.count === 2 ? 2 : 4, hr = r * 0.11, d = r * 0.24;
    ctx.fillStyle = shade(o.fill, -60);
    const holes = n === 2 ? [[-d, 0], [d, 0]] : [[-d, -d], [d, -d], [-d, d], [d, d]];
    for (const [dx, dy] of holes) { ctx.beginPath(); ctx.arc(w / 2 + dx, h / 2 + dy, hr, 0, Math.PI * 2); ctx.fill(); }
  } else if (type === 'zipper') {
    const tooth = Math.max(4, w * 0.28);
    ctx.fillStyle = shade(o.fill, -50); ctx.fillRect(w * 0.38, 0, w * 0.24, h);
    ctx.fillStyle = o.fill;
    for (let y = 0, i = 0; y < h; y += tooth, i++) ctx.fillRect(i % 2 ? w * 0.5 : w * 0.18, y, w * 0.32, tooth * 0.7);
    ctx.fillStyle = shade(o.fill, 30); ctx.beginPath(); ctx.roundRect(w * 0.1, 0, w * 0.8, Math.min(h, w * 1.6), w * 0.15); ctx.fill();
    if (o.strokeWidth) ctx.stroke();
  } else if (type === 'stitches') {
    ctx.setLineDash([o.dash || 10, (o.dash || 10) * 0.8]);
    ctx.strokeStyle = o.fill; ctx.lineWidth = Math.max(1, Math.min(h, o.strokeWidth || 3));
    ctx.beginPath(); ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2); ctx.stroke();
  } else if (type === 'pocket') {
    if (!transparent(o.fill)) { ctx.fillStyle = o.fill; ctx.beginPath(); ctx.roundRect(0, 0, w, h, [0, 0, w * 0.15, w * 0.15]); ctx.fill(); }
    ctx.setLineDash([o.dash || 8, (o.dash || 8) * 0.8]);
    ctx.beginPath(); ctx.roundRect(4, 4, w - 8, h - 8, [0, 0, w * 0.13, w * 0.13]); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(4, h * 0.25); ctx.lineTo(w - 4, h * 0.25); ctx.stroke();
  } else if (type === 'stripes') {
    const n = Math.max(1, o.count || 3), band = h / (n * 2 - 1);
    ctx.fillStyle = o.fill;
    for (let i = 0; i < n; i++) ctx.fillRect(0, i * band * 2, w, band);
  } else {
    path(ctx, type, w, h, o);
    if (!transparent(o.fill)) ctx.fill('nonzero');
    if (o.strokeWidth && !transparent(o.stroke)) ctx.stroke();
  }
  return new RGBAImage(c.width, c.height, ctx.getImageData(0, 0, c.width, c.height).data);
}

function shade(hex, amt) {
  const n = parseInt(String(hex).slice(1, 7), 16);
  const r = Math.max(0, Math.min(255, (n >> 16) + amt)), g = Math.max(0, Math.min(255, ((n >> 8) & 255) + amt)), b = Math.max(0, Math.min(255, (n & 255) + amt));
  return `rgb(${r},${g},${b})`;
}

/** Petite icône de prévisualisation pour le menu. */
export function shapeIcon(type) {
  const s = SHAPES.find((x) => x.id === type);
  const img = renderShape(type, { ...s.defaults, w: 36, h: 36, strokeWidth: Math.min(2, s.defaults.strokeWidth), dash: 4 });
  const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
  c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(img.data), img.width, img.height), 0, 0);
  return c;
}
