/* =====================================================================
   ELYZEA BOÎTE DE NUIT - interface : socle, menu F6, recrutement, messages du jeu.
   Les montants affichés viennent du serveur, qui recalcule tout avant de débiter.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_club';
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


/* =====================================================================
   Menu F6 (employés)
   ===================================================================== */
const F6 = { view: 'main', data: null, check: null };
function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {}, p = st.perms || {}, duty = !!st.duty, t = d.times, live = (d.timesAt || 0) / 1000;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc((st.shopName || 'Boîte de nuit').toUpperCase())}</span>
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
  if (F6.view === 'check') {
    const c = F6.check || {}, x = c.target;
    let b = head + '<button class="f6-back" data-f6="back">‹ Contrôle à l\'entrée</button><div class="f6-list">';
    if (!x) return b + `<div class="empty">${esc(c.error || 'Personne à proximité.')}</div></div>`;
    const band = x.band ? `<span class="pill on">Bracelet jusqu'à ${fmtTime(x.band)}</span>` : '<span class="pill off">Pas de bracelet</span>';
    b += `<div class="check-card"><b>${esc(x.name)}</b><small>ID ${x.id}</small><div class="chips">${x.staff ? '<span class="pill on">Personnel</span>' : band}
      ${x.vip ? '<span class="pill warn">VIP</span>' : ''}${x.banned ? `<span class="pill bad">Liste noire${x.banned.reason ? ` · ${esc(x.banned.reason)}` : ''}</span>` : ''}</div></div>`;
    b += item('recheck', '🔎', 'Contrôler à nouveau', 'Personne la plus proche');
    if (!x.staff) {
      b += item('kick', '🚪', 'Raccompagner à la sortie', 'Retire le bracelet', { attrs: `data-t="${x.id}"` });
      if (p.lists && !x.vip) b += item('vip', '⭐', 'Ajouter à la liste VIP', 'Entrée gratuite', { attrs: `data-t="${x.id}"` });
      if (p.lists && !x.banned) b += item('ban', '⛔', 'Liste noire', 'Interdit d\'entrée (durée au choix)', { attrs: `data-t="${x.id}"`, cls: 'duty-off' });
    }
    return b + '</div>';
  }
  if (F6.view === 'place') {
    const models = (APP.cfg && APP.cfg.music && APP.cfg.music.models) || [];
    return head + '<button class="f6-back" data-f6="back">‹ Poser une enceinte</button><div class="f6-list">'
      + models.map((m) => item('placeModel', m.model === 'none' ? '📍' : '🔊', esc(m.label), m.model === 'none' ? 'Point de son sans objet' : esc(m.model), { attrs: `data-model="${esc(m.model)}"` })).join('')
      + '</div><div class="f6-foot"><span>L\'enceinte suit le regard : clic gauche pour poser</span></div>';
  }
  let b = head + '<div class="f6-list">';
  if (st.open === false) b += '<div class="warn-box" style="margin:.5rem">Boîte désactivée par le staff : bar, entrée et musique suspendus.</div>';
  if (p.duty) b += duty ? item('dutyOff', '⏻', 'Terminer mon service', 'Votre temps est enregistré', { cls: 'duty-off' }) : item('dutyOn', '⏻', 'Prendre mon service', '', { cls: 'duty-on' });
  if (duty) b += item('status', '◉', 'Statut', esc(statusOf(st.status).label), { chev: true });
  if (p.bar) { b += '<div class="section-label">Bar</div>'; b += item('bar', '🍸', 'Servir au bar', 'Derrière le comptoir'); }
  if (p.door) { b += '<div class="section-label">Entrée</div>'; b += item('check', '🔎', 'Contrôler la personne proche', 'Bracelet, VIP, liste noire'); }
  if (p.music || p.speakers) {
    b += '<div class="section-label">Musique</div>';
    if (p.music) b += item('dj', '🎧', 'Platine DJ', 'Playlist, lecture, volume (près des enceintes)');
    if (p.speakers) b += item('place', '🔊', 'Poser une enceinte', 'Elle appartient à la boîte', { chev: true });
  }
  if (p.tablet) {
    b += '<div class="section-label">Tablette</div>';
    b += item('tab', '📊', 'Tableau de bord', 'Ventes, entrées, équipe', { attrs: 'data-page="dashboard"' });
    b += item('tab', '🍸', 'Carte, prix et stock', '', { attrs: 'data-page="bar"' });
    b += item('tab', '🎟️', 'Entrée et listes', 'Ouvrir, prix, annonce, VIP, liste noire', { attrs: 'data-page="entry"' });
    b += item('tab', '🎵', 'Musique', 'Playlist et enceintes', { attrs: 'data-page="music"' });
    if (p.direction) b += item('tab', '🏛️', 'Direction', 'Personnel, grades, permissions', { attrs: 'data-page="employees"' });
    if (p.finance) b += item('tab', '💰', 'Finances', 'Compte, salaires, commissions', { attrs: 'data-page="finance"' });
  }
  b += '</div><div class="f6-foot"><span><span class="kbd">E</span> bar / entrée / enceinte</span><span><span class="kbd">Échap</span> fermer</span></div>';
  return b;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }
$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if (!(b = e.target.closest('[data-f6]'))) return;
  const a = b.dataset.f6;
  if (a === 'back') { F6.view = 'main'; return f6Draw(); }
  if (a === 'status' || a === 'place') { F6.view = a; return f6Draw(); }
  if (a === 'dutyOn' || a === 'dutyOff') { F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw(); }
  if (a === 'bar' || a === 'dj') return post('f6', { action: a });
  if (a === 'check' || a === 'recheck') { F6.check = await post('f6', { action: 'doorCheck' }); F6.view = 'check'; return f6Draw(); }
  if (a === 'kick') { await post('f6', { action: 'doorKick', data: { target: Number(b.dataset.t) } }); F6.check = await post('f6', { action: 'doorCheck' }); return f6Draw(); }
  if (a === 'vip') { await post('f6', { action: 'listAdd', data: { kind: 'vip', target: Number(b.dataset.t) } }); F6.check = await post('f6', { action: 'doorCheck' }); return f6Draw(); }
  if (a === 'ban') {
    const v = await confirmBox('Liste noire', 'La personne ne pourra plus entrer et son bracelet est retiré.', 'Interdire', true,
      `<div class="stack" style="margin-top:.6rem"><label class="field"><span>Raison</span><input class="input" maxlength="160" data-cfv="reason"></label>
       <label class="field"><span>Durée en jours (0 = définitif)</span><input class="input" type="number" min="0" max="365" value="0" data-cfv="days"></label></div>`);
    if (!v) return;
    await post('f6', { action: 'listAdd', data: { kind: 'ban', target: Number(b.dataset.t), reason: v.reason, days: Number(v.days || 0) } });
    F6.check = await post('f6', { action: 'doorCheck' });
    return f6Draw();
  }
  if (a === 'placeModel') return post('f6', { action: 'place', model: b.dataset.model });
  if (a === 'tab') return post('f6', { action: 'tablet', page: b.dataset.page });
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
    case 'f6Data': if (!$('#f6').classList.contains('hidden') && F6.view === 'main') { F6.data = m; f6Draw(); } return;
    case 'bar': return Club.bar(m);
    case 'barOffer': return Club.barOffer(m);
    case 'card': return Club.card(m);
    case 'entry': return Club.entry(m);
    case 'announce': return Club.announce(m.data || {});
    case 'audio': return ClubAudio.apply(m.list || []);
    case 'dj': if (m.show) Dj.open(m.data); else Dj.hide(); return;
    case 'offer': if (m.show) showOffer(m.offer); else { show('#offer', false); clearInterval(offerTimer); } return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'admin': if (window.Admin) { if (m.show) Admin.open(m.data); else Admin.hide(); } return;
    case 'closeAll':
      ['#f6', '#bar', '#barOffer', '#card', '#entry', '#offer', '#confirm'].forEach((s) => show(s, false));
      Dj.hide(); if (window.Admin) Admin.hide(); if (window.Tablet) Tablet.hide(); return;
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (!$('#confirm').classList.contains('hidden')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of [['#barOffer', 'barOffer'], ['#offer', 'offer'], ['#bar', 'bar'], ['#card', 'card'], ['#entry', 'entry'], ['#dj', 'dj']]) {
    if (!$(sel).classList.contains('hidden')) return post('close', { ui });
  }
  if (window.Admin && Admin.isOpen()) return post('close', { ui: 'admin' });
  if (!$('#f6').classList.contains('hidden')) { if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); } return post('close', { ui: 'f6' }); }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
