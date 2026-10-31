/* =====================================================================
   ELYZEA MÉCANO - interface : F6, atelier (catalogue, aperçu, devis, installation),
   devis reçu par le client, devis de prestations, dépannage, recrutement.
   Les prix affichés viennent du serveur ; le total réel est recalculé par le serveur.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_meca';
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const fmtTime = (t) => { if (!t) return '—'; const d = new Date(t * 1000); return d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); };
const ago = (t) => { const m = Math.floor((Date.now() / 1000 - t) / 60); return m < 1 ? 'à l\'instant' : m < 60 ? `il y a ${m} min` : `il y a ${Math.floor(m / 60)} h`; };
const dur = (s) => { s = Math.max(0, Math.floor(Number(s) || 0)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return `${h}h${String(m).padStart(2, '0')}`; };

async function post(name, data = {}) {
  if (!IN_GAME) return window.EDemo ? window.EDemo(name, data) : {};
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return { error: 'Connexion au jeu impossible.' }; }
}
const req = (action, data = {}) => post('req', { action, data });

const APP = { cfg: null, st: null, statuses: [], towStatuses: {} };
const towSt = (s) => (APP.towStatuses || {})[s] || s;
const QST = { pending: 'En attente du client', accepted: 'Payé · à installer', installed: 'Installé', partial: 'Installé en partie', failed: 'Non installé (remboursé)',
  refused: 'Refusé', expired: 'Expiré', cancelled: 'Annulé' };

function toast(msg, ok = true) {
  if (!msg) return;
  const el = document.createElement('div');
  el.className = `toast ${ok ? 'ok' : 'err'}`;
  el.textContent = msg;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 3400);
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

/* =====================================================================
   Menu F6
   ===================================================================== */
const F6 = { view: 'main', data: null };
const statusOf = (id) => APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' };
const TOW_NEXT = ['enroute', 'onsite', 'diagnostic', 'quote', 'repair', 'done'];

function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {}, p = st.perms || {}, duty = !!st.duty, t = d.times, live = (d.timesAt || 0) / 1000;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc(APP.cfg ? APP.cfg.job : 'MÉCANO')}</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Mécanicien')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>
      ${t ? `<div class="times"><div><b>${dur(t.session + (duty ? live : 0))}</b><small>Session</small></div><div><b>${dur(t.unpaid + (duty ? live : 0))}</b><small>Non payé</small></div>
        <div><b>${dur(t.total + (duty ? live : 0))}</b><small>Total</small></div></div>` : ''}`;
  const item = (id, ico, label, sub, o = {}) => `<button class="f6-item ${o.cls || ''}" data-f6="${id}" ${o.disabled ? 'disabled' : ''} ${o.attrs || ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${o.chev ? '<span class="chev">›</span>' : ''}</button>`;
  const back = (l) => `<button class="f6-back" data-f6="back">‹ ${l}</button>`;
  const tows = d.tows || [], quotes = d.quotes || [];
  if (F6.view === 'status') {
    return head + back('Statut') + '<div class="f6-list">' + APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span>
      <span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
  }
  if (F6.view === 'vehicles') {
    let b = back('Véhicules') + '<div class="f6-list">';
    if (d.vehicle) b += `<div class="near">Véhicule proche : <b>${esc(d.vehicle.model)}</b> · <span class="mono">${esc(d.vehicle.plate)}</span></div>`;
    b += item('workshop', '🛠️', 'Catalogue d\'amélioration', d.workshop ? `Point « ${esc(d.workshop.label)} » : E` : 'Allez à un point d\'atelier (E)', { disabled: !p.workshop, attrs: d.workshop ? `data-id="${esc(d.workshop.id)}"` : '' });
    b += item('serviceQuote', '🧾', 'Créer un devis', 'Réparations, nettoyage, remorquage…', { disabled: !p.quotes || !duty });
    b += item('history', '📋', 'Historique du véhicule', d.vehicle ? esc(d.vehicle.plate) : 'Aucun véhicule à côté', { disabled: !p.vehicles_view || !d.vehicle });
    b += '</div>';
    if (quotes.length) {
      b += '<div class="section-label">Interventions en cours</div><div class="f6-list" style="padding:.5rem">' + quotes.map((q) => `<div class="alert-row" style="--c:var(--accent)">
        <div class="t"><span>${esc(q.uid)} · ${esc(q.plate || 'sans véhicule')}</span><span class="faint">${money(q.total)}</span></div>
        <div class="m">${esc(QST[q.status] || q.status)} · ${esc(q.customer || '')}</div>
        <div class="acts"><button class="btn small danger" data-qc="${esc(q.uid)}">Annuler</button></div></div>`).join('') + '</div>';
    }
    return head + b;
  }
  if (F6.view === 'tows') {
    let b = back('Dépannage') + '<div class="f6-list" style="padding:.6rem">';
    if (!tows.length) b += '<div class="empty">Aucune demande en cours.</div>';
    b += tows.map((c) => { const idx = TOW_NEXT.indexOf(c.status); const next = c.accepted ? TOW_NEXT.slice(idx + 1) : [];
      return `<div class="alert-row" style="--c:${c.status === 'pending' ? '#f59e0b' : '#3b82f6'}"><div class="t"><span>#${c.id} · ${esc(c.reason)}</span><span class="st-pill">${esc(towSt(c.status))}</span></div>
        <div class="m">${esc(c.street || '')} · ${ago(c.t)}${c.vehicle ? `<br>${esc(c.vehicle)} ${c.plate ? `· ${esc(c.plate)}` : ''}` : ''}${c.client ? `<br>Client : ${esc(c.client)}${c.phone ? ` · ${esc(c.phone)}` : ''}` : ''}
          <br>${c.crew && c.crew.length ? `Équipe : ${esc(c.crew.join(', '))}` : 'Personne n\'a pris la demande'}</div>
        <div class="acts">${c.accepted ? `<button class="btn small" data-tw="${c.id}:route">📍 GPS</button>
          ${next.length ? `<select class="input" style="width:auto;padding:.2rem .4rem;font-size:.78rem" data-twst="${c.id}"><option value="">Statut…</option>${next.map((s) => `<option value="${s}">${esc(towSt(s))}</option>`).join('')}</select>` : ''}
          <button class="btn small" data-tw="${c.id}:leave">Quitter</button>`
          : `<button class="btn small primary" data-tw="${c.id}:accept">${c.crew && c.crew.length ? 'Rejoindre' : 'Accepter'}</button><button class="btn small" data-tw="${c.id}:decline">Refuser</button>`}</div></div>`; }).join('');
    return head + b + '</div>';
  }
  let b = duty ? item('dutyOff', '⏻', 'Terminer mon service', 'Votre temps est enregistré', { cls: 'duty-off' })
    : item('dutyOn', '⏻', 'Prendre mon service', p.duty ? 'Le temps de service est compté' : 'Votre grade ne le permet pas', { cls: 'duty-on', disabled: !p.duty });
  if (duty) b += item('status', '◉', 'Statut', esc(statusOf(st.status).label), { chev: true });
  b += item('vehicles', '🚗', `Véhicules${quotes.length ? ` (${quotes.length})` : ''}`, 'Atelier, devis, historique', { chev: true, disabled: !duty });
  if (p.quotes) b += item('clients', '🧾', 'Clients', 'Devis, factures, paiements', { attrs: 'data-page="quotes"' });
  if (p.tow) b += item('tows', '🚚', `Dépannage${tows.length ? ` (${tows.length})` : ''}`, duty ? 'Demandes, GPS, statut' : 'Prenez votre service', { chev: true, disabled: !duty });
  if (p.tablet) b += item('tablet', '📱', 'Ouvrir la tablette', 'Véhicules clients, devis, statistiques');
  if (p.direction) b += item('direction', '🏛️', 'Direction', 'Personnel, catalogue et tarifs, finance', { attrs: 'data-page="employees"' });
  return `${head}<div class="f6-list">${b}</div><div class="f6-foot"><span><span class="kbd">ALT</span> véhicule</span><span><span class="kbd">E</span> atelier</span><span><span class="kbd">Échap</span> fermer</span></div>`;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }
async function refreshF6() { F6.data = await post('f6', { action: 'refresh' }); f6Draw(); }

$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6]'))) {
    const a = b.dataset.f6;
    if (a === 'back') { F6.view = 'main'; return f6Draw(); }
    if (a === 'dutyOn' || a === 'dutyOff') {
      if (a === 'dutyOff' && !(await confirmBox('Terminer votre service ?', 'Votre temps de service est enregistré et sera payé par la direction.', 'Terminer'))) return;
      F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw();
    }
    if (['status', 'vehicles', 'tows'].includes(a)) { F6.view = a; return f6Draw(); }
    if (a === 'workshop') return post('f6', { action: 'workshop', id: b.dataset.id });
    if (a === 'serviceQuote' || a === 'history') return post('f6', { action: a });
    if (a === 'tablet' || a === 'direction' || a === 'clients') return post('f6', { action: 'tablet', page: b.dataset.page });
  }
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if ((b = e.target.closest('[data-qc]'))) {
    if (!(await confirmBox('Annuler le devis ?', 'S\'il a été payé, le client est remboursé intégralement.', 'Annuler le devis', true))) return;
    F6.data = await post('f6', { action: 'cancelQuote', uid: b.dataset.qc }); return f6Draw();
  }
  if ((b = e.target.closest('[data-tw]'))) {
    const [id, todo] = b.dataset.tw.split(':');
    post('towAction', { id: Number(id), do_: todo });
    return setTimeout(refreshF6, 400);
  }
});
$('#f6').addEventListener('change', async (e) => {
  const s = e.target.closest('[data-twst]');
  if (!s || !s.value) return;
  if ((s.value === 'done') && !(await confirmBox('Clôturer l\'intervention ?', 'Elle passera au statut « Terminée » pour toute l\'équipe.', 'Clôturer'))) { s.value = ''; return; }
  post('towAction', { id: Number(s.dataset.twst), do_: 'status', status: s.value });
  setTimeout(refreshF6, 400);
});

/* =====================================================================
   Notifications de dépannage (G / I)
   ===================================================================== */
const notifEls = new Map();
function removeNotif(kind, id) {
  const k = `${kind}:${id}`, el = notifEls.get(k);
  if (!el) return;
  notifEls.delete(k);
  el.classList.add('out');
  setTimeout(() => el.remove(), 260);
}
function showNotif(m) {
  const a = m.alert, k = `${m.kind}:${a.id}`;
  removeNotif(m.kind, a.id);
  const el = document.createElement('div');
  const life = 30000;
  el.className = 'notif';
  el.style.setProperty('--c', '#f59e0b');
  el.innerHTML = `<div class="lvl-tag">Dépannage #${a.id}</div><h3>${esc(a.reason)}</h3>
    <div class="meta">${a.vehicle ? `${esc(a.vehicle)} ${a.plate ? `· ${esc(a.plate)}` : ''}<br>` : ''}${a.client ? `Client : ${esc(a.client)}<br>` : ''}📍 ${esc(a.street || '')} · ${m.distance} m</div>
    <div class="keys"><span><span class="kbd">G</span> Accepter</span><span><span class="kbd">I</span> Refuser</span></div><i class="bar"></i>`;
  el.querySelector('.bar').style.animationDuration = `${life}ms`;
  $('#notifs').prepend(el);
  notifEls.set(k, el);
  while ($('#notifs').children.length > 4) $('#notifs').lastChild.remove();
  setTimeout(() => { if (notifEls.get(k) === el) removeNotif(m.kind, a.id); }, life);
}

/* Atelier, installation, mini-jeux : html/workshop.js et html/minigames.js */

/* =====================================================================
   Devis reçu (client)
   ===================================================================== */
let offerQ = null, offerT = null;
function quoteOfferRender(q, timeout) {
  const w = $('#quoteOffer');
  $('.modal', w).innerHTML = `<div class="eyebrow">Garage · devis ${esc(q.uid)}</div><h2>${esc(q.model || 'Prestations')} ${q.plate ? `· <span class="mono">${esc(q.plate)}</span>` : ''}</h2>
    <p class="lead">Mécanicien : <b>${esc(q.mechanic)}</b>. En acceptant, le total est prélevé immédiatement (banque, puis liquide). Toute prestation qui ne pourrait pas être installée vous est remboursée.</p>
    <div class="q-items">${q.items.map((l) => `<div class="bill-line"><span>${esc(l.label)}${l.qty > 1 ? ` ×${l.qty}` : ''}</span><b>${money(l.total)}</b></div>`).join('')}</div>
    <div class="bill-total"><span>Total</span><span>${money(q.total)}</span></div>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-qa="no">Refuser</button><button class="btn primary block" data-qa="yes">Accepter et payer</button></div>
    <div class="countdown"><i id="qBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (timeout || 90) * 1000, end = Date.now() + total;
  clearInterval(offerT);
  offerT = setInterval(() => { const left = end - Date.now(); const bar = $('#qBar'); if (bar) bar.style.width = `${Math.max(0, left / total * 100)}%`; if (left <= 0) clearInterval(offerT); }, 200);
}
$('#quoteOffer').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-qa]');
  if (!b || !offerQ) return;
  if (b.dataset.qa === 'yes' && !(await confirmBox('Payer le devis ?', `<b>${money(offerQ.total)}</b> seront prélevés maintenant.`, 'Payer'))) return;
  post('quoteAnswer', { accept: b.dataset.qa === 'yes' });
});

/* =====================================================================
   Devis de prestations (F6 / ALT)
   ===================================================================== */
const SV = { items: [], sel: {}, customers: [], vehicle: null };
function svcRender(err = '') {
  const total = SV.items.reduce((s, i) => s + (SV.sel[i.code] ? i.price * SV.sel[i.code] : 0), 0);
  $('#svcQuote .modal').innerHTML = `<div class="eyebrow">Devis de prestations</div><h2>${SV.vehicle ? `${esc(SV.vehicle.model)} · <span class="mono">${esc(SV.vehicle.plate)}</span>` : 'Sans véhicule'}</h2>
    <p class="lead">Prix officiels de la direction. Le client accepte et paie sur son écran ; la facture est créée aussitôt.</p>
    <div class="q-items">${SV.items.map((i) => `<label class="extra" style="justify-content:space-between"><span><input type="checkbox" class="check" data-sv="${esc(i.code)}" ${SV.sel[i.code] ? 'checked' : ''} ${i.locked ? 'disabled' : ''}> ${esc(i.name)}
      ${i.locked ? '<small class="faint">(grade insuffisant)</small>' : ''}</span><span>${SV.sel[i.code] ? `<input class="input" type="number" min="1" max="10" value="${SV.sel[i.code]}" data-svq="${esc(i.code)}" style="width:4rem;padding:.2rem .4rem">` : ''} <b>${money(i.price)}</b></span></label>`).join('')}</div>
    <label class="field"><span>Client</span><select class="input" id="svCustomer">${SV.customers.length ? SV.customers.map((c) => `<option value="${c.id}">${c.self ? '🔧 Moi-même · je paie' : `Personne · ID ${c.id} (${c.distance} m)`}</option>`).join('') : '<option value="">Personne à côté</option>'}</select></label>
    <div class="bill-total"><span>Total</span><span>${money(total)}</span></div><div class="err">${esc(err)}</div>
    <div class="actions"><button class="btn" data-svb="cancel">Annuler</button><button class="btn primary" data-svb="send" ${total > 0 && SV.customers.length ? '' : 'disabled'}>Envoyer le devis</button></div>`;
}
$('#svcQuote').addEventListener('change', (e) => {
  const c = e.target.closest('[data-sv]');
  if (c) { if (c.checked) SV.sel[c.dataset.sv] = 1; else delete SV.sel[c.dataset.sv]; return svcRender(); }
  const q = e.target.closest('[data-svq]');
  if (q) { SV.sel[q.dataset.svq] = Math.max(1, Math.min(10, Number(q.value) || 1)); svcRender(); }
});
$('#svcQuote').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-svb]');
  if (!b) return;
  if (b.dataset.svb === 'cancel') return post('close', { ui: 'svcQuote' });
  const customer = Number($('#svCustomer').value);
  const items = Object.entries(SV.sel).map(([code, qty]) => ({ code, qty }));
  if (!(await confirmBox('Envoyer le devis ?', `${items.length} prestation(s) au client ID ${customer}.`, 'Envoyer'))) return;
  const r = await post('svcSend', { customer, items });
  if (r && r.error) svcRender(r.error);
});

/* =====================================================================
   Véhicules de service, recrutement, progression
   ===================================================================== */
let GAR = [];
function garageRender(list, err = '') {
  $('#garage .modal').innerHTML = `<div class="eyebrow">Véhicules de service</div><h2>Sortir un véhicule</h2><p class="lead">Le véhicule apparaît sur la place de sortie, avec ses clés.</p>
    <div class="veh-list">${list.map((v) => `<button class="veh" data-veh="${v.i}" ${v.locked ? 'disabled' : ''}><span><b>${esc(v.label)}</b><br><small class="mono">${esc(v.model)}</small></span>
      <small>${v.locked ? `grade ${v.minLevel} minimum` : 'Sortir ›'}</small></button>`).join('') || '<div class="empty">Aucun véhicule configuré.</div>'}</div>
    <div class="err" style="margin-top:.6rem">${esc(err)}</div><div class="actions"><button class="btn" data-gar="close">Fermer</button></div>`;
}
$('#garage').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-veh]'))) { b.classList.add('loading'); const r = await post('garageSpawn', { i: Number(b.dataset.veh) }); if (r && r.error) garageRender(GAR, r.error); return; }
  if (e.target.closest('[data-gar]')) post('close', { ui: 'garage' });
});

let offerTimer = null;
function showOffer(o) {
  const w = $('#offer');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre le garage au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-offer="no">Refuser</button><button class="btn primary block" data-offer="yes">Accepter</button></div>
    <div class="countdown"><i id="offerBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (o.timeout || 30) * 1000, end = Date.now() + total;
  clearInterval(offerTimer);
  offerTimer = setInterval(() => { const left = end - Date.now(); const bar = $('#offerBar'); if (bar) bar.style.width = `${Math.max(0, left / total * 100)}%`; if (left <= 0) clearInterval(offerTimer); }, 200);
}
$('#offer').addEventListener('click', (e) => { const b = e.target.closest('[data-offer]'); if (b) post('offerAnswer', { accept: b.dataset.offer === 'yes' }); });

let progT = null;
function progressShow(m) {
  const el = $('#progress');
  clearInterval(progT);
  if (!m.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  el.innerHTML = `<div class="lbl"><span>${esc(m.label)}</span><small><span class="kbd">X</span> annuler</small></div><div class="bar"><i></i></div>`;
  const start = Date.now(), total = m.duration || 1;
  progT = setInterval(() => { const i = $('#progress .bar i'); if (i) i.style.width = `${Math.min(100, (Date.now() - start) / total * 100)}%`; }, 60);
}

/* =====================================================================
   Messages du jeu
   ===================================================================== */
function applyCfg(cfg) { if (!cfg) return; APP.cfg = cfg; APP.statuses = cfg.statuses || []; APP.towStatuses = cfg.towStatuses || {}; }
const show = (sel, on) => $(sel).classList.toggle('hidden', !on);

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'state': APP.st = m.state; if (m.state && m.state.agency && APP.cfg) APP.cfg.job = m.state.agency; if (window.Tablet) Tablet.onState(m.state); return;
    case 'f6': if (m.show) { F6.view = 'main'; F6.data = m; show('#f6', true); f6Draw(); } else show('#f6', false); return;
    case 'f6Data':
      if (!$('#f6').classList.contains('hidden')) { const f = document.activeElement && document.activeElement.closest('#f6 select'); F6.data = m; if (!f) f6Draw(); }
      return;
    case 'notify': return showNotif(m);
    case 'alertClosed': case 'alertDismiss': return removeNotif(m.kind, m.id);
    case 'alertsClear': [...notifEls.keys()].forEach((k) => { const [kind, id] = k.split(':'); removeNotif(kind, id); }); return;
    case 'workshop': if (m.show) wsOpen(m); else show('#workshop', false); return;
    case 'install': return installRender(m);
    case 'minigame': if (m.show) MG.open(m); else MG.close(m.id); return;
    case 'watch': return watchRender(m.data || {});
    case 'handover': return handoverRender(m);
    case 'wsQuote': if (W.quote && m.quote && W.quote.uid === m.quote.uid) { W.quote = m.quote; wsRender(); } return;
    case 'quoteOffer': if (m.show) { offerQ = m.quote; quoteOfferRender(m.quote, m.timeout); } else { show('#quoteOffer', false); offerQ = null; clearInterval(offerT); } return;
    case 'svcQuote':
      if (m.show) { Object.assign(SV, { items: m.items || [], customers: m.customers || [], vehicle: m.vehicle, sel: {} }); if (m.suggest && SV.items.find((i) => i.code === m.suggest && !i.locked)) SV.sel[m.suggest] = 1; svcRender(); show('#svcQuote', true); }
      else show('#svcQuote', false);
      return;
    case 'garage': if (m.show) { GAR = m.list || []; garageRender(GAR); show('#garage', true); } else show('#garage', false); return;
    case 'progress': return progressShow(m);
    case 'offer': if (m.show) showOffer(m.offer); else { show('#offer', false); clearInterval(offerTimer); } return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'closeAll': ['#f6', '#workshop', '#quoteOffer', '#svcQuote', '#garage', '#offer', '#confirm'].forEach((s) => show(s, false)); MG.cancel(); if (window.Tablet) Tablet.hide(); return;
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (MG.cur) return MG.cancel();   // mini-jeu : Échap annule (rien n'est posé)
  if (!$('#confirm').classList.contains('hidden')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of [['#workshop', 'workshop'], ['#quoteOffer', 'quoteOffer'], ['#svcQuote', 'svcQuote'], ['#garage', 'garage'], ['#offer', 'offer']]) {
    if (!$(sel).classList.contains('hidden')) return post('close', { ui });
  }
  if (!$('#f6').classList.contains('hidden')) { if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); } return post('close', { ui: 'f6' }); }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});

/* ---------- Atelier : caméra (clic droit maintenu + glisser, molette pour zoomer) ---------- */
(() => {
  let drag = false, acc = { dx: 0, dy: 0, zoom: 0 }, timer = null;
  const open = () => !$('#workshop').classList.contains('hidden');
  const flush = () => { timer = null; if (!acc.dx && !acc.dy && !acc.zoom) return; const a = acc; acc = { dx: 0, dy: 0, zoom: 0 }; post('wsCam', a); };
  const queue = () => { if (!timer) timer = setTimeout(flush, 33); };
  document.addEventListener('contextmenu', (e) => { if (open()) e.preventDefault(); });
  document.addEventListener('mousedown', (e) => { if (open() && e.button === 2) { drag = true; document.body.classList.add('cam-drag'); e.preventDefault(); } });
  document.addEventListener('mouseup', (e) => { if (e.button === 2 && drag) { drag = false; document.body.classList.remove('cam-drag'); } });
  document.addEventListener('mousemove', (e) => {
    if (!drag || !open()) return;
    if (!(e.buttons & 2)) { drag = false; document.body.classList.remove('cam-drag'); return; }
    acc.dx += e.movementX; acc.dy += e.movementY; queue();
  });
  document.addEventListener('wheel', (e) => {
    if (!open() || e.target.closest('#workshop')) return;   // molette dans le panneau = défilement normal
    acc.zoom += e.deltaY > 0 ? 0.6 : -0.6; queue();
  }, { passive: true });
  document.addEventListener('dblclick', (e) => { if (open() && !e.target.closest('#workshop')) post('wsCam', { reset: true }); });
})();
