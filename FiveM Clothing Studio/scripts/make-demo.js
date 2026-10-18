// Génère le projet de démonstration et l'exemple d'export (examples/).
// Toutes les ressources sont CRÉÉES ici (motif, logo, modèle 3D simple) : aucun fichier du jeu,
// aucun contenu de tiers. L'export obtenu est volontairement « incomplet » : il montre la
// structure générée et l'étape de conversion .ytd qui reste à faire avec un outil externe.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { RGBAImage } from '../src/core/image/rgba.js';
import { encodeImage } from '../src/core/image/codecs.js';
import * as store from '../src/core/project/store.js';
import { newId } from '../src/core/project/schema.js';
import { textureDocFromAsset, saveTextureDoc } from '../src/core/project/textures.js';
import { exportResource } from '../src/core/export/exporter.js';
import { loadDefaults } from '../src/core/config.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const EX = path.join(ROOT, 'examples');
const SRC = path.join(EX, 'demo-sources');
for (const d of ['demo-project', 'demo-export', 'demo-sources']) fs.rmSync(path.join(EX, d), { recursive: true, force: true });
fs.mkdirSync(SRC, { recursive: true });

// 1. Motif de tissu 512×512 (rayures + bruit léger)
const base = new RGBAImage(512, 512);
for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) {
  const i = (y * 512 + x) * 4, stripe = Math.floor(y / 32) % 2, n = ((x * 7919 + y * 104729) % 23) - 11;
  base.data.set(stripe ? [40 + n, 70 + n, 140 + n, 255] : [235 + n / 2, 235 + n / 2, 240 + n / 2, 255], i);
}
fs.writeFileSync(path.join(SRC, 'tissu_rayures.png'), encodeImage(base, { format: 'png' }).buffer);
// 2. Logo 128×128 transparent (anneau + barre)
const logo = new RGBAImage(128, 128);
for (let y = 0; y < 128; y++) for (let x = 0; x < 128; x++) {
  const r = Math.hypot(x - 64, y - 64), ring = r > 40 && r < 56, bar = Math.abs(y - 64) < 8 && Math.abs(x - 64) < 44;
  if (ring || bar) logo.data.set([240, 180, 40, 255], (y * 128 + x) * 4);
}
fs.writeFileSync(path.join(SRC, 'logo_demo.png'), encodeImage(logo, { format: 'png' }).buffer);
// 3. Modèle 3D simple : un cylindre ouvert (« torse ») avec UV, en GLB
function cylinderGlb(segments = 32, radius = 0.25, height = 0.6) {
  const pos = [], uv = [], nor = [], idx = [];
  for (let r = 0; r <= 1; r++) for (let s = 0; s <= segments; s++) {
    const a = (s / segments) * Math.PI * 2;
    pos.push(Math.cos(a) * radius, 0.9 + r * height, Math.sin(a) * radius);
    nor.push(Math.cos(a), 0, Math.sin(a));
    uv.push(s / segments, 1 - r);
  }
  for (let s = 0; s < segments; s++) { const a = s, b = s + 1, c = s + segments + 1, d = s + segments + 2; idx.push(a, c, b, b, c, d); }
  const P = Buffer.from(new Float32Array(pos).buffer), N = Buffer.from(new Float32Array(nor).buffer), U = Buffer.from(new Float32Array(uv).buffer), I = Buffer.from(new Uint16Array(idx).buffer);
  const pad = (b) => Buffer.concat([b, Buffer.alloc((4 - (b.length % 4)) % 4)]);
  const bin = Buffer.concat([pad(P), pad(N), pad(U), pad(I)]);
  let o = 0; const view = (b) => { const v = { buffer: 0, byteOffset: o, byteLength: b.length }; o += pad(b).length; return v; };
  const json = { asset: { version: '2.0', generator: 'FiveM Clothing Studio – démo' },
    buffers: [{ byteLength: bin.length }], bufferViews: [view(P), view(N), view(U), view(I)],
    accessors: [{ bufferView: 0, componentType: 5126, count: pos.length / 3, type: 'VEC3', min: [-radius, 0.9, -radius], max: [radius, 0.9 + height, radius] },
      { bufferView: 1, componentType: 5126, count: nor.length / 3, type: 'VEC3' }, { bufferView: 2, componentType: 5126, count: uv.length / 2, type: 'VEC2' },
      { bufferView: 3, componentType: 5123, count: idx.length, type: 'SCALAR' }],
    materials: [{ name: 'Tissu', pbrMetallicRoughness: { metallicFactor: 0, roughnessFactor: 0.9 }, doubleSided: true }],
    meshes: [{ name: 'Torse', primitives: [{ attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2 }, indices: 3, material: 0 }] }],
    nodes: [{ mesh: 0, name: 'Torse' }], scenes: [{ nodes: [0] }], scene: 0 };
  let j = Buffer.from(JSON.stringify(json)); j = Buffer.concat([j, Buffer.alloc((4 - (j.length % 4)) % 4, 0x20)]);
  const head = Buffer.alloc(12); head.write('glTF'); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + j.length + 8 + bin.length, 8);
  const ch = (len, type) => { const c = Buffer.alloc(8); c.writeUInt32LE(len); c.writeUInt32LE(type, 4); return c; };
  return Buffer.concat([head, ch(j.length, 0x4e4f534a), j, ch(bin.length, 0x004e4942), bin]);
}
fs.writeFileSync(path.join(SRC, 'torse_demo.glb'), cylinderGlb());

// 4. Projet
fs.mkdirSync(path.join(EX, 'demo-project'), { recursive: true });
const { dir, project } = store.createProject(path.join(EX, 'demo-project'), 'Démo T-shirt rayé', { peds: ['mp_m_freemode_01'], description: 'Projet de démonstration créé avec des ressources générées (aucun fichier du jeu).', appVersion: '0.1.0' });
const imp = (name, kind, format) => {
  const { asset } = store.importAsset(dir, project, path.join(SRC, name), { kind, format, info: { summary: 'Fichier de démonstration généré', status: { readable: true, viewable: true, editable: true, convertible: kind === 'texture', exportable: false } } });
  asset.originalPath = null;
  return asset;
};
const tex = imp('tissu_rayures.png', 'texture', 'png');
const lg = imp('logo_demo.png', 'texture', 'png');
const model = imp('torse_demo.glb', 'model', 'glb');
const { doc, meta } = textureDocFromAsset(dir, project, tex);
doc.name = 'T-shirt rayé (logo)';
doc.addLayer({ name: 'Logo', image: logo, x: 192, y: 140, scale: 1, rotation: -8, opacity: 0.95 });
saveTextureDoc(dir, project, doc, { id: meta.id });
project.garments.push({ id: newId(), name: 'T-shirt rayé', description: 'Démonstration', category: 'T-shirts', ped: 'mp_m_freemode_01', kind: 'component', slot: 'jbib',
  drawableIndex: 0, yddAssetId: null, modelAssetId: model.id, materials: [{ name: 'Tissu', textureDocId: meta.id }],
  variants: [{ id: newId(), name: 'Rayé bleu', letter: 'a', ytdAssetId: null, textureDocId: meta.id }] });
project.exportSettings = { packName: 'Démo T-shirt rayé', resourceName: 'demo_tshirt_raye', mode: 'replace', destination: '', collections: {} };
store.saveProject(dir, project);
store.closeProject(dir);
void lg;

// 5. Exemple d'export (incomplet : texture à convertir en .ytd)
fs.mkdirSync(path.join(EX, 'demo-export'), { recursive: true });
const r = await exportResource({ dir, project, destination: path.join(EX, 'demo-export'), allowIncomplete: true, config: loadDefaults(), appVersion: '0.1.0' });
console.log(`Projet : ${dir}\nExport : ${r.path} (${r.status})\nÀ convertir : ${r.convertPath}`);
