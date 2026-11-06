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
    for (const t of tiles) if (t.img.complete && t.img.naturalWidth) ctx.drawImage(t.img, t.x * tileW - u, t.y * tileH - v);
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
      ctx.beginPath(); ctx.arc(sx, sy, 3.6 * k, 0, Math.PI * 2);
      ctx.fillStyle = COL[p.c] || '#d9cff5'; ctx.fill();
      ctx.lineWidth = 1.2 * k; ctx.strokeStyle = 'rgba(0,0,0,.75)'; ctx.stroke();
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
