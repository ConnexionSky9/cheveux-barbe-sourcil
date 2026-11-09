/* =========================================================
   ÉDITEUR DE MAP › 🌀 TÉLÉPORTEURS
   · A → B : un départ, une arrivée (retour B → A possible).
   · Destinations multiples : un départ, le joueur choisit dans la liste.
   Coordonnées précises (x, y, z, cap) ou « Ma position ». Sauvegardé côté serveur.
   + Fenêtre de choix de destination côté joueur (#tpchoose).
   ========================================================= */
let tpEdit = null;   // téléporteur en cours de modification (null = création)

const tpPoint = (name = '') => ({ name, x: '', y: '', z: '', h: 0 });
function newTpDraft() {
    return { name: '', mode: 'ab', from: tpPoint('Départ'), dests: [tpPoint('Arrivée')], radius: 1.5, twoWay: true, vehicle: false, marker: true };
}
const tpDraft = () => tpEdit || (drafts.tp = drafts.tp || newTpDraft());
const tpNum = (v, d = 2) => (v === '' || v === undefined || v === null || isNaN(Number(v)) ? '' : Number(v).toFixed(d));

function tpTile(on, act, label, sub) {
    return `<div class="tile toggle-tile ${on ? 'on' : ''}" data-tpx="${act}"><div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
}

// Ligne de coordonnées : nom, x, y, z, cap, « Ma position »
function tpCoordRow(path, p, opts = {}) {
    return `<div class="tp-pt">
        <div class="tp-pt-head">
            ${opts.badge ? `<span class="tp-badge ${opts.badgeClass || ''}">${opts.badge}</span>` : ''}
            <input class="input tp-name" data-tpf="${path}.name" value="${esc(p.name)}" placeholder="${esc(opts.placeholder || 'Nom affiché')}" maxlength="40">
            <button class="btn" data-tpx="mypos" data-path="${path}" title="Remplir avec ta position et ton orientation actuelles">📍 Ma position</button>
            ${opts.remove ? `<button class="btn danger" data-tpx="rm_dest" data-i="${opts.remove - 1}" title="Retirer cette destination">✕</button>` : ''}
        </div>
        <div class="tp-xyz">
            ${['x', 'y', 'z'].map((k) => `<label><span>${k.toUpperCase()}</span><input class="input" type="number" step="0.01" data-tpf="${path}.${k}" value="${tpNum(p[k])}"></label>`).join('')}
            <label><span>CAP</span><input class="input" type="number" step="0.1" min="0" max="360" data-tpf="${path}.h" value="${tpNum(p.h, 1)}"></label>
        </div></div>`;
}

function tpForm(t) {
    const multi = t.mode === 'multi';
    return `<div class="form-grid" style="grid-template-columns:1.4fr 1fr;max-width:720px;align-items:end">
            <div><label>Nom du téléporteur</label><input class="input" data-tpf="name" value="${esc(t.name)}" placeholder="ex : Ascenseur Maze Bank" maxlength="40"></div>
            <div><label>Taille de la zone de départ · <b id="tpRadVal">${Number(t.radius).toFixed(1)} m</b></label>
                <input class="input" type="range" style="padding:0" min="0.8" max="5" step="0.1" data-tpf="radius" value="${t.radius}"
                    oninput="document.getElementById('tpRadVal').textContent = Number(this.value).toFixed(1) + ' m'"></div>
        </div>
        <div class="segmented" style="margin-bottom:14px">
            <button class="seg ${!multi ? 'active' : ''}" data-tpx="mode" data-mode="ab">↔️ A → B</button>
            <button class="seg ${multi ? 'active' : ''}" data-tpx="mode" data-mode="multi">🔀 Destinations multiples</button>
        </div>
        <h3 class="sub-h" style="font-size:16px">Point de départ</h3>
        ${tpCoordRow('from', t.from, { badge: 'A', placeholder: 'Nom du départ (affiché pour le retour)' })}
        <h3 class="sub-h" style="font-size:16px;margin-top:14px">${multi ? `Destinations (${t.dests.length})` : 'Point d\'arrivée'}</h3>
        ${multi
            ? t.dests.map((q, i) => tpCoordRow(`dests.${i}`, q, { badge: String(i + 1), badgeClass: 'b', placeholder: 'Nom de la destination (vu par le joueur)', remove: t.dests.length > 1 ? i + 1 : 0 })).join('')
                + (t.dests.length < 20 ? '<button class="btn" data-tpx="add_dest" style="margin-top:4px">➕ Ajouter une destination</button>' : '')
            : tpCoordRow('dests.0', t.dests[0], { badge: 'B', badgeClass: 'b', placeholder: 'Nom de l\'arrivée' })}
        <h3 class="sub-h" style="font-size:16px;margin-top:16px">Options</h3>
        <div class="grid" style="grid-template-columns:repeat(${multi ? 2 : 3}, 1fr);margin-bottom:14px">
            ${!multi ? tpTile(t.twoWay, 'tog_twoWay', 'Retour B → A', 'E à l\'arrivée ramène au départ') : ''}
            ${tpTile(t.vehicle, 'tog_vehicle', 'Véhicules', 'Le conducteur passe avec son véhicule')}
            ${tpTile(t.marker, 'tog_marker', 'Repère au sol', 'Cercle violet visible à l\'approche')}
        </div>`;
}

function tpDestText(r) {
    if (r.mode !== 'multi') return `A <b>${esc(r.from.name)}</b> → B <b>${esc((r.dests[0] || {}).name || '')}</b>${r.twoWay ? ' <span class="muted">(aller-retour)</span>' : ''}`;
    return `<b>${esc(r.from.name)}</b> → ${r.dests.map((q) => `<span class="zbadge">${esc(q.name)}</span>`).join(' ')}`;
}

function edTeleports() {
    const list = (D.editor.teleports || []);
    if (tpEdit) {
        return `<div class="btn-row" style="margin-bottom:16px">
                <button class="btn" data-tpx="back">← Retour aux téléporteurs</button>
                <button class="btn primary" data-tpx="save">Enregistrer</button></div>
            <h2 class="sub-h">${esc(tpEdit.name || 'Téléporteur')} <span class="muted" style="font-size:14px">#${tpEdit.id}</span></h2>
            <div class="section">${tpForm(tpEdit)}<button class="btn primary big" data-tpx="save">Enregistrer</button></div>`;
    }
    return `<div class="section"><h2>Créer un téléporteur</h2>
        <p class="hint">Le joueur appuie sur <span class="keycap">E</span> dans la zone de départ.
            <b>A → B</b> : il arrive directement au point B. <b>Destinations multiples</b> : il choisit sa destination dans une liste.
            Remplis les coordonnées à la main ou va sur place et clique <b>📍 Ma position</b> (l'orientation est reprise).</p>
        ${tpForm(tpDraft())}
        <button class="btn primary big" data-tpx="create">🌀 Créer le téléporteur</button></div>
        <div class="section"><h2>Téléporteurs enregistrés (${list.length})</h2>
        ${!list.length ? '<div class="empty">Aucun téléporteur pour le moment.</div>' : [...list].sort(byDist).slice(0, 100).map((r) => `
            <div class="card">
                <div class="card-head"><strong>🌀 ${esc(r.name)}</strong><span class="muted">${r.mode === 'multi' ? `${r.dests.length} destinations` : 'A → B'} · ${distTxt(r.dist)}</span></div>
                <div class="recipe-preview">${tpDestText(r)}<br><span class="muted">Zone ${Number(r.radius || 1.5).toFixed(1)} m${r.vehicle ? ' · véhicules autorisés' : ''}${r.marker ? '' : ' · sans repère'}</span></div>
                <div class="btn-row">
                    <button class="btn primary" data-tpx="edit" data-id="${r.id}">Modifier</button>
                    <button class="btn" data-ed="tp" data-kind="teleport" data-id="${r.id}">Aller au départ</button>
                    ${r.mode !== 'multi' ? `<button class="btn" data-ed="tp" data-kind="teleport_dest" data-id="${r.id}">Aller à l'arrivée</button>` : ''}
                    <button class="btn danger" data-ed="delete" data-kind="teleport" data-id="${r.id}">Supprimer</button>
                </div>
            </div>`).join('')}</div>`;
}

function tpPayload(t) {
    const pt = (p) => ({ name: String(p.name || '').trim(), x: Number(p.x), y: Number(p.y), z: Number(p.z), h: Number(p.h) || 0 });
    const dests = (t.mode === 'multi' ? t.dests : t.dests.slice(0, 1)).map(pt);
    return { id: t.id, name: String(t.name || '').trim(), mode: t.mode, from: pt(t.from), dests, radius: Number(t.radius) || 1.5,
        twoWay: t.mode === 'ab' && !!t.twoWay, vehicle: !!t.vehicle, marker: !!t.marker };
}
function tpValid(pl) {
    const ok = (p) => p.x !== '' && [p.x, p.y, p.z].every((v) => Number.isFinite(v)) && !(p.x === 0 && p.y === 0 && p.z === 0);
    if (!pl.name) return toast('Donne un nom au téléporteur.', 'error'), false;
    if (!ok(pl.from)) return toast('Indique les coordonnées du départ (ou 📍 Ma position).', 'error'), false;
    for (let i = 0; i < pl.dests.length; i++) {
        if (!ok(pl.dests[i])) return toast(pl.mode === 'multi' ? `Coordonnées de la destination ${i + 1} manquantes.` : 'Indique les coordonnées de l\'arrivée.', 'error'), false;
        if (pl.mode === 'multi' && !pl.dests[i].name) return toast(`Donne un nom à la destination ${i + 1} : le joueur la choisira avec.`, 'error'), false;
    }
    return true;
}
// Chemin « dests.2.x » → objet du brouillon
function tpSet(t, path, v) {
    const k = path.split('.');
    let o = t;
    for (let i = 0; i < k.length - 1; i++) o = o[k[i]];
    if (o) o[k[k.length - 1]] = v;
}
function tpGet(t, path) { return path.split('.').reduce((o, k) => (o ? o[k] : undefined), t); }

document.addEventListener('click', async (ev) => {
    if (!isOpen || tab !== 'editor' || editorSub !== 'teleports') return;
    const n = ev.target.closest('[data-tpx]');
    if (!n) return;
    const t = tpDraft(), k = n.dataset.tpx;
    switch (k) {
        case 'mode':
            t.mode = n.dataset.mode;
            if (!t.dests.length) t.dests.push(tpPoint(t.mode === 'multi' ? 'Destination 1' : 'Arrivée'));
            return render();
        case 'tog_twoWay': t.twoWay = !t.twoWay; return render();
        case 'tog_vehicle': t.vehicle = !t.vehicle; return render();
        case 'tog_marker': t.marker = !t.marker; return render();
        case 'add_dest': if (t.dests.length < 20) t.dests.push(tpPoint(`Destination ${t.dests.length + 1}`)); return render();
        case 'rm_dest': t.dests.splice(Number(n.dataset.i), 1); if (!t.dests.length) t.dests.push(tpPoint('Destination 1')); return render();
        case 'mypos': {
            const res = await selfAction('coords');
            const m = String(res.coords || '').match(/-?\d+(?:\.\d+)?/g);
            if (!m || m.length < 4) return toast('Position indisponible.', 'error');
            const p = tpGet(t, n.dataset.path);
            if (!p) return;
            p.x = Number(m[m.length - 4]); p.y = Number(m[m.length - 3]); p.z = Number(m[m.length - 2]); p.h = Number(m[m.length - 1]);
            toast('Position reprise.', 'success');
            return render();
        }
        case 'create': {
            const pl = tpPayload(t);
            if (!tpValid(pl)) return;
            delete pl.id;
            action('editor_tp_save', pl);
            return;   // brouillon vidé à la confirmation du serveur (tpSaved)
        }
        case 'edit': {
            const r = (D.editor.teleports || []).find((x) => x.id === Number(n.dataset.id));
            if (!r) return;
            tpEdit = { id: r.id, name: r.name, mode: r.mode, from: clone(r.from), dests: clone(r.dests), radius: r.radius || 1.5,
                twoWay: !!r.twoWay, vehicle: !!r.vehicle, marker: r.marker !== false };
            document.querySelector('#content').scrollTop = 0;
            return render();
        }
        case 'back': tpEdit = null; return render();
        case 'save': {
            const pl = tpPayload(tpEdit);
            if (!tpValid(pl)) return;
            action('editor_tp_save', pl);
            return;
        }
    }
});
function tpInput(ev) {
    if (!isOpen || tab !== 'editor' || editorSub !== 'teleports') return;
    const f = ev.target.dataset && ev.target.dataset.tpf;
    if (f) tpSet(tpDraft(), f, ev.target.value);
}
document.addEventListener('input', tpInput);
document.addEventListener('change', tpInput);

/* ---------- Côté joueur : choix de la destination ---------- */
let TPC = null;
function closeTpChoose(notify = true) {
    $('#tpchoose').classList.add('hidden');
    TPC = null;
    if (notify) post('tpchoose_close');
}
function openTpChoose(d) {
    TPC = d;
    $('#tpchoose').innerHTML = `<div class="st-box tp-box">
        <div class="st-head"><img src="logo.png" alt=""><h2>${esc(d.name)}</h2><button class="sb-close" data-tpc="close">✕</button></div>
        <div class="st-list">${d.dests.map((q, i) => `<button class="tp-dest" data-tpc="pick" data-idx="${q.i}" style="animation-delay:${Math.min(i, 12) * 35}ms">
            <span class="tp-num">${i + 1}</span><strong>${esc(q.name)}</strong><span class="tp-go">➜</span></button>`).join('')}</div>
        <p class="muted st-foot">Échap pour fermer</p></div>`;
    $('#tpchoose').classList.remove('hidden');
}
$('#tpchoose').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tpc]');
    if (!b || !TPC) return;
    if (b.dataset.tpc === 'close') return closeTpChoose();
    const id = TPC.id;
    closeTpChoose(false);
    post('tpchoose_pick', { id, idx: Number(b.dataset.idx) });
});
document.addEventListener('keydown', (e) => {
    if (!TPC) return;
    if (e.key === 'Escape') return closeTpChoose();
    if (/^[1-9]$/.test(e.key)) {
        const q = TPC.dests[Number(e.key) - 1];
        if (q) { const id = TPC.id; closeTpChoose(false); post('tpchoose_pick', { id, idx: q.i }); }
    }
});
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'tpchoose') openTpChoose(m.data);
    else if (m.action === 'tpchoose_hide') closeTpChoose(false);
    else if (m.action === 'tpSaved') {
        tpEdit = null; drafts.tp = null;
        if (isOpen && tab === 'editor' && editorSub === 'teleports') { post('refresh'); render(); }
    }
});
