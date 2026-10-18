// Stockage des textures de travail (documents en calques) dans le projet :
//   textures/<id>/doc.json  +  textures/<id>/layers/<calque>.png  +  textures/<id>/preview.png
import fs from 'node:fs';
import path from 'node:path';
import { safeJoin, toPosix } from '../paths.js';
import { TextureDocument } from '../image/layers.js';
import { encodeImage, readImageFile } from '../image/codecs.js';
import { newId, addHistory } from './schema.js';
import { readYtd, decodeYtdTexture } from '../gta/ytd.js';
import { writeJsonAtomic } from './store.js';

/**
 * Enregistre un document. Écrit d'abord dans un dossier temporaire puis remplace
 * l'ancien : une coupure pendant l'enregistrement ne corrompt pas la version précédente.
 */
export function saveTextureDoc(dir, project, doc, { id, sourceAssetId = null } = {}) {
  let meta = id ? project.textureDocs.find((t) => t.id === id) : null;
  if (!meta) {
    meta = { id: id || newId(), name: doc.name, dir: '', sourceAssetId, createdAt: new Date().toISOString() };
    meta.dir = toPosix(path.join('textures', meta.id));
    project.textureDocs.push(meta);
    addHistory(project, `Texture créée : ${doc.name}`);
  }
  const target = safeJoin(dir, meta.dir);
  const tmp = `${target}.saving`;
  fs.rmSync(tmp, { recursive: true, force: true });
  fs.mkdirSync(path.join(tmp, 'layers'), { recursive: true });
  const { json, images } = doc.serialize();
  for (const [lid, img] of Object.entries(images)) fs.writeFileSync(path.join(tmp, 'layers', `${lid}.png`), encodeImage(img, { format: 'png' }).buffer);
  const preview = doc.composite();
  fs.writeFileSync(path.join(tmp, 'preview.png'), encodeImage(preview, { format: 'png' }).buffer);
  writeJsonAtomic(path.join(tmp, 'doc.json'), json);
  const old = `${target}.old`;
  fs.rmSync(old, { recursive: true, force: true });
  if (fs.existsSync(target)) fs.renameSync(target, old);
  fs.renameSync(tmp, target);
  fs.rmSync(old, { recursive: true, force: true });
  Object.assign(meta, { name: doc.name, width: doc.width, height: doc.height, layers: doc.layers.length, updatedAt: new Date().toISOString() });
  doc.dirty = false;
  return meta;
}

export function loadTextureDoc(dir, meta, opts = {}) {
  const base = safeJoin(dir, meta.dir);
  const json = JSON.parse(fs.readFileSync(path.join(base, 'doc.json'), 'utf8'));
  const images = {};
  for (const l of json.layers) images[l.id] = readImageFile(safeJoin(base, l.file)).image;
  return TextureDocument.deserialize(json, images, opts);
}

/** Nouveau document à partir d'une image importée (calque de fond = copie de l'original). */
export function textureDocFromAsset(dir, project, asset, opts = {}) {
  const { image } = readImageFile(safeJoin(dir, asset.file));
  const doc = new TextureDocument(image.width, image.height, { name: asset.name.replace(/\.[^.]+$/, ''), ...opts });
  doc.addLayer({ name: 'Original', image });
  doc.past = [];
  const meta = saveTextureDoc(dir, project, doc, { sourceAssetId: asset.id });
  return { doc, meta };
}

/** Nouveau document à partir d'une texture contenue dans un .ytd du projet. */
export function textureDocFromYtd(dir, project, asset, textureName, opts = {}) {
  const ytd = readYtd(fs.readFileSync(safeJoin(dir, asset.file)));
  const t = ytd.textures.find((x) => x.name === textureName) || ytd.textures.find((x) => /_diff/i.test(x.name)) || ytd.textures[0];
  const image = decodeYtdTexture(ytd, t.name);
  const doc = new TextureDocument(image.width, image.height, { name: t.name, ...opts });
  doc.addLayer({ name: `Original (${t.format.toUpperCase()})`, image });
  doc.past = [];
  const meta = saveTextureDoc(dir, project, doc, { sourceAssetId: asset.id });
  meta.source = { type: 'ytd', assetId: asset.id, textureName: t.name, format: t.format, width: t.width, height: t.height, levels: t.levels };
  return { doc, meta };
}
