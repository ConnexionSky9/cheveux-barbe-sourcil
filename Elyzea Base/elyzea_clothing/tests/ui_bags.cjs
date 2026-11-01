// Sacs de shopping (Chromium, hors jeu) : choix avec / sans sac au paiement, fenêtre du sac, choix dans le coffre, cadeau
// NODE_PATH=$(npm root -g) node tests/ui_bags.cjs <dossier des captures>
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
  await p.evaluate(() => { window.paid = null; const m = window.mock; window.mock = (ev, d) => { if (ev === 'pay') window.paid = d; return m(ev, d); };
    window.bagCalls = []; window.bagMock = (ev, d) => window.bagCalls.push([ev, d]); });
  // boutique avec sacs
  await p.evaluate(() => window.postMessage({ action: 'open', shop: { name: 'Ponsonbys', multiplier: 100 }, sex: 'male', categories: S.categories, gta: true, packs: S.packs,
    money: { cash: 5000, bank: 0 }, payments: ['cash', 'bank'], currency: '$', images: { enabled: false }, itemsMode: true, bags: true }, '*'));
  await p.waitForTimeout(250);
  console.log('\n[Choix au paiement]');
  for (const d of [2, 3]) { await p.click(`#grid .card[data-d="${d}"]`); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60); }
  check(await p.isVisible('.bagopt'), 'choix « Avec un sac / Sans sac » affiché avant de payer');
  check(await p.$eval('.bagopt [data-bag="1"]', (e) => e.classList.contains('on')), 'par défaut : avec un sac');
  await p.screenshot({ path: path.join(OUT, 'sac_choix.png') });
  await p.click('#payBtn'); await p.waitForTimeout(150);
  let paid = await p.evaluate(() => window.paid);
  check(paid && paid.withBag === true, 'paiement envoyé « avec un sac »');
  await p.waitForTimeout(800); await p.evaluate(() => { document.querySelector('#modal').innerHTML = ''; });
  await p.evaluate(() => window.postMessage({ action: 'open', shop: { name: 'Ponsonbys', multiplier: 100 }, sex: 'male', categories: S.categories, gta: true, packs: S.packs,
    money: { cash: 5000, bank: 0 }, payments: ['cash', 'bank'], currency: '$', images: { enabled: false }, itemsMode: true, bags: true }, '*'));
  await p.waitForTimeout(200);
  await p.click('#grid .card[data-d="4"]'); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60);
  await p.click('.bagopt [data-bag="0"]'); await p.waitForTimeout(60);
  await p.click('#payBtn'); await p.waitForTimeout(150);
  paid = await p.evaluate(() => window.paid);
  check(paid && paid.withBag === false, '« Sans sac » choisi : envoyé sans sac');
  await p.waitForTimeout(800); await p.evaluate(() => { document.querySelector('#modal').innerHTML = ''; });
  await p.evaluate(() => window.postMessage({ action: 'open', shop: { name: 'Ponsonbys', multiplier: 100 }, sex: 'male', categories: S.categories, gta: true, packs: S.packs,
    money: { cash: 5000, bank: 0 }, payments: ['cash', 'bank'], currency: '$', images: { enabled: false }, itemsMode: true, bags: false }, '*'));
  await p.waitForTimeout(200);
  await p.click('#grid .card[data-d="5"]'); await p.waitForTimeout(60); await p.click('#add'); await p.waitForTimeout(60);
  check(!(await p.$('.bagopt')), 'sacs désactivés : pas de choix affiché');
  await p.evaluate(() => window.postMessage({ action: 'close' }, '*'));
  await p.evaluate(() => document.querySelector('#app').classList.add('hidden'));

  console.log('\n[Fenêtre du sac]');
  const bag = { id: 'B123', color: 'rose', colorLabel: 'rose', hex: '#ff5fa8', shop: 'Ponsonbys', total: 3,
    items: [{ first: 1, qty: 2, label: 'Veste en cuir', cat: 'Hauts', catId: 'tops', sex: 'male' }, { first: 3, qty: 1, label: 'Jean slim', cat: 'Pantalons', catId: 'pants', sex: 'male' }] };
  await p.evaluate((bag) => window.postMessage({ action: 'bagView', bag }, '*'), bag);
  await p.waitForTimeout(250);
  check(await p.isVisible('#bagUi .bg-card'), 'fenêtre ouverte');
  const rows = await p.$$eval('#bagUi .bg-item', (l) => l.map((e) => e.querySelector('b').textContent + ' ' + e.querySelector('.qty').textContent));
  check(rows.length === 2 && rows[0] === 'Veste en cuir ×2' && rows[1] === 'Jean slim ×1', 'nom et quantité de chaque vêtement : ' + JSON.stringify(rows));
  await p.screenshot({ path: path.join(OUT, 'sac_fenetre.png') });
  await p.click('#bagUi [data-take="3"]'); await p.waitForTimeout(80);
  let calls = await p.evaluate(() => window.bagCalls);
  check(calls.some((c) => c[0] === 'bagTake' && c[1].id === 'B123' && c[1].idx === 3), 'récupérer un vêtement : demande envoyée');
  check(await p.$eval('#bagUi .bg-all', (e) => e.disabled), 'boutons bloqués pendant la demande (pas de double clic)');
  await p.evaluate((bag) => window.postMessage({ action: 'bagView', bag: { ...bag, total: 2, items: [bag.items[0]] } }, '*'), bag);
  await p.waitForTimeout(120);
  check((await p.$$('#bagUi .bg-item')).length === 1, 'contenu actualisé en temps réel');
  await p.click('#bagUi [data-act="all"]'); await p.waitForTimeout(80);
  calls = await p.evaluate(() => window.bagCalls);
  check(calls.some((c) => c[0] === 'bagTake' && c[1].all === true), '« Tout récupérer » : demande envoyée');
  await p.evaluate(() => window.postMessage({ action: 'bagView', bag: { id: 'B123', empty: true } }, '*'));
  await p.waitForTimeout(120);
  check(!(await p.isVisible('#bagUi .bg-card')), 'sac vide : fenêtre fermée');

  console.log('\n[Coffre : choisir un sac]');
  await p.evaluate(() => window.postMessage({ action: 'bagPick', pick: { mode: 'trunk', netId: 7, class: 1, bags: [
    { id: 'B1', color: 'violet', hex: '#9b6bff', label: 'Sac violet · Binco (2)', count: 2 }, { id: 'B2', color: 'multi', hex: '#ff5fa8', label: 'Sac multicolore · Suburban (5)', count: 5 }] } }, '*'));
  await p.waitForTimeout(200);
  check((await p.$$('#bagUi .bg-pick')).length === 2, 'liste des sacs du coffre');
  await p.screenshot({ path: path.join(OUT, 'sac_coffre.png') });
  await p.click('#bagUi [data-pick="B2"]'); await p.waitForTimeout(80);
  calls = await p.evaluate(() => window.bagCalls);
  check(calls.some((c) => c[0] === 'bagPickChoose' && c[1].id === 'B2') && !(await p.isVisible('#bagUi .bg-card')), 'sac choisi : demande envoyée, fenêtre fermée');
  await p.evaluate(() => window.postMessage({ action: 'bagView', bag: { id: 'B9', color: 'jaune', colorLabel: 'jaune', hex: '#ffc93c', shop: 'Binco', total: 1, items: [{ first: 1, qty: 1, label: 'Casquette', cat: 'Chapeaux', catId: 'hats' }] } }, '*'));
  await p.waitForTimeout(150);
  await p.keyboard.press('Escape'); await p.waitForTimeout(80);
  calls = await p.evaluate(() => window.bagCalls);
  check(!(await p.isVisible('#bagUi .bg-card')) && calls.some((c) => c[0] === 'bagClose'), 'Échap : fermé, le jeu est prévenu');

  console.log('\n[Cadeau reçu]');
  await p.evaluate(() => window.postMessage({ action: 'bagGiftAsk', gift: { from: 'Lina Vega', color: 'rose', hex: '#ff5fa8', colorLabel: 'rose', shop: 'Ponsonbys', count: 3, timeout: 20 }, keys: { accept: 'Y', refuse: 'L' } }, '*'));
  await p.waitForTimeout(300);
  const gtxt = await p.textContent('#bagGift');
  check(await p.$eval('#bagGift', (e) => e.classList.contains('show')) && gtxt.includes('Lina Vega') && gtxt.includes('3 vêtements'), 'bandeau : nom de celui qui offre, contenu');
  await p.screenshot({ path: path.join(OUT, 'sac_cadeau.png') });
  await p.click('#bagGift [data-g="1"]'); await p.waitForTimeout(80);
  calls = await p.evaluate(() => window.bagCalls);
  check(calls.some((c) => c[0] === 'bagGiftAnswer' && c[1].accept === true), 'accepter (clic) : réponse envoyée');
  console.log('erreurs JS : ' + (errs.length ? errs.join(' | ') : 'aucune')); if (errs.length) fails++;
  console.log(`\n${passes} ok, ${fails} échec(s)`);
  await b.close(); process.exit(fails ? 1 : 0);
})();
