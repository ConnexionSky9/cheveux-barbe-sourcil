// Tests d'interface : produits vendus (staff), paiement en pesos (client), mini-jeu « plat » (recettes elyzea_cuisine).
// Usage : NODE_PATH=$(npm root -g) node tests/ui_catalog.cjs [dossier de captures]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'tests', 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, label) => { if (ok) { passes++; console.log('  ok   ' + label); } else { fails++; console.log('  ÉCHEC ' + label); } };

const CATS = [{ id: 'burgers', label: 'Burgers', icon: '🍔' }, { id: 'drinks', label: 'Boissons', icon: '🥤' },
  { id: 'italien', label: 'Restaurant italien', icon: '🍝', cuisine: true }, { id: 'japonais', label: 'Restaurant japonais', icon: '🍣', cuisine: true }];
const PRODUCTS = [
  { id: 'classic', label: 'Le Classic', cat: 'burgers', price: 25, station: 'grill', image: 'bs_burger_classic.png' },
  { id: 'cola', label: 'Cola', cat: 'drinks', price: 8, station: 'fountain', image: 'bs_drink_cola.png' },
  { id: 'it_lasagnes', label: 'Lasagnes à la viande', cat: 'italien', price: 25, station: 'oven', image: 'it_lasagnes.png', cuisine: true },
  { id: 'it_tiramisu', label: 'Tiramisu', cat: 'italien', price: 11, station: 'pastry', image: 'it_tiramisu.png', cuisine: true },
  { id: 'jp_sushi_saumon', label: 'Sushi Saumon', cat: 'japonais', price: 17, station: 'prep', image: 'jp_sushi_saumon.png', cuisine: true },
  { id: 'jp_ramen_porc', label: 'Ramen au porc', cat: 'japonais', price: 26, station: 'stove', image: 'jp_ramen_porc.png', cuisine: true },
];
const TYPES = [{ id: 'grill', label: 'Grill à burgers', icon: '🔥' }, { id: 'oven', label: 'Four à pizza', icon: '🍕' }, { id: 'fountain', label: 'Fontaine à boissons', icon: '🥤' },
  { id: 'pastry', label: 'Plan de pâtisserie', icon: '🍰' }, { id: 'stove', label: 'Piano de cuisson', icon: '🍳' }, { id: 'prep', label: 'Plan de travail', icon: '🔪' }];
const SHOP = { id: 1, name: 'Pizza This', address: 'Vespucci', job: 'resto_pizza', jobLabel: 'Pizza This', society: 'resto_pizza', matPrefix: 'PT-', enabled: true,
  options: { logo: '🍕', color: '#ef4444', catalog: ['classic', 'cola', 'it_lasagnes'] }, points: { order: { x: 1, y: 2, z: 3 }, stations: [{ x: 1, y: 2, z: 3, types: ['grill', 'oven', 'fountain'] }] },
  employees: 3, balance: 1200, publicOpen: true, activeOrders: 0, methods: ['bank', 'cash'], onMenu: ['classic', 'cola', 'it_lasagnes'], pesos: 431 };
const ADM = { shops: [SHOP], grades: {}, stationTypes: TYPES, products: PRODUCTS, categories: CATS, methods: ['bank', 'cash', 'pesos'], defaultMethods: ['bank', 'cash'],
  pesosRate: 1, cuisine: { count: 80 }, can: { view: true, edit: true, points: true, boss: true, toggle: true, delete: true, orders: true, menu: true, all: true } };
const PLAT = {
  cook: { from: 40, to: 62, speed: 0.55 }, need: ['pasta', 'tomato', 'basil'], shown: ['garlic', 'pasta', 'olive', 'tomato', 'mushroom', 'basil'], ordered: false,
  labels: { pasta: ['🍝', 'Pâtes'], tomato: ['🍅', 'Sauce tomate'], basil: ['🌿', 'Basilic'], garlic: ['🧄', 'Ail'], olive: ['🫒', 'Huile d\'olive'], mushroom: ['🍄', 'Champignons'] },
};
const SUSHI = { need: ['rice', 'nori'], shown: ['soy', 'rice', 'wasabi', 'nori', 'tuna'], ordered: false,
  labels: { rice: ['🍚', 'Riz'], nori: ['🟩', 'Algue nori'], soy: ['🥢', 'Sauce soja'], wasabi: ['🟢', 'Wasabi'], tuna: ['🍣', 'Thon'] } };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  await page.addInitScript(({ ADM }) => {
    window.__posts = []; window.__finish = []; window.__adm = ADM;
    window.EDemo = async (name, data) => {
      window.__posts.push({ name, data });
      if (name === 'orderSend') return { ok: true, message: 'Commande #002 payée (33 pesos).', order: { num: '#002' } };
      if (name === 'pub' && data.action === 'menuCard') return window.__card;
      if (name === 'cookStart') return { ok: true, token: 'T1', game: 'plat', params: window.__plat, duration: 35, difficulty: 2, label: 'Lasagnes à la viande', units: 1, num: '#002' };
      if (name === 'cookFinish') { window.__finish.push(data); return data.fail ? { ok: false, failed: true, message: 'Raté.' } : { ok: true, message: 'Réussi.' }; }
      if (name === 'stationOptions') return window.__station;
      if (name === 'admReload') return window.__adm;
      if (name === 'adm') return { ok: true, message: 'Enregistré.' };
      return {};
    };
  }, { ADM });
  await page.goto('file://' + path.join(ROOT, 'html', 'index.html'));
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  const shot = (n) => page.screenshot({ path: path.join(OUT, n) });

  // ---------------- Carte du client : pesos ----------------
  console.log('\n[Carte : recettes + paiement en pesos]');
  const card = { shop: { id: 1, name: 'Pizza This', logo: '🍕', color: '#ef4444', address: 'Vespucci', open: true }, categories: CATS,
    products: PRODUCTS.filter((p) => SHOP.options.catalog.includes(p.id)).map((p) => ({ ...p, desc: 'Recette maison.' })), methods: ['bank', 'pesos'], pesosRate: 1.3,
    limits: { maxQty: 10, maxLines: 12, maxUnits: 25 }, mine: [] };
  await page.evaluate((c) => { window.__card = c; }, card);
  await send({ action: 'order', show: true, data: card });
  await page.waitForTimeout(400);
  check((await page.locator('.ord-cat').count()) === 3, 'catégories avec produits : Burgers, Boissons, Restaurant italien');
  check((await page.locator('[data-m]').count()) === 2 && (await page.locator('[data-m="cash"]').count()) === 0, 'boutons : Banque + Pesos (espèces non acceptées)');
  await page.click('[data-cat="italien"]');
  await page.click('[data-add="it_lasagnes"]');
  let tot = (await page.textContent('.cart-total b')).replace(/\s/g, '');
  check(tot === '25$', 'banque : total 25 $ (' + tot + ')');
  await page.click('[data-m="pesos"]');
  await page.waitForTimeout(150);
  tot = (await page.textContent('.cart-total b')).replace(/\s/g, '');
  check(tot === '33pesos', 'pesos : 25 × 1,3 = 33 pesos (arrondi au-dessus) (' + tot + ')');
  check((await page.textContent('.prod .price')).replace(/\s/g, '') === '33pesos', 'prix de la carte affiché en pesos');
  await shot('c1_carte_pesos.png');
  await page.click('[data-o="pay"]');
  await page.waitForTimeout(150);
  check((await page.textContent('#confirm')).includes('pesos'), 'confirmation : « (pesos) »');
  await page.click('[data-cf="yes"]');
  await page.waitForTimeout(400);
  const sent = await page.evaluate(() => window.__posts.find((p) => p.name === 'orderSend'));
  check(sent && sent.data.method === 'pesos' && sent.data.expect === 25 && sent.data.lines[0].id === 'it_lasagnes', 'envoyé : method = pesos, total attendu en $ (le serveur convertit)');
  await send({ action: 'order', show: false });
  // Carte d'un restaurant sans pesos : le choix précédent (pesos) retombe sur un moyen accepté
  await send({ action: 'order', show: true, data: { ...card, methods: ['cash'] } });
  await page.waitForTimeout(300);
  check((await page.locator('[data-m="cash"].on').count()) === 1, 'restaurant sans pesos : espèces sélectionnées d\'office');
  await send({ action: 'order', show: false });

  // ---------------- Mini-jeu plat ----------------
  console.log('\n[Mini-jeu « plat » joué]');
  const station = { station: 1, label: 'Four à pizza', list: [{ order: 2, num: '#002', line: 1, label: 'Lasagnes à la viande', qty: 1, done: 0, image: 'it_lasagnes.png', gameLabel: 'Cuisson + dressage', difficulty: 2 }] };
  await page.evaluate((s) => { window.__station = s; }, station);
  const waitZone = async (z) => {
    for (let i = 0; i < 400; i++) {
      const v = await page.evaluate(() => parseFloat(document.querySelector('#kitchen .needle').style.left));
      if (v > z.from + 3 && v < z.to - 3) return true;
      await page.waitForTimeout(8);
    }
    return false;
  };
  const play = async (params, fn) => {
    await page.evaluate((p) => { window.__plat = p; window.__finish = []; }, params);
    await send({ action: 'kitchen', show: true, data: station });
    await page.waitForTimeout(200);
    await page.click('[data-pick="0"]');
    await page.waitForTimeout(300);
    await fn();
    await page.waitForTimeout(300);
    return page.evaluate(() => window.__finish[0]);
  };
  let f = await play(PLAT, async () => {
    check(await waitZone(PLAT.cook), 'cuisson : aiguille dans la zone');
    await page.keyboard.press('Space');
    await page.waitForTimeout(150);
    check((await page.locator('.palette .ing').count()) === 6 && (await page.textContent('.recipe')).includes('Sauce tomate'), 'dressage : 6 ingrédients italiens, fiche affichée');
    for (const k of PLAT.need) await page.click(`[data-ing="${k}"]`);
    await shot('c2_plat_dressage.png');
    await page.click('[data-ok]');
  });
  check(f && !f.fail && f.result.gauge >= PLAT.cook.from && f.result.gauge <= PLAT.cook.to && f.result.picked.length === 3, 'plat : cuisson + 3 bons ingrédients envoyés');
  f = await play(SUSHI, async () => {
    check((await page.locator('.gauge').count()) === 0, 'sushi : pas de cuisson');
    for (const k of SUSHI.need) await page.click(`[data-ing="${k}"]`);
    await page.click('[data-ok]');
  });
  check(f && !f.fail && f.result.gauge === undefined && f.result.picked.join() === 'rice,nori', 'sushi : dressage seul envoyé');
  f = await play(SUSHI, async () => { await page.click('[data-ing="soy"]'); await page.click('[data-ing="rice"]'); await page.click('[data-ok]'); });
  check(f && f.fail === true, 'mauvais ingrédient : échec envoyé');
  f = await play(PLAT, async () => {
    for (let i = 0; i < 400; i++) { const v = await page.evaluate(() => parseFloat(document.querySelector('#kitchen .needle').style.left)); if (v > PLAT.cook.to + 8) break; await page.waitForTimeout(8); }
    await page.click('[data-act]');
  });
  check(f && f.fail === true, 'cuisson hors zone : échec envoyé');
  await send({ action: 'kitchen', show: false });

  // ---------------- Panneau staff ----------------
  console.log('\n[Staff : produits vendus et paiements]');
  await send({ action: 'admin', show: true, data: ADM });
  await page.waitForTimeout(400);
  check(await page.isVisible('#catalogCard'), 'carte « Produits vendus » affichée');
  check((await page.textContent('#catalogCard')).includes('80 recettes'), 'mention des 80 recettes elyzea_cuisine');
  check((await page.textContent('#catCount')).trim() === '3', '3 produits autorisés (liste du restaurant)');
  check((await page.locator('.cat-grp').count()) === 4, '4 catégories');
  check(await page.locator('#catWarn').isHidden(), 'aucune station manquante pour la liste actuelle (grill, four, fontaine posés)');
  await page.click('.cat-grp[data-grp="japonais"] > summary span:first-child');
  await page.click('[data-catall="japonais"]');
  await page.waitForTimeout(100);
  check((await page.textContent('#catCount')).trim() === '5', 'japonais : « Tout » coche 2 produits (5)');
  const w1 = await page.textContent('#catWarn');
  check(await page.locator('#catWarn').isVisible() && w1.includes('Piano de cuisson') && w1.includes('Plan de travail'), 'avertissement en direct : piano + plan de travail à poser');
  check((await page.textContent('[data-grpn="japonais"]')).includes('2 / 2'), 'compteur de la catégorie : 2 / 2');
  await page.fill('[data-catq]', 'tira');
  await page.waitForTimeout(100);
  const visible = await page.$$eval('.cat-row', (rows) => rows.filter((r) => r.style.display !== 'none').map((r) => r.querySelector('[data-prod]').dataset.prod));
  check(visible.length === 1 && visible[0] === 'it_tiramisu', 'recherche « tira » : seul le tiramisu reste');
  await page.click('[data-prod="it_tiramisu"]');
  await page.fill('[data-catq]', '');
  await page.waitForTimeout(100);
  check((await page.textContent('#catCount')).trim() === '6', 'tiramisu coché (6)');
  await page.click('[data-prod="cola"]');
  check((await page.textContent('#catCount')).trim() === '5', 'cola décoché (5)');
  await shot('c3_staff_produits.png');
  await page.click('[data-ad="catalog"]');
  await page.waitForTimeout(300);
  const cat = await page.evaluate(() => window.__posts.filter((p) => p.name === 'adm' && p.data.action === 'catalogSet').pop());
  const ids = cat && cat.data.data.products.slice().sort().join(',');
  check(ids === 'classic,it_lasagnes,it_tiramisu,jp_ramen_porc,jp_sushi_saumon', 'enregistré : la liste cochée (' + ids + ')');
  // Les stations manquantes sont signalées (le restaurant n'a ni piano, ni plan de travail, ni pâtisserie)
  await page.evaluate(() => { const s = window.__adm.shops[0]; s.options = { ...s.options, catalog: ['classic', 'it_tiramisu', 'jp_sushi_saumon'] }; });
  await send({ action: 'admin', show: true, data: await page.evaluate(() => window.__adm) });
  await page.waitForTimeout(300);
  const warn = await page.textContent('#catWarn');
  check(warn.includes('Plan de pâtisserie') && warn.includes('Plan de travail') && !warn.includes('Grill'), 'stations à poser signalées : pâtisserie + plan de travail');
  await page.click('input[name="catmode"][value="all"]');
  await page.click('[data-ad="catalog"]');
  await page.waitForTimeout(300);
  const all = await page.evaluate(() => window.__posts.filter((p) => p.name === 'adm' && p.data.action === 'catalogSet').pop());
  check(all && all.data.data.all === true && !all.data.data.products, '« Tout le catalogue » envoyé');
  // Paiements
  check((await page.textContent('.adm-main')).includes('431'), 'pesos actuellement au coffre affichés (431)');
  await page.click('[data-pay="pesos"]');
  await page.click('[data-pay="cash"]');
  await page.click('[data-ad="payments"]');
  await page.waitForTimeout(300);
  const pay = await page.evaluate(() => window.__posts.filter((p) => p.name === 'adm' && p.data.action === 'paymentsSet').pop());
  check(pay && pay.data.data.methods.join() === 'bank,pesos', 'paiements enregistrés : banque + pesos (' + (pay && pay.data.data.methods.join()) + ')');
  await page.evaluate(() => document.querySelector('#catalogCard').scrollIntoView());
  await shot('c4_staff_paiements.png');
  await send({ action: 'admin', show: false });

  // ---------------- Répartition des plats (plat × restaurant) ----------------
  console.log('\n[Staff : répartition des plats, un par un]');
  await page.evaluate(() => {
    const a = window.__adm;
    a.shops = [Object.assign({}, a.shops[0], { onMenu: ['classic', 'cola'] }),
      Object.assign({}, a.shops[0], { id: 2, name: 'ItalianRestaurent', onMenu: [] })];
  });
  await send({ action: 'admin', show: true, data: await page.evaluate(() => window.__adm) });
  await page.waitForTimeout(300);
  await page.click('[data-ad="matrix"]');
  await page.waitForTimeout(300);
  check(await page.locator('table.mx').count() === 1 && (await page.locator('table.mx tbody tr').count()) === 6, 'tableau : 6 plats × 2 restaurants');
  check((await page.textContent('table.mx thead')).includes('ItalianRestaurent'), 'colonne par restaurant');
  check(await page.locator('[data-mx="1"][value="classic"]:checked').count() === 1 && await page.locator('[data-mx="2"][value="classic"]:checked').count() === 0, 'cases cochées = plats en vente');
  await page.click('[data-mcat="italien"]');
  await page.waitForTimeout(200);
  check((await page.locator('table.mx tbody tr').count()) === 2, 'filtre « Restaurant italien » : 2 plats');
  await page.click('[data-mx="2"][value="it_lasagnes"]');
  await page.waitForTimeout(300);
  let mx = await page.evaluate(() => window.__posts.filter((p) => p.name === 'adm' && p.data.action === 'catalogAssign').pop());
  check(mx && mx.data.data.id === 2 && mx.data.data.on === true && mx.data.data.products.join() === 'it_lasagnes', 'une case = « ItalianRestaurent vend les lasagnes » envoyé tout de suite');
  check((await page.textContent('[data-mxn="2"]')).includes('1 en vente'), 'compteur de la colonne mis à jour');
  await page.click('[data-mxall="2"]');
  await page.waitForTimeout(300);
  mx = await page.evaluate(() => window.__posts.filter((p) => p.name === 'adm' && p.data.action === 'catalogAssign').pop());
  check(mx && mx.data.data.on === true && mx.data.data.products.sort().join() === 'it_lasagnes,it_tiramisu', '« ✓ tout » : tous les plats affichés (italien) pour ce restaurant');
  await page.click('[data-mcat=""]');
  await page.fill('[data-mq]', 'sushi');
  await page.waitForTimeout(200);
  check((await page.locator('table.mx tbody tr').count()) === 1, 'recherche « sushi » : 1 plat');
  await page.fill('[data-mq]', '');
  await page.waitForTimeout(200);
  await page.screenshot({ path: path.join(OUT, 'c5_repartition.png') });
  await send({ action: 'admin', show: false });

  // ---------------- Capture : carte d'un restaurant italien en 1920×1080 ----------------
  await page.setViewportSize({ width: 1920, height: 1080 });
  const it = { shop: { id: 2, name: 'ItalianRestaurent', logo: '🍝', color: '#2e9e5b', address: '', open: true }, categories: CATS,
    products: PRODUCTS.map((p) => ({ ...p, desc: p.cuisine ? 'Recette maison préparée à la commande, servie chaude.' : 'Le classique de la maison.' })), methods: ['bank', 'cash', 'pesos'], pesosRate: 1,
    limits: { maxQty: 10, maxLines: 12, maxUnits: 25 }, mine: [{ num: '#003', shop: 'ItalianRestaurent', status: 'ready', statusLabel: 'Terminée', done: 3, units: 3 }] };
  await page.evaluate((c) => { window.__card = c; }, it);
  await send({ action: 'order', show: true, data: it });
  await page.waitForTimeout(400);
  await page.click('[data-cat="italien"]');
  await page.click('[data-add="it_lasagnes"]');
  await page.waitForTimeout(200);
  await page.screenshot({ path: path.join(OUT, 'c6_carte_1080p.png') });
  await send({ action: 'order', show: false });

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await browser.close();
  console.log(`\nTOTAL : ${passes} ok, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
