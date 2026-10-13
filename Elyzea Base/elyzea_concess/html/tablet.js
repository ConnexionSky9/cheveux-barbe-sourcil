/* =====================================================================
   ELYZEA CONCESSION - tablette (toujours limitée à la concession de l'employé)
   Commercial : Tableau de bord · Catalogue et prix · Exposition · Ventes et livraisons · Clients · Configuration
   Direction : Recrutement, Employés, Grades, Permissions, Historique · Finance : Vue d'ensemble, Transactions
   Chaque bouton appelle le serveur, qui revérifie les droits, les statuts et recalcule les montants.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
  const CAT = { sale: 'Ventes', refund: 'Remboursements', salary: 'Salaires', commission: 'Commissions', other: 'Autre' };
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'catalog', label: 'Catalogue et prix', ico: '🚘', perm: ['catalog'] },
    { id: 'display', label: 'Exposition', ico: '🅿️', perm: ['catalog'] },
    { id: 'sales', label: 'Ventes et livraisons', ico: '🧾', perm: ['catalog'] },
    { id: 'clients', label: 'Clients', ico: '👤', perm: ['sales_all'] },
    { id: 'prices', label: 'Historique des prix', ico: '🏷️', perm: ['catalog'] },
    { id: 'config', label: 'Configuration', ico: '⚙️', perm: ['catalog'] },
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
    let last = null, html = `<div class="brand"><div class="shield">🚘</div><div><b>${esc((T.st || {}).shopName || 'Concession')}</b><small>Concession automobile</small></div></div>`;
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

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || ((T.st && T.st.shopName) || 'Concession'); }
  function loading() { body().insertAdjacentHTML('afterbegin', '<div class="loading-bar"></div>'); }
  function stopTimers() { clearInterval(T.timer); T.timer = null; }
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
    if (!keepSub) { ES.cid = null; }
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
    const t = d.me.times || {}, c = d.counts, r = d.revenue;
    body().innerHTML = `
      <div class="stats">
        <div class="stat blue"><b>${c.offered}</b><span>Véhicules proposés · ${c.sellable} vendables</span></div>
        <div class="stat orange"><b>${c.shown}</b><span>En exposition</span></div>
        <div class="stat green"><b>${c.sales}</b><span>Ventes · ${c.pending} livraison(s) en attente</span></div>
        <div class="stat green"><b>${money(r.week)}</b><span>Chiffre d'affaires 7 jours · ${money(r.today)} aujourd'hui · ${money(r.total)} au total</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Dernières ventes</h2>${d.last.map((l) => `<div class="list-row"><div class="main"><b>${esc(l.label)}</b>
          <small>${esc(l.buyer_name || '')} · ${esc(l.seller_name || '')} · <span class="mono">${esc(l.plate || '')}</span> · ${fmtTime(l.t)}</small></div>
          <span class="mono nw">${money(l.price)}</span>${l.delivery === 'pending' ? '<span class="pill warn">À livrer</span>' : '<span class="pill on">Livré</span>'}</div>`).join('') || empty('Aucune vente.')}</div>
        <div class="card"><h2>Derniers véhicules livrés</h2>${d.delivered.map((l) => `<div class="list-row"><div class="main"><b>${esc(l.label)}</b><small>${esc(l.buyer_name || '')} · <span class="mono">${esc(l.plate)}</span> · ${fmtTime(l.t)}</small></div></div>`).join('') || empty('Aucune livraison.')}</div>
        ${d.tx.length ? `<div class="card"><h2>Dernières transactions</h2>${d.tx.map((x) => `<div class="list-row"><div class="main"><b style="font-weight:500">${esc(x.reason || x.category)}</b><small class="mono">${esc(x.txid)} · ${fmtTime(x.t)}</small></div>
          <b class="mono" style="color:${x.type === 'out' ? '#fca5a5' : x.type === 'in' ? 'var(--green)' : 'var(--muted)'}">${x.type === 'out' ? '−' : x.type === 'in' ? '+' : ''}${money(x.amount)}</b></div>`).join('')}</div>` : ''}
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Concession</span><b>${esc(d.shop.name)}</b><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session</span><b class="mono">${dur(t.session)}</b><span>Non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b>
          <span>Taux</span><b>${money(t.rate)} / h${t.commission ? ` · ${t.commission} % sur mes ventes` : ''}</b></div>
          <div class="actions-row"><button class="btn small" data-q="catalog">🚘 Catalogue</button><button class="btn small" data-q="sales">🧾 Ventes</button>
            <button class="btn danger small" data-resign="1">Quitter la concession</button></div></div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)} · ${dur(a.session)}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div></div>`;
    every(15000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Catalogue de la concession : prix, restrictions, historique          */
  /* ------------------------------------------------------------------ */
  const KS = { data: null, q: '', cat: '', f: '' };
  PAGES.catalog = async (g) => {
    const d = await req('catalog');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    KS.data = d;
    drawCatalog();
  };
  function drawCatalog() {
    const d = KS.data, q = KS.q.trim().toLowerCase();
    const list = d.list.filter((o) => (!q || `${o.label} ${o.model} ${o.brand || ''}`.toLowerCase().includes(q)) && (!KS.cat || String(o.categoryId) === KS.cat)
      && (!KS.f || (KS.f === 'sell' ? o.sellable : KS.f === 'nosell' ? !o.sellable : KS.f === 'hidden' ? !o.visible : o.displayed > 0)));
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-kq placeholder="Rechercher : modèle, nom de spawn, marque" value="${esc(KS.q)}">
        <select class="input" data-kcat><option value="">Toutes catégories</option>${d.categories.map((c) => `<option value="${c.id}" ${KS.cat === String(c.id) ? 'selected' : ''}>${esc(c.name)}${c.visible ? '' : ' (masquée)'}${c.sellable ? '' : ' (non vendable)'}</option>`).join('')}</select>
        <select class="input" data-kf>${[['', 'Tous'], ['sell', 'Vendables'], ['nosell', 'Non vendables'], ['hidden', 'Masqués aux clients'], ['expo', 'En exposition']].map(([k, l]) => `<option value="${k}" ${KS.f === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <button class="btn" data-kopen="1">🚘 Ouvrir le catalogue client</button></div>
      <div class="note">Le catalogue, les catégories et ce que la concession propose sont définis par le staff. ${d.canPrices ? 'Vous pouvez modifier les prix de VOTRE concession (vide = prix de référence).' : 'La modification des prix demande la permission « Modifier les prix ».'}</div>
      <div class="card" style="padding:.3rem .6rem">${list.length ? `<table class="tbl"><tr><th>Modèle</th><th>Catégorie</th><th>Statut</th><th>Prix</th><th></th></tr>${list.map((o) => `<tr>
        <td><b>${esc(o.label)}</b><br><small class="mono faint">${esc(o.model)}</small></td><td>${esc(o.category)}</td>
        <td>${o.sellable ? '<span class="pill on">Vendable</span>' : `<span class="pill bad" title="${esc(o.sellReason || '')}">Non vendable</span>`} ${o.visible ? '' : '<span class="pill off">Masqué</span>'} ${o.displayed ? `<span class="pill warn">Exposé ×${o.displayed}</span>` : ''}
          ${!o.sellable && o.sellReason ? `<br><small class="faint">${esc(o.sellReason)}</small>` : ''}</td>
        <td class="nw"><b class="mono">${money(o.price)}</b><br><small class="faint">${o.ownPrice ? `référence ${o.refPrice != null ? money(o.refPrice) : '—'}` : 'prix de référence'}</small></td>
        <td style="text-align:right;white-space:nowrap">${d.canPrices ? `<button class="btn small" data-kprice="${o.id}">Prix</button>` : ''} <button class="btn small" data-khist="${o.id}">Historique</button></td></tr>`).join('')}</table>` : empty('Aucun modèle ne correspond.')}</div>`;
  }

  PAGES.prices = async (g) => {
    const d = await req('priceHistory', {});
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">Chaque changement de prix de la concession est enregistré. Une modification ne change jamais une vente déjà conclue.</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Date</th><th>Modèle</th><th>Ancien prix</th><th>Nouveau prix</th><th>Par</th></tr>${d.list.map((r) => `<tr>
        <td class="muted">${fmtTime(r.t)}</td><td><b>${esc(r.label)}</b> <small class="mono faint">${esc(r.model || '')}</small></td><td class="mono">${r.old_price != null ? money(r.old_price) : '—'}</td>
        <td class="mono"><b>${r.new_price != null ? money(r.new_price) : '—'}</b></td><td>${esc(r.actor_name || '')}</td></tr>`).join('')}</table>` : empty('Aucun changement de prix.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Exposition                                                          */
  /* ------------------------------------------------------------------ */
  PAGES.display = async (g) => {
    const d = await req('displayList');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    T.disp = d;
    body().innerHTML = `<div class="note">Emplacements créés par le staff. Un emplacement reçoit un seul véhicule. Les véhicules exposés sont verrouillés, ne donnent aucune clé et ne vont jamais dans un garage ; une vente livre un véhicule neuf.</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Emplacement</th><th>Véhicule</th><th>Placé par</th><th></th></tr>${d.list.map((s) => `<tr style="${s.enabled ? '' : 'opacity:.5'}">
        <td><b>${esc(s.label)}</b>${s.enabled ? '' : '<br><small class="faint">désactivé par le staff</small>'}</td><td>${s.model ? `<b>${esc(s.modelLabel || s.model)}</b>` : '<span class="faint">Libre</span>'}</td>
        <td class="muted">${esc(s.placedBy || '')}</td>
        <td style="text-align:right;white-space:nowrap">${d.canDisplay && s.enabled ? `<button class="btn small primary" data-dput="${s.id}">${s.model ? 'Remplacer' : 'Exposer'}</button>
          ${s.model ? `<button class="btn small" data-drot="${s.id}" data-delta="-15">⟲</button><button class="btn small" data-drot="${s.id}" data-delta="15">⟳</button><button class="btn small danger" data-drem="${s.id}">Retirer</button>` : ''}` : ''}</td></tr>`).join('')}</table>`
        : empty('Aucun emplacement d\'exposition : le staff les place depuis l\'administration automobile.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Ventes, livraisons, clients                                         */
  /* ------------------------------------------------------------------ */
  const SS = { q: '', delivery: '' };
  PAGES.sales = async (g) => {
    const d = await req('sales', SS);
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="sq" placeholder="Rechercher : vente, modèle, client, vendeur, plaque" value="${esc(SS.q)}">
        <select class="input" data-sd>${[['', 'Toutes'], ['pending', 'À livrer'], ['delivered', 'Livrées']].map(([k, l]) => `<option value="${k}" ${SS.delivery === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <button class="btn" data-ssearch="1">Rechercher</button></div>
      ${d.all ? '' : '<div class="note">Vous voyez vos ventes. Toutes les ventes : permission « Voir toutes les ventes et les clients ».</div>'}
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Vente</th><th>Véhicule</th><th>Client</th><th>Prix</th><th>Livraison</th><th></th></tr>${d.list.map((s) => `<tr>
        <td class="mono" style="font-size:.76rem">${esc(s.uid)}<br><span class="faint">${fmtTime(s.t)} · ${esc(s.seller_name || '')}</span></td>
        <td><b>${esc(s.label || s.model)}</b><br><small class="mono faint">${esc(s.plate || '')}</small></td><td>${esc(s.buyer_name || '')}</td>
        <td class="mono nw">${money(s.price)}${s.discount > 0 ? `<br><small class="faint">remise ${money(s.discount)}</small>` : ''}<br><small class="faint">${s.method === 'cash' ? 'espèces' : 'banque'}</small></td>
        <td>${s.delivery === 'delivered' ? `<span class="pill on">Livré</span><br><small class="faint">${fmtTime(s.dt)}</small>` : '<span class="pill warn">À livrer</span>'}<br><small class="faint">${s.key_given ? '🔑 clé remise' : '⚠ clé non remise'}</small></td>
        <td style="text-align:right;white-space:nowrap">${d.canDeliver && s.delivery !== 'delivered' ? `<button class="btn small primary" data-sdel="${esc(s.uid)}">Livrer</button>` : ''}
          ${d.canDeliver && !s.key_given ? `<button class="btn small" data-skey="${esc(s.uid)}">Clé</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune vente.')}</div>`;
  };
  PAGES.clients = async (g) => {
    const d = await req('clients');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">Clients de la concession, d'après les ventes enregistrées (identifiant persistant du personnage).</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Client</th><th>Achats</th><th>Total</th><th>Dernier achat</th><th>Véhicules</th></tr>${d.list.map((c) => `<tr>
        <td><b>${esc(c.name || '—')}</b></td><td>${c.n}</td><td class="mono">${money(c.total)}</td><td class="muted">${fmtTime(c.last)}</td><td class="muted">${esc(c.vehicles || '')}</td></tr>`).join('')}</table>` : empty('Aucun client.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Configuration autorisée (lecture de ce que le staff a défini)        */
  /* ------------------------------------------------------------------ */
  PAGES.config = async (g) => {
    const d = await req('config');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const yes = (v) => (v ? '<span class="pill on">Oui</span>' : '<span class="pill off">Non</span>');
    body().innerHTML = `<div class="cols"><div><div class="card"><h2>Concession</h2><div class="kv"><span>Nom</span><b>${esc(d.shop.name)}</b><span>Adresse</span><b>${esc(d.shop.address || '—')}</b>
        <span>Métier</span><b class="mono">${esc(d.shop.job)}</b><span>Compte</span><b class="mono">${esc(d.shop.society)}</b><span>Service obligatoire</span><b>${yes(d.shop.requireDuty)}</b>
        <span>Remise maximale</span><b>${d.shop.maxDiscount} %</b><span>Emplacements</span><b>${d.slots}</b><span>Places de sortie</span><b>${d.exits}</b><span>Point catalogue</span><b>${yes(d.hasCatalog)}</b></div>
        <p class="faint" style="font-size:.78rem;margin-top:.6rem">Ces réglages sont modifiés par le staff (admin_menu › Administration automobile).</p></div></div>
      <div><div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Catégories de la concession</h2><table class="tbl"><tr><th>Catégorie</th><th>Activée</th><th>Visible</th><th>Vendable</th></tr>
        ${d.categories.map((c) => `<tr style="${c.global ? '' : 'opacity:.5'}"><td>${esc(c.icon || '')} <b>${esc(c.name)}</b>${c.global ? '' : '<br><small class="faint">désactivée par le staff</small>'}</td><td>${yes(c.enabled)}</td><td>${yes(c.visible)}</td><td>${yes(c.sellable)}</td></tr>`).join('')}</table></div></div></div>`;
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
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne travaille déjà dans une concession.</p>' : ''}
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
        <span>Ventes</span><b>${e.sales || 0}</b><span>Chiffre d'affaires</span><b>${money(e.revenue || 0)}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${e.canAct ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'}>▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de la concession</button>' : ''}</div>`
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
    const income = sm('in:sale').total;
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
            
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)}</b></div></div>
          <div class="card"><h2>Depuis l'ouverture</h2><div class="kv"><span>Ventes</span><b class="mono">${money(al('in:sale').total)} <span class="faint">(${al('in:sale').n})</span></b>
            <span>Salaires versés</span><b class="mono">${money(al('out:salary').total)}</b><span>Remboursements</span><b class="mono">${money(al('out:refund').total)}</b></div></div></div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur les ventes conclues, versée par l'entreprise. Appliqué à partir de maintenant.</p></div>
        <div class="card"><h2>Historique des taux</h2>${FS.rates.slice(0, 15).map((r) => `<div class="list-row"><div class="main"><b>${esc(r.grade_name)} · ${money(r.rate)}/h</b><small>${esc(r.actor_name || '')} · ${fmtTime(r.t)}</small></div></div>`).join('') || empty('Aucun changement.')}</div>
        <div class="card"><h2>Moyens de paiement</h2><div class="kv"><span>Banque</span><b>${money(((d.methods || {}).bank || {}).total || 0)} · ${((d.methods || {}).bank || {}).n || 0} vente(s)</b><span>Espèces</span><b>${money(((d.methods || {}).cash || {}).total || 0)} · ${((d.methods || {}).cash || {}).n || 0} vente(s)</b></div></div>
        <div class="card"><h2>Compte ${esc(d.society || '')} : derniers mouvements</h2>${d.logs.map((l) => `<div class="list-row"><div class="main"><b style="font-weight:500">${esc(l.reason || '—')}</b><small>${l.t ? fmtTime(l.t) : ''}</small></div>
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
      if (!(await confirmBox('Changer la commission ?', `<b>${esc(gr ? gr.name : '')}</b> : ${gr ? gr.commission || 0 : 0} % → <b>${pct} %</b> sur les ventes conclues.<br>Versée depuis le compte de l'entreprise à chaque encaissement, à partir de maintenant.`, 'Appliquer'))) return;
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
  /* Événements                                                          */
  /* ------------------------------------------------------------------ */
  $('#tabNav').addEventListener('click', (e) => { const b = e.target.closest('[data-nav]'); if (b) go(b.dataset.nav); });
  $('#tabClose').addEventListener('click', () => post('close', { ui: 'tablet' }));

  body().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.target.tagName === 'TEXTAREA') return;
    const t = e.target;
    if (t.dataset.hq !== undefined) { HS.q = t.value; return go('history'); }
    if (t.id === 'sq') { SS.q = t.value; return go('sales'); }
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.kcat !== undefined) { KS.cat = t.value; return drawCatalog(); }
    if (t.dataset.kf !== undefined) { KS.f = t.value; return drawCatalog(); }
    if (t.dataset.sd !== undefined) { SS.delivery = t.value; SS.q = ($('#sq') || {}).value || ''; return go('sales'); }
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
    if (t.dataset.kq !== undefined) { KS.q = t.value; return keep('[data-kq]', drawCatalog); }
    if (t.dataset.ef === 'q') { ES.f.q = t.value; return keep('[data-ef="q"]', drawEmployees); }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) return go(b.dataset.q);
    // Catalogue et prix
    if (e.target.closest('[data-kopen]')) return post('openCatalog', {});
    if ((b = e.target.closest('[data-kprice]'))) {
      const o = KS.data.list.find((x) => String(x.id) === b.dataset.kprice);
      const v = await confirmBox(`Prix : ${o.label}`, `Prix actuel dans votre concession : <b>${money(o.price)}</b>${o.refPrice != null ? ` · référence ${money(o.refPrice)}` : ''}.<br>Les ventes déjà conclues ne changent pas.`, 'Enregistrer', false,
        `<label class="field" style="margin-top:.6rem"><span>Nouveau prix ($) · vide = prix de référence</span><input class="input" type="number" min="1" data-cfv="price" value="${o.ownPrice ? o.price : ''}"></label>`);
      if (!v) return;
      const r = await call('priceSet', { id: o.id, price: v.price === '' ? '' : Number(v.price) });
      if (r.ok) return PAGES.catalog(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-khist]'))) {
      const r = await req('priceHistory', { id: Number(b.dataset.khist) });
      if (r.error) return toast(r.error, false);
      return confirmBox('Historique des prix', r.list.length ? r.list.map((x) => `<div class="list-row"><div class="main"><b>${x.old_price != null ? money(x.old_price) : '—'} → ${x.new_price != null ? money(x.new_price) : '—'}</b><small>${esc(x.actor_name || '')} · ${fmtTime(x.t)}</small></div></div>`).join('') : 'Aucun changement.', 'Fermer');
    }
    // Exposition
    if ((b = e.target.closest('[data-dput]'))) {
      const s = T.disp.list.find((x) => String(x.id) === b.dataset.dput);
      if (!T.disp.models.length) return toast('Aucun modèle autorisé en exposition dans votre concession.', false);
      const v = await confirmBox(`${s.model ? 'Remplacer' : 'Exposer'} · ${s.label}`, s.model ? `Actuellement : <b>${esc(s.modelLabel || s.model)}</b>.` : 'Emplacement libre.', s.model ? 'Remplacer' : 'Exposer', false,
        `<label class="field" style="margin-top:.6rem"><span>Modèle</span><select class="input" data-cfv="model">${T.disp.models.map((m) => `<option value="${m.id}">${esc(m.label)} · ${esc(m.category)}</option>`).join('')}</select></label>`);
      if (!v) return;
      const r = await call('displayPlace', { slot: s.id, model: Number(v.model), replace: !!s.model });
      if (r.ok) return PAGES.display(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-drot]'))) { await call('displayRotate', { slot: Number(b.dataset.drot), delta: Number(b.dataset.delta) }); return; }
    if ((b = e.target.closest('[data-drem]'))) {
      if (!(await confirmBox('Retirer de l\'exposition ?', 'L\'emplacement redevient libre.', 'Retirer', true))) return;
      const r = await call('displayRemove', { slot: Number(b.dataset.drem) });
      if (r.ok) return PAGES.display(T.gen);
      return;
    }
    // Ventes
    if (e.target.closest('[data-ssearch]')) { SS.q = ($('#sq') || {}).value || ''; return go('sales'); }
    if ((b = e.target.closest('[data-sdel]'))) {
      if (!(await confirmBox('Livrer le véhicule ?', 'Il apparaît sur une place libre de la zone de sortie (vous devez être à proximité). Aucun nouveau paiement.', 'Livrer'))) return;
      const r = await call('deliverFor', { uid: b.dataset.sdel }, b);
      if (r.ok) return PAGES.sales(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-skey]'))) { const r = await call('keyFor', { uid: b.dataset.skey }, b); if (r.ok) return PAGES.sales(T.gen); return; }
    // Démission
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter la concession ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter', true))) return;
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
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre la concession au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Retirer de la concession ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
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
