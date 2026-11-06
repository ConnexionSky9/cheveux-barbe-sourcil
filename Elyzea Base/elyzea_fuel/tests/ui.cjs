// Écran de la pompe dans Chromium (mode démo) : aucune erreur JavaScript, chiffres cohérents, captures.
//   node tests/ui.cjs [dossier_captures]
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = process.argv[2] || path.join(__dirname, 'screens');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
const num = (t) => Number(String(t).replace(/\s| | /g, '').replace(',', '.'));
(async () => {
  const browser = await chromium.launch();
  for (const step of ['prompt', 'hand', 'pump', 'spill', 'receipt']) {
    const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    page.on('console', (m) => { if (m.type() === 'error' && !/fonts\.g|ERR_|Failed to load resource/.test(m.text())) errors.push(m.text()); });
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html') + '?demo=' + step);
    if (step === 'prompt') {
      await page.waitForTimeout(300);
      check(await page.isVisible('#prompt') && (await page.textContent('#ptext')).includes('Prendre le pistolet') && (await page.textContent('#pkey')) === 'E', 'invite « E Prendre le pistolet » avec le prix au litre');
      await page.screenshot({ path: path.join(OUT, 'fuel_prompt.png'), clip: { x: 500, y: 700, width: 600, height: 130 } });
    }
    if (step === 'hand') {
      await page.waitForTimeout(900);
      check(await page.isVisible('#pump') && (await page.textContent('#status')).includes('Insère le pistolet') && (await page.textContent('#keys')).includes('raccrocher'), 'pistolet en main : consignes « insérer » / « raccrocher »');
    }
    if (step === 'pump') {
      await page.waitForTimeout(1600);
      const c1 = num(await page.textContent('#cost')), l1 = num(await page.textContent('#liters'));
      await page.waitForTimeout(1200);
      const c2 = num(await page.textContent('#cost')), l2 = num(await page.textContent('#liters'));
      check(c2 > c1 && l2 > l1, `l'argent et les litres montent (${c1} → ${c2} $, ${l1} → ${l2} L)`);
      check(Math.abs(c2 - l2 * 3.15) < 0.6, `montant ≈ litres × prix (${c2} $ pour ${l2} L à 3,15 $)`);
      const w = await page.$eval('#fill', (e) => parseFloat(e.style.width));
      check(w > 18 && w < 100, `le réservoir se remplit (${w.toFixed(1)} %)`);
      check(await page.$eval('#pump', (e) => e.classList.contains('pumping')) && (await page.textContent('#status')).includes('Remplissage'), 'état « remplissage en cours » (voyant, vague)');
      await page.screenshot({ path: path.join(OUT, 'fuel_pump.png'), clip: { x: 1180, y: 250, width: 420, height: 520 } });
    }
    if (step === 'spill') {
      await page.waitForTimeout(5200);
      check(await page.$eval('#pump', (e) => e.classList.contains('spilling')) && (await page.textContent('#status')).includes('déborde'), 'réservoir plein : alerte « l\'essence déborde »');
      check(await page.isVisible('#spillBox') && num(await page.textContent('#spilled')) > 0, 'litres renversés affichés');
      check((await page.textContent('#free')).includes('PLEIN') && (await page.textContent('#pct')).startsWith('100'), 'jauge à 100 % « PLEIN »');
      await page.screenshot({ path: path.join(OUT, 'fuel_spill.png'), clip: { x: 1180, y: 250, width: 420, height: 560 } });
    }
    if (step === 'receipt') {
      await page.waitForTimeout(5000);
      const t = await page.textContent('#receipt');
      check(await page.isVisible('#receipt') && t.includes('PAYÉ') && t.includes('Essence mise') && t.includes('arrondi'), 'ticket de fin : litres, prix, total payé (arrondi au dollar)');
      await page.screenshot({ path: path.join(OUT, 'fuel_receipt.png'), clip: { x: 1180, y: 250, width: 420, height: 520 } });
    }
    check(errors.length === 0, `écran « ${step} » sans erreur JavaScript` + (errors.length ? ' → ' + errors.join(' | ') : ''));
    await page.close();
  }
  await browser.close();
  console.log(`\nÉcran de la pompe : ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
