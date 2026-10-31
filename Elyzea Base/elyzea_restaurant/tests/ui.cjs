// Tests d'interface d'elyzea_restaurant (Playwright + Chromium, hors jeu).
// Usage : NODE_PATH=$(npm root -g) node tests/ui.cjs [dossier de captures]
// Le jeu est imité par window.EDemo (réponses du client Lua) ; les 5 mini-jeux sont
// JOUÉS (aiguille arrêtée dans la zone, ingrédients cliqués…) et leurs réponses vérifiées.
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'tests', 'shots');
fs.mkdirSync(OUT, { recursive: true });
let fails = 0, passes = 0;
const check = (ok, label) => { if (ok) { passes++; console.log('  ok   ' + label); } else { fails++; console.log('  ÉCHEC ' + label); } };

const PRODUCTS = [
  { id: 'classic', item: 'bs_burger_classic', label: 'Le Classic', desc: 'Steak, cheddar, salade, tomate, sauce maison.', cat: 'burgers', price: 25, image: 'bs_burger_classic.png' },
  { id: 'double', item: 'bs_burger_double', label: 'Double Cheese', desc: 'Deux steaks, double cheddar.', cat: 'burgers', price: 32, image: 'bs_burger_double.png' },
  { id: 'pizza_ham', item: 'pizza', label: 'Pizza jambon', desc: 'Sauce tomate, mozzarella, jambon.', cat: 'pizzas', price: 30, image: 'pizza_ham.png' },
  { id: 'fries', item: 'bs_frites', label: 'Frites', desc: 'Frites dorées.', cat: 'sides', price: 10, image: 'bs_frites.png' },
  { id: 'cola', item: 'bs_drink_cola', label: 'Cola', desc: 'Le cola maison.', cat: 'drinks', price: 8, image: 'bs_drink_cola.png' },
  { id: 'sundae', item: 'bs_dessert_sundae', label: 'Sundae caramel', desc: 'Glace vanille, caramel.', cat: 'desserts', price: 11, image: 'bs_dessert_sundae.png' },
  { id: 'nope', item: 'x', label: 'Image absente', desc: 'Repli sur l\'emoji.', cat: 'desserts', price: 5, image: 'n_existe_pas.png' },
];
const CATS = [{ id: 'burgers', label: 'Burgers', icon: '🍔' }, { id: 'pizzas', label: 'Pizzas', icon: '🍕' }, { id: 'sides', label: 'Accompagnements', icon: '🍟' },
  { id: 'drinks', label: 'Boissons', icon: '🥤' }, { id: 'desserts', label: 'Desserts', icon: '🍰' }];
// Paramètres comme ceux de shared/games.lua (difficulté 1)
const PARAMS = {
  burger: { cook: [{ from: 40, to: 62, speed: 0.55 }], recipe: ['bun_bottom', 'patty', 'cheese', 'salad', 'bun_top'], palette: ['salad', 'bun_top', 'patty', 'tomato', 'bun_bottom', 'cheese', 'onion', 'bacon', 'sauce', 'pickles'] },
  pizza: { spots: [{ x: 50, y: 30 }, { x: 70, y: 55 }, { x: 35, y: 65 }], tol: 9, bake: { from: 45, to: 67, speed: 0.55 } },
  drink: { from: 60, to: 74, rate: 22 },
  dessert: { need: ['caramel', 'nuts', 'cream'], shown: ['mint', 'caramel', 'banana', 'cream', 'nuts', 'honey'], ordered: false },
  fries: { from: 45, to: 63, cookMs: 7000 },
};

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(String(e)));
  await page.addInitScript(({ PARAMS }) => {
    window.__posts = [];
    window.__finish = [];
    window.EDemo = async (name, data) => {
      window.__posts.push({ name, data });
      if (name === 'orderSend') return { ok: true, message: 'Commande #001 payée (66 $).', order: { num: '#001' } };
      if (name === 'pub' && data.action === 'menuCard') return window.__card;
      if (name === 'bagTake') return data.line ? { ok: true, message: 'Récupéré : 1 × Cola.', bag: { uid: 'B1', num: '#001', shop: 'Pizza This', logo: '🍕', lines: [{ i: 1, label: 'Le Classic', qty: 3, image: 'bs_burger_classic.png' }] } } : { ok: true, empty: true, message: 'Récupéré : 3 × Le Classic. Sac vide : jeté.' };
      if (name === 'cookStart') return { ok: true, token: 'T' + Date.now(), game: window.__game, params: PARAMS[window.__game], duration: 30, difficulty: 1, label: 'Produit', units: 2, num: '#001' };
      if (name === 'cookFinish') { window.__finish.push(data); return data.fail ? { ok: false, failed: true, message: 'Raté.' } : { ok: true, message: 'Réussi : 2 / 3 prêt(s).' }; }
      if (name === 'stationOptions') return window.__station;
      if (name === 'req' && data.action === 'ordersList') return window.__orders;
      if (name === 'req') return { ok: true };
      return {};
    };
  }, { PARAMS });
  await page.goto('file://' + path.join(ROOT, 'html', 'index.html'));
  const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
  const shot = (n) => page.screenshot({ path: path.join(OUT, n) });

  // ---------------- Carte et panier ----------------
  console.log('\n[Carte et panier]');
  const card = { shop: { id: 1, name: 'Pizza This', logo: '🍕', color: '#ef4444', address: 'Vespucci', open: true }, categories: CATS, products: PRODUCTS, methods: ['bank', 'cash'],
    limits: { maxQty: 10, maxLines: 12, maxUnits: 25 }, mine: [{ num: '#000', shop: 'Pizza This', status: 'preparing', statusLabel: 'En préparation', done: 1, units: 3 }] };
  await page.evaluate((c) => { window.__card = c; }, card);
  await send({ action: 'order', show: true, data: card });
  await page.waitForTimeout(400);
  check(await page.isVisible('#order'), 'carte affichée');
  check((await page.locator('.ord-cat').count()) === 5, '5 catégories');
  check((await page.locator('.prod').count()) === 2, 'catégorie Burgers : 2 produits avec image');
  await page.click('[data-add="classic"]'); await page.click('[data-add="classic"]');
  await page.click('[data-cat="drinks"]'); await page.click('[data-add="cola"]');
  await page.click('[data-cat="desserts"]');
  await page.waitForTimeout(300);
  check((await page.locator('.prod .emo').count()) >= 1, 'image manquante : repli sur l\'emoji');
  let tot = await page.textContent('.cart-total b');
  check(tot.replace(/\s/g, '') === '58$', 'total 2 × 25 + 8 = 58 $ (' + tot + ')');
  await page.click('[data-q="classic"][data-d="1"]');
  tot = await page.textContent('.cart-total b');
  check(tot.replace(/\s/g, '') === '83$', 'quantité + : 83 $');
  await page.click('[data-q="classic"][data-d="-1"]');
  await page.click('[data-rm="cola"]');
  tot = await page.textContent('.cart-total b');
  check(tot.replace(/\s/g, '') === '50$', 'produit supprimé : 50 $');
  await page.click('[data-m="cash"]');
  check(await page.locator('[data-m="cash"].on').count() === 1, 'paiement en espèces choisi');
  check((await page.textContent('.cart-list')).includes('#000'), 'suivi des commandes en cours affiché');
  await shot('1_carte_panier.png');
  await page.click('[data-o="pay"]');
  await page.waitForTimeout(150);
  await page.click('[data-cf="yes"]');
  await page.waitForTimeout(400);
  const sent = await page.evaluate(() => window.__posts.find((p) => p.name === 'orderSend'));
  check(sent && sent.data.method === 'cash' && sent.data.expect === 50 && sent.data.lines.length === 1 && sent.data.lines[0].id === 'classic' && sent.data.lines[0].qty === 2,
    'envoyé au jeu : identifiants + quantités + total attendu (aucun prix)');
  check((await page.textContent('#toasts')).includes('#001'), 'confirmation affichée');
  check((await page.locator('.cart-line').count()) === 0, 'panier vidé après paiement');
  for (let i = 0; i < 12; i++) await page.click('[data-cat="burgers"] >> nth=0').then(() => page.click('[data-add="classic"]')).catch(() => {});
  check(await page.locator('[data-add="classic"][disabled]').count() === 1, 'quantité max (10) : bouton « Ajouter » bloqué');
  await send({ action: 'order', show: false });

  // ---------------- Sac ----------------
  console.log('\n[Sac de commande]');
  await send({ action: 'bag', show: true, data: { uid: 'B1', num: '#001', shop: 'Pizza This', logo: '🍕', lines: [{ i: 1, label: 'Le Classic', qty: 3, image: 'bs_burger_classic.png' }, { i: 2, label: 'Cola', qty: 1, image: 'bs_drink_cola.png' }] } });
  await page.waitForTimeout(300);
  check((await page.locator('.bag-line').count()) === 2, 'sac : 2 produits');
  await shot('2_sac.png');
  await page.click('[data-take="2"]');
  await page.waitForTimeout(300);
  check((await page.locator('.bag-line').count()) === 1, 'cola pris : 1 produit restant');
  await page.click('[data-b="all"]');
  await page.waitForTimeout(300);
  const closeBag = await page.evaluate(() => window.__posts.filter((p) => p.name === 'close' && p.data.ui === 'bag').length);
  check(closeBag === 1, 'sac vide : fermeture demandée');
  await send({ action: 'bag', show: false });

  // ---------------- Station + mini-jeux ----------------
  console.log('\n[Station de cuisine et mini-jeux joués]');
  const station = { station: 1, label: 'Grill à burgers · Four à pizza', list: [{ order: 1, num: '#001', line: 1, label: 'Le Classic', qty: 3, done: 0, image: 'bs_burger_classic.png', gameLabel: 'Cuisson + montage', difficulty: 2 }] };
  await page.evaluate((s) => { window.__station = s; }, station);
  const waitZone = async (sel, z) => {
    for (let i = 0; i < 400; i++) {
      const v = await page.evaluate((s) => parseFloat(document.querySelector(s).style.left), sel);
      if (v > z.from + 3 && v < z.to - 3) return true;
      await page.waitForTimeout(8);
    }
    return false;
  };
  const play = async (game) => {
    await page.evaluate((g) => { window.__game = g; window.__finish = []; }, game);
    await send({ action: 'kitchen', show: true, data: station });
    await page.waitForTimeout(200);
    await page.click('[data-pick="0"]');
    await page.waitForTimeout(300);
    const P = PARAMS[game];
    if (game === 'burger') {
      check(await waitZone('#kitchen .needle', P.cook[0]), 'burger : aiguille dans la zone');
      await page.keyboard.press('Space');
      await page.waitForTimeout(150);
      if (fails === 0) await shot('3_burger_montage.png');
      for (const k of P.recipe) { await page.click(`[data-ing="${k}"]`); await page.waitForTimeout(40); }
    } else if (game === 'pizza') {
      const box = await page.locator('.pizza').boundingBox();
      for (const s of P.spots) { await page.mouse.click(box.x + box.width * s.x / 100, box.y + box.height * s.y / 100); await page.waitForTimeout(40); }
      await shot('4_pizza.png');
      await page.waitForTimeout(400);
      check(await waitZone('#kitchen .needle', P.bake), 'pizza : aiguille du four dans la zone');
      await page.click('[data-act]');
    } else if (game === 'drink') {
      const b = await page.locator('[data-fill]').boundingBox();
      await page.mouse.move(b.x + 10, b.y + 10); await page.mouse.down();
      for (let i = 0; i < 600; i++) { const h = await page.evaluate(() => parseFloat(document.querySelector('.liquid').style.height) || 0); if (h > P.from + 3) break; await page.waitForTimeout(8); }
      await page.mouse.up();
      await shot('5_boisson.png');
      await page.click('[data-serve]');
    } else if (game === 'dessert') {
      for (const k of P.need) await page.click(`[data-ing="${k}"]`);
      await shot('6_dessert.png');
      await page.click('[data-ok]');
    } else if (game === 'fries') {
      await page.click('[data-act]');
      check(await waitZone('#kitchen .needle', P), 'frites : aiguille dans la zone dorée');
      await page.click('[data-act]');
    }
    await page.waitForTimeout(300);
    const f = await page.evaluate(() => window.__finish[0]);
    return f;
  };
  const inZ = (z, v) => v >= z.from && v <= z.to;
  let f = await play('burger');
  check(f && !f.fail && inZ(PARAMS.burger.cook[0], f.result.gauge[0]) && JSON.stringify(f.result.seq) === JSON.stringify(PARAMS.burger.recipe), 'burger : réponse valide envoyée (jauge + ordre de la recette)');
  check((await page.textContent('#kitchen')).includes('Réussi'), 'écran de réussite');
  await shot('7_resultat.png');
  f = await play('pizza');
  check(f && !f.fail && f.result.spots.length === 3 && inZ(PARAMS.pizza.bake, f.result.gauge), 'pizza : 3 garnitures + cuisson valides');
  f = await play('drink');
  check(f && !f.fail && inZ(PARAMS.drink, f.result.level), `boisson : niveau ${f && f.result && f.result.level} dans la bande`);
  f = await play('dessert');
  check(f && !f.fail && f.result.picked.length === 3, 'dessert : 3 bons ingrédients');
  f = await play('fries');
  check(f && !f.fail && inZ(PARAMS.fries, f.result.t), 'frites : sorties dans la zone dorée');
  // Échec : mauvais ingrédient → raté, « Recommencer » proposé
  await page.evaluate(() => { window.__game = 'burger'; window.__finish = []; });
  await send({ action: 'kitchen', show: true, data: station });
  await page.waitForTimeout(200);
  await page.click('[data-pick="0"]');
  await page.waitForTimeout(200);
  await waitZone('#kitchen .needle', PARAMS.burger.cook[0]);
  await page.keyboard.press('Space');
  await page.waitForTimeout(150);
  await page.click('[data-ing="bun_top"]');
  await page.waitForTimeout(300);
  f = await page.evaluate(() => window.__finish[0]);
  check(f && f.fail === true, 'mauvais ingrédient : échec envoyé au serveur');
  check(await page.locator('[data-k="retry"]').count() === 1, '« Recommencer » proposé');
  await shot('8_rate.png');
  await page.click('[data-k="retry"]');
  await page.waitForTimeout(200);
  check(await page.locator('.gauge').count() === 1, 'recommencer relance le mini-jeu');
  await send({ action: 'kitchen', show: false });
  check(!(await page.isVisible('#kitchen')), 'station fermée');
  await page.evaluate((s) => { window.__station = s; }, { station: 1, label: 'Grill', list: [], empty: 'Rien à préparer ici.' });
  await send({ action: 'kitchen', show: true, data: { station: 1, label: 'Grill', list: [], empty: 'Rien à préparer ici.' } });
  await page.waitForTimeout(200);
  check((await page.textContent('#kitchen')).includes('Rien à préparer'), 'station sans travail : message clair');
  await send({ action: 'kitchen', show: false });

  // ---------------- Tablette : commandes ----------------
  console.log('\n[Tablette : commandes]');
  const order = (id, status, extra = {}) => Object.assign({ id, num: '#00' + id, status, statusLabel: { pending: 'En attente', preparing: 'En préparation', ready: 'Terminée' }[status], t: Date.now() / 1000 - 120,
    total: 58, customer: 'Claire Cliente', units: 3, done: status === 'pending' ? 0 : 2,
    lines: [{ label: 'Le Classic', qty: 2, done: status === 'pending' ? 0 : 2, stationLabel: 'Grill à burgers' }, { label: 'Cola', qty: 1, done: 0, stationLabel: 'Fontaine à boissons' }] }, extra);
  await page.evaluate((o) => { window.__orders = o; }, { pending: [order(1, 'pending'), order(2, 'pending')], mine: [order(3, 'preparing', { mine: true, employee: 'Paul' }), order(4, 'ready', { mine: true, employee: 'Paul', done: 3 })], others: [],
    history: [{ num: '#000', lines: [{ label: 'Frites', qty: 1 }], total: 10, status: 'delivered', statusLabel: 'Livrée', customer_name: 'Bob', employee_name: 'Paul', t: Date.now() / 1000 - 3600 }],
    duty: true, can: { take: true, cook: true, deliver: true, manage: true }, maxPerEmployee: 3, taken: 2 });
  const st = { shop: 1, shopName: 'Pizza This', grade: 'Patron', matricule: 'RS-001', duty: true, status: 'kitchen', perms: { tablet: true, orders: true, direction: true, finance: true, menu: true } };
  await send({ action: 'init', cfg: { statuses: [{ id: 'kitchen', label: 'En cuisine', color: '#f97316' }], games: {} } });
  await send({ action: 'tablet', show: true, state: st, opts: { page: 'orders' } });
  await page.waitForTimeout(500);
  check((await page.locator('[data-ot]').count()) === 2, 'tablette : 2 commandes en attente avec « Prendre en charge »');
  await shot('9_tablette_attente.png');
  await page.click('[data-ot="1"]');
  await page.waitForTimeout(400);
  const took = await page.evaluate(() => window.__posts.find((p) => p.name === 'req' && p.data.action === 'orderTake'));
  check(took && took.data.data.id === 1, 'prise en charge envoyée au serveur');
  await page.click('[data-otab="mine"]');
  await page.waitForTimeout(400);
  check((await page.locator('[data-odel="4"]').count()) === 1, 'Mes commandes : « Remettre au client » sur la commande terminée');
  await shot('10_tablette_mes_commandes.png');
  await page.click('[data-otab="history"]');
  await page.waitForTimeout(300);
  check((await page.textContent('#tabBody')).includes('Livrée'), 'historique affiché');
  await send({ action: 'tablet', show: false });

  check(errs.length === 0, 'aucune erreur JavaScript' + (errs.length ? ' : ' + errs.join(' | ') : ''));
  await browser.close();
  console.log(`\nTOTAL : ${passes} ok, ${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
