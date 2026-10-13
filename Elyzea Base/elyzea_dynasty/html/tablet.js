/* =====================================================================
   ELYZEA DYNASTY 8 - tablette
   Immobilier : Tableau de bord · Biens disponibles · Biens loués / vendus · Carte · Contrats · Visites
   Direction : Recrutement, Employés, Grades, Permissions, Historique · Finance : Vue d'ensemble, Transactions
   Chaque bouton appelle le serveur, qui revérifie les droits, les statuts et recalcule les montants.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const propPill = (st) => { const s = propStatus(st); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55"><span class="st-dot" style="background:${s.color}"></span>${esc(s.label)}</span>`; };
  const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
  const CAT = { sale: 'Ventes', rent: 'Locations', extend: 'Prolongations', refund: 'Remboursements', salary: 'Salaires', commission: 'Commissions', other: 'Autre' };
  const KIND = { sale: 'Vente', rent: 'Location' };
  const PKIND = { sale: 'Vente', rent: 'Location', extend: 'Prolongation', refund: 'Remboursement' };
  const PST = { paid: 'payé', refunded: 'remboursé', failed: 'échoué', pending: 'en attente' };
  const CSTAT = { active: 'En cours', expired: 'Expiré', ended: 'Terminé', cancelled: 'Annulé' };
  const catLabel = (c) => (APP.cats || {})[c] || c;
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'available', label: 'Habitations disponibles', ico: '🟢', perm: ['tablet'] },
    { id: 'unavailable', label: 'Habitations indisponibles', ico: '🟠', perm: ['tablet'] },
    { id: 'map', label: 'Carte', ico: '🗺️', perm: ['tablet'] },
    { id: 'contracts', label: 'Contrats', ico: '📄', perm: ['properties_view'] },
    { id: 'visits', label: 'Visites commerciales', ico: '🔑', perm: ['tablet'] },
    { id: 'recruit', label: 'Recrutement', ico: '➕', perm: ['recruit'], group: 'Direction' },
    { id: 'employees', label: 'Employés', ico: '👥', perm: ['employees_view'], group: 'Direction' },
    { id: 'grades', label: 'Grades', ico: '🎖️', perm: ['direction'], group: 'Direction' },
    { id: 'perms', label: 'Permissions', ico: '🔐', perm: ['perms_manage'], group: 'Direction' },
    { id: 'history', label: 'Historique', ico: '🕘', perm: ['history_view'], group: 'Direction' },
    { id: 'finance', label: 'Vue d\'ensemble', ico: '💰', perm: ['finance'], group: 'Finance' },
    { id: 'transactions', label: 'Transactions', ico: '🔁', perm: ['finance'], group: 'Finance' },
  ];
  const allowed = (n) => canAny(...n.perm) && (n.group !== 'Direction' || can('direction'));

  function renderNav() {
    let last = null, html = `<div class="brand"><div class="shield">🏠</div><div><b>Dynasty 8</b><small>Agence immobilière</small></div></div>`;
    NAV.filter(allowed).forEach((n) => {
      if (n.group && n.group !== last) html += `<div class="nav-group">${n.group}</div>`;
      last = n.group;
      html += `<button class="nav-btn ${T.page === n.id ? 'active' : ''}" data-nav="${n.id}"><span class="ico">${n.ico}</span>${n.label}</button>`;
    });
    const st = T.st || {};
    html += `<div class="nav-me"><b>${esc(st.grade || '')}</b><span class="mono">${esc(st.matricule || '')}</span></div>`;
    $('#tabNav').innerHTML = html;
    const pill = $('#tabDuty');
    pill.className = `pill ${st.duty ? 'on' : 'off'}`;
    pill.textContent = st.duty ? `En service · ${statusOf(st.status).label}` : 'Hors service';
  }

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || 'Dynasty 8'; }
  function loading() { body().insertAdjacentHTML('afterbegin', '<div class="loading-bar"></div>'); }
  function stopTimers() { clearInterval(T.timer); T.timer = null; if (T.map) { T.map.destroy(); T.map = null; } }
  function every(ms, fn) { clearInterval(T.timer); T.timer = setInterval(fn, ms); }
  const typing = () => { const a = document.activeElement; return a && a.closest && a.closest('#tabBody') && a.matches('input,textarea,select'); };
  async function call(action, data, btn) {
    if (btn) btn.classList.add('loading');
    const r = await req(action, data);
    if (btn) btn.classList.remove('loading');
    if (r.error) toast(r.error, false); else if (r.message) toast(r.message, true);
    return r;
  }
  async function go(page, keepSub) {
    stopTimers();
    const nav = NAV.find((n) => n.id === page);
    if (!nav || !allowed(nav)) page = 'dashboard';
    T.page = page;
    T.gen++;
    if (!keepSub) { PS_.sel = null; ES.cid = null; }
    renderNav();
    const n = NAV.find((x) => x.id === page);
    setTitle(n.label, n.group);
    body().scrollTop = 0;
    loading();
    await PAGES[page](T.gen);
  }
  const stale = (g) => g !== T.gen || !T.open;
  const PAGES = {};

  /* ------------------------------------------------------------------ */
  /* Tableau de bord                                                     */
  /* ------------------------------------------------------------------ */
  PAGES.dashboard = async (g) => {
    const d = await req('dashboard');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const t = d.me.times || {}, c = d.counts || {};
    body().innerHTML = `
      <div class="stats">
        <div class="stat green"><b>${c.available || 0}</b><span>Biens disponibles</span></div>
        <div class="stat orange"><b>${c.rented || 0}</b><span>Biens loués</span></div>
        <div class="stat red"><b>${c.sold || 0}</b><span>Biens vendus</span></div>
        <div class="stat blue"><b>${money(d.revenue.week)}</b><span>Encaissé (7 jours) · ${money(d.revenue.today)} aujourd'hui</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Dernières ventes et locations</h2>${d.last.map((l) => `<div class="list-row"><div class="main"><b>${esc(l.name || '—')}</b>
          <small>${esc(KIND[l.kind] || l.kind)}${l.kind === 'rent' ? ` · ${l.days} j` : ''}${l.holder_name ? ` · ${esc(l.holder_name)}` : ''} · ${esc(l.employee_name || '')} · ${fmtTime(l.t)}</small></div>
          <span class="mono nw">${money(l.price)}</span></div>`).join('') || empty('Aucun contrat.')}</div>
        <div class="card"><h2>Locations bientôt expirées</h2>${d.soon.map((s) => `<div class="alert-row click" style="--c:#f97316" data-prop="${s.pid}"><div class="t"><span>${esc(s.name)}</span><span class="faint">${fmtTime(s.ends)}</span></div>
          <div class="m">${s.holder ? `${esc(s.holder)} · ` : ''}reste ${left(s.ends - d.now)}</div></div>`).join('') || empty('Aucune location n\'expire bientôt.')}</div>
        <div class="card"><h2>Dernières visites</h2>${d.visits.map((v) => `<div class="list-row"><div class="main"><b>${esc(v.name || '—')}</b><small>${esc(v.employee_name || '')}${v.clients ? ` · ${esc(v.clients)}` : ''} · ${ago(v.t)}</small></div></div>`).join('') || empty('Aucune visite.')}</div>
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session</span><b class="mono">${dur(t.session)}</b><span>Non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b><span>Taux</span><b>${money(t.rate)} / h</b></div>
          <div class="actions-row"><button class="btn small" data-q="available">🟢 Biens disponibles</button><button class="btn small" data-q="map">🗺️ Carte</button>
            <button class="btn danger small" data-resign="1">Quitter Dynasty 8</button></div></div>
        <div class="card"><h2>Parc immobilier</h2><div class="kv"><span>Appartements</span><b>${c.apartment || 0}</b><span>Maisons</span><b>${c.house || 0}</b><span>Villas</span><b>${c.villa || 0}</b>
          <span>Garages seuls</span><b>${c.garage || 0}</b><span>Réservés</span><b>${c.reserved || 0}</b></div></div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div></div>`;
    every(10000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Biens : disponibles / indisponibles + fiche                          */
  /* ------------------------------------------------------------------ */
  const PS_ = { list: null, full: false, f: { q: '', cat: '', garage: '' }, sel: null, info: null };
  async function loadProps() { const d = await req('props'); if (!d.error) { PS_.list = d.list; PS_.full = d.full; } return d; }
  const matches = (p) => {
    const f = PS_.f, q = f.q.trim().toLowerCase();
    return (!q || `${p.name} ${p.address} ${catLabel(p.category)} ${(p.contract && p.contract.holder) || ''} ${propStatus(p.status).label}`.toLowerCase().includes(q))
      && (!f.cat || p.category === f.cat) && (!f.garage || (f.garage === 'yes' ? p.hasGarage : !p.hasGarage));
  };
  const filters = () => `<div class="toolbar"><input class="input grow" data-pf="q" placeholder="Rechercher : nom, adresse, catégorie, statut${PS_.full ? ', occupant' : ''}" value="${esc(PS_.f.q)}">
      <select class="input" data-pf="cat"><option value="">Toutes catégories</option>${Object.entries(APP.cats).map(([k, l]) => `<option value="${k}" ${PS_.f.cat === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>
      <select class="input" data-pf="garage"><option value="">Avec ou sans garage</option><option value="yes" ${PS_.f.garage === 'yes' ? 'selected' : ''}>Avec garage</option><option value="no" ${PS_.f.garage === 'no' ? 'selected' : ''}>Sans garage</option></select></div>`;
  function card(p, avail) {
    const c = p.contract;
    return `<div class="prop-card ${PS_.sel === p.id ? 'sel' : ''}"><div><h3>${CAT_ICO[p.category] || ''} ${esc(p.name)} ${propPill(p.status)}</h3>
        <div class="meta">${esc(p.address || '')} · ${esc(catLabel(p.category))}${p.interior ? ` · ${esc(p.interior)}` : ''}${p.hasGarage ? ` · garage ${p.garage.capacity} place(s)` : ' · sans garage'}${p.visit ? ` · 🔑 visite par ${esc(p.visit)}` : ''}${p.reservedBy ? ` · réservé par ${esc(p.reservedBy)}` : ''}</div>
        ${!avail && c ? `<div class="meta">${c.kind === 'sale' ? '<b style="color:#fca5a5">Vendu</b>' : `<b style="color:#fdba74">Location</b> · jusqu'au ${fmtTime(c.ends)} · reste ${left(c.remaining)}`}${c.holder ? ` · ${esc(c.holder)}${c.phone ? ` · 📞 ${esc(c.phone)}` : ''}` : ''}</div>` : ''}</div>
      <div class="price">${avail ? `${p.salePrice != null ? `${money(p.salePrice)}<small>à la vente</small>` : ''}${p.rentPrice != null ? `<div>${money(p.rentPrice)}<small>par jour de location</small></div>` : ''}` : (c ? money(c.price || 0) : '')}</div>
      <div class="acts"><button class="btn small" data-prop="${p.id}">Fiche</button>${p.x != null ? `<button class="btn small" data-gps="${p.x},${p.y}">📍 GPS</button>` : ''}
        ${avail && can('visits') && p.status === 'available' ? `<button class="btn small" data-visit="${p.id}">🔑 Faire visiter</button>` : ''}
        ${avail && (can('sell') || can('rent')) ? `<button class="btn small primary" data-assign="${p.id}">Vendre / louer</button>` : ''}</div></div>`;
  }
  async function listPage(g, avail) {
    const d = await loadProps();
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    drawList(avail);
    every(15000, async () => { if (!typing() && (T.page === 'available' || T.page === 'unavailable')) { await loadProps(); drawList(avail); } });
  }
  function drawList(avail) {
    const list = (PS_.list || []).filter((p) => (avail ? (p.status === 'available' || p.status === 'reserved') : (p.status === 'rented' || p.status === 'sold')) && matches(p));
    body().innerHTML = filters() + (avail ? '' : (PS_.full ? '' : '<div class="note">Les occupants et contrats sont visibles avec la permission « Voir les biens occupés ».</div>'))
      + (list.map((p) => card(p, avail)).join('') || empty(avail ? 'Aucun bien disponible ne correspond.' : 'Aucun bien loué ou vendu ne correspond.'));
  }
  PAGES.available = (g) => listPage(g, true);
  PAGES.unavailable = (g) => listPage(g, false);

  async function openProp(pid) {
    const r = await req('propInfo', { pid });
    if (r.error) return toast(r.error, false);
    PS_.info = r.prop;
    const p = r.prop, c = p.contract;
    const avail = p.status === 'available' || p.status === 'reserved';
    const v = await confirmBox(p.name, `<div class="recap"><span>Adresse</span><b>${esc(p.address || '—')}</b><span>Catégorie</span><b>${esc(catLabel(p.category))}</b>
        <span>Statut</span><b>${propPill(p.status)}</b>${p.interior ? `<span>Intérieur</span><b>${esc(p.interior)}</b>` : ''}
        <span>Garage</span><b>${p.hasGarage ? `${esc((APP.cfg && APP.cfg.garageSizes && APP.cfg.garageSizes[p.garageSize] || {}).label || 'Garage')} · ${p.garage.capacity} place(s)` : 'Aucun'}</b>
        ${p.salePrice != null ? `<span>Prix de vente</span><b>${money(p.salePrice)}</b>` : ''}${p.rentPrice != null ? `<span>Location</span><b>${money(p.rentPrice)} / jour (${p.rentMin} à ${p.rentMax} j)</b>` : ''}
        ${c ? `<span>Contrat</span><b>${c.kind === 'sale' ? 'Vendu' : 'Location'}${c.holder ? ` · ${esc(c.holder)}` : ''}</b>${c.phone ? `<span>Téléphone</span><b>${esc(c.phone)}</b>` : ''}
          <span>Début</span><b>${fmtTime(c.starts)}</b>${c.kind === 'rent' ? `<span>Fin</span><b>${fmtTime(c.ends)} · reste ${left(c.remaining)}</b><span>Durée payée</span><b>${c.days} j</b>` : ''}
          ${c.paid != null ? `<span>Payé</span><b>${money(c.paid)} (${c.method === 'cash' ? 'espèces' : 'banque'})</b><span>Agent</span><b>${esc(c.employee || '')}</b>` : ''}` : ''}</div>
      ${p.tenants && p.tenants.length ? `<p class="lead">Locataires ajoutés : ${p.tenants.map((t) => esc(t.name)).join(', ')}</p>` : ''}
      ${p.payments && p.payments.length ? `<h3 style="font-size:.85rem;margin:.6rem 0 .3rem">Paiements</h3>${p.payments.map((x) => `<div class="list-row"><div class="main"><b class="mono" style="font-size:.78rem">${esc(x.txid)}</b><small>${esc(PKIND[x.kind] || x.kind)} · ${esc(x.payer_name || '')} · ${fmtTime(x.t)}${x.note ? ` · ${esc(x.note)}` : ''}</small></div><b class="mono">${money(x.amount)} · ${esc(PST[x.status] || x.status)}</b></div>`).join('')}` : ''}
      ${p.history && p.history.length ? `<h3 style="font-size:.85rem;margin:.6rem 0 .3rem">Historique des contrats</h3>${p.history.map((h) => `<div class="list-row"><div class="main"><b>${esc(KIND[h.kind] || h.kind)} · ${esc(h.holder_name || '')}</b><small>${fmtTime(h.s)} → ${h.e ? fmtTime(h.e) : '…'} · ${esc(CSTAT[h.status] || h.status)}${h.end_reason ? ` · ${esc(h.end_reason)}` : ''}</small></div><span class="mono">${money(h.price)}</span></div>`).join('')}` : ''}`,
      'Valider', false,
      `<div class="actions-row">${avail && p.canVisit && p.status === 'available' ? '<label class="extra"><input type="checkbox" class="check" data-cfv="visit"> Commencer une visite commerciale</label>' : ''}${avail && (p.canSell || p.canRent) ? '<label class="extra"><input type="checkbox" class="check" data-cfv="assign"> Préparer une vente / location</label>' : ''}
        ${avail && p.canManage ? `<label class="extra"><input type="checkbox" class="check" data-cfv="reserve"> ${p.status === 'reserved' ? 'Lever la réservation' : 'Réserver ce bien'}</label>` : ''}
        ${c && p.canManage ? '<label class="extra"><input type="checkbox" class="check" data-cfv="terminate"> Résilier le contrat</label>' : ''}
        ${p.canPrices ? '<label class="extra"><input type="checkbox" class="check" data-cfv="prices"> Modifier les tarifs</label>' : ''}</div>`);
    if (!v) return;
    if (v.visit) { const r = await call('visitStart', { pid: p.id }); if (r.ok) post('close', { ui: 'tablet' }); return; }
    if (v.assign) return assignForm(p);
    if (v.reserve) { await call('reserve', { pid: p.id, on: p.status !== 'reserved' }); return go(T.page, true); }
    if (v.terminate) {
      const x = await confirmBox('Résilier le contrat ?', `<b>${esc(p.name)}</b> redevient disponible. Coffre archivé (rien n'est transmis au suivant), véhicules renvoyés au garage public. Aucun remboursement automatique.`, 'Résilier', true,
        '<label class="field" style="margin-top:.6rem"><span>Motif (obligatoire)</span><input class="input" data-cfv="reason" maxlength="120"></label>');
      if (!x) return;
      await call('terminate', { pid: p.id, reason: x.reason });
      return go(T.page, true);
    }
    if (v.prices) return pricesForm(p);
  }

  async function assignForm(p) {
    const n = await req('nearby');
    if (!n.list || !n.list.length) return toast('Aucun client à moins de 6 m.', false);
    const kinds = [];
    if (p.canSell && p.salePrice != null) kinds.push(['sale', `Vente · ${money(p.salePrice)}`]);
    if (p.canRent && p.rentPrice != null) kinds.push(['rent', `Location · ${money(p.rentPrice)} / jour`]);
    if (!kinds.length) return toast('Ce bien n\'est proposé ni à la vente ni à la location pour votre grade.', false);
    const v = await confirmBox(`Préparer : ${p.name}`, `<div class="recap"><span>Bien</span><b>${esc(p.name)}</b><span>Adresse</span><b>${esc(p.address || '—')}</b><span>Catégorie</span><b>${esc(catLabel(p.category))}</b>
        <span>Agent</span><b>${esc((T.st || {}).name || '')}</b></div>`, 'Envoyer l\'offre au client', false,
      `<div class="form-grid"><label class="field"><span>Transaction</span><select class="input" data-cfv="kind">${kinds.map(([k, l]) => `<option value="${k}">${esc(l)}</option>`).join('')}</select></label>
        <label class="field"><span>Client (à côté de vous)</span><select class="input" data-cfv="target">${n.list.map((x) => `<option value="${x.id}">${esc(x.name)} · ID ${x.id} · ${x.distance} m</option>`).join('')}</select></label>
        <label class="field"><span>Durée de location (jours, ${p.rentMin} à ${p.rentMax})</span><input class="input" type="number" min="${p.rentMin}" max="${p.rentMax}" value="${p.rentMin}" data-cfv="days"></label>
        <label class="field"><span>Paiement</span><select class="input" data-cfv="method"><option value="bank">Banque</option><option value="cash">Espèces</option></select></label></div>
       <p class="faint" style="font-size:.78rem;margin-top:.5rem">Le client voit le récapitulatif (nom, prix, durée, paiement) et signe sur son écran. Le serveur recalcule le prix, vérifie les fonds et attribue le bien.</p>`);
    if (!v) return;
    await call('assignOffer', { pid: p.id, kind: v.kind, target: Number(v.target), days: Number(v.days), method: v.method });
  }

  async function pricesForm(p) {
    const v = await confirmBox(`Tarifs : ${p.name}`, 'Les nouveaux prix ne s\'appliquent qu\'aux prochains contrats.', 'Enregistrer', false,
      `<div class="form-grid"><label class="field"><span>Prix de vente ($)</span><input class="input" type="number" min="0" value="${p.salePrice ?? 0}" data-cfv="sale"></label>
        <label class="field"><span>Location ($ / jour)</span><input class="input" type="number" min="0" value="${p.rentPrice ?? 0}" data-cfv="rent"></label>
        <label class="field"><span>Prolongation ($ / jour, vide = tarif du contrat)</span><input class="input" type="number" min="0" value="${p.extendPrice ?? ''}" data-cfv="ext"></label>
        <label class="field"><span>Durée min / max (jours)</span><span style="display:flex;gap:.4rem"><input class="input" type="number" min="1" value="${p.rentMin}" data-cfv="min"><input class="input" type="number" min="1" value="${p.rentMax}" data-cfv="max"></span></label>
        <label class="extra"><input type="checkbox" class="check" data-cfv="forSale" ${p.forSale ? 'checked' : ''}> À vendre</label><label class="extra"><input type="checkbox" class="check" data-cfv="forRent" ${p.forRent ? 'checked' : ''}> À louer</label></div>`);
    if (!v) return;
    await call('pricesSave', { pid: p.id, salePrice: Number(v.sale), rentPrice: Number(v.rent), extendPrice: v.ext === '' ? '' : Number(v.ext), rentMin: Number(v.min), rentMax: Number(v.max), forSale: v.forSale, forRent: v.forRent });
    return go(T.page, true);
  }

  /* ------------------------------------------------------------------ */
  /* Carte : vert disponible, orange en location, rouge vendu             */
  /* ------------------------------------------------------------------ */
  const MS = { data: null, sel: null, f: { cat: '', st: '' } };
  const MAPCOL = { available: '#22c55e', reserved: '#a855f7', rented: '#f97316', sold: '#ef4444' };
  PAGES.map = async (g) => {
    body().innerHTML = `<div class="toolbar">${[['', 'Tout'], ['apartment', 'Appartements'], ['house', 'Maisons'], ['villa', 'Villas'], ['garage', 'Garages']].map(([k, l]) => `<button class="btn small ${MS.f.cat === k ? 'primary' : ''}" data-mcat="${k}">${l}</button>`).join('')}
        <span style="width:1rem"></span>${[['', 'Tous statuts'], ['available', 'Disponibles'], ['rented', 'Loués'], ['sold', 'Vendus']].map(([k, l]) => `<button class="btn small ${MS.f.st === k ? 'primary' : ''}" data-mst="${k}">${l}</button>`).join('')}</div>
      <div class="map-wrap"><div class="map-box" id="mapBox"><div class="map-tools"><button class="icon-btn" data-m="in">+</button><button class="icon-btn" data-m="out">−</button><button class="icon-btn" data-m="fit">⤢</button></div>
        <div class="map-legend"><span><i style="background:#22c55e"></i>Disponible</span><span><i style="background:#f97316"></i>En location</span><span><i style="background:#ef4444"></i>Vendu</span><span><i style="background:#a855f7"></i>Réservé</span><span><i style="background:#3b82f6"></i>Agent</span></div></div>
      <div class="map-side"><div class="card" id="mapSel"></div></div></div>`;
    T.map = D8Map.create($('#mapBox'), { image: APP.cfg && APP.cfg.map && APP.cfg.map.file ? APP.cfg.map : null, levels: {},
      onSelect: (s) => { MS.sel = s; renderSel(); } });
    const refresh = async () => {
      const d = await req('map');
      if (stale(g) || T.page !== 'map' || d.error) return;
      MS.data = d;
      const props = d.props.filter((p) => p.x != null && (!MS.f.cat || p.category === MS.f.cat || (MS.f.cat === 'garage' && p.hasGarage)) && (!MS.f.st || p.status === MS.f.st))
        .map((p) => ({ ...p, color: MAPCOL[p.status] || '#94a3b8' }));
      MS.props = props;
      T.map.setData(d.crew, [], props);
      renderSel();
    };
    await refresh();
    every(Math.max(3000, (APP.cfg && APP.cfg.mapRefresh) || 5000), refresh);
  };
  function renderSel() {
    const el = $('#mapSel');
    if (!el) return;
    const s = MS.sel;
    if (!s) { el.innerHTML = '<h2>Sélection</h2><div class="faint" style="font-size:.85rem">Cliquez sur un bien ou un agent.</div>'; return; }
    const o = s.data;
    if (s.kind === 'agent') { el.innerHTML = `<h2>${esc(o.name)}</h2><div class="kv"><span>Grade</span><b>${esc(o.grade)}</b><span>Statut</span><b>${statusPill(o.status)}</b></div>`; return; }
    el.innerHTML = `<h2>${CAT_ICO[o.category] || ''} ${esc(o.name)}</h2><div class="kv"><span>Adresse</span><b>${esc(o.address || '—')}</b><span>Catégorie</span><b>${esc(catLabel(o.category))}</b>
      <span>Statut</span><b>${propPill(o.status)}</b><span>Garage</span><b>${o.hasGarage ? `${o.garage.capacity} place(s)` : 'Aucun'}</b>
      ${o.status === 'available' && o.salePrice != null ? `<span>Vente</span><b>${money(o.salePrice)}</b>` : ''}${o.status === 'available' && o.rentPrice != null ? `<span>Location</span><b>${money(o.rentPrice)} / j</b>` : ''}</div>
      <div class="actions-row"><button class="btn small" data-prop="${o.id}">Fiche</button><button class="btn small" data-gps="${o.x},${o.y}">📍 GPS</button></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Contrats et visites                                                 */
  /* ------------------------------------------------------------------ */
  const CS_ = { q: '', status: '' };
  PAGES.contracts = async (g) => {
    const d = await req('contracts', CS_);
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="cq" placeholder="Rechercher : contrat, client, bien, adresse" value="${esc(CS_.q)}">
        <select class="input" data-cs="status"><option value="">Tous</option>${Object.entries(CSTAT).map(([k, l]) => `<option value="${k}" ${CS_.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <button class="btn" data-csearch="1">Rechercher</button></div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Contrat</th><th>Bien</th><th>Type</th><th>Client</th><th>Montant</th><th>Période</th><th>Statut</th></tr>${d.list.map((c) => `<tr class="click" data-prop="${c.property_id}">
        <td class="mono" style="font-size:.76rem">${esc(c.uid)}<br><span class="faint">${esc(c.employee_name || '')}</span></td><td><b>${esc(c.name || '—')}</b><br><small class="faint">${esc(c.address || '')}</small></td>
        <td>${esc(KIND[c.kind] || c.kind)}${c.kind === 'rent' ? `<br><small class="faint">${c.days} j</small>` : ''}</td><td>${esc(c.holder_name || '—')}${c.holder_phone ? `<br><small class="faint">📞 ${esc(c.holder_phone)}</small>` : ''}</td>
        <td class="mono nw">${money(c.paid_total)}<br><small class="faint">${c.method === 'cash' ? 'espèces' : 'banque'}</small></td><td class="muted">${fmtTime(c.s)}<br>${c.e ? `→ ${fmtTime(c.e)}` : ''}</td>
        <td>${esc(CSTAT[c.status] || c.status)}${c.end_reason ? `<br><small class="faint">${esc(c.end_reason)}</small>` : ''}</td></tr>`).join('')}</table>` : empty('Aucun contrat.')}</div>`;
  };
  PAGES.visits = async (g) => {
    const d = await req('visits');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">Une visite se lance depuis un bien disponible (« Faire visiter »). L'agent et les clients invités (F6 › Visite commerciale) entrent sans aucun droit permanent ; la visite se ferme à la fin, après ${(APP.cfg && APP.cfg.visitMinutes) || 30} min ou si le bien est attribué.</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Bien</th><th>Agent</th><th>Clients</th><th>Début</th><th>Fin</th></tr>${d.list.map((v) => `<tr><td><b>${esc(v.name || '—')}</b></td><td>${esc(v.employee_name || '')}</td>
        <td class="muted">${esc(v.clients || '—')}</td><td class="muted">${fmtTime(v.s)}</td><td class="muted">${v.e ? `${fmtTime(v.e)}<br><small>${esc(v.end_reason || '')}</small>` : '<span class="pill on">En cours</span>'}</td></tr>`).join('')}</table>` : empty('Aucune visite.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Recrutement                                                         */
  /* ------------------------------------------------------------------ */
  const RC = { preview: null };
  PAGES.recruit = async () => {
    const p = RC.preview;
    body().innerHTML = `<div class="note">La demande est envoyée à la <b>personne la plus proche</b> de vous. Elle reçoit une proposition « Accepter / Refuser » (30 secondes). Vous ne pouvez recruter qu'à un grade inférieur au vôtre ; le métier est donné par le framework (elyzea_core).</div>
      <div class="card" style="max-width:40rem"><h2>Recruter</h2><button class="btn primary" data-rc="find">🔎 Rechercher la personne la plus proche</button>
        ${p ? `<div style="margin-top:1rem" class="card"><div class="list-row"><span class="avatar">${initials(p.target.name)}</span><div class="main"><b>${esc(p.target.name)}</b><small>À ${p.target.distance} m · métier actuel : ${esc(p.target.job)}</small></div></div>
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne fait déjà partie de Dynasty 8.</p>' : ''}
          ${p.target.pending ? '<p style="color:#fcd34d;font-size:.84rem;margin-top:.6rem">Une demande est déjà en attente pour cette personne.</p>' : ''}
          <div class="form-grid" style="margin-top:.8rem"><label class="field"><span>Grade de départ</span><select class="input" id="rcGrade">${p.grades.map((gr) => `<option value="${gr.id}" ${gr.id === p.defaultGrade ? 'selected' : ''}>${esc(gr.name)} (niveau ${gr.level})</option>`).join('')}</select></label></div>
          <div class="actions-row"><button class="btn primary" data-rc="send" ${p.target.already || p.target.pending || !p.grades.length ? 'disabled' : ''}>Envoyer la demande</button><button class="btn" data-rc="clear">Annuler</button></div></div>` : ''}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Employés                                                            */
  /* ------------------------------------------------------------------ */
  const ES = { cid: null, f: { q: '', grade: '', state: '' }, data: null, emp: null };
  PAGES.employees = async (g) => {
    const d = await req('employees');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    ES.data = d;
    drawEmployees();
    if (ES.cid) await loadEmployee(ES.cid);
  };
  function drawEmployees() {
    const d = ES.data, f = ES.f, q = f.q.trim().toLowerCase();
    const list = d.list.filter((e) => (!q || e.name.toLowerCase().includes(q) || e.matricule.toLowerCase().includes(q)) && (!f.grade || String(e.gradeId) === f.grade)
      && (!f.state || (f.state === 'duty' ? e.duty : f.state === 'online' ? e.online : !e.online)));
    const rows = list.map((e) => `<tr class="click ${ES.cid === e.cid ? 'sel' : ''}" data-emp="${esc(e.cid)}"><td><b>${esc(e.name)}</b><br><small class="mono faint">${esc(e.matricule)}</small></td><td>${esc(e.grade)}</td>
      <td>${e.duty ? '<span class="pill on">En service</span>' : e.online ? '<span class="pill plain">Connecté</span>' : '<span class="pill off">Hors ligne</span>'}</td>
      <td class="mono">${dur(e.total)}</td><td class="mono">${dur(e.unpaid)}<br><small class="faint">${money(e.unpaidAmount)}</small></td></tr>`).join('');
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-ef="q" placeholder="Rechercher : nom ou matricule" value="${esc(f.q)}">
        <select class="input" data-ef="grade"><option value="">Tous les grades</option>${d.grades.map((gr) => `<option value="${gr.id}" ${String(gr.id) === f.grade ? 'selected' : ''}>${esc(gr.name)}</option>`).join('')}</select>
        <select class="input" data-ef="state">${[['', 'Tous'], ['duty', 'En service'], ['online', 'Connectés'], ['offline', 'Hors ligne']].map(([v, l]) => `<option value="${v}" ${f.state === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
      <div class="split"><div class="card" style="padding:.3rem .6rem">${list.length ? `<table class="tbl"><tr><th>Employé</th><th>Grade</th><th>Statut</th><th>Temps total</th><th>Non payé</th></tr>${rows}</table>` : empty('Aucun employé ne correspond.')}</div>
        <div class="detail" id="empDetail"><div class="card"><h2>Fiche</h2><div class="faint" style="font-size:.85rem">Sélectionnez un employé.</div></div></div></div>`;
    if (ES.emp && ES.cid) drawEmployee();
  }
  async function loadEmployee(cid) {
    ES.cid = cid;
    const r = await req('employee', { cid });
    if (r.error) { toast(r.error, false); ES.cid = null; ES.emp = null; return; }
    ES.emp = r.employee;
    document.querySelectorAll('[data-emp]').forEach((tr) => tr.classList.toggle('sel', tr.dataset.emp === cid));
    drawEmployee();
  }
  function gradeSteps(e) {
    const gs = ES.data.grades, my = ES.data.myLevel;
    return { up: gs.filter((g) => g.level > e.level && g.level < my).sort((a, b) => a.level - b.level)[0],
      down: gs.filter((g) => g.level < e.level).sort((a, b) => b.level - a.level)[0], choices: gs.filter((g) => g.level < my && g.id !== e.gradeId) };
  }
  function drawEmployee() {
    const e = ES.emp, el = $('#empDetail');
    if (!e || !el) return;
    const s = gradeSteps(e);
    el.innerHTML = `<div class="card"><div class="list-row" style="padding:0 0 .8rem"><span class="avatar">${initials(e.name)}</span><div class="main"><b>${esc(e.name)}</b><small class="mono">${esc(e.matricule)}</small></div>
        ${e.duty ? '<span class="pill on">En service</span>' : e.online ? '<span class="pill plain">Connecté</span>' : '<span class="pill off">Hors ligne</span>'}</div>
      <div class="kv"><span>Grade</span><b>${esc(e.grade)} <span class="faint">(niv. ${e.level})</span></b><span>Recrutement</span><b>${esc(e.recruited || '—')}</b><span>Dernière promotion</span><b>${esc(e.promoted || '—')}</b>
        <span>Temps total</span><b class="mono">${dur(e.total)}</b><span>Temps non payé</span><b class="mono">${dur(e.unpaid)} · ${money(e.unpaidAmount)}</b>
        <span>Contrats signés</span><b>${e.contracts || 0}</b><span>Visites</span><b>${e.visits || 0}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${e.canAct ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'}>▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de Dynasty 8</button>' : ''}</div>`
        : `<p class="faint" style="font-size:.8rem;margin-top:.8rem">${e.cid === ES.data.myCid ? 'C\'est votre fiche : vous ne pouvez pas modifier votre propre grade.' : 'Grade égal ou supérieur au vôtre : aucune action possible.'}</p>`}</div>
      <div class="card"><h2>Sessions de service</h2>${(e.sessions || []).map((x) => `<div class="list-row"><div class="main"><b class="mono" style="font-weight:500">${fmtTime(x.s)} → ${x.e ? fmtTime(x.e) : 'en cours'}</b>
        <small>${esc(x.grade_name || '')}${x.end_reason ? ` · ${esc(x.end_reason)}` : ''}</small></div><span class="mono nw">${dur(x.seconds)} · ${money(x.amount)}</span></div>`).join('') || empty('Aucune session.')}</div>
      ${e.history ? `<div class="card"><h2>Historique des grades</h2><div class="timeline">${e.history.map((h) => `<div><b>${esc(h.action)}</b>${h.old_grade || h.new_grade ? ` · ${esc(h.old_grade || '—')} → ${esc(h.new_grade || '—')}` : ''}
        <small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}${h.reason ? ` · « ${esc(h.reason)} »` : ''}</small></div>`).join('') || '<span class="faint">Aucune opération.</span>'}</div></div>` : ''}`;
  }
  async function changeGrade(e, target, kind) {
    const me = T.st || {};
    const v = await confirmBox(kind, `<div class="kv"><span>Employé</span><b>${esc(e.name)}</b><span>Grade actuel</span><b>${esc(e.grade)}</b><span>Nouveau grade</span><b>${esc(target.name)}</b><span>Responsable</span><b>${esc(me.grade || '')} · ${esc(me.matricule || '')}</b></div>
      <p class="faint" style="margin-top:.5rem;font-size:.8rem">Le grade est appliqué dans le framework. Le temps déjà fait reste payé au taux de l'ancien grade.</p>`,
      'Confirmer', kind === 'Rétrograder', '<label class="field" style="margin-top:.8rem"><span>Motif (facultatif)</span><input class="input" data-cfv="reason" maxlength="200"></label>');
    if (!v) return;
    const r = await call('setGrade', { cid: e.cid, gradeId: target.id, reason: v.reason });
    if (r.ok) await PAGES.employees(T.gen);
  }

  /* ------------------------------------------------------------------ */
  /* Grades (sans salaire : les taux horaires sont dans Finance)          */
  /* ------------------------------------------------------------------ */
  const GS = { data: null, edit: null };
  PAGES.grades = async (g) => {
    const d = await req('grades');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    GS.data = d;
    drawGrades();
  };
  function drawGrades() {
    const d = GS.data, ed = GS.edit;
    const list = [...d.list].sort((a, b) => b.level - a.level);
    body().innerHTML = `${d.canGrades ? '' : '<div class="note">Consultation seule : la création et la modification demandent la permission « Créer, modifier et désactiver les grades ».</div>'}
      <div class="split"><div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Niveau</th><th>Grade</th><th>Effectif</th><th></th></tr>
        ${list.map((gr) => `<tr style="${gr.active ? '' : 'opacity:.55'}"><td class="mono">${gr.level}</td><td><b>${esc(gr.name)}</b> ${gr.isDefault ? '<span class="tag">Recrues</span>' : ''}${gr.perms.includes('direction') ? ' <span class="tag">Direction</span>' : ''}${gr.active ? '' : ' <span class="tag">Désactivé</span>'}</td><td>${gr.members}</td>
          <td style="text-align:right;white-space:nowrap">${d.canGrades && gr.level < d.myLevel ? `<button class="btn small" data-g="edit" data-id="${gr.id}">Modifier</button> <button class="btn small danger" data-g="del" data-id="${gr.id}">Supprimer</button>` : '<span class="faint" style="font-size:.75rem">—</span>'}</td></tr>`).join('')}</table></div>
        <div class="detail">${d.canGrades ? `<div class="card"><h2>${ed && ed.id ? 'Modifier le grade' : 'Créer un grade'}</h2><div class="form-grid">
          <label class="field full"><span>Nom</span><input class="input" id="gName" maxlength="50" value="${esc(ed ? ed.name : '')}" placeholder="ex : Carrossier"></label>
          <label class="field"><span>Niveau (hiérarchie)</span><input class="input" id="gLevel" type="number" min="1" max="${d.myLevel - 1}" value="${ed ? ed.level : ''}" placeholder="1 à ${d.myLevel - 1}"></label>
          <label class="field full" style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" class="check" id="gDefault" ${ed && ed.isDefault ? 'checked' : ''}><span style="font-size:.85rem;color:var(--text)">Grade donné aux nouvelles recrues</span></label>
          <label class="field full" style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" class="check" id="gActive" ${!ed || ed.active ? 'checked' : ''}><span style="font-size:.85rem;color:var(--text)">Actif (désactivé : plus donné ni proposé, les employés le gardent)</span></label></div>
          <div class="actions-row"><button class="btn primary" data-g="save">${ed && ed.id ? 'Enregistrer' : 'Créer le grade'}</button>${ed ? '<button class="btn" data-g="cancel">Annuler</button>' : ''}</div>
          <p class="faint" style="font-size:.76rem;margin-top:.7rem">Permissions : onglet Permissions. Taux horaire : Finance. Les grades sont synchronisés avec le métier du framework. Supprimer un grade réaffecte d'abord ses employés ; le désactiver ne touche à aucune donnée. Votre niveau : ${d.myLevel}.</p></div>` : ''}</div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Permissions                                                         */
  /* ------------------------------------------------------------------ */
  const PS = { data: null, dirty: {} };
  PAGES.perms = async (g) => {
    const d = await req('grades');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    PS.data = d; PS.dirty = {};
    d.list.forEach((gr) => { gr.set = new Set(gr.perms); });
    drawPerms();
  };
  function drawPerms() {
    const d = PS.data, grades = [...d.list].sort((a, b) => a.level - b.level);
    let last = null, rows = '';
    d.permList.forEach((p) => {
      if (p.group !== last) { rows += `<tr class="grp"><td colspan="${grades.length + 1}">${esc(p.group)}</td></tr>`; last = p.group; }
      rows += `<tr><td>${esc(p.label)}</td>${grades.map((gr) => { const ok = d.canPerms && gr.level < d.myLevel && d.myPerms[p.key];
        return `<td><input type="checkbox" class="check" data-pg="${gr.id}" data-pk="${p.key}" ${gr.set.has(p.key) ? 'checked' : ''} ${ok ? '' : 'disabled'}></td>`; }).join('')}</tr>`;
    });
    const n = Object.keys(PS.dirty).length;
    body().innerHTML = `<div class="note">Vous ne modifiez que les grades <b>inférieurs</b> au vôtre, et seulement avec les permissions que vous possédez. Appliqué immédiatement aux employés connectés.</div>
      <div class="toolbar"><span class="muted" style="font-size:.85rem" id="permCount">${n ? `${n} grade(s) modifié(s)` : 'Aucune modification'}</span><span style="flex:1"></span>
        <button class="btn" data-p="reset" ${n ? '' : 'disabled'}>Annuler</button><button class="btn primary" data-p="save" ${n ? '' : 'disabled'}>Enregistrer</button></div>
      <div class="card" style="padding:.2rem .4rem;overflow-x:auto"><table class="perm-table"><tr><th>Permission</th>${grades.map((gr) => `<th>${esc(gr.name)}<br><span class="faint">niv. ${gr.level}</span></th>`).join('')}</tr>${rows}</table></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Historique du personnel                                             */
  /* ------------------------------------------------------------------ */
  const HS = { q: '' };
  PAGES.history = async (g) => {
    const d = await req('history', { q: HS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-hq placeholder="Rechercher : responsable, employé, action" value="${esc(HS.q)}"><button class="btn" data-h="search">Rechercher</button></div>
      ${d.list.length ? `<div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Date</th><th>Responsable</th><th>Employé</th><th>Action</th><th>Grade</th><th>Détail</th></tr>
        ${d.list.map((h) => `<tr><td class="muted">${fmtTime(h.t)}</td><td>${esc(h.actor_name || '—')}</td><td>${esc(h.target_name || '—')}</td><td><b>${esc(h.action)}</b></td>
          <td class="muted">${h.old_grade || h.new_grade ? `${esc(h.old_grade || '—')} → ${esc(h.new_grade || '—')}` : '—'}</td><td class="muted">${esc(h.reason || '')}</td></tr>`).join('')}</table></div>` : empty('Aucune opération enregistrée.')}`;
  };


  /* ------------------------------------------------------------------ */
  /* Finance : vue d'ensemble, salaires, taux horaires                    */
  /* ------------------------------------------------------------------ */
  const FS = { data: null, rates: null };
  PAGES.finance = async (g) => {
    const d = await req('finance');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    FS.data = d;
    const h = await req('rateHistory');
    FS.rates = h.list || [];
    if (stale(g)) return;
    drawFinance();
    every(10000, async () => {
      if (T.page !== 'finance' || typing()) return;
      const n = await req('finance');
      if (T.page !== 'finance' || n.error) return;
      FS.data = n; drawFinance();
    });
  };
  function drawFinance() {
    const d = FS.data, sm = (k) => (d.sums[k] || { total: 0, n: 0 });
    const income = sm('in:sale').total + sm('in:rent').total + sm('in:extend').total;
    const expense = sm('out:salary').total + sm('out:refund').total + sm('out:commission').total;
    const al = (k) => ((d.all || {})[k] || { total: 0, n: 0 });
    const rows = d.employees.map((e) => `<tr><td><b>${esc(e.name)}</b><br><small class="mono faint">${esc(e.matricule)}</small></td><td>${esc(e.grade)}</td>
      <td>${e.duty ? '<span class="pill on">En service</span>' : '<span class="pill off">Hors service</span>'}</td><td class="mono nw">${dur(e.seconds)}</td><td class="mono nw">${dur(e.total)}</td>
      <td class="nw"><b class="mono">${money(e.due)}</b></td>
      <td style="text-align:right">${d.canPay ? `<button class="btn small ${e.due > 0 ? 'primary' : ''}" data-fpay="${esc(e.cid)}" ${e.due > 0 ? '' : 'disabled'}>Payer</button>` : ''}</td></tr>`).join('');
    // Commission (%) du grade sur ce que l'employé fait encaisser
    const comBox = (gr) => `<div class="rate" title="Commission">${gr.commissionEditable ? `<input class="input" type="number" min="0" max="50" step="1" data-com="${gr.id}" value="${gr.commission || 0}"><span class="faint">%</span><button class="btn small" data-fcom="${gr.id}">OK</button>`
      : `<b class="mono">${gr.commission || 0} %</b>`}</div>`;
    const grades = [...d.grades].sort((a, b) => b.level - a.level).map((gr) => `<div class="list-row"><div class="main"><b>${esc(gr.name)}</b><small>Niv. ${gr.level} · ${gr.members} empl.</small></div>
      ${gr.editable ? `<div class="rate"><input class="input" type="number" min="0" step="10" data-rate="${gr.id}" value="${gr.rate}"><span class="faint">$/h</span><button class="btn small" data-frate="${gr.id}">OK</button></div>` : `<b class="mono">${money(gr.rate)}/h</b>`}${comBox(gr)}</div>`).join('');
    const sp = d.split || {};
    body().innerHTML = `<div class="stats">
        <div class="stat green"><b>${money(d.balance)}</b><span>Compte de l'entreprise</span></div>
        <div class="stat blue"><b>${money(income)}</b><span>Entrées (7 jours)</span></div>
        <div class="stat red"><b>${money(expense)}</b><span>Sorties (7 jours)</span></div>
        <div class="stat ${d.totalDue > d.balance ? 'red' : 'orange'}"><b>${money(d.totalDue)}</b><span>Salaires dus</span></div></div>
      <div class="split"><div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Salaires ${d.canPay ? `<button class="btn small primary" data-fpayall="1" ${d.totalDue > 0 ? '' : 'disabled'}>Payer tout le monde</button>` : ''}</h2>
          ${d.employees.length ? `<table class="tbl"><tr><th>Employé</th><th>Grade</th><th>Service</th><th>Non payé</th><th>Total</th><th>À payer</th><th></th></tr>${rows}</table>` : empty('Aucun employé.')}
          <p class="faint" style="font-size:.76rem;margin:.6rem .4rem">Chaque période est comptée au taux et au grade qu'elle avait : un changement de taux ou une promotion n'est jamais rétroactif. « Payer » recalcule le montant, vérifie le solde, débite le compte de l'entreprise puis crédite la banque de l'employé (même hors ligne) ; seul le temps payé est retiré.</p></div>
        <div class="cols even"><div class="card"><h2>Détail sur 7 jours</h2><div class="kv"><span>Ventes</span><b class="mono">+${money(sm('in:sale').total)} <span class="faint">(${sm('in:sale').n})</span></b>
            <span>Locations</span><b class="mono">+${money(sm('in:rent').total)} <span class="faint">(${sm('in:rent').n})</span></b><span>Prolongations</span><b class="mono">+${money(sm('in:extend').total)} <span class="faint">(${sm('in:extend').n})</span></b>
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)}</b></div></div>
          <div class="card"><h2>Depuis l'ouverture</h2><div class="kv"><span>Ventes</span><b class="mono">${money(al('in:sale').total)} <span class="faint">(${al('in:sale').n})</span></b>
            <span>Locations</span><b class="mono">${money(al('in:rent').total)} <span class="faint">(${al('in:rent').n})</span></b><span>Prolongations</span><b class="mono">${money(al('in:extend').total)}</b>
            <span>Salaires versés</span><b class="mono">${money(al('out:salary').total)}</b><span>Remboursements</span><b class="mono">${money(al('out:refund').total)}</b></div></div></div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur les ventes et locations signées, versée par l'entreprise. Appliqué à partir de maintenant.</p></div>
        <div class="card"><h2>Historique des taux</h2>${FS.rates.slice(0, 15).map((r) => `<div class="list-row"><div class="main"><b>${esc(r.grade_name)} · ${money(r.rate)}/h</b><small>${esc(r.actor_name || '')} · ${fmtTime(r.t)}</small></div></div>`).join('') || empty('Aucun changement.')}</div>
        <div class="card"><h2>Compte société : derniers mouvements</h2>${d.logs.map((l) => `<div class="list-row"><div class="main"><b style="font-weight:500">${esc(l.reason || '—')}</b><small>${l.t ? fmtTime(l.t) : ''}</small></div>
          <b class="mono" style="color:${l.amount < 0 ? '#fca5a5' : 'var(--green)'}">${l.amount < 0 ? '−' : '+'}${money(Math.abs(l.amount))}</b></div>`).join('') || empty('Aucun mouvement.')}</div></div></div>`;
  }
  async function financeAction(b) {
    if (b.dataset.fpay) {
      const e = FS.data.employees.find((x) => x.cid === b.dataset.fpay);
      if (!e) return;
      const ok = await confirmBox('Payer le salaire ?', `<div class="kv"><span>Employé</span><b>${esc(e.name)} · ${esc(e.matricule)}</b><span>Grade</span><b>${esc(e.grade)}</b>
        <span>Temps non payé</span><b>${dur(e.seconds)}</b><span>Montant</span><b>${money(e.due)}</b><span>Solde de l'entreprise</span><b>${money(FS.data.balance)}</b></div>
        <p class="faint" style="margin-top:.6rem">Le serveur recalcule le montant au moment du paiement (le service en cours continue d'être compté).</p>`, `Payer ${money(e.due)}`);
      if (!ok) return;
      await call('financePay', { cid: e.cid }, b);
      return PAGES.finance(T.gen);
    }
    if (b.dataset.fpayall) {
      const ok = await confirmBox('Payer tout le monde ?', `Environ <b>${money(FS.data.totalDue)}</b> seront versés (un paiement par employé, arrêt si les fonds manquent).`, 'Payer');
      if (!ok) return;
      await call('financePayAll', {}, b);
      return PAGES.finance(T.gen);
    }
    if (b.dataset.fcom) {
      const input = body().querySelector(`[data-com="${b.dataset.fcom}"]`);
      const gr = FS.data.grades.find((x) => String(x.id) === b.dataset.fcom);
      const pct = Number(input && input.value);
      if (!(await confirmBox('Changer la commission ?', `<b>${esc(gr ? gr.name : '')}</b> : ${gr ? gr.commission || 0 : 0} % → <b>${pct} %</b> sur les ventes et locations signées.<br>Versée depuis le compte de l'entreprise à chaque encaissement, à partir de maintenant.`, 'Appliquer'))) return;
      const r = await call('financeCommission', { id: Number(b.dataset.fcom), pct }, b);
      if (r.ok) return PAGES.finance(T.gen);
      return;
    }
    if (b.dataset.frate) {
      const input = body().querySelector(`[data-rate="${b.dataset.frate}"]`);
      const gr = FS.data.grades.find((x) => String(x.id) === b.dataset.frate);
      const rate = Number(input && input.value);
      if (!(await confirmBox('Changer le taux horaire ?', `<b>${esc(gr.name)}</b> : ${money(gr.rate)}/h → <b>${money(rate)}/h</b>.<br>Le temps déjà fait reste payé à l'ancien taux.`, 'Appliquer'))) return;
      const r = await call('financeRate', { id: gr.id, rate }, b);
      if (r.ok) return PAGES.finance(T.gen);
    }
  }

  /* ------------------------------------------------------------------ */
  /* Transactions                                                        */
  /* ------------------------------------------------------------------ */
  const TS = { q: '', category: '' };
  PAGES.transactions = async (g) => {
    const d = await req('transactions', TS);
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="tq" placeholder="Rechercher : identifiant, motif, personne" value="${esc(TS.q)}">
        <select class="input" data-tc><option value="">Toutes catégories</option>${Object.entries(CAT).map(([k, l]) => `<option value="${k}" ${TS.category === k ? 'selected' : ''}>${l}</option>`).join('')}</select><button class="btn" data-ts="1">Rechercher</button></div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Transaction</th><th>Catégorie</th><th>Motif</th><th>Personne</th><th>Par</th><th>Montant</th><th>Date</th></tr>${d.list.map((x) => `<tr>
        <td class="mono" style="font-size:.78rem">${esc(x.txid)}${x.ref ? `<br><span class="faint">${esc(x.ref)}</span>` : ''}</td><td>${esc(CAT[x.category] || x.category)}</td><td class="muted">${esc(x.reason || '')}${x.seconds ? ` · ${dur(x.seconds)}` : ''}</td>
        <td>${esc(x.target_name || '—')}</td><td class="muted">${esc(x.actor_name || '—')}</td><td class="mono nw" style="color:${x.type === 'out' ? '#fca5a5' : 'var(--green)'}">${x.type === 'out' ? '−' : '+'}${money(x.amount)}</td><td class="muted">${fmtTime(x.t)}</td></tr>`).join('')}</table>` : empty('Aucune transaction.')}</div>`;
  };

  /* ------------------------------------------------------------------ */

  /* ------------------------------------------------------------------ */
  /* Événements                                                          */
  /* ------------------------------------------------------------------ */
  $('#tabNav').addEventListener('click', (e) => { const b = e.target.closest('[data-nav]'); if (b) go(b.dataset.nav); });
  $('#tabClose').addEventListener('click', () => post('close', { ui: 'tablet' }));

  body().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.target.tagName === 'TEXTAREA') return;
    const t = e.target;
    if (t.dataset.hq !== undefined) { HS.q = t.value; return go('history'); }
    if (t.id === 'cq') { CS_.q = t.value; return go('contracts'); }
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.pf && t.dataset.pf !== 'q') { PS_.f[t.dataset.pf] = t.value; return drawList(T.page === 'available'); }
    if (t.dataset.cs) { CS_.status = t.value; CS_.q = ($('#cq') || {}).value || ''; return go('contracts'); }
    if (t.dataset.ef && t.dataset.ef !== 'q') { ES.f[t.dataset.ef] = t.value; return drawEmployees(); }
    if (t.dataset.tc !== undefined) { TS.category = t.value; TS.q = ($('#tq') || {}).value || ''; return go('transactions'); }
    if (t.dataset.pg) {
      const gr = PS.data.list.find((x) => String(x.id) === t.dataset.pg);
      if (t.checked) gr.set.add(t.dataset.pk); else gr.set.delete(t.dataset.pk);
      PS.dirty[gr.id] = true;
      const n = Object.keys(PS.dirty).length;
      document.querySelectorAll('[data-p]').forEach((b) => { b.disabled = !n; });
      const lab = $('#permCount'); if (lab) lab.textContent = `${n} grade(s) modifié(s)`;
    }
  });
  body().addEventListener('input', (e) => {
    const t = e.target;
    const keep = (sel, fn) => { const pos = t.selectionStart; fn(); const n = body().querySelector(sel); if (n) { n.focus(); n.setSelectionRange(pos, pos); } };
    if (t.dataset.pf === 'q') { PS_.f.q = t.value; return keep('[data-pf="q"]', () => drawList(T.page === 'available')); }
    if (t.dataset.ef === 'q') { ES.f.q = t.value; return keep('[data-ef="q"]', drawEmployees); }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) return go(b.dataset.q);
    if ((b = e.target.closest('[data-gps]'))) { const [x, y] = b.dataset.gps.split(',').map(Number); return post('gps', { x, y }); }
    if ((b = e.target.closest('[data-assign]'))) { const r = await req('propInfo', { pid: Number(b.dataset.assign) }); if (r.error) return toast(r.error, false); return assignForm(r.prop); }
    if ((b = e.target.closest('[data-visit]'))) {
      if (!(await confirmBox('Faire visiter ce bien ?', 'Vous pourrez entrer avec le client. Invitez-le ensuite avec F6 › Visite commerciale.', 'Commencer'))) return;
      const r = await call('visitStart', { pid: Number(b.dataset.visit) }, b);
      if (r.ok) post('close', { ui: 'tablet' });
      return;
    }
    if ((b = e.target.closest('[data-prop]'))) return openProp(Number(b.dataset.prop));
    if ((b = e.target.closest('[data-mcat]'))) { MS.f.cat = b.dataset.mcat; return go('map'); }
    if ((b = e.target.closest('[data-mst]'))) { MS.f.st = b.dataset.mst; return go('map'); }
    if ((b = e.target.closest('[data-m]')) && T.map) { const m = b.dataset.m; if (m === 'in') T.map.zoom(1.4); else if (m === 'out') T.map.zoom(0.7); else T.map.fit(); return; }
    if ((b = e.target.closest('[data-csearch]'))) { CS_.q = ($('#cq') || {}).value || ''; return go('contracts'); }
    // Démission
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter l\'agence ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter', true))) return;
      let r = await call('resign', {});
      if (r.unpaid) {
        if (!(await confirmBox('Salaire non payé', `Vous avez <b>${money(r.unpaid)}</b> non payés. Partir quand même et y renoncer ?`, 'Partir et renoncer', true))) return;
        r = await call('resign', { dropUnpaid: true });
      }
      if (r.ok) post('close', { ui: 'tablet' });
      return;
    }
    // Recrutement
    if ((b = e.target.closest('[data-rc]'))) {
      const a = b.dataset.rc;
      if (a === 'clear') { RC.preview = null; return PAGES.recruit(); }
      if (a === 'find') { const r = await call('recruitPreview', {}, b); RC.preview = r.error ? null : r; return PAGES.recruit(); }
      if (a === 'send') {
        const p = RC.preview, gid = Number($('#rcGrade').value), gr = p.grades.find((x) => x.id === gid);
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre Dynasty 8 au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
        const r = await call('recruitSend', { target: p.target.id, gradeId: gid }, b);
        if (r.ok) { RC.preview = null; PAGES.recruit(); }
      }
      return;
    }
    // Employés
    if ((b = e.target.closest('[data-emp]'))) return loadEmployee(b.dataset.emp);
    if ((b = e.target.closest('[data-ea]'))) {
      const emp = ES.emp, s = gradeSteps(emp), a = b.dataset.ea;
      if (a === 'up' && s.up) return changeGrade(emp, s.up, 'Promouvoir');
      if (a === 'down' && s.down) return changeGrade(emp, s.down, 'Rétrograder');
      if (a === 'change') {
        const v = await confirmBox('Changer de grade', `Nouveau grade de <b>${esc(emp.name)}</b> (actuellement ${esc(emp.grade)}).`, 'Continuer', false,
          `<label class="field"><span>Nouveau grade</span><select class="input" data-cfv="grade">${s.choices.map((g) => `<option value="${g.id}">${esc(g.name)} (niveau ${g.level})</option>`).join('')}</select></label>`);
        if (!v) return;
        const target = s.choices.find((g) => String(g.id) === v.grade);
        if (target) return changeGrade(emp, target, target.level > emp.level ? 'Promouvoir' : 'Rétrograder');
        return;
      }
      if (a === 'edit') {
        const v = await confirmBox('Modifier la fiche', `Informations professionnelles de <b>${esc(emp.name)}</b>.`, 'Enregistrer', false,
          `<div style="display:flex;flex-direction:column;gap:.7rem"><label class="field"><span>Matricule</span><input class="input" data-cfv="matricule" maxlength="20" value="${esc(emp.matricule)}"></label>
           <label class="field"><span>Note</span><input class="input" data-cfv="note" maxlength="255" value="${esc(emp.note || '')}"></label></div>`);
        if (!v) return;
        const r = await call('editEmployee', { cid: emp.cid, matricule: v.matricule, note: v.note });
        if (r.ok) await PAGES.employees(T.gen);
        return;
      }
      if (a === 'fire') {
        const v = await confirmBox('Retirer de Dynasty 8 ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
          '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="200"></label>');
        if (!v) return;
        let r = await call('fire', { cid: emp.cid, reason: v.reason });
        if (r.unpaid && await confirmBox('Abandonner le salaire dû ?', `${money(r.unpaid)} ne seront jamais payés à ${esc(emp.name)}.`, 'Retirer quand même', true)) {
          r = await call('fire', { cid: emp.cid, reason: v.reason, dropUnpaid: true });
        }
        if (r.ok) { ES.cid = null; ES.emp = null; await PAGES.employees(T.gen); }
      }
      return;
    }
    // Grades
    if ((b = e.target.closest('[data-g]'))) {
      const a = b.dataset.g;
      if (a === 'cancel') { GS.edit = null; return drawGrades(); }
      if (a === 'edit') { GS.edit = GS.data.list.find((x) => String(x.id) === b.dataset.id); return drawGrades(); }
      if (a === 'save') {
        const data = { id: GS.edit ? GS.edit.id : undefined, name: $('#gName').value, level: Number($('#gLevel').value), isDefault: $('#gDefault').checked, active: $('#gActive').checked };
        if (!(await confirmBox(data.id ? 'Modifier le grade ?' : 'Créer le grade ?', `« <b>${esc(data.name)}</b> », niveau ${data.level || '?'}${data.active ? '' : ', <b>désactivé</b>'}.`, 'Confirmer'))) return;
        const r = await call('gradeSave', data, b);
        if (r.ok) { GS.edit = null; return PAGES.grades(T.gen); }
        return;
      }
      if (a === 'del') {
        const gr = GS.data.list.find((x) => String(x.id) === b.dataset.id);
        const others = GS.data.list.filter((x) => x.id !== gr.id && x.level < GS.data.myLevel && x.active);
        const extra = gr.members > 0 ? `<label class="field" style="margin-top:.7rem"><span>Réaffecter les ${gr.members} employé(s) au grade</span><select class="input" data-cfv="reassign">${others.map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join('')}</select></label>` : '';
        const v = await confirmBox('Supprimer le grade ?', `« <b>${esc(gr.name)}</b> » sera supprimé.${gr.members ? ' Ses employés sont d\'abord réaffectés.' : ''} Pour le garder dans l'historique sans le donner, désactivez-le plutôt.`, 'Supprimer', true, extra);
        if (!v) return;
        const r = await call('gradeDelete', { id: gr.id, reassign: v.reassign ? Number(v.reassign) : undefined });
        if (r.ok) return PAGES.grades(T.gen);
      }
      return;
    }
    // Permissions
    if ((b = e.target.closest('[data-p]'))) {
      if (b.dataset.p === 'reset') return PAGES.perms(T.gen);
      if (!(await confirmBox('Enregistrer les permissions ?', `${Object.keys(PS.dirty).length} grade(s) modifié(s).`, 'Enregistrer'))) return;
      b.classList.add('loading');
      let ok = 0;
      for (const id of Object.keys(PS.dirty)) {
        const gr = PS.data.list.find((x) => String(x.id) === id);
        const r = await req('gradePerms', { id: gr.id, perms: [...gr.set] });
        if (r.error) toast(`${gr.name} : ${r.error}`, false); else ok++;
      }
      b.classList.remove('loading');
      if (ok) toast(`Permissions enregistrées (${ok} grade(s)).`, true);
      return PAGES.perms(T.gen);
    }
    // Finance
    if ((b = e.target.closest('[data-fpay],[data-frate],[data-fcom],[data-fpayall]'))) return financeAction(b);
    if ((b = e.target.closest('[data-ts]'))) { TS.q = ($('#tq') || {}).value || ''; return go('transactions'); }
  });

  setInterval(() => { const d = new Date(); $('#tabClock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

  /* ------------------------------------------------------------------ */
  function applyOpts(o) {
    if (!o) return false;
    if (o.page) { go(o.page); return true; }
    return false;
  }
  window.Tablet = {
    open(st, opts) {
      T.open = true;
      T.st = st || APP.st || T.st;
      T.perms = (T.st && T.st.perms) || {};
      $('#tablet').classList.remove('hidden');
      if (!applyOpts(opts)) go(T.page || 'dashboard', true);
    },
    goTo(opts) { applyOpts(opts); },
    hide() { T.open = false; stopTimers(); $('#tablet').classList.add('hidden'); },
    isOpen: () => T.open,
    back() {
      if (T.page === 'employees' && ES.cid) { ES.cid = null; ES.emp = null; drawEmployees(); return true; }
      if (T.page === 'grades' && GS.edit) { GS.edit = null; drawGrades(); return true; }
      return false;
    },
    onState(st) {
      T.st = st;
      T.perms = (st && st.perms) || {};
      if (!T.open) return;
      if (!st) return post('close', { ui: 'tablet' });
      renderNav();
      const nav = NAV.find((n) => n.id === T.page);
      if (!nav || !allowed(nav)) go('dashboard');
    },
  };
})();
