// Document de texture en calques, avec annuler / rétablir. Module PUR.
// Les images des calques sont traitées comme IMMUABLES : chaque modification remplace
// l'image du calque par une nouvelle. Un instantané d'historique ne copie donc que
// la liste des calques (références), ce qui reste léger même sur des textures 4K.
import { RGBAImage, ImageError } from './rgba.js';
import { drawImage } from './ops.js';

let seq = 0;
const newLayerId = () => `L${Date.now().toString(36)}${(seq++).toString(36)}`;

export const LAYER_DEFAULTS = { x: 0, y: 0, scale: 1, rotation: 0, opacity: 1, visible: true };

export class TextureDocument {
  constructor(width, height, { name = 'Texture', undoSteps = 40 } = {}) {
    if (!(width > 0 && height > 0)) throw new ImageError('Dimensions de document invalides.');
    this.width = width;
    this.height = height;
    this.name = name;
    this.layers = [];          // index 0 = calque du fond
    this.undoSteps = undoSteps;
    this.past = [];
    this.future = [];
    this.dirty = false;
  }

  // -------------------------------------------------------------- historique
  #state() { return { width: this.width, height: this.height, layers: this.layers.map((l) => ({ ...l })) }; }
  #restore(s) { this.width = s.width; this.height = s.height; this.layers = s.layers.map((l) => ({ ...l })); }

  /** Exécute `fn` comme UNE action annulable. */
  transaction(label, fn) {
    const before = this.#state();
    const res = fn();
    this.past.push({ label, state: before });
    if (this.past.length > this.undoSteps) this.past.shift();
    this.future = [];
    this.dirty = true;
    return res;
  }
  get canUndo() { return this.past.length > 0; }
  get canRedo() { return this.future.length > 0; }
  get undoLabel() { return this.past.at(-1)?.label ?? null; }
  get redoLabel() { return this.future.at(-1)?.label ?? null; }
  undo() {
    const step = this.past.pop();
    if (!step) return false;
    this.future.push({ label: step.label, state: this.#state() });
    this.#restore(step.state);
    this.dirty = true;
    return true;
  }
  redo() {
    const step = this.future.pop();
    if (!step) return false;
    this.past.push({ label: step.label, state: this.#state() });
    this.#restore(step.state);
    this.dirty = true;
    return true;
  }

  // -------------------------------------------------------------- calques
  layer(id) {
    const l = this.layers.find((x) => x.id === id);
    if (!l) throw new ImageError('Calque introuvable.');
    return l;
  }
  index(id) { return this.layers.findIndex((x) => x.id === id); }

  addLayer({ name = 'Calque', image, ...props } = {}, at = this.layers.length) {
    if (!(image instanceof RGBAImage)) image = new RGBAImage(this.width, this.height);
    const l = { ...LAYER_DEFAULTS, ...props, id: newLayerId(), name: String(name), image };
    return this.transaction(`Ajouter « ${l.name} »`, () => { this.layers.splice(at, 0, l); return l.id; });
  }

  removeLayer(id) {
    const i = this.index(id);
    if (i < 0) throw new ImageError('Calque introuvable.');
    this.transaction(`Supprimer « ${this.layers[i].name} »`, () => this.layers.splice(i, 1));
  }

  duplicateLayer(id) {
    const i = this.index(id);
    const src = this.layer(id);
    const copy = { ...src, id: newLayerId(), name: `${src.name} (copie)` };
    return this.transaction(`Dupliquer « ${src.name} »`, () => { this.layers.splice(i + 1, 0, copy); return copy.id; });
  }

  /** Déplace un calque à l'index `to` (0 = tout en bas). */
  moveLayer(id, to) {
    const i = this.index(id);
    to = Math.max(0, Math.min(this.layers.length - 1, to));
    if (i < 0 || i === to) return;
    this.transaction(`Déplacer « ${this.layers[i].name} »`, () => {
      const [l] = this.layers.splice(i, 1);
      this.layers.splice(to, 0, l);
    });
  }
  moveUp(id) { this.moveLayer(id, this.index(id) + 1); }
  moveDown(id) { this.moveLayer(id, this.index(id) - 1); }

  /** Propriétés : name, x, y, scale, rotation, opacity (0…1), visible, meta. */
  updateLayer(id, patch, label = 'Modifier le calque') {
    const i = this.index(id);
    if (i < 0) throw new ImageError('Calque introuvable.');
    const allowed = ['name', 'x', 'y', 'scale', 'rotation', 'opacity', 'visible', 'meta'];
    const clean = Object.fromEntries(Object.entries(patch).filter(([k]) => allowed.includes(k)));
    if ('opacity' in clean) clean.opacity = Math.max(0, Math.min(1, Number(clean.opacity)));
    this.transaction(label, () => { this.layers[i] = { ...this.layers[i], ...clean }; });
  }

  /** Remplace l'image d'un calque par fn(image) (opération de retouche). */
  applyToLayer(id, label, fn) {
    const i = this.index(id);
    if (i < 0) throw new ImageError('Calque introuvable.');
    const img = fn(this.layers[i].image);
    if (!(img instanceof RGBAImage)) throw new ImageError('Opération invalide.');
    this.transaction(label, () => { this.layers[i] = { ...this.layers[i], image: img }; });
  }

  /** Recadre le DOCUMENT : les calques sont décalés, leurs pixels ne sont pas détruits. */
  cropDocument(x, y, w, h) {
    x = Math.round(x); y = Math.round(y); w = Math.round(w); h = Math.round(h);
    if (w < 1 || h < 1) throw new ImageError('Zone de recadrage vide.');
    this.transaction('Recadrer', () => {
      this.width = w; this.height = h;
      this.layers = this.layers.map((l) => ({ ...l, x: l.x - x, y: l.y - y }));
    });
  }

  /** Redimensionne le DOCUMENT : positions et échelles des calques suivent (non destructif). */
  resizeDocument(w, h) {
    w = Math.round(w); h = Math.round(h);
    if (w < 1 || h < 1 || w > 8192 || h > 8192) throw new ImageError('Dimensions invalides.');
    const kx = w / this.width, ky = h / this.height, k = Math.min(kx, ky);
    this.transaction(`Redimensionner en ${w} × ${h}`, () => {
      this.width = w; this.height = h;
      this.layers = this.layers.map((l) => ({ ...l, x: l.x * kx, y: l.y * ky, scale: l.scale * k }));
    });
  }

  // -------------------------------------------------------------- rendu
  composite({ background = null } = {}) {
    const out = background ? RGBAImage.filled(this.width, this.height, background) : new RGBAImage(this.width, this.height);
    for (const l of this.layers) {
      if (!l.visible || l.opacity <= 0) continue;
      const simple = l.x === 0 && l.y === 0 && l.scale === 1 && l.rotation === 0 && l.opacity === 1
        && l.image.width === this.width && l.image.height === this.height;
      if (simple && !background && l === this.layers.find((z) => z.visible && z.opacity > 0)) {
        out.data.set(l.image.data);  // premier calque visible plein cadre : copie directe
        continue;
      }
      drawImage(out, l.image, { x: l.x, y: l.y, scale: l.scale, rotation: l.rotation, opacity: l.opacity });
    }
    return out;
  }

  // -------------------------------------------------------------- persistance
  /** JSON du document + images à enregistrer séparément (PNG par calque). */
  serialize() {
    return {
      json: {
        type: 'fcs-texture-document', version: 1, name: this.name, width: this.width, height: this.height,
        layers: this.layers.map(({ image, ...rest }) => ({ ...rest, file: `layers/${rest.id}.png`, w: image.width, h: image.height })),
      },
      images: Object.fromEntries(this.layers.map((l) => [l.id, l.image])),
    };
  }

  static deserialize(json, images, opts = {}) {
    if (json?.type !== 'fcs-texture-document') throw new ImageError('Document de texture invalide.');
    const doc = new TextureDocument(json.width, json.height, { name: json.name, ...opts });
    doc.layers = json.layers.map((l) => {
      const img = images[l.id];
      if (!(img instanceof RGBAImage)) throw new ImageError(`Image du calque « ${l.name} » manquante.`);
      const { file, w, h, ...rest } = l;
      return { ...LAYER_DEFAULTS, ...rest, image: img };
    });
    return doc;
  }
}
