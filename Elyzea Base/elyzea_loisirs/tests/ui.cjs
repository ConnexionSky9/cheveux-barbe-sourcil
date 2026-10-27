// Interface : lobby, tableaux de score des 3 jeux, jauge, classement — 2 résolutions, aucune erreur JS
// node tests/ui.cjs [dossier captures]
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
    const out = process.argv[2] || require('os').tmpdir();
    const b = await chromium.launch();
    let fails = 0;
    const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
    const players = [{ id: 1, name: 'Alice <script>', status: 'active', host: true }, { id: 2, name: 'Bruno', status: 'active' }];
    for (const [w, h] of [[1920, 1080], [1280, 720]]) {
        const page = await b.newPage({ viewport: { width: w, height: h } });
        const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
        await page.route('https://elyzea_loisirs/**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' }));
        await page.goto('file://' + path.resolve(__dirname, '../html/index.html'));
        const send = (m) => page.evaluate((x) => window.postMessage(x, '*'), m);
        await send({ action: 'lobby', open: true, me: 1, inst: { id: 1, kind: 'bowling', name: 'Piste 1' }, game: { label: 'Bowling', minPlayers: 1, maxPlayers: 6, price: 0 }, sessions: [], rules: ['10 frames'] });
        await page.waitForTimeout(150);
        check(await page.isVisible('#fName'), `${w}×${h} : lobby, formulaire de création`);
        await page.screenshot({ path: `${out}/loisirs_lobby_${w}.png` });
        const sess = { id: 3, game: 'bowling', inst: 1, name: 'Duel', state: 'WAITING', host: 1, max: 2, players, locked: true };
        await send({ action: 'lobbySession', session: sess });
        await page.waitForTimeout(100);
        check(await page.isVisible('[data-act="start"]') && (await page.textContent('#lobbyBody')).includes('Alice <script>'), `${w}×${h} : lobby avec joueurs, nom affiché sans être interprété`);
        await page.click('[data-act="close"]');
        // bowling en cours
        const frames = [[10], [7, 3], [9, 0], [10], [10], [8, 1]];
        await send({ action: 'session', me: 1, mine: true, session: { ...sess, state: 'IN_PROGRESS', turn: 1, turnLeft: 45,
            data: { standing: [1, 2, 4, 7], players: [{ id: 1, frames, cum: { 1: 20, 2: 39, 3: 48, 4: 76, 5: 95 }, total: 104 }, { id: 2, frames: [[5, 4]], cum: { 1: 9 }, total: 9 }] } } });
        await send({ action: 'controls', show: true, game: 'bowling', power: 0.62, charging: true, info: 'Position +0.10 m', keys: ['A / D : position', 'ESPACE'] });
        await send({ action: 'toast', text: 'STRIKE !', kind: 'win' });
        await page.waitForTimeout(150);
        const hud = await page.textContent('#hud');
        check(hud.includes('X') && hud.includes('/') && hud.includes('104'), `${w}×${h} : tableau de bowling (X, /, total 104)`);
        await page.screenshot({ path: `${out}/loisirs_bowling_${w}.png` });
        // billard
        await send({ action: 'session', me: 1, mine: true, session: { id: 3, game: 'billiards', inst: 2, name: 'Billard', state: 'IN_PROGRESS', host: 1, max: 2, players, turn: 2,
            data: { seat: [1, 2], groups: ['solids', 'stripes'], pocketed: [[1, 3], [9]], remaining: [5, 6], ballInHand: 'anywhere', lastFoul: 'blanche empochée' } } });
        await page.waitForTimeout(100);
        check((await page.textContent('#hud')).includes('Pleines'), `${w}×${h} : tableau du billard (groupes, boules empochées)`);
        await page.screenshot({ path: `${out}/loisirs_billard_${w}.png` });
        // golf
        await send({ action: 'session', me: 1, mine: true, session: { id: 3, game: 'golf', inst: 3, name: 'Golf', state: 'IN_PROGRESS', host: 1, max: 2, players, turn: 1,
            data: { hole: 2, holes: 9, pars: [4, 3], maxStrokes: 9, players: [{ id: 1, strokes: { 1: 4, 2: 1 }, total: 5, toPar: 1, dist: 87.3, lie: 'fairway' }, { id: 2, strokes: { 1: 5, 2: 2 }, total: 7, toPar: 3, dist: 12, lie: 'green' }] } } });
        await send({ action: 'controls', show: true, game: 'golf', power: 0.95, charging: true, over: true, info: 'Fer 7 · 87 m du trou', keys: ['A / D : direction'] });
        await page.waitForTimeout(100);
        check((await page.textContent('#hud')).includes('Trou 2 / 9'), `${w}×${h} : tableau du golf (trou, distance, total, par)`);
        await page.screenshot({ path: `${out}/loisirs_golf_${w}.png` });
        // fin
        await send({ action: 'session', me: 1, mine: true, session: { id: 3, game: 'golf', inst: 3, name: 'Golf', state: 'FINISHED', players, results: { holes: 9, parTotal: 36,
            ranking: [{ name: 'Alice', total: 38, toPar: 2, penalties: 1 }, { name: 'Bruno', total: 41, toPar: 5, penalties: 0, left: true }] } } });
        await page.waitForTimeout(150);
        check(await page.isVisible('#results') && (await page.textContent('#results')).includes('38'), `${w}×${h} : classement final`);
        await page.screenshot({ path: `${out}/loisirs_fin_${w}.png` });
        // aucun débordement horizontal
        const over = await page.evaluate(() => [...document.querySelectorAll('#hud, #controls, #results')].some((e) => e.getBoundingClientRect().right > window.innerWidth + 1));
        check(!over, `${w}×${h} : rien ne dépasse de l'écran`);
        // pole dance : panneau de choix de la danse
        const pole = { action: 'pole', show: true, name: 'Scène <b>VIP</b>', cursor: true, cam: true, mode: 'pole', current: 2, auto: false,
            dances: [{ i: 1, label: 'Routine 1', icon: '🌀', desc: 'Tours autour de la barre' }, { i: 2, label: 'Routine 2', icon: '⬆️', desc: 'Montées et descentes' }, { i: 3, label: 'Routine 3', icon: '✨', desc: 'Figures' }],
            private: { label: 'Danse sensuelle', icon: '💋', desc: 'Debout, devant la barre' }, calib: { ox: 0.02, oy: -0.05, oz: 0.1, h: 90 } };
        await page.evaluate(() => { window.__posts = []; const f = window.fetch; window.fetch = (u, o) => { window.__posts.push([u, o && o.body]); return f(u, o); }; });
        await send(pole);
        await page.waitForTimeout(150);
        const pt = await page.textContent('#pole');
        check(await page.isVisible('#pole') && pt.includes('Routine 3') && pt.includes('Danse sensuelle') && pt.includes('RÉGLAGE') && (await page.innerHTML('#poleName')) === 'Scène &lt;b&gt;VIP&lt;/b&gt;', `${w}×${h} : panneau pole dance (danses, réglage staff, nom échappé)`);
        check(await page.getAttribute('.pd.on', 'data-i') === '2', `${w}×${h} : danse en cours surlignée`);
        await page.screenshot({ path: `${out}/loisirs_pole_${w}.png` });
        await page.click('[data-pd="dance"][data-i="3"]');
        await page.click('[data-pd="nudge"][data-axis="oz"][data-d="0.01"]');
        await page.keyboard.press('5');
        await page.click('[data-pd="stop"]');
        await page.waitForTimeout(100);
        const posts = (await page.evaluate(() => window.__posts)).filter(([u]) => u.endsWith('/pole')).map(([, b]) => JSON.parse(b));
        check(posts.length === 4 && posts[0].cmd === 'dance' && posts[0].i === 3 && posts[1].axis === 'oz' && posts[1].d === 0.01 && posts[2].cmd === 'auto' && posts[3].cmd === 'stop',
            `${w}×${h} : clics et touches envoyés au jeu (danse 3, réglage, auto, descendre)`);
        await send({ ...pole, cursor: false, calib: null });
        await page.waitForTimeout(80);
        check(await page.evaluate(() => document.querySelector('#pole').classList.contains('dim')) && !(await page.textContent('#pole')).includes('RÉGLAGE'), `${w}×${h} : curseur caché → panneau estompé, sans bloc staff`);
        await send({ action: 'pole', show: false });
        await page.waitForTimeout(50);
        check(!(await page.isVisible('#pole')), `${w}×${h} : panneau fermé en descendant de la barre`);
        check(errors.length === 0, `${w}×${h} : aucune erreur JavaScript (${errors.join(' | ')})`);
        await page.close();
    }
    await b.close();
    console.log(`\n${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
