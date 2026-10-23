/* =====================================================================
   ELYZEA EMS - interface : socle, F6, appels, examen, facture, PPA, garage,
   coma, progression, recrutement. Le serveur vérifie chaque action.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_ems';
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const fmtTime = (t) => { if (!t) return '—'; const d = new Date(t * 1000); return d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); };
const ago = (t) => { const m = Math.floor((Date.now() / 1000 - t) / 60); return m < 1 ? 'à l\'instant' : m < 60 ? `il y a ${m} min` : `il y a ${Math.floor(m / 60)} h`; };
const dur = (s) => { s = Math.max(0, Math.floor(Number(s) || 0)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return `${h}h${String(m).padStart(2, '0')}`; };
const clock = (s) => { s = Math.max(0, Math.floor(s)); return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };

async function post(name, data = {}) {
  if (!IN_GAME) return window.EDemo ? window.EDemo(name, data) : {};
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return { error: 'Connexion au jeu impossible.' }; }
}
const req = (action, data = {}) => post('req', { action, data });

const APP = { cfg: null, st: null, levels: {}, statuses: [], urgencies: [], callStatuses: {} };
const urgOf = (u) => APP.urgencies.find((x) => x.id === Number(u)) || { label: '?', color: '#f59e0b' };
const callSt = (s) => (APP.callStatuses || {})[s] || s;

function toast(msg, ok = true) {
  if (!msg) return;
  const el = document.createElement('div');
  el.className = `toast ${ok ? 'ok' : 'err'}`;
  el.textContent = msg;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 3400);
}

/* ---------- Confirmation générique ---------- */
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
const F6 = { view: 'main', data: null, busy: false };
function statusOf(id) { return APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' }; }
const NEXT = ['enroute', 'onsite', 'care', 'transport', 'done'];

function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {};
  const p = st.perms || {};
  const duty = !!st.duty;
  const t = d.times;
  const live = (d.timesAt || 0) / 1000;
  const nCalls = (d.calls || []).length, nSup = (d.supports || []).length;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc(APP.cfg ? APP.cfg.job : 'SAMS')}</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Secouriste')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>
      ${t ? `<div class="times"><div><b>${dur(t.session + (duty ? live : 0))}</b><small>Session</small></div><div><b>${dur(t.unpaid + (duty ? live : 0))}</b><small>Non payé</small></div>
        <div><b>${dur(t.total + (duty ? live : 0))}</b><small>Total</small></div></div>` : ''}`;
  const item = (id, ico, label, sub, opts = {}) => `<button class="f6-item ${opts.cls || ''}" data-f6="${id}" ${opts.disabled ? 'disabled' : ''} ${opts.attrs || ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${opts.chev ? '<span class="chev">›</span>' : ''}</button>`;
  const back = (label) => `<button class="f6-back" data-f6="back">‹ ${label}</button>`;
  let body = '';
  if (F6.view === 'main') {
    body += duty
      ? item('dutyOff', '⏻', 'Quitter mon service', 'Votre temps est enregistré', { cls: 'duty-off' })
      : item('dutyOn', '⏻', 'Prendre mon service', p.duty ? 'Le temps de service est compté' : 'Votre grade ne le permet pas', { cls: 'duty-on', disabled: !p.duty });
    if (duty) body += item('status', '◉', 'Statut opérationnel', esc(statusOf(st.status).label), { chev: true });
    if (p.medical) body += item('med', '🩺', 'Actions médicales', duty ? (d.near ? `Personne proche · ID ${d.near.id}` : 'Personne à proximité') : 'Prenez votre service', { chev: true, disabled: !duty });
    if (p.calls) body += item('calls', '📟', `Appels${nCalls ? ` (${nCalls})` : ''}`, duty ? 'Accepter, GPS, statut' : 'Prenez votre service', { chev: true, disabled: !duty });
    if (p.support) body += item('support', '🚨', `Soutien${nSup ? ` (${nSup})` : ''}`, duty ? 'Demander de l\'aide aux EMS' : 'Prenez votre service', { chev: true, disabled: !duty });
    if (p.tablet) body += item('tablet', '📱', 'Ouvrir la tablette', 'Dispatch, comptes rendus, laboratoire');
    if (p.direction) body += item('direction', '🏛️', 'Direction', 'Personnel, grades, finance', { attrs: 'data-page="employees"' });
  } else if (F6.view === 'status') {
    body += back('Statut opérationnel') + '<div class="f6-list">' + APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span>
      <span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
    return head + body;
  } else if (F6.view === 'med') {
    const n = d.near;
    body += back('Actions médicales');
    if (!n) return `${head}${body}<div class="f6-list"><div class="empty">Personne à moins de 3 m.<br>Approchez-vous du patient.</div></div>`;
    body += `<div class="near">Patient : <b>ID ${n.id}</b> · ${n.distance} m${n.down ? ' · <span style="color:#fca5a5">inconscient</span>' : ''}${n.inVehicle ? ' · dans un véhicule' : ''}</div><div class="f6-list">`;
    const m = (act, ico, label, ok = true, sub = '') => (ok ? `<button class="f6-item" data-med="${act}" data-t="${n.id}"><span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span></button>` : '');
    body += m('examine', '🩺', 'Examiner / état de santé', p.medical);
    const pr = APP.procs || {};
    body += m('procs', '🧰', 'Actes et examens…', p.medical && Object.values(pr).some(Boolean), 'Prise de sang, imagerie, attelle, vaccin…');
    body += m('hemostasis', '🩸', 'Contrôler l\'hémorragie', p.stabilize && pr.hemostasis, 'Compression d\'urgence');
    body += n.down ? m('stabilize', '🩹', 'Stabiliser', p.stabilize) + m('revive', '❤️', pr.cpr ? 'Massage cardiaque' : 'Réanimer', p.revive)
      : m('heal', '💊', 'Soigner', p.heal) + m('splint', '🦴', 'Poser une attelle', p.heal && !pr.cast, 'Blessure à la jambe') + m('treat', '💉', 'Donner un traitement', p.heal, 'Rhume, MST…');
    if (n.stretcher) body += n.onStretcher ? m('escort', '🛏️', 'Retirer du brancard', p.escort)
      : (!n.inVehicle ? m('escort', '🛏️', 'Allonger sur le brancard', p.escort, 'Brancard tenu, à côté, ou sorti') : '');
    else if (!n.inVehicle) body += m('escort', '🚶', n.escorted ? 'Lâcher le patient' : (n.down ? 'Porter le patient' : 'Accompagner le patient'), p.escort);
    body += n.inVehicle ? m('takeOut', '🚪', 'Sortir du véhicule', p.vehicle) : m('putIn', '🚑', 'Installer dans le véhicule', p.vehicle && d.vehicle, d.vehicle ? '' : 'Aucun véhicule proche');
    body += m('report', '📝', 'Compte rendu', p.reports_write) + m('bill', '🧾', 'Facturer les soins', p.billing);
    if (!n.down) body += m('ppa_civil', '📜', 'Délivrer un PPA civil', p.ppa_civil) + m('ppa_fdo', '📜', 'Délivrer un PPA force de l\'ordre', p.ppa_fdo);
    return `${head}${body}</div>`;
  } else if (F6.view === 'calls') {
    body += back('Appels') + '<div class="f6-list" style="padding:.6rem">';
    const C = d.calls || [];
    if (!C.length) body += '<div class="empty">Aucun appel en cours.</div>';
    body += C.map((c) => { const u = urgOf(c.urgency); const idx = NEXT.indexOf(c.status);
      const next = c.accepted ? NEXT.slice(Math.max(0, idx + 1)) : [];
      return `<div class="alert-row" style="--c:${u.color}"><div class="t"><span>#${c.id} · ${esc(c.reason)}</span><span class="st-pill st-${c.status}">${esc(callSt(c.status))}</span></div>
        <div class="m">${esc(c.street || '')} · ${ago(c.t)}${c.patient ? `<br>Patient : ${esc(c.patient)}` : ''}${c.info ? `<br>${esc(c.info)}` : ''}<br>${c.crew && c.crew.length ? `Équipe : ${esc(c.crew.join(', '))}` : 'Personne n\'a pris l\'appel'}</div>
        <div class="acts">${c.accepted
          ? `<button class="btn small" data-call="${c.id}:route">📍 GPS</button>${next.length ? `<select class="input" style="width:auto;padding:.2rem .4rem;font-size:.78rem" data-callst="${c.id}"><option value="">Statut…</option>${next.map((s) => `<option value="${s}">${esc(callSt(s))}</option>`).join('')}</select>` : ''}
             <button class="btn small" data-call="${c.id}:report">📝</button>`
          : `<button class="btn small primary" data-call="${c.id}:accept">${c.crew && c.crew.length ? 'Rejoindre' : 'Accepter'}</button><button class="btn small" data-call="${c.id}:decline">Refuser</button>`}</div></div>`; }).join('');
    return `${head}${body}</div>`;
  } else if (F6.view === 'support') {
    body += back('Soutien') + '<div class="f6-list" style="padding:.6rem">' +
      ['low', 'medium', 'high'].map((k) => { const l = APP.levels[k] || {}; return `<button class="lvl" style="--c:${l.color}" data-f6l="${k}"><span class="dot"></span>
        <span><b>${esc(l.label || k)}</b><small>${esc(l.text || '')}</small></span></button>`; }).join('');
    const S = d.supports || [];
    if (S.length) body += '<div class="section-label">En cours</div>' + S.map((s) => { const l = APP.levels[s.level] || {};
      const canClose = s.authorId === d.me || p.support_close;
      return `<div class="alert-row" style="--c:${l.color}"><div class="t"><span>${esc(l.label)} · ${esc(s.author)}</span><span class="faint">${ago(s.t)}</span></div>
        <div class="m">${esc(s.street || '')}</div><div class="acts"><button class="btn small" data-sup="${s.id}:route">📍 GPS</button>
        ${canClose ? `<button class="btn small danger" data-sup="${s.id}:close">Clôturer</button>` : ''}</div></div>`; }).join('');
    return `${head}${body}</div>`;
  } else if (F6.view === 'confirmHigh') {
    const l = APP.levels.high || {};
    return `${head}<div class="confirm-box"><div class="big">🚨</div><b>Soutien urgent</b><p>${esc(l.text || '')}. Tous les EMS en service recevront un point GPS rouge à votre position.</p>
      <div class="row"><button class="btn" data-f6="back">Annuler</button><button class="btn danger" data-f6l2="high">Envoyer</button></div></div>`;
  }
  return `${head}<div class="f6-list">${body}</div><div class="f6-foot"><span><span class="kbd">ALT</span> patient</span><span><span class="kbd">G</span>/<span class="kbd">I</span> appels</span><span><span class="kbd">Échap</span> fermer</span></div>`;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }

$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6]'))) {
    const a = b.dataset.f6;
    if (a === 'back') { F6.view = 'main'; return f6Draw(); }
    if (a === 'dutyOn' || a === 'dutyOff') {
      if (a === 'dutyOff' && !(await confirmBox('Quitter votre service ?', 'Votre temps de service est enregistré et sera payé par la direction.', 'Quitter le service'))) return;
      b.classList.add('loading'); F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw();
    }
    if (['status', 'med', 'calls', 'support'].includes(a)) { F6.view = a; return f6Draw(); }
    if (a === 'tablet' || a === 'direction') return post('f6', { action: 'tablet', page: b.dataset.page });
  }
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if ((b = e.target.closest('[data-med]'))) return post('f6', { action: 'med', act: b.dataset.med, target: Number(b.dataset.t) });
  if ((b = e.target.closest('[data-f6l]'))) { if (b.dataset.f6l === 'high') { F6.view = 'confirmHigh'; return f6Draw(); } return sendSupport(b.dataset.f6l, b); }
  if ((b = e.target.closest('[data-f6l2]'))) return sendSupport('high', b);
  if ((b = e.target.closest('[data-call]'))) {
    const [id, todo] = b.dataset.call.split(':');
    post('callAction', { kind: 'call', id: Number(id), do_: todo });
    if (todo === 'report') return post('close', { ui: 'f6' });
    return setTimeout(refreshF6, 400);
  }
  if ((b = e.target.closest('[data-sup]'))) {
    const [id, todo] = b.dataset.sup.split(':');
    if (todo === 'close' && !(await confirmBox('Clôturer la demande de soutien ?', 'Le point GPS disparaîtra chez tous les EMS.', 'Clôturer', true))) return;
    post('callAction', { kind: 'support', id: Number(id), do_: todo });
    return setTimeout(refreshF6, 400);
  }
});
$('#f6').addEventListener('change', async (e) => {
  const s = e.target.closest('[data-callst]');
  if (!s || !s.value) return;
  const st = s.value;
  if ((st === 'done' || st === 'cancelled') && !(await confirmBox('Terminer l\'appel ?', `L'appel passera au statut « ${esc(callSt(st))} » pour toute l'équipe.`, 'Confirmer'))) { s.value = ''; return; }
  post('callAction', { kind: 'call', id: Number(s.dataset.callst), do_: 'status', status: st });
  setTimeout(refreshF6, 400);
});
async function refreshF6() { F6.data = await post('f6', { action: 'refresh' }); f6Draw(); }
async function sendSupport(level, btn) {
  if (F6.busy) return;
  F6.busy = true;
  if (btn) btn.classList.add('loading');
  const r = await post('f6', { action: 'support', level });
  F6.busy = false;
  if (r && r.ok) F6.view = 'main';
  refreshF6();
}

/* =====================================================================
   Notifications (G / I)
   ===================================================================== */
const notifEls = new Map();
const nkey = (kind, id) => `${kind}:${id}`;
function removeNotif(kind, id) {
  const el = notifEls.get(nkey(kind, id));
  if (!el) return;
  notifEls.delete(nkey(kind, id));
  el.classList.add('out');
  setTimeout(() => el.remove(), 260);
}
function showNotif(m) {
  const a = m.alert;
  removeNotif(m.kind, a.id);
  const el = document.createElement('div');
  let life = 20000;
  const hour = new Date(a.t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  if (m.kind === 'support') {
    const l = APP.levels[a.level] || { label: a.level, color: '#3b82f6' };
    life = a.level === 'high' ? 25000 : 14000;
    el.className = `notif ${a.level === 'high' ? 'urgent' : ''}`;
    el.style.setProperty('--c', l.color);
    el.innerHTML = `<div class="lvl-tag">Soutien · ${esc(l.label)}</div><h3>${m.mine ? 'Votre demande a été envoyée' : `${esc(a.author)} demande du soutien`}</h3>
      <div class="meta"><span class="mono">${esc(a.matricule || '')}</span> · ${hour}<br>📍 ${esc(a.street || 'Position transmise')} · ${m.distance} m</div>
      ${m.mine ? '' : '<div class="keys"><span><span class="kbd">G</span> GPS</span><span><span class="kbd">I</span> Masquer</span></div>'}<i class="bar"></i>`;
  } else {
    const u = urgOf(a.urgency);
    life = 30000;
    el.className = `notif ${a.urgency === 3 ? 'urgent' : ''}`;
    el.style.setProperty('--c', u.color);
    el.innerHTML = `<div class="lvl-tag">Appel #${a.id} · urgence ${esc(u.label.toLowerCase())}</div><h3>${esc(a.reason)}</h3>
      <div class="meta">${a.info ? `${esc(a.info)}<br>` : ''}${a.caller ? `Appelant : ${esc(a.caller)}<br>` : ''}📍 ${esc(a.street || '')} · ${m.distance} m · ${hour}</div>
      <div class="keys"><span><span class="kbd">G</span> Accepter</span><span><span class="kbd">I</span> Refuser</span></div><i class="bar"></i>`;
  }
  el.querySelector('.bar').style.animationDuration = `${life}ms`;
  $('#notifs').prepend(el);
  notifEls.set(nkey(m.kind, a.id), el);
  while ($('#notifs').children.length > 4) $('#notifs').lastChild.remove();
  setTimeout(() => { if (notifEls.get(nkey(m.kind, a.id)) === el) removeNotif(m.kind, a.id); }, life);
}

/* =====================================================================
   Examen
   ===================================================================== */
let EXAM = null;
const INJ_ST = { active: 'à prendre en charge', controlled: 'saignement contrôlé, pansement à poser', treated: 'traitée' };
function examRender() {
  const x = EXAM.exam, p = EXAM.perms || {};
  if (!Array.isArray(x.injuries)) x.injuries = Object.values(x.injuries || {});   // table Lua vide : {}
  const col = (v) => (v > 60 ? 'var(--green)' : v > 25 ? 'var(--orange)' : 'var(--red)');
  $('#exam .modal').innerHTML = `<div class="eyebrow">Examen · ID ${x.id}</div><h2>${esc(x.name)}</h2><p class="lead">${esc(x.state)}${x.cause ? ` · cause probable : ${esc(x.cause)}` : ''}</p>
    <div class="vitals">
      <div class="vital"><span>Santé</span><b>${x.down ? 'Inconscient' : `${x.hp} %`}</b><div class="meter"><i style="width:${x.down ? 3 : x.hp}%;background:${col(x.down ? 0 : x.hp)}"></i></div></div>
      <div class="vital"><span>Gilet</span><b>${x.armor} %</b><div class="meter"><i style="width:${x.armor}%;background:#60a5fa"></i></div></div>
      ${x.down ? `<div class="vital"><span>À terre depuis</span><b>${clock(x.downFor)}</b></div><div class="vital"><span>Avant perte du patient</span><b style="color:${x.bleedLeft < 60 ? '#fca5a5' : 'inherit'}">${clock(x.bleedLeft)}</b><small class="faint">${x.stabilized ? 'stabilisé' : 'non stabilisé'}</small></div>` : ''}
      ${x.hunger != null ? `<div class="vital"><span>Faim</span><b>${x.hunger} %</b></div><div class="vital"><span>Soif</span><b>${x.thirst} %</b></div>` : ''}
    </div>
    <div class="kv"><span>Groupe sanguin</span><b>${esc(x.blood || 'non renseigné')}</b><span>Allergies</span><b>${esc(x.allergies || 'non renseignées')}</b></div>
    ${(x.injuries || []).length ? `<div class="section-label" style="margin-top:.6rem">Blessures</div><div class="kv">${x.injuries.map((i) => `<span>${esc(i.zoneLabel)}</span><b>${esc(i.label)}<small class="faint"> · ${esc(INJ_ST[i.status] || i.status)}</small></b>`).join('')}</div>` : ''}
    <div class="section-label" style="margin-top:.6rem">Diagnostic</div>
    ${(x.conditions || []).length ? `<div class="kv">${x.conditions.map((c) => `<span>${c.type === 'std' ? 'MST' : c.type === 'injury' ? 'Blessure' : 'Maladie'}</span><b>${esc(c.label)}${c.splinted ? ' · attelle posée' : ''}<small class="faint"> · ${c.cure === 'splint' ? 'attelle' : 'traitement'}</small></b>`).join('')}</div>`
      : '<p class="faint" style="font-size:.8rem">Aucune maladie ni blessure décelée.</p>'}
    <div class="actions" style="flex-wrap:wrap">
      ${(x.injuries || []).some((i) => i.type === 'hemorrhage' && i.status === 'active') && p.stabilize && x.procs ? '<button class="btn danger" data-ex="hemostasis">🩸 Compression</button>' : ''}
      ${x.down ? `${p.stabilize && !x.stabilized ? '<button class="btn" data-ex="stabilize">🩹 Stabiliser</button>' : ''}${p.revive ? `<button class="btn primary" data-ex="revive">❤️ ${x.cprProc ? 'Massage cardiaque' : 'Réanimer'}</button>` : ''}`
        : (p.heal ? `<button class="btn primary" data-ex="heal">💊 Soigner</button>${!x.castProc && (x.conditions || []).some((c) => c.cure === 'splint' && !c.splinted) ? '<button class="btn" data-ex="splint">🦴 Attelle</button>' : ''}${(x.conditions || []).some((c) => c.cure === 'treat') ? '<button class="btn" data-ex="treat">💉 Traitement</button>' : ''}` : '')}
      ${x.procs && p.medical ? '<button class="btn" data-ex="procs">🧰 Actes et examens</button>' : ''}
${p.billing ? '<button class="btn" data-ex="bill">🧾 Facturer</button>' : ''}
      <button class="btn" data-ex="close">Fermer</button></div>`;
}
$('#exam').addEventListener('click', (e) => {
  const b = e.target.closest('[data-ex]');
  if (!b) return;
  if (b.dataset.ex === 'close') return post('close', { ui: 'exam' });
  post('examAction', { act: b.dataset.ex, target: EXAM.exam.id });
});

/* =====================================================================
   Facture (montants recalculés par le serveur)
   ===================================================================== */
let BILL = null;
const MODES = { service: 'Par prestation', flat: 'Forfait', mixed: 'Forfait + prestations' };
function billRender(err = '') {
  const b = BILL, chosen = new Set((b.extrasSel || []));
  const auto = new Set(b.items.filter((i) => i.auto).map((i) => i.id));
  const extras = (b.services || []).filter((s) => s.enabled && !auto.has(s.id));
  $('#bill .modal').innerHTML = `<div class="eyebrow">Facture médicale · ${esc(MODES[b.mode] || b.mode)}</div><h2>${esc(b.patient.name)}</h2>
    <p class="lead">Payée immédiatement (banque, puis liquide). Les actes facturés ne peuvent plus l'être une seconde fois.</p>
    ${b.items.length ? b.items.map((i) => `<div class="bill-line"><span>${esc(i.label)} ${i.auto ? '<small>· acte enregistré</small>' : '<small>· ajouté</small>'}</span><b>${b.mode === 'flat' ? '—' : money(i.price)}</b></div>`).join('')
      : '<div class="empty">Aucun acte enregistré pour ce patient. Ajoutez une prestation ci-dessous.</div>'}
    ${b.mode !== 'service' && b.items.length ? `<div class="bill-line"><span>Forfait d'intervention</span><b>${money(b.flat)}</b></div>` : ''}
    <div class="bill-total"><span>Total</span><span>${money(b.total)}</span></div>
    ${extras.length ? `<div class="section-label" style="padding-left:.2rem">Ajouter une prestation</div>${extras.map((s) => `<label class="extra"><input type="checkbox" class="check" data-extra="${s.id}" ${chosen.has(s.id) ? 'checked' : ''}>
      ${esc(s.label)} <span class="faint">· ${money(s.price)}</span></label>`).join('')}` : ''}
    <div class="err" id="bErr">${esc(err)}</div>
    <div class="actions"><button class="btn" data-bl="cancel">Annuler</button><button class="btn primary" data-bl="send" ${b.total > 0 ? '' : 'disabled'}>Facturer ${money(b.total)}</button></div>`;
}
$('#bill').addEventListener('change', async (e) => {
  const c = e.target.closest('[data-extra]');
  if (!c) return;
  BILL.extrasSel = [...$('#bill').querySelectorAll('[data-extra]:checked')].map((x) => x.dataset.extra);
  const r = await post('billPreview', { target: BILL.patient.id, extras: BILL.extrasSel });
  if (r.error) return billRender(r.error);
  const keep = BILL.extrasSel;
  BILL = { ...r.bill, patient: BILL.patient, extrasSel: keep };
  billRender();
});
$('#bill').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-bl]');
  if (!b) return;
  if (b.dataset.bl === 'cancel') return post('close', { ui: 'bill' });
  const ok = await confirmBox('Confirmer la facture', `${esc(BILL.patient.name)} sera prélevé(e) de <b>${money(BILL.total)}</b> immédiatement.`, 'Facturer');
  if (!ok) return;
  b.classList.add('loading');
  const r = await post('billSend', { target: BILL.patient.id, extras: BILL.extrasSel || [], expected: BILL.total });
  b.classList.remove('loading');
  if (r && r.error) { if (r.bill) BILL = { ...r.bill, patient: BILL.patient, extrasSel: [] }; billRender(r.error); }
});

/* =====================================================================
   PPA : récapitulatif puis délivrance
   ===================================================================== */
let PPA = null;
function ppaRender(err = '') {
  const r = PPA;
  $('#ppa .modal').innerHTML = `<div class="eyebrow">Délivrance directe</div><h2>${esc(r.label)}</h2>
    <p class="lead">Vérifiez les informations : le paiement est prélevé immédiatement, puis le permis est remis. En cas d'échec de la remise, le paiement est remboursé.</p>
    <div class="recap"><span>Bénéficiaire</span><b>${esc(r.name)} · ID ${r.target}</b><span>Catégorie</span><b>${esc(r.label)}</b>
      <span>Prix</span><b>${r.price > 0 ? money(r.price) : 'Gratuit'}</b><span>Délivré par</span><b>${esc(r.ems)} · ${esc(r.grade)}</b>
      <span>Conditions</span><b style="color:var(--green)">✓ en service · ✓ à proximité · ✓ délivrance active</b></div>
    <div class="err" id="pErr" style="margin-top:.6rem">${esc(err)}</div>
    <div class="actions"><button class="btn" data-pp="cancel">Annuler</button><button class="btn primary" data-pp="ok">Confirmer et délivrer</button></div>`;
}
$('#ppa').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-pp]');
  if (!b) return;
  if (b.dataset.pp === 'cancel') return post('close', { ui: 'ppa' });
  b.classList.add('loading');
  const r = await post('ppaDeliver', { target: PPA.target, kind: PPA.kind, expected: PPA.price });
  b.classList.remove('loading');
  if (r && r.error) ppaRender(r.error);
});

/* =====================================================================
   Garage
   ===================================================================== */
function garageRender(list, err = '') {
  $('#garage .modal').innerHTML = `<div class="eyebrow">Garage</div><h2>Sortir un véhicule</h2><p class="lead">Le véhicule apparaît sur la place de sortie, avec ses clés.</p>
    <div class="veh-list">${list.map((v) => `<button class="veh" data-veh="${v.i}" ${v.locked ? 'disabled' : ''}><span><b>${esc(v.label)}</b><br><small class="mono">${esc(v.model)}</small></span>
      <small>${v.locked ? `grade ${v.minLevel} minimum` : 'Sortir ›'}</small></button>`).join('') || '<div class="empty">Aucun véhicule configuré.</div>'}</div>
    <div class="err" style="margin-top:.6rem">${esc(err)}</div><div class="actions"><button class="btn" data-gar="close">Fermer</button></div>`;
}
let GAR = [];
$('#garage').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-veh]'))) {
    b.classList.add('loading');
    const r = await post('garageSpawn', { i: Number(b.dataset.veh) });
    if (r && r.error) garageRender(GAR, r.error);
    return;
  }
  if (e.target.closest('[data-gar]')) post('close', { ui: 'garage' });
});

/* =====================================================================
   Coma et progression
   ===================================================================== */
function deathRender(m) {
  const el = $('#death');
  if (!m.show) { el.classList.add('hidden'); return; }
  el.classList.remove('hidden');
  el.innerHTML = `<div class="box"><h2>Vous êtes inconscient</h2>
    ${m.canRespawn ? '<div class="timer">—</div><p>Personne ne vous a réanimé. Maintenez <span class="kbd">E</span> pour vous réveiller à l\'hôpital'
      + `${m.fee ? ` (frais : ${money(m.fee)})` : ''}.</p><div class="hold"><i style="width:${Math.round((m.hold || 0) * 100)}%"></i></div>`
      : `<div class="timer">${clock(m.left)}</div><p>Attendez les secours. <span class="kbd">G</span> signaler votre position aux EMS.</p>`}
    ${m.stabilized ? '<div class="stab">✓ Stabilisé par un secouriste</div>' : ''}</div>`;
}
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
   Proposition de recrutement
   ===================================================================== */
let offerTimer = null;
function showOffer(o) {
  const w = $('#offer');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre le ${esc(o.job)} au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-offer="no">Refuser</button><button class="btn primary block" data-offer="yes">Accepter</button></div>
    <div class="countdown"><i id="offerBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const total = (o.timeout || 30) * 1000, end = Date.now() + total;
  clearInterval(offerTimer);
  offerTimer = setInterval(() => { const left = end - Date.now(); const bar = $('#offerBar'); if (bar) bar.style.width = `${Math.max(0, left / total * 100)}%`; if (left <= 0) clearInterval(offerTimer); }, 200);
}
$('#offer').addEventListener('click', (e) => {
  const b = e.target.closest('[data-offer]');
  if (b) post('offerAnswer', { accept: b.dataset.offer === 'yes' });
});

/* =====================================================================
   Messages du jeu
   ===================================================================== */
function applyCfg(cfg) {
  if (!cfg) return;
  APP.cfg = cfg;
  APP.levels = cfg.levels || {};
  APP.statuses = cfg.statuses || [];
  APP.urgencies = cfg.urgencies || [];
  APP.callStatuses = cfg.callStatuses || {};
}
const show = (sel, on) => $(sel).classList.toggle('hidden', !on);

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'procs': APP.procs = m.procs || {}; return;
    case 'state': APP.st = m.state; if (m.state && m.state.agency && APP.cfg) APP.cfg.job = m.state.agency; if (window.Tablet) Tablet.onState(m.state); return;
    case 'f6':
      if (m.show) { F6.view = 'main'; F6.data = m; show('#f6', true); f6Draw(); } else show('#f6', false);
      return;
    case 'f6Data':
      if (!$('#f6').classList.contains('hidden') && F6.view !== 'confirmHigh') {
        const focused = document.activeElement && document.activeElement.closest('#f6 select');
        F6.data = m;
        if (!focused) f6Draw();
      }
      return;
    case 'notify': return showNotif(m);
    case 'alertClosed': case 'alertDismiss': return removeNotif(m.kind, m.id);
    case 'callUpdate': return;
    case 'alertsClear': [...notifEls.keys()].forEach((k) => { const [kind, id] = k.split(':'); removeNotif(kind, id); }); return;
    case 'exam': if (m.show) { EXAM = m; examRender(); show('#exam', true); } else show('#exam', false); return;
    case 'bill': if (m.show) { BILL = { ...m.bill, extrasSel: [] }; billRender(); show('#bill', true); } else show('#bill', false); return;
    case 'ppa': if (m.show) { PPA = m.recap; ppaRender(); show('#ppa', true); } else show('#ppa', false); return;
    case 'garage': if (m.show) { GAR = m.list || []; garageRender(GAR); show('#garage', true); } else show('#garage', false); return;
    case 'death': return deathRender(m);
    case 'progress': return progressShow(m);
    case 'offer': if (m.show) showOffer(m.offer); else { show('#offer', false); clearInterval(offerTimer); } return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'closeAll': ['#f6', '#exam', '#bill', '#ppa', '#garage', '#offer', '#confirm'].forEach((s) => show(s, false)); if (window.Tablet) Tablet.hide(); return;
  }
});

/* Échap : ferme l'écran du dessus */
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (!$('#confirm').classList.contains('hidden')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of [['#exam', 'exam'], ['#bill', 'bill'], ['#ppa', 'ppa'], ['#garage', 'garage'], ['#offer', 'offer']]) {
    if (!$(sel).classList.contains('hidden')) return post('close', { ui });
  }
  if (!$('#f6').classList.contains('hidden')) {
    if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); }
    return post('close', { ui: 'f6' });
  }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
