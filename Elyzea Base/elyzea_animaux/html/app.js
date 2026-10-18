/* =========================================================
   ELYZEA ANIMAUX - INTERFACE
   Boutique (aperçu réel en jeu), accessoires, vétérinaire, « Mes animaux ».
   Les prix affichés viennent du serveur, qui les recalcule à l'achat.
   ========================================================= */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_animaux';
const $ = (s) => document.querySelector(s);
const post = (name, body = {}) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    .then((r) => r.json()).catch(() => ({}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const arr = (x) => (Array.isArray(x) ? x : []);   // Lua envoie {} pour une liste vide
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
const date = (t) => (t ? new Date(t * 1000).toLocaleDateString('fr-FR', { day: '2-digit', month: 'long', year: 'numeric' }) : '—');

let view = null;
const S = { d: null, tab: 'pets', cat: null, sp: null, va: null, name: '', pay: 'cash', acc: {}, busy: false };
const P = { d: null, renaming: null };

/* ---------- Confirmation ---------- */
function confirmBox(title, text, yes = 'Confirmer') {
    $('#mTitle').textContent = title;
    $('#mText').textContent = text;
    $('#mYes').textContent = yes;
    $('#modal').classList.remove('hidden');
    return new Promise((resolve) => {
        $('#mYes').onclick = () => { $('#modal').classList.add('hidden'); resolve(true); };
        $('#mNo').onclick = () => { $('#modal').classList.add('hidden'); resolve(false); };
    });
}

/* ---------- Boutique ---------- */
const sp = () => arr(S.d && S.d.catalog).find((x) => x.id === S.sp);
const va = () => { const s = sp(); return s ? s.variants.find((v) => v.id === S.va) || s.variants[0] : null; };
const payOptions = () => Object.entries(S.d.payments || {}).map(([k, l]) => `<option value="${k}" ${S.pay === k ? 'selected' : ''}>${esc(l)}${S.d.money && S.d.money[k] !== undefined ? ` (${money(S.d.money[k])})` : ''}</option>`).join('');

function pickSpecies(id) {
    S.sp = id;
    const s = sp();
    S.va = s && s.variants[0] ? s.variants[0].id : null;
    preview();
    renderShop();
}
function preview() {
    const v = va();
    if (v) post('shop', { action: 'preview', variant: v });
}

function shopPets() {
    const d = S.d;
    if (!arr(d.catalog).length) return '<div class="empty">Aucun animal disponible chez ce vendeur pour le moment.</div>';
    const cats = arr(d.categories).filter((c) => arr(d.catalog).some((s) => s.cat === c.id));
    if (!S.cat || !cats.find((c) => c.id === S.cat)) S.cat = cats[0] ? cats[0].id : null;
    const list = arr(d.catalog).filter((s) => s.cat === S.cat);
    const s = sp();
    const v = va();
    const cards = list.map((x) => `<div class="card ${x.id === S.sp ? 'on' : ''}" data-sp="${x.id}">
        <div><b>${esc(x.label)}</b><small>${esc(x.profile)} · ${x.variants.length} pelage(s)${x.exotic ? ' · exotique' : ''}</small></div>
        <span class="price">dès ${money(Math.min(...x.variants.map((y) => y.total)))}</span></div>`).join('');
    let detail = '<p class="hint">Choisis un animal : il apparaît devant toi avec son vrai pelage.</p>';
    if (s && v) {
        const full = d.owned >= d.maxOwned;
        const exoFull = s.exotic && d.exoticOwned >= d.maxExotic;
        detail = `<div class="box2">
            <div><label>Pelage (${s.variants.length})</label><div class="row">${s.variants.map((y) => `<span class="sw ${y.id === v.id ? 'on' : ''}" data-va="${y.id}">${esc(y.label)}${y.extra ? ` +${money(y.extra)}` : ''}</span>`).join('')}</div></div>
            <table class="bd"><tr><td>Prix de l'animal</td><td>${money(s.price)}</td></tr>
                ${v.extra ? `<tr><td>Supplément pelage « ${esc(v.label)} »</td><td>${money(v.extra)}</td></tr>` : ''}
                ${s.fees ? `<tr><td>Frais (certificat, dossier)</td><td>${money(s.fees)}</td></tr>` : ''}
                <tr class="total"><td>Total</td><td>${money(v.total)}</td></tr></table>
            <div><label>Son nom</label><input type="text" id="petName" maxlength="20" placeholder="2 à 20 lettres" value="${esc(S.name)}"></div>
            <div><label>Paiement</label><select id="pay">${payOptions()}</select></div>
            ${s.exotic && d.exoticItem ? `<p class="hint warn">Animal exotique : il faut « ${esc(d.exoticItem)} » dans ton inventaire.</p>` : ''}
            ${full ? `<p class="hint err">Tu as déjà ${d.owned} animal(aux) sur ${d.maxOwned} autorisés.</p>` : ''}
            ${exoFull ? `<p class="hint err">Maximum d'animaux exotiques atteint (${d.maxExotic}).</p>` : ''}
            <button class="act primary" data-buy ${full || exoFull || S.busy ? 'disabled' : ''}>Acheter ${esc(s.label)} · ${money(v.total)}</button>
            ${s.harness ? '<p class="hint">Harnais et laisse : onglet Accessoires (chez les vendeurs qui en ont).</p>' : ''}
        </div>`;
    }
    return `<div class="row">${cats.map((c) => `<span class="chip ${c.id === S.cat ? 'on' : ''}" data-cat="${c.id}">${c.icon} ${esc(c.label)}</span>`).join('')}</div>
        ${cards}${detail}
        <p class="hint">Animaux possédés : ${d.owned} / ${d.maxOwned}${d.maxExotic ? ` · exotiques : ${d.exoticOwned} / ${d.maxExotic}` : ''}</p>`;
}

function shopAcc() {
    const d = S.d;
    if (!arr(d.accessories).length) return '<div class="empty">Pas d\'accessoires ici.</div>';
    return arr(d.accessories).map((a) => {
        const st = S.acc[a.id] || (S.acc[a.id] = { qty: 1, style: d.styles[0].id, color: d.colors[0].id });
        let extra = '';
        if (a.id === 'harness') {
            extra = `<div><label>Style</label><div class="row">${d.styles.map((s) => `<span class="sw ${st.style === s.id ? 'on' : ''}" data-hs="${s.id}">${esc(s.label)}</span>`).join('')}</div></div>
                <div><label>Couleur</label><div class="row">${d.colors.map((c) => `<span class="dot ${st.color === c.id ? 'on' : ''}" title="${esc(c.label)}" data-hc="${c.id}" style="background:rgb(${c.rgb.join(',')})"></span>`).join('')}</div></div>`;
        } else if (a.stack) {
            extra = `<div><label>Quantité</label><input type="number" min="1" max="20" value="${st.qty}" data-qty="${a.id}"></div>`;
        }
        const total = a.price * (a.stack ? st.qty : 1);
        return `<div class="box2"><div class="row" style="justify-content:space-between"><b>${esc(a.label)}</b><span class="price">${money(a.price)}${a.stack ? ' / u' : ''}</span></div>
            ${extra}<button class="act primary" data-buyacc="${a.id}" ${S.busy ? 'disabled' : ''}>Acheter · ${money(total)}</button></div>`;
    }).join('') + `<div><label>Paiement</label><select id="pay">${payOptions()}</select></div>
        <p class="hint">Harnais : utilise-le près de ton chien (ou ALT sur lui). Laisse : garde-la dans ton inventaire, puis ALT › Attacher la laisse.</p>`;
}

function shopVet() {
    const d = S.d;
    const rows = arr(d.vetPets).map((p) => `<div class="card"><div><b>${esc(p.name)}</b><small>${esc(p.speciesLabel)} · ${p.status === 'injured' ? '<span class="err">blessé</span>' : `santé ${p.health} %`}</small></div>
        <button class="act primary" data-vet="${p.id}" ${S.busy ? 'disabled' : ''}>Soigner · ${money(d.vetPrice)}</button></div>`).join('');
    return `${rows || '<div class="empty">Aucun de tes animaux n\'a besoin de soins.</div>'}
        <div><label>Paiement</label><select id="pay">${payOptions()}</select></div>
        <p class="hint">Le vétérinaire remet la santé à 100 % (même un animal blessé resté à la maison), et nourrit / abreuve un minimum.</p>`;
}

function renderShop() {
    const d = S.d;
    $('#shopTitle').textContent = d.vendor ? d.vendor.label : 'Vendeur';
    if (d.loading) {
        $('#shopTabs').innerHTML = '';
        $('#shopBody').innerHTML = '<div class="empty">Chargement du catalogue (vérification des pelages)…</div>';
        return;
    }
    $('#shopSub').textContent = d.money ? `Espèces ${money(d.money.cash)} · Banque ${money(d.money.bank)}` : '';
    const tabs = [{ id: 'pets', label: '🐾 Animaux' }];
    if (arr(d.accessories).length) tabs.push({ id: 'acc', label: '🦮 Accessoires' });
    if (d.vendor.vet) tabs.push({ id: 'vet', label: '🩺 Vétérinaire' });
    if (!tabs.find((t) => t.id === S.tab)) S.tab = 'pets';
    $('#shopTabs').innerHTML = tabs.map((t) => `<button class="${t.id === S.tab ? 'on' : ''}" data-tab="${t.id}">${t.label}</button>`).join('');
    $('#shopBody').innerHTML = S.tab === 'acc' ? shopAcc() : S.tab === 'vet' ? shopVet() : shopPets();
    $('#rotate').classList.toggle('hidden', S.tab !== 'pets' || !sp());
}

async function reloadShop() {
    const r = await post('shop', { action: 'reload' });
    if (r && r.ok && r.data) { S.d = r.data; renderShop(); }
}

async function buy() {
    const s = sp(); const v = va();
    if (!s || !v || S.busy) return;
    const name = ($('#petName') || {}).value || '';
    if (name.trim().length < 2) return confirmBox('Donne-lui un nom', 'Le nom doit faire 2 à 20 lettres.', 'OK');
    const pay = ($('#pay') || {}).value || S.pay;
    if (!await confirmBox('Confirmer l\'achat ?', `${s.label} · ${v.label}\nNom : ${name.trim()}\nTotal : ${money(v.total)} (${S.d.payments[pay]})`)) return;
    S.busy = true; renderShop();
    const r = await post('shop', { action: 'buy', species: s.id, variant: v.id, name: name.trim(), pay, expected: v.total });
    S.busy = false;
    if (r.ok) S.name = '';
    await reloadShop();
}

async function buyAcc(id) {
    const a = arr(S.d.accessories).find((x) => x.id === id);
    if (!a || S.busy) return;
    const st = S.acc[id];
    const qty = a.stack ? Math.max(1, Math.min(20, Number(st.qty) || 1)) : 1;
    const total = a.price * qty;
    const pay = ($('#pay') || {}).value || S.pay;
    let label = a.label;
    if (id === 'harness') {
        const s = S.d.styles.find((x) => x.id === st.style); const c = S.d.colors.find((x) => x.id === st.color);
        label = `${a.label} · ${s.label} · ${c.label}`;
    }
    if (!await confirmBox('Confirmer l\'achat ?', `${qty} × ${label}\nTotal : ${money(total)} (${S.d.payments[pay]})`)) return;
    S.busy = true; renderShop();
    await post('shop', { action: 'buyItem', kind: id, style: st.style, color: st.color, qty, pay, expected: total });
    S.busy = false;
    await reloadShop();
}

async function vet(id) {
    const p = arr(S.d.vetPets).find((x) => x.id === id);
    if (!p || S.busy) return;
    const pay = ($('#pay') || {}).value || S.pay;
    if (!await confirmBox('Soins vétérinaires ?', `${p.name} · ${money(S.d.vetPrice)} (${S.d.payments[pay]})`)) return;
    S.busy = true; renderShop();
    await post('shop', { action: 'vet', pet: id, pay, expected: S.d.vetPrice });
    S.busy = false;
    await reloadShop();
}

/* ---------- Mes animaux ---------- */
const STATUS = { stored: 'Rangé', out: 'Sorti', injured: 'Blessé' };
const bar = (label, v) => `<div class="stat"><span>${label}</span><div class="bar ${v < 25 ? 'crit' : v < 50 ? 'low' : ''}"><i style="width:${Math.max(0, Math.min(100, v))}%"></i></div><span>${v} %</span></div>`;

function harnessLabel(h) {
    if (!h || !P.d) return '';
    const s = (P.d.styles || []).find((x) => x.id === h.style); const c = (P.d.colors || []).find((x) => x.id === h.color);
    return s && c ? `${s.label} · ${c.label}` : 'Harnais';
}

function renderPets() {
    const d = P.d;
    d.pets = arr(d.pets);
    const out = d.pets.filter((p) => p.out).length;
    $('#petsSub').textContent = `${d.pets.length} / ${d.maxOwned} animaux · ${out} / ${d.maxOut} sorti(s)${d.enabled ? '' : ' · système désactivé par le staff'}`;
    if (!d.pets.length) {
        $('#petsBody').innerHTML = '<div class="empty">Tu n\'as pas encore d\'animal. Va voir l\'animalerie (blip sur la carte).</div>';
        return;
    }
    $('#petsBody').innerHTML = `<div class="pets">${d.pets.map((p) => {
        const st = p.out ? 'out' : p.status;
        const cmds = p.out ? `<div class="cmds">${arr(p.commands).map((c) => `<button data-cmd="${c.id}" data-id="${p.id}">${esc(c.label)}</button>`).join('')}</div>
            <div class="cmds"><button data-care="food" data-id="${p.id}">Croquettes</button><button data-care="treat" data-id="${p.id}">Friandise</button><button data-care="water" data-id="${p.id}">Eau</button>
            ${p.health < 100 ? `<button data-care="medkit" data-id="${p.id}">Soigner</button>` : ''}
            ${p.gear && p.gear.harness ? `<button data-unharness="${p.id}">Retirer le harnais</button>` : ''}
            <button data-leash="${p.id}">${p.leash ? 'Détacher la laisse' : 'Laisse'}</button></div>` : '';
        const rename = P.renaming === p.id
            ? `<div class="row"><input type="text" id="rn" maxlength="20" value="${esc(p.name)}" style="flex:1"><button class="act primary" data-rnok="${p.id}">OK</button><button class="act" data-rnno>✕</button></div>` : '';
        return `<div class="pet ${d.focus === p.id ? 'focus' : ''}">
            <h3>${esc(p.name)} <span class="badge ${st}">${STATUS[st] || st}</span></h3>
            <span class="hint">${esc(p.speciesLabel)} · ${esc(p.variantLabel)}${p.exotic ? ' · exotique' : ''}<br>Puce ${esc(p.chip)} · depuis le ${date(p.acquired)}${p.price ? ` · ${money(p.price)}` : ''}
            ${p.gear && p.gear.harness ? `<br>Harnais : ${esc(harnessLabel(p.gear.harness))}` : ''}</span>
            ${bar('Faim', p.hunger)}${bar('Soif', p.thirst)}${bar('Santé', p.health)}
            ${p.status === 'injured' ? '<p class="hint err">Blessé : soigne-le avec une trousse vétérinaire ou chez le vétérinaire avant de le sortir.</p>' : ''}
            ${rename}${cmds}
            <div class="row">${p.out ? `<button class="act" data-store="${p.id}">Ranger</button>` : `<button class="act primary" data-spawn="${p.id}" ${p.status === 'injured' || !d.enabled ? 'disabled' : ''}>Sortir</button>`}
                ${p.status === 'injured' ? `<button class="act" data-care="medkit" data-id="${p.id}">Trousse vétérinaire</button>` : ''}
                <button class="act" data-rename="${p.id}">Renommer</button></div></div>`;
    }).join('')}</div>`;
}

/* ---------- Messages Lua ---------- */
window.addEventListener('message', (e) => {
    const m = e.data;
    if (m.action === 'open') {
        view = m.view;
        if (view === 'shop') { S.d = m.data; S.tab = 'pets'; S.sp = null; S.va = null; $('#shop').classList.remove('hidden'); renderShop(); }
        if (view === 'pets') { P.d = m.data; P.renaming = null; $('#pets').classList.remove('hidden'); renderPets(); }
    } else if (m.action === 'update') {
        if (m.view === 'shop' && view === 'shop') { S.d = m.data; renderShop(); }
        if (m.view === 'pets' && view === 'pets') { const f = P.d && P.d.focus; P.d = m.data; P.d.focus = f; renderPets(); }
    } else if (m.action === 'close') {
        view = null;
        $('#shop').classList.add('hidden'); $('#pets').classList.add('hidden'); $('#modal').classList.add('hidden');
    }
});

const close = () => post('close');
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('#modal').classList.contains('hidden')) { $('#mNo').click(); return; }
    close();
});

document.addEventListener('input', (e) => {
    const t = e.target;
    if (t.id === 'petName') S.name = t.value;
    if (t.dataset.qty) { S.acc[t.dataset.qty].qty = Number(t.value) || 1; }
});
document.addEventListener('change', (e) => {
    if (e.target.id === 'pay') S.pay = e.target.value;
    if (e.target.dataset.qty) renderShop();
});

document.addEventListener('click', async (e) => {
    const n = (sel) => e.target.closest(sel);
    let x;
    if (n('[data-close]')) return close();
    if (view === 'shop') {
        if ((x = n('[data-tab]'))) { S.tab = x.dataset.tab; if (S.tab !== 'pets') post('shop', { action: 'hidePreview' }); else preview(); return renderShop(); }
        if ((x = n('[data-cat]'))) { S.cat = x.dataset.cat; S.sp = null; post('shop', { action: 'hidePreview' }); return renderShop(); }
        if ((x = n('[data-sp]'))) return pickSpecies(x.dataset.sp);
        if ((x = n('[data-va]'))) { S.va = x.dataset.va; preview(); return renderShop(); }
        if ((x = n('[data-rot]'))) return post('shop', { action: 'rotate', deg: Number(x.dataset.rot) });
        if (n('[data-buy]')) return buy();
        if ((x = n('[data-hs]'))) { S.acc.harness.style = x.dataset.hs; return renderShop(); }
        if ((x = n('[data-hc]'))) { S.acc.harness.color = x.dataset.hc; return renderShop(); }
        if ((x = n('[data-buyacc]'))) return buyAcc(x.dataset.buyacc);
        if ((x = n('[data-vet]'))) return vet(Number(x.dataset.vet));
    }
    if (view === 'pets') {
        if ((x = n('[data-spawn]'))) return post('pets', { action: 'spawn', id: Number(x.dataset.spawn) });
        if ((x = n('[data-store]'))) return post('pets', { action: 'store', id: Number(x.dataset.store) });
        if ((x = n('[data-cmd]'))) return post('pets', { action: 'command', id: Number(x.dataset.id), command: x.dataset.cmd });
        if ((x = n('[data-care]'))) return post('pets', { action: 'care', id: Number(x.dataset.id), kind: x.dataset.care });
        if ((x = n('[data-leash]'))) return post('pets', { action: 'leash', id: Number(x.dataset.leash) });
        if ((x = n('[data-unharness]'))) return post('pets', { action: 'unharness', id: Number(x.dataset.unharness) });
        if ((x = n('[data-rename]'))) { P.renaming = Number(x.dataset.rename); renderPets(); const i = $('#rn'); if (i) { i.focus(); i.select(); } return; }
        if (n('[data-rnno]')) { P.renaming = null; return renderPets(); }
        if ((x = n('[data-rnok]'))) {
            const r = await post('pets', { action: 'rename', id: Number(x.dataset.rnok), name: ($('#rn') || {}).value || '' });
            if (r.ok) P.renaming = null;
            return renderPets();
        }
    }
});
