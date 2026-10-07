const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_lscustom';
const post = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) })
        .then((r) => r.json()).catch(() => ({}));
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `$${Number(n || 0).toLocaleString('fr-FR')}`;

const GROUPS = { service: 'Services', performance: 'Performance', esthetique: 'Esthétique' };
const SERVICES = [
    { key: 'repair', label: 'Réparation complète', ico: '🔧' },
    { key: 'tyres', label: 'Réparation des roues', ico: '🛞' },
    { key: 'clean', label: 'Nettoyage', ico: '🧽' },
];

window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'menu': return m.show ? openMenu(m) : $('#menu').classList.add('hidden');
        case 'menuData': Menu.data = m.data; return renderMenu();
        case 'invoiceSent': return;
        case 'mods': return m.show ? openMods(m) : $('#mods').classList.add('hidden');
        case 'modsRefused': Mods.waiting = false; Mods.refused = true; renderServices(); return renderFooter();
        case 'garage': return openGarage(m.vehicles || []);
        case 'invoice': return m.show ? openInvoice(m.invoice) : closeInvoice();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#mods').classList.contains('hidden')) { if (!Mods.waiting) post('modsCancel'); return; }
    if (!$('#garage').classList.contains('hidden')) return closeLayer('garage');
    if (!$('#menu').classList.contains('hidden')) return closeLayer('menu');
});
document.addEventListener('click', (e) => { const c = e.target.closest('[data-close]'); if (c) closeLayer(c.dataset.close); });
function closeLayer(id) { $(`#${id}`).classList.add('hidden'); post('close'); }

/* ================================================================== */
/* Menu de l'atelier                                                   */
/* ================================================================== */
const Menu = { data: null, tab: 'work', catalog: [], players: [], prefill: null, maxInvoice: 100000, prices: null };

function openMenu(m) {
    Object.assign(Menu, { catalog: m.catalog || [], maxInvoice: m.maxInvoice || 100000, prefill: m.prefill || null, data: null, prices: null });
    Menu.tab = m.prefill ? 'invoice' : 'work';
    $('#menuTitle').textContent = m.jobLabel || 'LsCustom';
    $('#menu').classList.remove('hidden');
    loadPlayers();
    renderMenu();
}

async function loadPlayers() {
    const r = await post('nearbyPlayers');
    Menu.players = r.players || [];
    if (Menu.tab === 'invoice') renderMenu();
}

$('#menuTabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-mtab]');
    if (!b) return;
    Menu.tab = b.dataset.mtab;
    if (Menu.tab === 'invoice') loadPlayers();
    renderMenu();
});

function renderMenu() {
    document.querySelectorAll('#menuTabs button').forEach((b) => b.classList.toggle('active', b.dataset.mtab === Menu.tab));
    const d = Menu.data;
    $('#menuSub').innerHTML = d ? `${d.onduty ? '<span class="status on">En service</span>' : '<span class="status off">Hors service</span>'}${d.enabled ? '' : ' <span class="status off">Atelier fermé</span>'}` : '';
    const body = $('#menuBody');
    if (!d) { body.innerHTML = '<p class="muted">Chargement…</p>'; return; }
    const p = d.perms || {};
    if (Menu.tab === 'work') {
        const dis = (perm) => (p[perm] && d.onduty && d.enabled ? '' : 'disabled');
        body.innerHTML = `
            <div class="duty-card ${d.onduty ? 'on' : ''}">
                <div><strong>${d.onduty ? 'Tu es en service' : 'Tu es hors service'}</strong>
                    <span>${d.onduty ? 'Tu peux travailler et tu portes ta tenue de travail.' : 'Prends ton service pour travailler.'}</span></div>
                <button class="btn ${d.onduty ? '' : 'primary'}" data-ma="duty" ${!d.onduty && !d.enabled ? 'disabled title="Atelier fermé"' : ''}>${d.onduty ? 'Terminer le service' : 'Prendre le service'}</button>
            </div>
            <div class="acts">
                <button class="act" data-ma="repair" ${dis('repair')}><strong>Réparer</strong><span>Véhicule le plus proche</span></button>
                <button class="act" data-ma="clean" ${dis('clean')}><strong>Nettoyer</strong><span>Véhicule le plus proche</span></button>
                <button class="act" data-ma="mods" ${dis('modify')}><strong>Personnaliser</strong><span>Dans une zone « Modification »</span></button>
                <button class="act" data-mtab-go="invoice" ${dis('invoice')}><strong>Facturer</strong><span>Une personne proche</span></button>
            </div>
            ${!d.enabled ? '<p class="note">L\'atelier est fermé par le staff : aucune prestation possible.</p>' : ''}
            <h3>Mécaniciens en service (${d.mechanics.length})</h3>
            ${d.mechanics.length ? `<div class="list">${d.mechanics.map((x) => `<div class="li"><div><b>${esc(x.name)}</b><small>${esc(x.grade)}</small></div></div>`).join('')}</div>` : '<p class="muted">Personne en service.</p>'}`;
    } else if (Menu.tab === 'invoice') {
        const pf = Menu.prefill || {};
        body.innerHTML = p.invoice ? `
            <label class="field">Client
                <select id="invTarget">${Menu.players.length ? Menu.players.map((x) => `<option value="${x.id}">[${x.id}] ${esc(x.name)} · ${x.distance} m</option>`).join('') : '<option value="">Personne à proximité</option>'}</select></label>
            <label class="field">Motif<input type="text" id="invLabelIn" value="${esc(pf.label || '')}" placeholder="Ex. : Réparation complète"></label>
            <label class="field">Montant<input type="number" id="invAmountIn" min="1" max="${Menu.maxInvoice}" value="${pf.amount || ''}"></label>
            <div class="row-btns" style="justify-content:space-between"><button class="btn" data-ma="refreshPlayers">Actualiser</button>
                <button class="btn primary" data-ma="invoice" ${Menu.players.length ? '' : 'disabled'}>Envoyer la facture</button></div>
            <p class="note">Le client accepte et paie par banque. Ta commission est versée automatiquement.</p>`
            : '<p class="muted">Ton grade ne permet pas de facturer.</p>';
    } else {
        const edit = p.prices === true;
        Menu.prices = Menu.prices || { ...d.prices };
        body.innerHTML = Object.entries(GROUPS).map(([g, label]) => `<h3>${label}</h3>${Menu.catalog.filter((c) => c.group === g).map((c) => `
            <div class="price-row"><span>${esc(c.label)}${c.perLevel ? ' <small class="muted">par niveau</small>' : ''}</span>
            ${edit ? `<input type="number" min="0" data-price="${c.key}" value="${Number(Menu.prices[c.key] || 0)}">` : `<span class="mono" style="text-align:right">${money(Menu.prices[c.key])}</span>`}</div>`).join('')}`).join('')
            + (edit ? '<div class="row-btns" style="margin-top:14px;justify-content:flex-end"><button class="btn primary" data-ma="savePrices">Enregistrer les tarifs</button></div>' : '');
    }
}

$('#menuBody').addEventListener('input', (e) => { if (e.target.dataset.price) Menu.prices[e.target.dataset.price] = Number(e.target.value); });
$('#menuBody').addEventListener('click', (e) => {
    const go = e.target.closest('[data-mtab-go]');
    if (go && !go.disabled) { Menu.tab = go.dataset.mtabGo; loadPlayers(); return renderMenu(); }
    const b = e.target.closest('[data-ma]');
    if (!b || b.disabled) return;
    const a = b.dataset.ma;
    if (a === 'refreshPlayers') return loadPlayers();
    if (a === 'invoice') {
        const target = Number($('#invTarget').value);
        const amount = Number($('#invAmountIn').value);
        if (!target || !amount) return;
        post('menuAction', { action: 'invoice', target, amount, label: $('#invLabelIn').value.trim() });
        Menu.prefill = null;
        return closeLayer('menu');
    }
    if (a === 'savePrices') return post('menuAction', { action: 'prices', prices: Menu.prices });
    post('menuAction', { action: a });
});

/* ================================================================== */
/* Personnalisation                                                    */
/* ================================================================== */
const Mods = { cats: [], prices: {}, wheelTypes: [], cat: null, opts: null, cart: {}, waiting: false, refused: false, wheelType: null };

function openMods(m) {
    Object.assign(Mods, { cats: m.categories || [], prices: m.prices || {}, wheelTypes: m.wheelTypes || [], cat: null, opts: null, cart: {}, waiting: false, refused: false, wheelType: null, picker: null,
        state: m.state || {}, allowed: m.services || {} });
    $('#modsVehicle').textContent = m.vehicle || 'Véhicule';
    $('#modsPlate').textContent = m.plate || '';
    $('#menu').classList.add('hidden');
    $('#mods').classList.remove('hidden');
    $('#modsOptions').innerHTML = '<p class="muted pad">Choisis une catégorie à gauche. Les changements s\'affichent directement sur le véhicule.</p>';
    renderServices();
    renderCats();
    renderFooter();
}

/* ---------- Services (en haut du menu) ---------- */
function serviceInfo(key) {
    const s = Mods.state || {};
    if (key === 'repair') return `Moteur ${s.engine ?? 100} % · Carrosserie ${s.body ?? 100} %`;
    if (key === 'tyres') return s.tyres ? `${s.tyres} pneu${s.tyres > 1 ? 's' : ''} crevé${s.tyres > 1 ? 's' : ''}` : 'Pneus en bon état';
    return `Saleté ${Math.min(100, s.dirt ?? 0)} %`;
}
function serviceAlert(key) {
    const s = Mods.state || {};
    if (key === 'repair') return (s.engine ?? 100) < 90 || (s.body ?? 100) < 90;
    if (key === 'tyres') return (s.tyres || 0) > 0;
    return (s.dirt || 0) > 20;
}
function renderServices() {
    $('#modsServices').innerHTML = SERVICES.map((x) => {
        const on = !!Mods.cart[x.key];
        const ok = Mods.allowed[x.key] !== false;
        return `<button class="svc ${on ? 'on' : ''} ${serviceAlert(x.key) ? 'alert' : ''}" data-svc="${x.key}" ${ok && !Mods.waiting ? '' : 'disabled'}>
            <span class="svc-ico">${x.ico}</span>
            <span class="svc-txt"><b>${x.label}</b><small>${ok ? serviceInfo(x.key) : 'Grade insuffisant'}</small></span>
            <span class="svc-price">${on ? '✓ ' : '+ '}${money(Mods.prices[x.key])}</span></button>`;
    }).join('');
}
$('#modsServices').addEventListener('click', (e) => {
    const b = e.target.closest('[data-svc]');
    if (!b || b.disabled || Mods.waiting) return;
    const k = b.dataset.svc;
    if (Mods.cart[k]) delete Mods.cart[k]; else Mods.cart[k] = { value: 1, service: true };
    Mods.refused = false;
    renderServices();
    renderFooter();
});

const labelOf = (k) => { const s = SERVICES.find((x) => x.key === k); return s ? s.label : (catByKey(k) || {}).label || k; };

const catByKey = (k) => Mods.cats.find((c) => c.key === k);
const priceOf = (key, value) => {
    const c = catByKey(key);
    const base = Number(Mods.prices[key] || 0);
    if (c && c.perLevel && Number(value) >= 0) return base * (Number(value) + 1);
    return base;
};

function renderCats() {
    const order = ['performance', 'esthetique'];
    $('#modsCats').innerHTML = order.map((g) => {
        const list = Mods.cats.filter((c) => c.group === g);
        if (!list.length) return '';
        return `<div class="cat-group">${GROUPS[g]}</div>${list.map((c) => `<button class="cat ${Mods.cat === c.key ? 'active' : ''}" data-cat="${c.key}">
            <span>${esc(c.label)}</span>${Mods.cart[c.key] ? '<span class="dot"></span>' : ''}</button>`).join('')}`;
    }).join('');
}

async function loadOptions(key, wheelType) {
    const r = await post('modsOptions', { key, wheelType });
    Mods.opts = { key, ...r };
    if (r.wheelType !== undefined && r.wheelType !== null) Mods.wheelType = r.wheelType;
    renderOptions();
}

/* ---------- Couleur personnalisée (palette) ---------- */
const CUSTOM = { paint1: 'paint', paint2: 'paint', neon: 'light', smoke: 'light' };
const FINISHES = [
    { id: 0, label: 'Normal' }, { id: 1, label: 'Métallisé' }, { id: 2, label: 'Nacré' },
    { id: 3, label: 'Mat' }, { id: 4, label: 'Métal' }, { id: 5, label: 'Chrome' },
];
const hsvToRgb = (h, s, v) => {
    const f = (n) => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
    return [f(5), f(3), f(1)].map((x) => Math.round(x * 255));
};
const rgbToHsv = (r, g, b) => {
    r /= 255; g /= 255; b /= 255;
    const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
    let h = 0;
    if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return { h: (h * 60 + 360) % 360, s: max ? d / max : 0, v: max };
};
const toHex = (rgb) => `#${rgb.map((x) => x.toString(16).padStart(2, '0')).join('')}`;
const parseRgb = (v) => {
    const m = /^rgb:(\d+),(\d+),(\d+):?(\d*)$/.exec(String(v || ''));
    return m ? { rgb: [Number(m[1]), Number(m[2]), Number(m[3])], finish: m[4] === '' ? null : Number(m[4]) } : null;
};

// Prépare la palette avec la couleur actuelle (ou rouge par défaut)
function initPicker(key, value) {
    const p = parseRgb(value);
    const rgb = p ? p.rgb : [220, 30, 40];
    Mods.picker = { key, ...rgbToHsv(...rgb), finish: p && p.finish !== null ? p.finish : 1 };
}

function pickerValue() {
    const p = Mods.picker;
    const [r, g, b] = hsvToRgb(p.h, p.s, p.v);
    return CUSTOM[p.key] === 'paint' ? `rgb:${r},${g},${b}:${p.finish}` : `rgb:${r},${g},${b}`;
}

function pickerHTML(key, selected) {
    const p = Mods.picker;
    const hex = toHex(hsvToRgb(p.h, p.s, p.v));
    const active = !!parseRgb(selected);
    return `<div class="picker ${active ? 'active' : ''}">
        <div class="pk-head"><b>Couleur personnalisée</b>${active ? '<span class="pk-badge">Choisie</span>' : ''}
            <span class="pk-swatch" id="pkSwatch" style="background:${hex}"></span>
            <input type="text" id="pkHex" value="${hex}" maxlength="7" spellcheck="false"></div>
        <div class="pk-sv" id="pkSV" style="background-color:hsl(${Math.round(p.h)},100%,50%)">
            <span class="pk-dot" id="pkDot" style="left:${p.s * 100}%;top:${(1 - p.v) * 100}%"></span></div>
        <div class="pk-hue" id="pkHue"><span class="pk-hdot" id="pkHDot" style="left:${(p.h / 360) * 100}%"></span></div>
        ${CUSTOM[key] === 'paint' ? `<div class="chips" style="margin:10px 0 0">${FINISHES.map((f) => `<button class="chip ${p.finish === f.id ? 'on' : ''}" data-finish="${f.id}">${f.label}</button>`).join('')}</div>` : ''}
    </div>`;
}

// Met à jour la palette sans tout redessiner (glisser reste fluide)
function refreshPicker() {
    const p = Mods.picker;
    const hex = toHex(hsvToRgb(p.h, p.s, p.v));
    const set = (id, fn) => { const el = $(id); if (el) fn(el); };
    set('#pkSwatch', (el) => { el.style.background = hex; });
    set('#pkHex', (el) => { if (document.activeElement !== el) el.value = hex; });
    set('#pkSV', (el) => { el.style.backgroundColor = `hsl(${Math.round(p.h)},100%,50%)`; });
    set('#pkDot', (el) => { el.style.left = `${p.s * 100}%`; el.style.top = `${(1 - p.v) * 100}%`; });
    set('#pkHDot', (el) => { el.style.left = `${(p.h / 360) * 100}%`; });
}

// Aperçu sur le véhicule (limité pour ne pas inonder le jeu) + panier
let previewTimer = null;
function previewCustom(final) {
    const o = Mods.opts;
    if (!o || !Mods.picker || Mods.waiting) return;
    const value = pickerValue();
    if (value === String(o.original)) delete Mods.cart[o.key];
    else Mods.cart[o.key] = { value };
    clearTimeout(previewTimer);
    const send = () => post('modsPreview', { key: o.key, value });
    if (final) send(); else previewTimer = setTimeout(send, 60);
    if (final) { Mods.refused = false; renderOptions(); renderCats(); renderFooter(); }
}

let pickDrag = null;
function pickAt(e) {
    const el = pickDrag === 'sv' ? $('#pkSV') : $('#pkHue');
    if (!el) return;
    const r = el.getBoundingClientRect();
    const x = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width));
    const y = Math.max(0, Math.min(1, (e.clientY - r.top) / r.height));
    if (pickDrag === 'sv') { Mods.picker.s = x; Mods.picker.v = 1 - y; } else { Mods.picker.h = x * 360; }
    refreshPicker();
    previewCustom(false);
}
document.addEventListener('mousedown', (e) => {
    if (e.button !== 0 || Mods.waiting) return;
    if (e.target.closest('#pkSV')) pickDrag = 'sv';
    else if (e.target.closest('#pkHue')) pickDrag = 'hue';
    else return;
    e.preventDefault();
    pickAt(e);
});
document.addEventListener('mousemove', (e) => { if (pickDrag) pickAt(e); });
document.addEventListener('mouseup', (e) => {
    if (e.button === 0 && pickDrag) { pickDrag = null; previewCustom(true); }
});
document.addEventListener('change', (e) => {
    if (e.target.id !== 'pkHex' || !Mods.picker) return;
    const m = /^#?([0-9a-f]{6})$/i.exec(e.target.value.trim());
    if (!m) return refreshPicker();
    const n = parseInt(m[1], 16);
    Object.assign(Mods.picker, rgbToHsv((n >> 16) & 255, (n >> 8) & 255, n & 255));
    previewCustom(true);
});

function renderOptions() {
    const o = Mods.opts;
    if (!o) return;
    const c = catByKey(o.key);
    const sel = Mods.cart[o.key] ? Mods.cart[o.key].value : o.current;
    if (CUSTOM[o.key] && (!Mods.picker || Mods.picker.key !== o.key)) initPicker(o.key, sel);
    const wheelChips = c.key === 'wheels' ? `<div class="chips">${Mods.wheelTypes.map((w) => `<button class="chip ${Number(Mods.wheelType) === w.id ? 'on' : ''}" data-wtype="${w.id}">${esc(w.label)}</button>`).join('')}</div>` : '';
    $('#modsOptions').innerHTML = `
        <div class="opt-head"><b>${esc(c.label)}</b><span class="muted">${c.perLevel ? `${money(Mods.prices[c.key])} par niveau` : money(Mods.prices[c.key])}</span></div>
        ${wheelChips}
        ${CUSTOM[o.key] ? pickerHTML(o.key, sel) + `<div class="cat-group" style="padding:12px 0 6px">${o.key === 'neon' ? 'Effets animés et couleurs' : 'Couleurs prêtes'}</div>` : ''}
        ${o.options && o.options.length ? `<div class="opts">${o.options.map((x) => `<button class="opt ${String(x.value) === String(sel) ? 'sel' : ''}" data-val="${esc(x.value)}">
            ${esc(x.label)}${String(x.value) === String(o.original) ? '<small>Actuel</small>' : ''}</button>`).join('')}</div>` : '<p class="muted">Rien de disponible pour ce véhicule.</p>'}`;
}

function renderFooter() {
    const items = Object.entries(Mods.cart);
    const total = items.reduce((n, [k, v]) => n + priceOf(k, v.value), 0);
    $('#modsFooter').innerHTML = Mods.waiting
        ? `<span class="waiting">En attente du paiement du client…</span><span class="total">${money(total)}</span>`
        : `<div><div class="total">${money(total)}</div><div class="cart">${items.length ? items.map(([k]) => esc(labelOf(k))).join(', ') : 'Aucune prestation'}</div>
            ${Mods.refused ? '<div style="color:var(--red);font-size:.82rem">Facture refusée ou non payée.</div>' : ''}</div>
          <div class="row-btns">
            <button class="btn" data-mods="cancel">Annuler tout</button>
            <select id="modsClient" style="width:190px"></select>
            <button class="btn primary" data-mods="invoice" ${items.length ? '' : 'disabled'}>Facturer au client</button>
          </div>`;
    if (!Mods.waiting) fillClients();
}

async function fillClients() {
    const r = await post('nearbyPlayers');
    const s = $('#modsClient');
    if (!s) return;
    const list = r.players || [];
    s.innerHTML = list.length ? list.map((x) => `<option value="${x.id}">[${x.id}] ${esc(x.name)}</option>`).join('') : '<option value="">Aucun client proche</option>';
}

$('#modsCats').addEventListener('click', (e) => {
    const b = e.target.closest('[data-cat]');
    if (!b || Mods.waiting) return;
    Mods.cat = b.dataset.cat;
    Mods.wheelType = null;
    Mods.picker = null;
    renderCats();
    loadOptions(Mods.cat);
});

$('#modsOptions').addEventListener('click', (e) => {
    if (Mods.waiting) return;
    const f = e.target.closest('[data-finish]');
    if (f && Mods.picker) { Mods.picker.finish = Number(f.dataset.finish); return previewCustom(true); }
    const w = e.target.closest('[data-wtype]');
    if (w) return loadOptions('wheels', Number(w.dataset.wtype));
    const b = e.target.closest('[data-val]');
    if (!b) return;
    const o = Mods.opts;
    const raw = b.dataset.val;
    const value = /^-?\d+$/.test(raw) ? Number(raw) : raw;
    post('modsPreview', { key: o.key, value });
    if (CUSTOM[o.key]) Mods.picker = null;
    if (String(value) === String(o.original)) delete Mods.cart[o.key];
    else Mods.cart[o.key] = { value };
    Mods.refused = false;
    renderOptions();
    renderCats();
    renderFooter();
});

document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-mods]');
    if (!b || b.disabled) return;
    if (b.dataset.mods === 'cancel') { if (!Mods.waiting) post('modsCancel'); return; }
    if (b.dataset.mods === 'invoice') {
        const target = Number(($('#modsClient') || {}).value);
        if (!target) return;
        Mods.waiting = true;
        Mods.refused = false;
        renderServices();
        renderFooter();
        post('modsInvoice', { target, items: Object.entries(Mods.cart).map(([key, v]) => ({ key, level: v.value })) });
    }
});

/* ================================================================== */
/* Garage                                                              */
/* ================================================================== */
function openGarage(list) {
    $('#garage').classList.remove('hidden');
    $('#garageBody').innerHTML = list.length ? `<div class="list">${list.map((v) => `<div class="li"><div><b>${esc(v.label)}</b><small class="mono">${esc(v.model)}</small></div>
        <button class="btn primary" data-spawn="${v.index}" ${v.allowed ? '' : 'disabled title="Grade insuffisant"'}>${v.allowed ? 'Sortir' : `Grade ${v.grade}+`}</button></div>`).join('')}</div>`
        : '<p class="muted">Aucun véhicule de service configuré.</p>';
}
$('#garageBody').addEventListener('click', (e) => {
    const b = e.target.closest('[data-spawn]');
    if (!b || b.disabled) return;
    $('#garage').classList.add('hidden');
    post('garageSpawn', { index: Number(b.dataset.spawn) });
});

/* ================================================================== */
/* Facture reçue                                                       */
/* ================================================================== */
let invTimer = null, invCurrent = null;
function openInvoice(inv) {
    invCurrent = inv;
    $('#invCompany').textContent = inv.company || 'LsCustom';
    $('#invAmount').textContent = money(inv.amount);
    $('#invLabel').textContent = inv.label;
    $('#invMechanic').textContent = `Mécanicien : ${inv.mechanic}`;
    $('#invoice').classList.remove('hidden');
    let left = inv.timeout || 60;
    const bar = $('#invTime');
    bar.style.width = '100%';
    clearInterval(invTimer);
    invTimer = setInterval(() => {
        left -= 1;
        bar.style.width = `${Math.max(0, (left / (inv.timeout || 60)) * 100)}%`;
        if (left <= 0) answer(false);
    }, 1000);
}
function closeInvoice() { clearInterval(invTimer); invCurrent = null; $('#invoice').classList.add('hidden'); }
function answer(accept) {
    if (!invCurrent) return;
    post('invoiceAnswer', { id: invCurrent.id, accept });
    closeInvoice();
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-inv]');
    if (b) answer(b.dataset.inv === 'accept');
});

/* ================================================================== */
/* Caméra libre : clic droit maintenu sur le décor, molette = zoom     */
/* ================================================================== */
let camDrag = null, camAcc = { dx: 0, dy: 0 }, camTimer = null;
document.addEventListener('contextmenu', (e) => e.preventDefault());
$('#mods').addEventListener('mousedown', (e) => {
    if (e.button !== 2 || e.target.closest('.panel')) return;
    e.preventDefault();
    camDrag = { x: e.clientX, y: e.clientY };
    camAcc = { dx: 0, dy: 0 };
    document.body.classList.add('cam-dragging');
    post('camFree', { start: true });
});
window.addEventListener('mousemove', (e) => {
    if (!camDrag) return;
    camAcc.dx += e.clientX - camDrag.x;
    camAcc.dy += e.clientY - camDrag.y;
    camDrag = { x: e.clientX, y: e.clientY };
    if (camTimer) return;
    camTimer = setTimeout(() => {
        camTimer = null;
        if (camAcc.dx || camAcc.dy) { post('camFree', { dx: camAcc.dx, dy: camAcc.dy }); camAcc = { dx: 0, dy: 0 }; }
    }, 25);
});
window.addEventListener('mouseup', (e) => {
    if (e.button !== 2 || !camDrag) return;
    camDrag = null;
    document.body.classList.remove('cam-dragging');
});
$('#mods').addEventListener('wheel', (e) => {
    if (e.target.closest('.panel')) return;
    post('camZoom', { delta: e.deltaY > 0 ? 0.6 : -0.6 });
}, { passive: true });
