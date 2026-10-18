import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { tmpDir, makeYtd, fakeRsc7, testImage } from './helpers.js';
import { scanCatalog, queryCatalog, collectionsOf, mergeCatalogs, diagnoseScan, inferPed } from '../src/core/gta/catalog.js';
import { parseGarmentFileName } from '../src/core/gta/naming.js';
import * as store from '../src/core/project/store.js';
import { garmentFromCatalog } from '../src/core/project/fromCatalog.js';
import { textureDocFromYtd, saveTextureDoc } from '../src/core/project/textures.js';
import { validateExport } from '../src/core/export/validate.js';
import { exportResource } from '../src/core/export/exporter.js';
import { readYtd, decodeYtdTexture } from '../src/core/gta/ytd.js';
import { RGBAImage } from '../src/core/image/rgba.js';
import * as ops from '../src/core/image/ops.js';

/** Arborescence imitant une extraction CodeWalker (fichiers SYNTHÉTIQUES). */
function fakeGame() {
  const root = tmpDir('jeu extrait ');
  const w = (rel, buf) => { const p = path.join(root, rel); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, buf); };
  const ytd = (name, color) => makeYtd([{ name, image: RGBAImage.filled(32, 32, color), format: 'dxt1', levels: 6 }]);
  w('streamedpeds_mp/mp_m_freemode_01/jbib_000_u.ydd', fakeRsc7(165, 'haut 0'));
  w('streamedpeds_mp/mp_m_freemode_01/jbib_diff_000_a_uni.ytd', ytd('jbib_diff_000_a_uni', [200, 30, 30, 255]));
  w('streamedpeds_mp/mp_m_freemode_01/jbib_diff_000_b_uni.ytd', ytd('jbib_diff_000_b_uni', [30, 30, 200, 255]));
  w('streamedpeds_mp/mp_m_freemode_01/uppr_003_r.ydd', fakeRsc7(165, 'bras'));
  w('streamedpeds_mp/mp_m_freemode_01/uppr_diff_003_a_whi.ytd', ytd('uppr_diff_003_a_whi', [220, 200, 180, 255]));
  w('streamedpeds_mp/mp_m_freemode_01/uppr_diff_003_a_bla.ytd', ytd('uppr_diff_003_a_bla', [90, 60, 40, 255]));
  w('streamedpedprops/mp_f_freemode_01_p/p_eyes_002.ydd', fakeRsc7(165, 'lunettes'));
  w('streamedpedprops/mp_f_freemode_01_p/p_eyes_diff_002_a.ytd', ytd('p_eyes_diff_002_a', [10, 10, 10, 255]));
  w('dlc/mp_m_freemode_01_mp_m_business_01/jbib_004_u.ydd', fakeRsc7(165, 'dlc'));
  w('dlc/mp_m_freemode_01_mp_m_business_01/jbib_diff_004_a_uni.ytd', ytd('jbib_diff_004_a_uni', [0, 0, 0, 255]));
  w('autres/readme.txt', 'rien');
  w('autres/jbib_000_u.ydd', fakeRsc7(165, 'sans dossier de personnage'));
  return root;
}

test('Noms sans préfixe (fichiers extraits du jeu)', () => {
  const p = parseGarmentFileName('jbib_diff_000_a_uni.ytd');
  assert.equal(p.prefix, null); assert.equal(p.slot, 'jbib'); assert.equal(p.letter, 'a');
  assert.equal(parseGarmentFileName('jbib_000.ytd'), null);
});

test('Catalogue : indexation par personnage, emplacement, collection', () => {
  const cat = scanCatalog(fakeGame());
  assert.equal(cat.items.length, 4);
  const top = cat.items.find((i) => i.key === 'mp_m_freemode_01|component|jbib|0');
  assert.equal(top.yddStream, 'mp_m_freemode_01^jbib_000_u.ydd');
  assert.deepEqual(top.textures.map((t) => t.stream), ['mp_m_freemode_01^jbib_diff_000_a_uni.ytd', 'mp_m_freemode_01^jbib_diff_000_b_uni.ytd']);
  const glasses = cat.items.find((i) => i.slot === 'p_eyes');
  assert.equal(glasses.ped, 'mp_f_freemode_01'); assert.equal(glasses.kind, 'prop');
  assert.equal(glasses.yddStream, 'mp_f_freemode_01_p^p_eyes_002.ydd');
  assert.equal(cat.items.find((i) => i.collection === 'mp_m_business_01').index, 4);
  assert.equal(cat.stats.ignored, 1, 'fichier hors dossier de personnage ignoré');
  assert.equal(queryCatalog(cat, { slot: 'uppr' }).total, 1);
  assert.equal(queryCatalog(cat, { ped: 'mp_m_freemode_01', collection: '' }).total, 2);
  assert.deepEqual(collectionsOf(cat), ['', 'mp_m_business_01']);
});

test('Créer à partir d\'un vêtement du jeu, modifier sa texture, exporter (.ytd réécrit)', async () => {
  const game = fakeGame();
  const cat = scanCatalog(game);
  const root = tmpDir();
  const { dir, project } = store.createProject(root, 'Depuis le jeu');
  const g = garmentFromCatalog(dir, project, game, cat.items.find((i) => i.key === 'mp_m_freemode_01|component|jbib|0'));
  assert.equal(g.variants.length, 2);
  // Texture de la variante a, avec un logo vert par-dessus
  const va = g.variants[0];
  const { doc, meta } = textureDocFromYtd(dir, project, project.assets.find((a) => a.id === va.ytdAssetId), 'jbib_diff_000_a_uni');
  assert.ok(doc.layers[0].image.get(1, 1)[0] > 180, 'texture d\'origine décodée');
  doc.addLayer({ name: 'Logo', image: RGBAImage.filled(16, 16, [0, 220, 0, 255]), x: 0, y: 0 });
  doc.applyToLayer(doc.layers[0].id, 'Assombrir', (im) => ops.brightness(im, -30));
  saveTextureDoc(dir, project, doc, { id: meta.id });
  va.textureDocId = meta.id;
  project.exportSettings = { packName: 'Depuis le jeu', resourceName: 'depuis_le_jeu', mode: 'replace' };
  const v = validateExport(dir, project);
  assert.equal(v.status, 'ready', JSON.stringify(v.issues));
  assert.ok(v.issues.some((i) => /sera écrite dans/.test(i.message)));
  const out = tmpDir('sortie ');
  const r = await exportResource({ dir, project, destination: out });
  assert.equal(r.status, 'ready');
  const res = path.join(out, 'depuis_le_jeu', 'stream');
  assert.deepEqual(fs.readdirSync(res).sort(), ['mp_m_freemode_01^jbib_000_u.ydd', 'mp_m_freemode_01^jbib_diff_000_a_uni.ytd', 'mp_m_freemode_01^jbib_diff_000_b_uni.ytd']);
  const patched = readYtd(fs.readFileSync(path.join(res, 'mp_m_freemode_01^jbib_diff_000_a_uni.ytd')));
  const img = decodeYtdTexture(patched, 'jbib_diff_000_a_uni');
  assert.ok(img.get(4, 4)[1] > 190 && img.get(4, 4)[0] < 40, `logo vert présent (${img.get(4, 4)})`);
  assert.ok(img.get(28, 28)[0] < 190 && img.get(28, 28)[0] > 100, `fond assombri (${img.get(28, 28)})`);
  const untouched = fs.readFileSync(path.join(res, 'mp_m_freemode_01^jbib_diff_000_b_uni.ytd'));
  assert.deepEqual(untouched, fs.readFileSync(path.join(game, 'streamedpeds_mp/mp_m_freemode_01/jbib_diff_000_b_uni.ytd')), 'variante b copiée à l\'identique');
  assert.ok(r.files.find((f) => f.patched === 'jbib_diff_000_a_uni'));
});

test('Créer à partir de bras (_r, plusieurs teintes de peau) et de lunettes', () => {
  const game = fakeGame();
  const cat = scanCatalog(game);
  const { dir, project } = store.createProject(tmpDir(), 'Variantes');
  const arms = garmentFromCatalog(dir, project, game, cat.items.find((i) => i.slot === 'uppr'));
  assert.deepEqual(arms.variants.map((v) => `${v.letter}_${v.suffix}`), ['a_bla', 'a_whi']);
  const glasses = garmentFromCatalog(dir, project, game, cat.items.find((i) => i.slot === 'p_eyes'));
  project.targetPeds.push('mp_f_freemode_01');
  project.exportSettings = { packName: 'V', resourceName: 'variantes', mode: 'replace' };
  const v = validateExport(dir, project);
  assert.equal(v.status, 'ready', JSON.stringify(v.issues));
  const names = v.plan.stream.map((s) => s.to).sort();
  assert.ok(names.includes('stream/mp_m_freemode_01^uppr_diff_003_a_whi.ytd'));
  assert.ok(names.includes('stream/mp_f_freemode_01_p^p_eyes_002.ydd'));
  void glasses;
});

// ---------------------------------------------------------------- extractions « réelles » variées
function writer(root) {
  return (rel, buf) => { const p = path.join(root, rel); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, buf); };
}
const smallYtd = (name) => makeYtd([{ name, image: RGBAImage.filled(16, 16, [9, 9, 9, 255]), format: 'dxt1', levels: 1 }]);

test('Personnage deviné : mp_…, « .rpf », homme / femme / female', () => {
  assert.equal(inferPed('mp_m_freemode_01.rpf').ped, 'mp_m_freemode_01');
  assert.equal(inferPed('Copie de mp_f_freemode_01_p (2)').props, true);
  assert.equal(inferPed('Vêtements Femme').ped, 'mp_f_freemode_01');
  assert.equal(inferPed('female').ped, 'mp_f_freemode_01');
  assert.equal(inferPed('HOMMES').ped, 'mp_m_freemode_01');
  assert.equal(inferPed('GTA vêtements'), null);
});

test('Fichiers « en vrac » (sans dossier de personnage) : question puis indexation', () => {
  const root = tmpDir('en vrac ');
  const w = writer(root);
  w('jbib_000_u.ydd', fakeRsc7(165, 'x'));
  w('jbib_diff_000_a_uni.ytd', smallYtd('jbib_diff_000_a_uni'));
  w('p_head_001.ydd', fakeRsc7(165, 'x'));
  w('p_head_diff_001_a.ytd', smallYtd('p_head_diff_001_a'));
  const first = scanCatalog(root);
  assert.equal(first.items.length, 0);
  assert.equal(first.report.orphans, 4);
  assert.ok(diagnoseScan(first.report).some((a) => a.level === 'question'));
  const fem = scanCatalog(root, { defaultPed: 'mp_f_freemode_01' });
  assert.equal(fem.items.length, 2);
  assert.equal(fem.items.find((i) => i.slot === 'jbib').yddStream, 'mp_f_freemode_01^jbib_000_u.ydd');
  assert.equal(fem.items.find((i) => i.slot === 'p_head').yddStream, 'mp_f_freemode_01_p^p_head_001.ydd', 'accessoire : dossier _p');
  assert.equal(scanCatalog(root, { defaultPed: 'skip' }).items.length, 0);
});

test('Dossiers « homme » / « femme » et dossier « mp_m_freemode_01.rpf »', () => {
  const root = tmpDir('GTA vêtements ');
  const w = writer(root);
  w('homme/jbib_002_u.ydd', fakeRsc7(165, 'x'));
  w('homme/p_eyes_003.ydd', fakeRsc7(165, 'x'));
  w('Femme/lowr_004_u.ydd', fakeRsc7(165, 'x'));
  w('x/mp_m_freemode_01.rpf/feet_005_u.ydd', fakeRsc7(165, 'x'));
  const c = scanCatalog(root);
  assert.equal(c.report.orphans, 0);
  assert.deepEqual(c.items.map((i) => i.yddStream).sort(), ['mp_f_freemode_01^lowr_004_u.ydd', 'mp_m_freemode_01^feet_005_u.ydd', 'mp_m_freemode_01^jbib_002_u.ydd', 'mp_m_freemode_01_p^p_eyes_003.ydd']);
  assert.equal(c.stats.mp_m_freemode_01, 3);
  assert.ok(diagnoseScan(c.report).some((a) => a.level === 'info' && /deviné/.test(a.title)));
});

test('Diagnostic : dossier de GTA V, archives .rpf, Export XML, Extract Uncompressed, dossier vide', () => {
  const gta = tmpDir('Grand Theft Auto V ');
  writer(gta)('GTA5.exe', 'MZ'); writer(gta)('x64v.rpf', 'RPF7'); writer(gta)('update/update.rpf', 'RPF7');
  const g = scanCatalog(gta);
  assert.equal(g.report.gtaInstall, true); assert.equal(g.report.rpf, 2);
  assert.match(diagnoseScan(g.report)[0].title, /installation de GTA V/);

  const rpf = tmpDir('rpf ');
  writer(rpf)('streamedpeds_mp.rpf', 'RPF7');
  assert.match(diagnoseScan(scanCatalog(rpf).report)[0].title, /archive/);

  const xml = tmpDir('xml ');
  writer(xml)('mp_m_freemode_01/jbib_000_u.ydd.xml', '<x/>');
  assert.ok(diagnoseScan(scanCatalog(xml).report).some((a) => a.level === 'error' && /xml/i.test(a.title)));

  const unc = tmpDir('uncompressed ');
  writer(unc)('mp_m_freemode_01/jbib_000_u.ydd', Buffer.alloc(64, 1));
  const u = scanCatalog(unc);
  assert.equal(u.report.notRsc7, 1); assert.equal(u.items.length, 0);
  assert.ok(diagnoseScan(u.report).some((a) => /mauvais mode/.test(a.title)));

  const empty = tmpDir('vide ');
  assert.match(diagnoseScan(scanCatalog(empty).report)[0].text, /vide/);

  const other = tmpDir('autres ');
  writer(other)('mp_m_freemode_01/prop_chair_01.ydd', fakeRsc7(165, 'x'));
  assert.ok(diagnoseScan(scanCatalog(other).report).some((a) => /pas des vêtements/.test(a.title)));
});

test('Ajouter un second dossier au catalogue, puis créer un vêtement depuis ce dossier', () => {
  const a = tmpDir('homme ');
  writer(a)('jbib_000_u.ydd', fakeRsc7(165, 'x'));
  writer(a)('jbib_diff_000_a_uni.ytd', smallYtd('jbib_diff_000_a_uni'));
  const b = tmpDir('femme ');
  writer(b)('jbib_000_u.ydd', fakeRsc7(165, 'y'));
  writer(b)('jbib_diff_000_a_uni.ytd', smallYtd('jbib_diff_000_a_uni'));
  const merged = mergeCatalogs(scanCatalog(a), scanCatalog(b));
  assert.equal(merged.items.length, 2);
  assert.deepEqual(merged.roots, [a, b]);
  assert.equal(merged.stats.mp_f_freemode_01, 1);
  const fem = merged.items.find((i) => i.ped === 'mp_f_freemode_01');
  assert.equal(fem.root, b);
  const proj = tmpDir('proj ');
  const { dir, project } = store.createProject(proj, 'Fusion');
  const g = garmentFromCatalog(dir, project, fem.root, fem);
  assert.equal(g.variants.length, 1);
  assert.equal(g.streamNames.ydd, 'mp_f_freemode_01^jbib_000_u.ydd');
});
