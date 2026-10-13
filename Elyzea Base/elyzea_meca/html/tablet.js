/* =====================================================================
   ELYZEA MÉCANO - tablette
   Atelier : Tableau de bord · Dépannage · Véhicules clients · Devis · Factures · Stock · Carte · Statistiques
   Direction : Recrutement, Employés, Grades, Permissions, Historique, Catalogue et tarifs, Garage
   Finance : Vue d'ensemble et salaires, Transactions
   Chaque bouton appelle le serveur, qui revérifie les droits et recalcule les montants.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
  const towPill = (s) => `<span class="st-pill st-${esc(s)}">${esc(towSt(s))}</span>`;
  const qPill = (s) => `<span class="st-pill q-${esc(s)}">${esc(QST[s] || s)}</span>`;
  const INV = { paid: 'Payée', refunded: 'Remboursée', cancelled: 'Annulée' };
  const KIND = { service: 'Prestation', perf: 'Performance', cosmetic: 'Esthétique', carplay: 'CarPlay', custom: 'Libre' };
  const PERF = { engine: 'Moteur', brakes: 'Freins', transmission: 'Transmission', suspension: 'Suspension', armor: 'Blindage', turbo: 'Turbo' };
  const COS = { body: 'Carrosserie', paint: 'Peinture', pearl: 'Nacré', livery: 'Livrée', tint: 'Vitres teintées', plate: 'Plaque', wheels: 'Jantes',
    wheelcolor: 'Couleur des jantes', smoke: 'Fumée des pneus', neon: 'Néons', xenon: 'Xénon', interior: 'Intérieur',
    intcolor: 'Couleur intérieur', dashcolor: 'Couleur tableau de bord', tyres: 'Pneus', extras: 'Éléments optionnels', roofliv: 'Livrée de toit', platetext: 'Plaque personnalisée' };
  const CAT = { invoice: 'Factures clients', refund: 'Remboursements', salary: 'Salaires', commission: 'Commissions', other: 'Autre' };
  const METHOD = { bank: 'banque', cash: 'liquide' };
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const lineTotal = (l) => Number(l.total != null ? l.total : (Number(l.price) || 0) * (Number(l.qty) || 1));
  const itemsText = (items) => (items || []).map((i) => esc(i.label || i.name || i.code) + (i.qty > 1 ? ` ×${i.qty}` : '')).join(', ');

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'tows', label: 'Dépannage', ico: '🚨', perm: ['tow'] },
    { id: 'vehicles', label: 'Véhicules clients', ico: '🚗', perm: ['vehicles_view'] },
    { id: 'quotes', label: 'Devis', ico: '📋', perm: ['quotes'] },
    { id: 'invoices', label: 'Factures', ico: '🧾', perm: ['quotes'] },
    { id: 'map', label: 'Carte', ico: '🗺️', perm: ['tablet'] },
    { id: 'stats', label: 'Statistiques', ico: '📊', perm: ['stats_view'] },
    { id: 'recruit', label: 'Recrutement', ico: '➕', perm: ['recruit'], group: 'Direction' },
    { id: 'employees', label: 'Employés', ico: '👥', perm: ['employees_view'], group: 'Direction' },
    { id: 'grades', label: 'Grades', ico: '🎖️', perm: ['direction'], group: 'Direction' },
    { id: 'perms', label: 'Permissions', ico: '🔐', perm: ['perms_manage'], group: 'Direction' },
    { id: 'history', label: 'Historique', ico: '🕘', perm: ['history_view'], group: 'Direction' },
    { id: 'catalog', label: 'Catalogue et tarifs', ico: '🏷️', perm: ['catalog_manage'], group: 'Direction' },
    { id: 'workshops', label: 'Points d\'atelier', ico: '📍', perm: ['garage_manage'], group: 'Direction' },
    { id: 'garage', label: 'Garage', ico: '🚛', perm: ['garage_manage'], group: 'Direction' },
    { id: 'finance', label: 'Vue d\'ensemble', ico: '💰', perm: ['finance'], group: 'Finance' },
    { id: 'transactions', label: 'Transactions', ico: '🔁', perm: ['finance'], group: 'Finance' },
  ];
  const allowed = (n) => canAny(...n.perm) && (n.group !== 'Direction' || can('direction'));

  function renderNav() {
    let last = null, html = `<div class="brand"><div class="shield">🔧</div><div><b>${esc((APP.cfg && APP.cfg.job) || 'Mécano')}</b><small>Tablette d'atelier</small></div></div>`;
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

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || ((APP.cfg && APP.cfg.job) || 'Mécano'); }
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
    if (!keepSub) { VS.id = null; VS.plate = null; ES.cid = null; TW.sel = null; CS.edit = null; }
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
  const towRow = (c) => `<div class="alert-row click" data-tow="${c.id}" style="--c:${c.status === 'pending' ? '#f59e0b' : '#22c55e'}"><div class="t"><span>#${c.id} · ${esc(c.reason)}</span>${towPill(c.status)}</div>
    <div class="m">${esc(c.street || '')}${c.vehicle ? ` · ${esc(c.vehicle)}` : ''} · ${ago(c.t)} · ${c.crew.length ? esc(c.crew.join(', ')) : 'personne'}</div></div>`;
  PAGES.dashboard = async (g) => {
    const d = await req('dashboard');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const t = d.me.times || {}, td = d.today || {};
    body().innerHTML = `
      <div class="stats">
        <div class="stat blue"><b>${d.dutyCount}</b><span>Mécaniciens en service</span></div>
        <div class="stat orange"><b>${d.tows.length}</b><span>Dépannages en cours</span></div>
        <div class="stat"><b>${td.openQuotes}</b><span>Devis ouverts</span></div>
        <div class="stat green"><b>${money(td.revenue)}</b><span>Encaissé aujourd'hui</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Dépannages en cours ${can('tow') ? '<button class="btn small" data-q="tows">Dépannage ›</button>' : ''}</h2>${d.tows.map(towRow).join('') || empty('Aucune demande en cours.')}</div>
        <div class="card"><h2>Devis ouverts ${can('quotes') ? '<button class="btn small" data-q="quotes">Devis ›</button>' : ''}</h2>${(d.quotes || []).map((q) => `<div class="list-row"><div class="main"><b>${esc(q.plate || '—')} · ${esc(q.customer || '—')}</b>
          <small>${itemsText(q.items)} · ${esc(q.mechanic || '')} · ${ago(q.t)}</small></div><span class="mono nw">${money(q.total)}</span>${qPill(q.status)}</div>`).join('') || empty('Aucun devis ouvert.')}</div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small><span class="mono">${esc(a.matricule)}</span> · ${esc(a.grade)}${a.street ? ` · 📍 ${esc(a.street)}` : ''}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session en cours</span><b class="mono">${dur(t.session)}</b><span>Temps non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b>
          <span>Temps total</span><b class="mono">${dur(t.total)}</b><span>Taux actuel</span><b>${money(t.rate)} / h</b></div>
          <div class="actions-row">${can('vehicles_view') ? '<button class="btn small" data-q="vehicles">🚗 Véhicules</button>' : ''}<button class="btn small" data-q="map">🗺️ Carte</button>
            <button class="btn danger small" data-resign="1">Quitter le garage</button></div></div>
        <div class="card"><h2>Aujourd'hui</h2><div class="kv"><span>Demandes de dépannage</span><b>${td.tows}</b><span>Interventions</span><b>${td.interventions}</b>
          <span>CarPlay installés (total)</span><b>${td.carplay}</b><span>Effectif total</span><b>${d.employees}</b></div></div>
      </div></div>`;
    every(6000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Dépannage                                                           */
  /* ------------------------------------------------------------------ */
  const TW = { sel: null, data: null, info: null };
  async function loadTowInfo() { if (!TW.sel) { TW.info = null; return; } const r = await req('towInfo', { id: TW.sel }); TW.info = r.error ? null : r.tow; }
  PAGES.tows = async (g) => {
    const d = await req('tows');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    TW.data = d;
    await loadTowInfo();
    if (stale(g)) return;
    drawTows();
    every(5000, async () => {
      if (T.page !== 'tows' || typing()) return;
      const n = await req('tows'); if (n.error || T.page !== 'tows') return;
      TW.data = n;
      await loadTowInfo();
      if (T.page === 'tows') drawTows();
    });
  };
  function drawTows() {
    const d = TW.data, i = TW.info;
    const rows = d.list.map((c) => `<tr class="click ${TW.sel === c.id ? 'sel' : ''}" data-tow="${c.id}"><td class="mono faint">${c.id}</td><td><b>${esc(c.reason)}</b><br><small class="muted">${esc(c.street || '')}</small></td>
      <td>${esc(c.client || '—')}${c.vehicle || c.plate ? `<br><small class="faint">${esc(c.vehicle || '')} ${esc(c.plate || '')}</small>` : ''}</td><td>${towPill(c.status)}</td><td class="muted">${esc(c.crew.join(', ') || '—')}</td><td class="muted">${ago(c.t)}</td></tr>`).join('');
    const hist = d.history.map((c) => `<tr class="click" data-tow="${c.id}"><td class="mono faint">${c.id}</td><td>${esc(c.reason)}<br><small class="muted">${esc(c.street || '')}</small></td><td>${esc(c.client_name || '—')}</td>
      <td>${towPill(c.status)}</td><td class="muted">${esc(c.assigned_name || '—')}</td><td class="muted">${fmtTime(c.t)}</td></tr>`).join('');
    let detail = '<div class="card"><h2>Détail</h2><div class="faint" style="font-size:.85rem">Sélectionnez une demande.</div></div>';
    if (i) {
      const live = i.live;
      const idx = live ? TOW_NEXT.indexOf(live.status) : -1;
      detail = `<div class="card"><div class="eyebrow">Demande #${i.id} · ${esc(i.source || '')}</div><h2 style="margin-top:.3rem;justify-content:flex-start">${esc(i.reason)}</h2>
        <div class="kv"><span>Statut</span><b>${towPill(live ? live.status : i.status)}</b><span>Lieu</span><b>${esc(i.street || '—')}</b><span>Client</span><b>${esc(i.client_name || '—')}</b>
          <span>Téléphone</span><b class="mono">${esc(i.client_phone || '—')}</b><span>Véhicule</span><b>${esc(i.vehicle || '—')} <span class="mono">${esc(i.plate || '')}</span></b>
          <span>Responsable</span><b>${esc(i.assigned_name || '—')}</b><span>Équipe</span><b>${esc(live ? live.crew.join(', ') || '—' : '—')}</b>
          <span>Reçue</span><b>${fmtTime(i.t)}</b>${i.c ? `<span>Clôturée</span><b>${fmtTime(i.c)}</b>` : ''}</div>
        ${i.description ? `<p class="muted" style="font-size:.84rem;margin-top:.6rem">${esc(i.description)}</p>` : ''}
        ${live ? `<div class="actions-row">${live.mine ? `<button class="btn small" data-ta="route">📍 GPS</button>
            ${TOW_NEXT.slice(idx + 1, -1).map((s) => `<button class="btn small" data-ta="st:${s}">${esc(towSt(s))}</button>`).join('')}
            <button class="btn small success" data-ta="st:done">Terminer</button><button class="btn small" data-ta="leave">Quitter</button>`
          : `${d.list.find((x) => x.id === i.id) && live.status === 'pending' ? '<button class="btn small primary" data-ta="accept">Accepter</button>' : '<button class="btn small primary" data-ta="accept">Rejoindre</button>'}<button class="btn small" data-ta="route">📍 GPS</button>`}
          ${d.canManage || live.mine ? '<button class="btn small danger" data-ta="st:cancelled">Annuler la demande</button>' : ''}</div>` : ''}
        ${i.plate && can('vehicles_view') ? `<div class="actions-row"><button class="btn small" data-vplate="${esc(i.plate)}">🚗 Fiche du véhicule</button></div>` : ''}</div>
        <div class="card"><h2>Historique de la demande</h2><div class="timeline">${(i.log || []).map((l) => `<div><b>${esc(towSt(l.status))}</b><small>${esc(l.actor_name || '')} · ${fmtTime(l.t)}</small></div>`).join('')}</div></div>`;
    }
    body().innerHTML = `<div class="note">Les demandes arrivent du téléphone (Urgences › Dépannage) et de la commande /${esc((APP.cfg && APP.cfg.towCommand) || 'depannage')}. Accepter trace le GPS ; chaque statut est enregistré.</div>
      <div class="split"><div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">En cours <span class="faint" style="font-size:.8rem">${d.list.length}</span></h2>
          ${d.list.length ? `<table class="tbl"><tr><th>#</th><th>Motif</th><th>Client</th><th>Statut</th><th>Équipe</th><th>Reçue</th></tr>${rows}</table>` : empty('Aucune demande en cours.')}</div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Historique</h2>
          ${d.history.length ? `<table class="tbl"><tr><th>#</th><th>Motif</th><th>Client</th><th>Statut</th><th>Responsable</th><th>Date</th></tr>${hist}</table>` : empty('Aucune demande clôturée.')}</div>
      </div><div class="detail">${detail}</div></div>`;
  }
  async function towAction(a, b) {
    const id = TW.sel, live = TW.info && TW.info.live;
    if (a === 'route') { if (live) post('gps', { x: live.x, y: live.y }); return; }
    if (a === 'accept') { b.classList.add('loading'); await post('towAction', { id, do_: 'accept' }); }
    else if (a === 'leave') await call('towLeave', { id }, b);
    else if (a.startsWith('st:')) {
      const st = a.slice(3);
      if ((st === 'done' || st === 'cancelled') && !(await confirmBox(st === 'done' ? 'Terminer le dépannage ?' : 'Annuler la demande ?', `La demande #${id} sera clôturée pour toute l'équipe.`, 'Confirmer', st === 'cancelled'))) return;
      await call('towStatus', { id, status: st }, b);
    }
    return PAGES.tows(T.gen);
  }

  /* ------------------------------------------------------------------ */
  /* Véhicules clients (identifiant persistant = carte grise, pas la plaque) */
  /* ------------------------------------------------------------------ */
  const VS = { q: '', id: null, plate: null };
  PAGES.vehicles = async (g) => {
    if (VS.id || VS.plate) return vehicleView(g);
    const d = await req('vehicleSearch', { q: VS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="vq" placeholder="Plaque ou nom du propriétaire (2 caractères minimum)" value="${esc(VS.q)}"><button class="btn" data-vs="1">Rechercher</button></div>
      ${d.recent ? '<div class="note">Derniers véhicules passés à l\'atelier. Recherchez une plaque ou un propriétaire pour les autres.</div>' : ''}
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Plaque</th><th>Modèle</th><th>${d.recent ? 'Dernier passage' : 'Propriétaire'}</th></tr>${d.list.map((v) => `<tr class="click" data-vid="${v.id}">
        <td class="mono"><b>${esc(v.plate || '—')}</b></td><td>${esc(v.model || '—')}</td><td class="muted">${d.recent ? fmtTime(v.t) : esc(v.owner || '—')}</td></tr>`).join('')}</table>` : empty('Aucun véhicule trouvé.')}</div>`;
  };
  const bar = (v) => { v = Math.max(0, Math.min(100, Number(v) || 0)); return `<span class="hbar"><i style="width:${v}%;background:${v > 60 ? '#22c55e' : v > 30 ? '#f59e0b' : '#ef4444'}"></i></span> <b class="mono">${v} %</b>`; };
  async function vehicleView(g) {
    const r = await req('vehicleGet', VS.id ? { id: VS.id } : { plate: VS.plate });
    if (stale(g)) return;
    if (r.error) { toast(r.error, false); VS.id = null; VS.plate = null; return PAGES.vehicles(g); }
    const v = r.vehicle;
    VS.id = v.id; VS.plate = null;
    setTitle(`${v.plate} · ${v.model || ''}`, 'Véhicule client');
    const perf = Object.entries(PERF).map(([k, l]) => `<span>${l}</span><b>${k === 'turbo' ? (v.perf.turbo ? 'Installé' : 'Non') : (v.perf[k] ? `Niveau ${v.perf[k]}` : 'Origine')}</b>`).join('');
    body().innerHTML = `<div class="toolbar"><button class="btn" data-vback="1">‹ Véhicules</button></div>
      <div class="split"><div>
        <div class="card"><h2>Fiche <span class="faint mono" style="font-size:.75rem">ID ${v.id}</span></h2><div class="kv"><span>Plaque</span><b class="mono">${esc(v.plate)}</b><span>Modèle</span><b>${esc(v.model || '—')}</b>
          <span>Propriétaire</span><b>${esc(v.owner || '—')}</b><span>Moteur (dernier relevé)</span><b>${bar(v.engine)}</b><span>Carrosserie (dernier relevé)</span><b>${bar(v.body)}</b>
          <span>CarPlay</span><b>${v.carplay ? `<span class="pill on">Installé</span> <small class="faint">${fmtTime(v.carplay.t)} · ${esc(v.carplay.installed_by || '')} · ${money(v.carplay.price)}</small>` : '<span class="pill off">Non équipé</span>'}</b></div>
          <p class="faint" style="font-size:.74rem;margin-top:.6rem">Le véhicule est suivi par son identifiant de carte grise : l'historique et le CarPlay restent après un changement de propriétaire ou de plaque.</p></div>
        <div class="card"><h2>Interventions</h2><div class="timeline">${v.history.map((h) => `<div><b>${esc(h.action)}</b>${h.details ? ` · ${esc(h.details)}` : ''}<small>${esc(h.mechanic_name || '')} · ${fmtTime(h.t)}${h.ref ? ` · <span class="mono">${esc(h.ref)}</span>` : ''}</small></div>`).join('') || '<span class="faint">Aucune intervention.</span>'}</div></div>
      </div><div class="detail">
        <div class="card"><h2>Performances installées</h2><div class="kv">${perf}</div></div>
        <div class="card"><h2>Devis</h2>${v.quotes.map((q) => `<div class="list-row"><div class="main"><b class="mono">${esc(q.uid)}</b><small>${esc(q.customer_name || '—')} · ${esc(q.mechanic_name || '')} · ${fmtTime(q.t)}</small></div><span class="mono nw">${money(q.total)}</span>${qPill(q.status)}</div>`).join('') || empty('Aucun devis.')}</div>
        ${v.invoices ? `<div class="card"><h2>Factures</h2>${v.invoices.map((x) => `<div class="list-row"><div class="main"><b class="mono">${esc(x.uid)}</b><small>${esc(x.mechanic_name || '')} · ${fmtTime(x.t)}</small></div><b class="inv-${x.status}">${money(x.amount)} · ${esc(INV[x.status] || x.status)}</b></div>`).join('') || empty('Aucune facture.')}</div>` : ''}
      </div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Devis                                                               */
  /* ------------------------------------------------------------------ */
  const QS = { q: '', status: '', mine: false, list: null };
  PAGES.quotes = async (g) => {
    const d = await req('quotes', { q: QS.q, status: QS.status, mine: QS.mine });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    QS.list = d.list; QS.canManage = d.canManage;
    const me = (T.st || {}).name;
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="qq" placeholder="Rechercher : numéro, plaque, client, mécanicien" value="${esc(QS.q)}">
        <select class="input" data-qf="status"><option value="">Tous les statuts</option>${Object.entries(QST).map(([k, l]) => `<option value="${k}" ${QS.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        ${d.canManage ? `<label class="extra"><input type="checkbox" class="check" data-qf="mine" ${QS.mine ? 'checked' : ''}> Mes devis</label>` : ''}<button class="btn" data-qs="1">Rechercher</button></div>
      ${d.canManage ? '' : '<div class="note">Vous voyez vos propres devis. La direction voit ceux de tout le garage.</div>'}
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Devis</th><th>Client</th><th>Véhicule</th><th>Lignes</th><th>Total</th><th>Statut</th><th>Date</th><th></th></tr>${d.list.map((x) => `<tr>
        <td class="mono" style="font-size:.78rem">${esc(x.uid)}${x.invoice_uid ? `<br><span class="faint">${esc(x.invoice_uid)}</span>` : ''}</td><td>${esc(x.customer_name || '—')}<br><small class="faint">par ${esc(x.mechanic_name || '—')}</small></td>
        <td>${x.plate ? `<span class="mono click" data-vplate="${esc(x.plate)}" style="text-decoration:underline dotted">${esc(x.plate)}</span>` : '—'}<br><small class="faint">${esc(x.model || '')}</small></td>
        <td class="muted" style="font-size:.8rem">${itemsText(x.items)}</td>
        <td class="mono nw">${money(x.total)}${x.paid ? `<br><small class="faint">payé ${money(x.paid)}${x.refunded ? ` · rendu ${money(x.refunded)}` : ''}</small>` : ''}</td>
        <td>${qPill(x.status)}${x.note ? `<br><small class="faint">${esc(x.note)}</small>` : ''}</td><td class="muted">${fmtTime(x.t)}</td>
        <td>${(x.status === 'pending' || x.status === 'accepted') && (d.canManage || x.mechanic_name === me) ? `<button class="btn small danger" data-qcancel="${esc(x.uid)}">Annuler</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucun devis.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Factures                                                            */
  /* ------------------------------------------------------------------ */
  const IS = { q: '', list: null };
  PAGES.invoices = async (g) => {
    const d = await req('invoices', { q: IS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    IS.list = d.list;
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="iq" placeholder="Rechercher : numéro, plaque, client" value="${esc(IS.q)}"><button class="btn" data-is="1">Rechercher</button></div>
      <div class="note">Le client paie au moment où il accepte le devis (banque, puis liquide). Les lignes qui n'ont pas pu être installées sont remboursées automatiquement : la facture ne contient que ce qui a été réellement posé.</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Facture</th><th>Client</th><th>Véhicule</th><th>Détail</th><th>Montant</th><th>Statut</th><th>Date</th><th></th></tr>${d.list.map((x) => `<tr>
        <td class="mono" style="font-size:.78rem">${esc(x.uid)}${x.quote_uid ? `<br><span class="faint">${esc(x.quote_uid)}</span>` : ''}</td><td>${esc(x.customer_name || '—')}<br><small class="faint">par ${esc(x.mechanic_name || '—')}</small></td>
        <td class="mono">${esc(x.plate || '—')}</td><td class="muted" style="font-size:.8rem">${(x.items || []).map((i) => `${esc(i.label || i.name)} <span class="faint">${money(lineTotal(i))}</span>`).join('<br>')}</td>
        <td class="mono nw">${money(x.amount)}</td><td class="inv-${x.status}"><b>${esc(INV[x.status] || x.status)}</b>${x.method ? `<br><small class="faint">${esc(METHOD[x.method] || x.method)}</small>` : ''}${x.note ? `<br><small class="faint">${esc(x.note)}</small>` : ''}</td>
        <td class="muted">${fmtTime(x.t)}</td><td>${d.canManage && x.status === 'paid' ? `<button class="btn small danger" data-refund="${esc(x.uid)}">Rembourser</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune facture.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Carte                                                               */
  /* ------------------------------------------------------------------ */
  const MS = { sel: null, data: null };
  PAGES.map = async (g) => {
    body().innerHTML = `<div class="map-wrap">
      <div class="map-box" id="mapBox"><div class="map-tools"><button class="icon-btn" data-m="in" title="Zoomer">+</button><button class="icon-btn" data-m="out" title="Dézoomer">−</button><button class="icon-btn" data-m="fit" title="Tout voir">⤢</button></div>
        <div class="map-legend"><span><i style="background:#22c55e"></i>Mécanicien</span><span><i style="background:#fb923c;border-radius:2px"></i>Dépannage</span></div></div>
      <div class="map-side"><div class="card" id="mapSel"></div><div class="card" id="mapList"></div></div></div>`;
    T.map = MecaMap.create($('#mapBox'), { image: APP.cfg && APP.cfg.map && APP.cfg.map.file ? APP.cfg.map : null, levels: {},
      statusColor: (s) => statusOf(s).color, onSelect: (s) => { MS.sel = s; renderSel(); } });
    const refresh = async () => {
      const d = await req('map');
      if (stale(g) || T.page !== 'map') return;
      if (d.error) { toast(d.error, false); return; }
      MS.data = d;
      MS.inters = d.tows.map((c) => ({ ...c, takers: c.crew }));
      T.map.setData(d.crew, [], MS.inters);
      $('#mapList').innerHTML = `<h2>Équipe <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row click" data-focus="agent:${a.id}">
          <span style="width:.6rem;height:.6rem;border-radius:50%;flex:none;background:${statusOf(a.status).color}"></span><div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)} · ${esc(statusOf(a.status).label)}${a.street ? ` · ${esc(a.street)}` : ''}</small></div></div>`).join('') || empty('Personne en service.')}
        <h2 style="margin-top:.9rem">Dépannages</h2>${MS.inters.map((i) => `<div class="alert-row" style="--c:#fb923c;cursor:pointer" data-focus="inter:${i.id}">
          <div class="t"><span>#${i.id} · ${esc(i.reason)}</span>${towPill(i.status)}</div><div class="m">${esc(i.street || '')}</div></div>`).join('') || empty('Rien en cours.')}`;
      renderSel();
    };
    await refresh();
    every((APP.cfg && APP.cfg.mapRefresh) || 3000, refresh);
  };
  function renderSel() {
    const el = $('#mapSel');
    if (!el) return;
    const s = MS.sel;
    if (!s) { el.innerHTML = '<h2>Sélection</h2><div class="faint" style="font-size:.85rem">Cliquez sur un mécanicien ou un dépannage.</div>'; return; }
    const o = s.data;
    const gps = o.x != null ? `<div class="actions-row"><button class="btn small" data-gps="${o.x},${o.y}">📍 GPS</button>${s.kind === 'inter' && can('tow') ? `<button class="btn small" data-tow-open="${o.id}">Ouvrir la demande</button>` : ''}</div>` : '';
    if (s.kind === 'agent') el.innerHTML = `<h2>Mécanicien</h2><div class="kv"><span>Nom</span><b>${esc(o.name)}</b><span>Matricule</span><b class="mono">${esc(o.matricule)}</b><span>Grade</span><b>${esc(o.grade)}</b><span>Statut</span><b>${statusPill(o.status)}</b><span>Position</span><b>${esc(o.street || '—')}</b></div>${gps}`;
    else el.innerHTML = `<h2>Dépannage #${o.id}</h2><div class="kv"><span>Motif</span><b>${esc(o.reason)}</b><span>Lieu</span><b>${esc(o.street || '—')}</b><span>Client</span><b>${esc(o.client || '—')}</b>
      <span>Véhicule</span><b>${esc(o.vehicle || '—')} <span class="mono">${esc(o.plate || '')}</span></b><span>Statut</span><b>${towPill(o.status)}</b><span>Équipe</span><b>${esc((o.crew || []).join(', ') || 'Personne')}</b></div>${gps}`;
  }

  /* ------------------------------------------------------------------ */
  /* Statistiques                                                        */
  /* ------------------------------------------------------------------ */
  const SS = { days: 7 };
  PAGES.stats = async (g) => {
    const d = await req('stats', { days: SS.days });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const t = d.totals || {};
    const max = Math.max(1, ...d.top.map((a) => a.n));
    const kinds = Object.entries(d.byKind || {});
    const maxK = Math.max(1, ...kinds.map(([, v]) => Number(v) || 0));
    body().innerHTML = `<div class="toolbar"><span class="muted">Période :</span>${[1, 7, 30, 90].map((n) => `<button class="btn small ${SS.days === n ? 'primary' : ''}" data-days="${n}">${n === 1 ? '24 h' : `${n} jours`}</button>`).join('')}</div>
      <div class="stats"><div class="stat green"><b>${money(t.revenue)}</b><span>Encaissé (${t.invoices || 0} factures)</span></div><div class="stat blue"><b>${t.interventions || 0}</b><span>Interventions</span></div>
        <div class="stat orange"><b>${t.tows || 0}</b><span>Demandes de dépannage</span></div><div class="stat"><b>${t.carplay || 0}</b><span>CarPlay installés</span></div></div>
      <div class="cols even"><div class="card"><h2>Articles les plus vendus</h2><div class="bars-h">${d.top.map((a) => `<div><span>${esc(a.name)}</span><i style="width:${a.n / max * 100}%"></i><b class="mono">${a.n}</b></div>`).join('') || empty('Aucune vente.')}</div>
          <div class="kv" style="margin-top:1rem"><span>Salaires versés</span><b class="mono">−${money(t.salaries)}</b><span>Remboursements</span><b class="mono">−${money(t.refunds)}</b></div></div>
        <div><div class="card"><h2>Recettes par type</h2><div class="bars-h">${kinds.map(([k, v]) => `<div><span>${esc(KIND[k] || k)}</span><i style="width:${(Number(v) || 0) / maxK * 100}%"></i><b class="mono">${money(v)}</b></div>`).join('') || empty('Aucune recette.')}</div></div>
          <div class="card"><h2>Interventions par mécanicien</h2>${d.workers.map((a) => `<div class="list-row"><div class="main"><b>${esc(a.name || '—')}</b></div><b class="mono">${a.n}</b></div>`).join('') || empty('Aucune intervention.')}</div></div></div>`;
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
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne fait déjà partie du garage.</p>' : ''}
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
        <span>Interventions</span><b>${e.interventions || 0}</b><span>Devis installés</span><b>${e.invoices || 0}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${e.canAct ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'}>▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer du garage</button>' : ''}</div>`
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
    body().innerHTML = `<div class="note">Vous ne modifiez que les grades <b>inférieurs</b> au vôtre, et seulement avec les permissions que vous possédez. Appliqué immédiatement aux mécaniciens connectés.</div>
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
  /* Catalogue et tarifs                                                 */
  /* ------------------------------------------------------------------ */
  const CS = { data: null, kind: '', edit: null };
  PAGES.catalog = async (g) => {
    const d = await req('catalog');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    CS.data = d;
    if (CS.edit && !CS.edit.isNew) CS.edit = d.list.find((x) => x.code === CS.edit.code) || null;
    drawCatalog();
  };
  const gradeName = (lvl) => { const gs = (CS.data && CS.data.grades) || []; const gr = gs.filter((x) => x.level <= lvl).sort((a, b) => b.level - a.level)[0] || gs[gs.length - 1]; return gr ? gr.name : `niv. ${lvl}`; };
  function drawCatalog() {
    const d = CS.data, ed = CS.edit;
    const list = d.list.filter((x) => !CS.kind || x.kind === CS.kind);
    const ro = d.canEdit ? '' : 'disabled';
    let form = '<div class="card"><h2>Article</h2><div class="faint" style="font-size:.85rem">Sélectionnez un article pour modifier son prix, son activation ou le grade minimum.</div></div>';
    if (ed) {
      const locked = ed.kind === 'perf' || ed.kind === 'carplay';
      form = `<div class="card"><h2>${ed.isNew ? 'Nouvel article' : esc(ed.name)}</h2><div class="form-grid">
        ${ed.isNew ? `<label class="field"><span>Code (unique)</span><input class="input" data-ce="code" maxlength="40" value="${esc(ed.code || '')}" placeholder="ex : vidange"></label>
          <label class="field"><span>Type</span><select class="input" data-ce="kind">${['custom', 'service', 'perf', 'cosmetic'].map((k) => `<option value="${k}" ${ed.kind === k ? 'selected' : ''}>${KIND[k]}</option>`).join('')}</select></label>
          ${ed.kind === 'perf' ? `<label class="field"><span>Amélioration</span><select class="input" data-ce="mod">${Object.keys(d.perfMods).map((k) => `<option value="${k}" ${ed.mod === k ? 'selected' : ''}>${PERF[k] || k}</option>`).join('')}</select></label>
            <label class="field"><span>Niveau</span><input class="input" type="number" min="1" max="10" data-ce="level" value="${ed.level || 1}"></label>` : ''}
          ${ed.kind === 'cosmetic' ? `<label class="field"><span>Groupe de pièces</span><select class="input" data-ce="mod">${Object.keys(d.cosmetic).map((k) => `<option value="${k}" ${ed.mod === k ? 'selected' : ''}>${COS[k] || k}</option>`).join('')}</select></label>` : ''}`
        : `<div class="field full"><span>Code · type</span><b class="mono">${esc(ed.code)} · ${esc(KIND[ed.kind] || ed.kind)}${ed.mod ? ` · ${esc(PERF[ed.mod] || COS[ed.mod] || ed.mod)}` : ''}${ed.level ? ` · niveau ${ed.level}` : ''}</b></div>`}
        <label class="field full"><span>Nom</span><input class="input" data-ce="name" maxlength="80" value="${esc(ed.name || '')}" ${ro}></label>
        <label class="field full"><span>Description</span><input class="input" data-ce="description" maxlength="255" value="${esc(ed.description || '')}" ${ro}></label>
        <label class="field"><span>Catégorie</span><select class="input" data-ce="category" ${locked || ro ? 'disabled' : ''}>${Object.entries(d.categories).map(([k, l]) => `<option value="${k}" ${ed.category === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select></label>
        <label class="field"><span>Prix ($)</span><input class="input" type="number" min="0" max="${d.maxPrice}" data-ce="price" value="${ed.price || 0}" ${ro}></label>
        <label class="field"><span>Grade minimum</span><select class="input" data-ce="minLevel" ${ro}>${[...d.grades].sort((a, b) => a.level - b.level).map((gr) => `<option value="${gr.level}" ${(ed.minLevel || 1) === gr.level ? 'selected' : ''}>${esc(gr.name)} (niv. ${gr.level})</option>`).join('')}</select></label>
        <label class="field full"><span>Compatibilité (note affichée)</span><input class="input" data-ce="compat" maxlength="120" value="${esc(ed.compat || '')}" placeholder="ex : voitures uniquement" ${ro}></label>
        <label class="field full" style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" class="check" data-ce="enabled" ${ed.enabled !== false ? 'checked' : ''} ${ro}><span style="font-size:.85rem;color:var(--text)">Actif (proposé à l'atelier et dans les devis)</span></label></div>
        ${d.canEdit ? `<div class="actions-row"><button class="btn primary" data-cs="save">${ed.isNew ? 'Ajouter' : 'Enregistrer'}</button><button class="btn" data-cs="cancel">Fermer</button>
          ${!ed.isNew && ed.kind === 'custom' ? '<button class="btn danger" data-cs="del">Supprimer</button>' : ''}</div>` : ''}
        <p class="faint" style="font-size:.74rem;margin-top:.6rem">Un nouveau prix ne s'applique qu'aux prochains devis : les devis en cours gardent le prix accepté. La compatibilité réelle (pièces disponibles sur le modèle) est vérifiée en jeu à l'atelier.</p></div>`;
    }
    body().innerHTML = `<div class="stats"><div class="stat"><b>${d.list.length}</b><span>Articles</span></div><div class="stat green"><b>${d.list.filter((x) => x.enabled).length}</b><span>Actifs</span></div>
        <div class="stat blue"><b>${d.carplay.count}</b><span>CarPlay installés</span></div><div class="stat orange"><b>${money(d.carplay.revenue)}</b><span>Recettes CarPlay</span></div></div>
      <div class="toolbar">${[['', 'Tous'], ['service', 'Prestations'], ['perf', 'Performances'], ['cosmetic', 'Esthétique'], ['carplay', 'CarPlay'], ['custom', 'Libres']].map(([k, l]) => `<button class="btn small ${CS.kind === k ? 'primary' : ''}" data-ck="${k}">${l}</button>`).join('')}
        <span style="flex:1"></span>${d.canEdit ? '<button class="btn primary small" data-cs="new">+ Nouvel article</button>' : ''}</div>
      <div class="split"><div class="card" style="padding:.3rem .6rem">${list.length ? `<table class="tbl"><tr><th>Article</th><th>Type</th><th>Prix</th><th>Grade min.</th><th>État</th></tr>${list.map((x) => `<tr class="click ${ed && ed.code === x.code ? 'sel' : ''}" data-citem="${esc(x.code)}" style="${x.enabled ? '' : 'opacity:.55'}">
        <td><b>${esc(x.name)}</b><br><small class="faint">${esc(d.categories[x.category] || x.category)}${x.description ? ` · ${esc(x.description)}` : ''}</small></td><td class="muted">${esc(KIND[x.kind] || x.kind)}${x.level ? ` · niv. ${x.level}` : ''}</td>
        <td class="mono nw">${money(x.price)}</td><td class="muted">${esc(gradeName(x.minLevel))}</td><td>${x.enabled ? '<span class="pill on">Actif</span>' : '<span class="pill off">Inactif</span>'}</td></tr>`).join('')}</table>` : empty('Aucun article.')}</div>
      <div class="detail">${form}</div></div>`;
  }
  function captureCatalog() {
    const ed = CS.edit;
    body().querySelectorAll('[data-ce]').forEach((i) => {
      const k = i.dataset.ce;
      if (k === 'enabled') ed.enabled = i.checked;
      else if (k === 'price' || k === 'minLevel' || k === 'level') ed[k] = Number(i.value);
      else ed[k] = i.value;
    });
  }

  /* ------------------------------------------------------------------ */
  /* Points d'atelier (touche E) : placés en jeu, autant que voulu        */
  /* ------------------------------------------------------------------ */
  const WP = { data: null, edit: null };
  PAGES.workshops = async (g) => {
    const d = await req('workshopList');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    WP.data = d;
    if (WP.edit && WP.edit.id) WP.edit = d.list.find((x) => x.id === WP.edit.id) ? { ...d.list.find((x) => x.id === WP.edit.id) } : null;
    drawWorkshops();
  };
  const coordTxt = (c) => (c ? `${Number(c.x).toFixed(1)}, ${Number(c.y).toFixed(1)}, ${Number(c.z).toFixed(1)}` : null);
  function drawWorkshops() {
    const d = WP.data, ed = WP.edit;
    const cards = d.list.map((w) => {
      return `<div class="point ${ed && ed.id === w.id ? 'sel' : ''}"><div style="min-width:0"><b>${esc(w.label)}</b>
          <br><small class="faint">${(w.categories || []).map((c) => esc(d.categories[c] || c)).join(' · ')} · grade ${esc(gradeOf(w.minLevel))} · ${w.radius || d.defaults.radius} m${w.distance != null ? ` · à ${w.distance} m de vous` : ''}${w.quotes ? ` · ${w.quotes} devis en cours` : ''}</small>
          <br><small class="faint mono">${esc(coordTxt(w.coords) || 'non placé')}</small></div>
        <div style="display:flex;gap:.35rem;flex-wrap:wrap;justify-content:flex-end">
          <button class="btn small" data-wp="move" data-id="${esc(w.id)}" title="Votre position, ou celle du véhicule si vous êtes dedans">📍 Déplacer ici</button>
          ${w.coords ? `<button class="btn small" data-gps="${w.coords.x},${w.coords.y}">📍</button>` : ''}
          <button class="btn small" data-wp="edit" data-id="${esc(w.id)}">✎</button><button class="btn small danger" data-wp="del" data-id="${esc(w.id)}">✕</button></div></div>`;
    }).join('');
    const e = ed || { label: '', categories: d.defaults.categories, minLevel: d.defaults.minLevel, radius: d.defaults.radius };
    const form = `<div class="card"><h2>${ed && ed.id ? 'Modifier le point' : 'Nouveau point'}</h2><div class="form-grid">
        <label class="field full"><span>Nom</span><input class="input" id="wpLabel" maxlength="40" value="${esc(e.label || '')}" placeholder="ex : Banc moteur, Peinture 1"></label>
        <div class="field full"><span>Rubriques proposées à ce point</span><div class="chips">${Object.entries(d.categories).map(([k, l]) => `<label class="extra" style="padding:.15rem .3rem"><input type="checkbox" class="check" data-wpc="${k}" ${(e.categories || []).includes(k) ? 'checked' : ''}> ${esc(l)}</label>`).join('')}</div></div>
        <label class="field"><span>Grade minimum</span><select class="input" id="wpLevel">${[...d.grades].sort((a, b) => a.level - b.level).map((gr) => `<option value="${gr.level}" ${(e.minLevel || 1) === gr.level ? 'selected' : ''}>${esc(gr.name)} (niv. ${gr.level})</option>`).join('')}</select></label>
        <label class="field"><span>Taille de la zone (rayon, m)</span><input class="input" id="wpRadius" type="number" min="1.5" max="8" step="0.5" value="${e.radius || d.defaults.radius}"></label></div>
      <div class="actions-row"><button class="btn primary" data-wp="save">${ed && ed.id ? 'Enregistrer' : '📍 Créer ici'}</button>${ed ? '<button class="btn" data-wp="cancel">Annuler</button>' : ''}</div>
      <p class="faint" style="font-size:.76rem;margin-top:.6rem">${ed && ed.id ? 'Pour changer l\'endroit : « Déplacer ici » sur le point.' : '« Créer ici » place le point à votre position (ou à celle du véhicule si vous êtes au volant).'}</p></div>`;
    body().innerHTML = `<div class="note">Posez autant de points que vous voulez (${d.max} maximum), n'importe où. Le mécanicien amène le véhicule du client sur le point, <b>au volant</b>, et appuie sur <b>E</b> : l'atelier s'ouvre. Seuls les mécaniciens voient les points. Changements appliqués tout de suite.</div>
      <div class="split"><div class="card"><h2>Points <span class="faint" style="font-size:.8rem">${d.list.length} / ${d.max}</span></h2>${cards || empty('Aucun point : créez le premier à votre position.')}</div>
        <div class="detail">${form}</div></div>`;
  }
  const gradeOf = (lvl) => { const gs = (WP.data && WP.data.grades) || []; const gr = gs.filter((x) => x.level <= (lvl || 1)).sort((a, b) => b.level - a.level)[0] || gs[0]; return gr ? gr.name : `niv. ${lvl}`; };
  async function workshopAction(b) {
    const a = b.dataset.wp, w = WP.data.list.find((x) => x.id === b.dataset.id);
    if (a === 'cancel') { WP.edit = null; return drawWorkshops(); }
    if (a === 'edit') { WP.edit = { ...w }; return drawWorkshops(); }
    if (a === 'move') {
      if (!(await confirmBox('Déplacer le point ici ?', `<b>${esc(w.label)}</b> sera placé à votre position (ou à celle du véhicule si vous êtes au volant).`, 'Déplacer'))) return;
      await call('workshopPlace', { id: w.id }, b);
      return PAGES.workshops(T.gen);
    }
    if (a === 'del') {
      if (!(await confirmBox('Supprimer ce point ?', `« <b>${esc(w.label)}</b> » ne sera plus utilisable.`, 'Supprimer', true))) return;
      await call('workshopDelete', { id: w.id }, b);
      if (WP.edit && WP.edit.id === w.id) WP.edit = null;
      return PAGES.workshops(T.gen);
    }
    if (a === 'save') {
      const data = { id: WP.edit && WP.edit.id, label: $('#wpLabel').value, minLevel: Number($('#wpLevel').value), radius: Number($('#wpRadius').value),
        categories: [...body().querySelectorAll('[data-wpc]')].filter((i) => i.checked).map((i) => i.dataset.wpc) };
      if (!data.id && !(await confirmBox('Créer le point ici ?', `« <b>${esc(data.label)}</b> » sera placé à votre position actuelle.`, 'Créer'))) return;
      const r = await call('workshopSave', data, b);
      if (r.ok) { WP.edit = null; return PAGES.workshops(T.gen); }
    }
  }

  /* ------------------------------------------------------------------ */
  /* Garage (points placés en jeu, véhicules proposés)                    */
  /* ------------------------------------------------------------------ */
  const GA = { data: null };
  const VTYPES = [['automobile', 'Voiture / dépanneuse'], ['bike', 'Moto'], ['heli', 'Hélicoptère'], ['boat', 'Bateau']];
  PAGES.garage = async (g) => {
    const d = await req('garageSettings');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    GA.data = d;
    drawGarage();
  };
  function drawGarage() {
    const s = GA.data.settings, lv = GA.data.levels;
    const pt = (k, label, desc) => { const p = s[k]; return `<div class="point"><div><b>${label}</b><br><small class="faint">${p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}${p.h != null ? ` · cap ${p.h}°` : ''}` : desc}</small></div>
      <div style="display:flex;gap:.4rem"><button class="btn small primary" data-gp="${k}">📍 Placer ici</button>${p ? `<button class="btn small danger" data-gpr="${k}">Retirer</button>` : ''}</div></div>`; };
    body().innerHTML = `<div class="note">Les points sont placés à <b>votre position actuelle</b> dans le jeu. La place de sortie utilise aussi votre orientation. Les points d'atelier (touche E) se placent dans Direction › Points d'atelier.</div>
      <div class="cols even"><div class="card"><h2>Points</h2>${pt('garage', 'Garage', 'Non placé : on y choisit le véhicule de service')}${pt('spawn', 'Place de sortie', 'Non placée : là où le véhicule apparaît')}${pt('pharmacy', 'Coffre d\'atelier', 'Non placé : coffre partagé de l\'atelier')}</div>
        <div class="card"><h2>Véhicules de service</h2><table class="tbl"><tr><th>Modèle</th><th>Nom affiché</th><th>Type</th><th>Grade min.</th><th></th></tr>
          ${s.vehicles.map((v, i) => `<tr data-vrow="${i}"><td><input class="input" data-v="model" value="${esc(v.model)}" maxlength="30"></td><td><input class="input" data-v="label" value="${esc(v.label)}" maxlength="40"></td>
            <td><select class="input" data-v="type">${VTYPES.map(([k, l]) => `<option value="${k}" ${v.type === k ? 'selected' : ''}>${l}</option>`).join('')}</select></td>
            <td><select class="input" data-v="minLevel">${lv.map((l) => `<option value="${l.level}" ${v.minLevel === l.level ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select></td>
            <td><button class="btn small danger" data-vdel="${i}">✕</button></td></tr>`).join('')}</table>
          <div class="actions-row"><button class="btn small" data-vadd="1">+ Ajouter un modèle</button><span style="flex:1"></span><button class="btn primary small" data-vsave="1">Enregistrer les véhicules</button></div>
          <p class="faint" style="font-size:.76rem;margin-top:.6rem">Nom du modèle exact (ex. « flatbed », « towtruck »). S'il n'existe pas, la sortie l'indique.</p></div></div>`;
  }
  function captureVehicles() {
    return [...body().querySelectorAll('[data-vrow]')].map((tr) => ({ model: $('[data-v="model"]', tr).value.trim(), label: $('[data-v="label"]', tr).value.trim(),
      type: $('[data-v="type"]', tr).value, minLevel: Number($('[data-v="minLevel"]', tr).value) }));
  }

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
    const income = sm('in:invoice').total;
    const expense = sm('out:salary').total + sm('out:refund').total + sm('out:commission').total;
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
        <div class="cols even"><div class="card"><h2>Détail sur 7 jours</h2><div class="kv"><span>Factures clients</span><b class="mono">+${money(sm('in:invoice').total)} <span class="faint">(${sm('in:invoice').n})</span></b>
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)} <span class="faint">(${sm('out:refund').n})</span></b>
            <span>Devis en attente</span><b class="mono">${d.pendingQuotes.n} · ${money(d.pendingQuotes.total)}</b></div></div>
          <div class="card"><h2>Recettes par type (7 jours)</h2><div class="kv">${Object.entries(KIND).map(([k, l]) => `<span>${l}</span><b class="mono">${money(sp[k] || 0)}</b>`).join('')}</div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur le montant final des devis installés, versée par l'entreprise. Appliqué à partir de maintenant.</p></div>
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
      if (!(await confirmBox('Changer la commission ?', `<b>${esc(gr ? gr.name : '')}</b> : ${gr ? gr.commission || 0 : 0} % → <b>${pct} %</b> sur le montant final des devis installés.<br>Versée depuis le compte de l'entreprise à chaque encaissement, à partir de maintenant.`, 'Appliquer'))) return;
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

  const openVehicle = (o) => { VS.id = o.id || null; VS.plate = o.plate || null; if (T.page !== 'vehicles') return go('vehicles', true); T.gen++; loading(); return vehicleView(T.gen); };

  body().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.target.tagName === 'TEXTAREA') return;
    const t = e.target;
    if (t.dataset.hq !== undefined) { HS.q = t.value; return go('history'); }
    if (t.id === 'vq') { VS.q = t.value; return go('vehicles'); }
    if (t.id === 'qq') { QS.q = t.value; return go('quotes'); }
    if (t.id === 'iq') { IS.q = t.value; return go('invoices'); }
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.ef && t.dataset.ef !== 'q') { ES.f[t.dataset.ef] = t.value; return drawEmployees(); }
    if (t.dataset.qf) { if (t.dataset.qf === 'mine') QS.mine = t.checked; else QS.status = t.value; QS.q = ($('#qq') || {}).value || ''; return go('quotes'); }
    if (t.dataset.tc !== undefined) { TS.category = t.value; TS.q = ($('#tq') || {}).value || ''; return go('transactions'); }
    if (t.dataset.ce === 'kind' || (t.dataset.ce === 'mod' && CS.edit && CS.edit.isNew)) { captureCatalog(); return drawCatalog(); }
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
    if (e.target.dataset.ef === 'q') {
      ES.f.q = e.target.value;
      const pos = e.target.selectionStart;
      drawEmployees();
      const n = body().querySelector('[data-ef="q"]'); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
    }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) return go(b.dataset.q);
    if ((b = e.target.closest('[data-gps]'))) { const [x, y] = b.dataset.gps.split(',').map(Number); post('gps', { x, y }); return toast('Itinéraire tracé.'); }
    // Véhicules
    if ((b = e.target.closest('[data-vplate]'))) return openVehicle({ plate: b.dataset.vplate });
    if ((b = e.target.closest('[data-vid]'))) return openVehicle({ id: Number(b.dataset.vid) });
    if ((b = e.target.closest('[data-vs]'))) { VS.q = ($('#vq') || {}).value || ''; return go('vehicles'); }
    if ((b = e.target.closest('[data-vback]'))) { VS.id = null; VS.plate = null; return go('vehicles'); }
    // Dépannage
    if ((b = e.target.closest('[data-tow-open]'))) { TW.sel = Number(b.dataset.towOpen); return go('tows', true); }
    if ((b = e.target.closest('[data-tow]'))) {
      TW.sel = Number(b.dataset.tow);
      if (T.page !== 'tows') return go('tows', true);
      await loadTowInfo(); return drawTows();
    }
    if ((b = e.target.closest('[data-ta]'))) return towAction(b.dataset.ta, b);
    // Devis
    if ((b = e.target.closest('[data-qs]'))) { QS.q = ($('#qq') || {}).value || ''; return go('quotes'); }
    if ((b = e.target.closest('[data-qcancel]'))) {
      const q = QS.list.find((x) => x.uid === b.dataset.qcancel);
      const paid = q && q.status === 'accepted';
      if (!(await confirmBox('Annuler le devis ?', paid ? `Le client a déjà payé : ce qui n'a pas été installé lui est <b>remboursé</b> par le compte de l'entreprise.` : 'Le client ne pourra plus l\'accepter.', 'Annuler le devis', true))) return;
      await call('quoteCancel', { uid: b.dataset.qcancel }, b);
      return go('quotes');
    }
    // Factures
    if ((b = e.target.closest('[data-is]'))) { IS.q = ($('#iq') || {}).value || ''; return go('invoices'); }
    if ((b = e.target.closest('[data-refund]'))) {
      const inv = IS.list.find((x) => x.uid === b.dataset.refund);
      const v = await confirmBox('Rembourser la facture ?', `<b>${money(inv.amount)}</b> seront repris du compte de l'entreprise et rendus à ${esc(inv.customer_name || 'le client')}. Un CarPlay facturé sur cette facture est retiré du véhicule.`,
        'Rembourser', true, '<label class="field" style="margin-top:.6rem"><span>Motif (obligatoire)</span><input class="input" data-cfv="reason" maxlength="160"></label>');
      if (!v) return;
      const r = await call('invoiceRefund', { uid: inv.uid, reason: v.reason }, b);
      if (r.ok) return go('invoices');
      return;
    }
    // Carte
    if ((b = e.target.closest('[data-m]')) && T.map) { const m = b.dataset.m; if (m === 'in') T.map.zoom(1.4); else if (m === 'out') T.map.zoom(0.7); else T.map.fit(); return; }
    if ((b = e.target.closest('[data-focus]')) && T.map && MS.data) {
      const [kind, id] = b.dataset.focus.split(':');
      const list = kind === 'agent' ? MS.data.crew : MS.inters;
      const o = list.find((x) => String(x.id) === id);
      if (o && o.x != null) { T.map.focus(o.x, o.y, 0.25); MS.sel = { kind, id: o.id, data: o }; renderSel(); }
      return;
    }
    // Statistiques
    if ((b = e.target.closest('[data-days]'))) { SS.days = Number(b.dataset.days); return go('stats'); }
    // Démission
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter le garage ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter', true))) return;
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
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre le garage au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Retirer du garage ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
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
    if ((b = e.target.closest('[data-h]'))) { const q = body().querySelector('[data-hq]'); HS.q = q ? q.value : ''; return go('history'); }
    // Catalogue
    if ((b = e.target.closest('[data-ck]'))) { CS.kind = b.dataset.ck; return drawCatalog(); }
    if ((b = e.target.closest('[data-citem]'))) { const it = CS.data.list.find((x) => x.code === b.dataset.citem); CS.edit = it ? { ...it } : null; return drawCatalog(); }
    if ((b = e.target.closest('[data-cs]'))) {
      const a = b.dataset.cs;
      if (a === 'new') { CS.edit = { isNew: true, kind: 'custom', category: 'service', price: 0, minLevel: 1, enabled: true }; return drawCatalog(); }
      if (a === 'cancel') { CS.edit = null; return drawCatalog(); }
      if (a === 'del') {
        if (!(await confirmBox('Supprimer l\'article ?', `« <b>${esc(CS.edit.name)}</b> » sera retiré du catalogue. Les anciennes factures le gardent.`, 'Supprimer', true))) return;
        const r = await call('catalogDelete', { code: CS.edit.code }, b);
        if (r.ok) { CS.edit = null; return PAGES.catalog(T.gen); }
        return;
      }
      if (a === 'save') {
        captureCatalog();
        const ed = CS.edit, old = !ed.isNew && CS.data.list.find((x) => x.code === ed.code);
        const priceTxt = old && old.price !== ed.price ? `${money(old.price)} → <b>${money(ed.price)}</b> (prochains devis seulement)` : `<b>${money(ed.price)}</b>`;
        if (!(await confirmBox(ed.isNew ? 'Ajouter l\'article ?' : 'Enregistrer l\'article ?', `« <b>${esc(ed.name || '')}</b> » · ${priceTxt}${ed.enabled ? '' : ' · <b>inactif</b>'}.`, 'Enregistrer'))) return;
        const r = await call('catalogSave', ed, b);
        if (r.ok) { if (ed.isNew) CS.edit = null; return PAGES.catalog(T.gen); }
      }
      return;
    }
    // Points d'atelier
    if ((b = e.target.closest('[data-wp]'))) return workshopAction(b);
    // Garage
    if ((b = e.target.closest('[data-gp]'))) {
      if (!(await confirmBox('Placer le point ici ?', 'Le point sera enregistré à votre position actuelle.', 'Placer'))) return;
      const r = await call('garagePoint', { kind: b.dataset.gp }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-gpr]'))) {
      if (!(await confirmBox('Retirer ce point ?', 'Il ne sera plus utilisable tant qu\'il n\'est pas replacé.', 'Retirer', true))) return;
      const r = await call('garagePoint', { kind: b.dataset.gpr, remove: true }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-vadd]'))) { GA.data.settings.vehicles = captureVehicles(); GA.data.settings.vehicles.push({ model: '', label: '', type: 'automobile', minLevel: (GA.data.levels[0] || {}).level || 1 }); return drawGarage(); }
    if ((b = e.target.closest('[data-vdel]'))) { const list = captureVehicles(); list.splice(Number(b.dataset.vdel), 1); GA.data.settings.vehicles = list; return drawGarage(); }
    if ((b = e.target.closest('[data-vsave]'))) {
      const list = captureVehicles().filter((v) => v.model);
      if (!(await confirmBox('Enregistrer les véhicules ?', `${list.length} modèle(s) proposé(s) au garage.`, 'Enregistrer'))) return;
      const r = await call('garageVehicles', { vehicles: list }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    // Finance
    if ((b = e.target.closest('[data-fpay],[data-frate],[data-fcom],[data-fpayall]'))) return financeAction(b);
    if ((b = e.target.closest('[data-ts]'))) { TS.q = ($('#tq') || {}).value || ''; return go('transactions'); }
  });

  setInterval(() => { const d = new Date(); $('#tabClock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

  /* ------------------------------------------------------------------ */
  function applyOpts(o) {
    if (!o) return false;
    if (o.page === 'vehicle') { openVehicle({ plate: o.plate, id: o.id }); return true; }
    if (o.page === 'tow' && o.id) { TW.sel = Number(o.id); go('tows', true); return true; }
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
      if (T.page === 'vehicles' && (VS.id || VS.plate)) { VS.id = null; VS.plate = null; go('vehicles'); return true; }
      if (T.page === 'employees' && ES.cid) { ES.cid = null; ES.emp = null; drawEmployees(); return true; }
      if (T.page === 'grades' && GS.edit) { GS.edit = null; drawGrades(); return true; }
      if (T.page === 'catalog' && CS.edit) { CS.edit = null; drawCatalog(); return true; }
      if (T.page === 'workshops' && WP.edit) { WP.edit = null; drawWorkshops(); return true; }
      if (T.page === 'tows' && TW.sel) { TW.sel = null; TW.info = null; drawTows(); return true; }
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
