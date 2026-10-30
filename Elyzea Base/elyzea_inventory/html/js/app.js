/* ELYZEA FA — Inventaire (NUI)
 * La NUI n'a aucune autorité : elle affiche l'état envoyé par le serveur et
 * transmet des intentions. Seuls les déplacements simples sont prédits
 * localement pour la fluidité ; l'état serveur suivant fait foi. */
(() => {
  'use strict';

  const IS_FIVEM = typeof window.GetParentResourceName === 'function';
  const RES = IS_FIVEM ? window.GetParentResourceName() : 'elyzea_inventory';
  const $ = (s, r = document) => r.querySelector(s);

  const app = $('#app');
  const gridEl = $('#grid');
  const hotbarEl = $('#hotbar');
  const hud = $('#hud-hotbar');
  const groundGrid = $('#ground-grid');
  const groundPanel = $('#drop-zone');
  const containerGrid = $('#container-grid');
  const containerPanel = $('#container-zone');
  const leftCol = $('#equip-left');
  const rightCol = $('#equip-right');
  const charEl = $('#character');
  const ghost = $('#ghost');
  const tip = $('#tooltip');
  const toasts = $('#toasts');
  const qtyEl = $('#qty');
  const weightBox = $('#weight');
  const wFill = $('#w-fill');
  const wPrev = $('#w-preview');

  const state = { open: false, data: null, equipSlots: [], slotEls: [], equipEls: {}, built: false, lastCap: null };
  // Onglet et recherche : seulement l'affichage (les cases gardent leur numéro, rien n'est déplacé)
  const view = { cat: 'all', q: '' };
  const tabsEl = $('#tabs');
  const searchEl = $('#search');
  const emptyEl = $('#grid-empty');
  const CAT_LABEL = { weapons: 'arme ni munition', food: 'nourriture', papers: 'papier' };
  const walletEl = $('#wallet');
  const cashForm = $('#cash-form');
  const cashAmount = $('#cash-amount');
  const money = n => `${Math.floor(Number(n) || 0).toLocaleString('fr-FR').replace(/\u202f|\u00a0/g, ' ')} $`;
  // Objets reçus depuis la dernière ouverture : mis en évidence à la prochaine ouverture
  let fresh = new Set();
  const sig = it => `${it.name}|${it.count}`;
  function noteFresh(prev, next) {
    if (!prev || !next) return;
    const before = {};
    (prev.items || []).forEach(it => { before[it.slot] = it; });
    (next.items || []).forEach(it => {
      const b = before[it.slot];
      if (!b || b.name !== it.name || it.count > b.count) fresh.add(it.slot);
    });
  }
  function renderWallet(m) {
    walletEl.hidden = !m;
    if (!m) return;
    $('#cash').textContent = money(m.cash);
    $('#bank').textContent = money(m.bank);
    $('#cash-give').disabled = !(m.cash > 0);
  }
  const norm = s => String(s || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

  const fmt = n => (Math.round(n * 10) / 10).toFixed(1);
  const fmt2 = n => (Math.round(n * 100) / 100).toFixed(2);
  // Petits poids (vêtements à 10 g) affichés en grammes pour rester exacts
  const fmtW = kg => (kg > 0 && kg < 0.1 ? `${Math.round(kg * 1000)} g` : fmt(kg));
  const fmtCap = n => (Number.isInteger(n) ? String(n) : fmt(n));
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  function post(name, body = {}) {
    if (!IS_FIVEM) return Promise.resolve(Mock.handle(name, body));
    return fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body),
    }).catch(() => {});
  }

  const action = (type, payload) => post('action', Object.assign({ type }, payload));

  // ───────── Construction ─────────

  function buildGrid(n, hotbar) {
    if (state.slotEls.length === n) return;
    gridEl.textContent = '';
    hotbarEl.textContent = '';
    state.slotEls = [];
    const frag = document.createDocumentFragment();
    for (let i = 1; i <= n; i++) {
      const el = document.createElement('div');
      el.className = 'slot';
      el.dataset.drop = 'inv';
      el.dataset.slot = i;
      el._sig = '';
      el._item = null;
      if (i <= hotbar) { el.dataset.key = i; hotbarEl.appendChild(el); }
      else frag.appendChild(el);
      state.slotEls.push(el);
    }
    gridEl.appendChild(frag);
  }

  function buildEquip(slots) {
    if (state.built || !slots.length) return;
    state.built = true;
    slots.forEach(s => {
      const el = document.createElement('div');
      el.className = 'eslot';
      el.dataset.drop = 'equip';
      el.dataset.slot = s.name;
      el.innerHTML = `<div class="ebox"><span class="eicon">${esc(s.icon)}</span><div class="ecell"></div></div><span class="elabel">${esc(s.label)}</span>`;
      el._sig = '';
      el._item = null;
      el._label = s.label;
      (s.side === 'right' ? rightCol : leftCol).appendChild(el);
      state.equipEls[s.name] = el;
    });
  }

  // ───────── Rendu (différentiel : on ne touche qu'aux cases modifiées) ─────────

  // Icône : html/img/<image>, puis le dossier d'images d'ox_inventory (s'il est installé), puis l'emoji
  function iconHTML(it) {
    const fb = esc(it.icon || '📦');
    if (it.imageUrl) return `<img class="icon" src="${esc(it.imageUrl)}" alt="" draggable="false" data-fallback="${fb}">`;
    if (it.image) {
      const alt = state.data && state.data.imageAlt ? `${state.data.imageAlt}${encodeURI(it.image)}` : '';
      return `<img class="icon" src="img/${encodeURI(it.image)}" alt="" draggable="false" data-alt="${esc(alt)}" data-fallback="${fb}">`;
    }
    return `<span class="icon">${fb}</span>`;
  }

  function itemHTML(it) {
    const count = it.count > 1 ? `<span class="count">×${it.count}</span>` : '';
    const price = it.price != null ? `<span class="price">${it.price > 0 ? it.price + ' $' : 'Gratuit'}</span>` : '';
    return `<div class="item" data-drag="1">${iconHTML(it)}${count}${price}<span class="w">${fmtW(it.weight * it.count)}</span><span class="name">${esc(it.label)}</span></div>`;
  }

  function bindImg(root) {
    root.querySelectorAll('img.icon').forEach(img => img.addEventListener('error', function onErr() {
      if (img.dataset.alt) { const a = img.dataset.alt; img.dataset.alt = ''; img.src = a; return; }
      img.removeEventListener('error', onErr);
      const s = document.createElement('span');
      s.className = 'icon';
      s.textContent = img.dataset.fallback;
      img.replaceWith(s);
    }));
  }

  const sigOf = it => (it ? `${it.name}|${it.count}|${it.label}|${it.imageUrl || it.image || ''}|${it.category || ''}` : '');

  function setSlot(el, it) {
    el._item = it || null;
    const sig = sigOf(it);
    if (el._sig === sig) return;
    el._sig = sig;
    el.classList.toggle('has', !!it);
    el.dataset.cat = it ? (it.category || 'other') : '';
    el.innerHTML = it ? itemHTML(it) : '';
    if (it) { bindImg(el); el.firstChild.classList.add('pop'); }
  }

  // ───────── Onglets et recherche ─────────
  // Un objet correspond-il à l'onglet et à la recherche ?
  const matches = it => it && (view.cat === 'all' || it.category === view.cat) && (!view.q || norm(it.label).includes(view.q) || norm(it.name).includes(view.q));
  function applyFilter() {
    const d = state.data;
    if (!d) return;
    const items = d.items || [];
    const n = { all: items.length, weapons: 0, food: 0, papers: 0 };
    items.forEach(it => { if (n[it.category] !== undefined) n[it.category] += 1; });
    tabsEl.querySelectorAll('[data-n]').forEach(i => { i.textContent = n[i.dataset.n]; });
    const active = view.cat !== 'all' || !!view.q;
    const hot = d.hotbar || 5;
    let shownCount = 0;
    state.slotEls.forEach((el, i) => {
      const ok = matches(el._item);
      if (ok) shownCount += 1;
      if (i < hot) { el.classList.toggle('dim', active && !!el._item && !ok); return; }   // raccourcis toujours visibles
      el.classList.toggle('fx-hide', active && !ok);
    });
    gridEl.classList.toggle('filtered', active);
    emptyEl.hidden = !active || shownCount > 0;
    if (active && !shownCount) emptyEl.textContent = view.q ? `Aucun objet ne correspond à « ${searchEl.value.trim()} ».` : `Tu n'as aucun${view.cat === 'food' ? 'e' : ''} ${CAT_LABEL[view.cat] || 'objet'} sur toi.`;
  }
  function setCat(cat) {
    view.cat = cat;
    tabsEl.querySelectorAll('[data-cat]').forEach(b => { const on = b.dataset.cat === cat; b.classList.toggle('on', on); b.setAttribute('aria-selected', String(on)); });
    gridEl.scrollTop = 0;
    applyFilter();
  }
  tabsEl.addEventListener('click', e => { const b = e.target.closest('[data-cat]'); if (b) setCat(b.dataset.cat); });
  let searchT = 0;
  searchEl.addEventListener('input', () => {
    $('#search-clear').hidden = !searchEl.value;
    clearTimeout(searchT);
    searchT = setTimeout(() => { view.q = norm(searchEl.value.trim()); applyFilter(); }, 90);
  });
  $('#search-clear').addEventListener('click', () => { searchEl.value = ''; $('#search-clear').hidden = true; view.q = ''; applyFilter(); searchEl.focus(); });

  function setEquip(el, it) {
    el._item = it || null;
    const sig = sigOf(it);
    if (el._sig === sig) return;
    el._sig = sig;
    el.classList.toggle('filled', !!it);
    const cell = el.querySelector('.ecell');
    cell.innerHTML = it ? itemHTML(it) : '';
    if (it) { bindImg(cell); cell.firstChild.classList.add('pop'); }
  }

  function renderGround(g) {
    const items = g ? g.items || [] : [];
    groundPanel.classList.toggle('has-items', items.length > 0);
    $('#ground-count').textContent = items.length ? `${items.length} objet${items.length > 1 ? 's' : ''}` : '';
    const sig = (g ? g.id : '') + JSON.stringify(items.map(i => [i.name, i.count, i.label]));
    if (groundGrid._sig !== sig) {
      groundGrid._sig = sig;
      groundGrid.textContent = '';
      items.forEach(it => {
        const el = document.createElement('div');
        el.className = 'slot has';
        el.dataset.area = 'ground';
        el.dataset.index = it.slot;
        el.innerHTML = itemHTML(it);
        bindImg(el);
        groundGrid.appendChild(el);
      });
    }
    [...groundGrid.children].forEach((el, i) => { el._item = items[i]; });
  }

  // Second inventaire : coffre, boutique ou joueur fouillé
  function renderContainer(c) {
    containerPanel.classList.toggle('open', !!c);
    if (!c) { containerGrid._sig = ''; containerGrid.textContent = ''; return; }
    const shop = c.kind === 'shop';
    containerPanel.classList.toggle('shop', shop);
    $('#container-title').textContent = c.label || 'Coffre';
    const items = c.items || [];
    $('#container-count').textContent = shop ? `${items.length} article${items.length > 1 ? 's' : ''}` : `${items.length} / ${c.size}`;
    if (!shop && c.capacity) {
      const pct = Math.min(1, c.weight / c.capacity);
      $('#c-fill').style.transform = `scaleX(${pct})`;
      $('#c-text').textContent = `${fmt2(c.weight)} / ${fmtCap(c.capacity)} KG`;
    }
    const size = shop ? items.length : c.size;
    const sig = `${c.kind}|${c.id}|${size}|` + JSON.stringify(items.map(i => [i.slot, i.name, i.count, i.label, i.price]));
    if (containerGrid._sig === sig) return;
    containerGrid._sig = sig;
    containerGrid.textContent = '';
    const bySlot = {};
    items.forEach(it => { bySlot[it.slot] = it; });
    for (let i = 1; i <= size; i++) {
      const it = bySlot[i];
      const el = document.createElement('div');
      el.className = 'slot' + (it ? ' has' : ' empty-c');
      el.dataset.area = 'container';
      el.dataset.drop = 'container';
      el.dataset.slot = i;
      el._item = it || null;
      if (it) { el.innerHTML = itemHTML(it); bindImg(el); }
      containerGrid.appendChild(el);
    }
  }

  let shown = 0, tweenRaf = 0;
  function tweenWeight(target) {
    cancelAnimationFrame(tweenRaf);
    const from = shown, t0 = performance.now(), cur = $('#w-cur');
    const step = now => {
      const k = Math.min(1, (now - t0) / 380);
      shown = from + (target - from) * (1 - Math.pow(1 - k, 3));
      cur.textContent = fmt2(shown);
      if (k < 1) tweenRaf = requestAnimationFrame(step);
    };
    tweenRaf = requestAnimationFrame(step);
  }

  function renderWeight(d) {
    const cap = d.capacity, w = d.weight;
    const pct = cap > 0 ? Math.min(1, w / cap) : 0;
    wFill.style.transform = `scaleX(${pct})`;
    weightBox.classList.toggle('warn', pct >= 0.75 && pct < 0.9);
    weightBox.classList.toggle('danger', pct >= 0.9);
    weightBox.classList.toggle('has-bag', !!d.bag);
    $('#w-max').textContent = fmtCap(cap);
    $('#w-cap').textContent = `${fmtCap(cap)} KG`;
    $('#bag-bonus').textContent = `+${fmtCap(cap - d.baseCapacity)} KG`;
    $('#w-free').textContent = `${fmt2(Math.max(0, cap - w))} KG libres`;
    tweenWeight(w);

    if (state.lastCap !== null && state.lastCap !== cap) {
      weightBox.classList.remove('cap-bump');
      void weightBox.offsetWidth;
      weightBox.classList.add('cap-bump');
    }
    state.lastCap = cap;
  }

  function render() {
    const d = state.data;
    if (!d) return;
    buildGrid(d.slots, d.hotbar || 5);
    const bySlot = {};
    (d.items || []).forEach(it => { bySlot[it.slot] = it; });
    state.slotEls.forEach((el, i) => setSlot(el, bySlot[i + 1]));
    $('#slot-count').textContent = `${(d.items || []).length} / ${d.slots}`;
    const eq = d.equipment && !Array.isArray(d.equipment) ? d.equipment : {};
    for (const name in state.equipEls) setEquip(state.equipEls[name], eq[name]);
    renderGround(d.ground);
    renderContainer(d.container);
    renderWeight(d);
    renderWallet(d.money);
    applyFilter();
  }

  // ───────── Mini barre de raccourcis (inventaire fermé) ─────────

  let hudTimer = 0;
  function showHud(index, data) {
    if (state.open || !data) return;
    const n = data.hotbar || 5;
    const bySlot = {};
    (data.items || []).forEach(it => { bySlot[it.slot] = it; });
    hud.textContent = '';
    for (let i = 1; i <= n; i++) {
      const el = document.createElement('div');
      el.className = 'slot' + (bySlot[i] ? ' has' : '') + (i === index ? ' active' : '');
      el.dataset.key = i;
      if (bySlot[i]) { el.innerHTML = itemHTML(bySlot[i]); bindImg(el); }
      hud.appendChild(el);
    }
    hud.classList.add('show');
    clearTimeout(hudTimer);
    hudTimer = setTimeout(() => hud.classList.remove('show'), 2200);
  }

  // ───────── Prédiction locale (déplacement dans la grille uniquement) ─────────

  function predictMove(from, to, count) {
    const items = state.data.items;
    const a = items.find(i => i.slot === from);
    if (!a) return;
    const b = items.find(i => i.slot === to);
    if (!b) {
      if (count >= a.count) a.slot = to;
      else { items.push(Object.assign({}, a, { slot: to, count })); a.count -= count; }
    } else if (b.name === a.name && a.stack && a.plain && b.plain) {
      const add = Math.min(count, b.max - b.count);
      if (add <= 0) return;
      b.count += add; a.count -= add;
      if (a.count <= 0) items.splice(items.indexOf(a), 1);
    } else {
      a.slot = to; b.slot = from;
    }
    render();
  }

  // ───────── Notifications ─────────

  function toast(type, text) {
    const el = document.createElement('div');
    el.className = `toast ${type || ''}`;
    el.textContent = text;
    toasts.appendChild(el);
    while (toasts.children.length > 3) toasts.firstChild.remove();
    requestAnimationFrame(() => el.classList.add('in'));
    setTimeout(() => {
      el.classList.remove('in');
      setTimeout(() => el.remove(), 250);
    }, 2800);
    if (type === 'error' && /poids|KG/i.test(text)) {
      weightBox.classList.remove('denied');
      void weightBox.offsetWidth;
      weightBox.classList.add('denied');
    }
  }

  // ───────── Infobulle ─────────

  let mx = 0, my = 0, tipItem = null;

  function showTip(it, area) {
    tipItem = it;
    const total = it.weight * it.count;
    const rows = [
      `<dt>Poids</dt><dd>${it.weight < 0.1 ? fmtW(it.weight) : fmt(it.weight) + ' KG'}${it.count > 1 ? ` · ${fmtW(total)}${total < 0.1 ? '' : ' KG'}` : ''}</dd>`,
      it.count > 1 ? `<dt>Quantité</dt><dd>${it.count}</dd>` : '',
      it.equip && state.equipEls[it.equip] ? `<dt>Emplacement</dt><dd>${esc(state.equipEls[it.equip]._label)}</dd>` : '',
      it.bonus ? `<dt>Capacité</dt><dd class="bonus">+${fmtCap(it.bonus)} KG</dd>` : '',
    ].join('');
    let hint = '';
    if (area === 'inv' && it.equip) hint = 'Glissez sur le personnage ou double-cliquez pour équiper.';
    else if (area === 'inv') hint = it.slot <= (state.data.hotbar || 5) ? `Clic droit pour utiliser · touche ${it.slot}.` : 'Clic droit pour utiliser.';
    else if (area === 'equip') hint = 'Double-cliquez ou glissez vers l\'inventaire pour ranger.';
    else if (area === 'ground') hint = 'Glissez vers l\'inventaire pour ramasser.';
    else if (area === 'container' && it.price != null) hint = `Glissez vers l'inventaire pour acheter${it.price > 0 ? ` (${it.price} $ l'unité)` : ''}.`;
    else if (area === 'container') hint = 'Glissez vers l\'inventaire pour prendre.';
    tip.innerHTML = `<h3>${esc(it.label)}</h3>${it.description ? `<p>${esc(it.description)}</p>` : ''}<dl>${rows}</dl>${hint ? `<p class="hint">${hint}</p>` : ''}`;
    tip.classList.add('show');
    placeTip();
  }

  function placeTip() {
    if (!tipItem) return;
    const w = tip.offsetWidth, h = tip.offsetHeight;
    let x = mx + 18, y = my + 18;
    if (x + w > innerWidth - 8) x = mx - w - 18;
    if (y + h > innerHeight - 8) y = innerHeight - h - 8;
    tip.style.transform = `translate3d(${x}px, ${y}px, 0)`;
  }

  function hideTip() {
    tipItem = null;
    tip.classList.remove('show');
  }

  // ───────── Drag & drop (événements pointer + rAF : aucun reflow pendant le glisser) ─────────

  let pend = null, drag = null, raf = 0, hoverEl = null, rot = null, rotAcc = 0, rotTimer = 0;

  function sourceOf(node) {
    const el = node.closest('.slot, .eslot');
    if (!el || !el._item) return null;
    if (el.classList.contains('eslot')) return { area: 'equip', slot: el.dataset.slot, item: el._item, el };
    if (el.dataset.area === 'ground') return { area: 'ground', slot: +el.dataset.index, item: el._item, el };
    if (el.dataset.area === 'container') return { area: 'container', slot: +el.dataset.slot, item: el._item, el };
    return { area: 'inv', slot: +el.dataset.slot, item: el._item, el };
  }

  function targetAt(x, y) {
    const n = document.elementFromPoint(x, y);
    const t = n && n.closest('[data-drop]');
    if (!t) return null;
    const area = t.dataset.drop;
    if (area === 'container') return { area, slot: t.dataset.slot ? +t.dataset.slot : null, el: t };
    return { area, slot: area === 'inv' ? +t.dataset.slot : t.dataset.slot, el: t };
  }

  function isValid(src, t) {
    if (!t) return false;
    const it = src.item;
    switch (src.area) {
      case 'inv':
        if (t.area === 'inv') return t.slot !== src.slot;
        if (t.area === 'equip') return it.equip === t.slot;
        if (t.area === 'character') return !!it.equip;
        if (t.area === 'container') return !isShop();
        return t.area === 'ground';
      case 'equip':
        return t.area === 'inv';
      case 'ground':
        return t.area === 'inv';
      case 'container':
        if (t.area === 'inv') return true;
        return t.area === 'container' && !isShop() && t.slot && t.slot !== src.slot;
    }
    return false;
  }

  const isShop = () => !!(state.data && state.data.container && state.data.container.kind === 'shop');

  function dragCount(it, e, src) {
    if (src && src.area === 'container' && isShop()) {
      const q = parseInt(qtyEl.value, 10) || 0;
      return q > 0 ? q : 1;
    }
    if (e && e.ctrlKey) return 1;
    if (e && e.shiftKey) return Math.max(1, Math.floor(it.count / 2));
    const q = parseInt(qtyEl.value, 10) || 0;
    return q > 0 ? Math.min(q, it.count) : it.count;
  }

  function previewWeight(add) {
    const d = state.data;
    if (!d || add <= 0) return wPrev.classList.remove('show');
    const left = Math.min(1, d.weight / d.capacity);
    const width = Math.max(0, Math.min(1 - left, add / d.capacity));
    wPrev.style.left = `${left * 100}%`;
    wPrev.style.width = `${Math.max(width * 100, 1)}%`;
    wPrev.classList.toggle('over', d.weight + add > d.capacity + 1e-4);
    wPrev.classList.add('show');
  }

  function startDrag(src) {
    drag = { src };
    const r = src.el.querySelector('.ebox, .item').getBoundingClientRect();
    drag.ox = r.width / 2;
    drag.oy = r.height / 2;
    ghost.style.width = `${r.width}px`;
    ghost.style.height = `${r.height}px`;
    ghost.innerHTML = itemHTML(src.item);
    bindImg(ghost);
    ghost.classList.add('show');
    src.el.classList.add('drag-src');
    document.body.classList.add('is-dragging');
    hideTip();

    if (src.area === 'inv' && src.item.equip) {
      const target = state.equipEls[src.item.equip];
      if (target) target.classList.add('target-ok');
      charEl.classList.add('target-ok');
    }
    if (src.area === 'ground') previewWeight(src.item.weight * dragCount(src.item));
    if (src.area === 'equip') previewWeight(src.item.weight);
    frame();
  }

  function setHover(t) {
    const el = t ? t.el : null;
    if (el === hoverEl) return;
    if (hoverEl) hoverEl.classList.remove('hover', 'hover-bad');
    hoverEl = el;
    if (el) el.classList.add(isValid(drag.src, t) ? 'hover' : 'hover-bad');
  }

  function frame() {
    raf = 0;
    if (!drag) return;
    ghost.style.transform = `translate3d(${mx - drag.ox}px, ${my - drag.oy}px, 0) scale(1.06)`;
    setHover(targetAt(mx, my));
  }

  function cleanupDrag() {
    if (!drag) return;
    drag.src.el.classList.remove('drag-src');
    if (hoverEl) hoverEl.classList.remove('hover', 'hover-bad');
    hoverEl = null;
    document.querySelectorAll('.target-ok').forEach(el => el.classList.remove('target-ok'));
    document.body.classList.remove('is-dragging');
    ghost.classList.remove('show');
    wPrev.classList.remove('show');
    drag = null;
  }

  function dispatch(src, t, count) {
    const it = src.item;
    if (src.area === 'inv') {
      if (t.area === 'inv' && t.slot !== src.slot) {
        predictMove(src.slot, t.slot, count);
        action('move', { from: src.slot, to: t.slot, count });
      } else if (t.area === 'equip') {
        if (it.equip === t.slot) post('equipClothing', { slot: src.slot });
        else toast('error', 'Cet objet ne va pas dans cet emplacement.');
      } else if (t.area === 'character') {
        if (it.equip) post('equipClothing', { slot: src.slot });
        else toast('error', 'Seuls les vêtements peuvent être portés.');
      } else if (t.area === 'ground') {
        action('drop', { from: src.slot, count });
      } else if (t.area === 'container') {
        action('store', { from: src.slot, count, to: t.slot || undefined });
      }
    } else if (src.area === 'container') {
      if (t.area === 'inv') action('take', { from: src.slot, to: t.slot, count });
      else if (t.area === 'container' && t.slot) action('cmove', { from: src.slot, to: t.slot, count });
    } else if (src.area === 'equip') {
      if (t.area === 'inv') post('unequipClothing', { cat: src.slot });
    } else if (src.area === 'ground') {
      if (t.area === 'inv') action('pickup', { drop: state.data.ground && state.data.ground.id, index: src.slot, to: t.slot, count });
    }
  }

  function endDrag(e) {
    const t = targetAt(e.clientX, e.clientY);
    const src = drag.src;
    const count = dragCount(src.item, e, src);
    cleanupDrag();
    if (t) dispatch(src, t, count);
  }

  document.addEventListener('pointerdown', e => {
    if (e.button !== 0 || !state.open) return;
    const handle = e.target.closest('[data-drag]');
    if (handle) {
      const src = sourceOf(handle);
      if (src) pend = { src, x: e.clientX, y: e.clientY };
      return;
    }
    if (e.target.closest('#character')) {
      rot = { x: e.clientX };
      charEl.classList.add('rotating');
    }
  });

  document.addEventListener('pointermove', e => {
    mx = e.clientX; my = e.clientY;
    if (rot) {
      rotAcc += (e.clientX - rot.x) * 0.55;
      rot.x = e.clientX;
      if (!rotTimer) rotTimer = setTimeout(() => {
        rotTimer = 0;
        if (rotAcc) { post('rotate', { delta: rotAcc }); rotAcc = 0; }
      }, 16);
      return;
    }
    if (pend && !drag && Math.hypot(mx - pend.x, my - pend.y) > 5) startDrag(pend.src);
    if (drag) { if (!raf) raf = requestAnimationFrame(frame); }
    else if (tipItem) placeTip();
  });

  document.addEventListener('pointerup', e => {
    if (rot) { rot = null; charEl.classList.remove('rotating'); }
    if (drag) endDrag(e);
    pend = null;
  });

  window.addEventListener('blur', () => { cleanupDrag(); pend = null; rot = null; });

  document.addEventListener('pointerover', e => {
    if (drag || rot) return;
    const el = e.target.closest('.slot.has, .eslot.filled');
    if (!el || !el._item) return hideTip();
    if (el._item === tipItem) return;
    const area = el.classList.contains('eslot') ? 'equip' : el.dataset.area === 'ground' ? 'ground' : el.dataset.area === 'container' ? 'container' : 'inv';
    showTip(el._item, area);
  });

  document.addEventListener('dblclick', e => {
    const src = sourceOf(e.target);
    if (!src) return;
    hideTip();
    if (src.area === 'inv' && src.item.equip) post('equipClothing', { slot: src.slot });
    else if (src.area === 'inv') action('use', { from: src.slot });
    else if (src.area === 'equip') post('unequipClothing', { cat: src.slot });
    else if (src.area === 'ground') action('pickup', { drop: state.data.ground && state.data.ground.id, index: src.slot, count: dragCount(src.item) });
    else if (src.area === 'container') action('take', { from: src.slot, count: dragCount(src.item, null, src) });
  });

  // Renommer une arme à feu (fenêtre dans l'inventaire)
  const renameBox = document.createElement('div');
  renameBox.className = 'rename-box';
  renameBox.innerHTML = `<div class="rename-card"><h3>Renommer l'arme</h3><p class="rename-sub"></p>
    <input type="text" maxlength="30" placeholder="Nouveau nom (2 à 30 caractères)">
    <div class="rename-actions"><button type="button" data-rn="reset">Nom d'origine</button><span></span><button type="button" data-rn="no">Annuler</button><button type="button" data-rn="ok" class="primary">Valider</button></div></div>`;
  document.body.appendChild(renameBox);
  const renameInput = renameBox.querySelector('input');
  let renameSlot = null;
  const renameOpen = () => renameBox.classList.contains('show');
  function closeRename() { renameBox.classList.remove('show'); renameSlot = null; }
  function renameWeapon(slot, it) {
    renameSlot = slot;
    renameBox.querySelector('.rename-sub').textContent = `${it.label}${it.metadata && it.metadata.serial ? ` · N° ${it.metadata.serial}` : ''}`;
    renameInput.value = it.metadata && it.metadata.custom ? it.label : '';
    renameBox.classList.add('show');
    setTimeout(() => renameInput.focus(), 20);
  }
  function submitRename(reset) {
    if (renameSlot == null) return closeRename();
    action('renameWeapon', { slot: renameSlot, name: reset ? '' : renameInput.value.trim() });
    closeRename();
  }
  renameBox.addEventListener('click', e => {
    const b = e.target.closest('[data-rn]');
    if (!b) { if (e.target === renameBox) closeRename(); return; }
    if (b.dataset.rn === 'no') closeRename(); else submitRename(b.dataset.rn === 'reset');
  });
  renameInput.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); submitRename(false); } });

  // Clic droit : menu contextuel (Utiliser + boutons de l'objet, ex. Porter / Renommer)
  const menu = document.createElement('div');
  menu.className = 'ctx-menu';
  document.body.appendChild(menu);
  const hideMenu = () => menu.classList.remove('show');
  document.addEventListener('pointerdown', e => { if (!e.target.closest('.ctx-menu')) hideMenu(); }, true);

  document.addEventListener('contextmenu', e => {
    e.preventDefault();
    const src = sourceOf(e.target);
    if (!src) return hideMenu();
    hideTip();
    const it = src.item, opts = [];
    if (src.area === 'inv') {
      if (it.buttons > 0) {
        BUTTONS(it).forEach((label, i) => opts.push([label, () => post('button', { slot: src.slot, index: i + 1 })]));
      } else {
        opts.push([it.weapon ? 'Équiper / ranger' : 'Utiliser', () => action('use', { from: src.slot })]);
      }
      if (it.wear) {
        const on = !!(it.metadata && it.metadata.worn);
        const label = it.wear === 'back' ? (on ? 'Retirer du dos' : 'Mettre dans le dos') : (on ? 'Retirer de la ceinture' : 'Mettre à la ceinture');
        opts.push([label, () => post('wear', { slot: src.slot })]);
      }
      if (it.weapon && it.firearm) opts.push(['Renommer', () => renameWeapon(src.slot, it)]);
      if (state.data.container && !isShop()) opts.push(['Ranger dans le coffre', () => action('store', { from: src.slot, count: dragCount(it) })]);
      opts.push(['Donner', () => post('give', { from: src.slot, count: dragCount(it) })]);
      opts.push(['Jeter', () => action('drop', { from: src.slot, count: dragCount(it) })]);
    } else if (src.area === 'equip') {
      opts.push(['Ranger dans l\'inventaire', () => post('unequipClothing', { cat: src.slot })]);
    } else if (src.area === 'ground') {
      opts.push(['Ramasser', () => action('pickup', { drop: state.data.ground && state.data.ground.id, index: src.slot, count: dragCount(it) })]);
    } else if (src.area === 'container') {
      if (isShop()) opts.push([`Acheter${it.price > 0 ? ` (${it.price} $)` : ''}`, () => action('take', { from: src.slot, count: dragCount(it, null, src) })]);
      else opts.push(['Prendre', () => action('take', { from: src.slot, count: dragCount(it) })]);
    }
    menu.innerHTML = '';
    opts.forEach(([label, fn]) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      b.addEventListener('click', () => { hideMenu(); fn(); });
      menu.appendChild(b);
    });
    menu.style.transform = `translate3d(${Math.min(e.clientX, innerWidth - 190)}px, ${Math.min(e.clientY, innerHeight - opts.length * 36 - 12)}px, 0)`;
    menu.classList.add('show');
  });
  // Libellés des boutons des vêtements (mêmes que dans shared/items.lua)
  const BUTTONS = it => (it.equip ? ['Porter', 'Renommer'] : []).slice(0, it.buttons);

  charEl.addEventListener('wheel', e => {
    e.preventDefault();
    post('zoom', { dir: e.deltaY > 0 ? 1 : -1 });
  }, { passive: false });

  document.querySelectorAll('[data-qty]').forEach(b => b.addEventListener('click', () => {
    qtyEl.value = Math.max(0, (parseInt(qtyEl.value, 10) || 0) + +b.dataset.qty);
  }));
  qtyEl.addEventListener('keydown', e => { if (e.key === 'Enter') qtyEl.blur(); });

  // ───────── Ouverture / fermeture ─────────

  function open(data) {
    if (data.equipSlots) state.equipSlots = data.equipSlots;
    buildEquip(state.equipSlots);
    noteFresh(state.data, data.payload);
    state.data = data.payload;
    state.lastCap = null;
    state.open = true;
    // Toujours rouvrir sur « Tout », sans recherche : un objet reçu ne doit jamais être caché par un ancien filtre
    view.q = ''; searchEl.value = ''; $('#search-clear').hidden = true;
    cashForm.hidden = true;
    setCat('all');
    app.classList.remove('hidden');
    app.setAttribute('aria-hidden', 'false');
    render();
    if (fresh.size) {
      const slots = [...fresh];
      fresh = new Set();
      slots.forEach(n => { const el = state.slotEls[n - 1]; if (el && el._item) el.classList.add('fresh'); });
      const first = state.slotEls[Math.min(...slots) - 1];
      if (first && first._item && first.scrollIntoView) first.scrollIntoView({ block: 'nearest' });
      setTimeout(() => state.slotEls.forEach(el => el.classList.remove('fresh')), 4000);
    }
  }

  // Portefeuille : donner de l'argent liquide
  $('#cash-give').addEventListener('click', () => {
    cashForm.hidden = !cashForm.hidden;
    if (!cashForm.hidden) { cashAmount.value = ''; cashAmount.focus(); }
  });
  $('#cash-cancel').addEventListener('click', () => { cashForm.hidden = true; });
  cashForm.addEventListener('submit', e => {
    e.preventDefault();
    const n = Math.floor(Number(cashAmount.value) || 0);
    const max = (state.data && state.data.money && state.data.money.cash) || 0;
    if (n < 1) { cashAmount.focus(); return; }
    if (n > max) { toast('error', `Tu n'as que ${money(max)} en liquide.`); return; }
    cashForm.hidden = true;
    post('giveCash', { amount: n });
  });

  function close(fromGame) {
    if (!state.open) return;
    state.open = false;
    cleanupDrag();
    hideTip();
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    if (!fromGame) post('close');
  }

  $('#close').addEventListener('click', () => close(false));

  document.addEventListener('keydown', e => {
    if (renameOpen()) { if (e.key === 'Escape') { e.preventDefault(); closeRename(); } return; }
    if (document.activeElement === qtyEl && e.key !== 'Escape') return;
    if (document.activeElement === searchEl) {
      if (e.key === 'Escape' && searchEl.value) { e.preventDefault(); $('#search-clear').click(); searchEl.blur(); return; }
      if (e.key !== 'Escape' && e.key !== 'Tab') return;
    }
    // Ctrl + F : rechercher · Alt + 1 à 4 : onglets
    if (state.open && e.ctrlKey && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); searchEl.focus(); return; }
    if (state.open && e.altKey && /^[1-4]$/.test(e.key)) { e.preventDefault(); setCat(['all', 'weapons', 'food', 'papers'][+e.key - 1]); return; }
    if (state.open && (e.key === 'Escape' || e.key === 'F2' || e.key === 'Tab')) {
      e.preventDefault();
      close(false);
    } else if (!state.open && !IS_FIVEM && e.key === 'F2') {
      Mock.open();
    }
  });

  window.addEventListener('message', e => {
    const msg = e.data || {};
    if (msg.action === 'open') open(msg.data);
    else if (msg.action === 'close') close(true);
    else if (msg.action === 'hotbar' && msg.data) showHud(msg.data.index, msg.data.payload);
    else if (msg.action === 'sync' && msg.data) {
      if (!state.open) noteFresh(state.data, msg.data.payload);
      state.data = msg.data.payload;
      if (state.open) render();
      const t = msg.data.toast;
      if (t && t.text) toast(t.type, t.text);
    }
  });

  // ───────── Mode aperçu navigateur (hors FiveM) ─────────
  // Simule le serveur avec les mêmes règles pour tester l'interface en ouvrant index.html.

  const Mock = (() => {
    const BASE = 18000;
    const D = {
      phone: { label: 'Téléphone', icon: '📱', weight: 200, category: 'other' },
      burger: { label: 'Burger', icon: '🍔', weight: 220, stack: true, max: 20, category: 'food', description: 'Rassasie un peu.' },
      water: { label: "Bouteille d'eau", icon: '💧', weight: 500, stack: true, max: 20, category: 'food' },
      sandwich: { label: 'Sandwich', icon: '🥪', weight: 200, stack: true, max: 20, category: 'food' },
      WEAPON_PISTOL: { label: 'Pistolet', icon: '🔫', weight: 1130, weapon: true, firearm: true, category: 'weapons' },
      WEAPON_KNIFE: { label: 'Couteau', icon: '🔪', weight: 300, weapon: true, category: 'weapons' },
      'ammo-9': { label: 'Munitions 9 mm', icon: '🔸', weight: 7, stack: true, max: 1000, category: 'weapons' },
      carte_identite: { label: "Carte d'identité", icon: '🪪', weight: 10, category: 'papers', image: 'carte_identite.png' },
      permis: { label: 'Permis de conduire', icon: '🪪', weight: 10, category: 'papers', image: 'permis.png' },
      ppa: { label: 'PPA · Civil', icon: '🪪', weight: 10, category: 'papers', image: 'ppa.png' },
      bandage: { label: 'Bandage', icon: '🩹', weight: 100, stack: true, max: 20, category: 'other' },
      brick: { label: 'Parpaing', icon: '🧱', weight: 4000, stack: true, max: 5, description: 'Lourd : pour tester la limite.', category: 'other' },
    };
    const CL = { vet_haut: ['Haut', 'tops'], vet_tshirt: ['T-shirt', 'undershirts'], vet_pantalon: ['Pantalon', 'pants'], vet_chaussures: ['Chaussures', 'shoes'], vet_sac: ['Sac', 'bags'], vet_chapeau: ['Chapeau', 'hats'], vet_montre: ['Montre', 'watches'] };
    for (const k in CL) D[k] = { label: CL[k][0], icon: '👕', weight: 10, image: `${k}.png`, equip: CL[k][1], buttons: 2, bonus: k === 'vet_sac' ? 10 : undefined, category: 'other' };
    const SLOTS = [['hats','Chapeau','👒','left'],['glasses','Lunettes','👓','left'],['ears','Boucles','💎','left'],['masks','Masque','😷','left'],['chains','Collier','📿','left'],['tops','Haut','🧥','left'],['undershirts','T-shirt','👕','left'],['vests','Gilet','🦺','left'],['arms','Gants','🧤','right'],['decals','Logo','🏷️','right'],['watches','Montre','⌚','right'],['bracelets','Bracelet','💍','right'],['pants','Pantalon','👖','right'],['shoes','Chaussures','👟','right'],['bags','Sac','🎒','right']]
      .map(([name, label, icon, side]) => ({ name, label, icon, side }));
    const itemOf = {}; for (const k in CL) itemOf[CL[k][1]] = k;

    const inv = { slots: {}, worn: { tops: 263, pants: 24, shoes: 10, bags: 45 }, bag: true };
    let ground = [{ name: 'water', count: 2 }];
    [['phone', 1], ['burger', 5], ['water', 2], ['WEAPON_PISTOL', 1, 'Le Silencieux'], ['ammo-9', 120], ['carte_identite', 1], ['brick', 2], ['vet_haut', 1, 'Veste de mariage'],
      ['vet_chapeau', 1], ['permis', 1], ['ppa', 1], ['sandwich', 3], ['WEAPON_KNIFE', 1], ['bandage', 6], ['vet_montre', 1]]
      .forEach((e, i) => { if (e) inv.slots[i + 1] = { name: e[0], count: e[1], label: e[2] }; });

    const ser = (it, slot) => { const d = D[it.name]; return Object.assign({ plain: true, max: d.max || 1 }, d, { slot, name: it.name, count: it.count, label: it.label || d.label, weight: d.weight / 1000 }); };
    const weight = () => Object.values(inv.slots).reduce((s, it) => s + D[it.name].weight * it.count, 0);
    const cap = () => BASE + (inv.bag ? 10000 : 0);
    const empty = () => { for (let i = 1; i <= 100; i++) if (!inv.slots[i]) return i; return null; };
    const wallet = { cash: 1840, bank: 26350 };
    const HEAVY = "Poids maximum atteint : vous n'avez pas assez de place dans votre inventaire.";

    function payload() {
      const equipment = {};
      for (const cat in inv.worn) { const n = itemOf[cat]; equipment[cat] = { slot: cat, name: n, count: 1, label: `${D[n].label} n°${inv.worn[cat]}`, image: `${n}.png`, icon: '👕', weight: 0.01, equip: cat }; }
      return { slots: 100, hotbar: 5, items: Object.entries(inv.slots).map(([s, it]) => ser(it, +s)), equipment,
        weight: weight() / 1000, capacity: cap() / 1000, baseCapacity: 18, bag: inv.bag,
        ground: ground.length ? { id: 1, items: ground.map((it, i) => ser(it, i + 1)) } : null, money: Object.assign({}, wallet) };
    }
    function give(name, count, to) {
      if (weight() + D[name].weight * count > cap()) return HEAVY;
      const t = to && inv.slots[to];
      if (D[name].stack && t && t.name === name) { t.count += count; return null; }
      const slot = to && !t ? to : empty();
      if (!slot) return 'Aucun emplacement libre dans votre inventaire.';
      inv.slots[slot] = { name, count };
      return null;
    }
    const ops = {
      move({ from, to, count }) {
        const a = inv.slots[from], b = inv.slots[to];
        if (!a) return;
        if (!b) { if (count >= a.count) { inv.slots[to] = a; delete inv.slots[from]; } else { inv.slots[to] = { name: a.name, count }; a.count -= count; } }
        else if (a.name === b.name && D[a.name].stack) { const n = Math.min(count, D[a.name].max - b.count); b.count += n; a.count -= n; if (a.count <= 0) delete inv.slots[from]; }
        else { inv.slots[to] = a; inv.slots[from] = b; }
      },
      drop({ from, count }) {
        const it = inv.slots[from]; if (!it) return;
        ground.push({ name: it.name, count, label: it.label });
        it.count -= count; if (it.count <= 0) delete inv.slots[from];
      },
      pickup({ index, to, count }) {
        const g = ground[index - 1]; if (!g) return;
        const err = give(g.name, count, to); if (err) return err;
        g.count -= count; if (g.count <= 0) ground.splice(index - 1, 1);
      },
      use({ from }) { const it = inv.slots[from]; if (it && D[it.name].stack && --it.count <= 0) delete inv.slots[from]; },
      equipClothing({ slot }) {
        const it = inv.slots[slot]; if (!it || !D[it.name].equip) return;
        const cat = D[it.name].equip; delete inv.slots[slot];
        if (inv.worn[cat]) inv.slots[slot] = { name: itemOf[cat], count: 1 };
        inv.worn[cat] = 100 + slot; if (cat === 'bags') inv.bag = true;
      },
      unequipClothing({ cat }) {
        if (!inv.worn[cat]) return;
        if (cat === 'bags') {
          const w = weight() + 10;
          if (w > BASE) return `Impossible de retirer le sac : vous passeriez à ${(w / 1000).toFixed(2)} KG / 18 KG. Déposez des objets d'abord.`;
          inv.bag = false;
        }
        const err = give(itemOf[cat], 1); if (err) { if (cat === 'bags') inv.bag = true; return err; }
        delete inv.worn[cat];
      },
    };
    function handle(name, body) {
      let err;
      if (name === 'action') err = ops[body.type] && ops[body.type](body);
      else if (name === 'equipClothing' || name === 'unequipClothing') err = ops[name](body);
      else if (name === 'giveCash') { if (body.amount > wallet.cash) err = "Vous n'avez pas assez d'argent."; else wallet.cash -= body.amount; }
      else if (name === 'button') err = body.index === 1 ? ops.equipClothing({ slot: body.slot }) : null;
      else return;
      setTimeout(() => window.postMessage({ action: 'sync', data: { payload: payload(), toast: err ? { type: 'error', text: err } : null } }, '*'), 30);
    }
    // Tests : simule un achat reçu pendant que l'inventaire est fermé
    function receive(name, count) { give(name, count); window.postMessage({ action: 'sync', data: { payload: payload() } }, '*'); }
    function setCash(n) { wallet.cash = n; window.postMessage({ action: 'sync', data: { payload: payload() } }, '*'); }
    return { handle, receive, setCash, open: () => open({ payload: payload(), equipSlots: SLOTS }) };
  })();

  if (!IS_FIVEM) {
    window.InvMock = Mock;
    document.body.classList.add('is-preview');
    document.body.style.background = 'radial-gradient(ellipse at 50% 55%, #2a3550 0%, #121826 60%, #0a0d16 100%)';
    Mock.open();
  }
})();
