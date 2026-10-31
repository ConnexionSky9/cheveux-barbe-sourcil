// Test d'interface : panneau Matériaux › bibliothèque de textures (Playwright + Chromium, hors jeu).
// Usage : python3 tests/make_init.py > /tmp/init.json && NODE_PATH=$(npm root -g) node tests/ui_textures.cjs /tmp/init.json [captures]
const path = require('path');
const fs = require('fs');
const zlib = require('zlib');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..');
const INIT = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const OUT = process.argv[3] || path.join(ROOT, 'tests', 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, l) => { if (ok) { passes++; console.log('  ok   ' + l); } else { fails++; console.log('  ÉCHEC ' + l); } };
// Petite image PNG (dégradé) écrite sur le disque comme un fichier du PC
function png(w, h) {
  const rows = [];
  for (let y = 0; y < h; y++) { const r = [0]; for (let x = 0; x < w; x++) r.push(150 + (x * 3) % 100, 40 + y, 30); rows.push(Buffer.from(r)); }
  const chunk = (t, d) => { const b = Buffer.alloc(8 + d.length + 4); b.writeUInt32BE(d.length, 0); b.write(t, 4); d.copy(b, 8); b.writeUInt32BE(zlib.crc32 ? zlib.crc32(Buffer.concat([Buffer.from(t), d])) >>> 0 : 0, 8 + d.length); return b; };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(Buffer.concat(rows))), chunk('IEND', Buffer.alloc(0))]);
}
const IMG = path.join(OUT, 'brique_test.png');
fs.writeFileSync(IMG, png(40, 30));

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  await page.addInitScript(() => {
    window.__posts = [];
    window.DemoPost = (name, data) => {
      window.__posts.push({ name, data });
      if (name === 'kitStatus') return { kits: { blocs: { present: 10, total: 10 }, ubk: { present: 0, total: 379 } }, ubkMaterials: {} };
      if (name === 'checkModels') return { models: {} };
      if (name === 'prefs:get') return { fav: [], recent: [] };
      if (name === 'estimate' && data.kind === 'terrain') return { ok: true, pieces: { ile: 994, montagne: 1806, plat: 576 }, max: { element: 1500, op: 2500 } };
      if (name === 'estimate' && data.kind === 'building') return { ok: true, list: data.list.map((o, i) => ({ pieces: 400 + i * 100, biggest: 80 })), max: { element: 1500, op: 2500 } };
      if (name === 'terrainHeights') return { ok: true, heights: [], pieces: data.kind === 'montagne' ? 1806 : 994, max: 1500 };
      return { ok: true };
    };
  });
  await page.goto('file://' + path.join(ROOT, 'html', 'index.html'));
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  INIT.action = 'open';
  INIT.current = 'p1';
  await send(INIT);
  await page.waitForTimeout(300);
  await send({ action: 'project', project: { id: 'p1', name: 'Test', elements: {}, textures: [], origin: { x: 0, y: 0, z: 70 } } });
  await page.waitForTimeout(300);
  await page.click('#right .tabs button[data-tab="materiaux"]');
  await page.waitForTimeout(300);
  check(await page.isVisible('#texFile') || (await page.locator('#texFile').count()) === 1, 'bouton « Image du PC » présent');
  // Import d'une image du PC à 256 × 256
  await page.selectOption('#texW', '256'); await page.selectOption('#texH', '256');
  await page.fill('#texName', 'Brique test');
  await page.setInputFiles('#texFile', IMG);
  await page.waitForTimeout(800);
  const up = await page.evaluate(() => window.__posts.find((p) => p.name === 'tex:upload'));
  check(up && up.data.kind === 'image' && up.data.w === 256 && up.data.h === 256 && up.data.name === 'Brique test', 'image envoyée : nom et résolution choisis');
  const dims = up && await page.evaluate((src) => new Promise((r) => { const i = new Image(); i.onload = () => r([i.width, i.height]); i.src = src; }), up.data.data);
  check(up && /^data:image\/png;base64,/.test(up.data.data) && dims && dims[0] === 256 && dims[1] === 256, `image convertie en PNG 256 × 256 (${dims})`);
  // Le serveur renvoie la bibliothèque
  await send({ action: 'texLibrary', textures: [{ id: 'tx1', name: 'Brique test', kind: 'image', w: 256, h: 256 }, { id: 'tx2', name: 'Logo', kind: 'url', url: 'https://exemple.invalid/logo.png', w: 256, h: 256 }] });
  await send({ action: 'texData', id: 'tx1', data: up.data.data });
  await page.waitForTimeout(300);
  check((await page.locator('.texCard').count()) === 2, 'bibliothèque : 2 textures affichées');
  check(await page.evaluate(() => (document.querySelector('img[data-texprev="tx1"]') || {}).src || '').then((s) => s.startsWith('data:image/png')), 'aperçu de l\'image importée');
  // Lien https
  await page.fill('#texUrl', 'http://pas-https.fr/a.png');
  await page.click('#texUrlAdd');
  check((await page.textContent('#texMsg')).includes('https'), 'lien non https refusé dans l\'interface');
  await page.fill('#texUrl', 'https://exemple.invalid/mur.jpg');
  await page.click('#texUrlAdd');
  const upUrl = await page.evaluate(() => window.__posts.filter((p) => p.name === 'tex:upload').pop());
  check(upUrl.data.kind === 'url' && upUrl.data.url === 'https://exemple.invalid/mur.jpg', 'lien https envoyé');
  // Remplacements
  await page.click('#texAdd');
  await page.waitForTimeout(150);
  await page.fill('.texRow [data-t="target"]', 'ubk_textures|ubk_brique');
  await page.dispatchEvent('.texRow [data-t="target"]', 'change');
  await page.waitForTimeout(150);
  await page.selectOption('.texRow [data-t="tex"]', 'tx1');
  await page.waitForTimeout(150);
  check(await page.evaluate(() => [...document.querySelectorAll('#texTargets option')].some((o) => o.value === 'ubk_textures|ubk_brique')), 'cibles proposées : matériaux du kit (ubk_textures|ubk_brique…)');
  await page.screenshot({ path: path.join(OUT, 'builder_textures.png') });
  await page.click('#texSave');
  await page.waitForTimeout(200);
  const set = await page.evaluate(() => window.__posts.filter((p) => p.name === 'textures:set').pop());
  check(set && set.data.list.length === 1 && set.data.list[0].txd === 'ubk_textures' && set.data.list[0].txn === 'ubk_brique' && set.data.list[0].tex === 'tx1', 'remplacement envoyé : cible + texture de la bibliothèque');
  await page.click('#texAdd');
  await page.waitForTimeout(150);
  await page.click('#texSave');
  await page.waitForTimeout(200);
  check((await page.textContent('#toasts')).includes('dictionnaire|texture'), 'remplacement incomplet : refusé avec explication');
  // Estimations du nombre d'objets (cause des plantages : trop d'objets pour GTA)
  await page.click('[data-mode="terrain"]');
  await page.waitForTimeout(400);
  check((await page.textContent('[data-ter-preset="ile"]')).includes('994 objets'), 'terrain : estimation affichée sur la carte (île ≈ 994 objets)');
  check(await page.locator('[data-ter-preset="montagne"].heavy').count() === 1, 'montagne trop lourde : carte grisée « trop lourd »');
  await page.click('[data-ter-preset="montagne"]');
  await page.waitForTimeout(300);
  check((await page.textContent('#toasts')).includes('1806'), 'clic sur un terrain trop lourd : refusé avant de poser, avec explication');
  await page.screenshot({ path: path.join(OUT, 'builder_terrain_estimation.png') });
  await page.click('[data-mode="urbanisme"]');
  await page.waitForTimeout(400);
  check((await page.locator('[data-bp] .est').count()) === 7, 'immeubles : estimation affichée sur les 7 cartes');
  check(!(await page.textContent('#palette')).includes('Gratte-ciel'), 'préréglages trop lourds (tour 15 étages, gratte-ciel 40) retirés');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await browser.close();
  console.log(`\nTOTAL : ${passes} ok, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
