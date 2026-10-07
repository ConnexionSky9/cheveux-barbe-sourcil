const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_police_staff';
const post = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const action = (name, data = {}) => post('action', { action: name, data });
const ask = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .then((r) => r.json()).catch(() => ({ error: 'Pas de réponse.' }));
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `$${Number(n || 0).toLocaleString('fr-FR')}`;
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const empty = (t) => `<div class="empty">${t}</div>`;
const clone = (o) => JSON.parse(JSON.stringify(o));

const PERMS = [
    { k: 'mdt', label: 'Ouvrir la tablette', help: 'Accès à la tablette de l\'agent (F6).' },
    { k: 'dispatch', label: 'Accepter les appels', help: 'Prendre et clôturer les appels du dispatch.' },
    { k: 'cuff', label: 'Menotter, escorter, véhicule', help: 'Menottes, escorte, mettre ou sortir d\'un véhicule, vérifier l\'identité.' },
    { k: 'search', label: 'Fouiller', help: 'Ouvrir l\'inventaire d\'une personne (elyzea_inventory).' },
    { k: 'fines', label: 'Mettre une amende', help: 'Avec le catalogue ou un montant libre.' },
    { k: 'records_write', label: 'Écrire un rapport', help: 'Ajouter au casier judiciaire.' },
    { k: 'jail', label: 'Prison', help: 'Envoyer en prison et libérer.' },
    { k: 'warrants', label: 'Avis de recherche', help: 'Publier et lever des avis.' },
    { k: 'licenses', label: 'Permis', help: 'Donner ou retirer un permis de conduire ou de port d\'arme.' },
    { k: 'records_delete', label: 'Supprimer un rapport', help: 'Effacer une entrée du casier.' },
    { k: 'roster', label: 'Gérer l\'effectif', help: 'Recruter, promouvoir, renvoyer (grades inférieurs au sien).' },
];

const SETTINGS = [
    { k: 'alertTimeout', label: 'Affichage des appels', help: 'Temps pendant lequel un agent peut accepter un appel.', unit: 's' },
    { k: 'callCooldown', label: 'Délai entre deux /112', help: 'Anti-spam pour les citoyens.', unit: 's' },
    { k: 'shotsAlert', label: 'Alerte « coups de feu »', help: 'Prévient la police quand un civil tire sans silencieux.', bool: true },
    { k: 'shotsCooldown', label: 'Délai entre deux alertes de tir', help: 'Pour un même tireur.', unit: 's' },
    { k: 'colleagueBlips', label: 'Collègues sur la carte', help: 'Les agents en service se voient sur la carte.', bool: true },
    { k: 'searchNeedsCuff', label: 'Fouille seulement si menotté', help: 'Ou mains en l\'air.', bool: true },
    { k: 'maxJail', label: 'Prison maximum', help: 'Durée maximale d\'une peine.', unit: 'min' },
    { k: 'jailRadius', label: 'Rayon de la prison', help: 'Au-delà, le détenu est ramené au point de prison.', unit: 'm' },
    { k: 'maxFine', label: 'Amende maximum', help: 'Montant total maximum d\'une amende.', unit: '$' },
    { k: 'fineToSociety', label: 'Amendes versées au métier', help: 'Crédite le compte de l\'entreprise (elyzea_core).', bool: true },
    { k: 'blipSprite', label: 'Icône des appels', help: 'Numéro de blip GTA (161 = cercle d\'alerte).' },
    { k: 'blipColor', label: 'Couleur des appels', help: 'Numéro de couleur de blip GTA (3 = bleu).' },
];

const POINTS = [
    { k: 'duty', label: 'Prise de service', help: 'E pour prendre ou terminer son service.' },
    { k: 'armory', label: 'Armurerie', help: 'E pour ouvrir la boutique de l\'armurerie (elyzea_inventory).' },
    { k: 'jail', label: 'Prison (cellule)', help: 'Le premier point est utilisé pour les détenus.' },
    { k: 'release', label: 'Sortie de prison', help: 'Où le détenu est relâché. Le premier point est utilisé.' },
];

const st = { data: null, tab: 'overview', job: null, fines: null, armory: null, policeJobs: null, uniJob: null, trying: false };

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') { st.data = m.data; resetDrafts(); $('#mdt').classList.remove('hidden'); render(); }
    if (m.action === 'data') { st.data = m.data; if (st.saved) { resetDrafts(st.saved); st.saved = null; } render(); }
    if (m.action === 'close') $('#mdt').classList.add('hidden');
    if (m.action === 'toast') toast(m.message, m.kind !== 'error');
});

function resetDrafts(only) {
    const s = st.data.settings;
    if (!only || only === 'job') st.job = clone(s.job);
    if (!only || only === 'fines') st.fines = clone(s.fines);
    if (!only || only === 'armory') st.armory = clone(s.armory);
    if (!only || only === 'jobs') st.policeJobs = [...s.policeJobs];
}

function close() { $('#mdt').classList.add('hidden'); st.trying = false; post('close'); }
$('#closeBtn').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#mdt').classList.contains('hidden')) close(); });
setInterval(() => { const d = new Date(); $('#clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

function toast(msg, ok = true) {
    const t = $('#toast');
    t.textContent = msg;
    t.className = `toast ${ok ? 'ok' : 'err'}`;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.add('hidden'), 3500);
}

$('#nav').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tab]');
    if (!b) return;
    st.tab = b.dataset.tab;
    document.querySelectorAll('#nav button').forEach((x) => x.classList.toggle('active', x === b));
    render();
});

function render() {
    if (!st.data) return;
    const el = $('#page');
    const top = el.dataset.tab === st.tab ? el.scrollTop : 0;
    el.innerHTML = VIEWS[st.tab]();
    el.dataset.tab = st.tab;
    el.scrollTop = top;
}

const gradeOptions = (cur, grades) => grades.map((g, i) => `<option value="${i}" ${i === Number(cur) ? 'selected' : ''}>${i} · ${esc(g.name)}</option>`).join('');

const VIEWS = {};

/* ---------- Vue d'ensemble ---------- */
VIEWS.overview = () => {
    const d = st.data;
    const onDuty = d.units.filter((u) => u.onduty);
    return `
        <h1>Vue d'ensemble</h1>
        <p class="lead">État du métier Police en temps réel.</p>
        <div class="stats">
            <div class="stat"><b>${onDuty.length}</b><span>Agents en service</span></div>
            <div class="stat"><b>${d.units.length}</b><span>Policiers connectés</span></div>
            <div class="stat ${d.calls.length ? 'hot' : ''}"><b>${d.calls.length}</b><span>Appels en cours</span></div>
            <div class="stat"><b>${d.jailed.length}</b><span>Détenus</span></div>
        </div>
        <div class="cols">
            <div><h2>Policiers connectés</h2>
                ${d.units.length ? `<div class="list">${d.units.map((u) => `<div class="row"><div><b>[${u.id}] ${u.callsign ? `<span class="mono">${esc(u.callsign)}</span> · ` : ''}${esc(u.name)}</b>
                    <small>${esc(u.job)} · ${esc(u.grade)}</small></div><span class="tag ${u.onduty ? 'green' : ''}">${u.onduty ? 'En service' : 'Hors service'}</span></div>`).join('')}</div>` : empty('Aucun policier connecté.')}
                <h2>Personnes menottées</h2>
                ${d.cuffed.length ? `<div class="list">${d.cuffed.map((c) => `<div class="row"><div><b>[${c.id}] ${esc(c.name)}</b></div>
                    <div class="actions"><button class="btn" data-act="uncuff" data-target="${c.id}">Démenotter</button></div></div>`).join('')}</div>` : empty('Personne n\'est menotté.')}
            </div>
            <div><h2>Appels en cours</h2>
                ${d.calls.length ? `<div class="list">${d.calls.map((c) => `<div class="row"><div><b>${esc(c.title)}</b>
                    <small>#${c.id} · ${esc(c.time)}${c.street ? ' · ' + esc(c.street) : ''} · ${c.units.length} unité(s)</small>${c.message ? `<small>${esc(c.message)}</small>` : ''}</div>
                    <div class="actions"><button class="btn" data-act="tpCall" data-id="${c.id}">Y aller</button><button class="btn danger" data-confirm="closeCall" data-id="${c.id}">Clôturer</button></div></div>`).join('')}</div>` : empty('Aucun appel.')}
            </div>
        </div>
        <div class="footer-actions"><span></span><button class="btn" data-act="refresh">Actualiser</button></div>`;
};

/* ---------- Métier ---------- */
VIEWS.job = () => {
    const j = st.job;
    const core = st.data.coreJobs;
    return `
        <h1>Métier et grades</h1>
        <p class="lead">Le métier <b class="mono">${esc(j.name)}</b> est créé et mis à jour dans elyzea_core à chaque enregistrement, sans redémarrage.</p>
        <div class="card">
            <div class="grid2">
                <label class="field">Nom affiché<input type="text" data-jf="label" value="${esc(j.label)}"></label>
                <label class="field">Type<input type="text" data-jf="type" value="${esc(j.type || '')}" placeholder="leo"></label>
            </div>
            <label class="check" style="margin-top:8px"><input type="checkbox" data-jf="defaultDuty" ${j.defaultDuty ? 'checked' : ''}> En service à la connexion</label>
            <label class="check"><input type="checkbox" data-jf="offDutyPay" ${j.offDutyPay ? 'checked' : ''}> Payé hors service</label>
            <h2>Grades</h2>
            <div class="table-wrap"><table class="edit-table">
                <thead><tr><th style="width:60px">Niveau</th><th>Nom</th><th style="width:140px">Salaire ($)</th><th style="width:70px">Patron</th><th style="width:90px"></th></tr></thead>
                <tbody>${j.grades.map((g, i) => `<tr><td>${i}</td>
                    <td><input type="text" data-grade="${i}" data-gf="name" value="${esc(g.name)}"></td>
                    <td><input type="number" min="0" data-grade="${i}" data-gf="payment" value="${Number(g.payment) || 0}"></td>
                    <td><input type="checkbox" data-grade="${i}" data-gf="isboss" ${g.isboss ? 'checked' : ''}></td>
                    <td><button class="btn danger" data-act="removeGrade" data-i="${i}" ${j.grades.length <= 1 ? 'disabled' : ''}>Retirer</button></td></tr>`).join('')}</tbody>
            </table></div>
            <div class="footer-actions"><button class="btn" data-act="addGrade">Ajouter un grade</button>
                <div style="display:flex;gap:8px"><button class="btn" data-act="resetJob">Annuler</button><button class="btn primary" data-act="saveJob">Enregistrer le métier</button></div></div>
        </div>
        <h2>Métiers considérés comme police</h2>
        <p class="lead">Ils reçoivent le dispatch, ouvrent la tablette et utilisent les interactions (ex. sheriff, state police). Leurs agents utilisent leur propre niveau de grade.</p>
        <div class="card"><div class="jobs-pick">${core.map((c) => `<label class="check"><input type="checkbox" data-pj="${esc(c.name)}" ${st.policeJobs.includes(c.name) ? 'checked' : ''} ${c.name === j.name ? 'disabled' : ''}> ${esc(c.label)} <span class="mono" style="color:var(--muted);font-size:.8rem">${esc(c.name)}</span></label>`).join('')}</div>
            <div class="footer-actions"><span></span><button class="btn primary" data-act="savePoliceJobs">Enregistrer la liste</button></div></div>`;
};

/* ---------- Permissions ---------- */
VIEWS.perms = () => {
    const pg = st.data.settings.permGrades;
    const grades = st.data.settings.job.grades;
    return `
        <h1>Permissions par grade</h1>
        <p class="lead">Grade minimum pour chaque action. Les grades au-dessus l'ont aussi.</p>
        <div class="card settings-list" style="padding:0">
            ${PERMS.map((p) => `<div class="srow"><div><b>${p.label}</b><p>${p.help}</p></div>
                <select data-perm="${p.k}">${gradeOptions(pg[p.k] ?? 0, grades)}<option value="99" ${pg[p.k] >= 99 ? 'selected' : ''}>Personne</option></select></div>`).join('')}
        </div>
        <div class="footer-actions"><span></span><button class="btn primary" data-act="savePerms">Enregistrer les permissions</button></div>`;
};

/* ---------- Amendes ---------- */
VIEWS.fines = () => `
    <h1>Catalogue des amendes</h1>
    <p class="lead">Utilisé dans le menu d'interaction (F7) et les rapports. La prison indiquée est une suggestion pour l'agent.</p>
    <div class="table-wrap"><table class="edit-table">
        <thead><tr><th style="width:150px">Catégorie</th><th>Infraction</th><th style="width:120px">Montant ($)</th><th style="width:110px">Prison (min)</th><th style="width:90px"></th></tr></thead>
        <tbody>${st.fines.map((f, i) => `<tr>
            <td><input type="text" data-fine="${i}" data-ff="category" value="${esc(f.category)}"></td>
            <td><input type="text" data-fine="${i}" data-ff="label" value="${esc(f.label)}"></td>
            <td><input type="number" min="0" data-fine="${i}" data-ff="amount" value="${Number(f.amount) || 0}"></td>
            <td><input type="number" min="0" data-fine="${i}" data-ff="jail" value="${Number(f.jail) || 0}"></td>
            <td><button class="btn danger" data-act="removeFine" data-i="${i}">Retirer</button></td></tr>`).join('')}</tbody>
    </table></div>
    <div class="footer-actions"><button class="btn" data-act="addFine">Ajouter une infraction</button>
        <div style="display:flex;gap:8px"><button class="btn" data-act="resetFines">Annuler</button><button class="btn primary" data-act="saveFines">Enregistrer le catalogue</button></div></div>`;

/* ---------- Armurerie ---------- */
VIEWS.armory = () => {
    const grades = st.data.settings.job.grades;
    return `
        <h1>Armurerie</h1>
        <p class="lead">Objets disponibles au point « Armurerie ». Utilise les noms d'objets d'elyzea_inventory (ex. <span class="mono">WEAPON_STUNGUN</span>, <span class="mono">ammo-9</span>).</p>
        ${st.data.hasInventory ? '' : '<div class="warnbox">elyzea_inventory n\'est pas démarré : l\'armurerie et la fouille ne fonctionneront pas.</div>'}
        <div class="table-wrap"><table class="edit-table">
            <thead><tr><th>Objet</th><th style="width:130px">Prix ($)</th><th style="width:220px">Grade minimum</th><th style="width:90px"></th></tr></thead>
            <tbody>${st.armory.map((a, i) => `<tr>
                <td><input type="text" class="mono" data-arm="${i}" data-af="item" value="${esc(a.item)}"></td>
                <td><input type="number" min="0" data-arm="${i}" data-af="price" value="${Number(a.price) || 0}"></td>
                <td><select data-arm="${i}" data-af="grade">${gradeOptions(a.grade, grades)}</select></td>
                <td><button class="btn danger" data-act="removeArmory" data-i="${i}">Retirer</button></td></tr>`).join('')}</tbody>
        </table></div>
        <div class="footer-actions"><button class="btn" data-act="addArmory">Ajouter un objet</button>
            <div style="display:flex;gap:8px"><button class="btn" data-act="resetArmory">Annuler</button><button class="btn primary" data-act="saveArmory">Enregistrer l'armurerie</button></div></div>`;
};

/* ---------- Tenues ---------- */
VIEWS.uniforms = () => {
    const d = st.data;
    if (!d.uniformsAvailable) return `<h1>Tenues de service</h1><div class="warnbox">Les tenues sont gérées par admin_menu : démarre-le pour les utiliser.</div>`;
    const jobs = d.policeJobs || [];
    if (!jobs.length) return `<h1>Tenues de service</h1>${empty('Aucun métier police trouvé dans elyzea_core.')}`;
    const job = jobs.find((j) => j.name === st.uniJob) || jobs[0];
    st.uniJob = job.name;
    const uni = (d.uniforms || {})[job.name] || {};
    const status = (level, gender) => {
        const own = uni[String(level)];
        if (own && own[gender]) return '<span class="tag green">Définie</span>';
        for (let l = level - 1; l >= 0; l--) {
            const u = uni[String(l)];
            if (u && u[gender]) return `<span class="tag">Celle du grade ${l}</span>`;
        }
        return '<span class="tag red">Aucune</span>';
    };
    const chip = (level, gender, label) => {
        const own = uni[String(level)];
        return `<span style="display:inline-flex;align-items:center;gap:4px;margin-right:14px">${label} ${status(level, gender)}
            ${own && own[gender] ? `<button class="btn danger" style="padding:1px 7px" data-confirm="uniformDelete" data-grade="${level}" data-gender="${gender}" title="Supprimer">✕</button>` : ''}</span>`;
    };
    return `
        <h1>Tenues de service</h1>
        <p class="lead">Quand un agent prend son service, il enfile la tenue de son grade ; il retrouve ses vêtements en fin de service.
        Pour créer une tenue : habille-toi avec le magasin de vêtements, puis « Enregistrer ma tenue » sur le grade voulu.
        Un grade sans tenue prend celle du grade inférieur le plus proche. Homme et femme sont séparés (selon ton personnage).</p>
        ${jobs.length > 1 ? `<div class="searchbar"><select id="uniJob">${jobs.map((j) => `<option value="${esc(j.name)}" ${j.name === job.name ? 'selected' : ''}>${esc(j.label)}</option>`).join('')}</select></div>` : ''}
        ${st.trying ? '<div class="warnbox" style="display:flex;justify-content:space-between;align-items:center">Tu portes une tenue d\'essai.<button class="btn" data-act="uniformUntry">Remettre mes vêtements</button></div>' : ''}
        ${job.grades.length ? `<div class="list">${job.grades.map((g) => `<div class="row">
            <div><b>${g.level} · ${esc(g.label)}</b><small style="margin-top:6px">${chip(g.level, 'male', 'Homme')}${chip(g.level, 'female', 'Femme')}</small></div>
            <div class="actions">
                <button class="btn" data-act="uniformTry" data-grade="${g.level}" ${uni[String(g.level)] ? '' : 'disabled'}>Essayer</button>
                <button class="btn primary" data-act="uniformSave" data-grade="${g.level}">Enregistrer ma tenue</button>
            </div></div>`).join('')}</div>` : empty('Ce métier n\'a pas de grade.')}
        <div class="footer-actions"><span></span><button class="btn danger" data-confirm="uniformReset">Remettre les tenues par défaut</button></div>`;
};

/* ---------- Points ---------- */
VIEWS.points = () => {
    const pts = st.data.settings.points;
    return `<h1>Points</h1><p class="lead">« Ajouter ici » enregistre ta position actuelle.</p>
        ${POINTS.map((p) => {
            const list = pts[p.k] || [];
            return `<h2>${p.label}</h2><p class="lead" style="margin-top:-6px">${p.help}</p>
                ${list.length ? `<div class="list">${list.map((pt, i) => `<div class="row"><div><b>${esc(pt.label)}</b>${i === 0 && (p.k === 'jail' || p.k === 'release') ? '<span class="tag blue">Utilisé</span>' : ''}
                    <small class="mono">${pt.x.toFixed(1)}, ${pt.y.toFixed(1)}, ${pt.z.toFixed(1)}</small></div>
                    <div class="actions"><button class="btn" data-act="tpPoint" data-kind="${p.k}" data-i="${i + 1}">Y aller</button>
                    <button class="btn danger" data-confirm="deletePoint" data-kind="${p.k}" data-i="${i + 1}">Supprimer</button></div></div>`).join('')}</div>` : empty('Aucun point.')}
                <div class="searchbar" style="margin-top:8px"><input type="text" id="pt-${p.k}" placeholder="Nom du point (facultatif)"><button class="btn primary" data-act="addPoint" data-kind="${p.k}">Ajouter ici</button></div>`;
        }).join('')}`;
};

/* ---------- Réglages ---------- */
VIEWS.settings = () => {
    const s = st.data.settings.settings;
    return `<h1>Réglages</h1><p class="lead">Appliqués immédiatement à tous les joueurs.</p>
        <div class="card settings-list" style="padding:0">
            ${SETTINGS.map((f) => `<div class="srow"><div><b>${f.label}</b><p>${f.help}</p></div>
                ${f.bool ? `<label class="check"><input type="checkbox" data-sk="${f.k}" ${s[f.k] ? 'checked' : ''}> Activé</label>`
                    : `<div style="display:flex;gap:6px;align-items:center"><input type="number" min="0" data-sk="${f.k}" value="${Number(s[f.k]) || 0}"><span style="color:var(--muted);min-width:24px">${f.unit || ''}</span></div>`}</div>`).join('')}
        </div>
        <div class="footer-actions"><span></span><button class="btn primary" data-act="saveSettings">Enregistrer les réglages</button></div>`;
};

/* ---------- Dossiers ---------- */
VIEWS.files = () => {
    const d = st.data;
    return `<h1>Dossiers</h1><p class="lead">Modération des données de la police : détenus, avis, amendes impayées et rapports.</p>
        <h2>Détenus (${d.jailed.length})</h2>
        ${d.jailed.length ? `<div class="list">${d.jailed.map((j) => `<div class="row"><div><b>${esc(j.name)}</b><small>${mmss(j.remaining)} restantes · ${esc(j.reason || 'Sans motif')} · ${esc(j.officer || '')}</small></div>
            <div class="actions"><button class="btn danger" data-confirm="release" data-cid="${esc(j.citizenid)}">Libérer</button></div></div>`).join('')}</div>` : empty('Aucun détenu.')}
        <h2>Avis de recherche (${d.warrants.length})</h2>
        ${d.warrants.length ? `<div class="list">${d.warrants.map((w) => `<div class="row"><div><b>${esc(w.name)}</b><small>${esc(w.reason)}</small><small>${esc(w.officer)} · ${esc(w.date)}</small></div>
            <div class="actions"><button class="btn danger" data-confirm="closeWarrant" data-id="${w.id}">Lever</button></div></div>`).join('')}</div>` : empty('Aucun avis actif.')}
        <h2>Amendes impayées (${d.fines.length})</h2>
        ${d.fines.length ? `<div class="list">${d.fines.map((f) => `<div class="row"><div><b>${esc(f.name)} · ${money(f.amount)}</b><small>${esc(f.label)} · ${esc(f.officer)} · ${esc(f.date)}</small></div>
            <div class="actions"><button class="btn danger" data-confirm="deleteFine" data-id="${f.id}">Annuler</button></div></div>`).join('')}</div>` : empty('Aucune amende impayée.')}
        <h2>Derniers rapports</h2>
        ${d.records.length ? `<div class="list">${d.records.map((r) => `<div class="row"><div><b>${esc(r.title)}</b><small>${esc(r.name)} · ${esc(r.officer)} · ${esc(r.date)}${r.charges ? ' · ' + esc(r.charges) : ''}</small></div>
            <div class="actions"><button class="btn danger" data-confirm="deleteRecord" data-id="${r.id}">Supprimer</button></div></div>`).join('')}</div>` : empty('Aucun rapport.')}`;
};

/* ================================================================== */
/* Saisie                                                              */
/* ================================================================== */
$('#page').addEventListener('input', (e) => {
    const t = e.target;
    if (t.id === 'uniJob') { st.uniJob = t.value; st.trying && ask('uniformUntry'); st.trying = false; return render(); }
    const val = t.type === 'checkbox' ? t.checked : t.value;
    if (t.dataset.jf) st.job[t.dataset.jf] = val;
    if (t.dataset.grade !== undefined) st.job.grades[Number(t.dataset.grade)][t.dataset.gf] = t.dataset.gf === 'payment' ? Number(val) : val;
    if (t.dataset.fine !== undefined) st.fines[Number(t.dataset.fine)][t.dataset.ff] = ['amount', 'jail'].includes(t.dataset.ff) ? Number(val) : val;
    if (t.dataset.arm !== undefined) st.armory[Number(t.dataset.arm)][t.dataset.af] = ['price', 'grade'].includes(t.dataset.af) ? Number(val) : val;
    if (t.dataset.pj) {
        const i = st.policeJobs.indexOf(t.dataset.pj);
        if (t.checked && i < 0) st.policeJobs.push(t.dataset.pj);
        if (!t.checked && i >= 0) st.policeJobs.splice(i, 1);
    }
});

/* ================================================================== */
/* Boutons                                                             */
/* ================================================================== */
const save = (name, data, draft) => { st.saved = draft; action(name, data); };

const H = {
    refresh: () => action('refresh'),
    uncuff: (b) => action('uncuff', { target: Number(b.dataset.target) }),
    tpCall: (b) => action('tpCall', { id: Number(b.dataset.id) }),
    closeCall: (b) => action('closeCall', { id: Number(b.dataset.id) }),

    addGrade: () => { st.job.grades.push({ name: '', payment: 0, isboss: false }); render(); },
    removeGrade: (b) => { st.job.grades.splice(Number(b.dataset.i), 1); render(); },
    resetJob: () => { resetDrafts('job'); render(); },
    saveJob: () => save('saveJob', st.job, 'job'),
    savePoliceJobs: () => save('savePoliceJobs', { jobs: st.policeJobs }, 'jobs'),

    savePerms: () => {
        const out = {};
        document.querySelectorAll('[data-perm]').forEach((s) => { out[s.dataset.perm] = Number(s.value); });
        action('savePermGrades', out);
    },

    addFine: () => { st.fines.push({ id: '', category: 'Divers', label: '', amount: 0, jail: 0 }); render(); },
    removeFine: (b) => { st.fines.splice(Number(b.dataset.i), 1); render(); },
    resetFines: () => { resetDrafts('fines'); render(); },
    saveFines: () => save('saveFines', { fines: st.fines }, 'fines'),

    addArmory: () => { st.armory.push({ item: '', price: 0, grade: 0 }); render(); },
    removeArmory: (b) => { st.armory.splice(Number(b.dataset.i), 1); render(); },
    resetArmory: () => { resetDrafts('armory'); render(); },
    saveArmory: () => save('saveArmory', { armory: st.armory }, 'armory'),

    addPoint: (b) => action('addPoint', { kind: b.dataset.kind, label: ($(`#pt-${b.dataset.kind}`) || {}).value || '' }),
    tpPoint: (b) => action('tpPoint', { kind: b.dataset.kind, index: Number(b.dataset.i) }),
    deletePoint: (b) => action('deletePoint', { kind: b.dataset.kind, index: Number(b.dataset.i) }),

    saveSettings: () => {
        const out = {};
        document.querySelectorAll('[data-sk]').forEach((i) => { out[i.dataset.sk] = i.type === 'checkbox' ? i.checked : Number(i.value) || 0; });
        action('saveSettings', out);
    },

    uniformSave: async (b) => {
        const r = await ask('uniformCapture');
        if (!r || r.error) return toast((r && r.error) || 'Impossible de lire ta tenue.', false);
        action('uniformSave', { job: st.uniJob, grade: Number(b.dataset.grade), gender: r.gender, outfit: r.outfit });
    },
    uniformDelete: (b) => action('uniformDelete', { job: st.uniJob, grade: Number(b.dataset.grade), gender: b.dataset.gender }),
    uniformReset: () => action('uniformReset', { job: st.uniJob }),
    uniformTry: async (b) => {
        const r = await ask('uniformTry', { job: st.uniJob, grade: Number(b.dataset.grade) });
        if (!r || r.error) return toast((r && r.error) || 'Essai impossible.', false);
        st.trying = true;
        render();
    },
    uniformUntry: async () => { await ask('uniformUntry'); st.trying = false; render(); },

    release: (b) => action('release', { citizenid: b.dataset.cid }),
    closeWarrant: (b) => action('closeWarrant', { id: Number(b.dataset.id) }),
    deleteFine: (b) => action('deleteFine', { id: Number(b.dataset.id) }),
    deleteRecord: (b) => action('deleteRecord', { id: Number(b.dataset.id) }),
};

$('#page').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b || b.disabled) return;
    if (b.dataset.confirm) {
        if (!b.classList.contains('confirm')) {
            b.dataset.original = b.textContent;
            b.textContent = 'Confirmer ?';
            b.classList.add('confirm');
            setTimeout(() => { if (b.isConnected) { b.textContent = b.dataset.original; b.classList.remove('confirm'); } }, 3000);
            return;
        }
        return H[b.dataset.confirm]?.(b);
    }
    if (b.dataset.act) H[b.dataset.act]?.(b);
});
