// Test de l'interface NUI dans Chromium (Playwright) : chaque écran du mode démo est ouvert,
// aucune erreur JavaScript ne doit apparaître, et une capture est enregistrée.
//   node tests/ui_screens.cjs [dossier_captures]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const ROOT = path.join(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'tests', 'screens');
const SCREENS = ['home', 'pvp', 'create', 'lobby', 'zombie', 'zlobby', 'ranks', 'profile', 'history', 'settings', 'admin', 'hud-pvp', 'hud-zombie', 'results', 'zresults', 'loading'];

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  let failures = 0;
  for (const s of SCREENS) {
    const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error' && !/fonts\.g|ERR_|Failed to load resource/.test(m.text())) errors.push(m.text()); });
    await page.goto('file://' + path.join(ROOT, 'html', 'index.html') + '?demo=' + s);
    await page.waitForTimeout(900);
    // interactions de base sur certains écrans
    if (s === 'admin') {
      for (const tab of ['pvp', 'weapons', 'zombie', 'zprices', 'maps', 'npcs', 'players', 'logs', 'games']) {
        await page.click(`[data-atab="${tab}"]`);
        await page.waitForTimeout(120);
      }
      await page.click('[data-atab="zombie"]');
      await page.waitForTimeout(200);
    }
    if (s === 'ranks') { await page.click('[data-lbg="zombie"]'); await page.waitForTimeout(250); await page.click('[data-lbg="pvp"]'); await page.waitForTimeout(250); }
    if (s === 'create') { await page.click('[data-cs="format"][data-v="5v5"]'); await page.click('[data-cs="map"][data-v="pvp_large"]'); await page.click('[data-ct="private"]'); await page.waitForTimeout(150); }
    const file = path.join(OUT, `${s}.png`);
    await page.screenshot({ path: file });
    const ok = errors.length === 0;
    if (!ok) failures++;
    console.log(`${ok ? '  ok  ' : 'ÉCHEC '} ${s}${ok ? '' : ' → ' + errors.join(' | ')}`);
    await page.close();
  }
  await browser.close();
  console.log(`${SCREENS.length - failures}/${SCREENS.length} écrans sans erreur`);
  process.exit(failures ? 1 : 0);
})();
