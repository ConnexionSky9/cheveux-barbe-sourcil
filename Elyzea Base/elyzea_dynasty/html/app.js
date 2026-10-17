/* =====================================================================
   ELYZEA DYNASTY 8 - interface : F6, porte, sonnette, invitation et offre,
   zone de gestion (cercle bleu), recrutement. Les montants affichés viennent
   du serveur, qui recalcule tout avant de débiter.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_dynasty';
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

const APP = { cfg: null, st: null, statuses: [], props: {}, cats: { apartment: 'Appartement', house: 'Maison', villa: 'Villa', garage: 'Garage' } };
const CAT_ICO = { apartment: '🏢', house: '🏠', villa: '🏡', garage: '🚗' };
const propStatus = (s) => (APP.props[s] || { label: s, color: '#94a3b8' });
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

/* =====================================================================
   Menu F6
   ===================================================================== */
const F6 = { view: 'main', data: null };
function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {}, p = st.perms || {}, duty = !!st.duty, t = d.times, live = (d.timesAt || 0) / 1000;
  const head = `<div class="f6-head"><div class="top"><span class="badge">DYNASTY 8</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Agent')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>
      ${t ? `<div class="times"><div><b>${dur(t.session + (duty ? live : 0))}</b><small>Session</small></div><div><b>${dur(t.unpaid + (duty ? live : 0))}</b><small>Non payé</small></div>
        <div><b>${dur(t.total + (duty ? live : 0))}</b><small>Total</small></div></div>` : ''}`;
  const item = (id, ico, label, sub, o = {}) => `<button class="f6-item ${o.cls || ''}" data-f6="${id}" ${o.disabled ? 'disabled' : ''} ${o.attrs || ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${o.chev ? '<span class="chev">›</span>' : ''}</button>`;
  const back = (l) => `<button class="f6-back" data-f6="back">‹ ${l}</button>`;
  if (F6.view === 'status') {
    return head + back('Statut') + '<div class="f6-list">' + APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span>
      <span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
  }
  if (F6.view === 'visit') {
    const v = d.visit;
    return head + back('Visite commerciale') + `<div class="f6-list">${v ? `<div class="section-label">${esc(v.name)}</div>
      ${(d.near || []).map((n) => item('invite', '👤', `Inviter · ID ${n.id}`, `à ${n.distance} m`, { attrs: `data-target="${n.id}"` })).join('') || '<div class="faint" style="padding:.6rem .8rem;font-size:.8rem">Aucun client à moins de 6 m.</div>'}
      ${item('endVisit', '⏹', 'Terminer la visite', 'Les visiteurs sortent', { cls: 'duty-off' })}` : '<div class="faint" style="padding:.8rem">Aucune visite en cours. Lancez-en une depuis la tablette (bien disponible › Faire visiter).</div>'}</div>`;
  }
  let b = head + '<div class="f6-list">';
  if (p.duty) b += duty ? item('dutyOff', '⏻', 'Terminer mon service', 'Votre temps est enregistré', { cls: 'duty-off' }) : item('dutyOn', '⏻', 'Prendre mon service', '', { cls: 'duty-on' });
  if (duty) b += item('status', '◉', 'Statut', esc(statusOf(st.status).label), { chev: true });
  if (p.tablet) {
    b += '<div class="section-label">Immobilier</div>';
    b += item('tab', '📊', 'Tableau de bord', 'Ventes, locations, recettes', { attrs: 'data-page="dashboard"' });
    b += item('tab', '🟢', 'Biens disponibles', 'Vendre, louer, faire visiter', { attrs: 'data-page="available"' });
    b += item('tab', '🟠', 'Biens loués / vendus', 'Occupants, contrats, échéances', { attrs: 'data-page="unavailable"' });
    b += item('tab', '🗺️', 'Carte', 'Disponibilités', { attrs: 'data-page="map"' });
  }
  if (duty && p.visits) b += '<div class="section-label">Commercial</div>' + item('visit', '🔑', 'Visite commerciale', d.visit ? esc(d.visit.name) : 'Aucune en cours', { chev: true });
  if (p.properties_view) b += item('tab', '📄', 'Contrats et transactions', '', { attrs: 'data-page="contracts"' });
  if (p.direction) b += item('tab', '🏛️', 'Direction', 'Personnel, finance', { attrs: 'data-page="employees"' });
  b += '</div><div class="f6-foot"><span><span class="kbd">E</span> porte / garage</span><span><span class="kbd">Échap</span> fermer</span></div>';
  return b;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }
$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if (!(b = e.target.closest('[data-f6]'))) return;
  const a = b.dataset.f6;
  if (a === 'back') { F6.view = 'main'; return f6Draw(); }
  if (a === 'status' || a === 'visit') { F6.view = a; return f6Draw(); }
  if (a === 'dutyOn' || a === 'dutyOff') { F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw(); }
  if (a === 'invite') { F6.data = await post('f6', { action: 'invite', target: b.dataset.target }); return f6Draw(); }
  if (a === 'endVisit') { if (!(await confirmBox('Terminer la visite ?', 'Les visiteurs encore à l\'intérieur sortent.', 'Terminer'))) return; F6.data = await post('f6', { action: 'endVisit' }); F6.view = 'main'; return f6Draw(); }
  if (a === 'tab') return post('f6', { action: 'tablet', page: b.dataset.page });
});

/* =====================================================================
   Sonnette (résident) : Accepter / Refuser, la première réponse compte
   ===================================================================== */
const bells = new Map();
function showBell(b) {
  const el = document.createElement('div');
  el.className = 'notif bell';
  el.style.setProperty('--c', '#facc15');
  el.innerHTML = `<div class="lvl-tag">Sonnette · ${new Date(b.t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}</div>
    <h3>${esc(b.visitor)} sonne</h3><div class="meta">${esc(b.property)}</div>
    <div class="acts"><button class="btn danger small" data-bell="no">Refuser</button><button class="btn primary small" data-bell="yes">Ouvrir</button></div><i class="bar"></i>`;
  el.querySelector('.bar').style.animationDuration = `${(b.timeout || 45) * 1000}ms`;
  el.addEventListener('click', (e) => {
    const x = e.target.closest('[data-bell]');
    if (!x) return;
    post('bellAnswer', { id: b.id, accept: x.dataset.bell === 'yes' });
    closeBell(b.id);
  });
  $('#notifs').prepend(el);
  bells.set(b.id, el);
  setTimeout(() => closeBell(b.id), (b.timeout || 45) * 1000);
}
function closeBell(id) { const el = bells.get(id); if (!el) return; bells.delete(id); el.classList.add('out'); setTimeout(() => el.remove(), 260); }

/* =====================================================================
   Porte : entrer, code, sonner (les droits sont vérifiés par le serveur)
   ===================================================================== */
function doorRender(d) {
  const w = $('#door');
  const occupied = d.occupied;
  $('.modal', w).innerHTML = `<div class="prop-head"><span class="ico">${CAT_ICO[d.category] || '🏠'}</span><div><h2>${esc(d.name)}</h2><small>${esc(d.address || '')}${d.area === 'garage' ? ' · Garage' : ''}</small></div></div>
    <div class="door-actions">
      ${d.canEnter ? '<button class="btn primary block" data-door="enter">🚪 Entrer</button>' : ''}
      ${d.area === 'home' && d.hasCode ? `<div class="code-row"><input class="input" id="doorCode" maxlength="8" inputmode="numeric" placeholder="Code de la porte"><button class="btn" data-door="code">Valider</button></div>` : ''}
      ${d.area === 'home' && occupied ? '<button class="btn block" data-door="bell">🔔 Sonner à la porte</button>' : ''}
      ${!d.canEnter && !occupied && d.area === 'home' ? `<p class="lead" style="margin:0">${d.status === 'available' ? 'Ce bien est disponible : contactez Dynasty 8 pour une visite.' : 'Porte fermée.'}</p>` : ''}
      ${d.canVisit ? '<p class="faint" style="font-size:.78rem">Agent : lancez une visite depuis la tablette pour entrer avec un client.</p>' : ''}
      ${d.staff ? '<button class="btn small" data-door="staff">🛠️ Entrer (staff)</button>' : ''}
    </div>
    <div class="actions"><button class="btn" data-door="close">Fermer</button></div>`;
  w.classList.remove('hidden');
  setTimeout(() => { const i = $('#doorCode'); if (i) i.focus(); }, 40);
}
$('#door').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-door]');
  if (!b) return;
  const a = b.dataset.door;
  if (a === 'close') return post('close', { ui: 'door' });
  const r = await post('doorAction', { do_: a, code: ($('#doorCode') || {}).value });
  if (a === 'code' && r.error) { toast(r.error, false); const i = $('#doorCode'); if (i) { i.value = ''; i.focus(); } }
});
$('#door').addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.id === 'doorCode') $('[data-door="code"]').click(); });

/* =====================================================================
   Invitation de visite / offre de vente ou location (client)
   ===================================================================== */
let promptTimer = null;
function promptRender(kind, d) {
  const w = $('#prompt');
  let body;
  if (kind === 'invite') {
    body = `<div class="eyebrow">Dynasty 8 · Visite</div><h2>${esc(d.property)}</h2>
      <p class="lead"><b>${esc(d.agent)}</b> vous propose de visiter ce bien. La visite ne donne aucun droit (ni clé, ni coffre).</p>`;
  } else {
    body = `<div class="eyebrow">Dynasty 8 · ${d.kind === 'sale' ? 'Achat' : 'Location'}</div><h2>${esc(d.property)}</h2>
      <div class="recap"><span>Adresse</span><b>${esc(d.address || '—')}</b><span>Catégorie</span><b>${esc(d.category || '')}</b>
        <span>Client</span><b>${esc(d.client)}</b><span>Agent</span><b>${esc(d.agent)}</b>
        ${d.kind === 'rent' ? `<span>Durée</span><b>${d.days} jour(s) · ${money(d.rate)} / jour</b>` : ''}
        ${d.garage ? `<span>Garage</span><b>${d.garage} place(s)</b>` : ''}
        <span>Paiement</span><b>${d.method === 'cash' ? 'Espèces' : 'Banque'}</b><span>Total</span><b class="total">${money(d.price)}</b></div>
      <p class="lead">En acceptant, le total est prélevé tout de suite. ${d.kind === 'sale' ? 'Le bien devient votre propriété.' : 'Vous pourrez prolonger depuis la zone de gestion.'}</p>`;
  }
  $('.modal', w).innerHTML = `${body}<div class="actions" style="justify-content:stretch"><button class="btn danger block" data-pr="no">Refuser</button>
    <button class="btn primary block" data-pr="yes">${kind === 'invite' ? 'Visiter' : 'Signer et payer'}</button></div><div class="countdown"><i id="prBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (d.timeout || 30) * 1000, end = Date.now() + total;
  clearInterval(promptTimer);
  promptTimer = setInterval(() => { const l = end - Date.now(); const bar = $('#prBar'); if (bar) bar.style.width = `${Math.max(0, l / total * 100)}%`; if (l <= 0) clearInterval(promptTimer); }, 200);
}
$('#prompt').addEventListener('click', (e) => { const b = e.target.closest('[data-pr]'); if (b) post('promptAnswer', { accept: b.dataset.pr === 'yes' }); });

/* =====================================================================
   Zone de gestion (cercle bleu)
   ===================================================================== */
const M = { d: null, tab: 'contract', ext: null };
function manageRender() {
  const d = M.d;
  if (!d) return;
  const c = d.contract, r = d.rights || {};
  const tabs = [['contract', 'Contrat']];
  if (r.manage) tabs.push(['access', 'Code et accès']);
  if (r.holder) tabs.push(['tenants', 'Locataires']);
  if (r.manage && d.deco) tabs.push(['deco', 'Décoration']);
  if (!tabs.find((t) => t[0] === M.tab)) M.tab = 'contract';
  let main = '';
  if (M.tab === 'contract') {
    main = `<div class="recap"><span>Type</span><b>${c.kind === 'sale' ? 'Propriété (vendu)' : 'Location'}</b><span>Titulaire</span><b>${esc(c.holder)}</b>
      <span>Début</span><b>${fmtTime(c.starts)}</b>${c.kind === 'rent' ? `<span>Fin</span><b>${fmtTime(c.ends)}</b><span>Temps restant</span><b>${left(c.remaining)}</b>
      <span>Durée payée</span><b>${c.days} jour(s)</b>` : ''}<span>Montant payé</span><b>${money(c.paid)}</b><span>Contrat</span><b class="mono">${esc(c.uid)}</b>
      <span>Votre rôle</span><b>${d.role === 'holder' ? 'Titulaire' : 'Locataire ajouté'}</b></div>
      ${c.kind === 'rent' && r.holder ? `<h3 style="margin:1rem 0 .5rem">Prolonger la location</h3>
        <div class="form-grid" style="grid-template-columns:1fr 1fr auto;align-items:end">
          <label class="field"><span>Jours (1 à ${d.rent.maxDays})</span><input class="input" type="number" min="1" max="${d.rent.maxDays}" id="extDays" value="${M.ext ? M.ext.days : 7}"></label>
          <label class="field"><span>Paiement</span><select class="input" id="extMethod"><option value="bank">Banque</option><option value="cash">Espèces</option></select></label>
          <button class="btn" data-mg="extQuote">Calculer</button></div>
        ${M.ext ? `<div class="recap"><span>Jours</span><b>${M.ext.days}</b><span>Tarif</span><b>${money(M.ext.rate)} / jour</b><span>Total</span><b class="total">${money(M.ext.total)}</b></div>
          <div class="actions"><button class="btn primary" data-mg="extend">Payer et prolonger</button></div>` : `<p class="faint" style="font-size:.8rem;margin-top:.5rem">Tarif de prolongation : ${money(c.extendRate)} / jour.</p>`}` : ''}`;
  } else if (M.tab === 'access') {
    main = `<p class="lead">Les résidents entrent toujours sans code. Le code donne seulement l'entrée (ni coffre, ni gestion).</p>
      <div class="code-row" style="max-width:24rem"><input class="input" id="mgCode" maxlength="8" inputmode="numeric" placeholder="${d.hasCode ? 'Nouveau code' : 'Aucun code'}" value="${esc(d.code || '')}">
        <button class="btn primary" data-mg="setCode">Enregistrer</button>${d.hasCode ? '<button class="btn danger" data-mg="clearCode">Supprimer</button>' : ''}</div>`;
  } else if (M.tab === 'tenants') {
    main = `${d.tenants.map((t) => `<div class="tenant"><div class="main"><b>${esc(t.name)}</b><br>
        <label><input type="checkbox" class="check" data-tr="stash" data-cid="${esc(t.cid)}" ${t.stash ? 'checked' : ''}> Coffre</label>
        <label><input type="checkbox" class="check" data-tr="manage" data-cid="${esc(t.cid)}" ${t.manage ? 'checked' : ''}> Gestion</label>
        <label><input type="checkbox" class="check" data-tr="garage" data-cid="${esc(t.cid)}" ${t.garage ? 'checked' : ''}> Garage</label></div>
        <button class="btn small danger" data-mg="removeTenant" data-cid="${esc(t.cid)}">Retirer</button></div>`).join('') || '<div class="empty">Aucun locataire ajouté.</div>'}
      <h3 style="margin:1rem 0 .5rem">Ajouter une personne à côté de vous</h3>
      ${d.near.length ? `<div class="form-grid" style="grid-template-columns:1fr auto;align-items:end"><label class="field"><span>Personne</span><select class="input" id="mgNear">${d.near.map((n) => `<option value="${n.id}">${esc(n.name)} · ID ${n.id}</option>`).join('')}</select></label>
        <button class="btn primary" data-mg="addTenant">Ajouter</button></div>
        <div style="margin-top:.5rem"><label class="extra"><input type="checkbox" class="check" id="mgStash"> Coffre</label><label class="extra"><input type="checkbox" class="check" id="mgManage"> Gestion</label>
          <label class="extra"><input type="checkbox" class="check" id="mgGarage"> Garage</label></div>` : '<p class="faint">Aucune personne à moins de 5 m.</p>'}
      <p class="faint" style="font-size:.76rem;margin-top:.6rem">Un locataire ajouté entre sans code. Coffre, gestion et garage ne sont donnés que si vous les cochez.</p>`;
  } else if (M.tab === 'deco') {
    const dc = d.deco;
    const cats = [...new Set(dc.catalog.map((x) => x.cat))];
    main = `<p class="lead">${dc.placed} / ${dc.limit} objet(s) placés. Choisissez un objet : il apparaît devant vous, placez-le avec les flèches, Pg.Préc/Pg.Suiv, Q/E, G (au sol), Entrée pour valider.</p>
      ${dc.reserve.length ? `<h3 style="margin:.4rem 0">En réserve (à replacer)</h3><div class="deco-grid" style="margin-bottom:.8rem">${dc.reserve.map((o) => `<button class="deco-item" data-deco-move="${o.id}" data-model="${esc(o.model)}">${esc(o.model)}<small>Replacer</small></button>`).join('')}</div>` : ''}
      ${cats.map((cat) => `<h3 style="margin:.6rem 0 .4rem;font-size:.8rem;color:var(--faint);text-transform:uppercase;letter-spacing:.08em">${esc(cat)}</h3>
        <div class="deco-grid">${dc.catalog.filter((x) => x.cat === cat).map((x) => `<button class="deco-item" data-deco="${esc(x.model)}" ${dc.placed >= dc.limit ? 'disabled' : ''}>${esc(x.label)}<small class="mono">${esc(x.model)}</small></button>`).join('')}</div>`).join('')}
      <p class="faint" style="font-size:.76rem;margin-top:.8rem">Déplacer ou retirer un objet déjà posé : liste ci-dessous.</p>
      <div id="mgPlaced"></div>`;
  }
  $('#manage .modal').innerHTML = `<div class="prop-head"><span class="ico">🔵</span><div><h2>${esc(d.prop.name)}</h2><small>${esc(d.prop.address || '')} · ${esc(d.prop.category)}</small></div>
      <span style="flex:1"></span><button class="icon-btn" data-mg="close">✕</button></div>
    <div class="mgr-tabs">${tabs.map(([k, l]) => `<button class="${M.tab === k ? 'on' : ''}" data-mgt="${k}">${l}</button>`).join('')}</div>${main}`;
  if (M.tab === 'deco') loadPlaced();
}
async function loadPlaced() {
  const r = await pub('decoList', { pid: M.d.prop.id });
  const el = $('#mgPlaced');
  if (!el) return;
  el.innerHTML = (r.list || []).map((o) => `<div class="tenant"><div class="main mono" style="font-size:.82rem">${esc(o.model)}</div>
    <button class="btn small" data-deco-move="${o.id}" data-model="${esc(o.model)}">Déplacer</button><button class="btn small danger" data-deco-del="${o.id}">Retirer</button></div>`).join('') || '<div class="faint" style="font-size:.8rem">Aucun objet posé.</div>';
}
async function manageReload() { const r = await post('manageRefresh'); if (!r.error) { M.d = r; manageRender(); } }
$('#manage').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-mgt]'))) { M.tab = b.dataset.mgt; return manageRender(); }
  if ((b = e.target.closest('[data-deco]'))) return post('decoStart', { model: b.dataset.deco });
  if ((b = e.target.closest('[data-deco-move]'))) return post('decoStart', { model: b.dataset.model, id: Number(b.dataset.decoMove) });
  if ((b = e.target.closest('[data-deco-del]'))) {
    if (!(await confirmBox('Retirer cet objet ?', 'Il est supprimé de votre logement.', 'Retirer', true))) return;
    await act(pub('decoDelete', { pid: M.d.prop.id, id: Number(b.dataset.decoDel) }), b);
    return manageReload();
  }
  if (!(b = e.target.closest('[data-mg]'))) return;
  const a = b.dataset.mg, pid = M.d.prop.id;
  if (a === 'close') return post('close', { ui: 'manage' });
  if (a === 'extQuote') {
    const r = await pub('extend', { pid, days: Number($('#extDays').value), quote: true });
    if (r.error) return toast(r.error, false);
    M.ext = r.quote; return manageRender();
  }
  if (a === 'extend') {
    const method = ($('#extMethod') || {}).value || 'bank';
    if (!(await confirmBox('Prolonger la location ?', `${M.ext.days} jour(s) · <b>${money(M.ext.total)}</b> prélevés (${method === 'cash' ? 'espèces' : 'banque'}).`, 'Payer'))) return;
    const r = await act(pub('extend', { pid, days: M.ext.days, method }), b);
    if (r.ok) { M.ext = null; return manageReload(); }
    return;
  }
  if (a === 'setCode' || a === 'clearCode') {
    const code = a === 'clearCode' ? '' : String(($('#mgCode') || {}).value || '');
    const r = await act(pub('setCode', { pid, code }), b);
    if (r.ok) return manageReload();
    return;
  }
  if (a === 'addTenant') {
    const target = Number(($('#mgNear') || {}).value);
    const r = await act(pub('addTenant', { pid, target, stash: $('#mgStash').checked, manage: $('#mgManage').checked, garage: $('#mgGarage').checked }), b);
    if (r.ok) return manageReload();
    return;
  }
  if (a === 'removeTenant') {
    if (!(await confirmBox('Retirer l\'accès ?', 'Cette personne ne pourra plus entrer sans code.', 'Retirer', true))) return;
    const r = await act(pub('tenantRights', { pid, cid: b.dataset.cid, remove: true }), b);
    if (r.ok) return manageReload();
  }
});
$('#manage').addEventListener('change', async (e) => {
  const t = e.target;
  if (!t.dataset.tr) return;
  const cid = t.dataset.cid;
  const get = (k) => { const el = $(`[data-tr="${k}"][data-cid="${CSS.escape(cid)}"]`); return el ? el.checked : false; };
  await act(pub('tenantRights', { pid: M.d.prop.id, cid, stash: get('stash'), manage: get('manage'), garage: get('garage') }));
});

/* =====================================================================
   Recrutement
   ===================================================================== */
let offerTimer = null;
function showOffer(o) {
  const w = $('#offer');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre Dynasty 8 au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
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
function applyCfg(cfg) {
  if (!cfg) return;
  APP.cfg = cfg; APP.statuses = cfg.statuses || []; APP.props = cfg.propStatuses || {}; APP.cats = cfg.categories || APP.cats;
}
const show = (sel, on) => $(sel).classList.toggle('hidden', !on);

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'state': APP.st = m.state; if (m.state && m.state.agency && APP.cfg) APP.cfg.job = m.state.agency; if (window.Tablet) Tablet.onState(m.state); return;
    case 'f6': if (m.show) { F6.view = 'main'; F6.data = m; show('#f6', true); f6Draw(); } else show('#f6', false); return;
    case 'f6Data': if (!$('#f6').classList.contains('hidden')) { F6.data = m; f6Draw(); } return;
    case 'bell': return showBell(m.bell);
    case 'bellClosed': return closeBell(m.id);
    case 'door': if (m.show) doorRender(m.data); else show('#door', false); return;
    case 'prompt': if (m.show) promptRender(m.kind, m.data); else { show('#prompt', false); clearInterval(promptTimer); } return;
    case 'manage': if (m.show) { M.d = m.data; M.ext = null; show('#manage', true); manageRender(); } else show('#manage', false); return;
    case 'visit': if (F6.data) { F6.data.visit = m.visit; if (!$('#f6').classList.contains('hidden')) f6Draw(); } return;
    case 'offer': if (m.show) showOffer(m.offer); else { show('#offer', false); clearInterval(offerTimer); } return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'admin': if (window.Admin) { if (m.show) Admin.open(m.data, m.preview); else Admin.hide(); } return;
    case 'closeAll':
      ['#f6', '#door', '#manage', '#prompt', '#offer', '#confirm'].forEach((s) => show(s, false));
      if (window.Admin) Admin.hide(); if (window.Tablet) Tablet.hide(); return;
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (!$('#confirm').classList.contains('hidden')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of [['#door', 'door'], ['#manage', 'manage'], ['#prompt', 'prompt'], ['#offer', 'offer']]) {
    if (!$(sel).classList.contains('hidden')) return post('close', { ui });
  }
  if (window.Admin && Admin.isOpen()) return post('close', { ui: 'admin' });
  if (!$('#f6').classList.contains('hidden')) { if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); } return post('close', { ui: 'f6' }); }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
