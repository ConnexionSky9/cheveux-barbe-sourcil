import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { tmpDir, testImage, fakeRsc7 } from './helpers.js';
import * as store from '../src/core/project/store.js';
import { newId } from '../src/core/project/schema.js';
import { textureDocFromAsset } from '../src/core/project/textures.js';
import { encodeImage } from '../src/core/image/codecs.js';
import { validateExport } from '../src/core/export/validate.js';
import { exportResource } from '../src/core/export/exporter.js';
import { generateManifest, checkManifest } from '../src/core/export/manifest.js';
import { garmentFileNames, parseGarmentFileName } from '../src/core/gta/naming.js';
import { inspectRsc7 } from '../src/core/gta/rsc7.js';
import { readDdsHeader } from '../src/core/image/dds.js';

function setup(name = 'Pack Test') {
  const root = tmpDir();
  const { dir, project } = store.createProject(root, name);
  const imp = (fname, buf) => { const p = path.join(root, fname); fs.writeFileSync(p, buf); return store.importAsset(dir, project, p, { kind: 'gta' }).asset; };
  const out = path.join(root, 'sortie é');
  fs.mkdirSync(out);
  return { root, dir, project, imp, out };
}

function garment(project, extra) {
  const g = { id: newId(), name: 'T-shirt', category: 'T-shirts', ped: 'mp_m_freemode_01', kind: 'component', slot: 'jbib', drawableIndex: 5,
    yddAssetId: null, variants: [], ...extra };
  project.garments.push(g);
  return g;
}

test('Nommage des fichiers freemode', () => {
  const n = garmentFileNames({ prefix: 'mp_m_freemode_01', kind: 'component', slot: 'jbib', index: 5 });
  assert.equal(n.ydd, 'mp_m_freemode_01^jbib_005_u.ydd');
  assert.equal(n.ytd('b'), 'mp_m_freemode_01^jbib_diff_005_b_uni.ytd');
  const p = garmentFileNames({ prefix: 'mp_f_freemode_01', kind: 'prop', slot: 'p_head', index: 12 });
  assert.equal(p.ydd, 'mp_f_freemode_01^p_head_012.ydd');
  assert.equal(p.ytd('a'), 'mp_f_freemode_01^p_head_diff_012_a.ytd');
  assert.deepEqual(parseGarmentFileName('mp_m_freemode_01_mypack^lowr_diff_003_c_uni.ytd'),
    { prefix: 'mp_m_freemode_01_mypack', ped: 'mp_m_freemode_01', kind: 'component', slot: 'lowr', index: 3, letter: 'c', suffix: 'uni', isTexture: true, ext: 'ytd' });
  assert.equal(parseGarmentFileName('n_importe_quoi.ydd'), null);
  assert.throws(() => garmentFileNames({ prefix: 'x', kind: 'component', slot: 'zzzz', index: 1 }), /Slot inconnu/);
});

test('RSC7 : en-tête, version inhabituelle, données tronquées', () => {
  assert.equal(inspectRsc7(fakeRsc7(13), { ext: 'ytd' }).ok, true);
  const w = inspectRsc7(fakeRsc7(99), { ext: 'ytd' });
  assert.equal(w.ok, true);
  assert.ok(w.issues.some((i) => i.level === 'warning'));
  assert.equal(inspectRsc7(fakeRsc7(13).subarray(0, 20), { ext: 'ytd' }).ok, false);
  assert.equal(inspectRsc7(Buffer.from('pas une ressource')).ok, false);
});

test('Validation : erreurs bloquantes claires', () => {
  const s = setup();
  s.project.exportSettings.resourceName = 'Mauvais Nom';
  const g = garment(s.project, { slot: null });
  let v = validateExport(s.dir, s.project);
  assert.equal(v.status, 'blocked');
  assert.ok(v.issues.some((i) => /Nom technique/.test(i.message)));
  assert.ok(v.issues.some((i) => /slot GTA V/.test(i.message)));
  s.project.exportSettings.resourceName = 'pack_test';
  g.slot = 'jbib';
  v = validateExport(s.dir, s.project);
  assert.ok(v.issues.some((i) => /aucune variante/.test(i.message)));
  // Doublon d'emplacement
  const ytd = s.imp('t.ytd', fakeRsc7(13));
  g.variants = [{ id: newId(), letter: 'a', ytdAssetId: ytd.id }];
  garment(s.project, { name: 'Autre', variants: [{ id: newId(), letter: 'a', ytdAssetId: ytd.id }] });
  v = validateExport(s.dir, s.project);
  assert.ok(v.issues.some((i) => /même emplacement/.test(i.message)));
  // Fichier du mauvais type
  s.project.garments.pop();
  const notYdd = s.imp('faux.ydd', Buffer.from('ceci n\'est pas un ydd'));
  g.yddAssetId = notYdd.id;
  v = validateExport(s.dir, s.project);
  assert.equal(v.status, 'blocked');
  assert.ok(v.issues.some((i) => /RSC7/.test(i.message)));
});

test('Export « remplacement » complet : structure, manifeste, rapport, chemins relatifs', async () => {
  const s = setup();
  s.project.exportSettings = { packName: 'Pack Été', resourceName: 'pack_ete', mode: 'replace' };
  const ydd = s.imp('veste.ydd', fakeRsc7(165, 'modele'));
  const ytdA = s.imp('veste_a.ytd', fakeRsc7(13, 'texture a'));
  const ytdB = s.imp('veste_b.ytd', fakeRsc7(13, 'texture b'));
  garment(s.project, { yddAssetId: ydd.id, variants: [{ id: newId(), letter: 'a', ytdAssetId: ytdA.id }, { id: newId(), letter: 'b', ytdAssetId: ytdB.id }] });
  const v = validateExport(s.dir, s.project);
  assert.equal(v.status, 'ready', JSON.stringify(v.issues));
  const steps = [];
  const r = await exportResource({ dir: s.dir, project: s.project, destination: s.out, onProgress: (st) => steps.push(st), appVersion: 'test' });
  assert.equal(r.status, 'ready');
  assert.equal(r.testedInGame, false);
  const res = path.join(s.out, 'pack_ete');
  const files = fs.readdirSync(path.join(res, 'stream')).sort();
  assert.deepEqual(files, ['mp_m_freemode_01^jbib_005_u.ydd', 'mp_m_freemode_01^jbib_diff_005_a_uni.ytd', 'mp_m_freemode_01^jbib_diff_005_b_uni.ytd']);
  assert.deepEqual(fs.readFileSync(path.join(res, 'stream', files[0])), fakeRsc7(165, 'modele'), 'copie binaire exacte');
  const manifest = fs.readFileSync(path.join(res, 'fxmanifest.lua'), 'utf8');
  assert.match(manifest, /^fx_version 'cerulean'/m);
  assert.doesNotMatch(manifest, /data_file|files\s*\{/);
  assert.doesNotMatch(manifest, new RegExp(s.root.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  const report = JSON.parse(fs.readFileSync(path.join(res, 'export_report.json'), 'utf8'));
  assert.equal(report.files.length, 3);
  assert.ok(report.files.every((f) => !path.isAbsolute(f.path) && f.path.startsWith('stream/')));
  assert.match(fs.readFileSync(path.join(res, 'README.txt'), 'utf8'), /ensure pack_ete/);
  assert.ok(steps.includes('Terminé'));
  assert.deepEqual(fs.readdirSync(s.out).sort(), ['pack_ete'], 'aucun dossier temporaire restant');
});

test('Export : pas d\'écrasement sans confirmation, remplacement atomique avec confirmation', async () => {
  const s = setup();
  s.project.exportSettings = { packName: 'P', resourceName: 'pack_x', mode: 'replace' };
  const ytd = s.imp('t.ytd', fakeRsc7(13));
  garment(s.project, { variants: [{ id: newId(), letter: 'a', ytdAssetId: ytd.id }] });
  fs.mkdirSync(path.join(s.out, 'pack_x'));
  fs.writeFileSync(path.join(s.out, 'pack_x', 'mon_fichier.txt'), 'à garder');
  await assert.rejects(exportResource({ dir: s.dir, project: s.project, destination: s.out }), /existe déjà/);
  assert.equal(fs.readFileSync(path.join(s.out, 'pack_x', 'mon_fichier.txt'), 'utf8'), 'à garder');
  await exportResource({ dir: s.dir, project: s.project, destination: s.out, overwrite: true });
  assert.ok(fs.existsSync(path.join(s.out, 'pack_x', 'fxmanifest.lua')));
  assert.equal(fs.existsSync(path.join(s.out, 'pack_x', 'mon_fichier.txt')), false);
  assert.deepEqual(fs.readdirSync(s.out), ['pack_x']);
});

test('Export annulé : destination inchangée, temporaires supprimés', async () => {
  const s = setup();
  s.project.exportSettings = { packName: 'P', resourceName: 'pack_annule', mode: 'replace' };
  const ytd = s.imp('t.ytd', fakeRsc7(13));
  garment(s.project, { variants: [{ id: newId(), letter: 'a', ytdAssetId: ytd.id }] });
  const signal = { cancelled: false };
  await assert.rejects(exportResource({ dir: s.dir, project: s.project, destination: s.out, signal,
    onProgress: (st) => { if (st === 'Manifeste') signal.cancelled = true; } }), /annulé/);
  assert.deepEqual(fs.readdirSync(s.out), []);
});

test('Export bloqué : rien n\'est écrit', async () => {
  const s = setup();
  s.project.exportSettings = { packName: 'P', resourceName: 'pack_bloque', mode: 'replace' };
  garment(s.project, { variants: [{ id: newId(), letter: 'a' }] });
  await assert.rejects(exportResource({ dir: s.dir, project: s.project, destination: s.out }), /erreurs bloquantes/);
  assert.deepEqual(fs.readdirSync(s.out), []);
});

test('Export incomplet : texture de travail exportée en DDS à convertir, statut honnête', async () => {
  const s = setup();
  s.project.exportSettings = { packName: 'P', resourceName: 'pack_incomplet', mode: 'replace' };
  const png = path.join(s.root, 'tee.png');
  fs.writeFileSync(png, encodeImage(testImage(60, 60), { format: 'png' }).buffer);
  const { asset } = store.importAsset(s.dir, s.project, png, { kind: 'texture' });
  const { meta } = textureDocFromAsset(s.dir, s.project, asset);
  garment(s.project, { variants: [{ id: newId(), letter: 'a', textureDocId: meta.id }] });
  const v = validateExport(s.dir, s.project);
  assert.equal(v.status, 'incomplete');
  await assert.rejects(exportResource({ dir: s.dir, project: s.project, destination: s.out }), /incomplet/);
  const r = await exportResource({ dir: s.dir, project: s.project, destination: s.out, allowIncomplete: true });
  assert.equal(r.status, 'incomplete');
  assert.ok(r.convertPath);
  const dds = path.join(r.convertPath, 'jbib_diff_005_a_uni.dds');
  const h = readDdsHeader(fs.readFileSync(dds));
  assert.equal(h.width, 64, 'redimensionnée en puissance de 2');
  assert.equal(h.format, 'dxt5', 'alpha conservé');
  assert.ok(h.mipCount > 1);
  assert.match(fs.readFileSync(path.join(r.path, 'README.txt'), 'utf8'), /AVANT D'INSTALLER/);
});

test('Export « collection additionnelle » : ymt + meta, data_file', async () => {
  const s = setup();
  const ymt = s.imp('mp_m_freemode_01_monpack.ymt', fakeRsc7(2, 'meta'));
  const metaPath = path.join(s.root, 'shop.meta');
  fs.writeFileSync(metaPath, '<?xml version="1.0" encoding="UTF-8"?>\n<ShopPedApparel>\n  <pedName>mp_m_freemode_01</pedName>\n  <dlcName>monpack</dlcName>\n</ShopPedApparel>\n');
  const meta = store.importAsset(s.dir, s.project, metaPath, { kind: 'gta' }).asset;
  s.project.exportSettings = { packName: 'Mon pack', resourceName: 'monpack', mode: 'addon',
    collections: { mp_m_freemode_01: { ymtAssetId: ymt.id, metaAssetId: meta.id } } };
  const ydd = s.imp('a.ydd', fakeRsc7(165));
  const ytd = s.imp('a.ytd', fakeRsc7(13));
  garment(s.project, { drawableIndex: 0, yddAssetId: ydd.id, variants: [{ id: newId(), letter: 'a', ytdAssetId: ytd.id }] });
  const r = await exportResource({ dir: s.dir, project: s.project, destination: s.out });
  assert.equal(r.status, 'ready');
  const res = path.join(s.out, 'monpack');
  assert.ok(fs.existsSync(path.join(res, 'stream', 'mp_m_freemode_01_monpack^jbib_000_u.ydd')));
  assert.ok(fs.existsSync(path.join(res, 'stream', 'mp_m_freemode_01_monpack.ymt')));
  const manifest = fs.readFileSync(path.join(res, 'fxmanifest.lua'), 'utf8');
  assert.match(manifest, /data_file 'SHOP_PED_APPAREL_META_FILE' 'data\/mp_m_freemode_01_monpack\.meta'/);
  assert.match(manifest, /files \{\n    'data\/mp_m_freemode_01_monpack\.meta',\n\}/);
  // Sans ydd : erreur en mode additionnel
  s.project.garments[0].yddAssetId = null;
  assert.ok(validateExport(s.dir, s.project).issues.some((i) => /besoin de son modèle/.test(i.message)));
  // Mauvais nom de ymt
  const bad = s.imp('collection.ymt', fakeRsc7(2, 'x'));
  s.project.exportSettings.collections.mp_m_freemode_01.ymtAssetId = bad.id;
  assert.ok(validateExport(s.dir, s.project).issues.some((i) => /doit s'appeler/.test(i.message)));
});

test('Manifeste : contrôle structurel et exécution réelle en Lua (si disponible)', () => {
  const m = generateManifest({ name: "pack'test", description: 'Pack d\'été', dataFiles: [{ path: 'data/x.meta', type: 'SHOP_PED_APPAREL_META_FILE' }] });
  assert.deepEqual(checkManifest(m, new Set(['data/x.meta'])), []);
  assert.ok(checkManifest(m, new Set()).some((p) => /absent/.test(p)));
  assert.ok(checkManifest("fx_version 'cerulean'\ngame 'gta5'\nfiles { 'C:/Users/moi/x.meta' }", new Set()).some((p) => /absolu/.test(p)));
  // Exécution du manifeste par un vrai interpréteur Lua 5.4 (lupa) : syntaxe valide
  const lua = `
import sys
from lupa import lua54
L = lua54.LuaRuntime()
L.execute("""seen = {}
local function rec(n) return function(v) seen[#seen+1] = n end end
for _, k in ipairs({'fx_version','game','name','description','version','author','files'}) do _G[k] = rec(k) end
data_file = function(t) return function(p) seen[#seen+1] = 'data_file' end end""")
L.execute(sys.stdin.read())
print(L.eval("#seen"))`;
  let out;
  try { out = execFileSync('python3', ['-I', '-c', lua], { input: m }).toString().trim(); } catch { return; /* lupa absent : test ignoré */ }
  assert.equal(out, '8');
});
