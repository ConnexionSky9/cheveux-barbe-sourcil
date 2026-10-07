const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_concess';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .then((r) => r.json()).catch(() => ({}));
const req = (action, data = {}) => nui('req', { action, data });
const $ = (s, el = document) => el.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const empty = (t) => `<div class="empty">${t}</div>`;
const imgTag = (url, cls = '') => url ? `<img src="${esc(url)}" class="${cls}" alt="" onerror="this.replaceWith(Object.assign(document.createElement('span'),{className:'noimg',textContent:'🚗'}))">` : '<span class="noimg">🚗</span>';

const S = { currentVehicle: null, page: 'dashboard', me: null, dash: null, catalog: [], categories: [], cat: 'all', q: '', sort: 'price-asc', showHidden: false, pageN: 1, permsList: [], staff: false, viewer: false, spots: null };
const PER_PAGE = 24;

/* ================================================================== */
/* Notifications et confirmation                                       */
/* ================================================================== */
function toast(msg, kind = 'info') {
    if (!msg) return;
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = msg;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 320); }, 3800);
}

let confirmResolve = null;
function confirmBox(title, text, yes = 'Confirmer') {
    $('#confirmTitle').textContent = title;
    $('#confirmText').textContent = text || '';
    $('#confirmYes').textContent = yes;
    $('#confirm').classList.remove('hidden');
    return new Promise((r) => { confirmResolve = r; });
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-confirm]');
    if (!b) return;
    $('#confirm').classList.add('hidden');
    if (confirmResolve) { confirmResolve(b.dataset.confirm === 'yes'); confirmResolve = null; }
});

// Appel serveur avec retour visuel sur le bouton
async function run(btn, action, data, after) {
    if (btn) btn.classList.add('loading');
    const r = await req(action, data);
    if (btn) btn.classList.remove('loading');
    if (r.error) { toast(r.error, 'error'); return null; }
    if (r.message) toast(r.message, 'success');
    if (after) await after(r);
    return r;
}

/* ================================================================== */
/* Messages Lua                                                        */
/* ================================================================== */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'viewer':
            // Catalogue ouvert par un PNJ : on regarde, on n'achète pas
            Object.assign(S, { viewer: true, staff: false, me: null, dash: null, pageN: 1, cat: 'all', q: '', catalog: m.data.list || [], categories: m.data.categories || [],
                viewerTest: !!m.data.test, viewerTestDuration: m.data.testDuration || 120 });
            $('#company').textContent = m.data.company || 'Concession';
            $('#staffBadge').classList.add('hidden');
            $('#dutyPill').className = 'pill off';
            $('#dutyPill').textContent = 'Catalogue';
            $('#sideMe').innerHTML = '<b>Bienvenue</b><span class="muted small">Pour acheter, adresse-toi à un vendeur.</span>';
            $('#tablet').classList.remove('hidden');
            return go('catalog');
        case 'tablet':
            // Nouvelle ouverture : on repart de zéro (droits, brouillons)
            Object.assign(S, { me: null, dash: null, pageN: 1, viewer: false, spots: null });
            catDraft = null; permDraft = null; permMeta = null;
            S.staff = !!m.staff;
            S.permsList = m.permissions || [];
            $('#tablet').classList.remove('hidden');
            $('#staffBadge').classList.toggle('hidden', !S.staff);
            return go(S.staff ? 'catalog' : 'dashboard');
        case 'refresh': if (!$('#tablet').classList.contains('hidden')) go(S.page, true); return;
        case 'offer': return m.show ? openOffer(m.offer) : closeOffer();
        case 'garage': return openGarage(m.list || []);
        case 'test': return testHud(m);
    }
});

function closeTablet() {
    $('#tablet').classList.add('hidden');
    $('#modal').classList.add('hidden');
    nui('close');
}
$('#closeBtn').addEventListener('click', closeTablet);
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#confirm').classList.contains('hidden')) { $('#confirm').classList.add('hidden'); if (confirmResolve) confirmResolve(false); return; }
    if (!$('#modal').classList.contains('hidden')) return $('#modal').classList.add('hidden');
    if (!$('#garage').classList.contains('hidden')) { $('#garage').classList.add('hidden'); return nui('garageClose'); }
    if (!$('#tablet').classList.contains('hidden')) closeTablet();
});
setInterval(() => { const d = new Date(); $('#clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

/* ================================================================== */
/* Navigation                                                          */
/* ================================================================== */
const PAGES = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', group: 'Atelier de vente', show: () => !S.staff || (S.me && S.me.employee) },
    { id: 'catalog', label: 'Catalogue', ico: '🚘', group: 'Atelier de vente' },
    { id: 'showroom', label: 'Showroom', ico: '✨', group: 'Atelier de vente', perm: 'present' },
    { id: 'categories', label: 'Catégories', ico: '🗂️', group: 'Direction', perm: 'categories' },
    { id: 'employees', label: 'Employés', ico: '👥', group: 'Direction', perm: 'employees' },
    { id: 'permissions', label: 'Permissions', ico: '🔐', group: 'Direction', perm: 'permissions' },
    { id: 'finances', label: 'Finances', ico: '💰', group: 'Direction', perm: 'finances' },
];
const can = (perm) => !!(S.me && S.me.perms && S.me.perms[perm]);

function renderNav() {
    let last = null;
    $('#nav').innerHTML = PAGES.filter((p) => (S.viewer ? p.id === 'catalog' : (!p.perm || can(p.perm)) && (!p.show || p.show()))).map((p) => {
        const g = p.group !== last ? `<div class="nav-group">${p.group}</div>` : '';
        last = p.group;
        return `${g}<button data-page="${p.id}" class="${S.page === p.id ? 'active' : ''}"><span class="ico">${p.ico}</span><span class="lbl">${p.label}</span></button>`;
    }).join('');
}
$('#nav').addEventListener('click', (e) => { const b = e.target.closest('[data-page]'); if (b) go(b.dataset.page); });

function renderMe() {
    const me = S.me;
    if (!me) return;
    const pill = $('#dutyPill');
    pill.className = `pill ${me.onduty ? 'on' : 'off'}`;
    pill.textContent = me.staff && !me.employee ? 'Staff' : me.onduty ? 'En service' : 'Hors service';
    $('#sideMe').innerHTML = `<b>${esc(me.name)}</b><span class="muted small">${esc(me.gradeLabel || '')}</span>`;
}

async function loadMe() {
    const d = await req('dashboard');
    if (d.error) { toast(d.error, 'error'); return false; }
    S.dash = d;
    S.me = d.me;
    S.categories = d.categories || [];
    $('#company').textContent = d.company.label;
    renderMe();
    return true;
}

async function go(page, keep) {
    S.page = page;
    const el = $('#page');
    const top = keep ? el.scrollTop : 0;
    if (!keep) el.innerHTML = '<div class="grid cols-3">' + '<div class="skeleton" style="height:110px"></div>'.repeat(6) + '</div>';
    if (!S.viewer && (!S.me || page === 'dashboard' || keep)) { if (!(await loadMe())) { el.innerHTML = '<div class="state error">Impossible de charger la tablette.</div>'; return; } }
    renderNav();
    const p = PAGES.find((x) => x.id === page) || PAGES[0];
    $('#pageEyebrow').textContent = S.viewer ? 'Véhicules en vente' : p.group;
    $('#pageTitle').textContent = p.label;
    const html = await VIEWS[page]();
    if (S.page !== page) return;
    el.innerHTML = html;
    el.scrollTop = top;
    if (AFTER[page]) AFTER[page]();
}

const VIEWS = {};
const AFTER = {};

/* ================================================================== */
/* Tableau de bord                                                     */
/* ================================================================== */
VIEWS.dashboard = async () => {
    const d = S.dash;
    const me = d.me, st = d.stats;
    return `
        <div class="card hero">
            <div>
                <div class="eyebrow">${esc(d.company.label)}${d.company.enabled ? '' : ' · fermée'}</div>
                <h2>Bonjour ${esc(me.name.split(' ')[0])}</h2>
                <p class="muted">${esc(me.gradeLabel)} · ${me.onduty ? 'tu es <b style="color:var(--ok)">en service</b>' : 'tu es <b>hors service</b>'}</p>
            </div>
            ${me.employee ? `<button class="btn big ${me.onduty ? '' : 'primary'}" data-act="duty">${me.onduty ? 'TERMINER LE SERVICE' : 'SE METTRE EN SERVICE'}</button>` : ''}
        </div>
        <div class="grid cols-4" style="margin-top:14px">
            <div class="card stat"><span>Mes ventes (30 j)</span><b>${st.monthSales}</b><span class="small">${st.mySales} au total</span></div>
            <div class="card stat"><span>Mon chiffre (30 j)</span><b class="gold-text">${money(st.monthTotal)}</b><span class="small">${money(st.myTotal)} au total</span></div>
            <div class="card stat"><span>Véhicules en vente</span><b>${st.catalog}</b><span class="small">au catalogue</span></div>
            ${st.companyMonth ? `<div class="card stat"><span>Chiffre de l'entreprise (30 j)</span><b class="gold-text">${money(st.companyMonth.total)}</b><span class="small">${st.companyMonth.n} ventes · ${money(st.companyMonth.today)} aujourd'hui</span></div>`
                : `<div class="card stat"><span>Remise maximum</span><b>${me.perms.discount} %</b><span class="small">selon ton grade</span></div>`}
        </div>
        <div class="grid cols-2" style="margin-top:4px">
            <div><h3>Équipe en service</h3><div class="card">${d.team.length ? d.team.map((t) => `<div class="list-item"><div><b>${esc(t.name)}</b><div class="muted small">${esc(t.grade)}</div></div><span class="badge green">En service</span></div>`).join('') : '<p class="muted">Personne en service.</p>'}</div></div>
            <div><h3>Dernières ventes</h3><div class="card">${d.lastSales.length ? d.lastSales.map((s) => `<div class="list-item"><div><b>${esc(s.label)}</b><div class="muted small">${esc(s.buyer)} · par ${esc(s.seller)} · ${esc(s.date)}</div></div><b class="gold-text">${money(s.price)}</b></div>`).join('') : '<p class="muted">Aucune vente pour le moment.</p>'}</div></div>
        </div>
        ${me.onduty ? '' : '<p class="muted small" style="margin-top:14px">La vente, la présentation et les essais demandent d\'être en service. Ta tenue de travail est mise automatiquement à la prise de service et tes vêtements te sont rendus à la fin, même après une déconnexion.</p>'}`;
};

/* ================================================================== */
/* Catalogue                                                           */
/* ================================================================== */
VIEWS.catalog = async () => {
    if (S.viewer) return catalogHTML();
    const r = await req('catalog');
    if (r.error) return `<div class="state error">${esc(r.error)}</div>`;
    S.catalog = r.list || [];
    S.categories = r.categories || S.categories;
    return catalogHTML();
};

function filteredCatalog() {
    const q = S.q.trim().toLowerCase();
    let list = S.catalog.filter((v) => (S.cat === 'all' || v.category === S.cat) && (S.showHidden || !v.hidden)
        && (!q || v.label.toLowerCase().includes(q) || v.model.toLowerCase().includes(q)));
    const sorts = { 'price-asc': (a, b) => a.price - b.price, 'price-desc': (a, b) => b.price - a.price, name: (a, b) => a.label.localeCompare(b.label) };
    return list.sort(sorts[S.sort] || sorts['price-asc']);
}

function catalogHTML() {
    const manage = can('catalog') || can('hide');
    const counts = {};
    S.catalog.forEach((v) => { if (S.showHidden || !v.hidden) counts[v.category] = (counts[v.category] || 0) + 1; });
    const list = filteredCatalog();
    const pages = Math.max(1, Math.ceil(list.length / PER_PAGE));
    S.pageN = Math.min(S.pageN, pages);
    const slice = list.slice((S.pageN - 1) * PER_PAGE, S.pageN * PER_PAGE);
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    return `
        <div class="toolbar">
            <div class="search"><input type="search" id="q" placeholder="Rechercher un véhicule (nom ou modèle)" value="${esc(S.q)}"></div>
            <select id="sort">
                <option value="price-asc" ${S.sort === 'price-asc' ? 'selected' : ''}>Prix croissant</option>
                <option value="price-desc" ${S.sort === 'price-desc' ? 'selected' : ''}>Prix décroissant</option>
                <option value="name" ${S.sort === 'name' ? 'selected' : ''}>Nom (A → Z)</option>
            </select>
            ${manage ? `<label class="row small muted" style="cursor:pointer"><input type="checkbox" id="showHidden" ${S.showHidden ? 'checked' : ''}> Afficher les masqués</label>` : ''}
            ${can('catalog') ? '<button class="btn primary" data-act="addVehicle">＋ Ajouter un véhicule</button>' : ''}
        </div>
        <div class="chips">
            <button class="chip ${S.cat === 'all' ? 'on' : ''}" data-cat="all">Tous<small>${total}</small></button>
            ${S.categories.map((c) => `<button class="chip ${S.cat === c.id ? 'on' : ''}" data-cat="${esc(c.id)}">${esc(c.label)}<small>${counts[c.id] || 0}</small></button>`).join('')}
        </div>
        ${slice.length ? `<div class="vgrid">${slice.map((v, i) => `
            <button class="vcard ${v.hidden ? 'hidden-v' : ''}" data-vehicle="${v.id}" style="animation-delay:${Math.min(i, 12) * 25}ms">
                <div class="vimg">${imgTag(v.imageUrl)}<span class="badge gold vtag">${esc(v.categoryLabel)}</span>${v.hidden ? '<span class="badge red vstate">Masqué</span>' : ''}</div>
                <div class="vbody"><div class="vname">${esc(v.label)}</div><div class="vmodel">${esc(v.model)}</div><div class="vprice gold-text">${money(v.price)}</div></div>
            </button>`).join('')}</div>` : empty(S.q ? 'Aucun véhicule ne correspond à ta recherche.' : 'Aucun véhicule dans cette catégorie.')}
        ${pages > 1 ? `<div class="pager"><button class="btn ghost" data-pg="${S.pageN - 1}" ${S.pageN <= 1 ? 'disabled' : ''}>‹</button>
            <span class="muted">Page ${S.pageN} / ${pages}</span><button class="btn ghost" data-pg="${S.pageN + 1}" ${S.pageN >= pages ? 'disabled' : ''}>›</button></div>` : ''}`;
}
const rerenderCatalog = () => { const el = $('#page'); el.innerHTML = catalogHTML(); };

/* ---------- Détail d'un véhicule ---------- */
async function openVehicle(id) {
    const v = S.catalog.find((x) => x.id === id);
    if (!v) return;
    const maxDisc = (S.me.perms && S.me.perms.discount) || 0;
    $('#modalCard').innerHTML = `
        <button class="icon-btn modal-close" data-close-modal>✕</button>
        <div class="detail">
            <div>
                <div class="detail-img">${imgTag(v.imageUrl)}</div>
                <div class="bars" id="stats"><div class="skeleton" style="height:90px"></div></div>
            </div>
            <div>
                <div class="eyebrow">${esc(v.categoryLabel)}</div>
                <h2 style="font-size:1.7rem">${esc(v.label)}</h2>
                <div class="row" style="margin:4px 0 10px"><span class="badge">${esc(v.model)}</span>${v.hidden ? '<span class="badge red">Masqué</span>' : '<span class="badge green">En vente</span>'}</div>
                <div class="big-price gold-text">${money(v.price)}</div>
                ${v.description ? `<p class="muted" style="margin-top:8px;line-height:1.5">${esc(v.description)}</p>` : ''}
                ${S.viewer ? `<div class="sale-box">
                    ${S.viewerTest ? `<p class="muted" style="margin-bottom:10px">Essaie-le pendant ${mmss(S.viewerTestDuration)} : il t'attend sur le parking, tu es mis au volant.</p>
                        <button class="btn primary big" data-vact="npcTest" style="width:100%">🏁 Essai</button>` : ''}
                    <p class="muted small" style="margin-top:${S.viewerTest ? '10px' : '0'}">Pour l'acheter, adresse-toi à un vendeur de la concession.</p></div>` : `<div class="sale-box">
                    ${can('sell') ? `<label class="field"><span>Acheteur</span></label>
                    <div class="buyer" id="buyer">
                        <button class="buyer-opt on" data-buyer="nearest"><b>Personne la plus proche</b><small id="nearestName">Recherche…</small></button>
                        <button class="buyer-opt" data-buyer="self"><b>Moi-même</b><small>Achat personnel, sans commission</small></button>
                    </div>` : ''}
                    ${can('sell') ? `<label class="field" style="margin-top:10px"><span>Remise · <b id="discVal" style="color:var(--gold-hi)">0 %</b> <span class="small">(maximum ${maxDisc} % pour ton grade)</span></span>
                        <input type="range" id="disc" min="0" max="${maxDisc}" step="1" value="0" ${maxDisc ? '' : 'disabled'}></label>
                    <div class="final"><span class="muted">Prix proposé</span><span><span class="old hidden" id="oldPrice">${money(v.price)}</span><b class="big-price gold-text" style="font-size:1.5rem" id="finalPrice">${money(v.price)}</b></span></div>` : ''}
                    <div class="row" style="margin-top:12px;flex-wrap:wrap">
                        ${can('sell') ? `<button class="btn primary big" data-vact="sell" style="flex:1" ${v.hidden ? 'disabled title="Véhicule masqué"' : ''}>Vendre</button>` : ''}
                    </div>
                    ${can('present') ? `<div class="row" style="margin-top:12px;flex-wrap:wrap">
                        <select id="spotSel" style="flex:1;min-width:200px"><option value="">Recherche des emplacements…</option></select>
                        <button class="btn" data-vact="present" ${v.hidden ? 'disabled title="Véhicule masqué"' : ''}>Mettre en exposition</button></div>` : ''}
                </div>`}
                ${(can('catalog') || can('prices') || can('hide') || can('delete')) ? `<div class="row" style="margin-top:12px;flex-wrap:wrap">
                    ${(can('catalog') || can('prices')) ? '<button class="btn ghost" data-vact="edit">Modifier</button>' : ''}
                    ${can('hide') ? `<button class="btn ghost" data-vact="hide">${v.hidden ? 'Remettre en vente' : 'Masquer'}</button>` : ''}
                    ${can('delete') ? '<button class="btn danger" data-vact="delete">Supprimer</button>' : ''}
                </div>` : ''}
            </div>
        </div>`;
    S.currentVehicle = id;   // gardé en mémoire (et plus sur la fenêtre : un clic dedans rouvrait la fiche)
    $('#modal').classList.remove('hidden');
    // Clients proches et caractéristiques
    if (!S.viewer) nui('nearby').then((r) => {
        const el = $('#nearestName');
        if (!el) return;
        const p = ((r && r.list) || []).find((x) => x.distance <= 6);
        el.textContent = p ? `[${p.id}] ${p.name} · ${p.distance} m` : 'Personne à moins de 6 m';
    });
    if (can('present')) req('showroom').then((r) => {
        const sel = $('#spotSel');
        if (!sel || r.error) return;
        sel.innerHTML = r.spots.length ? r.spots.map((sp) => `<option value="${sp.id}">${esc(sp.label)} · ${sp.vehicle ? `remplace ${esc(sp.vehicle.label)}` : 'libre'} · ${sp.distance} m</option>`).join('')
            : '<option value="">Aucun emplacement (onglet Showroom)</option>';
    });
    nui('stats', { model: v.model }).then((s) => {
        const el = $('#stats');
        if (!el) return;
        if (!s || !s.exists) { el.innerHTML = '<p class="muted small">Caractéristiques indisponibles pour ce modèle.</p>'; return; }
        const pct = (val, max) => Math.max(4, Math.min(100, Math.round((val / max) * 100)));
        const row = (label, p, txt) => `<div class="bar"><span>${label}</span><div class="bar-track"><div class="bar-fill" style="width:0" data-w="${p}"></div></div><span>${txt}</span></div>`;
        el.innerHTML = row('Vitesse', pct(s.speed, 260), `${s.speed} km/h`) + row('Accélération', pct(s.acceleration, 0.5), Math.round(pct(s.acceleration, 0.5)) + ' %')
            + row('Freinage', pct(s.braking, 1.6), Math.round(pct(s.braking, 1.6)) + ' %') + row('Adhérence', pct(s.traction, 3.5), Math.round(pct(s.traction, 3.5)) + ' %')
            + `<div class="bar"><span>Places</span><span style="color:var(--text)">${s.seats}</span><span></span></div>`;
        requestAnimationFrame(() => el.querySelectorAll('.bar-fill').forEach((b) => { b.style.width = `${b.dataset.w}%`; }));
    });
}

document.addEventListener('input', (e) => {
    if (e.target.id === 'disc') {
        const v = S.catalog.find((x) => x.id === S.currentVehicle);
        const d = Number(e.target.value);
        $('#discVal').textContent = `${d} %`;
        $('#finalPrice').textContent = money(Math.floor(v.price * (100 - d) / 100));
        $('#oldPrice').classList.toggle('hidden', d === 0);
    }
    if (e.target.id === 'q') { S.q = e.target.value; S.pageN = 1; const pos = e.target.selectionStart; rerenderCatalog(); const q = $('#q'); q.focus(); q.setSelectionRange(pos, pos); }
    if (e.target.id === 'imgUrl') { const p = $('#imgPreview'); if (p) p.innerHTML = imgTag(e.target.value || `https://docs.fivem.net/vehicles/${($('#fModel') || {}).value || ''}.webp`); }
});
document.addEventListener('change', (e) => {
    if (e.target.id === 'sort') { S.sort = e.target.value; rerenderCatalog(); }
    if (e.target.id === 'showHidden') { S.showHidden = e.target.checked; S.pageN = 1; rerenderCatalog(); }
});

/* ---------- Ajouter / modifier un véhicule ---------- */
function vehicleForm(v) {
    const infoLocked = v && !can('catalog');
    const priceLocked = v && !can('prices');
    $('#modalCard').innerHTML = `
        <button class="icon-btn modal-close" data-close-modal>✕</button>
        <div class="eyebrow">${v ? 'Modifier' : 'Nouveau véhicule'}</div>
        <h2 style="margin-bottom:16px">${v ? esc(v.label) : 'Ajouter au catalogue'}</h2>
        <div class="detail">
            <div>
                <div class="detail-img" id="imgPreview">${imgTag(v ? v.imageUrl : '')}</div>
                <div class="bars" id="fStats"></div>
            </div>
            <div class="grid">
                <label class="field">Modèle (nom de spawn)
                    <div class="row"><input type="text" id="fModel" value="${esc(v ? v.model : '')}" placeholder="adder" ${infoLocked ? 'disabled' : ''}>
                    <button class="btn" data-act="checkModel" type="button">Vérifier</button></div></label>
                <label class="field">Nom affiché<input type="text" id="fLabel" value="${esc(v ? v.label : '')}" placeholder="Adder" ${infoLocked ? 'disabled' : ''}></label>
                <div class="grid cols-2">
                    <label class="field">Prix ($)<input type="number" id="fPrice" min="1" value="${v ? v.price : ''}" ${priceLocked ? 'disabled' : ''}></label>
                    <label class="field">Catégorie<select id="fCat" ${infoLocked ? 'disabled' : ''}>${S.categories.map((c) => `<option value="${esc(c.id)}" ${v && v.category === c.id ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></label>
                </div>
                <label class="field">Image (lien, facultatif : image du jeu sinon)<input type="text" id="imgUrl" value="${esc(v ? v.image : '')}" placeholder="https://…" ${infoLocked ? 'disabled' : ''}></label>
                <label class="field">Description<textarea id="fDesc" placeholder="Points forts, motorisation, équipements…" ${infoLocked ? 'disabled' : ''}>${esc(v ? v.description : '')}</textarea></label>
            </div>
        </div>
        <div class="row-end"><button class="btn" data-close-modal>Annuler</button><button class="btn primary" data-act="saveVehicle" data-id="${v ? v.id : ''}">${v ? 'Enregistrer' : 'Ajouter au catalogue'}</button></div>`;
    $('#modal').classList.remove('hidden');
}

/* ================================================================== */
/* Showroom                                                            */
/* ================================================================== */
VIEWS.showroom = async () => {
    const r = await req('showroom');
    if (r.error) return `<div class="state error">${esc(r.error)}</div>`;
    S.spots = r.spots;
    const vehOptions = (cur) => `<option value="">— Choisir un véhicule —</option>` + r.vehicles.map((v) => `<option value="${v.id}" ${cur === v.id ? 'selected' : ''}>${esc(v.label)} · ${esc(v.category)}</option>`).join('');
    return `
        <p class="muted" style="margin-bottom:14px">Chaque emplacement accueille un véhicule exposé : verrouillé, immobile, il reste en place même après un redémarrage.
            ${r.canManage ? 'Place-toi à l\'endroit voulu, tourné dans le sens du véhicule, puis ajoute ou déplace un emplacement.' : ''}</p>
        ${r.canManage ? `<div class="card" style="margin-bottom:14px"><div class="row" style="flex-wrap:wrap">
            <label class="field" style="flex:1;min-width:220px">Nom du nouvel emplacement<input type="text" id="spotLabel" placeholder="ex : Podium central"></label>
            <button class="btn primary" style="align-self:flex-end" data-act="spotAdd">📍 Ajouter à ma position</button></div></div>` : ''}
        ${r.spots.length ? `<div class="vgrid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">${r.spots.map((sp) => `
            <div class="vcard" style="cursor:default" data-spot="${sp.id}">
                <div class="vimg">${sp.vehicle ? imgTag(sp.vehicle.imageUrl) : '<span class="noimg">✨</span>'}
                    <span class="badge ${sp.vehicle ? 'gold' : ''} vtag">${sp.vehicle ? 'En exposition' : 'Libre'}</span><span class="badge vstate">${sp.distance} m</span></div>
                <div class="vbody">
                    <div class="vname">${esc(sp.label)}</div>
                    <div class="vmodel">${sp.vehicle ? `${esc(sp.vehicle.label)} · ${money(sp.vehicle.price)}` : 'Aucun véhicule exposé'}</div>
                    <select class="spot-veh" style="margin-top:10px">${vehOptions(sp.vehicle && sp.vehicle.id)}</select>
                    <div class="row" style="margin-top:8px;flex-wrap:wrap">
                        <button class="btn primary" data-act="exhibit">Exposer</button>
                        ${sp.vehicle ? '<button class="btn" data-act="unexhibit">Retirer</button>' : ''}
                        ${r.canManage ? '<button class="btn ghost" data-act="spotMove" title="Déplacer à ma position">📍</button><button class="btn danger" data-act="spotDelete">✕</button>' : ''}
                    </div>
                </div>
            </div>`).join('')}</div>` : empty('Aucun emplacement d\'exposition.' + (r.canManage ? ' Ajoute-en un à ta position.' : ' Demande à la direction d\'en créer.'))}`;
};

/* ================================================================== */
/* Catégories                                                          */
/* ================================================================== */
let catDraft = null;
VIEWS.categories = async () => {
    if (!catDraft) catDraft = JSON.parse(JSON.stringify(S.categories));
    return `
        <p class="muted" style="margin-bottom:14px">L'ordre ici est celui du catalogue. Les véhicules d'une catégorie supprimée passent dans la première.</p>
        <div class="card"><table class="table"><tr><th>Nom affiché</th><th>Identifiant</th><th style="width:150px"></th></tr>
            ${catDraft.map((c, i) => `<tr><td><input type="text" data-cat-l="${i}" value="${esc(c.label)}"></td><td><input type="text" data-cat-i="${i}" value="${esc(c.id)}" placeholder="auto"></td>
                <td style="text-align:right;white-space:nowrap"><button class="btn ghost" data-catmv="${i}:-1" ${i === 0 ? 'disabled' : ''}>↑</button><button class="btn ghost" data-catmv="${i}:1" ${i === catDraft.length - 1 ? 'disabled' : ''}>↓</button><button class="btn danger" data-catdel="${i}">✕</button></td></tr>`).join('')}
        </table>
        <div class="row-between" style="margin-top:12px"><button class="btn" data-act="catAdd">＋ Ajouter une catégorie</button>
            <div class="row"><button class="btn ghost" data-act="catReset">Annuler</button><button class="btn primary" data-act="catSave">Enregistrer</button></div></div></div>`;
};

/* ================================================================== */
/* Employés                                                            */
/* ================================================================== */
VIEWS.employees = async () => {
    const r = await req('employees');
    if (r.error) return `<div class="state error">${esc(r.error)}</div>`;
    const opts = (cur) => r.grades.filter((g) => g.level < r.myGrade || g.level === cur).map((g) => `<option value="${g.level}" ${g.level === cur ? 'selected' : ''}>${g.level} · ${esc(g.label)}</option>`).join('');
    return `
        <div class="card" style="margin-bottom:14px"><div class="row" style="flex-wrap:wrap">
            <label class="field" style="width:130px">ID du joueur<input type="number" id="hireId" min="1"></label>
            <label class="field" style="flex:1;min-width:200px">Grade<select id="hireGrade">${r.grades.filter((g) => g.level < r.myGrade).map((g) => `<option value="${g.level}">${g.level} · ${esc(g.label)}</option>`).join('')}</select></label>
            <button class="btn primary" style="align-self:flex-end" data-act="hire">Recruter</button></div>
            <p class="muted small" style="margin-top:8px">La personne doit être près de toi. Tu ne gères que les grades inférieurs au tien.</p></div>
        ${r.list.length ? `<div class="card"><table class="table"><tr><th>Employé</th><th>Statut</th><th>Ventes (30 j)</th><th style="width:330px">Grade</th></tr>
            ${r.list.map((m) => `<tr data-cid="${esc(m.citizenid)}"><td><b>${esc(m.name)}</b><div class="muted small">${esc(m.gradeLabel)}</div></td>
                <td>${m.online ? `<span class="badge ${m.onduty ? 'green' : 'blue'}">${m.onduty ? 'En service' : 'Connecté'}</span>` : '<span class="badge">Hors ligne</span>'}</td>
                <td>${m.sales} · <span class="gold-text">${money(m.revenue)}</span></td>
                <td>${m.grade < r.myGrade ? `<div class="row"><select class="egrade">${opts(m.grade)}</select><button class="btn" data-act="setGrade">OK</button><button class="btn danger" data-act="fire">Renvoyer</button></div>` : '<span class="muted small">—</span>'}</td></tr>`).join('')}
        </table></div>` : empty('Aucun employé.')}`;
};

/* ================================================================== */
/* Permissions                                                         */
/* ================================================================== */
let permDraft = null, permMeta = null;
VIEWS.permissions = async () => {
    if (!permDraft) {
        const r = await req('permissions');
        if (r.error) return `<div class="state error">${esc(r.error)}</div>`;
        permDraft = JSON.parse(JSON.stringify(r.perms || {}));
        permMeta = r;
    }
    const r = permMeta;
    return `
        <p class="muted" style="margin-bottom:14px">Coche ce que chaque grade peut faire et fixe sa remise maximum. Tu ne modifies que les grades inférieurs au tien.</p>
        <div class="card" style="overflow-x:auto"><table class="table">
            <tr><th>Grade</th>${r.list.map((p) => `<th style="text-align:center">${esc(p.label)}</th>`).join('')}<th style="text-align:center;width:110px">Remise max</th></tr>
            ${r.grades.map((g) => {
                const row = permDraft[String(g.level)] || {};
                const locked = g.level >= r.myGrade;
                return `<tr><td><b>${g.level} · ${esc(g.label)}</b></td>
                    ${r.list.map((p) => `<td style="text-align:center"><input type="checkbox" data-perm="${g.level}:${p.key}" ${row[p.key] ? 'checked' : ''} ${locked ? 'disabled' : ''}></td>`).join('')}
                    <td><input type="number" min="0" max="100" data-disc="${g.level}" value="${Number(row.discount) || 0}" ${locked ? 'disabled' : ''}></td></tr>`;
            }).join('')}
        </table>
        <div class="row-end"><button class="btn ghost" data-act="permReset">Annuler</button><button class="btn primary" data-act="permSave">Enregistrer</button></div></div>`;
};

/* ================================================================== */
/* Finances                                                            */
/* ================================================================== */
VIEWS.finances = async () => {
    const f = await req('finances');
    if (f.error) return `<div class="state error">${esc(f.error)}</div>`;
    const max = Math.max(1, ...f.days.map((d) => Number(d.total) || 0));
    const card = (label, p) => `<div class="card stat"><span>${label}</span><b class="gold-text">${money(p.total)}</b><span class="small">${p.n} vente${p.n > 1 ? 's' : ''}${Number(p.discounts) ? ` · ${money(p.discounts)} de remises` : ''}</span></div>`;
    return `
        <div class="grid cols-4">
            <div class="card stat"><span>Compte de l'entreprise</span><b class="gold-text">${f.balance != null ? money(f.balance) : '—'}</b><span class="small">${f.balance != null ? 'Solde actuel' : 'Renewed-Banking non détecté'}</span></div>
            ${card('Aujourd\'hui', f.today)}${card('7 derniers jours', f.week)}${card('30 derniers jours', f.month)}
        </div>
        <h3>Chiffre d'affaires · 14 jours</h3>
        <div class="card">${f.days.length ? `<div class="chart">${f.days.map((d) => `<div class="col" title="${money(d.total)} · ${d.n} vente(s)"><div class="fill" style="height:${Math.round((Number(d.total) / max) * 100)}%"></div><span class="lbl">${esc(d.day)}</span></div>`).join('')}</div>` : '<p class="muted">Pas encore de vente.</p>'}</div>
        <div class="grid cols-2" style="margin-top:4px">
            <div><h3>Véhicules les plus vendus (30 j)</h3><div class="card">${f.topVehicles.length ? f.topVehicles.map((t, i) => `<div class="list-item"><div><b>${i + 1}. ${esc(t.label)}</b><div class="muted small">${t.n} vente(s)</div></div><b class="gold-text">${money(t.total)}</b></div>`).join('') : '<p class="muted">—</p>'}</div></div>
            <div><h3>Meilleurs vendeurs (30 j)</h3><div class="card">${f.topSellers.length ? f.topSellers.map((t, i) => `<div class="list-item"><div><b>${i + 1}. ${esc(t.seller)}</b><div class="muted small">${t.n} vente(s)</div></div><b class="gold-text">${money(t.total)}</b></div>`).join('') : '<p class="muted">—</p>'}</div></div>
        </div>
        <h3>Historique des ventes</h3>
        <div class="card" style="overflow-x:auto">${f.sales.length ? `<table class="table"><tr><th>Date</th><th>Véhicule</th><th>Client</th><th>Vendeur</th><th>Plaque</th><th style="text-align:right">Prix</th></tr>
            ${f.sales.map((s) => `<tr><td class="muted small">${esc(s.date)}</td><td><b>${esc(s.label)}</b></td><td>${esc(s.buyer)}</td><td>${esc(s.seller)}</td><td><span class="plate">${esc(s.plate || '')}</span></td>
                <td style="text-align:right"><b class="gold-text">${money(s.price)}</b>${s.discount ? `<div class="muted small">-${s.discount} %</div>` : ''}</td></tr>`).join('')}</table>` : '<p class="muted">Aucune vente.</p>'}
        </div>`;
};

/* ================================================================== */
/* Clics                                                               */
/* ================================================================== */
document.addEventListener('click', async (e) => {
    let n;
    if ((n = e.target.closest('[data-close-modal]'))) return $('#modal').classList.add('hidden');
    if ((n = e.target.closest('[data-buyer]'))) { document.querySelectorAll('#buyer .buyer-opt').forEach((b) => b.classList.toggle('on', b === n)); return; }
    if (e.target.id === 'modal') return $('#modal').classList.add('hidden');
    if ((n = e.target.closest('[data-cat]'))) { S.cat = n.dataset.cat; S.pageN = 1; return rerenderCatalog(); }
    if ((n = e.target.closest('[data-pg]')) && !n.disabled) { S.pageN = Number(n.dataset.pg); rerenderCatalog(); return $('#page').scrollTo(0, 0); }
    // Seules les cartes du catalogue ouvrent une fiche (jamais un clic dans une fenêtre)
    if (!e.target.closest('.modal') && (n = e.target.closest('.vgrid [data-vehicle]'))) return openVehicle(Number(n.dataset.vehicle));
    if ((n = e.target.closest('[data-catmv]'))) { const [i, d] = n.dataset.catmv.split(':').map(Number); const t = catDraft[i]; catDraft[i] = catDraft[i + d]; catDraft[i + d] = t; return go('categories', true); }
    if ((n = e.target.closest('[data-catdel]'))) { catDraft.splice(Number(n.dataset.catdel), 1); return go('categories', true); }

    if ((n = e.target.closest('[data-vact]')) && !n.disabled) {
        const id = S.currentVehicle;
        const v = S.catalog.find((x) => x.id === id);
        const a = n.dataset.vact;
        if (a === 'npcTest') { $('#modal').classList.add('hidden'); $('#tablet').classList.add('hidden'); return nui('npcTest', { id }); }
        if (a === 'sell') {
            const buyer = (($('#buyer .buyer-opt.on') || {}).dataset || {}).buyer || 'nearest';
            const disc = Number(($('#disc') || {}).value || 0);
            // Le client (ou toi) reçoit « Voulez-vous acheter ce véhicule à ce prix ? » et répond oui / non
            return run(n, 'sell', { id, target: buyer, discount: disc }, () => $('#modal').classList.add('hidden'));
        }
        if (a === 'present') {
            const zone = Number(($('#spotSel') || {}).value);
            if (!zone) return toast('Choisis un emplacement du showroom.', 'error');
            return run(n, 'exhibit', { id, zone }, () => $('#modal').classList.add('hidden'));
        }
        if (a === 'edit') return vehicleForm(v);
        if (a === 'hide') return run(n, 'vehicleHide', { id, hidden: !v.hidden }, async () => { $('#modal').classList.add('hidden'); await go('catalog', true); });
        if (a === 'delete') {
            if (!(await confirmBox(`Supprimer ${v.label} ?`, 'Il disparaît du catalogue. Les véhicules déjà vendus ne sont pas touchés.', 'Supprimer'))) return;
            return run(n, 'vehicleDelete', { id }, async () => { $('#modal').classList.add('hidden'); await go('catalog', true); });
        }
    }

    if (!(n = e.target.closest('[data-act]')) || n.disabled) return;
    const a = n.dataset.act;
    switch (a) {
        case 'duty': return run(n, 'toggleDuty', {}, () => go('dashboard', true));
        case 'spotAdd': return run(n, 'spotAdd', { label: ($('#spotLabel') || {}).value || '' }, () => go('showroom', true));
        case 'exhibit': {
            const card = n.closest('[data-spot]');
            const id = Number(card.querySelector('.spot-veh').value);
            if (!id) return toast('Choisis le véhicule à exposer.', 'error');
            return run(n, 'exhibit', { id, zone: Number(card.dataset.spot) }, () => go('showroom', true));
        }
        case 'unexhibit': return run(n, 'unexhibit', { zone: Number(n.closest('[data-spot]').dataset.spot) }, () => go('showroom', true));
        case 'spotMove': {
            if (!(await confirmBox('Déplacer l\'emplacement ici ?', 'Il prend ta position et ton orientation. Le véhicule exposé suit.', 'Déplacer'))) return;
            return run(n, 'spotMove', { zone: Number(n.closest('[data-spot]').dataset.spot) }, () => go('showroom', true));
        }
        case 'spotDelete': {
            if (!(await confirmBox('Supprimer cet emplacement ?', 'Le véhicule exposé dessus est retiré.', 'Supprimer'))) return;
            return run(n, 'spotDelete', { zone: Number(n.closest('[data-spot]').dataset.spot) }, () => go('showroom', true));
        }
        case 'addVehicle': return vehicleForm(null);
        case 'checkModel': {
            const model = ($('#fModel').value || '').trim().toLowerCase();
            if (!model) return;
            const s = await nui('stats', { model });
            $('#fStats').innerHTML = s && s.exists ? `<span class="badge green">Modèle trouvé</span> <span class="muted small">${s.speed} km/h · ${s.seats} places</span>` : '<span class="badge red">Modèle introuvable sur ce serveur</span>';
            if (!$('#imgUrl').value) $('#imgPreview').innerHTML = imgTag(`https://docs.fivem.net/vehicles/${model}.webp`);
            return;
        }
        case 'saveVehicle': {
            const data = { id: n.dataset.id ? Number(n.dataset.id) : undefined, model: $('#fModel').value, label: $('#fLabel').value, price: Number($('#fPrice').value),
                category: $('#fCat').value, image: $('#imgUrl').value, description: $('#fDesc').value };
            return run(n, 'vehicleSave', data, async () => { $('#modal').classList.add('hidden'); await go('catalog', true); });
        }
        case 'catAdd': catDraft.push({ id: '', label: '' }); return go('categories', true);
        case 'catReset': catDraft = null; return go('categories', true);
        case 'catSave': {
            document.querySelectorAll('[data-cat-l]').forEach((i) => { catDraft[Number(i.dataset.catL)].label = i.value; });
            document.querySelectorAll('[data-cat-i]').forEach((i) => { catDraft[Number(i.dataset.catI)].id = i.value; });
            return run(n, 'categoriesSave', { categories: catDraft }, async () => { catDraft = null; await loadMe(); await go('categories', true); });
        }
        case 'hire': return run(n, 'hire', { target: Number($('#hireId').value), grade: Number($('#hireGrade').value) }, () => go('employees', true));
        case 'setGrade': { const tr = n.closest('tr'); return run(n, 'setGrade', { citizenid: tr.dataset.cid, grade: Number(tr.querySelector('.egrade').value) }, () => go('employees', true)); }
        case 'fire': {
            const tr = n.closest('tr');
            if (!(await confirmBox('Renvoyer cet employé ?', 'Il perd immédiatement son poste à la concession.', 'Renvoyer'))) return;
            return run(n, 'fire', { citizenid: tr.dataset.cid }, () => go('employees', true));
        }
        case 'permReset': permDraft = null; return go('permissions', true);
        case 'permSave':
            document.querySelectorAll('[data-perm]').forEach((c) => { const [g, k] = c.dataset.perm.split(':'); (permDraft[g] = permDraft[g] || {})[k] = c.checked; });
            document.querySelectorAll('[data-disc]').forEach((i) => { (permDraft[i.dataset.disc] = permDraft[i.dataset.disc] || {}).discount = Number(i.value) || 0; });
            return run(n, 'permissionsSave', { perms: permDraft }, async () => { permDraft = null; await go('permissions', true); });
    }
});

/* ================================================================== */
/* Proposition reçue (client)                                          */
/* ================================================================== */
let offerTimer = null, offerCur = null;
function openOffer(o) {
    offerCur = o;
    const isTest = o.type === 'test';
    $('#offerImg').src = o.vehicle.image;
    $('#offerType').textContent = isTest ? 'Essai routier' : (o.self ? 'Confirmer ton achat' : 'Proposition d\'achat');
    $('#offerCompany').textContent = o.company;
    $('#offerVehicle').textContent = o.vehicle.label;
    $('#offerMeta').textContent = `${o.vehicle.category} · présenté par ${o.seller}`;
    $('#offerOld').textContent = !isTest && o.discount ? `${money(o.basePrice)} (-${o.discount} %)` : '';
    $('#offerPrice').textContent = isTest ? 'Gratuit' : money(o.price);
    $('#offerInfo').textContent = isTest ? `Tu prends le volant pendant ${mmss(o.duration)}.`
        : 'Voulez-vous acheter ce véhicule à ce prix ? Paiement par banque. Le véhicule apparaît sur le parking et sa clé arrive dans votre inventaire (U pour ouvrir ou fermer).';
    $('#offerAccept').textContent = isTest ? 'Commencer l\'essai' : 'Oui, acheter';
    $('[data-offer="refuse"]').textContent = isTest ? 'Refuser' : 'Non';
    $('#offer').classList.remove('hidden');
    let left = o.timeout || 60;
    const bar = $('#offerTimer');
    bar.style.width = '100%';
    clearInterval(offerTimer);
    offerTimer = setInterval(() => {
        left -= 1;
        bar.style.width = `${Math.max(0, (left / (o.timeout || 60)) * 100)}%`;
        if (left <= 0) answerOffer(false);
    }, 1000);
}
function closeOffer() { clearInterval(offerTimer); offerCur = null; $('#offer').classList.add('hidden'); }
function answerOffer(accept) {
    if (!offerCur) return;
    nui('offerAnswer', { id: offerCur.id, accept });
    closeOffer();
}
document.addEventListener('click', (e) => { const b = e.target.closest('[data-offer]'); if (b) answerOffer(b.dataset.offer === 'accept'); });

/* ================================================================== */
/* Garage                                                              */
/* ================================================================== */
function openGarage(list) {
    $('#garage').classList.remove('hidden');
    const bar = (label, v) => `<div class="bar"><span>${label}</span><div class="bar-track"><div class="bar-fill" style="width:${Math.max(3, Math.min(100, v))}%"></div></div><span>${v} %</span></div>`;
    $('#garageList').innerHTML = list.length ? list.map((v) => `
        <div class="vcard" style="cursor:default">
            <div class="vimg">${imgTag(v.image)}<span class="badge ${v.out ? 'red' : 'green'} vstate">${v.out ? 'Sorti' : 'Au garage'}</span></div>
            <div class="vbody">
                <div class="row-between"><div class="vname">${esc(v.label)}</div><span class="plate">${esc(v.plate)}</span></div>
                <div class="bars" style="margin-top:8px">${bar('Moteur', v.engine)}${bar('Carrosserie', v.body)}${bar('Essence', v.fuel)}</div>
                <button class="btn primary" style="width:100%;margin-top:12px" data-takeout="${esc(v.plate)}" ${v.out ? 'disabled' : ''}>${v.out ? 'Déjà en ville' : 'Sortir le véhicule'}</button>
            </div>
        </div>`).join('') : '<div class="empty" style="grid-column:1/-1">Tu n\'as aucun véhicule.</div>';
}
document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-takeout]');
    if (t && !t.disabled) { $('#garage').classList.add('hidden'); return nui('garageTakeOut', { plate: t.dataset.takeout }); }
    if (e.target.closest('[data-garage="close"]')) { $('#garage').classList.add('hidden'); nui('garageClose'); }
});

/* ================================================================== */
/* Essai routier                                                       */
/* ================================================================== */
let testTimer = null;
function testHud(m) {
    clearInterval(testTimer);
    $('#testHud').classList.toggle('hidden', !m.show);
    if (!m.show) return;
    let left = m.seconds || 120;
    $('#testLabel').textContent = m.label || '';
    $('#testTime').textContent = mmss(left);
    testTimer = setInterval(() => { left = Math.max(0, left - 1); $('#testTime').textContent = mmss(left); }, 1000);
}

// La molette fait défiler la barre des catégories de gauche à droite
document.addEventListener('wheel', (e) => {
    const bar = e.target.closest('.chips');
    if (!bar || bar.scrollWidth <= bar.clientWidth) return;
    bar.scrollLeft += e.deltaY;
    e.preventDefault();
}, { passive: false });
