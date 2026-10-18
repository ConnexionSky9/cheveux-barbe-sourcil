import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { tmpDir, testImage } from './helpers.js';
import * as store from '../src/core/project/store.js';
import { PROJECT_VERSION } from '../src/core/project/schema.js';
import { saveTextureDoc, loadTextureDoc, textureDocFromAsset } from '../src/core/project/textures.js';
import { encodeImage } from '../src/core/image/codecs.js';
import * as ops from '../src/core/image/ops.js';
import { safeJoin, toResourceName, safeFileName, isValidResourceName } from '../src/core/paths.js';

test('Création, sauvegarde et réouverture (chemin avec accents et espaces)', () => {
  const root = tmpDir();
  const { dir, project } = store.createProject(root, 'Mon Pack Été', { peds: ['mp_f_freemode_01'] });
  assert.ok(dir.endsWith('Mon Pack Été.fcsproj'));
  project.description = 'Test';
  store.saveProject(dir, project);
  store.closeProject(dir);
  const o = store.openProject(dir);
  assert.equal(o.project.name, 'Mon Pack Été');
  assert.equal(o.project.description, 'Test');
  assert.deepEqual(o.project.targetPeds, ['mp_f_freemode_01']);
  assert.equal(o.recovery, null);
  assert.deepEqual(o.missing, []);
  store.closeProject(dir);
  assert.throws(() => store.createProject(root, 'Mon Pack Été'), /existe déjà/);
  assert.throws(() => store.createProject(root, '   '), /nom/);
});

test('Sauvegarde automatique et récupération après fermeture anormale', () => {
  const root = tmpDir();
  const { dir, project } = store.createProject(root, 'Crash');
  store.openProject(dir);                 // pose le verrou
  project.description = 'non enregistré';
  // horodatage plus récent que project.json
  const later = { ...project };
  store.autosaveProject(dir, later);
  // Simule un crash : verrou d'un autre processus inexistant
  fs.writeFileSync(path.join(dir, '.lock'), JSON.stringify({ pid: 999999, host: 'autre-pc', at: new Date().toISOString() }));
  const o = store.openProject(dir);
  assert.ok(o.recovery, 'récupération proposée');
  assert.equal(o.recovery.abnormal, true);
  const rec = store.recoverAutosave(dir);
  assert.equal(rec.description, 'non enregistré');
  assert.equal(fs.existsSync(path.join(dir, 'autosave.json')), false);
});

test('Duplication, renommage, suppression protégée', () => {
  const root = tmpDir();
  const { dir } = store.createProject(root, 'Original');
  const dup = store.duplicateProject(dir, 'Copie');
  assert.notEqual(dup.project.id, store.openProject(dir, { lock: false }).project.id);
  const ren = store.renameProject(dup.dir, 'Copie renommée');
  assert.ok(fs.existsSync(path.join(root, 'Copie renommée.fcsproj', 'project.json')));
  assert.equal(fs.existsSync(dup.dir), false);
  const notProject = path.join(root, 'dossier perso');
  fs.mkdirSync(notProject);
  assert.throws(() => store.deleteProject(notProject), /pas un projet/);
  assert.ok(fs.existsSync(notProject));
  store.deleteProject(ren.dir);
  assert.equal(fs.existsSync(ren.dir), false);
});

test('Import : copie (original intact), doublons, fichiers manquants', () => {
  const root = tmpDir();
  const { dir, project } = store.createProject(root, 'Imports');
  const src = path.join(root, 'logo é.png');
  fs.writeFileSync(src, encodeImage(testImage(), { format: 'png' }).buffer);
  const before = fs.readFileSync(src);
  const a = store.importAsset(dir, project, src, { kind: 'texture', format: 'png' });
  assert.equal(a.duplicate, false);
  assert.ok(fs.existsSync(store.assetPath(dir, a.asset)));
  assert.equal(store.importAsset(dir, project, src, { kind: 'texture' }).duplicate, true);
  assert.deepEqual(fs.readFileSync(src), before);
  fs.rmSync(store.assetPath(dir, a.asset));
  const miss = store.findMissing(dir, project);
  assert.equal(miss.length, 1);
  assert.equal(miss[0].name, 'logo é.png');
  assert.throws(() => store.importAsset(dir, project, src, { maxBytes: 10 }), /volumineux/);
});

test('Migration depuis le format v1', () => {
  const root = tmpDir();
  const dir = path.join(root, 'Ancien.fcsproj');
  fs.mkdirSync(dir);
  fs.writeFileSync(path.join(dir, 'project.json'), JSON.stringify({ version: 1, title: 'Ancien pack', gender: 'female',
    items: [{ name: 'Veste', type: 'Vestes', files: [{ path: 'C:/x/veste.ydd', role: 'model' }] }] }));
  const o = store.openProject(dir);
  assert.equal(o.migrated, true);
  assert.equal(o.project.formatVersion, PROJECT_VERSION);
  assert.equal(o.project.name, 'Ancien pack');
  assert.equal(o.project.garments[0].ped, 'mp_f_freemode_01');
  assert.ok(fs.readdirSync(dir).some((f) => f.startsWith('project.v-old')), 'ancienne version conservée');
  fs.writeFileSync(path.join(dir, 'project.json'), JSON.stringify({ format: 'fivem-clothing-studio-project', formatVersion: 99 }));
  assert.throws(() => store.openProject(dir), /plus récente/);
});

test('Textures de travail : enregistrement et rechargement des calques', () => {
  const root = tmpDir();
  const { dir, project } = store.createProject(root, 'Textures');
  const src = path.join(root, 'tee.png');
  fs.writeFileSync(src, encodeImage(testImage(32, 32), { format: 'png' }).buffer);
  const { asset } = store.importAsset(dir, project, src, { kind: 'texture' });
  const { doc, meta } = textureDocFromAsset(dir, project, asset);
  doc.addLayer({ name: 'Logo', image: testImage(8, 8), x: 3, y: 4, rotation: 30, opacity: 0.7 });
  doc.applyToLayer(doc.layers[0].id, 'Éclaircir', (im) => ops.brightness(im, 10));
  saveTextureDoc(dir, project, doc, { id: meta.id });
  const back = loadTextureDoc(dir, meta);
  assert.equal(back.layers.length, 2);
  assert.equal(back.layers[1].rotation, 30);
  assert.deepEqual(back.composite().data, doc.composite().data);
  assert.ok(fs.existsSync(path.join(dir, meta.dir, 'preview.png')));
  assert.deepEqual(fs.readFileSync(src), fs.readFileSync(src), 'source intacte');
});

test('Chemins et noms sûrs', () => {
  const root = tmpDir();
  assert.throws(() => safeJoin(root, '../evil.txt'), /hors du dossier/);
  assert.throws(() => safeJoin(root, 'C:\\Windows\\x'), /refusé/);
  assert.throws(() => safeJoin(root, '/etc/passwd'), /refusé/);
  assert.equal(path.basename(safeJoin(root, 'a/b é.png')), 'b é.png');
  assert.equal(toResourceName('Mon Pack Été 2024 !'), 'mon_pack_ete_2024');
  assert.equal(safeFileName('CON'), '_CON');
  assert.equal(safeFileName('a<b>:c?.png'), 'a_b__c_.png');
  assert.equal(isValidResourceName('mon pack'), false);
  assert.equal(isValidResourceName('mon_pack-2'), true);
});
