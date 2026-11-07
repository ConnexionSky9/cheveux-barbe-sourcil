// Test du menu staff : Gestion immobilière › Immeubles (elyzea_dynasty 1.2), Chromium headless.
// node tests/dynasty_buildings_ui.cjs [dossier captures] [échelle]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
const scale = Number(process.argv[3] || 1);
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
const cfg = { cameras: { enabled: true, price: 15000, max: 4, radius: 25, fovMin: 25, fovMax: 90, payTo: 'agency' },
  dancer: { enabled: true, max: 1, cooldownSeconds: 20, payTo: 'agency', styles: [{ id: 'glamour', label: 'Glamour', on: true }], tariffs: [{ minutes: 30, price: 2500 }, { minutes: 60, price: 4500 }, { minutes: 120, price: 8000 }] },
  cannabis: { enabled: true, price: 20000, payTo: 'none', maxPots: 3, speed: 1 } };
const pts = (x) => ({ enter: true, bell: false, exit: x, manage: x, stash: x, garage: false, slots: 0 });
const d8 = { available: true, cfg, spots: [], categories: { apartment: 'Appartement', house: 'Maison', villa: 'Villa', garage: 'Garage' }, sizes: { small: { label: 'Petit garage', capacity: 2 } },
  interiors: [{ id: 1, label: 'Appartement modeste', kind: 'apartment' }, { id: 2, label: 'Appartement standing moyen', kind: 'apartment' }, { id: 10, label: '3655 Wild Oats Drive', kind: 'house' }],
  props: [{ id: 21, name: 'Apt 1', category: 'apartment', enabled: true, status: 'available', salePrice: 180000, rentPrice: 900, building: 3, points: pts(true), upgrades: [] },
    { id: 22, name: 'Apt 2', category: 'apartment', enabled: true, status: 'sold', holder: 'Alice Martin', kind: 'sale', salePrice: 180000, rentPrice: 900, building: 3, points: pts(true), upgrades: [] },
    { id: 23, name: 'Apt 3', category: 'apartment', enabled: false, status: 'available', salePrice: 180000, rentPrice: 900, building: 3, points: pts(false), upgrades: [] },
    { id: 30, name: 'Studio Vespucci', category: 'apartment', enabled: true, status: 'available', salePrice: 120000, rentPrice: 600, points: pts(true), upgrades: [] }],
  buildings: [{ id: 3, name: 'Résidence Alta', address: 'Alta Street', x: 500, y: -300, z: 40, h: 0, r: 1.6, enabled: true, blip: true,
    apts: [{ id: 21, name: 'Apt 1', enabled: true, ready: true }, { id: 22, name: 'Apt 2', enabled: true, holder: 'Alice Martin', ready: true }, { id: 23, name: 'Apt 3', enabled: false, ready: false }] }] };
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1500, height: 1000 }, deviceScaleFactor: scale });
  const posts = [];
  page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
  await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
  await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
  await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await page.evaluate((d8) => {
    window.postMessage({ action: 'open' }, '*');
    window.postMessage({ action: 'data', data: { me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { property_manage: true }, onDuty: true, duty: true },
      players: [], keys: [], jobs: [], d8, config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
      editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
  }, d8);
  await page.waitForTimeout(300);
  await page.evaluate(() => { tab = 'dynasty'; render(); }); await page.waitForTimeout(200);
  let t = await page.textContent('#content');
  check(t.includes('Immeubles (1)') && t.includes('Résidence Alta') && !t.includes('undefined'), 'section Immeubles affichée');
  const act = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'd8').map((p) => p.body.data).pop();
  await page.fill('[data-d8bf="name"]', 'Tour Eclipse');
  await page.click('[data-d8b="create"]'); await page.waitForTimeout(100);
  check(act() && act().name === 'bCreate' && act().data.name === 'Tour Eclipse', 'créer un immeuble à ma position');
  await page.click('[data-d8bsel="3"]'); await page.waitForTimeout(100);
  t = await page.textContent('#content');
  check(t.includes('Appartements (3)') && t.includes('points intérieurs à placer') && t.includes('Studio Vespucci'), 'immeuble ouvert : appartements, alerte points, rattachement possible');
  await page.evaluate(() => { const s = document.querySelector('[data-d8bf="name"]'); s.closest('.section').scrollIntoView(); });
  await page.evaluate(() => { const el = document.querySelector('[data-d8b="move"]'); el.scrollIntoView({ block: 'center' }); });
  await page.screenshot({ path: path.join(out, 'admin_immeuble.png') });
  await page.selectOption('[data-d8ba="interiorId"]', '2');
  await page.fill('[data-d8ba="name"]', 'Apt 4');
  await page.click('[data-d8b="apt"]'); await page.waitForTimeout(100);
  check(act().name === 'bCreateApt' && act().data.id === 3 && act().data.interiorId === 2 && act().data.name === 'Apt 4', 'créer « Apt 4 » dans l\'immeuble');
  await page.click('[data-d8b="attach"]'); await page.waitForTimeout(100);
  check(act().name === 'bAttach' && act().data.pid === 30, 'rattacher « Studio Vespucci »');
  await page.click('[data-d8b="move"]'); await page.waitForTimeout(100);
  check(act().name === 'bMove' && act().data.id === 3, 'déplacer la porte');
  await page.click('[data-d8b="toggle"][data-k="blip"]'); await page.waitForTimeout(100);
  check(act().name === 'bSave' && act().data.blip === false, 'blip coupé');
  await page.click('[data-d8arm="bdetach:23"]'); await page.waitForTimeout(80);
  await page.click('[data-d8arm="bdetach:23"]'); await page.waitForTimeout(100);
  check(act().name === 'bDetach' && act().data.pid === 23, 'détacher (avec confirmation)');
  await page.click('[data-d8sel="22"]'); await page.waitForTimeout(150);
  t = await page.textContent('#content');
  check(t.includes('Entrée : immeuble « Résidence Alta »') && t.includes('pas de caméras ni de culture') && !t.includes('Emplacements des caméras'), 'assistant d\'un appartement d\'immeuble : entrée de l\'immeuble, pas de caméras');
  await page.evaluate(() => { const el = [...document.querySelectorAll('h2')].find((h) => h.textContent.includes('Assistant')); if (el) el.scrollIntoView(); });
  await page.screenshot({ path: path.join(out, 'admin_assistant_appartement.png') });
  await browser.close();
  console.log(`\nImmeubles (menu staff) : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
