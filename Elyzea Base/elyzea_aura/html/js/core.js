'use strict';
/* =========================================================
   CŒUR — utilitaires, langue, état, sons, apparence
   ========================================================= */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const IS_BROWSER = !RES;

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const pad = (n) => String(n).padStart(2, '0');

// ---------- Langue ----------
// Les textes sont écrits en français ; i18n.js fournit l'anglais et l'espagnol.
function t(fr, params) {
  const lang = S.settings.lang || 'fr';
  let s = (lang !== 'fr' && I18N[lang] && I18N[lang][fr]) || fr;
  if (params) s = s.replace(/\{(\w+)\}/g, (_, k) => params[k] ?? '');
  return s;
}
const LOCALES = { fr: 'fr-FR', en: 'en-US', es: 'es-ES' };
const locale = () => LOCALES[S.settings.lang] || 'fr-FR';
const money = (n) => '$' + Math.round(Number(n) || 0).toLocaleString(locale());

// ---------- Échanges avec le client Lua ----------
async function post(endpoint, data = {}) {
  if (IS_BROWSER) return Mock.handle(endpoint, data);
  try {
    const r = await fetch(`https://${RES}/${endpoint}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data)
    });
    return await r.json();
  } catch (e) { return { ok: false, error: 'network' }; }
}
const api = (name, args = {}) => post('request', { name, args });

// ---------- Temps ----------
function timeAgo(ts) {
  if (!ts) return '';
  const d = new Date(ts * 1000), now = new Date();
  const diff = (now - d) / 1000;
  if (diff < 60) return t('À l\'instant');
  if (diff < 3600) return t('{n} min', { n: Math.floor(diff / 60) });
  if (d.toDateString() === now.toDateString()) return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
  const y = new Date(now); y.setDate(now.getDate() - 1);
  if (d.toDateString() === y.toDateString()) return t('Hier');
  return d.toLocaleDateString(locale(), { day: '2-digit', month: '2-digit' });
}
const duration = (s) => `${Math.floor(s / 60)}:${pad(s % 60)}`;

// ---------- Avatars ----------
const AV_COLORS = ['#7C6CFF', '#2FB7C4', '#FF6F9E', '#F2A33A', '#4C8DFF', '#3FBF8E', '#B57CFF', '#FF8A5C'];
function avColor(key) {
  let h = 0; for (const c of String(key)) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return AV_COLORS[h % AV_COLORS.length];
}
function initials(name) {
  const p = String(name || '?').trim().split(/\s+/);
  return ((p[0]?.[0] || '') + (p[1]?.[0] || '')).toUpperCase() || '#';
}
const avatar = (name, key, cls = '') =>
  `<div class="avatar ${cls}" style="--av:${avColor(key ?? name)}">${esc(/^\d/.test(name) ? '#' : initials(name))}</div>`;

// ---------- État ----------
const S = {
  open: false, profile: null, settings: { lang: 'fr' }, contacts: [],
  stack: [], currentApp: null, unread: 0, call: null, callTimer: null,
  thread: null, gameTime: null, locked: true, lockNotifs: [], pendingDrops: [], notes: []
};
const nameFor = (number) => S.contacts.find(c => c.number === number)?.name || number;

// ---------- Apparence ----------
const WALLPAPERS = ['halo', 'aube', 'nebuleuse', 'glacier', 'braise', 'foret', 'uni'];
const WP_NAMES = { halo: 'Halo', aube: 'Aube', nebuleuse: 'Nébuleuse', glacier: 'Glacier', braise: 'Braise', foret: 'Forêt', uni: 'Uni' };
const ACCENTS = { plasma: '#7C6CFF', glace: '#2FC9D9', rose: '#FF6F9E', ambre: '#F5A524', cobalt: '#4C8DFF', lime: '#7FCB3A' };
const FRAMES = { titane: 'linear-gradient(150deg,#A3A9B9,#5E6372)', graphite: 'linear-gradient(150deg,#474B5A,#1B1D26)', nacre: 'linear-gradient(150deg,#FFFFFF,#CFCAD9)', aurore: 'linear-gradient(150deg,#E6C4F5,#7F95EE)' };
const RINGTONES = { cristal: 'Cristal', onde: 'Onde', classique: 'Classique', orbite: 'Orbite' };

const screenEl = $('#screen'), phoneEl = $('#phone'), stage = $('#stage');
const appView = $('#app'), callView = $('#call'), island = $('#island'), lockView = $('#lock'), setupView = $('#setup');

function resolvedTheme() {
  const th = S.settings.theme;
  if (th === 'light' || th === 'dark') return th;
  const h = S.gameTime ? S.gameTime.h : new Date().getHours();
  return (h >= 7 && h < 20) ? 'light' : 'dark';
}
function accentHex() {
  const a = S.settings.accent;
  return /^#[0-9a-f]{6}$/i.test(a) ? a : (ACCENTS[a] || ACCENTS.plasma);
}
function inkFor(hex) {
  const n = parseInt(hex.slice(1), 16), r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  return (0.299 * r + 0.587 * g + 0.114 * b) > 170 ? '#151833' : '#FFFFFF';
}
function applySettings() {
  const s = S.settings, root = document.documentElement.style;
  screenEl.dataset.theme = resolvedTheme();
  document.body.dataset.theme = resolvedTheme();
  screenEl.dataset.icons = ['prisme', 'verre', 'mono'].includes(s.iconStyle) ? s.iconStyle : 'prisme';
  const wp = $('#wp');
  if (/^https:\/\//.test(s.wallpaper || '')) {
    wp.removeAttribute('data-wp');
    wp.style.setProperty('--wp', `url("${String(s.wallpaper).replace(/"/g, '')}")`);
    screenEl.classList.add('no-halo');
  } else {
    wp.style.removeProperty('--wp');
    wp.dataset.wp = WALLPAPERS.includes(s.wallpaper) ? s.wallpaper : 'halo';
    screenEl.classList.toggle('no-halo', s.wallpaper === 'uni');
  }
  const acc = accentHex();
  root.setProperty('--accent', acc);
  root.setProperty('--accent-ink', inkFor(acc));
  root.setProperty('--accent-soft', acc + '2E');
  root.setProperty('--zoom', (Number(s.zoom) || 100) / 100);
  phoneEl.dataset.frame = FRAMES[s.frame] ? s.frame : 'titane';
  phoneEl.classList.toggle('no-edge', s.edgeLight === false);
  $('#sb-plane').classList.toggle('hidden', !s.airplane);
  $('#sb-signal').classList.toggle('hidden', !!s.airplane);
  document.documentElement.lang = s.lang || 'fr';
  $('#home-bar').setAttribute('aria-label', t('Accueil'));
}
async function saveSettings(patch) {
  Object.assign(S.settings, patch);
  applySettings();
  const r = await api('saveSettings', { settings: S.settings });
  if (r.ok && r.settings) { S.settings = Object.assign(S.settings, r.settings); applySettings(); }
  return r;
}
const hasSecurity = () => !!(S.profile?.passcode?.set);

// ---------- Sons (Web Audio, aucun fichier requis) ----------
const Sound = (() => {
  let ctx, loop;
  const ac = () => (ctx ||= new (window.AudioContext || window.webkitAudioContext)());
  function note(freq, start, len, type = 'sine', vol = .16) {
    try {
      const c = ac(), o = c.createOscillator(), g = c.createGain();
      o.type = type; o.frequency.value = freq;
      g.gain.setValueAtTime(0, c.currentTime + start);
      g.gain.linearRampToValueAtTime(vol, c.currentTime + start + .02);
      g.gain.exponentialRampToValueAtTime(.0001, c.currentTime + start + len);
      o.connect(g).connect(c.destination);
      o.start(c.currentTime + start); o.stop(c.currentTime + start + len + .05);
    } catch (e) { /* audio indisponible */ }
  }
  const patterns = {
    cristal: () => { [1318, 1568, 1976, 1568].forEach((f, i) => note(f, i * .13, .5, 'triangle')); },
    onde: () => { [880, 660, 880, 660].forEach((f, i) => note(f, i * .22, .3, 'sine', .2)); },
    classique: () => { note(440, 0, 1, 'sine', .12); note(480, 0, 1, 'sine', .12); },
    orbite: () => { [523, 659, 784, 1046, 784, 659].forEach((f, i) => note(f, i * .1, .35, 'sine', .14)); },
  };
  return {
    ring(name, force) {
      this.stop(); if (S.settings.silent && !force) return;
      const p = patterns[name] || patterns.cristal; p();
      loop = setInterval(p, 1900);
    },
    preview(name) { this.stop(); (patterns[name] || patterns.cristal)(); },
    ringback() { this.stop(); const p = () => note(425, 0, 1.2, 'sine', .07); p(); loop = setInterval(p, 4000); },
    stop() { clearInterval(loop); loop = null; },
    ping() { if (S.settings.silent) return; note(1568, 0, .25, 'triangle', .12); note(2093, .09, .35, 'triangle', .1); },
    unlock() { if (S.settings.silent) return; note(880, 0, .12, 'sine', .08); note(1318, .07, .2, 'sine', .08); },
    error() { if (S.settings.silent) return; note(220, 0, .18, 'square', .05); note(196, .12, .22, 'square', .05); },
    tap(d) { const f = { 1: 697, 2: 770, 3: 852 }; note(f[(+d % 3) + 1] || 941, 0, .08, 'sine', .05); },
    shutter() { if (S.settings.silent) return; note(2400, 0, .05, 'square', .04); note(1200, .04, .08, 'triangle', .06); },
    recStart() { if (S.settings.silent) return; note(880, 0, .15, 'sine', .08); },
    recStop() { if (S.settings.silent) return; note(660, 0, .15, 'sine', .08); note(440, .1, .2, 'sine', .08); },
    boot() { [392, 523, 659, 784].forEach((f, i) => note(f, i * .16, .9, 'sine', .07)); },
  };
})();

// ---------- Presse-papiers (compatible navigateur de FiveM) ----------
function copyText(text) {
  const ta = document.createElement('textarea');
  ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
  document.body.appendChild(ta); ta.select();
  try { document.execCommand('copy'); } catch (e) { /* ignoré */ }
  ta.remove();
}

// ---------- Gabarit d'application ----------
function frame({ title, back: hasBack = true, action = '', body = '', foot = '', tabs = '', small = false }) {
  appView.innerHTML = `<div class="app">
    <header class="app__head">
      ${hasBack ? `<button class="icon-btn" data-back aria-label="${t('Retour')}">${icon('back')}</button>` : ''}
      <h1 class="app__title ${small ? 'app__title--sm' : ''}">${title}</h1>${action}
    </header>${tabs}
    <div class="app__body">${body}</div>${foot ? `<div class="app__foot">${foot}</div>` : ''}
  </div>`;
  return appView;
}
const loading = () => `<div class="spinner" role="status" aria-label="${t('Chargement')}"></div>`;
const empty = (title, text, btn = '') => `<div class="empty"><strong>${title}</strong>${text}${btn}</div>`;
const tabsHtml = (items, active, attr) => `<div class="tabs" role="tablist">${items.map(([k, l]) =>
  `<button class="tab ${active === k ? 'active' : ''}" ${attr}="${k}" role="tab" aria-selected="${active === k}">${l}</button>`).join('')}</div>`;

// ---------- Feuille modale ----------
function openSheet(title, html, onMount) {
  closeSheet(true);
  const bd = document.createElement('div'); bd.className = 'sheet-backdrop';
  const sh = document.createElement('div'); sh.className = 'sheet';
  sh.setAttribute('role', 'dialog');
  sh.innerHTML = `${title ? `<h2 class="sheet__title">${title}</h2>` : ''}${html}`;
  screenEl.append(bd, sh);
  bd.addEventListener('click', () => closeSheet());
  requestAnimationFrame(() => { bd.classList.add('show'); sh.classList.add('show'); });
  onMount?.(sh);
  setTimeout(() => sh.querySelector('input:not([type=range]):not([type=color]), textarea')?.focus(), 320);
  return sh;
}
function closeSheet(instant) {
  const sh = $('.sheet', screenEl), bd = $('.sheet-backdrop', screenEl);
  if (!sh) return false;
  sh.dispatchEvent(new Event('sheetclose'));
  if (instant) { sh.remove(); bd?.remove(); return true; }
  sh.classList.remove('show'); bd?.classList.remove('show');
  setTimeout(() => { sh.remove(); bd?.remove(); }, 320);
  return true;
}
function confirmSheet(title, text, label, onYes) {
  openSheet(title, `<p class="sheet__text">${text}</p>
    <div class="form"><button class="btn btn--danger btn--block" data-yes>${label}</button>
    <button class="btn btn--ghost btn--block" data-no>${t('Annuler')}</button></div>`, (sh) => {
    sh.querySelector('[data-yes]').onclick = () => { closeSheet(); onYes(); };
    sh.querySelector('[data-no]').onclick = () => closeSheet();
  });
}

// ---------- Notifications ----------
// Modèles des notifications envoyées par le serveur (traduits selon la langue)
const NOTIFS = {
  noPhone:        { title: 'Elyzea Aura', text: 'Vous n\'avez pas de téléphone.' },
  bankReceived:   { title: 'Virement reçu', text: '{amount} de {number}' },
  bankRequest:    { title: 'Demande de paiement', text: '{number} vous demande {amount}' },
  requestPaid:    { title: 'Demande payée', text: '{number} vous a payé {amount}' },
  requestDeclined:{ title: 'Demande refusée', text: '{number} a refusé votre demande de {amount}' },
  mention:        { title: '{name} vous a mentionné' },
  newPost:        { title: '{name} sur Birdy' },
  newPhoto:       { title: '{name} sur InstaPick', fallback: 'Nouvelle photo' },
  comment:        { title: '{name} a commenté' },
  codeReset:      { title: 'Code réinitialisé', text: 'Un administrateur a supprimé votre code.' },
  dropAccepted:   { title: 'AuraDrop', text: '{device} a enregistré votre fiche' },
  dropDeclined:   { title: 'AuraDrop', text: '{device} a refusé votre fiche' },
  alert:          { title: 'Appel {service}' },
  deliveryEnroute:{ title: 'Votre livreur est en route', text: 'Parti de {shop}. Suivez-le sur votre GPS.' },
  deliveryNear:   { title: 'Livrézy', text: 'Votre livreur arrive dans un instant.' },
  deliveryArrived:{ title: 'Votre livreur est arrivé', text: 'Il vient vous remettre votre commande.' },
  deliveryDone:   { title: 'Commande livrée', text: 'Bon appétit !' },
  deliveryPartial:{ title: 'Commande livrée', text: 'Certains articles ne tenaient pas dans vos poches : {amount} remboursés.' },
  deliveryFailed: { title: 'Livraison annulée', text: 'Le livreur n\'a pas pu vous rejoindre. Vous avez été remboursé.' },
  mechEnroute:    { title: 'La dépanneuse est en route', text: 'Partie de {garage}. Suivez-la sur votre GPS.' },
  mechNear:       { title: 'HelpMécano', text: 'La dépanneuse arrive dans un instant.' },
  mechArrived:    { title: 'Le mécanicien est arrivé', text: 'Il se dirige vers votre véhicule.' },
  mechDone:       { title: 'Intervention terminée', text: '{service} effectué. Bonne route !' },
  mechFailed:     { title: 'Intervention annulée', text: 'Le mécanicien n\'a pas pu vous rejoindre. Vous avez été remboursé.' },
  mechNoVehicle:  { title: 'Intervention annulée', text: 'Votre véhicule a disparu. Vous avez été remboursé.' },
  valetEnroute:   { title: 'Votre véhicule arrive', text: 'Le voiturier vous apporte {vehicle}. Suivez-le sur votre GPS.' },
  valetNear:      { title: 'Garage', text: 'Votre véhicule arrive dans un instant.' },
  valetArrived:   { title: 'Le voiturier est arrivé', text: 'Il vient vous remettre les clés.' },
  valetDone:      { title: 'Véhicule livré', text: 'Les clés de {vehicle} sont à vous. Bonne route !' },
  valetFailed:    { title: 'Livraison annulée', text: 'Le voiturier n\'a pas pu vous rejoindre. Vous avez été remboursé et le véhicule est resté au garage.' },
  cpSummonGo:     { title: 'Votre voiture arrive', text: 'Elle vient seule jusqu\'à vous. Suivez-la sur le GPS.' },
  cpSummonDone:   { title: 'Votre voiture est là', text: 'Elle est garée à côté de vous, moteur allumé et déverrouillée.' },
  cpSummonFail:   { title: 'CarPlay', text: 'Impossible de prendre le contrôle du véhicule. Réessayez.' },
  cpNoVehicle:    { title: 'ElyzeaCarPlay', text: 'Montez dans un véhicule pour ouvrir la tablette.' },
  cpSeat:         { title: 'ElyzeaCarPlay', text: 'La tablette est réservée aux places avant.' },
  datingMatch:    { title: 'C\'est une étincelle !', text: 'Vous et {name} vous plaisez.' },
  datingMessage:  { title: '{name} sur Étincelle' },
  datingSuper:    { title: 'Étincelle', text: 'Quelqu\'un vous a envoyé un coup de cœur.' },
  cameraOff:      { title: 'Appareil photo', text: 'Appareil photo non configuré sur ce serveur.' },
  photoSaved:     { title: 'Photo enregistrée', text: 'Disponible dans la galerie.' },
  photoFailed:    { title: 'Échec de l\'envoi', text: 'Vérifiez la configuration de l\'appareil photo.' },
};
function resolveNotif(d) {
  if (!d.key) return d;
  const tpl = NOTIFS[d.key] || {};
  const params = Object.assign({}, d.params);
  if (params.amount !== undefined) params.amount = money(params.amount);
  if (d.key === 'alert' && params.number) d.text = `${params.number} : ${d.text || ''}`;
  return {
    app: d.app, sticky: d.sticky,
    title: tpl.title ? t(tpl.title, params) : '',
    text: d.text || (tpl.text ? t(tpl.text, params) : (tpl.fallback ? t(tpl.fallback) : '')),
  };
}

let islandTimeout;
function islandNotify({ app = 'system', title, text }) {
  if (S.call?.status === 'active' && !callView.classList.contains('active')) return toast({ app, title, text });
  island.classList.remove('compact', 'music', 'tall');
  $('.island__content', island).innerHTML = `<div class="island__icon">${solidTile(app, 42)}</div>
    <div class="island__text"><div class="island__title">${esc(title)}</div><div class="island__body">${esc(text)}</div></div>`;
  island.classList.add('expanded');
  island.onclick = () => { collapseIsland(); if (APPS[app] && !S.locked) openApp(app); };
  clearTimeout(islandTimeout);
  islandTimeout = setTimeout(collapseIsland, 4200);
}
function collapseIsland() {
  island.classList.remove('expanded', 'tall');
  island.onclick = null;
  if (S.call && !callView.classList.contains('active')) showCallIsland();
  else if (typeof Music !== 'undefined' && Music.playing) showMusicIsland();
  else setTimeout(() => { if (!island.classList.contains('expanded') && !island.classList.contains('compact')) $('.island__content', island).innerHTML = ''; }, 300);
}

function toast({ app = 'system', title, text, sticky }) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.innerHTML = `<div class="island__icon">${solidTile(app, 38)}</div>
    <div class="island__text"><div class="island__title">${esc(title)}</div><div class="island__body">${esc(text)}</div></div>`;
  const box = $('#toasts');
  box.prepend(el);
  while (box.children.length > 3) box.lastChild.remove();
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, sticky ? 9000 : 4500);
}

// Aperçu : le téléphone remonte en bas à droite avec la notification, puis redescend
let peekTimer = null;
function peekNotify(d) {
  if (!S.profile || S.open || S.call || S.settings.notifPreview === false || !S.settings.setup) return false;
  if (stage.classList.contains('peek')) return false;
  S.peekNotifs = [d].concat(S.peekNotifs || []).slice(0, 3);
  const pv = $('#peek');
  const now = new Date();
  const h = S.gameTime ? S.gameTime.h : now.getHours(), m = S.gameTime ? S.gameTime.m : now.getMinutes();
  pv.innerHTML = `<div class="peek">
    <p class="peek__date">${now.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' })}</p>
    <p class="peek__time">${pad(h)}:${pad(m)}</p>
    <div class="peek__list">${S.peekNotifs.map((n, i) => `<div class="lock__notif ${i === 0 ? 'peek__new' : ''}"><div class="island__icon">${solidTile(n.app, 34)}</div>
      <div class="island__text"><div class="island__title">${esc(n.title)}</div><div class="island__body">${esc(n.text)}</div></div></div>`).join('')}</div></div>`;
  pv.classList.add('active');
  screenEl.classList.add('peeking');
  stage.classList.remove('hidden');
  stage.classList.add('notif-peek');
  clearTimeout(peekTimer);
  peekTimer = setTimeout(endPeek, 5200);
  return true;
}
function endPeek() {
  clearTimeout(peekTimer);
  stage.classList.remove('notif-peek');
  S.peekNotifs = [];
  if (!S.open) setVisibility();
  setTimeout(() => {
    if (stage.classList.contains('notif-peek')) return;
    $('#peek').classList.remove('active'); $('#peek').innerHTML = '';
    screenEl.classList.remove('peeking');
  }, 550);
}

function notify(raw) {
  const d = resolveNotif(raw);
  if (S.settings.notifications === false && d.app !== 'alert') return;
  if (!S.open) {
    if (S.locked) { S.lockNotifs.unshift(d); S.lockNotifs = S.lockNotifs.slice(0, 4); }
    if (!peekNotify(d)) toast(d);
    return;
  }
  if (S.open && S.locked) {
    S.lockNotifs.unshift(d); S.lockNotifs = S.lockNotifs.slice(0, 4);
    if (lockView.classList.contains('active') && !$('.passcode', lockView)) renderLock();
    islandNotify(d);
    return;
  }
  if (S.open && !stage.classList.contains('ghost')) islandNotify(d); else toast(d);
}
function updateToastOffset() {
  $('#toasts').style.bottom = S.open ? 'calc(3vh + 830px * var(--zoom))' : '3vh';
}
