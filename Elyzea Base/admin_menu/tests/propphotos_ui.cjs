// Test : aperçu image des props au survol dans l'éditeur de map (photo prise en jeu). NODE_PATH=$(npm root -g) node tests/propphotos_ui.cjs [captures]
const { chromium } = require('playwright');
const path = require('path');
const out = process.argv[2] || path.join(__dirname, 'shots');
require('fs').mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
    const posts = [];
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    // Fausse photo renvoyée par le jeu : un carré violet en webp
    const fake = await page.evaluate(() => 'x');
    await page.route('https://admin_menu/**', async (r) => {
        const ep = r.request().url().split('/').pop();
        const body = JSON.parse(r.request().postData() || '{}');
        posts.push({ ep, body });
        let res = {};
        if (ep === 'propThumb') res = body.model === 'prop_bench_01a' ? { src: global.IMG } : { noCapture: false };
        r.fulfill({ status: 200, body: JSON.stringify(res), contentType: 'application/json' });
    });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    global.IMG = await page.evaluate(() => { const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d'); x.fillStyle = '#9B5CFF'; x.fillRect(8, 8, 48, 48); return c.toDataURL('image/webp'); });
    await page.evaluate(() => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: { me: { id: 1, label: 'F', color: '#fff', level: 100, perms: { editor: true, editor_props: true, editor_peds: true }, onDuty: true, duty: true }, players: [], keys: [], jobs: [],
            config: { noclipKey: 'F2', editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
    });
    await page.waitForTimeout(400);
    await page.evaluate(() => { tab = 'editor'; editorSub = 'catalog'; catState.mode = 'props'; render(); });
    await page.waitForTimeout(300);
    check(await page.$('[data-catitem="prop_bench_01a"]') !== null, 'catalogue des props affiché');
    check(await page.$('[data-ppall]') !== null, 'bouton « Générer les images manquantes »');
    await page.hover('[data-catitem="prop_bench_01a"]'); await page.waitForTimeout(900);
    check(posts.some((p) => p.ep === 'propThumb' && p.body.model === 'prop_bench_01a'), 'survol : image demandée au jeu (photo en jeu)');
    const src = await page.$eval('#cat-preview img', (i) => i.src);
    check(src.startsWith('data:image/webp'), 'aperçu : image du prop affichée');
    await page.screenshot({ path: path.join(out, 'editeur_map_apercu.png') });
    await page.hover('[data-catitem="prop_bench_01b"]'); await page.waitForTimeout(150);
    await page.hover('[data-catitem="prop_bench_02"]'); await page.waitForTimeout(900);
    check(!posts.some((p) => p.ep === 'propThumb' && p.body.model === 'prop_bench_01b'), 'survol rapide : pas de photo pour un prop seulement effleuré');
    await page.click('[data-ppall]'); await page.waitForTimeout(200);
    const all = posts.find((p) => p.ep === 'propThumbAll');
    check(all && all.body.models.length > 100, `génération groupée : ${all ? all.body.models.length : 0} props envoyés`);
    await browser.close();
    console.log(fails ? `${fails} ÉCHEC(S)` : 'TOUS LES TESTS APERÇU PROPS SONT PASSÉS');
    process.exit(fails ? 1 : 0);
})();
