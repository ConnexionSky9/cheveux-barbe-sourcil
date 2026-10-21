/* =========================================================
   ELYZEA ILLÉGAL - TABLETTE DU GROUPE
   Affiche uniquement ce que le serveur envoie (le groupe du joueur).
   Les boutons ne sont qu'un confort : chaque action est revérifiée
   côté serveur (groupe, grade, permission, montant, cible).
   ========================================================= */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_illegal';
const $ = (s) => document.querySelector(s);
const post = (endpoint, body = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body) })
        .then((r) => r.json()).catch(() => ({}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
const signed = (n) => `<span class="amount ${n >= 0 ? 'plus' : 'minus'}">${n >= 0 ? '+' : '−'}${money(Math.abs(n))}</span>`;
const date = (t) => (t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
const ACCOUNTS = { clean: 'Argent propre', dirty: 'Argent sale' };
const PAYMENTS = { clean: 'Argent propre', dirty: 'Argent sale', both: 'Propre ou sale' };
const TX = { deposit: 'Dépôt', withdraw: 'Retrait', admin_add: 'Ajout staff', admin_remove: 'Retrait staff', order: 'Commande', mission: 'Mission' };
const STATUS = { pending: ['En attente de validation', 'gold'], preparing: ['En préparation', 'gold'], ready: ['Prête : point GPS', 'ok'], delivered: ['Livrée', 'ok'],
    refused: ['Refusée', 'danger'], cancelled: ['Annulée', ''] };
const hhmm = (t) => (t ? new Date(t * 1000).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) : '');

let D = null;
let tab = 'home';

// Une table Lua vide peut arriver en {} au lieu de [] : on remet les listes d'aplomb
const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
function normalize(d) {
    ['members', 'grades', 'orders', 'requests', 'permissions', 'categories'].forEach((k) => { d[k] = arr(d[k]); });
    if (d.logs) d.logs = arr(d.logs);
    if (d.finance) d.finance.history = arr(d.finance.history);
    d.group.og = arr(d.group.og);
    if (d.missions) { d.missions.list = arr(d.missions.list); if (d.missions.active) d.missions.active.participants = arr(d.missions.active.participants); }
    d.tabs = d.tabs || {};
    return d;
}
let orderCat = 'all';
let olderHistory = [];
let historyEnd = false;

const can = (p) => !!(D && D.me && D.me.perms && D.me.perms[p]);
const action = (name, data = {}) => post('action', { name, data });

const TABS = [
    { id: 'home', label: 'Informations', ico: '🏠', sub: () => 'Ton groupe, ton grade et tes permissions.', show: () => true },
    { id: 'members', label: 'Membres', ico: '👥', sub: () => `${D.members.length} membre(s).`, show: () => true },
    { id: 'grades', label: 'Grades', ico: '🎖', sub: () => 'Grades du groupe et leurs permissions.', show: () => true },
    { id: 'finances', label: 'Finances', ico: '💰', sub: () => 'Coffre du groupe : argent propre et argent sale, séparés.',
        show: () => ['finance_view', 'clean_deposit', 'clean_withdraw', 'dirty_deposit', 'dirty_withdraw'].some(can) },
    { id: 'orders', label: 'Commandes', ico: '📦', sub: () => 'Commandes illégales disponibles pour le groupe.',
        show: () => true, count: () => (can('orders_validate') ? D.requests.filter((r) => r.status === 'pending').length : 0) },
    { id: 'missions', label: 'Missions', ico: '🎯', sub: () => 'Missions du groupe : XP, niveaux et récompenses versées au coffre.',
        show: () => !!D.missions, count: () => (D.missions && D.missions.active ? 1 : 0) },
    { id: 'map', label: 'Map', ico: '🗺️', sub: () => 'Territoires de vente de drogue : à qui ils appartiennent et à combien de %.',
        show: () => !!D.territories, count: () => 0 },
    { id: 'settings', label: 'Paramètres', ico: '⚙️', sub: () => 'Nom, description et couleur du groupe.', show: () => can('settings') },
];
const visibleTabs = () => TABS.filter((t) => D.tabs && D.tabs[t.id] && t.show());

/* ---------- Messages Lua ---------- */
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
        D = normalize(m.data); tab = 'home'; olderHistory = []; historyEnd = false;
        $('#app').classList.remove('hidden');
        render();
    } else if (m.action === 'data') {
        D = normalize(m.data);
        if ($('#modal-root').innerHTML === '') render();   // ne pas casser une saisie en cours
    } else if (m.action === 'close') {
        $('#app').classList.add('hidden');
        closeModal();
    } else if (m.action === 'notify') {
        toast(m.message, m.type);
    } else if (m.action === 'prompt') {
        showPrompt(m);
    } else if (m.action === 'dsell') {
        dsell(m);
    } else if (m.action === 'f5') {
        openF5(m.data);
    } else if (m.action === 'f5close') {
        $('#quick').classList.add('hidden');
    } else if (m.action === 'missionHud') {
        missionHud(m);
    } else if (m.action === 'dprogress') {
        dprogress(m);
    } else if (m.action === 'missionEnd') {
        missionEnd(m);
    } else if (m.action === 'codeInput') {
        codeInput(m);
    } else if (m.action === 'codeClose') {
        $('#modal-root').innerHTML = '';
    }
});

/* ---------- Missions : compte à rebours, barre de progression (rendu du MenuStaff), fin ---------- */
let hudTimer = null, hudEnd = 0, hudData = null;
// HUD de mission : petit panneau discret (coin configurable). Les informations importantes
// (codes, plaques, mots de passe…) restent affichées tant que le serveur les garde.
const HUD_CAT = { objective: 'showObjective', clues: 'showClues', code: 'showCodes', password: 'showCodes', alert: 'showAlert' };
function missionHud(m) {
    const el = $('#missionhud');
    clearInterval(hudTimer);
    if (!m.show) { el.classList.add('hidden'); hudData = null; return; }
    const cfg = m.cfg || {};
    if (cfg.enabled === false) { el.classList.add('hidden'); return; }
    hudData = m;
    hudEnd = Date.now() + (m.remaining || 0) * 1000;
    const received = Date.now();
    el.className = `compact pos-${cfg.position || 'top-right'}`;
    el.style.setProperty('--hud-scale', cfg.scale || 1);
    el.style.setProperty('--hud-alpha', cfg.opacity ?? 0.92);
    const shown = (cat) => cfg[HUD_CAT[cat] || 'showInfo'] !== false;
    const draw = () => {
        const left = Math.max(0, Math.round((hudEnd - Date.now()) / 1000));
        const elapsed = (Date.now() - received) / 1000;
        const info = arr(m.info).filter((x) => x.remaining === undefined || x.remaining === null || x.remaining - elapsed > 0);
        const objInfo = info.find((x) => x.cat === 'objective');
        const objective = objInfo ? objInfo.value : m.objective;
        const rows = [];
        if (objective && cfg.showObjective !== false) rows.push(`<div class="mh-sec"><span>OBJECTIF</span><b>${esc(objective)}</b></div>`);
        arr(m.lines).forEach((l) => { if (shown(l.cat)) rows.push(`<div class="mh-row"><span>${esc(l.label)}</span><b>${esc(l.value)}</b></div>`); });
        info.filter((x) => x.cat !== 'objective' && shown(x.cat)).forEach((x) => {
            const imp = ['code', 'password', 'plate', 'phone'].includes(x.cat);
            rows.push(`<div class="mh-row ${imp ? 'imp' : ''} ${x.used ? 'used' : ''} ${x.cat === 'alert' ? 'alert a' + m.alert : ''}"><span>${esc(x.label)}</span>
                <b>${esc(x.value)}${x.used ? ' <i>utilisé</i>' : ''}</b></div>`);
        });
        if (cfg.showTimer !== false) rows.push(`<div class="mh-row time ${left <= 60 ? 'low' : ''}"><span>TEMPS</span><b>${clock(left)}</b></div>`);
        el.innerHTML = `<div class="mh-head">MISSION EN COURS<small>${esc(m.label || '')}</small></div>${rows.join('')}`;
    };
    draw();
    hudTimer = setInterval(draw, 1000);
    el.classList.remove('hidden');
}

/* ---------- Saisie du code d'une caisse (vérifié par le serveur) ---------- */
function codeInput(m) {
    $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal" style="width:380px">
        <h2>Caisse n°${Number(m.crate)} — code</h2>
        <p class="hint">Entre le code. ${hudData && arr(hudData.info).find((x) => x.cat === 'code' && !x.used) ? 'Le code trouvé est affiché dans le HUD de mission.' : 'Le code se trouve dans un indice ou dans la cabine du fourgon.'}</p>
        <div class="field"><input class="input" id="code-in" maxlength="12" autocomplete="off" style="font:700 26px var(--display);letter-spacing:.3em;text-align:center"></div>
        <div class="btn-row"><button class="btn danger" data-cm="force">Forcer (alarme)</button><span style="flex:1"></span>
            <button class="btn" data-cm="cancel">Annuler</button><button class="btn primary" data-cm="code">Valider</button></div></div></div>`;
    const input = $('#code-in');
    if (input) input.focus();
    const done = (action) => { const code = input ? input.value.trim() : ''; $('#modal-root').innerHTML = ''; post('codeResult', { action, code }); };
    $('#modal-root').onclick = (e) => { const b = e.target.closest('[data-cm]'); if (b) done(b.dataset.cm); };
    if (input) input.onkeydown = (e) => { if (e.key === 'Enter') done('code'); if (e.key === 'Escape') done('cancel'); };
}

function dprogress(m) {
    const el = $('#dprogress');
    clearInterval(window.__dpT);
    if (!m.show) { el.classList.add('hidden'); return; }
    el.querySelector('b').textContent = m.label || '';
    const bar = el.querySelector('i');
    bar.style.transition = 'none'; bar.style.width = '0'; void bar.offsetWidth;
    bar.style.transition = `width ${m.time}s linear`; bar.style.width = '100%';
    const end = Date.now() + m.time * 1000, sp = el.querySelector('span');
    const tick = () => { sp.textContent = `${Math.max(0, Math.ceil((end - Date.now()) / 1000))} s`; };
    tick(); window.__dpT = setInterval(tick, 250);
    el.classList.remove('hidden');
}
let endTimer = null;
function missionEnd(m) {
    const el = $('#missionend');
    const [title, ...rest] = String(m.message || '').split(' : ');
    el.className = m.success ? '' : 'fail';
    el.innerHTML = `<b>${esc(title || (m.success ? 'MISSION TERMINÉE' : 'MISSION ÉCHOUÉE'))}</b>${rest.length ? `<span>${esc(rest.join(' : '))}</span>` : ''}`;
    clearTimeout(endTimer);
    endTimer = setTimeout(() => el.classList.add('hidden'), 6000);
}

/* ---------- Invite d'interaction [E] (même rendu que le MenuStaff) ---------- */
function showPrompt(m) {
    const el = $('#prompt');
    if (!m.show) { el.classList.add('hidden'); return; }
    el.classList.toggle('muted', !!m.muted);
    el.innerHTML = `<span class="pk">${esc(m.key || 'E')}</span><span class="pt"><span class="pa">${esc(m.verb || '')}</span><span class="pn">${esc(m.name || '')}</span></span>`;
    el.classList.remove('hidden');
}

/* ---------- Menu F5 (même panneau que le menu rapide du staff) ---------- */
function openF5(d) {
    F5DATA = d;
    const box = $('#quick');
    document.documentElement.style.setProperty('--rank', d.color || '#d9b56a');
    box.innerHTML = `<div class="q-panel">
        <div class="q-head"><div><strong>Menu</strong><span class="muted">F5 · groupe illégal</span></div>
            <button class="sb-close q-close" data-f5="close" title="Fermer (Échap)">✕</button></div>
        <div class="q-body">${d.inGroup !== false && d.label ? `<div class="q-sec"><h3>Ton groupe</h3>
            <button class="q-group" data-f5="open"><span class="q-crest">${esc((d.label || '?').charAt(0).toUpperCase())}</span>
                <span><strong>${esc(d.label)}</strong><span>${esc(d.grade ? `Grade : ${d.grade}` : '')} · ouvrir la tablette</span></span></button>
        </div>` : ''}${d.drug ? drugSection(d.drug) : ''}</div></div>`;
    box.classList.remove('hidden');
}
const F5SEL = new Set();
function drugSection(g) {
    const items = g.items || [];
    if (g.on) {
        const sel = g.selected && g.selected.length ? items.filter((i) => g.selected.includes(i.item)) : items;
        return `<div class="q-sec"><h3>Vente de drogue</h3>
            <button class="q-group q-drug on" data-f5="drug" data-on="0"><span class="q-crest">🌿</span>
                <span><strong>Mode vente activé</strong><span>${g.sales} vendu(s) · ${g.earned} $ · cliquer pour arrêter</span></span></button>
            <p class="muted" style="font-size:11.5px;margin:8px 2px 4px">Tu vends : ${g.selected && g.selected.length ? '' : '<b>tout</b> (les clients demandent au hasard)'}</p>
            <div class="q-chips">${sel.map((i) => `<span class="q-chip on">${esc(i.label)} <b>× ${i.count}</b></span>`).join('') || '<span class="muted">Plus rien sur toi.</span>'}</div></div>`;
    }
    for (const it of [...F5SEL]) if (!items.some((i) => i.item === it)) F5SEL.delete(it);
    const all = items.length > 0 && (F5SEL.size === 0 || F5SEL.size === items.length);
    const chips = items.map((i) => `<button class="q-chip q-pick ${all || F5SEL.has(i.item) ? 'on' : ''}" data-dpick="${esc(i.item)}" title="${i.min} à ${i.max} $ l'unité">
        <span class="q-box"></span>${esc(i.label)} <b>× ${i.count}</b><small>${i.min}–${i.max} $</small></button>`).join('');
    return `<div class="q-sec"><h3>Vente de drogue</h3>
        <p class="muted" style="font-size:11.5px;margin:0 2px 6px">Choisis ce que tu vends (seulement ce que tu as sur toi). Une seule drogue : les clients ne demandent qu'elle. Tout : ils demandent au hasard.</p>
        <div class="q-chips">${items.length ? `<button class="q-chip q-pick ${all ? 'on' : ''}" data-dpick="*"><span class="q-box"></span><b>Tout</b></button>${chips}` : '<span class="muted">Plus rien sur toi.</span>'}</div>
        <button class="q-group q-drug" style="margin-top:10px" data-f5="drug" data-on="1" ${!g.can ? 'disabled' : ''}>
            <span class="q-crest">🌿</span>
            <span><strong>Activer le mode vente</strong>
            <span>${g.can ? (all ? 'Tout ce que tu as' : `${F5SEL.size} drogue${F5SEL.size > 1 ? 's' : ''} choisie${F5SEL.size > 1 ? 's' : ''}`) : esc(g.reason || '')}</span></span></button>
        <p class="muted" style="font-size:11.5px;margin:6px 2px 0">Clients : 🥴 l'accro (peu d'argent, paie bien, vole souvent), 💎 le riche (paie même cher), 🎉 le fêtard (achète en gros).
            [E] fixer ton prix à l'unité · [G] refuser. Certains volent, sortent un couteau ou appellent la police.</p></div>`;
}
let F5DATA = null;
/* ---------- Vente de drogue : prix proposé au client (au dollar près) ---------- */
function dsell(m) {
    const el = $('#dsell');
    if (!m.show) { el.classList.add('hidden'); el.innerHTML = ''; return; }
    const d = m.data;
    const clamp = (v) => Math.max(d.min, Math.min(d.max, Math.round(Number(v) || d.min)));
    el.dataset.profile = d.profile || '';
    el.innerHTML = `<div class="ds-card">
        <div class="ds-head"><span class="ds-ico">${esc(d.picon || '👤')}</span><div><strong>${esc(d.plabel || 'Client')}</strong><span>veut <b>${d.qty} × ${esc(d.label)}</b></span></div></div>
        ${d.msg ? `<div class="ds-msg">${esc(d.msg)}</div>` : ''}
        <label class="ds-lbl">Ton prix à l'unité</label>
        <div class="ds-price"><button data-ds="-10">−10</button><button data-ds="-1">−1</button>
            <input id="ds-val" type="number" min="${d.min}" max="${d.max}" step="1" value="${clamp(d.price)}"><span>$</span>
            <button data-ds="1">+1</button><button data-ds="10">+10</button></div>
        <input id="ds-range" type="range" min="${d.min}" max="${d.max}" step="1" value="${clamp(d.price)}">
        <div class="ds-scale"><span>${d.min} $</span><span>${d.max} $</span></div>
        <div class="ds-total">Total demandé : <b id="ds-total"></b></div>
        <div class="ds-btns"><button class="ds-no" data-ds="refuse">Refuser <kbd>Échap</kbd></button><button class="ds-ok" data-ds="offer">Proposer <kbd>Entrée</kbd></button></div>
        <p class="ds-hint">Plus c'est cher, plus il risque de refuser. Le riche paie même cher, l'accro n'a pas beaucoup d'argent, le fêtard achète en gros.</p></div>`;
    const val = $('#ds-val'), rng = $('#ds-range');
    const sync = (v, from) => { v = clamp(v); if (from !== val) val.value = v; rng.value = v; $('#ds-total').textContent = `${(v * d.qty).toLocaleString('fr-FR')} $ (${d.qty} × ${v} $)`; };
    sync(val.value);
    val.addEventListener('input', () => { if (val.value !== '') sync(val.value, val); });
    val.addEventListener('change', () => sync(val.value));
    rng.addEventListener('input', () => sync(rng.value));
    el.onclick = (e) => {
        const b = e.target.closest('[data-ds]');
        if (!b) return;
        const k = b.dataset.ds;
        if (k === 'offer') return dsellSend(clamp(val.value));
        if (k === 'refuse') return dsellRefuse();
        sync(clamp(val.value) + Number(k));
    };
    el.classList.remove('hidden');
    setTimeout(() => { val.focus(); val.select(); }, 30);
}
function dsellSend(price) { $('#dsell').classList.add('hidden'); post('dsellOffer', { price }); }
function dsellRefuse() { $('#dsell').classList.add('hidden'); post('dsellRefuse'); }
document.addEventListener('keydown', (e) => {
    if ($('#dsell').classList.contains('hidden')) return;
    if (e.key === 'Enter') { e.preventDefault(); const v = $('#ds-val'); dsellSend(Math.round(Number(v.value) || Number(v.min))); }
    else if (e.key === 'Escape') { e.preventDefault(); e.stopImmediatePropagation(); dsellRefuse(); }
}, true);

function closeF5() { $('#quick').classList.add('hidden'); post('f5close'); }
$('#quick').addEventListener('click', (e) => {
    const b = e.target.closest('[data-f5]');
    if (e.target.id === 'quick' || (b && b.dataset.f5 === 'close')) return closeF5();
    if (b && b.dataset.f5 === 'open') { $('#quick').classList.add('hidden'); post('f5open'); }
    const pick = e.target.closest('[data-dpick]');
    if (pick && F5DATA && F5DATA.drug) {
        const items = (F5DATA.drug.items || []).map((i) => i.item);
        const it = pick.dataset.dpick;
        const allOn = F5SEL.size === 0 || F5SEL.size === items.length;
        if (it === '*') F5SEL.clear();
        else if (allOn) { F5SEL.clear(); F5SEL.add(it); }
        else if (F5SEL.has(it)) { F5SEL.delete(it); }
        else { F5SEL.add(it); if (F5SEL.size === items.length) F5SEL.clear(); }
        return openF5(F5DATA);
    }
    if (b && b.dataset.f5 === 'drug' && !b.disabled) {
        $('#quick').classList.add('hidden');
        post('f5drug', { on: b.dataset.on === '1', items: b.dataset.on === '1' && F5SEL.size ? [...F5SEL] : [] });
    }
});

function close() { $('#app').classList.add('hidden'); closeModal(); post('close'); }
$('#close-btn').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#quick').classList.contains('hidden')) return closeF5();
    if (e.key !== 'Escape' || $('#app').classList.contains('hidden')) return;
    if ($('#modal-root').innerHTML) return closeModal();
    close();
});
setInterval(() => { const d = new Date(); $('#sb-clock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

/* ---------- Rendu ---------- */
function render() {
    if (!D) return;
    const g = D.group;
    document.documentElement.style.setProperty('--rank', g.color || '#d9b56a');
    $('#sb-title').textContent = g.label;
    $('#sb-via').textContent = D.via === 'ped' ? '📍 Depuis le PNJ' : `👥 ${D.members.filter((m) => m.online).length} en ligne`;
    $('#brand-name').textContent = g.label;
    $('#brand-sub').textContent = g.typeLabel;
    $('#me-name').textContent = `Connecté : ${D.me.name}`;
    $('#me-grade').textContent = D.me.grade + (D.me.boss ? ' · Chef' : '');
    $('#sidebar-foot').innerHTML = `${esc(g.label)} · ${esc(g.typeLabel)}<br>Ouvrir : <span class="keycap">F5</span>${D.via === 'ped' ? ' ou le PNJ' : ''}`;

    const tabs = visibleTabs();
    if (!tabs.find((t) => t.id === tab)) tab = 'home';
    $('#tabs').innerHTML = tabs.map((t) => {
        const c = t.count ? t.count() : 0;
        return `<button class="tab ${t.id === tab ? 'active' : ''}" data-tab="${t.id}"><span class="ico">${t.ico}</span>${t.label}${c ? `<span class="count">${c}</span>` : ''}</button>`;
    }).join('');
    const cur = TABS.find((t) => t.id === tab);
    $('#page-title').textContent = cur.label;
    $('#page-sub').textContent = cur.sub();
    const content = $('#content');
    const top = content.scrollTop;
    if (TMap.inst && tab !== 'map') TMap.destroy();
    content.innerHTML = VIEWS[tab]();
    content.scrollTop = top;
    if (tab === 'map') TMap.mount();
}

$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tab]');
    if (b) { tab = b.dataset.tab; $('#content').scrollTop = 0; render(); }
});

const VIEWS = {};

/* ---------- Map des territoires ---------- */
const MAP_BOUNDS = { minX: -5661.2, maxX: 6694.0, minY: -4058.5, maxY: 8429.3 };   // image satellite html/img/map.jpg
const TMap = { inst: null, sel: null, view: null };
const NEUTRAL = '#ecf0f8';
function hexA(hex, a) {
    const h = String(hex || NEUTRAL).replace('#', '');
    const n = parseInt(h.length === 3 ? h.split('').map((c) => c + c).join('') : h.slice(0, 6), 16) || 0;
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}
const zoneColor = (z) => (z.owner ? z.owner.color : NEUTRAL);
function zoneCenter(z) {
    if (z.shape === 'circle') return { x: z.center.x, y: z.center.y };
    const p = z.points || [];
    return { x: p.reduce((a, q) => a + q.x, 0) / (p.length || 1), y: p.reduce((a, q) => a + q.y, 0) / (p.length || 1) };
}
function shareBar(z) {
    if (!z.shares.length) return '<div class="t-bar"><i style="width:100%;background:rgba(236,240,248,.25)"></i></div>';
    return `<div class="t-bar">${z.shares.map((s) => `<i style="width:${s.pct}%;background:${esc(s.color)}" title="${esc(s.label)} ${s.pct} %"></i>`).join('')}</div>`;
}
VIEWS.map = () => {
    const list = D.territories || [];
    const mine = list.filter((z) => z.owner && z.owner.id === D.group.id).length;
    const rows = list.map((z) => `<div class="t-row ${TMap.sel === z.id ? 'sel' : ''}" data-tzone="${z.id}">
        <div class="t-head"><span class="t-dot" style="background:${esc(zoneColor(z))}"></span><b>${esc(z.name)}</b>
            <span class="muted">${z.owner ? `${esc(z.owner.label)} · ${z.owner.pct} %` : 'Neutre'}</span></div>
        ${shareBar(z)}
        ${TMap.sel === z.id ? `<div class="t-go"><button class="btn primary" data-tgo="${z.id}">📍 Y aller (point GPS)</button></div>` : ''}
        ${z.shares.length ? `<div class="t-shares">${z.shares.map((s) => `<span><i style="background:${esc(s.color)}"></i>${esc(s.label)} <b>${s.pct} %</b></span>`).join('')}</div>` : '<div class="t-shares muted">Personne ne contrôle cette zone.</div>'}
    </div>`).join('');
    return `<div class="t-wrap">
        <div class="t-map" id="tmap"><canvas></canvas>
            <div class="t-tools"><button class="btn" data-tmap="in">+</button><button class="btn" data-tmap="out">−</button><button class="btn" data-tmap="fit">⤢</button><button class="btn" data-tmap="refresh" title="Actualiser">⟳</button></div>
            <div class="t-legend"><span><i style="background:${NEUTRAL}"></i>Neutre</span><span><i style="background:${esc(D.group.color)}"></i>${esc(D.group.label)}</span><span class="muted">Autres couleurs : groupes rivaux</span></div></div>
        <div class="t-side">
            <div class="stats" style="grid-template-columns:1fr 1fr;margin-bottom:10px">
                <div class="stat"><b>${list.length}</b><span>Territoire(s)</span></div>
                <div class="stat"><b>${mine}</b><span>Contrôlé(s) par ${esc(D.group.label)}</span></div></div>
            <p class="muted" style="font-size:12px;margin:0 0 8px">On ne vend de la drogue (F5 › Vente de drogue) que dans ces zones. Chaque pochon vendu par un membre fait gagner du % à son groupe, pris aux autres.</p>
            ${rows || '<div class="empty">Aucun territoire n\'a encore été créé par le staff.</div>'}
        </div></div>`;
};
TMap.destroy = () => { if (TMap.inst) { TMap.inst.dead = true; window.removeEventListener('mouseup', TMap.inst.up); window.removeEventListener('mousemove', TMap.inst.move); } TMap.inst = null; };
TMap.mount = () => {
    TMap.destroy();
    const box = document.getElementById('tmap');
    if (!box) return;
    const canvas = box.querySelector('canvas'), ctx = canvas.getContext('2d');
    const img = TMap.img || (TMap.img = Object.assign(new Image(), { src: 'img/map.jpg' }));
    const S = TMap.view || { cx: 300, cy: 600, scale: 0 };
    const I = { dead: false };
    TMap.inst = I;
    let W = 0, H = 0, dpr = 1;
    const sx = (x) => (x - S.cx) * S.scale + W / 2, sy = (y) => -(y - S.cy) * S.scale + H / 2;
    const wx = (px) => (px - W / 2) / S.scale + S.cx, wy = (py) => -(py - H / 2) / S.scale + S.cy;
    function size() { const r = box.getBoundingClientRect(); dpr = window.devicePixelRatio || 1; W = r.width; H = r.height; canvas.width = W * dpr; canvas.height = H * dpr; }
    function fit() {
        size();
        const zs = D.territories || [];
        let b = { minX: -3500, maxX: 4000, minY: -3800, maxY: 7500 };
        if (zs.length) {
            b = { minX: Infinity, maxX: -Infinity, minY: Infinity, maxY: -Infinity };
            zs.forEach((z) => (z.shape === 'circle' ? [{ x: z.center.x - z.radius, y: z.center.y - z.radius }, { x: z.center.x + z.radius, y: z.center.y + z.radius }] : z.points)
                .forEach((p) => { b.minX = Math.min(b.minX, p.x); b.maxX = Math.max(b.maxX, p.x); b.minY = Math.min(b.minY, p.y); b.maxY = Math.max(b.maxY, p.y); }));
            const pad = Math.max(300, (b.maxX - b.minX) * 0.25);
            b.minX -= pad; b.maxX += pad; b.minY -= pad; b.maxY += pad;
        }
        S.scale = Math.min(W / (b.maxX - b.minX), H / (b.maxY - b.minY));
        S.cx = (b.minX + b.maxX) / 2; S.cy = (b.minY + b.maxY) / 2;
    }
    function shape(z) {
        ctx.beginPath();
        if (z.shape === 'circle') ctx.arc(sx(z.center.x), sy(z.center.y), z.radius * S.scale, 0, Math.PI * 2);
        else z.points.forEach((p, i) => (i ? ctx.lineTo(sx(p.x), sy(p.y)) : ctx.moveTo(sx(p.x), sy(p.y))));
        ctx.closePath();
    }
    function frame() {
        if (I.dead) return;
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.fillStyle = '#143d6b'; ctx.fillRect(0, 0, W, H);
        if (img.complete && img.naturalWidth) {
            const b = MAP_BOUNDS;
            ctx.drawImage(img, sx(b.minX), sy(b.maxY), (b.maxX - b.minX) * S.scale, (b.maxY - b.minY) * S.scale);
        }
        (D.territories || []).forEach((z) => {
            const c = zoneColor(z), sel = TMap.sel === z.id;
            shape(z);
            ctx.fillStyle = hexA(c, sel ? 0.5 : 0.35); ctx.fill();
            ctx.lineWidth = sel ? 3 : 2; ctx.strokeStyle = hexA(c, 0.95); ctx.stroke();
            const ce = zoneCenter(z);
            ctx.font = '700 13px Barlow, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
            ctx.shadowColor = 'rgba(0,0,0,.9)'; ctx.shadowBlur = 4; ctx.fillStyle = '#fff';
            ctx.fillText(z.name, sx(ce.x), sy(ce.y) - 8);
            ctx.font = '600 11.5px Barlow, sans-serif'; ctx.fillStyle = '#fff';
            ctx.fillText(z.owner ? `${z.owner.label} ${z.owner.pct} %` : 'Neutre', sx(ce.x), sy(ce.y) + 8);
            ctx.shadowBlur = 0;
        });
        requestAnimationFrame(frame);
    }
    function zoomAt(f, px = W / 2, py = H / 2) { const bx = wx(px), by = wy(py); S.scale = Math.max(0.02, Math.min(3, S.scale * f)); S.cx = bx - (px - W / 2) / S.scale; S.cy = by + (py - H / 2) / S.scale; }
    let drag = null;
    canvas.addEventListener('mousedown', (e) => { drag = { x: e.clientX, y: e.clientY, cx: S.cx, cy: S.cy, moved: false }; });
    I.move = (e) => { if (!drag) return; const dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true; S.cx = drag.cx - dx / S.scale; S.cy = drag.cy + dy / S.scale; };
    I.up = (e) => {
        if (!drag) return;
        const moved = drag.moved; drag = null;
        if (moved || !box.isConnected) return;
        const r = canvas.getBoundingClientRect(), px = e.clientX - r.left, py = e.clientY - r.top;
        const hit = (D.territories || []).find((z) => { shape(z); return ctx.isPointInPath(px * dpr, py * dpr); });
        if (hit) selectZone(hit.id, false);
    };
    window.addEventListener('mousemove', I.move);
    window.addEventListener('mouseup', I.up);
    canvas.addEventListener('wheel', (e) => { e.preventDefault(); zoomAt(e.deltaY < 0 ? 1.25 : 0.8, e.offsetX, e.offsetY); }, { passive: false });
    I.zoom = zoomAt;
    I.fit = fit;
    I.focus = (z) => { const c = zoneCenter(z); S.cx = c.x; S.cy = c.y; S.scale = Math.max(S.scale, 0.35); };
    if (!S.scale) fit(); else size();
    TMap.view = S;
    requestAnimationFrame(frame);
};
function selectZone(id, focus) {
    TMap.sel = TMap.sel === id && !focus ? null : id;
    const z = (D.territories || []).find((x) => x.id === id);
    if (focus && z && TMap.inst) TMap.inst.focus(z);
    const side = document.querySelector('.t-side');
    const keep = side ? side.scrollTop : 0;
    if (tab === 'map') { const c = $('#content'); const old = TMap.inst; c.querySelector('.t-side').outerHTML = new DOMParser().parseFromString(VIEWS.map(), 'text/html').querySelector('.t-side').outerHTML; if (old) TMap.inst = old; }
    const side2 = document.querySelector('.t-side');
    if (side2) side2.scrollTop = keep;
    const row = document.querySelector(`.t-row[data-tzone="${id}"]`);
    if (row && !focus) row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}
document.addEventListener('click', (e) => {
    const go = e.target.closest('[data-tgo]');
    if (go) {
        const z = (D.territories || []).find((x) => x.id === Number(go.dataset.tgo));
        if (z) { const c = zoneCenter(z); post('zoneGps', { x: c.x, y: c.y, name: z.name }); }
        return;
    }
    const r = e.target.closest('[data-tzone]');
    if (r) return selectZone(Number(r.dataset.tzone), true);
    const t = e.target.closest('[data-tmap]');
    if (!t || !TMap.inst) return;
    if (t.dataset.tmap === 'in') TMap.inst.zoom(1.3);
    else if (t.dataset.tmap === 'out') TMap.inst.zoom(0.77);
    else if (t.dataset.tmap === 'fit') TMap.inst.fit();
    else if (t.dataset.tmap === 'refresh') post('refresh');
});

/* ---------- Informations ---------- */
VIEWS.home = () => {
    const g = D.group;
    const myPerms = D.permissions.filter((p) => can(p.key));
    return `
        <div class="stats">
            <div class="stat"><b>${g.memberCount}</b><span>Membres</span></div>
            <div class="stat"><b>${D.members.filter((m) => m.online).length}</b><span>En ligne</span></div>
            <div class="stat"><b>${esc(g.typeLabel)}</b><span>Type</span></div>
            <div class="stat money"><b>${esc(g.og.join(', ') || '—')}</b><span>Chef(s)</span></div>
        </div>
        <div class="section"><h2>${esc(g.label)}</h2>
            <p class="hint">${esc(g.description || 'Aucune description.')}</p>
            <p class="muted">Créé le ${date(g.created)}</p>
            ${g.stash ? `<p class="muted" style="margin-top:6px">🗄️ Coffre du groupe : ${esc(g.stash.label)} · ${g.stash.weight} kg · ${g.stash.slots} places ·
                ${can('stash') ? '<span class="badge ok">Accès autorisé</span>' : '<span class="badge danger">Pas d\'accès avec ton grade</span>'}</p>` : ''}
        </div>
        <div class="section"><h2>Mon grade : ${esc(D.me.grade)}</h2>
            ${D.me.boss ? '<p class="hint">Grade chef : toutes les permissions.</p>' : ''}
            ${myPerms.length ? `<div class="chips">${myPerms.map((p) => `<span class="badge ok">✓ ${esc(p.label)}</span>`).join('')}</div>` : '<p class="muted">Aucune permission particulière.</p>'}
            <div class="btn-row"><button class="btn danger" data-a="leave">Quitter le groupe</button></div>
        </div>
        ${D.logs ? `<div class="section"><h2>Journal du groupe</h2>
            ${D.logs.length ? D.logs.slice(0, 15).map((l) => `<div class="log-row"><span class="muted">${date(l.created)}</span><span><b>${esc(l.action)}</b> · ${esc(l.details || l.actor)}</span></div>`).join('') : '<p class="muted">Rien pour le moment.</p>'}
        </div>` : ''}`;
};

/* ---------- Membres ---------- */
VIEWS.members = () => `
    ${can('recruit') ? '<div class="btn-row" style="margin:0 0 14px"><button class="btn primary" data-a="recruit">+ Ajouter un membre</button></div>' : ''}
    <div class="section">
        <table><tr><th>Nom</th><th>ID</th><th>Grade</th><th>Statut</th><th>Dernière connexion</th><th></th></tr>
        ${D.members.map((m) => `<tr>
            <td><strong>${esc(m.name)}</strong>${m.me ? ' <span class="badge gold">Moi</span>' : ''}</td>
            <td>${m.online ? m.id : '<span class="muted">—</span>'}</td>
            <td>${esc(m.grade)}${m.boss ? ' <span class="badge gold">Chef</span>' : ''}</td>
            <td>${m.online ? '<span class="badge ok">En ligne</span>' : '<span class="badge">Hors ligne</span>'}</td>
            <td class="muted">${m.online ? 'Maintenant' : date(m.lastSeen)}</td>
            <td class="right">
                <button class="btn" data-a="profile" data-cid="${esc(m.cid)}" title="Voir le profil">👁</button>
                ${!m.me && m.below && can('promote') ? `<button class="btn" data-a="promote" data-cid="${esc(m.cid)}" title="Promouvoir">↑</button>` : ''}
                ${!m.me && m.below && can('demote') ? `<button class="btn" data-a="demote" data-cid="${esc(m.cid)}" title="Rétrograder">↓</button>` : ''}
                ${!m.me && m.below && can('set_grade') ? `<button class="btn" data-a="setGrade" data-cid="${esc(m.cid)}">Grade</button>` : ''}
                ${!m.me && m.below && can('kick') ? `<button class="btn danger" data-a="kick" data-cid="${esc(m.cid)}">Expulser</button>` : ''}
            </td></tr>`).join('')}
        </table>
    </div>`;

/* ---------- Grades ---------- */
const permBadges = (gr) => (gr.boss ? '<span class="badge gold">Toutes</span>'
    : D.permissions.filter((p) => gr.perms[p.key]).map((p) => `<span class="badge">${esc(p.label)}</span>`).join(' ') || '<span class="muted">Aucune</span>');

VIEWS.grades = () => {
    const list = [...D.grades].reverse();
    return `
        ${can('manage_grades') ? `<div class="btn-row" style="margin:0 0 14px"><button class="btn primary" data-a="createGrade">+ Créer un grade</button>
            <span class="muted">Tu ne peux créer ou modifier que des grades inférieurs au tien (niveau ${D.me.level}).</span></div>` : ''}
        <div class="section"><table><tr><th>Niveau</th><th>Grade</th><th>Membres</th><th>Permissions</th><th></th></tr>
        ${list.map((gr, i) => `<tr>
            <td><span class="badge">${gr.level}</span></td>
            <td><strong>${esc(gr.label)}</strong> <span class="muted">${esc(gr.name)}</span>${gr.boss ? ' <span class="badge gold">Chef</span>' : ''}</td>
            <td>${gr.members}</td>
            <td style="max-width:420px">${permBadges(gr)}</td>
            <td class="right">${can('manage_grades') && gr.editable ? `
                <button class="btn" data-a="moveGrade" data-id="${gr.id}" data-dir="1" ${i === 0 || !list[i - 1].editable ? 'disabled' : ''} title="Monter">↑</button>
                <button class="btn" data-a="moveGrade" data-id="${gr.id}" data-dir="-1" ${i === list.length - 1 ? 'disabled' : ''} title="Descendre">↓</button>
                <button class="btn" data-a="editGrade" data-id="${gr.id}">Modifier</button>
                <button class="btn danger" data-a="deleteGrade" data-id="${gr.id}">✕</button>` : ''}</td></tr>`).join('')}
        </table></div>`;
};

/* ---------- Finances ---------- */
function accountBlock(acc) {
    const dep = can(`${acc}_deposit`), wit = can(`${acc}_withdraw`), f = D.finance;
    if (!dep && !wit && !f) return '';
    return `<div class="section"><h2>${ACCOUNTS[acc]}</h2>
        ${f ? `<div class="stat money ${acc}" style="margin-bottom:12px"><b>${money(f[acc])}</b><span>Solde</span></div>` : '<p class="hint">Ton grade ne permet pas de voir le solde.</p>'}
        <div class="btn-row">${dep ? `<button class="btn ok" data-a="deposit" data-acc="${acc}">Déposer</button>` : ''}
            ${wit ? `<button class="btn" data-a="withdraw" data-acc="${acc}">Retirer</button>` : ''}</div></div>`;
}

VIEWS.finances = () => {
    const f = D.finance;
    const hist = f ? [...f.history, ...olderHistory] : [];
    return `<div class="grid2">${accountBlock('clean')}${accountBlock('dirty')}</div>
        ${f ? `<div class="section"><h2>Historique financier</h2>
            ${hist.length ? `<table><tr><th>Date</th><th>Joueur</th><th>Type</th><th>Compte</th><th>Montant</th><th>Solde avant → après</th></tr>
            ${hist.map((t) => `<tr><td class="muted">${date(t.created)}</td><td>${esc(t.actor)}</td><td>${TX[t.type] || esc(t.type)}${t.reason ? `<br><span class="muted">${esc(t.reason)}</span>` : ''}</td>
                <td>${ACCOUNTS[t.account] || ''}</td><td>${signed(t.amount)}</td><td class="muted">${money(t.before)} → ${money(t.after)}</td></tr>`).join('')}
            </table>${historyEnd || hist.length < 50 ? '' : '<div class="btn-row"><button class="btn" data-a="moreHistory">Plus ancien…</button></div>'}`
            : '<div class="empty">Aucune transaction.</div>'}</div>` : ''}`;
};

/* ---------- Commandes ---------- */
const catOf = (k) => D.categories.find((c) => c.key === k) || { label: k, ico: '📦' };

VIEWS.orders = () => {
    const orders = D.orders.filter((o) => orderCat === 'all' || o.category === orderCat);
    const reqs = D.requests;
    return `
        <div class="chips"><span class="chip ${orderCat === 'all' ? 'on' : ''}" data-cat="all">Tout</span>
            ${D.categories.map((c) => `<span class="chip ${orderCat === c.key ? 'on' : ''}" data-cat="${c.key}">${c.ico} ${esc(c.label)}</span>`).join('')}
            <span style="flex:1"></span>${D.config.canCreateOrders && can('orders_manage') ? '<button class="btn primary" data-a="createOrder">+ Créer une commande</button>' : ''}</div>
        <p class="hint">${D.config.requireValidation ? 'Une commande doit être validée par un grade autorisé, puis' : 'Une commande est'} payée par le coffre du groupe.
            Elle est prête ${D.config.prepareMinutes} minutes plus tard : un point GPS s'ajoute sur ta carte, va chercher le sac devant le chef.</p>
        ${orders.length ? `<div class="cards">${orders.map((o) => `<div class="card">
            <div class="muted">${catOf(o.category).ico} ${esc(catOf(o.category).label)}${o.global ? ' · <span class="badge">Tous groupes</span>' : ''}${o.available ? '' : ' · <span class="badge danger">Indisponible</span>'}</div>
            <div class="t">${esc(o.name)}</div>
            <div class="muted">${esc(o.description || '')}</div>
            <div class="price">${money(o.price)}</div>
            <div class="muted">Payée en : ${PAYMENTS[o.payment]}${o.hasItem ? ' · livrée en objet' : ''}</div>
            <div class="btn-row">${can('orders_place') && o.available ? `<button class="btn primary" data-a="placeOrder" data-id="${o.id}">Commander</button>` : ''}
                ${o.editable ? `<button class="btn" data-a="editOrder" data-id="${o.id}">Modifier</button><button class="btn danger" data-a="deleteOrder" data-id="${o.id}">✕</button>` : ''}</div>
        </div>`).join('')}</div>` : '<div class="section"><div class="empty">Aucune commande disponible.</div></div>'}
        <div class="section" style="margin-top:14px"><h2>${can('orders_validate') ? 'Commandes du groupe' : 'Mes commandes'}</h2>
            ${reqs.length ? `<table><tr><th>Date</th><th>Commande</th><th>Par</th><th>Total</th><th>Statut</th><th></th></tr>
            ${reqs.map((r) => `<tr><td class="muted">${date(r.created)}</td><td>${r.quantity}x ${esc(r.orderName)}</td><td>${esc(r.requester)}</td>
                <td>${money(r.total)}<br><span class="muted">${ACCOUNTS[r.account]}</span></td>
                <td><span class="badge ${(STATUS[r.status] || [])[1] || ''}">${(STATUS[r.status] || [r.status])[0]}</span>${r.status === 'preparing' && r.readyAt ? `<br><span class="muted">Prête vers ${hhmm(r.readyAt)}</span>` : ''}${r.handledBy ? `<br><span class="muted">${esc(r.handledBy)}</span>` : ''}</td>
                <td class="right">
                    ${r.status === 'pending' && can('orders_validate') ? `<button class="btn ok" data-a="validateRequest" data-id="${r.id}">Valider</button><button class="btn danger" data-a="refuseRequest" data-id="${r.id}">Refuser</button>` : ''}
                    ${r.status === 'pending' && r.mine ? `<button class="btn" data-a="cancelRequest" data-id="${r.id}">Annuler</button>` : ''}
                    ${r.status === 'ready' && r.mine ? `<button class="btn primary" data-a="gps" data-id="${r.id}">📍 GPS</button>` : ''}
                </td></tr>`).join('')}</table>` : '<div class="empty">Aucune commande.</div>'}
        </div>`;
};

/* ---------- Missions ---------- */
const clock = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const dur = (s) => (s >= 3600 ? `${Math.floor(s / 3600)} h ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}` : `${Math.ceil(s / 60)} min`);
VIEWS.missions = () => {
    const m = D.missions, p = m.progress;
    const pct = p.need ? Math.min(100, Math.round((p.xp / p.need) * 100)) : 100;
    const a = m.active;
    return `
        <div class="stats">
            <div class="stat"><b>${p.level}</b><span>Niveau · ${esc(p.label)}</span></div>
            <div class="stat money"><b>${p.need ? `${p.xp} / ${p.need}` : `${p.xp} · MAX`}</b><span>XP ${p.nextLabel ? `vers « ${esc(p.nextLabel)} »` : '(niveau maximum)'}</span>
                <div class="mbar"><i style="width:${pct}%"></i></div></div>
        </div>
        ${a ? `<div class="section"><h2>Mission en cours : ${esc(a.label)}</h2>
            <p class="hint">${esc(a.stage)} · temps restant <b>${clock(a.remaining)}</b> · participants : ${esc(a.participants.join(', '))}</p>
            <div class="btn-row">${a.mine ? '' : '<button class="btn primary" data-a="joinMission">Rejoindre</button>'}
                ${a.starter || m.boss ? '<button class="btn danger" data-a="abandonMission">Abandonner</button>' : ''}</div></div>` : ''}
        <div class="section"><h2>Missions</h2>
            ${m.list.length ? `<div class="cards">${m.list.map((x) => {
                const need = x.levelRequired > p.level;
                const missing = need && p.need ? Math.max(0, p.need - p.xp) : 0;
                return `<div class="card mcard ${x.locked ? 'locked' : ''}">
                    <div class="t">${x.locked ? '🔒' : '🟢'} ${esc(x.label)}</div>
                    <div class="muted">${esc(x.description || '')}</div>
                    <div>Niveau requis : <b>${x.levelRequired}</b> · XP : <b>+${x.xp}</b></div>
                    <div class="muted">${x.minPlayers}-${x.maxPlayers} joueur(s) · ${x.minutes} min${x.money ? ` · ${money(x.money.min)} à ${money(x.money.max)} au coffre` : ''}${x.items ? ` · ${x.items} objet(s)` : ''}</div>
                    ${x.locked ? `<div class="lock">MISSION VERROUILLÉE</div>
                        <div class="muted">Niveau requis : ${x.levelRequired} · Votre niveau : ${p.level}${p.need ? `<br>XP : ${p.xp} / ${p.need}${x.levelRequired === p.level + 1 ? ` · ${missing} XP nécessaires` : ''}` : ''}</div>`
                        : x.cooldown > 0 ? `<div class="muted">⏳ Disponible dans ${dur(x.cooldown)}</div>`
                        : m.canStart && !a ? `<div class="btn-row"><button class="btn primary" data-a="startMission" data-mid="${esc(x.id)}">Lancer la mission</button></div>`
                        : `<div class="muted">${a ? 'Une mission est déjà en cours.' : 'Ton grade ne permet pas de lancer une mission.'}</div>`}
                </div>`;
            }).join('')}</div>` : '<div class="empty">Aucune mission disponible pour ton groupe.</div>'}
            <p class="hint" style="margin-top:12px">Les membres du groupe à proximité de celui qui lance la mission y participent. Les récompenses vont dans le coffre du groupe, une seule fois.</p>
        </div>`;
};

/* ---------- Paramètres ---------- */
VIEWS.settings = () => `
    <div class="section"><h2>Paramètres du groupe</h2>
        <div class="grid2">
            <div class="field"><label>Nom affiché</label><input class="input" id="set-label" maxlength="64" value="${esc(D.group.label)}"></div>
            <div class="field"><label>Couleur</label><input class="input" id="set-color" type="color" value="${esc(D.group.color)}" style="height:38px;padding:3px"></div>
        </div>
        <div class="field"><label>Description</label><textarea class="input" id="set-desc" maxlength="500">${esc(D.group.description)}</textarea></div>
        <p class="hint">Le nom interne (${esc(D.group.name)}) et le type (${esc(D.group.typeLabel)}) ne se changent que par le staff.</p>
        <div class="btn-row"><button class="btn primary" data-a="saveSettings">Enregistrer</button></div>
    </div>`;

/* =========================================================
   MODALES
   ========================================================= */
let modalResolve = null;
function closeModal(value = null) {
    $('#modal-root').innerHTML = '';
    if (modalResolve) { const r = modalResolve; modalResolve = null; r(value); }
    if (value === null && D && !$('#app').classList.contains('hidden')) render();
}

// fields : { name, label, type: text|number|select|textarea|perms|info, value, options, max }
function formModal(title, fields, okLabel = 'Valider', danger = false) {
    const html = fields.map((f) => {
        if (f.type === 'info') return `<p class="hint">${f.html || esc(f.value)}</p>`;
        let input;
        if (f.type === 'select') input = `<select class="input" name="${f.name}">${f.options.map((o) => `<option value="${esc(o.value)}" ${String(o.value) === String(f.value) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
        else if (f.type === 'textarea') input = `<textarea class="input" name="${f.name}" maxlength="${f.max || 500}">${esc(f.value || '')}</textarea>`;
        else if (f.type === 'perms') {
            // Même présentation que l'onglet Grades du MenuStaff
            const cats = [...new Set(D.permissions.map((p) => p.cat))];
            input = cats.map((c) => `<div class="perm-cat"><h3>${esc(c)}</h3><div class="perm-grid">${D.permissions.filter((p) => p.cat === c).map((p) => {
                const allowed = D.me.boss || can(p.key);
                return `<label class="perm ${allowed ? '' : 'locked'}" title="${allowed ? '' : 'Tu ne peux pas donner une permission que tu n\'as pas'}">
                    <input type="checkbox" data-perm="${p.key}" ${f.value && f.value[p.key] ? 'checked' : ''} ${allowed ? '' : 'disabled'}>${esc(p.label)}</label>`;
            }).join('')}</div></div>`).join('');
        } else input = `<input class="input" name="${f.name}" type="${f.type === 'number' ? 'number' : 'text'}" value="${esc(f.value ?? '')}" ${f.max ? `maxlength="${f.max}"` : ''} placeholder="${esc(f.placeholder || '')}">`;
        return `<div class="field"><label>${esc(f.label || '')}</label>${input}</div>`;
    }).join('');
    const wide = fields.some((f) => f.type === 'perms');
    $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal" ${wide ? 'style="width:660px"' : ''}><h2>${esc(title)}</h2>${html}
        <div class="btn-row"><button class="btn" data-m="cancel">Annuler</button><button class="btn ${danger ? 'danger' : 'primary'}" data-m="ok">${esc(okLabel)}</button></div></div></div>`;
    const first = $('#modal-root .input');
    if (first) first.focus();
    return new Promise((resolve) => {
        modalResolve = resolve;
        $('#modal-root').onclick = (e) => {
            if (e.target.classList.contains('modal-backdrop') || e.target.dataset.m === 'cancel') return closeModal(null);
            if (e.target.dataset.m === 'ok') {
                const v = {};
                $('#modal-root').querySelectorAll('[name]').forEach((i) => { v[i.name] = i.value; });
                const perms = {};
                $('#modal-root').querySelectorAll('[data-perm]').forEach((i) => { if (i.checked) perms[i.dataset.perm] = true; });
                v.perms = perms;
                modalResolve = null;
                $('#modal-root').innerHTML = '';
                resolve(v);
            }
        };
    });
}
const confirmBox = (title, text) => formModal(title, [{ type: 'info', value: text }], 'Confirmer', true);

function toast(msg, type = 'info') {
    const t = document.createElement('div');
    t.className = `toast ${type}`;
    t.textContent = msg;
    $('#toasts').appendChild(t);
    setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, 4500);
}

const gradeOptions = (onlyBelow) => [...D.grades].reverse().filter((g) => !onlyBelow || g.level < D.me.level).map((g) => ({ value: g.id, label: `${g.label} (niveau ${g.level})` }));
const member = (cid) => D.members.find((m) => m.cid === cid);
const grade = (id) => D.grades.find((g) => g.id === Number(id));
const order = (id) => D.orders.find((o) => o.id === Number(id));

function orderFields(o) {
    return [
        { name: 'name', label: 'Nom', value: o ? o.name : '', max: 64 },
        { name: 'description', label: 'Description', type: 'textarea', value: o ? o.description : '' },
        { name: 'category', label: 'Type', type: 'select', value: o ? o.category : 'other', options: D.categories.map((c) => ({ value: c.key, label: `${c.ico} ${c.label}` })) },
        { name: 'price', label: 'Prix (unité)', type: 'number', value: o ? o.price : 0 },
        { name: 'payment', label: 'Payée avec', type: 'select', value: o ? o.payment : 'dirty', options: Object.entries(PAYMENTS).map(([value, label]) => ({ value, label })) },
        { name: 'available', label: 'Disponibilité', type: 'select', value: o ? String(o.available) : 'true', options: [{ value: 'true', label: 'Disponible' }, { value: 'false', label: 'Indisponible' }] },
    ];
}
const orderPayload = (v) => ({ name: v.name, description: v.description, category: v.category, price: Number(v.price), payment: v.payment, available: v.available === 'true' });

/* =========================================================
   ACTIONS
   ========================================================= */
document.addEventListener('click', async (e) => {
    const chip = e.target.closest('[data-cat]');
    if (chip) { orderCat = chip.dataset.cat; return render(); }
    const b = e.target.closest('[data-a]');
    if (!b || b.disabled || !D) return;
    const a = b.dataset.a, cid = b.dataset.cid, id = Number(b.dataset.id);
    let v;
    switch (a) {
        case 'leave':
            if (await confirmBox(`Quitter ${D.group.label} ?`, 'Tu perdras ton grade et l\'accès à la tablette du groupe.')) action('leave');
            return;
        case 'recruit':
            v = await formModal('Ajouter un membre', [
                { name: 'target', label: 'ID du joueur (connecté)', type: 'number', placeholder: 'ex : 25' },
                { name: 'gradeId', label: 'Grade', type: 'select', options: gradeOptions(true) },
            ], 'Recruter');
            if (v) action('recruit', { target: Number(v.target), gradeId: Number(v.gradeId) });
            return;
        case 'profile': {
            const m = member(cid);
            if (m) formModal(m.name, [{ type: 'info', html: `Grade : <b>${esc(m.grade)}</b><br>Statut : ${m.online ? `en ligne (ID ${m.id})` : 'hors ligne'}<br>
                Dernière connexion : ${m.online ? 'maintenant' : date(m.lastSeen)}<br>Membre depuis : ${date(m.joined)}<br>Identifiant : ${esc(m.cid)}` }], 'Fermer');
            return;
        }
        case 'promote': return action('promote', { cid });
        case 'demote': return action('demote', { cid });
        case 'setGrade': {
            const m = member(cid);
            v = await formModal(`Grade de ${m.name}`, [{ name: 'gradeId', label: 'Nouveau grade', type: 'select', value: m.gradeId, options: gradeOptions(true) }], 'Changer');
            if (v) action('setGrade', { cid, gradeId: Number(v.gradeId) });
            return;
        }
        case 'kick': {
            const m = member(cid);
            if (await confirmBox(`Expulser ${m.name} ?`, `Il ne fera plus partie de ${D.group.label}.`)) action('kick', { cid });
            return;
        }
        case 'createGrade':
        case 'editGrade': {
            const gr = a === 'editGrade' ? grade(id) : null;
            v = await formModal(gr ? `Modifier ${gr.label}` : 'Créer un grade', [
                { name: 'name', label: 'Nom (identifiant)', value: gr ? gr.name : '', placeholder: 'lieutenant', max: 32 },
                { name: 'label', label: 'Label', value: gr ? gr.label : '', placeholder: 'Lieutenant', max: 64 },
                { name: 'level', label: `Niveau / priorité (inférieur à ${D.me.level})`, type: 'number', value: gr ? gr.level : '' },
                { name: 'perms', label: 'Permissions', type: 'perms', value: gr ? gr.perms : {} },
            ], gr ? 'Enregistrer' : 'Créer');
            if (v) action(gr ? 'updateGrade' : 'createGrade', { id: gr ? gr.id : undefined, name: v.name, label: v.label, level: Number(v.level), perms: v.perms });
            return;
        }
        case 'deleteGrade': {
            const gr = grade(id);
            if (await confirmBox(`Supprimer le grade ${gr.label} ?`, `Ses ${gr.members} membre(s) passeront au grade juste en dessous.`)) action('deleteGrade', { id });
            return;
        }
        case 'moveGrade': return action('moveGrade', { id, dir: Number(b.dataset.dir) });
        case 'deposit':
        case 'withdraw': {
            const acc = b.dataset.acc;
            v = await formModal(`${a === 'deposit' ? 'Déposer' : 'Retirer'} : ${ACCOUNTS[acc].toLowerCase()}`, [{ name: 'amount', label: 'Montant', type: 'number', placeholder: '50000' }],
                a === 'deposit' ? 'Déposer' : 'Retirer');
            const n = v && Math.floor(Number(v.amount));
            if (v && (!n || n <= 0)) return toast('Montant invalide.', 'error');
            if (v) action(a, { account: acc, amount: n });
            return;
        }
        case 'moreHistory': {
            const all = [...D.finance.history, ...olderHistory];
            const last = all[all.length - 1];
            const more = await post('history', { before: last ? last.id : 0 });
            if (!Array.isArray(more) || more.length === 0) historyEnd = true;
            else olderHistory = olderHistory.concat(more);
            return render();
        }
        case 'placeOrder': {
            const o = order(id);
            const fields = [{ name: 'quantity', label: `Quantité (1 à ${D.config.maxQuantity})`, type: 'number', value: 1 }];
            if (o.payment === 'both') fields.push({ name: 'account', label: 'Payer avec', type: 'select', value: 'dirty', options: [{ value: 'clean', label: 'Argent propre' }, { value: 'dirty', label: 'Argent sale' }] });
            fields.unshift({ type: 'info', html: `<b>${esc(o.name)}</b> · ${money(o.price)} l'unité. Payée par le coffre du groupe${D.config.requireValidation ? ' à la validation' : ''}, prête ${D.config.prepareMinutes} minutes plus tard.` });
            v = await formModal('Passer commande', fields, 'Commander');
            if (v) action('placeOrder', { id, quantity: Number(v.quantity), account: v.account || o.payment });
            return;
        }
        case 'createOrder':
            v = await formModal('Créer une commande', orderFields(null), 'Créer');
            if (v) action('createOrder', orderPayload(v));
            return;
        case 'editOrder': {
            const o = order(id);
            v = await formModal(`Modifier ${o.name}`, orderFields(o), 'Enregistrer');
            if (v) action('updateOrder', { id, ...orderPayload(v) });
            return;
        }
        case 'deleteOrder': {
            const o = order(id);
            if (await confirmBox(`Supprimer « ${o.name} » ?`, 'La commande ne sera plus proposée.')) action('deleteOrder', { id });
            return;
        }
        case 'validateRequest':
            if (await confirmBox('Valider la commande ?', 'Le montant sera retiré du coffre du groupe.')) action('validateRequest', { id });
            return;
        case 'refuseRequest': return action('refuseRequest', { id });
        case 'cancelRequest': return action('cancelRequest', { id });
        case 'gps': return post('gps', { id });
        case 'startMission': {
            const x = D.missions.list.find((y) => y.id === b.dataset.mid);
            if (x && await confirmBox(`Lancer « ${x.label} » ?`, `Durée : ${x.minutes} minutes. Les membres du groupe proches de toi participent avec toi.`))
                action('startMission', { id: x.id });
            return;
        }
        case 'joinMission': return action('joinMission');
        case 'abandonMission':
            if (await confirmBox('Abandonner la mission ?', 'La mission échoue : aucune récompense, et le cooldown s\'applique.')) action('abandonMission');
            return;
        case 'saveSettings':
            return action('saveSettings', { label: $('#set-label').value, color: $('#set-color').value, description: $('#set-desc').value });
    }
});
