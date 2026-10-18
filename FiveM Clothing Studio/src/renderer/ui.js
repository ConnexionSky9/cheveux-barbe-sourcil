// Petits outils d'interface : création d'éléments, notifications, fenêtres modales.

/** h('div.classe#id', { attributs, onclick }, enfants…) */
export function h(sel, attrs = {}, ...children) {
  if (typeof attrs !== 'object' || attrs === null || attrs instanceof Node || Array.isArray(attrs)) { children.unshift(attrs); attrs = {}; }
  const [, tag = 'div', rest = ''] = /^([a-z0-9-]*)(.*)$/i.exec(sel);
  const el = document.createElement(tag || 'div');
  for (const m of rest.matchAll(/([.#])([\w-]+)/g)) { if (m[1] === '.') el.classList.add(m[2]); else el.id = m[2]; }
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
    else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
    else if (k === 'dataset') Object.assign(el.dataset, v);
    else if (k in el && k !== 'list' && typeof v !== 'string') el[k] = v;
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export const $ = (s, root = document) => root.querySelector(s);

/** Remplace le contenu d'un élément (tableaux aplatis, null / false ignorés). */
export function fill(el, ...children) {
  el.replaceChildren(...children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false)
    .map((c) => (c instanceof Node ? c : document.createTextNode(String(c)))));
  return el;
}

/** Icônes SVG (trait simple, cohérentes). */
const ICONS = {
  plus: 'M12 5v14M5 12h14', folder: 'M3 7h6l2 2h10v10H3z', file: 'M6 3h9l4 4v14H6zM15 3v4h4', import: 'M12 3v12m0 0l-4-4m4 4l4-4M4 17v4h16v-4',
  export: 'M12 21V9m0 0l-4 4m4-4l4 4M4 7V3h16v4', save: 'M5 3h12l4 4v14H5zM8 3v6h8V3M8 21v-7h8v7', undo: 'M9 14L4 9l5-5M4 9h11a5 5 0 010 10h-3',
  redo: 'M15 14l5-5-5-5M20 9H9a5 5 0 000 10h3', eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 15a3 3 0 100-6 3 3 0 000 6z',
  eyeoff: 'M3 3l18 18M10.6 6.1A9 9 0 0112 6c6 0 10 6 10 6a17 17 0 01-3 3.5M6.6 6.6C3.9 8.3 2 12 2 12s4 7 10 7a9 9 0 004.4-1.1',
  trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3', copy: 'M8 8h12v12H8zM4 16V4h12', up: 'M12 19V5m0 0l-6 6m6-6l6 6', down: 'M12 5v14m0 0l-6-6m6 6l6-6',
  cube: 'M12 2l9 5v10l-9 5-9-5V7zM12 22V12M21 7l-9 5-9-5', image: 'M3 5h18v14H3zM8 11a2 2 0 100-4 2 2 0 000 4zM21 15l-5-5L5 19',
  shirt: 'M8 3l-5 3 2 5 3-1v11h8V10l3 1 2-5-5-3a4 4 0 01-8 0z', tool: 'M14 6a4 4 0 00-5 5L3 17l4 4 6-6a4 4 0 005-5l-3 3-3-1-1-3z',
  gear: 'M12 15a3 3 0 100-6 3 3 0 000 6zM19 12a7 7 0 00-.1-1.2l2-1.6-2-3.4-2.4 1a7 7 0 00-2-1.2L14 3h-4l-.5 2.6a7 7 0 00-2 1.2l-2.4-1-2 3.4 2 1.6a7 7 0 000 2.4l-2 1.6 2 3.4 2.4-1a7 7 0 002 1.2L10 21h4l.5-2.6a7 7 0 002-1.2l2.4 1 2-3.4-2-1.6c.1-.4.1-.8.1-1.2z',
  help: 'M12 21a9 9 0 100-18 9 9 0 000 18zM9.5 9a2.5 2.5 0 015 .5c0 1.5-2.5 2-2.5 3.5M12 17h.01', check: 'M5 12l5 5 9-10', warn: 'M12 3l10 18H2zM12 10v5M12 18h.01',
  x: 'M6 6l12 12M18 6L6 18', brush: 'M15 3l6 6-9 9-3-1-1-3zM6 15c-2 0-3 2-3 5 3 0 5-1 5-3', eraser: 'M16 3l5 5-11 11H5l-2-2zM9 9l6 6', move: 'M12 2v20M2 12h20M12 2l-3 3m3-3l3 3M12 22l-3-3m3 3l3-3M2 12l3-3m-3 3l3 3M22 12l-3-3m3 3l-3 3',
  crop: 'M6 2v16h16M2 6h16v16', text: 'M5 5h14M12 5v14', layers: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5', reset: 'M4 4v6h6M20 20v-6h-6M5 15a8 8 0 0014 2M19 9A8 8 0 005 7',
  grid: 'M3 3h18v18H3zM3 9h18M3 15h18M9 3v18M15 3v18', bucket: 'M5 12l7-7 7 7-7 7zM19 15s2 2.5 2 4a2 2 0 01-4 0c0-1.5 2-4 2-4', shapes: 'M3 3h8v8H3zM17 3a4 4 0 110 8 4 4 0 010-8zM7 13l4 8H3z', sphere: 'M12 21a9 9 0 100-18 9 9 0 000 18zM3 12c0 2 4 4 9 4s9-2 9-4', home: 'M3 11l9-8 9 8v10H3z', search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM21 21l-5-5', rect: 'M4 6h16v12H4z',
};
export function icon(name, size = 18) {
  const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  s.setAttribute('viewBox', '0 0 24 24'); s.setAttribute('width', size); s.setAttribute('height', size);
  s.setAttribute('fill', 'none'); s.setAttribute('stroke', 'currentColor'); s.setAttribute('stroke-width', '1.8');
  s.setAttribute('stroke-linecap', 'round'); s.setAttribute('stroke-linejoin', 'round'); s.classList.add('ico');
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  p.setAttribute('d', ICONS[name] || ICONS.file);
  s.append(p);
  return s;
}

export function btn(label, onclick, { icon: ic, kind = '', title, disabled, id } = {}) {
  return h(`button.btn${kind ? '.' + kind.split(' ').join('.') : ''}`, { onclick, title: title || undefined, disabled, id, type: 'button' }, ic ? icon(ic) : null, label ? h('span', label) : null);
}

// ------------------------------------------------------------------ notifications
export function toast(message, kind = 'info', ms = 4200) {
  let box = $('#toasts');
  if (!box) { box = h('div#toasts'); document.body.append(box); }
  const t = h(`div.toast.${kind}`, { role: 'status' }, icon(kind === 'error' ? 'warn' : kind === 'success' ? 'check' : 'help', 16), h('span', message));
  box.append(t);
  setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, ms);
}

// ------------------------------------------------------------------ fenêtres modales
export function modal({ title, body, actions = [], wide = false, onClose, closable = true }) {
  const close = () => { overlay.remove(); document.removeEventListener('keydown', key); onClose?.(); };
  const key = (e) => { if (e.key === 'Escape' && closable) close(); };
  const footer = h('div.modal-actions', actions.map((a) => btn(a.label, async () => { const keep = await a.onclick?.(close); if (keep !== true && !a.keepOpen) close(); }, { kind: a.kind, icon: a.icon, disabled: a.disabled, id: a.id })));
  const overlay = h('div.overlay', h(`div.modal${wide ? '.wide' : ''}`, { role: 'dialog', 'aria-modal': 'true', 'aria-label': title },
    h('div.modal-head', h('h2', title), closable ? h('button.icon-btn', { onclick: close, title: 'Fermer', type: 'button' }, icon('x')) : null),
    h('div.modal-body', body), actions.length ? footer : null));
  document.body.append(overlay);
  document.addEventListener('keydown', key);
  setTimeout(() => overlay.querySelector('input, select, button.primary')?.focus(), 30);
  return { close, overlay, footer };
}

/** Demande un texte (renvoie null si annulé). */
export function prompt(title, { label, value = '', placeholder = '', ok = 'Valider', help } = {}) {
  return new Promise((resolve) => {
    let done = false;
    const input = h('input.input', { value, placeholder, onkeydown: (e) => { if (e.key === 'Enter') { done = true; resolve(input.value.trim()); m.close(); } } });
    const m = modal({ title, body: h('div.form', h('label.field', h('span', label || title), input), help ? h('p.help', help) : null),
      actions: [{ label: 'Annuler' }, { label: ok, kind: 'primary', onclick: () => { done = true; resolve(input.value.trim()); } }],
      onClose: () => { if (!done) resolve(null); } });
  });
}

export function confirmBox(title, message, { ok = 'Confirmer', danger = false } = {}) {
  return new Promise((resolve) => {
    let done = false;
    modal({ title, body: h('p', message), actions: [{ label: 'Annuler' }, { label: ok, kind: danger ? 'danger' : 'primary', onclick: () => { done = true; resolve(true); } }],
      onClose: () => { if (!done) resolve(false); } });
  });
}

export function issueList(issues) {
  if (!issues?.length) return h('p.muted', 'Aucun problème détecté.');
  const order = { error: 0, warning: 1, info: 2 };
  const label = { error: 'Erreur bloquante', warning: 'Avertissement', info: 'Information' };
  return h('ul.issues', [...issues].sort((a, b) => order[a.level] - order[b.level]).map((i) =>
    h(`li.issue.${i.level}`, h('span.badge', label[i.level] || i.level), h('span', i.message))));
}

export const fmtBytes = (n) => (n < 1024 ? `${n} o` : n < 1048576 ? `${(n / 1024).toFixed(0)} Ko` : `${(n / 1048576).toFixed(1)} Mo`);
export const fmtDate = (s) => (s ? new Date(s).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) : '');

/** Champ de formulaire avec libellé et aide. */
export function field(label, input, help) {
  return h('label.field', h('span', label), input, help ? h('small.help', help) : null);
}
export function select(options, value, onchange, attrs = {}) {
  return h('select.input', { onchange: (e) => onchange(e.target.value), ...attrs },
    options.map((o) => h('option', { value: o.value, selected: String(o.value) === String(value) }, o.label)));
}
