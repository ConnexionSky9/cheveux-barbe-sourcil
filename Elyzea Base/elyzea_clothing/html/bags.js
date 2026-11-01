/* Sacs de shopping (elyzea_clothing) : fenêtres du sac, du choix dans le coffre et du cadeau reçu.
   Messages reçus : bagView, bagPick, bagGiftAsk, bagGiftEnd · Callbacks : bagTake, bagPickChoose, bagClose, bagGiftAnswer */
(() => {
  'use strict';
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
  const post = (ev, d) => RES ? fetch(`https://${RES}/${ev}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(d || {}) }).catch(() => {}) : (window.bagMock && window.bagMock(ev, d), Promise.resolve());
  const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const IMG = (color) => `nui://elyzea_inventory/html/img/sac_shopping_${color}.png`;
  const ICON = { tops: '👕', undershirts: '🎽', pants: '👖', shoes: '👟', bags: '🎒', vests: '🦺', arms: '🧤', chains: '📿', masks: '🎭',
    decals: '🏷️', hats: '🧢', glasses: '🕶️', ears: '💎', watches: '⌚', bracelets: '💫' };
  const root = document.createElement('div'); root.id = 'bagUi'; document.body.appendChild(root);
  const gift = document.createElement('div'); gift.id = 'bagGift'; gift.setAttribute('role', 'alertdialog'); document.body.appendChild(gift);
  let bag = null, mode = null, giftT = 0, busyIdx = null;

  // Couleur du sac en variables CSS (sans color-mix : compatible avec le navigateur de FiveM)
  const tone = (hex) => {
    const n = parseInt(String(hex || '#ff5fa8').replace('#', ''), 16) || 0xff5fa8;
    const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    const mix = (v) => Math.round(v + (255 - v) * 0.55);
    return `--c:rgb(${r},${g},${b});--ca:rgba(${r},${g},${b},.38);--cs:rgba(${r},${g},${b},.22);--cl:rgb(${mix(r)},${mix(g)},${mix(b)})`;
  };
  const icon = (color, emoji) => `<div class="bg-icon"><img src="${IMG(color)}" alt="" onerror="this.replaceWith(document.createTextNode('${emoji || '🛍️'}'))"></div>`;
  function close(notify) {
    root.classList.remove('show'); root.innerHTML = ''; bag = null; mode = null;
    if (notify) post('bagClose');
  }
  function renderBag() {
    mode = 'view';
    const items = bag.items || [];
    root.innerHTML = `<div class="bg-card" style="${tone(bag.hex)}">
      <div class="bg-head">${icon(bag.color)}<div class="bg-title"><h2>Sac ${esc(bag.colorLabel || '')}</h2>
        <p>${esc(bag.shop || 'Boutique')} · ${bag.total} vêtement${bag.total > 1 ? 's' : ''}</p></div>
        <button class="bg-x" data-act="close" aria-label="Fermer">✕</button></div>
      <div class="bg-list">${items.length ? items.map((it) => `<div class="bg-item">
          <div class="tag">${ICON[it.catId] || '👗'}</div>
          <div class="txt"><b title="${esc(it.label)}">${esc(it.label)}</b><small>${esc(it.cat)}${it.sex ? ` · ${it.sex === 'male' ? 'Homme' : 'Femme'}` : ''}</small></div>
          <span class="qty">×${it.qty}</span>
          <button class="bg-btn" data-take="${it.first}" ${busyIdx !== null ? 'disabled' : ''}>Prendre</button></div>`).join('')
        : '<div class="bg-empty">Le sac est vide.</div>'}</div>
      <div class="bg-foot"><span>Les vêtements vont dans ton inventaire.</span>
        <button class="bg-all" data-act="all" ${!items.length || busyIdx !== null ? 'disabled' : ''}>Tout récupérer</button></div></div>`;
    root.classList.add('show');
  }
  function renderPick(p) {
    mode = 'pick';
    root.innerHTML = `<div class="bg-card" style="${tone('#9b6bff')}">
      <div class="bg-head"><div class="bg-icon">🚗</div><div class="bg-title"><h2>Coffre du véhicule</h2><p>Choisis le sac à récupérer</p></div>
        <button class="bg-x" data-act="close" aria-label="Fermer">✕</button></div>
      <div class="bg-list">${p.bags.map((b) => `<button class="bg-pick" data-pick="${esc(b.id)}" style="--pc:${esc(b.hex)};--pa:${esc(b.hex)}33">
          <span class="dot"><img src="${IMG(b.color)}" alt="" style="width:34px;height:34px" onerror="this.replaceWith(document.createTextNode('🛍️'))"></span>
          <span class="txt"><b>${esc(b.label)}</b><small>${b.count} vêtement${b.count > 1 ? 's' : ''}</small></span></button>`).join('')}</div></div>`;
    root.classList.add('show');
  }
  root.addEventListener('click', (e) => {
    const a = e.target.closest('[data-act]');
    if (a && a.dataset.act === 'close') return close(true);
    if (a && a.dataset.act === 'all' && bag) { busyIdx = 'all'; renderBag(); return post('bagTake', { id: bag.id, all: true }); }
    const t = e.target.closest('[data-take]');
    if (t && bag) { busyIdx = Number(t.dataset.take); renderBag(); return post('bagTake', { id: bag.id, idx: busyIdx, qty: 1 }); }
    const p = e.target.closest('[data-pick]');
    if (p) { const id = p.dataset.pick; close(false); return post('bagPickChoose', { id }); }
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && root.classList.contains('show')) { e.stopImmediatePropagation(); e.preventDefault(); close(true); }
  }, true);

  function showGift(g, keys) {
    clearTimeout(giftT);
    gift.style.setProperty('--c', g.hex || '#ff5fa8');
    gift.innerHTML = `<div class="in"><div class="gi">🎁</div><div style="flex:1;min-width:0"><h4>Cadeau</h4>
      <p><b>${esc(g.from)}</b> t'offre un sac ${esc(g.colorLabel || '')} de <b>${esc(g.shop || 'boutique')}</b> (${g.count} vêtement${g.count > 1 ? 's' : ''}).</p>
      <div class="acts"><button class="yes" data-g="1"><kbd>${esc(keys.accept)}</kbd>Accepter</button><button class="no" data-g="0"><kbd>${esc(keys.refuse)}</kbd>Refuser</button></div></div></div>
      <div class="bar" id="bagGiftBar"></div>`;
    const bar = gift.querySelector('#bagGiftBar'); const t = g.timeout || 20;
    bar.style.transform = 'scaleX(1)';
    requestAnimationFrame(() => requestAnimationFrame(() => { bar.style.transition = `transform ${t}s linear`; bar.style.transform = 'scaleX(0)'; }));
    gift.classList.add('show');
    giftT = setTimeout(() => gift.classList.remove('show'), t * 1000);
  }
  gift.addEventListener('click', (e) => { const b = e.target.closest('[data-g]'); if (b) { gift.classList.remove('show'); post('bagGiftAnswer', { accept: b.dataset.g === '1' }); } });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
      case 'bagView':
        busyIdx = null;
        if (!m.bag || m.bag.empty) { if (mode === 'view') close(false); return; }
        bag = m.bag; renderBag(); break;
      case 'bagPick': if (m.pick && Array.isArray(m.pick.bags)) renderPick(m.pick); break;
      case 'bagGiftAsk': if (m.gift) showGift(m.gift, m.keys || { accept: 'Y', refuse: 'L' }); break;
      case 'bagGiftEnd': clearTimeout(giftT); gift.classList.remove('show'); break;
    }
  });
  window.__bags = { state: () => ({ open: root.classList.contains('show'), mode, bag }) };
})();
