'use strict';
/* =========================================================
   LIVRÉZY — courses livrées par un PNJ
   ========================================================= */
const Deliv = { catalog: null, cat: null, cart: {}, active: null, live: null, prepTimer: null, readyAt: 0 };
const STEPS = ['received', 'preparing', 'enroute', 'delivered'];

function itemImage(name, label) {
  const path = Deliv.catalog?.imagePath || '';
  const letter = esc((label || name || '?').trim()[0] || '?');
  return `<span class="lv-img" style="--av:${avColor(name)}"><b>${letter}</b>${path ? `<img src="${esc(path.replace('%s', name))}" alt="" onerror="this.remove()">` : ''}</span>`;
}
const findItem = (name) => { for (const c of Deliv.catalog?.categories || []) for (const it of c.items) if (it.name === name) return it; return null; };
const cartLines = () => Object.entries(Deliv.cart).filter(([, q]) => q > 0).map(([name, qty]) => ({ name, qty, item: findItem(name) })).filter(l => l.item);
const cartCount = () => cartLines().reduce((a, l) => a + l.qty, 0);
const cartSubtotal = () => cartLines().reduce((a, l) => a + l.qty * l.item.price, 0);

Views.livrezy = async ({ tab } = {}) => {
  frame({ title: 'Livrézy', body: loading() });
  const r = await api('deliveryCatalog');
  if (S.currentApp !== 'livrezy') return;
  if (!r.ok) { $('.app__body', appView).innerHTML = empty(t('Livraison indisponible'), t('Le service de livraison est désactivé sur ce serveur.')); return; }
  Deliv.catalog = r;
  if (!Deliv.cat) Deliv.cat = r.categories[0]?.id;
  if (r.active) { Deliv.active = r.active; if (r.active.readyIn !== undefined) Deliv.readyAt = Date.now() + r.active.readyIn * 1000; }
  else if (Deliv.active && Deliv.live?.stage !== 'delivered') { Deliv.active = null; Deliv.live = null; }
  tab = tab || (Deliv.active ? 'order' : 'shop');
  const tabs = tabsHtml([['shop', t('Commander')], ['order', t('Suivi')], ['history', t('Historique')]], tab, 'data-lt');
  frame({ title: 'Livrézy', tabs, body: '', foot: tab === 'shop' ? '<div id="lv-bar"></div>' : '' });
  appView.querySelector('.app').classList.add('lv');
  $$('[data-lt]', appView).forEach(b => b.onclick = () => { setParams({ tab: b.dataset.lt }); Views.livrezy({ tab: b.dataset.lt }); });
  if (tab === 'shop') return renderShop();
  if (tab === 'order') return renderTracking();
  return renderDeliveryHistory();
};

/* ---------- Catalogue ---------- */
async function renderShop() {
  const body = $('.app__body', appView);
  const cats = Deliv.catalog.categories;
  const current = cats.find(c => c.id === Deliv.cat) || cats[0];
  body.innerHTML = `<div class="lv-address"><span class="chip-ic" style="--c:#21B37E">${icon('pin')}</span>
      <div class="row__main"><div class="row__sub">${t('Livraison à votre position')}</div><div class="row__title" id="lv-street">…</div></div></div>
    ${Deliv.active ? `<button class="lv-banner" data-goorder>${icon('car')}<span>${t('Une commande est en cours. Suivre le livreur')}</span>${icon('chev')}</button>` : ''}
    <div class="chips" role="tablist">${cats.map(c => `<button class="${c.id === current.id ? 'active' : ''}" data-cat="${c.id}">${esc(t(c.label))}</button>`).join('')}</div>
    <div class="lv-grid">${current.items.map(it => {
      const q = Deliv.cart[it.name] || 0;
      return `<article class="lv-item">${itemImage(it.name, it.label)}
        <p class="lv-item__name">${esc(t(it.label))}</p><p class="lv-item__price">${money(it.price)}</p>
        <div class="lv-step" data-item="${it.name}">${q ? `<button data-dq="-1" aria-label="${t('Retirer')}">−</button><span>${q}</span>` : ''}<button data-dq="1" class="${q ? '' : 'solo'}" aria-label="${t('Ajouter')}">${icon('plus')}</button></div></article>`;
    }).join('')}</div>
    <p class="row__sub row__sub--wrap" style="text-align:center;margin:16px 10px 0">${t('Livré par un coursier en voiture. Frais de livraison : {fee}.', { fee: money(Deliv.catalog.fee) })}</p>`;
  $$('[data-cat]', appView).forEach(b => b.onclick = () => { Deliv.cat = b.dataset.cat; renderShop(); });
  $('[data-goorder]', appView)?.addEventListener('click', () => { setParams({ tab: 'order' }); Views.livrezy({ tab: 'order' }); });
  $$('.lv-step', appView).forEach(st => $$('[data-dq]', st).forEach(b => b.onclick = () => changeQty(st.dataset.item, +b.dataset.dq)));
  drawCartBar();
  const loc = await post('getLocation');
  const el = $('#lv-street'); if (el) el.textContent = [loc?.street, loc?.zone].filter(Boolean).join(', ') || t('Position inconnue');
}
function changeQty(name, delta) {
  const max = Deliv.catalog.maxPerItem || 10;
  const q = Math.max(0, Math.min(max, (Deliv.cart[name] || 0) + delta));
  if (delta > 0 && cartCount() >= (Deliv.catalog.maxItems || 20)) { notify({ app: 'livrezy', title: 'Livrézy', text: t('Trop d\'articles dans le panier') }); return; }
  Deliv.cart[name] = q;
  if (S.currentApp === 'livrezy' && $('.lv-grid', appView)) renderShop();
}
function drawCartBar() {
  const bar = $('#lv-bar'); if (!bar) return;
  const n = cartCount();
  bar.innerHTML = n ? `<button class="lv-cartbar" id="lv-open-cart"><span class="lv-cartbar__n">${n}</span><span>${t('Voir le panier')}</span><b>${money(cartSubtotal() + Deliv.catalog.fee)}</b></button>` : '';
  $('#lv-open-cart')?.addEventListener('click', cartSheet);
}

/* ---------- Panier & paiement ---------- */
function cartSheet() {
  const c = Deliv.catalog;
  let pay = (c.pay || ['bank'])[0];
  const draw = (sh) => {
    const lines = cartLines();
    if (!lines.length) { closeSheet(); return; }
    const sub = cartSubtotal(), total = sub + c.fee;
    sh.innerHTML = `<h2 class="sheet__title">${t('Votre panier')}</h2>
      <div class="list">${lines.map(l => `<div class="row">${itemImage(l.name, l.item.label)}
        <div class="row__main"><div class="row__title">${esc(t(l.item.label))}</div><div class="row__sub">${money(l.item.price)}</div></div>
        <div class="lv-step lv-step--inline" data-item="${l.name}"><button data-dq="-1" aria-label="${t('Retirer')}">−</button><span>${l.qty}</span><button data-dq="1" aria-label="${t('Ajouter')}">${icon('plus')}</button></div></div>`).join('')}</div>
      <div class="lv-sum"><p><span>${t('Sous-total')}</span><span>${money(sub)}</span></p><p><span>${t('Livraison')}</span><span>${money(c.fee)}</span></p>
        <p class="lv-sum__total"><span>${t('Total')}</span><span>${money(total)}</span></p></div>
      ${(c.pay || []).length > 1 && c.cash ? `<p class="section-label">${t('Paiement')}</p>
        <div class="seg" id="lv-pay">${c.pay.map(m => `<button data-pay="${m}" class="${pay === m ? 'active' : ''}">${m === 'cash' ? t('Espèces') : t('Banque')}</button>`).join('')}</div>` : ''}
      <p class="error-text" id="lv-err" style="margin-top:10px"></p>
      <button class="btn btn--block" id="lv-order">${t('Commander')}, ${money(total)}</button>`;
    $$('.lv-step', sh).forEach(st => $$('[data-dq]', st).forEach(b => b.onclick = () => { changeQty(st.dataset.item, +b.dataset.dq); draw(sh); drawCartBar(); }));
    $$('[data-pay]', sh).forEach(b => b.onclick = () => { pay = b.dataset.pay; draw(sh); });
    $('#lv-order', sh).onclick = async (e) => {
      e.currentTarget.disabled = true;
      const r = await api('deliveryOrder', { cart: lines.map(l => ({ name: l.name, qty: l.qty })), pay });
      if (!r.ok) { $('#lv-err', sh).textContent = t(r.error || 'Commande impossible.'); e.currentTarget.disabled = false; return; }
      Deliv.cart = {}; Deliv.active = r.order; Deliv.live = { stage: 'preparing' };
      Deliv.readyAt = Date.now() + (r.order.readyIn || 30) * 1000;
      closeSheet(true);
      notify({ app: 'livrezy', title: t('Commande confirmée'), text: t('En préparation chez {shop}', { shop: r.order.shop }) });
      setParams({ tab: 'order' }); Views.livrezy({ tab: 'order' });
    };
  };
  openSheet('', '', draw).classList.add('lv');
}

/* ---------- Suivi en temps réel ---------- */
function stageOf() {
  const live = Deliv.live?.stage;
  if (live === 'delivered') return 'delivered';
  if (live === 'enroute' || live === 'arrived' || Deliv.active?.status === 'enroute') return live === 'arrived' ? 'arrived' : 'enroute';
  return 'preparing';
}
function renderTracking() {
  const body = $('.app__body', appView);
  const a = Deliv.active;
  if (!a) {
    body.innerHTML = empty(t('Aucune commande en cours'), t('Choisissez vos articles : un livreur vous les apporte où que vous soyez.'), `<button class="btn" data-goshop>${t('Commander')}</button>`);
    $('[data-goshop]', appView).onclick = () => { setParams({ tab: 'shop' }); Views.livrezy({ tab: 'shop' }); };
    return;
  }
  const stage = stageOf();
  const titles = {
    preparing: t('En préparation chez {shop}', { shop: esc(a.shop) }),
    enroute: t('Votre livreur est en route'),
    arrived: t('Votre livreur est arrivé'),
    delivered: t('Commande livrée, bon appétit !'),
  };
  const stepIndex = { preparing: 1, enroute: 2, arrived: 2, delivered: 3 }[stage];
  body.innerHTML = `
    <h2 class="lv-status" id="lv-status">${titles[stage]}</h2>
    <p class="row__sub row__sub--wrap" id="lv-sub" style="margin:4px 4px 0"></p>
    <div class="radar-map" id="lv-radar">
      <i class="rm-ring" style="--r:33%"></i><i class="rm-ring" style="--r:66%"></i><i class="rm-ring" style="--r:100%"></i>
      <svg class="rm-line" viewBox="0 0 100 100" preserveAspectRatio="none"><line id="lv-line" x1="50" y1="50" x2="50" y2="50"/></svg>
      <span class="rm-north">N</span>
      <span class="rm-me">${icon('user')}</span>
      <span class="rm-car ${stage === 'preparing' ? 'hidden' : ''}" id="lv-car">${icon('car')}</span>
      <span class="rm-scale" id="lv-scale"></span>
      ${stage === 'preparing' ? `<div class="rm-wait"><span class="spinner" style="margin:0 auto 8px"></span>${t('Le livreur partira de {shop}', { shop: esc(a.shop) })}</div>` : ''}
    </div>
    <div class="grid-2"><div class="widget" style="min-height:0"><span class="widget__label">${t('Distance')}</span><span class="widget__value" id="lv-dist" style="font-size:20px">--</span></div>
      <div class="widget" style="min-height:0"><span class="widget__label">${t('Arrivée estimée')}</span><span class="widget__value" id="lv-eta" style="font-size:20px">--</span></div></div>
    <div class="lv-steps">${STEPS.map((s, i) => `<div class="lv-stepper ${i <= stepIndex ? 'done' : ''} ${i === stepIndex ? 'now' : ''}"><i></i><span>${[t('Commande reçue'), t('En préparation'), t('En route'), t('Livrée')][i]}</span></div>`).join('')}</div>
    <p class="section-label">${t('Votre commande')}</p>
    <div class="list">${a.items.map(it => `<div class="row">${itemImage(it.name, it.label)}<div class="row__main"><div class="row__title">${esc(t(it.label))}</div></div><span class="row__aside">×${it.qty}</span></div>`).join('')}
      <div class="row"><div class="row__main row__title">${t('Total payé')}</div><span class="row__title">${money(a.total)}</span></div></div>
    ${stage === 'delivered' ? `<button class="btn btn--block" style="margin-top:14px" data-again>${t('Commander à nouveau')}</button>`
      : stage !== 'arrived' ? `<button class="btn btn--danger btn--block" style="margin-top:14px" data-cancel>${t('Annuler la commande')}</button>` : ''}`;
  $('[data-cancel]', appView)?.addEventListener('click', () => confirmSheet(t('Annuler la commande ?'),
    stage === 'preparing' ? t('Vous serez remboursé intégralement.') : t('Le livreur est déjà parti : les frais de livraison ({fee}) ne sont pas remboursés.', { fee: money(Deliv.catalog?.fee || 0) }),
    t('Annuler la commande'), async () => {
      const r = await api('deliveryCancel');
      if (r.ok) notify({ app: 'livrezy', title: t('Commande annulée'), text: t('{amount} remboursés', { amount: money(r.refund) }) });
      Deliv.active = null; Deliv.live = null; Views.livrezy({ tab: 'shop' });
    }));
  $('[data-again]', appView)?.addEventListener('click', () => { Deliv.active = null; Deliv.live = null; setParams({ tab: 'shop' }); Views.livrezy({ tab: 'shop' }); });
  updateTracking();
  clearInterval(Deliv.prepTimer);
  if (stage === 'preparing') Deliv.prepTimer = setInterval(() => { if (!$('#lv-sub')) return clearInterval(Deliv.prepTimer); updateTracking(); }, 1000);
}
function updateTracking() {
  const live = Deliv.live || {};
  const stage = stageOf();
  const sub = $('#lv-sub'); if (!sub) return;
  if (stage === 'preparing') {
    const s = Math.max(0, Math.round((Deliv.readyAt - Date.now()) / 1000));
    sub.textContent = s > 0 ? t('Départ du livreur dans {s} s', { s }) : t('Le livreur prend la route…');
    return;
  }
  if (stage === 'enroute') sub.textContent = live.street ? t('Actuellement sur {street}', { street: live.street }) : t('Parti de {shop}', { shop: live.shop || Deliv.active?.shop });
  if (stage === 'arrived') sub.textContent = t('Il vient vous remettre votre commande.');
  if (stage === 'delivered') sub.textContent = t('Merci d\'avoir commandé avec Livrézy.');
  const dist = live.distance ?? 0;
  $('#lv-dist').textContent = stage === 'enroute' ? (dist >= 1000 ? `${(dist / 1000).toFixed(1)} km` : `${dist} m`) : '—';
  $('#lv-eta').textContent = stage === 'enroute' ? (live.eta >= 60 ? t('{n} min', { n: Math.round(live.eta / 60) }) : t('{s} s', { s: live.eta || 0 })) : (stage === 'arrived' ? t('Maintenant') : '—');
  // Radar : vous au centre, nord en haut
  const rel = live.rel || { x: 0, y: 0 };
  const range = Math.max(80, Math.hypot(rel.x, rel.y) * 1.2);
  const px = 50 + (rel.x / range) * 50, py = 50 - (rel.y / range) * 50;
  const car = $('#lv-car');
  if (car) { car.style.left = px + '%'; car.style.top = py + '%'; car.classList.toggle('hidden', stage === 'delivered'); }
  const line = $('#lv-line'); if (line) { const done = stage === 'delivered'; line.setAttribute('x2', done ? 50 : px); line.setAttribute('y2', done ? 50 : py); }
  const sc = $('#lv-scale'); if (sc) sc.textContent = `${Math.round(range / 3)} m`;
}

/* ---------- Historique ---------- */
async function renderDeliveryHistory() {
  const body = $('.app__body', appView);
  body.innerHTML = loading();
  const r = await api('deliveryHistory');
  if (S.currentApp !== 'livrezy') return;
  const orders = r.orders || [];
  const label = { delivered: t('Livrée'), cancelled: t('Annulée'), refunded: t('Remboursée'), preparing: t('En préparation'), enroute: t('En route') };
  body.innerHTML = orders.length ? `<div class="list">${orders.map(o => `<div class="row"><span class="chip-ic" style="--c:${o.status === 'delivered' ? '#21B37E' : '#8A90A8'}">${icon('car')}</span>
    <div class="row__main"><div class="row__title">${esc(o.items.map(i => `${i.qty}× ${t(i.label)}`).join(', '))}</div>
    <div class="row__sub">${esc(o.shop)}, ${label[o.status] || o.status}, ${timeAgo(o.ts)}</div></div><span class="row__title">${money(o.total)}</span></div>`).join('')}</div>`
    : empty(t('Aucune commande'), t('Vos commandes passées apparaîtront ici.'));
}

// Mises à jour envoyées par le jeu pendant la livraison
function onDeliveryUpdate(d) {
  if (d.stage === 'aborted') {
    Deliv.active = null; Deliv.live = null;
    if (S.currentApp === 'livrezy') Views.livrezy({ tab: 'shop' });
    return;
  }
  const prev = stageOf();
  Deliv.live = Object.assign({}, Deliv.live, d);
  if (Deliv.active) Deliv.active.status = d.stage === 'delivered' ? 'delivered' : 'enroute';
  if (S.open && S.currentApp === 'livrezy' && $('#lv-radar')) {
    if (prev !== stageOf()) renderTracking(); else updateTracking();
  }
}
