/*
 * NOIR X — Générateur d'assets graphiques (SVG + PNG)
 * Usage : node tools/build-assets.js   (nécessite le module npm "sharp" pour les PNG)
 * Tous les dessins sont originaux et vectoriels ; aucune police externe n'est requise
 * (le logotype est dessiné en tracés).
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const BRAND = path.join(ROOT, 'assets', 'brand');
const INV = path.join(ROOT, 'assets', 'inventory');
const HTML = path.join(ROOT, 'html', 'assets');
const ICONS = path.join(HTML, 'icons');
[BRAND, INV, HTML, ICONS].forEach(d => fs.mkdirSync(d, { recursive: true }));

const C = {
  void: '#050506', matte: '#0b0b0d', graphite: '#17171b', steel: '#2a2a30',
  blood: '#8e0f1c', ember: '#c4162a', ice: '#e9edf2', mist: '#8a8f98',
};

/* ── Emblème : un X dont la lame claire est tranchée par la lame rouge ─────── */
function emblem({ size = 100, x = 0, y = 0, light = C.ice, red = C.ember, frame = C.steel, frameOn = true, sw = 7 } = {}) {
  const s = size / 100;
  const g = `<g transform="translate(${x} ${y}) scale(${s})" fill="none" stroke-linecap="square">`;
  const f = frameOn
    ? `<path d="M18 4 H82 L96 18 V82 L82 96 H18 L4 82 V18 Z" stroke="${frame}" stroke-width="2"/>`
    : '';
  // lame claire coupée au centre (gap) — la lame rouge passe "à travers"
  const lightBlade = `<path d="M27 27 L44.5 44.5 M55.5 55.5 L73 73" stroke="${light}" stroke-width="${sw}"/>`;
  const redBlade = `<path d="M73 27 L27 73" stroke="${red}" stroke-width="${sw}"/>`;
  return `${g}${f}${redBlade}${lightBlade}</g>`;
}

/* ── Logotype NOIR (tracés géométriques, hauteur 60) ────────────────────── */
function wordmark({ x = 0, y = 0, h = 60, color = C.ice, xColor = C.ember, sw = 6.5 } = {}) {
  const s = h / 60;
  const N = `M0 60 V0 L40 60 V0`;
  const O = `M64 6 Q64 0 70 0 H98 Q104 0 104 6 V54 Q104 60 98 60 H70 Q64 60 64 54 Z`;
  const I = `M128 0 V60`;
  const R = `M152 60 V0 H180 Q194 0 194 15 Q194 30 180 30 H152 M176 30 L196 60`;
  const X = `M228 0 L268 60 M268 0 L228 60`;
  return `<g transform="translate(${x} ${y}) scale(${s})" fill="none" stroke-linejoin="miter" stroke-miterlimit="1.5" stroke-linecap="square">
    <path d="${N} M${O.slice(1)} ${I} ${R}" stroke="${color}" stroke-width="${sw}"/>
    <path d="${X}" stroke="${xColor}" stroke-width="${sw}"/>
  </g>`;
}

const svg = (w, h, body, bg) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${bg ? `<rect width="${w}" height="${h}" fill="${bg}"/>` : ''}${body}</svg>\n`;

const glowDefs = `<defs>
  <radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="${C.blood}" stop-opacity=".35"/><stop offset="1" stop-color="${C.blood}" stop-opacity="0"/></radialGradient>
  <linearGradient id="sheen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".06"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient>
</defs>`;

const files = {};

/* 1. Logo principal (fond noir) */
files['brand/noirx-logo.svg'] = svg(760, 260, glowDefs +
  `<ellipse cx="150" cy="130" rx="150" ry="120" fill="url(#glow)"/>` +
  emblem({ size: 140, x: 80, y: 60 }) +
  `<path d="M250 70 V190" stroke="${C.steel}" stroke-width="1.5"/>` +
  wordmark({ x: 290, y: 100, h: 60 }) +
  `<text x="290" y="200" fill="${C.mist}" font-family="Inter, 'Helvetica Neue', Arial, sans-serif" font-size="13" letter-spacing="7">UNDERGROUND NETWORK</text>`,
  C.void);

/* 3. Logo fond transparent */
files['brand/noirx-logo-transparent.svg'] = svg(760, 260,
  emblem({ size: 140, x: 80, y: 60 }) + wordmark({ x: 290, y: 100, h: 60 }));

/* 4. Monochrome blanc (et noir pour fonds clairs) */
files['brand/noirx-logo-mono-white.svg'] = svg(760, 260,
  emblem({ size: 140, x: 80, y: 60, light: '#fff', red: '#fff', frame: '#fff' }) +
  wordmark({ x: 290, y: 100, h: 60, color: '#fff', xColor: '#fff' }));
files['brand/noirx-logo-mono-black.svg'] = svg(760, 260,
  emblem({ size: 140, x: 80, y: 60, light: '#000', red: '#000', frame: '#000' }) +
  wordmark({ x: 290, y: 100, h: 60, color: '#000', xColor: '#000' }));

/* 5. Variante noire et rouge */
files['brand/noirx-logo-redblack.svg'] = svg(760, 260,
  emblem({ size: 140, x: 80, y: 60, light: C.void, red: C.ember, frame: C.blood }) +
  wordmark({ x: 290, y: 100, h: 60, color: C.ember, xColor: C.ember }),
  '#000');

/* Emblème seul */
files['brand/noirx-emblem.svg'] = svg(100, 100, emblem({ size: 100 }));

/* 2. Icône carrée d'inventaire : le terminal vu de face, emblème au dos lumineux */
files['brand/noirx-inventory-icon.svg'] = svg(512, 512, glowDefs + `
  <defs><linearGradient id="body" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1d1d22"/><stop offset="1" stop-color="#060607"/></linearGradient></defs>
  <ellipse cx="256" cy="270" rx="230" ry="220" fill="url(#glow)"/>
  <g transform="rotate(-12 256 256)">
    <rect x="156" y="56" width="200" height="400" rx="34" fill="url(#body)" stroke="${C.steel}" stroke-width="3"/>
    <rect x="156" y="56" width="200" height="400" rx="34" fill="url(#sheen)"/>
    <rect x="170" y="70" width="172" height="372" rx="24" fill="${C.void}"/>
    <rect x="226" y="80" width="60" height="10" rx="5" fill="${C.matte}"/>
    ${emblem({ size: 110, x: 201, y: 190 })}
    <path d="M206 360 H306" stroke="${C.steel}" stroke-width="2"/>
    <rect x="356" y="160" width="5" height="46" rx="2" fill="${C.blood}"/>
  </g>`);

/* 6. Fonds d'écran */
files['html/wallpaper-void.svg'] = svg(390, 844, glowDefs + `
  <rect width="390" height="844" fill="${C.void}"/>
  <ellipse cx="195" cy="520" rx="320" ry="260" fill="url(#glow)" opacity=".7"/>
  ${emblem({ size: 260, x: 65, y: 330, light: '#0f0f12', red: '#1a0a0d', frame: '#0d0d10', sw: 3 })}`);
files['html/wallpaper-grid.svg'] = svg(390, 844, `
  <defs><pattern id="p" width="26" height="26" patternUnits="userSpaceOnUse"><path d="M26 0 H0 V26" fill="none" stroke="#141418" stroke-width="1"/></pattern>
  <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.void}" stop-opacity="0"/><stop offset="1" stop-color="${C.void}"/></linearGradient></defs>
  <rect width="390" height="844" fill="${C.void}"/><rect width="390" height="844" fill="url(#p)"/>
  <path d="M0 610 L390 380" stroke="${C.blood}" stroke-width="1" opacity=".55"/>
  <rect width="390" height="844" fill="url(#fade)"/>`);
files['html/wallpaper-ember.svg'] = svg(390, 844, `
  <defs><linearGradient id="e" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#030304"/><stop offset=".62" stop-color="#0a0608"/><stop offset="1" stop-color="#2a0710"/></linearGradient></defs>
  <rect width="390" height="844" fill="url(#e)"/>
  <path d="M-20 844 Q195 600 410 844" fill="${C.blood}" opacity=".12"/>`);

/* 7. Écran de démarrage */
files['brand/noirx-boot.svg'] = svg(390, 844, glowDefs + `
  <rect width="390" height="844" fill="#000"/>
  <ellipse cx="195" cy="390" rx="200" ry="200" fill="url(#glow)"/>
  ${emblem({ size: 120, x: 135, y: 330 })}
  ${wordmark({ x: 128, y: 490, h: 20, sw: 7 })}
  <rect x="145" y="560" width="100" height="2" fill="${C.steel}"/><rect x="145" y="560" width="38" height="2" fill="${C.ember}"/>`);
files['html/emblem.svg'] = files['brand/noirx-emblem.svg'];
files['html/wordmark.svg'] = svg(270, 64, wordmark({ x: 2, y: 2, h: 60 }));

/* 9. Coque : face et dos */
files['brand/noirx-device-case.svg'] = svg(900, 900, glowDefs + `
  <defs><linearGradient id="body" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1c1c21"/><stop offset="1" stop-color="#050506"/></linearGradient>
  <pattern id="kev" width="8" height="8" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="4" height="8" fill="#0e0e11"/><rect x="4" width="4" height="8" fill="#0a0a0c"/></pattern></defs>
  <rect width="900" height="900" fill="${C.void}"/>
  <!-- face -->
  <rect x="90" y="110" width="320" height="680" rx="46" fill="url(#body)" stroke="${C.steel}" stroke-width="3"/>
  <rect x="104" y="124" width="292" height="652" rx="36" fill="#000"/>
  <rect x="215" y="138" width="70" height="20" rx="10" fill="${C.matte}"/>
  ${emblem({ size: 90, x: 205, y: 380 })}
  <rect x="410" y="250" width="5" height="70" rx="2" fill="${C.blood}"/>
  <rect x="85" y="230" width="5" height="44" rx="2" fill="${C.steel}"/><rect x="85" y="290" width="5" height="70" rx="2" fill="${C.steel}"/>
  <!-- dos -->
  <rect x="490" y="110" width="320" height="680" rx="46" fill="url(#kev)" stroke="${C.steel}" stroke-width="3"/>
  <rect x="490" y="110" width="320" height="680" rx="46" fill="url(#sheen)"/>
  <rect x="518" y="138" width="110" height="110" rx="26" fill="#08080a" stroke="${C.steel}" stroke-width="2"/>
  <circle cx="553" cy="173" r="18" fill="#000" stroke="#222" stroke-width="3"/><circle cx="593" cy="213" r="18" fill="#000" stroke="#222" stroke-width="3"/>
  <circle cx="598" cy="166" r="5" fill="${C.ember}"/>
  ${emblem({ size: 120, x: 590, y: 390, frame: C.blood })}
  ${wordmark({ x: 600, y: 700, h: 18, sw: 7, color: C.mist })}
  <text x="250" y="840" text-anchor="middle" fill="${C.mist}" font-family="Inter, Arial, sans-serif" font-size="14" letter-spacing="5">FACE</text>
  <text x="650" y="840" text-anchor="middle" fill="${C.mist}" font-family="Inter, Arial, sans-serif" font-size="14" letter-spacing="5">DOS · FIBRE ARAMIDE</text>`);

/* 10. Identité du PC policier — unité fictive, aucun insigne réel */
const P = { navy: '#0a1220', steel: '#1b2a40', line: '#3a5a86', text: '#dfe7f2', accent: '#4f8fe0' };
function shield(x, y, s) {
  return `<g transform="translate(${x} ${y}) scale(${s})" fill="none">
    <path d="M50 4 L92 18 V50 Q92 80 50 98 Q8 80 8 50 V18 Z" stroke="${P.accent}" stroke-width="3"/>
    <path d="M50 16 L80 26 V50 Q80 72 50 86 Q20 72 20 50 V26 Z" stroke="${P.line}" stroke-width="1.5"/>
    <circle cx="50" cy="50" r="13" stroke="${P.text}" stroke-width="2.5"/>
    <path d="M50 30 V37 M50 63 V70 M30 50 H37 M63 50 H70" stroke="${P.text}" stroke-width="2.5"/>
  </g>`;
}
files['brand/police-pc-identity.svg'] = svg(900, 420, `
  <rect width="900" height="420" fill="${P.navy}"/>
  <rect x="0" y="0" width="900" height="6" fill="${P.accent}"/>
  ${shield(70, 110, 2)}
  <text x="300" y="180" fill="${P.text}" font-family="Inter, 'Segoe UI', Arial, sans-serif" font-size="44" font-weight="700" letter-spacing="10">SECTION CYBER</text>
  <text x="302" y="222" fill="${P.accent}" font-family="Inter, 'Segoe UI', Arial, sans-serif" font-size="16" letter-spacing="6">UNITÉ D'ENQUÊTE NUMÉRIQUE</text>
  <path d="M302 250 H830" stroke="${P.steel}" stroke-width="2"/>
  <text x="302" y="290" fill="#7f93ad" font-family="'JetBrains Mono', Consolas, monospace" font-size="14" letter-spacing="2">TERMINAL D'INVESTIGATION · ACCÈS RESTREINT</text>
  <g font-family="Inter, Arial, sans-serif" font-size="11" letter-spacing="2">
    ${[P.navy, P.steel, P.line, P.accent, P.text].map((c, i) => `<rect x="${302 + i * 106}" y="320" width="96" height="40" fill="${c}" stroke="${P.steel}"/><text x="${302 + i * 106}" y="378" fill="#7f93ad">${c.toUpperCase()}</text>`).join('')}
  </g>`);
files['brand/police-pc-shield.svg'] = svg(100, 100, shield(0, 0, 1));

/* 8. Icônes d'applications (24×24, trait 1.6, cohérentes) */
const ic = (d, extra = '') =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${d}${extra}</svg>\n`;
const icons = {
  darkchat: ic('<path d="M4 5h16v11H9l-5 4z"/><path d="M8 10h8M8 13h5"/>'),
  ghostline: ic('<path d="M6 20V10a6 6 0 0 1 12 0v10l-2-1.5L14 20l-2-1.5L10 20l-2-1.5z"/><circle cx="10" cy="10.5" r=".9" fill="currentColor"/><circle cx="14" cy="10.5" r=".9" fill="currentColor"/>'),
  market: ic('<path d="M4 8l2-4h12l2 4"/><path d="M4 8h16v12H4z"/><path d="M9 12h6"/>'),
  contracts: ic('<path d="M7 3h8l4 4v14H7z"/><path d="M15 3v4h4"/><path d="M10 12h6M10 15h6M10 18h3"/>'),
  blackbreach: ic('<rect x="3" y="4" width="18" height="13" rx="1.5"/><path d="M7 9l2.5 2L7 13M12 13h4"/><path d="M9 21h6M12 17v4"/>'),
  mercs: ic('<circle cx="12" cy="12" r="7.5"/><circle cx="12" cy="12" r="2"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>'),
  blackfile: ic('<path d="M3 6h6l2 2h10v11H3z"/><path d="M14 12l2 2-2 2"/>'),
  ratline: ic('<path d="M5 12a7 7 0 0 1 14 0"/><path d="M8 12a4 4 0 0 1 8 0"/><circle cx="12" cy="12" r="1.2" fill="currentColor"/><path d="M12 13v8"/>'),
  burner: ic('<rect x="7" y="3" width="10" height="18" rx="2"/><path d="M12 8c1.8 1.6 2 3.4 0 5-2-1.6-1.8-3.4 0-5z"/><path d="M10 17h4"/>'),
  deaddrop: ic('<path d="M12 21s-6-5.5-6-10a6 6 0 0 1 12 0c0 4.5-6 10-6 10z"/><rect x="9.5" y="8" width="5" height="4.5" rx=".6"/><path d="M10.5 8V7a1.5 1.5 0 0 1 3 0v1"/>'),
  auction: ic('<path d="M14 4l6 6-3 3-6-6z"/><path d="M12.5 8.5L4 17l3 3 8.5-8.5"/><path d="M13 21h8"/>'),
  settings: ic('<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/>'),
  back: ic('<path d="M15 5l-7 7 7 7"/>'),
  lock: ic('<rect x="5" y="11" width="14" height="10" rx="1.5"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>'),
  signal: ic('<path d="M4 20v-2M9 20v-6M14 20v-10M19 20V4"/>'),
  bell: ic('<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 21h4"/>'),
  info: ic('<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>'),
  sound: ic('<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M16.5 9a4 4 0 0 1 0 6M19 6.5a8 8 0 0 1 0 11"/>'),
  image: ic('<rect x="3" y="4" width="18" height="16" rx="1.5"/><path d="M3 16l5-5 4 4 3-3 6 6"/>'),
  power: ic('<path d="M12 3v8"/><path d="M6.3 6.5a8 8 0 1 0 11.4 0"/>'),
  launder: ic('<rect x="3" y="6" width="18" height="12" rx="1.5"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9.5v5M18 9.5v5"/><path d="M8 3.5l4-1.5 4 1.5M8 20.5l4 1.5 4-1.5"/>'),
  plus: ic('<path d="M12 5v14M5 12h14"/>'),
  send: ic('<path d="M4 12l16-8-6 16-2.5-6.5z"/><path d="M11.5 13.5L20 4"/>'),
  more: ic('<circle cx="6" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="18" cy="12" r="1" fill="currentColor"/>'),
  users: ic('<circle cx="9" cy="8.5" r="3.2"/><path d="M3 19.5c.6-3.3 3-5 6-5s5.4 1.7 6 5"/><path d="M15.5 5.6a3 3 0 0 1 0 5.8M17.5 14.8c1.8.6 3 2.2 3.5 4.7"/>'),
  user: ic('<circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c.8-3.8 3.6-5.8 7-5.8s6.2 2 7 5.8"/>'),
  star: ic('<path d="M12 3.5l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.8l-5.2 2.8 1-5.8-4.3-4.1 5.9-.8z"/>'),
  block: ic('<circle cx="12" cy="12" r="8.5"/><path d="M6 6l12 12"/>'),
  gps: ic('<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>'),
  shield: ic('<path d="M12 3l7.5 3v6c0 4.4-3.1 7.7-7.5 9-4.4-1.3-7.5-4.6-7.5-9V6z"/><path d="M9 12l2.2 2.2L15.5 10"/>'),
  check: ic('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  close: ic('<path d="M6 6l12 12M18 6L6 18"/>'),
  clock: ic('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
  alert: ic('<path d="M12 3.5L21.5 20h-19z"/><path d="M12 10v4.5M12 17.2v.3"/>'),
  key: ic('<circle cx="8" cy="15" r="4"/><path d="M11 12l8.5-8.5M16 7l2.5 2.5M14 9l2 2"/>'),
  trash: ic('<path d="M4.5 7h15M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13"/>'),
  edit: ic('<path d="M15 4.5l4.5 4.5L9 19.5H4.5V15z"/><path d="M13 6.5l4.5 4.5"/>'),
  chevron: ic('<path d="M9 5l7 7-7 7"/>'),
  eye: ic('<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>'),
  thumbup: ic('<path d="M7 11v9H4v-9zM7 11l4-7c1.5 0 2.5 1 2.2 2.6L12.6 10H19a1.6 1.6 0 0 1 1.6 1.9l-1.4 6.6A1.8 1.8 0 0 1 17.4 20H7"/>'),
  thumbdown: ic('<path d="M7 13V4H4v9zM7 13l4 7c1.5 0 2.5-1 2.2-2.6L12.6 14H19a1.6 1.6 0 0 0 1.6-1.9l-1.4-6.6A1.8 1.8 0 0 0 17.4 4H7"/>'),
};
for (const [k, v] of Object.entries(icons)) files[`icons/${k}.svg`] = v;

/* ── Écriture ─────────────────────────────────────────────────────────── */
for (const [rel, content] of Object.entries(files)) {
  let out;
  if (rel.startsWith('brand/')) out = path.join(BRAND, rel.slice(6));
  else if (rel.startsWith('html/')) out = path.join(HTML, rel.slice(5));
  else if (rel.startsWith('icons/')) out = path.join(ICONS, rel.slice(6));
  fs.writeFileSync(out, content);
}
// copies d'icônes pour la documentation de marque
fs.mkdirSync(path.join(BRAND, 'app-icons'), { recursive: true });
for (const k of Object.keys(icons)) fs.copyFileSync(path.join(ICONS, `${k}.svg`), path.join(BRAND, 'app-icons', `${k}.svg`));
fs.copyFileSync(path.join(BRAND, 'noirx-boot.svg'), path.join(HTML, 'boot.svg'));
fs.copyFileSync(path.join(BRAND, 'noirx-inventory-icon.svg'), path.join(INV, 'noirphone.svg'));

/* ── PNG (sharp) ──────────────────────────────────────────────────────── */
(async () => {
  let sharp;
  try { sharp = require('sharp'); } catch { console.log('sharp absent : PNG non générés.'); return; }
  const png = (src, dst, w, h) => sharp(fs.readFileSync(src), { density: 300 }).resize(w, h, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toFile(dst);
  await png(path.join(BRAND, 'noirx-inventory-icon.svg'), path.join(INV, 'noirphone.png'), 512, 512);
  await png(path.join(BRAND, 'noirx-inventory-icon.svg'), path.join(INV, 'noirphone_128.png'), 128, 128);
  await png(path.join(BRAND, 'noirx-logo.svg'), path.join(BRAND, 'noirx-logo.png'), 1520, 520);
  await png(path.join(BRAND, 'noirx-logo-transparent.svg'), path.join(BRAND, 'noirx-logo-transparent.png'), 1520, 520);
  await png(path.join(BRAND, 'noirx-device-case.svg'), path.join(BRAND, 'noirx-device-case.png'), 1800, 1800);
  await png(path.join(BRAND, 'police-pc-identity.svg'), path.join(BRAND, 'police-pc-identity.png'), 1800, 840);
  console.log(`${Object.keys(files).length} SVG + 6 PNG générés.`);
})();
