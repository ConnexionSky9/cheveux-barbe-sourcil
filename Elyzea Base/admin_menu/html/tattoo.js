/* =========================================================
   TATOUEUR - INTERFACE JOUEUR
   Silhouette cliquable (zones du corps), catégories (collections),
   recherche, survol = aperçu, clic = panier, retrait au laser.
   Même charte que le coiffeur (classes .bb-*).
   ========================================================= */
(() => {
    const root = document.getElementById('tattoo');
    if (!root) return;

    const T = { open: false, cache: {} };
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const send = (ep, body = {}) => fetch(`https://${RES}/${ep}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body),
    }).catch(() => {});

    // Silhouette (vue de face : le bras GAUCHE du personnage est à DROITE de l'image)
    const BODY = {
        ZONE_HEAD: '<circle cx="60" cy="22" r="15"/><rect x="53" y="36" width="14" height="8" rx="3"/>',
        ZONE_TORSO: '<path d="M36 46 Q60 40 84 46 L82 104 Q60 110 38 104 Z"/>',
        ZONE_RIGHT_ARM: '<path d="M34 47 L24 52 L14 104 L22 107 L34 64 Z"/>',
        ZONE_LEFT_ARM: '<path d="M86 47 L96 52 L106 104 L98 107 L86 64 Z"/>',
        ZONE_RIGHT_LEG: '<path d="M39 107 L59 111 L56 192 L44 192 Z"/>',
        ZONE_LEFT_LEG: '<path d="M61 111 L81 107 L76 192 L64 192 Z"/>',
    };

    const zoneById = (id) => T.zones.find((z) => z.id === id) || {};
    const priceOfZone = (zone) => T.shop.prices[zoneById(zone).price] ?? 0;
    const entry = (id) => T.byId[id];

    /* ---------- Squelette ---------- */
    function frame() {
        const w = T.shop.wallet || {};
        const wallet = Object.entries(w).map(([k, v]) => `<span class="bb-w"><i>${k === 'bank' ? '🏦' : k === 'cash' ? '💵' : '👜'}</i>${money(v)}</span>`).join('');
        root.innerHTML = `
            <div class="bb-stage" id="tt-stage"></div>
            <aside class="bb-panel bb-left tt-left">
                <div class="bb-pole tt-ink" aria-hidden="true"></div>
                <header class="bb-head">
                    <img src="logo.png" alt="">
                    <div class="bb-title"><h1>${esc(T.shop.name)}</h1><p>${wallet || 'Salon de tatouage'}</p></div>
                </header>
                <div class="tt-top">
                    <svg class="tt-body" viewBox="0 0 120 196" id="tt-body">
                        ${Object.entries(BODY).map(([z, d]) => `<g class="tt-z" data-zone="${z}">${d}</g>`).join('')}
                    </svg>
                    <div class="tt-zones" id="tt-zones"></div>
                </div>
                <div class="bb-modes" id="tt-modes"></div>
                <div class="tt-filters" id="tt-filters"></div>
                <div class="bb-list" id="tt-list"></div>
            </aside>
            <div class="bb-hover hidden" id="tt-hover"></div>
            <div class="bb-ctrl">
                <button class="bb-rot" data-spin="-1" title="Tourner (←)">⟲</button>
                <button class="bb-cam" data-view="front">Face</button>
                <button class="bb-cam" data-view="back">Dos</button>
                <button class="bb-cam" data-view="full">Vue complète</button>
                <button class="bb-rot" data-spin="1" title="Tourner (→)">⟳</button>
                <small>Glisse sur ton personnage pour le tourner, molette pour zoomer</small>
            </div>
            <aside class="bb-panel bb-right">
                <header class="bb-cart-head"><h2>Panier</h2><span id="tt-count"></span>
                    <button class="sb-close" id="tt-close" title="Quitter sans payer (Échap)">✕</button></header>
                <div class="bb-cart" id="tt-cart"></div>
                <div class="bb-pay" id="tt-pay"></div>
            </aside>`;
        drawZones();
        drawModes();
        drawFilters();
        drawList();
        drawCart();
    }

    /* ---------- Zones ---------- */
    function countIn(zone) { return T.list.filter((e) => e[2] === zone).length; }
    function drawZones() {
        document.querySelectorAll('#tt-body .tt-z').forEach((g) => {
            g.classList.toggle('on', g.dataset.zone === T.zone);
            g.classList.toggle('has', cartZones().has(g.dataset.zone));
        });
        document.getElementById('tt-zones').innerHTML = T.zones.map((z) => `
            <button class="tt-zone ${z.id === T.zone ? 'on' : ''}" data-zone="${z.id}">
                <span>${esc(z.icon)}</span><b>${esc(z.label)}</b><em>${countIn(z.id)}</em></button>`).join('');
    }
    function cartZones() {
        const s = new Set();
        T.adds.forEach((id) => { const e = entry(id); if (e) s.add(e[2]); });
        return s;
    }
    function selectZone(z) {
        T.zone = z; T.coll = 'all';
        const cam = zoneById(z).cam || 'full';
        T.back = false;
        send('tattoo_cam', { mode: cam, back: false });
        drawZones(); drawFilters(); drawList();
    }

    /* ---------- Modes : catalogue / mes tatouages ---------- */
    function drawModes() {
        document.getElementById('tt-modes').innerHTML = `
            <button class="bb-mode ${T.mode === 'shop' ? 'on' : ''}" data-mode="shop">Catalogue</button>
            <button class="bb-mode ${T.mode === 'mine' ? 'on' : ''}" data-mode="mine">Mes tatouages (${T.owned.size})</button>`;
    }

    /* ---------- Filtres : catégories + recherche ---------- */
    function drawFilters() {
        const f = document.getElementById('tt-filters');
        if (T.mode === 'mine') { f.innerHTML = ''; return; }
        const colls = new Map();
        T.list.forEach((e) => { if (e[2] === T.zone) colls.set(e[3], e[4]); });
        const opts = [...colls.entries()].sort((a, b) => a[1].localeCompare(b[1], 'fr'));
        f.innerHTML = `
            <select class="input tt-coll" id="tt-coll">
                <option value="all">Toutes les catégories (${countIn(T.zone)})</option>
                ${opts.map(([k, l]) => `<option value="${esc(k)}" ${T.coll === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}
            </select>
            <input class="input" id="tt-search" placeholder="Chercher un tatouage…" value="${esc(T.search)}">
            <div class="bb-price">${esc(zoneById(T.zone).label || '')} <b>${priceOfZone(T.zone) ? money(priceOfZone(T.zone)) : 'Gratuit'}</b></div>`;
    }

    /* ---------- Liste ---------- */
    function visible() {
        if (T.mode === 'mine') return [...T.owned].map(entry).filter(Boolean);
        const q = T.search.trim().toLowerCase();
        return T.list.filter((e) => e[2] === T.zone && (T.coll === 'all' || e[3] === T.coll)
            && (!q || e[1].toLowerCase().includes(q) || e[4].toLowerCase().includes(q)));
    }
    function stateOf(id) {
        if (T.owned.has(id)) return T.removes.has(id) ? 'removing' : 'owned';
        return T.adds.has(id) ? 'sel' : '';
    }
    function card(e) {
        const st = stateOf(e[0]);
        const owned = st === 'owned' || st === 'removing';
        const tag = st === 'removing' ? '<i class="tt-tag rm">À retirer</i>' : owned ? '<i class="tt-tag own">Porté</i>' : st === 'sel' ? '<i class="tt-tag sel">Au panier</i>' : '';
        const price = owned ? (T.shop.removal ? `Retrait ${money(T.shop.prices.remove)}` : 'Déjà tatoué') : money(priceOfZone(e[2]));
        return `<button class="tt-card ${st}" data-id="${e[0]}" ${owned && !T.shop.removal ? 'disabled' : ''}>
            <span class="tt-ink-dot"></span>
            <span class="tt-txt"><b>${esc(e[1])}</b><small>${esc(e[4])}${T.mode === 'mine' ? ` · ${esc(zoneById(e[2]).label || '')}` : ''}</small></span>
            <span class="tt-price">${price}</span>${tag}</button>`;
    }
    const PAGE = 120;
    function drawList() {
        const list = document.getElementById('tt-list');
        const items = visible();
        T.shown = Math.min(items.length, T.shown || PAGE);
        if (!items.length) {
            list.innerHTML = `<div class="bb-empty">${T.mode === 'mine' ? 'Tu n\'as encore aucun tatouage du catalogue.'
                : T.search ? `Aucun tatouage ne correspond à « ${esc(T.search)} ».` : 'Aucun tatouage dans cette zone pour ton personnage.'}</div>`;
            return;
        }
        list.innerHTML = `<div class="tt-grid">${items.slice(0, T.shown).map(card).join('')}</div>
            ${items.length > T.shown ? `<button class="btn tt-more" id="tt-more">Afficher plus (${items.length - T.shown} restants)</button>` : ''}`;
    }
    // Ne redessine que la carte modifiée (ou toutes si id absent)
    function markList(id) {
        const sel = id ? `#tt-list [data-id="${id}"]` : '#tt-list [data-id]';
        document.querySelectorAll(sel).forEach((el) => { el.outerHTML = card(entry(Number(el.dataset.id))); });
    }

    /* ---------- Panier ---------- */
    function total() {
        let s = 0;
        T.adds.forEach((id) => { const e = entry(id); if (e) s += priceOfZone(e[2]); });
        s += T.removes.size * (T.shop.prices.remove || 0);
        return s;
    }
    function drawCart() {
        const n = T.adds.size + T.removes.size;
        document.getElementById('tt-count').textContent = n ? `${n} prestation${n > 1 ? 's' : ''}` : '';
        const lines = [];
        T.adds.forEach((id) => {
            const e = entry(id); if (!e) return;
            lines.push(`<div class="bb-line"><span class="bb-ico">🖋️</span>
                <div class="bb-line-txt"><small>${esc(zoneById(e[2]).label || '')}</small><strong>${esc(e[1])}</strong></div>
                <span class="bb-line-price">${priceOfZone(e[2]) ? money(priceOfZone(e[2])) : 'Offert'}</span>
                <button class="bb-del" data-unadd="${id}" title="Retirer du panier">✕</button></div>`);
        });
        T.removes.forEach((id) => {
            const e = entry(id); if (!e) return;
            lines.push(`<div class="bb-line tt-rmline"><span class="bb-ico">✨</span>
                <div class="bb-line-txt"><small>Retrait au laser</small><strong>${esc(e[1])}</strong></div>
                <span class="bb-line-price">${T.shop.prices.remove ? money(T.shop.prices.remove) : 'Offert'}</span>
                <button class="bb-del" data-unrm="${id}" title="Annuler">✕</button></div>`);
        });
        document.getElementById('tt-cart').innerHTML = lines.join('')
            || '<div class="bb-empty">Choisis une zone sur la silhouette, survole un tatouage pour le voir sur toi, puis clique pour l\'ajouter.</div>';

        const sum = total();
        const w = T.shop.wallet || {};
        const method = T.shop.payChoice ? T.method : T.shop.payment;
        const have = w[method] ?? w[Object.keys(w)[0]];
        const short = n && sum > 0 && have !== undefined && have < sum;
        document.getElementById('tt-pay').innerHTML = `
            <div class="bb-total"><span>Total</span><b>${money(sum)}</b></div>
            ${T.shop.payChoice ? `<div class="bb-modes">
                <button class="bb-mode ${T.method === 'cash' ? 'on' : ''}" data-method="cash">💵 Liquide</button>
                <button class="bb-mode ${T.method === 'bank' ? 'on' : ''}" data-method="bank">🏦 Banque</button></div>`
                : `<p class="bb-note">Paiement : ${T.shop.payment === 'bank' ? 'banque' : T.shop.payment === 'item' ? esc(T.shop.paymentLabel || 'objet') : 'argent liquide'}</p>`}
            ${short ? `<p class="bb-warn">Il te manque ${money(sum - have)}.</p>` : ''}
            ${T.error ? `<p class="bb-warn bb-shake">${esc(T.error)}</p>` : ''}
            ${T.done ? `<p class="bb-ok">✓ ${esc(T.done)}</p>` : ''}
            <button class="btn primary big bb-go" id="tt-go" ${!n || T.paying || T.done ? 'disabled' : ''}>
                ${T.paying ? 'Paiement en cours…' : sum > 0 ? `Payer ${money(sum)}` : 'Valider'}</button>
            <button class="btn bb-reset" id="tt-reset" ${!n || T.paying ? 'disabled' : ''}>Vider le panier</button>`;
        drawZones();
    }

    /* ---------- Aperçu au survol ---------- */
    let want = null, sent = null, timer = 0, last = 0;
    function preview(id) {
        want = id;
        const hv = document.getElementById('tt-hover');
        const e = id ? entry(id) : null;
        if (e) { hv.textContent = `${zoneById(e[2]).label || ''} · ${e[1]}`; hv.classList.remove('hidden'); } else hv.classList.add('hidden');
        if (timer) return;
        timer = setTimeout(() => {
            timer = 0;
            if (want === sent) return;
            sent = want; last = performance.now();
            send('tattoo_preview', { id: want });
        }, Math.max(0, 60 - (performance.now() - last)));
    }

    root.addEventListener('mouseover', (e) => {
        const c = e.target.closest('#tt-list [data-id]');
        if (!c || T.paying) return;
        const id = Number(c.dataset.id);
        if (T.owned.has(id)) return preview(null);
        preview(id);
    });
    root.addEventListener('mouseout', (e) => {
        const list = document.getElementById('tt-list');
        if (!list || !e.target.closest('#tt-list')) return;
        if (e.relatedTarget && list.contains(e.relatedTarget)) return;
        preview(null);
    });

    function toggle(id) {
        T.error = null;
        if (T.owned.has(id)) {
            if (!T.shop.removal) return;
            const on = !T.removes.has(id);
            if (on) T.removes.add(id); else T.removes.delete(id);
            send('tattoo_remove', { id, on });
        } else {
            const on = !T.adds.has(id);
            if (on) T.adds.add(id); else T.adds.delete(id);
            send('tattoo_add', { id, on });
        }
        sent = null;
        markList(id); drawCart(); drawModes();
    }

    root.addEventListener('click', (e) => {
        let n;
        if ((n = e.target.closest('#tt-list [data-id]'))) return toggle(Number(n.dataset.id));
        if ((n = e.target.closest('[data-zone]'))) { T.mode = 'shop'; T.shown = PAGE; drawModes(); return selectZone(n.dataset.zone); }
        if ((n = e.target.closest('[data-mode]'))) { T.mode = n.dataset.mode; T.shown = PAGE; drawModes(); drawFilters(); return drawList(); }
        if ((n = e.target.closest('[data-view]'))) {
            const v = n.dataset.view;
            if (v === 'full') return send('tattoo_cam', { mode: 'full' });
            T.back = v === 'back';
            return send('tattoo_cam', { mode: zoneById(T.zone).cam || 'full', back: T.back });
        }
        if ((n = e.target.closest('[data-method]'))) { T.method = n.dataset.method; T.error = null; return drawCart(); }
        if ((n = e.target.closest('[data-unadd]'))) return toggle(Number(n.dataset.unadd));
        if ((n = e.target.closest('[data-unrm]'))) return toggle(Number(n.dataset.unrm));
        if (e.target.closest('#tt-more')) { T.shown += PAGE; return drawList(); }
        if (e.target.closest('#tt-reset')) {
            T.adds.clear(); T.removes.clear(); T.error = null;
            send('tattoo_reset'); markList(); drawModes(); return drawCart();
        }
        if (e.target.closest('#tt-go')) {
            if (!(T.adds.size + T.removes.size) || T.paying) return;
            T.paying = true; T.error = null; drawCart();
            return send('tattoo_pay', { method: T.method });
        }
        if (e.target.closest('#tt-close')) return close();
    });

    root.addEventListener('input', (e) => {
        if (e.target.id === 'tt-search') { T.search = e.target.value; T.shown = PAGE; clearTimeout(T.st); T.st = setTimeout(drawList, 120); }
    });
    root.addEventListener('change', (e) => {
        if (e.target.id === 'tt-coll') { T.coll = e.target.value; T.shown = PAGE; drawList(); }
    });

    // Rotation / zoom
    let drag = false, acc = 0, rotT = 0;
    root.addEventListener('mousedown', (e) => {
        if (e.target.id === 'tt-stage') { drag = true; e.target.classList.add('grab'); }
        const s = e.target.closest('[data-spin]');
        if (s) send('tattoo_spin', { dir: Number(s.dataset.spin) });
    });
    window.addEventListener('mousemove', (e) => {
        if (!drag || !T.open) return;
        acc += e.movementX;
        if (!rotT) rotT = setTimeout(() => { rotT = 0; if (acc) { send('tattoo_rotate', { d: acc * 0.45 }); acc = 0; } }, 30);
    });
    window.addEventListener('mouseup', () => {
        if (!T.open) return;
        if (drag) { drag = false; const st = document.getElementById('tt-stage'); if (st) st.classList.remove('grab'); }
        send('tattoo_spin', { dir: 0 });
    });
    let wheelT = 0;
    root.addEventListener('wheel', (e) => {
        if (e.target.id !== 'tt-stage' || wheelT) return;
        wheelT = setTimeout(() => { wheelT = 0; }, 35);
        send('tattoo_zoom', { d: e.deltaY > 0 ? 1 : -1 });
    }, { passive: true });
    let spinKey = 0;
    document.addEventListener('keydown', (e) => {
        if (!T.open) return;
        if (e.key === 'Escape') { e.preventDefault(); return close(); }
        if (document.activeElement && ['INPUT', 'SELECT'].includes(document.activeElement.tagName)) return;
        const dir = e.key === 'ArrowLeft' ? -1 : e.key === 'ArrowRight' ? 1 : 0;
        if (dir && spinKey !== dir) { spinKey = dir; send('tattoo_spin', { dir }); }
    });
    document.addEventListener('keyup', (e) => {
        if (T.open && spinKey && ['ArrowLeft', 'ArrowRight'].includes(e.key)) { spinKey = 0; send('tattoo_spin', { dir: 0 }); }
    });

    function close() { if (!T.paying) send('tattoo_close'); }

    /* ---------- Messages Lua ---------- */
    window.addEventListener('message', (ev) => {
        const m = ev.data;
        if (!m || m.action !== 'tattoo') return;
        if (m.event === 'payfail') { T.paying = false; T.error = m.msg; return T.open && drawCart(); }
        if (m.event === 'paid') { T.paying = false; T.done = m.msg || 'Payé !'; return T.open && drawCart(); }
        if (m.open) {
            if (m.list) T.cache[m.sig] = m.list;
            const list = T.cache[m.sig] || [];
            const byId = {};
            list.forEach((e) => { byId[e[0]] = e; });
            const zones = (m.zones || []).filter((z) => list.some((e) => e[2] === z.id));
            Object.assign(T, {
                open: true, shop: m.shop, list, byId, zones: zones.length ? zones : (m.zones || []),
                owned: new Set((m.owned || []).filter((id) => byId[id])), adds: new Set(), removes: new Set(),
                zone: (zones[0] || {}).id, coll: 'all', search: '', mode: 'shop', shown: PAGE,
                method: (m.shop.wallet && m.shop.wallet.cash === undefined) ? 'bank' : 'cash',
                paying: false, error: null, done: null, back: false,
            });
            sent = null; want = null;
            frame();
            root.classList.remove('hidden');
            document.body.classList.add('barber-open');
            if (T.zone) send('tattoo_cam', { mode: zoneById(T.zone).cam || 'full' });
        } else {
            T.open = false;
            root.classList.add('hidden');
            root.innerHTML = '';
            document.body.classList.remove('barber-open');
        }
    });
})();
