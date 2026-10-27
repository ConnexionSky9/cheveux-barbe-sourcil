// Onglet « Loisirs » du menu admin (admin_menu/html/loisirs.js) : rendu des 4 pages, boutons → actions envoyées, aucune erreur JS
// node tests/admin_ui.cjs [dossier captures]
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
    const out = process.argv[2] || require('os').tmpdir();
    const admin = path.resolve(__dirname, '../../admin_menu/html');
    const b = await chromium.launch();
    let fails = 0;
    const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
    // Données au format de exports.elyzea_loisirs:AdminData() (tables Lua vides → {} en JSON)
    const data = { available: true, ready: true, games: { bowling: { label: 'Bowling' } },
        installations: [
            { id: 1, kind: 'bowling', name: 'Piste <b>1</b>', data: { x: 100.1, y: 200.2, z: 30, h: 90 }, session: { id: 7, name: 'Soirée', state: 'IN_PROGRESS', players: 3 } },
            { id: 2, kind: 'billiards', name: 'Table Yellow Jack', data: { x: 1, y: 2, z: 3, h: 0, model: 'prop_pooltable_02', spawn: false, calib: { length: 2.3 } } },
            { id: 3, kind: 'golf', name: 'Golf LS', data: { holes: [
                { tee: { x: 0, y: 0, z: 50, h: 0 }, flag: { x: 0, y: 160, z: 50 }, par: 3, greenR: 14, fairwayW: 40, hazards: [{ type: 'water', x: 3, y: 80, r: 12 }] },
                { tee: { x: 0, y: 200, z: 50, h: 0 }, par: 4, greenR: 14, fairwayW: 40, hazards: {} }] } },
            { id: 4, kind: 'pole', name: 'Scène <i>VIP</i>', data: { x: 5, y: 6, z: 30, h: 90, spawn: true, oz: 0.05 }, dancer: { sid: 2, name: 'Chloé' } },
        ],
        sessions: [{ id: 7, game: 'bowling', name: 'Soirée', state: 'IN_PROGRESS', inst: 1, players: 3, host: 'Alice' }] };
    for (const [w, h] of [[1920, 1080], [1280, 720]]) {
        const page = await b.newPage({ viewport: { width: w, height: h } });
        const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
        const harness = path.join(out, 'admin_loisirs_harness.html');
        require('fs').writeFileSync(harness, `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${admin}/style.css"></head>
            <body style="background:#111"><div id="content" class="content" style="padding:20px;height:100vh;overflow:auto"></div></body></html>`);
        await page.goto('file://' + harness);
        await page.addScriptTag({ content: `
            const TABS = []; const VIEWS = {}; let isOpen = true; let tab = 'loisirs'; let D = null; const sent = []; let confirms = 0;
            const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
            const has = (p) => !!(D && D.me.perms[p]);
            const action = (name, d) => sent.push({ name, data: d });
            const post = () => Promise.resolve({});
            const confirmBox = () => { confirms++; return Promise.resolve(true); };
            function render() { document.getElementById('content').innerHTML = VIEWS[tab](); }` });
        await page.addScriptTag({ path: path.join(admin, 'loisirs.js') });
        const setData = (perm) => page.evaluate(([d, p]) => { D = { me: { perms: { loisirs_manage: p } }, loisirs: d }; }, [data, perm]);
        await setData(false);
        check(await page.evaluate(() => TABS[0].id === 'loisirs' && TABS[0].show() === false), `${w}×${h} : onglet caché sans la permission`);
        await setData(true);
        check(await page.evaluate(() => TABS[0].show() && TABS[0].count() === 1), `${w}×${h} : onglet visible avec la permission, compteur 1 partie en cours`);
        await page.evaluate(() => render());
        const txt = () => page.textContent('#content');
        check((await txt()).includes('Soirée') && (await txt()).includes('Alice'), `${w}×${h} : page Parties en cours`);
        await page.screenshot({ path: `${out}/admin_loisirs_parties_${w}.png` });
        await page.click('[data-lcancel="7"]'); await page.waitForTimeout(50);
        let last = await page.evaluate(() => sent[sent.length - 1]);
        check(last && last.name === 'loisirs' && last.data.name === 'cancel_session' && last.data.data.session === 7, `${w}×${h} : annuler une partie (confirmation + action)`);
        // bowling
        await page.click('[data-lsub="bowling"]');
        check((await page.innerHTML('#content')).includes('Piste &lt;b&gt;1&lt;/b&gt;'), `${w}×${h} : bowling, nom échappé`);
        await page.fill('[data-lk="new:bowling"]', 'Piste 2');
        await page.evaluate(() => render());   // rafraîchissement automatique : la saisie reste
        check(await page.inputValue('[data-lk="new:bowling"]') === 'Piste 2', `${w}×${h} : la saisie survit au rafraîchissement`);
        await page.screenshot({ path: `${out}/admin_loisirs_bowling_${w}.png` });
        await page.click('[data-ladd="bowling"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'add_bowling' && last.data.data.name === 'Piste 2', `${w}×${h} : poser une piste ici`);
        await page.click('[data-ladd="bowling_align"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'add_bowling' && last.data.data.align === true, `${w}×${h} : aligner la piste sur les quilles du décor`);
        // billard
        await page.click('[data-lsub="billiards"]');
        check(await page.inputValue('[data-lk="cl:2"]') === '2.3' && await page.inputValue('[data-lk="cw:2"]') === '', `${w}×${h} : billard, calibrage affiché`);
        await page.fill('[data-lk="cw:2"]', '1.27');
        await page.click('[data-lcalib="2"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'billiards_calib' && last.data.data.width === '1.27' && last.data.data.id === 2, `${w}×${h} : calibrage envoyé`);
        await page.selectOption('[data-lk="new:model"]', 'prop_pooltable_3b');
        await page.click('[data-ladd="billiards"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'add_billiards' && last.data.data.model === 'prop_pooltable_3b' && !last.data.data.existing, `${w}×${h} : table neuve avec le modèle choisi`);
        await page.click('[data-ladd="billiards_existing"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.data.existing === true, `${w}×${h} : reprendre la table du jeu la plus proche`);
        await page.screenshot({ path: `${out}/admin_loisirs_billard_${w}.png` });
        // golf
        await page.click('[data-lsub="golf"]');
        const g = await txt();
        check(g.includes('Trou 1') && g.includes('160 m') && g.includes('drapeau à poser') && g.includes('Par total : 7'), `${w}×${h} : golf, trous, distance, drapeau manquant, par total`);
        await page.screenshot({ path: `${out}/admin_loisirs_golf_${w}.png`, fullPage: true });
        await page.click('[data-lgolf="hole_tee"][data-hole="new"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'hole_tee' && last.data.data.id === 3 && last.data.data.hole === undefined, `${w}×${h} : nouveau trou`);
        await page.click('[data-lgolf="hole_flag"][data-hole="2"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'hole_flag' && last.data.data.hole === 2, `${w}×${h} : drapeau du trou 2`);
        await page.fill('[data-lk="par:3:1"]', '4');
        await page.click('[data-lgolf="hole_set"][data-hole="1"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'hole_set' && last.data.data.par === '4' && last.data.data.hole === 1, `${w}×${h} : réglages du trou (par 4)`);
        await page.selectOption('[data-lk="hzt:3:2"]', 'ob');
        await page.fill('[data-lk="hzr:3:2"]', '30');
        await page.click('[data-lhz="2"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'hole_hazard' && last.data.data.type === 'ob' && last.data.data.radius === 30 && last.data.data.hole === 2, `${w}×${h} : zone hors limites 30 m sur le trou 2`);
        await page.click('[data-lhzdel="1"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'hazard_del' && last.data.data.index === 1, `${w}×${h} : supprimer une zone`);
        // pole dance
        await page.click('[data-lsub="pole"]');
        const pt = await txt();
        check(pt.includes('Chloé danse') && (await page.innerHTML('#content')).includes('Scène &lt;i&gt;VIP&lt;/i&gt;') && await page.inputValue('[data-lk="poz:4"]') === '0.05', `${w}×${h} : page Pole dance (danseuse, nom échappé, calage)`);
        await page.screenshot({ path: `${out}/admin_loisirs_pole_${w}.png`, fullPage: true });
        await page.click('[data-ladd="pole"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'add_pole' && !last.data.data.existing, `${w}×${h} : poser une barre à mes pieds`);
        await page.click('[data-ladd="pole_existing"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'add_pole' && last.data.data.existing === true, `${w}×${h} : reprendre une barre du décor`);
        await page.fill('[data-lk="poy:4"]', '-0.1');
        await page.click('[data-lpole="4"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'pole_calib' && last.data.data.oy === '-0.1' && last.data.data.id === 4, `${w}×${h} : calage de la barre envoyé`);
        await page.click('[data-lpolehere="4"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.data.here === true, `${w}×${h} : tourner la danse vers mon regard`);
        await page.click('[data-lpolelive="4"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'pole_calib_live' && last.data.data.id === 4, `${w}×${h} : caler la barre en jeu`);
        await page.click('[data-lpolestop="4"]'); await page.waitForTimeout(50);
        last = await page.evaluate(() => sent[sent.length - 1]);
        check(last.data.name === 'pole_stop', `${w}×${h} : arrêter la danse`);
        // ressource arrêtée
        await page.evaluate(() => { D.loisirs = { available: false, resource: 'elyzea_loisirs' }; render(); });
        check((await txt()).includes('ne répond pas'), `${w}×${h} : ressource arrêtée, avertissement`);
        const wide = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
        check(wide, `${w}×${h} : pas de défilement horizontal`);
        check(errors.length === 0, `${w}×${h} : aucune erreur JavaScript ${errors.join(' | ')}`);
        await page.close();
    }
    await b.close();
    console.log(`\nRésultat : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
