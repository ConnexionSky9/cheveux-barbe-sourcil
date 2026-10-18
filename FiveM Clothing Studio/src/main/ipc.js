// Fonctions exposées à l'interface (ipcMain.handle). Chaque appel est journalisé en cas
// d'erreur et renvoie { ok, ... } ou { ok: false, error } : l'interface n'a jamais à
// deviner ce qui s'est passé.
import { ipcMain, dialog, shell } from 'electron';
import fs from 'node:fs';
import path from 'node:path';
import * as store from '../core/project/store.js';
import { PROJECT_EXT, addHistory, newId } from '../core/project/schema.js';
import { saveTextureDoc, loadTextureDoc, textureDocFromAsset } from '../core/project/textures.js';
import { inspectFile } from '../core/importer.js';
import { readImageFile, encodeImage } from '../core/image/codecs.js';
import { RGBAImage } from '../core/image/rgba.js';
import { TextureDocument } from '../core/image/layers.js';
import { validateExport } from '../core/export/validate.js';
import { exportResource } from '../core/export/exporter.js';
import { detectTools } from '../core/tools.js';
import { saveUserConfig, loadConfig } from '../core/config.js';
import { safeJoin, safeFileName, isInside } from '../core/paths.js';

// ------------------------------------------------------------------ conversions
export function docToPayload(doc) {
  return { name: doc.name, width: doc.width, height: doc.height,
    layers: doc.layers.map(({ image, ...l }) => ({ ...l, w: image.width, h: image.height, data: new Uint8Array(image.data.buffer, image.data.byteOffset, image.data.byteLength) })) };
}
export function payloadToDoc(p, opts) {
  const images = {};
  for (const l of p.layers) images[l.id] = new RGBAImage(l.w, l.h, l.data);
  return TextureDocument.deserialize({ type: 'fcs-texture-document', version: 1, name: p.name, width: p.width, height: p.height,
    layers: p.layers.map(({ data, ...l }) => l) }, images, opts);
}

export function registerIpc(ctx) {
  const { logger } = ctx;
  const state = { dir: null, exportSignal: null };
  const recentFile = () => path.join(ctx.userData(), 'recent.json');
  const readRecent = () => { try { return JSON.parse(fs.readFileSync(recentFile(), 'utf8')); } catch { return []; } };
  const pushRecent = (dir, name) => {
    const list = [{ dir, name, openedAt: new Date().toISOString() }, ...readRecent().filter((r) => r.dir !== dir)].slice(0, 12);
    store.writeJsonAtomic(recentFile(), list);
  };
  const needProject = () => { if (!state.dir) throw new Error('Aucun projet ouvert.'); return state.dir; };

  const handle = (channel, fn) => ipcMain.handle(channel, async (_e, ...args) => {
    try { return { ok: true, ...(await fn(...args)) }; }
    catch (e) {
      logger.error(`${channel} : ${e.message}`, e.details ? { details: e.details } : e);
      return { ok: false, error: e.message, code: e.code, details: e.details, exists: e.exists };
    }
  });

  // ---------------------------------------------------------------- application
  handle('app:info', () => ({ appName: ctx.config.appName, version: ctx.appVersion, config: ctx.config, platform: process.platform,
    logsDir: path.join(ctx.userData(), 'logs'), configFile: ctx.configFile, recent: readRecent().filter((r) => fs.existsSync(r.dir)) }));
  handle('app:events', () => ({ events: logger.recent.slice(-40).reverse() }));

  // ---------------------------------------------------------------- dialogues
  handle('dialog:pickDir', async (title = 'Choisir un dossier') => {
    const r = await dialog.showOpenDialog(ctx.window, { title, properties: ['openDirectory', 'createDirectory'] });
    return { path: r.canceled ? null : r.filePaths[0] };
  });
  handle('dialog:pickFiles', async (opts = {}) => {
    const r = await dialog.showOpenDialog(ctx.window, { title: opts.title || 'Choisir des fichiers', properties: ['openFile', ...(opts.multi === false ? [] : ['multiSelections'])],
      filters: opts.filters || [{ name: 'Fichiers pris en charge', extensions: ['png', 'jpg', 'jpeg', 'tga', 'dds', 'obj', 'mtl', 'gltf', 'glb', 'fbx', 'ydd', 'ytd', 'ymt', 'meta'] }, { name: 'Tous les fichiers', extensions: ['*'] }] });
    return { paths: r.canceled ? [] : r.filePaths };
  });
  handle('dialog:openProject', async () => {
    const r = await dialog.showOpenDialog(ctx.window, { title: 'Ouvrir un projet', properties: ['openFile'], filters: [{ name: 'Projet FiveM Clothing Studio', extensions: ['json'] }],
      message: `Choisissez le fichier project.json dans un dossier ${PROJECT_EXT}` });
    return { dir: r.canceled ? null : path.dirname(r.filePaths[0]) };
  });
  handle('dialog:confirm', async ({ title, message, detail, ok = 'Confirmer', danger = false }) => {
    const r = await dialog.showMessageBox(ctx.window, { type: danger ? 'warning' : 'question', title, message, detail, buttons: [ok, 'Annuler'], defaultId: 1, cancelId: 1, noLink: true });
    return { confirmed: r.response === 0 };
  });

  // ---------------------------------------------------------------- projets
  const opened = (o) => {
    state.dir = o.dir;
    pushRecent(o.dir, o.project.name);
    logger.info(`Projet ouvert : ${o.project.name}`, { dir: o.dir });
    return { dir: o.dir, project: o.project, recovery: o.recovery ?? null, missing: o.missing ?? [], migrated: o.migrated ?? false };
  };
  handle('project:create', ({ parent, name, peds, description, template }) => {
    if (state.dir) store.closeProject(state.dir, { keepAutosave: true });
    if (template) {
      const tpl = safeJoin(path.join(ctx.userData(), 'templates'), template);
      const dir = path.join(parent, safeFileName(name) + PROJECT_EXT);
      if (fs.existsSync(dir)) throw new Error(`« ${path.basename(dir)} » existe déjà.`);
      fs.cpSync(tpl, dir, { recursive: true });
      const p = store.openProject(dir, { lock: false }).project;
      Object.assign(p, { id: newId(), name, description: description ?? p.description, createdAt: new Date().toISOString() });
      p.exportSettings.packName = name;
      addHistory(p, 'Projet créé depuis un modèle');
      store.saveProject(dir, p);
      return opened(store.openProject(dir));
    }
    const c = store.createProject(parent, name, { peds, description, appVersion: ctx.appVersion });
    return opened(store.openProject(c.dir));
  });
  handle('project:open', (dir) => {
    if (state.dir && state.dir !== dir) store.closeProject(state.dir, { keepAutosave: true });
    return opened(store.openProject(dir));
  });
  handle('project:save', (project) => ({ savedAt: store.saveProject(needProject(), project) }));
  handle('project:autosave', (project) => ({ savedAt: store.autosaveProject(needProject(), project) }));
  handle('project:recover', () => ({ project: store.recoverAutosave(needProject()) }));
  handle('project:close', ({ discardAutosave = true, quitting = false } = {}) => {
    if (state.dir) store.closeProject(state.dir, { keepAutosave: !discardAutosave });
    state.dir = null;
    if (quitting) { ctx.allowClose = true; setImmediate(() => ctx.window?.close()); }
    return {};
  });
  handle('project:duplicate', (name) => {
    const r = store.duplicateProject(needProject(), name);
    return { dir: r.dir };
  });
  handle('project:rename', (name) => {
    const dir = needProject();
    store.closeProject(dir, { keepAutosave: false });
    const r = store.renameProject(dir, name);
    const o = store.openProject(r.dir);
    state.dir = r.dir;
    const list = readRecent().filter((x) => x.dir !== dir);
    store.writeJsonAtomic(recentFile(), list);
    return opened(o);
  });
  handle('project:delete', async (dir) => {
    if (!store.isProjectDir(dir)) throw new Error('Ce dossier n\'est pas un projet.');
    const r = await dialog.showMessageBox(ctx.window, { type: 'warning', title: 'Supprimer le projet', message: `Supprimer le projet « ${path.basename(dir)} » ?`,
      detail: 'Le dossier du projet sera placé dans la Corbeille. Les fichiers d\'origine que vous aviez importés ne sont pas touchés.', buttons: ['Mettre à la corbeille', 'Annuler'], defaultId: 1, cancelId: 1 });
    if (r.response !== 0) return { deleted: false };
    if (state.dir === dir) { store.closeProject(dir); state.dir = null; }
    try { await shell.trashItem(dir); } catch { store.deleteProject(dir); }
    store.writeJsonAtomic(recentFile(), readRecent().filter((x) => x.dir !== dir));
    logger.info('Projet supprimé', { dir });
    return { deleted: true };
  });
  handle('project:saveTemplate', (name) => {
    const dir = needProject();
    const target = path.join(ctx.userData(), 'templates', safeFileName(name) + PROJECT_EXT);
    if (fs.existsSync(target)) throw new Error('Un modèle porte déjà ce nom.');
    fs.cpSync(dir, target, { recursive: true, filter: (s) => !['.lock', 'autosave.json'].includes(path.basename(s)) });
    return { template: path.basename(target) };
  });
  handle('project:templates', () => {
    const base = path.join(ctx.userData(), 'templates');
    return { templates: fs.readdirSync(base).filter((d) => d.endsWith(PROJECT_EXT) && store.isProjectDir(path.join(base, d))) };
  });
  handle('recent:list', () => ({ recent: readRecent().map((r) => ({ ...r, exists: fs.existsSync(r.dir) })) }));
  handle('recent:remove', (dir) => { store.writeJsonAtomic(recentFile(), readRecent().filter((r) => r.dir !== dir)); return {}; });

  // ---------------------------------------------------------------- import
  handle('import:inspect', (paths) => ({ reports: paths.map((p) => inspectFile(p, { limits: ctx.config.limits })) }));
  handle('import:add', ({ project, path: file }) => {
    const dir = needProject();
    const rep = inspectFile(file, { limits: ctx.config.limits });
    if (rep.issues.some((i) => i.level === 'error') && rep.family !== 'gta') throw new Error(rep.issues.find((i) => i.level === 'error').message);
    if (rep.family === 'gta' && !rep.status.readable) throw new Error(rep.issues.find((i) => i.level === 'error')?.message || 'Fichier illisible.');
    const { asset, duplicate } = store.importAsset(dir, project, file, { kind: rep.kind, format: rep.format,
      info: { role: rep.role, status: rep.status, summary: summarize(rep), issues: rep.issues, garment: rep.info?.garment ?? null }, maxBytes: ctx.config.limits.maxImportBytes });
    logger.info(`Import ${duplicate ? '(déjà présent) ' : ''}: ${asset.name}`);
    return { project, asset, duplicate };
  });

  // ---------------------------------------------------------------- textures
  const undoSteps = () => ctx.config.undoSteps ?? 40;
  handle('texture:fromAsset', ({ project, assetId }) => {
    const dir = needProject();
    const asset = project.assets.find((a) => a.id === assetId);
    if (!asset) throw new Error('Fichier introuvable dans le projet.');
    const { doc, meta } = textureDocFromAsset(dir, project, asset, { undoSteps: undoSteps() });
    return { project, meta, doc: docToPayload(doc) };
  });
  handle('texture:blank', ({ project, name, width, height, color }) => {
    const dir = needProject();
    const doc = new TextureDocument(width, height, { name, undoSteps: undoSteps() });
    doc.addLayer({ name: 'Fond', image: color ? RGBAImage.filled(width, height, color) : new RGBAImage(width, height) });
    const meta = saveTextureDoc(dir, project, doc);
    return { project, meta, doc: docToPayload(doc) };
  });
  handle('texture:load', ({ project, id }) => {
    const meta = project.textureDocs.find((t) => t.id === id);
    if (!meta) throw new Error('Texture introuvable.');
    return { meta, doc: docToPayload(loadTextureDoc(needProject(), meta)) };
  });
  handle('texture:save', ({ project, id, doc }) => {
    const meta = saveTextureDoc(needProject(), project, payloadToDoc(doc), { id });
    return { project, meta };
  });
  handle('texture:delete', ({ project, id }) => {
    const dir = needProject();
    const meta = project.textureDocs.find((t) => t.id === id);
    if (!meta) return { project };
    for (const g of project.garments) for (const v of g.variants || []) if (v.textureDocId === id) v.textureDocId = null;
    project.textureDocs = project.textureDocs.filter((t) => t.id !== id);
    const target = safeJoin(dir, meta.dir);
    if (isInside(path.join(dir, 'textures'), target)) fs.rmSync(target, { recursive: true, force: true });
    addHistory(project, `Texture supprimée : ${meta.name}`);
    return { project };
  });
  handle('texture:decodeFile', (file) => {
    const rep = inspectFile(file, { limits: ctx.config.limits });
    if (rep.kind !== 'texture' || !rep.status.editable) throw new Error(rep.issues.find((i) => i.level === 'error')?.message || 'Ce fichier n\'est pas une image utilisable.');
    const { image } = readImageFile(file);
    return { name: path.basename(file), width: image.width, height: image.height, data: new Uint8Array(image.data.buffer) };
  });
  handle('texture:decodeAsset', ({ project, assetId }) => {
    const a = project.assets.find((x) => x.id === assetId);
    if (!a) throw new Error('Fichier introuvable dans le projet.');
    const { image } = readImageFile(store.assetPath(needProject(), a));
    return { name: a.name, width: image.width, height: image.height, data: new Uint8Array(image.data.buffer) };
  });
  handle('texture:export', async ({ name, width, height, data, format, dds, quality }) => {
    const ext = format === 'jpeg' ? 'jpg' : format;
    const r = await dialog.showSaveDialog(ctx.window, { title: 'Exporter la texture', defaultPath: `${safeFileName(name)}.${ext}`,
      filters: [{ name: format.toUpperCase(), extensions: [ext] }] });
    if (r.canceled) return { path: null };
    const out = encodeImage(new RGBAImage(width, height, data), { format, dds, quality });
    const tmp = `${r.filePath}.tmp`;
    fs.writeFileSync(tmp, out.buffer);
    fs.renameSync(tmp, r.filePath);
    logger.info(`Texture exportée : ${r.filePath}`);
    return { path: r.filePath, warnings: out.warnings, lossy: out.lossy, bytes: out.buffer.length };
  });

  // ---------------------------------------------------------------- modèles
  handle('model:load', ({ project, assetId }) => {
    const dir = needProject();
    const a = project.assets.find((x) => x.id === assetId);
    if (!a) throw new Error('Modèle introuvable dans le projet.');
    const file = store.assetPath(dir, a);
    const buf = fs.readFileSync(file);
    // Fichiers voisins (MTL, textures, .bin) : servis depuis le dossier d'origine s'il existe encore
    const baseDir = a.originalPath && fs.existsSync(path.dirname(a.originalPath)) ? path.dirname(a.originalPath) : path.dirname(file);
    return { name: a.name, format: a.format, data: new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength), companions: readCompanions(buf, a.format, baseDir, logger) };
  });
  handle('asset:remove', ({ project, assetId }) => {
    const dir = needProject();
    const a = project.assets.find((x) => x.id === assetId);
    if (!a) return { project };
    const file = store.assetPath(dir, a);
    // Seule la COPIE interne au projet est supprimée, jamais le fichier d'origine
    if (isInside(path.join(dir, 'assets'), file) || isInside(path.join(dir, 'models'), file)) fs.rmSync(file, { force: true });
    project.assets = project.assets.filter((x) => x.id !== assetId);
    for (const g of project.garments) {
      if (g.yddAssetId === assetId) g.yddAssetId = null;
      if (g.modelAssetId === assetId) g.modelAssetId = null;
      for (const v of g.variants || []) if (v.ytdAssetId === assetId) v.ytdAssetId = null;
    }
    for (const c of Object.values(project.exportSettings.collections || {})) {
      if (c.ymtAssetId === assetId) c.ymtAssetId = null;
      if (c.metaAssetId === assetId) c.metaAssetId = null;
    }
    for (const k of Object.keys(project.referenceModels || {})) if (project.referenceModels[k] === assetId) delete project.referenceModels[k];
    addHistory(project, `Fichier retiré du projet : ${a.name}`);
    return { project };
  });
  handle('model:saveWork', ({ project, name, data }) => {
    const dir = needProject();
    const tmp = path.join(dir, 'models', `${safeFileName(name)}.glb`);
    fs.writeFileSync(tmp, Buffer.from(data));
    const { asset } = store.importAsset(dir, project, tmp, { kind: 'model', format: 'glb', info: { role: 'work', summary: 'Copie de travail GLB' } });
    fs.rmSync(tmp, { force: true });
    return { project, asset };
  });

  // ---------------------------------------------------------------- export
  handle('export:validate', ({ project, settings }) => validateExport(needProject(), project, settings, { limits: ctx.config.limits }));
  handle('export:run', async ({ project, settings, destination, overwrite, allowIncomplete }) => {
    const signal = { cancelled: false };
    state.exportSignal = signal;
    try {
      const r = await exportResource({ dir: needProject(), project, settings, destination, overwrite, allowIncomplete, signal,
        config: ctx.config, appVersion: ctx.appVersion, onProgress: (step, ratio) => ctx.window?.webContents.send('export:progress', { step, ratio }) });
      const rel = `reports/export-${Date.now()}.json`;
      fs.writeFileSync(safeJoin(needProject(), rel), JSON.stringify(r, null, 2));
      project.reports.push({ t: r.generatedAt, file: rel, status: r.status, resource: r.resourceName });
      addHistory(project, `Export « ${r.resourceName} » (${r.status})`);
      logger.info(`Export réussi : ${r.path} (${r.status})`);
      return { result: r, project };
    } finally { state.exportSignal = null; }
  });
  handle('export:cancel', () => { if (state.exportSignal) state.exportSignal.cancelled = true; return {}; });

  // ---------------------------------------------------------------- outils, config, docs
  handle('tools:detect', async () => ({ tools: await detectTools(ctx.config.tools) }));
  handle('config:get', () => ({ config: ctx.config, file: ctx.configFile }));
  handle('config:set', (cfg) => {
    saveUserConfig(ctx.configFile, cfg);
    ctx.config = loadConfig(ctx.configFile, logger);
    return { config: ctx.config };
  });
  handle('config:openFile', async () => { await shell.openPath(ctx.configFile); return {}; });
  handle('shell:openPath', async (p) => {
    if (!p || !fs.existsSync(p)) throw new Error('Chemin introuvable.');
    const err = await shell.openPath(p);
    if (err) throw new Error(err);
    return {};
  });
  handle('shell:openExternal', async (url) => {
    if (!/^https:\/\/[\w.-]+\//.test(url)) throw new Error('Lien refusé.');
    await shell.openExternal(url);
    return {};
  });
  handle('docs:read', (name) => {
    const allowed = ['GUIDE_UTILISATEUR.md', 'FORMATS.md', 'INSTALLATION_FIVEM.md', 'GUIDE_DEVELOPPEUR.md', 'RAPPORT_TESTS.md'];
    if (!allowed.includes(name)) throw new Error('Document inconnu.');
    return { text: fs.readFileSync(path.join(ctx.root, 'docs', name), 'utf8') };
  });
}

/**
 * Fichiers voisins référencés par un modèle (MTL et ses textures, .bin et images d'un glTF),
 * lus dans le dossier d'origine : jamais en dehors de ce dossier, 64 Mo maximum chacun.
 */
function readCompanions(buf, format, baseDir, logger) {
  const refs = new Set();
  try {
    if (format === 'obj') {
      for (const m of buf.toString('utf8').matchAll(/^\s*mtllib\s+(.+?)\s*$/gm)) refs.add(m[1]);
      for (const mtl of [...refs]) {
        try {
          const txt = fs.readFileSync(safeJoin(baseDir, mtl), 'utf8');
          for (const m of txt.matchAll(/^\s*(?:map_Kd|map_Ka|map_Ks|map_Bump|bump|map_d|norm)\s+(?:-\S+\s+\S+\s+)*(.+?)\s*$/gim)) refs.add(m[1]);
        } catch { /* MTL absent : signalé par le visualiseur */ }
      }
    } else if (format === 'gltf') {
      const j = JSON.parse(buf.toString('utf8'));
      for (const b of [...(j.buffers || []), ...(j.images || [])]) if (b.uri && !b.uri.startsWith('data:')) refs.add(decodeURIComponent(b.uri));
    }
  } catch (e) { logger.warn('Analyse des fichiers voisins impossible', e); }
  const out = {};
  for (const r of refs) {
    try {
      const p = safeJoin(baseDir, r);
      if (fs.existsSync(p) && fs.statSync(p).size <= 64 * 1048576) { const b = fs.readFileSync(p); out[r.replace(/\\/g, '/')] = new Uint8Array(b.buffer, b.byteOffset, b.byteLength); }
    } catch { /* chemin refusé (hors dossier) : ignoré */ }
  }
  return out;
}

function summarize(rep) {
  const i = rep.info || {};
  if (rep.kind === 'texture') return `${i.width} × ${i.height}${i.ddsFormat ? ` · ${i.ddsFormat.toUpperCase()} · ${i.mipCount} mipmap(s)` : ''}${i.hasAlphaChannel ? ' · alpha' : ''}`;
  if (rep.kind === 'model') return `${(i.format || '').toUpperCase()}${i.triangles ? ` · ${i.triangles} triangles` : ''}${i.materials?.length ? ` · ${i.materials.length} matériau(x)` : ''}`;
  if (rep.role === 'shopmeta') return `ShopPedApparel · ${i.pedName ?? '?'}`;
  if (rep.kind === 'gta') return `RSC7 v${i.version ?? '?'}${i.decompressedSize ? ` · ${(i.decompressedSize / 1024).toFixed(0)} Ko décompressés` : ''}`;
  return rep.format;
}
