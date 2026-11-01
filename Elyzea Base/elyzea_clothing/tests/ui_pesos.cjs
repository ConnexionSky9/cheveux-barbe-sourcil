// Boutique « pesos uniquement » (Chromium, hors jeu, données fictives) : node tests/ui_pesos.cjs <dossier des captures>
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = process.argv[2] || path.join(require('os').tmpdir(), 'clothing_ui');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, l) => { if (ok) { passes++; console.log('  ok   ' + l); } else { fails++; console.log('  ÉCHEC ' + l); } };
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const errs = [];
  p.on('pageerror', (e) => errs.push(e.message));
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(500);
  await p.evaluate(() => { window.paid = null; const m = window.mock; window.mock = (ev, d) => { if (ev === 'pay') window.paid = d; return m(ev, d); }; });
  await p.evaluate(() => window.postMessage({ action: 'open', shop: { name: 'Cayo Shop', multiplier: 100 }, sex: 'male', categories: S.categories, gta: true, packs: S.packs,
    money: { pesos: 1500 }, payments: ['pesos'], currency: 'pesos', images: { enabled: false }, itemsMode: true }, '*'));
  await p.waitForTimeout(250);
  await p.click('#grid .card[data-d="3"]'); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(120);
  const pays = await p.$$eval('#cartFoot [data-pay]', (l) => l.map((x) => x.dataset.pay + ':' + x.textContent));
  check(pays.length === 1 && /^pesos:Pesos/.test(pays[0]) && /1\s?500 pesos/.test(pays[0].replace(/ /g, ' ')), 'un seul moyen de paiement : Pesos (1 500 pesos) -> ' + JSON.stringify(pays));
  const total = (await p.textContent('#cartFoot .total b')).replace(/ /g, ' ');
  check(/pesos/.test(total), 'total affiché en pesos : ' + total);
  await p.screenshot({ path: path.join(OUT, 'pesos_boutique.png') });
  await p.click('#payBtn'); await p.waitForTimeout(150);
  const paid = await p.evaluate(() => window.paid);
  check(paid && paid.method === 'pesos', 'paiement envoyé avec la méthode « pesos »');
  console.log('erreurs JS : ' + (errs.length ? errs.join(' | ') : 'aucune')); if (errs.length) fails++;
  console.log(`\n${passes} ok, ${fails} échec(s)`);
  await b.close(); process.exit(fails ? 1 : 0);
})();
