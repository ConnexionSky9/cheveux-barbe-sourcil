const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_garage';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const img = (url) => `<img src="${esc(url)}" alt="" onerror="this.replaceWith(Object.assign(document.createElement('span'),{className:'noimg',textContent:'🚗'}))">`;

const G = { data: null, tab: 'stored', q: '' };
const STATUS = {
    stored: { label: 'Au garage', cls: 'green' },
    out: { label: 'En circulation', cls: 'blue' },
    lost: { label: 'Introuvable', cls: 'warn' },
    impound: { label: 'Fourrière', cls: 'red' },
};
const TABS = [
    { id: 'stored', label: 'Au garage', match: (v) => v.status === 'stored' || v.status === 'lost' },
    { id: 'out', label: 'En circulation', match: (v) => v.status === 'out' },
    { id: 'impound', label: 'Fourrière', match: (v) => v.status === 'impound' },
    { id: 'all', label: 'Tous', match: () => true },
];

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') { G.data = m.data; G.tab = 'stored'; G.q = ''; $('#q').value = ''; $('#app').classList.remove('hidden'); render(); }
    if (m.action === 'data') { G.data = m.data; render(); }
});

function close() { $('#app').classList.add('hidden'); nui('close'); }
$('#closeBtn').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('#app').classList.contains('hidden')) close(); });
$('#q').addEventListener('input', (e) => { G.q = e.target.value.trim().toLowerCase(); renderGrid(); });

const level = (v) => (v >= 70 ? '' : v >= 35 ? 'mid' : 'low');
const bar = (label, v) => `<div class="bar-row"><span>${label}</span><div class="track"><div class="fill ${level(v)}" style="width:${Math.max(2, Math.min(100, v))}%"></div></div><span>${v} %</span></div>`;

function damages(v) {
    const out = [];
    if (v.tyres) out.push(`<span class="badge red">🛞 ${v.tyres} pneu${v.tyres > 1 ? 's' : ''} crevé${v.tyres > 1 ? 's' : ''}</span>`);
    if (v.windows) out.push(`<span class="badge red">🪟 ${v.windows} vitre${v.windows > 1 ? 's' : ''} cassée${v.windows > 1 ? 's' : ''}</span>`);
    if (v.doors) out.push(`<span class="badge red">🚪 ${v.doors} portière${v.doors > 1 ? 's' : ''} arrachée${v.doors > 1 ? 's' : ''}</span>`);
    if (v.deformed) out.push('<span class="badge warn">Carrosserie déformée</span>');
    if (v.dirt >= 40) out.push('<span class="badge">Sale</span>');
    if (!out.length) out.push('<span class="badge green">✓ Aucun dégât visible</span>');
    return out.join('');
}

function render() {
    const d = G.data;
    $('#garageName').textContent = d.name;
    const n = (id) => d.list.filter(TABS.find((t) => t.id === id).match).length;
    $('#counters').innerHTML = `<div class="counter"><b class="gold-text">${n('stored')}</b><span>Au garage</span></div>
        <div class="counter"><b>${n('out')}</b><span>Dehors</span></div><div class="counter"><b>${d.list.length}</b><span>Véhicules</span></div>`;
    $('#tabs').innerHTML = TABS.map((t) => `<button class="tab ${G.tab === t.id ? 'on' : ''}" data-tab="${t.id}">${t.label}<small>${n(t.id)}</small></button>`).join('');

    // Véhicule à ranger
    const c = d.candidate;
    $('#store').innerHTML = c && !c.foreign ? `
        <div class="store-card">
            <div class="thumb">${img(c.image)}</div>
            <div>
                <div class="eyebrow">Véhicule à ranger</div>
                <h2>${esc(c.label)} <span class="plate" style="margin-left:6px">${esc(c.plate)}</span></h2>
                <div class="bars" style="grid-template-columns:repeat(3,1fr);gap:14px">${bar('Moteur', c.engine)}${bar('Carrosserie', c.body)}${bar('Essence', c.fuel)}</div>
                ${c.tyres ? `<div class="damages"><span class="badge red">🛞 ${c.tyres} pneu(s) crevé(s)</span></div>` : ''}
            </div>
            <button class="btn primary" data-store>Ranger le véhicule</button>
        </div>`
        : `<div class="store-hint">${c && c.foreign ? `Le véhicule <span class="plate">${esc(c.plate)}</span> à côté de toi ne t'appartient pas : tu ne peux ranger que tes véhicules.`
            : 'Pour ranger un véhicule, gare-le près du garage et reparle au gardien : il apparaîtra ici.'}</div>`;
    renderGrid();
}

function renderGrid() {
    const d = G.data;
    const tab = TABS.find((t) => t.id === G.tab);
    const list = d.list.filter(tab.match).filter((v) => !G.q || v.label.toLowerCase().includes(G.q) || v.plate.toLowerCase().includes(G.q));
    if (!list.length) {
        $('#grid').innerHTML = `<div class="empty">${G.q ? 'Aucun véhicule ne correspond à ta recherche.' : G.tab === 'stored' ? 'Aucun véhicule rangé.' : 'Rien ici.'}</div>`;
        return;
    }
    $('#grid').innerHTML = list.map((v, i) => {
        const st = STATUS[v.status] || STATUS.stored;
        const can = (v.status === 'stored' || v.status === 'lost') && d.spots > 0;
        const why = v.status === 'out' ? 'Déjà en circulation' : v.status === 'impound' ? 'À la fourrière' : d.spots ? '' : 'Aucune place de sortie ici';
        return `<div class="card" style="animation-delay:${Math.min(i, 12) * 25}ms">
            <div class="img">${img(v.image)}<span class="badge ${st.cls} status">${st.label}</span><span class="plate">${esc(v.plate)}</span></div>
            <div class="body">
                <div class="name">${esc(v.label)}</div>
                <div class="where">${v.status === 'stored' && v.garage ? `Rangé à ${esc(v.garage)}` : v.status === 'lost' ? 'Introuvable en ville : tu peux le ressortir' : esc(v.model)}</div>
                <div class="bars">${bar('Moteur', v.engine)}${bar('Carrosserie', v.body)}${bar('Réservoir', v.tank)}${bar('Essence', v.fuel)}</div>
                <div class="damages">${damages(v)}</div>
                <button class="btn ${can ? 'primary' : ''}" data-out="${esc(v.plate)}" data-model="${esc(v.model)}" ${can ? '' : 'disabled'}>${can ? 'Sortir le véhicule' : why}</button>
            </div>
        </div>`;
    }).join('');
}

document.addEventListener('click', (e) => {
    const t = e.target.closest('[data-tab]');
    if (t) { G.tab = t.dataset.tab; return render(); }
    const o = e.target.closest('[data-out]');
    if (o && !o.disabled) { $('#app').classList.add('hidden'); return nui('takeOut', { plate: o.dataset.out, model: o.dataset.model }); }
    const s = e.target.closest('[data-store]');
    if (s) { s.disabled = true; s.textContent = 'Rangement…'; return nui('store'); }
});
