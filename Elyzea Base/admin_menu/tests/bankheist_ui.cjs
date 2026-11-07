// Test du menu staff : onglet « Braquage de banque » (bank_heist 2.0), Chromium headless.
// node tests/bankheist_ui.cjs <admindata.json> [dossier captures]
// admindata.json = exports.bank_heist:AdminData() (généré par la simulation serveur).
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const out = process.argv[3] || path.join(__dirname, 'shots');
fs.mkdirSync(out, { recursive: true });
let fails = 0;
const check = (c, l) => { console.log(`  ${c ? 'ok  ' : 'ÉCHEC'} ${l}`); if (!c) fails++; };
(async () => {
    const browser = await chromium.launch();
    const page = await browser.newPage({ viewport: { width: 1500, height: 1000 } });
    const posts = [];
    page.on('pageerror', (e) => { console.log('  ERREUR JS', e.message); fails++; });
    await page.route('https://admin_menu/**', (r) => { posts.push({ ep: r.request().url().split('/').pop(), body: JSON.parse(r.request().postData() || '{}') }); r.fulfill({ status: 200, body: '{}', contentType: 'application/json' }); });
    await page.route(/^https?:\/\/(?!admin_menu)/, (r) => r.abort());
    await page.goto('file://' + path.join(__dirname, '..', 'html', 'index.html'));
    await page.evaluate((bankheist) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: { me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms: { bankheist_manage: true }, onDuty: true, duty: true },
            players: [], keys: [], jobs: [], bankheist, config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [] } },
            editor: { spawns: [], props: [], peds: [], fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] } } }, '*');
    }, data);
    await page.waitForTimeout(300);
    await page.evaluate(() => { tab = 'bankheist'; render(); }); await page.waitForTimeout(200);
    const subs = await page.$$eval('[data-bsub]', (l) => l.map((b) => b.dataset.bsub));
    check(subs.length === 14, `14 sous-onglets (${subs.join(', ')})`);
    for (const s of subs) {
        await page.click(`[data-bsub="${s}"]`); await page.waitForTimeout(80);
        const t = await page.textContent('#content');
        check(t.length > 200 && !t.includes('undefined') && !t.includes('[object Object]'), `sous-onglet ${s} : rendu sans « undefined »`);
        await page.screenshot({ path: path.join(out, `admin_bh_${s}.png`), fullPage: true });
    }
    for (const [s, y] of [['points', 520], ['door', 420], ['informants', 380]]) {
        await page.click(`[data-bsub="${s}"]`); await page.waitForTimeout(80);
        await page.evaluate((y) => { const c = document.querySelector('#content'); if (c) c.scrollTop = y; document.querySelectorAll('*').forEach((e) => { if (e.scrollHeight > e.clientHeight + 50 && getComputedStyle(e).overflowY === 'auto') e.scrollTop = y; }); }, y);
        await page.waitForTimeout(80);
        await page.screenshot({ path: path.join(out, `admin_bh_${s}_detail.png`) });
    }
    // Points de butin : changer le type, le montant, ajouter un point du type choisi
    await page.click('[data-bsub="points"]');
    await page.selectOption('[data-bf="banks.0.loot.0.type"]', 'trolley_gold'); await page.waitForTimeout(80);
    await page.fill('[data-bf="banks.0.loot.0.max"]', '77000');
    await page.selectOption('#bh-lt', 'stack_cash');
    await page.click('[data-ba="place"][data-w="loot"]:not([data-li])'); await page.waitForTimeout(100);
    let p = posts.filter((x) => x.ep === 'action' && x.body.name === 'bankheist').pop();
    check(p && p.body.data.name === 'place' && p.body.data.data.lootType === 'stack_cash' && p.body.data.data.draft.banks[0].loot[0].type === 'trolley_gold'
        && p.body.data.data.draft.banks[0].loot[0].max === 77000, 'ajout d\'un point « liasses » + brouillon (chariot de lingots, max 77 000 $) envoyé');
    await page.evaluate(() => { tab = 'bankheist'; render(); }); await page.waitForTimeout(100);
    await page.click('[data-bsub="points"]');
    await page.click('[data-ba="place"][data-li="2"]'); await page.waitForTimeout(100);
    p = posts.filter((x) => x.ep === 'action' && x.body.name === 'bankheist').pop();
    check(p && p.body.data.data.lootIndex === 2 && !p.body.data.data.lootType, 'déplacement du point #2');
    // Porte, alarme, indics
    await page.click('[data-bsub="door"]');
    await page.click('[data-bt="door.c4OnlyAfterHack"]'); await page.waitForTimeout(60);
    await page.fill('[data-bf="drill.time"]', '40');
    await page.click('[data-bsub="alarm"]');
    await page.fill('[data-bf="alarm.volume"]', '0.3');
    await page.click('[data-bsub="informants"]');
    await page.fill('[data-bf="informants.0.price"]', '1200');
    await page.selectOption('[data-bf="informants.0.merchant"]', 'fournisseur'); await page.waitForTimeout(60);
    await page.click('[data-bsub="cond"]');
    await page.selectOption('[data-bf="banks.0.required.tool"]', 'c4'); await page.waitForTimeout(60);
    await page.click('[data-bsub="live"]');
    const live = await page.textContent('#content');
    check(live.includes('Braquage en cours') && live.includes('Porte verrouillée') && live.includes('Alarme déclenchée') && live.includes('Alice'), 'sessions en direct : porte, alarme, braqueurs');
    await page.click('[data-ba="save"]'); await page.waitForTimeout(100);
    p = posts.filter((x) => x.ep === 'action' && x.body.name === 'bankheist').pop();
    const d = p && p.body.data.data;
    check(p && p.body.data.name === 'save' && d.door.c4OnlyAfterHack === !data.settings.door.c4OnlyAfterHack && d.drill.time === 40 && d.alarm.volume === 0.3
        && d.informants[0].price === 1200 && d.informants[0].merchant === 'fournisseur' && d.banks[0].required.tool === 'c4', 'enregistré : C4 après décryptage, perceuse 40 s, volume 0,3, indic 1 200 $ → fournisseur, outil C4');
    await browser.close();
    console.log(`\nBraquage de banque (menu staff) : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
