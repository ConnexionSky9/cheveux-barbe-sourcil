/* =========================================================
   CARTE ELYZEA — remplace la mini-carte de GTA, dessinée dans le cadre du HUD.
   Le jeu envoie ~30 fois / s : position, cap de la caméra et du personnage, zoom ;
   toutes les 2,5 s : les points de la carte (blips) et le point GPS.
   Image : une seule ou des tuiles (config.lua › Config.CustomMap.image).
   ========================================================= */
(() => {
  const box = document.getElementById('mm'), cv = document.getElementById('mm-c'), north = document.getElementById('mm-n'), wpEl = document.getElementById('mm-wp');
  if (!cv) return;
  const ctx = cv.getContext('2d');
  // Couleurs des points GTA (index de couleur → teinte)
  const COL = { 0: '#ffffff', 1: '#e5484d', 2: '#46c35a', 3: '#4c8dff', 4: '#ffffff', 5: '#f5d000', 6: '#ff7a7a', 7: '#b45cff', 8: '#ff5fb4', 9: '#ffb36b',
    10: '#c9a27a', 11: '#9be3a5', 12: '#8fc7ff', 13: '#d1b3ff', 14: '#6d3fbf', 15: '#2fd5e6', 16: '#fff3a0', 17: '#ff9f1c', 18: '#77b7ff', 19: '#d63f8a',
    20: '#c9a300', 21: '#e07a00', 22: '#bdbdbd', 23: '#ffb3d1', 24: '#c6f25c', 25: '#3d8b4f', 26: '#2c7dff', 27: '#a24dff', 28: '#d4b000', 29: '#2846a8',
    30: '#1a9aa8', 38: '#3b6fe0', 40: '#555b66', 46: '#f5c542', 47: '#ff8a1f', 48: '#ff5fb4', 49: '#b3261e', 50: '#8a4dff', 52: '#3ec46d', 54: '#4c8dff', 59: '#d93636', 83: '#a855f7' };
  // Icônes des points à proximité (dessinées ici, en 24 × 24) : type de point GTA (sprite) → icône
  const ICON_PATHS = {
    cart: 'M3 4h2.2l2.1 10.2a1.5 1.5 0 0 0 1.5 1.2h7.7a1.5 1.5 0 0 0 1.4-1.1L20 8H6.4 M9 20.2a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6z M17 20.2a1.3 1.3 0 1 0 0-2.6 1.3 1.3 0 0 0 0 2.6z',
    shirt: 'M8 3 3.5 6 5.5 10 7 9.3V21h10V9.3l1.5.7 2-4L16 3c-.6 1.5-2.1 2.4-4 2.4S8.6 4.5 8 3z',
    scissors: 'M6.5 9a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z M6.5 20a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z M8.5 8.2 20 18 M8.5 15.8 20 6',
    needle: 'M19 3l2 2-9.5 9.5-3-3z M8.5 11.5 4 16l1 3 3 1 4.5-4.5 M3 21l2-2',
    gun: 'M3 8h15l2 2v2h-6l-1 2h-3l-1 5H5l1.5-7H3z M18 8V6',
    fuel: 'M4 21V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v16 M3 21h12 M6 8h6 M14 10h2a2 2 0 0 1 2 2v4a1.5 1.5 0 0 0 3 0V8l-3-3',
    shield: 'M12 3 5 6v5c0 4.5 3 8.4 7 10 4-1.6 7-5.5 7-10V6z M12 8l1.2 2.5 2.8.4-2 2 .5 2.8L12 14.4l-2.5 1.3.5-2.8-2-2 2.8-.4z',
    cross: 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6z',
    wrench: 'M14.5 6.5a4 4 0 0 0-5.3 5.3L3.5 17.5a1.8 1.8 0 0 0 2.5 2.5l5.7-5.7a4 4 0 0 0 5.3-5.3l-2.6 2.6-2.4-.6-.6-2.4z',
    car: 'M5 16V12l1.8-4.5A2 2 0 0 1 8.7 6h6.6a2 2 0 0 1 1.9 1.5L19 12v4 M3.5 16h17v3h-3v-1.5h-11V19h-3z M7.5 13.5h.01 M16.5 13.5h.01 M5 12h14',
    garage: 'M3 10 12 4l9 6v10H3z M7 20v-6h10v6 M7 17h10',
    home: 'M3 11 12 4l9 7 M5.5 9.5V20h13V9.5 M10 20v-5h4v5',
    dollar: 'M12 3v18 M16.5 7.5C16 6 14.3 5 12 5c-2.5 0-4.5 1.3-4.5 3.3 0 4.7 9 2.6 9 7.2 0 2-2 3.5-4.5 3.5-2.4 0-4.2-1.1-4.7-2.8',
    glass: 'M6 4h12l-6 7z M12 11v8 M8 20h8',
    plane: 'M21 15v-2l-8-5V3.5a1 1 0 0 0-2 0V8l-8 5v2l8-2.5V18l-2 1.5V21l3-1 3 1v-1.5L13 18v-5.5z',
    boat: 'M3 16h18l-2.5 4H5.5z M6 16V10h12v6 M12 10V4l5 4h-5',
    heli: 'M3 5h18 M12 5v3 M6 12a6 4 0 0 0 12 0 6 4 0 0 0-12 0z M18 12h4 M9 16l-1 3 M15 16l1 3 M7 19h10',
    truck: 'M2 7h12v9H2z M14 10h4l3 3v3h-7 M6 18.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z M17 18.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z',
    pill: 'M8.5 15.5 15.5 8.5 M7 17a4.2 4.2 0 0 1 0-6l4-4a4.2 4.2 0 0 1 6 6l-4 4a4.2 4.2 0 0 1-6 0z',
    leaf: 'M12 21V11 M12 11c-3-1-6-4-6-8 3 .5 5.5 2.5 6 6 .5-3.5 3-5.5 6-6 0 4-3 7-6 8z M12 15c-2 0-5-1-7-3 M12 15c2 0 5-1 7-3',
    flag: 'M5 21V4 M5 4h12l-2.5 4L17 12H5',
    chip: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 7.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9z M12 3v4.5 M12 16.5V21 M3 12h4.5 M16.5 12H21',
    star: 'M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6L3.4 9.3l6-.7z',
  };
  const SPRITE_ICON = {};
  const ICON_OF = { cart: [52, 59, 628], shirt: [73, 366], scissors: [71], needle: [75], gun: [110, 313, 567], fuel: [361, 415],
    shield: [60, 188, 526, 137], cross: [61, 153, 489], wrench: [72, 446, 402, 544, 643], car: [225, 326, 523, 669, 380, 227, 595],
    garage: [357, 50, 524, 557, 289], home: [40, 350, 374, 375, 411, 492, 417], dollar: [108, 207, 277, 434, 500], glass: [93, 121, 614],
    plane: [90, 307, 423, 578], boat: [410, 427, 455, 471], heli: [43, 64, 422, 574], truck: [477, 67, 318, 198, 56], pill: [51, 403, 499],
    leaf: [140, 469, 496], flag: [38, 315, 309], chip: [679, 680, 681] };
  for (const [k, ids] of Object.entries(ICON_OF)) for (const id of ids) SPRITE_ICON[id] = k;
  const PATHS = {};
  for (const [k, d] of Object.entries(ICON_PATHS)) PATHS[k] = new Path2D(d);
  function drawIcon(x, y, k, sprite, color) {
    const r = 9.5 * k;
    ctx.save(); ctx.translate(x, y);
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(10,6,22,.88)'; ctx.fill();
    ctx.lineWidth = 1.6 * k; ctx.strokeStyle = color; ctx.shadowColor = color; ctx.shadowBlur = 5 * k; ctx.stroke(); ctx.shadowBlur = 0;
    const s = (r * 1.25) / 24;
    ctx.translate(-12 * s, -12 * s); ctx.scale(s, s);
    ctx.lineWidth = 2.6; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = color;
    ctx.stroke(PATHS[SPRITE_ICON[sprite] || 'star']);
    ctx.restore();
  }

  let cfg = null, tiles = [], tileW = 0, tileH = 0;
  let cur = null, tgt = null, blips = [], wp = null;
  const lerp = (a, b, k) => a + (b - a) * k;
  const lerpAng = (a, b, k) => { let d = ((b - a + 540) % 360) - 180; return a + d * k; };

  function setCfg(c) {
    cfg = c || {};
    const im = cfg.image || { path: 'img/map.jpg', cols: 1, rows: 1 };
    tiles = [];
    for (let y = 0; y < (im.rows || 1); y++) for (let x = 0; x < (im.cols || 1); x++) {
      const img = new Image();
      img.onload = () => { if (!tileW) { tileW = img.naturalWidth; tileH = img.naturalHeight; } };
      img.src = String(im.path).replace('{x}', x).replace('{y}', y);
      tiles.push({ img, x, y });
    }
    cfg.cols = im.cols || 1; cfg.rows = im.rows || 1;
  }

  function size() {
    const r = box.getBoundingClientRect(), d = window.devicePixelRatio || 1;
    const w = Math.max(2, Math.round(r.width * d)), h = Math.max(2, Math.round(r.height * d));
    if (cv.width !== w || cv.height !== h) { cv.width = w; cv.height = h; }
    return { w, h };
  }

  function draw() {
    requestAnimationFrame(draw);
    if (!cfg || !tgt || box.offsetParent === null) return;
    cur = cur ? { x: lerp(cur.x, tgt.x, .35), y: lerp(cur.y, tgt.y, .35), cam: lerpAng(cur.cam, tgt.cam, .35), ped: lerpAng(cur.ped, tgt.ped, .35), zoom: lerp(cur.zoom, tgt.zoom, .2) } : { ...tgt };
    const { w, h } = size(), b = cfg.bounds;
    const totW = (tileW || 2000) * cfg.cols, totH = (tileH || 2000) * cfg.rows;
    const ppmX = totW / (b.maxX - b.minX), ppmY = totH / (b.maxY - b.minY);   // pixels d'image par mètre
    const scale = w / cur.zoom;                                                // pixels écran par mètre
    const rot = cfg.rotate ? cur.cam * Math.PI / 180 : 0;
    const cx = w / 2, cy = h * 0.6;                                            // joueur un peu sous le centre (on voit devant)
    const toScreen = (x, y) => {                                               // monde → écran
      const dx = (x - cur.x) * scale, dy = -(y - cur.y) * scale;
      return [cx + dx * Math.cos(rot) - dy * Math.sin(rot), cy + dx * Math.sin(rot) + dy * Math.cos(rot)];
    };
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.fillStyle = '#0b1c2c'; ctx.fillRect(0, 0, w, h);                      // mer
    ctx.save();
    ctx.translate(cx, cy); ctx.rotate(rot);
    ctx.scale(scale / ppmX, scale / ppmY);
    const u = (cur.x - b.minX) * ppmX, v = (b.maxY - cur.y) * ppmY;
    ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high';
    ctx.filter = 'contrast(1.12) saturate(1.08)';
    for (const t of tiles) if (t.img.complete && t.img.naturalWidth) ctx.drawImage(t.img, t.x * tileW - u, t.y * tileH - v);
    ctx.filter = 'none';
    ctx.restore();
    // teinte du HUD (violet nuit) pour que la carte se fonde dans le cadre
    ctx.fillStyle = 'rgba(16,8,34,.28)'; ctx.fillRect(0, 0, w, h);
    const d = window.devicePixelRatio || 1, k = h / 200;
    // points de la carte
    const reach = cur.zoom * 0.9;
    for (const p of blips) {
      if (p.s === 8) continue;
      if (Math.abs(p.x - cur.x) > reach || Math.abs(p.y - cur.y) > reach) continue;
      const [sx, sy] = toScreen(p.x, p.y);
      if (sx < -6 || sy < -6 || sx > w + 6 || sy > h + 6) continue;
      if (p.s === 1 || !SPRITE_ICON[p.s] && p.s < 10) {   // point simple
        ctx.beginPath(); ctx.arc(sx, sy, 3.6 * k, 0, Math.PI * 2);
        ctx.fillStyle = COL[p.c] || '#d9cff5'; ctx.fill();
        ctx.lineWidth = 1.2 * k; ctx.strokeStyle = 'rgba(0,0,0,.75)'; ctx.stroke();
      } else drawIcon(sx, sy, k, p.s, COL[p.c] || '#E9D5FF');
    }
    // point GPS (repère d'arrivée) : sur la carte, ou flèche au bord s'il est loin
    if (wp) {
      let [sx, sy] = toScreen(wp.x, wp.y);
      const m = 18 * k, inside = sx > m && sy > m && sx < w - m && sy < h - m;
      if (!inside) {
        const ang = Math.atan2(sy - cy, sx - cx);
        const tx = Math.cos(ang), ty = Math.sin(ang);
        const f = Math.min((tx > 0 ? (w - m - cx) / tx : (m - cx) / tx), (ty > 0 ? (h - m - cy) / ty : (m - cy) / ty));
        sx = cx + tx * f; sy = cy + ty * f;
        ctx.save(); ctx.translate(sx, sy); ctx.rotate(ang);
        ctx.beginPath(); ctx.moveTo(8 * k, 0); ctx.lineTo(-5 * k, -5.5 * k); ctx.lineTo(-5 * k, 5.5 * k); ctx.closePath();
        ctx.fillStyle = '#C9A6FF'; ctx.shadowColor = '#9B5CFF'; ctx.shadowBlur = 8 * k; ctx.fill(); ctx.restore();
      } else {
        ctx.save(); ctx.translate(sx, sy);
        ctx.beginPath(); ctx.arc(0, -6 * k, 5 * k, Math.PI, 0); ctx.lineTo(0, 3 * k); ctx.closePath();
        ctx.fillStyle = '#B57BFF'; ctx.shadowColor = '#9B5CFF'; ctx.shadowBlur = 10 * k; ctx.fill();
        ctx.beginPath(); ctx.arc(0, -6 * k, 2 * k, 0, Math.PI * 2); ctx.fillStyle = '#fff'; ctx.fill(); ctx.restore();
      }
      const dist = Math.hypot(wp.x - cur.x, wp.y - cur.y);
      wpEl.textContent = dist >= 1000 ? `${(dist / 1000).toFixed(1)} km` : `${Math.round(dist)} m`;
    } else wpEl.textContent = '';
    // joueur : flèche dans le sens où il regarde
    ctx.save(); ctx.translate(cx, cy);
    ctx.rotate(((cfg.rotate ? cur.cam : 0) - cur.ped) * Math.PI / 180);
    ctx.beginPath(); ctx.moveTo(0, -9 * k); ctx.lineTo(6.5 * k, 7 * k); ctx.lineTo(0, 3.5 * k); ctx.lineTo(-6.5 * k, 7 * k); ctx.closePath();
    ctx.fillStyle = '#fff'; ctx.shadowColor = '#B57BFF'; ctx.shadowBlur = 10 * k; ctx.fill();
    ctx.lineWidth = 1.4 * k; ctx.strokeStyle = '#7B2FF7'; ctx.stroke(); ctx.restore();
    // repère nord au bord de la carte
    const na = -rot - Math.PI / 2, nr = Math.min(w, h) / 2 - 11 * k;
    const nx = cx + Math.cos(na) * nr, ny = Math.max(10 * k, Math.min(h - 10 * k, cy + Math.sin(na) * nr));
    north.style.transform = `translate(${(nx - w / 2) / d}px, ${(ny - h / 2) / d}px)`;
  }

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'mapcfg') setCfg(m.cfg);
    else if (m.action === 'map') tgt = { x: m.x, y: m.y, cam: m.cam, ped: m.ped, zoom: m.zoom };
    else if (m.action === 'blips') { blips = Array.isArray(m.list) ? m.list : []; wp = m.wp || null; }
  });
  requestAnimationFrame(draw);
})();
