// Test navigateur (Playwright) de la NUI server_shop, avec le catalogue réel de l'API.
// node tests/e2e/nui.e2e.cjs
const { chromium } = require('playwright');
const path = require('path').resolve(__dirname, '../../fivem/server_shop/html/index.html');
const OUT = (process.env.SHOTS_DIR || require('os').tmpdir()) + '/';
let fails = 0; const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
(async () => {
  const catalog = await fetch((process.env.API_URL || 'http://localhost:3000') + '/api/catalog').then((r) => r.json());
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
  const posts = [];
  await page.exposeFunction('__post', (url, body) => posts.push([url, body]));
  await page.route('https://server_shop/**', async (route) => { posts.push([route.request().url(), route.request().postData()]); route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }); });
  await page.addInitScript(() => { window.GetParentResourceName = () => 'server_shop'; window.__opened = []; window.invokeNative = (n, u) => window.__opened.push([n, u]); });
  await page.goto('file://' + path);
  check(await page.locator('#shop').isHidden(), 'fermée au chargement (aucune interface affichée)');
  const send = (m) => page.evaluate((m) => window.postMessage(m, '*'), m);
  await send({ action: 'open' });
  check(await page.locator('.spinner').isVisible(), 'ouverture : état de chargement');
  await send({ action: 'data', data: { serverName: 'Elyzea', siteUrl: 'https://boutique.exemple.fr', catalog, account: { name: 'Alex Moreau', cfxId: '1' },
    summary: { linked: false, entitlements: [{ type: 'group', name: 'vip_or', product: 'VIP Or', expiresAt: '2026-12-01T10:00:00Z' }], history: [
      { ref: 'a', status: 'paid', totalCents: 1500, currency: 'EUR', createdAt: '2026-10-20T10:00:00Z', items: [{ name: 'VIP Or', quantity: 1, delivery: 'delivered', expiresAt: '2026-12-01T10:00:00Z' }] },
      { ref: 'b', status: 'pending', totalCents: 800, currency: 'EUR', createdAt: '2026-10-21T10:00:00Z', items: [{ name: 'Pack de démarrage', quantity: 1, delivery: 'none' }] }] } } });
  await page.waitForSelector('.product-card');
  check(await page.locator('.nav-item').count() === catalog.categories.length + 1, 'catégories du catalogue partagé dans le menu');
  await page.screenshot({ path: OUT + 'nui_01_accueil.png' });
  await page.click('.nav-item:has-text("VIP")');
  check(await page.locator('.product-card').count() === 2, 'catégorie VIP : 2 produits');
  await page.click('.product-card:has-text("VIP Or")');
  await page.waitForSelector('.detail');
  check(await page.locator('.detail').innerText().then((t) => t.includes('1 mois') && t.includes('temporaire')), 'fiche : durée et mention « temporaire »');
  await page.screenshot({ path: OUT + 'nui_02_fiche.png' });
  await page.click('button:has-text("Acheter")');
  await page.waitForTimeout(300);
  const co = posts.find((p) => p[0].endsWith('/checkout'));
  check(co && JSON.parse(co[1]).productId === catalog.products.find((p) => p.name === 'VIP Or').id && !('price' in JSON.parse(co[1])), 'achat : seule l\'intention (id + quantité) est envoyée, pas de prix');
  check(await page.locator('button:has-text("Préparation du paiement")').isDisabled(), 'bouton bloqué pendant la préparation (pas de double clic)');
  await send({ action: 'result', kind: 'checkout', data: { error: 'Le service de paiement ne répond pas.' } });
  await page.waitForSelector('.toast.error');
  check(true, 'erreur serveur : notification d\'erreur, aucun faux succès');
  await page.click('button:has-text("Acheter")');
  await send({ action: 'result', kind: 'checkout', data: { url: 'https://ident.tebex.io/fivem?x=1', ref: 'r' } });
  await page.waitForSelector('.url');
  check(await page.evaluate(() => window.__opened.length) === 1, 'lien Tebex ouvert dans le navigateur (invokeNative openUrl)');
  check(await page.locator('text=Rien n\'est livré tant que Tebex').count() === 1, 'message honnête : livraison seulement après confirmation');
  await page.screenshot({ path: OUT + 'nui_03_paiement.png' });
  await page.click('[data-view="history"]');
  check(await page.locator('.order').count() === 2 && await page.locator('text=En attente de paiement').count() === 1, 'historique avec statuts');
  await page.screenshot({ path: OUT + 'nui_04_historique.png' });
  await page.click('[data-view="account"]');
  await page.click('button:has-text("Générer un code")');
  await send({ action: 'result', kind: 'link', data: { code: 'ABCD2345', url: 'https://boutique.exemple.fr/connexion' } });
  await page.waitForSelector('.code');
  check((await page.locator('.code').innerText()) === 'ABCD2345', 'code de liaison affiché');
  await page.screenshot({ path: OUT + 'nui_05_compte.png' });
  // Texte malveillant venant de l'API : affiché comme texte
  const evil = JSON.parse(JSON.stringify(catalog)); evil.products[0].name = '<img src=x onerror="window.__xss=1">';
  await send({ action: 'data', data: { serverName: 'Elyzea', catalog: evil } });
  await page.click('.nav-item:has-text("Accueil")');
  check(await page.evaluate(() => !window.__xss), 'contenu de l\'API inséré comme texte (pas d\'injection HTML)');
  await page.keyboard.press('Escape');
  await page.waitForTimeout(300);
  check(posts.some((p) => p[0].endsWith('/close')), 'Échap : demande de fermeture (focus rendu par le client Lua)');
  await send({ action: 'close' });
  await page.waitForTimeout(300);
  check(await page.locator('#shop').isHidden(), 'fermée');
  const small = await b.newPage({ viewport: { width: 1280, height: 720 } });
  await small.addInitScript(() => { window.GetParentResourceName = () => 'server_shop'; });
  await small.goto('file://' + path);
  await small.evaluate((c) => { window.postMessage({ action: 'open' }, '*'); window.postMessage({ action: 'data', data: { serverName: 'Elyzea', catalog: c } }, '*'); }, catalog);
  await small.waitForSelector('.product-card');
  const box = await small.locator('#shop').boundingBox();
  check(box.width <= 1280 && box.height <= 720, 'tient en 1280×720');
  await small.screenshot({ path: OUT + 'nui_06_720p.png' });
  check(errors.length === 0, 'aucune erreur JavaScript ' + errors.join(' | '));
  await b.close();
  console.log(`\n${fails} échec(s)`); process.exit(fails ? 1 : 0);
})();
