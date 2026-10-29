// Onglet « Écrans / TV » du menu admin (admin_menu/html/tv.js) : rendu, boutons → actions envoyées, aucune erreur JS
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
const fs = require('fs');
(async () => {
    const out = process.argv[2] || require('os').tmpdir();
    const admin = path.resolve(__dirname, '../../admin_menu/html');
    const b = await chromium.launch();
    let fails = 0;
    const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
    const now = 1800000000;
    const data = { available: true, ready: true, now, limits: { minW: 0.4, maxW: 60, minH: 0.25, maxH: 35 },
        screens: [{ id: 1, name: 'Écran <b>géant</b>', data: { x: 1, y: 2, z: 30, h: 90, w: 16, hgt: 9, public: true, range: 45, volume: 60, remote: { x: 1, y: 1, z: 29 } },
            state: { id: 'dQw4w9WgXcQ', offset: 30, startAt: now - 45, paused: false, volume: 70, by: 'Alice' } },
            { id: 2, name: 'Bar', data: { x: 5, y: 6, z: 30, h: 0, w: 1.6, hgt: 0.9, public: false, range: 20, volume: 50 } }],
        flats: [{ key: 'm123|1.0|2.0|3.0', model: 'prop_tv_flat_01', x: 1, y: 2, z: 3, state: { id: 'aaaaaaaaaaa', paused: true, pausedAt: 61, by: 'Bruno' } }] };
    for (const [w, h] of [[1920, 1080], [1280, 720]]) {
        const page = await b.newPage({ viewport: { width: w, height: h } });
        const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
        const harness = path.join(out, 'admin_tv_harness.html');
        fs.writeFileSync(harness, `<!doctype html><html><head><meta charset="utf-8"><link rel="stylesheet" href="file://${admin}/style.css"></head>
            <body style="background:#111"><div id="content" class="content" style="padding:20px;height:100vh;overflow:auto"></div></body></html>`);
        await page.goto('file://' + harness);
        await page.addScriptTag({ content: `
            const TABS = []; const VIEWS = {}; let isOpen = true; let tab = 'tv'; let D = null; const sent = []; const posts = [];
            const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
            const has = (p) => !!(D && D.me.perms[p]);
            const action = (name, d) => sent.push({ name, data: d });
            const post = (n) => { posts.push(n); return Promise.resolve({}); };
            const confirmBox = () => Promise.resolve(true);
            function render() { document.getElementById('content').innerHTML = VIEWS[tab](); }` });
        await page.addScriptTag({ path: path.join(admin, 'tv.js') });
        await page.evaluate((d) => { D = { me: { perms: { tv_manage: false } }, tv: d }; }, data);
        check(await page.evaluate(() => TABS[0].id === 'tv' && TABS[0].show() === false), `${w}×${h} : onglet caché sans la permission`);
        await page.evaluate(() => { D.me.perms.tv_manage = true; render(); });
        check(await page.evaluate(() => TABS[0].show() && TABS[0].count() === 2), `${w}×${h} : onglet visible, 2 écrans allumés (1 écran + 1 télé)`);
        const txt = await page.textContent('#content');
        check(txt.includes('16.00 × 9.00 m') && txt.includes('en lecture') && txt.includes('0:45') === false && txt.includes('1:15') && txt.includes('staff seulement') && txt.includes('prop_tv_flat_01') && txt.includes('en pause'),
            `${w}×${h} : écrans (taille, état, position 1:15, accès) et télés du jeu allumées`);
        check((await page.innerHTML('#content')).includes('Écran &lt;b&gt;géant&lt;/b&gt;'), `${w}×${h} : nom échappé`);
        await page.screenshot({ path: `${out}/admin_tv_${w}.png`, fullPage: true });
        const last = () => page.evaluate(() => sent[sent.length - 1].data);
        await page.click('[data-tsize="16"]');
        check(await page.inputValue('[data-tk="new:w"]') === '16' && await page.inputValue('[data-tk="new:h"]') === '9', `${w}×${h} : taille « Géant 16 × 9 » préremplie`);
        await page.fill('[data-tk="new:name"]', 'Parc');
        await page.click('[data-tnew]');
        let l = await last();
        check(l.name === 'screen_new' && l.data.name === 'Parc' && l.data.w === 16 && l.data.h === 9 && (await page.evaluate(() => posts.includes('close'))), `${w}×${h} : placer en jeu (menu fermé pour viser)`);
        await page.fill('[data-tk="url:1"]', 'https://youtu.be/dQw4w9WgXcQ');
        await page.click('[data-tplay="1"]'); l = await last();
        check(l.name === 'play' && l.data.id === 1 && l.data.url.includes('dQw4w9WgXcQ'), `${w}×${h} : lancer une vidéo sur l'écran`);
        await page.click('[data-tctl="1"][data-a="pause"]'); l = await last();
        check(l.name === 'control' && l.data.action === 'pause', `${w}×${h} : pause`);
        await page.fill('[data-tk="w:1"]', '30'); await page.fill('[data-tk="vol:1"]', '20'); await page.selectOption('[data-tk="pub:1"]', '0');
        const before = await page.evaluate(() => sent.length);
        await page.click('[data-tsave="1"]');
        const batch = await page.evaluate((n) => sent.slice(n).map((x) => x.data), before);
        check(batch[0].name === 'screen_size' && batch[0].data.w === 30 && batch[0].data.h === 9 && batch[1].name === 'screen_set' && batch[1].data.public === false && batch[1].data.volume === '20'
            && batch[2].name === 'control' && batch[2].data.action === 'volume' && batch[2].data.value === 20, `${w}×${h} : enregistrer taille, accès et volume (appliqué aussitôt)`);
        await page.click('[data-tedit="2"]'); l = await last();
        check(l.name === 'screen_edit' && l.data.id === 2, `${w}×${h} : modifier un écran en jeu`);
        await page.click('[data-tflat="m123|1.0|2.0|3.0"]'); l = await last();
        check(l.name === 'control' && l.data.key === 'm123|1.0|2.0|3.0' && l.data.action === 'stop', `${w}×${h} : éteindre une télé du jeu`);
        await page.click('[data-tall]'); await page.waitForTimeout(30); l = await last();
        check(l.name === 'stop_all', `${w}×${h} : tout éteindre`);
        await page.click('[data-tdel="2"]'); await page.waitForTimeout(30); l = await last();
        check(l.name === 'screen_delete' && l.data.id === 2, `${w}×${h} : supprimer un écran`);
        const wide = await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
        check(wide && errors.length === 0, `${w}×${h} : pas de défilement horizontal, aucune erreur JavaScript ${errors.join(' | ')}`);
        await page.close();
    }
    await b.close();
    console.log(`\nRésultat : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
