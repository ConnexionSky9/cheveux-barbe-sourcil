/* =====================================================================
   ELYZEA CONCESSION - interface : socle, F6, offre d'achat, livraison,
   recrutement. Les montants affichés viennent du serveur, qui recalcule
   tout avant de débiter.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_concess';
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const fmtTime = (t) => { if (!t) return '—'; const d = new Date(t * 1000); return d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }); };
const ago = (t) => { const m = Math.floor((Date.now() / 1000 - t) / 60); return m < 1 ? 'à l\'instant' : m < 60 ? `il y a ${m} min` : m < 1440 ? `il y a ${Math.floor(m / 60)} h` : `il y a ${Math.floor(m / 1440)} j`; };
const dur = (s) => { s = Math.max(0, Math.floor(Number(s) || 0)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return `${h}h${String(m).padStart(2, '0')}`; };
const left = (s) => { s = Math.max(0, Math.floor(Number(s) || 0)); const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600); return d > 0 ? `${d} j ${h} h` : `${h} h ${Math.floor((s % 3600) / 60)} min`; };

async function post(name, data = {}) {
  if (!IN_GAME) return window.EDemo ? window.EDemo(name, data) : {};
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return { error: 'Connexion au jeu impossible.' }; }
}
const req = (action, data = {}) => post('req', { action, data });
const pub = (action, data = {}) => post('pub', { action, data });
const adm = (action, data = {}) => post('adm', { action, data });

const APP = { cfg: null, st: null, statuses: [] };
const statusOf = (id) => APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' };

function toast(msg, ok = true) {
  if (!msg) return;
  const el = document.createElement('div');
  el.className = `toast ${ok ? 'ok' : 'err'}`;
  el.textContent = msg;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 3400);
}
async function act(promise, btn) {
  if (btn) btn.classList.add('loading');
  const r = await promise;
  if (btn) btn.classList.remove('loading');
  if (r && r.error) toast(r.error, false); else if (r && r.message) toast(r.message, true);
  return r || {};
}

/* ---------- Confirmation ---------- */
let confirmResolve = null;
function confirmBox(title, text, yes = 'Confirmer', danger = false, extra = '') {
  const w = $('#confirm');
  $('.modal', w).innerHTML = `<h2>${esc(title)}</h2><p class="lead">${text}</p>${extra}
    <div class="actions"><button class="btn" data-cf="no">Annuler</button><button class="btn ${danger ? 'danger' : 'primary'}" data-cf="yes">${esc(yes)}</button></div>`;
  w.classList.remove('hidden');
  setTimeout(() => $('[data-cf="yes"]', w).focus(), 30);
  return new Promise((r) => { confirmResolve = r; });
}
$('#confirm').addEventListener('click', (e) => {
  const b = e.target.closest('[data-cf]');
  if (!b && e.target !== $('#confirm')) return;
  const yes = b && b.dataset.cf === 'yes';
  const vals = {};
  $('#confirm').querySelectorAll('[data-cfv]').forEach((i) => { vals[i.dataset.cfv] = i.type === 'checkbox' ? i.checked : i.value; });
  $('#confirm').classList.add('hidden');
  if (confirmResolve) { confirmResolve(yes ? vals : null); confirmResolve = null; }
});


const imgOf = (it) => (it && it.image) || (APP.cfg && APP.cfg.imageUrl && it && it.model ? APP.cfg.imageUrl.replace('%s', it.model) : '');

/* =====================================================================
   Menu F6 (employés)
   ===================================================================== */
const F6 = { view: 'main', data: null };
function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {}, p = st.perms || {}, duty = !!st.duty, t = d.times, live = (d.timesAt || 0) / 1000;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc((st.shopName || 'Concession').toUpperCase())}</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Employé')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>
      ${t ? `<div class="times"><div><b>${dur(t.session + (duty ? live : 0))}</b><small>Session</small></div><div><b>${dur(t.unpaid + (duty ? live : 0))}</b><small>Non payé</small></div>
        <div><b>${dur(t.total + (duty ? live : 0))}</b><small>Total</small></div></div>` : ''}`;
  const item = (id, ico, label, sub, o = {}) => `<button class="f6-item ${o.cls || ''}" data-f6="${id}" ${o.disabled ? 'disabled' : ''} ${o.attrs || ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${o.chev ? '<span class="chev">›</span>' : ''}</button>`;
  if (F6.view === 'status') {
    return head + '<button class="f6-back" data-f6="back">‹ Statut</button><div class="f6-list">' + APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span>
      <span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
  }
  let b = head + '<div class="f6-list">';
  if (st.open === false) b += '<div class="warn-box" style="margin:.5rem">Concession fermée par le staff : catalogue, ventes et exposition suspendus.</div>';
  if (p.duty) b += duty ? item('dutyOff', '⏻', 'Terminer mon service', 'Votre temps est enregistré', { cls: 'duty-off' }) : item('dutyOn', '⏻', 'Prendre mon service', '', { cls: 'duty-on' });
  if (duty) b += item('status', '◉', 'Statut', esc(statusOf(st.status).label), { chev: true });
  if (p.catalog) {
    b += '<div class="section-label">Commercial</div>';
    b += item('catalog', '🚘', 'Catalogue de la concession', p.sell ? 'Présenter, vendre, exposer' : 'Présenter les véhicules');
    if (p.tablet) b += item('tab', '🔎', 'Rechercher un véhicule', 'Prix, restrictions, fiches', { attrs: 'data-page="catalog"' });
    if (p.tablet) b += item('tab', '🧾', p.sales_all ? 'Ventes et livraisons' : 'Mes ventes et livraisons', 'Suivi des livraisons et des clés', { attrs: 'data-page="sales"' });
  }
  if (p.tablet) {
    b += '<div class="section-label">Exposition</div>';
    b += item('tab', '🅿️', 'Véhicules en exposition', p.display ? 'Ajouter, retirer, remplacer' : 'Emplacements', { attrs: 'data-page="display"' });
    b += '<div class="section-label">Tablette</div>';
    b += item('tab', '📊', 'Tableau de bord', 'Ventes, chiffre d\'affaires, équipe', { attrs: 'data-page="dashboard"' });
    if (p.direction) b += item('tab', '🏛️', 'Direction', 'Personnel, grades', { attrs: 'data-page="employees"' });
    if (p.finance) b += item('tab', '💰', 'Finances', 'Compte, salaires, commissions', { attrs: 'data-page="finance"' });
  }
  b += '</div><div class="f6-foot"><span><span class="kbd">E</span> catalogue / sortie</span><span><span class="kbd">Échap</span> fermer</span></div>';
  return b;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }
$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if (!(b = e.target.closest('[data-f6]'))) return;
  const a = b.dataset.f6;
  if (a === 'back') { F6.view = 'main'; return f6Draw(); }
  if (a === 'status') { F6.view = a; return f6Draw(); }
  if (a === 'dutyOn' || a === 'dutyOff') { F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw(); }
  if (a === 'catalog') return post('f6', { action: 'catalog' });
  if (a === 'tab') return post('f6', { action: 'tablet', page: b.dataset.page });
});

/* =====================================================================
   Offre d'achat (client) : récapitulatif, Accepter / Refuser
   ===================================================================== */
let saleTimer = null;
function showSaleOffer(o) {
  const w = $('#saleOffer');
  const img = imgOf(o);
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.shop)} · Achat</div><h2>${esc(o.label)}</h2>
    ${img ? `<div class="cat-detail" style="padding:0"><div class="hero" style="aspect-ratio:16/7"><img src="${esc(img)}" alt="" onerror="this.remove()"></div></div>` : ''}
    <div class="recap"><span>Concession</span><b>${esc(o.shop)}</b><span>Catégorie</span><b>${esc(o.category || '')}</b><span>Vendeur</span><b>${esc(o.seller)}</b>
      <span>Prix catalogue</span><b>${money(o.list)}</b>${o.discount > 0 ? `<span>Remise</span><b>−${money(o.discount)} (${o.pct} %)</b>` : ''}
      <span>Paiement</span><b>${o.method === 'cash' ? 'Espèces' : 'Banque'}</b><span>Total</span><b class="total">${money(o.price)}</b></div>
    <p class="lead">En acceptant, le total est prélevé tout de suite. Vous recevez un véhicule <b>neuf</b> à votre nom, une plaque unique et la clé dans votre inventaire ; il vous attend à la zone de sortie de la concession.</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-sa="no">Refuser</button><button class="btn primary block" data-sa="yes">Acheter et payer</button></div>
    <div class="countdown"><i id="saBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (o.timeout || 60) * 1000, end = Date.now() + total;
  clearInterval(saleTimer);
  saleTimer = setInterval(() => { const l = end - Date.now(); const bar = $('#saBar'); if (bar) bar.style.width = `${Math.max(0, l / total * 100)}%`; if (l <= 0) clearInterval(saleTimer); }, 200);
}
$('#saleOffer').addEventListener('click', (e) => { const b = e.target.closest('[data-sa]'); if (b) post('saleAnswer', { accept: b.dataset.sa === 'yes' }); });

/* =====================================================================
   Véhicules à récupérer (zone de sortie)
   ===================================================================== */
function showDeliveries(shop, list) {
  const w = $('#deliveries');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(shop)} · Zone de sortie</div><h2>Récupérer un véhicule</h2>
    ${list.map((x) => `<div class="list-row"><div class="main"><b>${esc(x.label || x.model)}</b><small class="mono">${esc(x.plate)} · ${fmtTime(x.t)}</small></div>
      <button class="btn small primary" data-dv="${esc(x.uid)}">Sortir</button></div>`).join('')}
    <p class="faint" style="font-size:.78rem;margin-top:.6rem">Le véhicule apparaît sur une place libre. Si tout est occupé, réessayez : rien n'est facturé à nouveau.</p>
    <div class="actions"><button class="btn" data-dv-close="1">Fermer</button></div>`;
  w.classList.remove('hidden');
}
$('#deliveries').addEventListener('click', async (e) => {
  let b;
  if (e.target.closest('[data-dv-close]')) return post('close', { ui: 'deliveries' });
  if ((b = e.target.closest('[data-dv]'))) { b.classList.add('loading'); await post('deliver', { uid: b.dataset.dv }); b.classList.remove('loading'); }
});

/* =====================================================================
   Proposition de recrutement
   ===================================================================== */
let offerTimer = null;
function showOffer(o) {
  const w = $('#offer');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre <b>${esc(o.job)}</b> au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-offer="no">Refuser</button><button class="btn primary block" data-offer="yes">Accepter</button></div>
    <div class="countdown"><i id="offerBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (o.timeout || 30) * 1000, end = Date.now() + total;
  clearInterval(offerTimer);
  offerTimer = setInterval(() => { const l = end - Date.now(); const bar = $('#offerBar'); if (bar) bar.style.width = `${Math.max(0, l / total * 100)}%`; if (l <= 0) clearInterval(offerTimer); }, 200);
}
$('#offer').addEventListener('click', (e) => { const b = e.target.closest('[data-offer]'); if (b) post('offerAnswer', { accept: b.dataset.offer === 'yes' }); });

/* =====================================================================
   Messages du jeu
   ===================================================================== */
function applyCfg(cfg) { if (!cfg) return; APP.cfg = cfg; APP.statuses = cfg.statuses || []; }
const show = (sel, on) => $(sel).classList.toggle('hidden', !on);

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'state': APP.st = m.state; if (window.Tablet) Tablet.onState(m.state); return;
    case 'f6': if (m.show) { F6.view = 'main'; F6.data = m; show('#f6', true); f6Draw(); } else show('#f6', false); return;
    case 'f6Data': if (!$('#f6').classList.contains('hidden')) { F6.data = m; f6Draw(); } return;
    case 'catalog': if (window.Catalog) { if (m.show) Catalog.open(m.data); else Catalog.hide(); } return;
    case 'saleOffer': if (m.show) showSaleOffer(m.offer); else { show('#saleOffer', false); clearInterval(saleTimer); } return;
    case 'deliveries': if (m.show) showDeliveries(m.shop, m.list); else show('#deliveries', false); return;
    case 'offer': if (m.show) showOffer(m.offer); else { show('#offer', false); clearInterval(offerTimer); } return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'admin': if (window.Admin) { if (m.show) Admin.open(m.data, m.preview); else Admin.hide(); } return;
    case 'closeAll':
      ['#f6', '#saleOffer', '#deliveries', '#offer', '#confirm'].forEach((s) => show(s, false));
      if (window.Catalog) Catalog.hide(); if (window.Admin) Admin.hide(); if (window.Tablet) Tablet.hide(); return;
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (!$('#confirm').classList.contains('hidden')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of [['#saleOffer', 'saleOffer'], ['#deliveries', 'deliveries'], ['#offer', 'offer']]) {
    if (!$(sel).classList.contains('hidden')) return post('close', { ui });
  }
  if (window.Catalog && Catalog.isOpen()) { if (!Catalog.back()) post('close', { ui: 'catalog' }); return; }
  if (window.Admin && Admin.isOpen()) return post('close', { ui: 'admin' });
  if (!$('#f6').classList.contains('hidden')) { if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); } return post('close', { ui: 'f6' }); }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
