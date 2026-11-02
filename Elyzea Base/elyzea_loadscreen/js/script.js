/* =====================================================================
   ELYZEA FA — LOADING SCREEN v3 « NÉON » · MOTEUR
   1. Intro : la vidéo du logo (4K 120 i/s ou 1080p 60 i/s selon l'écran)
      avec effets synchronisés (éclair, étincelles, onde de choc, reflet).
   2. Le logo monte, l'interface arrive : photos teintées, sol néon,
      particules, progression RÉELLE du chargement FiveM, astuces, musique.
   Tout est dessiné à la résolution native de l'écran et à sa fréquence.
   ===================================================================== */
(() => {
    'use strict';
    const $ = (id) => document.getElementById(id);
    const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
    const rand = (a, b) => a + Math.random() * (b - a);
    const G = (name, def) => (typeof window[name] !== 'undefined' ? window[name] : def);
    // Les const de config.js ne sont pas sur window : lecture directe protégée
    const read = (fn, def) => { try { return fn(); } catch (e) { return def; } };
    const cfg = {
        server: Object.assign({ name: 'ELYZEA FA', tagline: 'Roleplay', slogan: '' }, read(() => server, {})),
        video: Object.assign({ quality: 'auto', src4k: '', src1080: '', poster: '', introScale: 1, headerScale: .52, headerY: '-25vh', skippable: true,
            beats: { reveal: .9, sparks: 1.95, city: 3, title: 4.05, settle: 7.2 } }, read(() => video, {})),
        slides: read(() => slides, []),
        slideshow: Object.assign({ interval: 8000, transition: 2200, shuffle: false }, read(() => slideshow, {})),
        music: Object.assign({ playlist: [], volume: .35, autoplay: true, shuffle: false, fadeIn: 2500 }, read(() => music, {})),
        loading: Object.assign({ smoothing: .06, demoDuration: 26000, stages: {} }, read(() => loading, {})),
        tips: Object.assign({ interval: 7000, list: [] }, read(() => tips, {})),
        links: read(() => links, []),
        effects: Object.assign({ reduced: 'auto', particles: 140, grid: true, lightBeams: true, shootingLines: true, grain: .05, parallax: true, fadeOutDuration: 1200 },
            read(() => effects, {})),
    };
    void G;
    const reduced = cfg.effects.reduced === true || (cfg.effects.reduced === 'auto' && window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);
    const body = document.body;
    if (reduced) body.classList.add('reduced');
    document.documentElement.style.setProperty('--grain', String(cfg.effects.grain || 0));
    document.documentElement.style.setProperty('--headerY', cfg.video.headerY);
    document.documentElement.style.setProperty('--headerScale', String(cfg.video.headerScale));
    document.documentElement.style.setProperty('--introScale', String(cfg.video.introScale));
    if (!cfg.effects.lightBeams) $('stage').previousElementSibling && document.querySelector('.beams').remove();

    /* =================================================================
       Boucle d'animation unique (suit la fréquence de l'écran)
       ================================================================= */
    const loops = new Set();
    let last = performance.now();
    function tick(now) {
        const dt = Math.min(50, now - last) / 1000;
        last = now;
        loops.forEach((fn) => { try { fn(dt, now); } catch (e) { loops.delete(fn); } });
        requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);

    /* =================================================================
       1. CANVAS : particules, étincelles, traits lumineux
       ================================================================= */
    const FX = (() => {
        const cv = $('fx'), ctx = cv.getContext('2d');
        let W = 0, H = 0, D = 1;
        const motes = [], sparks = [], streaks = [];
        let target = reduced ? Math.min(30, cfg.effects.particles) : cfg.effects.particles;
        const mouse = { x: 0, y: 0, sx: 0, sy: 0 };
        // Sprite lumineux pré-dessiné (rapide à afficher, même par centaines)
        const sprite = (color, size) => {
            const c = document.createElement('canvas'); c.width = c.height = size;
            const g = c.getContext('2d'), r = size / 2, grd = g.createRadialGradient(r, r, 0, r, r, r);
            grd.addColorStop(0, 'rgba(255,255,255,1)'); grd.addColorStop(.18, color); grd.addColorStop(1, 'rgba(0,0,0,0)');
            g.fillStyle = grd; g.fillRect(0, 0, size, size); return c;
        };
        const SPR = [sprite('rgba(192,132,252,.85)', 64), sprite('rgba(232,121,249,.85)', 64), sprite('rgba(103,232,249,.7)', 64)];
        function resize() {
            D = Math.min(window.devicePixelRatio || 1, 2);
            W = Math.round(innerWidth * D); H = Math.round(innerHeight * D);
            cv.width = W; cv.height = H;
        }
        function mote(fresh) {
            const s = H / 1080;
            return { x: rand(0, W), y: fresh ? rand(0, H) : H + rand(0, 60 * s), r: rand(1.5, 5.5) * s, vy: rand(-26, -8) * s, vx: rand(-6, 6) * s,
                a: rand(.25, .9), tw: rand(1, 3.5), ph: rand(0, 6.28), z: rand(.3, 1), spr: Math.random() < .7 ? 0 : (Math.random() < .7 ? 1 : 2) };
        }
        function burst(x, y, n, opts = {}) {
            if (reduced) n = Math.round(n / 4);
            const s = H / 1080, sp = opts.speed || 520;
            for (let i = 0; i < n; i++) {
                const ang = (opts.angle ?? 0) + rand(-(opts.spread ?? Math.PI), opts.spread ?? Math.PI), v = rand(.25, 1) * sp * s;
                sparks.push({ x: x * D, y: y * D, vx: Math.cos(ang) * v, vy: Math.sin(ang) * v, life: rand(.7, 1.8), t: 0, r: rand(1.2, 3.6) * s,
                    spr: Math.random() < .6 ? 0 : 1, g: (opts.gravity ?? 260) * s });
            }
        }
        function streak() {
            if (!cfg.effects.shootingLines || reduced) return;
            const s = H / 1080, fromLeft = Math.random() < .5;
            streaks.push({ x: fromLeft ? -200 * s : W + 200 * s, y: rand(H * .08, H * .55), vx: (fromLeft ? 1 : -1) * rand(1400, 2200) * s, vy: rand(80, 260) * s, len: rand(160, 340) * s, t: 0 });
        }
        let streakIn = 3;
        // Qualité automatique : si l'ordinateur peine (< 45 i/s), moins de particules
        let fpsAcc = 0, fpsN = 0;
        function frame(dt, now) {
            fpsAcc += dt; fpsN++;
            if (fpsAcc > 3) { const fps = fpsN / fpsAcc; if (fps < 45 && target > 40) target = Math.round(target * .6); fpsAcc = 0; fpsN = 0; }
            while (motes.length < target) motes.push(mote(motes.length < target * .9 && now < 4000 ? true : false));
            if (motes.length > target) motes.length = target;
            mouse.sx += (mouse.x - mouse.sx) * .05; mouse.sy += (mouse.y - mouse.sy) * .05;
            ctx.clearRect(0, 0, W, H);
            ctx.globalCompositeOperation = 'lighter';
            const t = now / 1000;
            for (const m of motes) {
                m.x += (m.vx + Math.sin(t * .6 + m.ph) * 8) * dt; m.y += m.vy * dt;
                if (m.y < -40 || m.x < -40 || m.x > W + 40) Object.assign(m, mote(false));
                const a = m.a * (.55 + .45 * Math.sin(t * m.tw + m.ph)), sz = m.r * 6 * m.z;
                ctx.globalAlpha = clamp(a * m.z, 0, 1);
                ctx.drawImage(SPR[m.spr], m.x + mouse.sx * 30 * m.z * D - sz / 2, m.y + mouse.sy * 20 * m.z * D - sz / 2, sz, sz);
            }
            for (let i = sparks.length - 1; i >= 0; i--) {
                const p = sparks[i];
                p.t += dt;
                if (p.t >= p.life) { sparks.splice(i, 1); continue; }
                const drag = Math.pow(.18, dt);
                p.vx *= drag; p.vy = p.vy * drag + p.g * dt;
                const px = p.x, py = p.y;
                p.x += p.vx * dt; p.y += p.vy * dt;
                const k = 1 - p.t / p.life;
                ctx.globalAlpha = k;
                ctx.strokeStyle = p.spr ? 'rgba(244,114,182,.9)' : 'rgba(216,180,254,.95)';
                ctx.lineWidth = p.r * .6 * k + .5;
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(p.x, p.y); ctx.stroke();
                const sz = p.r * 7 * k;
                ctx.drawImage(SPR[p.spr], p.x - sz / 2, p.y - sz / 2, sz, sz);
            }
            streakIn -= dt;
            if (streakIn <= 0) { streak(); streakIn = rand(2.5, 6); }
            for (let i = streaks.length - 1; i >= 0; i--) {
                const s = streaks[i];
                s.t += dt; s.x += s.vx * dt; s.y += s.vy * dt;
                if (s.t > 2.2) { streaks.splice(i, 1); continue; }
                const nx = s.vx / Math.hypot(s.vx, s.vy), ny = s.vy / Math.hypot(s.vx, s.vy);
                const g = ctx.createLinearGradient(s.x, s.y, s.x - nx * s.len, s.y - ny * s.len);
                g.addColorStop(0, 'rgba(255,255,255,.95)'); g.addColorStop(.25, 'rgba(192,132,252,.6)'); g.addColorStop(1, 'rgba(192,132,252,0)');
                ctx.globalAlpha = 1; ctx.strokeStyle = g; ctx.lineWidth = 2 * (H / 1080);
                ctx.beginPath(); ctx.moveTo(s.x, s.y); ctx.lineTo(s.x - nx * s.len, s.y - ny * s.len); ctx.stroke();
            }
            ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
        }
        resize();
        addEventListener('resize', resize);
        addEventListener('mousemove', (e) => { mouse.x = e.clientX / innerWidth - .5; mouse.y = e.clientY / innerHeight - .5; });
        if (target > 0 || cfg.effects.shootingLines) loops.add(frame);
        return { burst, mouse };
    })();

    /* =================================================================
       2. SOL NÉON EN PERSPECTIVE (rappel de la ville du logo)
       ================================================================= */
    (() => {
        if (!cfg.effects.grid) { $('grid').remove(); return; }
        const cv = $('grid'), ctx = cv.getContext('2d');
        let W, H, D;
        function resize() { D = Math.min(window.devicePixelRatio || 1, 2); W = cv.width = Math.round(innerWidth * D); H = cv.height = Math.round(innerHeight * D); }
        resize(); addEventListener('resize', resize);
        let off = 0;
        loops.add((dt) => {
            if (!body.classList.contains('phase-ui') && !body.classList.contains('grid-on')) return;
            off = (off + dt * (reduced ? .05 : .22)) % 1;
            ctx.clearRect(0, 0, W, H);
            const hz = H * .7, bottom = H, cx = W / 2 + FX.mouse.sx * -40 * D;
            // Lueur d'horizon
            const glow = ctx.createLinearGradient(0, hz - H * .12, 0, hz + H * .05);
            glow.addColorStop(0, 'rgba(168,85,247,0)'); glow.addColorStop(.7, 'rgba(168,85,247,.22)'); glow.addColorStop(1, 'rgba(232,121,249,0)');
            ctx.fillStyle = glow; ctx.fillRect(0, hz - H * .12, W, H * .17);
            ctx.lineWidth = Math.max(1, 1.2 * D);
            // Lignes horizontales qui avancent
            for (let i = 0; i < 18; i++) {
                const p = (i + off) / 18, y = hz + (bottom - hz) * p * p;
                ctx.strokeStyle = `rgba(192,132,252,${(0.05 + p * .45).toFixed(3)})`;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
            }
            // Lignes qui convergent vers l'horizon
            for (let i = -16; i <= 16; i++) {
                const xb = cx + i * W * .09;
                const g = ctx.createLinearGradient(0, hz, 0, bottom);
                g.addColorStop(0, 'rgba(192,132,252,0)'); g.addColorStop(1, 'rgba(192,132,252,.38)');
                ctx.strokeStyle = g;
                ctx.beginPath(); ctx.moveTo(cx + i * W * .006, hz); ctx.lineTo(xb, bottom); ctx.stroke();
            }
        });
    })();

    /* =================================================================
       3. LOGO VIDÉO + effets synchronisés
       ================================================================= */
    const Intro = (() => {
        const v = $('logo'), wrap = $('logoWrap');
        const big = (screen.width || innerWidth) * (window.devicePixelRatio || 1) >= 2560;
        const use4k = cfg.video.quality === '4k' || (cfg.video.quality === 'auto' && big);
        const src = use4k ? cfg.video.src4k : cfg.video.src1080;
        let ended = false, uiShown = false;
        const fired = {};
        const B = cfg.video.beats;
        // Coordonnées d'un point de l'image vidéo (0..1) à l'écran
        function at(fx, fy) { const r = wrap.getBoundingClientRect(); return [r.left + fx * r.width, r.top + fy * r.height]; }
        function flash() { const f = $('flash'); f.classList.remove('go'); void f.offsetWidth; f.classList.add('go'); }
        function ring() { const r = $('ring'); r.classList.remove('go'); void r.offsetWidth; r.classList.add('go'); }
        const BEATS = [
            ['reveal', () => { flash(); body.classList.add('halo-on'); const [x, y] = at(.5, .45); FX.burst(x, y, 40, { speed: 380, gravity: 60 }); }],
            ['sparks', () => { const [x, y] = at(.63, .56); FX.burst(x, y, 140, { speed: 820, angle: -0.4, spread: 1.6, gravity: 320 }); body.classList.add('beams-on'); }],
            ['city', () => { ring(); body.classList.add('grid-on'); const [x, y] = at(.62, .5); FX.burst(x, y, 60, { speed: 420, gravity: 40 }); }],
            ['title', () => { wrap.classList.remove('chroma'); void wrap.offsetWidth; wrap.classList.add('chroma'); const [x, y] = at(.5, .78); FX.burst(x, y, 70, { speed: 600, angle: -Math.PI / 2, spread: 1.2, gravity: 200 }); }],
            ['settle', () => showUI()],
        ];
        function fire(name) {
            if (fired[name]) return;
            fired[name] = true;
            const b = BEATS.find((x) => x[0] === name);
            if (b) b[1]();
        }
        loops.add(() => {
            if (ended || !v.duration) return;
            const t = v.currentTime;
            for (const [name] of BEATS) if (B[name] != null && t >= B[name]) fire(name);
        });
        function showUI() {
            if (uiShown) return;
            uiShown = true;
            ['reveal', 'sparks', 'city', 'title'].forEach((n) => (fired[n] = true));
            body.classList.add('halo-on', 'beams-on', 'grid-on');
            body.classList.remove('phase-intro');
            body.classList.add('phase-ui');
            UI.start();
        }
        function skip() {
            if (uiShown) return;
            if (v.duration) { try { v.currentTime = Math.max(0, v.duration - .05); } catch (e) { /* rien */ } }
            flash();
            showUI();
        }
        let triedLow = false;
        function fallback() {
            // 4K absente ou illisible : on essaie la 1080p avant l'image fixe
            if (!triedLow && use4k && cfg.video.src1080 && v.currentSrc.indexOf(cfg.video.src1080) < 0) {
                triedLow = true;
                v.src = cfg.video.src1080;
                const p = v.play();
                if (p && p.catch) p.catch(() => fallback());
                return;
            }
            // Vidéo illisible : image finale du logo, interface directement
            if (cfg.video.poster) { v.poster = cfg.video.poster; }
            ended = true;
            setTimeout(showUI, 600);
        }
        function start() {
            if (!src) return fallback();
            v.src = src;
            v.muted = true;
            v.addEventListener('ended', () => { ended = true; showUI(); });
            v.addEventListener('error', fallback);
            const p = v.play();
            if (p && p.catch) p.catch(() => fallback());
            // Sécurité : rien ne démarre en 4 s → interface quand même
            setTimeout(() => { if (!v.currentTime) fallback(); }, 4000);
            setTimeout(() => { if (!v.currentTime && !uiShown) { ended = true; showUI(); } }, 8000);
            if (cfg.video.skippable) {
                $('skip').addEventListener('click', skip);
                addEventListener('keydown', (e) => { if (['Escape', 'Enter', ' ', 'Spacebar'].includes(e.key)) skip(); });
            } else $('skip').remove();
        }
        return { start, skip, showUI };
    })();

    /* =================================================================
       4. INTERFACE : diaporama, astuces, slogan, horloge, liens
       ================================================================= */
    const UI = (() => {
        let started = false;
        function slideshow() {
            const box = $('slides');
            let list = cfg.slides.map((s) => (typeof s === 'string' ? { src: s } : s));
            if (!list.length) return;
            if (cfg.slideshow.shuffle) list.sort(() => Math.random() - .5);
            const els = list.map((s) => { const d = document.createElement('div'); d.className = 'slide'; d.style.backgroundImage = `url("${s.src}")`; d.style.setProperty('--fade', `${cfg.slideshow.transition}ms`); box.appendChild(d); return d; });
            let i = -1;
            const KB = ['kb-a', 'kb-b', 'kb-c'];
            const place = $('placeTitle'), side = $('placeSide'), card = document.querySelector('.place-card');
            const SIDE = { legal: ['Côté légal', '⚖'], illegal: ['Côté illégal', '☠'], neutral: ['Los Santos', '◆'] };
            function next() {
                const prev = els[i];
                i = (i + 1) % els.length;
                const el = els[i], s = list[i];
                KB.forEach((k) => el.classList.remove(k)); void el.offsetWidth;
                el.classList.add('on', KB[i % KB.length]);
                if (prev && prev !== el) setTimeout(() => prev.classList.remove('on'), 60);
                const sd = SIDE[s.side] || SIDE.neutral;
                place.classList.add('out');
                setTimeout(() => {
                    place.textContent = s.title || '';
                    side.textContent = s.label || sd[0];
                    $('placeIco').textContent = sd[1];
                    card.dataset.side = s.side || 'neutral';
                    card.style.display = s.title ? '' : 'none';
                    place.classList.remove('out');
                }, 450);
            }
            next();
            setInterval(next, cfg.slideshow.interval);
        }
        function tipsLoop() {
            const el = $('tip'), bar = $('tipBar'), list = cfg.tips.list || [];
            if (!list.length) { document.querySelector('.tip-card').remove(); return; }
            let i = 0;
            document.documentElement.style.setProperty('--tipT', `${cfg.tips.interval}ms`);
            function show() {
                el.classList.add('out');
                setTimeout(() => {
                    el.textContent = list[i % list.length]; i++;
                    el.classList.remove('out');
                    bar.classList.remove('run'); void bar.offsetWidth; bar.classList.add('run');
                }, 450);
            }
            show();
            setInterval(show, cfg.tips.interval);
        }
        function slogan() {
            const el = $('slogan'), txt = cfg.server.slogan || '';
            if (!txt) return;
            let n = 0;
            const cur = '<span class="cur"></span>';
            const id = setInterval(() => {
                n++;
                el.innerHTML = txt.slice(0, n).replace(/[<>&]/g, '') + cur;
                if (n >= txt.length) clearInterval(id);
            }, 55);
        }
        function clock() {
            const el = $('clock');
            const f = () => { const d = new Date(); el.textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
            f(); setInterval(f, 10000);
        }
        function start() {
            if (started) return;
            started = true;
            $('srvName').textContent = cfg.server.name;
            $('srvTag').textContent = cfg.server.tagline;
            $('links').innerHTML = (cfg.links || []).map((l) => `<div class="link"><span>${String(l.label).replace(/[<>&]/g, '')}</span>${String(l.value).replace(/[<>&]/g, '')}</div>`).join('');
            slideshow(); tipsLoop(); slogan(); clock();
            Progress.wake();
        }
        // Parallaxe douce du fond
        if (cfg.effects.parallax && !reduced) {
            const bg = $('bg');
            loops.add(() => { bg.style.transform = `translate3d(${(-FX.mouse.sx * 1.4).toFixed(3)}%, ${(-FX.mouse.sy * 1).toFixed(3)}%, 0)`; });
        }
        return { start };
    })();

    /* =================================================================
       5. PROGRESSION RÉELLE DU CHARGEMENT FIVEM
       ================================================================= */
    const Progress = (() => {
        const fill = $('barFill'), pctEl = $('pct'), statusEl = $('status'), stepsEl = $('steps');
        const S = cfg.loading.stages || {};
        const ORDER = ['core', 'before', 'data', 'map', 'after', 'session', 'done'];
        const SHORT = { core: 'Jeu', before: 'Ressources', data: 'Données', map: 'Carte', after: 'Monde', session: 'Session', done: 'Prêt' };
        stepsEl.innerHTML = ORDER.map((k) => `<li data-k="${k}">${SHORT[k]}</li>`).join('');
        const RANGES = {
            INIT_CORE: [2, 10, 'core'], INIT_BEFORE_MAP_LOADED: [10, 25, 'before'], MAP: [25, 55, 'data'], MAPLOAD: [55, 66, 'map'],
            INIT_AFTER_MAP_LOADED: [66, 82, 'after'], INIT_SESSION: [82, 97, 'session'],
        };
        const counts = {}, done = {};
        let target = 0, shown = 0, ceiling = 8, finished = false, running = false, lastBump = performance.now(), lastPct = -1, stage = 'start';
        function setStatus(key) {
            if (!S[key] || key === stage) return;
            stage = key;
            statusEl.classList.add('out');
            setTimeout(() => { statusEl.textContent = S[key]; statusEl.classList.remove('out'); }, 260);
            const idx = ORDER.indexOf(key);
            stepsEl.querySelectorAll('li').forEach((li, i) => { li.classList.toggle('done', i < idx || key === 'done'); li.classList.toggle('now', i === idx && key !== 'done'); });
        }
        function setTarget(v) { v = clamp(v, 0, finished ? 100 : 99); if (v > target) { target = v; lastBump = performance.now(); } }
        function enter(type) { const r = RANGES[type]; if (!r) return; ceiling = Math.max(ceiling, r[1]); setTarget(r[0]); setStatus(r[2]); }
        function advance(type) { const r = RANGES[type]; if (!r) return; const c = Math.max(1, counts[type] || 1); setTarget(r[0] + (r[1] - r[0]) * clamp((done[type] || 0) / c, 0, 1)); }
        const H = {
            startInitFunctionOrder(d) { counts[d.type] = d.count || 1; done[d.type] = 0; enter(d.type); },
            initFunctionInvoking(d) { done[d.type] = Math.max(done[d.type] || 0, (d.idx || 0) + 1); advance(d.type); },
            endInitFunction(d) { if (d && d.type) { done[d.type] = counts[d.type] || 1; advance(d.type); } },
            startDataFileEntries(d) { counts.MAP = d.count || 1; done.MAP = 0; enter('MAP'); },
            onDataFileEntry() { done.MAP = (done.MAP || 0) + 1; advance('MAP'); },
            endDataFileEntries() { done.MAP = counts.MAP || 1; advance('MAP'); },
            performMapLoadFunction() { if (!done.MAPLOAD) enter('MAPLOAD'); done.MAPLOAD = (done.MAPLOAD || 0) + 1; counts.MAPLOAD = Math.max(counts.MAPLOAD || 8, done.MAPLOAD + 2); advance('MAPLOAD'); },
            loadProgress(d) { if (d && typeof d.loadFraction === 'number') setTarget(d.loadFraction * 100); },
            onLogLine() { /* rien */ },
        };
        function frame(dt, now) {
            if (!finished && now - lastBump > 1200 && target < ceiling - 1) target = Math.min(ceiling - 1, target + .7 * dt);
            const sm = finished ? Math.max(.12, cfg.loading.smoothing) : cfg.loading.smoothing;
            shown += (target - shown) * (1 - Math.pow(1 - clamp(sm, .005, .5), dt * 60));
            if (Math.abs(target - shown) < .02) shown = target;
            fill.style.transform = `translateX(${(shown - 100).toFixed(3)}%)`;
            const p = Math.floor(shown);
            if (p !== lastPct) { pctEl.textContent = p; lastPct = p; }
        }
        function wake() { if (running) return; running = true; if (stage === 'start') { statusEl.textContent = S.start || ''; } loops.add(frame); }
        function finish() { finished = true; ceiling = 100; setTarget(100); setStatus('done'); wake(); }
        function handle(name, data) { if (H[name]) H[name](data || {}); if (name === 'endInitFunction' && data && data.type === 'INIT_SESSION') finish(); }
        function demo() {
            const T = Math.max(6000, cfg.loading.demoDuration);
            const plan = [
                [.02, 'startInitFunctionOrder', { type: 'INIT_CORE', count: 6 }], ...Array.from({ length: 6 }, (_, i) => [.03 + i * .012, 'initFunctionInvoking', { type: 'INIT_CORE', idx: i }]),
                [.12, 'startInitFunctionOrder', { type: 'INIT_BEFORE_MAP_LOADED', count: 10 }], ...Array.from({ length: 10 }, (_, i) => [.13 + i * .012, 'initFunctionInvoking', { type: 'INIT_BEFORE_MAP_LOADED', idx: i }]),
                [.26, 'startDataFileEntries', { count: 30 }], ...Array.from({ length: 30 }, (_, i) => [.27 + i * .008, 'onDataFileEntry', {}]),
                ...Array.from({ length: 8 }, (_, i) => [.53 + i * .015, 'performMapLoadFunction', {}]),
                [.66, 'startInitFunctionOrder', { type: 'INIT_AFTER_MAP_LOADED', count: 12 }], ...Array.from({ length: 12 }, (_, i) => [.67 + i * .011, 'initFunctionInvoking', { type: 'INIT_AFTER_MAP_LOADED', idx: i }]),
                [.82, 'startInitFunctionOrder', { type: 'INIT_SESSION', count: 10 }], ...Array.from({ length: 10 }, (_, i) => [.83 + i * .014, 'initFunctionInvoking', { type: 'INIT_SESSION', idx: i }]),
            ];
            plan.forEach(([at, n, d]) => setTimeout(() => H[n](d), at * T));
            setTimeout(finish, T);
        }
        return { handle, wake, demo, finish };
    })();

    /* =================================================================
       6. MUSIQUE
       ================================================================= */
    const Music = (() => {
        const a = $('audio'), list = (cfg.music.playlist || []).filter((t) => t && t.file);
        const play = $('plPlay'), eq = $('eq'), vol = $('plVol');
        if (!list.length) { $('player').remove(); return { fadeOut() {} }; }
        if (cfg.music.shuffle) list.sort(() => Math.random() - .5);
        let i = 0, wanted = clamp(cfg.music.volume, 0, 1), fadeT = null;
        vol.value = Math.round(wanted * 100);
        function load(n, autoplay) {
            i = (n + list.length) % list.length;
            const t = list[i];
            a.src = t.file; $('trTitle').textContent = t.title || 'Musique'; $('trArtist').textContent = t.artist || '';
            if (autoplay) go();
        }
        function ui() { const on = !a.paused; play.textContent = on ? '⏸' : '▶'; eq.classList.toggle('paused', !on); }
        function fadeTo(v, ms) {
            clearInterval(fadeT);
            const from = a.volume, t0 = performance.now();
            fadeT = setInterval(() => { const k = clamp((performance.now() - t0) / Math.max(1, ms), 0, 1); a.volume = from + (v - from) * k; if (k >= 1) clearInterval(fadeT); }, 30);
        }
        function go() { a.volume = 0; const p = a.play(); if (p && p.catch) p.catch(() => ui()); fadeTo(wanted, cfg.music.fadeIn); }
        a.addEventListener('play', ui); a.addEventListener('pause', ui);
        a.addEventListener('ended', () => load(i + 1, true));
        play.addEventListener('click', () => { if (a.paused) go(); else a.pause(); });
        $('plNext').addEventListener('click', () => load(i + 1, true));
        $('plPrev').addEventListener('click', () => load(i - 1, true));
        vol.addEventListener('input', () => { wanted = vol.value / 100; clearInterval(fadeT); a.volume = wanted; });
        load(0, cfg.music.autoplay);
        ui();
        return { fadeOut(ms) { fadeTo(0, ms * .9); } };
    })();

    /* =================================================================
       7. FIVEM : messages, sortie
       ================================================================= */
    let leaving = false;
    function leave(ms) {
        if (leaving) return;
        leaving = true;
        ms = Number(ms) || cfg.effects.fadeOutDuration || 1200;
        document.documentElement.style.setProperty('--exitT', `${ms}ms`);
        Progress.finish();
        Intro.showUI();
        Music.fadeOut(ms);
        body.classList.add('leaving');
    }
    addEventListener('message', (e) => {
        const d = e.data;
        if (!d || typeof d !== 'object' || !d.eventName) return;
        if (d.eventName === 'elyzea:fadeOut') leave(d.duration);
        else Progress.handle(d.eventName, d);
    });

    const inFiveM = typeof window.invokeNative === 'function' || typeof window.nuiHandoverData !== 'undefined' || /CitizenFX/i.test(navigator.userAgent);
    Intro.start();
    Progress.wake();
    if (!inFiveM) Progress.demo();
    window.__elyzeaLS = { leave, skip: Intro.skip, finish: Progress.finish };
})();
