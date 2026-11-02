// Test de l'éditeur de PNJ : rôle « Fourrière » + type de garage public (Chromium headless).
// NODE_PATH=$(npm root -g) node tests/impound_editor_ui.cjs [dossier captures]
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
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    const peds = [
        { id: 5, model: 's_m_y_cop_01', name: 'Gardien', x: 0, y: 0, z: 0, h: 0, npc: { payment: 'cash', impound: { kind: 'air', name: 'Fourrière LSIA', blip: true,
            spots: [{ x: 1, y: 2, z: 3, h: 90, cls: 'heli' }, { x: 4, y: 5, z: 6, h: 0, cls: 'plane' }] } } },
        { id: 6, model: 'a_m_m_business_01', name: 'Port', x: 0, y: 0, z: 0, h: 0, npc: { payment: 'cash', pubgarage: { name: 'Port de plaisance', kind: 'sea', blip: true, spots: [], stores: [] } } },
    ];
    await page.evaluate((peds) => {
        const perms = { editor_peds: true };
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: {
            me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true }, players: [], keys: [], jobs: [],
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [{ id: '', label: 'Aucune' }] } },
            editor: { spawns: [], props: [], peds, fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] },
        } }, '*');
    }, peds);
    await page.waitForTimeout(300);
    await page.evaluate(() => { tab = 'editor'; editorSub = 'peds'; pedEdit = toPedEdit(D.editor.peds.find((x) => x.id === 5)); render(); });
    await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('🚧 Fourrière') && txt.includes('Places de sortie par type'), 'carte « Fourrière » affichée');
    check(await page.$eval('select[data-pe="impKind"]', (s) => s.value) === 'air', 'type de fourrière : aérienne');
    check(txt.includes('🚁 Hélicoptères') && txt.includes('✈️ Avions'), 'places listées avec leur type');
    const btns = await page.$$eval('[data-ed="impound_spot"]', (b) => b.map((x) => x.dataset.cls));
    check(btns.join(',') === 'heli,plane,all', 'boutons de pose : hélico, avion, tous types');
    check(txt.includes('Dollars ou pesos'), 'réglage dollars / pesos du PNJ présent');
    await page.click('[data-ed="impound_spot"][data-cls="plane"]');
    await page.waitForTimeout(100);
    const pl = posts.find((p) => p.ep === 'editor' && p.body.name === 'impound_spot');
    check(pl && pl.body.data ? pl.body.data.cls === 'plane' : (pl && JSON.stringify(pl.body).includes('plane')), 'pose d\'une place « avion » demandée au jeu');
    await page.screenshot({ path: path.join(out, 'editeur_fourriere.png'), fullPage: true });
    // Enregistrement : le rôle part au serveur
    await page.selectOption('select[data-pe="currency"]', 'pesos');
    const payload = await page.evaluate(() => pedEditPayload(pedEdit));
    check(payload.npc && payload.npc.impound && payload.npc.impound.kind === 'air' && payload.npc.impound.name === 'Fourrière LSIA', 'données enregistrées : rôle fourrière aérienne');
    check(payload.npc.currency === 'pesos', 'données enregistrées : PNJ en pesos');
    // Changer le type : il faut enregistrer avant de poser
    await page.selectOption('select[data-pe="impKind"]', 'sea');
    await page.waitForTimeout(100);
    check((await page.textContent('#content')).includes('Type de fourrière changé'), 'type changé : demande d\'enregistrer avant de poser');
    // Garage maritime
    await page.evaluate(() => { pedEdit = toPedEdit(D.editor.peds.find((x) => x.id === 6)); render(); });
    await page.waitForTimeout(150);
    check(await page.$eval('select[data-pe="pubKind"]', (s) => s.value) === 'sea', 'garage public : type « bateaux » chargé');
    check((await page.textContent('#content')).includes('sur l\'eau'), 'garage maritime : conseil de pose sur l\'eau');
    const p2 = await page.evaluate(() => pedEditPayload(pedEdit));
    check(p2.npc.pubgarage.kind === 'sea', 'données enregistrées : garage maritime');
    await browser.close();
    console.log(`\nÉditeur : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
