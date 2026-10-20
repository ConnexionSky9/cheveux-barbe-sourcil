/* =====================================================================
   ELYZEA POLICE - interface : socle, ALT, F6, notifications, amende, recrutement
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_police';
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const fmtTime = (t) => { if (!t) return '—'; const d = new Date(t * 1000); return d.toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }); };
const ago = (t) => { const m = Math.floor((Date.now() / 1000 - t) / 60); return m < 1 ? 'à l\'instant' : m < 60 ? `il y a ${m} min` : `il y a ${Math.floor(m / 60)} h`; };

async function post(name, data = {}) {
  if (!IN_GAME) return window.PDemo ? window.PDemo(name, data) : {};
  try {
    const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) });
    return await r.json();
  } catch (e) { return { error: 'Connexion au jeu impossible.' }; }
}
const req = (action, data = {}) => post('req', { action, data });

const APP = { cfg: null, st: null, levels: {}, statuses: [] };

function toast(msg, ok = true) {
  if (!msg) return;
  const el = document.createElement('div');
  el.className = `toast ${ok ? 'ok' : 'err'}`;
  el.textContent = msg;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 3200);
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
  $('#confirm').querySelectorAll('[data-cfv]').forEach((i) => { vals[i.dataset.cfv] = i.value; });
  $('#confirm').classList.add('hidden');
  if (confirmResolve) { confirmResolve(yes ? vals : null); confirmResolve = null; }
});

/* =====================================================================
   Menu ALT
   ===================================================================== */
const ICONS = { cuff: '⛓️', escort: '🚶', in: '🚓', out: '🚪', fine: '🧾', carry: '🧍', trunk: '🧳', hide: '🫣', impound: '🚛', search: '🔍',
  examine: '🩺', heal: '💊', stabilize: '🩹', revive: '❤️', record: '📋', ppa: '📜', repair: '🔧', clean: '🧽', flip: '🔄', engine: '⚙️', body: '🚗', tyres: '🛞',
  bag: '🎒', open: '👜', buy: '🛒', sell: '💰', rob: '🔫', hack: '💻', c4: '🧨', cash: '💵',
  anim_copy: '🪞', anim_propose: '💃', anim_cancel: '✖️', anim_stop: '⏹️', mic: '🎤', press: '📰' };
let altOpenedAt = 0;
function showAlt(m) {
  const alt = $('#alt');
  alt.innerHTML = `<div class="head"><span class="badge">◎</span><b>${esc(m.title)}</b></div>` +
    (m.options.length ? m.options.map((o) => `<button role="menuitem" data-key="${o.key}" ${o.disabled ? 'disabled' : ''}><span class="ico">${ICONS[o.icon] || '•'}</span>
      <span>${esc(o.label)}${o.desc ? `<small>${esc(o.desc)}</small>` : ''}</span></button>`).join('') : '<div class="empty">Aucune action</div>') +
    '<div class="foot">Échap ou clic à côté pour fermer</div>';
  alt.classList.remove('hidden');
  altOpenedAt = Date.now();
  const w = innerWidth, h = innerHeight, r = alt.getBoundingClientRect();
  alt.style.left = `${Math.min(Math.max(8, m.x * w + 14), w - r.width - 8)}px`;
  alt.style.top = `${Math.min(Math.max(8, m.y * h - 10), h - r.height - 8)}px`;
  const first = alt.querySelector('button:not(:disabled)');
  if (first) first.focus();
}
$('#alt').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-key]');
  if (!b || b.disabled) return;
  $('#alt').classList.add('hidden');
  post('altSelect', { key: Number(b.dataset.key) });
});
document.addEventListener('mousedown', (e) => {
  const alt = $('#alt');
  if (alt.classList.contains('hidden') || alt.contains(e.target) || Date.now() - altOpenedAt < 400) return;
  alt.classList.add('hidden');
  post('altClose');
});

/* =====================================================================
   Menu F6
   ===================================================================== */
const F6 = { view: 'main', data: null, pendingLevel: null, busy: false };

function statusOf(id) { return APP.statuses.find((s) => s.id === id) || { label: id, color: '#94a3b8' }; }

function f6Render() {
  const d = F6.data;
  if (!d) return;
  const st = d.state || {};
  const p = st.perms || {};
  const duty = !!st.duty;
  const nAlerts = (d.agentAlerts || []).length + (d.general || []).length;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc(APP.cfg ? APP.cfg.job : 'POLICE')}</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Agent')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>`;
  let body = '';
  if (F6.view === 'main') {
    const item = (id, ico, label, sub, opts = {}) => `<button class="f6-item ${opts.cls || ''}" data-f6="${id}" ${opts.disabled ? 'disabled' : ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${opts.chev ? '<span class="chev">›</span>' : ''}</button>`;
    body += duty
      ? item('dutyOff', '⏻', 'Quitter mon service', 'Vous ne recevrez plus les alertes', { cls: 'duty-off' })
      : item('dutyOn', '⏻', 'Prendre mon service', p.duty ? 'Alertes, carte et interactions' : 'Votre grade ne le permet pas', { cls: 'duty-on', disabled: !p.duty });
    if (duty) body += item('status', '◉', 'Statut opérationnel', esc(statusOf(st.status).label), { chev: true });
    if (p.alert_agent) body += item('agent', '🚨', 'Alerte agent', duty ? 'Demander du renfort' : 'Prenez votre service', { chev: true, disabled: !duty });
    if (p.alerts_receive) body += item('alerts', '📡', `Alertes en cours${nAlerts ? ` (${nAlerts})` : ''}`, duty ? 'GPS, prise en charge, clôture' : 'Prenez votre service', { chev: true, disabled: !duty });
    if (p.tablet) body += item('tablet', '📱', 'Ouvrir la tablette', 'Rapports, carte, direction');
  } else if (F6.view === 'status') {
    body += '<button class="f6-back" data-f6="back">‹ Statut opérationnel</button><div class="f6-list">' +
      APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span><span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
    return `${head}${body}`;
  } else if (F6.view === 'agent') {
    body += '<button class="f6-back" data-f6="back">‹ Alerte agent</button><div class="f6-list" style="padding:.6rem">' +
      ['low', 'medium', 'high'].map((k) => { const l = APP.levels[k] || {}; return `<button class="lvl" style="--c:${l.color}" data-f6l="${k}"><span class="dot"></span>
        <span><b>${esc(l.label || k)}</b><small>${esc(l.text || '')}</small></span></button>`; }).join('') +
      '<p class="faint" style="font-size:.74rem;padding:.2rem .3rem">Votre position actuelle est envoyée à tous les agents en service, avec un point GPS de la couleur choisie.</p></div>';
    return `${head}${body}`;
  } else if (F6.view === 'confirmHigh') {
    const l = APP.levels.high || {};
    body += `<div class="confirm-box"><div class="big">🚨</div><b>Alerte urgente</b><p>${esc(l.text || '')}. Tous les agents en service recevront un point GPS rouge à votre position.</p>
      <div class="row"><button class="btn" data-f6="back">Annuler</button><button class="btn danger" data-f6l2="high">Envoyer</button></div></div>`;
    return `${head}${body}`;
  } else if (F6.view === 'alerts') {
    body += '<button class="f6-back" data-f6="back">‹ Alertes en cours</button><div class="f6-list" style="padding:.6rem">';
    const A = d.agentAlerts || [], G = d.general || [];
    if (!A.length && !G.length) body += '<div class="empty">Aucune alerte en cours.</div>';
    if (A.length) body += '<div class="section-label">Alertes agent</div>' + A.map((a) => { const l = APP.levels[a.level] || {};
      const canClose = a.authorId === d.me || p.alert_close;
      return `<div class="alert-row" style="--c:${l.color}"><div class="t"><span>${esc(l.label)} · ${esc(a.author)}</span><span class="faint mono">${esc(a.matricule || '')}</span></div>
        <div class="m">${esc(a.street || 'Position transmise')} · ${ago(a.t)}</div>
        <div class="acts"><button class="btn small" data-al="agent:${a.id}:route">📍 Itinéraire</button>${canClose ? `<button class="btn small danger" data-al="agent:${a.id}:close">Clôturer</button>` : ''}</div></div>`; }).join('');
    if (G.length) body += '<div class="section-label">Interventions</div>' + G.map((g) => `<div class="alert-row" style="--c:var(--orange)">
        <div class="t"><span>${esc(g.title || g.label)}${g.count > 1 ? ` ×${g.count}` : ''}</span><span class="faint">${ago(g.t)}</span></div>
        <div class="m">${esc(g.street || '')}${g.description ? `<br>${esc(g.description)}` : ''}${g.takers && g.takers.length ? `<br>Pris en charge : ${esc(g.takers.join(', '))}` : '<br>Personne sur place'}</div>
        <div class="acts">${g.accepted ? `<button class="btn small" data-al="general:${g.id}:route">📍 Itinéraire</button><button class="btn small success" data-al="general:${g.id}:close">Terminer</button>`
          : `<button class="btn small primary" data-al="general:${g.id}:accept">${g.takers && g.takers.length ? 'Rejoindre' : 'Valider'}</button><button class="btn small" data-al="general:${g.id}:decline">Décliner</button>`}</div></div>`).join('');
    body += '</div>';
    return `${head}${body}`;
  }
  return `${head}<div class="f6-list">${body}</div><div class="f6-foot"><span><span class="kbd">ALT</span> interactions</span><span><span class="kbd">G</span>/<span class="kbd">I</span> alertes</span><span><span class="kbd">Échap</span> fermer</span></div>`;
}
function f6Draw() { $('#f6').innerHTML = f6Render(); }

$('#f6').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-f6]'))) {
    const a = b.dataset.f6;
    if (a === 'back') { F6.view = 'main'; return f6Draw(); }
    if (a === 'dutyOn' || a === 'dutyOff') { b.classList.add('loading'); F6.data = await post('f6', { action: 'duty', on: a === 'dutyOn' }); return f6Draw(); }
    if (a === 'status' || a === 'agent' || a === 'alerts') { F6.view = a; return f6Draw(); }
    if (a === 'tablet') return post('f6', { action: 'tablet' });
  }
  if ((b = e.target.closest('[data-f6s]'))) { F6.data = await post('f6', { action: 'status', status: b.dataset.f6s }); F6.view = 'main'; return f6Draw(); }
  if ((b = e.target.closest('[data-f6l]'))) {
    if (b.dataset.f6l === 'high') { F6.view = 'confirmHigh'; return f6Draw(); }
    return sendAgentAlert(b.dataset.f6l, b);
  }
  if ((b = e.target.closest('[data-f6l2]'))) return sendAgentAlert('high', b);
  if ((b = e.target.closest('[data-al]'))) {
    const [kind, id, todo] = b.dataset.al.split(':');
    if (todo === 'close' && kind === 'agent') {
      const ok = await confirmBox('Clôturer l\'alerte agent ?', 'Le point GPS disparaîtra chez tous les agents.', 'Clôturer', true);
      if (!ok) return;
    }
    post('alertAction', { kind, id: Number(id), do_: todo });
    setTimeout(async () => { F6.data = await post('f6', { action: 'refresh' }); f6Draw(); }, 350);
  }
});
async function sendAgentAlert(level, btn) {
  if (F6.busy) return;
  F6.busy = true;
  if (btn) btn.classList.add('loading');
  const r = await post('f6', { action: 'agentAlert', level });
  F6.busy = false;
  if (r && r.ok) { F6.view = 'main'; F6.data = await post('f6', { action: 'refresh' }); }
  f6Draw();
}

/* =====================================================================
   Notifications d'alertes (G / I)
   ===================================================================== */
const notifEls = new Map();
function notifKey(kind, id) { return `${kind}:${id}`; }
function removeNotif(kind, id) {
  const el = notifEls.get(notifKey(kind, id));
  if (!el) return;
  notifEls.delete(notifKey(kind, id));
  el.classList.add('out');
  setTimeout(() => el.remove(), 260);
}
function showNotif(m) {
  const a = m.alert;
  const key = notifKey(m.kind, a.id);
  removeNotif(m.kind, a.id);
  const el = document.createElement('div');
  let life = 12000;
  if (m.kind === 'agent') {
    const l = APP.levels[a.level] || { label: a.level, color: '#3b82f6' };
    el.className = `notif ${a.level === 'high' ? 'urgent' : ''}`;
    el.style.setProperty('--c', l.color);
    el.innerHTML = `<div class="lvl-tag">Alerte agent · ${esc(l.label)}</div>
      <h3>${m.mine ? 'Votre alerte a été envoyée' : `${esc(a.author)} demande du renfort`}</h3>
      <div class="meta"><span class="mono">${esc(a.matricule || '')}</span> · ${new Date(a.t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}<br>
        📍 ${esc(a.street || 'Position transmise')} · ${m.distance} m</div>
      ${m.mine ? '' : '<div class="keys"><span><span class="kbd">G</span> Itinéraire</span><span><span class="kbd">I</span> Masquer</span></div>'}
      <i class="bar" style="animation-duration:${life}ms"></i>`;
    if (a.level === 'high') life = 20000;
  } else {
    life = 30000;
    el.className = 'notif';
    el.style.setProperty('--c', 'var(--orange)');
    el.innerHTML = `<div class="lvl-tag">${esc(a.label || 'Alerte')}${a.count > 1 ? ` ×${a.count}` : ''}</div>
      <h3>${esc(a.title || a.label)}</h3>
      <div class="meta">${a.description ? `${esc(a.description)}<br>` : ''}📍 ${esc(a.street || '')} · ${m.distance} m · ${new Date(a.t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
        ${a.takers && a.takers.length ? `<br>Pris en charge : ${esc(a.takers.join(', '))}` : ''}</div>
      <div class="keys"><span><span class="kbd">G</span> Valider</span><span><span class="kbd">I</span> Décliner</span></div>
      <i class="bar" style="animation-duration:${life}ms"></i>`;
  }
  const bar = el.querySelector('.bar');
  if (bar) bar.style.animationDuration = `${life}ms`;
  $('#notifs').prepend(el);
  notifEls.set(key, el);
  while ($('#notifs').children.length > 4) $('#notifs').lastChild.remove();
  setTimeout(() => { if (notifEls.get(key) === el) removeNotif(m.kind, a.id); }, life);
}

/* =====================================================================
   Amende
   ===================================================================== */
const FINE = { target: null, offense: null };
function fineRender(err = '') {
  const offs = (APP.cfg && APP.cfg.offenses) || [];
  const cur = offs.find((o) => o.id === FINE.offense);
  $('#fine .modal').innerHTML = `<h2 id="fineTitle">Mettre une amende</h2><p class="lead">${esc(FINE.target ? FINE.target.name : '')} · prélevée sur son compte, puis en liquide ; sinon elle reste due.</p>
    <div class="stack">
      <div class="field"><span>Infraction</span><div class="offenses">${offs.map((o) => `<button class="offense" data-off="${o.id}" aria-pressed="${o.id === FINE.offense}"><span>${esc(o.label)}</span><b>${o.amount ? money(o.amount) : 'libre'}</b></button>`).join('')}</div></div>
      <div class="grid2">
        <label class="field"><span>Montant ($)</span><input class="input" id="fAmount" type="number" min="1" max="${APP.cfg ? APP.cfg.maxFine : 100000}" value="${cur && cur.amount ? cur.amount : ''}" placeholder="Montant"></label>
        <label class="field"><span>Motif</span><input class="input" id="fReason" maxlength="150" placeholder="ex : 82 km/h en zone 50" value="${esc(cur ? cur.label : '')}"></label>
      </div>
      <label class="field"><span>Description (facultatif)</span><textarea class="input" id="fDesc" maxlength="500" placeholder="Circonstances, lieu, remarques…"></textarea></label>
      <div class="err" id="fErr">${esc(err)}</div>
    </div>
    <div class="actions"><button class="btn" data-fine="cancel">Annuler</button><button class="btn primary" data-fine="ok" ${FINE.offense ? '' : 'disabled'}>Confirmer l'amende</button></div>`;
}
$('#fine').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-off]'))) {
    const keep = { amount: $('#fAmount').value, reason: $('#fReason').value, desc: $('#fDesc').value };
    const prev = (APP.cfg.offenses || []).find((o) => o.id === FINE.offense);
    FINE.offense = b.dataset.off;
    fineRender();
    if (keep.desc) $('#fDesc').value = keep.desc;
    if (prev && keep.reason && keep.reason !== prev.label) $('#fReason').value = keep.reason;
    return;
  }
  if ((b = e.target.closest('[data-fine]'))) {
    if (b.dataset.fine === 'cancel') return post('close', { ui: 'fine' });
    const amount = Number($('#fAmount').value);
    const reason = $('#fReason').value.trim();
    if (!(amount > 0)) return ($('#fErr').textContent = 'Indiquez un montant.');
    if (reason.length < 3) return ($('#fErr').textContent = 'Indiquez le motif.');
    const off = (APP.cfg.offenses || []).find((o) => o.id === FINE.offense);
    const ok = await confirmBox('Confirmer l\'amende', `<b>${esc(off ? off.label : '')}</b> · ${money(amount)}<br>Motif : ${esc(reason)}`, 'Mettre l\'amende');
    if (!ok) return;
    b.classList.add('loading');
    const r = await post('fineSubmit', { offense: FINE.offense, amount, reason, description: $('#fDesc').value.trim() });
    b.classList.remove('loading');
    if (r && r.error) $('#fErr').textContent = r.error;
  }
});

/* =====================================================================
   Proposition de recrutement
   ===================================================================== */
let offerTimer = null;
function showOffer(o) {
  const w = $('#offer');
  $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre la police au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-offer="no">Refuser</button><button class="btn primary block" data-offer="yes">Accepter</button></div>
    <div class="countdown"><i id="offerBar" style="width:100%"></i></div>`;
  w.classList.remove('hidden');
  const end = Date.now() + (o.timeout || 30) * 1000, total = (o.timeout || 30) * 1000;
  clearInterval(offerTimer);
  offerTimer = setInterval(() => { const left = end - Date.now(); const bar = $('#offerBar'); if (bar) bar.style.width = `${Math.max(0, left / total * 100)}%`; if (left <= 0) clearInterval(offerTimer); }, 200);
}
$('#offer').addEventListener('click', (e) => {
  const b = e.target.closest('[data-offer]');
  if (b) post('offerAnswer', { accept: b.dataset.offer === 'yes' });
});

/* =====================================================================
   Mes amendes (/amendes)
   ===================================================================== */
function showMyFines(list) {
  $('#myfines .modal').innerHTML = `<h2>Mes amendes</h2><p class="lead">Amendes non payées. Le paiement est prélevé sur votre compte, puis en liquide.</p>
    ${list.length ? list.map((f) => `<div class="list-row"><div class="main"><b>${esc(f.offense)} · ${money(f.amount)}</b><small>${esc(f.reason || '')} · ${esc(f.officer_name || '')} · ${esc(f.date)}</small></div>
      <button class="btn small primary" data-pay="${f.id}">Payer</button></div>`).join('') : '<div class="empty">Aucune amende à payer.</div>'}
    <div class="actions"><button class="btn" data-mf="close">Fermer</button></div>`;
}
$('#myfines').addEventListener('click', (e) => {
  let b;
  if ((b = e.target.closest('[data-pay]'))) { b.classList.add('loading'); return post('payFine', { id: Number(b.dataset.pay) }); }
  if (e.target.closest('[data-mf]')) post('close', { ui: 'fines' });
});

/* =====================================================================
   Messages du jeu
   ===================================================================== */
function applyCfg(cfg) {
  if (!cfg) return;
  APP.cfg = cfg;
  APP.levels = cfg.levels || {};
  APP.statuses = cfg.statuses || [];
}

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'state': APP.st = m.state; if (m.state && m.state.agency && APP.cfg) APP.cfg.job = m.state.agency; if (window.Tablet) Tablet.onState(m.state); return;
    case 'altMenu': if (m.show) showAlt(m); else $('#alt').classList.add('hidden'); return;
    case 'f6':
      if (m.show) { F6.view = 'main'; F6.data = m; $('#f6').classList.remove('hidden'); f6Draw(); } else $('#f6').classList.add('hidden');
      return;
    case 'f6Data': if (!$('#f6').classList.contains('hidden') && F6.view !== 'confirmHigh') { F6.data = m; if (F6.view === 'main' || F6.view === 'alerts') f6Draw(); } return;
    case 'notify': return showNotif(m);
    case 'alertClosed': case 'alertDismiss': return removeNotif(m.kind, m.id);
    case 'generalUpdate': return;
    case 'alertsClear': notifEls.forEach((_, k) => { const [kind, id] = k.split(':'); removeNotif(kind, id); }); return;
    case 'fine':
      if (m.show) { FINE.target = m.target; FINE.offense = null; fineRender(); $('#fine').classList.remove('hidden'); } else $('#fine').classList.add('hidden');
      return;
    case 'offer': if (m.show) showOffer(m.offer); else { $('#offer').classList.add('hidden'); clearInterval(offerTimer); } return;
    case 'myFines': if (m.show) { showMyFines(m.list || []); $('#myfines').classList.remove('hidden'); } else $('#myfines').classList.add('hidden'); return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state); } else Tablet.hide(); } return;
    case 'closeAll': ['#alt', '#f6', '#fine', '#offer', '#myfines', '#confirm'].forEach((s) => $(s).classList.add('hidden')); if (window.Tablet) Tablet.hide(); return;
  }
});

/* Échap : ferme l'écran du dessus. ALT encore tenu à l'ouverture du menu ALT : ignoré */
document.addEventListener('keydown', (e) => {
  if (e.key === 'Alt') { e.preventDefault(); return; }
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (!$('#confirm').classList.contains('hidden')) { $('#confirm').classList.add('hidden'); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  if (!$('#alt').classList.contains('hidden')) { $('#alt').classList.add('hidden'); return post('altClose'); }
  if (!$('#fine').classList.contains('hidden')) return post('close', { ui: 'fine' });
  if (!$('#myfines').classList.contains('hidden')) return post('close', { ui: 'fines' });
  if (!$('#offer').classList.contains('hidden')) return post('close', { ui: 'offer' });
  if (!$('#f6').classList.contains('hidden')) {
    if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); }
    return post('close', { ui: 'f6' });
  }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
