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
    const zone = { points: [{ x: 770, y: 780, z: 29 }, { x: 830, y: 780, z: 29 }, { x: 830, y: 820, z: 29 }, { x: 770, y: 820, z: 29 }], minZ: 26, maxZ: 60 };
    const spawns = { A: [{ x: 775, y: 800, z: 30, h: 270 }], B: [{ x: 825, y: 800, z: 30, h: 90 }] };
    const LG = { available: true, command: 'lgadmin', stats: { players: 42, matches: 17, held: 25000 }, teams: { A: 'ROUGE', B: 'BLEUE' },
        games: [{ uid: 'g1', mode: 'pvp', name: 'Finale', phase: 'round', map: 'Entrepôt néon', format: '3v3', round: 2, stake: 5000, host: 'Léna', score: { A: 1, B: 0 },
            players: [{ id: 3, name: 'Léna', team: 'A' }, { id: 4, name: 'Malik', team: 'B' }] }],
        arenas: [
            { id: 'arena_1', label: 'Entrepôt néon', enabled: true, valid: true, issues: [], size: 'M', area: 2400, maxPerTeam: 4, corners: 4, spawnsA: 1, spawnsB: 1, zone, spawns,
              time: 22, weather: 'CLEAR', shape: { poly: [[5, 27], [95, 27], [95, 73], [5, 73]], A: [[12, 50]], B: [[88, 50]] }, inUse: 'running' },
            { id: 'arena_2', label: 'Chantier', enabled: false, valid: false, issues: ['zone de combat non dessinée (3 coins minimum)'], size: '—', area: 0, maxPerTeam: 6,
              corners: 0, spawnsA: 0, spawnsB: 0, zone: { points: [] }, spawns: { A: [], B: [] } }] };

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
    let txt = await page.textContent('#content');
    check(txt.includes('Arènes (2)') && txt.includes('Entrepôt néon') && txt.includes('Chantier') && !/zombie/i.test(txt), 'onglet Arènes par défaut : 2 arènes, aucune trace du Zombie');
    check(txt.includes('42') && txt.includes('17'), 'statistiques affichées');
    check(await page.$('.lg-shape svg polygon') !== null && txt.includes('partie en cours'), 'silhouette de la zone et état « partie en cours »');
    await page.screenshot({ path: path.join(out, 'admin_lasergame_arenes.png'), fullPage: true });
    const lastAction = () => posts.filter((p) => p.ep === 'action' && p.body.name === 'lasergame').pop();
    const lastEditor = () => posts.filter((p) => p.ep === 'editor').pop();
    // créer une arène à sa position
    posts.length = 0;
    await page.fill('#lg-new', 'Toits de Vinewood');
    await page.click('[data-lgnew]'); await page.waitForTimeout(150);
    check(lastAction() && lastAction().body.data.name === 'arena_create' && lastAction().body.data.data.label === 'Toits de Vinewood', '« Créer ici » envoyé avec le nom');
    // dessiner la zone : outil de dessin de l'éditeur, avec l'arène et ses apparitions
    await page.click('[data-lgzone]'); await page.waitForTimeout(120);
    const ez = lastEditor();
    check(ez && ez.body.name === 'lg_zone_draw' && ez.body.data.id === 'arena_1' && ez.body.data.height === 31 && ez.body.data.spawns.A.length === 1, 'dessiner la zone : outil lg_zone_draw (hauteur actuelle conservée)');
    await page.click('[data-lgspawn="B"]'); await page.waitForTimeout(120);
    const es = lastEditor();
    check(es && es.body.name === 'lg_spawns_draw' && es.body.data.team === 'B' && es.body.data.teamName === 'BLEUE' && es.body.data.zone.points.length === 4, 'apparitions BLEUE : outil lg_spawns_draw avec la zone');
    // réglages
    await page.fill('[data-lgf="label"]', 'Entrepôt néon 2'); await page.selectOption('[data-lgf="maxPerTeam"]', '3'); await page.fill('[data-lgf="time"]', '');
    await page.selectOption('[data-lgf="weather"]', 'FOGGY'); await page.fill('[data-lgf="maxZ"]', '55');
    await page.click('[data-lgsave]'); await page.waitForTimeout(120);
    const sv = lastAction().body.data;
    check(sv.name === 'arena_update' && sv.data.label === 'Entrepôt néon 2' && sv.data.maxPerTeam === 3 && sv.data.time === '' && sv.data.weather === 'FOGGY' && sv.data.maxZ === 55 && sv.data.minZ === 26, 'réglages enregistrés (nom, joueurs, heure vidée, météo, plafond)');
    await page.click('[data-lgtoggle]'); await page.waitForTimeout(120);
    check(lastAction().body.data.name === 'arena_update' && lastAction().body.data.data.enabled === false, 'fermer l\'arène aux joueurs');
    posts.length = 0;
    await page.click('[data-lgdel]'); await page.waitForTimeout(120);
    check(!lastAction(), 'supprimer : premier clic = demande de confirmation');
    await page.click('[data-lgdel]'); await page.waitForTimeout(120);
    check(lastAction() && lastAction().body.data.name === 'arena_delete' && lastAction().body.data.data.id === 'arena_1', 'suppression confirmée : envoyée');
    // arène incomplète : ouverture et apparitions bloquées tant que la zone manque
    await page.click('[data-lgarena="arena_2"]'); await page.waitForTimeout(150);
    txt = await page.textContent('#content');
    check(txt.includes('zone de combat non dessinée') && await page.$eval('[data-lgtoggle]', (b) => b.disabled) && await page.$eval('[data-lgspawn="A"]', (b) => b.disabled), 'arène incomplète : « À faire », ouverture et apparitions bloquées');
    await page.screenshot({ path: path.join(out, 'admin_lasergame_incomplete.png'), fullPage: true });
    // parties en cours
    await page.click('[data-lgsub="games"]'); await page.waitForTimeout(150);
    txt = await page.textContent('#content');
    check(txt.includes('Finale') && txt.includes('Entrepôt néon') && txt.includes('1 - 0'), 'parties en cours listées (arène, score)');
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
