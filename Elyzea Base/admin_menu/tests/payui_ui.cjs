// Test de l'interface « supérette » (market.js + payui.js) avec paiement en pesos.
// NODE_PATH=$(npm root -g) node tests/payui_ui.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 880 } });
    const posts = [];
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}' }); });
    await page.route('nui://**', (r) => r.abort());
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    await page.evaluate(() => { window.RES = 'admin_menu'; });
    const shop = { id: 3, name: 'Supérette 24/7', image: 'nui://x/%s.png', categories: [],
        items: [{ i: 1, item: 'water', label: 'Eau', price: 10, cat: 'boissons', max: 10 }, { i: 2, item: 'burger', label: 'Burger', price: 25, cat: 'nourriture', max: 5 }],
        methods: ['cash', 'bank', 'pesos'], rate: 1, wallet: { cash: 5, bank: 300, pesos: 40 }, payChoice: true, payment: 'cash' };
    await page.evaluate((s) => window.postMessage({ action: 'market', open: true, shop: s }, '*'), shop);
    await page.waitForTimeout(300);
    const modes = await page.$$eval('#mk-pay [data-method]', (b) => b.map((x) => x.dataset.method));
    check(modes.join(',') === 'cash,bank,pesos', 'boutons Liquide / Carte / Pesos');
    check((await page.textContent('#mk-wallet')).includes('40 pesos'), 'solde en pesos affiché');
    await page.click('[data-inc="2"]'); await page.click('[data-inc="2"]');
    check(/Il te manque 45/.test(await page.textContent('#mk-pay')), 'liquide insuffisant : montant manquant');
    await page.click('#mk-pay [data-method="pesos"]');
    const pay = await page.textContent('#mk-pay');
    check(pay.includes('50 pesos') && pay.includes('Il te manque 10 pesos') && pay.includes('bureau de change'), 'en pesos : total 50 pesos, manque 10, renvoi au bureau de change');
    check((await page.textContent('#mk-grid')).includes('25 pesos'), 'prix des produits affichés en pesos');
    await page.screenshot({ path: path.join(out, 'superette_pesos.png') });
    await page.click('#mk-go');
    await page.waitForTimeout(100);
    const buy = posts.find((p) => p.ep === 'market_buy');
    check(buy && buy.body.method === 'pesos', 'achat envoyé avec la méthode « pesos » (le serveur revérifie)');
    // Commerce en pesos uniquement
    await page.evaluate((s) => window.postMessage({ action: 'market', open: true, shop: { ...s, methods: ['pesos'], payChoice: false, payment: 'item', wallet: { pesos: 40 } } }, '*'), shop);
    await page.waitForTimeout(200);
    check((await page.textContent('#mk-pay')).includes('pesos uniquement') && !(await page.$('#mk-pay [data-method]')), 'pesos imposés : pas de choix, « pesos uniquement »');
    // Ancien format (sans methods) : liquide / carte comme avant
    await page.evaluate((s) => { const o = { ...s }; delete o.methods; o.wallet = { cash: 100, bank: 50 }; window.postMessage({ action: 'market', open: true, shop: o }, '*'); }, shop);
    await page.waitForTimeout(200);
    const m2 = await page.$$eval('#mk-pay [data-method]', (b) => b.map((x) => x.dataset.method));
    check(m2.join(',') === 'cash,bank', 'ancien format : liquide / carte');
    await browser.close();
    console.log(`\nSupérette : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
