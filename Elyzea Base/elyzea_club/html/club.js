/* =====================================================================
   ELYZEA BOÎTE DE NUIT - bar (servir, commande reçue, carte), entrée, annonces
   Les montants affichés viennent du serveur, qui recalcule tout avant de débiter.
   ===================================================================== */
(() => {
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const groupBy = (list) => list.reduce((m, x) => { (m[x.cat] = m[x.cat] || []).push(x); return m; }, {});

  /* ------------------------------------------------------------------ */
  /* Servir au bar (employé)                                             */
  /* ------------------------------------------------------------------ */
  const B = { data: null, target: null, qty: {} };
  function drawBar() {
    const d = B.data, el = $('#bar .modal');
    if (!d) return;
    if (B.target && !d.customers.some((c) => c.id === B.target)) B.target = null;
    if (!B.target && d.customers.length === 1) B.target = d.customers[0].id;
    const lines = d.menu.filter((x) => B.qty[x.item] > 0);
    const total = lines.reduce((a, x) => a + x.price * B.qty[x.item], 0);
    const groups = groupBy(d.menu);
    el.innerHTML = `<div class="modal-head"><div><div class="eyebrow">Bar</div><h2>Servir un client</h2></div><button class="icon-btn" data-bar="close" aria-label="Fermer">✕</button></div>
      <div class="split2"><div>
        <div class="sec-title">Client <button class="btn small" data-bar="refresh">↻</button></div>
        ${d.customers.map((c) => `<button class="pick ${B.target === c.id ? 'on' : ''}" data-cust="${c.id}"><b>${esc(c.name)}</b><small>ID ${c.id} · ${c.distance} m</small></button>`).join('')
          || empty('Personne à côté du bar. Le client doit être à moins de 4 m.')}
        <div class="sec-title" style="margin-top:1rem">Commande</div>
        ${lines.map((x) => `<div class="bill-line"><span>${B.qty[x.item]} × ${esc(x.label)}</span><b class="mono">${money(x.price * B.qty[x.item])}</b></div>`).join('') || '<p class="faint">Choisissez des boissons.</p>'}
        <div class="bill-total"><span>Total</span><b class="mono">${money(total)}</b></div>
        <button class="btn primary block" data-bar="send" ${!B.target || !lines.length ? 'disabled' : ''}>Envoyer la commande au client</button>
        <p class="faint" style="font-size:.75rem;margin-top:.5rem">Le client voit la commande et choisit banque ou espèces. Les boissons arrivent dans son inventaire.</p>
      </div><div class="drinks">
        ${Object.entries(groups).map(([cat, list]) => `<div class="sec-title">${esc(cat)}</div>${list.map((x) => `<div class="drink ${x.available ? '' : 'out'}">
          <div class="main"><b>${esc(x.label)}</b><small>${money(x.price)} · stock ${x.stock}</small></div>
          <div class="qty"><button class="btn small" data-dq="${esc(x.item)}" data-d="-1" ${!B.qty[x.item] ? 'disabled' : ''}>−</button><span class="mono">${B.qty[x.item] || 0}</span>
          <button class="btn small" data-dq="${esc(x.item)}" data-d="1" ${!x.available || (B.qty[x.item] || 0) >= Math.min(20, x.stock) ? 'disabled' : ''}>+</button></div></div>`).join('')}`).join('')
          || empty('Aucune boisson à la carte.')}
      </div></div>`;
  }
  $('#bar').addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-cust]'))) { B.target = Number(b.dataset.cust); return drawBar(); }
    if ((b = e.target.closest('[data-dq]'))) { const k = b.dataset.dq; B.qty[k] = Math.max(0, (B.qty[k] || 0) + Number(b.dataset.d)); return drawBar(); }
    if (!(b = e.target.closest('[data-bar]'))) return;
    const a = b.dataset.bar;
    if (a === 'close') return post('close', { ui: 'bar' });
    if (a === 'refresh') { const r = await post('barRefresh'); if (r.error) return toast(r.error, false); B.data = r; return drawBar(); }
    if (a === 'send') {
      const lines = B.data.menu.filter((x) => B.qty[x.item] > 0).map((x) => ({ item: x.item, qty: B.qty[x.item] }));
      b.classList.add('loading');
      await post('barSell', { target: B.target, lines });
      b.classList.remove('loading');
    }
  });

  /* ------------------------------------------------------------------ */
  /* Commande reçue (client)                                             */
  /* ------------------------------------------------------------------ */
  let offerTimer = null;
  function showOffer(o) {
    const w = $('#barOffer');
    $('.modal', w).innerHTML = `<div class="eyebrow">${esc(o.shop)} · Bar</div><h2>Votre commande</h2>
      <p class="lead">Servie par <b>${esc(o.seller)}</b>.</p>
      ${o.lines.map((l) => `<div class="bill-line"><span>${l.qty} × ${esc(l.label)} <small class="faint">(${money(l.unit)})</small></span><b class="mono">${money(l.total)}</b></div>`).join('')}
      <div class="bill-total"><span>Total</span><b class="mono">${money(o.total)}</b></div>
      <div class="actions" style="justify-content:stretch;flex-wrap:wrap"><button class="btn primary block" data-bo="bank">💳 Payer par carte</button><button class="btn block" data-bo="cash">💵 Payer en espèces</button>
        <button class="btn danger block" data-bo="no">Refuser</button></div>
      <div class="countdown"><i id="boBar" style="width:100%"></i></div>`;
    w.classList.remove('hidden');
    const total = (o.timeout || 45) * 1000, end = Date.now() + total;
    clearInterval(offerTimer);
    offerTimer = setInterval(() => { const l = end - Date.now(); const bar = $('#boBar'); if (bar) bar.style.width = `${Math.max(0, l / total * 100)}%`; if (l <= 0) clearInterval(offerTimer); }, 200);
  }
  $('#barOffer').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-bo]');
    if (!b) return;
    b.classList.add('loading');
    await post('barAnswer', { accept: b.dataset.bo !== 'no', method: b.dataset.bo === 'cash' ? 'cash' : 'bank' });
  });

  /* ------------------------------------------------------------------ */
  /* Carte du bar (lecture seule)                                        */
  /* ------------------------------------------------------------------ */
  function showCard(d) {
    const groups = groupBy(d.list || []);
    $('#card .modal').innerHTML = `<div class="modal-head"><div><div class="eyebrow">${esc(d.shop)}</div><h2>La carte</h2></div><button class="icon-btn" data-card="close" aria-label="Fermer">✕</button></div>
      ${Object.entries(groups).map(([cat, list]) => `<div class="sec-title">${esc(cat)}</div>${list.map((x) => `<div class="bill-line ${x.available ? '' : 'out'}"><span>${esc(x.label)}${x.available ? '' : ' <small class="faint">(épuisé)</small>'}</span><b class="mono">${money(x.price)}</b></div>`).join('')}`).join('')
        || empty('La carte est vide.')}
      <p class="faint" style="font-size:.78rem;margin-top:.8rem">Commandez auprès d'un serveur au bar : il vous envoie la commande, vous payez par carte ou en espèces.</p>`;
    $('#card').classList.remove('hidden');
  }
  $('#card').addEventListener('click', (e) => { if (e.target.closest('[data-card]') || e.target === $('#card')) post('close', { ui: 'card' }); });

  /* ------------------------------------------------------------------ */
  /* Entrée                                                              */
  /* ------------------------------------------------------------------ */
  function showEntry(d) {
    let bodyHtml;
    if (d.banned) {
      bodyHtml = `<div class="warn-box bad">Vous êtes sur la liste noire de ${esc(d.shop)}${d.banned.reason ? ` (${esc(d.banned.reason)})` : ''}${d.banned.expires ? `, jusqu'au ${fmtTime(d.banned.expires)}` : ''}. L'entrée vous est refusée.</div>
        <div class="actions"><button class="btn" data-en="close">Fermer</button></div>`;
    } else if (!d.open) {
      bodyHtml = `<div class="warn-box">${esc(d.shop)} est fermée pour le moment. Revenez plus tard !</div><div class="actions"><button class="btn" data-en="close">Fermer</button></div>`;
    } else if (d.fee <= 0 || d.vip) {
      bodyHtml = `<p class="lead">${d.vip ? 'Vous êtes sur la <b>liste VIP</b> : entrée gratuite.' : 'Entrée gratuite ce soir.'}</p>
        <div class="actions"><button class="btn" data-en="close">Annuler</button><button class="btn primary" data-en="bank">Entrer</button></div>`;
    } else {
      bodyHtml = `<div class="big-price">${money(d.fee)}</div><p class="lead" style="text-align:center">Bracelet valable ${Math.round((APP.cfg && APP.cfg.wristband || 14400) / 3600)} h : vous pouvez sortir et revenir sans repayer.</p>
        <div class="actions" style="justify-content:stretch;flex-wrap:wrap"><button class="btn primary block" data-en="bank">💳 Payer par carte</button><button class="btn block" data-en="cash">💵 Payer en espèces</button>
        <button class="btn block" data-en="close">Annuler</button></div>`;
    }
    $('#entry .modal').innerHTML = `<div class="eyebrow">Entrée</div><h2>${esc(d.shop)}</h2>${bodyHtml}`;
    $('#entry').classList.remove('hidden');
  }
  $('#entry').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-en]');
    if (!b) return;
    if (b.dataset.en === 'close') return post('close', { ui: 'entry' });
    b.classList.add('loading');
    await post('enter', { method: b.dataset.en });
    b.classList.remove('loading');
  });

  /* ------------------------------------------------------------------ */
  /* Annonce d'une boîte (bandeau pour toute la ville)                   */
  /* ------------------------------------------------------------------ */
  let annTimer = null;
  function showAnnounce(a) {
    const el = $('#announce');
    el.innerHTML = `<div class="ann-ico">🪩</div><div><b>${esc(a.shop)}</b><p>${esc(a.text)}</p><small>${a.open ? `Ouvert · entrée ${a.fee > 0 ? money(a.fee) : 'gratuite'}` : 'Bientôt ouvert'}</small></div>`;
    el.classList.remove('hidden', 'out');
    clearTimeout(annTimer);
    annTimer = setTimeout(() => { el.classList.add('out'); setTimeout(() => el.classList.add('hidden'), 500); }, 12000);
  }

  window.Club = {
    bar(m) { if (m.show) { B.data = m.data; B.target = null; B.qty = {}; $('#bar').classList.remove('hidden'); drawBar(); } else $('#bar').classList.add('hidden'); },
    barOffer(m) { if (m.show) showOffer(m.offer); else { $('#barOffer').classList.add('hidden'); clearInterval(offerTimer); } },
    card(m) { if (m.show) showCard(m.data); else $('#card').classList.add('hidden'); },
    entry(m) { if (m.show) showEntry(m.data); else $('#entry').classList.add('hidden'); },
    announce: showAnnounce,
  };
})();
