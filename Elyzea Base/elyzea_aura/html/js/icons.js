'use strict';
/* =========================================================
   ICÔNES — Elyzea Aura 5
   Pictogrammes bicolores : un contour plein + un remplissage
   translucide, posés sur une tuile dont le style change
   selon la personnalisation (Prisme, Verre, Mono).
   ========================================================= */

// Icônes d'applications : c1/c2 = dégradé de la tuile, fill = formes remplies, line = traits seuls
const APP_ICONS = {
  phone:     { c1: '#5BE8BC', c2: '#0F9E83', fill: '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>', line: '<path d="M15 3.5a5.5 5.5 0 0 1 5.5 5.5M15 7a2 2 0 0 1 2 2"/>' },
  messages:  { c1: '#9A8BFF', c2: '#5440E6', fill: '<path d="M21 11.5a8.5 8 0 0 1-12.3 7.1L4 20l1.3-4A8.5 8 0 1 1 21 11.5z"/>', line: '<path d="M8.5 11.5h.01M12.5 11.5h.01M16.5 11.5h.01"/>' },
  store:     { c1: '#73ECF5', c2: '#4373F2', fill: '<rect x="3.5" y="3.5" width="7.5" height="7.5" rx="2.2"/><rect x="13" y="3.5" width="7.5" height="7.5" rx="2.2"/><rect x="3.5" y="13" width="7.5" height="7.5" rx="2.2"/>', line: '<path d="M16.75 13.5v6.5M13.5 16.75H20"/>' },
  camera:    { c1: '#6A7190', c2: '#262A40', fill: '<path d="M4 7.5h3.2L9 5h6l1.8 2.5H20a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8.5a1 1 0 0 1 1-1z"/>', line: '<circle cx="12" cy="13.5" r="3.6"/><path d="M17.5 10.5h.01"/>' },
  contacts:  { c1: '#FFC15C', c2: '#FF7240', fill: '<circle cx="12" cy="8" r="4"/>', line: '<path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>' },
  bank:      { c1: '#3FD9C6', c2: '#2468E6', fill: '<rect x="3" y="5.5" width="18" height="13.5" rx="3"/>', line: '<path d="M3 10h18M7 15h3.5M15.5 15h1.5"/>' },
  gallery:   { c1: '#FF9E7A', c2: '#EC3F86', fill: '<rect x="3" y="4" width="18" height="16" rx="3.5"/>', line: '<circle cx="9" cy="10" r="1.8"/><path d="m21 16-5-5-9 9"/>' },
  notes:     { c1: '#FFD86B', c2: '#F29A16', fill: '<path d="M6 3h9l4 4v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z"/>', line: '<path d="M9 11h6M9 15h6M15 3v4h4"/>' },
  ads:       { c1: '#FF8AB4', c2: '#B544DC', fill: '<path d="M4 9.5v5l10 5V4.5z"/>', line: '<path d="M17.5 8.5a4.5 4.5 0 0 1 0 7M6 14.5 7 20h3l-1-5"/>' },
  maps:      { c1: '#B1E866', c2: '#20A673', fill: '<path d="M12 21.5s-7-6.6-7-12.2a7 7 0 0 1 14 0c0 5.6-7 12.2-7 12.2z"/>', line: '<circle cx="12" cy="9.3" r="2.6"/>' },
  alert:     { c1: '#FF7D8A', c2: '#D92B45', fill: '<path d="M12 3 2.5 20h19z"/>', line: '<path d="M12 10v4.5M12 17.2v.3"/>' },
  calc:      { c1: '#9298B2', c2: '#434962', fill: '<rect x="5" y="3" width="14" height="18" rx="3"/>', line: '<path d="M8.5 7h7M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 16h.01M12 16h.01M15.5 16h.01"/>' },
  settings:  { c1: '#A3A9C0', c2: '#4B5169', fill: '<circle cx="12" cy="12" r="4.2"/>', line: '<path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>' },
  birdy:     { c1: '#72CBFF', c2: '#3A6EF5', fill: '<path d="M15.6 12A5.6 5.6 0 0 0 6 8.4c-.6 3.8 1.5 6.6 5.2 7.4"/>', line: '<path d="M3 18.5c5.6.5 10.6-1.5 12.6-6.5M15.6 8.2 19.6 9l-3.6 2"/><circle cx="12.2" cy="9" r=".5"/>' },
  instapick: { c1: '#FFA14D', c2: '#E2418C', fill: '<rect x="4" y="3" width="16" height="18" rx="3"/>', line: '<path d="M4 16.5h16"/><path d="m12 6.5 1.2 2.4 2.6.4-1.9 1.8.5 2.6L12 12.5l-2.4 1.2.5-2.6-1.9-1.8 2.6-.4z"/>' },
  itoune:    { c1: '#6FE7F2', c2: '#7058F5', fill: '<circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>', line: '<path d="M9 18V5.5l11-2.5v13"/>' },
  etincelle: { c1: '#FF9A5C', c2: '#FF2E6E', fill: '<path d="M12 21.5c-4.1 0-7-2.9-7-6.8 0-3.2 2.1-5.4 3.6-7.5.3 2 1.3 3.1 2.5 3.5C11 7 12.6 4.4 15.1 2.8c-.3 2.9.8 4.8 2.2 6.5 1.1 1.4 1.7 3 1.7 5.4 0 3.9-2.9 6.8-7 6.8z"/>', line: '<path d="M12 18.4c-1.7-1-3-2.2-3-3.7a1.6 1.6 0 0 1 3-.8 1.6 1.6 0 0 1 3 .8c0 1.5-1.3 2.7-3 3.7z"/>' },
  livrezy:   { c1: '#C6F36B', c2: '#16A87A', fill: '<path d="M7.5 8h12l-1 12.2a1.5 1.5 0 0 1-1.5 1.3h-7a1.5 1.5 0 0 1-1.5-1.3z"/>', line: '<path d="M10.5 8V6.5a3 3 0 0 1 6 0V8M2 11.5h3.5M1.5 15h4M2.5 18.5h3"/>' },
  helpmecano:{ c1: '#FFB547', c2: '#E8590C', fill: '<path d="M14.7 3.3a5 5 0 0 0-6.2 6.4L3.6 14.6a2.3 2.3 0 0 0 3.3 3.3l4.9-4.9a5 5 0 0 0 6.4-6.2l-3 3-2.6-.7-.7-2.6z"/>', line: '<path d="M16 16.5h5M18.5 14v5"/>' },
  garage:    { c1: '#7FA8FF', c2: '#3A55D8', fill: '<path d="M3 10.5 12 4l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/>', line: '<path d="M7 21v-6.5h10V21M7 17.5h10"/>' },
  carplay:   { c1: '#5EF0D2', c2: '#1B6FE0', fill: '<circle cx="12" cy="12" r="9"/>', line: '<circle cx="12" cy="12" r="2.6"/><path d="M3.5 10.5c3-1.2 5.6-1.6 8.5-1.6s5.5.4 8.5 1.6M12 14.6v6.2M9.6 13.4 4.8 17.6M14.4 13.4l4.8 4.2"/>' },
  auradrop:  { c1: '#6FE7F2', c2: '#7C6CFF', fill: '<circle cx="12" cy="12" r="3.2"/>', line: '<path d="M7.5 16.5a6.4 6.4 0 0 1 0-9M16.5 7.5a6.4 6.4 0 0 1 0 9M4.6 19.4a10.5 10.5 0 0 1 0-14.8M19.4 4.6a10.5 10.5 0 0 1 0 14.8"/>' },
  system:    { c1: '#9AA0B8', c2: '#4B5169', fill: '<circle cx="12" cy="12" r="8"/>', line: '<path d="M12 8v4.5M12 15.5v.3"/>' },
};

// Tuile d'application (le style dépend de l'attribut data-icons de l'écran)
function appTile(id, badge = '', cls = '') {
  const ic = APP_ICONS[id] || APP_ICONS.system;
  return `<span class="tile-wrap"><span class="tile ${cls}" style="--c1:${ic.c1};--c2:${ic.c2}">${glyph(id)}</span>${badge}</span>`;
}
function glyph(id) {
  const ic = APP_ICONS[id] || APP_ICONS.system;
  return `<svg class="glyph" viewBox="0 0 60 60" aria-hidden="true"><g transform="translate(15 15) scale(1.25)" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><g fill="currentColor" fill-opacity=".3">${ic.fill}</g>${ic.line}</g></svg>`;
}
// Icône pleine (toujours en dégradé) pour notifications, île et magasin
function solidTile(id, size = 42) {
  const ic = APP_ICONS[id] || APP_ICONS.system;
  const gid = 'g' + id + size;
  return `<svg viewBox="0 0 60 60" width="${size}" height="${size}" aria-hidden="true"><defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${ic.c1}"/><stop offset="1" stop-color="${ic.c2}"/></linearGradient></defs><rect width="60" height="60" rx="16" fill="url(#${gid})"/><g transform="translate(15 15) scale(1.25)" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><g fill="#fff" fill-opacity=".3">${ic.fill}</g>${ic.line}</g></svg>`;
}

// Icônes d'interface (traits)
const P = {
  back: '<path d="m15 5-7 7 7 7"/>',
  chev: '<path d="m9 5 7 7-7 7"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  close: '<path d="M6 6l12 12M18 6 6 18"/>',
  send: '<path d="M4 12 20 4l-6 16-3-7z"/>',
  heart: '<path d="M12 20s-8-5-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 9c0 6-8 11-8 11z"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  phone: APP_ICONS.phone.fill,
  messages: APP_ICONS.messages.fill,
  camera: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  pin: '<path d="M12 21s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/>',
  star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
  callIn: '<path d="M17 7 7 17M7 9v8h8"/>',
  callOut: '<path d="M7 17 17 7M9 7h8v8"/>',
  minimize: '<path d="m6 9 6 6 6-6"/>',
  repost: '<path d="M4 10V8a2 2 0 0 1 2-2h12M15 3l3 3-3 3M20 14v2a2 2 0 0 1-2 2H6M9 21l-3-3 3-3"/>',
  comment: '<path d="M4 5h16v11H9.5L5 20v-4H4z"/>',
  play: '<path d="M8 4.5v15l12-7.5z" fill="currentColor"/>',
  pause: '<path d="M7 4.5h3.5v15H7zM13.5 4.5H17v15h-3.5z" fill="currentColor"/>',
  next: '<path d="M5 5.5v13l9.5-6.5zM18.5 5.5v13"/>',
  prev: '<path d="M19 5.5v13L9.5 12zM5.5 5.5v13"/>',
  speaker: '<path d="M4 9h4l5-4v14l-5-4H4z"/><path d="M17 9a4 4 0 0 1 0 6"/>',
  shield: '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/>',
  cross: '<path d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
  wrench: '<path d="M14.5 5.5a4 4 0 0 0 5 5L11 19a2.1 2.1 0 0 1-3-3z"/>',
  car: '<path d="M3 16v-4l2-5h14l2 5v4z"/><circle cx="7" cy="16" r="2"/><circle cx="17" cy="16" r="2"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
  face: '<path d="M4 8V6a2 2 0 0 1 2-2h2M16 4h2a2 2 0 0 1 2 2v2M20 16v2a2 2 0 0 1-2 2h-2M8 20H6a2 2 0 0 1-2-2v-2"/><path d="M9 9.5v1M15 9.5v1M12 9.5v3.5h-1M9 15.5c1.8 1.4 4.2 1.4 6 0"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
  drop: APP_ICONS.auradrop.line + '<circle cx="12" cy="12" r="2.4" fill="currentColor"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
  card: '<rect x="3" y="5.5" width="18" height="13.5" rx="3"/><path d="M3 10h18"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z"/>',
  moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
  bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
  plane: '<path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>',
  palette: '<path d="M12 3a9 9 0 0 0 0 18c1.2 0 1.8-.8 1.8-1.7 0-1.3-1-1.6-1-2.8 0-1 .8-1.5 1.8-1.5H17a4 4 0 0 0 4-4C21 6.6 17 3 12 3z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7" r="1"/>',
  grid: '<rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/>',
  music: APP_ICONS.itoune.line + '<circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
  size: '<path d="M4 20 20 4M14 4h6v6M10 20H4v-6"/>',
  reset: '<path d="M4 12a8 8 0 1 0 2.4-5.7L4 8.5M4 4v4.5h4.5"/>',
  arrowUp: '<path d="M7 17 17 7M9 7h8v8"/>',
  arrowDown: '<path d="M17 7 7 17M7 9v8h8"/>',
  inbox: '<path d="M4 13h4.5l1.5 2.5h4l1.5-2.5H20"/><path d="M5.5 5h13L20 13v6H4v-6z"/>',
  wallpaper: '<rect x="4" y="3" width="16" height="18" rx="3"/><path d="m4 16 4.5-4.5 4 4 2.5-2.5L20 18"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  frame: '<rect x="6" y="2.5" width="12" height="19" rx="3.5"/><path d="M10.5 5h3"/>',
  sparkle: '<path d="M12 3c.6 4.2 2.8 6.4 7 7-4.2.6-6.4 2.8-7 7-.6-4.2-2.8-6.4-7-7 4.2-.6 6.4-2.8 7-7z"/>',
  carplay: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.6"/><path d="M3.5 10.5c3-1.2 5.6-1.6 8.5-1.6s5.5.4 8.5 1.6M12 14.6v6.2M9.6 13.4 4.8 17.6M14.4 13.4l4.8 4.2"/>',
  alert: '<path d="M12 3 2.5 20h19z"/><path d="M12 10v4.5M12 17.2v.3"/>',
  hash: '<path d="M5 9h15M4 15h15M10 3 8 21M16 3l-2 18"/>',
};
const icon = (name, color) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="${color || 'currentColor'}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[name] || ''}</svg>`;
