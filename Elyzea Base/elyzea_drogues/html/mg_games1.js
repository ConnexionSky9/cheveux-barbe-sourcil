/* =====================================================================
   ELYZEA DROGUES · mini-jeux (1/2) : effeuillage, séchage, broyage, roulage, pesée, blister
   ===================================================================== */
(() => {
  const MG = window.ElyMG, D = MG.D, W = D.W, H = D.H, TAU = Math.PI * 2;

  // ================================================================= EFFEUILLAGE (cannabis, assis à la table)
  // Une vraie fleur de cannabis (calices, pistils, trichomes) entourée de petites feuilles : on attrape chaque feuille
  // et on la tire vers l'extérieur pour la décrocher. Pincer la fleur ou tirer de travers = erreur.
  const BW = 260, BH = 380;                 // taille du dessin de la fleur
  const budW = (t) => (t < 0 ? 0 : t > 1 ? 0 : 82 * Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.08 + 0.02)), 0.62) * (0.55 + 0.45 * t));
  MG.games.trim = {
    init(S) {
      const per = Math.max(3, S.x.per || 6);
      const buds = [];
      let left = S.total;
      while (left > 0) { const n = Math.min(per, left); buds.push(n); left -= n; }
      const st = { buds, idx: 0, bud: null, slide: 0, jar: 0, fall: [], grab: null };
      st.make = () => this.makeBud(S, st, buds[st.idx]);
      st.make();
      return st;
    },
    // ---- dessin de la fleur (une fois par tête, dans une image hors écran)
    makeBud(S, st, n) {
      const r = S.r, cx = W / 2 - 70, cy = H / 2 + 5;
      const tint = { purple: [110, 50, 150] }[S.x.tint] || null;
      const cv = document.createElement('canvas'); cv.width = BW; cv.height = BH;
      const g = cv.getContext('2d'), x0 = BW / 2, top = 28, hgt = BH - 70;
      const Y = (t) => top + t * hgt;
      // tige
      g.strokeStyle = '#6b5a32'; g.lineWidth = 7; g.beginPath(); g.moveTo(x0, Y(0.9)); g.lineTo(x0 + 4, BH - 6); g.stroke();
      // silhouette sombre (profondeur)
      g.beginPath(); for (let t = 0; t <= 1.001; t += 0.02) g.lineTo(x0 + budW(t) * 0.95, Y(t)); for (let t = 1; t >= -0.001; t -= 0.02) g.lineTo(x0 - budW(t) * 0.95, Y(t));
      g.closePath(); g.fillStyle = tint ? '#2c1f36' : '#24401c'; g.fill();
      // calices (gouttes serrées, orientées vers l'extérieur et le haut)
      const calyx = [];
      for (let i = 0; i < 360; i++) {
        const t = Math.pow(r(), 0.9), w = budW(t);
        if (w < 4) continue;
        const u = (r() * 2 - 1);
        calyx.push({ x: x0 + u * w * 0.9, y: Y(t) + (r() - 0.5) * 6, s: 6 + r() * 6 * (0.6 + w / 82 * 0.5), a: -Math.PI / 2 + u * 0.9 + (r() - 0.5) * 0.6, t });
      }
      calyx.sort((p, q) => q.t - p.t);                 // le bas d'abord, le haut par-dessus
      for (const c of calyx) {
        g.save(); g.translate(c.x, c.y); g.rotate(c.a + Math.PI / 2);
        let light = [178, 214, 128], dark = [52, 96, 40];
        if (tint) { const k = r(); light = k < 0.55 ? [196, 140, 222] : [170, 196, 120]; dark = k < 0.55 ? [72, 34, 98] : [58, 70, 44]; }
        const grd = g.createLinearGradient(0, -c.s, 0, c.s * 0.8);
        grd.addColorStop(0, D.rgba(light, 1)); grd.addColorStop(0.55, D.rgba(D.mix(light, dark, 0.5), 1)); grd.addColorStop(1, D.rgba(dark, 1));
        g.fillStyle = grd;
        g.beginPath(); g.moveTo(0, -c.s); g.bezierCurveTo(c.s * 0.95, -c.s * 0.55, c.s * 0.85, c.s * 0.75, 0, c.s * 0.8); g.bezierCurveTo(-c.s * 0.85, c.s * 0.75, -c.s * 0.95, -c.s * 0.55, 0, -c.s); g.fill();
        g.strokeStyle = 'rgba(20,40,14,.35)'; g.lineWidth = 0.8; g.stroke();
        g.restore();
      }
      // pistils (poils orange recourbés)
      for (let i = 0; i < 130; i++) {
        const c = calyx[Math.floor(r() * calyx.length)]; if (!c) continue;
        const a = c.a + (r() - 0.5) * 0.9, len = 8 + r() * 12, bend = (r() - 0.5) * 14;
        const col = r() < 0.65 ? 'rgba(222,128,48,.95)' : 'rgba(170,92,40,.95)';
        g.strokeStyle = col; g.lineWidth = 1.1 + r() * 0.6; g.lineCap = 'round';
        const sx = c.x + Math.cos(a) * c.s * 0.6, sy = c.y + Math.sin(a) * c.s * 0.6;
        g.beginPath(); g.moveTo(sx, sy); g.quadraticCurveTo(sx + Math.cos(a) * len * 0.5 + bend * Math.sin(a), sy + Math.sin(a) * len * 0.5 - bend * Math.cos(a), sx + Math.cos(a) * len, sy + Math.sin(a) * len); g.stroke();
      }
      // trichomes (givre de résine), plus denses en haut
      for (let i = 0; i < 1100; i++) {
        const t = 0.08 + Math.pow(r(), 0.9) * 0.92, w = budW(t); if (w < 3) continue;
        const x = x0 + (r() * 2 - 1) * w * 0.95, y = Y(t) + (r() - 0.5) * 8;
        g.fillStyle = `rgba(245,250,240,${0.2 + r() * 0.5})`; g.beginPath(); g.arc(x, y, 0.5 + r() * 0.8, 0, TAU); g.fill();
      }
      // ombrage des bords (volume)
      g.globalCompositeOperation = 'source-atop';
      const sh = g.createRadialGradient(x0 - 18, Y(0.45), 20, x0, Y(0.5), 150);
      sh.addColorStop(0, 'rgba(255,255,230,.10)'); sh.addColorStop(0.6, 'rgba(0,0,0,0)'); sh.addColorStop(1, 'rgba(0,0,0,.45)');
      g.fillStyle = sh; g.fillRect(0, 0, BW, BH);
      g.globalCompositeOperation = 'source-over';
      // petites feuilles (sugar leaves) : sortent des flancs, base cachée sous la fleur
      const leaves = [];
      for (let i = 0; i < n; i++) {
        const side = i % 2 ? 1 : -1;
        const t = 0.14 + ((i + 0.5) / n) * 0.74 + (r() - 0.5) * 0.06;
        const w = budW(t);
        const a = side > 0 ? -0.45 + r() * 0.75 : Math.PI + 0.45 - r() * 0.75;
        const L = 46 + r() * 26;
        const bx = cx + side * w * 0.6, by = cy - BH / 2 + 40 + Y(t) - 40 + 10;
        leaves.push({ bx, by, a, L, img: this.leafImg(S, L, tint), pull: 0, gone: false });
      }
      st.bud = { cx, cy, img: cv, leaves, left: n, x0: cx - BW / 2, y0: cy - BH / 2 + 10, top, hgt };
      st.slide = 1;
    },
    // feuille composée (5 folioles dentelées, givrées), dessinée une fois
    leafImg(S, L, tint) {
      const r = S.r, c = document.createElement('canvas'); c.width = Math.ceil(L * 2.2); c.height = Math.ceil(L * 1.6);
      const g = c.getContext('2d'); const ox = 6, oy = c.height / 2;
      let col = [46, 92, 38], vein = [104, 150, 78];
      if (tint) { col = [62, 70, 52]; vein = [140, 100, 160]; }
      const folio = (ang, len, wid) => {
        g.save(); g.translate(ox + 12, oy); g.rotate(ang);
        g.beginPath(); g.moveTo(0, 0);
        const N = 9;
        for (let i = 1; i <= N; i++) { const t = i / N, ww = Math.sin(Math.PI * Math.pow(t, 0.8)) * wid * (i % 2 ? 1 : 0.72); g.lineTo(t * len, -ww); }
        for (let i = N; i >= 1; i--) { const t = i / N, ww = Math.sin(Math.PI * Math.pow(t, 0.8)) * wid * (i % 2 ? 1 : 0.72); g.lineTo(t * len, ww); }
        g.closePath();
        const grd = g.createLinearGradient(0, 0, len, 0); grd.addColorStop(0, D.rgba(D.mix(col, [20, 40, 14], 0.3), 1)); grd.addColorStop(1, D.rgba(D.mix(col, vein, 0.25), 1));
        g.fillStyle = grd; g.fill();
        g.strokeStyle = D.rgba(vein, 0.9); g.lineWidth = 1; g.beginPath(); g.moveTo(0, 0); g.lineTo(len * 0.95, 0); g.stroke();
        for (let i = 0; i < len * 0.6; i++) { g.fillStyle = `rgba(240,248,235,${0.3 + r() * 0.5})`; g.fillRect(r() * len * 0.8, (r() - 0.5) * wid, 1.2, 1.2); }
        g.restore();
      };
      // pétiole
      g.strokeStyle = D.rgba(D.mix(col, [140, 160, 90], 0.4), 1); g.lineWidth = 2.5; g.beginPath(); g.moveTo(ox, oy); g.lineTo(ox + 14, oy); g.stroke();
      folio(-0.95, L * 0.5, 5); folio(0.95, L * 0.5, 5); folio(-0.45, L * 0.78, 6.5); folio(0.45, L * 0.78, 6.5); folio(0, L, 8);
      return { c, ox, oy };
    },
    leafPos(l) { const k = l.pull * 0.65; return [l.bx + Math.cos(l.a) * k, l.by + Math.sin(l.a) * k]; },
    // point où l'on attrape la feuille (milieu de la foliole centrale)
    grip(l) { const [x, y] = this.leafPos(l); return [x + Math.cos(l.a) * (14 + l.L * 0.55), y + Math.sin(l.a) * (14 + l.L * 0.55)]; },
    onBud(b, x, y) {
      const t = (y - (b.y0 + b.top)) / b.hgt; return t >= 0 && t <= 1 && Math.abs(x - b.cx) < budW(t) * 0.9;
    },
    down(S, x, y) {
      const st = S.g, b = st.bud; if (!b || st.slide !== 0) return;
      for (let i = b.leaves.length - 1; i >= 0; i--) {
        const l = b.leaves[i]; if (l.gone) continue;
        const [lx, ly] = this.leafPos(l);
        const tx = lx + Math.cos(l.a) * (l.L + 12), ty = ly + Math.sin(l.a) * (l.L + 12);
        const sx = lx + Math.cos(l.a) * 16, sy = ly + Math.sin(l.a) * 16;
        if (D.segDist(x, y, sx, sy, tx, ty) < 15) { st.grab = { l, x0: x, y0: y }; return; }
      }
      if (this.onBud(b, x, y)) S.miss('Ne pince pas la fleur !');
    },
    move(S, x, y) {
      const st = S.g, gr = st.grab; if (!gr || !S.m.down) return;
      const l = gr.l, dx = x - gr.x0, dy = y - gr.y0;
      const along = dx * Math.cos(l.a) + dy * Math.sin(l.a), side = Math.abs(-dx * Math.sin(l.a) + dy * Math.cos(l.a));
      l.pull = D.clamp(along, 0, 70);
      if (side > 50 && along < 40) { st.grab = null; S.miss('Tire dans le sens de la feuille'); return; }
      if (along > 56) {
        const [lx, ly] = this.leafPos(l);
        l.gone = true; st.grab = null; st.bud.left--;
        st.fall.push({ l, x: lx, y: ly, vx: Math.cos(l.a) * 220 + dx * 2, vy: Math.sin(l.a) * 160 - 60, rot: 0, vr: (Math.random() - 0.5) * 7, t: 0 });
        D.burst(l.bx, l.by, 'rgba(235,245,225,.85)', 7, 70, 1.4, 200);
        S.hit();
        if (st.bud.left <= 0) { st.slide = -0.0001; S.good('Fleur effeuillée'); }
      }
    },
    up(S) { const st = S.g; st.grab = null; },
    update(S, dt) {
      const st = S.g;
      if (st.bud) for (const l of st.bud.leaves) if (!l.gone && (!st.grab || st.grab.l !== l)) l.pull = Math.max(0, l.pull - dt * 260);
      if (st.slide > 0) st.slide = Math.max(0, st.slide - dt * 2.4);
      else if (st.slide < 0) { st.slide -= dt * 2.4; if (st.slide < -1) { st.jar++; st.idx++; if (st.idx < st.buds.length) st.make(); else st.bud = null; } }
      for (let i = st.fall.length - 1; i >= 0; i--) { const f = st.fall[i]; f.t += dt; f.vy += 600 * dt; f.vx *= 0.98; f.x += f.vx * dt; f.y += f.vy * dt; f.rot += f.vr * dt; if (f.t > 1.6) st.fall.splice(i, 1); }
    },
    drawLeaf(g, l, x, y, a) {
      g.save(); g.translate(x, y); g.rotate(a); g.drawImage(l.img.c, -l.img.ox, -l.img.oy); g.restore();
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'wood', S.accent);
      // plateau de manucure
      g.fillStyle = '#c9c2b3'; D.rr(g, 70, 40, 400, 370, 22); g.fill();
      g.fillStyle = '#b8b0a0'; D.rr(g, 84, 54, 372, 342, 16); g.fill();
      // bocal de têtes manucurées
      const jx = W - 130, jy = H - 160;
      g.fillStyle = 'rgba(210,235,255,.07)'; D.rr(g, jx - 58, jy - 70, 116, 170, 20); g.fill(); g.strokeStyle = 'rgba(210,235,255,.4)'; g.lineWidth = 2; g.stroke();
      g.fillStyle = '#3b3b3b'; D.rr(g, jx - 52, jy - 84, 104, 18, 6); g.fill();
      for (let i = 0; i < Math.min(st.jar, 9); i++) { const bx = jx - 30 + (i % 3) * 30, by = jy + 78 - Math.floor(i / 3) * 26; const grd = g.createRadialGradient(bx - 4, by - 4, 2, bx, by, 14); grd.addColorStop(0, '#a9cf7c'); grd.addColorStop(1, '#3f6a2e'); g.fillStyle = grd; g.beginPath(); g.ellipse(bx, by, 12, 15, 0.3, 0, TAU); g.fill(); }
      D.label(g, `Bocal : ${st.jar}`, jx, jy - 102, { size: 12, color: '#cbd5e1' });
      // feuilles retirées (tombent sur le plateau)
      for (const f of st.fall) { g.save(); g.globalAlpha = Math.max(0, 1 - f.t / 1.6); this.drawLeaf(g, f.l, f.x, f.y, f.l.a + f.rot); g.restore(); }
      const b = st.bud; if (!b) return;
      const ox = st.slide > 0 ? -st.slide * 460 : st.slide < 0 ? -st.slide * 520 : 0;
      g.save(); g.translate(ox, st.slide < 0 ? st.slide * 60 : 0);
      // ombre portée
      g.fillStyle = 'rgba(0,0,0,.28)'; g.beginPath(); g.ellipse(b.cx + 14, b.cy + 168, 80, 16, 0, 0, TAU); g.fill();
      // feuilles encore attachées (sous la fleur), puis la fleur
      for (const l of b.leaves) {
        if (l.gone) continue;
        const [x, y] = this.leafPos(l);
        const stretch = l.pull > 0 ? 1 + l.pull / 300 : 1;
        g.save(); g.translate(x, y); g.rotate(l.a); g.scale(stretch, 1); g.drawImage(l.img.c, -l.img.ox, -l.img.oy); g.restore();
      }
      g.drawImage(b.img, b.x0, b.y0);
      // repères discrets : où attraper
      if (st.slide === 0) for (const l of b.leaves) {
        if (l.gone || (st.grab && st.grab.l === l)) continue;
        const [gx, gy] = this.grip(l); const pulse = 0.25 + Math.sin(performance.now() / 300 + l.a * 3) * 0.15;
        g.strokeStyle = `rgba(255,255,255,${pulse})`; g.lineWidth = 1.5; g.setLineDash([3, 4]); g.beginPath(); g.arc(gx, gy, 10, 0, TAU); g.stroke(); g.setLineDash([]);
      }
      g.restore();
      D.label(g, `Tête ${Math.min(st.idx + 1, st.buds.length)} / ${st.buds.length} · feuilles restantes : ${b.left}`, 270, 24, { size: 12, color: '#e2e8f0' });
    },
    drawCursor(S, g) { // doigts qui pincent
      const { x, y } = S.m, pinch = !!S.g.grab;
      g.save(); g.translate(x, y);
      g.fillStyle = '#f1d3b8'; g.strokeStyle = 'rgba(60,30,10,.6)'; g.lineWidth = 1.2;
      const gap = pinch ? 3 : 9;
      g.beginPath(); g.ellipse(-gap, -2, 6, 10, -0.25, 0, TAU); g.fill(); g.stroke();
      g.beginPath(); g.ellipse(gap, 2, 6, 10, 0.25, 0, TAU); g.fill(); g.stroke();
      g.restore();
    },
  };

  // ================================================================= SÉCHAGE (accrocher / étaler, puis régler la ventilation ou la lampe)
  MG.games.hang = {
    init(S) {
      const skin = S.cfg.skin || 'weed';
      const n = Math.max(1, S.total - 1);
      const items = [], spots = [];
      const grid = skin === 'crack' || skin === 'keta';
      for (let i = 0; i < n; i++) items.push({ x: 70 + (i % 3) * 52, y: 120 + Math.floor(i / 3) * 56, hx: 70 + (i % 3) * 52, hy: 120 + Math.floor(i / 3) * 56, at: null, r: S.r() });
      const cols = grid ? Math.min(5, Math.max(3, Math.ceil((n + 2) / 2))) : n + 2;
      for (let i = 0; i < n + 2; i++) {
        if (grid) spots.push({ x: 330 + (i % cols) * 78, y: 150 + Math.floor(i / cols) * 90, used: false });
        else spots.push({ x: 300 + (i * 400) / (n + 1), y: 110 + Math.sin(i * 0.9) * 6, used: false });
      }
      return { skin, grid, items, spots, drag: null, phase: 'hang', fan: 0.2, needle: 0.2, band: [0.55, 0.75], ok: 0, red: 0, drift: 0 };
    },
    down(S, x, y) {
      const st = S.g;
      if (st.phase === 'hang') { const it = st.items.find((i) => !i.at && D.dist(x, y, i.x, i.y) < 26); if (it) st.drag = it; }
      else if (Math.abs(y - 360) < 26 && x > 250 && x < 650) { st.knob = true; st.fan = D.clamp((x - 270) / 360, 0, 1); }
    },
    move(S, x, y) {
      const st = S.g;
      if (st.drag) { st.drag.x = x; st.drag.y = y; }
      if (st.knob && S.m.down) st.fan = D.clamp((x - 270) / 360, 0, 1);
    },
    up(S, x, y) {
      const st = S.g; st.knob = false;
      const it = st.drag; st.drag = null; if (!it) return;
      const sp = st.spots.find((s) => !s.used && D.dist(x, y, s.x, s.y + (st.grid ? 0 : 40)) < 40);
      if (sp) {
        sp.used = true; it.at = sp; it.x = sp.x; it.y = sp.y + (st.grid ? 0 : 42);
        S.hit();
        if (st.items.every((i) => i.at)) { st.phase = 'tune'; S.hint(st.grid ? 'Règle la lampe : garde l\'aiguille dans la zone verte jusqu\'au bout.' : 'Règle la ventilation : garde l\'humidité dans la zone verte jusqu\'au bout.'); }
      } else { it.x = it.hx; it.y = it.hy; }
    },
    update(S, dt) {
      const st = S.g; if (st.phase !== 'tune') return;
      st.drift += dt;
      const target = st.fan + Math.sin(st.drift * 1.3) * 0.12 + Math.sin(st.drift * 3.1) * 0.05;
      st.needle += (target - st.needle) * Math.min(1, dt * 3);
      if (Math.floor(st.drift / 3.5) !== st.lastShift) { st.lastShift = Math.floor(st.drift / 3.5); const c = 0.3 + S.r() * 0.45; st.band = [c, c + 0.2]; }
      const inb = st.needle >= st.band[0] && st.needle <= st.band[1];
      if (inb) { st.ok += dt; st.red = 0; } else { st.red += dt; if (st.red > 1.6) { st.red = 0; st.ok = Math.max(0, st.ok - 1); S.miss(st.grid ? 'Trop ou pas assez de chaleur' : 'Humidité hors de la zone'); } }
      if (st.ok >= 3) { st.phase = 'done'; S.hit(); }
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, st.grid ? 'lab' : 'dark', S.accent);
      // bac de départ
      g.fillStyle = 'rgba(255,255,255,.05)'; D.rr(g, 30, 80, 180, 260, 16); g.fill(); g.strokeStyle = 'rgba(255,255,255,.12)'; g.stroke();
      D.label(g, 'Bac', 120, 66, { size: 12, color: '#94a3b8' });
      if (st.grid) {
        g.fillStyle = 'rgba(148,163,184,.12)'; D.rr(g, 290, 100, 440, 220, 14); g.fill(); g.strokeStyle = 'rgba(148,163,184,.3)'; g.stroke();
        for (const s of st.spots) { g.strokeStyle = s.used ? D.rgba(S.accent, 0.6) : 'rgba(255,255,255,.18)'; g.setLineDash([4, 4]); g.strokeRect(s.x - 30, s.y - 30, 60, 60); g.setLineDash([]); }
        // lampe chauffante
        g.fillStyle = '#334155'; g.fillRect(500, 20, 6, 60); g.fillStyle = `rgba(255,${180 - st.fan * 80},80,${0.25 + st.fan * 0.5})`; g.beginPath(); g.ellipse(503, 86, 60, 16, 0, 0, TAU); g.fill();
      } else {
        g.strokeStyle = '#94a3b8'; g.lineWidth = 3; g.beginPath(); g.moveTo(270, 104); for (const s of st.spots) g.lineTo(s.x, s.y); g.lineTo(730, 104); g.stroke();
        for (const s of st.spots) { g.strokeStyle = '#cbd5e1'; g.lineWidth = 2; g.beginPath(); g.moveTo(s.x, s.y); g.lineTo(s.x, s.y + 22); g.arc(s.x + 5, s.y + 22, 5, Math.PI, 0, true); g.stroke(); }
        // ventilateur
        g.save(); g.translate(690, 330); g.strokeStyle = '#64748b'; g.lineWidth = 3; g.beginPath(); g.arc(0, 0, 42, 0, TAU); g.stroke();
        g.rotate((performance.now() / 1000) * (2 + st.fan * 14)); g.fillStyle = 'rgba(148,163,184,.7)'; for (let i = 0; i < 3; i++) { g.rotate(TAU / 3); g.beginPath(); g.ellipse(0, -20, 9, 18, 0, 0, TAU); g.fill(); } g.restore();
      }
      for (const it of st.items) this.item(S, g, it);
      if (st.phase !== 'hang') {
        D.label(g, st.grid ? 'Puissance de la lampe' : 'Ventilation', 450, 330, { size: 12, color: '#cbd5e1' });
        D.rr(g, 270, 352, 360, 12, 6); g.fillStyle = 'rgba(148,178,230,.15)'; g.fill();
        g.fillStyle = D.rgba(S.accent, 1); g.beginPath(); g.arc(270 + st.fan * 360, 358, 12, 0, TAU); g.fill();
        D.gauge(g, 270, 300 - 30, 360, 10, st.needle, st.band[0], st.band[1], S.accent);
        D.label(g, st.grid ? 'Température des cristaux' : 'Humidité', 450, 250, { size: 12, color: '#cbd5e1' });
        D.ring(g, 720, 40, 18, st.ok / 3, D.rgba(S.accent, 1));
      }
    },
    item(S, g, it) {
      const skin = S.g.skin;
      g.save(); g.translate(it.x, it.y);
      if (skin === 'mush') { g.fillStyle = '#e8dcc3'; g.fillRect(-4, -4, 8, 18); g.fillStyle = '#9a7650'; g.beginPath(); g.ellipse(0, -6, 16, 10, 0, Math.PI, TAU); g.fill(); }
      else if (skin === 'crack') { g.fillStyle = '#e9dcc0'; g.beginPath(); for (let i = 0; i < 7; i++) { const a = (i / 7) * TAU, r = 15 + Math.sin(i * 3 + it.r * 9) * 5; g.lineTo(Math.cos(a) * r, Math.sin(a) * r); } g.closePath(); g.fill(); }
      else if (skin === 'keta') { g.fillStyle = 'rgba(220,210,255,.9)'; for (let i = 0; i < 5; i++) { g.beginPath(); g.moveTo(-14 + i * 7, 10); g.lineTo(-10 + i * 7, -12 - (i % 2) * 5); g.lineTo(-6 + i * 7, 10); g.fill(); } }
      else { for (let i = 0; i < 5; i++) { g.fillStyle = D.rgba(D.mix([110, 170, 80], [40, 90, 30], i / 5), 1); g.beginPath(); g.arc(Math.sin(i * 1.9) * 5, i * 6 - 10, 11 - i, 0, TAU); g.fill(); } }
      g.restore();
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= BROYAGE (moulin à weed / manivelle à coca / mortier)
  MG.games.grind = {
    init(S) { return { ang: 0, acc: 0, speed: 0, heat: 0, prev: null, turns: 0, max: S.x.maxSpeed || 2.2, min: S.x.minSpeed || 0.5 }; },
    move(S, x, y) {
      const st = S.g, cx = W / 2 - 60, cy = H / 2 + 10;
      const a = Math.atan2(y - cy, x - cx);
      if (!S.m.down || D.dist(x, y, cx, cy) < 30) { st.prev = null; return; }
      if (st.prev !== null) {
        let d = a - st.prev; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU;
        st.inst = (st.inst || 0) + Math.abs(d);
        st.ang += d;
        if (st.speed <= st.max) { st.acc += Math.abs(d); if (st.acc >= TAU) { st.acc -= TAU; st.turns++; D.burst(cx + (Math.random() - 0.5) * 60, cy + 70, S.cfg.skin === 'crank' ? 'rgba(90,140,70,.9)' : 'rgba(230,230,240,.9)', 6, 80, 2); S.hit(); } }
      }
      st.prev = a;
    },
    up(S) { S.g.prev = null; },
    update(S, dt) {
      const st = S.g;
      const inst = (st.inst || 0) / TAU / Math.max(dt, 0.001); st.inst = 0;
      st.speed += (inst - st.speed) * Math.min(1, dt * 6);
      if (st.speed > st.max) { st.heat += dt * 0.9; } else st.heat = Math.max(0, st.heat - dt * 0.5);
      if (st.heat >= 1) { st.heat = 0.2; st.acc = 0; S.miss(S.cfg.skin === 'mortar' ? 'Ça déborde du mortier !' : 'Trop vite : ça bourre !'); }
    },
    draw(S, g) {
      const st = S.g, cx = W / 2 - 60, cy = H / 2 + 10, skin = S.cfg.skin;
      D.bg(g, skin === 'crank' ? 'steel' : 'wood', S.accent);
      g.save(); g.translate(cx, cy);
      if (skin === 'mortar') {
        g.fillStyle = '#6b7280'; g.beginPath(); g.ellipse(0, 20, 130, 110, 0, 0, TAU); g.fill();
        g.fillStyle = '#374151'; g.beginPath(); g.ellipse(0, 10, 105, 85, 0, 0, TAU); g.fill();
        g.fillStyle = D.rgba(D.mix([235, 230, 245], S.accent, 0.2), 0.95); g.beginPath(); g.ellipse(0, 18, 80 - st.turns, 55, 0, 0, TAU); g.fill();
        g.rotate(st.ang); g.fillStyle = '#9ca3af'; g.beginPath(); g.ellipse(70, 0, 22, 16, 0, 0, TAU); g.fill();
      } else if (skin === 'crank') {
        g.fillStyle = '#475569'; D.rr(g, -120, -120, 240, 240, 24); g.fill();
        g.fillStyle = '#1e293b'; g.beginPath(); g.arc(0, 0, 95, 0, TAU); g.fill();
        g.rotate(st.ang); g.strokeStyle = '#94a3b8'; g.lineWidth = 10; g.beginPath(); for (let i = 0; i < 8; i++) { g.moveTo(0, 0); g.lineTo(Math.cos((i / 8) * TAU) * 85, Math.sin((i / 8) * TAU) * 85); } g.stroke();
        g.fillStyle = '#ef4444'; g.beginPath(); g.arc(85, 0, 16, 0, TAU); g.fill();
      } else {
        g.fillStyle = '#4b5563'; g.beginPath(); g.arc(0, 0, 125, 0, TAU); g.fill();
        g.fillStyle = '#9ca3af'; g.beginPath(); g.arc(0, 0, 110, 0, TAU); g.fill();
        g.rotate(st.ang); g.fillStyle = '#6b7280'; for (let i = 0; i < 24; i++) { g.save(); g.rotate((i / 24) * TAU); g.beginPath(); g.moveTo(98, -6); g.lineTo(110, 0); g.lineTo(98, 6); g.fill(); g.restore(); }
        g.fillStyle = D.rgba(S.accent, 0.35); g.beginPath(); g.arc(0, 0, 70, 0, TAU); g.fill();
        g.fillStyle = '#d1d5db'; g.beginPath(); g.arc(0, 0, 18, 0, TAU); g.fill();
      }
      g.restore();
      // jauge de vitesse
      const sv = D.clamp(st.speed / (st.max * 1.5), 0, 1);
      g.save(); g.translate(W - 120, H / 2 + 10);
      D.label(g, 'Vitesse', 0, -130, { size: 12, color: '#cbd5e1' });
      D.rr(g, -14, -110, 28, 220, 14); g.fillStyle = 'rgba(148,178,230,.12)'; g.fill();
      const zl = st.min / (st.max * 1.5), zh = st.max / (st.max * 1.5);
      g.fillStyle = D.rgba(S.accent, 0.35); g.fillRect(-14, 110 - zh * 220, 28, (zh - zl) * 220);
      g.fillStyle = 'rgba(248,113,113,.3)'; g.fillRect(-14, -110, 28, (1 - zh) * 220);
      g.fillStyle = '#fff'; g.fillRect(-20, 110 - sv * 220 - 2, 40, 4);
      g.fillStyle = `rgba(248,113,113,${st.heat})`; g.beginPath(); g.arc(0, 140, 10, 0, TAU); g.fill();
      g.restore();
      D.label(g, 'Tourne en maintenant le clic', cx, 28, { size: 12, color: '#cbd5e1' });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= ROULAGE (répartir, rouler sous tension, coller)
  MG.games.roll = {
    init(S) { return { phase: 0, pinches: [], spots: [0.25, 0.5, 0.75].map((f) => ({ f, ok: false })), m: 0.2, v: 0, zone: 0.5, zt: 0, fill: 0, out: 0, needle: 0, nd: 1, joints: 0 }; },
    reset(st) { st.phase = 0; st.spots.forEach((s) => { s.ok = false; }); st.fill = 0; st.out = 0; st.m = 0.2; st.v = 0; },
    down(S, x, y) {
      const st = S.g;
      if (st.phase === 0) {
        const s = st.spots.find((p) => !p.ok && D.dist(x, y, 180 + p.f * 400, 230) < 30);
        if (s) { s.ok = true; D.burst(180 + s.f * 400, 230, 'rgba(110,170,80,.9)', 8, 70, 2); if (st.spots.every((p) => p.ok)) { st.phase = 1; S.hit(); S.hint('Maintiens le clic pour rouler : garde le repère dans la zone verte.'); } }
        else if (y > 190 && y < 270 && x > 160 && x < 600) S.miss('À côté de la feuille');
      } else if (st.phase === 2) {
        if (Math.abs(st.needle - 0.5) < 0.07) { S.hit(); st.joints++; S.good('Joint roulé'); this.reset(st); S.hint('Répartis le cannabis : clique les 3 repères sur la feuille.'); }
        else S.miss('Collage raté');
      }
    },
    update(S, dt) {
      const st = S.g;
      if (st.phase === 1) {
        st.zt += dt; st.zone = 0.5 + Math.sin(st.zt * 0.9) * 0.28 + Math.sin(st.zt * 2.3) * 0.08;
        st.v += (S.m.down || S.key.Space ? 1.9 : -1.6) * dt; st.v *= 0.92; st.m = D.clamp(st.m + st.v * dt * 3, 0, 1);
        if (st.m === 0 || st.m === 1) st.v = 0;
        if (Math.abs(st.m - st.zone) < 0.09) { st.fill += dt / 2.6; st.out = 0; } else { st.fill = Math.max(0, st.fill - dt * 0.12); st.out += dt; }
        if (st.out > 1.5) { st.out = 0; st.fill = 0; S.miss('La feuille se déchire'); }
        if (st.fill >= 1) { st.phase = 2; S.hit(); S.hint('Colle la feuille : clique quand l\'aiguille passe au centre.'); }
      } else if (st.phase === 2) { st.needle += st.nd * dt * 0.9; if (st.needle > 1) { st.needle = 1; st.nd = -1; } if (st.needle < 0) { st.needle = 0; st.nd = 1; } }
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'wood', S.accent);
      // feuille à rouler
      const rollK = st.phase >= 1 ? st.fill : 0;
      g.fillStyle = '#f5f1e6'; D.rr(g, 160, 190 - (1 - rollK) * 40, 440, 80 * (1 - rollK * 0.6) + (1 - rollK) * 0, 6); g.fill();
      g.fillStyle = 'rgba(0,0,0,.06)'; g.fillRect(160, 196, 440, 3);
      for (const s of st.spots) {
        const x = 180 + s.f * 400;
        if (s.ok || st.phase > 0) { g.fillStyle = '#4d7c3a'; for (let i = 0; i < 14; i++) { g.beginPath(); g.arc(x + Math.sin(i * 2.1) * 26, 230 + Math.cos(i * 1.3) * 9, 3, 0, TAU); g.fill(); } }
        else { g.strokeStyle = D.rgba(S.accent, 0.8); g.setLineDash([4, 4]); g.lineWidth = 2; g.beginPath(); g.arc(x, 230, 24, 0, TAU); g.stroke(); g.setLineDash([]); }
      }
      if (st.phase >= 1) { g.fillStyle = '#efe9da'; D.rr(g, 160, 216, 440, 30 + (1 - rollK) * 10, 15); g.fill(); }
      if (st.phase === 1) {
        D.gauge(g, 160, 330, 440, 12, st.m, D.clamp(st.zone - 0.09, 0, 1), D.clamp(st.zone + 0.09, 0, 1), S.accent);
        D.label(g, 'Tension', 380, 360, { size: 12, color: '#cbd5e1' });
        D.ring(g, 680, 230, 26, st.fill, D.rgba(S.accent, 1));
      }
      if (st.phase === 2) { D.gauge(g, 160, 330, 440, 12, st.needle, 0.43, 0.57, S.accent); D.label(g, 'Colle !', 380, 360, { size: 12, color: '#cbd5e1' }); }
      D.label(g, `Joints : ${st.joints}`, 70, 26, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= PESÉE (verser au bon poids, fermer le sachet)
  MG.games.scale = {
    init(S) {
      const t = S.x.grams || 1.0, tol = S.x.tol || Math.max(0.05, t * 0.06);
      return { t, tol, w: 0, flow: 0, lag: 0, stable: 0, bags: 0, pour: false, skin: S.cfg.skin || 'powder' };
    },
    down(S, x, y) { if (x > 430 && x < 720 && y > 60 && y < 300) S.g.pour = true; },
    up(S) { const st = S.g; st.pour = false; st.lag = st.flow * 0.22; },
    key(S, code, on) { if (code === 'Space') { S.g.pour = on; if (!on) S.g.lag = S.g.flow * 0.22; } },
    update(S, dt) {
      const st = S.g;
      if (st.pour) { st.flow = Math.min(st.t * 0.9, st.flow + st.t * 0.8 * dt); st.w += st.flow * dt; }
      else { st.flow = 0; if (st.lag > 0) { const d = Math.min(st.lag, st.t * 0.35 * dt); st.w += d; st.lag -= d; } }
      if (Math.random() < (st.pour ? 0.9 : 0)) D.burst(560 + (Math.random() - 0.5) * 10, 200, this.color(S), 1, 30, 2, 600);
      if (st.w > st.t + st.tol) { st.w = 0; st.lag = 0; st.flow = 0; st.pour = false; st.stable = 0; S.miss('Trop lourd : on reverse et on recommence'); return; }
      if (!st.pour && st.lag <= 0.0001 && Math.abs(st.w - st.t) <= st.tol) { st.stable += dt; if (st.stable > 0.6) { st.bags++; st.w = 0; st.stable = 0; S.good('Sachet fermé'); S.hit(); } }
      else st.stable = 0;
    },
    color(S) { return { bud: 'rgba(90,150,70,.95)', powder: 'rgba(245,245,250,.95)', crystal: 'rgba(170,220,255,.95)', mush: 'rgba(160,120,80,.95)', keta: 'rgba(220,210,255,.95)' }[S.g.skin] || '#fff'; },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'steel', S.accent);
      // balance
      g.fillStyle = '#1f2937'; D.rr(g, 150, 250, 260, 120, 16); g.fill(); g.strokeStyle = '#374151'; g.lineWidth = 3; g.stroke();
      g.fillStyle = '#9ca3af'; D.rr(g, 165, 228, 230, 26, 8); g.fill();
      g.fillStyle = '#0b1220'; D.rr(g, 210, 290, 140, 48, 8); g.fill();
      const ok = Math.abs(st.w - st.t) <= st.tol;
      D.label(g, `${st.w.toFixed(2)} g`, 280, 314, { size: 24, color: ok ? D.rgba(S.accent, 1) : '#e2e8f0' });
      // sachet
      g.fillStyle = 'rgba(220,235,255,.18)'; g.strokeStyle = 'rgba(220,235,255,.5)'; g.lineWidth = 2;
      D.rr(g, 225, 120, 110, 108, 8); g.fill(); g.stroke();
      const k = D.clamp(st.w / (st.t * 1.2), 0, 1);
      g.fillStyle = this.color(S); D.rr(g, 232, 222 - k * 90, 96, k * 90, 6); g.fill();
      // pot à verser
      g.save(); g.translate(560, 150); g.rotate(st.pour ? -0.8 : -0.15);
      g.fillStyle = '#334155'; D.rr(g, -50, -60, 100, 120, 14); g.fill(); g.strokeStyle = D.rgba(S.accent, 0.6); g.lineWidth = 2; g.stroke();
      g.fillStyle = this.color(S); D.rr(g, -42, -10, 84, 62, 10); g.fill();
      g.restore();
      D.label(g, st.pour ? 'Versement…' : 'Maintiens le clic sur le pot', 560, 300, { size: 12, color: '#cbd5e1' });
      D.label(g, `Cible : ${st.t.toFixed(2)} g (± ${st.tol.toFixed(2)})`, 280, 395, { size: 13, color: '#cbd5e1' });
      D.label(g, `Sachets : ${st.bags}`, 70, 26, { size: 13 });
      if (st.stable > 0) D.ring(g, 280, 175, 70, st.stable / 0.6, D.rgba(S.accent, 1));
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= BLISTER / TRI DE PIÈCES (comprimés, cailloux, seringues)
  MG.games.count = {
    init(S) {
      const n = S.total, bad = Math.max(2, Math.round(n * 0.35));
      const items = [];
      for (let i = 0; i < n + bad; i++) items.push({ good: i < n, x: 0, y: 0, hx: 0, hy: 0, r: S.r(), placed: false });
      items.sort(() => S.r() - 0.5);
      items.forEach((it, i) => { it.hx = it.x = 70 + (i % 4) * 46 + (S.r() - 0.5) * 10; it.hy = it.y = 90 + Math.floor(i / 4) * 46 + (S.r() - 0.5) * 10; });
      const slots = []; const cols = Math.min(6, n);
      for (let i = 0; i < n; i++) slots.push({ x: 330 + (i % cols) * 62, y: 150 + Math.floor(i / cols) * 70, it: null });
      return { items, slots, drag: null, skin: S.cfg.skin || 'pills' };
    },
    down(S, x, y) { const it = S.g.items.find((i) => !i.placed && D.dist(x, y, i.x, i.y) < 20); if (it) S.g.drag = it; },
    move(S, x, y) { const it = S.g.drag; if (it) { it.x = x; it.y = y; } },
    up(S, x, y) {
      const st = S.g, it = st.drag; st.drag = null; if (!it) return;
      if (x > 610 && y > 300) { // poubelle
        if (it.good) { S.miss('Pièce correcte jetée'); it.x = it.hx; it.y = it.hy; } else { it.placed = true; it.x = -100; D.burst(670, 350, 'rgba(148,163,184,.8)', 6, 60, 2); }
        return;
      }
      const sl = st.slots.find((s) => !s.it && D.dist(x, y, s.x, s.y) < 30);
      if (!sl) { it.x = it.hx; it.y = it.hy; return; }
      if (!it.good) { S.miss(st.skin === 'rocks' ? 'Caillou trop petit' : 'Pièce abîmée'); it.x = it.hx; it.y = it.hy; return; }
      sl.it = it; it.placed = true; it.x = sl.x; it.y = sl.y; S.hit();
    },
    piece(S, g, it) {
      const skin = S.g.skin;
      g.save(); g.translate(it.x, it.y);
      if (skin === 'rocks') { g.fillStyle = '#efe3c6'; g.beginPath(); const s = it.good ? 1 : 0.5; for (let i = 0; i < 7; i++) { const a = (i / 7) * TAU, r = (12 + Math.sin(i * 2 + it.r * 7) * 4) * s; g.lineTo(Math.cos(a) * r, Math.sin(a) * r); } g.closePath(); g.fill(); }
      else if (skin === 'syringe') { g.rotate(-0.6); g.fillStyle = it.good ? 'rgba(251,191,36,.85)' : 'rgba(148,163,184,.6)'; g.fillRect(-16, -4, 26, 8); g.fillStyle = '#e5e7eb'; g.fillRect(10, -1, 10, 2); g.fillRect(-22, -6, 6, 12); if (!it.good) { g.strokeStyle = '#ef4444'; g.lineWidth = 2; g.beginPath(); g.moveTo(-10, -6); g.lineTo(0, 6); g.stroke(); } }
      else {
        const c = { pink: '#f472b6', blue: '#60a5fa', yellow: '#facc15', oxy: '#f1f5f9' }[S.x.color] || '#f1f5f9';
        g.fillStyle = c; g.beginPath(); g.arc(0, 0, 13, 0, TAU); g.fill();
        g.strokeStyle = 'rgba(0,0,0,.25)'; g.lineWidth = 1.5; g.beginPath(); g.moveTo(-8, 0); g.lineTo(8, 0); g.stroke();
        if (!it.good) { g.strokeStyle = '#1f2937'; g.lineWidth = 2; g.beginPath(); g.moveTo(-6, -11); g.lineTo(2, 0); g.lineTo(-3, 11); g.stroke(); }
      }
      g.restore();
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'lab', S.accent);
      g.fillStyle = 'rgba(255,255,255,.05)'; D.rr(g, 40, 60, 210, 330, 16); g.fill();
      D.label(g, 'Plateau', 145, 46, { size: 12, color: '#94a3b8' });
      // conditionnement
      g.fillStyle = st.skin === 'syringe' ? '#1f2937' : 'rgba(203,213,225,.18)'; D.rr(g, 295, 105, Math.min(6, st.slots.length) * 62 + 10, Math.ceil(st.slots.length / 6) * 70 + 20, 14); g.fill();
      for (const s of st.slots) { g.strokeStyle = 'rgba(255,255,255,.3)'; g.lineWidth = 2; g.beginPath(); g.arc(s.x, s.y, 22, 0, TAU); g.stroke(); }
      // poubelle
      g.fillStyle = '#374151'; D.rr(g, 625, 310, 90, 90, 12); g.fill(); D.label(g, '🗑 Rebut', 670, 355, { size: 13 });
      for (const it of st.items) if (it.x > 0) this.piece(S, g, it);
      D.label(g, 'Glisse les pièces correctes dans les cases, les abîmées au rebut', W / 2 + 60, 30, { size: 12, color: '#cbd5e1' });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };
})();
