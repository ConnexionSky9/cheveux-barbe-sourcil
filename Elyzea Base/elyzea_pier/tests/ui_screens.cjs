// Interface dans Chromium (Playwright) : aucun écran ne doit produire d'erreur JavaScript.  node tests/ui_screens.cjs [dossier]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = process.argv[2] || path.join(__dirname, 'screens');
const SCREENS = ['menu', 'coaster', 'tickets', 'hud-queue', 'hud-wheel', 'hud-coaster'];
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  let fails = 0;
  for (const s of SCREENS) {
    const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html') + '?demo=' + s);
    await page.waitForTimeout(500);
    if (s === 'menu') { await page.click('[data-q="1"]'); await page.click('[data-pay="cash"]'); await page.waitForTimeout(300); }
    await page.screenshot({ path: path.join(OUT, s + '.png') });
    if (errors.length) fails++;
    console.log((errors.length ? 'ÉCHEC ' : '  ok  ') + s + (errors.length ? ' → ' + errors.join(' | ') : ''));
    await page.close();
  }
  await browser.close();
  console.log(`${SCREENS.length - fails}/${SCREENS.length} écrans sans erreur`);
  process.exit(fails ? 1 : 0);
})();
