/* =====================================================================
   ELYZEA EMS - carte de la tablette (canvas)
   Coordonnées du jeu (x vers l'est, y vers le nord). Fond : image satellite
   (html/img/map.jpg + bornes dans Config.MapImage) ou, sans image, carte tactique dessinée.
   ===================================================================== */
(() => {
  // Contour schématique de l'île de San Andreas (coordonnées du jeu, approximatives)
  const ISLAND = [[1750, -3300], [1050, -3420], [300, -3250], [-450, -3450], [-1150, -3650], [-1900, -3250], [-2050, -2450], [-1700, -1500], [-1850, -1150], [-2300, -400],
    [-3050, 400], [-3350, 1100], [-3150, 1800], [-2900, 2500], [-2850, 3300], [-2550, 4050], [-1900, 4900], [-1400, 5450], [-750, 6300], [-150, 6950], [450, 7150],
    [1300, 6800], [2200, 6250], [3050, 5550], [3700, 4700], [3900, 3700], [3650, 2500], [3200, 1300], [2800, 300], [2450, -700], [2100, -1700], [1950, -2650]];
  const LAKE = [[700, 3950], [1300, 3650], [2050, 3780], [2450, 4250], [2200, 4700], [1500, 4800], [950, 4500]];
  const ZONES = [['Los Santos', 150, -950, 1.15], ['Vinewood Hills', 250, 900], ['Aéroport LS', -1250, -2900], ['Port de LS', 950, -3000], ['Vespucci', -1300, -1250],
    ['Sandy Shores', 1850, 3700], ['Grapeseed', 1900, 4950], ['Paleto Bay', -200, 6350], ['Mont Chiliad', 500, 5550], ['Fort Zancudo', -2250, 3100], ['Chumash', -3050, 950],
    ['Lac Alamo', 1500, 4250], ['Grand Senora', 1900, 2900], ['Tataviam', 2500, -150], ['Mirror Park', 1150, -600], ['Paleto Forest', -800, 5400]];
  const BOUNDS = { minX: -4200, maxX: 4600, minY: -4200, maxY: 8200 };

  function create(box, opts = {}) {
    const canvas = document.createElement('canvas');
    box.appendChild(canvas);
    const ctx = canvas.getContext('2d');
    const S = { cx: 0, cy: 1800, scale: 0.05, agents: [], alerts: [], inters: [], sel: null, img: null, imgB: null, t0: performance.now(), raf: 0, dead: false };
    let W = 0, H = 0, dpr = 1;

    if (opts.image && opts.image.file) {
      const im = new Image();
      im.onload = () => { S.img = im; S.imgB = opts.image; };
      im.src = opts.image.file;
    }

    function resize() {
      const r = box.getBoundingClientRect();
      dpr = window.devicePixelRatio || 1;
      W = r.width; H = r.height;
      canvas.width = Math.max(1, W * dpr); canvas.height = Math.max(1, H * dpr);
    }
    function fit() {
      resize();
      S.scale = Math.min(W / (BOUNDS.maxX - BOUNDS.minX), H / (BOUNDS.maxY - BOUNDS.minY)) * 0.95;
      S.cx = (BOUNDS.minX + BOUNDS.maxX) / 2; S.cy = (BOUNDS.minY + BOUNDS.maxY) / 2;
    }
    const sx = (x) => (x - S.cx) * S.scale + W / 2;
    const sy = (y) => -(y - S.cy) * S.scale + H / 2;
    const wx = (px) => (px - W / 2) / S.scale + S.cx;
    const wy = (py) => -(py - H / 2) / S.scale + S.cy;

    function poly(points) {
      ctx.beginPath();
      points.forEach(([x, y], i) => (i ? ctx.lineTo(sx(x), sy(y)) : ctx.moveTo(sx(x), sy(y))));
      ctx.closePath();
    }

    function drawBackground() {
      ctx.fillStyle = S.img ? '#143d6b' : '#0a1a2c';
      ctx.fillRect(0, 0, W, H);
      if (S.img) {
        const b = S.imgB;
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(S.img, sx(b.minX), sy(b.maxY), (b.maxX - b.minX) * S.scale, (b.maxY - b.minY) * S.scale);
        drawNames('rgba(255,255,255,.7)', true);
        return;
      }
      // Grille (1 km)
      ctx.strokeStyle = 'rgba(96,165,250,.07)'; ctx.lineWidth = 1;
      for (let x = Math.ceil(wx(0) / 1000) * 1000; x < wx(W); x += 1000) { ctx.beginPath(); ctx.moveTo(sx(x), 0); ctx.lineTo(sx(x), H); ctx.stroke(); }
      for (let y = Math.ceil(wy(H) / 1000) * 1000; y < wy(0); y += 1000) { ctx.beginPath(); ctx.moveTo(0, sy(y)); ctx.lineTo(W, sy(y)); ctx.stroke(); }
      // Terre
      poly(ISLAND);
      const g = ctx.createLinearGradient(0, sy(7000), 0, sy(-3500));
      g.addColorStop(0, '#1b2b23'); g.addColorStop(1, '#1d2633');
      ctx.fillStyle = g; ctx.fill();
      ctx.strokeStyle = 'rgba(148,178,230,.35)'; ctx.lineWidth = 1.4; ctx.stroke();
      // Ville
      ctx.fillStyle = 'rgba(96,165,250,.08)';
      ctx.beginPath(); ctx.ellipse(sx(150), sy(-1100), 1700 * S.scale, 1500 * S.scale, 0, 0, Math.PI * 2); ctx.fill();
      // Lac
      poly(LAKE); ctx.fillStyle = '#0d2238'; ctx.fill(); ctx.strokeStyle = 'rgba(148,178,230,.25)'; ctx.stroke();
      drawNames('rgba(203,213,225,.42)', false);
    }

    function drawNames(color, shadow) {
      ctx.save();
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      if (shadow) { ctx.shadowColor = 'rgba(0,0,0,.9)'; ctx.shadowBlur = 4; }
      ZONES.forEach(([n, x, y, k]) => {
        ctx.font = `${k ? 600 : 500} ${Math.max(10, Math.min(15, 11 + S.scale * 40)) * (k || 1)}px Inter, sans-serif`;
        ctx.fillStyle = color;
        ctx.fillText(n.toUpperCase(), sx(x), sy(y));
      });
      ctx.restore();
    }

    function drawMarkers(now) {
      const pulse = (now - S.t0) / 1000;
      // Interventions (losange orange)
      S.inters.forEach((i) => {
        const x = sx(i.x), y = sy(i.y);
        if (i.radius) {   // alerte approximative : zone de recherche
          ctx.beginPath(); ctx.arc(x, y, Math.max(6, i.radius * S.scale), 0, Math.PI * 2);
          ctx.fillStyle = 'rgba(251,146,60,.12)'; ctx.fill(); ctx.strokeStyle = 'rgba(251,146,60,.6)'; ctx.setLineDash([5, 4]); ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
        }
        ctx.save(); ctx.translate(x, y); ctx.rotate(Math.PI / 4);
        ctx.fillStyle = i.takers && i.takers.length ? '#f59e0b' : '#fb923c'; ctx.strokeStyle = '#0b1220'; ctx.lineWidth = 2;
        ctx.fillRect(-6, -6, 12, 12); ctx.strokeRect(-6, -6, 12, 12); ctx.restore();
      });
      // Alertes agent (anneaux pulsants de la couleur du niveau)
      S.alerts.forEach((a) => {
        const x = sx(a.x), y = sy(a.y), c = (opts.levels[a.level] || {}).color || '#ef4444';
        const k = (pulse * 0.8) % 1;
        ctx.beginPath(); ctx.arc(x, y, 8 + k * 22, 0, Math.PI * 2);
        ctx.strokeStyle = c; ctx.globalAlpha = 1 - k; ctx.lineWidth = 2.5; ctx.stroke(); ctx.globalAlpha = 1;
        ctx.beginPath(); ctx.arc(x, y, 8, 0, Math.PI * 2); ctx.fillStyle = c; ctx.fill();
        ctx.lineWidth = 2; ctx.strokeStyle = '#0b1220'; ctx.stroke();
      });
      // Agents (point bleu + matricule)
      ctx.font = '600 11px Inter, sans-serif'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
      S.agents.forEach((a) => {
        if (a.x == null) return;
        const x = sx(a.x), y = sy(a.y), sel = S.sel && S.sel.kind === 'agent' && S.sel.id === a.id;
        const life = (a.health && a.health.life) || 'ok';
        // À terre : anneau orange pulsant ; mort : anneau rouge pulsant
        if (life === 'down' || life === 'dead') {
          const k = (pulse * 0.9) % 1;
          ctx.beginPath(); ctx.arc(x, y, 7 + k * 16, 0, Math.PI * 2);
          ctx.strokeStyle = life === 'dead' ? '#ef4444' : '#f59e0b'; ctx.globalAlpha = 1 - k; ctx.lineWidth = 2; ctx.stroke(); ctx.globalAlpha = 1;
        }
        ctx.beginPath(); ctx.arc(x, y, sel ? 8 : 6, 0, Math.PI * 2);
        ctx.fillStyle = life === 'dead' ? '#7f1d1d' : life === 'down' ? '#f59e0b' : (opts.statusColor && opts.statusColor(a.status)) || '#3b82f6'; ctx.fill();
        ctx.lineWidth = sel ? 3 : 2; ctx.strokeStyle = sel ? '#fff' : '#0b1220'; ctx.stroke();
        if (life === 'dead') {
          ctx.strokeStyle = '#fecaca'; ctx.lineWidth = 1.6; ctx.beginPath();
          ctx.moveTo(x - 3, y - 3); ctx.lineTo(x + 3, y + 3); ctx.moveTo(x + 3, y - 3); ctx.lineTo(x - 3, y + 3); ctx.stroke();
        }
        const label = (a.matricule || a.name) + (life === 'dead' ? ' · MORT' : life === 'down' ? ' · À TERRE' : '');
        const tw = ctx.measureText(label).width;
        ctx.fillStyle = 'rgba(11,18,32,.82)'; ctx.fillRect(x + 10, y - 9, tw + 10, a.health ? 22 : 18);
        ctx.fillStyle = life === 'dead' ? '#fca5a5' : life === 'down' ? '#fcd34d' : '#e8eef9'; ctx.fillText(label, x + 15, y);
        // Barre de vie sous le matricule
        if (a.health) {
          const bw = tw, hp = Math.max(0, Math.min(100, a.health.hp || 0)) / 100;
          ctx.fillStyle = 'rgba(255,255,255,.12)'; ctx.fillRect(x + 15, y + 8, bw, 3);
          ctx.fillStyle = hp > 0.5 ? '#22c55e' : hp > 0.25 ? '#f59e0b' : '#ef4444'; ctx.fillRect(x + 15, y + 8, bw * hp, 3);
        }
      });
    }

    function frame(now) {
      if (S.dead) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      drawBackground();
      drawMarkers(now);
      S.raf = requestAnimationFrame(frame);
    }

    // Déplacement / zoom
    let drag = null;
    canvas.addEventListener('mousedown', (e) => { drag = { x: e.clientX, y: e.clientY, cx: S.cx, cy: S.cy, moved: false }; box.classList.add('drag'); });
    const onMove = (e) => {
      if (!drag) return;
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
      S.cx = drag.cx - dx / S.scale; S.cy = drag.cy + dy / S.scale;
    };
    const onUp = (e) => {
      if (!drag) return;
      const moved = drag.moved;
      drag = null; box.classList.remove('drag');
      if (!moved) pick(e);
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
    canvas.addEventListener('wheel', (e) => { e.preventDefault(); zoomAt(e.deltaY < 0 ? 1.25 : 0.8, e.offsetX, e.offsetY); }, { passive: false });
    function zoomAt(f, px = W / 2, py = H / 2) {
      const bx = wx(px), by = wy(py);
      S.scale = Math.min(1.2, Math.max(0.02, S.scale * f));
      S.cx = bx - (px - W / 2) / S.scale; S.cy = by + (py - H / 2) / S.scale;
    }
    function pick(e) {
      const r = canvas.getBoundingClientRect();
      const px = e.clientX - r.left, py = e.clientY - r.top;
      let best = null, bestD = 16;
      const test = (kind, list) => list.forEach((o) => { if (o.x == null) return; const d = Math.hypot(sx(o.x) - px, sy(o.y) - py); if (d < bestD) { best = { kind, id: o.id, data: o }; bestD = d; } });
      test('agent', S.agents); test('alert', S.alerts); test('inter', S.inters);
      S.sel = best;
      if (opts.onSelect) opts.onSelect(best);
    }

    const ro = new ResizeObserver(() => resize());
    ro.observe(box);
    fit();
    S.raf = requestAnimationFrame(frame);

    return {
      setData(agents, alerts, inters) {
        S.agents = agents || []; S.alerts = alerts || []; S.inters = inters || [];
        if (S.sel) {
          const list = S.sel.kind === 'agent' ? S.agents : S.sel.kind === 'alert' ? S.alerts : S.inters;
          const still = list.find((o) => o.id === S.sel.id);
          if (!still) { S.sel = null; if (opts.onSelect) opts.onSelect(null); } else S.sel.data = still;
        }
      },
      focus(x, y, scale) { S.cx = x; S.cy = y; if (scale) S.scale = scale; },
      zoom(f) { zoomAt(f); },
      fit,
      selected() { return S.sel; },
      destroy() { S.dead = true; cancelAnimationFrame(S.raf); ro.disconnect(); window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); canvas.remove(); },
    };
  }

  window.EmsMap = { create };
})();
