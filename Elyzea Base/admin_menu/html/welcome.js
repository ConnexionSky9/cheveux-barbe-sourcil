/* =========================================================
   ARRIVÉE EN VILLE : affichage de la cinématique (piloté par le jeu)
   Étapes : intro → reveal → city → outro → end
   + onglet ✨ Arrivée en ville (permission « manage_welcome »)
   ========================================================= */
(() => {
    const W = document.getElementById('welcome');
    const el = (id) => document.getElementById(id);
    const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const timers = [];
    const later = (fn, ms) => timers.push(setTimeout(fn, ms));
    const clearTimers = () => { while (timers.length) clearTimeout(timers.pop()); };

    /* ---------- Particules violettes (canvas, s'arrête tout seul) ---------- */
    const FX = (() => {
        const c = el('wlFx'); const g = c.getContext('2d');
        let parts = [], raf = 0, dpr = 1;
        const size = () => { dpr = Math.min(window.devicePixelRatio || 1, 1.5); c.width = innerWidth * dpr; c.height = innerHeight * dpr; };
        const COLORS = ['233,213,255', '201,166,255', '181,123,255', '155,92,255'];
        function burst(x, y, n, speed) {
            for (let i = 0; i < n; i++) {
                const a = Math.random() * Math.PI * 2, v = speed * (0.3 + Math.random());
                parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 1, decay: 0.006 + Math.random() * 0.012,
                    r: 0.8 + Math.random() * 2.4, c: COLORS[(Math.random() * COLORS.length) | 0], drag: 0.975 });
            }
            run();
        }
        function rise(n) {   // poussière lumineuse qui monte de la ville
            for (let i = 0; i < n; i++) {
                parts.push({ x: Math.random() * innerWidth, y: innerHeight * (0.75 + Math.random() * 0.3), vx: (Math.random() - 0.5) * 0.3,
                    vy: -(0.3 + Math.random() * 0.9), life: 1, decay: 0.003 + Math.random() * 0.004, r: 0.6 + Math.random() * 1.6,
                    c: COLORS[(Math.random() * COLORS.length) | 0], drag: 1 });
            }
            run();
        }
        function frame() {
            g.setTransform(dpr, 0, 0, dpr, 0, 0);
            g.clearRect(0, 0, innerWidth, innerHeight);
            g.globalCompositeOperation = 'lighter';
            parts = parts.filter((p) => p.life > 0);
            for (const p of parts) {
                p.x += p.vx; p.y += p.vy; p.vx *= p.drag; p.vy *= p.drag; p.life -= p.decay;
                const a = Math.max(0, p.life);
                g.fillStyle = `rgba(${p.c},${a})`;
                g.beginPath(); g.arc(p.x, p.y, p.r, 0, 7); g.fill();
                g.fillStyle = `rgba(${p.c},${a * 0.18})`;
                g.beginPath(); g.arc(p.x, p.y, p.r * 4, 0, 7); g.fill();
            }
            raf = parts.length ? requestAnimationFrame(frame) : 0;
            if (!raf) g.clearRect(0, 0, innerWidth, innerHeight);
        }
        function run() { if (!raf) { size(); raf = requestAnimationFrame(frame); } }
        function stop() { parts = []; if (raf) cancelAnimationFrame(raf); raf = 0; g.clearRect(0, 0, c.width, c.height); }
        return { burst, rise, stop };
    })();

    /* ---------- Sons de synthèse (aucun fichier, volume doux) ---------- */
    const SFX = (() => {
        let ctx = null;
        const ac = () => { try { ctx = ctx || new (window.AudioContext || window.webkitAudioContext)(); if (ctx.state === 'suspended') ctx.resume(); } catch (e) { ctx = null; } return ctx; };
        function tone(type, f0, f1, dur, vol, delay = 0) {
            const a = ac(); if (!a) return;
            const t = a.currentTime + delay, o = a.createOscillator(), v = a.createGain();
            o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + dur);
            v.gain.setValueAtTime(0.0001, t); v.gain.exponentialRampToValueAtTime(vol, t + 0.03); v.gain.exponentialRampToValueAtTime(0.0001, t + dur);
            o.connect(v).connect(a.destination); o.start(t); o.stop(t + dur + 0.05);
        }
        function noise(dur, vol, f0, f1, delay = 0) {
            const a = ac(); if (!a) return;
            const t = a.currentTime + delay, len = Math.floor(a.sampleRate * dur), b = a.createBuffer(1, len, a.sampleRate), d = b.getChannelData(0);
            for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
            const s = a.createBufferSource(), f = a.createBiquadFilter(), v = a.createGain();
            s.buffer = b; f.type = 'bandpass'; f.Q.value = 1.2; f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(f1, t + dur);
            v.gain.setValueAtTime(0.0001, t); v.gain.exponentialRampToValueAtTime(vol, t + dur * 0.6); v.gain.exponentialRampToValueAtTime(0.0001, t + dur);
            s.connect(f).connect(v).connect(a.destination); s.start(t);
        }
        return {
            whoosh: (d = 0) => noise(1.4, 0.18, 300, 2400, d),
            boom: (d = 0) => { tone('sine', 110, 32, 1.6, 0.35, d); noise(0.8, 0.08, 900, 120, d); },
            shimmer: (d = 0) => [880, 1318.5, 1760, 2637].forEach((f, i) => tone('triangle', f, f * 1.002, 1.8, 0.035, d + i * 0.09)),
            tick: (d = 0) => tone('square', 2200, 1800, 0.05, 0.02, d),
        };
    })();

    function letters(text) {
        const words = String(text || 'Elyzea FA').trim().split(/\s+/);
        let i = 0;
        return words.map((w, wi) => {
            const v = words.length > 1 && wi === words.length - 1 ? ' v' : '';
            return [...w].map((ch) => `<span class="${v.trim()}" style="animation-delay:${(2.6 + i++ * 0.07).toFixed(2)}s">${esc(ch)}</span>`).join('');
        }).join('<span style="width:.35em"></span>');
    }

    function reset() {
        clearTimers(); FX.stop();
        W.classList.remove('hidden', 'reveal', 'cinema', 'out');
        el('wlIntro').classList.remove('hidden');
        el('wlScene').classList.add('hidden');
        el('wlOutro').classList.add('hidden');
        el('wlBlack').classList.remove('hidden');
        el('wlRing').classList.remove('hidden');
        // Relance les animations CSS de l'intro
        const intro = el('wlIntro'); const clone = intro.cloneNode(true); intro.replaceWith(clone);
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'welcome') return;
        switch (m.stage) {
            case 'intro': {
                reset();
                el('wlMark').innerHTML = Ely.mark({ size: 340, anim: true, live: true });
                el('wlTitle').textContent = m.title || 'Bienvenue sur';
                el('wlName').innerHTML = letters(m.name);
                el('wlCity').innerHTML = Ely.skyline({ w: 1920, h: 340, seed: 11, lit: 0.35 });
                el('wlCity').querySelectorAll('.w.on').forEach((w) => { w.style.animationDelay = `${(3 + Math.random() * 2.2).toFixed(2)}s`; });
                SFX.whoosh(0.15);
                later(() => { FX.burst(innerWidth / 2, innerHeight * 0.4, 140, 7); SFX.boom(); }, 1300);
                later(() => SFX.shimmer(), 2600);
                later(() => FX.rise(70), 3200);
                return;
            }
            case 'reveal':
                W.classList.add('reveal');
                FX.burst(innerWidth / 2, innerHeight * 0.52, 220, 11);
                SFX.boom(); SFX.whoosh(0.05);
                later(() => { el('wlIntro').classList.add('hidden'); el('wlBlack').classList.add('hidden'); el('wlRing').classList.add('hidden'); }, 1700);
                return;
            case 'city': {
                W.classList.add('cinema');
                const zone = [m.district, m.street].filter(Boolean).map(esc).join(' · ');
                el('wlLoc').innerHTML = `${Ely.mark({ size: 74, live: true })}<i class="bar"></i><div class="txt">
                    <div class="city">${esc(m.city || 'Los Santos')}</div>${zone ? `<div class="zone">${zone}</div>` : ''}
                    ${m.time ? `<div class="time">${esc(m.time)}</div>` : ''}</div>`;
                el('wlWho').innerHTML = m.name ? `<small>Nouveau citoyen</small><b>${esc(m.name)}</b>` : '';
                const s = el('wlScene'); s.classList.add('hidden'); void s.offsetWidth; s.classList.remove('hidden');
                SFX.whoosh(0.3); SFX.tick(0.8); SFX.tick(1.3);
                return;
            }
            case 'outro': {
                el('wlScene').classList.add('hidden');
                const words = String(m.message || '').trim().split(/\s+/).filter(Boolean);
                el('wlMsg').innerHTML = words.map((w, i) => `<span style="animation-delay:${(i * 0.09).toFixed(2)}s">${esc(w)}</span>`).join(' ');
                el('wlSign').textContent = m.signature || '';
                el('wlSign').style.animationDelay = `${(words.length * 0.09 + 0.4).toFixed(2)}s`;
                el('wlSign').classList.toggle('hidden', !m.signature);
                const o = el('wlOutro'); o.classList.add('hidden'); void o.offsetWidth; o.classList.remove('hidden');
                SFX.shimmer(0.1);
                later(() => FX.rise(40), 300);
                return;
            }
            case 'end':
                W.classList.remove('cinema');
                W.classList.add('out');
                later(() => { FX.stop(); W.classList.add('hidden'); W.classList.remove('out', 'reveal'); }, 1450);
        }
    });

    /* ---------- Onglet du menu admin ---------- */
    const at = TABS.findIndex((t) => t.id === 'respawn');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'welcome', group: 2, label: 'Arrivée en ville', ico: '✨',
        sub: 'Cinématique de bienvenue quand un joueur valide son nouveau personnage.',
        show: () => has('manage_welcome') && !!(D && D.welcome),
    });
    const F = { draft: null };

    VIEWS.welcome = () => {
        const w = D.welcome;
        if (!F.draft) F.draft = { enabled: w.enabled, title: w.title, name: w.name, message: w.message, signature: w.signature };
        const d = F.draft;
        return `
            <p class="hint">${w.creator ? 'Quand un joueur <b>valide son nouveau personnage dans ely_creator</b>, il voit'
                : 'À la <b>toute première arrivée en ville</b> de chaque personnage, il voit'} : le titre de bienvenue, puis sa génération « cyber »
                (la caméra descend de la tête aux pieds pendant que le corps se matérialise), puis le message final.
                Une seule fois par personnage. ${w.seen} personnage(s) l'ont déjà vue.</p>
            <div class="section"><h2>Réglages</h2>
                <div class="tile toggle-tile ${d.enabled ? 'on' : ''}" data-wl="enabled" style="max-width:420px;margin-bottom:12px"><div><strong>Cinématique de bienvenue</strong><span>${d.enabled ? 'Active pour les nouveaux personnages' : 'Désactivée'}</span></div><div class="switch"></div></div>
                <div class="form-grid" style="grid-template-columns:1fr 1fr;max-width:820px">
                    <div><label>Titre</label><input class="input" data-wlf="title" value="${esc(d.title)}" maxlength="60"></div>
                    <div><label>Nom du serveur</label><input class="input" data-wlf="name" value="${esc(d.name)}" maxlength="40"></div>
                    <div style="grid-column:span 2"><label>Message final</label><input class="input" data-wlf="message" value="${esc(d.message)}" maxlength="240"></div>
                    <div><label>Signature</label><input class="input" data-wlf="signature" value="${esc(d.signature)}" maxlength="60"></div>
                </div>
                <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-wl="save">Enregistrer</button>
                    <button class="btn" data-wl="test">▶ Voir la cinématique (sur moi)</button></div>
            </div>
            <div class="section"><h2>Rejouer pour un joueur</h2>
                <p class="hint">La cinématique se rejoue tout de suite pour lui (utile après un bug ou une déconnexion pendant la cinématique).</p>
                <div class="inline" style="max-width:420px"><input class="input" id="wl-id" inputmode="numeric" placeholder="ID du joueur">
                    <button class="btn" data-wl="replay">Rejouer</button></div>
            </div>`;
    };

    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'welcome' || !e.target.dataset.wlf || !F.draft) return;
        F.draft[e.target.dataset.wlf] = e.target.value;
    });
    document.addEventListener('click', (e) => {
        if (!isOpen || tab !== 'welcome') return;
        const b = e.target.closest('[data-wl]');
        if (!b) return;
        switch (b.dataset.wl) {
            case 'enabled': F.draft.enabled = !F.draft.enabled; return render();
            case 'save': action('welcome_save', F.draft); F.draft = null; return;
            case 'test': post('close'); return action('welcome_test');
            case 'replay': { const id = Number((el('wl-id') || {}).value); if (!id) return toast('Entre un ID.', 'error'); return action('welcome_replay', { target: id }); }
        }
    });
})();
