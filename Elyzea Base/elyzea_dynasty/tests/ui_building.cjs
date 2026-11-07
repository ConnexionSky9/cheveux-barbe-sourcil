// Test et aperçus de l'interface « Immeuble » (Chromium). node tests/ui_building.cjs [dossier captures] [échelle]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
const scale = Number(process.argv[3] || 1);
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
const DATA = { ok: true, id: 3, name: 'Résidence Alta', address: 'Alta Street, Pillbox Hill', bellCooldown: 20, staff: false, apts: [
  { id: 21, name: 'Apt 1', status: 'available', statusLabel: 'Disponible', occupied: false, salePrice: 180000, rentPrice: 900 },
  { id: 22, name: 'Apt 2', status: 'sold', statusLabel: 'Occupé', role: 'holder', canEnter: true, occupied: true, hasCode: true },
  { id: 23, name: 'Apt 3', status: 'rented', statusLabel: 'Occupé', occupied: true, hasCode: true },
  { id: 24, name: 'Apt 4', status: 'rented', statusLabel: 'Occupé', occupied: true, hasCode: false },
  { id: 25, name: 'Apt 5', status: 'sold', statusLabel: 'Occupé', role: 'tenant', canEnter: true, occupied: true, hasCode: true },
  { id: 26, name: 'Apt 6', status: 'sold', statusLabel: 'Occupé', occupied: true, hasCode: true, granted: false },
  { id: 27, name: 'Penthouse 12', status: 'available', statusLabel: 'Disponible', occupied: false, rentPrice: 2500 } ] };
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: scale });
  const posts = [];
  page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
  await page.route(/^https?:\/\/(?!fonts)/, (r) => r.abort());
  await page.addInitScript(() => {
    window.__posts = [];
    window.EDemo = async (name, data) => { window.__posts.push({ name, data }); if (name === 'building' && data.do_ === 'code') return data.code === '2580' ? { ok: true } : { error: 'Code incorrect.' };
      if (name === 'building' && data.do_ === 'bell') return { ok: true, message: 'Vous avez sonné : attendez la réponse des résidents.' }; return { ok: true }; };
  });
  await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await page.evaluate(() => { document.documentElement.style.background = 'radial-gradient(ellipse at 30% 20%, #4a4152, #15121b 70%)'; });
  await page.evaluate((d) => window.postMessage({ action: 'building', show: true, data: d }, '*'), DATA);
  await page.waitForTimeout(1200);
  const names = await page.$$eval('.apt .nm', (l) => l.map((x) => x.textContent));
  check(names[0] === 'Apt 2' && names[1] === 'Apt 5' && names.length === 7, `mes appartements en premier (${names.slice(0, 3).join(', ')}…)`);
  check(await page.$$eval('[data-pid="22"][data-bd="enter"]', (l) => l.length) === 1, 'Apt 2 (mien) : bouton Entrer');
  check(await page.$$eval('[data-pid="23"]', (l) => l.map((x) => x.dataset.bd).join(',')) === 'pad,bell', 'Apt 3 : Code + Sonner');
  check(await page.$$eval('[data-pid="24"]', (l) => l.map((x) => x.dataset.bd).join(',')) === 'bell', 'Apt 4 sans code : Sonner seulement');
  await page.screenshot({ path: path.join(out, 'immeuble_liste.png') });
  await page.fill('#bdq', 'pent');
  await page.waitForTimeout(500);
  check((await page.$$eval('.apt', (l) => l.length)) === 1, 'recherche « pent » : 1 résultat');
  await page.fill('#bdq', '');
  await page.click('[data-pid="23"][data-bd="pad"]');
  await page.waitForTimeout(400);
  for (const k of ['1', '2', '3']) await page.click(`[data-key="${k}"]`);
  await page.screenshot({ path: path.join(out, 'immeuble_code.png') });
  await page.click('[data-key="4"]'); await page.click('[data-key="ok"]');
  await page.waitForTimeout(250);
  check((await page.textContent('.pad .err')).includes('Code incorrect'), 'mauvais code : message, pavé secoué');
  await page.screenshot({ path: path.join(out, 'immeuble_code_faux.png') });
  await page.waitForTimeout(800);
  await page.keyboard.type('2580'); await page.keyboard.press('Enter');
  await page.waitForTimeout(300);
  const ps = await page.evaluate(() => window.__posts);
  const last = ps.filter((p) => p.name === 'building').pop();
  check(last && last.data.do_ === 'code' && last.data.code === '2580' && last.data.pid === 23, 'code au clavier envoyé (2580, Apt 3)');
  await page.keyboard.press('Escape'); await page.waitForTimeout(200);
  await page.click('[data-pid="24"][data-bd="bell"]'); await page.waitForTimeout(300);
  check((await page.evaluate(() => window.__posts)).filter((p) => p.data && p.data.do_ === 'bell').length === 1, 'sonnette envoyée');
  await page.click('[data-pid="24"][data-bd="bell"]'); await page.waitForTimeout(300);
  check((await page.evaluate(() => window.__posts)).filter((p) => p.data && p.data.do_ === 'bell').length === 1, 'anti-spam : deuxième sonnette bloquée côté interface');
  await page.keyboard.press('Escape'); await page.waitForTimeout(200);
  check((await page.evaluate(() => window.__posts)).some((p) => p.name === 'close' && p.data.ui === 'building'), 'Échap : fermeture demandée');
  await b.close();
  console.log(`\nInterface immeuble : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
