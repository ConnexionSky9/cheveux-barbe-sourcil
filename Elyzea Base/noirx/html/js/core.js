/* NOIR X — cœur du téléphone
 * Fournit : état, communication avec le serveur (NX.rpc), événements serveur (NX.on),
 * sons, icônes, notifications, portefeuille, navigation et registre d'applications.
 *
 * Ajouter une application = créer html/js/apps/<id>.js qui appelle :
 *   NX.registerApp('<id>', { title: 'Nom', render(body, api) {...}, onBack() {...}, destroy() {...} })
 * puis l'inclure dans index.html et l'activer dans config.lua (Config.Apps).
 */
(function () {
  'use strict';

  const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'noirx';
  const IN_GAME = typeof GetParentResourceName === 'function';

  const NX = {
    inGame: IN_GAME,
    state: {
      open: false,
      booted: false,
      serial: '',
      symbol: '$',
      settings: { wallpaper: 'void', sounds: true, volume: 0.35, battery: 100 },
      apps: [],
      ui: { bootDuration: 1800, showBootEveryOpen: false, battery: { enabled: true, drainPerMinute: 0.4, min: 8 }, sounds: {}, wallpapers: ['void'] },
      time: { h: 0, m: 0 },
      current: null,
      wallet: null,
      badges: {},
    },
    registry: {},
  };

  /* ── Communication avec le client Lua ─────────────────────────── */
  NX.post = function (name, data) {
    if (!IN_GAME) return Promise.resolve({ ok: true });
    return fetch(`https://${RESOURCE}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then(r => r.json()).catch(() => ({ ok: false, error: 'nui', message: 'Liaison interrompue.' }));
  };

  /** Appel serveur. Résout toujours avec un objet { ok, ... } (jamais d'exception). */
  NX.rpc = function (name, args) {
    if (!IN_GAME) {
      return NX.mock ? NX.mock.call(name, args || {}) : Promise.resolve({ ok: false, error: 'offline', message: 'Hors ligne.' });
    }
    return NX.post('rpc', { name, args: args || {} }).then(r => r || { ok: false });
  };

  /* ── Événements serveur (push) ────────────────────────────────── */
  const listeners = {};
  NX.on = function (event, fn) {
    (listeners[event] = listeners[event] || []).push(fn);
    return () => NX.off(event, fn);
  };
  NX.off = function (event, fn) {
    const l = listeners[event];
    if (l) listeners[event] = l.filter(f => f !== fn);
  };
  NX.emit = function (event, payload) {
    (listeners[event] || []).slice().forEach(fn => {
      try { fn(payload || {}); } catch (e) { console.error('[noirx]', event, e); }
    });
  };

  /* ── Icônes ───────────────────────────────────────────────────── */
  // URL absolue : une url() relative dans une variable CSS serait résolue depuis css/.
  const iconUrl = name => `url("${new URL(`assets/icons/${name}.svg`, document.baseURI).href}")`;
  NX.applyIcons = function (root) {
    (root || document).querySelectorAll('[data-icon]').forEach(el => {
      el.style.setProperty('--ic', iconUrl(el.dataset.icon));
    });
  };
  NX.icon = function (name, cls) {
    const s = document.createElement('span');
    s.dataset.icon = name;
    if (cls) s.className = cls;
    s.style.setProperty('--ic', iconUrl(name));
    return s;
  };

  /* ── Sons (synthèse WebAudio : aucun fichier audio requis) ────── */
  let audio = null;
  function ctx() {
    if (!audio) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      audio = new AC();
    }
    if (audio.state === 'suspended') audio.resume();
    return audio;
  }
  function tone(freq, start, dur, vol, type, endFreq) {
    const a = ctx(); if (!a) return;
    const o = a.createOscillator();
    const g = a.createGain();
    o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, a.currentTime + start);
    if (endFreq) o.frequency.exponentialRampToValueAtTime(endFreq, a.currentTime + start + dur);
    g.gain.setValueAtTime(0.0001, a.currentTime + start);
    g.gain.exponentialRampToValueAtTime(Math.max(vol, 0.0002), a.currentTime + start + 0.008);
    g.gain.exponentialRampToValueAtTime(0.0001, a.currentTime + start + dur);
    o.connect(g).connect(a.destination);
    o.start(a.currentTime + start);
    o.stop(a.currentTime + start + dur + 0.02);
  }
  NX.sound = function (kind) {
    const s = NX.state.settings;
    const cfg = NX.state.ui.sounds || {};
    if (!s.sounds || cfg.enabled === false || cfg[kind] === false) return;
    const v = Math.max(0, Math.min(1, s.volume)) * 0.25;
    if (v <= 0) return;
    switch (kind) {
      case 'tap': tone(1600, 0, 0.035, v * 0.5, 'sine'); break;
      case 'open': tone(320, 0, 0.12, v, 'sine', 640); tone(960, 0.08, 0.16, v * 0.6, 'sine'); break;
      case 'close': tone(640, 0, 0.14, v * 0.8, 'sine', 260); break;
      case 'notify': tone(1180, 0, 0.09, v, 'triangle'); tone(1580, 0.11, 0.14, v * 0.8, 'triangle'); break;
      case 'send': tone(900, 0, 0.06, v * 0.6, 'sine', 1400); break;
      case 'error': tone(220, 0, 0.16, v * 0.8, 'square'); break;
      case 'alert': [0, 0.18, 0.36].forEach(t => tone(880, t, 0.12, v, 'sawtooth', 660)); break;
      case 'win': tone(660, 0, 0.1, v, 'triangle'); tone(990, 0.1, 0.18, v, 'triangle'); break;
      case 'lose': tone(440, 0, 0.18, v, 'triangle', 220); break;
      case 'key': tone(2400, 0, 0.012, v * 0.25, 'square'); break;
    }
  };

  /* ── Formatage ────────────────────────────────────────────────── */
  NX.money = function (n) {
    if (n === null || n === undefined || isNaN(n)) return '—';
    const s = Math.floor(Math.abs(n)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    return `${n < 0 ? '−' : ''}${NX.state.symbol}${s}`;
  };

  /* ── Heure en jeu ─────────────────────────────────────────────── */
  const pad = n => String(n).padStart(2, '0');
  NX.setTime = function (t) {
    if (!t) return;
    NX.state.time = t;
    const str = `${pad(t.h)}:${pad(t.m)}`;
    document.getElementById('sb-time').textContent = str;
    document.getElementById('home-time').textContent = str;
  };

  /* ── Batterie (visuelle) ──────────────────────────────────────── */
  NX.renderBattery = function () {
    const b = document.getElementById('sb-battery');
    const cfg = NX.state.ui.battery || {};
    b.hidden = cfg.enabled === false;
    const lvl = Math.round(NX.state.settings.battery);
    b.querySelector('.battery__fill').style.width = `${lvl}%`;
    b.classList.toggle('is-low', lvl <= 20);
    b.title = `${lvl} %`;
  };
  setInterval(() => {
    const cfg = NX.state.ui.battery || {};
    if (!NX.state.open || cfg.enabled === false) return;
    const s = NX.state.settings;
    s.battery = Math.max(cfg.min || 8, s.battery - (cfg.drainPerMinute || 0) / 6);
    NX.renderBattery();
  }, 10000);

  /* ── Portefeuille ─────────────────────────────────────────────── */
  NX.refreshWallet = function () {
    return NX.rpc('wallet.get').then(res => {
      if (!res.ok) return null;
      NX.state.wallet = res;
      document.getElementById('wallet-dirty').textContent = res.dirty === null || res.dirty === undefined ? '—' : NX.money(res.dirty);
      document.getElementById('wallet-clean').textContent = res.clean === null || res.clean === undefined ? '—' : NX.money(res.clean);
      const p = res.pending || {};
      const pend = document.getElementById('wallet-pending');
      const parts = [];
      if (p.clean > 0) parts.push(`${NX.money(p.clean)} propres`);
      if (p.dirty > 0) parts.push(`${NX.money(p.dirty)} sales`);
      pend.hidden = parts.length === 0;
      pend.textContent = parts.length ? `En attente : ${parts.join(' · ')}` : '';
      NX.emit('wallet', res);
      return res;
    });
  };

  /* ── Réglages ─────────────────────────────────────────────────── */
  let saveTimer = null;
  NX.applySettings = function () {
    const w = NX.state.settings.wallpaper;
    document.getElementById('wallpaper').style.backgroundImage = `url(assets/wallpaper-${w}.svg)`;
    NX.renderBattery();
  };
  NX.updateSettings = function (partial) {
    Object.assign(NX.state.settings, partial);
    NX.applySettings();
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => NX.post('saveSettings', partial), 400);
  };

  /* ── Notifications ────────────────────────────────────────────── */
  function makeToast(title, body, kind) {
    const el = document.createElement('div');
    el.className = 'toast' + (kind === 'alert' ? ' toast--alert' : kind === 'error' ? ' toast--error' : '');
    const mark = document.createElement('div'); mark.className = 'toast__mark';
    const text = document.createElement('div'); text.className = 'toast__text';
    const t = document.createElement('div'); t.className = 'toast__title'; t.textContent = title;
    const b = document.createElement('div'); b.className = 'toast__body'; b.textContent = body;
    text.append(t, b); el.append(mark, text);
    return el;
  }
  NX.notify = function (title, body, kind, ms) {
    const host = NX.state.open ? document.getElementById('toasts') : document.getElementById('peek');
    const el = makeToast(String(title || 'NOIR X'), String(body || ''), kind);
    if (!NX.state.open) el.classList.add('peek__item');
    host.prepend(el);
    while (host.children.length > 3) host.lastElementChild.remove();
    NX.sound(kind === 'alert' ? 'alert' : kind === 'error' ? 'error' : 'notify');
    setTimeout(() => {
      el.classList.add('is-leaving');
      setTimeout(() => el.remove(), 320);
    }, ms || (kind === 'alert' ? 6000 : 4200));
  };
  /** Affiche l'erreur d'une réponse RPC. */
  NX.fail = function (res) {
    NX.notify('Refusé', (res && res.message) || 'Le réseau a refusé la requête.', 'error');
  };

  /* ── Badges ───────────────────────────────────────────────────── */
  NX.badge = function (appId, n) {
    NX.state.badges[appId] = Math.max(0, n | 0);
    const el = document.querySelector(`.app[data-app="${appId}"] .app__badge`);
    if (el) {
      el.textContent = n > 9 ? '9+' : String(n);
      el.hidden = !(n > 0);
    }
  };

  /* ── Registre d'applications et navigation ────────────────────── */
  NX.registerApp = function (id, def) { NX.registry[id] = def; };

  const homeView = () => document.getElementById('view-home');
  const appView = () => document.getElementById('view-app');

  NX.renderGrid = function () {
    const grid = document.getElementById('app-grid');
    grid.textContent = '';
    NX.state.apps.forEach((app, i) => {
      const installed = !!NX.registry[app.id] && !NX.registry[app.id].pending;
      const btn = document.createElement('button');
      btn.className = 'app' + (installed ? '' : ' is-locked');
      btn.dataset.app = app.id;
      btn.style.animationDelay = `${40 + i * 28}ms`;
      const tile = document.createElement('span'); tile.className = 'app__tile';
      tile.append(NX.icon(app.id));
      const badge = document.createElement('span'); badge.className = 'app__badge'; badge.hidden = true;
      tile.append(badge);
      const label = document.createElement('span'); label.className = 'app__label'; label.textContent = app.label;
      btn.append(tile, label);
      btn.addEventListener('click', () => { NX.sound('tap'); NX.openApp(app.id); });
      grid.append(btn);
      if (NX.state.badges[app.id]) NX.badge(app.id, NX.state.badges[app.id]);
    });
  };

  NX.setTitle = function (text) {
    document.getElementById('app-title').textContent = text || '';
  };
  /** Bouton d'action en haut à droite de l'application (null pour masquer). */
  NX.setAction = function (icon, onClick) {
    const btn = document.getElementById('app-action');
    if (!icon) { btn.hidden = true; btn.onclick = null; return; }
    btn.hidden = false;
    btn.textContent = '';
    btn.append(NX.icon(icon));
    btn.onclick = () => { NX.sound('tap'); onClick(); };
  };

  NX.openApp = function (id, params) {
    const meta = NX.state.apps.find(a => a.id === id);
    if (!meta) return;
    const def = NX.registry[id] || NX.registry.__pending;
    NX.closeApp(true);
    NX.state.current = { id, def };
    NX.setTitle((def && def.title) || meta.label);
    NX.setAction(null);
    const body = document.getElementById('app-body');
    body.textContent = '';
    body.className = 'app-body';
    body.scrollTop = 0;
    if (def && def.render) def.render(body, { meta, NX, params: params || {} });
    NX.applyIcons(body);
    homeView().classList.remove('is-active');
    appView().classList.add('is-active');
  };

  NX.closeApp = function (silent) {
    const cur = NX.state.current;
    if (cur && cur.def && cur.def.destroy) { try { cur.def.destroy(); } catch (e) { /* noop */ } }
    NX.state.current = null;
    NX.ui && NX.ui.closeSheets && NX.ui.closeSheets();
    if (!silent) {
      appView().classList.remove('is-active');
      homeView().classList.add('is-active');
      NX.setAction(null);
    }
  };

  NX.currentApp = () => NX.state.current && NX.state.current.id;

  /** Retour : l'application peut intercepter (navigation interne) en renvoyant true. */
  NX.back = function () {
    if (NX.ui && NX.ui.closeTopSheet && NX.ui.closeTopSheet()) return true;
    const cur = NX.state.current;
    if (!cur) return false;
    if (cur.def && typeof cur.def.onBack === 'function' && cur.def.onBack() === true) { NX.sound('tap'); return true; }
    NX.sound('tap');
    NX.closeApp(false);
    return true;
  };

  /* ── Mise à l'échelle responsive ──────────────────────────────── */
  NX.rescale = function () {
    const s = Math.min((window.innerHeight * 0.9) / 864, (window.innerWidth * 0.9) / 410, 1.1);
    document.documentElement.style.setProperty('--scale', s.toFixed(4));
  };
  window.addEventListener('resize', NX.rescale);

  window.NX = NX;
})();
