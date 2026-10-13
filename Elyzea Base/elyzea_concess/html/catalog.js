/* =====================================================================
   ELYZEA CONCESSION - catalogue (clients et employés)
   Catégories, recherche, filtres, fiche détaillée (caractéristiques lues dans le
   jeu), aperçu 3D (clic droit + glisser hors du panneau, molette pour zoomer).
   Employés autorisés : Vendre (offre envoyée au client) et Exposer. Consulter ne
   débite jamais rien : seul le serveur crée une vente, après acceptation du client.
   ===================================================================== */
(() => {
  const CS = { open: false, data: null, cat: 'all', q: '', sort: 'cat', onlySell: false, sel: null, stats: null, preview: false };
  const root = () => $('#catalog');

  const sorters = {
    cat: (a, b) => (a.catSort - b.catSort) || (a.price - b.price) || a.label.localeCompare(b.label),
    priceAsc: (a, b) => (a.price - b.price) || a.label.localeCompare(b.label),
    priceDesc: (a, b) => (b.price - a.price) || a.label.localeCompare(b.label),
    name: (a, b) => a.label.localeCompare(b.label),
  };
  function items() {
    const q = CS.q.trim().toLowerCase();
    return CS.data.items.filter((i) => (CS.cat === 'all' || i.categoryId === Number(CS.cat))
      && (!q || `${i.label} ${i.brand || ''} ${i.category}`.toLowerCase().includes(q)) && (!CS.onlySell || i.sellable))
      .sort(sorters[CS.sort] || sorters.cat);
  }
  const photo = (it, cls = 'img') => {
    const src = imgOf(it);
    return `<div class="${cls}">${src ? `<img src="${esc(src)}" alt="" loading="lazy" onerror="this.replaceWith(Object.assign(document.createElement('span'),{className:'ph',textContent:'🚘'}))">` : '<span class="ph">🚘</span>'}</div>`;
  };
  const badges = (it) => `${it.sellable ? '' : '<span class="badge no">Non disponible à la vente</span>'}${it.displayed ? `<span class="badge expo">En exposition${it.displayed > 1 ? ` ×${it.displayed}` : ''}</span>` : ''}`;

  function draw() {
    const d = CS.data, list = items();
    const counts = {};
    d.items.forEach((i) => { counts[i.categoryId] = (counts[i.categoryId] || 0) + 1; });
    const side = `<div class="cat-side"><h1>${esc(d.shop.name)}</h1><div class="addr">${esc(d.shop.address || '')}</div>
      <button class="cat-btn ${CS.cat === 'all' ? 'on' : ''}" data-ccat="all">🚗 Tous les véhicules<span class="n">${d.items.length}</span></button>
      ${d.categories.map((c) => `<button class="cat-btn ${String(CS.cat) === String(c.id) ? 'on' : ''}" data-ccat="${c.id}">${esc(c.icon || '•')} ${esc(c.name)}<span class="n">${counts[c.id] || 0}</span></button>`).join('')}
      ${d.employee ? '<p class="faint" style="font-size:.74rem;margin:.9rem .4rem 0">Mode employé : « Vendre » envoie une offre au client choisi ; le prix est celui de la concession.</p>'
        : '<p class="faint" style="font-size:.74rem;margin:.9rem .4rem 0">Consultation libre : pour acheter, adressez-vous à un vendeur de la concession.</p>'}</div>`;
    let main;
    if (CS.sel) main = detail(CS.sel);
    else {
      main = `<div class="cat-tools"><input class="input" style="max-width:22rem" data-cq placeholder="Rechercher : modèle, marque, catégorie" value="${esc(CS.q)}">
          <select class="input" style="width:auto" data-csort>${[['cat', 'Par catégorie'], ['priceAsc', 'Prix croissant'], ['priceDesc', 'Prix décroissant'], ['name', 'Nom']]
            .map(([k, l]) => `<option value="${k}" ${CS.sort === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
          <label class="extra"><input type="checkbox" class="check" data-conly ${CS.onlySell ? 'checked' : ''}> Vendables uniquement</label>
          <span style="flex:1"></span><span class="faint" style="font-size:.8rem">${list.length} véhicule(s)</span>
          <button class="icon-btn" data-cclose="1" title="Fermer (Échap)">✕</button></div>
        <div class="cat-grid">${list.map((it) => `<div class="car" data-cit="${it.id}">${photo(it)}<div class="body"><div class="name">${esc(it.label)}</div>
          <div class="sub">${esc(it.brand ? `${it.brand} · ` : '')}${esc(it.category)}</div>
          <div class="row"><span class="price">${money(it.price)}</span><span>${badges(it)}</span></div></div></div>`).join('') || empty('Aucun véhicule ne correspond.')}</div>`;
    }
    root().innerHTML = side + `<div class="cat-main">${main}</div>`;
    root().classList.toggle('previewing', CS.preview);
  }
  const empty = (t) => `<div class="empty" style="grid-column:1/-1">${esc(t)}</div>`;

  function bar(label, v, max, txt) {
    const pct = Math.max(3, Math.min(100, (Number(v) || 0) / max * 100));
    return `<div class="statbar"><span class="muted">${label}</span><i><b style="width:${pct}%"></b></i><b class="mono" style="text-align:right">${txt}</b></div>`;
  }
  function detail(it) {
    const s = CS.stats || {}, emp = CS.data.employee || {};
    return `<div class="cat-tools"><button class="btn small" data-cback="1">‹ Retour</button><span style="flex:1"></span>
        ${CS.preview ? '<button class="btn small" data-cprev="off">Quitter l\'aperçu</button>' : ''}<button class="icon-btn" data-cclose="1" title="Fermer">✕</button></div>
      <div class="cat-detail">${CS.preview ? '' : photo(it, 'hero')}
        <div style="display:flex;align-items:flex-start;gap:1rem;flex-wrap:wrap"><div style="flex:1;min-width:14rem"><div class="eyebrow">${esc(it.category)}${it.brand ? ` · ${esc(it.brand)}` : ''}</div>
          <h2 style="font-size:1.5rem;margin:.2rem 0 .4rem">${esc(it.label)}</h2><div>${badges(it)}</div></div>
          <div style="text-align:right"><div class="big-price">${money(it.price)}</div><small class="faint">Prix de cette concession</small></div></div>
        ${it.description ? `<p class="lead" style="margin-top:.8rem">${esc(it.description)}</p>` : ''}
        ${!it.sellable ? `<div class="warn-box" style="margin-top:.8rem">Non disponible à la vente${it.sellReason ? ` : ${esc(it.sellReason)}` : ''}.</div>` : ''}
        <div class="card" style="margin-top:.9rem"><h2>Caractéristiques</h2>
          ${s.speed != null ? bar('Vitesse max.', s.speed, 320, `${s.speed} km/h`) + bar('Accélération', s.accel, 1, `${Math.round((s.accel || 0) * 100)}`)
            + bar('Freinage', s.brake, 3, `${Math.round((s.brake || 0) * 33)}`) + bar('Adhérence', s.traction, 3.5, `${Math.round((s.traction || 0) * 28)}`)
            + `<div class="statbar"><span class="muted">Places</span><span></span><b class="mono" style="text-align:right">${s.seats || it.seats || '—'}</b></div>`
            : '<div class="faint" style="font-size:.84rem">Caractéristiques indisponibles (modèle absent de votre jeu).</div>'}</div>
        <div class="actions-row" style="margin-top:.9rem">
          <button class="btn" data-cprev="on">🎥 ${CS.preview ? 'Recharger l\'aperçu' : 'Voir en 3D'}</button>
          ${emp.sell ? `<button class="btn primary" data-csell="1" ${it.sellable ? '' : 'disabled'}>💳 Vendre à un client</button>` : ''}
          ${emp.display ? '<button class="btn" data-cexpo="1">🅿️ Exposer</button>' : ''}</div>
        ${CS.preview ? '<p class="cam-hint">🖱️ Clic droit maintenu + glisser (hors du panneau) : tourner autour · molette : zoom.</p>' : ''}</div>`;
  }

  async function select(id) {
    CS.sel = CS.data.items.find((i) => i.id === id) || null;
    CS.stats = null;
    draw();
    if (CS.sel) { CS.stats = await post('catStats', { model: CS.sel.model }); if (CS.sel && CS.sel.id === id) draw(); }
  }

  // Vente : client proche, paiement, remise (le serveur recalcule et revérifie)
  async function sellForm(it) {
    const near = await req('nearby');
    if (near.error) return toast(near.error, false);
    if (!near.list.length) return toast('Aucun client à proximité.', false);
    const cat = await req('catalog');
    const max = cat.canDiscount ? (cat.maxDiscount || 0) : 0;
    const v = await confirmBox(`Vendre : ${it.label}`, `<div class="recap"><span>Prix</span><b>${money(it.price)}</b><span>Catégorie</span><b>${esc(it.category)}</b><span>Concession</span><b>${esc(CS.data.shop.name)}</b></div>`,
      'Envoyer l\'offre', false,
      `<div class="form-grid" style="margin-top:.6rem"><label class="field"><span>Client</span><select class="input" data-cfv="target">${near.list.map((n) => `<option value="${n.id}">${esc(n.name)} · ID ${n.id} · ${n.distance} m</option>`).join('')}</select></label>
        <label class="field"><span>Paiement</span><select class="input" data-cfv="method"><option value="bank">Banque</option><option value="cash">Espèces</option></select></label>
        ${max > 0 ? `<label class="field"><span>Remise (0 à ${max} %)</span><input class="input" type="number" min="0" max="${max}" value="0" data-cfv="discount"></label>` : ''}</div>
       <p class="faint" style="font-size:.78rem;margin-top:.5rem">Le client voit le récapitulatif et doit accepter. Le serveur vérifie le prix, ses fonds et la disponibilité.</p>`);
    if (!v) return;
    await act(req('saleOffer', { model: it.id, target: Number(v.target), method: v.method, discount: Number(v.discount || 0) }));
  }
  async function expoForm(it) {
    const d = await req('displayList');
    if (d.error) return toast(d.error, false);
    if (!d.models.find((m) => m.id === it.id)) return toast('Ce modèle n\'est pas autorisé en exposition dans votre concession.', false);
    const slots = d.list.filter((s) => s.enabled);
    if (!slots.length) return toast('Aucun emplacement d\'exposition (le staff les crée).', false);
    const v = await confirmBox(`Exposer : ${it.label}`, 'Choisissez l\'emplacement. Un emplacement occupé ne reçoit pas un second véhicule : cochez « Remplacer » pour changer celui qui y est.', 'Exposer', false,
      `<label class="field" style="margin-top:.6rem"><span>Emplacement</span><select class="input" data-cfv="slot">${slots.map((s) => `<option value="${s.id}">${esc(s.label)}${s.model ? ` · occupé (${esc(s.modelLabel || s.model)})` : ' · libre'}</option>`).join('')}</select></label>
       <label class="extra" style="margin-top:.5rem"><input type="checkbox" class="check" data-cfv="replace"> Remplacer le véhicule déjà exposé</label>`);
    if (!v) return;
    const r = await act(req('displayPlace', { slot: Number(v.slot), model: it.id, replace: v.replace }));
    if (r.ok) refresh();
  }
  async function refresh() {
    const r = await post('catRefresh', {});
    if (r && !r.error) { CS.data = r; if (CS.sel) CS.sel = r.items.find((i) => i.id === CS.sel.id) || null; draw(); }
  }

  root().addEventListener('click', async (e) => {
    let b;
    if (e.target.closest('[data-cclose]')) return post('close', { ui: 'catalog' });
    if ((b = e.target.closest('[data-ccat]'))) { CS.cat = b.dataset.ccat; CS.sel = null; return draw(); }
    if ((b = e.target.closest('[data-cit]'))) return select(Number(b.dataset.cit));
    if (e.target.closest('[data-cback]')) return Catalog.back();
    if ((b = e.target.closest('[data-cprev]'))) {
      if (b.dataset.cprev === 'off') { CS.preview = false; post('catPreviewOff', {}); return draw(); }
      b.classList.add('loading');
      const r = await post('catPreview', { model: CS.sel.model });
      b.classList.remove('loading');
      if (r.error) return toast(r.error, false);
      CS.preview = true;
      return draw();
    }
    if (e.target.closest('[data-csell]')) return sellForm(CS.sel);
    if (e.target.closest('[data-cexpo]')) return expoForm(CS.sel);
  });
  root().addEventListener('input', (e) => {
    if (e.target.dataset.cq === undefined) return;
    CS.q = e.target.value;
    const pos = e.target.selectionStart;
    draw();
    const n = root().querySelector('[data-cq]'); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
  });
  root().addEventListener('change', (e) => {
    if (e.target.dataset.csort !== undefined) { CS.sort = e.target.value; draw(); }
    if (e.target.dataset.conly !== undefined) { CS.onlySell = e.target.checked; draw(); }
  });

  // Caméra de l'aperçu : clic droit maintenu + glisser hors du panneau, molette
  let drag = null;
  document.addEventListener('contextmenu', (e) => { if (CS.preview) e.preventDefault(); });
  document.addEventListener('mousedown', (e) => { if (CS.preview && e.button === 2 && !e.target.closest('#catalog')) drag = { x: e.clientX, y: e.clientY }; });
  document.addEventListener('mouseup', (e) => { if (e.button === 2) drag = null; });
  document.addEventListener('mousemove', (e) => {
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    drag = { x: e.clientX, y: e.clientY };
    if (dx || dy) post('catCam', { dx, dy });
  });
  document.addEventListener('wheel', (e) => { if (CS.preview && !e.target.closest('#catalog')) post('catCam', { zoom: e.deltaY > 0 ? 0.6 : -0.6 }); }, { passive: true });

  window.Catalog = {
    open(data) { Object.assign(CS, { open: true, data, cat: 'all', q: '', sel: null, stats: null, preview: false }); root().classList.remove('hidden'); draw(); },
    hide() { CS.open = false; CS.preview = false; drag = null; root().classList.add('hidden'); root().classList.remove('previewing'); },
    isOpen: () => CS.open,
    back() {
      if (CS.preview) { CS.preview = false; post('catPreviewOff', {}); draw(); return true; }
      if (CS.sel) { CS.sel = null; CS.stats = null; draw(); return true; }
      return false;
    },
  };
})();
