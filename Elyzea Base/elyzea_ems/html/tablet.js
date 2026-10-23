/* =====================================================================
   ELYZEA EMS - tablette
   Tableau de bord · Dispatch · Patients · Comptes rendus · Carte · Statistiques
   Direction : Recrutement, Employés, Grades, Permissions, Historique, Garage
   Finance : Vue d'ensemble et salaires, Factures, Tarifs, PPA, Transactions
   Chaque bouton appelle le serveur, qui revérifie les droits et recalcule les montants.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0, kiosk: false, kioskLabel: '' };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusOf = (id) => APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' };
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
  const lvlColor = (l) => (APP.levels[l] || {}).color || '#3b82f6';
  const lvlLabel = (l) => (APP.levels[l] || {}).label || l;
  const stPill = (s) => `<span class="st-pill st-${esc(s)}">${esc(callSt(s))}</span>`;
  const urgDot = (u) => `<span class="urg" style="--c:${urgOf(u).color}" title="Urgence ${esc(urgOf(u).label)}"></span>`;
  const STATUS_R = { open: 'En cours', done: 'Terminé', archived: 'Archivé' };
  const INV = { paid: 'Payée', failed: 'Refusée', refunded: 'Remboursée', cancelled: 'Annulée', free: 'Gratuite' };
  const PPAK = { civil: 'PPA civil', fdo: 'PPA force de l\'ordre' };
  const PST = { pending: 'En cours', paid: 'Payé', failed: 'Refusé', refunded: 'Remboursé', free: 'Gratuit', delivered: 'Remis', cancelled: 'Annulé' };
  const CAT = { invoice: 'Factures médicales', ppa: 'PPA', salary: 'Salaires', commission: 'Commissions', refund: 'Remboursements', respawn: 'Frais d\'hôpital', other: 'Autre' };
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'dispatch', label: 'Dispatch', ico: '📟', perm: ['calls'] },
    { id: 'patients', label: 'Patients', ico: '🩺', perm: ['records_view'] },
    { id: 'reports', label: 'Comptes rendus', ico: '📝', perm: ['records_view'] },
    { id: 'lab', label: 'Laboratoire', ico: '🧪', perm: ['lab_view'] },
    { id: 'map', label: 'Carte', ico: '🗺️', perm: ['map'] },
    { id: 'stats', label: 'Statistiques', ico: '📊', perm: ['stats_view'] },
    { id: 'recruit', label: 'Recrutement', ico: '➕', perm: ['recruit'], group: 'Direction' },
    { id: 'employees', label: 'Employés', ico: '👥', perm: ['employees_view'], group: 'Direction' },
    { id: 'grades', label: 'Grades', ico: '🎖️', perm: ['direction'], group: 'Direction' },
    { id: 'perms', label: 'Permissions', ico: '🔐', perm: ['perms_manage'], group: 'Direction' },
    { id: 'history', label: 'Historique', ico: '🕘', perm: ['history_view'], group: 'Direction' },
    { id: 'garage', label: 'Garage', ico: '🚑', perm: ['garage_manage'], group: 'Direction' },
    { id: 'finance', label: 'Vue d\'ensemble', ico: '💰', perm: ['finance'], group: 'Finance' },
    { id: 'invoices', label: 'Factures', ico: '🧾', perm: ['finance', 'billing_manage'], group: 'Finance' },
    { id: 'billing', label: 'Tarifs des soins', ico: '🏷️', perm: ['finance', 'billing_manage'], group: 'Finance' },
    { id: 'ppa', label: 'PPA', ico: '📜', perm: ['ppa_manage', 'finance', 'stats_view'], group: 'Finance' },
    { id: 'transactions', label: 'Transactions', ico: '🔁', perm: ['finance'], group: 'Finance' },
  ];
  const allowed = (n) => (T.kiosk ? n.id === 'patients' : n.id !== 'patients') && canAny(...n.perm) && (n.group !== 'Direction' || can('direction'));

  function renderNav() {
    let last = null, html = `<div class="brand"><div class="shield">✚</div><div><b>${esc((APP.cfg && APP.cfg.job) || 'SAMS')}</b><small>${T.kiosk ? 'Poste des dossiers médicaux' : 'Tablette médicale'}</small></div></div>`;
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

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || ((APP.cfg && APP.cfg.job) || 'SAMS'); }
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
    if (!nav || !allowed(nav)) page = T.kiosk ? 'patients' : 'dashboard';
    T.page = page;
    T.gen++;
    if (!keepSub) { RS.mode = 'list'; ES.cid = null; PT.cid = null; PT.src = null; DS.sel = null; LS.id = null; LS.cid = null; }
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
    const t = d.me.times || {};
    const callRow = (c) => `<div class="alert-row" style="--c:${urgOf(c.urgency).color}"><div class="t"><span>${urgDot(c.urgency)}#${c.id} · ${esc(c.reason)}</span>${stPill(c.status)}</div>
      <div class="m">${esc(c.street || '')} · ${ago(c.t)} · ${c.crew.length ? esc(c.crew.join(', ')) : 'personne'}</div></div>`;
    body().innerHTML = `
      <div class="stats">
        <div class="stat blue"><b>${d.dutyCount}</b><span>EMS en service</span></div>
        <div class="stat orange"><b>${d.calls.length}</b><span>Appels en cours</span></div>
        <div class="stat red"><b>${d.downs.length}</b><span>Personnes à terre</span></div>
        <div class="stat green"><b>${d.today.revives}</b><span>Réanimations aujourd'hui</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Appels en cours ${can('calls') ? '<button class="btn small" data-q="dispatch">Dispatch ›</button>' : ''}</h2>${d.calls.map(callRow).join('') || empty('Aucun appel en cours.')}</div>
        <div class="card"><h2>Personnes à terre</h2>${d.downs.map((x) => `<div class="list-row"><span class="avatar" style="background:rgba(239,68,68,.16);color:#fca5a5">!</span>
          <div class="main"><b>${esc(x.name)}</b><small>${esc(x.street || '')} · à terre ${ago(x.since)}${x.stabilized ? ' · stabilisé' : ''}</small></div></div>`).join('') || empty('Personne à terre.')}</div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small><span class="mono">${esc(a.matricule)}</span> · ${esc(a.grade)}${a.street ? ` · 📍 ${esc(a.street)}` : ''}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session en cours</span><b class="mono">${dur(t.session)}</b><span>Temps non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b>
          <span>Temps total</span><b class="mono">${dur(t.total)}</b><span>Taux actuel</span><b>${money(t.rate)} / h</b></div>
          <div class="actions-row">${can('reports_write') ? '<button class="btn primary small" data-q="newReport">+ Compte rendu</button>' : ''}${can('map') ? '<button class="btn small" data-q="map">🗺️ Carte</button>' : ''}
            <button class="btn danger small" data-resign="1">Quitter l'EMS</button></div></div>
        <div class="card"><h2>Aujourd'hui</h2><div class="kv"><span>Appels reçus</span><b>${d.today.calls}</b><span>Actes médicaux</span><b>${d.today.treatments}</b><span>Réanimations</span><b>${d.today.revives}</b><span>Effectif total</span><b>${d.employees}</b></div></div>
        <div class="card"><h2>Soutiens actifs</h2>${d.supports.map((s) => `<div class="alert-row" style="--c:${lvlColor(s.level)}"><div class="t"><span>${esc(lvlLabel(s.level))} · ${esc(s.author)}</span><span class="faint">${ago(s.t)}</span></div><div class="m">${esc(s.street || '')}</div></div>`).join('') || empty('Aucune demande de soutien.')}</div>
      </div></div>`;
    every(6000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Dispatch                                                            */
  /* ------------------------------------------------------------------ */
  const DS = { sel: null, data: null, info: null };
  const NEXT = ['enroute', 'onsite', 'care', 'transport'];
  PAGES.dispatch = async (g) => {
    const d = await req('callsList');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    DS.data = d;
    if (DS.sel) { const r = await req('callInfo', { id: DS.sel }); DS.info = r.error ? null : r.call; }
    drawDispatch();
    every(5000, async () => {
      if (T.page !== 'dispatch' || typing()) return;
      const n = await req('callsList'); if (n.error || T.page !== 'dispatch') return;
      DS.data = n;
      if (DS.sel) { const r = await req('callInfo', { id: DS.sel }); DS.info = r.error ? null : r.call; }
      drawDispatch();
    });
  };
  function drawDispatch() {
    const d = DS.data, i = DS.info;
    const rows = d.list.map((c) => `<tr class="click ${DS.sel === c.id ? 'sel' : ''}" data-call="${c.id}"><td class="mono faint">${c.id}</td><td>${urgDot(c.urgency)}<b>${esc(c.reason)}</b><br><small class="muted">${esc(c.street || '')}</small></td>
      <td>${esc(c.patient || '—')}</td><td>${stPill(c.status)}</td><td class="muted">${esc(c.crew.join(', ') || '—')}</td><td class="muted">${ago(c.t)}</td></tr>`).join('');
    const hist = d.history.map((c) => `<tr class="click" data-call="${c.id}"><td class="mono faint">${c.id}</td><td>${esc(c.reason)}<br><small class="muted">${esc(c.street || '')}</small></td><td>${esc(c.patient_name || '—')}</td>
      <td>${stPill(c.status)}</td><td class="muted">${esc(c.assigned_name || '—')}</td><td class="muted">${fmtTime(c.t)}</td></tr>`).join('');
    let detail = `<div class="card"><h2>Détail</h2><div class="faint" style="font-size:.85rem">Sélectionnez un appel.</div></div>`;
    if (i) {
      const live = i.live;
      const idx = live ? NEXT.indexOf(live.status) : -1;
      detail = `<div class="card"><div class="eyebrow">Appel #${i.id} · ${esc(i.source)}</div><h2 style="margin-top:.3rem;justify-content:flex-start;gap:.2rem">${urgDot(i.urgency)}${esc(i.reason)}</h2>
        <div class="kv"><span>Statut</span><b>${stPill(live ? live.status : i.status)}</b><span>Lieu</span><b>${esc(i.street || '—')}</b><span>Appelant</span><b>${esc(i.caller_name || '—')}</b>
          <span>Patient</span><b>${esc(i.patient_name || '—')}</b><span>Responsable</span><b>${esc(i.assigned_name || '—')}</b><span>Équipe</span><b>${esc(live ? live.crew.join(', ') || '—' : '—')}</b>
          <span>Reçu</span><b>${fmtTime(i.t)}</b>${i.c ? `<span>Clôturé</span><b>${fmtTime(i.c)}</b>` : ''}</div>
        ${i.info ? `<p class="muted" style="font-size:.84rem;margin-top:.6rem">${esc(i.info)}</p>` : ''}
        ${live ? `<div class="actions-row">${live.mine ? `<button class="btn small" data-ca="route">📍 GPS</button>
            ${NEXT.slice(idx + 1).map((s) => `<button class="btn small" data-ca="st:${s}">${esc(callSt(s))}</button>`).join('')}
            <button class="btn small success" data-ca="st:done">Terminer</button><button class="btn small" data-ca="leave">Quitter</button>`
          : `<button class="btn small primary" data-ca="accept">${live.crew.length ? 'Rejoindre' : 'Accepter'}</button><button class="btn small" data-ca="route">📍 GPS</button>`}
          ${d.canManage || live.mine ? '<button class="btn small danger" data-ca="st:cancelled">Annuler l\'appel</button>' : ''}</div>` : ''}
        ${can('reports_write') ? '<div class="actions-row"><button class="btn small" data-ca="report">📝 Compte rendu de cet appel</button></div>' : ''}</div>
        <div class="card"><h2>Historique de l'appel</h2><div class="timeline">${(i.log || []).map((l) => `<div><b>${esc(callSt(l.status))}</b><small>${esc(l.actor_name || '')} · ${fmtTime(l.t)}</small></div>`).join('')}</div></div>`;
    }
    body().innerHTML = `<div class="split"><div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Appels en cours <span class="faint" style="font-size:.8rem">${d.list.length}</span></h2>
          ${d.list.length ? `<table class="tbl"><tr><th>#</th><th>Motif</th><th>Patient</th><th>Statut</th><th>Équipe</th><th>Reçu</th></tr>${rows}</table>` : empty('Aucun appel en cours.')}</div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Historique</h2>
          ${d.history.length ? `<table class="tbl"><tr><th>#</th><th>Motif</th><th>Patient</th><th>Statut</th><th>Responsable</th><th>Date</th></tr>${hist}</table>` : empty('Aucun appel terminé.')}</div>
      </div><div class="detail">${detail}</div></div>`;
  }
  async function dispatchAction(a, b) {
    const id = DS.sel, live = DS.info && DS.info.live;
    if (a === 'route') { if (live) post('gps', { x: live.x, y: live.y }); return; }
    if (a === 'report') return newReport({ callId: id });
    if (a === 'accept') { const r = await call('callAccept', { id }, b); if (r.ok && r.call) post('gps', { x: r.call.x, y: r.call.y }); }
    else if (a === 'leave') await call('callLeave', { id }, b);
    else if (a.startsWith('st:')) {
      const st = a.slice(3);
      if ((st === 'done' || st === 'cancelled') && !(await confirmBox(st === 'done' ? 'Terminer l\'appel ?' : 'Annuler l\'appel ?', `L'appel #${id} sera clôturé pour toute l'équipe.`, 'Confirmer', st === 'cancelled'))) return;
      await call('callStatus', { id, status: st }, b);
    }
    return PAGES.dispatch(T.gen);
  }

  /* ------------------------------------------------------------------ */
  /* Patients                                                            */
  /* ------------------------------------------------------------------ */
  const PT = { q: '', list: null, cid: null, src: null, p: null };
  PAGES.patients = async (g) => {
    if (PT.cid || PT.src) return patientView(g);
    setTitle('Recherche de dossier', T.kioskLabel || 'Dossiers médicaux');
    const bar = `<div class="toolbar"><input class="input grow" id="ptq" placeholder="Nom et prénom du patient (ex : Élodie Durand)" value="${esc(PT.q)}" autocomplete="off">
      <button class="btn primary" data-pt="search">🔎 Rechercher</button></div>`;
    if (!PT.q.trim()) {
      body().innerHTML = `${bar}<div class="card"><div class="empty">Entrez le nom et le prénom de la personne, puis « Rechercher ».<br>
        <small class="faint">Le dossier complet s'affiche : fiche médicale, maladies et blessures, actes, rendez-vous, analyses, comptes rendus, PPA, appels.</small></div></div>`;
      const i = $('#ptq'); if (i) i.focus();
      return;
    }
    const d = await req('patients', { q: PT.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = bar + empty(d.error); return; }
    body().innerHTML = `${bar}
      <div class="card" style="padding:.3rem .6rem">${d.needQuery ? empty('Tapez au moins deux lettres.') : d.list.length ? `<table class="tbl"><tr><th>Patient</th><th>Présence</th><th>Dernier acte</th></tr>${d.list.map((p) => `<tr class="click" data-pcid="${esc(p.cid)}">
        <td><b>${esc(p.name)}</b></td><td>${p.online ? `<span class="pill on">Présent · ID ${p.id}</span>` : '<span class="pill off">Absent</span>'}</td><td class="muted">${p.last ? fmtTime(p.last) : '—'}</td></tr>`).join('')}</table>` : empty('Aucune personne trouvée avec ce nom.')}</div>`;
  };
  async function patientView(g) {
    const r = await req('patient', { cid: PT.cid });
    if (stale(g)) return;
    if (r.error) { toast(r.error, false); PT.cid = null; PT.src = null; return PAGES.patients(g); }
    const p = r.patient;
    PT.p = p; PT.cid = p.cid; PT.src = null;
    setTitle(p.name, 'Dossier médical');
    const ro = p.canWrite ? '' : 'disabled';
    const COND = { illness: 'Maladie', injury: 'Blessure', std: 'MST' };
    const APST = { pending: ['warn', 'En attente'], accepted: ['on', 'Accepté'], done: ['off', 'Terminé'], cancelled: ['off', 'Annulé'], expired: ['off', 'Expiré'] };
    const cur = (p.conditions || []).filter((c) => c.active), past = (p.conditions || []).filter((c) => !c.active);
    body().innerHTML = `<div class="toolbar"><button class="btn" data-pt="back">‹ Nouvelle recherche</button><span style="flex:1"></span></div>
      <div class="split"><div>
        <div class="card"><h2>Fiche médicale ${p.online ? `<span class="pill ${p.down ? 'bad' : 'on'}">${p.down ? 'À terre' : 'Présent'} · ID ${p.id}</span>` : ''}</h2><div class="form-grid">
          <label class="field"><span>Groupe sanguin</span><select class="input" id="pBlood" ${ro}><option value="">Non renseigné</option>${['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((b) => `<option ${p.blood === b ? 'selected' : ''}>${b}</option>`).join('')}</select></label>
          <label class="field"><span>Allergies</span><input class="input" id="pAll" maxlength="255" value="${esc(p.allergies || '')}" ${ro} placeholder="ex : pénicilline"></label>
          <label class="field full"><span>Notes médicales</span><textarea class="input" id="pNotes" maxlength="4000" ${ro} placeholder="Antécédents, traitements, remarques…">${esc(p.notes || '')}</textarea></label></div>
          ${p.canWrite ? '<div class="actions-row"><button class="btn primary" data-pt="save">Enregistrer le dossier</button></div>' : ''}
          ${p.updatedBy ? `<p class="faint" style="font-size:.75rem;margin-top:.6rem">Modifié par ${esc(p.updatedBy)} · ${fmtTime(p.updated)}</p>` : ''}</div>
        <div class="card"><h2>Actes médicaux</h2>${p.treatments.length ? `<table class="tbl"><tr><th>Acte</th><th>Secouriste</th><th>Appel</th><th>Facture</th><th>Date</th></tr>${p.treatments.map((t) => `<tr>
          <td><b>${esc(t.label)}</b></td><td>${esc(t.ems_name || '—')}</td><td class="mono faint">${t.call_id ? `#${t.call_id}` : '—'}</td><td class="mono faint">${esc(t.invoice_uid || 'non facturé')}</td><td class="muted">${fmtTime(t.t)}</td></tr>`).join('')}</table>` : empty('Aucun acte enregistré.')}</div>
        <div class="card"><h2>Examens et actes</h2>${(p.procedures || []).length ? (p.procedures || []).map((x) => `<div class="list-row"><div class="main"><b>${x.icon || ''} ${esc(x.label)}${x.zone ? ` · ${esc(x.zone)}` : ''}</b>
          <small style="display:block">${esc(x.report || '')}</small><small class="faint" style="display:block">${esc(x.ems || '—')}${x.grade ? ` (${esc(x.grade)})` : ''} · ${fmtTime(x.t)}${x.items ? ` · matériel : ${esc(x.items)}` : ''}${x.score != null ? ` · ${x.score} %` : ''}</small></div>${x.hidden ? '<span class="pill warn">Confidentiel</span>' : ''}</div>`).join('') : empty('Aucun examen ni acte enregistré.')}</div>
        <div class="card"><h2>Blessures localisées</h2>${(p.injuries || []).length ? (p.injuries || []).map((x) => `<div class="list-row"><div class="main"><b>${esc(x.label)} · ${esc(x.zoneLabel)}</b>
          <small>${fmtTime(x.created)}${x.xray ? ` · radiographiée le ${fmtTime(x.xray)}` : ''}${x.treated ? ` · prise en charge ${fmtTime(x.treated)}${x.treatedBy ? ` par ${esc(x.treatedBy)}` : ''}` : ''}</small></div>
          <span class="pill ${x.status === 'healed' ? 'off' : (x.status === 'active' ? 'bad' : 'warn')}">${{ active: 'Active', controlled: 'Contrôlée', treated: 'Traitée', healed: 'Guérie' }[x.status] || esc(x.status)}</span></div>`).join('') : empty('Aucune blessure enregistrée.')}</div>
        <div class="card"><h2>Vaccinations</h2>${(p.vaccinations || []).length ? (p.vaccinations || []).map((v) => `<div class="list-row"><div class="main"><b>${esc(v.label || v.vaccine)}</b>
          <small>${fmtTime(v.given_at)} · ${esc(v.ems_name || '')}${v.expires_at ? ` · protégé jusqu'au ${fmtTime(v.expires_at)}` : ''}</small></div></div>`).join('') : empty('Aucune vaccination.')}</div>
        <div class="card"><h2>Maladies et blessures</h2>
          ${cur.length ? cur.map((c) => `<div class="list-row"><div class="main"><b>${esc(c.label)}</b><small>${COND[c.type] || ''} · depuis ${fmtTime(c.since)}${c.splinted ? ' · attelle posée' : ''}${c.diagnosed ? '' : ' · non diagnostiqué'}</small></div><span class="pill bad">En cours</span></div>`).join('') : empty('Aucune maladie ni blessure en cours.')}
          ${past.length ? `<div class="section-label" style="margin-top:.6rem">Antécédents</div>${past.map((c) => `<div class="list-row"><div class="main"><b>${esc(c.label)}</b><small>${fmtTime(c.since)} → ${c.cured ? fmtTime(c.cured) : '—'}${c.curedBy ? ` · soigné par ${esc(c.curedBy)}` : ' · guéri'}</small></div></div>`).join('')}` : ''}</div>
        <div class="card"><h2>Rendez-vous</h2>${(p.appointments || []).map((a) => { const st = APST[a.status] || ['off', a.status];
          return `<div class="list-row"><div class="main"><b>${esc(a.typeLabel)}</b><small>${fmtTime(a.created)}${a.ems ? ` · ${esc(a.ems)}` : ''}${a.reason ? ` · ${esc(a.reason)}` : ''}</small></div><span class="pill ${st[0]}">${st[1]}</span></div>`; }).join('') || empty('Aucun rendez-vous.')}</div>
      </div><div class="detail">
        <div class="card"><h2>Analyses (laboratoire)</h2>${(p.labs || []).map((x) => `<div class="list-row"><div class="main"><b>Prélèvement #${x.id}</b><small>${esc(x.sampled_by_name || '')} · ${fmtTime(x.t)}</small></div><span class="pill ${x.status === 'done' ? 'on' : 'off'}">${x.status === 'done' ? 'Analysé' : x.status === 'pending' ? 'En attente' : 'Annulé'}</span></div>`).join('') || empty('Aucune analyse.')}</div>
        <div class="card"><h2>Comptes rendus</h2>${p.reports.map((x) => `<div class="list-row"><div class="main"><b>${esc(x.title)}</b><small>${esc(x.outcome || '')} · ${esc(x.author_name)} · ${fmtTime(x.t)}</small></div></div>`).join('') || empty('Aucun compte rendu.')}</div>
        <div class="card"><h2>PPA</h2>${p.ppa.map((x) => `<div class="list-row"><div class="main"><b>${esc(PPAK[x.type] || x.type)} ${x.number ? `· ${esc(x.number)}` : ''}</b><small>${esc(PST[x.delivery_status] || x.delivery_status)} · ${esc(PST[x.payment_status] || x.payment_status)} · ${money(x.price)} · ${fmtTime(x.t)}</small></div></div>`).join('') || empty('Aucun PPA.')}</div>
        ${p.invoices ? `<div class="card"><h2>Factures</h2>${p.invoices.map((x) => `<div class="list-row"><div class="main"><b class="mono">${esc(x.uid)}</b><small>${x.kind === 'ppa' ? 'PPA' : 'Soins'} · ${fmtTime(x.t)}</small></div><b class="inv-${x.status}">${money(x.amount)} · ${esc(INV[x.status] || x.status)}</b></div>`).join('') || empty('Aucune facture.')}</div>` : ''}
        <div class="card"><h2>Appels</h2>${p.calls.map((x) => `<div class="list-row"><div class="main"><b>#${x.id} · ${esc(x.reason)}</b><small>${esc(x.assigned_name || '—')} · ${fmtTime(x.t)}</small></div>${stPill(x.status)}</div>`).join('') || empty('Aucun appel.')}</div>
      </div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Laboratoire : analyse sanguine « Alcool et substances »             */
  /* Résultats calculés et figés par le serveur (simulés pour le RP).    */
  /* ------------------------------------------------------------------ */
  const LS = { q: '', id: null, cid: null };
  const LSTAT = { positive: ['bad', 'Positif'], negative: ['on', 'Négatif'], indeterminate: ['off', 'Indéterminé'] };
  const LLEVEL = { nul: 'Nul', faible: 'Faible', modere: 'Modéré', eleve: 'Élevé' };
  const SST = { pending: ['warn', 'En attente d\'analyse'], done: ['on', 'Analysé'], cancelled: ['off', 'Annulé'] };
  const labPill = (st) => { const x = LSTAT[st] || LSTAT.indeterminate; return `<span class="pill lab-${esc(st || 'indeterminate')}">${x[1]}</span>`; };
  const fullTime = (t) => (t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—');
  PAGES.lab = async (g) => {
    if (LS.id) return labReport(g);
    const d = await req('labList', LS.cid ? { cid: LS.cid } : { q: LS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const pend = d.list.filter((x) => x.status === 'pending').length;
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="labq" placeholder="Rechercher un patient par nom" value="${esc(LS.q)}"><button class="btn" data-lab="search">Rechercher</button>
        ${LS.cid ? '<button class="btn" data-lab="all">Tous les patients</button>' : ''}</div>
      <div class="lab-note">🧪 Prélèvement : <b>ALT</b> sur le patient › « Prélèvement sanguin ». Résultats <b>simulés pour le jeu de rôle</b>, calculés uniquement à partir des consommations enregistrées par le serveur.</div>
      <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .2rem 0">Prélèvements ${pend ? `<span class="pill warn">${pend} en attente</span>` : ''}</h2>
      ${d.list.length ? `<table class="tbl"><tr><th>Réf.</th><th>Patient</th><th>Prélevé par</th><th>Prélèvement</th><th>État</th><th>Résultat</th></tr>${d.list.map((x) => `<tr class="click" data-labid="${x.id}">
        <td class="mono">${esc(x.ref)}</td><td><b>${esc(x.patient)}</b></td><td>${esc(x.sampledBy)}</td><td class="muted">${fmtTime(x.sampledAt)}</td>
        <td><span class="pill ${(SST[x.status] || SST.pending)[0]}">${(SST[x.status] || SST.pending)[1]}</span></td>
        <td>${x.status !== 'done' ? '<span class="faint">—</span>' : (x.positives && x.positives.length ? `<span class="pill lab-positive">Positif : ${esc(x.positives.join(', '))}</span>` : '<span class="pill lab-negative">Aucun positif</span>')}</td></tr>`).join('')}</table>`
        : empty('Aucun prélèvement.')}</div>`;
  };
  async function labReport(g) {
    const r = await req('labReport', { id: LS.id });
    if (stale(g)) return;
    if (r.error) { toast(r.error, false); LS.id = null; return PAGES.lab(g); }
    const x = r.report;
    setTitle(`${x.ref} · ${x.patient}`, 'Laboratoire');
    const res = x.results;
    const st = SST[x.status] || SST.pending;
    let section;
    if (x.status === 'pending') {
      section = `<div class="card"><h2>Alcool et substances</h2>${empty('Prélèvement en attente d\'analyse.')}
        ${x.canAnalyze ? '<div class="actions-row"><button class="btn primary" data-lab="analyze">🧪 Lancer l\'analyse</button><button class="btn danger" data-lab="cancel">Annuler le prélèvement</button></div>' : '<p class="faint" style="font-size:.8rem;margin-top:.5rem">L\'analyse demande la permission « Lancer l\'analyse » et d\'être en service.</p>'}</div>`;
    } else if (!res) {
      section = `<div class="card"><h2>Alcool et substances</h2>${empty('Aucun résultat (prélèvement annulé).')}</div>`;
    } else {
      const a = res.alcohol || {};
      const th = (x.config && x.config.thresholds) || {};
      const gauge = a.bac !== undefined && a.bac !== null ? Math.min(100, (a.bac / Math.max(1.5, (th.high || 1) * 1.5)) * 100) : 0;
      section = `<div class="card lab-section"><h2>Alcool et substances <span class="faint" style="font-size:.74rem;font-weight:500">Résultats simulés pour le jeu de rôle — pas une mesure médicale réelle</span></h2>
        <div class="lab-alc lab-b-${esc(a.status || 'indeterminate')}">
          <div class="lab-alc-head"><b>🍷 Alcoolémie</b>${labPill(a.status)}</div>
          <div class="kv"><span>Présence d'alcool</span><b>${a.present === true ? 'Oui' : a.present === false ? 'Non' : 'Indéterminée'}</b>
            <span>Taux simulé</span><b class="mono">${a.bac !== undefined && a.bac !== null ? `${Number(a.bac).toFixed(2).replace('.', ',')} g/L` : '—'}</b>
            <span>Niveau</span><b>${a.level ? LLEVEL[a.level] || a.level : '—'}</b>
            <span>Consommation</span><b>${esc((a.recency && a.recency.text) || (a.status === 'negative' ? 'Aucune consommation détectable' : '—'))}</b></div>
          ${a.bac !== undefined && a.bac !== null ? `<div class="lab-gauge"><i style="width:${gauge}%"></i><em style="left:${Math.min(100, ((th.moderate || 0.5) / Math.max(1.5, (th.high || 1) * 1.5)) * 100)}%"></em><em style="left:${Math.min(100, ((th.high || 1) / Math.max(1.5, (th.high || 1) * 1.5)) * 100)}%"></em></div>` : ''}
          ${a.note ? `<p class="faint lab-small">${esc(a.note)}</p>` : ''}</div>
        <h3 class="lab-h3">Dépistage des substances</h3>
        <table class="tbl"><tr><th>Substance</th><th>Résultat</th><th>Consommation</th><th>Prélèvement</th><th>Analyse</th></tr>
          ${(res.substances || []).map((sb) => `<tr class="lab-row-${esc(sb.status)}"><td><b>${esc(sb.label)}</b>${sb.note ? `<small class="lab-small faint" style="display:block">${esc(sb.note)}</small>` : ''}</td>
            <td>${labPill(sb.status)}</td><td class="muted">${esc((sb.recency && sb.recency.text) || (sb.status === 'negative' ? 'Non détectée' : '—'))}</td>
            <td class="muted">${fullTime(x.sampledAt)}</td><td class="muted">${fullTime(x.analyzedAt)}</td></tr>`).join('')}</table>
        <div class="lab-legend"><span class="pill lab-negative">Négatif</span><span class="pill lab-positive">Positif</span><span class="pill lab-indeterminate">Indéterminé</span></div></div>`;
    }
    body().innerHTML = `<div class="toolbar"><button class="btn" data-lab="back">‹ Laboratoire</button><span style="flex:1"></span>
        <button class="btn" data-lab="patientlabs" data-cid="${esc(x.cid)}">🧪 Analyses du patient</button></div>
      <div class="split"><div>
        <div class="card"><h2>Compte rendu d'analyse sanguine <span class="pill ${st[0]}">${st[1]}</span></h2>
          <div class="kv"><span>Référence</span><b class="mono">${esc(x.ref)}</b><span>Patient</span><b>${esc(x.patient)}</b><span>Identifiant</span><b class="mono">${esc(x.cid)}</b>
            <span>Prélevé par</span><b>${esc(x.sampledBy)}</b><span>Date du prélèvement</span><b>${fullTime(x.sampledAt)}</b>
            <span>Médecin responsable</span><b>${esc(x.analyzedBy || '—')}</b><span>Date de l'analyse</span><b>${fullTime(x.analyzedAt)}</b></div></div>
        ${section}
      </div><div class="detail">
        <div class="card"><h2>Historique de l'analyse</h2>${(x.history || []).map((h) => `<div class="list-row"><div class="main"><b>${esc(h.action)}</b><small>${esc(h.by || '')} · ${fullTime(h.at)}</small></div></div>`).join('') || empty('—')}</div>
        <div class="card"><h2>Analyses précédentes du patient</h2>${(x.previous || []).map((o) => `<div class="list-row click" data-labid="${o.id}"><div class="main"><b class="mono">${esc(o.ref)}</b>
          <small>${fmtTime(o.sampledAt)} · ${(SST[o.status] || SST.pending)[1]}${o.positives && o.positives.length ? ` · positif : ${esc(o.positives.join(', '))}` : ''}</small></div></div>`).join('') || empty('Aucune autre analyse.')}</div>
      </div></div>`;
  }
  body().addEventListener('click', async (e) => {
    if (T.page !== 'lab') return;
    const row = e.target.closest('[data-labid]');
    if (row) { LS.id = Number(row.dataset.labid); return go('lab', true); }
    const b = e.target.closest('[data-lab]');
    if (!b) return;
    const a = b.dataset.lab;
    if (a === 'search') { LS.q = ($('#labq') || {}).value || ''; LS.cid = null; return go('lab', true); }
    if (a === 'all') { LS.cid = null; LS.q = ''; return go('lab', true); }
    if (a === 'back') { LS.id = null; return go('lab', true); }
    if (a === 'patientlabs') { LS.id = null; LS.cid = b.dataset.cid; return go('lab', true); }
    if (a === 'analyze') { const r = await call('labAnalyze', { id: LS.id }, b); if (!r.error) go('lab', true); return; }
    if (a === 'cancel') {
      const v = await confirmBox('Annuler ce prélèvement ?', 'Il ne pourra plus être analysé. Le motif est gardé dans l\'historique.', 'Annuler le prélèvement', true,
        '<label class="field"><span>Motif</span><input class="input" data-cfv="reason" maxlength="120" placeholder="ex : erreur de patient"></label>');
      if (!v) return;
      const r = await call('labCancel', { id: LS.id, reason: v.reason }, b); if (!r.error) go('lab', true);
    }
  });
  $('#tabBody').addEventListener('keydown', (e) => { if (T.page === 'lab' && e.key === 'Enter' && e.target.id === 'labq') { LS.q = e.target.value; LS.cid = null; go('lab', true); } });

  /* ------------------------------------------------------------------ */
  /* Comptes rendus                                                      */
  /* ------------------------------------------------------------------ */
  const RS = { mode: 'list', f: { q: '', status: 'active' }, current: null, draft: null, loaded: null };
  PAGES.reports = async (g) => {
    if (RS.mode === 'view') return reportView(g);
    if (RS.mode === 'edit') return reportEdit();
    const d = await req('reportsList', { q: RS.f.q, status: RS.f.status });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-rf="q" placeholder="Rechercher : titre, patient, rédacteur, équipe" value="${esc(RS.f.q)}">
        <select class="input" data-rf="status">${[['active', 'Non archivés'], ['open', 'En cours'], ['done', 'Terminés'], ['archived', 'Archivés'], ['all', 'Tous']].map(([v, l]) => `<option value="${v}" ${RS.f.status === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <button class="btn" data-r="search">Rechercher</button>${can('reports_write') ? '<button class="btn primary" data-r="new">+ Nouveau compte rendu</button>' : ''}</div>
      ${d.list.length ? `<div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>#</th><th>Titre</th><th>Patient</th><th>Issue</th><th>Rédacteur</th><th>Date</th><th>Statut</th></tr>
        ${d.list.map((r) => `<tr class="click" data-open-report="${r.id}"><td class="mono faint">${r.id}</td><td><b>${esc(r.title)}</b>${r.call_id ? `<br><small class="faint">Appel #${r.call_id}</small>` : ''}</td>
          <td>${esc(r.patient_name || '—')}</td><td class="muted">${esc(r.outcome || '—')}</td><td>${esc(r.author_name)}</td><td class="muted">${fmtTime(r.t)}</td><td class="status-${r.status}">${STATUS_R[r.status]}</td></tr>`).join('')}</table></div>`
        : empty('Aucun compte rendu ne correspond.')}`;
  };
  async function reportView(g) {
    const d = await req('reportGet', { id: RS.current });
    if (stale(g)) return;
    if (d.error) { toast(d.error, false); RS.mode = 'list'; return PAGES.reports(g); }
    const r = d.report;
    RS.loaded = r;
    setTitle(`Compte rendu #${r.id}`, 'Comptes rendus');
    body().innerHTML = `<div class="toolbar"><button class="btn" data-r="back">‹ Comptes rendus</button><span style="flex:1"></span>
        ${r.canEdit && r.status !== 'archived' ? '<button class="btn" data-r="edit">✎ Modifier</button>' : ''}
        ${r.canArchive ? `<button class="btn ${r.status === 'archived' ? '' : 'danger'}" data-r="archive" data-arch="${r.status !== 'archived'}">${r.status === 'archived' ? 'Désarchiver' : 'Archiver'}</button>` : ''}</div>
      <div class="split"><div class="card"><div class="eyebrow"><span class="status-${r.status}">${STATUS_R[r.status]}</span>${r.call_id ? ` · Appel #${r.call_id}` : ''}</div>
          <h2 style="font-size:1.2rem;margin:.3rem 0 .9rem">${esc(r.title)}</h2>
          <div class="kv" style="margin-bottom:1rem"><span>Patient</span><b>${esc(r.patient_name || '—')}</b><span>Équipe</span><div class="chips">${r.crew.map((c) => `<span class="chip">${esc(c)}</span>`).join('') || '—'}</div>
            <span>Début</span><b>${fmtTime(r.s)}</b><span>Fin</span><b>${fmtTime(r.e)}</b><span>Transport</span><b>${r.transport ? 'Oui, à l\'hôpital' : 'Non'}</b><span>Issue</span><b>${esc(r.outcome || '—')}</b></div>
          <h3 class="muted" style="font-size:.8rem;margin-bottom:.4rem">SOINS ADMINISTRÉS</h3><div class="report-body">${r.treatments.map((t) => `• ${esc(t)}`).join('\n') || '—'}</div>
          <h3 class="muted" style="font-size:.8rem;margin:1rem 0 .4rem">OBSERVATIONS</h3><div class="report-body">${esc(r.notes || '—')}</div></div>
        <div class="detail"><div class="card"><h2>Informations</h2><div class="kv"><span>Rédacteur</span><b>${esc(r.author_name)}</b><span>Matricule</span><b class="mono">${esc(r.author_matricule || '—')}</b>
          <span>Créé le</span><b>${fmtTime(r.t)}</b><span>Modifié le</span><b>${fmtTime(r.u)}</b></div></div>
          <div class="card"><h2>Historique</h2><div class="timeline">${r.history.map((h) => `<div>${esc(h.action)}<small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}</small></div>`).join('')}</div></div></div></div>`;
  }
  const toLocal = (t) => { if (!t) return ''; const d = new Date(t * 1000); const p = (n) => String(n).padStart(2, '0'); return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`; };
  const fromLocal = (v) => (v ? Math.floor(new Date(v).getTime() / 1000) : null);
  function reportEdit() {
    const r = RS.draft;
    setTitle(r.id ? `Modifier le compte rendu #${r.id}` : 'Nouveau compte rendu', 'Comptes rendus');
    const outs = (APP.cfg && APP.cfg.outcomes) || [];
    body().innerHTML = `<div class="toolbar"><button class="btn" data-r="cancelEdit">‹ Annuler</button><span style="flex:1"></span><button class="btn primary" data-r="save">Enregistrer</button></div>
      ${r.callId ? `<div class="note">Pré-rempli à partir de l'appel #${r.callId} : vérifiez et complétez.</div>` : (r.patientCid && !r.id ? '<div class="note">Pré-rempli à partir des actes récents du patient : vérifiez et complétez.</div>' : '')}
      <div class="card"><div class="form-grid">
        <label class="field full"><span>Titre</span><input class="input" data-d="title" maxlength="120" value="${esc(r.title)}"></label>
        <label class="field"><span>Patient</span><input class="input" data-d="patientName" maxlength="100" value="${esc(r.patientName || '')}" placeholder="Nom du patient"></label>
        <label class="field"><span>Statut</span><select class="input" data-d="status"><option value="open" ${r.status !== 'done' ? 'selected' : ''}>En cours</option><option value="done" ${r.status === 'done' ? 'selected' : ''}>Terminé</option></select></label>
        <label class="field"><span>Début</span><input class="input" type="datetime-local" data-d="started" value="${toLocal(r.started)}"></label>
        <label class="field"><span>Fin</span><input class="input" type="datetime-local" data-d="ended" value="${toLocal(r.ended)}"></label>
        <label class="field"><span>Issue</span><select class="input" data-d="outcome"><option value="">—</option>${outs.map((o) => `<option ${r.outcome === o ? 'selected' : ''}>${esc(o)}</option>`).join('')}</select></label>
        <label class="field" style="flex-direction:row;align-items:center;gap:.5rem;margin-top:1.4rem"><input type="checkbox" class="check" data-d="transport" ${r.transport ? 'checked' : ''}><span style="font-size:.88rem;color:var(--text)">Transport à l'hôpital</span></label>
        <label class="field full"><span>Équipe (une personne par ligne)</span><textarea class="input" data-d="crew" style="min-height:4rem">${esc((r.crew || []).join('\n'))}</textarea></label>
        <label class="field full"><span>Soins administrés (un par ligne)</span><textarea class="input" data-d="treatments">${esc((r.treatments || []).join('\n'))}</textarea></label>
        <label class="field full"><span>Observations</span><textarea class="input" data-d="notes" maxlength="6000" style="min-height:8rem">${esc(r.notes || '')}</textarea></label>
      </div></div>`;
  }
  function captureDraft() {
    const r = RS.draft;
    body().querySelectorAll('[data-d]').forEach((i) => {
      const k = i.dataset.d;
      if (k === 'transport') r.transport = i.checked;
      else if (k === 'crew' || k === 'treatments') r[k] = i.value.split('\n').map((x) => x.trim()).filter(Boolean);
      else if (k === 'started' || k === 'ended') r[k] = fromLocal(i.value);
      else r[k] = i.value;
    });
  }
  async function newReport(src) {
    const d = await req('reportDraft', src || {});
    if (d.error) return toast(d.error, false);
    RS.draft = { ...d.draft, status: 'open' };
    RS.mode = 'edit';
    if (T.page !== 'reports') return go('reports', true);
    return reportEdit();
  }
  async function openReport(id) { RS.mode = 'view'; RS.current = id; if (T.page !== 'reports') return go('reports', true); T.gen++; loading(); await reportView(T.gen); }

  /* ------------------------------------------------------------------ */
  /* Carte                                                               */
  /* ------------------------------------------------------------------ */
  const MS = { sel: null, data: null };
  PAGES.map = async (g) => {
    body().innerHTML = `<div class="map-wrap">
      <div class="map-box" id="mapBox"><div class="map-tools"><button class="icon-btn" data-m="in" title="Zoomer">+</button><button class="icon-btn" data-m="out" title="Dézoomer">−</button><button class="icon-btn" data-m="fit" title="Tout voir">⤢</button></div>
        <div class="map-legend"><span><i style="background:#22c55e"></i>EMS</span>${['low', 'medium', 'high'].map((k) => `<span><i style="background:${lvlColor(k)}"></i>Soutien ${esc(lvlLabel(k).toLowerCase())}</span>`).join('')}<span><i style="background:#fb923c;border-radius:2px"></i>Appel / à terre</span></div></div>
      <div class="map-side"><div class="card" id="mapSel"></div><div class="card" id="mapList"></div></div></div>`;
    T.map = EmsMap.create($('#mapBox'), { image: APP.cfg && APP.cfg.map && APP.cfg.map.file ? APP.cfg.map : null, levels: APP.levels,
      statusColor: (s) => statusOf(s).color, onSelect: (s) => { MS.sel = s; renderSel(); } });
    const refresh = async () => {
      const d = await req('map');
      if (stale(g) || T.page !== 'map') return;
      if (d.error) { toast(d.error, false); return; }
      MS.data = d;
      const inters = [...d.calls.map((c) => ({ ...c, kind: 'call', takers: c.crew })), ...d.downs.filter((x) => x.x != null).map((x) => ({ ...x, id: `down${x.id}`, kind: 'down', reason: `À terre : ${x.name}`, takers: [] }))];
      MS.inters = inters;
      T.map.setData(d.crew, d.supports, inters);
      $('#mapList').innerHTML = `<h2>Équipe <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row click" data-focus="agent:${a.id}">
          <span style="width:.6rem;height:.6rem;border-radius:50%;flex:none;background:${statusOf(a.status).color}"></span><div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)} · ${esc(statusOf(a.status).label)}${a.street ? ` · ${esc(a.street)}` : ''}</small></div></div>`).join('') || empty('Personne en service.')}
        <h2 style="margin-top:.9rem">Appels et urgences</h2>${inters.map((i) => `<div class="alert-row" style="--c:${i.kind === 'down' ? '#ef4444' : urgOf(i.urgency).color};cursor:pointer" data-focus="inter:${i.id}">
          <div class="t"><span>${esc(i.reason)}</span>${i.kind === 'call' ? stPill(i.status) : ''}</div><div class="m">${esc(i.street || '')}</div></div>`).join('') || empty('Rien en cours.')}`;
      renderSel();
    };
    await refresh();
    every((APP.cfg && APP.cfg.mapRefresh) || 3000, refresh);
  };
  function renderSel() {
    const el = $('#mapSel');
    if (!el) return;
    const s = MS.sel;
    if (!s) { el.innerHTML = '<h2>Sélection</h2><div class="faint" style="font-size:.85rem">Cliquez sur un EMS, un soutien ou un appel.</div>'; return; }
    const o = s.data;
    const gps = o.x != null ? `<div class="actions-row"><button class="btn small" data-gps="${o.x},${o.y}">📍 GPS</button></div>` : '';
    if (s.kind === 'agent') el.innerHTML = `<h2>EMS</h2><div class="kv"><span>Nom</span><b>${esc(o.name)}</b><span>Matricule</span><b class="mono">${esc(o.matricule)}</b><span>Grade</span><b>${esc(o.grade)}</b><span>Statut</span><b>${statusPill(o.status)}</b><span>Position</span><b>${esc(o.street || '—')}</b></div>${gps}`;
    else if (s.kind === 'alert') el.innerHTML = `<h2>Soutien</h2><div class="kv"><span>Niveau</span><b style="color:${lvlColor(o.level)}">${esc(lvlLabel(o.level))}</b><span>Auteur</span><b>${esc(o.author)}</b><span>Lieu</span><b>${esc(o.street || '—')}</b><span>Heure</span><b>${fmtTime(o.t)}</b></div>${gps}`;
    else el.innerHTML = `<h2>${o.kind === 'down' ? 'Personne à terre' : `Appel #${o.id}`}</h2><div class="kv"><span>Motif</span><b>${esc(o.reason)}</b><span>Lieu</span><b>${esc(o.street || '—')}</b>
      ${o.kind === 'call' ? `<span>Statut</span><b>${stPill(o.status)}</b><span>Équipe</span><b>${esc((o.crew || []).join(', ') || 'Personne')}</b>` : `<span>Depuis</span><b>${ago(o.since)}</b><span>Stabilisé</span><b>${o.stabilized ? 'Oui' : 'Non'}</b>`}</div>${gps}`;
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
    const max = Math.max(1, ...d.acts.map((a) => a.n));
    const maxT = Math.max(1, ...d.topTime.map((a) => Number(a.secs) || 0));
    body().innerHTML = `<div class="toolbar"><span class="muted">Période :</span>${[1, 7, 30, 90].map((n) => `<button class="btn small ${SS.days === n ? 'primary' : ''}" data-days="${n}">${n === 1 ? '24 h' : `${n} jours`}</button>`).join('')}</div>
      <div class="stats"><div class="stat blue"><b>${t.calls || 0}</b><span>Appels</span></div><div class="stat green"><b>${t.done || 0}</b><span>Appels terminés</span></div>
        <div class="stat orange"><b>${t.avgTime ? dur(t.avgTime) : '—'}</b><span>Durée moyenne d'un appel</span></div><div class="stat"><b>${money(t.billed)}</b><span>Soins facturés</span></div></div>
      <div class="cols even"><div class="card"><h2>Actes médicaux</h2><div class="bars-h">${d.acts.map((a) => `<div><span>${esc(a.label)}</span><i style="width:${a.n / max * 100}%"></i><b class="mono">${a.n}</b></div>`).join('') || empty('Aucun acte.')}</div>
          <div class="kv" style="margin-top:1rem"><span>Comptes rendus</span><b>${t.reports || 0}</b><span>PPA remis</span><b>${t.ppa || 0}</b><span>Appels annulés</span><b>${t.cancelled || 0}</b></div></div>
        <div><div class="card"><h2>Temps de service</h2><div class="bars-h">${d.topTime.map((a) => `<div><span>${esc(a.name)}</span><i style="width:${(Number(a.secs) || 0) / maxT * 100}%"></i><b class="mono">${dur(a.secs)}</b></div>`).join('') || empty('Aucune session.')}</div></div>
          <div class="card"><h2>Actes par secouriste</h2>${d.topActs.map((a) => `<div class="list-row"><div class="main"><b>${esc(a.name || '—')}</b></div><b class="mono">${a.n}</b></div>`).join('') || empty('Aucun acte.')}</div></div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Recrutement                                                         */
  /* ------------------------------------------------------------------ */
  const RC = { preview: null };
  PAGES.recruit = async () => {
    const p = RC.preview;
    body().innerHTML = `<div class="note">La demande est envoyée à la <b>personne la plus proche</b> de vous. Vérifiez son identité : elle reçoit une proposition « Accepter / Refuser » (30 secondes). Vous ne pouvez recruter qu'à un grade inférieur au vôtre.</div>
      <div class="card" style="max-width:40rem"><h2>Recruter</h2><button class="btn primary" data-rc="find">🔎 Rechercher la personne la plus proche</button>
        ${p ? `<div style="margin-top:1rem" class="card"><div class="list-row"><span class="avatar">${initials(p.target.name)}</span><div class="main"><b>${esc(p.target.name)}</b><small>À ${p.target.distance} m · métier actuel : ${esc(p.target.job)}</small></div></div>
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne fait déjà partie de l\'EMS.</p>' : ''}
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
        <span>Actes médicaux</span><b>${e.treatments}</b><span>Comptes rendus</span><b>${e.reports}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${e.canAct ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'}>▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de l\'EMS</button>' : ''}</div>`
        : `<p class="faint" style="font-size:.8rem;margin-top:.8rem">${e.cid === ES.data.myCid ? 'C\'est votre fiche : vous ne pouvez pas modifier votre propre grade.' : 'Grade égal ou supérieur au vôtre : aucune action possible.'}</p>`}</div>
      <div class="card"><h2>Sessions de service</h2>${(e.sessions || []).map((x) => `<div class="list-row"><div class="main"><b class="mono" style="font-weight:500">${fmtTime(x.s)} → ${x.e ? fmtTime(x.e) : 'en cours'}</b>
        <small>${esc(x.grade_name || '')}${x.end_reason ? ` · ${esc(x.end_reason)}` : ''}</small></div><span class="mono nw">${dur(x.seconds)} · ${money(x.amount)}</span></div>`).join('') || empty('Aucune session.')}</div>
      ${e.history ? `<div class="card"><h2>Historique</h2><div class="timeline">${e.history.map((h) => `<div><b>${esc(h.action)}</b>${h.old_grade || h.new_grade ? ` · ${esc(h.old_grade || '—')} → ${esc(h.new_grade || '—')}` : ''}
        <small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}${h.reason ? ` · « ${esc(h.reason)} »` : ''}</small></div>`).join('') || '<span class="faint">Aucune opération.</span>'}</div></div>` : ''}`;
  }
  async function changeGrade(e, target, kind) {
    const me = T.st || {};
    const v = await confirmBox(kind, `<div class="kv"><span>Employé</span><b>${esc(e.name)}</b><span>Grade actuel</span><b>${esc(e.grade)}</b><span>Nouveau grade</span><b>${esc(target.name)}</b><span>Responsable</span><b>${esc(me.grade || '')} · ${esc(me.matricule || '')}</b></div>
      <p class="faint" style="margin-top:.5rem;font-size:.8rem">Le temps déjà fait reste payé au taux de l'ancien grade.</p>`,
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
    body().innerHTML = `${d.canGrades ? '' : '<div class="note">Consultation seule : la création et la modification demandent la permission « Créer et modifier les grades ».</div>'}
      <div class="split"><div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Niveau</th><th>Grade</th><th>Effectif</th><th></th></tr>
        ${list.map((gr) => `<tr><td class="mono">${gr.level}</td><td><b>${esc(gr.name)}</b> ${gr.isDefault ? '<span class="tag">Recrues</span>' : ''}${gr.perms.includes('direction') ? ' <span class="tag">Direction</span>' : ''}</td><td>${gr.members}</td>
          <td style="text-align:right;white-space:nowrap">${d.canGrades && gr.level < d.myLevel ? `<button class="btn small" data-g="edit" data-id="${gr.id}">Modifier</button> <button class="btn small danger" data-g="del" data-id="${gr.id}">Supprimer</button>` : '<span class="faint" style="font-size:.75rem">—</span>'}</td></tr>`).join('')}</table></div>
        <div class="detail">${d.canGrades ? `<div class="card"><h2>${ed && ed.id ? 'Modifier le grade' : 'Créer un grade'}</h2><div class="form-grid">
          <label class="field full"><span>Nom</span><input class="input" id="gName" maxlength="50" value="${esc(ed ? ed.name : '')}" placeholder="ex : Interne"></label>
          <label class="field"><span>Niveau (hiérarchie)</span><input class="input" id="gLevel" type="number" min="1" max="${d.myLevel - 1}" value="${ed ? ed.level : ''}" placeholder="1 à ${d.myLevel - 1}"></label>
          <label class="field full" style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" class="check" id="gDefault" ${ed && ed.isDefault ? 'checked' : ''}><span style="font-size:.85rem;color:var(--text)">Grade donné aux nouvelles recrues</span></label></div>
          <div class="actions-row"><button class="btn primary" data-g="save">${ed && ed.id ? 'Enregistrer' : 'Créer le grade'}</button>${ed ? '<button class="btn" data-g="cancel">Annuler</button>' : ''}</div>
          <p class="faint" style="font-size:.76rem;margin-top:.7rem">Permissions : onglet Permissions. Taux horaire : Finance. Supprimer un grade réaffecte d'abord ses employés. Votre niveau : ${d.myLevel}.</p></div>` : ''}</div></div>`;
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
    body().innerHTML = `<div class="note">Vous ne modifiez que les grades <b>inférieurs</b> au vôtre, et seulement avec les permissions que vous possédez. Appliqué immédiatement aux EMS connectés.</div>
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
  /* Garage (points placés en jeu, véhicules proposés)                    */
  /* ------------------------------------------------------------------ */
  const GA = { data: null };
  const VTYPES = [['automobile', 'Voiture / ambulance'], ['heli', 'Hélicoptère'], ['boat', 'Bateau'], ['bike', 'Moto']];
  PAGES.garage = async (g) => {
    const d = await req('garageSettings');
    const rp = await req('recordsPoints');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    GA.data = d;
    GA.records = rp.list || [];
    drawGarage();
  };
  function drawGarage() {
    const s = GA.data.settings, lv = GA.data.levels;
    const pt = (k, label, desc) => { const p = s[k]; return `<div class="point"><div><b>${label}</b><br><small class="faint">${p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}${p.h != null ? ` · cap ${p.h}°` : ''}` : desc}</small></div>
      <div style="display:flex;gap:.4rem"><button class="btn small primary" data-gp="${k}">📍 Placer ici</button>${p ? `<button class="btn small danger" data-gpr="${k}">Retirer</button>` : ''}</div></div>`; };
    body().innerHTML = `<div class="note">Les points sont placés à <b>votre position actuelle</b> dans le jeu. La place de sortie utilise aussi votre orientation (regardez dans le sens où le véhicule doit sortir).</div>
      <div class="cols even"><div class="card"><h2>Points</h2>${pt('garage', 'Garage', 'Non placé : on y choisit le véhicule')}${pt('spawn', 'Place de sortie', 'Non placée : là où le véhicule apparaît')}${pt('pharmacy', 'Pharmacie', 'Non placée : coffre de matériel médical')}</div>
        <div class="card"><h2>Véhicules proposés</h2><table class="tbl"><tr><th>Modèle</th><th>Nom affiché</th><th>Type</th><th>Grade min.</th><th></th></tr>
          ${s.vehicles.map((v, i) => `<tr data-vrow="${i}"><td><input class="input" data-v="model" value="${esc(v.model)}" maxlength="30"></td><td><input class="input" data-v="label" value="${esc(v.label)}" maxlength="40"></td>
            <td><select class="input" data-v="type">${VTYPES.map(([k, l]) => `<option value="${k}" ${v.type === k ? 'selected' : ''}>${l}</option>`).join('')}</select></td>
            <td><select class="input" data-v="minLevel">${lv.map((l) => `<option value="${l.level}" ${v.minLevel === l.level ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select></td>
            <td><button class="btn small danger" data-vdel="${i}">✕</button></td></tr>`).join('')}</table>
          <div class="actions-row"><button class="btn small" data-vadd="1">+ Ajouter un modèle</button><span style="flex:1"></span><button class="btn primary small" data-vsave="1">Enregistrer les véhicules</button></div>
          <p class="faint" style="font-size:.76rem;margin-top:.6rem">Nom du modèle exact (ex. « ambulance » ou un modèle de pack ajouté au serveur). S'il n'existe pas, la sortie l'indique.</p></div></div>
      <div class="card"><h2>Postes des dossiers médicaux</h2>
        <p class="faint" style="font-size:.8rem;margin-bottom:.6rem">Les dossiers médicaux ne s'ouvrent plus depuis la tablette : seulement à un poste (ex. le PC de l'accueil). Placez-vous devant le PC, puis « Placer ici ». Au poste, <b>E</b> ouvre la recherche par nom et prénom.</p>
        ${(GA.records || []).map((p) => `<div class="point"><div><b>${esc(p.label)}</b><br><small class="faint">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</small></div>
          <button class="btn small danger" data-rpr="${p.id}">Retirer</button></div>`).join('') || '<div class="empty">Aucun poste : personne ne peut consulter les dossiers.</div>'}
        <div class="actions-row"><input class="input grow" id="rpLabel" maxlength="60" placeholder="Nom du poste (ex : Accueil – Pillbox)"><button class="btn primary small" data-rpa="1">📍 Placer un poste ici</button></div></div>`;
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
    const income = sm('in:invoice').total + sm('in:ppa').total + sm('in:respawn').total;
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
    const ppa = (k) => (d.ppa.find((x) => x.type === k) || { total: 0, n: 0 });
    body().innerHTML = `<div class="stats">
        <div class="stat green"><b>${money(d.balance)}</b><span>Compte de l'entreprise</span></div>
        <div class="stat blue"><b>${money(income)}</b><span>Entrées (7 jours)</span></div>
        <div class="stat red"><b>${money(expense)}</b><span>Sorties (7 jours)</span></div>
        <div class="stat ${d.totalDue > d.balance ? 'red' : 'orange'}"><b>${money(d.totalDue)}</b><span>Salaires dus</span></div></div>
      <div class="split"><div>
        <div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Salaires ${d.canPay ? `<button class="btn small primary" data-fpayall="1" ${d.totalDue > 0 ? '' : 'disabled'}>Payer tout le monde</button>` : ''}</h2>
          ${d.employees.length ? `<table class="tbl"><tr><th>Employé</th><th>Grade</th><th>Service</th><th>Non payé</th><th>Total</th><th>À payer</th><th></th></tr>${rows}</table>` : empty('Aucun employé.')}
          <p class="faint" style="font-size:.76rem;margin:.6rem .4rem">Chaque période est comptée au taux et au grade qu'elle avait : un changement de taux ou une promotion n'est jamais rétroactif. « Payer » débite le compte de l'entreprise puis crédite la banque de l'employé (même hors ligne) ; seul le temps payé est retiré.</p></div>
        <div class="cols even"><div class="card"><h2>Détail sur 7 jours</h2><div class="kv"><span>Factures médicales</span><b class="mono">+${money(sm('in:invoice').total)} <span class="faint">(${sm('in:invoice').n})</span></b>
            <span>PPA</span><b class="mono">+${money(sm('in:ppa').total)} <span class="faint">(${sm('in:ppa').n})</span></b><span>Frais d'hôpital</span><b class="mono">+${money(sm('in:respawn').total)}</b>
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)}</b></div></div>
          <div class="card"><h2>Recettes PPA (7 jours)</h2><div class="kv"><span>PPA civil</span><b class="mono">${money(ppa('civil').total)} <span class="faint">(${ppa('civil').n})</span></b>
            <span>PPA force de l'ordre</span><b class="mono">${money(ppa('fdo').total)} <span class="faint">(${ppa('fdo').n})</span></b></div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur les factures de soins et de réanimation, versée par l'entreprise. Appliqué à partir de maintenant.</p></div>
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
      if (!(await confirmBox('Changer la commission ?', `<b>${esc(gr ? gr.name : '')}</b> : ${gr ? gr.commission || 0 : 0} % → <b>${pct} %</b> sur les factures de soins et de réanimation.<br>Versée depuis le compte de l'entreprise à chaque encaissement, à partir de maintenant.`, 'Appliquer'))) return;
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
  /* Factures                                                            */
  /* ------------------------------------------------------------------ */
  const IS = { q: '', status: '', kind: '' };
  PAGES.invoices = async (g) => {
    const d = await req('invoices', IS);
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    IS.list = d.list; IS.canManage = d.canManage;
    body().innerHTML = `<div class="toolbar"><input class="input grow" id="iq" placeholder="Rechercher : numéro, patient, secouriste" value="${esc(IS.q)}">
        <select class="input" data-if="kind"><option value="">Soins et PPA</option><option value="medical" ${IS.kind === 'medical' ? 'selected' : ''}>Soins</option><option value="ppa" ${IS.kind === 'ppa' ? 'selected' : ''}>PPA</option></select>
        <select class="input" data-if="status"><option value="">Tous les statuts</option>${Object.entries(INV).map(([k, l]) => `<option value="${k}" ${IS.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <button class="btn" data-is="search">Rechercher</button></div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Facture</th><th>Patient</th><th>Détail</th><th>Montant</th><th>Statut</th><th>Date</th><th></th></tr>${d.list.map((x) => `<tr>
        <td class="mono">${esc(x.uid)}<br><small class="faint">${x.kind === 'ppa' ? 'PPA' : 'Soins'}${x.mode ? ` · ${esc(MODES[x.mode] || x.mode)}` : ''}</small></td><td>${esc(x.patient_name || '—')}<br><small class="faint">par ${esc(x.ems_name || '—')}</small></td>
        <td class="muted" style="font-size:.8rem">${(x.items || []).map((i) => esc(i.label)).join(', ')}</td><td class="mono nw">${money(x.amount)}</td>
        <td class="inv-${x.status}"><b>${esc(INV[x.status] || x.status)}</b>${x.method ? `<br><small class="faint">${x.method === 'cash' ? 'liquide' : 'banque'}</small>` : ''}${x.note ? `<br><small class="faint">${esc(x.note)} · ${esc(x.handled_by || '')}</small>` : ''}</td>
        <td class="muted">${fmtTime(x.t)}</td><td>${d.canManage && (x.status === 'paid' || x.status === 'failed') ? `<button class="btn small danger" data-refund="${esc(x.uid)}">${x.status === 'paid' ? 'Rembourser' : 'Annuler'}</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune facture.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Tarifs des soins                                                    */
  /* ------------------------------------------------------------------ */
  PAGES.billing = async (g) => {
    const d = await req('billingSettings');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const s = d.settings, ro = d.canEdit ? '' : 'disabled';
    body().innerHTML = `${d.canEdit ? '' : '<div class="note">Consultation seule : la modification demande la permission « Tarifs des soins ».</div>'}
      <div class="cols even"><div class="card"><h2>Mode de facturation</h2>
        ${Object.entries(MODES).map(([k, l]) => `<label class="extra"><input type="radio" name="bmode" value="${k}" ${s.mode === k ? 'checked' : ''} ${ro}> <b>${l}</b>
          <span class="faint">${k === 'service' ? '· chaque acte enregistré est facturé' : k === 'flat' ? '· un forfait par intervention' : '· forfait + chaque acte'}</span></label>`).join('')}
        <label class="field" style="margin-top:.8rem;max-width:14rem"><span>Forfait d'intervention ($)</span><input class="input" id="bFlat" type="number" min="0" max="${d.maxPrice}" value="${s.flat}" ${ro}></label></div>
      <div class="card"><h2>Prestations</h2><table class="tbl"><tr><th>Prestation</th><th>Prix ($)</th><th>Active</th></tr>${s.services.map((x) => `<tr><td><b>${esc(x.label)}</b></td>
        <td><input class="input" style="width:7rem" type="number" min="0" max="${d.maxPrice}" data-sp="${x.id}" value="${x.price}" ${ro}></td><td><input type="checkbox" class="check" data-se="${x.id}" ${x.enabled ? 'checked' : ''} ${ro}></td></tr>`).join('')}</table>
        <p class="faint" style="font-size:.76rem;margin-top:.6rem">Les actes sont enregistrés automatiquement (examen, soins, stabilisation, réanimation, transport). Un acte facturé ne peut pas l'être deux fois. Les nouveaux tarifs ne s'appliquent qu'aux prochaines factures.</p>
        ${d.canEdit ? '<div class="actions-row"><button class="btn primary" data-bsave="1">Enregistrer les tarifs</button></div>' : ''}</div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* PPA : réglages et historique                                        */
  /* ------------------------------------------------------------------ */
  const PP = { q: '', kind: '' };
  PAGES.ppa = async (g) => {
    const [s, h] = await Promise.all([req('ppaSettings'), req('ppaHistory', PP)]);
    if (stale(g)) return;
    if (s.error) { body().innerHTML = empty(s.error); return; }
    const ro = s.canEdit ? '' : 'disabled';
    body().innerHTML = `${s.papiers ? '' : '<div class="note" style="border-color:rgba(239,68,68,.4);background:rgba(239,68,68,.08)">elyzea_papiers n\'est pas démarré : aucun PPA ne peut être remis.</div>'}
      <div class="cols even"><div class="card"><h2>Catégories</h2>${s.list.map((x) => `<div class="point"><div><b>${esc(x.label)}</b><br><small class="faint">${x.kind === 'fdo' ? `Réservé à : ${esc((s.conditions.fdoJobs || []).join(', ') || 'tout le monde')}` : 'Tout citoyen'}</small></div>
          <div style="display:flex;gap:.6rem;align-items:center"><input class="input" style="width:7rem" type="number" min="0" max="${s.maxPrice}" data-ppp="${x.kind}" value="${x.price}" ${ro}><span class="faint">$</span>
          <label class="extra"><input type="checkbox" class="check" data-ppe="${x.kind}" ${x.enabled ? 'checked' : ''} ${ro}> Active</label></div></div>`).join('')}
        ${s.canEdit ? '<div class="actions-row"><button class="btn primary" data-ppsave="1">Enregistrer</button></div>' : ''}
        <p class="faint" style="font-size:.76rem;margin-top:.6rem">Un changement de prix ne touche que les prochaines délivrances. Conditions : en service, à proximité, ${s.conditions.noDuplicate ? 'pas de doublon sur la personne, ' : ''}${s.conditions.requireIdCard ? 'carte d\'identité sur soi, ' : ''}paiement immédiat.</p></div>
      <div class="card"><h2>Grades autorisés</h2><table class="tbl"><tr><th>Grade</th><th>Civil</th><th>Force de l'ordre</th></tr>${s.grades.map((gr) => `<tr><td>${esc(gr.name)}</td><td>${gr.civil ? '✓' : '—'}</td><td>${gr.fdo ? '✓' : '—'}</td></tr>`).join('')}</table>
        <p class="faint" style="font-size:.76rem;margin-top:.6rem">Réglé dans Permissions (« Délivrer un PPA civil » / « … force de l'ordre »).</p></div></div>
      <div class="card"><h2>Historique des délivrances</h2><div class="toolbar"><input class="input grow" id="ppq" placeholder="Rechercher : bénéficiaire, secouriste, numéro" value="${esc(PP.q)}">
        <select class="input" data-ppk><option value="">Toutes catégories</option><option value="civil" ${PP.kind === 'civil' ? 'selected' : ''}>Civil</option><option value="fdo" ${PP.kind === 'fdo' ? 'selected' : ''}>Force de l'ordre</option></select><button class="btn" data-pps="1">Rechercher</button></div>
        ${h.error ? empty(h.error) : (h.list.length ? `<table class="tbl"><tr><th>Opération</th><th>Bénéficiaire</th><th>Catégorie</th><th>Délivré par</th><th>Prix</th><th>Paiement</th><th>Remise</th><th>Date</th></tr>${h.list.map((x) => `<tr>
          <td class="mono" style="font-size:.78rem">${esc(x.uid)}${x.number ? `<br><b>${esc(x.number)}</b>` : ''}</td><td>${esc(x.name)}</td><td>${esc(PPAK[x.type] || x.type)}</td><td>${esc(x.ems_name || '')}<br><small class="faint">${esc(x.ems_grade || '')}</small></td>
          <td class="mono">${money(x.price)}</td><td>${esc(PST[x.payment_status] || x.payment_status)}</td><td>${esc(PST[x.delivery_status] || x.delivery_status)}${x.reason ? `<br><small class="faint">${esc(x.reason)}</small>` : ''}</td><td class="muted">${fmtTime(x.t)}</td></tr>`).join('')}</table>` : empty('Aucune délivrance.'))}</div>`;
  };

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
    if (t.dataset.rf === 'q') { RS.f.q = t.value; return go('reports'); }
    if (t.dataset.hq !== undefined) { HS.q = t.value; return go('history'); }
    if (t.id === 'ptq') { PT.q = t.value; return go('patients'); }
    if (t.id === 'iq') { IS.q = t.value; return go('invoices'); }
    if (t.id === 'ppq') { PP.q = t.value; return go('ppa'); }
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.rf && t.dataset.rf !== 'q') { RS.f[t.dataset.rf] = t.value; return go('reports'); }
    if (t.dataset.ef && t.dataset.ef !== 'q') { ES.f[t.dataset.ef] = t.value; return drawEmployees(); }
    if (t.dataset.if) { IS[t.dataset.if] = t.value; IS.q = ($('#iq') || {}).value || ''; return go('invoices'); }
    if (t.dataset.ppk !== undefined) { PP.kind = t.value; PP.q = ($('#ppq') || {}).value || ''; return go('ppa'); }
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
    if (e.target.dataset.ef === 'q') {
      ES.f.q = e.target.value;
      const pos = e.target.selectionStart;
      drawEmployees();
      const n = body().querySelector('[data-ef="q"]'); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
    }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) { const q = b.dataset.q; return q === 'newReport' ? newReport() : go(q); }
    if ((b = e.target.closest('[data-open-report]'))) return openReport(Number(b.dataset.openReport));
    if ((b = e.target.closest('[data-gps]'))) { const [x, y] = b.dataset.gps.split(',').map(Number); post('gps', { x, y }); return toast('Itinéraire tracé.'); }
    // Dispatch
    if ((b = e.target.closest('[data-call]'))) { DS.sel = Number(b.dataset.call); const r = await req('callInfo', { id: DS.sel }); DS.info = r.error ? null : r.call; return drawDispatch(); }
    if ((b = e.target.closest('[data-ca]'))) return dispatchAction(b.dataset.ca, b);
    // Patients
    if ((b = e.target.closest('[data-pcid]'))) { PT.cid = b.dataset.pcid; T.gen++; loading(); return patientView(T.gen); }
    if ((b = e.target.closest('[data-pt]'))) {
      const a = b.dataset.pt;
      if (a === 'search') { PT.q = ($('#ptq') || {}).value || ''; return go('patients'); }
      if (a === 'back') { PT.cid = null; return go('patients'); }
      if (a === 'report') return newReport({ cid: PT.p.cid });
      if (a === 'save') {
        if (!(await confirmBox('Enregistrer le dossier ?', `Dossier médical de <b>${esc(PT.p.name)}</b>.`, 'Enregistrer'))) return;
        const r = await call('patientSave', { cid: PT.p.cid, name: PT.p.name, blood: $('#pBlood').value, allergies: $('#pAll').value, notes: $('#pNotes').value }, b);
        if (r.ok) { T.gen++; return patientView(T.gen); }
      }
      return;
    }
    // Comptes rendus
    if ((b = e.target.closest('[data-r]'))) {
      const a = b.dataset.r;
      if (a === 'search') { const q = body().querySelector('[data-rf="q"]'); RS.f.q = q ? q.value : ''; return go('reports'); }
      if (a === 'new') return newReport();
      if (a === 'back') { RS.mode = 'list'; return go('reports'); }
      if (a === 'edit') { const r = RS.loaded; RS.draft = { id: r.id, title: r.title, status: r.status, patientCid: r.patient_cid, patientName: r.patient_name, callId: r.call_id,
        crew: [...r.crew], treatments: [...r.treatments], started: r.s, ended: r.e, transport: r.transport, outcome: r.outcome || '', notes: r.notes || '' }; RS.mode = 'edit'; return reportEdit(); }
      if (a === 'cancelEdit') { RS.mode = RS.draft && RS.draft.id ? 'view' : 'list'; return go('reports', true); }
      if (a === 'archive') {
        const arch = b.dataset.arch === 'true';
        if (arch && !(await confirmBox('Archiver ce compte rendu ?', 'Il ne pourra plus être modifié, sauf s\'il est désarchivé.', 'Archiver', true))) return;
        const r = await call('reportArchive', { id: RS.current, archive: arch }, b);
        if (r.ok) { T.gen++; return reportView(T.gen); }
        return;
      }
      if (a === 'save') {
        captureDraft();
        if (!(await confirmBox('Enregistrer le compte rendu ?', `« ${esc(RS.draft.title)} »`, 'Enregistrer'))) return;
        const r = await call('reportSave', RS.draft, b);
        if (r.ok) { RS.current = r.id; RS.mode = 'view'; T.gen++; return reportView(T.gen); }
      }
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
      if (!(await confirmBox('Quitter l\'EMS ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter l\'EMS', true))) return;
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
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre l'EMS au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Retirer de l\'EMS ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
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
        const data = { id: GS.edit ? GS.edit.id : undefined, name: $('#gName').value, level: Number($('#gLevel').value), isDefault: $('#gDefault').checked };
        if (!(await confirmBox(data.id ? 'Modifier le grade ?' : 'Créer le grade ?', `« <b>${esc(data.name)}</b> », niveau ${data.level || '?'}.`, 'Confirmer'))) return;
        const r = await call('gradeSave', data, b);
        if (r.ok) { GS.edit = null; return PAGES.grades(T.gen); }
        return;
      }
      if (a === 'del') {
        const gr = GS.data.list.find((x) => String(x.id) === b.dataset.id);
        const others = GS.data.list.filter((x) => x.id !== gr.id && x.level < GS.data.myLevel);
        const extra = gr.members > 0 ? `<label class="field" style="margin-top:.7rem"><span>Réaffecter les ${gr.members} employé(s) au grade</span><select class="input" data-cfv="reassign">${others.map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join('')}</select></label>` : '';
        const v = await confirmBox('Supprimer le grade ?', `« <b>${esc(gr.name)}</b> » sera supprimé.${gr.members ? ' Ses employés sont d\'abord réaffectés.' : ''}`, 'Supprimer', true, extra);
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
    // Garage
    if ((b = e.target.closest('[data-gp]'))) {
      const k = b.dataset.gp;
      if (!(await confirmBox('Placer le point ici ?', 'Le point sera enregistré à votre position actuelle.', 'Placer'))) return;
      const r = await call('garagePoint', { kind: k }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-gpr]'))) {
      if (!(await confirmBox('Retirer ce point ?', 'Il ne sera plus utilisable tant qu\'il n\'est pas replacé.', 'Retirer', true))) return;
      const r = await call('garagePoint', { kind: b.dataset.gpr, remove: true }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-rpa]'))) {
      const label = ($('#rpLabel') || {}).value || '';
      if (!(await confirmBox('Placer un poste des dossiers ici ?', 'Le poste sera enregistré à votre position actuelle.', 'Placer'))) return;
      const r = await call('recordsPointAdd', { label }, b);
      if (r.ok) return PAGES.garage(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-rpr]'))) {
      if (!(await confirmBox('Retirer ce poste ?', 'Les dossiers ne seront plus consultables à cet endroit.', 'Retirer', true))) return;
      const r = await call('recordsPointRemove', { id: Number(b.dataset.rpr) }, b);
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
    // Factures
    if ((b = e.target.closest('[data-is]'))) { IS.q = ($('#iq') || {}).value || ''; return go('invoices'); }
    if ((b = e.target.closest('[data-refund]'))) {
      const inv = IS.list.find((x) => x.uid === b.dataset.refund);
      const paid = inv.status === 'paid';
      const v = await confirmBox(paid ? 'Rembourser la facture ?' : 'Annuler la facture ?', paid ? `<b>${money(inv.amount)}</b> seront repris du compte de l'entreprise et rendus à ${esc(inv.patient_name)}.` : 'Aucun argent n\'avait été pris : la facture sera marquée annulée.',
        paid ? 'Rembourser' : 'Annuler la facture', true, '<label class="field" style="margin-top:.6rem"><span>Motif (obligatoire)</span><input class="input" data-cfv="reason" maxlength="160"></label>');
      if (!v) return;
      const r = await call('invoiceRefund', { uid: inv.uid, reason: v.reason }, b);
      if (r.ok) return go('invoices');
      return;
    }
    // Tarifs
    if ((b = e.target.closest('[data-bsave]'))) {
      const mode = (body().querySelector('input[name="bmode"]:checked') || {}).value;
      const services = {};
      body().querySelectorAll('[data-sp]').forEach((i) => { services[i.dataset.sp] = { price: Number(i.value), enabled: body().querySelector(`[data-se="${i.dataset.sp}"]`).checked }; });
      if (!(await confirmBox('Enregistrer les tarifs ?', `Mode : <b>${esc(MODES[mode] || mode)}</b>. Appliqués aux prochaines factures seulement.`, 'Enregistrer'))) return;
      const r = await call('billingSave', { mode, flat: Number($('#bFlat').value), services }, b);
      if (r.ok) return go('billing');
      return;
    }
    // PPA
    if ((b = e.target.closest('[data-ppsave]'))) {
      const data = {};
      body().querySelectorAll('[data-ppp]').forEach((i) => { data[i.dataset.ppp] = { price: Number(i.value), enabled: body().querySelector(`[data-ppe="${i.dataset.ppp}"]`).checked }; });
      if (!(await confirmBox('Enregistrer les réglages PPA ?', `Civil : <b>${money(data.civil.price)}</b>${data.civil.enabled ? '' : ' (désactivé)'} · Force de l'ordre : <b>${money(data.fdo.price)}</b>${data.fdo.enabled ? '' : ' (désactivé)'}.<br>Prochaines délivrances seulement.`, 'Enregistrer'))) return;
      const r = await call('ppaSave', data, b);
      if (r.ok) return go('ppa');
      return;
    }
    if ((b = e.target.closest('[data-pps]'))) { PP.q = ($('#ppq') || {}).value || ''; return go('ppa'); }
    if ((b = e.target.closest('[data-ts]'))) { TS.q = ($('#tq') || {}).value || ''; return go('transactions'); }
  });

  setInterval(() => { const d = new Date(); $('#tabClock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

  /* ------------------------------------------------------------------ */
  function applyOpts(o) {
    if (!o) return false;
    if (o.kiosk) { PT.q = ''; PT.cid = null; PT.src = null; go('patients'); return true; }
    if (o.page === 'reportNew') { newReport(o.callId ? { callId: o.callId } : { src: o.src }); return true; }
    if (o.page) { go(o.page); return true; }
    return false;
  }
  window.Tablet = {
    open(st, opts) {
      T.open = true;
      T.st = st || APP.st || T.st;
      T.perms = (T.st && T.st.perms) || {};
      T.kiosk = !!(opts && opts.kiosk);
      T.kioskLabel = (opts && opts.label) || '';
      if (!T.kiosk && T.page === 'patients') T.page = 'dashboard';
      $('#tablet').classList.remove('hidden');
      if (!applyOpts(opts)) go(T.page || 'dashboard', T.page === 'reports');
    },
    goTo(opts) { applyOpts(opts); },
    hide() { T.open = false; T.kiosk = false; PT.cid = null; PT.p = null; stopTimers(); $('#tablet').classList.add('hidden'); if (T.page === 'patients') T.page = 'dashboard'; },
    isOpen: () => T.open,
    back() {
      if (T.page === 'reports' && RS.mode !== 'list') { RS.mode = 'list'; go('reports'); return true; }
      if (T.page === 'patients' && PT.cid) { PT.cid = null; go('patients'); return true; }
      if (T.page === 'lab' && (LS.id || LS.cid)) { if (LS.id) LS.id = null; else LS.cid = null; go('lab', true); return true; }
      if (T.page === 'employees' && ES.cid) { ES.cid = null; ES.emp = null; drawEmployees(); return true; }
      if (T.page === 'grades' && GS.edit) { GS.edit = null; drawGrades(); return true; }
      if (T.page === 'dispatch' && DS.sel) { DS.sel = null; DS.info = null; drawDispatch(); return true; }
      return false;
    },
    onState(st) {
      T.st = st;
      T.perms = (st && st.perms) || {};
      if (!T.open) return;
      if (!st) return post('close', { ui: 'tablet' });
      renderNav();
      const nav = NAV.find((n) => n.id === T.page);
      if (!nav || !allowed(nav)) go(T.kiosk ? 'patients' : 'dashboard');
    },
  };
})();
