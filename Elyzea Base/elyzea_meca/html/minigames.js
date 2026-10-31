/* =====================================================================
   ELYZEA MÉCANO - mini-jeux d'installation
   bolts  : serrer les vis (maintenir le clic sur chaque vis)
   align  : glisser la pièce sur son gabarit, puis clipser
   wires  : brancher chaque fil sur la borne de sa couleur
   gauge  : clé dynamométrique (cliquer / Espace quand l'aiguille est dans la zone verte)
   wheels : une seule partie pour toutes les roues demandées (écrous de chaque roue)
   paint  : pulvériser la carrosserie (la couleur avance sur le véhicule en direct)
   film   : poser le film teinté sur les vitres
   Simples, rapides, sans pénalité ; Échap ou ✕ : annuler ; jamais ouverts plus de « timeout ».
   ===================================================================== */
const MG = { cur: null };
(() => {
  const root = () => $('#minigame');
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  let progT = 0;

  function frame(m, body, hint) {
    root().innerHTML = `<div class="mg-card">
      <div class="mg-head">${icon(m.icon || 'service')}<div><div class="eyebrow">Installation</div><h3>${esc(m.label)}</h3>
        <small>${(m.parts || []).map(esc).join(' · ')}</small></div><button class="icon-btn" data-mg="cancel" title="Annuler (Échap)">✕</button></div>
      <div class="mg-body" id="mgBody">${body}</div>
      <div class="mg-foot"><div class="mg-hint" id="mgHint">${hint}</div><div class="mg-prog"><i id="mgBar"></i></div><span class="mono" id="mgPct">0%</span><span class="mono mg-time" id="mgTime"></span></div></div>`;
    root().classList.remove('hidden');
  }
  // Avancement : barre + envoi au jeu (peinture progressive, suivi du client)
  function progress(p, force) {
    const g = MG.cur; if (!g) return;
    p = clamp(p, 0, 1);
    if (p < g.p && !force) return;
    g.p = p;
    const bar = $('#mgBar'), pct = $('#mgPct');
    if (bar) bar.style.width = `${Math.round(p * 100)}%`;
    if (pct) pct.textContent = `${Math.round(p * 100)}%`;
    const now = Date.now();
    if (force || now - progT > 90) { progT = now; post('mgProgress', { id: g.id, p }); }
  }
  function hint(t) { const h = $('#mgHint'); if (h) h.innerHTML = t; }
  function finish(ok, reason) {
    const g = MG.cur; if (!g || g.done) return;
    g.done = true;
    clearInterval(g.timer); cancelAnimationFrame(g.raf);
    if (ok) { progress(1, true); root().querySelector('.mg-card').classList.add('win'); }
    setTimeout(() => {
      if (MG.cur !== g) return;
      post('mgDone', { id: g.id, ok, reason });
      MG.close(g.id);
    }, ok ? 650 : 0);
  }
  MG.finish = finish;

  /* ---------- Vis : maintenir le clic sur chaque vis ---------- */
  function bolts(m) {
    const n = 5;
    const pos = [[18, 22], [82, 22], [50, 50], [18, 78], [82, 78]];
    frame(m, `<div class="mg-panel"><div class="part-plate">${icon(m.icon || 'service', 'ico ghost')}</div>
      ${pos.slice(0, n).map((p, i) => `<button class="bolt" data-bolt="${i}" style="left:${p[0]}%;top:${p[1]}%"><svg viewBox="0 0 40 40"><circle class="track" cx="20" cy="20" r="16"/><circle class="fill" cx="20" cy="20" r="16"/><path d="M14 20h12M20 14v12"/></svg></button>`).join('')}</div>`,
      'Maintenez le clic sur chaque vis pour la serrer.');
    const done = new Set();
    let hold = null;
    const body = $('#mgBody');
    const step = () => {
      if (!hold) return;
      const k = clamp((Date.now() - hold.t) / 420, 0, 1);
      hold.el.style.setProperty('--k', k);
      progress((done.size + k) / n);
      if (k >= 1) {
        done.add(hold.i); hold.el.classList.add('tight'); hold.el.style.setProperty('--k', 1); hold = null;
        if (done.size >= n) return finish(true);
      } else MG.cur.raf = requestAnimationFrame(step);
    };
    body.addEventListener('mousedown', (e) => {
      const b = e.target.closest('[data-bolt]'); if (!b || done.has(Number(b.dataset.bolt))) return;
      hold = { el: b, i: Number(b.dataset.bolt), t: Date.now() }; step();
    });
    const up = () => { if (hold) { hold.el.style.setProperty('--k', 0); hold = null; } };
    body.addEventListener('mouseup', up); body.addEventListener('mouseleave', up);
  }

  /* ---------- Pièce à aligner puis clipser ---------- */
  function align(m) {
    const rear = m.part === 'rear';
    frame(m, `<div class="mg-panel align">
      <svg class="car-face" viewBox="0 0 400 200"><path d="M60 150V95l40-45h200l40 45v55z" class="body"/><path d="M110 60h180l25 30H85z" class="glass"/>
        ${rear ? '<rect x="80" y="100" width="60" height="16" rx="4" class="lamp red"/><rect x="260" y="100" width="60" height="16" rx="4" class="lamp red"/>' : '<rect x="80" y="100" width="60" height="16" rx="4" class="lamp"/><rect x="260" y="100" width="60" height="16" rx="4" class="lamp"/>'}</svg>
      <div class="slot" id="mgSlot"></div>
      <div class="bumper" id="mgPart">${rear ? 'Pare-chocs arrière' : 'Pare-chocs avant'}</div>
      ${[0, 1, 2].map((i) => `<button class="clip hidden" data-clip="${i}" style="left:${30 + i * 20}%"></button>`).join('')}</div>`,
      'Glissez le pare-chocs sur son emplacement.');
    const part = $('#mgPart'), slot = $('#mgSlot'), panel = part.parentElement;
    let drag = null, placed = false; const clips = new Set();
    part.addEventListener('mousedown', (e) => { if (placed) return; const r = part.getBoundingClientRect(); drag = { dx: e.clientX - r.left, dy: e.clientY - r.top }; part.classList.add('drag'); });
    document.addEventListener('mousemove', MG.cur.move = (e) => {
      if (!drag || placed) return;
      const pr = panel.getBoundingClientRect();
      part.style.left = `${e.clientX - pr.left - drag.dx}px`; part.style.top = `${e.clientY - pr.top - drag.dy}px`;
      const a = part.getBoundingClientRect(), b = slot.getBoundingClientRect();
      const d = Math.hypot(a.left - b.left, a.top - b.top);
      slot.classList.toggle('near', d < 60);
      progress(clamp(1 - d / 400, 0, 0.5) * 0.9);
    });
    document.addEventListener('mouseup', MG.cur.up = () => {
      if (!drag || placed) return; drag = null; part.classList.remove('drag');
      const a = part.getBoundingClientRect(), b = slot.getBoundingClientRect();
      if (Math.hypot(a.left - b.left, a.top - b.top) < 40) {
        placed = true; part.classList.add('placed'); part.style.left = slot.style.left || `${slot.offsetLeft}px`; part.style.top = `${slot.offsetTop}px`;
        panel.querySelectorAll('.clip').forEach((c) => c.classList.remove('hidden'));
        progress(0.5); hint('Cliquez les 3 agrafes pour fixer la pièce.');
      } else hint('Presque : déposez le pare-chocs dans le cadre en pointillés.');
    });
    panel.addEventListener('click', (e) => {
      const c = e.target.closest('[data-clip]'); if (!c || !placed) return;
      clips.add(c.dataset.clip); c.classList.add('on'); progress(0.5 + clips.size / 6);
      if (clips.size >= 3) finish(true);
    });
  }

  /* ---------- Fils de couleur ---------- */
  function wires(m) {
    const cols = [['#ef4444', 'Rouge'], ['#3b82f6', 'Bleu'], ['#eab308', 'Jaune'], ['#22c55e', 'Vert']];
    const right = cols.map((c, i) => i).sort(() => Math.random() - 0.5);
    frame(m, `<div class="mg-panel wires"><svg class="wire-svg" id="mgWires"></svg>
      <div class="w-col left">${cols.map((c, i) => `<button class="w-end" data-wl="${i}" style="--c:${c[0]}" title="${c[1]}"></button>`).join('')}</div>
      <div class="w-col right">${right.map((i) => `<button class="w-end term" data-wr="${i}" style="--c:${cols[i][0]}" title="${cols[i][1]}"></button>`).join('')}</div></div>`,
      'Cliquez un fil à gauche, puis la borne de la même couleur à droite.');
    let pick = null; const done = new Set();
    const svg = $('#mgWires'), panel = svg.parentElement;
    const draw = () => {
      const pr = panel.getBoundingClientRect();
      svg.innerHTML = [...done].map((i) => {
        const a = panel.querySelector(`[data-wl="${i}"]`).getBoundingClientRect(), b = panel.querySelector(`[data-wr="${i}"]`).getBoundingClientRect();
        const x1 = a.left + a.width / 2 - pr.left, y1 = a.top + a.height / 2 - pr.top, x2 = b.left + b.width / 2 - pr.left, y2 = b.top + b.height / 2 - pr.top;
        return `<path d="M${x1} ${y1} C ${(x1 + x2) / 2} ${y1}, ${(x1 + x2) / 2} ${y2}, ${x2} ${y2}" stroke="${cols[i][0]}" />`;
      }).join('');
    };
    panel.addEventListener('click', (e) => {
      const l = e.target.closest('[data-wl]'), r = e.target.closest('[data-wr]');
      if (l && !done.has(Number(l.dataset.wl))) { panel.querySelectorAll('.w-end.pick').forEach((x) => x.classList.remove('pick')); pick = Number(l.dataset.wl); l.classList.add('pick'); return; }
      if (r && pick !== null) {
        if (Number(r.dataset.wr) === pick) {
          done.add(pick); panel.querySelector(`[data-wl="${pick}"]`).classList.add('ok'); r.classList.add('ok'); pick = null; draw();
          progress(done.size / cols.length);
          if (done.size >= cols.length) finish(true);
        } else { r.classList.add('shake'); setTimeout(() => r.classList.remove('shake'), 350); hint('Pas la bonne borne : suivez la couleur du fil.'); }
      }
    });
  }

  /* ---------- Clé dynamométrique ---------- */
  function gauge(m) {
    const need = 3;
    frame(m, `<div class="mg-panel gauge"><div class="torque"><div class="zone" id="mgZone"></div><div class="needle" id="mgNeedle"></div></div>
      <div class="hits" id="mgHits">${Array.from({ length: need }, () => '<i></i>').join('')}</div>
      <button class="btn primary big" data-g="hit">Serrer</button></div>`,
      'Cliquez « Serrer » (ou Espace) quand l\'aiguille est dans la zone verte.');
    const g = MG.cur; let x = 0, dir = 1, hits = 0, zone = { a: 0.38, w: 0.24 };
    const zEl = $('#mgZone'), nEl = $('#mgNeedle');
    const place = () => { zEl.style.left = `${zone.a * 100}%`; zEl.style.width = `${zone.w * 100}%`; };
    place();
    let last = performance.now();
    const loop = (t) => {
      const dt = Math.min(0.05, (t - last) / 1000); last = t;
      x += dir * dt * (0.55 + hits * 0.12);
      if (x > 1) { x = 1; dir = -1; } if (x < 0) { x = 0; dir = 1; }
      nEl.style.left = `${x * 100}%`;
      g.raf = requestAnimationFrame(loop);
    };
    g.raf = requestAnimationFrame(loop);
    g.hit = () => {
      if (g.done) return;
      if (x >= zone.a && x <= zone.a + zone.w) {
        hits += 1; $('#mgHits').children[hits - 1].classList.add('on'); progress(hits / need);
        if (hits >= need) return finish(true);
        zone = { a: 0.1 + Math.random() * 0.6, w: Math.max(0.14, zone.w - 0.04) }; place();
      } else { nEl.classList.add('miss'); setTimeout(() => nEl.classList.remove('miss'), 300); hint('Un peu tôt ou trop tard : réessayez, sans pénalité.'); }
    };
    $('#mgBody').addEventListener('click', (e) => { if (e.target.closest('[data-g="hit"]')) g.hit(); });
  }

  /* ---------- Roues : une partie pour toutes les roues demandées ---------- */
  function wheels(m) {
    const stages = (m.stages && m.stages.length) ? m.stages : [{ label: 'avant gauche' }];
    const nuts = 5;
    frame(m, `<div class="mg-panel wheel"><div class="w-stage" id="mgStage"></div><div class="rim" id="mgRim">
      <svg viewBox="0 0 200 200"><circle cx="100" cy="100" r="92" class="tyre"/><circle cx="100" cy="100" r="62" class="disc"/><circle cx="100" cy="100" r="16" class="hub"/></svg>
      ${Array.from({ length: nuts }, (_, i) => { const a = (i / nuts) * Math.PI * 2 - Math.PI / 2; return `<button class="nut" data-nut="${i}" style="left:${50 + Math.cos(a) * 21}%;top:${50 + Math.sin(a) * 21}%"></button>`; }).join('')}</div>
      <div class="w-dots">${stages.map((s, i) => `<i data-ws="${i}"></i>`).join('')}</div></div>`,
      'Passez sur chaque écrou en gardant le clic enfoncé (ou cliquez-les).');
    let st = 0, got = new Set(), down = false, busy = false;
    const stageEl = $('#mgStage'), rim = $('#mgRim');
    const start = () => {
      got = new Set(); busy = false;
      rim.querySelectorAll('.nut').forEach((n) => n.classList.remove('off'));
      rim.classList.remove('swap');
      stageEl.innerHTML = `Roue <b>${esc(stages[st].label)}</b> <span class="mono">(${st + 1}/${stages.length})</span>`;
      post('mgStage', { id: MG.cur.id, stage: st + 1, phase: 'off' });   // pneu retiré sur le véhicule
    };
    const nut = (el) => {
      if (busy || !el) return; const i = Number(el.dataset.nut); if (got.has(i)) return;
      got.add(i); el.classList.add('off');
      progress((st + got.size / nuts * 0.9) / stages.length);
      if (got.size >= nuts) {
        busy = true; rim.classList.add('swap');
        setTimeout(() => {
          post('mgStage', { id: MG.cur.id, stage: st + 1, phase: 'on' });   // roue neuve remontée
          $(`[data-ws="${st}"]`, root()).classList.add('on');
          st += 1; progress(st / stages.length);
          if (st >= stages.length) return finish(true);
          start();
        }, 550);
      }
    };
    rim.addEventListener('mousedown', (e) => { down = true; nut(e.target.closest('[data-nut]')); });
    rim.addEventListener('mouseover', (e) => { if (down) nut(e.target.closest('[data-nut]')); });
    document.addEventListener('mouseup', MG.cur.up = () => { down = false; });
    start();
  }

  /* ---------- Peinture / film teinté : couvrir la surface ---------- */
  const CAR = 'M30 160 L40 120 Q60 110 120 104 L170 70 Q190 60 230 60 L320 62 Q350 64 380 100 L460 108 Q490 112 495 140 L495 165 Q490 172 470 172 L30 172 Z';
  const GLASS = 'M178 76 Q192 68 226 68 L270 68 L272 104 L140 106 Z M282 68 L318 70 Q342 72 366 102 L284 104 Z';
  function cover(m, film) {
    frame(m, `<div class="mg-panel paint"><canvas id="mgCanvas" width="520" height="220"></canvas>
      <div class="swatch"><span style="background:${esc(m.from || '#777')}"></span>→<span style="background:${esc(m.to || (film ? '#111' : '#38bdf8'))}"></span></div></div>`,
      film ? 'Maintenez le clic et lissez le film sur les vitres.' : 'Maintenez le clic et balayez la carrosserie : la couleur apparaît sur le véhicule en direct.');
    const cv = $('#mgCanvas'), ctx = cv.getContext('2d');
    const path = new Path2D(film ? GLASS : CAR);
    const to = m.to || (film ? '#101418' : '#38bdf8'), from = m.from || '#6b7280';
    // Grille de couverture : seules les cases à l'intérieur de la forme comptent
    const cell = 8, cols = Math.ceil(cv.width / cell), rows = Math.ceil(cv.height / cell);
    const inside = [], hit = new Uint8Array(cols * rows);
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) if (ctx.isPointInPath(path, x * cell + cell / 2, y * cell + cell / 2)) inside.push(y * cols + x);
    const total = inside.length || 1; let covered = 0;
    const base = () => {
      ctx.clearRect(0, 0, cv.width, cv.height);
      if (film) { ctx.fillStyle = '#334155'; ctx.fill(new Path2D(CAR)); }
      ctx.fillStyle = film ? '#9fb7d6' : from; ctx.fill(path);
      ctx.strokeStyle = 'rgba(148,178,230,.55)'; ctx.lineWidth = 2; ctx.stroke(path);
    };
    base();
    const brush = film ? 30 : 26;
    const spray = (x, y) => {
      ctx.save(); ctx.clip(path);
      const gr = ctx.createRadialGradient(x, y, 2, x, y, brush);
      gr.addColorStop(0, to); gr.addColorStop(1, `${to}00`);
      ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(x, y, brush, 0, Math.PI * 2); ctx.fill(); ctx.restore();
      const r = Math.ceil(brush * 0.8 / cell);
      const cx = Math.floor(x / cell), cy = Math.floor(y / cell);
      for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        const gx = cx + dx, gy = cy + dy; if (gx < 0 || gy < 0 || gx >= cols || gy >= rows) continue;
        if (dx * dx + dy * dy > r * r) continue;
        const k = gy * cols + gx; if (!hit[k] && ctx.isPointInPath(path, gx * cell + cell / 2, gy * cell + cell / 2)) { hit[k] = 1; covered += 1; }
      }
      const p = covered / total;
      progress(p >= 0.95 ? 1 : p);
      if (p >= 0.95) { ctx.fillStyle = to; ctx.fill(path); finish(true); }
    };
    let down = false;
    const at = (e) => { const r = cv.getBoundingClientRect(); return [(e.clientX - r.left) * cv.width / r.width, (e.clientY - r.top) * cv.height / r.height]; };
    cv.addEventListener('mousedown', (e) => { down = true; spray(...at(e)); });
    cv.addEventListener('mousemove', (e) => { if (down && !MG.cur.done) spray(...at(e)); });
    document.addEventListener('mouseup', MG.cur.up = () => { down = false; });
  }

  const GAMES = { bolts, align, wires, gauge, wheels, paint: (m) => cover(m, false), film: (m) => cover(m, true) };

  MG.open = (m) => {
    MG.close();
    MG.cur = { id: m.id, p: 0, done: false, game: m.game };
    (GAMES[m.game] || bolts)(m);
    // Délai maximum : le mini-jeu ne reste jamais ouvert
    const end = Date.now() + (m.timeout || 120) * 1000;
    const g = MG.cur;
    g.timer = setInterval(() => {
      const left = Math.max(0, Math.ceil((end - Date.now()) / 1000));
      const t = $('#mgTime'); if (t) t.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
      if (left <= 0) finish(false, 'timeout');
    }, 250);
  };
  MG.close = (id) => {
    const g = MG.cur;
    if (!g || (id && g.id !== id)) { if (!g) root().classList.add('hidden'); return; }
    clearInterval(g.timer); cancelAnimationFrame(g.raf);
    if (g.move) document.removeEventListener('mousemove', g.move);
    if (g.up) document.removeEventListener('mouseup', g.up);
    MG.cur = null;
    root().classList.add('hidden'); root().innerHTML = '';
  };
  MG.cancel = () => { if (MG.cur && !MG.cur.done) finish(false, 'cancel'); };

  root().addEventListener('click', (e) => { if (e.target.closest('[data-mg="cancel"]')) MG.cancel(); });
  document.addEventListener('keydown', (e) => {
    if (!MG.cur) return;
    if (e.code === 'Space' && MG.cur.hit) { e.preventDefault(); MG.cur.hit(); }
  });
})();
