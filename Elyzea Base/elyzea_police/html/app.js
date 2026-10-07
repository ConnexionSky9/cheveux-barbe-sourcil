const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_police';
const post = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
const mdt = (action, data = {}) => post('mdt', { action, data });
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `$${Number(n || 0).toLocaleString('fr-FR')}`;
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const empty = (t) => `<div class="empty">${t}</div>`;
const PRIO = { 1: '', 2: 'amber', 3: 'red' };
const LICENCES = { driver: 'Permis de conduire', weapon: 'Permis de port d\'arme', business: 'Licence commerciale' };

const S = {
    page: 'home', fines: [], me: null, perms: {},
    profile: null, citizenQ: '', citizenList: [], vehicleQ: '', vehicleList: [],
    recordQ: '', draftRecord: null, draftWarrant: null, calls: [],
};

/* ================================================================== */
/* Messages Lua                                                        */
/* ================================================================== */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'alerts': S.keys = m.keys || S.keys; return renderAlerts(m.alerts || []);
        case 'jail': return jailHud(m);
        case 'actions':
            if (m.show) return openActions(m);
            document.body.classList.remove('panel-open');
            return $('#actions').classList.add('hidden');
        case 'myFines': return renderMyFines(m.fines || []);
        case 'mdt':
            S.fines = m.fines || [];
            $('#mdtTitle').textContent = m.jobLabel || 'Police';
            $('#mdt').classList.remove('hidden');
            if (m.page && m.page.name === 'profile') return openProfile(m.page.citizenid);
            return go('home');
        case 'mdtProfile': return openProfile(m.citizenid);
        case 'mdtEvent':
            if (!$('#mdt').classList.contains('hidden') && (S.page === 'calls' || S.page === 'home')) go(S.page, true);
            return;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#actions').classList.contains('hidden')) return closePanel('actions');
    if (!$('#myfines').classList.contains('hidden')) return closePanel('myfines');
    if (!$('#mdt').classList.contains('hidden')) return closePanel('mdt');
});

document.addEventListener('click', (e) => {
    const c = e.target.closest('[data-close]');
    if (c) closePanel(c.dataset.close);
});

function closePanel(which) {
    $(`#${which}`).classList.add('hidden');
    if (which === 'actions' || which === 'myfines') document.body.classList.remove('panel-open');
    if (which === 'actions') post('actionsClose');
    if (which === 'myfines') post('finesClose');
    if (which === 'mdt') post('mdtClose');
}

setInterval(() => {
    const d = new Date();
    $('#clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}, 1000);

/* ================================================================== */
/* Alertes                                                             */
/* ================================================================== */
function renderAlerts(list) {
    $('#alerts').innerHTML = list.slice(0, 3).map((a, i) => `
        <div class="alert p${a.priority} ${i ? 'secondary' : ''}">
            <div class="a-body">
                <div class="a-head"><span class="a-title">${esc(a.title)}</span><span class="a-code">${a.code ? esc(a.code) + ' · ' : ''}#${a.id}</span></div>
                ${a.message ? `<div class="a-msg">${esc(a.message)}</div>` : ''}
                <div class="a-meta">${a.street ? esc(a.street) + ' · ' : ''}${a.distance >= 1000 ? (a.distance / 1000).toFixed(1) + ' km' : a.distance + ' m'}${a.units ? ` · ${a.units} unité${a.units > 1 ? 's' : ''} en route` : ''}</div>
                ${i === 0 ? `<div class="a-keys"><span><kbd>${esc((S.keys && S.keys.accept) || 'G')}</kbd> Accepter</span><span><kbd>${esc((S.keys && S.keys.ignore) || 'I')}</kbd> Ignorer</span></div>` : ''}
            </div>
            <div class="a-time"><span style="width:${a.timeout ? (a.remaining / a.timeout) * 100 : 0}%"></span></div>
        </div>`).join('');
}

/* ================================================================== */
/* Prison                                                              */
/* ================================================================== */
function jailHud(m) {
    $('#jailhud').classList.toggle('hidden', !m.show);
    if (!m.show) return;
    $('#jailTime').textContent = mmss(m.remaining || 0);
    $('#jailReason').textContent = m.reason || '';
}

/* ================================================================== */
/* Amendes du citoyen                                                  */
/* ================================================================== */
function renderMyFines(rows) {
    document.body.classList.add('panel-open');
    $('#myfines').classList.remove('hidden');
    const total = rows.reduce((n, r) => n + r.amount, 0);
    $('#myFinesBody').innerHTML = rows.length ? `
        ${rows.map((r) => `<div class="row" style="background:var(--panel);border-radius:8px;margin-bottom:6px">
            <div><b>${esc(r.label)}</b><small>${esc(r.date)} · ${esc(r.officer)}</small></div>
            <div class="actions"><span class="mono">${money(r.amount)}</span><button class="btn primary" data-pay="${r.id}">Payer</button></div>
        </div>`).join('')}
        <div class="total"><span>Total dû</span><span class="mono">${money(total)}</span></div>
        <p class="lead" style="margin:0">Le paiement est prélevé sur votre compte en banque.</p>`
        : empty('Vous n\'avez aucune amende à payer.');
}
$('#myFinesBody').addEventListener('click', (e) => {
    const b = e.target.closest('[data-pay]');
    if (b) { b.disabled = true; post('payFine', { id: Number(b.dataset.pay) }); }
});

/* ================================================================== */
/* Menu d'interaction                                                  */
/* ================================================================== */
const A = { target: null, perms: {}, fines: [], maxJail: 120, view: 'main', picked: new Set() };

function openActions(m) {
    Object.assign(A, { target: m.target, perms: m.perms || {}, fines: m.fines || [], maxJail: m.maxJail || 120, hasInventory: m.hasInventory, view: 'main' });
    A.picked = new Set();
    document.body.classList.add('panel-open');
    $('#actions').classList.remove('hidden');
    renderActions();
}

function renderActions() {
    const t = A.target;
    $('#actTarget').textContent = t ? `${t.name}` : 'Personne à proximité';
    $('#actTargetSub').innerHTML = t
        ? `ID ${t.id}${t.cuffed ? ' <span class="tag red">Menotté</span>' : ''}${t.handsUp ? ' <span class="tag amber">Mains en l\'air</span>' : ''}${t.inVehicle ? ' <span class="tag">En véhicule</span>' : ''}`
        : 'Approchez-vous à moins de 3 m d\'une personne.';
    const body = $('#actBody');
    if (A.view === 'fine') return (body.innerHTML = fineView());
    if (A.view === 'jail') return (body.innerHTML = jailView());

    const dis = (ok) => (ok && t ? '' : 'disabled');
    body.innerHTML = `
        <div class="act-grid">
            <button class="act" data-do="cuff" ${dis(A.perms.cuff)}><strong>${t && t.cuffed ? 'Démenotter' : 'Menotter'}</strong><span>Personne la plus proche</span></button>
            <button class="act" data-do="escort" ${dis(A.perms.cuff && t && t.cuffed)}><strong>Escorter</strong><span>Prendre / lâcher</span></button>
            <button class="act" data-do="inVehicle" ${dis(A.perms.cuff && t && t.cuffed)}><strong>Mettre en véhicule</strong><span>Véhicule le plus proche</span></button>
            <button class="act" data-do="outVehicle" ${A.perms.cuff ? '' : 'disabled'}><strong>Sortir du véhicule</strong><span>Personnes menottées</span></button>
            <button class="act" data-do="search" ${dis(A.perms.search && A.hasInventory)}><strong>Fouiller</strong><span>${A.hasInventory ? 'Menotté ou mains en l\'air' : 'Nécessite elyzea_inventory'}</span></button>
            <button class="act" data-do="id" ${dis(A.perms.cuff)}><strong>Vérifier l'identité</strong><span>Ouvre son dossier</span></button>
            <button class="act" data-view="fine" ${dis(A.perms.fines)}><strong>Amende</strong><span>Catalogue des infractions</span></button>
            <button class="act" data-view="jail" ${dis(A.perms.jail)}><strong>Prison</strong><span>Envoyer en cellule</span></button>
            <button class="act wide" data-do="refresh"><strong>Actualiser</strong><span>Rechercher à nouveau la personne la plus proche</span></button>
        </div>`;
}

function fineView() {
    const cats = {};
    A.fines.forEach((f) => { (cats[f.category || 'Divers'] = cats[f.category || 'Divers'] || []).push(f); });
    const total = A.fines.filter((f) => A.picked.has(f.id)).reduce((n, f) => n + Number(f.amount), 0);
    return `
        <div class="fine-list">
            ${Object.entries(cats).map(([cat, list]) => `<div class="fine-cat">${esc(cat)}</div>
                ${list.map((f) => `<label class="fine-row"><input type="checkbox" data-fine="${esc(f.id)}" ${A.picked.has(f.id) ? 'checked' : ''}>
                    <span class="fl">${esc(f.label)}</span><span class="fa">${money(f.amount)}</span></label>`).join('')}`).join('')}
        </div>
        <div class="grid2">
            <label class="field">Autre motif<input type="text" id="fineCustomLabel" placeholder="Facultatif"></label>
            <label class="field">Montant<input type="number" min="0" id="fineCustomAmount" placeholder="0"></label>
        </div>
        <div class="total"><span>Total (catalogue)</span><span class="mono" id="fineTotal">${money(total)}</span></div>
        <div class="footer-actions" style="margin-top:4px">
            <button class="btn" data-view="main">Retour</button>
            <button class="btn primary" data-do="fine">Donner l'amende</button>
        </div>`;
}

function jailView() {
    const suggested = A.fines.filter((f) => A.picked.has(f.id)).reduce((n, f) => n + Number(f.jail || 0), 0);
    return `
        <div class="grid2" style="grid-template-columns:120px 1fr">
            <label class="field">Minutes<input type="number" min="1" max="${A.maxJail}" id="jailMinutes" value="${suggested || 10}"></label>
            <label class="field">Motif<input type="text" id="jailReasonInput" placeholder="Ex. : vol à main armée"></label>
        </div>
        <p class="lead" style="margin-top:10px">Maximum ${A.maxJail} minutes. Le temps ne s'écoule que lorsque le détenu est connecté.</p>
        <div class="footer-actions">
            <button class="btn" data-view="main">Retour</button>
            <button class="btn primary" data-do="jail">Envoyer en prison</button>
        </div>`;
}

$('#actBody').addEventListener('change', (e) => {
    const f = e.target.dataset.fine;
    if (!f) return;
    if (e.target.checked) A.picked.add(f); else A.picked.delete(f);
    const total = A.fines.filter((x) => A.picked.has(x.id)).reduce((n, x) => n + Number(x.amount), 0);
    $('#fineTotal').textContent = money(total);
});

$('#actBody').addEventListener('click', async (e) => {
    const v = e.target.closest('[data-view]');
    if (v && !v.disabled) { A.view = v.dataset.view; return renderActions(); }
    const b = e.target.closest('[data-do]');
    if (!b || b.disabled) return;
    const kind = b.dataset.do;
    if (kind === 'refresh') {
        const r = await post('actionsRefresh');
        A.target = r.target || null;
        return renderActions();
    }
    const payload = { kind, target: A.target ? A.target.id : null };
    if (kind === 'fine') {
        payload.items = [...A.picked];
        const amount = Number($('#fineCustomAmount').value);
        if (amount > 0) payload.custom = { label: $('#fineCustomLabel').value.trim() || 'Autre', amount };
    }
    if (kind === 'jail') {
        payload.minutes = Number($('#jailMinutes').value);
        payload.reason = $('#jailReasonInput').value.trim();
    }
    post('interact', payload);
    if (['cuff', 'escort', 'inVehicle', 'outVehicle'].includes(kind)) {
        setTimeout(async () => { const r = await post('actionsRefresh'); A.target = r.target || null; renderActions(); }, 600);
    } else {
        closePanel('actions');
    }
});

/* ================================================================== */
/* Tablette                                                            */
/* ================================================================== */
function toast(msg, ok = true) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = `toast ${ok ? 'ok' : 'err'}`;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.add('hidden'), 3500);
}

// Appel serveur + message automatique
async function run(action, data, reload = true) {
    const r = await mdt(action, data);
    if (r.error) { toast(r.error, false); return r; }
    if (r.message) toast(r.message, true);
    if (reload) go(S.page, true);
    return r;
}

$('#nav').addEventListener('click', (e) => {
    const b = e.target.closest('[data-page]');
    if (b) go(b.dataset.page);
});

function setNav(page) {
    document.querySelectorAll('#nav button').forEach((b) => b.classList.toggle('active', b.dataset.page === page));
}

async function go(page, keep) {
    S.page = page;
    setNav(page === 'profile' ? 'citizens' : page);
    const el = $('#page');
    const top = keep ? el.scrollTop : 0;
    if (!keep) el.innerHTML = '<p class="lead">Chargement…</p>';
    const html = await (PAGES[page] || PAGES.home)();
    if (S.page !== page) return; // l'agent a changé de page entre-temps
    el.innerHTML = html;
    el.scrollTop = top;
}

function updateMe(me) {
    S.me = me;
    S.perms = me.perms || {};
    const pill = $('#dutyPill');
    pill.className = `pill ${me.onduty ? 'on' : 'off'}`;
    pill.textContent = me.onduty ? 'En service' : 'Hors service';
    $('#navRoster').classList.toggle('hidden', !S.perms.roster);
}

const PAGES = {};

/* ---------- Accueil ---------- */
PAGES.home = async () => {
    const d = await mdt('dashboard');
    if (d.error) return empty(esc(d.error));
    updateMe(d.me);
    S.calls = d.calls;
    $('#callCount').textContent = d.calls.length || '';
    const me = d.me;
    return `
        <div class="profile-head">
            <div><h1>${esc(me.name)}</h1><p class="lead">${esc(me.gradeLabel)} · ${esc(me.jobLabel)}</p></div>
            <div style="display:flex;gap:8px;align-items:flex-end">
                <label class="field" style="width:120px">Indicatif<input type="text" id="callsign" value="${esc(me.callsign || '')}" placeholder="1-ADAM-12" maxlength="8"></label>
                <button class="btn" data-act="callsign">Enregistrer</button>
                <button class="btn ${me.onduty ? 'danger' : 'primary'}" data-act="duty">${me.onduty ? 'Terminer le service' : 'Prendre le service'}</button>
            </div>
        </div>
        <div class="stats" style="margin-top:14px">
            <div class="stat"><b>${d.units.length}</b><span>Agents en service</span></div>
            <div class="stat ${d.calls.length ? 'hot' : ''}"><b>${d.calls.length}</b><span>Appels en cours</span></div>
            <div class="stat ${d.warrants.length ? 'hot' : ''}"><b>${d.warrants.length}</b><span>Avis de recherche</span></div>
            <div class="stat"><b>${d.jailed}</b><span>Détenus</span></div>
        </div>
        <div class="cols">
            <div>
                <h2>Agents en service</h2>
                ${d.units.length ? `<div class="list">${d.units.map((u) => `<div class="row"><div><b>${u.callsign ? `<span class="mono">${esc(u.callsign)}</span> · ` : ''}${esc(u.name)}</b><small>${esc(u.grade)}</small></div></div>`).join('')}</div>` : empty('Personne en service.')}
                <h2>Derniers rapports</h2>
                ${d.records.length ? `<div class="list">${d.records.map((r) => `<div class="row click" data-profile="${esc(r.citizenid)}"><div><b>${esc(r.title)}</b><small>${esc(r.name)} · ${esc(r.officer)} · ${esc(r.date)}</small></div></div>`).join('')}</div>` : empty('Aucun rapport.')}
            </div>
            <div>
                <h2>Appels en cours</h2>
                ${callRows(d.calls.slice(0, 5))}
                <h2>Avis de recherche</h2>
                ${d.warrants.length ? `<div class="list">${d.warrants.map(warrantRow).join('')}</div>` : empty('Aucun avis actif.')}
            </div>
        </div>`;
};

/* ---------- Appels ---------- */
function callRows(calls) {
    if (!calls.length) return empty('Aucun appel en cours.');
    const myId = S.me ? S.me.id : -1;
    return `<div class="list">${calls.map((c) => {
        const mine = c.units.some((u) => u.id === myId);
        return `<div class="row">
            <div><b>${esc(c.title)}</b>${c.priority > 1 ? `<span class="tag ${PRIO[c.priority]}">${c.priority === 3 ? 'Urgent' : 'Important'}</span>` : ''}
                <small>${c.code ? `<span class="mono">${esc(c.code)}</span> · ` : ''}#${c.id} · ${esc(c.time)}${c.street ? ' · ' + esc(c.street) : ''}</small>
                ${c.message ? `<small>${esc(c.message)}</small>` : ''}
                <small>${c.units.length ? 'Unités : ' + c.units.map((u) => esc(u.name)).join(', ') : 'Aucune unité'}${c.caller ? ' · Appelant : ' + esc(c.caller) : ''}</small>
            </div>
            <div class="actions">
                <button class="btn" data-gps="${c.coords.x},${c.coords.y}">GPS</button>
                ${S.perms.dispatch ? `<button class="btn primary" data-accept="${c.id}" ${mine ? 'disabled' : ''}>${mine ? 'En route' : 'Accepter'}</button>
                <button class="btn danger" data-confirm="closeCall" data-id="${c.id}">Clôturer</button>` : ''}
            </div></div>`;
    }).join('')}</div>`;
}

PAGES.calls = async () => {
    const d = await mdt('calls');
    if (d.error) return `<h1>Appels</h1>${empty(esc(d.error))}`;
    $('#callCount').textContent = d.list.length || '';
    return `<h1>Appels</h1><p class="lead">Appels au 112, alertes automatiques et boutons panique. Ils disparaissent après 30 minutes.</p>${callRows(d.list)}`;
};

/* ---------- Citoyens ---------- */
PAGES.citizens = async () => `
    <h1>Citoyens</h1>
    <p class="lead">Recherchez par nom, prénom, numéro de téléphone ou identifiant.</p>
    <div class="searchbar"><input type="text" id="citizenQ" value="${esc(S.citizenQ)}" placeholder="Ex. : Lucas Martin"><button class="btn primary" data-act="searchCitizens">Rechercher</button></div>
    <div id="citizenResults">${citizenResults()}</div>`;

function citizenResults() {
    if (!S.citizenQ) return '';
    if (!S.citizenList.length) return empty('Aucun résultat.');
    return `<div class="list">${S.citizenList.map((c) => `<div class="row click" data-profile="${esc(c.citizenid)}">
        <div><b>${esc(c.name)}</b><small>${esc(c.citizenid)}${c.birthdate ? ' · né(e) le ' + esc(c.birthdate) : ''}${c.phone ? ' · ' + esc(c.phone) : ''}</small></div></div>`).join('')}</div>`;
}

async function openProfile(cid) {
    S.profileId = cid;
    S.page = 'profile';
    setNav('citizens');
    $('#mdt').classList.remove('hidden');
    $('#page').innerHTML = '<p class="lead">Chargement…</p>';
    if (!S.me) { const d = await mdt('dashboard'); if (!d.error) updateMe(d.me); }
    $('#page').innerHTML = await PAGES.profile();
}

PAGES.profile = async () => {
    const p = await mdt('profile', { citizenid: S.profileId });
    if (p.error) return empty(esc(p.error));
    S.profile = p;
    const lic = Object.assign({ driver: false, weapon: false }, p.licences || {});
    const unpaid = p.fines.filter((f) => !f.paid);
    return `
        <button class="btn" data-page-go="citizens" style="margin-bottom:12px">← Retour</button>
        <div class="profile-head">
            <div><h1>${esc(p.name)}</h1><p class="lead mono">${esc(p.citizenid)}${p.online ? ' <span class="tag green">En ville</span>' : ''}${p.warrants.length ? ' <span class="tag red">Recherché</span>' : ''}${p.jail ? ' <span class="tag amber">Détenu</span>' : ''}</p></div>
            <div style="display:flex;gap:8px">
                ${S.perms.records_write ? '<button class="btn primary" data-act="newRecordFor">Nouveau rapport</button>' : ''}
                ${S.perms.warrants ? '<button class="btn danger" data-act="newWarrantFor">Avis de recherche</button>' : ''}
            </div>
        </div>
        <div class="kv">
            <div><span>Date de naissance</span>${esc(p.birthdate || '—')}</div>
            <div><span>Sexe</span>${p.gender === 1 ? 'Femme' : p.gender === 0 ? 'Homme' : '—'}</div>
            <div><span>Téléphone</span>${esc(p.phone || '—')}</div>
            <div><span>Nationalité</span>${esc(p.nationality || '—')}</div>
            <div><span>Métier</span>${esc(p.job || '—')}</div>
            <div><span>Amendes impayées</span>${unpaid.length ? `<b style="color:#ff8a8d">${money(unpaid.reduce((n, f) => n + f.amount, 0))}</b>` : 'Aucune'}</div>
        </div>
        ${p.jail ? `<h2>Détention</h2><div class="list"><div class="row"><div><b>${mmss(p.jail.remaining)} restantes</b><small>${esc(p.jail.reason || 'Sans motif')} · ${esc(p.jail.officer || '')}</small></div>
            ${S.perms.jail ? `<div class="actions"><button class="btn danger" data-confirm="release" data-cid="${esc(p.citizenid)}">Libérer</button></div>` : ''}</div></div>` : ''}
        <h2>Permis</h2>
        <div class="licences">${Object.entries(lic).map(([k, v]) => `<div class="lic"><span>${esc(LICENCES[k] || k)}</span>
            <span class="tag ${v ? 'green' : 'red'}">${v ? 'Valide' : 'Aucun'}</span>
            ${S.perms.licenses ? `<button class="btn" data-lic="${esc(k)}" data-state="${v ? '0' : '1'}">${v ? 'Retirer' : 'Donner'}</button>` : ''}</div>`).join('')}</div>
        ${p.warrants.length ? `<h2>Avis de recherche</h2><div class="list">${p.warrants.map(warrantRow).join('')}</div>` : ''}
        <h2>Casier judiciaire (${p.records.length})</h2>
        ${p.records.length ? `<div class="list">${p.records.map((r) => `<div class="row" style="align-items:flex-start"><div style="flex:1">
            <b>${esc(r.title)}</b><small>${esc(r.date)} · ${esc(r.officer)}${r.charges ? ' · ' + esc(r.charges) : ''}${r.fine ? ' · ' + money(r.fine) : ''}${r.jail ? ` · ${r.jail} min` : ''}</small>
            <div class="record-body">${esc(r.content)}</div></div>
            ${S.perms.records_delete ? `<div class="actions"><button class="btn danger" data-confirm="deleteRecord" data-id="${r.id}">Supprimer</button></div>` : ''}</div>`).join('')}</div>` : empty('Casier vierge.')}
        <div class="cols">
            <div><h2>Amendes</h2>${p.fines.length ? `<div class="list">${p.fines.map((f) => `<div class="row"><div><b>${esc(f.label)}</b><small>${esc(f.date)} · ${esc(f.officer)}</small></div>
                <div class="actions"><span class="mono">${money(f.amount)}</span><span class="tag ${f.paid ? 'green' : 'red'}">${f.paid ? 'Payée' : 'Impayée'}</span></div></div>`).join('')}</div>` : empty('Aucune amende.')}</div>
            <div><h2>Véhicules</h2>${p.vehicles.length ? `<div class="list">${p.vehicles.map((v) => `<div class="row"><div><b class="mono">${esc(v.plate)}</b><small>${esc(v.vehicle)}</small></div></div>`).join('')}</div>` : empty('Aucun véhicule.')}</div>
        </div>`;
};

/* ---------- Véhicules ---------- */
PAGES.vehicles = async () => `
    <h1>Véhicules</h1>
    <p class="lead">Recherchez une plaque (même partielle) pour retrouver le propriétaire.</p>
    <div class="searchbar"><input type="text" id="vehicleQ" value="${esc(S.vehicleQ)}" placeholder="Ex. : 12ABC345" style="text-transform:uppercase"><button class="btn primary" data-act="searchVehicles">Rechercher</button></div>
    <div id="vehicleResults">${vehicleResults()}</div>`;

function vehicleResults() {
    if (!S.vehicleQ) return '';
    if (!S.vehicleList.length) return empty('Aucune plaque ne correspond.');
    return `<div class="list">${S.vehicleList.map((v) => `<div class="row click" data-profile="${esc(v.citizenid)}">
        <div><b class="mono">${esc(v.plate)}</b><small>${esc(v.model)} · propriétaire : ${esc(v.owner)}</small></div></div>`).join('')}</div>`;
}

/* ---------- Rapports ---------- */
PAGES.records = async () => {
    if (S.draftRecord) return recordEditor();
    const d = await mdt('records', { q: S.recordQ });
    if (d.error) return `<h1>Rapports</h1>${empty(esc(d.error))}`;
    return `
        <div class="profile-head"><h1>Rapports</h1>${S.perms.records_write ? '<button class="btn primary" data-act="newRecord">Nouveau rapport</button>' : ''}</div>
        <div class="searchbar" style="margin-top:10px"><input type="text" id="recordQ" value="${esc(S.recordQ)}" placeholder="Nom, titre ou agent"><button class="btn" data-act="searchRecords">Filtrer</button></div>
        ${d.list.length ? `<div class="list">${d.list.map((r) => `<div class="row click" data-profile="${esc(r.citizenid)}"><div><b>${esc(r.title)}</b>
            <small>${esc(r.name)} · ${esc(r.officer)} · ${esc(r.date)}${r.charges ? ' · ' + esc(r.charges) : ''}</small></div></div>`).join('')}</div>` : empty('Aucun rapport.')}`;
};

function recordEditor() {
    const r = S.draftRecord;
    const cats = {};
    S.fines.forEach((f) => { (cats[f.category || 'Divers'] = cats[f.category || 'Divers'] || []).push(f); });
    const total = S.fines.filter((f) => r.charges.includes(f.id)).reduce((a, f) => ({ fine: a.fine + Number(f.amount), jail: a.jail + Number(f.jail || 0) }), { fine: 0, jail: 0 });
    return `
        <h1>Nouveau rapport</h1>
        <div class="card">
            ${r.citizenid ? `<p style="margin-bottom:12px">Concerne : <b>${esc(r.name)}</b> <span class="mono" style="color:var(--muted)">${esc(r.citizenid)}</span> <button class="btn" data-act="pickOther">Changer</button></p>`
                : `<label class="field">Personne concernée<div class="searchbar" style="margin:0"><input type="text" id="recPersonQ" placeholder="Rechercher un citoyen"><button class="btn" data-act="recSearch">Chercher</button></div></label>
                   <div id="recPersonResults" style="margin:8px 0 12px"></div>`}
            <label class="field">Titre<input type="text" id="recTitle" value="${esc(r.title)}" placeholder="Ex. : Interpellation - vol de véhicule"></label>
            <label class="field" style="margin-top:12px">Infractions retenues
                <div class="charges">${Object.values(cats).flat().map((f) => `<span class="charge ${r.charges.includes(f.id) ? 'on' : ''}" data-charge="${esc(f.id)}">${esc(f.label)}</span>`).join('')}</div>
            </label>
            <p class="lead" style="margin:6px 0 0">Indicatif : ${money(total.fine)}${total.jail ? ` · ${total.jail} min de prison` : ''}. L'amende et la prison se donnent avec le menu d'interaction (F7).</p>
            <label class="field" style="margin-top:12px">Déroulé des faits<textarea id="recContent" placeholder="Décrivez les faits, l'intervention et les suites données.">${esc(r.content)}</textarea></label>
            <div class="footer-actions"><button class="btn" data-act="cancelRecord">Annuler</button><button class="btn primary" data-act="saveRecord">Enregistrer le rapport</button></div>
        </div>`;
}

/* ---------- Avis de recherche ---------- */
PAGES.warrants = async () => {
    if (S.draftWarrant) return warrantEditor();
    const d = await mdt('warrants');
    if (d.error) return `<h1>Avis de recherche</h1>${empty(esc(d.error))}`;
    return `
        <div class="profile-head"><h1>Avis de recherche</h1>${S.perms.warrants ? '<button class="btn primary" data-act="newWarrant">Nouvel avis</button>' : ''}</div>
        <p class="lead">Classés par dangerosité.</p>
        ${d.list.length ? `<div class="list">${d.list.map(warrantRow).join('')}</div>` : empty('Aucun avis actif.')}`;
};

function warrantRow(w) {
    const label = { 1: 'faible', 2: 'modérée', 3: 'élevée' }[w.danger] || '';
    return `<div class="row ${w.citizenid ? 'click' : ''}" ${w.citizenid ? `data-profile="${esc(w.citizenid)}"` : ''}>
        <div><b>${esc(w.name || '')}</b> <span class="tag ${w.danger === 3 ? 'red' : w.danger === 2 ? 'amber' : ''}">Dangerosité ${label}</span>
        <small>${esc(w.reason)}</small><small>${esc(w.officer)} · ${esc(w.date)}</small></div>
        ${S.perms.warrants ? `<div class="actions"><button class="btn danger" data-confirm="closeWarrant" data-id="${w.id}">Lever</button></div>` : ''}</div>`;
}

function warrantEditor() {
    const w = S.draftWarrant;
    return `
        <h1>Nouvel avis de recherche</h1>
        <div class="card">
            <div class="grid2">
                <label class="field">Nom de la personne<input type="text" id="warName" value="${esc(w.name)}" ${w.citizenid ? 'disabled' : ''} placeholder="Ex. : Individu au blouson rouge"></label>
                <label class="field">Dangerosité<select id="warDanger">
                    <option value="1" ${w.danger === 1 ? 'selected' : ''}>Faible</option>
                    <option value="2" ${w.danger === 2 ? 'selected' : ''}>Modérée</option>
                    <option value="3" ${w.danger === 3 ? 'selected' : ''}>Élevée</option></select></label>
            </div>
            <label class="field" style="margin-top:12px">Motif et signalement<textarea id="warReason" placeholder="Pourquoi est-il recherché, à quoi il ressemble, son véhicule…">${esc(w.reason)}</textarea></label>
            <div class="footer-actions"><button class="btn" data-act="cancelWarrant">Annuler</button><button class="btn primary" data-act="saveWarrant">Publier l'avis</button></div>
        </div>`;
}

/* ---------- Prison ---------- */
PAGES.jail = async () => {
    const d = await mdt('jailed');
    if (d.error) return `<h1>Prison</h1>${empty(esc(d.error))}`;
    return `<h1>Prison</h1><p class="lead">Temps restant à purger. Le temps ne s'écoule que lorsque le détenu est connecté.</p>
        ${d.list.length ? `<div class="list">${d.list.map((j) => `<div class="row click" data-profile="${esc(j.citizenid)}"><div><b>${esc(j.name)}</b>
            <small>${mmss(j.remaining)} restantes · ${esc(j.reason || 'Sans motif')} · ${esc(j.officer || '')}</small></div>
            ${S.perms.jail ? `<div class="actions"><button class="btn danger" data-confirm="release" data-cid="${esc(j.citizenid)}">Libérer</button></div>` : ''}</div>`).join('')}</div>` : empty('Aucun détenu.')}`;
};

/* ---------- Effectif ---------- */
PAGES.roster = async () => {
    const d = await mdt('roster');
    if (d.error) return `<h1>Effectif</h1>${empty(esc(d.error))}`;
    const myGrade = S.me ? S.me.grade : 0;
    const opts = (cur) => d.grades.filter((g) => g.level < myGrade || g.level === cur)
        .map((g) => `<option value="${g.level}" ${g.level === cur ? 'selected' : ''}>${g.level} · ${esc(g.name)}</option>`).join('');
    return `
        <h1>Effectif</h1>
        <p class="lead">Vous pouvez gérer les agents d'un grade inférieur au vôtre.</p>
        <div class="card" style="margin-bottom:16px"><div class="grid2" style="grid-template-columns:120px 1fr auto;align-items:end">
            <label class="field">ID du joueur<input type="number" id="hireId" min="1"></label>
            <label class="field">Grade<select id="hireGrade">${d.grades.filter((g) => g.level < myGrade).map((g) => `<option value="${g.level}">${g.level} · ${esc(g.name)}</option>`).join('')}</select></label>
            <button class="btn primary" data-act="hire">Recruter</button></div>
            <p class="lead" style="margin:8px 0 0">La personne doit être près de vous.</p></div>
        ${d.list.length ? `<div class="list">${d.list.map((m) => {
            const can = m.grade < myGrade;
            return `<div class="row" data-cid="${esc(m.citizenid)}"><div><b>${esc(m.name)}</b>
                ${m.online ? `<span class="tag ${m.onduty ? 'green' : 'blue'}">${m.onduty ? 'En service' : 'Connecté'}</span>` : '<span class="tag">Hors ligne</span>'}
                <small>${esc(m.gradeLabel)} · <span class="mono">${esc(m.citizenid)}</span></small></div>
                ${can ? `<div class="actions"><select class="rgrade" style="width:180px">${opts(m.grade)}</select><button class="btn" data-act="setGrade">Appliquer</button>
                    <button class="btn danger" data-confirm="fire" data-cid="${esc(m.citizenid)}">Renvoyer</button></div>` : ''}</div>`;
        }).join('')}</div>` : empty('Aucun agent.')}`;
};

/* ================================================================== */
/* Événements de la tablette                                           */
/* ================================================================== */
const Acts = {
    duty: () => run('toggleDuty'),
    callsign: () => run('setCallsign', { callsign: $('#callsign').value }),
    searchCitizens: async () => {
        S.citizenQ = $('#citizenQ').value.trim();
        const r = await mdt('searchCitizens', { q: S.citizenQ });
        if (r.error) return toast(r.error, false);
        S.citizenList = r.list || [];
        $('#citizenResults').innerHTML = citizenResults();
    },
    searchVehicles: async () => {
        S.vehicleQ = $('#vehicleQ').value.trim();
        const r = await mdt('searchVehicles', { q: S.vehicleQ });
        if (r.error) return toast(r.error, false);
        S.vehicleList = r.list || [];
        $('#vehicleResults').innerHTML = vehicleResults();
    },
    searchRecords: () => { S.recordQ = $('#recordQ').value.trim(); go('records'); },
    newRecord: () => { S.draftRecord = { citizenid: null, name: '', title: '', content: '', charges: [] }; go('records'); },
    newRecordFor: () => { const p = S.profile; S.draftRecord = { citizenid: p.citizenid, name: p.name, title: '', content: '', charges: [] }; go('records'); },
    pickOther: () => { keepRecordInputs(); S.draftRecord.citizenid = null; go('records', true); },
    cancelRecord: () => { S.draftRecord = null; go('records'); },
    recSearch: async () => {
        const r = await mdt('searchCitizens', { q: $('#recPersonQ').value.trim() });
        if (r.error) return toast(r.error, false);
        $('#recPersonResults').innerHTML = (r.list || []).length ? `<div class="list">${r.list.map((c) => `<div class="row click" data-pick="${esc(c.citizenid)}" data-name="${esc(c.name)}"><div><b>${esc(c.name)}</b><small>${esc(c.citizenid)}</small></div></div>`).join('')}</div>` : empty('Aucun résultat.');
    },
    saveRecord: async () => {
        keepRecordInputs();
        const r = S.draftRecord;
        if (!r.citizenid) return toast('Choisissez la personne concernée.', false);
        const res = await mdt('saveRecord', r);
        if (res.error) return toast(res.error, false);
        toast(res.message);
        S.draftRecord = null;
        openProfile(r.citizenid);
    },
    newWarrant: () => { S.draftWarrant = { citizenid: null, name: '', reason: '', danger: 1 }; go('warrants'); },
    newWarrantFor: () => { const p = S.profile; S.draftWarrant = { citizenid: p.citizenid, name: p.name, reason: '', danger: 1 }; go('warrants'); },
    cancelWarrant: () => { S.draftWarrant = null; go('warrants'); },
    saveWarrant: async () => {
        const w = S.draftWarrant;
        Object.assign(w, { name: $('#warName').value.trim() || w.name, reason: $('#warReason').value.trim(), danger: Number($('#warDanger').value) });
        const res = await mdt('createWarrant', w);
        if (res.error) return toast(res.error, false);
        toast(res.message);
        S.draftWarrant = null;
        go('warrants');
    },
    hire: () => run('hire', { target: Number($('#hireId').value), grade: Number($('#hireGrade').value) }),
    setGrade: (b) => { const row = b.closest('[data-cid]'); run('setGrade', { citizenid: row.dataset.cid, grade: Number(row.querySelector('.rgrade').value) }); },
};

function keepRecordInputs() {
    const r = S.draftRecord;
    if (!r) return;
    if ($('#recTitle')) r.title = $('#recTitle').value;
    if ($('#recContent')) r.content = $('#recContent').value;
}

const Confirmed = {
    closeCall: (b) => post('closeCall', { id: Number(b.dataset.id) }).then(() => setTimeout(() => go(S.page, true), 300)),
    deleteRecord: (b) => mdt('deleteRecord', { id: Number(b.dataset.id) }).then((r) => { toast(r.error || r.message, !r.error); openProfile(S.profileId); }),
    closeWarrant: (b) => run('closeWarrant', { id: Number(b.dataset.id) }, false).then(() => (S.page === 'profile' ? openProfile(S.profileId) : go(S.page, true))),
    release: (b) => run('release', { citizenid: b.dataset.cid }, false).then(() => (S.page === 'profile' ? openProfile(S.profileId) : go(S.page, true))),
    fire: (b) => run('fire', { citizenid: b.dataset.cid }),
};

$('#page').addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    const ids = { citizenQ: 'searchCitizens', vehicleQ: 'searchVehicles', recordQ: 'searchRecords', recPersonQ: 'recSearch' };
    if (ids[e.target.id]) Acts[ids[e.target.id]]();
});

$('#page').addEventListener('click', (e) => {
    const n = (sel) => e.target.closest(sel);
    let el;
    if ((el = n('[data-charge]'))) {
        keepRecordInputs();
        const ch = S.draftRecord.charges;
        const i = ch.indexOf(el.dataset.charge);
        if (i >= 0) ch.splice(i, 1); else ch.push(el.dataset.charge);
        return go('records', true);
    }
    if ((el = n('[data-pick]'))) {
        keepRecordInputs();
        Object.assign(S.draftRecord, { citizenid: el.dataset.pick, name: el.dataset.name });
        return go('records', true);
    }
    const b = n('button');
    if (b && b.disabled) return;
    if ((el = n('[data-gps]'))) { const [x, y] = el.dataset.gps.split(',').map(Number); return post('waypoint', { x, y }); }
    if ((el = n('[data-accept]'))) { post('acceptCall', { id: Number(el.dataset.accept) }); return setTimeout(() => go(S.page, true), 400); }
    if ((el = n('[data-lic]'))) return run('setLicense', { citizenid: S.profileId, license: el.dataset.lic, state: el.dataset.state === '1' }, false).then(() => openProfile(S.profileId));
    if ((el = n('[data-page-go]'))) return go(el.dataset.pageGo);
    if ((el = n('[data-confirm]'))) {
        if (!el.classList.contains('confirm')) {
            el.dataset.original = el.textContent;
            el.textContent = 'Confirmer ?';
            el.classList.add('confirm');
            setTimeout(() => { if (el.isConnected) { el.textContent = el.dataset.original; el.classList.remove('confirm'); } }, 3000);
            return;
        }
        return Confirmed[el.dataset.confirm]?.(el);
    }
    if ((el = n('[data-act]'))) return Acts[el.dataset.act]?.(el);
    if ((el = n('[data-profile]'))) return openProfile(el.dataset.profile);
});
