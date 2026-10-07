/* =========================================================
   ELYZEA · Borne de commande (client), préparation (employé),
   suivi en direct (client), alerte « nouvelle commande »
   ========================================================= */
const KS = { data: null, cat: null, cart: {}, method: 'bank', view: 'menu', last: null };
const STATUS = { pending: 'En attente', preparing: 'En préparation', ready: 'Prête au comptoir' };

function kProduct(id) { return ((KS.data && KS.data.products) || []).find((p) => p.id === id); }
function kCount() { return Object.values(KS.cart).reduce((s, n) => s + n, 0); }
function kTotal() { return Object.entries(KS.cart).reduce((s, [id, n]) => s + n * ((kProduct(id) || {}).price || 0), 0); }
function kCanOrder() {
    const d = KS.data;
    return d.open && (!d.requireStaff || d.staff > 0);
}

function renderKiosk() {
    const d = KS.data;
    if (!d) return;
    document.documentElement.style.setProperty('--accent-soft', hexToRgba(d.color, 0.16));
    const cats = d.categories || [];
    if (!cats.find((c) => c.key === KS.cat)) KS.cat = cats.length ? cats[0].key : null;
    const head = `<header class="brandbar">
            <img src="logo.png" class="crest" alt="">
            <div class="brand-txt"><div class="eyebrow">Elyzea · Borne de commande</div><div class="title">${esc(d.label)}</div>
                <div class="sub">${d.open ? `<span class="status ${d.staff > 0 ? 'on' : 'off'}">● ${d.staff} employé${d.staff > 1 ? 's' : ''} en service</span>` : '<span class="status off">Fermé</span>'}
                    <span class="status">Commande · paiement · préparation devant vous</span></div></div>
            <button class="icon-btn" data-kclose title="Fermer (Échap)">✕</button></header>`;
    if (KS.view === 'done' && KS.last) {
        $('#kioskBox').innerHTML = `${head}<div class="k-done"><div>
            <div class="check">✓</div><div class="eyebrow">Commande envoyée en cuisine</div>
            <div class="big gold-text">n°${esc(KS.last.number)}</div>
            <p class="lead">Payé : <b>${money(KS.last.total)}</b>. Un employé va la préparer devant toi.<br>Reste près du comptoir pour la recevoir directement.</p>
            <div class="row" style="justify-content:center"><button class="btn" data-kclose>Fermer</button><button class="btn primary" data-knew>Nouvelle commande</button></div>
            ${mineBlock()}</div></div>`;
        return;
    }
    const list = (d.products || []).filter((p) => p.category === KS.cat);
    const cat = cats.find((c) => c.key === KS.cat) || {};
    const lines = Object.entries(KS.cart).filter(([, n]) => n > 0);
    const pay = d.payment === 'both'
        ? `<div class="k-pay"><button class="${KS.method === 'bank' ? 'on' : ''}" data-kpay="bank">🏦 Banque</button><button class="${KS.method === 'cash' ? 'on' : ''}" data-kpay="cash">💵 Liquide</button></div>`
        : `<p class="k-note" style="margin:0 0 10px">Paiement : ${d.payment === 'cash' ? '💵 liquide' : '🏦 banque'}</p>`;
    $('#kioskBox').innerHTML = `${head}<div class="k-body">
        <nav class="k-cats">${cats.map((c) => `<button class="k-cat ${c.key === KS.cat ? 'active' : ''}" data-kcat="${esc(c.key)}">
            <span class="ico">${esc(c.icon || '🍔')}</span><b>${esc(c.label)}</b><small>${(d.products || []).filter((p) => p.category === c.key).length} produits</small></button>`).join('')}</nav>
        <section class="k-products">
            ${!d.open ? '<div class="k-warn">La borne est fermée pour le moment.</div>' : d.requireStaff && d.staff === 0 ? '<div class="k-warn">Aucun employé en service : la commande est impossible pour le moment.</div>' : ''}
            <div class="k-head"><h2>${esc(cat.icon || '')} ${esc(cat.label || '')}</h2><span class="muted">${list.length} produit${list.length > 1 ? 's' : ''}</span></div>
            <div class="k-grid">${list.map((p, i) => `<article class="k-card ${KS.cart[p.id] ? 'in' : ''}" style="animation-delay:${i * 40}ms">
                ${KS.cart[p.id] ? `<span class="k-badge">${KS.cart[p.id]}</span>` : ''}
                <div class="k-vis">${Viz.product(p)}</div>
                <h3>${esc(p.label)}</h3><p>${esc(p.description || '')}</p>
                <div class="k-foot"><span class="k-price gold-text">${money(p.price)}</span>
                    <button class="k-add" data-kadd="${esc(p.id)}" ${kCount() >= d.maxItems ? 'disabled' : ''} title="Ajouter">+</button></div></article>`).join('') || '<div class="empty">Aucun produit dans cette catégorie.</div>'}</div>
        </section>
        <aside class="k-cart"><h2>🧾 Ma commande</h2>
            <div class="k-lines">${lines.map(([id, n]) => { const p = kProduct(id) || {}; return `<div class="k-line"><b>${esc(p.label)}</b><span class="k-lp">${money(n * (p.price || 0))}</span>
                <span class="k-step"><button data-kq="${esc(id)}" data-d="-1">−</button><b>${n}</b><button data-kq="${esc(id)}" data-d="1" ${kCount() >= d.maxItems ? 'disabled' : ''}>+</button></span>
                <small class="muted" style="text-align:right">${money(p.price)} pièce</small></div>`; }).join('') || '<div class="empty">Choisis tes produits à gauche.</div>'}</div>
            <div class="k-total"><span>Total · ${kCount()}/${d.maxItems} articles</span><b class="gold-text">${money(kTotal())}</b></div>
            ${pay}
            <button class="btn primary k-go" data-korder ${lines.length && kCanOrder() ? '' : 'disabled'}>Commander et payer</button>
            <p class="k-note">Paiement immédiat. Remboursé automatiquement si la commande n'est pas préparée sous ${d.orderTimeout || 15} min.</p>
            ${mineBlock()}
        </aside></div>`;
}

function mineBlock() {
    const mine = (KS.data && KS.data.mine) || [];
    if (!mine.length) return '';
    return `<div class="k-mine"><h4>Mes commandes</h4>${mine.map((o) => `<div class="k-order"><span class="num">n°${esc(o.number)}</span>
        <span class="grow"><span class="st ${o.status}">${STATUS[o.status] || o.status}</span>${o.employee && o.status === 'preparing' ? ` <small class="muted">${esc(o.employee)}</small>` : ''}</span>
        ${o.status === 'pending' ? `<button class="btn small danger" data-kcancel="${o.id}">Annuler</button>` : ''}</div>`).join('')}</div>`;
}

function closeKiosk() {
    $('#kiosk').classList.add('hidden');
    post('kioskClose');
}

$('#kiosk').addEventListener('click', (e) => {
    let n;
    if (e.target.closest('[data-kclose]')) return closeKiosk();
    if (e.target.closest('[data-knew]')) { KS.view = 'menu'; KS.cart = {}; return renderKiosk(); }
    if ((n = e.target.closest('[data-kcat]'))) { KS.cat = n.dataset.kcat; return renderKiosk(); }
    if ((n = e.target.closest('[data-kpay]'))) { KS.method = n.dataset.kpay; return renderKiosk(); }
    if ((n = e.target.closest('[data-kadd]')) && !n.disabled) {
        if (kCount() < KS.data.maxItems) KS.cart[n.dataset.kadd] = (KS.cart[n.dataset.kadd] || 0) + 1;
        return renderKiosk();
    }
    if ((n = e.target.closest('[data-kq]')) && !n.disabled) {
        const id = n.dataset.kq, dlt = Number(n.dataset.d);
        if (dlt > 0 && kCount() >= KS.data.maxItems) return;
        KS.cart[id] = Math.max(0, (KS.cart[id] || 0) + dlt);
        if (!KS.cart[id]) delete KS.cart[id];
        return renderKiosk();
    }
    if ((n = e.target.closest('[data-kcancel]'))) return post('kioskCancel', { id: Number(n.dataset.kcancel) });
    if ((n = e.target.closest('[data-korder]')) && !n.disabled) {
        n.disabled = true;
        const cart = Object.entries(KS.cart).filter(([, q]) => q > 0).map(([id, qty]) => ({ id, qty }));
        post('kioskOrder', { cart, method: KS.method });
        setTimeout(() => { if (KS.view === 'menu' && !$('#kiosk').classList.contains('hidden')) renderKiosk(); }, 2500);
    }
});

/* =========================================================
   Préparation (employé) et suivi (client)
   ========================================================= */
const PREP = { steps: [], index: 0 };
const WATCH = { steps: [], index: 0, timer: null };

function prepHtml(o, steps, index, watch) {
    const st = steps[index - 1];
    return `<div class="p-top"><div><div class="eyebrow">${watch ? 'Votre commande' : 'Préparation'} · ${esc(watch ? o.employee || '' : o.name || '')}</div>
            <div class="p-num gold-text">n°${esc(o.number)}</div></div><span class="status on">● ${index}/${steps.length}</span></div>
        <div class="p-stage" id="${watch ? 'wStage' : 'pStage'}">${st ? Viz.product(st, { hidden: true }) : ''}</div>
        <div class="p-cur">${st ? esc(st.label) : ''}</div>
        <div class="p-layer" id="${watch ? 'wLayer' : 'pLayer'}"></div>
        <div class="p-list">${steps.map((s, i) => `<div class="p-item ${i + 1 < index ? 'ok' : i + 1 === index ? 'cur' : ''}"><i>${i + 1 < index ? '✓' : i + 1}</i>${esc(s.label)}</div>`).join('')}</div>`;
}

// Nom de la couche posée, au rythme de l'assemblage
function layerTicker(el, st, duration) {
    if (!el || !st || !st.layers || !st.layers.length) { if (el) el.textContent = st && st.visual ? 'Service de la boisson…' : 'Mise en place…'; return; }
    const step = Math.max(120, (duration * 0.9) / st.layers.length);
    st.layers.forEach((l, i) => setTimeout(() => { el.textContent = `+ ${Viz.LABELS[l] || l}`; }, i * step));
}

function prepStep(index, duration) {
    PREP.index = index;
    const box = $('#assemble');
    box.innerHTML = prepHtml(PREP.order, PREP.steps, index, false);
    box.classList.remove('hidden');
    Viz.play($('#pStage'), duration);
    layerTicker($('#pLayer'), PREP.steps[index - 1], duration);
}

function prepEnd(ok) {
    const box = $('#assemble');
    if (!ok) { box.classList.add('hidden'); return; }
    Viz.finish($('#pStage'));
    box.querySelectorAll('.p-item').forEach((el) => { el.classList.remove('cur'); el.classList.add('ok'); const i = el.querySelector('i'); if (i) i.textContent = '✓'; });
    box.insertAdjacentHTML('beforeend', '<div class="p-done gold-text">Commande prête ✓</div>');
    setTimeout(() => box.classList.add('hidden'), 3500);
}

function watchStep(index) {
    WATCH.index = index;
    const st = WATCH.steps[index];
    const box = $('#watch');
    // index = article terminé : affiche le suivant en cours d'assemblage
    box.innerHTML = prepHtml(WATCH.order, WATCH.steps, Math.min(index + 1, WATCH.steps.length), true);
    box.classList.remove('hidden');
    if (st) {
        const dur = (Number(st.time) || 5) * 1000;
        Viz.play($('#wStage'), dur);
        layerTicker($('#wLayer'), st, dur);
    } else Viz.finish($('#wStage'));
}

function watchEnd(ok) {
    const box = $('#watch');
    if (box.classList.contains('hidden')) return;
    if (!ok) { box.classList.add('hidden'); return; }
    Viz.finish($('#wStage'));
    box.querySelectorAll('.p-item').forEach((el) => { el.classList.remove('cur'); el.classList.add('ok'); const i = el.querySelector('i'); if (i) i.textContent = '✓'; });
    box.insertAdjacentHTML('beforeend', '<div class="p-done gold-text">Votre commande est prête ✓</div>');
    setTimeout(() => box.classList.add('hidden'), 5000);
}

function toast(o) {
    const el = document.createElement('div');
    el.className = 'toast';
    el.innerHTML = `<span class="t-ico">🍔</span><div><b>Nouvelle commande n°${esc(o.number)}</b><span>${o.count} article${o.count > 1 ? 's' : ''} · ${esc(o.name)}</span></div>`;
    $('#toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 450); }, 6000);
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#kiosk').classList.contains('hidden')) closeKiosk();
});

window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'kiosk':
            if (!KS.data || KS.data.company !== m.data.company) { KS.cart = {}; KS.cat = null; }
            KS.data = m.data;
            KS.view = 'menu';
            if (m.data.payment !== 'both') KS.method = m.data.payment;
            $('#kiosk').classList.remove('hidden');
            return renderKiosk();
        case 'kioskClose': $('#kiosk').classList.add('hidden'); return;
        case 'kioskOrdered':
            KS.last = m.data; KS.cart = {}; KS.view = 'done';
            if (KS.data) KS.data.mine = m.data.mine || [];
            return renderKiosk();
        case 'myOrders':
            if (KS.data) { KS.data.mine = m.list || []; if (!$('#kiosk').classList.contains('hidden')) renderKiosk(); }
            return;
        case 'assemble':
            PREP.order = m.data; PREP.steps = m.data.steps || []; PREP.index = 0;
            return;
        case 'assembleStep': return prepStep(m.index, m.duration);
        case 'assembleEnd': return prepEnd(m.ok);
        case 'watch':
            WATCH.order = m.data; WATCH.steps = m.data.steps || [];
            return watchStep(0);
        case 'watchStep': return watchStep(m.index);
        case 'watchEnd': return watchEnd(m.ok);
        case 'newOrder': return toast(m.data);
    }
});
