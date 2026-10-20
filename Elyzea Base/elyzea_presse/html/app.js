/* =====================================================================
   ELYZEA PRESSE - interface : F6, interviews, annonces, viseur, vestiaire, matériel,
   carte de presse, flash info, journal public. Tout est revérifié par le serveur.
   ===================================================================== */
const IN_GAME = typeof GetParentResourceName === 'function';
const RES = IN_GAME ? GetParentResourceName() : 'elyzea_presse';
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


const APP = { cfg: null, st: null, statuses: [], cats: {} };
const statusOf = (id) => APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' };
const catLabel = (c) => APP.cats[c] || c || '';
const show = (sel, on) => $(sel).classList.toggle('hidden', !on);
const isShown = (sel) => !$(sel).classList.contains('hidden');
const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
function countdown(barSel, seconds) {
  const total = (seconds || 30) * 1000, end = Date.now() + total;
  const t = setInterval(() => { const l = end - Date.now(); const bar = $(barSel); if (!bar || l <= 0) { clearInterval(t); if (bar) bar.style.width = '0%'; return; } bar.style.width = `${Math.max(0, l / total * 100)}%`; }, 200);
}

/* =====================================================================
   Menu F6
   ===================================================================== */
const F6 = { view: 'main', data: null };
function f6Render() {
  const d = F6.data;
  if (!d) return '';
  const st = d.state || {}, p = st.perms || {}, duty = !!st.duty, t = d.times, live = (d.timesAt || 0) / 1000;
  const head = `<div class="f6-head"><div class="top"><span class="badge">${esc((st.short || st.agency || 'PRESSE').toUpperCase())}</span>
      <span class="pill ${duty ? 'on' : 'off'}">${duty ? 'En service' : 'Hors service'}</span></div>
      <div class="who">${esc(st.grade || 'Journaliste')}</div><div class="sub mono">${esc(st.matricule || '')}${duty ? ` · ${esc(statusOf(st.status).label)}` : ''}</div></div>
      ${t ? `<div class="times"><div><b>${dur(t.session + (duty ? live : 0))}</b><small>Session</small></div><div><b>${dur(t.unpaid + (duty ? live : 0))}</b><small>Non payé</small></div>
        <div><b>${dur(t.total + (duty ? live : 0))}</b><small>Total</small></div></div>` : ''}`;
  const item = (id, ico, label, sub, o = {}) => `<button class="f6-item ${o.cls || ''}" data-f6="${id}" ${o.disabled ? 'disabled' : ''} ${o.attrs || ''}>
      <span class="ico">${ico}</span><span class="txt">${label}${sub ? `<small>${sub}</small>` : ''}</span>${o.chev ? '<span class="chev">›</span>' : ''}</button>`;
  if (F6.view === 'status') {
    return head + '<button class="f6-back" data-f6="back">‹ Statut</button><div class="f6-list">' + APP.statuses.map((s) => `<button class="f6-item" data-f6s="${s.id}"><span class="ico" style="color:${s.color}">●</span>
      <span class="txt">${esc(s.label)}</span>${st.status === s.id ? '<span class="chev">✓</span>' : ''}</button>`).join('') + '</div>';
  }
  let b = head + '<div class="f6-list">';
  if (p.duty) b += duty ? item('dutyOff', '⏻', 'Terminer mon service', 'Votre temps est enregistré', { cls: 'duty-off' }) : item('dutyOn', '⏻', 'Prendre mon service', '', { cls: 'duty-on' });
  if (duty) b += item('status', '◉', 'Statut', esc(statusOf(st.status).label), { chev: true });
  if (d.interview) {
    b += '<div class="section-label">Interview en cours</div>';
    if (d.interview.role === 'journalist') b += item('ivNotes', '📝', 'Notes de l\'interview', esc(d.interview.subject));
    b += item('ivEnd', '⏹', 'Terminer l\'interview', esc(d.interview.other), { cls: 'duty-off' });
  }
  if (d.hold) b += item('stopHold', '✋', 'Ranger le matériel', { mic: 'Micro', camera: 'Caméra', photo: 'Appareil photo' }[d.hold] || '');
  if (p.tablet) {
    b += '<div class="section-label">Rédaction</div>';
    b += item('tab', '📊', 'Tableau de bord', 'Articles, équipe en service', { attrs: 'data-page="dashboard"' });
    if (p.write) b += item('tab', '✍️', 'Rédiger un article', '', { attrs: 'data-page="write"' });
    b += item('tab', '🗂️', 'Mes articles', 'Brouillons, soumis, renvoyés', { attrs: 'data-page="mine"' });
    if (p.review) b += item('tab', '✅', 'À valider', '', { attrs: 'data-page="pending"' });
    if (p.interview) b += item('tab', '🎙️', 'Interviews', 'Notes, historique', { attrs: 'data-page="interviews"' });
    if (p.flash && duty) b += item('tab', '⚡', 'Flash info', 'Bandeau à tout le serveur', { attrs: 'data-page="flash"' });
    if (p.direction) b += item('tab', '🏛️', 'Direction', 'Personnel, finance, locaux', { attrs: 'data-page="employees"' });
  }
  b += item('reader', '📰', 'Lire le journal', 'Articles publiés, petites annonces');
  if (d.uniform) b += item('civil', '👕', 'Tenue personnelle', 'Retirer la tenue de service');
  b += '</div><div class="f6-foot"><span><span class="kbd">ALT</span> interview / annonce</span><span><span class="kbd">G</span> viseur</span><span><span class="kbd">Échap</span> fermer</span></div>';
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
  if (a === 'ivEnd') { if (!(await confirmBox('Terminer l\'interview ?', 'Vos notes restent enregistrées.', 'Terminer'))) return; F6.data = await post('f6', { action: 'ivEnd' }); return f6Draw(); }
  if (a === 'stopHold' || a === 'civil') { F6.data = await post('f6', { action: a }); return f6Draw(); }
  if (a === 'ivNotes' || a === 'reader') return post('f6', { action: a });
  if (a === 'tab') return post('f6', { action: 'tablet', page: b.dataset.page });
});

/* =====================================================================
   Recrutement (proposition reçue)
   ===================================================================== */
function showOffer(o) {
  $('#offer .modal').innerHTML = `<div class="eyebrow">${esc(o.job)}</div><h2>Proposition de recrutement</h2>
    <p class="lead"><b>${esc(o.from)}</b> vous propose de rejoindre la rédaction <b>${esc(o.job)}</b> au grade <b>${esc(o.grade)}</b>.${o.current ? `<br>Vous quitterez votre métier actuel (${esc(o.current)}).` : ''}</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-offer="no">Refuser</button><button class="btn primary block" data-offer="yes">Accepter</button></div>
    <div class="countdown"><i id="offerBar" style="width:100%"></i></div>`;
  show('#offer', true);
  countdown('#offerBar', o.timeout);
}
$('#offer').addEventListener('click', (e) => { const b = e.target.closest('[data-offer]'); if (b) post('offerAnswer', { accept: b.dataset.offer === 'yes' }); });

/* =====================================================================
   Interviews
   ===================================================================== */
function showIvOffer(o) {
  $('#ivOffer .modal').innerHTML = `<div class="eyebrow">${esc(o.agency)} · Interview</div><h2>Demande d'interview</h2>
    <p class="lead"><b>${esc(o.from)}</b> souhaite vous interviewer.</p>
    <div class="recap"><span>Sujet</span><b>${esc(o.subject)}</b><span>Média</span><b>${esc(o.agency)}</b></div>
    <p class="lead">Vous êtes libre de refuser. Rien n'est enregistré automatiquement : le journaliste prend lui-même ses notes. Vous pourrez arrêter à tout moment (<span class="kbd">/fininterview</span>).</p>
    <label class="extra"><input type="checkbox" class="check" id="ivAnon"> Rester anonyme (votre nom n'est pas noté)</label>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-iv="no">Refuser</button><button class="btn primary block" data-iv="yes">Accepter</button></div>
    <div class="countdown"><i id="ivBar" style="width:100%"></i></div>`;
  show('#ivOffer', true);
  countdown('#ivBar', o.timeout);
}
$('#ivOffer').addEventListener('click', (e) => { const b = e.target.closest('[data-iv]'); if (b) post('ivAnswer', { accept: b.dataset.iv === 'yes', anonymous: !!($('#ivAnon') || {}).checked }); });

function showIvAsk(m) {
  $('#ivAsk .modal').innerHTML = `<div class="eyebrow">Interview</div><h2>Proposer une interview</h2>
    <p class="lead">À <b>${esc(m.name)}</b>. La personne pourra accepter ou refuser. Il vous faut un micro sur vous.</p>
    <label class="field"><span>Sujet</span><input class="input" id="ivSubject" maxlength="120" placeholder="ex : Ouverture du nouveau commissariat"></label>
    <div class="err" id="ivErr"></div>
    <div class="actions"><button class="btn" data-ia="no">Annuler</button><button class="btn primary" data-ia="yes">Envoyer la demande</button></div>`;
  $('#ivAsk').dataset.target = m.target;
  show('#ivAsk', true);
  setTimeout(() => $('#ivSubject').focus(), 30);
}
$('#ivAsk').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-ia]');
  if (!b) return;
  if (b.dataset.ia === 'no') return post('close', { ui: 'ivAsk' });
  const r = await act(post('ivAsk', { target: Number($('#ivAsk').dataset.target), subject: $('#ivSubject').value }), b);
  if (r.error) $('#ivErr').textContent = r.error;
});

function ivBanner(iv) {
  if (!iv) return show('#ivBanner', false);
  $('#ivBanner').innerHTML = `<span class="rec">● INTERVIEW</span> · ${esc(iv.agency)}<b>${esc(iv.subject)}</b>
    <small>${iv.role === 'journalist' ? `Avec ${esc(iv.anonymous ? 'une personne anonyme' : iv.other)} · notes : bloc-notes ou F6` : `Avec ${esc(iv.other)} · /fininterview pour arrêter`}</small>`;
  show('#ivBanner', true);
}

function showNotes(m) {
  const iv = m.interview;
  $('#notes .modal').innerHTML = `<div class="eyebrow">Interview · ${esc(iv.guest || '')}${iv.anonymous ? ' (anonyme)' : ''}</div><h2>${esc(iv.subject)}</h2>
    <p class="lead">Saisissez les questions et les réponses vous-même. Rien n'est enregistré automatiquement. ${fmtTime(iv.started)}${iv.location ? ` · ${esc(iv.location)}` : ''}</p>
    <textarea class="input" id="ivNotes" maxlength="${m.max || 8000}" style="min-height:20rem" placeholder="Q : …&#10;R : …">${esc(iv.notes || '')}</textarea>
    <div class="actions"><button class="btn" data-nt="close">Fermer</button><button class="btn primary" data-nt="save">Enregistrer</button></div>`;
  $('#notes').dataset.id = iv.id;
  show('#notes', true);
  setTimeout(() => $('#ivNotes').focus(), 30);
}
$('#notes').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-nt]');
  if (!b) return;
  if (b.dataset.nt === 'close') return post('close', { ui: 'notes' });
  await act(post('notesSave', { id: Number($('#notes').dataset.id), notes: $('#ivNotes').value }), b);
});

/* =====================================================================
   Annonces payantes
   ===================================================================== */
function showAdForm(d) {
  const tiers = d.tiers || [], near = d.near || [];
  $('#adForm .modal').innerHTML = `<div class="eyebrow">Annonce payante</div><h2>Préparer l'annonce</h2>
    <p class="lead">Le client voit le texte et le prix, puis accepte (et paie) ou refuse. Le prix est celui des tarifs de la rédaction.</p>
    <div class="stack"><label class="field"><span>Client</span><select class="input" id="adTarget">${near.map((n) => `<option value="${n.id}" ${n.id === d.target ? 'selected' : ''}>ID ${n.id} · ${n.distance} m</option>`).join('') || `<option value="${d.target}">ID ${d.target}</option>`}</select></label>
      <label class="field"><span>Formule</span><select class="input" id="adTier">${tiers.map((t) => `<option value="${t.id}">${esc(t.label)} · ${money(t.price)} · ${t.hours} h${t.broadcast ? ' · diffusée' : ''}</option>`).join('')}</select></label>
      <label class="field"><span>Texte de l'annonce</span><textarea class="input" id="adText" maxlength="${d.textMax || 300}"></textarea></label></div>
    <div class="err" id="adErr"></div>
    <div class="actions"><button class="btn" data-af="no">Annuler</button><button class="btn primary" data-af="yes" ${tiers.length ? '' : 'disabled'}>Envoyer au client</button></div>`;
  show('#adForm', true);
}
$('#adForm').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-af]');
  if (!b) return;
  if (b.dataset.af === 'no') return post('close', { ui: 'adForm' });
  const r = await act(post('adSend', { target: Number($('#adTarget').value), tier: $('#adTier').value, text: $('#adText').value }), b);
  if (r.error) $('#adErr').textContent = r.error;
});

function showAdOffer(o) {
  $('#adOffer .modal').innerHTML = `<div class="eyebrow">${esc(o.agency)} · Annonce</div><h2>${esc(o.tier)}</h2>
    <div class="recap"><span>Journaliste</span><b>${esc(o.seller)}</b><span>Durée</span><b>${o.hours} h${o.broadcast ? ' · diffusée à tout le serveur' : ''}</b>
      <span>Texte</span><b style="white-space:pre-wrap">${esc(o.text)}</b><span>Prix</span><b class="total">${money(o.price)}</b></div>
    <label class="field"><span>Paiement</span><select class="input" id="adMethod"><option value="bank">Banque</option><option value="cash">Liquide</option></select></label>
    <p class="lead" style="margin-top:.6rem">En acceptant, le prix est prélevé tout de suite. Vous pouvez refuser sans rien payer.</p>
    <div class="actions" style="justify-content:stretch"><button class="btn danger block" data-ao="no">Refuser</button><button class="btn primary block" data-ao="yes">Accepter et payer</button></div>
    <div class="countdown"><i id="adBar" style="width:100%"></i></div>`;
  show('#adOffer', true);
  countdown('#adBar', o.timeout);
}
$('#adOffer').addEventListener('click', (e) => { const b = e.target.closest('[data-ao]'); if (b) post('adAnswer', { accept: b.dataset.ao === 'yes', method: $('#adMethod').value }); });

/* =====================================================================
   Viseur, légende, matériel en main
   ===================================================================== */
function viewfinder(m) {
  if (!m.show) return show('#viewfinder', false);
  const video = m.kind === 'video', s = m.recSeconds || 0;
  $('#viewfinder').innerHTML = `<div class="frame"></div>
    <div class="top"><span>${video ? (m.rec ? `<span class="rec">● REC</span> ${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}` : 'CAMÉRA · PRÊTE') : 'PHOTO'}</span><span>×${m.zoom}</span></div>
    <div class="bot"><span>${esc(m.street || '')}</span><span>Clic : ${video ? (m.rec ? 'arrêter' : 'filmer') : 'déclencher'} · Molette : zoom · G : quitter</span></div>`;
  show('#viewfinder', true);
}
function captionBox(m) {
  if (!m.show) return show('#caption', false);
  $('#caption .modal').innerHTML = `<h2>${m.kind === 'video' ? 'Séquence filmée' : 'Photo prise'}</h2>
    <p class="lead">Donnez une légende : elle accompagnera ${m.kind === 'video' ? 'la séquence' : 'la photo'} dans la tablette et dans vos articles.</p>
    <input class="input" id="capText" maxlength="${m.max || 160}" placeholder="ex : Incendie rue Vespucci, les pompiers sur place">
    <div class="actions"><button class="btn" data-cp="no">Ne pas garder</button><button class="btn primary" data-cp="yes">Enregistrer</button></div>`;
  show('#caption', true);
  setTimeout(() => $('#capText').focus(), 30);
}
$('#caption').addEventListener('click', (e) => { const b = e.target.closest('[data-cp]'); if (b) post('caption', { cancel: b.dataset.cp === 'no', caption: $('#capText').value }); });
$('#caption').addEventListener('keydown', (e) => { if (e.key === 'Enter') post('caption', { caption: $('#capText').value }); });
function holdHint(kind) {
  if (!kind) return show('#holdHint', false);
  $('#holdHint').innerHTML = kind === 'mic' ? '🎤 Micro · <span class="kbd">X</span> ranger' : `${kind === 'camera' ? '🎥 Caméra' : '📷 Appareil photo'} · <span class="kbd">G</span> viseur · <span class="kbd">X</span> ranger`;
  show('#holdHint', true);
}

/* =====================================================================
   Véhicules, matériel, vestiaire
   ===================================================================== */
function garageBox(list) {
  $('#garage .modal').innerHTML = `<h2>Véhicules de service</h2><p class="lead">Sortie sur la place de la rédaction. Rangez-le au même endroit (E au volant).</p>
    <div class="stack">${list.map((v) => `<button class="btn block" data-veh="${v.i}" ${v.locked ? 'disabled' : ''}>${esc(v.label)}${v.locked ? ` · grade ${v.minLevel}+` : ''}</button>`).join('') || '<div class="empty">Aucun véhicule.</div>'}</div>
    <div class="actions"><button class="btn" data-close="garage">Fermer</button></div>`;
  show('#garage', true);
}
$('#garage').addEventListener('click', async (e) => { const b = e.target.closest('[data-veh]'); if (b) await act(post('garageSpawn', { i: Number(b.dataset.veh) }), b); });
function gearBox(list) {
  $('#gear .modal').innerHTML = `<h2>Matériel de service</h2><p class="lead">Un exemplaire de chaque, gratuit, à rendre ici. Il ne fonctionne qu'en service.</p>
    ${list.map((g) => `<div class="list-row"><div class="main"><b>${esc(g.label)}</b><small>${!g.exists ? 'objet non déclaré dans l\'inventaire' : g.locked ? `grade ${g.minLevel} minimum` : g.has ? (g.service ? 'sur vous (service)' : 'sur vous') : 'disponible'}</small></div>
      ${g.service ? `<button class="btn small" data-gear="${esc(g.item)}" data-take="0">Rendre</button>` : `<button class="btn small primary" data-gear="${esc(g.item)}" data-take="1" ${g.locked || g.has || !g.exists ? 'disabled' : ''}>Prendre</button>`}</div>`).join('')}
    <div class="actions"><button class="btn" data-close="gear">Fermer</button></div>`;
  show('#gear', true);
}
$('#gear').addEventListener('click', async (e) => {
  const b = e.target.closest('[data-gear]');
  if (!b) return;
  b.classList.add('loading');
  const r = await post('gearAct', { item: b.dataset.gear, take: b.dataset.take === '1' });
  gearBox(r.list || []);
});
function wardrobeBox(m) {
  $('#wardrobe .modal').innerHTML = `<h2>Vestiaire</h2><p class="lead">La tenue de service n'est pas un objet : pendant que vous la portez, les vêtements de l'inventaire ne s'échangent pas. Elle est retirée à la fin du service.</p>
    <div class="stack">${m.list.map((o) => `<button class="btn block" data-wear="${esc(o.id)}" ${o.locked || !o.ready ? 'disabled' : ''}>${esc(o.label)}${o.locked ? ` · grade ${o.minLevel}+` : !o.ready ? ' · pas encore enregistrée' : ''}</button>`).join('')}
      <button class="btn block" data-wear="civil" ${m.wearing ? '' : 'disabled'}>👕 Tenue personnelle</button></div>
    <div class="actions"><button class="btn" data-close="wardrobe">Fermer</button></div>`;
  show('#wardrobe', true);
}
$('#wardrobe').addEventListener('click', (e) => { const b = e.target.closest('[data-wear]'); if (b) post('wardrobeWear', b.dataset.wear === 'civil' ? { civil: true } : { id: b.dataset.wear }); });
document.addEventListener('click', (e) => { const b = e.target.closest('[data-close]'); if (b) post('close', { ui: b.dataset.close }); });

/* =====================================================================
   Carte de presse, flash info
   ===================================================================== */
let cardTimer = null;
function showCard(c, own) {
  $('#card').innerHTML = `<div class="press-card"><div class="band"><span>PRESSE</span><span>${esc(c.agency || '')}</span></div>
    <div class="body"><div class="photo">${esc(initials(c.name))}</div><div class="kv"><span>Nom</span><b>${esc(c.name || '?')}</b><span>Matricule</span><b class="mono">${esc(c.matricule || '?')}</b>
      ${c.grade ? `<span>Grade</span><b>${esc(c.grade)}</b>` : ''}<span>N°</span><b class="mono">${esc(c.number || '?')}</b><span>Délivrée</span><b>${esc(c.issued || '?')}</b></div></div>
    <div class="state ${c.valid ? 'ok' : 'bad'}">${c.valid ? '✔ Carte valide (vérifiée par le registre de la presse)' : `✖ ${esc(c.why || 'Carte invalide')}`}</div>
    ${c.bearerMismatch ? '<div class="state bad">⚠ Présentée par une autre personne que son titulaire</div>' : ''}
    ${own ? '' : `<div class="state" style="background:#e2e8f0">Présentée par ${esc(c.shownBy || '?')}</div>`}</div>`;
  show('#card', true);
  clearTimeout(cardTimer);
  cardTimer = setTimeout(() => show('#card', false), 9000);
}
function showFlash(f) {
  const el = document.createElement('div');
  el.className = 'flash';
  if (f.color) el.style.setProperty('--c', f.color);
  const lbl = f.kind === 'ad' ? 'Annonce' : f.kind === 'publish' ? 'À la une' : 'Flash info';
  el.innerHTML = `<div class="lbl">${lbl}</div><div class="txt"><b>${esc(f.agency)}${f.title && f.kind !== 'ad' ? ` · ${esc(f.title)}` : ''}</b><span>${esc(f.text)}</span>
    <small>${f.author ? `Par ${esc(f.author)} · ` : ''}${f.kind === 'publish' ? '/journal pour lire' : new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}</small></div><i class="bar"></i>`;
  el.querySelector('.bar').style.animationDuration = `${(f.seconds || 12) * 1000}ms`;
  $('#flashes').prepend(el);
  while ($('#flashes').children.length > 3) $('#flashes').lastChild.remove();
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 320); }, (f.seconds || 12) * 1000);
}

/* =====================================================================
   Le journal (tout le monde)
   ===================================================================== */
const RD = { data: null, f: { job: '', category: '', q: '', page: 0, archives: false }, art: null, tab: 'news' };
function readerRender() {
  const d = RD.data || { list: [], agencies: [], categories: [], ads: [] }, f = RD.f, a = RD.art;
  const ag = (d.agencies || []).find((x) => x.job === f.job);
  let content;
  if (a) {
    content = `<div class="content single"><div class="full"><button class="btn small" data-rd="back">‹ Retour</button>
      <div class="meta" style="margin-top:.8rem"><span class="src" style="--c:${esc(a.color || '#1c1917')}">${esc(a.agency)}</span> · ${esc(catLabel(a.category))} · ${fmtTime(a.published)}${a.archived ? ' · archive' : ''}</div>
      <h2>${esc(a.title)}</h2>${a.summary ? `<p class="chapo">${esc(a.summary)}</p>` : ''}
      <div class="meta">Par ${esc(a.author)}${a.reviewer ? ` · relu par ${esc(a.reviewer)}` : ''}${a.updated && a.updated > (a.published || 0) + 60 ? ` · mis à jour ${fmtTime(a.updated)}` : ''}</div>
      <div class="text" style="margin-top:1rem">${esc(a.body)}</div>
      ${(a.media || []).length ? `<div class="media">${a.media.map((m) => `<div>${m.kind === 'video' ? '🎥 Séquence' : '📷 Photo'} : ${esc(m.caption)}${m.street ? ` — ${esc(m.street)}` : ''} · ${esc(m.author_name || '')}, ${fmtTime(m.t)}${m.seconds ? ` · ${dur(m.seconds)}` : ''}</div>`).join('')}</div>` : ''}
      ${RD.staff ? `<div style="margin-top:1rem"><button class="btn small mod" data-rd="modArt" data-id="${a.id}">Staff : retirer l'article</button></div>` : ''}</div></div>`;
  } else {
    content = `<div class="content"><div>${d.list.map((x) => `<div class="art" data-art="${x.id}"><div class="meta"><span class="src" style="--c:${esc(x.color || '#1c1917')}">${esc(x.agency)}</span> · ${esc(catLabel(x.category))} · ${fmtTime(x.t)}</div>
        <h3>${esc(x.title)}</h3>${x.summary ? `<p>${esc(x.summary)}</p>` : ''}<div class="meta">Par ${esc(x.author_name || '')}</div></div>`).join('') || `<div class="empty">${f.archives ? 'Aucune archive.' : 'Aucun article publié pour le moment.'}</div>`}
        <div style="display:flex;gap:.5rem;margin-top:.8rem">${f.page > 0 ? '<button class="btn small" data-rd="prev">‹ Plus récents</button>' : ''}${d.more ? '<button class="btn small" data-rd="next">Plus anciens ›</button>' : ''}</div></div>
      <aside class="side"><h4>Petites annonces</h4>${(d.ads || []).map((x) => `<div class="ad">${esc(x.text)}<small>${esc(x.agency)} · ${esc(x.client_name || '')} · jusqu'au ${fmtTime(x.e)}</small>
        ${RD.staff ? `<button class="btn small mod" data-rd="modAd" data-uid="${esc(x.uid)}">Retirer</button>` : ''}</div>`).join('') || '<div class="empty">Aucune annonce.</div>'}</aside></div>`;
  }
  $('#reader').innerHTML = `<div class="paper"><div class="mast"><div><h1>${esc(ag ? ag.label : 'Le Journal')}</h1><small>${new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })} · toutes les rédactions de la ville</small></div>
      <button class="icon-btn" data-rd="close" aria-label="Fermer">✕</button></div>
    <div class="bar"><select class="input" data-rf="job"><option value="">Toutes les rédactions</option>${(d.agencies || []).map((x) => `<option value="${esc(x.job)}" ${f.job === x.job ? 'selected' : ''}>${esc(x.label)}</option>`).join('')}</select>
      <select class="input" data-rf="category"><option value="">Toutes les rubriques</option>${(d.categories || []).map((c) => `<option value="${c.id}" ${f.category === c.id ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select>
      <input class="input" id="rdQ" placeholder="Rechercher" value="${esc(f.q)}" style="flex:1;min-width:10rem"><button class="btn" data-rd="search">Rechercher</button>
      <button class="btn ${f.archives ? 'primary' : ''}" data-rd="archives">Archives</button></div>${content}</div>`;
}
async function readerLoad() {
  const r = await pub('news', RD.f);
  if (r.error) return toast(r.error, false);
  RD.data = r; RD.staff = r.staff; RD.art = null;
  readerRender();
}
$('#reader').addEventListener('change', (e) => { const t = e.target; if (t.dataset.rf) { RD.f[t.dataset.rf] = t.value; RD.f.page = 0; readerLoad(); } });
$('#reader').addEventListener('keydown', (e) => { if (e.key === 'Enter' && e.target.id === 'rdQ') { RD.f.q = e.target.value; RD.f.page = 0; readerLoad(); } });
$('#reader').addEventListener('click', async (e) => {
  let b;
  if ((b = e.target.closest('[data-art]'))) {
    const r = await pub('newsGet', { id: Number(b.dataset.art) });
    if (r.error) return toast(r.error, false);
    RD.art = r.article; RD.staff = r.staff; $('#reader .paper') && readerRender(); return;
  }
  if (!(b = e.target.closest('[data-rd]'))) return;
  const a = b.dataset.rd;
  if (a === 'close') return post('close', { ui: 'reader' });
  if (a === 'back') { RD.art = null; return readerRender(); }
  if (a === 'search') { RD.f.q = $('#rdQ').value; RD.f.page = 0; return readerLoad(); }
  if (a === 'archives') { RD.f.archives = !RD.f.archives; RD.f.page = 0; return readerLoad(); }
  if (a === 'next' || a === 'prev') { RD.f.page += a === 'next' ? 1 : -1; return readerLoad(); }
  if (a === 'modArt' || a === 'modAd') {
    const v = await confirmBox('Retirer ce contenu ?', 'Action du staff : il disparaît du journal (gardé en base, l\'auteur est prévenu).', 'Retirer', true,
      '<label class="field" style="margin-top:.6rem"><span>Motif (obligatoire)</span><input class="input" data-cfv="reason" maxlength="160"></label>');
    if (!v) return;
    const r = await act(pub(a, a === 'modArt' ? { id: Number(b.dataset.id), reason: v.reason } : { uid: b.dataset.uid, reason: v.reason }), b);
    if (r.ok) readerLoad();
  }
});

/* =====================================================================
   Messages du jeu
   ===================================================================== */
function applyCfg(cfg) {
  if (!cfg) return;
  APP.cfg = cfg; APP.statuses = cfg.statuses || [];
  APP.cats = {}; (cfg.categories || []).forEach((c) => { APP.cats[c.id] = c.label; });
}

window.addEventListener('message', (e) => {
  const m = e.data || {};
  switch (m.action) {
    case 'init': return applyCfg(m.cfg);
    case 'state': APP.st = m.state; if (window.Tablet) Tablet.onState(m.state); return;
    case 'f6': if (m.show) { F6.view = 'main'; F6.data = m; show('#f6', true); f6Draw(); } else show('#f6', false); return;
    case 'f6Data': if (isShown('#f6')) { F6.data = m; f6Draw(); } return;
    case 'offer': if (m.show) showOffer(m.offer); else show('#offer', false); return;
    case 'ivOffer': if (m.show) showIvOffer(m.offer); else show('#ivOffer', false); return;
    case 'ivAsk': if (m.show) showIvAsk(m); else show('#ivAsk', false); return;
    case 'ivBanner': return ivBanner(m.iv);
    case 'notes': if (m.show) showNotes(m); else show('#notes', false); return;
    case 'adForm': if (m.show) showAdForm(m.data); else show('#adForm', false); return;
    case 'adOffer': if (m.show) showAdOffer(m.offer); else show('#adOffer', false); return;
    case 'viewfinder': return viewfinder(m);
    case 'flashShot': { const s = $('#shot'); s.classList.remove('go'); void s.offsetWidth; s.classList.add('go'); return; }
    case 'caption': return captionBox(m);
    case 'hold': return holdHint(m.kind);
    case 'garage': if (m.show) garageBox(m.list || []); else show('#garage', false); return;
    case 'gear': if (m.show) gearBox(m.list || []); else show('#gear', false); return;
    case 'wardrobe': if (m.show) wardrobeBox(m); else show('#wardrobe', false); return;
    case 'card': return showCard(m.card, m.own);
    case 'flash': return showFlash(m.flash);
    case 'reader': if (m.show) { RD.data = m.data; RD.staff = m.data.staff; RD.art = null; RD.f = { job: m.job || '', category: '', q: '', page: 0, archives: false };
      if (m.data.categories) { APP.cats = {}; m.data.categories.forEach((c) => { APP.cats[c.id] = c.label; }); } show('#reader', true); readerRender(); } else show('#reader', false); return;
    case 'tablet': if (window.Tablet) { if (m.show) { applyCfg(m.cfg || APP.cfg); Tablet.open(m.state, m.opts); } else Tablet.hide(); } return;
    case 'tabletGo': if (window.Tablet) Tablet.goTo(m.opts); return;
    case 'closeAll':
      ['#f6', '#offer', '#ivOffer', '#ivAsk', '#notes', '#adForm', '#adOffer', '#caption', '#garage', '#gear', '#wardrobe', '#reader', '#confirm', '#viewfinder'].forEach((s) => show(s, false));
      if (window.Tablet) Tablet.hide(); return;
  }
});

const ESC_UI = [['#caption', 'caption'], ['#ivOffer', 'ivOffer'], ['#adOffer', 'adOffer'], ['#offer', 'offer'], ['#ivAsk', 'ivAsk'], ['#adForm', 'adForm'], ['#notes', 'notes'],
  ['#garage', 'garage'], ['#gear', 'gear'], ['#wardrobe', 'wardrobe']];
document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  e.preventDefault();
  if (isShown('#confirm')) { show('#confirm', false); if (confirmResolve) { confirmResolve(null); confirmResolve = null; } return; }
  for (const [sel, ui] of ESC_UI) if (isShown(sel)) return post('close', { ui });
  if (isShown('#reader')) { if (RD.art) { RD.art = null; return readerRender(); } return post('close', { ui: 'reader' }); }
  if (isShown('#f6')) { if (F6.view !== 'main') { F6.view = 'main'; return f6Draw(); } return post('close', { ui: 'f6' }); }
  if (window.Tablet && Tablet.isOpen()) { if (!Tablet.back()) post('close', { ui: 'tablet' }); }
});
