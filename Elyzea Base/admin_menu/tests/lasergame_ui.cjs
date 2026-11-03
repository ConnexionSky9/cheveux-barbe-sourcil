// Test du menu staff : onglet « LaserGame » + rôle de PNJ « LaserGame » (Chromium headless).
// NODE_PATH=$(npm root -g) node tests/lasergame_ui.cjs [dossier captures]
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
    const send = (perms, lasergame) => page.evaluate(({ perms, lasergame }) => {
        window.postMessage({ action: 'open' }, '*');
        window.postMessage({ action: 'data', data: {
            me: { id: 1, label: 'Fondateur', color: '#d9b56a', level: 100, perms, onDuty: true, duty: true }, players: [], keys: [], jobs: [], lasergame,
            config: { editor: { minLevel: 0, quickProps: [], quickPeds: [], npcPresets: [], presets: [], craftPresets: [], scenarios: [{ id: '', label: 'Aucune' }] } },
            editor: { spawns: [], props: [], peds: [{ id: 7, model: 's_m_y_ammucity_01', name: 'Accueil', x: 0, y: 0, z: 0, h: 0, npc: { lasergame: { name: 'LaserGame Vespucci' } } }],
                fields: [], stations: [], searches: [], hidden: [], zones: [], stashes: [], doors: [], doorPanels: [] },
        } }, '*');
    }, { perms, lasergame });
    const LG = { available: true, command: 'lgadmin', stats: { players: 42, matches: 17, held: 25000 },
        games: [{ uid: 'g1', mode: 'pvp', name: 'Finale', phase: 'round', map: 'pvp_medium', format: '3v3', round: 2, stake: 5000, host: 'Léna',
            players: [{ id: 3, name: 'Léna', team: 'red' }, { id: 4, name: 'Malik', team: 'blue' }] },
            { uid: 'z1', mode: 'zombie', name: 'Last Stand', phase: 'round', map: 'zombie_map', round: 12, host: 'Inès', players: [{ id: 5, name: 'Inès' }] }] };

    // Sans la permission : pas d'onglet
    await send({ editor_peds: true }, undefined);
    await page.waitForTimeout(300);
    check(!(await page.evaluate(() => TABS.find((t) => t.id === 'lasergame').show())), 'sans la case LaserGame : onglet caché');

    // Avec la permission
    await send({ editor_peds: true, lasergame_manage: true }, LG);
    await page.waitForTimeout(300);
    check(await page.evaluate(() => TABS.find((t) => t.id === 'lasergame').show()), 'avec la case LaserGame : onglet visible');
    await page.evaluate(() => { tab = 'lasergame'; render(); });
    await page.waitForTimeout(200);
    const txt = await page.textContent('#content');
    check(txt.includes('Ouvrir le panneau LaserGame') && txt.includes('Finale') && txt.includes('Last Stand'), 'parties en cours (PVP + Zombie) listées');
    check(txt.includes('42') && txt.includes('17'), 'statistiques affichées');
    await page.screenshot({ path: path.join(out, 'admin_lasergame.png'), fullPage: true });
    posts.length = 0;
    await page.click('[data-lgstop="g1"]'); await page.waitForTimeout(150);
    check(!posts.some((p) => p.body.name === 'lasergame'), 'arrêt : premier clic = demande de confirmation');
    await page.click('[data-lgstop="g1"]'); await page.waitForTimeout(150);
    const stop = posts.find((p) => p.ep === 'action' && p.body.name === 'lasergame');
    check(stop && stop.body.data.name === 'stop' && stop.body.data.data.uid === 'g1', 'arrêt confirmé : envoyé au serveur');
    posts.length = 0;
    await page.click('[data-lgopen]'); await page.waitForTimeout(150);
    check(posts.some((p) => p.ep === 'action' && p.body.data && p.body.data.name === 'open') && posts.some((p) => p.ep === 'close'), '« Ouvrir le panneau » : demande /lgadmin et ferme le menu');

    // Ressource arrêtée
    await send({ lasergame_manage: true }, { available: false, resource: 'elyzea_lasergame' });
    await page.waitForTimeout(200);
    await page.evaluate(() => { tab = 'lasergame'; render(); });
    check((await page.textContent('#content')).includes('ne répond pas'), 'ressource arrêtée : message clair');

    // Rôle de PNJ dans l'éditeur
    await send({ editor_peds: true, lasergame_manage: true }, LG);
    await page.waitForTimeout(200);
    await page.evaluate(() => { tab = 'editor'; editorSub = 'peds'; pedEdit = toPedEdit(D.editor.peds.find((x) => x.id === 7)); render(); });
    await page.waitForTimeout(200);
    const ed = await page.textContent('#content');
    check(ed.includes('🔫 LaserGame') && await page.$eval('input[data-pe="lgName"]', (i) => i.value) === 'LaserGame Vespucci', 'éditeur : rôle « LaserGame » coché avec son nom');
    await page.screenshot({ path: path.join(out, 'editeur_lasergame.png'), fullPage: true });
    const payload = await page.evaluate(() => pedEditPayload(pedEdit));
    check(payload.npc && payload.npc.lasergame && payload.npc.lasergame.name === 'LaserGame Vespucci', 'données enregistrées : rôle LaserGame');
    await browser.close();
    console.log(`\nLaserGame (menu staff) : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
