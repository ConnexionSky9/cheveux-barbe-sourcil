// Éditeur de textures en calques.
// Affichage rapide via le canvas du navigateur ; les opérations et l'export final passent
// par le moteur d'images du projet (src/core/image), identique à celui testé automatiquement.
import { h, fill, icon, btn, toast, modal, field, select, confirmBox, prompt } from '../ui.js';
import { TextureDocument } from '../../core/image/layers.js';
import { RGBAImage, isPowerOfTwo } from '../../core/image/rgba.js';
import * as ops from '../../core/image/ops.js';
import { SHAPES, renderShape, shapeIcon } from './shapes.js';
import { S, api, adopt, markDirty, saveProject } from '../app.js';

const TOOLS = [
  { id: 'move', icon: 'move', label: 'Déplacer le calque (glisser) — molette : zoom, clic droit ou Espace : faire défiler la vue' },
  { id: 'brush', icon: 'brush', label: 'Pinceau' },
  { id: 'eraser', icon: 'eraser', label: 'Gomme' },
  { id: 'erase-rect', icon: 'rect', label: 'Effacer une zone rectangulaire du calque' },
  { id: 'crop', icon: 'crop', label: 'Recadrer le document (tracer un rectangle)' },
  { id: 'fill', icon: 'bucket', label: 'Pot de peinture : remplir une zone de couleur' },
];

export function payloadToDoc(p, undoSteps) {
  const images = {};
  for (const l of p.layers) images[l.id] = new RGBAImage(l.w, l.h, l.data);
  return TextureDocument.deserialize({ type: 'fcs-texture-document', version: 1, name: p.name, width: p.width, height: p.height,
    layers: p.layers.map(({ data, ...l }) => l) }, images, { undoSteps });
}
function docToPayload(doc) {
  return { name: doc.name, width: doc.width, height: doc.height,
    layers: doc.layers.map(({ image, ...l }) => ({ ...l, w: image.width, h: image.height, data: new Uint8Array(image.data.buffer, image.data.byteOffset, image.data.byteLength) })) };
}
const imgCanvases = new WeakMap();
function canvasOf(img) {
  let c = imgCanvases.get(img);
  if (!c) {
    c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(img.data), img.width, img.height), 0, 0);
    imgCanvases.set(img, c);
  }
  return c;
}
const hexToRgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));

/**
 * Crée l'éditeur. `center` = zone centrale, `side` = panneau de droite.
 * Renvoie un objet piloté par l'application (annuler, rétablir, enregistrer…).
 */
export function createTextureEditor(center, side, state) {
  const { meta, doc } = state;
  state.ui = state.ui || { tool: 'move', zoom: null, panX: 0, panY: 0 };
  const E = { active: true, meta, doc, get dirty() { return doc.dirty; }, set dirty(v) { doc.dirty = v; }, tool: state.ui.tool, layerId: doc.layers.at(-1)?.id, zoom: 1, panX: 0, panY: 0,
    brush: { size: 16, color: '#ffffff', hardness: 0.8, opacity: 100 }, fillOpt: { color: '#c0392b', tolerance: 40, global: false }, preview: null, drag: null, uvOverlay: false, refImage: null, refOpacity: 0.5 };

  // ---------------------------------------------------------------- vue
  const checker = h('div.checker');
  const view = h('canvas');
  const overlay = h('canvas', { style: { pointerEvents: 'none' } });
  const hud = h('div.texed-hud');
  const wrap = h('div.canvas-wrap', checker, view, overlay, hud);
  const toolbox = h('div.toolbox', TOOLS.map((t) => h(`button.icon-btn${t.id === E.tool ? '.active' : ''}`, { title: t.label, type: 'button', dataset: { tool: t.id },
    onclick: () => { E.tool = t.id; state.ui.tool = t.id; toolbox.querySelectorAll('[data-tool]').forEach((b) => b.classList.toggle('active', b.dataset.tool === t.id)); renderSide(); } }, icon(t.icon))),
  h('span', { style: { flex: 1 } }),
  h('button.icon-btn', { title: 'Ajuster à la fenêtre', type: 'button', onclick: () => fit() }, icon('reset')),
  h('button.icon-btn', { title: 'Zoom 100 %', type: 'button', onclick: () => { E.zoom = 1; layout(); } }, h('span.small', '1:1')));
  const root = h('div.texed', toolbox, wrap);
  center.append(root);

  function fit() {
    const r = wrap.getBoundingClientRect();
    E.zoom = Math.min((r.width - 40) / doc.width, (r.height - 40) / doc.height, 4);
    E.panX = 0; E.panY = 0;
    layout();
  }
  function layout() {
    const r = wrap.getBoundingClientRect();
    const w = doc.width * E.zoom, hgt = doc.height * E.zoom;
    const x = (r.width - w) / 2 + E.panX, y = (r.height - hgt) / 2 + E.panY;
    for (const el of [checker, view, overlay]) Object.assign(el.style, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${hgt}px` });
    view.style.imageRendering = E.zoom >= 2 ? 'pixelated' : 'auto';
    E.origin = { x, y };
    drawOverlay();
    hud.textContent = `${doc.width} × ${doc.height} px · zoom ${Math.round(E.zoom * 100)} %`;
  }
  const ro = new ResizeObserver(() => layout());
  ro.observe(wrap);

  /** Rendu de l'aperçu (canvas 2D). L'export final utilise doc.composite() (moteur du projet). */
  function render() {
    if (view.width !== doc.width || view.height !== doc.height) { view.width = overlay.width = doc.width; view.height = overlay.height = doc.height; layout(); }
    const ctx = view.getContext('2d');
    ctx.clearRect(0, 0, doc.width, doc.height);
    for (const l of doc.layers) {
      if (!l.visible || l.opacity <= 0) continue;
      let img = l.image;
      if (E.preview && E.preview.id === l.id) img = E.preview.image;
      const t = E.drag?.layerId === l.id ? { ...l, x: l.x + E.drag.dx, y: l.y + E.drag.dy } : l;
      const w = img.width * t.scale, hh = img.height * t.scale;
      ctx.save();
      ctx.globalAlpha = t.opacity;
      ctx.translate(t.x + w / 2, t.y + hh / 2);
      ctx.rotate((t.rotation * Math.PI) / 180);
      ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(canvasOf(img), -w / 2, -hh / 2, w, hh);
      ctx.restore();
    }
    drawOverlay();
    scheduleLive();
  }

  function drawOverlay() {
    const ctx = overlay.getContext('2d');
    ctx.clearRect(0, 0, overlay.width, overlay.height);
    if (E.refImage) { ctx.globalAlpha = E.refOpacity; ctx.drawImage(E.refImage, 0, 0, doc.width, doc.height); ctx.globalAlpha = 1; }
    if (E.uvOverlay && S.viewer) {
      const { segments, flipY } = S.viewer.uvSegments(E.uvMaterial || null);
      ctx.strokeStyle = 'rgba(60, 207, 142, .85)'; ctx.lineWidth = Math.max(1, 1 / E.zoom);
      ctx.beginPath();
      for (const [u1, v1, u2, v2] of segments) {
        const y1 = flipY ? 1 - v1 : v1, y2 = flipY ? 1 - v2 : v2;
        ctx.moveTo((u1 % 1 + 1) % 1 * doc.width, (y1 % 1 + 1) % 1 * doc.height);
        ctx.lineTo((u2 % 1 + 1) % 1 * doc.width, (y2 % 1 + 1) % 1 * doc.height);
      }
      ctx.stroke();
    }
    const l = doc.layers.find((x) => x.id === E.layerId);
    if (l && E.tool === 'move') {
      const t = E.drag?.layerId === l.id ? { ...l, x: l.x + E.drag.dx, y: l.y + E.drag.dy } : l;
      const w = l.image.width * t.scale, hh = l.image.height * t.scale;
      ctx.save(); ctx.translate(t.x + w / 2, t.y + hh / 2); ctx.rotate((t.rotation * Math.PI) / 180);
      ctx.setLineDash([6 / E.zoom, 4 / E.zoom]); ctx.strokeStyle = '#5b9dff'; ctx.lineWidth = 1.5 / E.zoom;
      ctx.strokeRect(-w / 2, -hh / 2, w, hh); ctx.restore();
    }
    if (E.rect) {
      const { x0, y0, x1, y1 } = E.rect;
      ctx.setLineDash([5 / E.zoom, 4 / E.zoom]); ctx.strokeStyle = E.tool === 'crop' ? '#f0b429' : '#ef5b5b'; ctx.lineWidth = 1.5 / E.zoom;
      ctx.strokeRect(Math.min(x0, x1), Math.min(y0, y1), Math.abs(x1 - x0), Math.abs(y1 - y0));
      ctx.setLineDash([]);
    }
    if (E.stroke) {
      ctx.strokeStyle = E.tool === 'eraser' ? 'rgba(255,255,255,.5)' : E.brush.color; ctx.lineWidth = E.brush.size; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      ctx.globalAlpha = E.brush.opacity / 100;
      ctx.beginPath(); E.stroke.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); ctx.stroke(); ctx.globalAlpha = 1;
    }
  }

  // ---------------------------------------------------------------- souris
  const docPoint = (e) => { const r = view.getBoundingClientRect(); return [(e.clientX - r.left) / E.zoom, (e.clientY - r.top) / E.zoom]; };
  /** Point du document → coordonnées dans l'image du calque (inverse de position / échelle / rotation). */
  const layerPoint = (l, [px, py]) => {
    const w = l.image.width * l.scale, hh = l.image.height * l.scale;
    const cx = l.x + w / 2, cy = l.y + hh / 2, rad = (-l.rotation * Math.PI) / 180;
    const dx = px - cx, dy = py - cy;
    return [(dx * Math.cos(rad) - dy * Math.sin(rad) + w / 2) / l.scale, (dx * Math.sin(rad) + dy * Math.cos(rad) + hh / 2) / l.scale];
  };
  let space = false;
  const keyDown = (e) => { if (e.code === 'Space' && !/INPUT|TEXTAREA/.test(document.activeElement?.tagName)) { space = true; wrap.style.cursor = 'grab'; } };
  const keyUp = (e) => { if (e.code === 'Space') { space = false; wrap.style.cursor = ''; } };
  document.addEventListener('keydown', keyDown); document.addEventListener('keyup', keyUp);
  wrap.addEventListener('contextmenu', (e) => e.preventDefault());
  wrap.addEventListener('wheel', (e) => {
    e.preventDefault();
    const k = e.deltaY < 0 ? 1.15 : 1 / 1.15;
    E.zoom = Math.max(0.05, Math.min(32, E.zoom * k));
    layout();
  }, { passive: false });
  wrap.addEventListener('pointerdown', (e) => {
    wrap.setPointerCapture(e.pointerId);
    const p = docPoint(e);
    if (e.button === 2 || e.button === 1 || space) { E.pan = { x: e.clientX, y: e.clientY, px: E.panX, py: E.panY }; return; }
    const l = doc.layers.find((x) => x.id === E.layerId);
    if (E.tool === 'move') { if (l) E.drag = { layerId: l.id, sx: p[0], sy: p[1], dx: 0, dy: 0 }; }
    else if (E.tool === 'brush' || E.tool === 'eraser') { if (!l) return toast('Choisissez un calque.'); E.stroke = [p]; drawOverlay(); }
    else if (E.tool === 'erase-rect' || E.tool === 'crop') { E.rect = { x0: p[0], y0: p[1], x1: p[0], y1: p[1] }; }
    else if (E.tool === 'fill') {
      if (!l) return toast('Choisissez un calque.');
      const [lx, ly] = layerPoint(l, p);
      const [r, g, b] = hexToRgb(E.fillOpt.color);
      change(() => doc.applyToLayer(l.id, 'Pot de peinture', (img) => ops.floodFill(img, lx, ly, [r, g, b, 255], { tolerance: E.fillOpt.tolerance, global: E.fillOpt.global })));
    }
  });
  wrap.addEventListener('pointermove', (e) => {
    const p = docPoint(e);
    hud.textContent = `${doc.width} × ${doc.height} px · zoom ${Math.round(E.zoom * 100)} % · x ${Math.floor(p[0])}, y ${Math.floor(p[1])}`;
    if (E.pan) { E.panX = E.pan.px + e.clientX - E.pan.x; E.panY = E.pan.py + e.clientY - E.pan.y; layout(); return; }
    if (E.drag) { E.drag.dx = p[0] - E.drag.sx; E.drag.dy = p[1] - E.drag.sy; render(); }
    else if (E.stroke) { E.stroke.push(p); drawOverlay(); }
    else if (E.rect) { E.rect.x1 = p[0]; E.rect.y1 = p[1]; drawOverlay(); }
  });
  wrap.addEventListener('pointerup', () => {
    if (E.pan) { E.pan = null; return; }
    const l = doc.layers.find((x) => x.id === E.layerId);
    if (E.drag) {
      const { dx, dy, layerId } = E.drag; E.drag = null;
      if (Math.abs(dx) + Math.abs(dy) > 0.01) change(() => doc.updateLayer(layerId, { x: l.x + dx, y: l.y + dy }, 'Déplacer le calque'));
      else render();
    } else if (E.stroke && l) {
      const pts = E.stroke.map((pt) => layerPoint(l, pt)); E.stroke = null;
      const [r, g, b] = hexToRgb(E.brush.color);
      change(() => doc.applyToLayer(l.id, E.tool === 'eraser' ? 'Gomme' : 'Pinceau', (img) => ops.brushStroke(img.clone(), pts,
        { size: E.brush.size / l.scale, color: [r, g, b, Math.round(E.brush.opacity * 2.55)], hardness: E.brush.hardness, erase: E.tool === 'eraser' })));
    } else if (E.rect) {
      const { x0, y0, x1, y1 } = E.rect; E.rect = null;
      const x = Math.min(x0, x1), y = Math.min(y0, y1), w = Math.abs(x1 - x0), hh = Math.abs(y1 - y0);
      if (w < 2 || hh < 2) return drawOverlay();
      if (E.tool === 'crop') change(() => doc.cropDocument(Math.max(0, x), Math.max(0, y), Math.min(doc.width - Math.max(0, x), w), Math.min(doc.height - Math.max(0, y), hh)));
      else if (l) {
        const a = layerPoint(l, [x, y]), c = layerPoint(l, [x + w, y + hh]);
        change(() => doc.applyToLayer(l.id, 'Effacer une zone', (img) => ops.erase(img, Math.min(a[0], c[0]), Math.min(a[1], c[1]), Math.abs(c[0] - a[0]), Math.abs(c[1] - a[1]))));
      }
    }
  });

  // ---------------------------------------------------------------- modifications
  function change(fn) {
    try { fn(); } catch (e) { toast(e.message, 'error'); }
    E.preview = null;
    E.dirty = true; markDirty();
    if (!doc.layers.some((l) => l.id === E.layerId)) E.layerId = doc.layers.at(-1)?.id;
    render(); renderSide();
  }
  E.undo = () => { if (!doc.canUndo) return false; doc.undo(); E.dirty = true; markDirty(); if (!doc.layers.some((l) => l.id === E.layerId)) E.layerId = doc.layers.at(-1)?.id; render(); renderSide(); return true; };
  E.redo = () => { if (!doc.canRedo) return false; doc.redo(); E.dirty = true; markDirty(); render(); renderSide(); return true; };

  E.save = async () => {
    const r = await api.textureSave({ project: S.project, id: meta.id, doc: docToPayload(doc) });
    if (!r.ok) { toast(`Texture non enregistrée : ${r.error}`, 'error'); return false; }
    adopt(r.project);
    E.dirty = false;
    await saveProject({ quiet: true });   // la liste des textures du projet est enregistrée aussi
    return true;
  };

  async function addImageLayer(src, name) {
    if (!src.ok) return toast(src.error, 'error');
    const img = new RGBAImage(src.width, src.height, src.data);
    const k = Math.min(1, (doc.width * 0.5) / img.width, (doc.height * 0.5) / img.height);
    change(() => { E.layerId = doc.addLayer({ name: name || src.name, image: img, scale: k, x: (doc.width - img.width * k) / 2, y: (doc.height - img.height * k) / 2 }); });
  }
  E.addImageLayer = addImageLayer;

  function rasterText({ text, size, color, font, bold, outline }) {
    const c = document.createElement('canvas'), ctx = c.getContext('2d');
    const f = `${bold ? 'bold ' : ''}${size}px "${font}"`;
    ctx.font = f;
    const lines = String(text).split('\n');
    const w = Math.ceil(Math.max(...lines.map((l) => ctx.measureText(l).width)) + size * 0.4 + (outline ? 8 : 0));
    const hh = Math.ceil(lines.length * size * 1.25 + size * 0.3);
    c.width = Math.max(1, w); c.height = Math.max(1, hh);
    ctx.font = f; ctx.textBaseline = 'top'; ctx.fillStyle = color;
    lines.forEach((l, i) => {
      if (outline) { ctx.lineWidth = Math.max(2, size / 10); ctx.strokeStyle = outline; ctx.strokeText(l, size * 0.2, i * size * 1.25 + size * 0.1); }
      ctx.fillText(l, size * 0.2, i * size * 1.25 + size * 0.1);
    });
    return new RGBAImage(c.width, c.height, ctx.getImageData(0, 0, c.width, c.height).data);
  }
  function shapeDialog(type, layer) {
    const def = SHAPES.find((x) => x.id === type);
    const k = Math.max(0.25, Math.min(4, doc.width / 512));
    const prev = layer?.meta?.shape?.opts;
    const st = prev ? { ...prev } : { ...def.defaults, w: Math.round(def.defaults.w * k), h: Math.round(def.defaults.h * k), strokeWidth: Math.round((def.defaults.strokeWidth || 0) * k) };
    st.fillOn = prev ? prev.fillOn : !/00$/.test(def.defaults.fill) || def.defaults.fill.length === 7;
    st.strokeOn = prev ? prev.strokeOn : (def.defaults.strokeWidth || 0) > 0 && def.defaults.stroke.length === 7;
    st.fill = st.fill.slice(0, 7); st.stroke = st.stroke.slice(0, 7);
    const num = (label, key, min, max) => field(label, h('input.input', { type: 'number', min, max, value: st[key], oninput: (e) => { st[key] = Number(e.target.value) || 0; } }));
    modal({ title: layer ? `Modifier : ${def.label}` : `Ajouter : ${def.label}`, body: h('div.form',
      h('div.row', num('Largeur (px)', 'w', 2, 8192), num('Hauteur (px)', 'h', 2, 8192)),
      h('div.row', h('label.checkbox', h('input', { type: 'checkbox', checked: st.fillOn, onchange: (e) => { st.fillOn = e.target.checked; } }), 'Couleur'), h('input', { type: 'color', value: st.fill, oninput: (e) => { st.fill = e.target.value; } }),
        h('label.checkbox', h('input', { type: 'checkbox', checked: st.strokeOn, onchange: (e) => { st.strokeOn = e.target.checked; } }), 'Contour'), h('input', { type: 'color', value: st.stroke, oninput: (e) => { st.stroke = e.target.value; } })),
      h('div.row', num('Épaisseur du contour', 'strokeWidth', 0, 200),
        ['stripes', 'star', 'button'].includes(type) ? num(type === 'stripes' ? 'Nombre de bandes' : type === 'star' ? 'Branches' : 'Trous (2 ou 4)', 'count', 1, 30) : null,
        ['stitches', 'pocket'].includes(type) ? num('Longueur des points', 'dash', 1, 200) : null)),
    actions: [{ label: 'Annuler' }, { label: layer ? 'Mettre à jour' : 'Ajouter', kind: 'primary', id: 'shape-ok', onclick: () => {
      const opts = { ...st, fill: st.fillOn ? st.fill : '#00000000', stroke: st.strokeOn ? st.stroke : '#00000000', strokeWidth: st.strokeOn ? st.strokeWidth : (type === 'stitches' ? st.strokeWidth : 0) };
      if (type === 'stitches') opts.fill = st.fill;
      const img = renderShape(type, opts);
      const meta = { shape: { type, opts: st } };
      if (layer) change(() => { doc.applyToLayer(layer.id, `Modifier ${def.label}`, () => img); doc.updateLayer(layer.id, { meta }, `Modifier ${def.label}`); });
      else change(() => { E.layerId = doc.addLayer({ name: def.label, image: img, x: Math.round((doc.width - img.width) / 2), y: Math.round((doc.height - img.height) / 2), meta }); });
    } }] });
  }

  function textDialog(layer) {
    const t = layer?.meta?.text || { text: 'Mon texte', size: Math.round(doc.height / 12), color: '#ffffff', font: 'Arial', bold: true, outline: '' };
    const st = { ...t };
    modal({ title: layer ? 'Modifier le texte' : 'Ajouter du texte', body: h('div.form',
      field('Texte', h('textarea.input', { rows: 3, oninput: (e) => { st.text = e.target.value; } }, st.text)),
      h('div.row', field('Taille (px)', h('input.input', { type: 'number', min: 4, max: 1000, value: st.size, oninput: (e) => { st.size = Number(e.target.value) || 12; } })),
        field('Police', select(['Arial', 'Impact', 'Segoe UI', 'Georgia', 'Courier New', 'Verdana', 'Times New Roman'].map((v) => ({ value: v, label: v })), st.font, (v) => { st.font = v; }))),
      h('div.row', field('Couleur', h('input', { type: 'color', value: st.color, oninput: (e) => { st.color = e.target.value; } })),
        field('Contour', h('input', { type: 'color', value: st.outline || '#000000', oninput: (e) => { st.outline = e.target.value; } })),
        h('label.checkbox', h('input', { type: 'checkbox', checked: st.bold, onchange: (e) => { st.bold = e.target.checked; } }), 'Gras'))),
    actions: [{ label: 'Annuler' }, { label: layer ? 'Mettre à jour' : 'Ajouter', kind: 'primary', onclick: () => {
      if (!st.text.trim()) { toast('Texte vide.', 'error'); return true; }
      const img = rasterText(st);
      if (layer) change(() => { doc.applyToLayer(layer.id, 'Modifier le texte', () => img); doc.updateLayer(layer.id, { meta: { text: st }, name: `Texte : ${st.text.slice(0, 20)}` }, 'Modifier le texte'); });
      else change(() => { E.layerId = doc.addLayer({ name: `Texte : ${st.text.slice(0, 20)}`, image: img, x: (doc.width - img.width) / 2, y: (doc.height - img.height) / 2, meta: { text: st } }); });
    } }] });
  }

  // ---------------------------------------------------------------- panneau latéral
  const adj = { brightness: 0, contrast: 0, hue: 0, saturation: 0, colorize: '#3366cc', colorizeOn: false, force: 100 };
  let previewTimer = null;
  function computePreview() {
    const l = doc.layers.find((x) => x.id === E.layerId);
    if (!l) return;
    let img = l.image;
    if (adj.brightness) img = ops.brightness(img, adj.brightness);
    if (adj.contrast) img = ops.contrast(img, adj.contrast);
    if (adj.hue || adj.saturation) img = ops.hueSaturation(img, adj.hue, adj.saturation);
    if (adj.colorizeOn) img = ops.colorize(img, hexToRgb(adj.colorize), adj.force);
    E.preview = img === l.image ? null : { id: l.id, image: img };
    render();
  }
  const schedulePreview = () => { clearTimeout(previewTimer); previewTimer = setTimeout(computePreview, 120); };
  const slider = (label, key, min, max) => {
    const out = h('output', String(adj[key]));
    return h('div.slider-row', h('span', label), h('input', { type: 'range', min, max, value: adj[key], oninput: (e) => { adj[key] = Number(e.target.value); out.textContent = e.target.value; schedulePreview(); } }), out);
  };

  function layerRow(l) {
    const thumb = h('canvas', { width: 36, height: 36 });
    const tctx = thumb.getContext('2d');
    const k = Math.min(36 / l.image.width, 36 / l.image.height);
    tctx.drawImage(canvasOf(l.image), (36 - l.image.width * k) / 2, (36 - l.image.height * k) / 2, l.image.width * k, l.image.height * k);
    return h(`li.layer${l.id === E.layerId ? '.selected' : ''}`, { onclick: () => { E.layerId = l.id; E.preview = null; render(); renderSide(); },
      ondblclick: async () => { const n = await prompt('Renommer le calque', { value: l.name }); if (n) change(() => doc.updateLayer(l.id, { name: n }, 'Renommer le calque')); } },
    thumb, h('span.name', { title: l.name }, l.name),
    h('button.icon-btn', { title: l.visible ? 'Masquer' : 'Afficher', type: 'button', onclick: (e) => { e.stopPropagation(); change(() => doc.updateLayer(l.id, { visible: !l.visible }, l.visible ? 'Masquer le calque' : 'Afficher le calque')); } }, icon(l.visible ? 'eye' : 'eyeoff', 16)));
  }

  function renderSide() {
    const l = doc.layers.find((x) => x.id === E.layerId);
    const warn = [];
    if (!isPowerOfTwo(doc.width) || !isPowerOfTwo(doc.height)) warn.push('Dimensions non puissances de 2 : redimensionnez avant la conversion pour le jeu.');
    if (Math.max(doc.width, doc.height) > (S.info?.config?.limits?.warnTextureSize ?? 2048)) warn.push('Grande texture : pensez aux performances en jeu.');
    fill(side, 
      h('div.panel-head', h('h3', 'Texture'), h('button.icon-btn', { title: 'Fermer l\'éditeur', type: 'button', onclick: () => E.onClose?.() }, icon('x'))),
      h('div.props-section',
        h('dl.kv', h('dt', 'Nom'), h('dd', doc.name), h('dt', 'Dimensions'), h('dd', `${doc.width} × ${doc.height} px`),
          h('dt', 'Calques'), h('dd', String(doc.layers.length)), h('dt', 'Transparence'), h('dd', doc.layers.some((x) => x.image.hasAlpha() || x.opacity < 1) ? 'oui' : 'non'),
          h('dt', 'Historique'), h('dd', doc.canUndo ? `Annuler : ${doc.undoLabel}` : '—')),
        warn.map((w) => h('p.help', { style: { color: 'var(--warn)' } }, w)),
        h('div.row', { style: { marginTop: '8px', flexWrap: 'wrap' } },
          btn('Enregistrer', async () => { if (await E.save()) toast('Texture enregistrée.', 'success', 1800); }, { icon: 'save', kind: 'small primary' }),
          btn('Exporter…', () => exportDialog(), { icon: 'export', kind: 'small' }),
          btn('Dimensions…', () => resizeDialog(), { kind: 'small' }))),
      h('div.props-section',
        h('div.row.tight', { style: { marginBottom: '6px' } }, h('h3', { style: { flex: 1, margin: 0 } }, 'Calques'),
          h('button.icon-btn', { title: 'Nouveau calque vide', type: 'button', onclick: () => change(() => { E.layerId = doc.addLayer({ name: `Calque ${doc.layers.length + 1}` }); }) }, icon('plus', 16)),
          h('button.icon-btn', { title: 'Importer un logo ou une image', type: 'button', onclick: async () => { const r = await api.dialogPickFiles({ multi: false, title: 'Logo ou image', filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'tga', 'dds'] }] }); if (r.paths?.[0]) addImageLayer(await api.textureDecodeFile(r.paths[0])); } }, icon('image', 16)),
          h('button.icon-btn', { title: 'Ajouter du texte', type: 'button', onclick: () => textDialog() }, icon('text', 16))),
        h('ul.layer-list', [...doc.layers].reverse().map(layerRow)),
        l ? h('div.row.tight', { style: { flexWrap: 'wrap', gap: '4px' } },
          h('button.icon-btn', { title: 'Monter', type: 'button', onclick: () => change(() => doc.moveUp(l.id)) }, icon('up', 16)),
          h('button.icon-btn', { title: 'Descendre', type: 'button', onclick: () => change(() => doc.moveDown(l.id)) }, icon('down', 16)),
          h('button.icon-btn', { title: 'Dupliquer', type: 'button', onclick: () => change(() => { E.layerId = doc.duplicateLayer(l.id); }) }, icon('copy', 16)),
          h('button.icon-btn', { title: 'Supprimer le calque', type: 'button', onclick: async () => { if (doc.layers.length === 1) return toast('Le document doit garder au moins un calque.'); if (await confirmBox('Supprimer le calque', `Supprimer « ${l.name} » ? (Ctrl+Z pour annuler)`, { ok: 'Supprimer', danger: true })) change(() => doc.removeLayer(l.id)); } }, icon('trash', 16)),
          l.meta?.text ? btn('Modifier le texte', () => textDialog(l), { kind: 'small' }) : null) : null),
      l ? h('div.props-section', h('h3', `Calque : ${l.name}`),
        h('div.slider-row', h('span', 'Opacité'), h('input', { type: 'range', min: 0, max: 100, value: Math.round(l.opacity * 100), onchange: (e) => change(() => doc.updateLayer(l.id, { opacity: Number(e.target.value) / 100 }, 'Opacité')) }), h('output', `${Math.round(l.opacity * 100)} %`)),
        h('div.row', numField('X', l.x, (v) => doc.updateLayer(l.id, { x: v }, 'Position')), numField('Y', l.y, (v) => doc.updateLayer(l.id, { y: v }, 'Position'))),
        h('div.row', numField('Échelle %', Math.round(l.scale * 1000) / 10, (v) => doc.updateLayer(l.id, { scale: Math.max(0.001, v / 100) }, 'Échelle')),
          numField('Rotation °', l.rotation, (v) => doc.updateLayer(l.id, { rotation: v }, 'Rotation'))),
        h('div.row.tight', { style: { flexWrap: 'wrap', gap: '4px' } },
          btn('↻ 90°', () => change(() => doc.applyToLayer(l.id, 'Pivoter de 90°', (im) => ops.rotate90(im, 1))), { kind: 'small' }),
          btn('Miroir', () => change(() => doc.applyToLayer(l.id, 'Miroir horizontal', (im) => ops.flip(im, true))), { kind: 'small' }),
          btn('Inverser', () => change(() => doc.applyToLayer(l.id, 'Inverser les couleurs', (im) => ops.invert(im))), { kind: 'small' }),
          btn('Centrer', () => change(() => doc.updateLayer(l.id, { x: (doc.width - l.image.width * l.scale) / 2, y: (doc.height - l.image.height * l.scale) / 2 }, 'Centrer')), { kind: 'small' })),
        h('div.adjust', h('h3', 'Couleurs'),
          slider('Luminosité', 'brightness', -100, 100), slider('Contraste', 'contrast', -100, 100),
          slider('Teinte', 'hue', -180, 180), slider('Saturation', 'saturation', -100, 100),
          h('div.row.tight', h('label.checkbox', h('input', { type: 'checkbox', checked: adj.colorizeOn, onchange: (e) => { adj.colorizeOn = e.target.checked; schedulePreview(); } }), 'Colorer'),
            h('input', { type: 'color', value: adj.colorize, oninput: (e) => { adj.colorize = e.target.value; schedulePreview(); } })),
          slider('Force', 'force', 0, 100),
          h('div.row', { style: { marginTop: '6px' } },
            btn('Appliquer', () => { if (!E.preview) return toast('Aucun réglage à appliquer.'); const img = E.preview.image; change(() => doc.applyToLayer(l.id, 'Réglage des couleurs', () => img)); Object.assign(adj, { brightness: 0, contrast: 0, hue: 0, saturation: 0, colorizeOn: false }); renderSide(); }, { kind: 'small primary' }),
            btn('Réinitialiser', () => { Object.assign(adj, { brightness: 0, contrast: 0, hue: 0, saturation: 0, colorizeOn: false }); E.preview = null; render(); renderSide(); }, { kind: 'small' })))) : null,
      (E.tool === 'brush' || E.tool === 'eraser') ? h('div.props-section', h('h3', E.tool === 'brush' ? 'Pinceau' : 'Gomme'),
        h('div.slider-row', h('span', 'Taille'), h('input', { type: 'range', min: 1, max: 300, value: E.brush.size, oninput: (e) => { E.brush.size = Number(e.target.value); } }), h('output', '')),
        h('div.slider-row', h('span', 'Dureté'), h('input', { type: 'range', min: 0, max: 100, value: E.brush.hardness * 100, oninput: (e) => { E.brush.hardness = Number(e.target.value) / 100; } }), h('output', '')),
        E.tool === 'brush' ? h('div.slider-row', h('span', 'Opacité'), h('input', { type: 'range', min: 1, max: 100, value: E.brush.opacity, oninput: (e) => { E.brush.opacity = Number(e.target.value); } }), h('output', '')) : null,
        E.tool === 'brush' ? h('div.row.tight', h('span.small.muted', 'Couleur'), h('input', { type: 'color', value: E.brush.color, oninput: (e) => { E.brush.color = e.target.value; } })) : null) : null,
      E.tool === 'fill' ? h('div.props-section', h('h3', 'Pot de peinture'),
        h('div.row.tight', h('span.small.muted', 'Couleur'), h('input', { type: 'color', value: E.fillOpt.color, oninput: (e) => { E.fillOpt.color = e.target.value; } })),
        h('div.slider-row', h('span', 'Tolérance'), h('input', { type: 'range', min: 0, max: 200, value: E.fillOpt.tolerance, oninput: (e) => { E.fillOpt.tolerance = Number(e.target.value); } }), h('output', '')),
        h('label.checkbox', h('input', { type: 'checkbox', checked: E.fillOpt.global, onchange: (e) => { E.fillOpt.global = e.target.checked; } }), 'Toutes les zones de cette couleur'),
        h('p.help', 'Cliquez sur la zone du calque à recolorer.')) : null,
      h('div.props-section', h('h3', 'Formes et détails'),
        h('div.shape-grid', SHAPES.map((sh) => h('button', { type: 'button', title: sh.label, dataset: { shape: sh.id }, onclick: () => shapeDialog(sh.id) }, shapeIcon(sh.id), sh.label))),
        l?.meta?.shape ? h('div', { style: { marginTop: '8px' } }, btn('Modifier la forme sélectionnée', () => shapeDialog(l.meta.shape.type, l), { kind: 'small' })) : null,
        h('p.help', 'Chaque forme devient un calque : déplacez-la, tournez-la, changez sa couleur ou son opacité.')),
      h('div.props-section', h('h3', 'Repères'),
        h('label.checkbox', h('input', { type: 'checkbox', checked: E.uvOverlay, onchange: (e) => {
          if (e.target.checked && !S.viewer?.models.some((m) => !m.reference)) { e.target.checked = false; return toast('Chargez d\'abord un modèle 3D avec UV dans l\'aperçu (onglet Aperçu 3D).'); }
          E.uvOverlay = e.target.checked; drawOverlay();
        } }), 'Afficher le patron UV du modèle 3D'),
        E.uvOverlay && S.viewer ? select([{ value: '', label: 'Tous les matériaux' }, ...S.viewer.materials().map((m) => ({ value: m, label: m }))], E.uvMaterial || '', (v) => { E.uvMaterial = v; drawOverlay(); }) : null,
        h('p.help', 'Le patron vient des UV réels du modèle chargé. Sans modèle, la texture est affichée à plat.'),
        h('div.row', { style: { marginTop: '6px' } }, btn(E.refImage ? 'Changer l\'image de référence' : 'Image de référence…', async () => {
          const r = await api.dialogPickFiles({ multi: false, title: 'Image de référence (non exportée)', filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'tga', 'dds'] }] });
          if (!r.paths?.[0]) return;
          const d = await api.textureDecodeFile(r.paths[0]);
          if (!d.ok) return toast(d.error, 'error');
          E.refImage = canvasOf(new RGBAImage(d.width, d.height, d.data)); drawOverlay(); renderSide();
        }, { kind: 'small' }), E.refImage ? btn('Retirer', () => { E.refImage = null; drawOverlay(); renderSide(); }, { kind: 'small' }) : null),
        E.refImage ? h('div.slider-row', h('span', 'Opacité'), h('input', { type: 'range', min: 5, max: 100, value: E.refOpacity * 100, oninput: (e) => { E.refOpacity = Number(e.target.value) / 100; drawOverlay(); } }), h('output', '')) : null),
    );
  }
  function numField(label, value, apply) {
    return field(label, h('input.input', { type: 'number', step: 'any', value: Math.round(value * 100) / 100,
      onchange: (e) => { const v = Number(e.target.value); if (Number.isFinite(v)) change(() => apply(v)); } }));
  }

  function resizeDialog() {
    const st = { w: doc.width, h: doc.height };
    const sizes = [256, 512, 1024, 2048, 4096];
    modal({ title: 'Dimensions de la texture', body: h('div.form',
      h('p.muted', 'Les calques sont repositionnés et mis à l\'échelle (sans perte : les pixels d\'origine sont conservés jusqu\'à l\'export).'),
      h('div.row', field('Largeur', select(sizes.map((v) => ({ value: v, label: `${v} px` })), sizes.includes(st.w) ? st.w : 1024, (v) => { st.w = Number(v); })),
        field('Hauteur', select(sizes.map((v) => ({ value: v, label: `${v} px` })), sizes.includes(st.h) ? st.h : 1024, (v) => { st.h = Number(v); })))),
    actions: [{ label: 'Annuler' }, { label: 'Appliquer', kind: 'primary', onclick: () => { change(() => doc.resizeDocument(st.w || 1024, st.h || 1024)); fit(); } }] });
  }

  function exportDialog() {
    const st = { format: 'png', dds: 'auto', mipmaps: true, quality: 92 };
    const ddsBox = h('div');
    const renderDds = () => fill(ddsBox, ...(st.format === 'dds' ? [
      field('Compression', select([{ value: 'auto', label: 'Automatique (DXT1 sans transparence, DXT5 sinon)' }, { value: 'dxt1', label: 'DXT1 / BC1 (opaque, compact)' },
        { value: 'dxt5', label: 'DXT5 / BC3 (transparence progressive)' }, { value: 'bgra8', label: 'BGRA 8 bits (sans perte, 4× plus lourd)' }], st.dds, (v) => { st.dds = v; })),
      h('label.checkbox', h('input', { type: 'checkbox', checked: st.mipmaps, onchange: (e) => { st.mipmaps = e.target.checked; } }), 'Générer les mipmaps (recommandé pour le jeu)'),
      h('p.help', 'Le DDS est le format des textures dans un .ytd. La création du .ytd lui-même se fait avec un outil externe (voir Aide).')]
      : st.format === 'jpeg' ? [h('p.help', 'JPEG : perte de qualité et pas de transparence.')] : []));
    renderDds();
    modal({ title: 'Exporter la texture', body: h('div.form',
      field('Format', select([{ value: 'png', label: 'PNG (sans perte, transparence)' }, { value: 'tga', label: 'TGA 32 bits (sans perte, transparence)' },
        { value: 'dds', label: 'DDS (format du jeu)' }, { value: 'jpeg', label: 'JPEG (avec perte)' }], st.format, (v) => { st.format = v; renderDds(); })), ddsBox),
    actions: [{ label: 'Annuler' }, { label: 'Exporter…', kind: 'primary', onclick: async () => {
      const img = doc.composite();
      let out = img;
      if (st.format === 'dds' && st.dds !== 'bgra8' && (img.width % 4 || img.height % 4)) {
        toast('DXT exige des dimensions multiples de 4 : utilisez « Dimensions… » d\'abord.', 'error', 6000); return true;
      }
      const dds = { format: st.dds === 'auto' ? (img.hasAlpha() ? 'dxt5' : 'dxt1') : st.dds, mipmaps: st.mipmaps };
      const r = await api.textureExport({ name: doc.name, width: out.width, height: out.height, data: new Uint8Array(out.data.buffer), format: st.format, dds, quality: st.quality });
      if (!r.ok) return toast(r.error, 'error');
      if (r.path) { toast(`Exporté : ${r.path}`, 'success', 5000); for (const w of r.warnings || []) toast(w, 'warning', 6000); }
    } }] });
  }

  // ---------------------------------------------------------------- aperçu 3D en direct
  let liveTimer = null;
  function scheduleLive() {
    clearTimeout(liveTimer);
    liveTimer = setTimeout(() => E.onLiveUpdate?.(view), 300);
  }
  E.canvas = view;

  E.dispose = () => { state.ui.zoom = E.zoom; state.ui.panX = E.panX; state.ui.panY = E.panY; E.active = false; ro.disconnect(); document.removeEventListener('keydown', keyDown); document.removeEventListener('keyup', keyUp); clearTimeout(liveTimer); clearTimeout(previewTimer); };
  render(); renderSide();
  if (state.ui.zoom) { E.zoom = state.ui.zoom; E.panX = state.ui.panX; E.panY = state.ui.panY; requestAnimationFrame(layout); } else requestAnimationFrame(fit);
  return E;
}
