// Test de bout en bout de l'application Electron (Linux + Xvfb, ou Windows).
// Les fenêtres natives (choix de fichiers) sont simulées dans le processus principal.
// Lancement : npm run test:e2e   (sous Linux sans écran : xvfb-run -a npm run test:e2e)
import { _electron as electron } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { encodeImage } from '../../src/core/image/codecs.js';
import { testImage, fakeRsc7, makeGlb, QUAD_OBJ } from '../helpers.js';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SHOTS = process.env.FCS_SHOTS || path.join(ROOT, 'test/.tmp/shots');
fs.mkdirSync(SHOTS, { recursive: true });
const work = fs.mkdtempSync(path.join(os.tmpdir(), 'fcs e2e é '));
const userData = path.join(work, 'données utilisateur');
const files = path.join(work, 'mes fichiers');
const out = path.join(work, 'serveur', 'resources');
fs.mkdirSync(files, { recursive: true }); fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(files, 't-shirt base.png'), encodeImage(testImage(256, 256), { format: 'png' }).buffer);
fs.writeFileSync(path.join(files, 'logo.png'), encodeImage(testImage(64, 64), { format: 'png' }).buffer);
fs.writeFileSync(path.join(files, 'veste.glb'), makeGlb());
fs.writeFileSync(path.join(files, 'veste.ydd'), fakeRsc7(165, 'modele de test'));
fs.writeFileSync(path.join(files, 'veste_a.ytd'), fakeRsc7(13, 'textures de test'));
const objDir = path.join(work, 'modèle obj');
fs.mkdirSync(objDir);
fs.writeFileSync(path.join(objDir, 'quad.obj'), QUAD_OBJ);
fs.writeFileSync(path.join(objDir, 'quad.mtl'), 'newmtl Tissu\nKd 1 1 1\nmap_Kd motif.png\n');
fs.writeFileSync(path.join(objDir, 'motif.png'), encodeImage(testImage(32, 32), { format: 'png' }).buffer);

const errors = [];
const step = (m) => console.log(`• ${m}`);
const electronPath = path.join(ROOT, 'node_modules/electron/dist', process.platform === 'win32' ? 'electron.exe' : 'electron');
const app = await electron.launch(process.env.FCS_EXE ? { executablePath: process.env.FCS_EXE, args: ['--no-sandbox'],
  env: { ...process.env, FCS_USER_DATA: userData, FCS_QUIET: '1' } } : { executablePath: electronPath, args: [ROOT, '--no-sandbox'], env: { ...process.env, FCS_USER_DATA: userData, FCS_QUIET: '1' } });
const page = await app.firstWindow();
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
await page.setViewportSize?.({ width: 1600, height: 960 });
const stubOpen = (paths) => app.evaluate(({ dialog }, p) => { dialog.showOpenDialog = async () => ({ canceled: false, filePaths: p }); }, paths);
const shot = (n) => page.screenshot({ path: path.join(SHOTS, `${n}.png`) });
const clickText = (t) => page.getByRole('button', { name: t }).first().click();

try {
  await page.waitForSelector('#home-new', { timeout: 20000 });
  step('Accueil affiché');
  await page.waitForTimeout(800);
  await shot('01-accueil');

  // Nouveau projet (dossier avec accents et espaces)
  await stubOpen([work]);
  await page.click('#home-new');
  await page.fill('#np-name', 'Collection Été');
  await page.click('#np-create');
  await page.waitForSelector('.workspace');
  assert.ok(fs.existsSync(path.join(work, 'Collection Été.fcsproj', 'project.json')));
  step('Projet créé');

  // Import de 5 fichiers
  await stubOpen(fs.readdirSync(files).map((f) => path.join(files, f)));
  await page.click('button[title="Importer (Ctrl+I)"]');
  await page.waitForSelector('#import-go');
  await shot('02-import');
  await page.click('#import-go');
  await page.waitForFunction(() => document.querySelectorAll('.panel.left .tree-item').length >= 5);
  assert.equal(await page.locator('.panel.left .tree-item').count(), 5);
  step('5 fichiers importés');

  // Aperçu 3D du GLB
  await page.locator('.tree-item', { hasText: 'veste.glb' }).click();
  await clickText('Afficher en 3D');
  await page.waitForFunction(() => /triangles/.test(document.querySelector('.viewer-info')?.textContent || ''), null, { timeout: 15000 });
  step('Modèle GLB affiché');
  await page.waitForTimeout(500);
  await shot('03-apercu-3d');

  // OBJ + MTL + texture voisine (lus dans le dossier d'origine)
  await stubOpen([path.join(objDir, 'quad.obj')]);
  await page.click('button[title="Importer (Ctrl+I)"]');
  await page.click('#import-go');
  await page.locator('.tree-item', { hasText: 'quad.obj' }).waitFor();
  await page.locator('.tree-item', { hasText: 'quad.obj' }).click();
  await clickText('Afficher en 3D');
  await page.waitForFunction(() => /quad\.obj · 1 maillage/.test(document.querySelector('.viewer-info')?.textContent || ''), null, { timeout: 15000 });
  const objIssues = await page.locator('#viewer-tools').innerText();
  assert.doesNotMatch(objIssues, /non trouvés/, 'MTL et texture voisins chargés');
  await page.waitForTimeout(400);
  await shot('03b-obj-mtl');
  step('OBJ + MTL + texture affichés');

  // Éditeur de textures
  await page.locator('.tree-item', { hasText: 't-shirt base.png' }).click();
  await clickText('Ouvrir dans l\'éditeur');
  await page.waitForSelector('.texed canvas');
  await page.locator('.slider-row', { hasText: 'Teinte' }).locator('input').fill('90');
  await page.waitForTimeout(400);
  await clickText('Appliquer');
  await page.click('button[title="Ajouter du texte"]');
  await page.locator('.modal textarea').fill('ÉLYZÉA');
  await page.locator('.modal').getByRole('button', { name: 'Ajouter' }).click();
  await stubOpen([path.join(files, 'logo.png')]);
  await page.click('button[title="Importer un logo ou une image"]');
  await page.waitForFunction(() => document.querySelectorAll('.layer').length === 3);
  step('Calques : réglage couleur, texte, logo');
  // Annuler / rétablir
  await page.keyboard.press('Control+z');
  await page.waitForFunction(() => document.querySelectorAll('.layer').length === 2);
  await page.keyboard.press('Control+y');
  await page.waitForFunction(() => document.querySelectorAll('.layer').length === 3);
  step('Annuler / rétablir');
  await page.waitForTimeout(400);
  await shot('04-editeur-texture');
  await page.locator('.panel.right').getByRole('button', { name: 'Enregistrer' }).click();
  await page.waitForTimeout(800);
  const proj = JSON.parse(fs.readFileSync(path.join(work, 'Collection Été.fcsproj', 'project.json'), 'utf8'));
  assert.equal(proj.textureDocs.length, 1);
  assert.equal(proj.textureDocs[0].layers, 3);
  step('Texture enregistrée (3 calques)');

  // Vêtement
  await page.click('#add-garment');
  await page.waitForSelector('#g-slot');
  await page.selectOption('#g-slot', 'jbib');
  await page.fill('#g-index', '15'); await page.press('#g-index', 'Tab');
  await page.locator('.variant select').nth(1).selectOption({ label: 'veste_a.ytd' });
  await page.locator('.field', { hasText: 'Modèle GTA V (.ydd)' }).locator('select').selectOption({ label: 'veste.ydd' });
  await page.waitForTimeout(300);
  await shot('05-vetement');
  step('Vêtement configuré');

  // Modèle de travail + texture appliquée au matériau « Tissu »
  await page.locator('.field', { hasText: 'Modèle 3D de travail' }).locator('select').selectOption({ label: 'veste.glb' });
  await page.waitForFunction(() => /triangles/.test(document.querySelector('.viewer-info')?.textContent || ''), null, { timeout: 15000 });
  await page.locator('#viewer-tools .field', { hasText: 'Tissu' }).locator('select').selectOption({ label: 't-shirt base' });
  await page.waitForTimeout(800);
  const pixel = await page.evaluate(() => {
    const c = document.querySelector('.viewer canvas');
    const g = c.getContext('webgl2') || c.getContext('webgl');
    const px = new Uint8Array(4);
    g.readPixels(Math.floor(c.width * 0.45), Math.floor(c.height * 0.4), 1, 1, g.RGBA, g.UNSIGNED_BYTE, px);
    return [...px];
  });
  await shot('05b-texture-sur-modele');
  assert.ok(Math.max(pixel[0], pixel[1], pixel[2]) - Math.min(pixel[0], pixel[1], pixel[2]) > 20, `texture colorée visible sur le modèle (pixel ${pixel})`);
  step('Texture appliquée au matériau du modèle 3D');
  // Patron UV dans l'éditeur
  await page.locator('.tree-item', { hasText: 't-shirt base' }).first().click();
  await page.waitForSelector('.texed canvas');
  await page.locator('label.checkbox', { hasText: 'patron UV' }).locator('input').check();
  await page.waitForTimeout(300);
  const uv = await page.evaluate(() => { const v = window.__fcs.viewer; return { models: v.models.length, seg: v.uvSegments().segments.length, mats: v.materials() }; });
  console.log('   UV :', JSON.stringify(uv));
  assert.ok(uv.seg >= 3, 'segments UV disponibles');
  const green = await page.evaluate(() => {
    const c = document.querySelectorAll('.canvas-wrap canvas')[1];
    const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
    let n = 0; for (let i = 0; i < d.length; i += 4) if (d[i + 3] > 0 && d[i + 1] > 150 && d[i] < 120) n++;
    return n;
  });
  assert.ok(green > 50, `patron UV dessiné (${green} px)`);
  await shot('05c-patron-uv');
  step('Patron UV superposé');

  // Export
  await stubOpen([out]);
  await page.getByRole('button', { name: 'Exporter pour FiveM' }).click();
  await page.waitForSelector('#exp-pack');
  await page.locator('.modal .input', { hasText: 'Choisir le dossier' }).click();
  await page.waitForTimeout(300);
  await page.click('#exp-validate');
  await page.waitForSelector('#exp-run:not([disabled])', { timeout: 15000 });
  await shot('06-validation');
  await page.click('#exp-run');
  await page.waitForSelector('.modal h2.result-ok', { timeout: 20000 });
  await shot('07-resultat');
  const res = path.join(out, 'collection_ete');
  assert.ok(fs.existsSync(path.join(res, 'stream', 'mp_m_freemode_01^jbib_015_u.ydd')));
  assert.ok(fs.existsSync(path.join(res, 'stream', 'mp_m_freemode_01^jbib_diff_015_a_uni.ytd')));
  assert.match(fs.readFileSync(path.join(res, 'README.txt'), 'utf8'), /ensure collection_ete/);
  step('Ressource exportée et vérifiée');
  await page.keyboard.press('Escape');

  // Aide, outils
  await page.click('button[title="Aide (F1)"]');
  await page.waitForSelector('.doc h1');
  await page.click('button[title="Outils et dépendances"]');
  await page.waitForSelector('.tool-card');
  await shot('08-outils');
  step('Aide et outils');
  if (errors.length) throw new Error(`Erreurs dans la console :\n${errors.join('\n')}`);
  console.log(`\nE2E RÉUSSI — captures : ${SHOTS}`);
} catch (e) {
  await shot('zz-echec').catch(() => {});
  console.error('E2E ÉCHEC :', e.message, errors.length ? `\nConsole :\n${errors.join('\n')}` : '');
  process.exitCode = 1;
} finally {
  await app.evaluate(({ app: a }) => a.exit(0)).catch(() => {});
}
