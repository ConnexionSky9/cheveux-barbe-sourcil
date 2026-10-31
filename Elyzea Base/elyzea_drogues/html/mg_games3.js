/* =====================================================================
   ELYZEA DROGUES · mini-jeux (3/3) : pâte à gâteau, cuisson au four
   batter : attraper le sac indiqué, le glisser au-dessus de la casserole et verser la bonne quantité
   oven   : régler le thermostat sur la température demandée et la tenir jusqu'à la cuisson complète
   Comme les autres mini-jeux : S.hit() par objectif réussi, S.miss() par erreur ; le serveur revérifie.
   ===================================================================== */
(() => {
  const MG = window.ElyMG, D = MG.D, W = D.W, H = D.H, TAU = Math.PI * 2;

  // Couleurs des ingrédients (sac, contenu versé)
  const ING = {
    flour:  { bag: [244, 239, 228], edge: [156, 143, 116], fill: [246, 240, 225], tag: [59, 125, 216], shape: 'sack' },
    sugar:  { bag: [247, 247, 251], edge: [139, 147, 168], fill: [252, 252, 255], tag: [226, 69, 60], shape: 'box' },
    yeast:  { bag: [242, 201, 76], edge: [163, 125, 18], fill: [232, 196, 110], tag: [224, 181, 74], shape: 'sachet' },
    milk:   { bag: [255, 255, 255], edge: [125, 138, 160], fill: [250, 250, 245], tag: [90, 160, 242], shape: 'carton' },
    shroom: { bag: [167, 139, 250], edge: [109, 76, 190], fill: [150, 110, 70], tag: [226, 69, 60], shape: 'sachet' },
  };
  const ingOf = (it) => ING[it.color] || ING.flour;

  // ================================================================= PÂTE À GÂTEAU
  const POT = { x: 230, y: 300, rx: 120, ry: 34 };
  const bagHome = (i) => ({ x: 410 + i * 76, y: 112 });

  function drawBag(g, it, x, y, tilt, alpha, active) {
    const c = ingOf(it);
    g.save(); g.translate(x, y); g.rotate(tilt); g.globalAlpha = alpha;
    if (active) { g.shadowColor = 'rgba(253,224,71,.8)'; g.shadowBlur = 18; }
    g.fillStyle = D.rgba(c.bag, 1); g.strokeStyle = D.rgba(c.edge, 1); g.lineWidth = 3;
    if (c.shape === 'sack') { D.rr(g, -24, -34, 48, 66, 10); g.fill(); g.stroke(); g.shadowBlur = 0; g.fillStyle = D.rgba(c.tag, 1); D.rr(g, -15, -8, 30, 22, 4); g.fill(); }
    else if (c.shape === 'box') { g.fillRect(-22, -30, 44, 60); g.strokeRect(-22, -30, 44, 60); g.shadowBlur = 0; g.fillStyle = D.rgba(c.tag, 1); g.fillRect(-16, -6, 32, 16); }
    else if (c.shape === 'carton') { g.beginPath(); g.moveTo(-18, -18); g.lineTo(0, -36); g.lineTo(18, -18); g.lineTo(18, 32); g.lineTo(-18, 32); g.closePath(); g.fill(); g.stroke(); g.shadowBlur = 0; g.fillStyle = D.rgba(c.tag, 1); g.fillRect(-18, 0, 36, 18); }
    else { D.rr(g, -22, -24, 44, 50, 6); g.fill(); g.stroke(); g.shadowBlur = 0; g.fillStyle = D.rgba(c.tag, 0.9); g.beginPath(); g.arc(0, 2, 10, 0, TAU); g.fill(); }
    g.restore();
  }

  MG.games.batter = {
    init(S) {
      const list = (S.x.ingredients && S.x.ingredients.length ? S.x.ingredients : [{ label: 'Farine', grams: 200, unit: 'g', color: 'flour' }]).slice(0, 6);
      const st = { list, idx: 0, amt: 0, flow: 0, lag: 0, held: false, pouring: false, bx: 0, by: 0, stable: 0, pause: 0, done: [], batches: 0, mix: 0 };
      const h = bagHome(0); st.bx = h.x; st.by = h.y;
      return st;
    },
    cur(S) { return S.g.list[S.g.idx]; },
    tol(it) { return Math.max(2, it.grams * 0.08); },
    rate(it) { return Math.max(4, it.grams / 2.4); },
    overPot(st) { return Math.abs(st.bx - POT.x) < POT.rx - 15 && st.by < POT.y - 30 && st.by > POT.y - 240; },
    down(S, x, y) {
      const st = S.g; if (st.pause > 0) return;
      const h = bagHome(st.idx);
      if (D.dist(x, y, h.x, h.y) < 42 || D.dist(x, y, st.bx, st.by) < 42) { st.held = true; st.bx = x; st.by = y; }
    },
    move(S, x, y) { const st = S.g; if (st.held) { st.bx = x; st.by = y; } },
    up(S) { const st = S.g; if (!st.held) return; st.held = false; if (st.pouring) st.lag = st.flow * 0.15; st.pouring = false; },
    update(S, dt) {
      const st = S.g, it = this.cur(S); if (!it) return;
      if (st.pause > 0) st.pause -= dt;
      if (!st.held) { const h = bagHome(st.idx); st.bx += (h.x - st.bx) * Math.min(1, dt * 10); st.by += (h.y - st.by) * Math.min(1, dt * 10); }
      const was = st.pouring;
      st.pouring = st.held && st.pause <= 0 && this.overPot(st);
      if (was && !st.pouring) st.lag = st.flow * 0.15;
      if (st.pouring) { const r = this.rate(it); st.flow = Math.min(r, st.flow + r * 1.6 * dt); st.amt += st.flow * dt; }
      else { st.flow = 0; if (st.lag > 0) { const d = Math.min(st.lag, it.grams * 0.4 * dt + 0.5 * dt); st.amt += d; st.lag -= d; } }
      const tol = this.tol(it);
      if (st.amt > it.grams + tol) {
        S.miss(`Trop de ${it.label.toLowerCase()} ! On retire et on recommence`);
        st.amt = 0; st.flow = 0; st.lag = 0; st.pouring = false; st.held = false; st.pause = 0.7; st.stable = 0; return;
      }
      if (!st.pouring && st.lag <= 0.0001 && Math.abs(st.amt - it.grams) <= tol) {
        st.stable += dt;
        if (st.stable > 0.45) {
          st.done.push(st.amt); st.mix += 1; st.idx++; st.amt = 0; st.stable = 0; S.hit();
          D.burst(POT.x, POT.y - 20, D.rgba(ingOf(it).fill, 0.9), 10, 90, 3, 300);
          if (st.idx >= st.list.length) { st.batches++; S.good('Pâte prête !'); if (!S.ended) { st.idx = 0; st.done = []; } }
          const h = bagHome(st.idx); if (!st.held) { st.bx = h.x; st.by = h.y; }
        }
      } else st.stable = 0;
    },
    draw(S, g) {
      const st = S.g, it = this.cur(S);
      D.bg(g, 'wood', S.accent);
      // plan de travail
      g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, 360, W, 80);
      // casserole : manche, corps, contenu
      g.save();
      g.fillStyle = '#2b2f36'; D.rr(g, POT.x + POT.rx - 6, POT.y + 6, 150, 18, 8); g.fill();
      g.fillStyle = '#3a404a'; g.beginPath(); g.moveTo(POT.x - POT.rx, POT.y); g.lineTo(POT.x - POT.rx + 12, POT.y + 80); g.quadraticCurveTo(POT.x, POT.y + 100, POT.x + POT.rx - 12, POT.y + 80); g.lineTo(POT.x + POT.rx, POT.y); g.closePath(); g.fill();
      const total = st.list.length, lvl = D.clamp((st.idx + (it ? Math.min(1, st.amt / it.grams) : 0)) / total, 0, 1);
      g.fillStyle = '#1d2128'; g.beginPath(); g.ellipse(POT.x, POT.y, POT.rx, POT.ry, 0, 0, TAU); g.fill();
      if (lvl > 0) { g.fillStyle = D.rgba(D.mix([246, 240, 225], [200, 160, 110], Math.min(1, st.idx / Math.max(1, total - 1))), 0.95); g.beginPath(); g.ellipse(POT.x, POT.y + 4, (POT.rx - 12) * (0.55 + 0.45 * lvl), (POT.ry - 8) * (0.55 + 0.45 * lvl), 0, 0, TAU); g.fill(); }
      g.strokeStyle = '#8b93a8'; g.lineWidth = 5; g.beginPath(); g.ellipse(POT.x, POT.y, POT.rx, POT.ry, 0, 0, TAU); g.stroke();
      g.restore();
      // filet versé
      if (st.pouring && it) {
        const c = ingOf(it);
        const sx = st.bx - 30, sy = st.by - 12;   // ouverture du sac penché
        g.strokeStyle = D.rgba(c.fill, 0.85); g.lineCap = 'round'; g.lineWidth = 2 + Math.min(4, st.flow / this.rate(it) * 4);
        g.beginPath(); g.moveTo(sx, sy); g.quadraticCurveTo(sx - 6, (sy + POT.y) / 2, sx - 4, POT.y); g.stroke();
        if (Math.random() < 0.6) D.burst(sx - 4, POT.y, D.rgba(c.fill, 0.9), 1, 40, 2, 300);
      }
      // sacs
      st.list.forEach((x, i) => {
        if (i === st.idx) return;
        const h = bagHome(i), done = i < st.idx;
        drawBag(g, x, h.x, h.y, 0, done ? 0.3 : 0.75, false);
        D.label(g, done ? '✓' : `${i + 1}`, h.x, h.y + 48, { size: 12, color: done ? '#86efac' : '#94a3b8' });
      });
      if (it) drawBag(g, it, st.bx, st.by, st.pouring ? -1.1 : (st.held ? -0.25 : 0), 1, !st.held);
      // pesée
      if (it) {
        const tol = this.tol(it), max = it.grams * 1.45;
        g.fillStyle = 'rgba(7,10,18,.72)'; D.rr(g, 400, 200, 330, 120, 14); g.fill(); g.strokeStyle = D.rgba(S.accent, 0.5); g.lineWidth = 2; g.stroke();
        D.label(g, `${st.idx + 1}/${st.list.length} · ${it.label}`, 565, 222, { size: 15 });
        D.label(g, `${Math.round(st.amt)} / ${it.grams} ${it.unit || 'g'}`, 565, 254, { size: 24, weight: 800, color: Math.abs(st.amt - it.grams) <= tol ? '#86efac' : '#f8fafc' });
        D.gauge(g, 420, 286, 290, 12, st.amt / max, (it.grams - tol) / max, (it.grams + tol) / max, S.accent, (it.grams + tol) / max);
      }
      D.label(g, st.held ? (st.pouring ? 'Versement… relâche pile sur la quantité' : 'Glisse le sac au-dessus de la casserole') : 'Attrape le sac en surbrillance', 230, 410, { size: 13, color: '#cbd5e1' });
      D.label(g, `Pâtes : ${st.batches}`, 70, 26, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= CUISSON AU FOUR
  const KNOB = { x: 600, y: 205, r: 62 };
  const TMIN = 50, TMAX = 260;
  MG.games.oven = {
    init(S) {
      const target = Number(S.x.target) || 180, tol = Number(S.x.tol) || 10, bake = Math.max(3, Number(S.x.bake) || 12);
      return { target, tol, bake, set: 100, T: 25, prog: 0, burn: 0, drag: false, dy: 0, cakes: 0, ev: 5 + S.r() * 4, msg: 0 };
    },
    clampSet(st) { st.set = Math.round(D.clamp(st.set, TMIN, TMAX) / 5) * 5; },
    down(S, x, y) {
      const st = S.g;
      if (D.dist(x, y, KNOB.x, KNOB.y) < KNOB.r + 10) { st.drag = true; st.dy = y; st.base = st.set; return; }
      if (D.dist(x, y, KNOB.x - 80, KNOB.y + 110) < 26) { st.set -= 10; this.clampSet(st); }
      if (D.dist(x, y, KNOB.x + 80, KNOB.y + 110) < 26) { st.set += 10; this.clampSet(st); }
    },
    move(S, x, y) { const st = S.g; if (st.drag) { st.set = st.base + (st.dy - y); this.clampSet(st); } },
    up(S) { S.g.drag = false; },
    key(S, code, on) { if (!on) return; const st = S.g; if (code === 'ArrowUp' || code === 'ArrowRight') st.set += 5; if (code === 'ArrowDown' || code === 'ArrowLeft') st.set -= 5; this.clampSet(st); },
    wheel(S, dy) { const st = S.g; st.set += dy < 0 ? 5 : -5; this.clampSet(st); },
    update(S, dt) {
      const st = S.g;
      // le four suit le thermostat avec du retard, et bouge un peu tout seul
      st.T += (st.set - st.T) * Math.min(1, 0.9 * dt) + (Math.random() - 0.5) * 4 * dt;
      st.ev -= dt;
      if (st.ev <= 0) {
        st.ev = 5 + S.r() * 5;
        if (S.r() < 0.5) { st.T -= 22; S.toast('Porte entrouverte : ça refroidit', 'bad'); } else { st.T += 22; S.toast('La résistance s\'emballe !', 'bad'); }
      }
      const lo = st.target - st.tol, hi = st.target + st.tol;
      if (st.T >= lo && st.T <= hi) { st.prog += dt / st.bake; st.burn = Math.max(0, st.burn - dt * 0.25); }
      else if (st.T > hi) {
        st.burn += dt * (0.25 + (st.T - hi) / 40);
        if (st.burn >= 1) { st.burn = 0; st.prog = Math.max(0, st.prog - 0.3); S.miss('Le gâteau brûle ! Baisse le thermostat'); }
      }
      if (st.prog >= 1) {
        st.prog = 0; st.cakes++; st.T -= 30; S.good('Gâteau bien cuit !'); S.hit();
        D.burst(300, 210, 'rgba(255,220,150,.9)', 14, 120, 3, 300);
      }
    },
    draw(S, g) {
      const st = S.g, lo = st.target - st.tol, hi = st.target + st.tol;
      D.bg(g, 'dark', S.accent);
      // four
      g.save(); g.translate(300, 230);
      g.fillStyle = '#c9ccd3'; D.rr(g, -200, -150, 400, 300, 18); g.fill(); g.strokeStyle = '#6b7280'; g.lineWidth = 4; g.stroke();
      g.fillStyle = '#9ca3af'; D.rr(g, -200, -150, 400, 40, 18); g.fill();
      const heat = D.clamp((st.T - 25) / 230, 0, 1);
      g.fillStyle = D.rgba(D.mix([30, 32, 38], [120, 50, 20], heat), 1); D.rr(g, -165, -90, 330, 190, 12); g.fill();
      g.fillStyle = `rgba(255,${120 + heat * 80},40,${0.15 + heat * 0.35})`; D.rr(g, -165, -90, 330, 190, 12); g.fill();
      g.strokeStyle = '#4b5563'; g.lineWidth = 6; D.rr(g, -165, -90, 330, 190, 12); g.stroke();
      // grille + gâteau qui monte et dore
      g.strokeStyle = 'rgba(200,200,200,.5)'; g.lineWidth = 2; g.beginPath(); g.moveTo(-150, 60); g.lineTo(150, 60); g.stroke();
      const rise = 18 + st.prog * 32, brown = D.mix([235, 205, 150], [175, 105, 45], Math.min(1, st.prog * 1.1));
      const cake = st.burn > 0.55 ? D.mix(brown, [40, 30, 25], (st.burn - 0.55) / 0.45) : brown;
      g.fillStyle = '#6b7280'; g.fillRect(-80, 40, 160, 20);
      g.fillStyle = D.rgba(cake, 1); g.beginPath(); g.moveTo(-76, 42); g.quadraticCurveTo(0, 42 - rise * 2, 76, 42); g.closePath(); g.fill();
      if (st.burn > 0.4) for (let i = 0; i < 3; i++) { const t = (performance.now() / 900 + i * 0.33) % 1; g.fillStyle = `rgba(60,60,60,${0.5 * (1 - t)})`; g.beginPath(); g.arc(-30 + i * 30, -10 - t * 70, 8 + t * 12, 0, TAU); g.fill(); }
      g.fillStyle = '#4b5563'; D.rr(g, -120, 112, 240, 14, 7); g.fill();
      g.restore();
      // thermomètre du four
      const tx = 40, ty0 = 70, th = 300, ty = (v) => ty0 + th - ((v - TMIN) / (TMAX - TMIN)) * th;
      D.rr(g, tx - 14, ty0, 28, th, 14); g.fillStyle = 'rgba(148,178,230,.12)'; g.fill();
      g.fillStyle = D.rgba(S.accent, 0.4); g.fillRect(tx - 14, ty(hi), 28, ty(lo) - ty(hi));
      const cur = D.clamp(st.T, TMIN, TMAX);
      g.fillStyle = D.rgba(D.mix([96, 165, 250], [248, 113, 113], (cur - TMIN) / (TMAX - TMIN)), 1); D.rr(g, tx - 6, ty(cur), 12, ty0 + th - ty(cur), 6); g.fill();
      // thermostat (bouton)
      g.save(); g.translate(KNOB.x, KNOB.y);
      g.fillStyle = '#1f2937'; g.beginPath(); g.arc(0, 0, KNOB.r + 14, 0, TAU); g.fill();
      for (let v = TMIN; v <= TMAX; v += 30) { const a = -Math.PI * 1.25 + ((v - TMIN) / (TMAX - TMIN)) * Math.PI * 1.5; g.strokeStyle = 'rgba(255,255,255,.45)'; g.lineWidth = 2; g.beginPath(); g.moveTo(Math.cos(a) * (KNOB.r + 4), Math.sin(a) * (KNOB.r + 4)); g.lineTo(Math.cos(a) * (KNOB.r + 12), Math.sin(a) * (KNOB.r + 12)); g.stroke(); }
      const at = -Math.PI * 1.25 + ((st.target - TMIN) / (TMAX - TMIN)) * Math.PI * 1.5;
      g.strokeStyle = D.rgba(S.accent, 1); g.lineWidth = 6; g.beginPath(); g.arc(0, 0, KNOB.r + 8, at - 0.08, at + 0.08); g.stroke();
      const a = -Math.PI * 1.25 + ((st.set - TMIN) / (TMAX - TMIN)) * Math.PI * 1.5;
      const grd = g.createRadialGradient(-15, -15, 5, 0, 0, KNOB.r); grd.addColorStop(0, '#e5e7eb'); grd.addColorStop(1, '#6b7280');
      g.fillStyle = grd; g.beginPath(); g.arc(0, 0, KNOB.r, 0, TAU); g.fill();
      g.strokeStyle = '#111827'; g.lineWidth = 6; g.beginPath(); g.moveTo(0, 0); g.lineTo(Math.cos(a) * (KNOB.r - 10), Math.sin(a) * (KNOB.r - 10)); g.stroke();
      g.restore();
      [['−', -80], ['+', 80]].forEach(([t, dx]) => { g.fillStyle = 'rgba(148,178,230,.18)'; g.beginPath(); g.arc(KNOB.x + dx, KNOB.y + 110, 24, 0, TAU); g.fill(); D.label(g, t, KNOB.x + dx, KNOB.y + 110, { size: 22, weight: 800 }); });
      D.label(g, `Thermostat : ${st.set} °C`, KNOB.x, KNOB.y + 150, { size: 15, weight: 800 });
      D.label(g, `Cible : ${st.target} °C`, KNOB.x, 50, { size: 16, weight: 800, color: D.rgba(S.accent, 1) });
      const inZone = st.T >= lo && st.T <= hi;
      D.label(g, `Four : ${Math.round(st.T)} °C`, KNOB.x, 76, { size: 14, color: inZone ? '#86efac' : st.T > hi ? '#fca5a5' : '#93c5fd' });
      D.label(g, inZone ? 'Cuisson en cours' : st.T > hi ? 'Trop chaud : ça brûle !' : 'Pas assez chaud', KNOB.x, 392, { size: 13, color: inZone ? '#86efac' : '#fca5a5' });
      D.ring(g, 300, 410, 16, st.prog, D.rgba(S.accent, 1));
      D.label(g, `Cuisson ${Math.round(st.prog * 100)} %`, 380, 410, { size: 13, align: 'left' });
      D.label(g, `Gâteaux cuits : ${st.cakes}`, 90, 26, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // Molette : thermostat du four (le moteur ne transmet pas la molette)
  const cv = document.querySelector('#mg canvas');
  if (cv) cv.addEventListener('wheel', (e) => {
    const S = MG.cur; if (!S || S.ended) return;
    const game = MG.games[S.cfg.type]; if (!game || !game.wheel) return;
    e.preventDefault(); game.wheel(S, e.deltaY);
  }, { passive: false });
})();
