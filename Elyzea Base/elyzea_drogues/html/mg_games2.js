/* =====================================================================
   ELYZEA DROGUES · mini-jeux (2/2) : dosage, chauffe, tamisage, découpe, cristaux, presse, tri, seringue
   ===================================================================== */
(() => {
  const MG = window.ElyMG, D = MG.D, W = D.W, H = D.H, TAU = Math.PI * 2;
  const COLORS = { solvent: [180, 220, 255], acid: [190, 255, 140], water: [120, 190, 255], soda: [240, 240, 240], oil: [230, 170, 90], base: [250, 210, 160], opium: [150, 90, 40], reagent: [255, 140, 200] };

  // ================================================================= DOSAGE (verser les réactifs dans l'ordre, jusqu'au trait)
  MG.games.pour = {
    init(S) {
      const list = (S.x.reagents && S.x.reagents.length ? S.x.reagents : [{ label: 'Solvant', color: 'solvent' }, { label: 'Réactif', color: 'reagent' }]).slice(0, 3);
      const st = { list, idx: 0, level: 0, flow: 0, lag: 0, pour: false, targets: [], beakers: 0 };
      st.newBeaker = () => { let acc = 0; st.targets = list.map(() => { acc += 0.18 + S.r() * 0.12; return acc; }); st.level = 0; st.idx = 0; st.layers = []; };
      st.newBeaker();
      return st;
    },
    tol: 0.035,
    down(S, x, y) { const st = S.g, bx = 470 + st.idx * 95; if ((st.pause || 0) <= 0 && Math.abs(x - bx) < 45 && y > 40 && y < 200) st.pour = true; },
    up(S) { const st = S.g; if (!st.pour) return; st.pour = false; st.lag = st.flow * 0.18; },
    key(S, code, on) { if (code === 'Space') { if (on) S.g.pour = true; else this.up(S); } },
    update(S, dt) {
      const st = S.g, t = st.targets[st.idx];
      if (st.pause > 0) { st.pause -= dt; if (st.pause <= 0 && S.m.down && Math.abs(S.m.x - (470 + st.idx * 95)) < 45 && S.m.y > 40 && S.m.y < 200) st.pour = true; }
      if (st.pour) { st.flow = Math.min(0.22, st.flow + 0.25 * dt); st.level += st.flow * dt; }
      else { st.flow = 0; if (st.lag > 0) { const d = Math.min(st.lag, 0.08 * dt); st.level += d; st.lag -= d; } }
      if (st.level > t + this.tol) { S.miss('Trop versé : mélange rattrapé'); st.level = st.idx > 0 ? st.targets[st.idx - 1] : 0; st.pour = false; st.flow = 0; st.lag = 0; st.pause = 0.7; return; }
      if (!st.pour && st.lag <= 0.0001 && Math.abs(st.level - t) <= this.tol) {
        st.layers.push(st.list[st.idx].color); st.idx++; S.hit();
        if (st.idx >= st.list.length) { st.beakers++; S.good('Mélange prêt'); if (!S.ended) st.newBeaker(); }
      }
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'lab', S.accent);
      // bécher
      const bx = 160, by = 80, bw = 190, bh = 300;
      g.fillStyle = 'rgba(200,230,255,.06)'; D.rr(g, bx, by, bw, bh, 14); g.fill(); g.strokeStyle = 'rgba(200,230,255,.45)'; g.lineWidth = 3; g.stroke();
      // couches
      let prev = 0;
      const levels = st.targets.slice(0, st.idx).concat([st.level]);
      levels.forEach((lv, i) => {
        const c = COLORS[(st.list[Math.min(i, st.list.length - 1)] || {}).color] || [200, 200, 200];
        const y0 = by + bh - prev * bh, y1 = by + bh - lv * bh; if (y1 < y0) { g.fillStyle = D.rgba(c, 0.75); g.fillRect(bx + 4, y1, bw - 8, y0 - y1); }
        prev = Math.max(prev, lv);
      });
      // graduations + trait cible
      for (let i = 1; i < 10; i++) { g.fillStyle = 'rgba(255,255,255,.3)'; g.fillRect(bx + bw - 22, by + bh - (i / 10) * bh, 14, 1.5); }
      const t = st.targets[st.idx];
      if (t !== undefined) {
        const ty = by + bh - t * bh;
        g.fillStyle = D.rgba(S.accent, 0.25); g.fillRect(bx - 10, ty - this.tol * bh, bw + 20, this.tol * bh * 2);
        g.strokeStyle = D.rgba(S.accent, 1); g.setLineDash([6, 4]); g.lineWidth = 2; g.beginPath(); g.moveTo(bx - 14, ty); g.lineTo(bx + bw + 14, ty); g.stroke(); g.setLineDash([]);
      }
      // flacons
      st.list.forEach((r, i) => {
        const x = 470 + i * 95, active = i === st.idx, done = i < st.idx;
        g.save(); g.translate(x, 120); if (active && st.pour) { g.translate(-60 - i * 20, 0); g.rotate(-1.2); }
        g.globalAlpha = done ? 0.35 : 1;
        g.fillStyle = D.rgba(COLORS[r.color] || [200, 200, 200], 0.85); D.rr(g, -26, -40, 52, 80, 10); g.fill();
        g.strokeStyle = active ? D.rgba(S.accent, 1) : 'rgba(255,255,255,.3)'; g.lineWidth = active ? 3 : 1.5; g.stroke();
        g.fillStyle = '#e2e8f0'; g.fillRect(-9, -56, 18, 18);
        g.restore();
        D.label(g, `${i + 1}. ${r.label}`, x, 190, { size: 12, color: active ? '#fff' : '#94a3b8' });
      });
      if (st.pour) { g.strokeStyle = D.rgba(COLORS[st.list[st.idx].color] || [200, 200, 200], 0.8); g.lineWidth = 5; g.beginPath(); g.moveTo(bx + bw / 2 + 20, by - 10); g.lineTo(bx + bw / 2 + 10, by + bh - st.level * bh); g.stroke(); }
      D.label(g, 'Maintiens le clic sur le flacon actif · arrête-toi sur le trait', 500, 300, { size: 12, color: '#cbd5e1' });
      D.label(g, `Mélanges : ${st.beakers}`, 80, 26, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= CHAUFFE (garder la température dans la zone)
  MG.games.heat = {
    init(S) { return { T: 35, band: [45, 62], next: 4, inb: 0, red: 0, spike: 5 + S.r() * 3, sec: 0 }; },
    update(S, dt) {
      const st = S.g, heat = S.m.down || S.key.Space;
      st.T += (heat ? 26 : -17) * dt + (Math.random() - 0.5) * 6 * dt;
      st.spike -= dt; if (st.spike <= 0) { st.spike = 4 + S.r() * 4; st.T += 14; S.toast(S.cfg.skin === 'pump' ? 'Coup de pression !' : 'Ébullition !', 'bad'); }
      st.next -= dt; if (st.next <= 0) { st.next = 4 + S.r() * 3; const c = 30 + S.r() * 40; st.band = [c, c + 16]; }
      st.T = D.clamp(st.T, 0, 100);
      if (st.T >= st.band[0] && st.T <= st.band[1]) { st.inb += dt; if (st.inb >= 1) { st.inb -= 1; S.hit(); } }
      if (st.T > 90) { st.red += dt; if (st.red > 0.8) { st.red = 0; st.T = 45; S.miss(S.cfg.skin === 'pump' ? 'Surpression !' : 'Surchauffe !'); } } else st.red = 0;
    },
    draw(S, g) {
      const st = S.g, skin = S.cfg.skin;
      D.bg(g, skin === 'stove' ? 'dark' : 'lab', S.accent);
      // appareil
      g.save(); g.translate(300, 250);
      if (skin === 'stove') {
        g.fillStyle = '#374151'; D.rr(g, -150, 40, 300, 90, 12); g.fill();
        g.fillStyle = '#9ca3af'; D.rr(g, -110, -70, 220, 110, 18); g.fill(); g.fillStyle = '#6b7280'; g.fillRect(110, -50, 70, 12);
        g.fillStyle = `rgba(255,${140 + st.T},80,${0.25 + st.T / 140})`; for (let i = -3; i <= 3; i++) { g.beginPath(); g.ellipse(i * 22, 40, 8, 10 + st.T / 8 + Math.sin(performance.now() / 90 + i) * 4, 0, 0, TAU); g.fill(); }
      } else if (skin === 'pump') {
        g.fillStyle = '#1e3a8a'; D.rr(g, -90, -120, 180, 240, 30); g.fill(); g.fillStyle = '#e5e7eb'; g.fillRect(-10, -150, 20, 34);
        g.fillStyle = '#facc15'; g.fillRect(-90, -20, 180, 18);
        g.strokeStyle = '#94a3b8'; g.lineWidth = 8; g.beginPath(); g.moveTo(90, 60); g.quadraticCurveTo(200, 80, 220, -40); g.stroke();
      } else {
        g.fillStyle = 'rgba(200,230,255,.08)'; g.beginPath(); g.arc(0, 0, 110, 0, TAU); g.fill(); g.strokeStyle = 'rgba(200,230,255,.5)'; g.lineWidth = 3; g.stroke();
        g.fillStyle = D.rgba(D.mix([120, 160, 220], [255, 120, 60], st.T / 100), 0.7); g.beginPath(); g.arc(0, 0, 100, 0.15 * Math.PI, 0.85 * Math.PI); g.fill();
        for (let i = 0; i < 8; i++) { const t = (performance.now() / 600 + i * 0.37) % 1; g.fillStyle = `rgba(255,255,255,${0.5 * (1 - t) * st.T / 100})`; g.beginPath(); g.arc(-60 + i * 17, 60 - t * 90, 3 + st.T / 40, 0, TAU); g.fill(); }
        g.fillStyle = '#334155'; D.rr(g, -60, 100, 120, 40, 8); g.fill();
      }
      g.restore();
      // thermomètre
      const x = 600, y0 = 60, h = 300;
      D.rr(g, x - 18, y0, 36, h, 18); g.fillStyle = 'rgba(148,178,230,.12)'; g.fill();
      g.fillStyle = D.rgba(S.accent, 0.35); g.fillRect(x - 18, y0 + h - (st.band[1] / 100) * h, 36, ((st.band[1] - st.band[0]) / 100) * h);
      g.fillStyle = 'rgba(248,113,113,.3)'; g.fillRect(x - 18, y0, 36, h * 0.1);
      const ty = y0 + h - (st.T / 100) * h;
      g.fillStyle = D.rgba(D.mix([96, 165, 250], [248, 113, 113], st.T / 100), 1); D.rr(g, x - 8, ty, 16, y0 + h - ty, 8); g.fill();
      g.fillStyle = '#fff'; g.fillRect(x - 26, ty - 2, 52, 4);
      D.label(g, `${Math.round(st.T * 1.6 + 20)} °C`, x, y0 + h + 24, { size: 15 });
      D.label(g, skin === 'pump' ? 'Pression' : 'Température', x, 40, { size: 12, color: '#cbd5e1' });
      D.label(g, 'Maintiens le clic (ou Espace) pour chauffer, relâche pour refroidir', 300, 30, { size: 12, color: '#cbd5e1' });
      D.ring(g, 690, 210, 22, st.inb, D.rgba(S.accent, 1));
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= TAMISAGE / FILTRATION (secouer de gauche à droite sans renverser)
  MG.games.shake = {
    init() { return { x: W / 2, dir: 0, lastX: W / 2, ext: W / 2, spill: 0, vel: 0, pile: 0 }; },
    move(S, x) {
      const st = S.g; if (!S.m.down) { st.lastX = x; return; }
      const dx = x - st.lastX; st.lastX = x; st.x = D.clamp(x, 200, 560); st.vel = Math.abs(dx);
      const d = Math.sign(dx);
      if (d && d !== st.dir) { if (Math.abs(st.x - st.ext) > 70) { st.pile++; D.burst(st.x, 230, S.cfg.skin === 'filter' ? 'rgba(160,110,60,.9)' : 'rgba(240,240,240,.9)', 6, 60, 2); S.hit(); } st.ext = st.x; st.dir = d; }
    },
    update(S, dt) {
      const st = S.g;
      if (st.vel > 38) st.spill += dt * (st.vel - 38) * 0.08; else st.spill = Math.max(0, st.spill - dt * 0.6);
      st.vel *= 0.6;
      if (st.spill >= 1) { st.spill = 0; S.miss(S.cfg.skin === 'filter' ? 'Ça déborde du filtre !' : 'Trop brusque : ça se renverse'); }
    },
    draw(S, g) {
      const st = S.g, filter = S.cfg.skin === 'filter';
      D.bg(g, 'lab', S.accent);
      // récipient du dessous
      g.fillStyle = 'rgba(200,230,255,.08)'; g.beginPath(); g.ellipse(W / 2, 360, 200, 40, 0, 0, TAU); g.fill(); g.strokeStyle = 'rgba(200,230,255,.35)'; g.lineWidth = 2; g.stroke();
      g.fillStyle = filter ? 'rgba(150,90,40,.8)' : 'rgba(245,245,250,.85)'; g.beginPath(); g.ellipse(W / 2, 360, Math.min(180, 20 + st.pile * 6), Math.min(30, 6 + st.pile), 0, 0, TAU); g.fill();
      // tamis / filtre
      g.save(); g.translate(st.x, 200);
      g.fillStyle = '#64748b'; g.beginPath(); g.ellipse(0, 0, 130, 34, 0, 0, TAU); g.fill();
      g.fillStyle = filter ? '#f5efe0' : '#cbd5e1'; g.beginPath(); g.ellipse(0, 0, 118, 26, 0, 0, TAU); g.fill();
      g.strokeStyle = 'rgba(0,0,0,.2)'; g.lineWidth = 1; for (let i = -110; i < 110; i += 10) { g.beginPath(); g.moveTo(i, -20); g.lineTo(i, 20); g.stroke(); }
      g.fillStyle = filter ? 'rgba(130,80,40,.85)' : 'rgba(240,240,245,.95)'; g.beginPath(); g.ellipse(0, -4, Math.max(20, 90 - st.pile * 2), 14, 0, 0, TAU); g.fill();
      g.restore();
      for (let i = 0; i < 6; i++) { const t = (performance.now() / 400 + i / 6) % 1; g.fillStyle = filter ? 'rgba(150,90,40,.6)' : 'rgba(240,240,245,.7)'; g.fillRect(st.x - 60 + i * 24, 225 + t * 120, 2, 6); }
      // jauge de débordement
      D.gauge(g, 200, 50, 360, 10, st.spill, 0, 0.6, S.accent, 0.6);
      D.label(g, 'Secoue de gauche à droite en maintenant le clic · pas trop vite', W / 2, 30, { size: 12, color: '#cbd5e1' });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= DÉCOUPE (suivre les traits du bloc / tracer des lignes)
  MG.games.cut = {
    init(S) {
      const per = Math.max(1, S.x.per || 3);
      const st = { per, lines: [], blocks: 0, cur: null, skin: S.cfg.skin || 'crack' };
      st.newBlock = () => {
        const n = Math.min(per, S.total - S.done) || per;
        st.lines = [];
        for (let i = 0; i < n; i++) {
          if (st.skin === 'coke' || st.skin === 'keta') { const y = 150 + (i + 0.5) * (170 / n); st.lines.push({ ax: 220, ay: y + (S.r() - 0.5) * 10, bx: 540, by: y + (S.r() - 0.5) * 10, done: false }); }
          else { const x = 220 + (i + 1) * (320 / (n + 1)); st.lines.push({ ax: x + (S.r() - 0.5) * 30, ay: 130, bx: x + (S.r() - 0.5) * 30, by: 330, done: false }); }
        }
      };
      st.newBlock();
      return st;
    },
    down(S, x, y) {
      const st = S.g;
      for (const l of st.lines) {
        if (l.done) continue;
        if (D.dist(x, y, l.ax, l.ay) < 24) { st.cur = { l, from: 'a' }; return; }
        if (D.dist(x, y, l.bx, l.by) < 24) { st.cur = { l, from: 'b' }; return; }
      }
    },
    move(S, x, y) {
      const st = S.g;
      if (!st.cur && S.m.down) this.down(S, x, y);   // bouton toujours tenu (après une coupe ratée) : reprise sur un bout de trait
      const c = st.cur; if (!c) return;
      const l = c.l;
      if (D.segDist(x, y, l.ax, l.ay, l.bx, l.by) > 15) { st.cur = null; S.miss('Coupe de travers'); return; }
      const end = c.from === 'a' ? [l.bx, l.by] : [l.ax, l.ay];
      if (D.dist(x, y, end[0], end[1]) < 22) {
        l.done = true; st.cur = null; D.burst(end[0], end[1], st.skin === 'crack' ? 'rgba(240,230,200,.9)' : 'rgba(250,250,255,.9)', 8, 80, 2); S.hit();
        if (st.lines.every((k) => k.done)) { st.blocks++; S.good(st.skin === 'crack' ? 'Bloc découpé' : 'Lignes faites'); if (!S.ended) setTimeout(() => { if (!S.ended) st.newBlock(); }, 350); }
      }
    },
    up(S) { S.g.cur = null; },
    draw(S, g) {
      const st = S.g;
      D.bg(g, st.skin === 'crack' ? 'wood' : 'dark', S.accent);
      if (st.skin === 'crack') {
        g.fillStyle = '#5b4632'; D.rr(g, 180, 110, 400, 240, 14); g.fill();
        g.fillStyle = '#efe3c6'; D.rr(g, 210, 125, 340, 210, 10); g.fill();
        g.fillStyle = 'rgba(0,0,0,.08)'; for (let i = 0; i < 40; i++) g.fillRect(220 + ((i * 53) % 320), 135 + ((i * 37) % 190), 4, 3);
      } else {
        g.fillStyle = '#0f172a'; D.rr(g, 180, 110, 400, 240, 10); g.fill(); g.strokeStyle = 'rgba(255,255,255,.12)'; g.stroke();
        const c = st.skin === 'keta' ? 'rgba(225,215,255,.92)' : 'rgba(248,250,252,.95)';
        g.fillStyle = c; g.beginPath(); g.ellipse(380, 230, 150, 90, 0, 0, TAU); g.fill();
      }
      for (const l of st.lines) {
        g.strokeStyle = l.done ? 'rgba(0,0,0,.55)' : D.rgba(S.accent, 0.95); g.lineWidth = l.done ? 4 : 2.5; g.setLineDash(l.done ? [] : [8, 6]);
        g.beginPath(); g.moveTo(l.ax, l.ay); g.lineTo(l.bx, l.by); g.stroke(); g.setLineDash([]);
        if (!l.done) for (const p of [[l.ax, l.ay], [l.bx, l.by]]) { g.fillStyle = D.rgba(S.accent, 1); g.beginPath(); g.arc(p[0], p[1], 7, 0, TAU); g.fill(); }
      }
      if (st.cur) { g.strokeStyle = '#fff'; g.lineWidth = 3; g.beginPath(); const a = st.cur.from === 'a' ? [st.cur.l.ax, st.cur.l.ay] : [st.cur.l.bx, st.cur.l.by]; g.moveTo(a[0], a[1]); g.lineTo(S.m.x, S.m.y); g.stroke(); }
      D.label(g, 'Pars d\'un point et suis le trait jusqu\'à l\'autre bout', W / 2, 30, { size: 12, color: '#cbd5e1' });
      D.label(g, `${st.skin === 'crack' ? 'Blocs' : 'Passes'} : ${st.blocks}`, 70, 60, { size: 13 });
    },
    drawCursor(S, g) { // lame / carte
      const { x, y } = S.m; g.save(); g.translate(x, y); g.rotate(-0.7);
      if (S.g.skin === 'crack') { g.fillStyle = '#e5e7eb'; g.beginPath(); g.moveTo(0, 0); g.lineTo(30, -6); g.lineTo(30, 4); g.closePath(); g.fill(); g.fillStyle = '#111827'; g.fillRect(30, -6, 22, 10); }
      else { g.fillStyle = '#1d4ed8'; D.rr(g, -2, -14, 44, 28, 3); g.fill(); g.fillStyle = '#facc15'; g.fillRect(6, -6, 10, 8); }
      g.restore();
    },
  };

  // ================================================================= CRISTAUX (casser la plaque de méth aux points de fissure)
  MG.games.smash = {
    init() { return { spots: [], next: 0.5, shards: [] }; },
    update(S, dt) {
      const st = S.g; st.next -= dt;
      for (let i = st.spots.length - 1; i >= 0; i--) { const s = st.spots[i]; s.t += dt; if (s.t > s.life) { st.spots.splice(i, 1); S.miss('Fissure ratée'); } }
      if (st.next <= 0 && st.spots.length < 2) { st.next = 0.55 + S.r() * 0.5; st.spots.push({ x: 210 + S.r() * 340, y: 140 + S.r() * 190, t: 0, life: 1.25 }); }
    },
    down(S, x, y) {
      const st = S.g;
      const i = st.spots.findIndex((s) => D.dist(x, y, s.x, s.y) < 30);
      if (i >= 0) { const s = st.spots[i]; st.spots.splice(i, 1); st.shards.push({ x: s.x, y: s.y, r: Math.random() * TAU }); D.burst(s.x, s.y, 'rgba(170,220,255,.95)', 12, 160, 2.5); S.hit(); }
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'steel', S.accent);
      g.fillStyle = '#9ca3af'; D.rr(g, 180, 110, 400, 250, 12); g.fill();
      g.fillStyle = 'rgba(170,220,255,.55)'; D.rr(g, 195, 125, 370, 220, 8); g.fill();
      g.strokeStyle = 'rgba(255,255,255,.35)'; g.lineWidth = 1;
      for (const sh of st.shards) { g.beginPath(); for (let k = 0; k < 5; k++) { const a = sh.r + k * 1.3; g.moveTo(sh.x, sh.y); g.lineTo(sh.x + Math.cos(a) * 40, sh.y + Math.sin(a) * 40); } g.stroke(); }
      for (const s of st.spots) {
        const k = s.t / s.life;
        g.strokeStyle = D.rgba(S.accent, 1 - k * 0.5); g.lineWidth = 3; g.beginPath(); g.arc(s.x, s.y, 34 - k * 22, 0, TAU); g.stroke();
        g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = 2; g.beginPath(); g.moveTo(s.x - 12, s.y - 6); g.lineTo(s.x, s.y + 2); g.lineTo(s.x + 10, s.y - 8); g.stroke();
      }
      D.label(g, 'Frappe les fissures quand elles brillent', W / 2, 30, { size: 12, color: '#cbd5e1' });
    },
    drawCursor(S, g) { const { x, y, down } = S.m; g.save(); g.translate(x, y); g.rotate(down ? 0.2 : -0.5); g.fillStyle = '#78350f'; g.fillRect(-3, 0, 6, 46); g.fillStyle = '#6b7280'; D.rr(g, -18, -12, 36, 16, 4); g.fill(); g.restore(); },
  };

  // ================================================================= PRESSE (taper au bon moment sur la matrice)
  MG.games.press = {
    init() { return { r: 150, tabs: 0, flash: 0 }; },
    target: 36,
    update(S, dt) {
      const st = S.g; st.r -= dt * 95; st.flash = Math.max(0, st.flash - dt * 3);
      if (st.r < 8) { st.r = 150; S.miss('Trop tard : comprimé raté'); }
    },
    down(S) {
      const st = S.g;
      if (Math.abs(st.r - this.target) <= 9) { st.tabs++; st.flash = 1; S.hit(); }
      else S.miss('Comprimé fendu');
      st.r = 150 + Math.random() * 40;
    },
    key(S, code, on) { if (code === 'Space' && on) this.down(S); },
    draw(S, g) {
      const st = S.g, cx = W / 2 - 60, cy = H / 2 + 10;
      const c = { pink: [244, 114, 182], blue: [96, 165, 250], yellow: [250, 204, 21] }[S.x.color] || S.accent;
      D.bg(g, 'steel', S.accent);
      g.fillStyle = '#374151'; D.rr(g, cx - 150, cy - 150, 300, 300, 26); g.fill();
      g.fillStyle = '#1f2937'; g.beginPath(); g.arc(cx, cy, this.target + 8, 0, TAU); g.fill();
      g.fillStyle = D.rgba(c, 0.5 + st.flash * 0.5); g.beginPath(); g.arc(cx, cy, this.target - 8, 0, TAU); g.fill();
      g.strokeStyle = 'rgba(255,255,255,.5)'; g.lineWidth = 2; g.setLineDash([5, 4]); g.beginPath(); g.arc(cx, cy, this.target, 0, TAU); g.stroke(); g.setLineDash([]);
      g.strokeStyle = D.rgba(S.accent, 1); g.lineWidth = 4; g.beginPath(); g.arc(cx, cy, Math.max(4, st.r), 0, TAU); g.stroke();
      // bac de comprimés
      g.fillStyle = 'rgba(255,255,255,.06)'; D.rr(g, W - 210, 80, 170, 280, 14); g.fill();
      for (let i = 0; i < Math.min(st.tabs, 24); i++) { g.fillStyle = D.rgba(c, 1); g.beginPath(); g.arc(W - 180 + (i % 4) * 36, 330 - Math.floor(i / 4) * 34, 12, 0, TAU); g.fill(); }
      D.label(g, 'Clique (ou Espace) quand l\'anneau touche le trait', cx, 30, { size: 12, color: '#cbd5e1' });
      D.label(g, `Comprimés : ${st.tabs}`, W - 125, 60, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= TRI (champignons sur le tapis : bons au panier, pourris au rebut)
  MG.games.sort = {
    init() { return { items: [], next: 0.2, drag: null, basket: 0 }; },
    update(S, dt) {
      const st = S.g; st.next -= dt;
      if (st.next <= 0) { st.next = 0.9 + S.r() * 0.5; st.items.push({ x: -30, y: 215 + (S.r() - 0.5) * 30, good: S.r() < 0.68, r: S.r() }); }
      for (let i = st.items.length - 1; i >= 0; i--) {
        const it = st.items[i]; if (it === st.drag) continue;
        it.x += 70 * dt;
        if (it.x > W - 40) { st.items.splice(i, 1); if (it.good) S.miss('Un bon champignon est parti'); }
      }
    },
    down(S, x, y) { const it = S.g.items.find((i) => D.dist(x, y, i.x, i.y) < 24); if (it) S.g.drag = it; },
    move(S, x, y) { const it = S.g.drag; if (it) { it.x = x; it.y = y; } },
    up(S, x, y) {
      const st = S.g, it = st.drag; st.drag = null; if (!it) return;
      const inBasket = x < 200 && y > 300, inBin = x > 560 && y > 300;
      if (!inBasket && !inBin) { it.y = 215; return; }
      st.items.splice(st.items.indexOf(it), 1);
      if (inBasket && it.good) { st.basket++; S.hit(); }
      else if (inBin && !it.good) { D.burst(x, y, 'rgba(80,60,40,.9)', 6, 60, 2); }
      else S.miss(inBasket ? 'Champignon pourri dans le panier' : 'Bon champignon jeté');
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'wood', S.accent);
      // tapis
      g.fillStyle = '#1f2937'; g.fillRect(0, 180, W, 70);
      g.fillStyle = '#374151'; for (let i = 0; i < 20; i++) { const x = ((i * 50 + performance.now() * 0.07) % (W + 50)) - 50; g.fillRect(x, 180, 4, 70); }
      g.fillStyle = '#6b4a2b'; D.rr(g, 30, 310, 170, 100, 16); g.fill(); D.label(g, `🧺 Panier (${st.basket})`, 115, 360, { size: 13 });
      g.fillStyle = '#374151'; D.rr(g, 560, 310, 170, 100, 16); g.fill(); D.label(g, '🗑 Rebut', 645, 360, { size: 13 });
      for (const it of st.items) {
        g.save(); g.translate(it.x, it.y);
        g.fillStyle = it.good ? '#efe6d2' : '#6b5b4a'; g.fillRect(-4, -2, 8, 18);
        g.fillStyle = it.good ? '#b08a5a' : '#3f3326'; g.beginPath(); g.moveTo(-18, 2); g.quadraticCurveTo(0, -30, 18, 2); g.closePath(); g.fill();
        if (!it.good) { g.fillStyle = 'rgba(120,160,60,.7)'; g.beginPath(); g.arc(5, -6, 5, 0, TAU); g.fill(); }
        g.restore();
      }
      D.label(g, 'Glisse les bons champignons dans le panier, les pourris au rebut', W / 2, 30, { size: 12, color: '#cbd5e1' });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };

  // ================================================================= SERINGUE (tirer le piston jusqu'à la dose, chasser les bulles)
  MG.games.syringe = {
    init(S) { return { v: 0, target: 0.4 + S.r() * 0.35, bubbles: [], drag: false, filled: 0 }; },
    tol: 0.04,
    down(S, x, y) {
      const st = S.g;
      if (st.bubbles.length) {
        const i = st.bubbles.findIndex((b) => D.dist(x, y, b.x, b.y) < 16);
        if (i >= 0) { const b = st.bubbles.splice(i, 1)[0]; D.burst(b.x, b.y, 'rgba(255,255,255,.9)', 5, 60, 1.5); if (!st.bubbles.length) { st.filled++; S.hit(); S.good('Seringue prête'); st.v = 0; st.target = 0.4 + S.r() * 0.35; } }
        return;
      }
      if (Math.abs(y - 220) < 40 && x > 120 && x < 680) st.drag = true;
    },
    move(S, x, y) {
      const st = S.g;
      if (!st.drag && S.m.down && !st.bubbles.length && Math.abs(y - 220) < 40 && x > 120 && x < 680) st.drag = true;   // reprise sans relâcher
      if (st.drag) st.v = D.clamp((x - 170) / 440, 0, 1);
    },
    up(S) {
      const st = S.g; if (!st.drag) return; st.drag = false;
      if (Math.abs(st.v - st.target) <= this.tol) { for (let i = 0; i < 2 + Math.floor(S.r() * 2); i++) st.bubbles.push({ x: 200 + S.r() * st.v * 380, y: 212 + (S.r() - 0.5) * 16 }); S.hint('Tapote les bulles d\'air pour les chasser.'); }
      else if (st.v > st.target + this.tol) { st.v = 0; S.miss('Dose dépassée : on vide et on recommence'); }
    },
    draw(S, g) {
      const st = S.g;
      D.bg(g, 'lab', S.accent);
      // corps de la seringue
      g.fillStyle = 'rgba(220,235,255,.12)'; D.rr(g, 170, 190, 440, 60, 10); g.fill(); g.strokeStyle = 'rgba(220,235,255,.6)'; g.lineWidth = 2; g.stroke();
      g.fillStyle = 'rgba(251,146,60,.75)'; g.fillRect(172, 194, st.v * 436, 52);
      for (let i = 0; i <= 20; i++) { g.fillStyle = 'rgba(255,255,255,.5)'; g.fillRect(170 + i * 22, 190, 1.5, i % 5 ? 10 : 18); }
      g.fillStyle = '#9ca3af'; g.fillRect(110, 214, 60, 12); g.fillStyle = '#cbd5e1'; g.fillRect(70, 205, 12, 30);
      g.fillStyle = '#6b7280'; g.fillRect(170 + st.v * 436, 186, 10, 68); g.fillRect(170 + st.v * 436, 214, 90, 12); g.fillRect(250 + st.v * 436, 196, 12, 48);
      // cible
      const tx = 170 + st.target * 436;
      g.fillStyle = D.rgba(S.accent, 0.3); g.fillRect(tx - this.tol * 436, 175, this.tol * 872, 90);
      g.strokeStyle = D.rgba(S.accent, 1); g.setLineDash([5, 4]); g.lineWidth = 2; g.beginPath(); g.moveTo(tx, 168); g.lineTo(tx, 272); g.stroke(); g.setLineDash([]);
      for (const b of st.bubbles) { g.strokeStyle = '#fff'; g.lineWidth = 2; g.beginPath(); g.arc(b.x, b.y, 7, 0, TAU); g.stroke(); }
      D.label(g, st.bubbles.length ? 'Clique les bulles' : 'Tire le piston jusqu\'au trait, puis relâche', W / 2, 30, { size: 12, color: '#cbd5e1' });
      D.label(g, `${(st.v * 5).toFixed(2)} ml · cible ${(st.target * 5).toFixed(2)} ml`, W / 2, 310, { size: 15 });
      D.label(g, `Seringues : ${st.filled}`, 80, 60, { size: 13 });
    },
    drawCursor(S, g) { D.hand(g, S.m.x, S.m.y, S.m.down); },
  };
})();
