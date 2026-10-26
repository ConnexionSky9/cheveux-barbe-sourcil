/* =====================================================================
   ELYZEA EMS - actes médicaux en mini-jeux (interface)
   Le serveur envoie un défi { id, act, title, icon, seed, duration, difficulty, maxMistakes, extra }.
   Chaque acte est une suite d'étapes (choisir, frotter, viser, maintenir, suivre un tracé…).
   Fin : réussite, échec (trop d'erreurs, temps écoulé) ou annulation (Échap). Le résultat
   { id, ok, mistakes, score, choice, cancelled } part au client Lua (procResult) puis au
   serveur, qui le vérifie (durée réelle, erreurs, choix imposés) avant d'appliquer l'acte.
   Fenêtres associées : choix de l'acte, attente du consentement, question, consentement du patient.
   ===================================================================== */
(() => {
  const IN = typeof GetParentResourceName === 'function';
  const RESN = IN ? GetParentResourceName() : 'elyzea_ems';
  const send = (n, d) => {
    if (!IN) { if (window.ProcOut) window.ProcOut(n, d); return Promise.resolve({}); }
    return fetch(`https://${RESN}/${n}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(d || {}) }).catch(() => {});
  };
  const E = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const W = 760, H = 440;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
  function rng(seed) {
    let a = (seed >>> 0) || 1;
    return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  function segDist(px, py, ax, ay, bx, by) {
    const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy;
    let t = l ? ((px - ax) * dx + (py - ay) * dy) / l : 0;
    t = clamp(t, 0, 1);
    return { d: Math.hypot(px - (ax + t * dx), py - (ay + t * dy)), t };
  }

  // ---------------------------------------------------------------- dessin
  const SKIN = '#d9a383', SKIN_D = '#b9825f', ACC = [229, 72, 77], OK = '#22c55e', BAD = '#f87171';
  const rgba = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;
  const D = {
    rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); },
    bg(g) {
      const grd = g.createLinearGradient(0, 0, 0, H); grd.addColorStop(0, '#111c30'); grd.addColorStop(1, '#070b14');
      g.fillStyle = grd; g.fillRect(0, 0, W, H);
      g.save(); g.globalAlpha = 0.05; g.strokeStyle = '#fff';
      for (let x = 0; x < W; x += 38) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, H); g.stroke(); }
      for (let y = 0; y < H; y += 38) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
      g.restore();
    },
    text(g, t, x, y, o = {}) {
      g.save(); g.font = `${o.w || 700} ${o.s || 13}px Inter, Segoe UI, sans-serif`; g.textAlign = o.a || 'center'; g.textBaseline = 'middle';
      g.fillStyle = o.c || '#e2e8f0'; g.shadowColor = 'rgba(0,0,0,.7)'; g.shadowBlur = 5; g.fillText(t, x, y); g.restore();
    },
    // jauge horizontale : valeur v, zone cible [lo, hi]
    hgauge(g, x, y, w, h, v, lo, hi, label, good) {
      D.rr(g, x, y, w, h, h / 2); g.fillStyle = 'rgba(148,178,230,.13)'; g.fill();
      g.fillStyle = good ? 'rgba(34,197,94,.35)' : rgba(ACC, 0.3); g.fillRect(x + w * lo, y, w * (hi - lo), h);
      g.strokeStyle = good ? OK : rgba(ACC, 0.9); g.lineWidth = 2; g.strokeRect(x + w * lo, y, w * (hi - lo), h);
      const mx = x + w * clamp(v, 0, 1);
      g.fillStyle = '#fff'; g.fillRect(mx - 2, y - 5, 4, h + 10);
      if (label) D.text(g, label, x + w / 2, y - 14, { s: 12, c: '#cbd5e1' });
    },
    vgauge(g, x, y, w, h, v, lo, hi, label, good) {
      D.rr(g, x, y, w, h, w / 2); g.fillStyle = 'rgba(148,178,230,.13)'; g.fill();
      const ty = (p) => y + h * (1 - p);
      g.fillStyle = good ? 'rgba(34,197,94,.35)' : rgba(ACC, 0.3); g.fillRect(x, ty(hi), w, ty(lo) - ty(hi));
      g.strokeStyle = good ? OK : rgba(ACC, 0.9); g.lineWidth = 2; g.strokeRect(x, ty(hi), w, ty(lo) - ty(hi));
      const my = ty(clamp(v, 0, 1));
      g.fillStyle = '#fff'; g.fillRect(x - 6, my - 2, w + 12, 4);
      if (label) D.text(g, label, x + w / 2, y + h + 16, { s: 11, c: '#cbd5e1' });
    },
    ring(g, x, y, r, t, color) {
      g.save(); g.lineWidth = 4; g.strokeStyle = 'rgba(255,255,255,.18)'; g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.stroke();
      g.strokeStyle = color || OK; g.beginPath(); g.arc(x, y, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * clamp(t, 0, 1)); g.stroke(); g.restore();
    },
    // membre (bras / jambe) vu de dessus : rectangle arrondi orienté
    limb(g, cx, cy, len, wid, ang, kind) {
      if (kind === 'body') return D.body(g, cx, cy, len, ang);
      g.save(); g.translate(cx, cy); g.rotate(ang);
      const grd = g.createLinearGradient(0, -wid / 2, 0, wid / 2); grd.addColorStop(0, SKIN); grd.addColorStop(1, SKIN_D);
      g.fillStyle = grd; D.rr(g, -len / 2, -wid / 2, len, wid, wid / 2); g.fill();
      g.fillStyle = 'rgba(0,0,0,.12)';
      if (kind === 'leg') { g.beginPath(); g.ellipse(0, 0, wid * 0.32, wid * 0.36, 0, 0, Math.PI * 2); g.fill(); }
      else { g.beginPath(); g.ellipse(-len * 0.05, 0, wid * 0.22, wid * 0.3, 0, 0, Math.PI * 2); g.fill(); }
      g.restore();
    },
    // corps entier allongé (radiographie intégrale) : tête à gauche, vu de dessus, longueur len
    body(g, cx, cy, len, ang = 0) {
      const u = len / 460;
      g.save(); g.translate(cx, cy); g.rotate(ang); g.scale(u, u);
      const grd = g.createLinearGradient(0, -70, 0, 70); grd.addColorStop(0, SKIN); grd.addColorStop(1, SKIN_D);
      g.fillStyle = grd;
      D.rr(g, 10, -38, 210, 30, 15); g.fill(); D.rr(g, 10, 8, 210, 30, 15); g.fill();          // jambes
      D.rr(g, -150, -62, 165, 22, 11); g.fill(); D.rr(g, -150, 40, 165, 22, 11); g.fill();      // bras le long du corps
      g.beginPath(); g.ellipse(-80, 0, 95, 46, 0, 0, Math.PI * 2); g.fill();                    // tronc
      g.beginPath(); g.arc(-200, 0, 30, 0, Math.PI * 2); g.fill();                              // tête
      g.fillStyle = 'rgba(0,0,0,.12)'; g.beginPath(); g.arc(-40, 0, 4, 0, Math.PI * 2); g.fill();
      g.restore();
    },
    torso(g, cx, cy, s = 1) {
      g.save(); g.translate(cx, cy); g.scale(s, s);
      const grd = g.createLinearGradient(-120, 0, 120, 0); grd.addColorStop(0, SKIN_D); grd.addColorStop(0.5, SKIN); grd.addColorStop(1, SKIN_D);
      g.fillStyle = grd; g.beginPath(); g.ellipse(0, 0, 120, 170, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = 'rgba(0,0,0,.18)'; g.beginPath(); g.arc(0, 40, 5, 0, Math.PI * 2); g.fill();
      g.restore();
    },
    cursor(g, x, y, down, kind) {
      g.save(); g.translate(x, y);
      if (kind === 'probe') { g.fillStyle = '#e2e8f0'; D.rr(g, -9, -26, 18, 34, 6); g.fill(); g.fillStyle = '#60a5fa'; g.fillRect(-9, 4, 18, 5); }
      else if (kind === 'swab') { g.strokeStyle = '#f8fafc'; g.lineWidth = 3; g.beginPath(); g.moveTo(0, 0); g.lineTo(18, -28); g.stroke(); g.fillStyle = '#fef3c7'; g.beginPath(); g.ellipse(0, 0, 8, 6, 0.6, 0, Math.PI * 2); g.fill(); }
      else if (kind === 'needle') { g.strokeStyle = '#e2e8f0'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, 0); g.lineTo(26, -26); g.stroke(); g.fillStyle = 'rgba(96,165,250,.8)'; g.fillRect(20, -40, 10, 18); }
      else { g.fillStyle = down ? '#fde68a' : '#f8fafc'; g.strokeStyle = 'rgba(0,0,0,.6)'; g.lineWidth = 1.5; g.beginPath(); g.arc(0, 0, down ? 6 : 8, 0, Math.PI * 2); g.fill(); g.stroke(); }
      g.restore();
    },
  };

  // ---------------------------------------------------------------- interface
  const root = document.createElement('div');
  root.id = 'pg';
  root.innerHTML = `<div class="pg-panel" role="dialog" aria-modal="true" aria-label="Acte médical">
    <header><div class="pg-ico"></div><div class="pg-head"><small>Acte médical</small><b></b></div><span class="pg-diff"></span></header>
    <p class="pg-hint" aria-live="polite"></p>
    <div class="pg-stage"><canvas width="${W}" height="${H}"></canvas><div class="pg-toast"></div><div class="pg-end"><div><b></b><span></span></div></div></div>
    <footer><div class="pg-prog"><i></i></div><span class="pg-step"></span><div class="pg-lives" aria-label="Erreurs restantes"></div><span class="pg-keys"></span></footer>
  </div>`;
  document.body.appendChild(root);
  const q = (s) => root.querySelector(s);
  const canvas = q('canvas'), g = canvas.getContext('2d');
  let toastT = 0;
  function toast(text, kind) {
    const t = q('.pg-toast'); t.textContent = text; t.className = `pg-toast on ${kind || ''}`;
    clearTimeout(toastT); toastT = setTimeout(() => { t.className = 'pg-toast'; }, 1300);
  }
  const DIFF = { 1: 'Facile', 2: 'Intermédiaire', 3: 'Difficile' };

  // ---------------------------------------------------------------- étapes réutilisables
  // Chaque étape : { hint, keys, cur, init(S), update(S, dt), draw(S, g), down/move/up(S, x, y), key(S, code, on) }
  // S.sub = avancement de l'étape (0-1) ; S.next() passe à la suivante.
  // spec / state : lecture seule de la définition et de l'état de l'étape (affichage de contrôle, tests hors jeu).
  const PH = {};

  // Choisir le bon élément (tube, zone d'injection, image…)
  PH.choose = (o) => ({
    hint: o.hint, keys: 'Clic : choisir', cur: true, type: 'choose', spec: o,
    draw(S, g) {
      if (o.scene) o.scene(S, g);
      for (const it of o.items) {
        const hov = S.m.x >= it.x && S.m.x <= it.x + it.w && S.m.y >= it.y && S.m.y <= it.y + it.h;
        if (it.shape === 'dot') {
          g.fillStyle = hov ? 'rgba(250,204,21,.55)' : 'rgba(255,255,255,.18)'; g.beginPath(); g.arc(it.x + it.w / 2, it.y + it.h / 2, it.w / 2, 0, Math.PI * 2); g.fill();
          g.strokeStyle = hov ? '#facc15' : 'rgba(255,255,255,.5)'; g.lineWidth = 2; g.stroke();
          if (it.label) D.text(g, it.label, it.x + it.w / 2, it.y - 12, { s: 11 });
          continue;
        }
        D.rr(g, it.x, it.y, it.w, it.h, 12); g.fillStyle = hov ? 'rgba(229,72,77,.22)' : 'rgba(148,178,230,.08)'; g.fill();
        g.strokeStyle = hov ? rgba(ACC, 0.9) : 'rgba(148,178,230,.3)'; g.lineWidth = 2; g.stroke();
        if (it.color) { D.rr(g, it.x + it.w / 2 - 14, it.y + 16, 28, it.h - 64, 10); g.fillStyle = '#e5e7eb'; g.fill(); g.fillStyle = it.color; g.fillRect(it.x + it.w / 2 - 14, it.y + 16, 28, 18); }
        if (it.draw) it.draw(g, it);
        D.text(g, it.label, it.x + it.w / 2, it.y + it.h - 24, { s: 12, w: 600 });
      }
    },
    down(S, x, y) {
      const it = o.items.find((i) => x >= i.x && x <= i.x + i.w && y >= i.y && y <= i.y + i.h);
      if (!it) return;
      if (o.expect !== undefined && it.id !== o.expect) return S.miss(o.wrong || 'Mauvais choix');
      if (o.setChoice) S.choice = it.id;
      S.good(o.goodMsg || 'Correct'); S.next();
    },
  });

  // Frotter une zone (désinfection, modelage du plâtre)
  PH.rub = (o) => {
    let cells = [], n = 0;
    return {
      hint: o.hint, keys: 'Clic maintenu + glisser', cursor: o.cursor || 'swab', type: 'rub', spec: o,
      init() {
        cells = [];
        for (let i = -6; i <= 6; i++) for (let j = -6; j <= 6; j++) { const x = o.cx + i * o.r / 6, y = o.cy + j * o.r / 6; if (dist(x, y, o.cx, o.cy) <= o.r) cells.push({ x, y, on: false }); }
        n = 0;
      },
      update(S) {
        if (!S.m.down) return;
        for (const c of cells) if (!c.on && dist(c.x, c.y, S.m.x, S.m.y) < 22) { c.on = true; n++; }
        S.sub = n / cells.length / (o.need || 0.85);
        if (S.sub >= 1) { S.good(o.done || 'Zone prête'); S.next(); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        g.strokeStyle = 'rgba(255,255,255,.35)'; g.setLineDash([6, 6]); g.lineWidth = 2; g.beginPath(); g.arc(o.cx, o.cy, o.r, 0, Math.PI * 2); g.stroke(); g.setLineDash([]);
        for (const c of cells) { g.fillStyle = c.on ? (o.tint || 'rgba(250,204,21,.22)') : 'rgba(120,90,60,.28)'; g.beginPath(); g.arc(c.x, c.y, o.r / 8, 0, Math.PI * 2); g.fill(); }
      },
    };
  };

  // Appuyer au bon moment (Espace ou clic) quand l'aiguille est dans la zone
  PH.timing = (o) => {
    let t = 0;
    const center = o.center ?? 0.5;
    return {
      hint: o.hint, keys: '<kbd>Espace</kbd> ou clic', cur: true, type: 'timing', spec: o,
      init() { t = 0; },
      update(S, dt) { t += dt * (o.speed || 0.6) * S.sp; },
      val() { return 0.5 + 0.5 * Math.sin(t * Math.PI * 2); },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        const w = (o.width || 0.16) * S.k;
        const v = this.val();
        D.hgauge(g, 150, 380, 460, 18, v, clamp(center - w / 2, 0, 1), clamp(center + w / 2, 0, 1), o.label, Math.abs(v - center) <= w / 2);
      },
      press(S) {
        const w = (o.width || 0.16) * S.k;
        if (Math.abs(this.val() - center) <= w / 2) { S.good(o.done || 'Parfait'); S.next(); } else S.miss(o.wrong || 'Trop tôt / trop tard');
      },
      down(S) { this.press(S); },
      key(S, code, on) { if (on && code === 'Space') this.press(S); },
    };
  };

  // Régler une valeur (clic maintenu + glisser, ou A / D) et la garder dans la zone
  PH.dial = (o) => {
    let v = 0, held = 0;
    return {
      hint: o.hint, keys: 'Clic maintenu + glisser · <kbd>A</kbd>/<kbd>D</kbd>', type: 'dial', spec: o, get state() { return { value: v, held }; },
      init(S) { v = o.from ?? (S.r() < 0.5 ? 0.1 : 0.9); held = 0; },
      update(S, dt) {
        if (S.key.KeyA || S.key.ArrowLeft) v -= dt * 0.45;
        if (S.key.KeyD || S.key.ArrowRight) v += dt * 0.45;
        if (S.m.down) v += (S.m.x - S.m.px) / 520;
        S.m.px = S.m.x;
        v = clamp(v + (o.drift ? Math.sin(S.t * 1.7) * dt * o.drift : 0), 0, 1);
        const w = (o.width || 0.1) * S.k;
        if (Math.abs(v - o.target) <= w / 2) held += dt; else held = Math.max(0, held - dt * 2);
        S.sub = held / (o.hold || 1.2);
        if (S.sub >= 1) { S.good(o.done || 'En place'); S.next(); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g, v);
        const w = (o.width || 0.1) * S.k;
        D.hgauge(g, 150, 390, 460, 16, v, clamp(o.target - w / 2, 0, 1), clamp(o.target + w / 2, 0, 1), o.label, Math.abs(v - o.target) <= w / 2);
      },
    };
  };

  // Maintenir le curseur (position verticale de la souris, clic maintenu) dans une zone qui bouge
  PH.track = (o) => {
    let fill = 0, out = 0, cur = 0.5, t0 = 0;
    return {
      hint: o.hint, keys: 'Clic maintenu · souris haut / bas', type: 'track', spec: o,
      init(S) { fill = 0; out = 0; t0 = S.r() * 10; },
      center(S) { return 0.5 + 0.28 * Math.sin((S.t + t0) * 0.8 * S.sp) + 0.1 * Math.sin((S.t + t0) * 2.1 * S.sp); },
      update(S, dt) {
        cur = clamp(1 - (S.m.y - 60) / 300, 0, 1);
        const w = (o.width || 0.2) * S.k, c = this.center(S);
        const inside = S.m.down && Math.abs(cur - c) <= w / 2;
        if (inside) { fill += dt / o.seconds; out = 0; } else if (S.m.down) { out += dt; }
        if (out > (o.grace || 1.3)) { out = 0; fill = Math.max(0, fill - 0.12); S.miss(o.lost || 'Cible perdue'); }
        S.sub = fill;
        if (fill >= 1) { S.good(o.done || 'Terminé'); S.next(); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g, fill, cur);
        const w = (o.width || 0.2) * S.k, c = this.center(S);
        D.vgauge(g, 64, 60, 26, 300, cur, clamp(c - w / 2, 0, 1), clamp(c + w / 2, 0, 1), o.label, S.m.down && Math.abs(cur - c) <= w / 2);
        if (!S.m.down) D.text(g, 'Maintenez le clic', 77, 40, { s: 11, c: '#fbbf24' });
      },
    };
  };

  // Cliquer des points dans l'ordre (bandes, sutures)
  PH.points = (o) => {
    let i = 0;
    return {
      hint: o.hint, keys: 'Clic : point suivant', cur: true, type: 'points', spec: o, get state() { return { next: i }; },
      init() { i = 0; },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        o.pts.forEach((p, k) => {
          g.fillStyle = k < i ? 'rgba(34,197,94,.8)' : (k === i ? 'rgba(250,204,21,.85)' : 'rgba(255,255,255,.25)');
          g.beginPath(); g.arc(p.x, p.y, (o.r || 14) * S.k, 0, Math.PI * 2); g.fill();
          D.text(g, String(k + 1), p.x, p.y, { s: 11, c: '#0f172a', w: 800 });
        });
      },
      down(S, x, y) {
        const p = o.pts[i];
        if (dist(x, y, p.x, p.y) <= (o.r || 14) * S.k + 6) { i++; S.sub = i / o.pts.length; if (i >= o.pts.length) { S.good(o.done || 'Terminé'); S.next(); } }
        else S.miss(o.wrong || 'Pas à cet endroit');
      },
    };
  };

  // Suivre un tracé en gardant le clic (insertion, extraction)
  PH.path = (o) => {
    let p = 0, active = false, check = 0;
    const segs = [];
    let total = 0;
    for (let k = 0; k < o.pts.length - 1; k++) { const a = o.pts[k], b = o.pts[k + 1]; const l = dist(a.x, a.y, b.x, b.y); segs.push({ a, b, l, s: total }); total += l; }
    const at = (u) => { const s = u * total; for (const sg of segs) if (s <= sg.s + sg.l) { const t = (s - sg.s) / sg.l; return { x: sg.a.x + (sg.b.x - sg.a.x) * t, y: sg.a.y + (sg.b.y - sg.a.y) * t }; } return o.pts[o.pts.length - 1]; };
    return {
      hint: o.hint, keys: 'Clic maintenu sur le point jaune + glisser', cursor: o.cursor, type: 'path', spec: o, get state() { return { p, active }; },
      init() { p = 0; active = false; check = 0; },
      down(S, x, y) { const h = at(p); if (dist(x, y, h.x, h.y) < 26) active = true; },
      up() { active = false; },
      update(S, dt) {
        if (!active || !S.m.down) { active = false; return; }
        let best = { d: 1e9, u: p };
        for (const sg of segs) { const r = segDist(S.m.x, S.m.y, sg.a.x, sg.a.y, sg.b.x, sg.b.y); if (r.d < best.d) best = { d: r.d, u: (sg.s + r.t * sg.l) / total }; }
        if (best.d > (o.tol || 16) * S.k) { active = false; p = check; S.miss(o.wrong || 'Vous sortez du tracé'); return; }
        const maxStep = dt * (o.maxSpeed || 0.5) * S.sp;
        if (best.u > p) p = Math.min(best.u, p + maxStep);
        if (p - check >= 0.25) check = Math.floor(p * 4) / 4;
        S.sub = p;
        if (p >= 0.995) { S.good(o.done || 'Terminé'); S.next(); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g, p);
        g.save(); g.lineWidth = (o.tol || 16) * S.k * 2; g.lineCap = 'round'; g.strokeStyle = 'rgba(96,165,250,.14)';
        g.beginPath(); g.moveTo(o.pts[0].x, o.pts[0].y); o.pts.slice(1).forEach((q2) => g.lineTo(q2.x, q2.y)); g.stroke();
        g.lineWidth = 2; g.setLineDash([6, 6]); g.strokeStyle = 'rgba(147,197,253,.8)'; g.stroke(); g.setLineDash([]); g.restore();
        const h = at(p); g.fillStyle = active ? OK : '#facc15'; g.beginPath(); g.arc(h.x, h.y, 9, 0, Math.PI * 2); g.fill();
        const e = o.pts[o.pts.length - 1]; g.strokeStyle = OK; g.lineWidth = 2; g.beginPath(); g.arc(e.x, e.y, 12, 0, Math.PI * 2); g.stroke();
      },
    };
  };

  // Faire glisser un objet sur une cible (compresse, pansement)
  PH.drop = (o) => {
    let x = o.from.x, y = o.from.y, held = false;
    return {
      hint: o.hint, keys: 'Glisser-déposer', cur: true, type: 'drop', spec: o,
      init() { x = o.from.x; y = o.from.y; held = false; },
      down(S, mx, my) { if (dist(mx, my, x, y) < 40) held = true; },
      move(S, mx, my) { if (held) { x = mx; y = my; } },
      up(S) {
        if (!held) return;
        held = false;
        if (dist(x, y, o.to.x, o.to.y) <= (o.r || 28) * S.k) { S.good(o.done || 'En place'); S.next(); }
        else { x = o.from.x; y = o.from.y; toast('À placer sur la plaie'); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        g.strokeStyle = 'rgba(34,197,94,.7)'; g.setLineDash([5, 5]); g.lineWidth = 2; g.beginPath(); g.arc(o.to.x, o.to.y, (o.r || 28) * S.k, 0, Math.PI * 2); g.stroke(); g.setLineDash([]);
        D.rr(g, x - 30, y - 22, 60, 44, 8); g.fillStyle = o.color || '#f1f5f9'; g.fill(); g.strokeStyle = 'rgba(0,0,0,.3)'; g.stroke();
        D.text(g, o.label || '', x, y, { s: 10, c: '#0f172a' });
      },
    };
  };

  // Tourner autour d'un point (bande enroulée)
  PH.circle = (o) => {
    let acc = 0, last = null;
    return {
      hint: o.hint, keys: 'Clic maintenu + tourner autour', cur: false, type: 'circle', spec: o,
      init() { acc = 0; last = null; },
      update(S) {
        if (!S.m.down) { last = null; return; }
        const d = dist(S.m.x, S.m.y, o.cx, o.cy);
        if (d < o.r * 0.5 || d > o.r * 1.9) { last = null; return; }
        const a = Math.atan2(S.m.y - o.cy, S.m.x - o.cx);
        if (last !== null) { let da = a - last; if (da > Math.PI) da -= Math.PI * 2; if (da < -Math.PI) da += Math.PI * 2; acc += Math.min(Math.abs(da), 0.25); }
        last = a;
        S.sub = acc / (Math.PI * 2 * (o.turns || 2));
        if (S.sub >= 1) { S.good(o.done || 'Bandage enroulé'); S.next(); }
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        g.strokeStyle = 'rgba(255,255,255,.25)'; g.lineWidth = o.r * 1.1; g.beginPath(); g.arc(o.cx, o.cy, o.r * 1.2, 0, Math.PI * 2); g.stroke();
        D.ring(g, o.cx, o.cy, o.r * 1.2, S.sub, '#e2e8f0');
      },
    };
  };

  // Trouver une position cachée et la tenir (échographie, palpation)
  // Image d'échographie (fœtus) préchargée une fois ; si elle manque, l'ancien dessin simplifié reste affiché
  const ECHO_FOETUS = new Image();
  ECHO_FOETUS.src = 'img/echo_foetus.webp';
  PH.find = (o) => {
    let tx = 0, ty = 0, prog = 0, clar = 0, ready = false;
    return {
      hint: o.hint, keys: o.freeze ? 'Clic maintenu · <kbd>Espace</kbd> figer l\'image' : 'Clic maintenu', cursor: o.cursor || 'probe', type: 'find', spec: o,
      get state() { return { x: tx, y: ty, prog, ready }; },
      init(S) { tx = o.x + 30 + S.r() * (o.w - 60); ty = o.y + 30 + S.r() * (o.h - 60); prog = 0; ready = false; },
      update(S, dt) {
        const dx = tx + Math.sin(S.t * 0.7) * 6, dy = ty + Math.cos(S.t * 0.9) * 5;
        clar = S.m.down ? clamp(1 - dist(S.m.x, S.m.y, dx, dy) / (170 * S.k), 0, 1) : 0;
        if (clar > 0.8) prog += dt / (o.hold || 3); else prog = Math.max(0, prog - dt * 0.4);
        prog = clamp(prog, 0, 1);
        S.sub = prog * 0.95;
        if (prog >= 1 && !ready) { ready = true; if (!o.freeze) { S.good(o.done || 'Trouvé'); S.next(); } else toast('Image nette : figez-la (Espace)', 'good'); }
        if (ready && prog < 0.7) ready = false;
      },
      key(S, code, on) {
        if (!on || code !== 'Space' || !o.freeze) return;
        if (ready) { S.good(o.done || 'Image enregistrée'); S.next(); } else S.miss(o.wrong || 'Image trop floue');
      },
      draw(S, g) {
        if (o.scene) o.scene(S, g);
        g.strokeStyle = 'rgba(148,178,230,.35)'; g.setLineDash([5, 6]); g.strokeRect(o.x, o.y, o.w, o.h); g.setLineDash([]);
        if (o.image) {
          const px = 470, py = 40, pw = 260, ph = 300;
          g.save(); g.beginPath(); g.moveTo(px + pw / 2, py); g.lineTo(px + pw, py + ph * 0.85); g.arc(px + pw / 2, py + ph * 0.2, ph * 0.75, 0.35 * Math.PI, 0.65 * Math.PI); g.closePath(); g.clip();
          g.fillStyle = '#05070b'; g.fillRect(px, py, pw, ph);
          const noise = 1 - clar;
          for (let i = 0; i < 380; i++) { const v = Math.random(); g.fillStyle = `rgba(255,255,255,${(0.04 + v * 0.22) * (0.35 + noise)})`; g.fillRect(px + Math.random() * pw, py + Math.random() * ph, 2, 2); }
          g.globalAlpha = clar; if (o.image === 'fetus') {
            // Image échographique d'un fœtus (html/img/echo_foetus.webp), dans le cône de la sonde : nette quand la sonde est bien placée
            if (ECHO_FOETUS.complete && ECHO_FOETUS.naturalWidth) {
              g.save(); g.filter = clar < 0.98 ? `blur(${((1 - clar) * 5).toFixed(1)}px)` : 'none';
              g.drawImage(ECHO_FOETUS, px, py, pw, ph); g.restore();
              g.globalAlpha = (1 - clar) * 0.6;
              for (let i = 0; i < 260; i++) { const v = Math.random(); g.fillStyle = `rgba(255,255,255,${0.05 + v * 0.18})`; g.fillRect(px + Math.random() * pw, py + Math.random() * ph, 2, 2); }
              g.globalAlpha = clar;
            } else { g.fillStyle = 'rgba(230,230,230,.85)'; g.beginPath(); g.ellipse(px + pw / 2, py + 170, 46, 34, 0.4, 0, Math.PI * 2); g.fill(); g.beginPath(); g.arc(px + pw / 2 + 36, py + 140, 22, 0, Math.PI * 2); g.fill(); }
          }
          else { g.fillStyle = 'rgba(220,220,220,.7)'; g.beginPath(); g.ellipse(px + pw / 2, py + 170, 60, 38, 0.2, 0, Math.PI * 2); g.fill(); g.fillStyle = '#05070b'; g.beginPath(); g.ellipse(px + pw / 2, py + 170, 26, 15, 0.2, 0, Math.PI * 2); g.fill(); }
          g.restore();
          D.text(g, `Netteté ${Math.round(clar * 100)} %`, px + pw / 2, py + ph + 14, { s: 12, c: clar > 0.8 ? OK : '#cbd5e1' });
        } else {
          D.hgauge(g, 470, 90, 250, 14, clar, 0.8, 1, 'Sensation sous les doigts', clar > 0.8);
        }
        D.ring(g, 600, 380, 22, prog, ready ? OK : '#93c5fd');
      },
    };
  };

  // Alertes à traiter pendant une progression (scanner : le patient bouge)
  PH.alerts = (o) => {
    let p = 0, next = 0, alert = 0;
    return {
      hint: o.hint, keys: '<kbd>E</kbd> ou clic : rassurer le patient', cur: true, type: 'alerts', spec: o, get state() { return { alert }; },
      init(S) { p = 0; next = 1.2 + S.r() * 2; alert = 0; },
      update(S, dt) {
        p += dt / o.seconds; S.sub = p;
        if (alert > 0) { alert -= dt; if (alert <= 0) { p = Math.max(0, p - 0.18); S.miss(o.wrong || 'Image bougée'); next = S.t + 1.5 + S.r() * 2.5; } }
        else if (S.t >= next && p < 0.92) alert = (o.window || 1.7) * S.k;
        if (p >= 1) { S.good(o.done || 'Acquisition terminée'); S.next(); }
      },
      calm(S) { if (alert > 0) { alert = 0; S.good('Patient rassuré'); next = S.t + 1.6 + S.r() * 2.6; } },
      down(S) { this.calm(S); },
      key(S, code, on) { if (on && code === 'KeyE') this.calm(S); },
      draw(S, g) {
        if (o.scene) o.scene(S, g, p);
        D.hgauge(g, 150, 390, 460, 14, p, 0, 0, 'Acquisition', true);
        if (alert > 0) { g.fillStyle = 'rgba(248,113,113,.18)'; g.fillRect(0, 0, W, H); D.text(g, '⚠ Le patient bouge ! [E]', W / 2, 60, { s: 20, c: '#fca5a5' }); }
      },
    };
  };

  // Étapes dans le bon ordre (cartes mélangées) ; une carte peut ouvrir une sous-étape
  PH.steps = (o) => {
    let order = [], i = 0, sub = null;
    const cardAt = (x, y) => order.find((c) => !c.done && x >= c.x && x <= c.x + c.w && y >= c.y && y <= c.y + c.h);
    return {
      type: 'steps', spec: o, get state() { return { cards: order, next: i, child: sub }; },
      get hint() { return sub ? sub.hint : o.hint; },
      get keys() { return sub ? sub.keys : 'Clic : étape suivante'; },
      get cur() { return sub ? sub.cur : true; },
      get cursor() { return sub ? sub.cursor : undefined; },
      init(S) {
        const list = o.steps.map((s, k) => ({ ...s, k, done: false }));
        for (let k = list.length - 1; k > 0; k--) { const j = Math.floor(S.r() * (k + 1)); [list[k], list[j]] = [list[j], list[k]]; }
        const cw = Math.min(170, (W - 40) / Math.ceil(list.length / 2) - 10);
        list.forEach((c, k) => { const row = k % 2, col = Math.floor(k / 2); c.x = 20 + col * (cw + 10); c.y = 330 + row * 50; c.w = cw; c.h = 42; });
        order = list; i = 0; sub = null;
      },
      update(S, dt) {
        if (!sub) { S.sub = i / o.steps.length; return; }
        const save = S.next;
        S.next = () => { sub = null; order.find((c) => c.k === i).done = true; i++; S.next = save; S.hint(this.hint); S.setKeys(); if (i >= o.steps.length) save(); };
        if (sub.update) sub.update(S, dt);
        if (sub) S.sub = (i + S.sub * 0.999) / o.steps.length;
        if (S.next !== save) S.next = save;
      },
      draw(S, g) {
        if (sub) { if (sub.draw) sub.draw(S, g); }
        else if (o.scene) o.scene(S, g, i);
        if (sub) return;
        for (const c of order) {
          D.rr(g, c.x, c.y, c.w, c.h, 9);
          const hov = !c.done && S.m.x >= c.x && S.m.x <= c.x + c.w && S.m.y >= c.y && S.m.y <= c.y + c.h;
          g.fillStyle = c.done ? 'rgba(34,197,94,.22)' : (hov ? 'rgba(229,72,77,.25)' : 'rgba(148,178,230,.09)'); g.fill();
          g.strokeStyle = c.done ? 'rgba(34,197,94,.7)' : 'rgba(148,178,230,.35)'; g.lineWidth = 1.5; g.stroke();
          D.text(g, (c.done ? '✓ ' : '') + c.label, c.x + c.w / 2, c.y + c.h / 2, { s: 11, w: 600, c: c.done ? '#86efac' : '#e2e8f0' });
        }
        D.text(g, `Étape ${Math.min(i + 1, o.steps.length)} / ${o.steps.length}`, W / 2, 312, { s: 12, c: '#93a3bf' });
      },
      forward(S, name, ...a) {
        if (!sub || !sub[name]) return;
        const save = S.next;
        S.next = () => { sub = null; order.find((c) => c.k === i).done = true; i++; S.next = save; S.hint(this.hint); S.setKeys(); if (i >= o.steps.length) save(); };
        sub[name](S, ...a);
        if (S.next !== save) S.next = save;
      },
      down(S, x, y) {
        if (sub) return this.forward(S, 'down', x, y);
        const c = cardAt(x, y);
        if (!c) return;
        if (c.k !== i) return S.miss('Mauvais ordre');
        if (c.sub) { sub = c.sub(); if (sub.init) sub.init(S); S.hint(sub.hint); S.setKeys(); return; }
        c.done = true; i++; S.good('✓');
        if (i >= o.steps.length) S.next();
      },
      move(S, x, y) { if (sub) this.forward(S, 'move', x, y); },
      up(S, x, y) { if (sub) this.forward(S, 'up', x, y); },
      key(S, code, on) { if (sub) this.forward(S, 'key', code, on); },
    };
  };

  // Attendre (développement du cliché, traitement)
  PH.wait = (o) => ({
    type: 'wait', hint: o.hint, keys: '', cur: true,
    update(S, dt) { S.sub += dt / (o.seconds || 1.2); if (S.sub >= 1) S.next(); },
    draw(S, g) { if (o.scene) o.scene(S, g); D.ring(g, W / 2, H / 2, 40, S.sub, '#93c5fd'); D.text(g, o.label || '…', W / 2, H / 2 + 64, { s: 13 }); },
  });

  // ---------------------------------------------------------------- scènes
  const limbKind = (x) => (x.full || x.region === 'body' ? 'body' : x.region === 'leg' ? 'leg' : 'arm');
  function woundScene(S, g, p, opts = {}) {
    const x = S.x;
    const kind = x.region === 'leg' || x.region === 'arm' ? limbKind(x) : null;
    if (kind) D.limb(g, 380, 200, 560, kind === 'leg' ? 150 : 110, 0, kind); else D.torso(g, 380, 200, 0.95);
    const bleed = opts.bleed ?? 1;
    g.fillStyle = `rgba(150,10,20,${0.45 + 0.4 * bleed})`; g.beginPath(); g.ellipse(380, 200, 26 + 30 * bleed, 16 + 18 * bleed, 0.3, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#5b0710'; g.beginPath(); g.ellipse(380, 200, 14, 6, 0.3, 0, Math.PI * 2); g.fill();
    D.text(g, x.zoneLabel || '', 380, 28, { s: 13, c: '#93a3bf' });
  }

  // ---------------------------------------------------------------- actes
  const GAMES = {};

  GAMES.blood = (S) => {
    const x = S.x;
    const tubes = list(x.tubes).map((t, k, a) => ({ id: t.id, label: t.label, color: t.color, x: W / 2 - (a.length * 190) / 2 + k * 190 + 10, y: 90, w: 170, h: 220 }));
    const veinY = (vx) => 230 + 16 * Math.sin(vx * 0.018 + S.seedA);
    const arm = (S2, g2) => {
      D.limb(g2, 400, 230, 640, 120, 0, 'arm');
      g2.strokeStyle = 'rgba(70,110,170,.35)'; g2.lineWidth = 7; g2.beginPath();
      for (let vx = 120; vx <= 680; vx += 8) { if (vx === 120) g2.moveTo(vx, veinY(vx)); else g2.lineTo(vx, veinY(vx)); } g2.stroke();
      g2.fillStyle = 'rgba(30,41,59,.85)'; g2.fillRect(170, 180, 30, 100); D.text(g2, 'garrot', 185, 168, { s: 10, c: '#94a3b8' });
    };
    let picked = { x: 0, y: 0 };
    return [
      PH.choose({ hint: `Choisissez le tube pour l'analyse : ${x.analysis || ''}.`, items: tubes, expect: x.expect, setChoice: true, wrong: 'Mauvais tube pour cette analyse' }),
      {
        type: 'vein', hint: 'Repérez la veine (bleutée) au pli du coude et cliquez dessus pour piquer.', keys: 'Clic : piquer', cursor: 'needle',
        draw(S2, g2) { arm(S2, g2); },
        down(S2, mx, my) {
          if (mx < 230 || mx > 680) return S2.miss('Piquez sur le bras, après le garrot');
          if (Math.abs(my - veinY(mx)) <= 9 * S2.k) { picked = { x: mx, y: veinY(mx) }; S2.good('Dans la veine'); S2.next(); } else S2.miss('Veine manquée');
        },
      },
      PH.track({
        hint: 'Gardez l\'aiguille dans la veine : suivez la zone avec la souris (clic maintenu) pendant que le tube se remplit.',
        seconds: Math.max(6, S.cfg.duration * 0.5), width: 0.22, label: 'Profondeur', lost: 'Veine perdue',
        scene(S2, g2, fill) {
          arm(S2, g2);
          g2.strokeStyle = '#e2e8f0'; g2.lineWidth = 3; g2.beginPath(); g2.moveTo(picked.x, picked.y); g2.lineTo(picked.x + 70, picked.y - 60); g2.stroke();
          D.rr(g2, 650, 70, 40, 200, 12); g2.fillStyle = '#e5e7eb'; g2.fill();
          g2.fillStyle = '#7f1d1d'; g2.fillRect(654, 70 + 196 * (1 - fill), 32, 196 * fill);
          const tube = tubes.find((t) => t.id === S2.choice); if (tube) { g2.fillStyle = tube.color; g2.fillRect(650, 60, 40, 18); }
        },
        done: 'Tube rempli',
      }),
    ];
  };

  GAMES.xray = (S) => {
    const x = S.x, kind = limbKind(x);
    const a0 = (S.r() - 0.5) * 0.7;
    const tgt = { x: 300 + S.r() * 160, y: 170 + S.r() * 60 };
    let ang = 0, held = 0;
    const scene = (S2, g2) => {
      g2.save(); g2.translate(tgt.x, tgt.y); g2.rotate(a0); D.limb(g2, 0, 0, 460, kind === 'leg' ? 130 : 96, 0, kind); g2.restore();
      g2.fillStyle = 'rgba(248,113,113,.25)'; g2.beginPath(); g2.arc(tgt.x, tgt.y, 16, 0, Math.PI * 2); g2.fill();
    };
    // clichés à valider : un seul est centré sur la zone et net
    const okShot = Math.floor(S.r() * 3);
    const shots = [0, 1, 2].map((k) => ({ id: k, label: `Cliché ${k + 1}`, x: 110 + k * 190, y: 90, w: 170, h: 220,
      draw(g2, it) {
        g2.fillStyle = '#0a0f18'; g2.fillRect(it.x + 15, it.y + 15, it.w - 30, it.h - 70);
        const off = it.id === okShot ? 0 : (it.id < okShot ? -30 : 30);
        g2.save(); g2.beginPath(); g2.rect(it.x + 15, it.y + 15, it.w - 30, it.h - 70); g2.clip();
        g2.fillStyle = 'rgba(235,240,245,.85)'; D.rr(g2, it.x + 30 + off, it.y + 70, it.w - 60, 22, 10); g2.fill();
        if (it.id !== okShot) { g2.fillStyle = 'rgba(10,15,24,.55)'; g2.fillRect(it.x + 15, it.y + 15, it.w - 30, it.h - 70); }
        g2.restore();
      } }));
    return [
      PH.dial({ hint: x.full ? 'Installez le patient allongé au centre de la table, puis maintenez.' : `Installez le patient : placez le membre (${x.zoneLabel || ''}) au centre de la plaque, puis maintenez.`, target: 0.5, width: 0.12, hold: Math.max(1.5, S.cfg.duration * 0.12), from: 0.85,
        label: 'Position sur la plaque', scene: (S2, g2, v) => { g2.fillStyle = 'rgba(148,178,230,.1)'; g2.fillRect(230, 90, 300, 220); g2.strokeStyle = 'rgba(148,178,230,.5)'; g2.strokeRect(230, 90, 300, 220);
          D.limb(g2, 380 + (v - 0.5) * 420, 200, 300, kind === 'leg' ? 110 : 80, 0, kind); }, done: 'Patient installé' }),
      {
        hint: x.full ? 'Centrez le cadre lumineux sur le patient et alignez-le sur l\'axe du corps (A / D ou molette).' : `Centrez le cadre lumineux sur la zone douloureuse (${x.zoneLabel || ''}) et alignez-le sur l'axe du membre (A / D ou molette).`,
        type: 'align', keys: 'Souris : position · <kbd>A</kbd>/<kbd>D</kbd> : rotation', cursor: 'none', get state() { return { x: tgt.x, y: tgt.y, a0, ang }; },
        update(S2, dt) {
          if (S2.key.KeyA || S2.key.KeyQ) ang -= dt * 0.8;
          if (S2.key.KeyD || S2.key.KeyE) ang += dt * 0.8;
          ang += S2.wheel * 0.0015; S2.wheel = 0;
          const okPos = dist(S2.m.x, S2.m.y, tgt.x, tgt.y) <= 20 * S2.k, okAng = Math.abs(ang - a0) <= 0.09 * S2.k;
          this.ok = okPos && okAng;
          held = this.ok ? held + dt : Math.max(0, held - dt * 2);
          S2.sub = held / 1.0;
          if (S2.sub >= 1) { S2.good('Repères alignés'); S2.next(); }
        },
        draw(S2, g2) {
          scene(S2, g2);
          g2.save(); g2.translate(S2.m.x, S2.m.y); g2.rotate(ang);
          g2.strokeStyle = this.ok ? OK : '#fde68a'; g2.lineWidth = 2; g2.fillStyle = this.ok ? 'rgba(34,197,94,.08)' : 'rgba(253,230,138,.08)';
          g2.fillRect(-110, -60, 220, 120); g2.strokeRect(-110, -60, 220, 120);
          g2.beginPath(); g2.moveTo(-120, 0); g2.lineTo(120, 0); g2.moveTo(0, -70); g2.lineTo(0, 70); g2.stroke(); g2.restore();
        },
      },
      PH.timing({ hint: 'Le patient doit être immobile : déclenchez le cliché quand le mouvement est au plus bas.', label: 'Mouvement du patient', center: 0.06, width: 0.2, speed: 0.35, scene, wrong: 'Cliché flou : le patient bougeait', done: 'Cliché pris' }),
      PH.wait({ hint: 'Développement du cliché…', label: 'Développement', seconds: 1.4, scene: (S2, g2) => { g2.fillStyle = '#0b1220'; g2.fillRect(0, 0, W, H); } }),
      PH.choose({ hint: 'Validez le cliché : choisissez celui qui est net et centré sur la zone examinée.', items: shots, expect: okShot, wrong: 'Cliché décentré : à refaire', goodMsg: 'Cliché validé' }),
    ];
  };

  GAMES.cast = (S) => {
    const x = S.x, kind = limbKind(x), plaster = x.material === 'platre';
    let bend = 0.75;
    const limb = (S2, g2, extra) => {
      g2.save(); g2.translate(380, 190); D.limb(g2, -120, 0, 260, kind === 'leg' ? 120 : 90, 0, kind); g2.translate(10, 0); g2.rotate((extra ?? 0) * 0.9);
      D.limb(g2, 120, 0, 260, kind === 'leg' ? 110 : 80, 0, kind); g2.restore();
    };
    const pulse = () => PH.choose({ hint: 'Vérifiez le pouls et la sensibilité en aval de la lésion.', scene: (S2, g2) => limb(S2, g2, 0),
      items: [{ id: 'proche', shape: 'dot', x: 150, y: 175, w: 30, h: 30 }, { id: 'lesion', shape: 'dot', x: 365, y: 175, w: 30, h: 30 }, { id: 'aval', shape: 'dot', x: 600, y: 175, w: 30, h: 30 }],
      expect: 'aval', wrong: 'Le pouls se prend en aval de la lésion', goodMsg: 'Pouls présent' });
    const align = () => PH.dial({ hint: 'Réalignez doucement le membre dans l\'axe (glissez ou A / D) et maintenez.', target: 0.5, width: 0.12, hold: 1.5, from: 0.9, label: 'Axe du membre',
      scene: (S2, g2, v) => { bend = (v - 0.5) * 1.2; limb(S2, g2, bend); }, done: 'Membre aligné' });
    const wraps = () => PH.points({ hint: plaster ? 'Déroulez les bandes plâtrées : cliquez les repères dans l\'ordre.' : 'Fixez l\'attelle : cliquez les attaches dans l\'ordre.',
      pts: [140, 250, 360, 470, 580].map((px) => ({ x: px, y: 190 + Math.sin(px) * 8 })), scene: (S2, g2) => { limb(S2, g2, 0); g2.fillStyle = plaster ? 'rgba(241,245,249,.55)' : 'rgba(59,130,246,.45)'; g2.fillRect(120, 150, 520, 80); } });
    const mold = () => PH.rub({ hint: 'Modelez et lissez le plâtre sur toute la zone.', cx: 380, cy: 190, r: 120, cursor: 'hand', need: 0.8, tint: 'rgba(241,245,249,.55)', scene: (S2, g2) => limb(S2, g2, 0), done: 'Plâtre lissé' });
    const steps = plaster
      ? [{ label: 'Pouls et sensibilité', sub: pulse }, { label: 'Aligner le membre', sub: align }, { label: 'Jersey et coton' }, { label: 'Bandes plâtrées', sub: wraps }, { label: 'Modeler', sub: mold }, { label: 'Contrôle circulation', sub: pulse }]
      : [{ label: 'Pouls et sensibilité', sub: pulse }, { label: 'Aligner le membre', sub: align }, { label: 'Rembourrage' }, { label: 'Placer l\'attelle' }, { label: 'Fixer les attaches', sub: wraps }, { label: 'Contrôle circulation', sub: pulse }];
    return [PH.steps({ hint: `${plaster ? 'Plâtre' : 'Attelle'} (${x.zoneLabel || ''}) : réalisez les étapes dans le bon ordre.`, steps, scene: (S2, g2) => limb(S2, g2, bend) })];
  };

  GAMES.hemostasis = (S) => {
    const x = S.x, sev = x.severity || 1;
    let pr = 0, prog = 0, out = 0, band = 0, assist = false;
    const base = [0.24, 0.18, 0.13][sev - 1] || 0.18;
    return [{
      hint: 'Appuyez sur la plaie (clic maintenu) et gardez une pression stable dans la zone verte. Relâchez un peu si la pression monte trop.',
      type: 'pressure', keys: 'Clic maintenu sur la plaie', cursor: 'hand', get state() { return { pressure: pr, band, prog }; },
      init(S2) { pr = 0; prog = 0; out = 0; S2.onAssist = () => { assist = true; toast('Un collègue vous aide', 'good'); }; },
      update(S2, dt) {
        const on = S2.m.down && dist(S2.m.x, S2.m.y, 380, 200) < 110;
        pr += (on ? 0.42 : -0.55) * dt * S2.sp;
        pr += Math.sin(S2.t * (2.2 + sev * 0.5)) * dt * 0.10 * S2.sp + (Math.sin(S2.t * 7.3) * 0.04 * dt * sev);
        pr = clamp(pr, 0, 1);
        band = base * S2.k + (assist ? (x.assistBonus || 0.06) : 0);
        const lo = 0.55 - band / 2, hi = 0.55 + band / 2;
        if (pr >= lo && pr <= hi) { prog += dt / (x.seconds || S2.cfg.duration); out = 0; }
        else if (prog > 0 || pr > 0.2) out += dt;
        if (pr > 0.97 && on) { pr = 0.8; S2.miss('Trop fort : le patient a très mal'); }
        if (out > 1.6) { out = 0; prog = Math.max(0, prog - 0.15); S2.miss('Le saignement reprend'); }
        S2.sub = prog;
        if (prog >= 1) { S2.good('Saignement contrôlé'); S2.next(); }
      },
      draw(S2, g2) {
        woundScene(S2, g2, prog, { bleed: 1 - prog * 0.85 });
        const lo = 0.55 - band / 2, hi = 0.55 + band / 2;
        D.vgauge(g2, 690, 60, 26, 300, pr, lo, hi, 'Pression', pr >= lo && pr <= hi);
        D.ring(g2, 70, 80, 26, prog, OK); D.text(g2, `${Math.ceil((1 - prog) * (x.seconds || 20))} s`, 70, 80, { s: 12 });
        if (assist) D.text(g2, 'Aide d\'un collègue', 70, 130, { s: 11, c: '#86efac' });
      },
    }];
  };

  GAMES.dressing = (S) => [
    PH.drop({ hint: 'Placez la compresse épaisse sur la plaie.', from: { x: 110, y: 360 }, to: { x: 380, y: 200 }, label: 'Compresse', scene: (S2, g2) => woundScene(S2, g2, 0, { bleed: 0.25 }) }),
    PH.circle({ hint: 'Enroulez la bande autour du membre (tournez autour de la plaie, clic maintenu).', cx: 380, cy: 200, r: 70, turns: 2, scene: (S2, g2) => { woundScene(S2, g2, 0, { bleed: 0.15 }); g2.fillStyle = '#f1f5f9'; D.rr(g2, 350, 178, 60, 44, 8); g2.fill(); } }),
    PH.timing({ hint: 'Serrez : la compression doit être ferme sans couper la circulation.', label: 'Serrage', center: 0.62, width: 0.18, speed: 0.4,
      scene: (S2, g2) => { woundScene(S2, g2, 0, { bleed: 0.05 }); g2.fillStyle = '#f8fafc'; g2.fillRect(320, 150, 120, 100); }, done: 'Pansement compressif posé', wrong: 'Trop lâche ou trop serré' }),
  ];

  GAMES.cpr = (S) => {
    const x = S.x, N = x.compressions || 30, bpm = x.bpm || 110, beat = 60 / bpm;
    const win = 0.13 * S.k;
    let n = 0, on = 0, t = 0, flash = 0, checked = -1;
    const pressed = new Set();
    const scorePct = () => (n ? on / n : 0);
    const phases = [];
    if (x.defib) phases.push(PH.timing({ hint: 'Défibrillateur : analyse du rythme. Choquez quand la charge est au maximum (écartez-vous !).', label: 'Charge', center: 0.9, width: 0.16, speed: 0.45, done: 'Choc délivré', wrong: 'Charge insuffisante' }));
    phases.push({
      hint: `Massage : appuyez sur Espace (ou clic) à chaque battement, ${bpm} par minute. ${N} compressions.`, keys: '<kbd>Espace</kbd> ou clic au rythme', cur: true,
      type: 'rhythm', get state() { return { t, beat, n, on }; },
      init() { n = 0; on = 0; t = -0.6; checked = -1; pressed.clear(); },
      update(S2, dt) {
        t += dt;
        // battements dont la fenêtre est passée sans appui : comptés comme manqués
        const due = Math.floor((t - win) / beat);
        for (let j = checked + 1; j <= due && n < N; j++) {
          if (j >= 0 && !pressed.has(j)) { n++; S2.mistakes++; S2.refresh(); toast('Battement manqué', 'bad'); }
        }
        if (due > checked) checked = due;
        S2.sub = n / N;
        S2.score = scorePct();
        if (n >= N) S2.next();
      },
      press(S2) {
        if (t < -win || n >= N) return;
        const b = Math.max(0, Math.round(t / beat)), off = Math.abs(t - b * beat);
        if (pressed.has(b) || b <= checked) return;
        pressed.add(b);
        n++;
        if (off <= win) { on++; flash = 0.18; } else { S2.mistakes++; S2.refresh(); toast(t - b * beat < 0 ? 'Trop tôt' : 'Trop tard', 'bad'); }
        S2.sub = n / N; S2.score = scorePct();
        if (n >= N) S2.next();
      },
      down(S2) { this.press(S2); },
      key(S2, code, d) { if (d && code === 'Space') this.press(S2); },
      draw(S2, g2) {
        D.torso(g2, 260, 220, 0.9);
        const ph = ((t % beat) + beat) % beat / beat;
        const r = 40 + 30 * (1 - ph);
        g2.strokeStyle = 'rgba(248,113,113,.9)'; g2.lineWidth = 4; g2.beginPath(); g2.arc(260, 200, r, 0, Math.PI * 2); g2.stroke();
        g2.fillStyle = flash > 0 ? 'rgba(34,197,94,.7)' : 'rgba(248,113,113,.35)'; g2.beginPath(); g2.arc(260, 200, 36, 0, Math.PI * 2); g2.fill();
        flash = Math.max(0, flash - 1 / 60);
        D.text(g2, `${n} / ${N}`, 260, 200, { s: 18 });
        D.text(g2, `Dans le rythme : ${Math.round(scorePct() * 100)} %`, 560, 160, { s: 16, c: scorePct() >= (x.pass || 0.6) ? '#86efac' : '#fca5a5' });
        D.text(g2, `Objectif : ${Math.round((x.pass || 0.6) * 100)} %`, 560, 190, { s: 12, c: '#93a3bf' });
        for (let k = 0; k < 8; k++) { const bx = 470 + k * 30; const tt = (Math.floor(t / beat) + k) * beat - t; g2.fillStyle = k === 0 ? '#fca5a5' : 'rgba(255,255,255,.25)'; g2.beginPath(); g2.arc(bx + (tt / beat) * 30, 250, 6, 0, Math.PI * 2); g2.fill(); }
      },
    });
    phases.push(PH.timing({ hint: 'Deux insufflations : tête basculée, menton relevé. Insufflez quand la jauge est dans la zone.', label: 'Insufflation', center: 0.55, width: 0.3, speed: 0.5, done: 'Insufflation', wrong: 'Insufflation inefficace' }));
    phases.push(PH.timing({ hint: 'Deuxième insufflation.', label: 'Insufflation', center: 0.55, width: 0.3, speed: 0.5, done: 'Séquence terminée', wrong: 'Insufflation inefficace' }));
    S.lenient = true;   // le nombre de battements manqués compte dans le score, pas comme une limite
    return phases;
  };

  GAMES.echo = (S) => {
    const x = S.x, preg = x.type === 'pregnancy';
    return [
      PH.rub({ hint: 'Appliquez le gel sur la zone à examiner.', cx: 260, cy: 230, r: 100, cursor: 'hand', tint: 'rgba(147,197,253,.35)', need: 0.75, scene: (S2, g2) => D.torso(g2, 260, 220, 1), done: 'Gel appliqué' }),
      PH.find({ hint: preg ? 'Déplacez la sonde (clic maintenu) jusqu\'à obtenir une image nette, puis figez-la avec Espace.' : 'Balayez la zone avec la sonde (clic maintenu) jusqu\'à une image nette, puis figez-la (Espace).',
        x: 150, y: 110, w: 220, h: 240, hold: Math.max(3, S.cfg.duration * 0.25), image: preg ? 'fetus' : 'organ', freeze: true, scene: (S2, g2) => D.torso(g2, 260, 220, 1), done: 'Image enregistrée' }),
    ];
  };

  GAMES.scan = (S) => {
    const tgt = 0.25 + S.r() * 0.5;
    const table = (S2, g2, v) => {
      const off = ((v ?? tgt) - tgt) * 500;
      g2.fillStyle = '#1e293b'; D.rr(g2, 80, 220, 600, 40, 10); g2.fill();
      g2.fillStyle = '#334155'; g2.beginPath(); g2.arc(380, 200, 150, Math.PI, 0); g2.lineTo(530, 270); g2.lineTo(230, 270); g2.closePath(); g2.globalAlpha = 0.45; g2.fill(); g2.globalAlpha = 1;
      g2.save(); g2.translate(off, 0); g2.fillStyle = SKIN; D.rr(g2, 180, 205, 420, 34, 16); g2.fill(); g2.beginPath(); g2.arc(170, 222, 22, 0, Math.PI * 2); g2.fill();
      g2.fillStyle = 'rgba(248,113,113,.45)'; g2.fillRect(380 - 6, 200, 12, 50); g2.restore();
      g2.strokeStyle = '#ef4444'; g2.lineWidth = 2; g2.beginPath(); g2.moveTo(380, 120); g2.lineTo(380, 300); g2.stroke();
    };
    const thumbs = [0, 1, 2].map((k) => ({ id: k, label: `Coupe ${k + 1}`, x: 110 + k * 190, y: 90, w: 170, h: 220 }));
    const good = Math.floor(S.r() * 3);
    thumbs.forEach((tb) => { tb.draw = (g2, it) => { g2.fillStyle = '#05070b'; g2.fillRect(it.x + 15, it.y + 15, it.w - 30, it.h - 70); g2.fillStyle = 'rgba(220,220,220,.7)'; g2.beginPath(); g2.ellipse(it.x + it.w / 2, it.y + 90, 45, 55, 0, 0, Math.PI * 2); g2.fill();
      if (it.id !== good) { g2.strokeStyle = 'rgba(255,255,255,.5)'; for (let l = 0; l < 6; l++) { g2.beginPath(); g2.moveTo(it.x + 20, it.y + 30 + l * 22); g2.lineTo(it.x + it.w - 20, it.y + 36 + l * 22); g2.stroke(); } } }; });
    return [
      PH.dial({ hint: 'Positionnez la table pour placer le repère rouge sous le laser, puis maintenez.', target: tgt, width: 0.06, hold: 1.2, label: 'Position de la table', scene: table, done: 'Patient en place' }),
      PH.alerts({ hint: 'Acquisition en cours : rassurez le patient dès qu\'il bouge (E ou clic).', seconds: Math.max(6, S.cfg.duration * 0.4), scene: (S2, g2) => table(S2, g2, tgt) }),
      PH.choose({ hint: 'Validez les images : choisissez la coupe sans artefact de mouvement.', items: thumbs, expect: good, wrong: 'Image floue : regardez mieux', goodMsg: 'Images validées' }),
    ];
  };

  GAMES.vaccine = (S) => {
    const x = S.x;
    const zones = list(x.zones).map((z) => ({ id: z.id, label: z.label }));
    const pos = { deltoide: { x: 300, y: 110 }, cuisse: { x: 320, y: 330 }, fesse: { x: 455, y: 250 } };
    const body = (S2, g2) => {
      g2.fillStyle = SKIN; g2.beginPath(); g2.arc(380, 60, 30, 0, Math.PI * 2); g2.fill();
      D.rr(g2, 320, 95, 120, 170, 40); g2.fill(); D.rr(g2, 285, 100, 34, 140, 16); g2.fill(); D.rr(g2, 441, 100, 34, 140, 16); g2.fill();
      D.rr(g2, 328, 255, 48, 110, 20); g2.fill(); D.rr(g2, 384, 255, 48, 110, 20); g2.fill();
    };
    const items = zones.map((z) => { const p = pos[z.id] || { x: 380, y: 200 }; return { id: z.id, shape: 'dot', x: p.x - 16, y: p.y - 16, w: 32, h: 32, label: z.label }; });
    const site = pos[x.expect] || { x: 300, y: 110 };
    const expectLabel = (zones.find((z) => z.id === x.expect) || {}).label || '';
    return [
      PH.choose({ hint: `Vaccin ${x.vaccine || ''} : zone d'injection indiquée : ${expectLabel}. Cliquez dessus.`, scene: body, items, expect: x.expect, setChoice: true, wrong: 'Ce n\'est pas la zone indiquée', goodMsg: 'Zone repérée' }),
      PH.rub({ hint: 'Désinfectez la zone d\'injection.', cx: site.x, cy: site.y, r: 50, scene: body, done: 'Zone désinfectée' }),
      PH.timing({ hint: 'Piquez avec un angle de 90° : appuyez quand l\'aiguille est droite.', label: 'Angle de l\'aiguille', center: 0.5, width: 0.14, speed: 0.55, scene: body, done: 'Aiguille en place', wrong: 'Mauvais angle' }),
      PH.dial({ hint: 'Injectez lentement : poussez le piston (glissez vers la droite ou D) en gardant la vitesse dans la zone.', target: 0.5, width: 0.22, hold: Math.max(3, S.cfg.duration * 0.25), from: 0.2, drift: 0.25,
        label: 'Vitesse d\'injection', scene: body, done: 'Vaccin injecté' }),
    ];
  };

  const skinPatch = (S2, g2) => { D.limb(g2, 380, 200, 640, 170, 0, 'arm'); D.text(g2, 'Face interne du bras', 380, 40, { s: 12, c: '#93a3bf' }); };
  GAMES.implant = (S) => [
    PH.rub({ hint: 'Désinfectez la face interne du bras.', cx: 380, cy: 200, r: 90, scene: skinPatch, done: 'Zone désinfectée' }),
    PH.timing({ hint: 'Anesthésie locale : injectez quand la jauge est dans la zone.', label: 'Anesthésie', center: 0.5, width: 0.16, speed: 0.5, scene: skinPatch, done: 'Anesthésie faite' }),
    PH.path({ hint: 'Insérez l\'implant sous la peau : suivez le tracé sans en sortir (clic maintenu).', pts: [{ x: 210, y: 210 }, { x: 380, y: 200 }, { x: 560, y: 196 }], tol: 14, maxSpeed: 0.22,
      cursor: 'needle', scene: (S2, g2, p) => { skinPatch(S2, g2); g2.strokeStyle = 'rgba(255,255,255,.6)'; g2.lineWidth = 4; g2.beginPath(); g2.moveTo(210, 210); g2.lineTo(210 + 350 * p, 210 - 14 * p); g2.stroke(); }, done: 'Implant en place' }),
    PH.drop({ hint: 'Posez le pansement compressif sur le point d\'entrée.', from: { x: 110, y: 360 }, to: { x: 210, y: 210 }, label: 'Pansement', scene: skinPatch, done: 'Pansement posé' }),
  ];

  GAMES.implant_remove = (S) => [
    PH.rub({ hint: 'Désinfectez la face interne du bras.', cx: 380, cy: 200, r: 90, scene: skinPatch, done: 'Zone désinfectée' }),
    PH.find({ hint: 'Palpez pour localiser l\'implant (clic maintenu) et restez dessus.', x: 200, y: 120, w: 360, h: 160, hold: Math.max(2.5, S.cfg.duration * 0.2), image: false, cursor: 'hand', scene: skinPatch, done: 'Implant localisé' }),
    PH.timing({ hint: 'Petite incision à l\'extrémité de l\'implant.', label: 'Incision', center: 0.5, width: 0.14, speed: 0.5, scene: skinPatch, done: 'Incision faite' }),
    PH.path({ hint: 'Retirez l\'implant doucement en suivant son axe (clic maintenu).', pts: [{ x: 560, y: 196 }, { x: 380, y: 200 }, { x: 240, y: 210 }], tol: 16, maxSpeed: 0.25, cursor: 'hand', scene: skinPatch, done: 'Implant retiré' }),
    PH.drop({ hint: 'Posez le pansement.', from: { x: 110, y: 360 }, to: { x: 560, y: 196 }, label: 'Pansement', scene: skinPatch, done: 'Pansement posé' }),
  ];

  // ---------------------------------------------------------------- moteur
  const MG = { cur: null, games: GAMES };
  window.ProcMG = MG;
  let raf = 0;

  function refresh(S) {
    q('.pg-prog i').style.width = `${Math.min(100, ((S.pi + clamp(S.sub, 0, 1)) / S.phases.length) * 100)}%`;
    q('.pg-step').textContent = `Étape ${Math.min(S.pi + 1, S.phases.length)} / ${S.phases.length}`;
    const lives = q('.pg-lives');
    const max = S.lenient ? 0 : S.max;
    if (S.lenient) { if (lives.childElementCount) lives.innerHTML = ''; }
    else if (lives.childElementCount !== max + 1) { lives.innerHTML = ''; for (let i = 0; i <= max; i++) lives.appendChild(document.createElement('i')); }
    if (!S.lenient) [...lives.children].forEach((el, i) => el.classList.toggle('lost', i >= max + 1 - S.mistakes));
  }
  function setKeys(S) { const ph = S.phases[S.pi]; q('.pg-keys').innerHTML = `${ph && ph.keys ? ph.keys + ' · ' : ''}<kbd>Échap</kbd> annuler`; canvas.classList.toggle('cur', !!(ph && ph.cur)); }

  function finish(S, ok, reason) {
    if (S.ended) return;
    S.ended = true;
    const box = q('.pg-end');
    const send2 = () => {
      const res = { id: S.cfg.id, ok, mistakes: S.lenient ? Math.min(S.mistakes, S.cfg.maxMistakes) : S.mistakes, cancelled: reason === 'cancel', reason: reason || null, choice: S.choice ?? null,
        score: Math.round(clamp(S.score ?? (1 - S.mistakes / (S.max + 2)), 0, 1) * 1000) / 1000 };
      if (MG.cur === S) close();
      send('procResult', res);
      if (MG.onResult) MG.onResult(res);
    };
    box.className = `pg-end on ${ok ? 'ok' : 'ko'}`;
    box.querySelector('b').textContent = ok ? 'Réussi !' : (reason === 'cancel' ? 'Annulé' : 'Raté');
    box.querySelector('span').textContent = ok ? 'Vérification…' : (reason === 'time' ? 'Temps écoulé' : reason === 'cancel' ? '' : 'Trop d\'erreurs');
    // un acte ne peut pas être plus court qu'une part de sa durée prévue (le serveur le vérifie aussi)
    const minMs = ok ? S.cfg.duration * 1000 * 0.42 - (performance.now() - S.t0) : 0;
    if (minMs > 0) box.querySelector('span').textContent = 'Finition des gestes…';
    setTimeout(send2, Math.max(ok ? 650 : 900, minMs));
  }
  function close() { cancelAnimationFrame(raf); raf = 0; root.classList.remove('on'); MG.cur = null; }

  MG.start = (cfg) => {
    if (MG.cur) close();
    const build = GAMES[cfg.act];
    if (!build) { send('procResult', { id: cfg.id, ok: false, cancelled: true, mistakes: 0, score: 0, reason: 'type' }); return; }
    const d = clamp(cfg.difficulty | 0 || 2, 1, 3);
    q('.pg-ico').textContent = cfg.icon || '🩺';
    q('.pg-head b').textContent = cfg.title || '';
    q('.pg-diff').textContent = DIFF[d];
    q('.pg-end').className = 'pg-end';
    const S = {
      cfg, x: cfg.extra || {}, r: rng(cfg.seed || 1), k: [1.35, 1, 0.75][d - 1], sp: [0.8, 1, 1.22][d - 1], seedA: 0,
      pi: 0, sub: 0, mistakes: 0, max: Math.max(0, cfg.maxMistakes | 0), t: 0, t0: performance.now(), limit: Math.max(20, (cfg.duration || 30) * 3) * 1000,
      ended: false, m: { x: W / 2, y: H / 2, px: W / 2, down: false }, key: {}, wheel: 0, choice: null, score: null, lastMiss: -1e9,
      miss(msg) {
        if (S.ended) return;
        const now = performance.now(); if (now - S.lastMiss < 400) return; S.lastMiss = now;
        S.mistakes++; refresh(S); toast(msg || 'Erreur', 'bad');
        q('.pg-stage').animate([{ transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'none' }], { duration: 180 });
        if (!S.lenient && S.mistakes > S.max) finish(S, false, 'mistakes');
      },
      good(msg) { if (msg) toast(msg, 'good'); },
      hint(t) { q('.pg-hint').textContent = t || ''; },
      setKeys() { setKeys(S); },
      refresh() { refresh(S); },
      next() {
        if (S.ended) return;
        S.pi++; S.sub = 0;
        if (S.pi >= S.phases.length) return finish(S, true);
        const ph = S.phases[S.pi]; if (ph.init) ph.init(S);
        S.hint(ph.hint); setKeys(S); refresh(S);
      },
    };
    S.seedA = S.r() * 6;
    S.phases = build(S);
    const ph0 = S.phases[0]; if (ph0.init) ph0.init(S);
    S.hint(ph0.hint); setKeys(S);
    MG.cur = S;
    refresh(S);
    root.classList.add('on');
    let last = performance.now();
    const loop = (now) => {
      if (MG.cur !== S) return;
      const dt = Math.min(0.05, (now - last) / 1000); last = now;
      const ph = S.phases[S.pi];
      if (!S.ended) {
        S.t += dt;
        if (now - S.t0 > S.limit) finish(S, false, 'time');
        else if (ph && ph.update) ph.update(S, dt);
        refresh(S);
      }
      D.bg(g);
      const cp = S.phases[Math.min(S.pi, S.phases.length - 1)];
      g.save(); if (cp && cp.draw) cp.draw(S, g); g.restore();
      if (cp && !cp.cur && cp.cursor !== 'none') D.cursor(g, S.m.x, S.m.y, S.m.down, cp.cursor);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
  };
  MG.stop = () => { if (MG.cur) close(); };
  MG.assist = () => { if (MG.cur && MG.cur.onAssist) MG.cur.onAssist(); };

  // ---------------------------------------------------------------- entrées
  const pos = (e) => { const r = canvas.getBoundingClientRect(); return { x: ((e.clientX - r.left) / r.width) * W, y: ((e.clientY - r.top) / r.height) * H }; };
  const cur = () => MG.cur && MG.cur.phases[MG.cur.pi];
  canvas.setAttribute('draggable', 'false');
  ['dragstart', 'selectstart', 'contextmenu'].forEach((t) => root.addEventListener(t, (e) => e.preventDefault()));
  canvas.addEventListener('pointerdown', (e) => {
    const S = MG.cur; if (!S || S.ended) return;
    e.preventDefault();
    const p = pos(e); S.m.px = p.x; S.m.x = p.x; S.m.y = p.y; S.m.down = true;
    try { canvas.setPointerCapture(e.pointerId); } catch (_) { /* rien */ }
    const ph = cur(); if (ph && ph.down) ph.down(S, p.x, p.y);
  });
  canvas.addEventListener('pointermove', (e) => {
    const S = MG.cur; if (!S) return;
    const p = pos(e); S.m.x = p.x; S.m.y = p.y;
    if (!S.m.down && (e.buttons & 1) && !S.ended) S.m.down = true;
    const ph = cur(); if (!S.ended && ph && ph.move) ph.move(S, p.x, p.y);
  });
  const up = (e) => {
    const S = MG.cur; if (!S || !S.m.down) return;
    S.m.down = false;
    const ph = cur(); if (!S.ended && ph && ph.up) { const p = e ? pos(e) : S.m; ph.up(S, p.x, p.y); }
  };
  window.addEventListener('pointerup', (e) => { if (e.button === 0 || !(e.buttons & 1)) up(e); });
  canvas.addEventListener('wheel', (e) => { if (MG.cur) { MG.cur.wheel += e.deltaY; e.preventDefault(); } }, { passive: false });
  // Échap est géré ici avant le reste de l'interface (capture) : il annule l'acte
  window.addEventListener('keydown', (e) => {
    const S = MG.cur;
    if (S) {
      e.stopImmediatePropagation();
      if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); finish(S, false, 'cancel'); return; }
      if (e.code === 'Space') e.preventDefault();
      if (S.key[e.code]) return; S.key[e.code] = true;
      const ph = cur(); if (!S.ended && ph && ph.key) ph.key(S, e.code, true);
      return;
    }
    if (UI.handleKey(e)) e.stopImmediatePropagation();
  }, true);
  window.addEventListener('keyup', (e) => { const S = MG.cur; if (!S) return; S.key[e.code] = false; const ph = cur(); if (!S.ended && ph && ph.key) ph.key(S, e.code, false); }, true);

  // ---------------------------------------------------------------- fenêtres
  const wrap = (id, cls = '') => { const w = document.createElement('div'); w.id = id; w.className = `modal-wrap hidden ${cls}`; w.innerHTML = '<div class="modal" role="dialog" aria-modal="true"></div>'; document.body.appendChild(w); return w; };
  const pick = wrap('procPick'), ask = wrap('procAsk', 'top'), consent = wrap('procConsent', 'top');
  const wait = document.createElement('div'); wait.id = 'procWait'; wait.className = 'hidden'; wait.setAttribute('aria-live', 'polite'); document.body.appendChild(wait);
  const report = document.createElement('div'); report.id = 'procReport'; report.className = 'hidden'; report.setAttribute('aria-live', 'polite'); document.body.appendChild(report);
  const showEl = (el, on) => el.classList.toggle('hidden', !on);
  let PK = null, consentTok = null, consentT = 0, reportT = 0;

  const list = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));   // table Lua vide : {}
  function pickRender() {
    const d = PK;
    const acts = list(d.acts);
    acts.forEach((a) => { if (a.choices !== undefined) a.choices = list(a.choices); });
    pick.querySelector('.modal').innerHTML = `<div class="eyebrow">Actes et examens · ID ${d.patient.id}</div><h2>${E(d.patient.name)}</h2>
      <p class="lead">${d.patient.down ? 'Patient inconscient : seuls les actes d\'urgence ou sans consentement sont possibles.' : 'Les actes marqués « consentement » demandent l\'accord du patient.'}</p>
      <div class="pk-list">${acts.map((a) => `<div class="pk-act ${a.disabled ? 'off' : ''}"><h3><span>${a.icon}</span>${E(a.label)}</h3>
        <small>${a.disabled ? E(a.reason || 'Indisponible') : (a.consent ? '<span class="pk-consent">Consentement demandé</span>' : 'Acte d\'urgence / sans consentement')}</small>
        <div class="pk-ch">${a.disabled ? '' : (a.choices ? a.choices.map((c, k) => `<button class="btn small ${c.warn ? 'warn' : ''}" data-pk="${E(a.id)}" data-k="${k}" title="${E(c.warn || c.sub || '')}">${E(c.label)}${c.sub ? ` <small>· ${E(c.sub)}</small>` : ''}</button>`).join('') : `<button class="btn small primary" data-pk="${E(a.id)}">Commencer</button>`)}
          ${a.assist ? `<button class="btn small success" data-pk="${E(a.id)}" data-assist="1">Aider à la compression</button>` : ''}</div></div>`).join('')}</div>
      <div class="actions"><button class="btn" data-pkc="1">Fermer</button></div>`;
  }
  pick.addEventListener('click', (e) => {
    if (e.target.closest('[data-pkc]') || e.target === pick) return send('close', { ui: 'proc' });
    const b = e.target.closest('[data-pk]');
    if (!b || !PK) return;
    const a = list(PK.acts).find((x) => x.id === b.dataset.pk);
    if (!a) return;
    if (b.dataset.assist) return send('procChoose', { act: a.id, target: PK.patient.id, assist: true });
    const c = a.choices && a.choices[Number(b.dataset.k)];
    const choice = c ? { [c.key]: c.value } : {};
    if (c && c.material) choice.material = c.material;
    send('procChoose', { act: a.id, target: PK.patient.id, choice, label: c ? c.label : null });
  });

  function askShow(m) {
    if (!m.show) return showEl(ask, false);
    ask.querySelector('.modal').innerHTML = `<h2>${E(m.title)}</h2><p class="lead" style="white-space:pre-line">${E(m.text)}</p>
      <div class="actions"><button class="btn" data-ask="0">${E(m.no || 'Non')} <span class="kbd">Échap</span></button><button class="btn primary" data-ask="1">${E(m.yes || 'Oui')} <span class="kbd">Entrée</span></button></div>`;
    showEl(ask, true);
  }
  ask.addEventListener('click', (e) => { const b = e.target.closest('[data-ask]'); if (b) { showEl(ask, false); send('procAsk', { yes: b.dataset.ask === '1' }); } });

  function consentShow(m) {
    clearInterval(consentT);
    if (!m.show) { consentTok = null; return showEl(consent, false); }
    consentTok = m.token;
    let left = m.timeout || 25;
    const draw = () => {
      consent.querySelector('.modal').innerHTML = `<div class="eyebrow">Consentement</div><h2>${E(m.title)}</h2><p class="lead">${E(m.text)}</p>
        <p class="count">Réponse attendue : ${left} s</p>
        <div class="actions"><button class="btn danger" data-cs="0">Refuser <span class="kbd">Échap</span></button><button class="btn primary" data-cs="1">Accepter <span class="kbd">Entrée</span></button></div>`;
    };
    draw();
    consentT = setInterval(() => { left--; if (left <= 0) { clearInterval(consentT); return; } const c = consent.querySelector('.count'); if (c) c.textContent = `Réponse attendue : ${left} s`; }, 1000);
    showEl(consent, true);
  }
  const answer = (yes) => { if (!consentTok) return; const t = consentTok; consentTok = null; clearInterval(consentT); showEl(consent, false); send('procConsent', { token: t, yes }); };
  consent.addEventListener('click', (e) => { const b = e.target.closest('[data-cs]'); if (b) answer(b.dataset.cs === '1'); });

  const UI = {
    handleKey(e) {
      if (consentTok && !consent.classList.contains('hidden')) {
        if (e.key === 'Escape') { e.preventDefault(); answer(false); return true; }
        if (e.key === 'Enter') { e.preventDefault(); answer(true); return true; }
      }
      if (!ask.classList.contains('hidden')) {
        if (e.key === 'Escape') { e.preventDefault(); showEl(ask, false); send('procAsk', { yes: false }); return true; }
        if (e.key === 'Enter') { e.preventDefault(); showEl(ask, false); send('procAsk', { yes: true }); return true; }
      }
      if (!pick.classList.contains('hidden') && e.key === 'Escape') { e.preventDefault(); send('close', { ui: 'proc' }); return true; }
      return false;
    },
  };

  window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    switch (m.action) {
      case 'proc:start': return MG.start(m.game || {});
      case 'proc:stop': return MG.stop();
      case 'proc:assist': return MG.assist();
      case 'proc:pick': if (m.show) { PK = m.data; pickRender(); showEl(pick, true); } else showEl(pick, false); return;
      case 'proc:ask': return askShow(m);
      case 'proc:wait': wait.textContent = m.text || ''; return showEl(wait, !!m.show);
      case 'proc:consent': return consentShow(m);
      case 'proc:report':
        report.innerHTML = `<b>${E(m.title || 'Compte rendu')}</b>${E(m.text)}`; showEl(report, true);
        clearTimeout(reportT); reportT = setTimeout(() => showEl(report, false), Math.min(25000, 9000 + String(m.text || '').length * 40)); return;
      case 'closeAll': MG.stop(); showEl(pick, false); showEl(ask, false); showEl(consent, false); showEl(wait, false); return;
    }
  });
})();
