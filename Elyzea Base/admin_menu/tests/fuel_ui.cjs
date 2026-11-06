// Test du menu staff : onglet « Stations essence » (elyzea_fuel 2.0 : débit de la pompe, essence renversée), Chromium headless.
// NODE_PATH=$(npm root -g) node tests/fuel_ui.cjs [dossier captures]
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
    const fuel = { available: true, settings: { enabled: true, consumption: 1, price: 3, payWith: 'auto', showBlips: true, flowRate: 1.2, chargeSpill: true },
        stations: [{ id: 1, label: 'LTD Grove Street', x: -70.2, y: -1761.8, z: 29.5, radius: 12, price: 3, enabled: true }] };
    await page.evaluate((fuel) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: { me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { fuel_manage: true }, onDuty: true, duty: true },
            players: [], keys: [], jobs: [], fuel, config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
    }, fuel);
    await page.waitForTimeout(300);
    await page.evaluate(() => { tab = 'fuel'; render(); }); await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('clic droit') && txt.includes('Débit de la pompe') && txt.includes('Essence renversée payée') && !txt.includes('millisecondes'), 'réglages de la pompe : débit, essence renversée (plus de « durée du plein »)');
    await page.fill('[data-fuf="flowRate"]', '2.5');
    await page.click('[data-fub="chargeSpill"]'); await page.waitForTimeout(100);
    check((await page.textContent('#content')).includes('Essence renversée offerte'), 'bascule « essence renversée offerte »');
    await page.screenshot({ path: path.join(out, 'admin_fuel.png'), fullPage: true });
    await page.click('[data-fua="save"]'); await page.waitForTimeout(150);
    const save = posts.filter((p) => p.ep === 'action' && p.body.name === 'fuel').pop();
    check(save && save.body.data.name === 'saveSettings' && save.body.data.data.flowRate === 2.5 && save.body.data.data.chargeSpill === false, 'enregistré : débit 2,5 L/s, essence renversée offerte');
    await browser.close();
    console.log(`\nStations essence (menu staff) : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
