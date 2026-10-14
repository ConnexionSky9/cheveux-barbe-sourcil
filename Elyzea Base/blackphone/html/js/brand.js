/* =====================================================================
   BLACKPHONE - identité graphique (source unique, SVG)
   Typographie géométrique originale dessinée en tracés (aucune police externe),
   monogramme, icônes des applications. Utilisé par l'interface ET pour exporter les PNG.
   ===================================================================== */
(function (root) {
  // Glyphes sur une grille 9 × 14 (tracés angulaires, coupes à 45°)
  const G = {
    B: ['M0 0V14H7L9 12V8.6L7.4 7L9 5.4V2L7 0Z', 'M0 7H7.4'],
    L: ['M0 0V14H9'],
    A: ['M0 14V4L4 0H5L9 4V14', 'M0 8.5H9'],
    C: ['M9 0H3L0 3V11L3 14H9'],
    K: ['M0 0V14', 'M9 0L2.2 7L9 14', 'M0 7H2.2'],
    P: ['M0 14V0H7L9 2V6L7 8H0'],
    H: ['M0 0V14', 'M9 0V14', 'M0 7H9'],
    O: ['M3 0H6L9 3V11L6 14H3L0 11V3Z'],
    N: ['M0 14V0L9 14V0'],
    E: ['M9 0H0V14H9', 'M0 7H6.5'],
  };
  function word(text, o) {
    o = o || {};
    const w = 9, gap = o.gap || 5.2, sw = o.stroke || 1.9;
    let x = 0; const parts = [];
    for (const ch of text) {
      const g = G[ch];
      if (g) {
        const col = (o.accentLetter && o.accentLetter === ch && !parts.accentDone) ? (parts.accentDone = true, o.accent) : o.color;
        parts.push(`<g transform="translate(${x} 0)" stroke="${col}">${g.map((d) => `<path d="${d}"/>`).join('')}</g>`);
      }
      x += w + gap;
    }
    const width = x - gap;
    return { width, svg: `<g fill="none" stroke-width="${sw}" stroke-linecap="square" stroke-linejoin="miter" stroke-miterlimit="2.2">${parts.join('')}</g>` };
  }
  // Monogramme : silhouette de terminal + « B » angulaire dont la barre centrale perce la coque (la « brèche »)
  function mark(o) {
    o = o || {};
    const c = o.color || '#f2f2f2', a = o.accent || '#b3161b', bg = o.bg;
    return `<g fill="none" stroke-linecap="square" stroke-linejoin="miter">
      ${bg ? `<rect x="2" y="2" width="60" height="100" rx="12" fill="${bg}"/>` : ''}
      <path d="M14 2H50A12 12 0 0 1 62 14V90A12 12 0 0 1 50 102H14A12 12 0 0 1 2 90V14A12 12 0 0 1 14 2Z" stroke="${c}" stroke-width="3"/>
      <path d="M22 26V78H38L44 72V58L39.5 52L44 46V32L38 26Z" stroke="${c}" stroke-width="5"/>
      <path d="M22 52H62" stroke="${c}" stroke-width="5"/>
      <path d="M58 52H66" stroke="${a}" stroke-width="5"/>
      <circle cx="32" cy="12" r="2.6" fill="${a}" stroke="none"/>
    </g>`;
  }
  function logo(o) {
    o = o || {};
    const wm = word('BLACKPHONE', { color: o.color || '#f2f2f2', accent: o.accent || '#b3161b', accentLetter: o.accentWord ? 'O' : null });
    const s = 3.2, mh = 104, ty = (mh - 14 * s) / 2;
    const W = 66 + 26 + wm.width * s;
    return { width: W, height: mh, svg: `<g>${mark(o)}<g transform="translate(${66 + 26} ${ty}) scale(${s})">${wm.svg}</g></g>` };
  }
  function svgDoc(inner, w, h, pad = 0, bg) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${-pad} ${-pad} ${w + pad * 2} ${h + pad * 2}" width="${w + pad * 2}" height="${h + pad * 2}">${bg ? `<rect x="${-pad}" y="${-pad}" width="${w + pad * 2}" height="${h + pad * 2}" fill="${bg}"/>` : ''}${inner}</svg>`;
  }
  // Icônes d'applications (24 × 24, trait fin, angles vifs)
  const I = {
    settings: '<circle cx="12" cy="12" r="3"/><path d="M12 2V5M12 19V22M2 12H5M19 12H22M4.9 4.9L7 7M17 17L19.1 19.1M4.9 19.1L7 17M17 7L19.1 4.9"/>',
    info: '<path d="M4 4H20V20H4Z"/><path d="M12 10.5V17M12 7V7.5"/>',
    lock: '<path d="M6 11H18V21H6Z"/><path d="M8.5 11V7.5C8.5 5.5 10 4 12 4C14 4 15.5 5.5 15.5 7.5V11"/>',
    back: '<path d="M15 4L7 12L15 20"/>',
    image: '<path d="M3 5H21V19H3Z"/><path d="M3 16L9 11L13 14.5L16 12L21 16"/><circle cx="15.5" cy="8.5" r="1.3"/>',
    sound: '<path d="M4 9H8L13 5V19L8 15H4Z"/><path d="M16.5 9.5C17.5 10.8 17.5 13.2 16.5 14.5M19 7C21 9.6 21 14.4 19 17"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2V4M12 20V22M2 12H4M20 12H22M5 5L6.5 6.5M17.5 17.5L19 19M5 19L6.5 17.5M17.5 6.5L19 5"/>',
    chevron: '<path d="M9 5L16 12L9 19"/>',
  };
  const icon = (name, size = 24, color = 'currentColor', sw = 1.6) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="square" stroke-linejoin="miter">${I[name] || ''}</svg>`;
  root.BPBrand = { word, mark, logo, svgDoc, icon, icons: I };
})(typeof window !== 'undefined' ? window : globalThis);
