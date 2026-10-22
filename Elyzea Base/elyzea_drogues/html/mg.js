/* =====================================================================
   ELYZEA DROGUES · moteur des mini-jeux (NUI)
   Le serveur envoie un défi : { type, skin, drug, title, hint, seed, count, maxMistakes, limit, extra }.
   Le mini-jeu (mg_games.js) appelle S.hit() à chaque objectif réussi et S.miss() à chaque erreur.
   Fin : réussite (count objectifs), échec (trop d'erreurs ou temps écoulé) ou annulation (Échap).
   Le résultat part au client Lua (mgResult), qui le transmet au serveur pour validation.
   ===================================================================== */
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
  const post = (name, data) => RES ? fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => {}) : Promise.resolve();

  const W = 760, H = 440;
  const THEMES = {
    weed:      { a: [90, 209, 106],  icon: '🌿', name: 'Cannabis' },
    cocaine:   { a: [125, 211, 252], icon: '❄️', name: 'Cocaïne' },
    crack:     { a: [251, 191, 36],  icon: '💎', name: 'Crack' },
    meth:      { a: [56, 189, 248],  icon: '⚗️', name: 'Méthamphétamine' },
    ecstasy:   { a: [244, 114, 182], icon: '💊', name: 'Ecstasy' },
    opiates:   { a: [251, 146, 60],  icon: '💉', name: 'Opiacés' },
    ketamine:  { a: [196, 181, 253], icon: '🐴', name: 'Kétamine' },
    mushrooms: { a: [167, 139, 250], icon: '🍄', name: 'Champignons' },
  };

  // Générateur pseudo-aléatoire à graine (même défi = même tirage)
  function rng(seed) {
    let a = (seed >>> 0) || 1;
    return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }

  // ---------------------------------------------------------------- outils de dessin communs
  const D = {
    W, H,
    rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); },
    rgba(c, a) { return `rgba(${c[0]},${c[1]},${c[2]},${a})`; },
    mix(c1, c2, t) { return [0, 1, 2].map((i) => Math.round(c1[i] + (c2[i] - c1[i]) * t)); },
    dist(ax, ay, bx, by) { return Math.hypot(ax - bx, ay - by); },
    // distance d'un point au segment [a, b]
    segDist(px, py, ax, ay, bx, by) {
      const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy;
      let t = l ? ((px - ax) * dx + (py - ay) * dy) / l : 0;
      t = Math.max(0, Math.min(1, t));
      return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
    },
    clamp(v, a, b) { return Math.max(a, Math.min(b, v)); },
    // fond : établi sombre (bois / inox / mousse) avec vignette
    bg(g, kind, accent) {
      const grd = g.createLinearGradient(0, 0, 0, H);
      const k = { wood: ['#2a1e14', '#16100a'], steel: ['#1b2330', '#0b1018'], moss: ['#15241a', '#0a130d'], lab: ['#101a2a', '#070b14'], dark: ['#141a26', '#090c13'] }[kind] || ['#141a26', '#090c13'];
      grd.addColorStop(0, k[0]); grd.addColorStop(1, k[1]);
      g.fillStyle = grd; g.fillRect(0, 0, W, H);
      g.save(); g.globalAlpha = 0.06; g.strokeStyle = '#fff';
      if (kind === 'wood') { for (let y = 10; y < H; y += 22) { g.beginPath(); g.moveTo(0, y); for (let x = 0; x <= W; x += 40) g.lineTo(x, y + Math.sin((x + y) * 0.03) * 3); g.stroke(); } }
      else if (kind === 'steel' || kind === 'lab') { for (let x = 0; x < W; x += 38) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, H); g.stroke(); } for (let y = 0; y < H; y += 38) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); } }
      g.restore();
      const v = g.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H * 0.95);
      v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,.55)');
      g.fillStyle = v; g.fillRect(0, 0, W, H);
      if (accent) { const l = g.createRadialGradient(W / 2, -40, 10, W / 2, -40, H); l.addColorStop(0, D.rgba(accent, 0.10)); l.addColorStop(1, D.rgba(accent, 0)); g.fillStyle = l; g.fillRect(0, 0, W, H); }
    },
    label(g, text, x, y, opts = {}) {
      g.save(); g.font = `${opts.weight || 700} ${opts.size || 13}px Inter, Segoe UI, sans-serif`; g.textAlign = opts.align || 'center'; g.textBaseline = 'middle';
      g.fillStyle = opts.color || '#e2e8f0'; if (opts.shadow !== false) { g.shadowColor = 'rgba(0,0,0,.7)'; g.shadowBlur = 6; }
      g.fillText(text, x, y); g.restore();
    },
    // jauge horizontale avec zone cible
    gauge(g, x, y, w, h, value, lo, hi, accent, danger) {
      D.rr(g, x, y, w, h, h / 2); g.fillStyle = 'rgba(148,178,230,.12)'; g.fill();
      if (danger !== undefined) { g.fillStyle = 'rgba(248,113,113,.25)'; D.rr(g, x + w * danger, y, w * (1 - danger), h, h / 2); g.fill(); }
      g.fillStyle = D.rgba(accent, 0.35); g.fillRect(x + w * lo, y, w * (hi - lo), h);
      g.strokeStyle = D.rgba(accent, 0.9); g.lineWidth = 2; g.strokeRect(x + w * lo, y, w * (hi - lo), h);
      const mx = x + w * D.clamp(value, 0, 1);
      g.fillStyle = '#fff'; g.beginPath(); g.moveTo(mx, y - 6); g.lineTo(mx - 6, y - 14); g.lineTo(mx + 6, y - 14); g.closePath(); g.fill();
      g.fillRect(mx - 1.5, y - 2, 3, h + 4);
    },
    // particules simples (miettes, gouttes, éclats)
    parts: [],
    burst(x, y, color, n = 10, speed = 140, size = 3, grav = 380) {
      for (let i = 0; i < n; i++) { const a = Math.random() * Math.PI * 2, s = speed * (0.4 + Math.random() * 0.8); D.parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - speed * 0.4, life: 0.7 + Math.random() * 0.5, t: 0, color, size: size * (0.6 + Math.random() * 0.8), grav }); }
    },
    stepParts(g, dt) {
      for (let i = D.parts.length - 1; i >= 0; i--) {
        const p = D.parts[i]; p.t += dt; if (p.t >= p.life) { D.parts.splice(i, 1); continue; }
        p.vy += p.grav * dt; p.x += p.vx * dt; p.y += p.vy * dt;
        g.globalAlpha = 1 - p.t / p.life; g.fillStyle = p.color; g.beginPath(); g.arc(p.x, p.y, p.size, 0, Math.PI * 2); g.fill();
      }
      g.globalAlpha = 1;
    },
    // anneau de progression (maintien)
    ring(g, x, y, r, t, color) {
      g.save(); g.lineWidth = 4; g.strokeStyle = 'rgba(255,255,255,.18)'; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.stroke();
      g.strokeStyle = color; g.beginPath(); g.arc(x, y, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * D.clamp(t, 0, 1)); g.stroke(); g.restore();
    },
    hand(g, x, y, down) { // curseur main générique
      g.save(); g.translate(x, y); g.fillStyle = down ? '#fde68a' : '#f8fafc'; g.strokeStyle = 'rgba(0,0,0,.6)'; g.lineWidth = 1.5;
      g.beginPath(); g.arc(0, 0, down ? 6 : 8, 0, Math.PI * 2); g.fill(); g.stroke(); g.restore();
    },
  };

  // ---------------------------------------------------------------- interface
  const root = document.createElement('div');
  root.id = 'mg';
  root.innerHTML = `<div class="mg-panel">
    <header><div class="mg-ico"></div><div class="mg-head"><small></small><b></b></div>
      <div class="mg-timer"><svg viewBox="0 0 48 48"><circle class="bg" cx="24" cy="24" r="20"/><circle class="fg" cx="24" cy="24" r="20" stroke-dasharray="125.66" stroke-dashoffset="0"/></svg><span></span></div></header>
    <p class="mg-hint"></p>
    <div class="mg-stage"><canvas width="${W}" height="${H}"></canvas><div class="mg-toast"></div><div class="mg-end"><div><b></b><span></span></div></div></div>
    <footer><div class="mg-prog"><i></i></div><span class="mg-count"></span><div class="mg-lives"></div><span class="mg-esc"><kbd>Échap</kbd> annuler</span></footer>
  </div>`;
  document.body.appendChild(root);
  const $ = (s) => root.querySelector(s);
  const canvas = $('canvas'), g = canvas.getContext('2d');

  const MG = { games: {}, cur: null, D, THEMES };
  window.ElyMG = MG;

  let raf = 0, toastT = 0;
  function toast(text, kind) {
    const t = $('.mg-toast'); t.textContent = text; t.className = 'mg-toast on ' + (kind || '');
    clearTimeout(toastT); toastT = setTimeout(() => { t.className = 'mg-toast'; }, 1300);
  }
  function setHint(text) { $('.mg-hint').textContent = text || ''; }
  function refreshHud(S) {
    $('.mg-prog i').style.width = `${Math.min(100, (S.done / S.total) * 100)}%`;
    $('.mg-count').textContent = `${S.done} / ${S.total}`;
    const lives = $('.mg-lives');
    if (lives.childElementCount !== S.max + 1) { lives.innerHTML = ''; for (let i = 0; i <= S.max; i++) lives.appendChild(document.createElement('i')); }
    [...lives.children].forEach((el, i) => el.classList.toggle('lost', i >= S.max + 1 - S.mistakes));
  }

  function end(S, ok, reason) {
    if (S.ended) return;
    S.ended = true;
    const box = $('.mg-end');
    box.className = 'mg-end on ' + (ok ? 'ok' : 'ko');
    box.querySelector('b').textContent = ok ? 'Réussi !' : (reason === 'cancel' ? 'Annulé' : 'Raté');
    box.querySelector('span').textContent = ok ? 'Le résultat est vérifié…' : (reason === 'time' ? 'Temps écoulé' : reason === 'cancel' ? '' : 'Trop d\'erreurs');
    const res = { id: S.cfg.id, ok, done: S.done, mistakes: S.mistakes, ms: Math.round(performance.now() - S.t0), cancelled: reason === 'cancel', reason: reason || null };
    setTimeout(() => { if (MG.cur === S) close(); post('mgResult', res); if (MG.onResult) MG.onResult(res); }, ok ? 650 : 900);
  }

  function close() {
    cancelAnimationFrame(raf); raf = 0;
    root.classList.remove('on');
    MG.cur = null;
    D.parts.length = 0;
  }

  MG.start = (cfg) => {
    if (MG.cur) close();
    const game = MG.games[cfg.type];
    if (!game) { post('mgResult', { id: cfg.id, ok: false, done: 0, mistakes: 0, ms: 0, cancelled: true, reason: 'type' }); return; }
    const th = THEMES[cfg.drug] || THEMES.weed;
    root.querySelector('.mg-panel').style.setProperty('--a', th.a.join(', '));
    $('.mg-ico').textContent = cfg.icon || th.icon;
    $('.mg-head small').textContent = `${th.name}${cfg.step ? ' · ' + cfg.step : ''}`;
    $('.mg-head b').textContent = cfg.title || '';
    $('.mg-end').className = 'mg-end';
    const S = {
      cfg, x: cfg.extra || {}, r: rng(cfg.seed || 1), accent: th.a, done: 0, total: Math.max(1, cfg.count | 0), mistakes: 0, max: Math.max(0, cfg.maxMistakes | 0),
      t0: performance.now(), limit: Math.max(10, cfg.limit || 60) * 1000, ended: false, m: { x: W / 2, y: H / 2, down: false, px: W / 2, py: H / 2 }, key: {},
      lastMiss: 0,
      hit(n = 1) { if (S.ended) return; S.done = Math.min(S.total, S.done + n); refreshHud(S); if (S.done >= S.total) end(S, true); },
      miss(msg) {
        if (S.ended) return;
        const now = performance.now(); if (now - S.lastMiss < 450) return; S.lastMiss = now;
        S.mistakes++; refreshHud(S); toast(msg || 'Erreur', 'bad');
        root.querySelector('.mg-stage').animate([{ transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'none' }], { duration: 180 });
        if (S.mistakes > S.max) end(S, false, 'mistakes');
      },
      good(msg) { toast(msg, 'good'); },
      hint: setHint, toast,
    };
    setHint(cfg.hint || '');
    canvas.classList.toggle('cur', game.cursor === true);
    D.parts.length = 0;
    S.g = game.init(S, D) || {};
    MG.cur = S;
    refreshHud(S);
    root.classList.add('on');
    let last = performance.now();
    const loop = (now) => {
      if (MG.cur !== S) return;
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      if (!S.ended) {
        const left = S.limit - (now - S.t0);
        const ratio = Math.max(0, left / S.limit);
        $('.mg-timer .fg').setAttribute('stroke-dashoffset', String(125.66 * (1 - ratio)));
        $('.mg-timer span').textContent = Math.max(0, Math.ceil(left / 1000));
        $('.mg-timer').classList.toggle('low', ratio < 0.2);
        if (left <= 0) end(S, false, 'time');
        if (game.update) game.update(S, dt, D);
      }
      g.save(); game.draw(S, g, D, dt); g.restore();
      D.stepParts(g, dt);
      if (game.cursor !== true && game.drawCursor) game.drawCursor(S, g, D);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
  };

  MG.stop = () => { if (MG.cur) close(); };

  // ---------------------------------------------------------------- entrées
  function pos(e) {
    const r = canvas.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * W, y: ((e.clientY - r.top) / r.height) * H };
  }
  canvas.addEventListener('pointerdown', (e) => {
    const S = MG.cur; if (!S || S.ended) return;
    const p = pos(e); S.m.px = S.m.x; S.m.py = S.m.y; S.m.x = p.x; S.m.y = p.y; S.m.down = true;
    try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* rien */ }
    const game = MG.games[S.cfg.type]; if (game.down) game.down(S, p.x, p.y, D);
  });
  canvas.addEventListener('pointermove', (e) => {
    const S = MG.cur; if (!S) return;
    const p = pos(e); S.m.px = S.m.x; S.m.py = S.m.y; S.m.x = p.x; S.m.y = p.y;
    if (S.ended) return;
    const game = MG.games[S.cfg.type]; if (game.move) game.move(S, p.x, p.y, D);
  });
  const up = (e) => {
    const S = MG.cur; if (!S || !S.m.down) return;
    S.m.down = false;
    if (S.ended) return;
    const p = e ? pos(e) : { x: S.m.x, y: S.m.y };
    const game = MG.games[S.cfg.type]; if (game.up) game.up(S, p.x, p.y, D);
  };
  canvas.addEventListener('pointerup', up);
  canvas.addEventListener('pointercancel', up);
  window.addEventListener('blur', () => up(null));
  window.addEventListener('keydown', (e) => {
    const S = MG.cur; if (!S) return;
    if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); end(S, false, 'cancel'); return; }
    if (S.key[e.code]) return; S.key[e.code] = true;
    const game = MG.games[S.cfg.type]; if (!S.ended && game.key) game.key(S, e.code, true, D);
  });
  window.addEventListener('keyup', (e) => {
    const S = MG.cur; if (!S) return; S.key[e.code] = false;
    const game = MG.games[S.cfg.type]; if (!S.ended && game.key) game.key(S, e.code, false, D);
  });
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'mg:start') MG.start(d.game || {});
    else if (d.action === 'mg:stop') MG.stop();
  });
})();
