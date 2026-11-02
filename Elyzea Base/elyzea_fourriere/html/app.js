/* =========================================================
   ELYZEA · FOURRIÈRE  (interface)
   Toutes les vérifications sont refaites par le serveur.
   ========================================================= */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_fourriere';
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nf = (n) => Number(n || 0).toLocaleString('fr-FR');
const post = (ev, data = {}) => fetch(`https://${RES}/${ev}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});

const PAY = { cash: { label: 'Liquide', icon: '💵' }, bank: { label: 'Banque', icon: '🏦' }, pesos: { label: 'Pesos', icon: '🪙' } };
const KIND_ICON = { land: '🚗', air: '🚁', sea: '🚤' };
const IMG = 'https://docs.fivem.net/vehicles/%s.webp';

let D = null;              // données envoyées par le serveur
let tab = 'here';          // here | all
let method = null;         // moyen de paiement choisi
let busy = null;           // plaque en cours de paiement
let msg = null;            // { ok, text }
let ends = {};             // plaque → fin de réparation (ms)
let refreshAsked = false;

const due = (usd, m = method) => (m === 'pesos' ? Math.ceil(Number(usd || 0) * Number(D.rate || 1) - 1e-9) : Number(usd || 0));
const money = (n, m = method) => (m === 'pesos' ? `${nf(n)} pesos` : `${nf(n)} $`);
const have = (m = method) => Number((D.wallet || {})[m] ?? 0);
const clsOf = (v) => (v.cls && D.classes[v.cls]) || null;
const spotsFor = (cls) => Number((D.spots || {})[cls] || 0) + Number((D.spots || {}).all || 0);
const fmtTime = (s) => {
    s = Math.max(0, Math.ceil(s));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
    return h ? `${h} h ${String(m).padStart(2, '0')} min` : `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
};

function setData(d, first) {
    D = d;
    if (first) { tab = 'here'; msg = null; busy = null; }
    if (!D.methods.includes(method)) method = D.methods[0];
    ends = {};
    for (const v of D.list) if (v.status === 'repair') ends[v.plate] = Date.now() + (v.remain || 0) * 1000;
    refreshAsked = false;
    render();
}

function render() {
    if (!D) return;
    const k = D.kinds[D.kind] || {};
    $('#crest').textContent = KIND_ICON[D.kind] || '🚧';
    $('#kindLabel').textContent = `Elyzea · ${k.label || 'Fourrière'}`;
    $('#poundName').textContent = D.name;
    const cats = Object.entries(D.classes).filter(([, c]) => c.kind === D.kind).map(([, c]) => `${c.icon} ${c.label.toLowerCase()}s`).join(' · ');
    $('#sub').textContent = `Ici : ${cats}. Réparation d'un véhicule détruit : ${D.repairMinutes} min.`;
    $('#wallet').innerHTML = D.methods.map((m) => `<span>${PAY[m]?.icon || ''} ${money(have(m), m)}</span>`).join('');

    const here = D.list.filter((v) => v.kind === D.kind || !v.kind);
    $('#tabs').innerHTML = `<button class="tab ${tab === 'here' ? 'on' : ''}" data-tab="here">Cette fourrière <em>${here.length}</em></button>
        <button class="tab ${tab === 'all' ? 'on' : ''}" data-tab="all">Tous mes véhicules <em>${D.list.length}</em></button>`;
    $('#pay').innerHTML = D.methods.length > 1
        ? `<span class="lbl">Payer en</span>${D.methods.map((m) => `<button class="pm ${m === method ? 'on' : ''}" data-method="${m}">${PAY[m]?.icon || ''} ${PAY[m]?.label || m}</button>`).join('')}`
        : `<span class="lbl">Paiement</span><span class="only">${PAY[method]?.icon || ''} ${method === 'pesos' ? 'Pesos uniquement' : PAY[method]?.label || method}</span>`;

    const m = $('#msg');
    m.className = msg ? `msg ${msg.ok ? 'ok' : 'err'}` : 'msg hidden';
    m.textContent = msg ? msg.text : '';

    const list = tab === 'here' ? here : D.list;
    $('#grid').innerHTML = list.length ? list.map(card).join('')
        : `<div class="empty"><b>${tab === 'here' ? 'Aucun véhicule ici' : 'Aucun véhicule à la fourrière'}</b>${tab === 'here' && D.list.length ? 'Tes autres véhicules sont dans une autre fourrière : onglet « Tous mes véhicules ».' : 'Tous tes véhicules sont libres.'}</div>`;
    tick();
}

function card(v) {
    const c = clsOf(v);
    const away = v.kind && v.kind !== D.kind;
    const repairing = v.status === 'repair';
    const badge = repairing ? '<span class="badge warn">En réparation</span>'
        : v.destroyed ? '<span class="badge red">Détruit</span>' : '<span class="badge blue">À la fourrière</span>';
    const rows = [
        ['Type', c ? `${c.icon} ${c.label}` : 'Inconnu'],
        ['État', v.destroyed ? '<dd class="bad">Complètement détruit</dd>' : '<dd class="good">Récupérable</dd>'],
        ['Motif', v.reason === 'police' ? 'Enlevé par la police' : v.reason === 'destroyed' ? 'Épave' : esc(v.reason)],
    ].map(([a, b]) => `<dt>${a}</dt>${String(b).startsWith('<dd') ? b : `<dd>${b}</dd>`}`).join('');

    let foot;
    if (repairing) {
        const total = (D.repairMinutes || 60) * 60;
        foot = `<div class="timer" data-timer="${esc(v.plate)}" data-total="${total}">
                <div class="t">--:--</div><div class="bar2"><i style="width:0%"></i></div></div>
            <div class="why">Payé ${money(v.paid || 0, v.paidCurrency === 'pesos' ? 'pesos' : 'cash')} · reviendra réparé au garage tout seul</div>
            <button class="btn" disabled>Réparation en cours</button>`;
    } else {
        let why = '';
        let ok = true;
        if (away) { ok = false; why = `À récupérer à la ${(D.kinds[v.kind] || {}).label?.toLowerCase() || 'bonne fourrière'}.`; }
        else if (!c) { ok = false; why = 'Catégorie en cours de vérification…'; }
        else if (!v.destroyed && spotsFor(v.cls) === 0) { ok = false; why = 'Aucune place de sortie ici pour ce type : préviens le staff.'; }
        const price = v.price != null ? due(v.price) : null;
        if (ok && price != null && have() < price) {
            ok = false;
            why = method === 'pesos' ? `Il te manque ${money(price - have())}. Change de l'argent au bureau de change.` : `Il te manque ${money(price - have())}.`;
        }
        if (ok && !why) why = v.destroyed ? `Réparation : ${D.repairMinutes} min, puis retour au garage.` : 'Sortie immédiate sur une place libre.';
        const label = busy === v.plate ? 'Paiement…' : v.destroyed ? 'Payer la réparation' : 'Payer et récupérer';
        foot = `${price != null ? `<div class="price">${money(price)}</div>` : ''}
            <div class="why">${esc(why)}</div>
            <button class="btn" data-pay="${esc(v.plate)}" ${!ok || busy ? 'disabled' : ''}>${label}</button>`;
    }
    return `<article class="card ${away ? 'away' : ''}">
        <div class="img"><img src="${IMG.replace('%s', encodeURIComponent(v.model))}" alt="" onerror="this.replaceWith(Object.assign(document.createElement('span'),{className:'ph',textContent:'${c ? c.icon : '🚗'}'}))">
            ${badge}<span class="type">${c ? `${c.icon} ${esc(c.label)}` : '?'}</span><span class="plate">${esc(v.plate)}</span></div>
        <div class="body"><div class="name">${esc(v.label || v.model)}</div><dl class="rows">${rows}</dl>${foot}</div>
    </article>`;
}

// Compte à rebours des réparations (le serveur reste la référence)
function tick() {
    const now = Date.now();
    let finished = false;
    document.querySelectorAll('[data-timer]').forEach((el) => {
        const end = ends[el.dataset.timer];
        if (!end) return;
        const left = (end - now) / 1000;
        const total = Number(el.dataset.total) || 3600;
        el.querySelector('.t').textContent = left > 0 ? `Encore ${fmtTime(left)}` : 'Terminée';
        el.querySelector('i').style.width = `${Math.min(100, Math.max(0, (1 - left / total) * 100))}%`;
        if (left <= 0) finished = true;
    });
    if (finished && !refreshAsked) { refreshAsked = true; setTimeout(() => post('refresh'), 1500); }
}
setInterval(() => { if (D && !$('#app').classList.contains('hidden')) tick(); }, 1000);

document.addEventListener('click', (e) => {
    let n;
    if ((n = e.target.closest('[data-tab]'))) { tab = n.dataset.tab; return render(); }
    if ((n = e.target.closest('[data-method]'))) { method = n.dataset.method; msg = null; return render(); }
    if ((n = e.target.closest('[data-pay]')) && !n.disabled && !busy) {
        busy = n.dataset.pay; msg = null; render();
        return post('pay', { plate: busy, method });
    }
    if (e.target.closest('#closeBtn')) close();
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#app').classList.contains('hidden')) close(); });

function close() {
    $('#app').classList.add('hidden');
    D = null; busy = null;
    post('close');
}

window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'open') { $('#app').classList.remove('hidden'); setData(m.data, true); }
    else if (m.action === 'data' && D) setData(m.data, false);
    else if (m.action === 'result') { busy = null; msg = { ok: !!m.ok, text: m.msg || '' }; render(); }
    else if (m.action === 'close') { $('#app').classList.add('hidden'); D = null; busy = null; }
});
