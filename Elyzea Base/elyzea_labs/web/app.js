/* =====================================================================
   ELYZEA LABS · interface : entrée (code), cercle bleu, fabrication, tablette, attaque
   ===================================================================== */
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Math.floor(Number(n) || 0).toLocaleString('fr-FR')} $`;
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_labs';
const post = (name, body = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    .then((r) => r.json()).catch(() => ({}));
const dur = (s) => { s = Math.max(0, Math.floor(s)); const m = Math.floor(s / 60); return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
const date = (t) => t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—';

let kind = null, data = null, state = {};
const panel = $('#panel');
const close = () => { panel.classList.add('hidden'); panel.innerHTML = ''; kind = null; post('close'); };
const head = (ico, title, sub) => `<div class="head"><div class="ico">${ico}</div><div><h1>${esc(title)}</h1>${sub ? `<small>${sub}</small>` : ''}</div><button class="x" data-close>✕</button></div>`;

/* ---------- Entrée ---------- */
function viewEntrance(d) {
    const s = state;
    if (s.code !== undefined) {
        const len = Math.max(4, s.code.length);
        return `<div class="card">${head('🔒', d.name, 'Saisis le code d\'accès')}
            <div class="body">${s.error ? `<div class="msg bad" style="margin-bottom:10px">${esc(s.error)}</div>` : ''}
            <div class="code">${Array.from({ length: Math.min(8, len) }, (_, i) => `<span>${s.code[i] ? '•' : ''}</span>`).join('')}</div>
            <div class="keys">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `<button data-key="${n}">${n}</button>`).join('')}
                <button data-key="del">⌫</button><button data-key="0">0</button><button data-key="ok" style="background:rgba(168,85,247,.25)">OK</button></div>
            <div class="row" style="margin-top:12px"><button class="btn block" data-back>Retour</button></div></div></div>`;
    }
    const btns = [];
    if (d.disabled) btns.push('<div class="msg">Ce laboratoire est fermé.</div>');
    else if (!d.owned) {
        btns.push(`<button class="btn primary block" data-act="buy" ${d.canBuy ? '' : 'disabled'}>Acheter pour ${money(d.price)} (compte du groupe)</button>`);
        if (d.buyHint) btns.push(`<p class="muted small">${esc(d.buyHint)}</p>`);
    } else {
        if (d.canEnter) btns.push('<button class="btn primary block" data-act="enter">Entrer</button>');
        else btns.push('<button class="btn primary block" data-act="code">Entrer avec le code</button>');
        if (!d.member) {
            btns.push(`<button class="btn danger block" data-act="raid" ${d.canRaid ? '' : 'disabled'}>⚔️ Lancer une attaque</button>`);
            if (d.raidHint) btns.push(`<p class="muted small">${esc(d.raidHint)}</p>`);
        }
    }
    return `<div class="card">${head('⚗️', d.name, d.owned ? `Propriétaire : ${esc(d.ownerLabel || '?')}` : 'Sans propriétaire')}
        <div class="body stack">${d.raid ? `<div class="msg bad">⚔️ Attaque ${d.raid.status === 'preparing' ? 'en préparation' : 'en cours'}</div>` : ''}${btns.join('')}</div></div>`;
}
async function entranceAct(act, code) {
    const r = await post('entranceAction', { lab: data.id, action: act, code });
    if (r && r.needCode) { state = { code: '', error: r.error }; render(); }
}

/* ---------- Cercle bleu : équipements ---------- */
function viewEditor(d) {
    const placed = d.owned.filter((o) => o.placed), stored = d.owned.filter((o) => !o.placed);
    const full = d.count >= d.max;
    return `<div class="card" style="width:560px">${head('🛠️', 'Équipements du laboratoire', `Niveau ${d.level} · ${d.count}/${d.max} équipements`)}
        <div class="body stack">
        <h3 class="small muted">INSTALLÉS (${placed.length})</h3><div class="list">${placed.map((o) => `<div class="item"><div class="grow"><b>${esc(o.label)}</b>${o.busy ? '<span class="tag warn">utilisé</span>' : ''}</div>
            <button class="btn" data-ed="move" data-id="${o.id}">Déplacer</button><button class="btn" data-ed="store" data-id="${o.id}">Ranger</button>
            <button class="btn danger" data-ed="sell" data-id="${o.id}" title="Rend ${money(o.refund)}">Revendre</button></div>`).join('') || '<p class="muted small">Aucun équipement installé.</p>'}</div>
        ${stored.length ? `<h3 class="small muted">RÉSERVE (${stored.length})</h3><div class="list">${stored.map((o) => `<div class="item"><div class="grow"><b>${esc(o.label)}</b></div>
            <button class="btn ok" data-ed="place" data-id="${o.id}">Poser</button><button class="btn danger" data-ed="sell" data-id="${o.id}">Revendre (${money(o.refund)})</button></div>`).join('')}</div>` : ''}
        <h3 class="small muted">ACHETER</h3><div class="list">${d.catalog.map((c) => `<div class="item ${c.unlocked ? '' : 'locked'}"><div class="grow"><b>${esc(c.icon || '')} ${esc(c.label)}</b>
            <span class="sub">${esc(c.category || '')} · ${money(c.price)}</span></div>${c.unlocked ? `<button class="btn primary" data-ed="buy" data-type="${esc(c.type)}" ${full ? 'disabled' : ''}>Acheter et poser</button>`
            : `<span class="tag">🔒 Niveau ${c.level}</span>`}</div>`).join('')}</div>
        ${full ? '<p class="muted small">Limite atteinte : améliore le laboratoire ou revends un équipement.</p>' : ''}</div></div>`;
}

/* ---------- Fabrication ---------- */
function viewCraft(d) {
    let body;
    if (d.locked) body = `<div class="msg bad">Équipement verrouillé : niveau ${d.needLevel} requis.</div>`;
    else if (!d.canCraft) body = '<div class="msg bad">Ton grade ne peut pas fabriquer ici.</div>';
    else if (d.busy) body = '<div class="msg bad">Quelqu\'un utilise déjà cet équipement.</div>';
    else body = `<div class="list">${d.recipes.map((r) => {
        const max = Math.max(0, Math.min(d.maxBatch, r.max));
        const n = Math.min(Math.max(1, state[r.id] || 1), Math.max(1, max));
        return `<div class="item" style="align-items:flex-start"><div class="grow"><b>${esc(r.label)}</b>
            <div class="ing">${r.inputs.map((i) => `<span class="${i.have >= i.count * n ? 'have' : 'miss'}">${i.count * n} × ${esc(i.label)} (${i.have})</span>`).join(' + ')}</div>
            <div class="ing">→ ${r.outputs.map((o) => `${o.count * n} × ${esc(o.label)}`).join(', ')} · ${r.duration * n} s · +${r.xp * n} XP</div></div>
            <div class="stack" style="gap:6px;justify-items:end"><div class="qty"><button class="btn" data-q="-1" data-r="${esc(r.id)}">−</button><input value="${n}" readonly><button class="btn" data-q="1" data-r="${esc(r.id)}" data-max="${max}">+</button></div>
            <button class="btn primary" data-craft="${esc(r.id)}" data-n="${n}" ${max < 1 ? 'disabled' : ''}>Fabriquer</button></div></div>`;
    }).join('') || '<p class="muted">Aucune recette.</p>'}</div>`;
    return `<div class="card" style="width:600px">${head('⚗️', d.label, 'Les ingrédients sont retirés à la fin de la fabrication')}<div class="body">${body}</div></div>`;
}

/* ---------- Tablette ---------- */
const TABS = [['info', '📊 Informations'], ['security', '🔐 Sécurité et accès'], ['equipment', '🛠️ Équipements'], ['upgrades', '⬆️ Améliorations'], ['stash', '📦 Coffre'], ['raids', '⚔️ Attaques']];
function tabAllowed(d, t) {
    const r = d.rights || {};
    if (t === 'security') return r.security || !!d.grades;
    if (t === 'stash') return r.stash;
    if (t === 'raids') return r.raid;
    return true;
}
function viewTablet(d) {
    if (!state.tab || !tabAllowed(d, state.tab)) state.tab = 'info';
    const l = d.lab;
    const tabs = TABS.map(([id, label]) => `<button data-tab="${id}" class="${state.tab === id ? 'on' : ''}" ${tabAllowed(d, id) ? '' : 'disabled'}>${label}</button>`).join('');
    return `<div class="card wide">${head('🧪', `Laboratoire · ${l.name}`, `${esc(l.owner)} · ${esc(l.levelLabel)}${d.staff ? ' · vue staff' : ''}`)}
        <div class="tbody"><div class="tabs">${tabs}</div><div class="tcontent">${TV[state.tab](d)}</div></div></div>`;
}
const progress = (l) => {
    if (!l.nextXp) return '<p class="muted small">Niveau maximum atteint.</p>';
    const pct = Math.max(0, Math.min(100, ((l.xp - l.levelXp) / Math.max(1, l.nextXp - l.levelXp)) * 100));
    return `<div class="row between small"><span>${l.xp} XP</span><span class="muted">Niveau suivant : ${l.nextXp} XP</span></div><div class="bar"><i style="width:${pct}%"></i></div>`;
};
const TV = {
    info(d) {
        const l = d.lab;
        return `<h2>Informations générales</h2><div class="stats">
            <div class="stat"><b>${esc(l.owner)}</b><span>Propriétaire</span></div>
            <div class="stat"><b>${esc(l.levelLabel)}</b><span>Niveau ${l.level} / ${l.maxLevel}</span></div>
            <div class="stat"><b>${l.xp} XP</b><span>Expérience</span></div>
            <div class="stat"><b>${l.placed} / ${l.maxEquipment}</b><span>Équipements installés (${l.equipment} achetés)</span></div>
            <div class="stat"><b>${l.present}</b><span>Personne(s) dans le laboratoire</span></div>
            <div class="stat"><b>${esc(l.interior)}</b><span>Intérieur</span></div></div>
            <h2>Progression</h2>${progress(l)}
            <h2>Améliorations acquises</h2>${(d.upgrades || []).length ? `<table><tr><th>Niveau</th><th>Prix</th><th>Par</th><th>Date</th></tr>${d.upgrades.map((u) => `<tr><td>${u.level}</td><td>${money(u.price)}</td><td>${esc(u.by)}</td><td>${date(u.t)}</td></tr>`).join('')}</table>` : '<p class="muted small">Aucune amélioration achetée pour l\'instant.</p>'}
            <h2>Débloqué</h2><div class="row" style="flex-wrap:wrap">${d.levels.filter((x) => x.owned).flatMap((x) => x.unlocks).map((c) => `<span class="tag ok">${esc(c.icon)} ${esc(c.label)}</span>`).join('')}</div>`;
    },
    security(d) {
        const r = d.rights || {};
        let out = '<h2>Code d\'accès</h2>';
        out += r.security ? `<p class="muted small" style="margin-bottom:8px">Les membres autorisés entrent sans code. Les autres doivent saisir le code. Le code actuel n'est jamais affiché.</p>
            <div class="row"><div class="field" style="flex:1"><input id="newcode" type="password" inputmode="numeric" maxlength="8" placeholder="Nouveau code (chiffres)"></div><button class="btn primary" data-t="setCode">Changer le code</button></div>`
            : '<p class="muted small">Ton grade ne peut pas changer le code.</p>';
        if (d.grades) {
            const defs = d.permDefs;
            out += `<h2 style="margin-top:18px">Autorisations des grades</h2><p class="muted small" style="margin-bottom:8px">Le chef a tous les droits. « Ouvrir la tablette » est distinct de la gestion (code, équipements, améliorations).</p>
                <table><tr><th>Grade</th>${defs.map((p) => `<th class="c">${esc(p.label)}</th>`).join('')}</tr>
                ${d.grades.slice().reverse().map((g) => `<tr><td><b>${esc(g.label)}</b> <span class="muted small">niv. ${g.level}</span></td>${defs.map((p) => g.boss
                    ? '<td class="c">✔</td>' : `<td class="c"><input type="checkbox" data-perm="${g.id}|${p.key}" ${(state.perms[g.id] || g.perms)[p.key] ? 'checked' : ''}></td>`).join('')}</tr>`).join('')}</table>
                <div class="row" style="margin-top:10px"><button class="btn primary" data-t="setPerms">Enregistrer les autorisations</button></div>`;
        }
        return out;
    },
    equipment(d) {
        const r = d.rights || {};
        const l = d.lab;
        return `<h2>Équipements (${l.equipment} / ${l.maxEquipment})</h2>
            ${r.equipment ? '' : '<p class="muted small" style="margin-bottom:8px">Consultation seulement : ton grade ne gère pas les équipements.</p>'}
            <table><tr><th>Équipement</th><th>État</th><th></th></tr>${d.owned.map((o) => `<tr><td>${esc(o.label)}</td><td>${o.placed ? '<span class="tag ok">installé</span>' : '<span class="tag">réserve</span>'}${o.busy ? ' <span class="tag warn">utilisé</span>' : ''}</td>
                <td style="text-align:right">${r.equipment ? `${o.placed ? `<button class="btn" data-t="equipStore" data-id="${o.id}">Ranger</button>` : `<button class="btn ok" data-t="place" data-id="${o.id}" data-type="${esc(o.type)}">Poser</button>`}
                <button class="btn danger" data-t="equipSell" data-id="${o.id}">Revendre (${money(o.refund)})</button>` : ''}</td></tr>`).join('') || '<tr><td colspan="3" class="muted">Aucun équipement.</td></tr>'}</table>
            <h2 style="margin-top:18px">Catalogue</h2><table><tr><th>Équipement</th><th>Drogue</th><th>Niveau</th><th>Prix</th><th>Recettes</th><th></th></tr>
            ${d.catalog.map((c) => `<tr style="${c.unlocked ? '' : 'opacity:.55'}"><td><b>${esc(c.label)}</b></td><td>${esc(c.category.icon)} ${esc(c.category.label)}</td><td>${c.level}</td><td>${money(c.price)}</td>
                <td class="small muted">${c.recipes.map(esc).join(' · ')}</td><td style="text-align:right;white-space:nowrap">${!c.unlocked ? '<span class="tag">🔒 verrouillé</span>' : r.equipment
                ? `<button class="btn" data-t="equipBuy" data-type="${esc(c.type)}">Acheter</button> <button class="btn primary" data-t="place" data-type="${esc(c.type)}">Acheter et poser</button>` : '<span class="tag ok">débloqué</span>'}</td></tr>`).join('')}</table>`;
    },
    upgrades(d) {
        const l = d.lab;
        return `<h2>Niveau ${l.level} · ${l.xp} XP</h2>${progress(l)}
            ${d.upgradeHint ? `<p class="muted small">${esc(d.upgradeHint)}</p>` : ''}
            <div class="levels" style="margin-top:10px">${d.levels.map((x) => {
                const next = x.n === l.level + 1;
                return `<div class="level ${x.owned ? 'on' : next ? 'next' : ''}"><div class="row between"><b>${esc(x.label)}</b>
                    ${x.owned ? '<span class="tag ok">acquis</span>' : next ? `<button class="btn primary" data-t="upgrade" ${d.canUpgrade ? '' : 'disabled'}>Acheter · ${money(x.price)}</button>` : '<span class="tag">verrouillé</span>'}</div>
                    <div class="small muted" style="margin-top:6px">Seuil : ${x.xp} XP · Prix : ${money(x.price)} · ${x.maxEquipment} équipements</div>
                    <div class="row" style="flex-wrap:wrap;margin-top:6px">${x.unlocks.map((c) => `<span class="tag acc">${esc(c.icon)} ${esc(c.label)}</span>`).join('')}</div></div>`;
            }).join('')}</div><p class="muted small" style="margin-top:10px">Les achats sont payés avec le ${esc(l.account)} du groupe. L'expérience vient des fabrications terminées dans ce laboratoire.</p>`;
    },
    stash() {
        return `<h2>Coffre du laboratoire</h2><p class="muted" style="margin-bottom:10px">Le coffre appartient au laboratoire : son contenu reste en place si le laboratoire change de propriétaire.</p>
            <button class="btn primary" data-t="stash">Ouvrir le coffre</button>`;
    },
    raids(d) {
        const R = d.raids || {};
        const c = R.current;
        return `<h2>Attaques</h2><div class="stats">
            <div class="stat"><b>${c ? (c.status === 'preparing' ? 'En préparation' : 'En cours') : 'Aucune'}</b><span>${c ? `Par ${esc(c.attacker)} · ${dur(c.remaining)}` : 'Attaque en cours'}</span></div>
            <div class="stat"><b>${Math.floor((R.duration || 0) / 60)} min</b><span>Durée d'une capture</span></div>
            <div class="stat"><b>${Math.floor(R.radius || 0)} m</b><span>Rayon de la zone</span></div>
            <div class="stat"><b>${R.cooldown > 0 ? dur(R.cooldown) : 'Attaquable'}</b><span>Repos après une attaque</span></div></div>
            ${c ? `<div class="msg bad" style="margin-bottom:12px">Attaquants dans la zone : ${c.attackers || 0} · Défenseurs : ${c.defenders || 0}</div>` : ''}
            <p class="muted small" style="margin-bottom:10px">Horaires : ${esc(R.schedule)} · Victoire des attaquants : ${R.rule === 'majority' ? 'plus d\'attaquants que de défenseurs vivants dans la zone à la fin' : 'au moins un attaquant vivant dans la zone à la fin'}.</p>
            <table><tr><th>Date</th><th>Attaquant</th><th>Défenseur</th><th>Résultat</th></tr>${(R.history || []).map((h) => `<tr><td>${date(h.t)}</td><td>${esc(h.attacker_label)}</td><td>${esc(h.defender_label)}</td>
                <td>${{ success: '<span class="tag bad">capturé</span>', failed: '<span class="tag ok">défendu</span>', cancelled: '<span class="tag">annulée</span>', active: '<span class="tag warn">en cours</span>', preparing: '<span class="tag warn">préparation</span>' }[h.status] || esc(h.status)}
                <span class="muted small">${esc(h.reason || '')}</span></td></tr>`).join('') || '<tr><td colspan="4" class="muted">Aucune attaque.</td></tr>'}</table>`;
    },
};

/* ---------- Rendu et évènements ---------- */
function render() {
    if (!kind) return;
    panel.innerHTML = kind === 'entrance' ? viewEntrance(data) : kind === 'editor' ? viewEditor(data) : kind === 'craft' ? viewCraft(data) : viewTablet(data);
    panel.classList.remove('hidden');
}
window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') { kind = m.kind; data = m.data; state = { perms: {} }; render(); }
    else if (m.action === 'update' && m.kind === kind) { data = m.data; if (kind === 'tablet') state.perms = {}; render(); }
    else if (m.action === 'close') { panel.classList.add('hidden'); panel.innerHTML = ''; kind = null; }
    else if (m.action === 'hud') hud(m);
});
panel.addEventListener('click', async (e) => {
    const t = e.target;
    if (t.closest('[data-close]') || t === panel) return close();
    let b;
    if (kind === 'entrance') {
        if ((b = t.closest('[data-act]'))) { const a = b.dataset.act; if (a === 'code') { state = { code: '' }; return render(); } return entranceAct(a); }
        if (t.closest('[data-back]')) { state = {}; return render(); }
        if ((b = t.closest('[data-key]'))) {
            const k = b.dataset.key;
            if (k === 'del') state.code = state.code.slice(0, -1);
            else if (k === 'ok') { if (state.code.length >= 4) entranceAct('enter', state.code); return; }
            else if (state.code.length < 8) state.code += k;
            state.error = null;
            return render();
        }
    } else if (kind === 'editor') {
        if ((b = t.closest('[data-ed]'))) post('editorAction', { action: b.dataset.ed, id: Number(b.dataset.id) || undefined, type: b.dataset.type, owned: data.owned });
    } else if (kind === 'craft') {
        if ((b = t.closest('[data-q]'))) { const id = b.dataset.r; const max = Math.max(1, Number(b.dataset.max || data.maxBatch)); state[id] = Math.max(1, Math.min(max, (state[id] || 1) + Number(b.dataset.q))); return render(); }
        if ((b = t.closest('[data-craft]')) && !b.disabled) post('craft', { id: data.id, recipe: b.dataset.craft, times: Number(b.dataset.n) || 1 });
    } else if (kind === 'tablet') {
        if ((b = t.closest('[data-tab]')) && !b.disabled) { state.tab = b.dataset.tab; return render(); }
        if ((b = t.closest('[data-t]')) && !b.disabled) {
            const name = b.dataset.t;
            if (name === 'setCode') { const v = ($('#newcode') || {}).value || ''; if (!/^\d{4,8}$/.test(v)) return; return post('tabletAction', { name, data: { code: v } }); }
            if (name === 'setPerms') {
                const perms = {};
                (data.grades || []).filter((g) => !g.boss).forEach((g) => { perms[g.id] = Object.assign({}, g.perms, state.perms[g.id] || {}); });
                return post('tabletAction', { name, data: { perms } });
            }
            return post('tabletAction', { name, data: { id: Number(b.dataset.id) || undefined, type: b.dataset.type } });
        }
    }
});
panel.addEventListener('change', (e) => {
    const t = e.target;
    if (kind === 'tablet' && t.dataset.perm) {
        const [gid, key] = t.dataset.perm.split('|');
        const g = (data.grades || []).find((x) => String(x.id) === gid);
        state.perms[gid] = Object.assign({}, g ? g.perms : {}, state.perms[gid] || {}, { [key]: t.checked });
    }
});
document.addEventListener('keydown', (e) => {
    if (!kind) return;
    if (e.key === 'Escape') { e.preventDefault(); return close(); }
    if (kind === 'entrance' && state.code !== undefined) {
        if (/^\d$/.test(e.key) && state.code.length < 8) { state.code += e.key; state.error = null; render(); }
        else if (e.key === 'Backspace') { state.code = state.code.slice(0, -1); render(); }
        else if (e.key === 'Enter' && state.code.length >= 4) entranceAct('enter', state.code);
    }
});

/* ---------- HUD d'attaque (compte à rebours local entre deux mises à jour du serveur) ---------- */
let hudState = null, hudTimer = null;
function hud(m) {
    const el = $('#hud');
    if (!m.show) { el.classList.add('hidden'); hudState = null; clearInterval(hudTimer); return; }
    hudState = Object.assign({}, m.data, { at: Date.now() });
    const draw = () => {
        if (!hudState) return;
        const s = hudState;
        const left = Math.max(0, s.remaining - (Date.now() - s.at) / 1000);
        const prep = s.status === 'preparing';
        el.className = s.side === 'attack' ? 'attack' : 'defend';
        el.innerHTML = `<div class="s">${s.side === 'attack' ? '⚔️ ATTAQUE' : '🛡️ DÉFENSE'} · ${esc(s.name)}</div><div class="t">${dur(left)}</div>
            <div class="s">${prep ? 'Préparation : l\'attaque commence bientôt' : `${esc(s.attackerLabel)} contre ${esc(s.defenderLabel)}`}</div>
            ${prep ? '' : `<div class="teams"><span>⚔️ ${s.attackers} attaquant(s) dans la zone</span><span>🛡️ ${s.defenders} défenseur(s)</span></div>`}
            ${s.grace != null ? `<div class="warn">Plus aucun attaquant dans la zone : échec dans ${Math.ceil(Math.max(0, s.grace - (Date.now() - s.at) / 1000))} s</div>` : ''}`;
    };
    draw();
    clearInterval(hudTimer);
    hudTimer = setInterval(draw, 250);
}
