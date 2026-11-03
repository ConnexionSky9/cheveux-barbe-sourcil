/* =====================================================================
   ELYZEA FA · KIT DE MARQUE (JS) : emblème E et skyline en SVG
   Ely.mark({ anim, live, size })  → SVG en ligne de l'emblème
   Ely.skyline({ w, h, seed, lit })  → SVG de la ville (fenêtres animées)
   ===================================================================== */
window.Ely = window.Ely || (() => {
  let uid = 0;
  function mark({ anim = false, live = false, size = 120, cls = '' } = {}) {
    const id = ++uid;
    const h = Math.round(size * 160 / 250);
    return `<svg class="ely-mark ${anim ? 'anim' : ''} ${live ? 'live' : ''} ${cls}" viewBox="0 0 250 160" width="${size}" height="${h}" aria-hidden="true">
      <defs><linearGradient id="ely-sw-g${id}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#E9D5FF"/><stop offset=".45" stop-color="#B57BFF"/><stop offset="1" stop-color="#7B2FF7"/></linearGradient>
      <linearGradient id="ely-e-g${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E7DEFF"/></linearGradient></defs>
      <path class="e" style="fill:url(#ely-e-g${id})" d="M88 10H236L221 38H118.5L108.7 66H192L181 90H100.3L89.8 120H206L191 148H40Z"/>
      <path class="sw" style="fill:url(#ely-sw-g${id})" d="M132 18C52 22 14 78 52 112C84 140 150 134 190 124C140 126 92 122 70 104C40 80 66 34 132 18Z"/>
      <path class="tr" d="M118 12C46 22 8 70 36 104"/></svg>`;
  }
  // Générateur pseudo-aléatoire stable (même ville à chaque affichage)
  function rng(seed) { let s = seed >>> 0 || 1; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
  function skyline({ w = 1200, h = 220, seed = 7, lit = 0.18, palm = true } = {}) {
    const r = rng(seed);
    let x = 0, bld = '', win = '';
    const maxWin = 260; let nWin = 0;
    while (x < w) {
      const bw = 26 + Math.floor(r() * 46), bh = h * (0.25 + r() * 0.7);
      bld += `<rect class="b" x="${x}" y="${(h - bh).toFixed(1)}" width="${bw}" height="${bh.toFixed(1)}"/>`;
      if (r() > 0.6) bld += `<rect class="b" x="${x + bw / 2 - 1.5}" y="${(h - bh - 14).toFixed(1)}" width="3" height="14"/>`;
      for (let wy = h - bh + 8; wy < h - 6 && nWin < maxWin; wy += 9) {
        for (let wx = x + 5; wx < x + bw - 6 && nWin < maxWin; wx += 8) {
          if (r() < 0.45) { nWin++; win += `<rect class="w ${r() < lit ? 'on' : ''}" x="${wx}" y="${wy.toFixed(1)}" width="3" height="4" style="animation-delay:-${(r() * 6).toFixed(2)}s"/>`; }
        }
      }
      x += bw + Math.floor(r() * 6);
    }
    const palmSvg = palm ? `<g class="b" transform="translate(${Math.round(w * 0.62)},${h - 4})"><rect class="b" x="-2" y="-${h * 0.62}" width="5" height="${h * 0.62}"/>
      <path class="b" d="M0 -${h * 0.62} q-30 -6 -46 14 q24 -10 46 -8 q-20 8 -30 30 q22 -22 30 -24 q10 22 30 26 q-14 -18 -28 -28 q24 -4 44 8 q-18 -20 -46 -16z"/></g>` : '';
    return `<svg class="ely-skyline" viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMax slice" aria-hidden="true">${bld}${palmSvg}${win}</svg>`;
  }
  return { mark, skyline };
})();
