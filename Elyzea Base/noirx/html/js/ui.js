/* NOIR X — composants d'interface partagés par les applications. */
(function () {
  'use strict';
  const ui = {};

  /** Mini constructeur d'éléments : h('div', { class, text, on: { click }, attrs }, ...enfants) */
  function h(tag, opts, ...children) {
    const el = document.createElement(tag);
    if (opts) {
      if (opts.class) el.className = opts.class;
      if (opts.text !== undefined) el.textContent = opts.text;
      if (opts.html) throw new Error('html interdit : utiliser text');
      if (opts.attrs) for (const [k, v] of Object.entries(opts.attrs)) { if (v !== undefined && v !== null && v !== false) el.setAttribute(k, v === true ? '' : v); }
      if (opts.style) Object.assign(el.style, opts.style);
      if (opts.dataset) Object.assign(el.dataset, opts.dataset);
      if (opts.on) for (const [k, fn] of Object.entries(opts.on)) el.addEventListener(k, fn);
    }
    for (const c of children.flat()) {
      if (c === null || c === undefined || c === false) continue;
      el.append(c instanceof Node ? c : document.createTextNode(String(c)));
    }
    return el;
  }
  NX.h = h;

  /* ── Temps ───────────────────────────────────────────────────── */
  ui.ago = function (ts) {
    if (!ts) return '';
    const d = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (d < 60) return 'à l\'instant';
    if (d < 3600) return `${Math.floor(d / 60)} min`;
    if (d < 86400) return `${Math.floor(d / 3600)} h`;
    const dt = new Date(ts * 1000);
    return `${String(dt.getDate()).padStart(2, '0')}/${String(dt.getMonth() + 1).padStart(2, '0')}`;
  };
  ui.clock = function (ts) {
    const dt = new Date(ts * 1000);
    return `${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}`;
  };
  ui.duration = function (sec) {
    sec = Math.max(0, Math.round(sec));
    if (sec < 60) return `${sec} s`;
    if (sec < 3600) { const m = Math.floor(sec / 60), s = sec % 60; return s ? `${m} min ${String(s).padStart(2, '0')}` : `${m} min`; }
    if (sec < 86400) { const hh = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60); return m ? `${hh} h ${String(m).padStart(2, '0')}` : `${hh} h`; }
    const d = Math.floor(sec / 86400); return `${d} j`;
  };
  ui.ephemeralLabel = function (sec) {
    if (!sec) return 'Désactivés';
    return ui.duration(sec);
  };

  /* ── Avatars (initiales, teintes sobres) ─────────────────────── */
  ui.avatar = function (name, opts) {
    const n = String(name || '?');
    let hash = 0;
    for (let i = 0; i < n.length; i++) hash = (hash * 31 + n.charCodeAt(i)) | 0;
    const shades = ['#1c1c22', '#22181b', '#1a1d22', '#201c18', '#1b2020'];
    const initials = n.replace(/[^a-zA-Z0-9]/g, ' ').trim().split(/\s+/).map(w => w[0]).join('').slice(0, 2).toUpperCase() || n[0].toUpperCase();
    return h('span', { class: 'avatar' + (opts && opts.npc ? ' avatar--npc' : '') + (opts && opts.small ? ' avatar--sm' : ''), style: { background: shades[Math.abs(hash) % shades.length] }, text: initials });
  };

  /* ── États ───────────────────────────────────────────────────── */
  ui.empty = function (icon, title, text, action) {
    return h('div', { class: 'empty' },
      NX.icon(icon, 'empty__icon'),
      h('div', { class: 'empty__title', text: title }),
      text ? h('div', { class: 'empty__text', text }) : null,
      action ? h('button', { class: 'btn btn--primary', text: action.label, on: { click: action.onClick } }) : null);
  };
  ui.loader = function () {
    return h('div', { class: 'loader' }, h('span'), h('span'), h('span'));
  };
  ui.label = function (text) { return h('div', { class: 'section-label', text }); };

  ui.button = function (label, kind, onClick, icon) {
    return h('button', { class: `btn btn--${kind || 'ghost'}`, on: { click: (e) => { NX.sound('tap'); onClick && onClick(e); } } },
      icon ? NX.icon(icon) : null, label ? h('span', { text: label }) : null);
  };

  /** Rangée de liste cliquable. */
  ui.row = function ({ lead, title, sub, meta, badge, onClick, cls }) {
    return h('button', { class: 'lrow' + (cls ? ' ' + cls : ''), on: { click: () => { NX.sound('tap'); onClick && onClick(); } } },
      lead || null,
      h('span', { class: 'lrow__main' },
        h('span', { class: 'lrow__title', text: title }),
        sub ? h('span', { class: 'lrow__sub', text: sub }) : null),
      h('span', { class: 'lrow__side' },
        meta ? h('span', { class: 'lrow__meta', text: meta }) : null,
        badge ? h('span', { class: 'pill-badge', text: badge > 9 ? '9+' : String(badge) }) : null));
  };

  ui.tabs = function (items, active, onChange) {
    const wrap = h('div', { class: 'tabs' });
    items.forEach(([id, label]) => {
      const b = h('button', { class: 'tabs__item' + (id === active ? ' is-active' : ''), text: label, on: { click: () => {
        if (b.classList.contains('is-active')) return;
        NX.sound('tap');
        wrap.querySelectorAll('.tabs__item').forEach(x => x.classList.remove('is-active'));
        b.classList.add('is-active');
        onChange(id);
      } } });
      wrap.append(b);
    });
    return wrap;
  };

  ui.chips = function (items, active, onChange) {
    const wrap = h('div', { class: 'chips' });
    items.forEach(([value, label]) => {
      const b = h('button', { class: 'chip' + (value === active ? ' is-active' : ''), text: label, on: { click: () => {
        NX.sound('tap');
        wrap.querySelectorAll('.chip').forEach(x => x.classList.remove('is-active'));
        b.classList.add('is-active');
        onChange(value);
      } } });
      wrap.append(b);
    });
    return wrap;
  };

  ui.input = function ({ placeholder, value, maxLength, type, onEnter }) {
    const el = h('input', { class: 'field', attrs: { type: type || 'text', placeholder: placeholder || '', maxlength: maxLength || 120, spellcheck: 'false', autocomplete: 'off' } });
    if (value !== undefined) el.value = value;
    if (onEnter) el.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); onEnter(el.value); } });
    return el;
  };

  /* ── Feuilles modales ────────────────────────────────────────── */
  const sheets = [];
  ui.sheet = function ({ title, content, actions, onClose }) {
    const host = document.getElementById('sheet-host');
    const scrim = h('div', { class: 'sheet-scrim' });
    const panel = h('div', { class: 'sheet' },
      h('div', { class: 'sheet__grip' }),
      title ? h('div', { class: 'sheet__title', text: title }) : null,
      h('div', { class: 'sheet__content' }, content || null));
    const record = { scrim, panel, onClose };
    function close() {
      const i = sheets.indexOf(record);
      if (i === -1) return;
      sheets.splice(i, 1);
      panel.classList.add('is-leaving');
      scrim.classList.add('is-leaving');
      setTimeout(() => { panel.remove(); scrim.remove(); }, 260);
      onClose && onClose();
    }
    record.close = close;
    if (actions && actions.length) {
      const bar = h('div', { class: 'sheet__actions' });
      actions.forEach(a => bar.append(ui.button(a.label, a.kind || 'ghost', () => {
        const keep = a.onClick && a.onClick(close) === false;
        if (!keep && !a.manual) close();
      }, a.icon)));
      panel.append(bar);
    }
    scrim.addEventListener('click', close);
    host.append(scrim, panel);
    sheets.push(record);
    NX.applyIcons(panel);
    const first = panel.querySelector('input, textarea');
    if (first) setTimeout(() => first.focus(), 60);
    return close;
  };
  ui.closeTopSheet = function () {
    const top = sheets[sheets.length - 1];
    if (!top) return false;
    top.close();
    return true;
  };
  ui.closeSheets = function () { while (sheets.length) sheets[sheets.length - 1].close(); };

  ui.confirm = function (title, text, confirmLabel, danger) {
    return new Promise(resolve => {
      let answered = false;
      ui.sheet({
        title,
        content: text ? h('p', { class: 'sheet__text', text }) : null,
        actions: [
          { label: 'Annuler', kind: 'ghost', onClick: () => { answered = true; resolve(false); } },
          { label: confirmLabel || 'Confirmer', kind: danger ? 'danger' : 'primary', onClick: () => { answered = true; resolve(true); } },
        ],
        onClose: () => { if (!answered) resolve(false); },
      });
    });
  };

  ui.prompt = function (title, { placeholder, value, maxLength, hint, confirmLabel } = {}) {
    return new Promise(resolve => {
      let answered = false;
      const input = ui.input({ placeholder, value, maxLength });
      const content = h('div', {}, input, hint ? h('div', { class: 'hint', text: hint }) : null);
      const close = ui.sheet({
        title, content,
        actions: [
          { label: 'Annuler', kind: 'ghost', onClick: () => { answered = true; resolve(null); } },
          { label: confirmLabel || 'Valider', kind: 'primary', onClick: () => { answered = true; resolve(input.value.trim()); } },
        ],
        onClose: () => { if (!answered) resolve(null); },
      });
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); answered = true; resolve(input.value.trim()); close(); }
      });
    });
  };

  /* ── Pile de vues internes à une application ─────────────────── */
  /** const stack = NX.ui.stack(body, 'Titre racine');  stack.push(title, render, { flush })  stack.pop() */
  ui.stack = function (body, rootTitle) {
    const views = [];
    function show(v) {
      body.textContent = '';
      body.className = 'app-body' + (v.flush ? ' is-flush' : '');
      body.scrollTop = 0;
      NX.setTitle(v.title);
      NX.setAction(null);
      if (v.cleanup) { try { v.cleanup(); } catch (e) { /* noop */ } v.cleanup = null; }
      const r = v.render(body, v);
      if (typeof r === 'function') v.cleanup = r;
      NX.applyIcons(body);
    }
    const api = {
      push(title, render, opts) {
        const top = views[views.length - 1];
        if (top && top.cleanup) { try { top.cleanup(); } catch (e) { /* noop */ } top.cleanup = null; }
        const v = { title, render, flush: opts && opts.flush };
        views.push(v);
        show(v);
        return v;
      },
      pop() {
        if (views.length <= 1) return false;
        const v = views.pop();
        if (v.cleanup) { try { v.cleanup(); } catch (e) { /* noop */ } }
        show(views[views.length - 1]);
        return true;
      },
      refresh() { const v = views[views.length - 1]; if (v) show(v); },
      depth: () => views.length,
      top: () => views[views.length - 1],
      destroy() { views.forEach(v => v.cleanup && v.cleanup()); views.length = 0; },
    };
    return api;
  };

  NX.ui = ui;
})();
