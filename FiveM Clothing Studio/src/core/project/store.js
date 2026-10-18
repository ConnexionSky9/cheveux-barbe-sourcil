// Gestion des projets sur disque : création, ouverture, sauvegarde atomique, sauvegarde
// automatique, récupération après fermeture anormale, duplication, renommage, suppression,
// import de fichiers (copies) et détection des fichiers manquants.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { emptyProject, migrateProject, addHistory, newId, PROJECT_EXT, PROJECT_FORMAT, ProjectError } from './schema.js';
import { safeFileName, safeJoin, toPosix } from '../paths.js';

const PROJECT_FILE = 'project.json';
const AUTOSAVE_FILE = 'autosave.json';
const LOCK_FILE = '.lock';
export const PROJECT_DIRS = ['assets/originals', 'assets/work', 'textures', 'models', 'reports'];

/** Écriture atomique : fichier temporaire puis renommage (jamais de fichier à moitié écrit). */
export function writeJsonAtomic(file, data) {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2), 'utf8');
  fs.renameSync(tmp, file);
}

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); }
  catch (e) { throw new ProjectError(`Lecture impossible de ${path.basename(file)} : ${e.message}`); }
}

export function isProjectDir(dir) {
  try {
    const p = JSON.parse(fs.readFileSync(path.join(dir, PROJECT_FILE), 'utf8'));
    return p.format === PROJECT_FORMAT || typeof p.version === 'number';
  } catch { return false; }
}

export function createProject(parentDir, name, opts = {}) {
  const clean = String(name ?? '').trim();
  if (!clean) throw new ProjectError('Donnez un nom au projet.');
  const dir = path.join(parentDir, safeFileName(clean) + PROJECT_EXT);
  if (fs.existsSync(dir)) throw new ProjectError(`Un dossier « ${path.basename(dir)} » existe déjà ici.`);
  fs.mkdirSync(dir, { recursive: true });
  for (const d of PROJECT_DIRS) fs.mkdirSync(path.join(dir, d), { recursive: true });
  const project = emptyProject(clean, opts);
  addHistory(project, 'Projet créé');
  writeJsonAtomic(path.join(dir, PROJECT_FILE), project);
  return { dir, project };
}

function pidAlive(pid) {
  try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; }
}

/**
 * Ouvre un projet. Renvoie aussi :
 *  - recovery : une sauvegarde automatique plus récente que project.json (fermeture anormale) ;
 *  - missing  : fichiers référencés mais absents ;
 *  - migrated : le projet vient d'une ancienne version du format.
 */
export function openProject(dir, { lock = true } = {}) {
  const file = path.join(dir, PROJECT_FILE);
  if (!fs.existsSync(file)) throw new ProjectError('Aucun fichier project.json dans ce dossier.');
  const { project, migrated } = migrateProject(readJson(file));
  for (const d of PROJECT_DIRS) fs.mkdirSync(path.join(dir, d), { recursive: true });

  let abnormal = false;
  const lockFile = path.join(dir, LOCK_FILE);
  if (fs.existsSync(lockFile)) {
    try {
      const l = JSON.parse(fs.readFileSync(lockFile, 'utf8'));
      if (l.host === os.hostname() && l.pid !== process.pid && pidAlive(l.pid)) {
        throw new ProjectError('Ce projet est déjà ouvert dans une autre fenêtre.');
      }
      abnormal = l.pid !== process.pid;
    } catch (e) { if (e instanceof ProjectError) throw e; abnormal = true; }
  }

  let recovery = null;
  const auto = path.join(dir, AUTOSAVE_FILE);
  if (fs.existsSync(auto)) {
    try {
      const a = migrateProject(readJson(auto)).project;
      if (Date.parse(a.updatedAt) >= Date.parse(project.updatedAt)) recovery = { updatedAt: a.updatedAt, abnormal };
    } catch { /* sauvegarde automatique corrompue : ignorée */ }
  }
  if (lock) writeJsonAtomic(lockFile, { pid: process.pid, host: os.hostname(), at: new Date().toISOString() });
  if (migrated) {
    fs.copyFileSync(file, path.join(dir, `project.v-old.${Date.now()}.json`));
    writeJsonAtomic(file, project);
  }
  return { dir, project, migrated, recovery, missing: findMissing(dir, project) };
}

/** Remplace le projet par sa sauvegarde automatique (choix de l'utilisateur). */
export function recoverAutosave(dir) {
  const { project } = migrateProject(readJson(path.join(dir, AUTOSAVE_FILE)));
  addHistory(project, 'Projet récupéré depuis la sauvegarde automatique');
  saveProject(dir, project);
  return project;
}

export function saveProject(dir, project) {
  project.updatedAt = new Date().toISOString();
  const file = path.join(dir, PROJECT_FILE);
  if (fs.existsSync(file)) fs.copyFileSync(file, `${file}.bak`);
  writeJsonAtomic(file, project);
  const auto = path.join(dir, AUTOSAVE_FILE);
  if (fs.existsSync(auto)) fs.rmSync(auto, { force: true });
  return project.updatedAt;
}

export function autosaveProject(dir, project) {
  const copy = { ...project, updatedAt: new Date().toISOString() };
  writeJsonAtomic(path.join(dir, AUTOSAVE_FILE), copy);
  return copy.updatedAt;
}

/** Fermeture normale : verrou retiré ; la sauvegarde automatique est jetée (l'utilisateur a choisi). */
export function closeProject(dir, { keepAutosave = false } = {}) {
  fs.rmSync(path.join(dir, LOCK_FILE), { force: true });
  if (!keepAutosave) fs.rmSync(path.join(dir, AUTOSAVE_FILE), { force: true });
}

export function duplicateProject(dir, newName) {
  const src = openProject(dir, { lock: false }).project;
  const target = path.join(path.dirname(dir), safeFileName(newName) + PROJECT_EXT);
  if (fs.existsSync(target)) throw new ProjectError(`« ${path.basename(target)} » existe déjà.`);
  fs.cpSync(dir, target, { recursive: true, filter: (s) => ![LOCK_FILE, AUTOSAVE_FILE].includes(path.basename(s)) });
  const p = { ...src, id: newId(), name: String(newName), createdAt: new Date().toISOString() };
  addHistory(p, `Dupliqué depuis « ${src.name} »`);
  saveProject(target, p);
  return { dir: target, project: p };
}

/** Renomme le projet ET son dossier. Renvoie le nouveau chemin. */
export function renameProject(dir, newName) {
  const clean = String(newName ?? '').trim();
  if (!clean) throw new ProjectError('Nom vide.');
  const p = openProject(dir, { lock: false }).project;
  p.name = clean;
  addHistory(p, `Renommé en « ${clean} »`);
  saveProject(dir, p);
  const target = path.join(path.dirname(dir), safeFileName(clean) + PROJECT_EXT);
  if (path.resolve(target) !== path.resolve(dir)) {
    if (fs.existsSync(target)) throw new ProjectError(`« ${path.basename(target)} » existe déjà.`);
    fs.renameSync(dir, target);
  }
  return { dir: target, project: p };
}

/** Supprime un dossier de projet — uniquement s'il s'agit bien d'un projet. */
export function deleteProject(dir) {
  if (!isProjectDir(dir)) throw new ProjectError('Ce dossier n\'est pas un projet : suppression refusée.');
  fs.rmSync(dir, { recursive: true, force: true });
}

export function sha256File(file) {
  const h = crypto.createHash('sha256');
  const fd = fs.openSync(file, 'r');
  try {
    const buf = Buffer.alloc(1 << 20);
    let n;
    while ((n = fs.readSync(fd, buf, 0, buf.length, null)) > 0) h.update(buf.subarray(0, n));
  } finally { fs.closeSync(fd); }
  return h.digest('hex');
}

/**
 * Copie un fichier dans le projet (assets/originals). L'original n'est jamais modifié.
 * Un fichier déjà importé (même empreinte) n'est pas recopié.
 */
export function importAsset(dir, project, srcPath, { kind, format, info, maxBytes = Infinity } = {}) {
  const st = fs.statSync(srcPath);
  if (!st.isFile()) throw new ProjectError('Ce n\'est pas un fichier.');
  if (st.size > maxBytes) throw new ProjectError(`Fichier trop volumineux (${(st.size / 1048576).toFixed(1)} Mo).`);
  const sha = sha256File(srcPath);
  const existing = project.assets.find((a) => a.sha256 === sha);
  if (existing) return { asset: existing, duplicate: true };
  const id = newId();
  const name = safeFileName(path.basename(srcPath));
  const rel = toPosix(path.join('assets/originals', `${id.slice(0, 8)}_${name}`));
  fs.copyFileSync(srcPath, safeJoin(dir, rel), fs.constants.COPYFILE_EXCL);
  const asset = { id, kind, format, name, file: rel, originalPath: srcPath, size: st.size, sha256: sha,
    importedAt: new Date().toISOString(), info: info || {} };
  project.assets.push(asset);
  addHistory(project, `Import : ${name}`);
  return { asset, duplicate: false };
}

export function assetPath(dir, asset) { return safeJoin(dir, asset.file); }

/** Liste des fichiers référencés par le projet qui n'existent plus. */
export function findMissing(dir, project) {
  const missing = [];
  for (const a of project.assets) {
    let ok = false;
    try { ok = fs.existsSync(safeJoin(dir, a.file)); } catch { ok = false; }
    if (!ok) missing.push({ type: 'asset', id: a.id, name: a.name, file: a.file });
  }
  for (const t of project.textureDocs) {
    let ok = false;
    try { ok = fs.existsSync(safeJoin(dir, `${t.dir}/doc.json`)); } catch { ok = false; }
    if (!ok) missing.push({ type: 'texture', id: t.id, name: t.name, file: `${t.dir}/doc.json` });
  }
  return missing;
}
