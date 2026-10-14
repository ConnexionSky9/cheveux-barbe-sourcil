// Génère les fichiers SVG de l'identité BLACKPHONE (node assets_src/build.js)
require('../html/js/brand.js');
const fs = require('fs'); const path = require('path');
const out = path.join(__dirname, '..', 'html', 'assets');
const B = globalThis.BPBrand;
const W = (n, s) => fs.writeFileSync(path.join(out, n), s);
const lg = (o) => { const l = B.logo(o); return B.svgDoc(l.svg, l.width, l.height, 18); };
W('logo.svg', lg({ color: '#f2f2f2', accent: '#b3161b' }));                       // principal (blanc, transparent)
W('logo_mono_black.svg', lg({ color: '#0b0b0c', accent: '#0b0b0c' }));             // monochrome noir
W('logo_mono_white.svg', lg({ color: '#f2f2f2', accent: '#f2f2f2' }));             // monochrome blanc
W('logo_red.svg', lg({ color: '#0b0b0c', accent: '#7d0f13', accentWord: true }));  // noir et rouge sombre
W('mark.svg', B.svgDoc(B.mark({ color: '#f2f2f2', accent: '#b3161b' }), 68, 104, 8));
// Icône d'inventaire : le terminal vu de face (dos noir mat, monogramme, liseré)
W('icon.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs>
    <linearGradient id="body" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#2a2a2e"/><stop offset=".45" stop-color="#0d0d0f"/><stop offset="1" stop-color="#050506"/></linearGradient>
    <linearGradient id="edge" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#5a5a60"/><stop offset=".5" stop-color="#1a1a1d"/><stop offset="1" stop-color="#3a3a40"/></linearGradient>
    <radialGradient id="glow" cx=".5" cy=".9" r=".5"><stop offset="0" stop-color="#000" stop-opacity=".55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  </defs>
  <ellipse cx="128" cy="238" rx="70" ry="12" fill="url(#glow)"/>
  <g transform="rotate(-12 128 128)">
    <rect x="70" y="18" width="116" height="214" rx="22" fill="url(#edge)"/>
    <rect x="74" y="22" width="108" height="206" rx="19" fill="url(#body)"/>
    <rect x="86" y="34" width="34" height="42" rx="9" fill="#09090a" stroke="#2c2c31" stroke-width="2"/>
    <circle cx="98" cy="48" r="6" fill="#141418" stroke="#38383e" stroke-width="2"/><circle cx="109" cy="64" r="4" fill="#141418" stroke="#38383e" stroke-width="1.5"/>
    <g transform="translate(103 108) scale(0.82)">${B.mark({ color: '#d9d9dc', accent: '#b3161b' })}</g>
    <path d="M78 40 Q80 24 96 23" stroke="#ffffff" stroke-opacity=".18" stroke-width="3" fill="none"/>
  </g></svg>`);
// Fond d'écran : noir profond, trame diagonale, monogramme fantôme
W('wallpaper.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 860" width="400" height="860">
  <defs><pattern id="p" width="14" height="14" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><path d="M0 0V14" stroke="#ffffff" stroke-opacity=".025" stroke-width="1"/></pattern>
  <radialGradient id="v" cx=".5" cy=".35" r=".8"><stop offset="0" stop-color="#141416"/><stop offset="1" stop-color="#020203"/></radialGradient>
  <linearGradient id="r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7d0f13" stop-opacity="0"/><stop offset="1" stop-color="#7d0f13" stop-opacity=".18"/></linearGradient></defs>
  <rect width="400" height="860" fill="url(#v)"/><rect width="400" height="860" fill="url(#p)"/><rect y="560" width="400" height="300" fill="url(#r)"/>
  <g transform="translate(110 250) scale(2.8)" opacity=".06">${B.mark({ color: '#ffffff', accent: '#ffffff' })}</g></svg>`);
// PC portable police (icône d'inventaire)
W('police_laptop.svg', `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#16243d"/><stop offset="1" stop-color="#0a1222"/></linearGradient>
  <linearGradient id="k" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3b4350"/><stop offset="1" stop-color="#1b2029"/></linearGradient></defs>
  <ellipse cx="128" cy="222" rx="104" ry="10" fill="#000" opacity=".35"/>
  <path d="M46 52H210V176H46Z" fill="#1d232c" stroke="#4a5363" stroke-width="4"/><rect x="56" y="62" width="144" height="104" fill="url(#s)"/>
  <path d="M128 78L156 88V112C156 128 144 140 128 146C112 140 100 128 100 112V88Z" fill="none" stroke="#5aa2ff" stroke-width="5"/>
  <path d="M116 112L125 121L141 103" fill="none" stroke="#5aa2ff" stroke-width="5"/>
  <path d="M30 186H226L240 212H16Z" fill="url(#k)" stroke="#555e6d" stroke-width="3"/><rect x="104" y="196" width="48" height="7" rx="2" fill="#11151b"/></svg>`);
console.log('ok');
