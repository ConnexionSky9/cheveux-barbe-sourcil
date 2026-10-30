// Test de la boutique (navigateur Chromium, hors jeu, données fictives) : node tests/ui_cart.cjs <dossier des captures>
// Panier à plusieurs articles par rayon, classé par rayon, pièce « Sur toi », vider, payer.
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
  p.on('console', (m) => { if (m.type() === 'error' && !/fonts|Failed to load resource/.test(m.text())) errs.push(m.text()); });
  await p.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
  await p.waitForTimeout(500);
  await p.evaluate(() => { window.paid = null; const m = window.mock; window.mock = (ev, d) => { if (ev === 'pay') window.paid = d; return m(ev, d); }; });
  const shot = (n) => p.screenshot({ path: path.join(OUT, n + '.png') });
  const cartItems = () => p.$$eval('#cartItems .ci', (l) => l.length);

  console.log('\n[Plusieurs articles du même rayon]');
  check(await p.isVisible('#app'), 'boutique ouverte');
  await shot('1_boutique_vide');
  // 3 hauts
  for (const d of [0, 1, 2]) { await p.click(`#grid .card[data-d="${d}"]`); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60); }
  check(await cartItems() === 3, '3 hauts différents dans le panier');
  check((await p.textContent('#rail [data-cat="tops"] .dot')) === '3', 'le menu des rayons montre le nombre d\'articles (3)');
  // même article : bouton désactivé
  await p.click('#grid .card[data-d="2"]'); await p.waitForTimeout(60);
  check(await p.isDisabled('#add') && /Dans le panier/.test(await p.textContent('#add')), 'le même article ne s\'ajoute pas deux fois');
  // autre coloris du même modèle : possible
  await p.click('#detail [data-t="1"]'); await p.waitForTimeout(80);
  check(!(await p.isDisabled('#add')) && /3 hauts déjà/.test(await p.textContent('#add')), 'autre coloris du même modèle : ajout possible (« 3 hauts déjà »)');
  // 2 pantalons, 1 chapeau
  await p.click('#rail [data-cat="pants"]'); await p.waitForTimeout(150);
  for (const d of [3, 4]) { await p.click(`#grid .card[data-d="${d}"]`); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60); }
  await p.click('#rail [data-cat="hats"]'); await p.waitForTimeout(150);
  await p.click('#grid .card[data-d="5"]'); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60);
  check(await cartItems() === 6, '6 articles : 3 hauts, 2 pantalons, 1 chapeau');
  check(!(await p.$('#grid .card[data-d="-1"]')), 'vêtements en objets : pas de carte « Aucun » (on range depuis F3)');

  console.log('\n[Panier classé par rayon]');
  const heads = await p.$$eval('#cartItems .ghead b', (l) => l.map((x) => x.textContent));
  check(JSON.stringify(heads) === JSON.stringify(['Hauts', 'Pantalons', 'Chapeaux']), 'rubriques dans l\'ordre des rayons : ' + heads.join(', '));
  const counts = await p.$$eval('#cartItems .ghead i', (l) => l.map((x) => x.textContent));
  check(counts.join() === '3,2,1', 'nombre par rubrique : ' + counts.join(' / '));
  check(/6 articles · 3 rayons/.test(await p.textContent('#cartSum')), 'résumé : 6 articles · 3 rayons');
  const sub = await p.textContent('#cartItems .cgroup:first-child .ghead span');
  check(/360/.test(sub), 'sous-total des hauts : ' + sub.trim());
  check(/^600/.test((await p.textContent('#cartFoot .total b')).replace(/\s/g, '')), 'total : 3 × 120 + 2 × 90 + 60 = 600 $');
  await shot('2_panier_classe');

  console.log('\n[Pièce « Sur toi » par rayon]');
  check((await p.$$eval('#cartItems .cgroup:first-child .wearbtn.on', (l) => l.length)) === 1, 'une seule pièce « Sur toi » par rayon');
  await p.locator('#cartItems .cgroup:first-child .ci .wearbtn').first().click();
  await p.waitForTimeout(80);
  const on = await p.$$eval('#cartItems .cgroup:first-child .ci', (l) => l.map((x) => x.classList.contains('worn')));
  check(on[0] === true && on.filter(Boolean).length === 1, 'choisir une autre pièce à porter');
  await p.check('#wearNow'); await p.waitForTimeout(50);
  check(/Une pièce par rayon/.test(await p.textContent('#cartFoot')), 'explication « une pièce par rayon » quand « Porter tout de suite » est coché');
  await shot('3_porter_tout_de_suite');

  console.log('\n[Retirer, vider, payer]');
  await p.locator('#cartItems .cgroup:first-child .ci .rm').first().click(); await p.waitForTimeout(60);
  check(await cartItems() === 5 && (await p.$$eval('#cartItems .cgroup:first-child .wearbtn.on', (l) => l.length)) === 1, 'retirer la pièce « Sur toi » : une autre prend sa place');
  await p.click('#payBtn'); await p.waitForTimeout(100);
  const paid = await p.evaluate(() => window.paid);
  const tops = paid.cart.filter((x) => x.cat === 'tops');
  check(paid && paid.cart.length === 5 && tops.length === 2 && tops.filter((x) => x.wear).length === 1 && paid.wearNow === true, 'paiement : 5 articles envoyés, une pièce à porter par rayon');
  await p.waitForTimeout(700);
  await shot('4_achat');
  // nouvelle ouverture pour tester « Vider »
  await p.evaluate(() => window.postMessage({ action: 'open', shop: { name: 'Ponsonbys', multiplier: 100 }, sex: 'male', categories: S.categories, gta: true, packs: S.packs,
    money: { cash: 1840, bank: 26350 }, payments: ['cash', 'bank'], currency: '$', images: { enabled: false }, itemsMode: true }, '*'));
  await p.waitForTimeout(200);
  for (const d of [7, 8]) { await p.click(`#grid .card[data-d="${d}"]`); await p.waitForTimeout(50); await p.click('#add'); await p.waitForTimeout(50); }
  await p.click('#cartClear'); await p.click('[data-m="clear"]'); await p.waitForTimeout(80);
  check(await cartItems() === 0 && /vide/.test(await p.textContent('#cartItems')), '« Vider » le panier');
  // performance : temps passé dans le code de la page (survol, redessin de la grille), sans le coût de l'outil de test
  const perf = await p.evaluate(() => {
    const cards = [...document.querySelectorAll('#grid .card')];
    const t0 = performance.now();
    for (let i = 0; i < 300; i++) cards[i % cards.length].dispatchEvent(new MouseEvent('mouseover', { bubbles: true }));
    const hover = (performance.now() - t0) / 300;
    const t1 = performance.now();
    for (let i = 0; i < 20; i++) renderGrid(true);
    return { hover, grid: (performance.now() - t1) / 20 };
  });
  check(perf.hover < 2 && perf.grid < 40, `rapide : survol ${perf.hover.toFixed(2)} ms, grille entière ${perf.grid.toFixed(1)} ms (pas de blocage)`);
  check(await p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), 'pas de défilement horizontal');
  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await b.close();
  console.log(`\nRésultat : ${passes} réussis, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
