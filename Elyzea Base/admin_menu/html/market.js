/* =========================================================
   SUPÉRETTE - INTERFACE JOUEUR
   Rayons (catégories), recherche, fiches produits avec image,
   quantités, panier, paiement liquide / banque.
   ========================================================= */
(() => {
    const root = document.getElementById('market');
    if (!root) return;

    const M = { open: false };
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const send = (ep, body = {}) => fetch(`https://${RES}/${ep}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    }).catch(() => {});

    const ICONS = { boissons: '🥤', nourriture: '🍔', snacks: '🍫', 'hygiène': '🧴', hygiene: '🧴', utilitaires: '🔦',
        tabac: '🚬', divers: '📦', alcool: '🍾', 'électronique': '📱', outils: '🔧', soins: '🩹', 'fruits et légumes': '🥕',
        pistolets: '🔫', mitraillettes: '🔫', 'fusils à pompe': '💥', "fusils d'assaut": '🎯', 'fusils de précision': '🔭',
        'corps à corps': '🔪', munitions: '🧨', accessoires: '🔦', armes: '🔫' };
    const isGun = () => M.shop && M.shop.kind === 'gunshop';
    const TYPE_TAG = { weapon: 'Arme', ammo: 'Munitions', item: 'Accessoire' };
    const iconOf = (cat) => ICONS[String(cat || '').toLowerCase()] || '🛒';
    const img = (item) => (M.shop.image || '').replace('%s', encodeURIComponent(item));

    function categories() {
        const order = M.shop.categories || [];
        const set = [...new Set(M.shop.items.map((i) => i.cat))];
        set.sort((a, b) => {
            const ia = order.indexOf(a), ib = order.indexOf(b);
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b, 'fr');
        });
        return set;
    }
    const byIdx = (i) => M.shop.items.find((x) => x.i === i);

    function frame() {
        const sub = isGun()
            ? `Armurerie · ${M.shop.items.length} articles${M.shop.licence ? ' · 🪪 permis de port d\'arme exigé' : ''}${M.shop.trial ? ` · 🎯 essai ${M.shop.trialDuration} s au stand de tir` : ''}`
            : `Ouvert 24h/24 · ${M.shop.items.length} produits`;
        root.innerHTML = `
            <div class="mk-backdrop"></div>
            <div class="mk-app ${isGun() ? 'gun' : ''}">
                <header class="mk-head">
                    <img src="logo.png" alt="">
                    <div class="mk-title"><h1>${esc(M.shop.name)}</h1><p>${sub}</p></div>
                    <div class="mk-wallet" id="mk-wallet"></div>
                    <button class="sb-close" id="mk-close" title="Fermer (Échap)">✕</button>
                </header>
                <div class="mk-body">
                    <nav class="mk-cats" id="mk-cats"></nav>
                    <section class="mk-main">
                        ${isGun() && M.shop.licence && !M.shop.hasLicence ? '<div class="mk-alert">🪪 Tu n\'as pas de permis de port d\'arme : tu peux regarder, mais pas acheter ni essayer.</div>' : ''}
                        <div class="mk-searchbar"><input class="input" id="mk-search" placeholder="${isGun() ? 'Chercher une arme, des munitions…' : 'Chercher un produit…'}" value="${esc(M.search)}"></div>
                        <div class="mk-grid" id="mk-grid"></div>
                    </section>
                    <aside class="mk-cart">
                        <h2>Panier <span id="mk-count"></span></h2>
                        <div class="mk-lines" id="mk-lines"></div>
                        <div class="mk-pay" id="mk-pay"></div>
                    </aside>
                </div>
            </div>`;
        drawWallet(); drawCats(); drawGrid(); drawCart();
        setTimeout(() => { const s = document.getElementById('mk-search'); if (s) s.focus(); }, 40);
    }

    function drawWallet() {
        const w = M.shop.wallet || {};
        document.getElementById('mk-wallet').innerHTML = Object.entries(w).map(([k, v]) =>
            `<span><i>${k === 'bank' ? '🏦' : k === 'cash' ? '💵' : '👜'}</i>${money(v)}</span>`).join('');
    }

    function drawCats() {
        const cats = categories();
        document.getElementById('mk-cats').innerHTML = `
            <button class="mk-cat ${M.cat === 'all' ? 'on' : ''}" data-cat="all"><span>🛒</span><b>Tout</b><em>${M.shop.items.length}</em></button>
            ${cats.map((c) => `<button class="mk-cat ${M.cat === c ? 'on' : ''}" data-cat="${esc(c)}">
                <span>${iconOf(c)}</span><b>${esc(c)}</b><em>${M.shop.items.filter((i) => i.cat === c).length}</em></button>`).join('')}`;
    }

    function visible() {
        const q = M.search.trim().toLowerCase();
        return M.shop.items.filter((i) => (M.cat === 'all' || i.cat === M.cat)
            && (!q || i.label.toLowerCase().includes(q) || i.item.toLowerCase().includes(q)));
    }

    function productCard(p) {
        const q = M.cart[p.i] || 0;
        return `<div class="mk-card ${q ? 'in' : ''}" data-i="${p.i}">
            <div class="mk-img"><img src="${img(p.item)}" alt="" loading="lazy" data-fallback="${iconOf(p.cat)}"></div>
            ${isGun() ? `<i class="mk-type t-${p.type}">${TYPE_TAG[p.type] || ''}${p.type !== 'weapon' && p.amount > 1 ? ` · lot de ${p.amount}` : ''}</i>` : ''}
            <div class="mk-info"><b>${esc(p.label)}</b><span>${p.price ? money(p.price) : 'Gratuit'}</span></div>
            ${isGun() && p.type === 'weapon' && M.shop.trial ? `<button class="mk-try" data-try="${p.i}" ${M.shop.licence && !M.shop.hasLicence ? 'disabled' : ''}>🎯 Essayer ${M.shop.trialDuration} s</button>` : ''}
            ${q ? `<div class="mk-step"><button data-dec="${p.i}">−</button><input type="number" min="0" max="${p.max}" value="${q}" data-qty="${p.i}"><button data-inc="${p.i}" ${q >= p.max ? 'disabled' : ''}>+</button></div>`
                : `<button class="mk-add" data-inc="${p.i}">Ajouter</button>`}
        </div>`;
    }

    function drawGrid() {
        const list = visible();
        const g = document.getElementById('mk-grid');
        g.innerHTML = list.length ? list.map(productCard).join('')
            : `<div class="mk-empty">Aucun produit ${M.search ? `ne correspond à « ${esc(M.search)} »` : 'dans ce rayon'}.</div>`;
        g.querySelectorAll('img[data-fallback]').forEach((im) => {
            im.addEventListener('error', () => { im.replaceWith(Object.assign(document.createElement('i'), { textContent: im.dataset.fallback, className: 'mk-emoji' })); }, { once: true });
        });
    }
    function redrawCard(i) {
        const el = document.querySelector(`#mk-grid [data-i="${i}"]`);
        const p = byIdx(i);
        if (!el || !p) return;
        const tmp = document.createElement('div');
        tmp.innerHTML = productCard(p);
        const fresh = tmp.firstElementChild;
        const oldImg = el.querySelector('.mk-img');
        fresh.querySelector('.mk-img').replaceWith(oldImg);   // garde l'image déjà chargée
        el.replaceWith(fresh);
    }

    const total = () => Object.entries(M.cart).reduce((s, [i, q]) => s + (byIdx(Number(i)) || {}).price * q, 0);

    function drawCart() {
        const keys = Object.keys(M.cart).map(Number);
        const n = keys.reduce((s, i) => s + M.cart[i], 0);
        document.getElementById('mk-count').textContent = n ? `(${n})` : '';
        document.getElementById('mk-lines').innerHTML = keys.length ? keys.map((i) => {
            const p = byIdx(i);
            return `<div class="mk-line"><span class="mk-lq">${M.cart[i]}×</span><b>${esc(p.label)}${isGun() && p.type !== 'weapon' && p.amount > 1 ? ` <small>(${M.cart[i] * p.amount})</small>` : ''}</b>
                <span class="mk-lp">${money(p.price * M.cart[i])}</span><button class="bb-del" data-del="${i}" title="Retirer">✕</button></div>`;
        }).join('') : '<div class="mk-empty small">Ton panier est vide. Clique sur « Ajouter » sous un produit.</div>';

        const sum = total();
        const w = M.shop.wallet || {};
        const method = M.shop.payChoice ? M.method : M.shop.payment;
        const have = w[method] ?? w[Object.keys(w)[0]];
        const short = keys.length && sum > 0 && have !== undefined && have < sum;
        document.getElementById('mk-pay').innerHTML = `
            <div class="bb-total"><span>Total</span><b>${money(sum)}</b></div>
            ${M.shop.payChoice ? `<div class="bb-modes">
                <button class="bb-mode ${M.method === 'cash' ? 'on' : ''}" data-method="cash">💵 Liquide</button>
                <button class="bb-mode ${M.method === 'bank' ? 'on' : ''}" data-method="bank">🏦 Carte</button></div>`
                : `<p class="bb-note">Paiement : ${M.shop.payment === 'bank' ? 'carte bancaire' : M.shop.payment === 'item' ? esc(M.shop.paymentLabel || 'objet') : 'argent liquide'}</p>`}
            ${short ? `<p class="bb-warn">Il te manque ${money(sum - have)}.</p>` : ''}
            ${M.error ? `<p class="bb-warn bb-shake">${esc(M.error)}</p>` : ''}
            ${M.done ? `<p class="bb-ok">✓ ${esc(M.done)}</p>` : ''}
            <button class="btn primary big bb-go" id="mk-go" ${!keys.length || M.paying || (isGun() && M.shop.licence && !M.shop.hasLicence) ? 'disabled' : ''}>
                ${M.paying ? 'Paiement en cours…' : sum > 0 ? `Payer ${money(sum)}` : 'Prendre'}</button>
            <button class="btn bb-reset" id="mk-reset" ${!keys.length || M.paying ? 'disabled' : ''}>Vider le panier</button>`;
    }

    function setQty(i, q) {
        const p = byIdx(i);
        if (!p) return;
        q = Math.max(0, Math.min(p.max, Math.floor(Number(q) || 0)));
        if (q) M.cart[i] = q; else delete M.cart[i];
        M.error = null; M.done = null;
        redrawCard(i); drawCart();
    }

    root.addEventListener('click', (e) => {
        let n;
        if ((n = e.target.closest('[data-cat]'))) { M.cat = n.dataset.cat; drawCats(); return drawGrid(); }
        if ((n = e.target.closest('[data-inc]'))) { const i = Number(n.dataset.inc); return setQty(i, (M.cart[i] || 0) + 1); }
        if ((n = e.target.closest('[data-dec]'))) { const i = Number(n.dataset.dec); return setQty(i, (M.cart[i] || 0) - 1); }
        if ((n = e.target.closest('[data-del]'))) return setQty(Number(n.dataset.del), 0);
        if ((n = e.target.closest('[data-method]'))) { M.method = n.dataset.method; M.error = null; return drawCart(); }
        if ((n = e.target.closest('[data-try]'))) return send('market_trial', { i: Number(n.dataset.try) });
        if (e.target.closest('#mk-reset')) { const ks = Object.keys(M.cart); M.cart = {}; ks.forEach((k) => redrawCard(Number(k))); return drawCart(); }
        if (e.target.closest('#mk-go')) {
            if (!Object.keys(M.cart).length || M.paying) return;
            M.paying = true; M.error = null; M.done = null; drawCart();
            return send('market_buy', { cart: M.cart, method: M.method });
        }
        if (e.target.closest('#mk-close') || e.target.classList.contains('mk-backdrop')) return close();
    });
    root.addEventListener('input', (e) => {
        if (e.target.id === 'mk-search') { M.search = e.target.value; clearTimeout(M.st); M.st = setTimeout(drawGrid, 100); }
    });
    root.addEventListener('change', (e) => {
        if (e.target.dataset.qty) setQty(Number(e.target.dataset.qty), e.target.value);
    });
    document.addEventListener('keydown', (e) => {
        if (M.open && e.key === 'Escape') { e.preventDefault(); close(); }
    });

    function close() { if (!M.paying) send('market_close'); }

    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (!m || m.action !== 'market') return;
        if (m.event) {
            M.paying = false;
            if (m.wallet) { M.shop.wallet = m.wallet; drawWallet(); }
            if (m.event === 'paid') {
                M.done = m.msg; M.error = null;
                const ks = Object.keys(M.cart); M.cart = {}; ks.forEach((k) => redrawCard(Number(k)));
            } else M.error = m.msg;
            return M.open && drawCart();
        }
        if (m.open) {
            Object.assign(M, {
                open: true, shop: m.shop, cat: 'all', search: '', cart: {}, paying: false, error: null, done: null,
                method: (m.shop.wallet && m.shop.wallet.cash === undefined) ? 'bank' : 'cash',
            });
            frame();
            root.classList.remove('hidden');
        } else {
            M.open = false;
            root.classList.add('hidden');
            root.innerHTML = '';
        }
    });
})();
