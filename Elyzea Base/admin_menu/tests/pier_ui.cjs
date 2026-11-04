// Test du menu staff : onglet « Parc de Del Perro » (elyzea_pier), Chromium headless.
// NODE_PATH=$(npm root -g) node tests/pier_ui.cjs [dossier captures]
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
    const send = (perms, pier) => page.evaluate(({ perms, pier }) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: {
            me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true }, players: [], keys: [], jobs: [], pier,
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] },
        } }, '*');
    }, { perms, pier });
    const PIER = { available: true, pendingDuration: false,
        settings: { wheelEnabled: true, coasterEnabled: false, wheelPrice: 150, coasterPrice: 250, cash: true, bank: true, maxPerPurchase: 10, maxOwned: 50,
            turnDuration: 180, stopDuration: 14, idleRotation: true, boardingTime: 25, fullDepartDelay: 6, coasterDuration: 0,
            npc: { enabled: true, x: -1658.1, y: -1131.85, z: 13.02, h: 49, model: 's_m_m_strvend_01', scenario: 'WORLD_HUMAN_STAND_IMPATIENT', blip: true } },
        wheel: { status: 'en marche', capacity: 32, free: 29, queue: 2, riders: [{ id: 4, name: 'Léna Duval', place: 'cabine 3' }, { id: 5, name: 'Malik Benali', place: 'cabine 3' }, { id: 6, name: 'Inès', place: 'cabine 4' }] },
        coaster: { status: 'fermées', capacity: 8, free: 8, queue: 0, riders: [], natural: 61 },
        players: [{ id: 4, name: 'Léna Duval' }, { id: 5, name: 'Malik Benali' }] };
    await send({}, undefined); await page.waitForTimeout(300);
    check(!(await page.evaluate(() => TABS.find((t) => t.id === 'pier').show())), 'sans la permission : onglet caché');
    await send({ pier_manage: true }, PIER); await page.waitForTimeout(300);
    check(await page.evaluate(() => TABS.find((t) => t.id === 'pier').show() && catOf('pier').id === 'eco'), 'avec la permission : onglet visible dans « Économie et services »');
    await page.evaluate(() => { tab = 'pier'; render(); }); await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('Léna Duval') && txt.includes('cabine 3') && txt.includes('3/32') && txt.includes('2 en file'), 'en direct : passagers, places, file d\'attente');
    check(txt.includes('Montagnes russes fermées') && txt.includes('150 $'), 'résumé : ouverture et prix');
    await page.screenshot({ path: path.join(out, 'admin_pier.png'), fullPage: true });
    const last = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'pier').pop();
    await page.click('[data-ptog="coasterEnabled"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'settings' && last().body.data.data.coasterEnabled === true, 'ouvrir les montagnes russes');
    await page.fill('[data-pf="wheelPrice"]', '300'); await page.fill('[data-pf="turnDuration"]', '240');
    await page.click('[data-psave]'); await page.waitForTimeout(100);
    check(last().body.data.data.wheelPrice === 300 && last().body.data.data.turnDuration === 240 && last().body.data.data.coasterPrice === 250, 'prix et durées envoyés');
    await page.click('[data-pact="npcHere"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'npcHere', 'placer le vendeur à ma position');
    await page.fill('[data-pn="model"]', 'a_m_y_beach_01'); await page.click('[data-pnsave]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'npc' && last().body.data.data.model === 'a_m_y_beach_01', 'modèle du vendeur');
    await page.fill('[data-pg="target"]', '4'); await page.selectOption('[data-pg="kind"]', 'coaster'); await page.fill('[data-pg="qty"]', '3');
    await page.click('[data-pgive]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'give' && last().body.data.data.target === 4 && last().body.data.data.kind === 'coaster' && last().body.data.data.qty === 3, 'offrir 3 tickets');
    posts.length = 0;
    await page.click('[data-preset="wheel"]'); await page.waitForTimeout(100);
    check(!last(), 'remise à zéro : confirmation demandée');
    await page.click('[data-preset="wheel"]'); await page.waitForTimeout(100);
    check(last() && last().body.data.name === 'reset' && last().body.data.data.what === 'wheel', 'remise à zéro de la grande roue');
    await send({ pier_manage: true }, { available: false, resource: 'elyzea_pier' }); await page.waitForTimeout(200);
    await page.evaluate(() => { tab = 'pier'; render(); });
    check((await page.textContent('#content')).includes('ne répond pas'), 'ressource arrêtée : message clair');
    await browser.close();
    console.log(fails ? `\n${fails} échec(s)` : '\nTout est bon');
    process.exit(fails ? 1 : 0);
})();
