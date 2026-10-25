// Test navigateur (Playwright) de la NUI elyzea_shop, données simulées comme les envoie le serveur.
// node tests/nui.e2e.cjs   (variable SHOTS_DIR pour garder les captures)
const { chromium } = require('playwright');
const path = require('path').resolve(__dirname, '../html/index.html');
const OUT = (process.env.SHOTS_DIR || require('os').tmpdir()) + '/';
let fails = 0; const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
const data = {
  serverName: 'Elyzea RP', coins: { enabled: true, label: 'Elyzea Coins', short: 'EC' }, noAccount: false,
  catalog: {
    categories: [{ id: 'vip', label: 'VIP', icon: 'crown', description: 'Les grades premium.' }, { id: 'coins', label: 'Elyzea Coins', icon: 'coin' }, { id: 'vehicles', label: 'Véhicules premium', icon: 'car' }],
    products: [
      { key: 'sapphire', category: 'vip', label: 'Elyzea Sapphire', description: 'Premier grade.', image: 'assets/products/sapphire.webp', perks: ['Avantage à définir'], durationDays: 30, tebex: true, displayPrice: null },
      { key: 'royale', category: 'vip', label: 'Elyzea Royale', description: 'Grade intermédiaire.', image: 'assets/products/royale.webp', perks: [], durationDays: 30, tebex: false },
      { key: 'divinity', category: 'vip', label: 'Elyzea Divinity', description: 'Le plus haut grade.', image: 'assets/products/divinity.webp', perks: [], durationDays: 30, tebex: true, displayPrice: '—' },
      { key: 'coins_1000', category: 'coins', label: '1 000 Elyzea Coins', description: '', image: 'assets/products/coins.webp', perks: [], tebex: true },
      { key: 'vehicle_example', category: 'vehicles', label: 'Véhicule premium', description: 'Exemple.', image: 'assets/products/vehicle.webp', perks: ['Livré au garage'], tebex: false, coinsPrice: 600 },
    ] },
  player: { account: '1', coins: 1000, vip: [{ name: 'vip_sapphire', expires_at: '2026-12-01 10:00:00', permanent: 0 }],
    history: [{ label: 'Elyzea Sapphire', action: 'grant', source: 'tebex', status: 'delivered', created_at: '2026-10-20 10:00:00', transaction_id: 'tbx-123' },
              { label: 'Véhicule premium', action: 'grant', source: 'coins', status: 'pending', created_at: '2026-10-21 10:00:00' }],
    coinHistory: [{ delta: 1000, reason: 'Achat : 1 000 Elyzea Coins', created_at: '2026-10-20 10:00:00' }, { delta: -600, reason: 'Achat : Véhicule premium', created_at: '2026-10-21 10:00:00' }] },
};
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
  const posts = [];
  await page.route('https://elyzea_shop/**', (r) => { posts.push([r.request().url().split('/').pop(), r.request().postData()]); r.fulfill({ status: 200, contentType: 'application/json', body: '{}' }); });
  await page.addInitScript(() => { window.GetParentResourceName = () => 'elyzea_shop'; window.__opened = []; window.invokeNative = (n, u) => window.__opened.push(u); });
  await page.goto('file://' + path);
  const send = (m) => page.evaluate((m) => window.postMessage(m, '*'), m);
  check(await page.locator('#shop').isHidden(), 'invisible au chargement');
  await send({ action: 'open' });
  check(await page.locator('.spinner').isVisible(), 'ouverture : chargement');
  await send({ action: 'data', data });
  await page.waitForSelector('.card');
  check(await page.locator('#wallet').innerText().then((t) => /1\s000/u.test(t)), 'solde de coins affiché');
  check(await page.locator('#nav .nav-item').count() === 4, 'catégories : VIP, Elyzea Coins, Véhicules premium');
  const hist = await page.locator('[data-view="history"]').boundingBox();
  const shopBox = await page.locator('#shop').boundingBox();
  check(hist && hist.y + hist.height <= shopBox.y + shopBox.height, 'bouton Historique visible (contenu long : défilement interne)');
  await page.screenshot({ path: OUT + 'elyzea_shop_accueil.png' });
  await page.click('.card:has-text("Elyzea Sapphire")');
  await page.waitForSelector('.detail');
  check(await page.locator('text=Prix affiché sur Tebex').count() === 1, 'pas de prix inventé : « Prix affiché sur Tebex » quand aucun prix n\'est configuré');
  await page.click('button:has-text("Acheter avec Tebex")');
  check(await page.locator('.modal .box').isVisible(), 'fenêtre de confirmation avant Tebex');
  await page.screenshot({ path: OUT + 'elyzea_shop_confirmation.png' });
  await page.click('.modal button:has-text("Ouvrir Tebex")');
  await page.waitForTimeout(200);
  check(posts.some((p) => p[0] === 'tebex' && JSON.parse(p[1]).key === 'sapphire'), 'seule la clé du produit est envoyée');
  await send({ action: 'result', kind: 'tebex', data: { url: 'https://elyzea.tebex.io/package/111', key: 'sapphire' } });
  await page.waitForSelector('.modal .url');
  check(await page.evaluate(() => window.__opened[0]) === 'https://elyzea.tebex.io/package/111', 'boutique Tebex officielle ouverte dans le navigateur');
  check(await page.locator('text=Rien n\'est livré tant que Tebex').count() === 1, 'message : livraison seulement après confirmation Tebex');
  await page.keyboard.press('Escape');
  check(await page.locator('.modal').isHidden(), 'Échap ferme d\'abord la fenêtre de confirmation');
  await page.click('.nav-item:has-text("Véhicules")');
  await page.click('.card:has-text("Véhicule premium")');
  await page.click('button:has-text("Acheter avec des coins")');
  check(await page.locator('.modal').innerText().then((t) => t.includes('400')), 'confirmation coins : solde après achat');
  await page.click('.modal button:has-text("Confirmer")');
  await page.waitForTimeout(200);
  check(posts.some((p) => p[0] === 'buyCoins'), 'achat en coins demandé au serveur');
  check(await page.locator('.toast.loading').count() === 1, 'notification de chargement');
  await send({ action: 'result', kind: 'coins', data: { error: 'Solde insuffisant' } });
  await page.waitForSelector('.toast.error');
  check(true, 'refus du serveur : notification d\'erreur');
  await page.click('[data-view="history"]');
  check(await page.locator('.item').count() === 4 && await page.locator('text=tbx-123').count() === 1, 'historique des achats et des coins (référence Tebex visible)');
  await page.screenshot({ path: OUT + 'elyzea_shop_historique.png' });
  // image collée dans l'admin menu (img:<id>) : demandée une fois, affichée à réception
  const withImg = JSON.parse(JSON.stringify(data)); withImg.catalog.products[0].image = 'img:7'; withImg.catalog.products[0].displayPrice = '9,99 €'; withImg.catalog.products[0].discount = '12,99 €';
  await send({ action: 'data', data: withImg }); await page.click('.nav-item:has-text("Accueil")'); await page.waitForTimeout(150);
  check(posts.filter((p) => p[0] === 'images' && JSON.parse(p[1]).ids[0] === 7).length === 1, 'image collée : demandée une seule fois au jeu');
  const px = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  await send({ action: 'image', id: 7, data: px }); await page.waitForTimeout(100);
  check(await page.evaluate((d) => [...document.querySelectorAll('img[data-img="7"]')].every((i) => i.src === d) && document.querySelectorAll('img[data-img="7"]').length > 0, px), 'image collée affichée à réception');
  check(await page.locator('s:has-text("12,99 €")').count() > 0 && await page.locator('text=9,99 €').count() > 0, 'prix Tebex et prix barré (promotion) affichés');
  await send({ action: 'image', id: 7, data: 'javascript:alert(1)' }); await page.waitForTimeout(50);
  check(await page.evaluate((d) => document.querySelector('img[data-img="7"]').src === d, px), 'donnée qui n\'est pas une image : ignorée');
  const evil = JSON.parse(JSON.stringify(data)); evil.catalog.products[0].label = '<img src=x onerror="window.__xss=1">';
  await send({ action: 'data', data: evil }); await page.click('.nav-item:has-text("Accueil")');
  check(await page.evaluate(() => !window.__xss), 'texte inséré comme texte (pas d\'injection HTML)');
  await page.keyboard.press('Escape'); await page.waitForTimeout(200);
  check(posts.some((p) => p[0] === 'close'), 'Échap : fermeture demandée au client Lua (focus rendu)');
  await send({ action: 'close' }); await page.waitForTimeout(300);
  check(await page.locator('#shop').isHidden(), 'fermée');
  const p2 = await b.newPage({ viewport: { width: 1280, height: 720 } });
  await p2.addInitScript(() => { window.GetParentResourceName = () => 'elyzea_shop'; });
  await p2.goto('file://' + path);
  await p2.evaluate((d) => { window.postMessage({ action: 'open' }, '*'); window.postMessage({ action: 'data', data: d }, '*'); }, data);
  await p2.waitForSelector('.card');
  const box = await p2.locator('#shop').boundingBox();
  check(box.width <= 1280 && box.height <= 720, 'tient en 1280×720');
  await p2.screenshot({ path: OUT + 'elyzea_shop_720p.png' });
  check(errors.length === 0, 'aucune erreur JavaScript ' + errors.join(' | '));
  await b.close();
  console.log(`\n${fails} échec(s)`); process.exit(fails ? 1 : 0);
})();
