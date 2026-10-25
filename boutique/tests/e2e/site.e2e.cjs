// Test navigateur (Playwright) du site et du panel. Base de DÉVELOPPEMENT uniquement (crée des données).
// API démarrée, produits vip-or / pack-demarrage reliés à Tebex, vip-diamant non relié.
// GAME_TOKEN=... ADMIN_PASS=... node tests/e2e/site.e2e.cjs
const { chromium } = require('playwright');
const OUT = (process.env.SHOTS_DIR || require('os').tmpdir()) + '/';
const BASE = process.env.API_URL || 'http://localhost:3000';
const GAME = process.env.GAME_TOKEN;
let fails = 0;
const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
(async () => {
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = [];
  const http = [];
  page.on('response', (r) => { if (r.status() >= 400) http.push(r.status() + ' ' + r.url().replace(BASE, '')); });
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.goto(BASE + '/', { waitUntil: 'networkidle' });
  check(await page.locator('h1').innerText().then((t) => t.includes('Elyzea')), 'accueil : bannière avec le nom du serveur');
  check(await page.locator('.product-card').count() >= 2, 'accueil : produits mis en avant / populaires');
  await page.screenshot({ path: OUT + '01_accueil.png', fullPage: true });
  await page.click('text=Voir les produits');
  await page.waitForSelector('.product-card');
  const nProducts = (await fetch(BASE + '/api/catalog').then((x) => x.json())).products.length;
  check(await page.locator('.product-card').count() === nProducts, `catalogue : ${nProducts} produits (tous ceux de l'API)`);
  await page.click('.chip:has-text("VIP")');
  check(await page.locator('.product-card').count() === 2, 'filtre catégorie VIP : 2 produits');
  check(await page.locator('.product-card:has-text("VIP Diamant") >> text=Indisponible').count() === 1, 'produit sans paquet Tebex : « Indisponible », pas de bouton');
  await page.screenshot({ path: OUT + '02_catalogue.png', fullPage: true });
  await page.click('text=VIP Or >> nth=0');
  await page.waitForSelector('.product-info');
  check(await page.locator('.product-info').innerText().then((t) => t.includes('30 jours') || t.includes('1 mois')), 'fiche produit : durée indiquée');
  await page.screenshot({ path: OUT + '03_fiche.png', fullPage: true });
  await page.click('text=Ajouter au panier');
  await page.goto(BASE + '/panier');
  await page.waitForSelector('.cart-line');
  check(await page.locator('text=Se connecter').count() === 1, 'panier sans compte : demande la liaison');
  // Code de liaison généré par le « serveur de jeu »
  const r = await fetch(BASE + '/api/game/link-code', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + GAME }, body: JSON.stringify({ cfxId: '1234567', name: 'Alex Moreau', identifiers: { license: 'license:abc' } }) });
  const { code } = await r.json();
  await page.click('text=Se connecter');
  await page.fill('#code', 'MAUVAIS1');
  await page.click('button:has-text("Lier mon compte")');
  await page.waitForSelector('.alert-error');
  check(true, 'mauvais code : message d\'erreur');
  await page.fill('#code', code.slice(0, 4) + ' ' + code.slice(4));
  await page.screenshot({ path: OUT + '04_connexion.png', fullPage: true });
  await page.click('button:has-text("Lier mon compte")');
  await Promise.race([page.waitForSelector('.summary >> text=Alex Moreau'), page.waitForSelector('text=Trop de tentatives')]);
  if (await page.locator('text=Trop de tentatives').count()) { console.log('  Limite de 10 liaisons / 15 min atteinte : redémarrez l\'API puis relancez.'); process.exit(2); }
  check(await page.locator('text=Alex Moreau').count() >= 1, 'liaison réussie : retour au panier, connecté');
  const pay = page.locator('button:has-text("Payer avec Tebex")');
  check(await pay.isDisabled(), 'paiement bloqué tant que les CGV ne sont pas acceptées');
  await page.check('.summary input[type=checkbox]');
  await page.screenshot({ path: OUT + '05_panier.png', fullPage: true });
  await pay.click();
  await page.waitForSelector('.summary .alert-error');
  check((await page.locator('.summary .alert-error').innerText()).includes('paiement ne répond pas'), 'Tebex injoignable (bac à sable sans réseau) : erreur claire, pas de faux succès');
  await page.goto(BASE + '/compte');
  await page.waitForSelector('h2');
  check(await page.locator('text=Aucun achat').count() === 1, 'compte : historique vide (commande annulée non affichée)');
  await page.screenshot({ path: OUT + '06_compte.png', fullPage: true });
  await page.goto(BASE + '/commande/00000000-0000-4000-8000-000000000000');
  await page.waitForSelector('.alert-error');
  check(true, 'commande inconnue : erreur');
  await page.goto(BASE + '/erreur?raison=mauvais-compte');
  check(await page.locator('text=autre compte Cfx.re').count() === 1, 'page d\'erreur explicite (mauvais compte)');
  for (const p of ['/faq', '/cgv', '/remboursement', '/confidentialite', '/support', '/nimportequoi']) {
    await page.goto(BASE + p); await page.waitForSelector('h1, h3');
  }
  check(true, 'pages FAQ, CGV, remboursement, confidentialité, support, 404 affichées');
  // Mobile
  const m = await b.newPage({ viewport: { width: 390, height: 844 }, isMobile: true });
  await m.goto(BASE + '/', { waitUntil: 'networkidle' });
  const overflow = await m.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1);
  check(!overflow, 'mobile : pas de défilement horizontal');
  await m.screenshot({ path: OUT + '07_mobile.png', fullPage: true });
  await m.goto(BASE + '/boutique'); await m.waitForSelector('.product-card');
  await m.screenshot({ path: OUT + '08_mobile_catalogue.png', fullPage: false });
  // Admin
  const a = await b.newPage({ viewport: { width: 1440, height: 900 } });
  await a.goto(BASE + '/admin');
  await a.fill('#u', process.env.ADMIN_USER || 'patron'); await a.fill('#p', process.env.ADMIN_PASS);
  await a.click('button:has-text("Se connecter")');
  await a.waitForSelector('.stat-grid');
  check(true, 'admin : connexion, tableau de bord');
  await a.screenshot({ path: OUT + '09_admin_dashboard.png', fullPage: true });
  await a.click('nav >> text=Produits'); await a.waitForSelector('table');
  await a.screenshot({ path: OUT + '10_admin_produits.png', fullPage: true });
  await a.click('text=VIP Diamant'); await a.waitForSelector('.reward-row');
  await a.fill('input[placeholder="ID du paquet"]', '9003');
  await a.click('button:has-text("Enregistrer")');
  await a.waitForSelector('.toast.success');
  check(true, 'admin : produit relié à un paquet Tebex et enregistré');
  await a.screenshot({ path: OUT + '11_admin_produit.png', fullPage: true });
  await a.click('nav >> text=Commandes'); await a.waitForSelector('table');
  check(await a.locator('text=Annulée').count() >= 1, 'admin : commande annulée (Tebex injoignable) visible');
  await a.click('nav >> text=Journaux'); await a.waitForSelector('table');
  check(await a.locator('text=tebex.basket_failed').count() >= 1, 'admin : erreur Tebex journalisée');
  await a.screenshot({ path: OUT + '12_admin_journaux.png', fullPage: true });
  const vd = await fetch(BASE + '/api/products/vip-diamant').then((x) => x.json());
  check(vd.available === true, 'le site reflète la modification (VIP Diamant achetable)');
  console.log('  réponses HTTP en erreur (attendues) :', http.join(' ; '));
  check(errors.length === 0, 'aucune erreur JavaScript' + (errors.length ? ' : ' + errors.join(' | ') : ''));
  await b.close();
  console.log(`\n${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
