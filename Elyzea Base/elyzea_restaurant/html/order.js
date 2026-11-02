/* =====================================================================
   ELYZEA RESTAURANT - carte et panier (client) · sac de commande
   Le panier ne contient que des identifiants et des quantités : le serveur
   relit la carte, recalcule le total et refuse si les prix ont changé.
   ===================================================================== */
(() => {
  const O = { data: null, cat: null, cart: {}, method: 'bank', busy: false, q: '' };
  const B = { data: null, busy: false };
  const CAT_EMO = { burgers: '🍔', pizzas: '🍕', sides: '🍟', drinks: '🥤', desserts: '🍰', italien: '🍝', fastfood: '🌭', japonais: '🍣', mexicain: '🌮' };
  const PAY = { bank: ['💳', 'Banque', 'banque'], cash: ['💵', 'Espèces', 'espèces'], pesos: ['🪙', 'Pesos', 'pesos'] };
  // Prix en pesos (même calcul que le serveur : prix × taux, arrondi au-dessus)
  const toPesos = (n) => Math.ceil((Number(n) || 0) * Number((O.data && O.data.pesosRate) || 1) - 1e-9);
  const pesosTxt = (n) => `${toPesos(n).toLocaleString('fr-FR')} pesos`;
  const priceTxt = (n) => (O.method === 'pesos' ? pesosTxt(n) : money(n));
  const el = () => $('#order .modal');
  const emptyBox = (t) => `<div class="empty">${esc(t)}</div>`;
  const picture = (img, cat, cls = '') => `<img class="${cls}" src="${esc(imgUrl(img))}" alt="" data-emo="${esc(CAT_EMO[cat] || '🍽️')}">`;
  const fixImages = (root) => root.querySelectorAll('img[data-emo]').forEach((im) => im.addEventListener('error', () => {
    const s = document.createElement('span'); s.className = `emo ${im.className}`; s.textContent = im.dataset.emo; im.replaceWith(s);
  }, { once: true }));

  const products = () => (O.data && O.data.products) || [];
  const byId = (id) => products().find((p) => p.id === id);
  const lines = () => Object.entries(O.cart).filter(([id, q]) => q > 0 && byId(id)).map(([id, qty]) => ({ p: byId(id), qty }));
  const total = () => lines().reduce((a, l) => a + l.p.price * l.qty, 0);
  const units = () => lines().reduce((a, l) => a + l.qty, 0);
  const limits = () => (O.data && O.data.limits) || { maxQty: 10, maxLines: 12, maxUnits: 25 };

  function canAdd(id) {
    const L = limits(), q = O.cart[id] || 0;
    if (q >= L.maxQty) return false;
    if (units() >= L.maxUnits) return false;
    if (!q && lines().length >= L.maxLines) return false;
    return true;
  }

  const norm = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  // Carte d'un produit : image, nom, description, prix, et quantité directement sur la carte
  function prodCard(p, open) {
    const q = O.cart[p.id] || 0;
    return `<article class="prod ${q ? 'in' : ''}"><div class="pic">${picture(p.image, p.cat)}${q ? `<span class="qbadge">${q}</span>` : ''}</div>
      <div class="info"><b title="${esc(p.label)}">${esc(p.label)}</b><p>${esc(p.desc || '')}</p>
      <div class="buy"><span class="price">${priceTxt(p.price)}</span>
        ${q ? `<div class="qty"><button class="btn small" data-q="${esc(p.id)}" data-d="-1" aria-label="Retirer un">−</button><span>${q}</span>
          <button class="btn small" data-q="${esc(p.id)}" data-d="1" ${canAdd(p.id) ? '' : 'disabled'} aria-label="Ajouter un">+</button></div>`
        : `<button class="btn small primary" data-add="${esc(p.id)}" ${!open || !canAdd(p.id) ? 'disabled' : ''}>+ Ajouter</button>`}</div></div></article>`;
  }

  function draw() {
    const d = O.data, root = el();
    if (!d) return;
    const shop = d.shop || {};
    root.style.setProperty('--brand', shop.color || '#f97316');
    const cats = (d.categories || []).filter((c) => products().some((p) => p.cat === c.id));
    if (!O.cat || !cats.some((c) => c.id === O.cat)) O.cat = cats.length ? cats[0].id : null;
    const q = norm(O.q).trim();
    // Recherche : dans toute la carte ; sinon la catégorie choisie
    const list = q ? products().filter((p) => norm(`${p.label} ${p.desc || ''}`).includes(q)) : products().filter((p) => p.cat === O.cat);
    const cat = cats.find((c) => c.id === O.cat) || {};
    const ls = lines(), tot = total();
    const methods = d.methods || ['bank', 'cash'];
    if (!methods.includes(O.method)) O.method = methods[0];
    const track = (d.mine || []).map((o) => `<div class="track"><span>Commande <b>${esc(o.num)}</b></span><span class="st st-${esc(o.status)}">${esc(o.statusLabel)}${o.status === 'preparing' ? ` · ${o.done}/${o.units}` : ''}</span></div>`).join('');
    root.innerHTML = `<div class="ord-head">${logoHTML(shop.logo)}<div class="grow"><h2>${esc(shop.name || 'Restaurant')}</h2>
        <small>${shop.address ? esc(shop.address) + ' · ' : ''}${shop.open ? '<span class="ok-dot">Commandes ouvertes</span>' : '<span class="ko-dot">Commandes fermées</span>'}</small></div>
        <label class="ord-search"><span>🔎</span><input id="ordQ" placeholder="Rechercher un plat, une boisson…" value="${esc(O.q)}"></label>
        <button class="icon-btn" data-o="close" aria-label="Fermer">✕</button></div>
      <div class="ord-body">
        <nav class="ord-cats">${cats.map((c) => `<button class="ord-cat ${!q && c.id === O.cat ? 'on' : ''}" data-cat="${esc(c.id)}" title="${esc(c.label)}"><span class="ic">${esc(c.icon || '')}</span>
          <span class="lb">${esc(c.label)}</span><span class="n">${products().filter((p) => p.cat === c.id).length}</span></button>`).join('') || '<p class="faint" style="padding:.6rem">Carte vide.</p>'}</nav>
        <section class="ord-main">
          ${!shop.open ? '<div class="closed-banner">Ce restaurant ne prend pas de commandes pour le moment.</div>' : ''}
          <div class="ord-title"><h3>${q ? `Résultats pour « ${esc(O.q.trim())} »` : `${esc(cat.icon || '')} ${esc(cat.label || '')}`}</h3><span class="faint">${list.length} produit(s)</span></div>
          <div class="ord-grid">${list.map((p) => prodCard(p, shop.open)).join('') || emptyBox(q ? 'Aucun produit ne correspond.' : 'Aucun produit dans cette catégorie.')}</div>
        </section>
        <aside class="ord-cart"><h3>Panier <span class="faint">${units()} article(s)</span></h3>
          <div class="cart-list">${track}${ls.map((l) => `<div class="cart-line">${picture(l.p.image, l.p.cat)}<div class="cl-main"><b>${esc(l.p.label)}</b><small>${l.qty} × ${priceTxt(l.p.price)}</small></div>
            <div class="cl-side"><b>${priceTxt(l.p.price * l.qty)}</b><div class="qty"><button class="btn small" data-q="${esc(l.p.id)}" data-d="-1" aria-label="Retirer un">−</button>
            <button class="btn small" data-q="${esc(l.p.id)}" data-d="1" ${canAdd(l.p.id) ? '' : 'disabled'} aria-label="Ajouter un">+</button>
            <button class="btn small danger" data-rm="${esc(l.p.id)}" aria-label="Supprimer">✕</button></div></div></div>`).join('') || emptyBox('Votre panier est vide.')}</div>
          <div class="cart-foot"><div class="cart-total"><span>Total</span><b>${priceTxt(tot)}</b></div>
            <div class="pay-methods" style="grid-template-columns:repeat(${methods.length}, 1fr)">${methods.map((m) => `<button data-m="${esc(m)}" class="${O.method === m ? 'on' : ''}">${(PAY[m] || ['', m])[0]} ${esc((PAY[m] || ['', m])[1])}</button>`).join('')}</div>
            ${O.method === 'pesos' ? '<small class="faint pesos-note">Payé avec les pesos de votre inventaire.</small>' : ''}
            <button class="btn primary block" data-o="pay" ${!ls.length || !shop.open || O.busy ? 'disabled' : ''}>Valider et payer ${priceTxt(tot)}</button>
            <small class="faint foot-note">Le restaurant est prévenu dès le paiement. Le sac vous est remis par un employé.</small></div></aside>
      </div>`;
    fixImages(root);
    const qi = $('#ordQ');
    if (qi) {
      qi.oninput = () => { O.q = qi.value; const pos = qi.selectionStart; draw(); const n = $('#ordQ'); if (n) { n.focus(); n.setSelectionRange(pos, pos); } };
    }
  }

  async function pay(btn) {
    const ls = lines();
    if (!ls.length || O.busy) return;
    const tot = total();
    if (!(await confirmBox('Confirmer la commande ?', `${ls.map((l) => `${l.qty} × ${esc(l.p.label)}`).join('<br>')}<br><br>Total : <b>${priceTxt(tot)}</b> (${esc((PAY[O.method] || ['', '', O.method])[2])}).`, 'Payer'))) return;
    O.busy = true;
    btn.classList.add('loading');
    const r = await post('orderSend', { shop: O.data.shop.id, method: O.method, expect: tot, lines: ls.map((l) => ({ id: l.p.id, qty: l.qty })) });
    O.busy = false;
    if (r.error) {
      toast(r.error, false);
      if (r.reload) { const d = await pub('menuCard', { shop: O.data.shop.id }); if (!d.error) O.data = d; }
      return draw();
    }
    toast(r.message || 'Commande envoyée.', true);
    O.cart = {};
    const d = await pub('menuCard', { shop: O.data.shop.id });
    if (!d.error) O.data = d;
    draw();
  }

  $('#order').addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-cat]'))) { O.cat = b.dataset.cat; O.q = ''; return draw(); }
    if ((b = e.target.closest('[data-add]'))) { const id = b.dataset.add; if (canAdd(id)) O.cart[id] = (O.cart[id] || 0) + 1; return draw(); }
    if ((b = e.target.closest('[data-q]'))) {
      const id = b.dataset.q, dlt = Number(b.dataset.d);
      if (dlt > 0 && !canAdd(id)) return;
      O.cart[id] = Math.max(0, (O.cart[id] || 0) + dlt);
      if (!O.cart[id]) delete O.cart[id];
      return draw();
    }
    if ((b = e.target.closest('[data-rm]'))) { delete O.cart[b.dataset.rm]; return draw(); }
    if ((b = e.target.closest('[data-m]'))) { O.method = b.dataset.m; return draw(); }
    if ((b = e.target.closest('[data-o]'))) {
      if (b.dataset.o === 'close') return post('close', { ui: 'order' });
      if (b.dataset.o === 'pay') return pay(b);
    }
  });

  /* ------------------------------------------------------------------ */
  /* Sac de commande                                                     */
  /* ------------------------------------------------------------------ */
  function drawBag() {
    const d = B.data, root = $('#bag .modal');
    if (!d) return;
    root.innerHTML = `<div class="bag-head">${logoHTML(d.logo)}<div style="flex:1"><div class="eyebrow">${esc(d.shop)}</div><h2>Commande ${esc(d.num)}</h2></div>
        <button class="icon-btn" data-b="close" aria-label="Fermer">✕</button></div>
      ${(d.lines || []).map((l) => `<div class="bag-line">${picture(l.image, '')}<div><b>${l.qty} × ${esc(l.label)}</b></div>
        <button class="btn small" data-take="${l.i}" ${B.busy ? 'disabled' : ''}>Prendre</button></div>`).join('') || emptyBox('Sac vide.')}
      <div class="actions"><button class="btn" data-b="close">Fermer</button><button class="btn primary" data-b="all" ${B.busy || !(d.lines || []).length ? 'disabled' : ''}>Tout prendre</button></div>
      <p class="faint" style="font-size:.74rem;margin-top:.6rem">Les produits vont dans votre inventaire (poids et place vérifiés). Le sac est jeté une fois vide.</p>`;
    fixImages(root);
  }
  async function take(line, btn) {
    if (B.busy || !B.data) return;
    B.busy = true;
    if (btn) btn.classList.add('loading');
    const r = await post('bagTake', { uid: B.data.uid, line });
    B.busy = false;
    if (r.error) { toast(r.error, false); if (r.close) return post('close', { ui: 'bag' }); return drawBag(); }
    toast(r.message, true);
    if (r.empty) return post('close', { ui: 'bag' });
    B.data = r.bag;
    drawBag();
  }
  $('#bag').addEventListener('click', (e) => {
    let b;
    if ((b = e.target.closest('[data-take]'))) return take(Number(b.dataset.take), b);
    if ((b = e.target.closest('[data-b]'))) {
      if (b.dataset.b === 'close') return post('close', { ui: 'bag' });
      if (b.dataset.b === 'all') return take(undefined, b);
    }
  });

  window.Order = {
    open(d) { O.data = d; O.cart = {}; O.busy = false; O.cat = null; O.q = ''; if (!(d.methods || []).includes(O.method)) O.method = (d.methods || ['bank'])[0]; $('#order').classList.remove('hidden'); draw(); },
    hide() { $('#order').classList.add('hidden'); O.data = null; },
    bag(d) { B.data = d; B.busy = false; $('#bag').classList.remove('hidden'); drawBag(); },
    hideBag() { $('#bag').classList.add('hidden'); B.data = null; },
    isOpen: () => !$('#order').classList.contains('hidden'),
  };
})();
