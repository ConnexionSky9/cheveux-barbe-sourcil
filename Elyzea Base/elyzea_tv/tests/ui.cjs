// Interfaces d'elyzea_tv : page vidéo (lecteur YouTube imité), télécommande — aucune erreur JS
// node tests/ui.cjs [dossier captures]
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
const STUB = `
window.__yt = [];
window.YT = { Player: class {
    constructor(el, o) { this.o = o; this.t = o.playerVars.start || 0; this.s = -1; this.v = 100; this.muted = false; __yt.push(['new', o.videoId, o.playerVars.start, o.playerVars.origin]);
        window.__player = this; setTimeout(() => { this.s = 1; o.events.onReady({ target: this }); }, 30); }
    setVolume(v) { this.v = v; __yt.push(['vol', v]); } mute() { this.muted = true; __yt.push(['mute']); } unMute() { this.muted = false; }
    seekTo(t) { this.t = t; __yt.push(['seek', t]); } pauseVideo() { this.s = 2; __yt.push(['pause']); } playVideo() { this.s = 1; __yt.push(['play']); }
    getCurrentTime() { return this.t; } getPlayerState() { return this.s; } stopVideo() { this.s = 0; __yt.push(['stop']); }
    loadVideoById(o) { this.t = o.startSeconds; __yt.push(['loadid', o.videoId, o.startSeconds]); }
} };
setTimeout(() => window.onYouTubeIframeAPIReady(), 10);`;
(async () => {
    const out = process.argv[2] || require('os').tmpdir();
    const b = await chromium.launch();
    let fails = 0;
    const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
    // ---------------- page vidéo
    const p = await b.newPage({ viewport: { width: 1280, height: 720 } });
    const errs = []; p.on('pageerror', (e) => errs.push(String(e)));
    await p.route('https://www.youtube.com/iframe_api', (r) => r.fulfill({ status: 200, contentType: 'application/javascript', body: STUB }));
    await p.goto('file://' + path.resolve(__dirname, '../html/player.html'));
    const send = (m) => p.evaluate((x) => window.postMessage(JSON.stringify(x), '*'), m);
    const yt = () => p.evaluate(() => window.__yt);
    await p.waitForTimeout(100);
    check((await p.textContent('#msg')).includes('En attente'), 'page vidéo : écran d\'attente');
    await send({ type: 'volume', v: 0.4 });
    await send({ type: 'load', id: 'dQw4w9WgXcQ', at: 95.7, paused: false });
    await p.waitForTimeout(200);
    let log = await yt();
    check(log[0][0] === 'new' && log[0][1] === 'dQw4w9WgXcQ' && log[0][2] === 95, 'lecteur YouTube créé avec la vidéo et la position (95 s)');
    check(log.some((x) => x[0] === 'vol' && x[1] === 40), 'volume appliqué (40 %)');
    check(await p.isHidden('#msg'), 'message d\'attente caché pendant la lecture');
    await p.evaluate(() => { __player.t = 120; });
    await send({ type: 'sync', at: 100, paused: false });
    await p.waitForTimeout(50);
    log = await yt();
    check(log.some((x) => x[0] === 'seek' && x[1] === 100), 'resynchronisation : la page se recale quand elle dérive (> 2,5 s)');
    const n = (await yt()).length;
    await p.evaluate(() => { __player.t = 101; });
    await send({ type: 'sync', at: 100, paused: false });
    await p.waitForTimeout(50);
    check(!(await yt()).slice(n).some((x) => x[0] === 'seek'), 'petit écart (< 2,5 s) : pas de saut à l\'image');
    await send({ type: 'sync', at: 101, paused: true });
    await p.waitForTimeout(50);
    check((await yt()).some((x) => x[0] === 'pause'), 'pause transmise');
    await send({ type: 'volume', v: 0 });
    await p.waitForTimeout(50);
    check((await yt()).some((x) => x[0] === 'mute'), 'trop loin : son coupé');
    await send({ type: 'load', id: 'aaaaaaaaaaa', at: 0, paused: false });
    await p.waitForTimeout(50);
    check((await yt()).some((x) => x[0] === 'loadid' && x[1] === 'aaaaaaaaaaa'), 'changement de vidéo sans recréer le lecteur');
    await send({ type: 'load', id: 'x"><script>', at: 0 });
    await p.waitForTimeout(50);
    check(!(await yt()).some((x) => x[1] === 'x"><script>'), 'identifiant invalide ignoré');
    await p.evaluate(() => __player.o.events.onError({ data: 150 }));
    await p.waitForTimeout(50);
    check((await p.textContent('#msg')).includes('interdit sa diffusion'), 'vidéo non intégrable : message clair sur l\'écran');
    await p.screenshot({ path: `${out}/tv_player_erreur.png` });
    check(errs.length === 0, `page vidéo : aucune erreur JavaScript ${errs.join(' | ')}`);
    // ---------------- télécommande
    for (const [w, h] of [[1920, 1080], [1280, 720]]) {
        const q = await b.newPage({ viewport: { width: w, height: h } });
        const e2 = []; q.on('pageerror', (e) => e2.push(String(e)));
        const posts = [];
        await q.route('https://elyzea_tv/**', (r) => { posts.push([r.request().url().split('/').pop(), JSON.parse(r.request().postData() || '{}')]); r.fulfill({ status: 200, contentType: 'application/json', body: '{"ok":true}' }); });
        await q.goto('file://' + path.resolve(__dirname, '../html/index.html'));
        const sendQ = (m) => q.evaluate((x) => window.postMessage(x, '*'), m);
        await sendQ({ action: 'remote', open: true, name: 'Télé <b>salon</b>', state: null });
        await q.waitForTimeout(100);
        check(await q.isVisible('#remote') && (await q.innerHTML('#rName')) === 'Télé &lt;b&gt;salon&lt;/b&gt;' && await q.isDisabled('[data-r="stop"]'), `${w}×${h} : télécommande ouverte, écran éteint (boutons inactifs), nom échappé`);
        await q.fill('#rUrl', 'https://evil.com/watch?v=dQw4w9WgXcQ');
        await q.click('[data-r="play"]');
        await q.waitForTimeout(50);
        check(await q.isVisible('#rErr') && posts.length === 0, `${w}×${h} : mauvais lien signalé tout de suite, rien envoyé`);
        await q.fill('#rUrl', 'https://youtu.be/dQw4w9WgXcQ?t=30');
        await q.press('#rUrl', 'Enter');
        await q.waitForTimeout(80);
        check(posts.length === 1 && posts[0][0] === 'remote' && posts[0][1].cmd === 'play' && posts[0][1].url.includes('dQw4w9WgXcQ'), `${w}×${h} : Entrée lance la vidéo`);
        await sendQ({ action: 'remote', open: true, name: 'Télé salon', state: { id: 'dQw4w9WgXcQ', paused: false, volume: 60, by: 'Alice', position: 75 } });
        await q.waitForTimeout(80);
        check((await q.textContent('#rNow')).includes('En lecture') && (await q.textContent('#rNow')).includes('1:15') && (await q.inputValue('#rVol')) === '60', `${w}×${h} : état affiché (lecture, 1:15, volume 60)`);
        await q.screenshot({ path: `${out}/tv_remote_${w}.png` });
        await q.click('#rPause'); await q.click('[data-r="seek"][data-by="10"]');
        await q.fill('#rVol', '30'); await q.dispatchEvent('#rVol', 'input'); await q.waitForTimeout(350);
        await q.click('[data-r="stop"]'); await q.keyboard.press('Escape'); await q.waitForTimeout(80);
        const cmds = posts.slice(1).map((x) => x[1].cmd + (x[1].by ? x[1].by : '') + (x[1].v !== undefined ? x[1].v : ''));
        check(JSON.stringify(cmds) === JSON.stringify(['pause', 'seek10', 'volume30', 'stop', 'close']), `${w}×${h} : pause, +10 s, volume 30, éteindre, Échap (${cmds.join(', ')})`);
        await sendQ({ action: 'editor', open: true, name: 'Écran géant', w: 16, h: 9, heading: 180 });
        await q.waitForTimeout(50);
        check((await q.textContent('#editor')).includes('16.00 × 9.00 m'), `${w}×${h} : bandeau de placement (taille, aide)`);
        const wide = await q.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1);
        check(wide && e2.length === 0, `${w}×${h} : pas de défilement horizontal, aucune erreur JavaScript`);
        await q.screenshot({ path: `${out}/tv_editor_${w}.png` });
        await q.close();
    }
    await b.close();
    console.log(`\nRésultat : ${fails} échec(s)`);
    process.exit(fails ? 1 : 0);
})();
