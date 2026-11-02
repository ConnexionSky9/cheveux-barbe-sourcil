// Test de l'interface de la fourrière (Chromium headless) : NODE_PATH=$(npm root -g) node tests/ui.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };

const classes = { car: { label: 'Voiture', icon: '🚗', kind: 'land' }, moto: { label: 'Moto', icon: '🏍️', kind: 'land' },
    heli: { label: 'Hélicoptère', icon: '🚁', kind: 'air' }, plane: { label: 'Avion', icon: '✈️', kind: 'air' }, boat: { label: 'Bateau', icon: '🚤', kind: 'sea' } };
const kinds = { land: { label: 'Fourrière terrestre' }, air: { label: 'Fourrière aérienne' }, sea: { label: 'Fourrière maritime' } };
const data = {
    name: 'Fourrière de Davis', kind: 'land', kindLabel: 'Fourrière terrestre', repairMinutes: 60, rate: 1,
    methods: ['cash', 'bank', 'pesos'], wallet: { cash: 450, bank: 12000, pesos: 200 }, spots: { car: 1, moto: 1 }, classes, kinds,
    list: [
        { plate: 'CAR001', model: 'sultan', label: 'Sultan', cls: 'car', kind: 'land', destroyed: false, reason: 'police', status: 'impound', price: 500 },
        { plate: 'MOTO01', model: 'bati', label: 'Bati 801', cls: 'moto', kind: 'land', destroyed: false, reason: 'police', status: 'impound', price: 300 },
        { plate: 'WRECK1', model: 'blista', label: 'Blista', cls: 'car', kind: 'land', destroyed: true, reason: 'destroyed', status: 'impound', price: 1500 },
        { plate: 'REPAI1', model: 'sanchez', label: 'Sanchez', cls: 'moto', kind: 'land', destroyed: true, reason: 'destroyed', status: 'repair', remain: 1800, paid: 900, paidCurrency: 'cash' },
        { plate: 'HELI01', model: 'frogger', label: 'Frogger', cls: 'heli', kind: 'air', destroyed: true, reason: 'police', status: 'impound', price: 7500 },
    ],
};

(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1600, height: 900 } });
    const posts = [];
    await page.route('https://elyzea_fourriere/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}' }); });
    await page.route('https://docs.fivem.net/**', (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    await page.evaluate((d) => window.postMessage({ action: 'open', data: d }, '*'), data);
    await page.waitForTimeout(400);

    check(await page.isVisible('#app'), 'interface ouverte');
    check((await page.textContent('#poundName')) === 'Fourrière de Davis', 'nom de la fourrière');
    check((await page.$$('.card')).length === 4, 'onglet « Cette fourrière » : 4 véhicules terrestres (hélico masqué)');
    const txt = await page.textContent('#grid');
    check(txt.includes('CAR001') && txt.includes('500 $') && txt.includes('Voiture'), 'modèle, plaque, type et prix affichés');
    check(txt.includes('Complètement détruit') && txt.includes('Payer la réparation'), 'véhicule détruit : état et bouton réparation');
    check(/Encore (29|30):\d\d/.test(txt), 'réparation : temps restant affiché');
    check(txt.includes('Payé 900 $'), 'réparation : montant payé affiché');
    const wreckBtn = await page.$('[data-pay="WRECK1"]');
    check(await wreckBtn.isDisabled(), 'pas assez de liquide (450 $) pour 1 500 $ : bouton désactivé');
    check(/Il te manque 1\s050 \$/.test(txt), 'montant manquant affiché');
    await page.screenshot({ path: path.join(out, 'fourriere_liquide.png') });

    await page.click('[data-method="pesos"]');
    const t2 = await page.textContent('#grid');
    check(t2.includes('500 pesos') && t2.includes('300 pesos'), 'paiement en pesos : prix affichés en pesos');
    check(t2.includes('bureau de change'), 'pesos insuffisants : renvoi au bureau de change');
    check(await (await page.$('[data-pay="MOTO01"]')).isDisabled(), 'moto 300 pesos avec 200 pesos : bouton désactivé');
    check(!(await (await page.$('[data-pay="MOTO01"]')).isDisabled()) === false, 'aucun paiement possible sans les pesos');
    await page.screenshot({ path: path.join(out, 'fourriere_pesos.png') });

    await page.click('[data-method="bank"]');
    await page.click('[data-pay="WRECK1"]');
    await page.waitForTimeout(150);
    const pay = posts.find((p) => p.ep === 'pay');
    check(pay && pay.body.plate === 'WRECK1' && pay.body.method === 'bank', 'clic : demande envoyée (plaque + banque)');
    check((await page.textContent('[data-pay="WRECK1"]')).includes('Paiement'), 'bouton « Paiement… » pendant la demande');
    await page.evaluate(() => window.postMessage({ action: 'result', ok: false, msg: 'La place de sortie est occupée. Libère-la puis réessaie.' }, '*'));
    await page.waitForTimeout(100);
    check((await page.textContent('#msg')).includes('occupée'), 'message d\'erreur du serveur affiché');

    await page.click('[data-tab="all"]');
    check((await page.$$('.card')).length === 5, 'onglet « Tous mes véhicules » : 5');
    const heli = await page.textContent('.card.away');
    check(heli.includes('fourrière aérienne'), 'hélico : à récupérer à la fourrière aérienne');
    await page.screenshot({ path: path.join(out, 'fourriere_tous.png') });

    // Monnaie imposée
    await page.evaluate((d) => window.postMessage({ action: 'open', data: { ...d, methods: ['pesos'], forced: true } }, '*'), data);
    await page.waitForTimeout(150);
    check((await page.textContent('#pay')).includes('Pesos uniquement') && !(await page.$('[data-method]')), 'monnaie imposée : « Pesos uniquement », pas de choix');

    await page.keyboard.press('Escape');
    await page.waitForTimeout(100);
    check(!(await page.isVisible('#app')) && posts.some((p) => p.ep === 'close'), 'Échap ferme et prévient le client');

    // Téléphone (petit écran)
    await page.setViewportSize({ width: 390, height: 800 });
    await page.evaluate((d) => window.postMessage({ action: 'open', data: d }, '*'), data);
    await page.waitForTimeout(200);
    const sw = await page.evaluate(() => document.documentElement.scrollWidth);
    check(sw <= 390, 'petit écran : pas de défilement horizontal');
    await browser.close();
    console.log(`\nInterface fourrière : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
