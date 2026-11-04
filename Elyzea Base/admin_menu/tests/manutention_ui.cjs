// Test du menu staff : onglet « Manutentionnaire » (elyzea_manutention), Chromium headless.
// NODE_PATH=$(npm root -g) node tests/manutention_ui.cjs [dossier captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 1100 } });
    const posts = [];
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    const send = (perms, manut) => page.evaluate(({ perms, manut }) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: {
            me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true }, players: [], keys: [], jobs: [], manut,
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] },
        } }, '*');
    }, { perms, manut });
    const P = (x, y, extra = {}) => Object.assign({ x, y, z: 30.0, h: 90 }, extra);
    const MANUT = { available: true,
        settings: { enabled: true, boxesPerPallet: 20, allowSprint: false, account: 'bank',
            pay: { delivery: 250, perBox: 0, perBoxOn: false, palletDone: 0, palletDoneOn: false, transport: 0, transportOn: false },
            models: { npc: 's_m_y_construct_01', box: 'hei_prop_heist_box', boxOnPallet: 'prop_cs_cardbox_01', pallet: 'prop_pallet_02a', forklift: 'forklift' },
            npc: { enabled: true, placed: true, x: 153.2, y: -3100.5, z: 5.9, h: 270, scenario: 'WORLD_HUMAN_CLIPBOARD' },
            forklift: { enabled: true, max: 10, idleMinutes: 20 },
            pickups: [P(150, -3080, { label: 'Rayon A' }), P(155, -3080, { label: 'Rayon B' })],
            pallets: [P(160, -3090, { label: 'Quai 1' })],
            spawns: [P(140, -3095, { label: 'Garage 1', state: 'libre' }), P(144, -3095, { label: 'Garage 2', state: 'occupé' })],
            deliveries: [P(200, -3120, { label: 'Expédition', radius: 5 })],
            outfit: { male: { c: { 11: [56, 0], 8: [59, 1] }, p: {} }, female: { c: { 11: [49, 0] }, p: {} } } },
        workers: [{ id: 7, name: 'Lucas Martin', stage: 'collect', boxes: 12, required: 20, delivered: 3, earned: 750, plate: 'INTR0042', forklift: true }],
        limits: { maxBoxes: 40, maxPay: 1000000, deliveryRadius: 4 }, defaults: { boxesPerPallet: 20, delivery: 250 } };

    await send({}, undefined);
    await page.waitForTimeout(300);
    check(!(await page.evaluate(() => TABS.find((t) => t.id === 'manut').show())), 'sans la permission « Manutentionnaire » : onglet caché');
    await send({ manut_manage: true }, MANUT);
    await page.waitForTimeout(300);
    check(await page.evaluate(() => TABS.find((t) => t.id === 'manut').show()), 'avec la permission : onglet visible');
    check(await page.evaluate(() => catOf('manut').id === 'eco'), 'rangé dans « Économie et services »');
    await page.evaluate(() => { tab = 'manut'; render(); });
    await page.waitForTimeout(200);
    let txt = await page.textContent('#content');
    check(txt.includes('250 $') && txt.includes('Cartons / palette') && txt.includes('Au travail'), 'résumé : prix, cartons, joueurs au travail');
    check(['Configuration générale', 'PNJ', 'Points de récupération', 'Palettes', 'Fenwick', 'Livraisons', 'Rémunérations', 'Tenue', 'Sauvegardes'].every((s) => txt.includes(s)), 'les 8 sous-catégories (+ joueurs au travail)');
    await page.screenshot({ path: path.join(out, 'manut_general.png'), fullPage: true });

    const last = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'manut').pop();
    posts.length = 0;
    await page.click('[data-mtog="allowSprint"]'); await page.waitForTimeout(100);
    check(last() && last().body.data.name === 'general' && last().body.data.data.allowSprint === true, 'AUTORISER LA COURSE AVEC UN CARTON : envoyé');
    await page.fill('[data-mg="boxesPerPallet"]', '25');
    await page.click('[data-msave="general"]'); await page.waitForTimeout(100);
    check(last().body.data.data.boxesPerPallet === 25, 'nombre de cartons par palette : envoyé');

    await page.click('[data-msec="npc"]'); await page.waitForTimeout(100);
    await page.screenshot({ path: path.join(out, 'manut_npc.png'), fullPage: true });
    await page.click('[data-mact="npcHere"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'npcHere', 'PNJ : « Enregistrer ma position actuelle »');

    for (const [sec, kind] of [['pickups', 'pickups'], ['pallets', 'pallets'], ['deliveries', 'deliveries']]) {
        await page.click(`[data-msec="${sec}"]`); await page.waitForTimeout(100);
        await page.fill(`[data-mnew="${kind}"]`, 'Nouveau');
        await page.click(`[data-madd="${kind}"]`); await page.waitForTimeout(100);
        check(last().body.data.name === 'pointAdd' && last().body.data.data.kind === kind && last().body.data.data.label === 'Nouveau', `${sec} : ajouter à ma position`);
    }
    await page.screenshot({ path: path.join(out, 'manut_livraisons.png'), fullPage: true });
    await page.fill('[data-mrow="deliveries"][data-i="1"] [data-mf="radius"]', '7');
    await page.click('[data-mrow="deliveries"][data-i="1"] [data-mpt="save"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'pointEdit' && last().body.data.data.radius === 7, 'livraison : rayon modifié');
    await page.click('[data-mrow="deliveries"][data-i="1"] [data-mpt="move"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'pointMove', 'livraison : déplacer à ma position');
    posts.length = 0;
    await page.click('[data-mrow="deliveries"][data-i="1"] [data-mpt="del"]'); await page.waitForTimeout(100);
    check(!last(), 'supprimer : premier clic = confirmation demandée');
    await page.click('[data-mrow="deliveries"][data-i="1"] [data-mpt="del"]'); await page.waitForTimeout(100);
    check(last() && last().body.data.name === 'pointDel', 'supprimer : confirmé');

    await page.click('[data-msec="spawns"]'); await page.waitForTimeout(100);
    txt = await page.textContent('#content');
    check(txt.includes('libre') && txt.includes('occupé') && txt.includes('Points libres'), 'Fenwick : emplacements libres / occupés');
    await page.fill('[data-mf2="max"]', '4');
    await page.click('[data-msave="forklift"]'); await page.waitForTimeout(100);
    check(posts.some((p) => p.body.name === 'manut' && p.body.data.name === 'forklift' && p.body.data.data.max === 4), 'Fenwick : nombre maximum envoyé');
    await page.screenshot({ path: path.join(out, 'manut_fenwick.png'), fullPage: true });

    await page.click('[data-msec="pay"]'); await page.waitForTimeout(100);
    await page.click('[data-mquick="750"]');
    await page.click('[data-msave="pay"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'pay' && last().body.data.data.delivery === 750, 'RÉMUNÉRATION PAR PALETTE LIVRÉE : 750 $');
    check(last().body.data.data.perBox === undefined, 'paiements intermédiaires désactivés : non envoyés');
    await page.click('[data-mpayt="perBoxOn"]'); await page.waitForTimeout(100);
    check(last().body.data.data.perBoxOn === true, 'paiement par carton : activable');
    await page.screenshot({ path: path.join(out, 'manut_pay.png'), fullPage: true });

    await page.click('[data-msec="outfit"]'); await page.waitForTimeout(100);
    await page.click('[data-moutfit="female"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'outfitAsk' && last().body.data.data.gender === 'female', 'tenue : copier ma tenue actuelle (femme)');
    await page.click('[data-msec="saves"]'); await page.waitForTimeout(100);
    await page.click('[data-mact="save"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'save', 'sauvegarder les paramètres');
    await page.click('[data-mact="reload"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'reload', 'charger les paramètres enregistrés');
    await page.click('[data-msec="workers"]'); await page.waitForTimeout(100);
    txt = await page.textContent('#content');
    check(txt.includes('Lucas Martin') && txt.includes('12/20') && txt.includes('750 $'), 'joueurs au travail : étape, cartons, gains');
    await page.screenshot({ path: path.join(out, 'manut_workers.png'), fullPage: true });

    await send({ manut_manage: true }, { available: false, resource: 'elyzea_manutention' });
    await page.waitForTimeout(200);
    await page.evaluate(() => { tab = 'manut'; render(); });
    check((await page.textContent('#content')).includes('ne répond pas'), 'ressource arrêtée : message clair');
    await browser.close();
    console.log(fails ? `\n${fails} échec(s)` : '\nTout est bon');
    process.exit(fails ? 1 : 0);
})();
