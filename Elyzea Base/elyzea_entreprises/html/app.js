const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_entreprises';
const post = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .then((r) => r.json()).catch(() => ({}));
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
const act = (action, data = {}) => post('act', { action, data });

const T = { company: null, cfg: null, data: null, tab: 'home', nearby: [], cart: {}, custom: { amount: '', label: '' }, target: null,
    counts: {}, qty: {}, meter: null, mission: null, orders: [] };

function hexToRgba(hex, a) {
    const m = String(hex || '').match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
    return m ? `rgba(${parseInt(m[1], 16)}, ${parseInt(m[2], 16)}, ${parseInt(m[3], 16)}, ${a})` : `rgba(217, 181, 106, ${a})`;
}

/* =========================================================
   Onglets disponibles selon l'entreprise et le grade
   ========================================================= */
function tabs() {
    const f = (T.cfg && T.cfg.features) || {};
    const p = (T.data && T.data.perms) || {};
    const list = [{ id: 'home', label: 'Accueil' }];
    if (p.invoice) list.push({ id: 'invoice', label: f.meter ? 'Facture' : 'Caisse' });
    if (f.meter || f.missions) list.push({ id: 'taxi', label: 'Taxi' });
    if (f.kiosk && p.orders) list.push({ id: 'orders', label: `Commandes${T.orders.length ? ` (${T.orders.filter((o) => o.status === 'pending').length})` : ''}` });
    if (f.production && p.prepare) list.push({ id: 'prepare', label: T.company === 'nightclub' ? 'Bar' : 'Cuisine' });
    if (f.production && p.stock) list.push({ id: 'supply', label: 'Fournisseur' });
    if (f.entry && p.entry) list.push({ id: 'entry', label: 'Entrée' });
    if (p.garage || p.stash) list.push({ id: 'vehicles', label: 'Véhicules & coffre' });
    if (p.boss_staff || p.boss_money) list.push({ id: 'boss', label: 'Entreprise' });
    return list;
}

function render() {
    if (!T.cfg) return;
    const c = T.cfg, d = T.data;
    document.documentElement.style.setProperty('--accent-soft', hexToRgba(c.color, 0.16));
    $("#tEyebrow").textContent = "Elyzea · Entreprise";
    $('#tTitle').textContent = c.job.label;
    $('#tSub').innerHTML = d ? `${d.onduty ? '<span class="status on">● En service</span>' : '<span class="status">Hors service</span>'}
        <span class="status">${esc(d.gradeLabel || '')}</span>${d.enabled ? '' : '<span class="status off">Fermé par le staff</span>'}` : '';
    const list = tabs();
    if (d && !list.find((t) => t.id === T.tab)) T.tab = 'home';
    $('#tabs').innerHTML = list.map((t) => `<button class="${t.id === T.tab ? 'active' : ''}" data-tab="${t.id}">${t.label}</button>`).join('');
    if (!d) { $('#body').innerHTML = '<p class="muted">Chargement…</p>'; return; }
    $('#body').innerHTML = (VIEWS[T.tab] || VIEWS.home)();
    if (T.tab === 'prepare' || T.tab === 'orders') loadCounts();
}

const VIEWS = {};
const dutyLock = () => (!T.data.onduty ? '<p class="lead">⚠️ Prends ton service pour utiliser cet onglet.</p>' : '');

function targetPicker() {
    if (!T.nearby.length) return '<div class="empty">Personne à moins de 6 m. Rapproche-toi du client puis « Actualiser ».</div>';
    if (!T.nearby.find((p) => p.id === T.target)) T.target = T.nearby[0].id;
    return `<select class="input" data-target>${T.nearby.map((p) => `<option value="${p.id}" ${p.id === T.target ? 'selected' : ''}>Joueur ${p.id} · ${p.dist} m</option>`).join('')}</select>`;
}

/* ---------- Accueil ---------- */
VIEWS.home = () => {
    const d = T.data;
    return `
        <div class="card duty ${d.onduty ? 'on' : ''}" style="margin-bottom:14px">
            <div><strong>${d.onduty ? 'Tu es en service' : 'Tu es hors service'}</strong>
                <span>${d.onduty ? 'Tu peux travailler et tu portes ta tenue de service.' : 'Prends ton service pour travailler (la tenue se met toute seule).'}</span></div>
            <button class="btn ${d.onduty ? '' : 'primary'}" data-a="duty" ${!d.onduty && !d.enabled ? 'disabled' : ''}>${d.onduty ? 'Terminer le service' : 'Prendre le service'}</button>
        </div>
        <div class="card"><h3>Collègues en service (${d.coworkers.length})</h3>
            ${d.coworkers.length ? `<div class="list">${d.coworkers.map((w) => `<div class="li"><span class="grow"><b>${esc(w.name)}</b> <small>· ${esc(w.grade)}</small></span><small>ID ${w.id}</small></div>`).join('')}</div>`
                : '<div class="empty">Personne n\'est en service.</div>'}
        </div>`;
};

/* ---------- Facture / caisse ---------- */
function cartTotal() {
    let total = 0;
    (T.cfg.menu || []).forEach((m, i) => { total += (T.cart[i] || 0) * (Number(m.price) || 0); });
    return total + (Number(T.custom.amount) || 0);
}
function cartLabel() {
    const parts = [];
    (T.cfg.menu || []).forEach((m, i) => { if (T.cart[i]) parts.push(`${T.cart[i]} × ${m.label}`); });
    if (T.custom.label.trim()) parts.push(T.custom.label.trim());
    return parts.join(', ') || T.cfg.job.label;
}
VIEWS.invoice = () => {
    const menu = T.cfg.menu || [];
    return `${dutyLock()}
        ${menu.length ? `<label class="lab">Carte</label><div class="menu-grid">${menu.map((m, i) => `<div class="menu-item ${T.cart[i] ? 'on' : ''}">
            <b>${esc(m.label)}</b><span>${money(m.price)}</span>
            <div class="row" style="margin-top:6px"><button class="btn small" data-cart="${i}" data-d="-1">−</button><b>${T.cart[i] || 0}</b><button class="btn small" data-cart="${i}" data-d="1">+</button></div></div>`).join('')}</div>` : ''}
        <div class="grid2">
            <div><label class="lab">Montant libre ($)</label><input class="input" type="number" min="0" data-custom="amount" value="${esc(T.custom.amount)}" placeholder="${T.meter && T.meter.total ? T.meter.total : '0'}"></div>
            <div><label class="lab">Motif</label><input class="input" data-custom="label" value="${esc(T.custom.label)}" maxlength="120" placeholder="ex : Course de taxi"></div>
        </div>
        <div class="grid2" style="margin-top:14px;align-items:end">
            <div><label class="lab">Client</label>${targetPicker()}</div>
            <div class="row" style="justify-content:flex-end"><button class="btn" data-a="nearby">Actualiser</button><span class="total gold-text">${money(cartTotal())}</span></div>
        </div>
        <div class="row end"><button class="btn" data-a="cartReset">Vider</button>
            <button class="btn primary" data-a="sendInvoice" ${!T.data.onduty || !T.nearby.length || cartTotal() <= 0 ? 'disabled' : ''}>Envoyer la facture</button></div>`;
};

/* ---------- Taxi ---------- */
VIEWS.taxi = () => {
    const f = T.cfg.features, s = T.cfg.settings, p = T.data.perms, m = T.meter || { total: 0, distance: 0, wait: 0, running: false };
    return `${dutyLock()}
        ${f.meter ? `<div class="card" style="margin-bottom:14px"><h3>🧾 Compteur</h3>
            <p class="lead">Prise en charge ${money(s.meterBase)} · ${money(s.meterPerKm)} le km · ${money(s.meterPerMin)} la minute d'attente.</p>
            <div class="stats"><div class="stat"><b class="gold-text">${money(m.total)}</b><span>Montant</span></div>
                <div class="stat"><b>${(m.distance / 1000).toFixed(2)} km</b><span>Distance</span></div>
                <div class="stat"><b>${Math.floor(m.wait / 60)} min</b><span>Attente</span></div></div>
            <div class="row">${m.running ? '<button class="btn" data-a="meterStop">⏸ Arrêter</button>' : `<button class="btn primary" data-a="meterStart" ${p.meter && T.data.onduty ? '' : 'disabled'}>▶ Démarrer</button>`}
                <button class="btn" data-a="meterReset">Remettre à zéro</button>
                <button class="btn primary" data-a="meterBill" ${m.total > 0 && p.invoice ? '' : 'disabled'}>Facturer ${money(m.total)}</button></div></div>` : ''}
        ${f.missions ? `<div class="card"><h3>🧍 Courses (clients PNJ)</h3>
            ${s.missionsEnabled ? `<p class="lead">Au volant d'un taxi de l'entreprise : un client t'attend, prends-le en charge et dépose-le à destination. Payé à l'arrivée.</p>
                ${T.mission ? `<p class="lead">Course en cours : <b>${T.mission.stage === 'pickup' ? 'va chercher le client' : 'emmène le client à destination'}</b>.</p>
                    <button class="btn danger" data-a="missionCancel">Annuler la course</button>`
                : `<button class="btn primary" data-a="missionStart" ${p.missions && T.data.onduty ? '' : 'disabled'}>Chercher un client</button>`}`
            : '<div class="empty">Les courses sont désactivées par le staff.</div>'}</div>` : ''}`;
};

/* ---------- Préparation ---------- */
async function loadCounts() {
    const items = new Set();
    (T.cfg.recipes || []).forEach((r) => (r.ingredients || []).forEach((x) => items.add(x.item)));
    ((T.cfg.kiosk && T.cfg.kiosk.products) || []).forEach((p) => (p.ingredients || []).forEach((x) => items.add(x.item)));
    if (!items.size) return;
    const r = await post('counts', { items: [...items] });
    const changed = JSON.stringify(r) !== JSON.stringify(T.counts);
    T.counts = r || {};
    if (changed && (T.tab === 'prepare' || T.tab === 'orders')) $('#body').innerHTML = VIEWS[T.tab]();
}
VIEWS.prepare = () => {
    const list = T.cfg.recipes || [];
    if (!list.length) return '<div class="empty">Aucune recette : le staff les ajoute dans le menu admin.</div>';
    return `${dutyLock()}<p class="lead">Va au poste de préparation. Les ingrédients sont pris dans ton inventaire.</p>
        <div class="recipes">${list.map((r) => {
            const ok = (r.ingredients || []).every((x) => (T.counts[x.item] || 0) >= x.count);
            return `<div class="card recipe"><h3>${esc(r.label)}</h3><small class="muted">Donne ${r.amount} × · ${r.time} s</small>
                <div class="ings">${(r.ingredients || []).map((x) => `<span class="chip ${(T.counts[x.item] || 0) >= x.count ? 'ok' : 'ko'}">${x.count} × ${esc(x.label)} (${T.counts[x.item] || 0})</span>`).join('') || '<span class="chip">Aucun ingrédient</span>'}</div>
                <button class="btn ${ok ? 'primary' : ''}" data-prepare="${esc(r.id)}" ${ok && T.data.onduty ? '' : 'disabled'}>Préparer</button></div>`;
        }).join('')}</div>`;
};

/* ---------- Commandes de la borne ---------- */
function orderNeeds(o) {
    const k = T.cfg.kiosk || {};
    if (k.useIngredients === false) return [];
    const need = {};
    (o.lines || []).forEach((l) => {
        const p = (k.products || []).find((x) => x.id === l.pid);
        ((p && p.ingredients) || []).forEach((x) => { need[x.item] = (need[x.item] || 0) + x.count * l.qty; });
    });
    return Object.entries(need).map(([item, count]) => ({ item, count, have: T.counts[item] || 0 }));
}
const ago = (s) => (s < 60 ? 'à l\'instant' : `il y a ${Math.floor(s / 60)} min`);
const ORDER_ST = { pending: 'En attente', preparing: 'En préparation', ready: 'Prête' };
VIEWS.orders = () => {
    const list = T.orders || [];
    const k = T.cfg.kiosk || {};
    return `${dutyLock()}<p class="lead">Les clients commandent à la borne et paient d'avance. Va au <b>plan de travail</b>, puis « Préparer » :
            tu prépares la commande devant le client${k.useIngredients === false ? '' : ' avec les ingrédients de ton inventaire'}.
            Client à moins de ${k.deliverDistance || 6} m : elle lui est remise directement, sinon il la récupère au comptoir.</p>
        <div class="row" style="margin-bottom:12px"><button class="btn small" data-a="ordersRefresh">Actualiser</button>
            <span class="muted">${list.filter((o) => o.status === 'pending').length} en attente · ${list.filter((o) => o.status === 'preparing').length} en préparation · ${list.filter((o) => o.status === 'ready').length} prête(s)</span></div>
        ${list.length ? `<div class="orders">${list.map((o) => {
            const needs = orderNeeds(o);
            const ok = needs.every((x) => x.have >= x.count);
            return `<div class="ticket ${o.status}"><div class="t-head"><span class="t-num gold-text">n°${esc(o.number)}</span><span class="st ${o.status}">${ORDER_ST[o.status] || o.status}</span></div>
                <small class="muted">${esc(o.name)} · ${ago(o.age || 0)} · ${money(o.total)}</small>
                <ul>${(o.lines || []).map((l) => `<li><b>${l.qty}×</b>${esc(l.label)}</li>`).join('')}</ul>
                ${o.status === 'pending' && needs.length ? `<div class="ings">${needs.map((x) => `<span class="chip ${x.have >= x.count ? 'ok' : 'ko'}">${x.count} × ${esc((T.cfg.kioskLabels || {})[x.item] || x.item)} (${x.have})</span>`).join(' ')}</div>` : ''}
                ${o.status === 'preparing' ? `<small class="muted">Préparée par ${esc(o.employee || '?')}</small>` : ''}
                ${o.status === 'ready' ? '<small class="muted">En attente du client au comptoir.</small>' : ''}
                ${o.status === 'pending' ? `<div class="row end" style="margin-top:6px"><button class="btn small danger" data-ocancel="${o.id}">Annuler et rembourser</button>
                    <button class="btn small ${ok ? 'primary' : ''}" data-ostart="${o.id}" ${T.data.onduty && ok ? '' : 'disabled'}>Préparer</button></div>` : ''}</div>`;
        }).join('')}</div>` : '<div class="empty">Aucune commande pour le moment. Une alerte s\'affiche à chaque nouvelle commande.</div>'}`;
};

/* ---------- Fournisseur ---------- */
VIEWS.supply = () => {
    const list = T.cfg.supplies || [];
    if (!list.length) return '<div class="empty">Aucun produit chez le fournisseur.</div>';
    return `${dutyLock()}<p class="lead">Va à la réserve. Les produits sont payés avec <b>l'argent de l'entreprise</b> et arrivent dans ton inventaire.</p>
        <div class="list">${list.map((x, i) => {
            const q = T.qty[i] || 5;
            return `<div class="li"><span class="grow"><b>${esc(x.label)}</b> <small>· ${money(x.price)} pièce</small></span>
                <span class="qty"><button class="btn small" data-qty="${i}" data-d="-5">−5</button><input class="input" type="number" min="1" max="100" data-qtyin="${i}" value="${q}"><button class="btn small" data-qty="${i}" data-d="5">+5</button></span>
                <b class="gold-text" style="min-width:90px;text-align:right">${money(q * x.price)}</b>
                <button class="btn primary small" data-supply="${i}" ${T.data.onduty ? '' : 'disabled'}>Commander</button></div>`;
        }).join('')}</div>`;
};

/* ---------- Entrée ---------- */
VIEWS.entry = () => {
    const s = T.cfg.settings;
    return `${dutyLock()}<p class="lead">À l'entrée de la boîte : choisis le client et le type d'entrée. Il reçoit la facture et paie tout de suite.</p>
        <div class="grid2" style="align-items:end"><div><label class="lab">Client</label>${targetPicker()}</div><div class="row"><button class="btn" data-a="nearby">Actualiser</button></div></div>
        <div class="grid2" style="margin-top:14px">
            <div class="card"><h3>Entrée</h3><span class="total gold-text">${money(s.entryPrice)}</span>
                <div class="row end"><button class="btn primary" data-entry="0" ${T.nearby.length && T.data.onduty ? '' : 'disabled'}>Faire payer</button></div></div>
            <div class="card"><h3>Entrée VIP</h3><span class="total gold-text">${money(s.vipPrice)}</span>
                <div class="row end"><button class="btn primary" data-entry="1" ${T.nearby.length && T.data.onduty ? '' : 'disabled'}>Faire payer</button></div></div>
        </div>`;
};

/* ---------- Véhicules et coffre ---------- */
VIEWS.vehicles = () => {
    const p = T.data.perms, list = T.cfg.settings.serviceVehicles || [];
    return `${p.garage ? `<div class="card" style="margin-bottom:14px"><h3>🚗 Véhicules de service</h3>
            <p class="lead">Au point « Garage de service ». Le véhicule sort sur la place de sortie la plus proche.</p>
            ${list.length ? `<div class="list">${list.map((v, i) => `<div class="li"><span class="grow"><b>${esc(v.label)}</b> <small>· ${esc(v.model)}</small></span>
                <small>Grade ${v.grade}+</small><button class="btn primary small" data-veh="${i + 1}" ${T.data.grade >= v.grade && T.data.onduty ? '' : 'disabled'}>Sortir</button></div>`).join('')}</div>`
                : '<div class="empty">Aucun véhicule de service.</div>'}</div>` : ''}
        ${p.stash ? `<div class="card"><h3>📦 Coffre de l'entreprise</h3><p class="lead">Au point « Coffre ».</p><button class="btn primary" data-a="stash">Ouvrir le coffre</button></div>` : ''}`;
};

/* ---------- Entreprise (patron) ---------- */
VIEWS.boss = () => {
    const d = T.data, p = d.perms;
    const grades = d.grades || [];
    const today = d.today || {};
    return `<div class="stats">
            <div class="stat"><b class="gold-text">${money(d.balance)}</b><span>Compte de l'entreprise</span></div>
            <div class="stat"><b>${today.n || 0}</b><span>Factures aujourd'hui</span></div>
            <div class="stat"><b>${money(today.total)}</b><span>Encaissé aujourd'hui</span></div></div>
        ${p.boss_money ? `<div class="card" style="margin-bottom:14px"><h3>💰 Argent</h3>
            <div class="grid2" style="align-items:end"><div><label class="lab">Montant ($)</label><input class="input" type="number" min="1" data-money></div>
                <div class="row"><button class="btn" data-a="deposit">Déposer (liquide)</button><button class="btn primary" data-a="withdraw">Retirer en liquide</button></div></div></div>` : ''}
        ${p.boss_staff ? `<div class="card" style="margin-bottom:14px"><h3>➕ Recruter</h3>
            <div class="grid3" style="align-items:end"><div><label class="lab">Personne proche</label>${targetPicker()}</div>
                <div><label class="lab">Grade</label><select class="input" data-rgrade>${grades.filter((g) => g.level < d.grade).map((g) => `<option value="${g.level}">${esc(g.label)}</option>`).join('')}</select></div>
                <div class="row"><button class="btn" data-a="nearby">Actualiser</button><button class="btn primary" data-a="recruit" ${T.nearby.length ? '' : 'disabled'}>Recruter</button></div></div></div>
        <div class="card"><h3>👥 Employés (${(d.members || []).length})</h3>
            ${(d.members || []).length ? `<div class="list">${d.members.map((m) => `<div class="li">
                <span class="grow"><b>${esc(m.name)}</b> <small>${m.online ? (m.duty ? '· en service' : '· connecté') : '· hors ligne'}</small></span>
                <select class="input" style="width:180px" data-mgrade="${esc(m.cid)}">${grades.map((g) => `<option value="${g.level}" ${g.level === m.grade ? 'selected' : ''}>${esc(g.label)}</option>`).join('')}</select>
                <button class="btn small" data-setgrade="${esc(m.cid)}">Valider</button>
                <button class="btn danger small" data-fire="${esc(m.cid)}">Renvoyer</button></div>`).join('')}</div>` : '<div class="empty">Aucun employé.</div>'}</div>` : ''}`;
};

/* =========================================================
   Événements de l'interface
   ========================================================= */
$('#tablet').addEventListener('click', async (e) => {
    let n;
    if (e.target.closest('[data-close]')) return close();
    if ((n = e.target.closest('[data-tab]'))) { T.tab = n.dataset.tab; return render(); }
    if ((n = e.target.closest('[data-cart]'))) {
        const i = n.dataset.cart;
        T.cart[i] = Math.max(0, (T.cart[i] || 0) + Number(n.dataset.d));
        return render();
    }
    if ((n = e.target.closest('[data-qty]'))) { const i = n.dataset.qty; T.qty[i] = Math.min(100, Math.max(1, (T.qty[i] || 5) + Number(n.dataset.d))); return render(); }
    if ((n = e.target.closest('[data-supply]')) && !n.disabled) return act('supply', { index: Number(n.dataset.supply) + 1, qty: T.qty[n.dataset.supply] || 5 });
    if ((n = e.target.closest('[data-ostart]')) && !n.disabled) return act('orderStart', { id: Number(n.dataset.ostart) });
    if ((n = e.target.closest('[data-ocancel]'))) return act('orderCancel', { id: Number(n.dataset.ocancel) });
    if ((n = e.target.closest('[data-prepare]')) && !n.disabled) return act('prepare', { id: n.dataset.prepare });
    if ((n = e.target.closest('[data-entry]')) && !n.disabled) return act('entry', { target: T.target, vip: n.dataset.entry === '1' });
    if ((n = e.target.closest('[data-veh]')) && !n.disabled) return act('vehicle', { index: Number(n.dataset.veh) });
    if ((n = e.target.closest('[data-setgrade]'))) {
        const sel = document.querySelector(`[data-mgrade="${CSS.escape(n.dataset.setgrade)}"]`);
        return act('boss', { name: 'setGrade', data: { cid: n.dataset.setgrade, grade: Number(sel.value) } });
    }
    if ((n = e.target.closest('[data-fire]'))) return act('boss', { name: 'fire', data: { cid: n.dataset.fire } });
    if (!(n = e.target.closest('[data-a]')) || n.disabled) return;
    switch (n.dataset.a) {
        case 'duty': return act('duty');
        case 'nearby': { const r = await post('nearby'); T.nearby = r.players || []; return render(); }
        case 'cartReset': T.cart = {}; T.custom = { amount: '', label: '' }; return render();
        case 'sendInvoice': {
            const total = cartTotal();
            if (total <= 0 || !T.target) return;
            act('invoice', { target: T.target, amount: total, label: cartLabel() });
            T.cart = {}; T.custom = { amount: '', label: '' };
            return render();
        }
        case 'meterStart': case 'meterStop': case 'meterReset': act(n.dataset.a); return;
        case 'meterBill': T.custom = { amount: String((T.meter && T.meter.total) || 0), label: 'Course de taxi' }; T.cart = {}; T.tab = 'invoice'; act('meterStop'); return render();
        case 'missionStart': case 'missionCancel': return act(n.dataset.a);
        case 'stash': return act('stash');
        case 'ordersRefresh': return act('ordersRefresh');
        case 'deposit': case 'withdraw': {
            const v = Number(document.querySelector('[data-money]').value);
            if (v > 0) act('boss', { name: n.dataset.a, data: { amount: v } });
            return;
        }
        case 'recruit': {
            const g = document.querySelector('[data-rgrade]');
            return act('boss', { name: 'recruit', data: { target: T.target, grade: Number(g ? g.value : 0) } });
        }
    }
});

$('#tablet').addEventListener('input', (e) => {
    const t = e.target;
    if (t.dataset.custom) { T.custom[t.dataset.custom] = t.value; const tot = document.querySelector('.total'); if (tot) tot.textContent = money(cartTotal()); }
    if (t.dataset.qtyin !== undefined) T.qty[t.dataset.qtyin] = Math.min(100, Math.max(1, Number(t.value) || 1));
});
$('#tablet').addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.target !== undefined) T.target = Number(t.value);
    if (t.dataset.custom || t.dataset.qtyin !== undefined) render();
});

function close() {
    $('#tablet').classList.add('hidden');
    post('close');
}

/* ---------- Compteur ---------- */
function renderMeter(show, m) {
    T.meter = m;
    const el = $('#meter');
    if (!show) { el.classList.add('hidden'); return; }
    el.innerHTML = `<div class="m-top"><span class="eyebrow">Compteur</span><span class="status ${m.running ? 'on' : ''}">${m.running ? '● En course' : 'Arrêté'}</span></div>
        <div class="m-total gold-text">${money(m.total)}</div>
        <div class="m-row"><span>${(m.distance / 1000).toFixed(2)} km</span><span>${Math.floor(m.wait / 60)} min d'attente</span></div>`;
    el.classList.remove('hidden');
    if (!$('#tablet').classList.contains('hidden') && T.tab === 'taxi') render();
}

/* ---------- Facture reçue ---------- */
let invTimer = null;
function openInvoice(i) {
    let left = i.timeout || 60;
    let method = 'bank';
    $('#invoiceBox').innerHTML = `<img src="logo.png" class="crest" alt=""><div class="eyebrow">${esc(i.icon || '')} ${esc(i.company)}</div>
        <div class="inv-title">Facture</div><div class="inv-amount gold-text">${money(i.amount)}</div>
        <p class="muted">${esc(i.label)}</p><p class="muted" style="margin-top:6px">Par ${esc(i.employee)}</p>
        <div class="row" style="justify-content:center;margin-top:12px"><small class="muted">Payer par :</small>
            <button class="btn small primary" data-m="bank">🏦 Banque</button><button class="btn small" data-m="cash">💵 Liquide</button></div>
        <div class="inv-time"><span id="invBar" style="width:100%"></span></div>
        <div class="row" style="justify-content:center"><button class="btn danger" data-inv="0">Refuser</button><button class="btn primary" data-inv="1">Payer</button></div>`;
    $('#invoice').classList.remove('hidden');
    $('#invoiceBox').onclick = (e) => {
        const m = e.target.closest('[data-m]');
        if (m) { method = m.dataset.m; $('#invoiceBox').querySelectorAll('[data-m]').forEach((b) => b.classList.toggle('primary', b === m)); return; }
        const b = e.target.closest('[data-inv]');
        if (b) answer(b.dataset.inv === '1');
    };
    function answer(accept) {
        clearInterval(invTimer);
        $('#invoice').classList.add('hidden');
        post('invoiceAnswer', { id: i.id, accept, method });
    }
    clearInterval(invTimer);
    invTimer = setInterval(() => {
        left -= 1;
        const bar = $('#invBar');
        if (bar) bar.style.width = `${Math.max(0, left / (i.timeout || 60) * 100)}%`;
        if (left <= 0) answer(false);
    }, 1000);
}

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#tablet').classList.contains('hidden')) close();
});

window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'tablet':
            Object.assign(T, { company: m.company, cfg: m.cfg, data: null, nearby: m.nearby || [], counts: {}, mission: m.mission || null, orders: m.orders || [] });
            if (m.meter) T.meter = m.meter;
            T.tab = m.tab || (T.tab && T.company === m.company ? T.tab : 'home');
            $('#tablet').classList.remove('hidden');
            return render();
        case 'tabletData': T.data = m.data; if (m.nearby) T.nearby = m.nearby; return render();
        case 'closeTablet': $('#tablet').classList.add('hidden'); return;
        case 'orders': T.orders = m.list || []; if (!$('#tablet').classList.contains('hidden') && T.data) render(); return;
        case 'meter': return renderMeter(m.show, m.data);
        case 'mission': T.mission = m.data; if (!$('#tablet').classList.contains('hidden')) render(); return;
        case 'invoice': return openInvoice(m.invoice);
        case 'invoiceClose': clearInterval(invTimer); $('#invoice').classList.add('hidden'); return;
        case 'invoiceResult': return;
    }
});
