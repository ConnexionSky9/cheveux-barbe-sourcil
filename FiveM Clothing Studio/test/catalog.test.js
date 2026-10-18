import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { tmpDir, makeYtd, fakeRsc7, testImage } from './helpers.js';
import { scanCatalog, queryCatalog, collectionsOf } from '../src/core/gta/catalog.js';
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
