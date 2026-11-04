// Test du menu staff : onglet « Gestion immobilière » (elyzea_dynasty), Chromium headless.
// NODE_PATH=$(npm root -g) node tests/dynasty_ui.cjs [dossier captures]
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
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{"street":"Hillcrest Ave"}', contentType: 'application/json' }); });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    const D8 = { available: true, categories: { apartment: 'Appartement', house: 'Maison', villa: 'Villa', garage: 'Garage' },
        sizes: { small: { label: 'Petit garage', capacity: 2 }, medium: { label: 'Garage moyen', capacity: 6 } },
        interiors: [{ id: 1, label: '3655 Wild Oats', kind: 'house' }, { id: 2, label: 'Garage 2 places', kind: 'garage' }], agencies: [],
        props: [{ id: 7, name: 'Villa Test', address: 'Hillcrest', category: 'villa', enabled: true, salePrice: 500000, rentPrice: 900, holder: 'Alice Martin', kind: 'sale', upgrades: ['cameras', 'dancer'], cams: 3, pots: 0, dancer: true,
            points: { enter: true, bell: false, exit: false, manage: false, stash: false, garage: true, gEnter: false, gSpawn: false, gInside: false, gExit: false, slots: 0 } }],
        spots: [{ id: 3, pid: 7, label: 'Portail', x: 1, y: 2, z: 3, rx: -10, rz: 45, fov: 60, yaw: 30, pitch: 15 }],
        cfg: { cameras: { enabled: true, price: 15000, payTo: 'agency', max: 4, radius: 25, fovMin: 25, fovMax: 90 },
            dancer: { enabled: true, price: 25000, payTo: 'agency', max: 1, maxMinutes: 30, cooldownSeconds: 20, anims: [{ id: 'private1', label: 'Danse privée 1', on: true }, { id: 'idle', label: 'Attente', on: false }] },
            cannabis: { enabled: true, price: 20000, payTo: 'none', maxPots: 3, speed: 1 } } };
    await page.evaluate((d8) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: { me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { property_manage: true }, onDuty: true, duty: true }, players: [], keys: [], jobs: [], d8,
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
    }, D8);
    await page.waitForTimeout(300);
    await page.evaluate(() => { tab = 'dynasty'; render(); }); await page.waitForTimeout(200);
    const last = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'd8').pop();
    check((await page.textContent('#content')).includes('Créer un logement à ma position'), 'formulaire de création rapide');
    await page.fill('[data-d8f="name"]', 'Maison Bleue'); await page.selectOption('[data-d8f="interiorId"]', '1');
    await page.click('[data-d8create]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'quickCreate' && last().body.data.data.name === 'Maison Bleue' && last().body.data.data.interiorId === 1, 'création envoyée');
    await page.click('[data-d8sel="7"]'); await page.waitForTimeout(150);
    check((await page.textContent('#content')).includes('Assistant · #7'), 'assistant de placement ouvert');
    await page.screenshot({ path: path.join(out, 'admin_dynasty.png'), fullPage: true });
    await page.click('[data-d8pt="garage.enter"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'point' && last().body.data.data.key === 'garage.enter', 'placer un point à ma position');
    await page.click('[data-d8spot]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'spotAdd' && last().body.data.data.pid === 7, 'emplacement de caméra');
    await page.fill('[data-spot="3"] [data-sf="yaw"]', '60'); await page.click('[data-spot="3"] [data-spotsave]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'spotEdit' && last().body.data.data.yaw === 60, 'réglage d\'un emplacement');
    await page.fill('[data-d8cfg="cameras.max"]', '6'); await page.click('[data-d8save="cameras"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'upSettings' && last().body.data.data.patch.max === 6, 'réglages des caméras');
    await page.check('[data-d8anim="idle"]'); await page.click('[data-d8save="dancer"]'); await page.waitForTimeout(100);
    check(last().body.data.data.patch.animsOn.idle === true, 'animations de la danseuse');
    await page.click('[data-d8arm="reset:7:cameras"]'); await page.waitForTimeout(100);
    await page.click('[data-d8arm="reset:7:cameras"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'upReset' && last().body.data.data.kind === 'cameras', 'réinitialisation avec confirmation');
    await page.click('[data-d8sel="7"]'); await page.waitForTimeout(150);
    await page.click('[data-d8own="me"]'); await page.waitForTimeout(100);
    check(last().body.data.name === 'setOwner' && last().body.data.data.pid === 7, 'me mettre propriétaire');
    await page.check('[data-d8ownreplace]'); await page.fill('[data-d8owntarget]', '12'); await page.click('[data-d8own="target"]'); await page.waitForTimeout(100);
    check(last().body.data.data.target === 12 && last().body.data.data.replace === true, 'donner le logement à un joueur (remplacer)');
    await browser.close();
    console.log(fails ? `${fails} ÉCHEC(S)` : 'TOUS LES TESTS ADMIN IMMOBILIER SONT PASSÉS');
    process.exit(fails ? 1 : 0);
})();
