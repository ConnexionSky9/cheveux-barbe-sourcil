/* =====================================================================
   ELYZEA POLICE - tablette
   Tableau de bord · Rapports · Carte · Agents · Direction (Recrutement, Employés,
   Grades, Permissions, Historique). Chaque bouton appelle le serveur, qui vérifie les droits.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const statusOf = (id) => APP.statuses.find((s) => s.id === id) || { label: id || '—', color: '#94a3b8' };
  const LIFE = { ok: ['En vie', 'on'], hurt: ['Blessé', 'warn'], down: ['À terre', 'warn'], dead: ['Mort', 'bad'] };
  const lifePill = (h) => { const l = LIFE[(h && h.life) || 'ok'] || LIFE.ok; return `<span class="pill ${l[1]}">${l[0]}</span>`; };
  const bars = (h) => (h ? `<div class="hbars" title="Vie ${h.hp} % · Armure ${h.armor} %"><div class="hbar"><i style="width:${h.hp}%;background:${h.hp > 50 ? 'var(--green)' : h.hp > 25 ? 'var(--orange)' : 'var(--red)'}"></i></div>
    <div class="hbar"><i style="width:${h.armor}%;background:#60a5fa"></i></div></div>` : '');
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const initials = (n) => String(n || '?').split(' ').map((p) => p[0] || '').join('').slice(0, 2).toUpperCase();
  const lvlColor = (l) => (APP.levels[l] || {}).color || '#3b82f6';
  const lvlLabel = (l) => (APP.levels[l] || {}).label || l;
  const STATUS_R = { open: 'En cours', done: 'Terminé', archived: 'Archivé' };

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: 'tablet' },
    { id: 'reports', label: 'Rapports', ico: '📄', perm: 'reports_view' },
    { id: 'map', label: 'Carte', ico: '🗺️', perm: 'map' },
    { id: 'agents', label: 'Agents', ico: '👮', perm: 'agents_view' },
    { id: 'recruit', label: 'Recrutement', ico: '➕', perm: 'recruit', group: 'Direction' },
    { id: 'employees', label: 'Employés', ico: '👥', perm: 'employees_view', group: 'Direction' },
    { id: 'grades', label: 'Grades', ico: '🎖️', perm: 'direction', group: 'Direction' },
    { id: 'perms', label: 'Permissions', ico: '🔐', perm: 'perms_manage', group: 'Direction' },
    { id: 'history', label: 'Historique', ico: '🕘', perm: 'history_view', group: 'Direction' },
  ];
  const allowed = (n) => can(n.perm) && (!n.group || can('direction'));

  function renderNav() {
    let last = null, html = `<div class="brand"><div class="shield">${esc((APP.cfg && APP.cfg.job) || 'LSPD').slice(0, 4)}</div><div><b>${esc((APP.cfg && APP.cfg.job) || 'Police')}</b><small>Tablette opérationnelle</small></div></div>`;
    NAV.filter(allowed).forEach((n) => {
      if (n.group && n.group !== last) html += `<div class="nav-group">${n.group}</div>`;
      last = n.group;
      html += `<button class="nav-btn ${T.page === n.id ? 'active' : ''}" data-nav="${n.id}"><span class="ico">${n.ico}</span>${n.label}</button>`;
    });
    const st = T.st || {};
    html += `<div class="nav-me"><b>${esc(st.grade || '')}</b><span class="mono">${esc(st.matricule || '')}</span></div>`;
    $('#tabNav').innerHTML = html;
    const duty = !!st.duty;
    const pill = $('#tabDuty');
    pill.className = `pill ${duty ? 'on' : 'off'}`;
    pill.textContent = duty ? `En service · ${statusOf(st.status).label}` : 'Hors service';
  }

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || ((APP.cfg && APP.cfg.job) || 'LSPD'); }
  function loading() { body().insertAdjacentHTML('afterbegin', '<div class="loading-bar"></div>'); }
  function stopTimers() { clearInterval(T.timer); T.timer = null; if (T.map) { T.map.destroy(); T.map = null; } }
  function every(ms, fn) { clearInterval(T.timer); T.timer = setInterval(fn, ms); }
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
    if (!keepSub) { RS.mode = 'list'; ES.cid = null; }
    renderNav();
    setTitle(NAV.find((n) => n.id === page).label, NAV.find((n) => n.id === page).group);
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
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    const agentsHtml = d.agents.length ? d.agents.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
        <div class="main"><b>${esc(a.name)}</b><small><span class="mono">${esc(a.matricule)}</span> · ${esc(a.grade)}</small></div>${statusPill(a.status)}</div>`).join('')
      : `<div class="empty">${can('agents_view') ? 'Aucun agent en service.' : 'Liste réservée aux grades autorisés.'}</div>`;
    const aa = d.agentAlerts.map((a) => `<div class="alert-row" style="--c:${lvlColor(a.level)}"><div class="t"><span>Alerte ${esc(lvlLabel(a.level).toLowerCase())} · ${esc(a.author)}</span><span class="faint">${ago(a.t)}</span></div>
        <div class="m">${esc(a.street || '')}</div></div>`).join('');
    const ga = d.interventions.map((i) => `<div class="alert-row" style="--c:var(--orange)"><div class="t"><span>${esc(i.title || i.label)}${i.count > 1 ? ` ×${i.count}` : ''}</span><span class="faint">${ago(i.t)}</span></div>
        <div class="m">${esc(i.street || '')} · ${i.takers.length ? `pris en charge par ${esc(i.takers.join(', '))}` : 'personne sur place'}</div></div>`).join('');
    const recent = d.recent.length ? `<table class="tbl"><tr><th>Alerte</th><th>Lieu</th><th>Statut</th><th>Heure</th></tr>${d.recent.map((r) => `<tr>
        <td>${r.kind === 'agent' ? `<span style="color:${lvlColor(r.type)}">●</span> ` : ''}${esc(r.title || r.type)}${r.author_name ? `<br><small class="muted">${esc(r.author_name)}</small>` : ''}</td>
        <td class="muted">${esc(r.street || '—')}</td><td>${r.status === 'active' ? '<span class="pill warn">Active</span>' : '<span class="pill off">Clôturée</span>'}</td><td class="muted">${fmtTime(r.t)}</td></tr>`).join('')}</table>`
      : '<div class="empty">Aucune alerte récente.</div>';
    body().innerHTML = `
      <div class="stats">
        <div class="stat blue"><b>${d.dutyCount}</b><span>Agents en service</span></div>
        <div class="stat red"><b>${d.agentAlerts.length}</b><span>Alertes agent actives</span></div>
        <div class="stat orange"><b>${d.interventions.length}</b><span>Interventions en cours</span></div>
        <div class="stat"><b>${d.employees}</b><span>Effectif total</span></div>
      </div>
      <div class="cols">
        <div>
          <div class="card"><h2>Agents en service <span class="faint" style="font-size:.8rem">${d.agents.length}</span></h2>${agentsHtml}</div>
          <div class="card"><h2>Dernières alertes</h2>${recent}</div>
        </div>
        <div>
          <div class="card"><h2>Moi</h2><div class="kv"><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
            <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b></div>
            <div class="actions-row">${can('reports_write') ? '<button class="btn primary small" data-q="newReport">+ Nouveau rapport</button>' : ''}
              ${can('map') ? '<button class="btn small" data-q="map">🗺️ Carte</button>' : ''}${can('reports_view') ? '<button class="btn small" data-q="reports">📄 Rapports</button>' : ''}</div></div>
          <div class="card"><h2>Alertes agent</h2>${aa || '<div class="empty">Aucune alerte agent active.</div>'}</div>
          <div class="card"><h2>Interventions en cours</h2>${ga || '<div class="empty">Aucune intervention en cours.</div>'}</div>
          ${d.reports ? `<div class="card"><h2>Derniers rapports</h2>${d.reports.length ? d.reports.map((r) => `<div class="list-row click" data-open-report="${r.id}"><div class="main"><b>${esc(r.title)}</b>
            <small>${esc(r.type)} · ${esc(r.author_name)} · ${fmtTime(r.t)}</small></div><span class="status-${r.status}" style="font-size:.78rem">${STATUS_R[r.status]}</span></div>`).join('') : '<div class="empty">Aucun rapport.</div>'}</div>` : ''}
        </div>
      </div>`;
    every(6000, async () => { if (T.page === 'dashboard' && T.open && !document.activeElement.closest('#tabBody input')) await PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Rapports                                                            */
  /* ------------------------------------------------------------------ */
  const RS = { mode: 'list', f: { q: '', type: '', status: 'active', from: '', to: '' }, current: null, draft: null };
  const typeOptions = (sel) => ((APP.cfg && APP.cfg.reportTypes) || []).map((t) => `<option ${t === sel ? 'selected' : ''}>${esc(t)}</option>`).join('');

  PAGES.reports = async (g) => {
    if (RS.mode === 'view') return reportView(g);
    if (RS.mode === 'edit') return reportEdit();
    const f = RS.f;
    const d = await req('reportsList', { q: f.q, type: f.type, status: f.status === 'active' ? undefined : f.status, from: f.from, to: f.to });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    body().innerHTML = `
      <div class="toolbar">
        <input class="input grow" data-rf="q" placeholder="Rechercher : titre, personne, agent, matricule, lieu…" value="${esc(f.q)}">
        <select class="input" data-rf="type"><option value="">Tous les types</option>${typeOptions(f.type)}</select>
        <select class="input" data-rf="status">${[['active', 'Non archivés'], ['open', 'En cours'], ['done', 'Terminés'], ['archived', 'Archivés'], ['all', 'Tous']].map(([v, l]) => `<option value="${v}" ${f.status === v ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <input class="input" type="date" data-rf="from" value="${esc(f.from)}" title="Du">
        <input class="input" type="date" data-rf="to" value="${esc(f.to)}" title="Au">
        <button class="btn" data-r="search">Rechercher</button>
        ${can('reports_write') ? '<button class="btn primary" data-r="new">+ Nouveau rapport</button>' : ''}
      </div>
      ${d.list.length ? `<div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>#</th><th>Titre</th><th>Type</th><th>Personnes concernées</th><th>Rédacteur</th><th>Date</th><th>Statut</th></tr>
        ${d.list.map((r) => `<tr class="click" data-open-report="${r.id}"><td class="mono faint">${r.id}</td><td><b>${esc(r.title)}</b>${r.location ? `<br><small class="muted">${esc(r.location)}</small>` : ''}</td>
          <td><span class="tag">${esc(r.type)}</span></td><td class="muted">${esc((r.people || []).join(', ') || '—')}</td>
          <td>${esc(r.author_name)}<br><small class="mono faint">${esc(r.author_matricule || '')}</small></td><td class="muted">${fmtTime(r.t)}</td>
          <td class="status-${r.status}">${STATUS_R[r.status]}</td></tr>`).join('')}</table></div>`
        : '<div class="empty">Aucun rapport ne correspond.</div>'}`;
  };

  async function reportView(g) {
    const d = await req('reportGet', { id: RS.current });
    if (stale(g)) return;
    if (d.error) { toast(d.error, false); RS.mode = 'list'; return PAGES.reports(g); }
    const r = d.report;
    RS.loaded = r;
    setTitle(`Rapport #${r.id}`, 'Rapports');
    body().innerHTML = `
      <div class="toolbar"><button class="btn" data-r="back">‹ Retour aux rapports</button><span style="flex:1"></span>
        ${r.canEdit && r.status !== 'archived' ? '<button class="btn" data-r="edit">✎ Modifier</button>' : ''}
        ${r.canArchive ? `<button class="btn ${r.status === 'archived' ? '' : 'danger'}" data-r="archive" data-arch="${r.status !== 'archived'}">${r.status === 'archived' ? 'Désarchiver' : 'Archiver'}</button>` : ''}</div>
      <div class="split">
        <div>
          <div class="card"><div class="eyebrow">${esc(r.type)} · <span class="status-${r.status}">${STATUS_R[r.status]}</span></div><h2 style="font-size:1.25rem;margin:.3rem 0 .9rem">${esc(r.title)}</h2>
            <div class="kv" style="margin-bottom:1rem"><span>Lieu des faits</span><b>${esc(r.location || '—')}</b><span>Personnes concernées</span><div class="chips">${(r.people || []).map((p) => `<span class="chip">${esc(p)}</span>`).join('') || '—'}</div></div>
            <h3 class="muted" style="font-size:.8rem;margin-bottom:.4rem">DESCRIPTION DES FAITS</h3><div class="report-body">${esc(r.description || '')}</div>
            ${r.observations ? `<h3 class="muted" style="font-size:.8rem;margin:1rem 0 .4rem">OBSERVATIONS</h3><div class="report-body">${esc(r.observations)}</div>` : ''}
          </div>
          ${(r.attachments || []).length ? `<div class="card"><h2>Pièces jointes</h2><div class="attach">${r.attachments.map((u) => `<a title="${esc(u)}"><img src="${esc(u)}" alt="" onerror="this.parentNode.innerHTML='<div class=&quot;empty&quot; style=&quot;padding:.5rem;font-size:.7rem&quot;>Lien</div>'"></a>`).join('')}</div>
            <div style="margin-top:.5rem;font-size:.75rem" class="muted">${r.attachments.map((u) => esc(u)).join('<br>')}</div></div>` : ''}
        </div>
        <div class="detail"><div class="card"><h2>Informations</h2><div class="kv"><span>Rédacteur</span><b>${esc(r.author_name)}</b><span>Matricule</span><b class="mono">${esc(r.author_matricule || '—')}</b>
          <span>Créé le</span><b>${fmtTime(r.t)}</b><span>Modifié le</span><b>${fmtTime(r.u)}</b></div></div>
          <div class="card"><h2>Historique</h2><div class="timeline">${(r.history || []).map((h) => `<div>${esc(h.action)}<small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}</small></div>`).join('') || '<span class="faint">—</span>'}</div></div></div>
      </div>`;
  }

  function reportEdit() {
    const r = RS.draft;
    setTitle(r.id ? `Modifier le rapport #${r.id}` : 'Nouveau rapport', 'Rapports');
    const maxA = (APP.cfg && APP.cfg.maxAttachments) || 6;
    body().innerHTML = `
      <div class="toolbar"><button class="btn" data-r="cancelEdit">‹ Annuler</button><span style="flex:1"></span><button class="btn primary" data-r="save">Enregistrer le rapport</button></div>
      <div class="card"><div class="form-grid">
        <label class="field full"><span>Titre</span><input class="input" data-d="title" maxlength="120" value="${esc(r.title)}" placeholder="ex : Interpellation après un vol à l'arraché"></label>
        <label class="field"><span>Type de rapport</span><select class="input" data-d="type"><option value="">Choisir…</option>${typeOptions(r.type)}</select></label>
        <label class="field"><span>Statut</span><select class="input" data-d="status"><option value="open" ${r.status !== 'done' ? 'selected' : ''}>En cours</option><option value="done" ${r.status === 'done' ? 'selected' : ''}>Terminé</option></select></label>
        <div class="field full"><span>Lieu des faits</span><div style="display:flex;gap:.5rem"><input class="input" data-d="location" maxlength="120" value="${esc(r.location)}" placeholder="Rue, quartier…"><button class="btn" data-r="here">📍 Ma position</button></div></div>
        <div class="field full"><span>Personnes concernées</span><div class="chips" style="margin-bottom:.4rem">${r.people.map((p, i) => `<span class="chip">${esc(p)}<button data-rmp="${i}" aria-label="Retirer">✕</button></span>`).join('')}</div>
          <div style="display:flex;gap:.5rem"><input class="input" id="rPerson" maxlength="60" placeholder="Nom Prénom, puis Entrée"><button class="btn" data-r="addPerson">Ajouter</button></div></div>
        <label class="field full"><span>Description détaillée des faits</span><textarea class="input" data-d="description" maxlength="6000" style="min-height:9rem">${esc(r.description)}</textarea></label>
        <label class="field full"><span>Observations complémentaires</span><textarea class="input" data-d="observations" maxlength="3000">${esc(r.observations)}</textarea></label>
        <div class="field full"><span>Preuves / pièces jointes (liens d'images, ${maxA} maximum)</span>
          <div class="attach" style="margin-bottom:.4rem">${r.attachments.map((u, i) => `<a title="${esc(u)}" style="position:relative"><img src="${esc(u)}" alt=""><button class="icon-btn" style="position:absolute;top:.2rem;right:.2rem;width:1.5rem;height:1.5rem" data-rma="${i}">✕</button></a>`).join('')}</div>
          <div style="display:flex;gap:.5rem"><input class="input" id="rAttach" placeholder="https://…" ${r.attachments.length >= maxA ? 'disabled' : ''}><button class="btn" data-r="addAttach" ${r.attachments.length >= maxA ? 'disabled' : ''}>Ajouter</button></div></div>
      </div></div>`;
  }
  function captureDraft() {
    document.querySelectorAll('[data-d]').forEach((i) => { RS.draft[i.dataset.d] = i.value; });
  }
  async function openReport(id) { if (T.page !== 'reports') { RS.mode = 'view'; RS.current = id; return go('reports', true); } RS.mode = 'view'; RS.current = id; T.gen++; loading(); await reportView(T.gen); }
  function newReport() {
    RS.draft = { id: null, title: '', type: '', status: 'open', location: '', people: [], description: '', observations: '', attachments: [] };
    RS.mode = 'edit';
    if (T.page !== 'reports') return go('reports', true);
    reportEdit();
  }

  /* ------------------------------------------------------------------ */
  /* Carte                                                               */
  /* ------------------------------------------------------------------ */
  const MS = { sel: null };
  PAGES.map = async (g) => {
    body().innerHTML = `<div class="map-wrap">
      <div class="map-box" id="mapBox"><div class="map-tools"><button class="icon-btn" data-m="in" title="Zoomer">+</button><button class="icon-btn" data-m="out" title="Dézoomer">−</button><button class="icon-btn" data-m="fit" title="Tout voir">⤢</button></div>
        <div class="map-legend"><span><i style="background:#3b82f6"></i>Agent</span><span><i style="background:#f59e0b"></i>À terre</span><span><i style="background:#7f1d1d"></i>Mort</span>${['low', 'medium', 'high'].map((k) => `<span><i style="background:${lvlColor(k)}"></i>Alerte ${esc(lvlLabel(k).toLowerCase())}</span>`).join('')}<span><i style="background:#f59e0b;border-radius:2px"></i>Intervention</span></div></div>
      <div class="map-side"><div class="card" id="mapSel"><h2>Sélection</h2><div class="faint" style="font-size:.85rem">Cliquez sur un agent, une alerte ou une intervention.</div></div>
        <div class="card" id="mapAgents"><h2>Agents</h2></div><div class="card" id="mapAlerts"><h2>Alertes</h2></div></div></div>`;
    T.map = PoliceMap.create($('#mapBox'), { image: APP.cfg && APP.cfg.map && APP.cfg.map.file ? APP.cfg.map : null, levels: APP.levels,
      statusColor: (s) => statusOf(s).color, onSelect: (s) => { MS.sel = s; renderSel(); } });
    const refresh = async () => {
      const d = await req('map');
      if (stale(g) || T.page !== 'map') return;
      if (d.error) { toast(d.error, false); return; }
      MS.data = d;
      T.map.setData(d.agents, d.agentAlerts, d.interventions);
      const off = d.offDuty || [];
      $('#mapAgents').innerHTML = `<h2>Agents en service <span class="faint" style="font-size:.8rem">${d.agents.length}</span></h2>` + (d.agents.length ? d.agents.map((a) => `<div class="list-row click agent-row" data-focus="agent:${a.id}">
        <span style="width:.6rem;height:.6rem;border-radius:50%;flex:none;background:${statusOf(a.status).color}" title="${esc(statusOf(a.status).label)}"></span><div class="main"><b>${esc(a.name)}</b><small><span class="mono">${esc(a.matricule)}</span> · ${esc(a.grade)} · ${esc(statusOf(a.status).label)}</small>
        ${a.street ? `<small class="faint">📍 ${esc(a.street)}</small>` : ''}${bars(a.health)}</div>${lifePill(a.health)}</div>`).join('') : '<div class="empty">Aucun agent en service.</div>')
        + (off.length ? `<h2 style="margin-top:.9rem">Hors service <span class="faint" style="font-size:.8rem">${off.length}</span></h2>` + off.map((a) => `<div class="list-row" style="opacity:.55">
        <span style="width:.6rem;height:.6rem;border-radius:50%;flex:none;background:#64748b"></span><div class="main"><b>${esc(a.name)}</b><small><span class="mono">${esc(a.matricule)}</span> · ${esc(a.grade)}</small></div><span class="pill off">Hors service</span></div>`).join('') : '');
      $('#mapAlerts').innerHTML = '<h2>Alertes</h2>' + ([...d.agentAlerts.map((a) => `<div class="alert-row click" style="--c:${lvlColor(a.level)};cursor:pointer" data-focus="alert:${a.id}"><div class="t"><span>Alerte ${esc(lvlLabel(a.level).toLowerCase())} · ${esc(a.author)}</span><span class="faint">${ago(a.t)}</span></div><div class="m">${esc(a.street || '')}</div></div>`),
        ...d.interventions.map((i) => `<div class="alert-row" style="--c:var(--orange);cursor:pointer" data-focus="inter:${i.id}"><div class="t"><span>${esc(i.title || i.label)}</span><span class="faint">${ago(i.t)}</span></div><div class="m">${esc(i.street || '')}</div></div>`)].join('') || '<div class="empty">Aucune alerte active.</div>');
      renderSel();
    };
    await refresh();
    every((APP.cfg && APP.cfg.mapRefresh) || 3000, refresh);
  };
  function renderSel() {
    const el = $('#mapSel');
    if (!el) return;
    const s = MS.sel;
    if (!s) { el.innerHTML = '<h2>Sélection</h2><div class="faint" style="font-size:.85rem">Cliquez sur un agent, une alerte ou une intervention.</div>'; return; }
    const o = s.data;
    if (s.kind === 'agent') {
      const h = o.health || { hp: 0, armor: 0, life: 'ok' };
      el.innerHTML = `<h2>Agent</h2><div class="kv"><span>Nom</span><b>${esc(o.name)}</b><span>Matricule</span><b class="mono">${esc(o.matricule)}</b><span>Grade</span><b>${esc(o.grade)}</b>
        <span>Service</span><b><span class="pill on">En service</span></b><span>Statut</span><b>${statusPill(o.status)}</b><span>État</span><b>${lifePill(h)}</b>
        <span>Vie</span><b>${h.hp} %</b><span>Armure</span><b>${h.armor} %</b><span>Position</span><b>${esc(o.street || '—')}</b></div>${bars(h)}`;
    }
    else if (s.kind === 'alert') el.innerHTML = `<h2>Alerte agent</h2><div class="kv"><span>Niveau</span><b style="color:${lvlColor(o.level)}">${esc(lvlLabel(o.level))}</b><span>Auteur</span><b>${esc(o.author)}</b><span>Matricule</span><b class="mono">${esc(o.matricule || '')}</b><span>Lieu</span><b>${esc(o.street || '—')}</b><span>Heure</span><b>${fmtTime(o.t)}</b></div>`;
    else el.innerHTML = `<h2>Intervention</h2><div class="kv"><span>Type</span><b>${esc(o.label)}</b><span>Titre</span><b>${esc(o.title || '')}</b><span>Lieu</span><b>${esc(o.street || '—')}</b><span>Heure</span><b>${fmtTime(o.t)}</b><span>Sur place</span><b>${esc((o.takers || []).join(', ') || 'Personne')}</b></div>${o.description ? `<p class="muted" style="font-size:.82rem;margin-top:.6rem">${esc(o.description)}</p>` : ''}`;
  }

  /* ------------------------------------------------------------------ */
  /* Agents                                                              */
  /* ------------------------------------------------------------------ */
  PAGES.agents = async (g) => {
    const d = await req('agents');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    const st = T.st || {};
    body().innerHTML = `<div class="cols">
      <div class="card"><h2>Agents en service <span class="faint" style="font-size:.8rem">${d.list.length}</span></h2>${d.list.length ? `<table class="tbl"><tr><th>Agent</th><th>Matricule</th><th>Grade</th><th>Statut</th><th>État</th></tr>
        ${d.list.map((a) => `<tr><td><b>${esc(a.name)}</b>${a.street ? `<br><small class="faint">📍 ${esc(a.street)}</small>` : ''}</td><td class="mono">${esc(a.matricule)}</td><td>${esc(a.grade)}</td><td>${statusPill(a.status)}</td><td>${lifePill(a.health)}${bars(a.health)}</td></tr>`).join('')}</table>` : '<div class="empty">Aucun agent en service.</div>'}</div>
      <div><div class="card"><h2>Ma fiche</h2><div class="kv"><span>Grade</span><b>${esc(st.grade || '')}</b><span>Matricule</span><b class="mono">${esc(st.matricule || '')}</b><span>Service</span><b>${st.duty ? statusPill(st.status) : '<span class="pill off">Hors service</span>'}</b></div>
        <div class="actions-row"><button class="btn danger small" data-resign="1">Quitter la police</button></div></div></div></div>`;
    every(6000, () => { if (T.page === 'agents') PAGES.agents(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Recrutement                                                         */
  /* ------------------------------------------------------------------ */
  const RC = { preview: null };
  PAGES.recruit = async () => {
    const p = RC.preview;
    body().innerHTML = `<div class="note">La demande est envoyée à la <b>personne la plus proche</b> de vous. Vérifiez son identité avant l'envoi : elle reçoit une proposition
      avec « Accepter » et « Refuser » (30 secondes). Vous ne pouvez recruter qu'à un grade inférieur au vôtre.</div>
      <div class="card" style="max-width:40rem"><h2>Recruter</h2>
        <button class="btn primary" data-rc="find">🔎 Rechercher la personne la plus proche</button>
        ${p ? `<div style="margin-top:1rem" class="card"><div class="list-row"><span class="avatar">${initials(p.target.name)}</span><div class="main"><b>${esc(p.target.name)}</b><small>À ${p.target.distance} m · métier actuel : ${esc(p.target.job)}</small></div></div>
          ${p.target.already ? '<p class="err" style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne fait déjà partie de la police.</p>' : ''}
          ${p.target.pending ? '<p style="color:#fcd34d;font-size:.84rem;margin-top:.6rem">Une demande est déjà en attente pour cette personne.</p>' : ''}
          <div class="form-grid" style="margin-top:.8rem"><label class="field"><span>Grade de départ</span><select class="input" id="rcGrade">${p.grades.map((gr) => `<option value="${gr.id}" ${gr.id === p.defaultGrade ? 'selected' : ''}>${esc(gr.name)} (niveau ${gr.level})</option>`).join('')}</select></label></div>
          <div class="actions-row"><button class="btn primary" data-rc="send" ${p.target.already || p.target.pending || !p.grades.length ? 'disabled' : ''}>Envoyer la demande</button><button class="btn" data-rc="clear">Annuler</button></div></div>` : ''}
      </div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Employés                                                            */
  /* ------------------------------------------------------------------ */
  const ES = { cid: null, f: { q: '', grade: '', state: '' }, data: null, emp: null };
  PAGES.employees = async (g) => {
    const d = await req('employees');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    ES.data = d;
    drawEmployees();
    if (ES.cid) await loadEmployee(ES.cid);
  };
  function drawEmployees() {
    const d = ES.data, f = ES.f;
    const q = f.q.trim().toLowerCase();
    const list = d.list.filter((e) => (!q || e.name.toLowerCase().includes(q) || e.matricule.toLowerCase().includes(q))
      && (!f.grade || String(e.gradeId) === f.grade)
      && (!f.state || (f.state === 'duty' ? e.duty : f.state === 'online' ? e.online : !e.online)));
    const rows = list.map((e) => `<tr class="click ${ES.cid === e.cid ? 'sel' : ''}" data-emp="${esc(e.cid)}"><td><b>${esc(e.name)}</b></td><td class="mono">${esc(e.matricule)}</td><td>${esc(e.grade)}</td>
      <td>${e.duty ? '<span class="pill on">En service</span>' : e.online ? '<span class="pill plain">Connecté</span>' : '<span class="pill off">Hors ligne</span>'}</td><td class="muted">${esc(e.recruited || '—')}</td><td class="muted">${esc(e.promoted || '—')}</td></tr>`).join('');
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-ef="q" placeholder="Rechercher : nom ou matricule" value="${esc(f.q)}">
        <select class="input" data-ef="grade"><option value="">Tous les grades</option>${d.grades.map((gr) => `<option value="${gr.id}" ${String(gr.id) === f.grade ? 'selected' : ''}>${esc(gr.name)}</option>`).join('')}</select>
        <select class="input" data-ef="state">${[['', 'Tous'], ['duty', 'En service'], ['online', 'Connectés'], ['offline', 'Hors ligne']].map(([v, l]) => `<option value="${v}" ${f.state === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
      <div class="split"><div class="card" style="padding:.3rem .6rem">${list.length ? `<table class="tbl"><tr><th>Nom</th><th>Matricule</th><th>Grade</th><th>Statut</th><th>Recrutement</th><th>Promotion</th></tr>${rows}</table>` : '<div class="empty" style="margin:.6rem 0">Aucun employé ne correspond.</div>'}</div>
        <div class="detail" id="empDetail"><div class="card"><h2>Fiche</h2><div class="faint" style="font-size:.85rem">Sélectionnez un employé pour voir sa fiche et les actions possibles.</div></div></div></div>`;
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
    const up = gs.filter((g) => g.level > e.level && g.level < my).sort((a, b) => a.level - b.level)[0];
    const down = gs.filter((g) => g.level < e.level).sort((a, b) => b.level - a.level)[0];
    const choices = gs.filter((g) => g.level < my && g.id !== e.gradeId);
    return { up, down, choices };
  }
  function drawEmployee() {
    const e = ES.emp, el = $('#empDetail');
    if (!e || !el) return;
    const s = gradeSteps(e);
    const act = e.canAct;
    el.innerHTML = `<div class="card"><div class="list-row" style="padding:0 0 .8rem"><span class="avatar">${initials(e.name)}</span><div class="main"><b>${esc(e.name)}</b><small class="mono">${esc(e.matricule)}</small></div>
        ${e.duty ? '<span class="pill on">En service</span>' : e.online ? '<span class="pill plain">Connecté</span>' : '<span class="pill off">Hors ligne</span>'}</div>
      <div class="kv"><span>Grade</span><b>${esc(e.grade)} <span class="faint">(niv. ${e.level})</span></b><span>Recrutement</span><b>${esc(e.recruited || '—')}</b><span>Dernière promotion</span><b>${esc(e.promoted || '—')}</b>
        <span>Amendes données</span><b>${e.fines}</b><span>Rapports rédigés</span><b>${e.reports}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${act ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'} title="${s.up ? esc(s.up.name) : 'Aucun grade supérieur possible'}">▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de la police</button>' : ''}</div>`
        : `<p class="faint" style="font-size:.8rem;margin-top:.8rem">${e.cid === ES.data.myCid ? 'C\'est votre fiche : vous ne pouvez pas modifier votre propre grade.' : 'Grade égal ou supérieur au vôtre : aucune action possible.'}</p>`}</div>
      ${e.history ? `<div class="card"><h2>Historique</h2><div class="timeline">${e.history.map((h) => `<div><b>${esc(h.action)}</b>${h.old_grade || h.new_grade ? ` · ${esc(h.old_grade || '—')} → ${esc(h.new_grade || '—')}` : ''}
        <small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}${h.reason ? ` · « ${esc(h.reason)} »` : ''}</small></div>`).join('') || '<span class="faint">Aucune opération.</span>'}</div></div>` : ''}`;
  }
  async function changeGrade(e, target, kind) {
    const me = T.st || {};
    const v = await confirmBox(kind, `<div class="kv"><span>Employé</span><b>${esc(e.name)}</b><span>Grade actuel</span><b>${esc(e.grade)}</b><span>Nouveau grade</span><b>${esc(target.name)}</b><span>Responsable</span><b>${esc(me.grade || '')} · ${esc(me.matricule || '')}</b></div>`,
      'Confirmer', kind === 'Rétrograder', '<label class="field" style="margin-top:.8rem"><span>Motif (facultatif)</span><input class="input" data-cfv="reason" maxlength="200"></label>');
    if (!v) return;
    const r = await call('setGrade', { cid: e.cid, gradeId: target.id, reason: v.reason });
    if (r.ok) { await PAGES.employees(T.gen); }
  }

  /* ------------------------------------------------------------------ */
  /* Grades                                                              */
  /* ------------------------------------------------------------------ */
  const GS = { data: null, edit: null };
  PAGES.grades = async (g) => {
    const d = await req('grades');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    GS.data = d;
    drawGrades();
  };
  function drawGrades() {
    const d = GS.data;
    const list = [...d.list].sort((a, b) => b.level - a.level);
    const ed = GS.edit;
    body().innerHTML = `${d.canGrades ? '' : '<div class="note">Consultation seule : la création et la modification des grades demandent la permission « Créer et modifier les grades ».</div>'}
      <div class="split"><div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Niveau</th><th>Grade</th><th>Salaire</th><th>Effectif</th><th></th></tr>
        ${list.map((gr) => `<tr><td class="mono">${gr.level}</td><td><b>${esc(gr.name)}</b> ${gr.isDefault ? '<span class="tag">Grade des recrues</span>' : ''}</td><td>${money(gr.salary)}</td><td>${gr.members}</td>
          <td style="text-align:right;white-space:nowrap">${d.canGrades && gr.level < d.myLevel ? `<button class="btn small" data-g="edit" data-id="${gr.id}">Modifier</button> <button class="btn small danger" data-g="del" data-id="${gr.id}">Supprimer</button>` : '<span class="faint" style="font-size:.75rem">—</span>'}</td></tr>`).join('')}</table></div>
        <div class="detail">${d.canGrades ? `<div class="card"><h2>${ed && ed.id ? 'Modifier le grade' : 'Créer un grade'}</h2><div class="form-grid">
          <label class="field full"><span>Nom</span><input class="input" id="gName" maxlength="50" value="${esc(ed ? ed.name : '')}" placeholder="ex : Brigadier-chef"></label>
          <label class="field"><span>Niveau (hiérarchie)</span><input class="input" id="gLevel" type="number" min="1" max="${d.myLevel - 1}" value="${ed ? ed.level : ''}" placeholder="1 à ${d.myLevel - 1}"></label>
          <label class="field"><span>Salaire ($ / paie)</span><input class="input" id="gSalary" type="number" min="0" value="${ed ? ed.salary : 0}"></label>
          <label class="field full" style="flex-direction:row;align-items:center;gap:.5rem"><input type="checkbox" class="check" id="gDefault" ${ed && ed.isDefault ? 'checked' : ''}><span style="font-size:.85rem;color:var(--text)">Grade donné aux nouvelles recrues</span></label></div>
          <div class="actions-row"><button class="btn primary" data-g="save">${ed && ed.id ? 'Enregistrer' : 'Créer le grade'}</button>${ed ? '<button class="btn" data-g="cancel">Annuler</button>' : ''}</div>
          <p class="faint" style="font-size:.76rem;margin-top:.7rem">Les permissions d'un grade se règlent dans l'onglet Permissions. Votre niveau : ${d.myLevel}. Vous ne gérez que les grades inférieurs.</p></div>` : ''}</div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Permissions                                                         */
  /* ------------------------------------------------------------------ */
  const PS = { data: null, dirty: {} };
  PAGES.perms = async (g) => {
    const d = await req('grades');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    PS.data = d; PS.dirty = {};
    d.list.forEach((gr) => { gr.set = new Set(gr.perms); });
    drawPerms();
  };
  function drawPerms() {
    const d = PS.data;
    const grades = [...d.list].sort((a, b) => a.level - b.level);
    let last = null, rows = '';
    d.permList.forEach((p) => {
      if (p.group !== last) { rows += `<tr class="grp"><td colspan="${grades.length + 1}">${esc(p.group)}</td></tr>`; last = p.group; }
      rows += `<tr><td>${esc(p.label)}</td>${grades.map((gr) => {
        const editable = d.canPerms && gr.level < d.myLevel && d.myPerms[p.key];
        return `<td><input type="checkbox" class="check" data-pg="${gr.id}" data-pk="${p.key}" ${gr.set.has(p.key) ? 'checked' : ''} ${editable ? '' : 'disabled'} title="${editable ? '' : 'Grade égal ou supérieur au vôtre, ou permission que vous n\'avez pas'}"></td>`;
      }).join('')}</tr>`;
    });
    const n = Object.keys(PS.dirty).length;
    body().innerHTML = `<div class="note">Cochez les permissions de chaque grade. Vous ne pouvez modifier que les grades <b>inférieurs</b> au vôtre, et seulement les permissions que vous possédez. Les changements s'appliquent immédiatement aux agents connectés.</div>
      <div class="toolbar"><span class="muted" style="font-size:.85rem">${n ? `${n} grade(s) modifié(s)` : 'Aucune modification'}</span><span style="flex:1"></span>
        <button class="btn" data-p="reset" ${n ? '' : 'disabled'}>Annuler</button><button class="btn primary" data-p="save" ${n ? '' : 'disabled'}>Enregistrer les permissions</button></div>
      <div class="card" style="padding:.2rem .4rem;overflow-x:auto"><table class="perm-table"><tr><th>Permission</th>${grades.map((gr) => `<th>${esc(gr.name)}<br><span class="faint">niv. ${gr.level}</span></th>`).join('')}</tr>${rows}</table></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Historique                                                          */
  /* ------------------------------------------------------------------ */
  const HS = { q: '' };
  PAGES.history = async (g) => {
    const d = await req('history', { q: HS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = `<div class="empty">${esc(d.error)}</div>`; return; }
    body().innerHTML = `<div class="toolbar"><input class="input grow" data-hq placeholder="Rechercher : responsable, employé, action" value="${esc(HS.q)}"><button class="btn" data-h="search">Rechercher</button></div>
      ${d.list.length ? `<div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Date</th><th>Responsable</th><th>Employé</th><th>Action</th><th>Grade</th><th>Motif</th></tr>
        ${d.list.map((h) => `<tr><td class="muted">${fmtTime(h.t)}</td><td>${esc(h.actor_name || '—')}</td><td>${esc(h.target_name || '—')}</td><td><b>${esc(h.action)}</b></td>
          <td class="muted">${h.old_grade || h.new_grade ? `${esc(h.old_grade || '—')} → ${esc(h.new_grade || '—')}` : '—'}</td><td class="muted">${esc(h.reason || '')}</td></tr>`).join('')}</table></div>` : '<div class="empty">Aucune opération enregistrée.</div>'}`;
  };

  /* ------------------------------------------------------------------ */
  /* Événements                                                          */
  /* ------------------------------------------------------------------ */
  $('#tabNav').addEventListener('click', (e) => { const b = e.target.closest('[data-nav]'); if (b) go(b.dataset.nav); });
  $('#tabClose').addEventListener('click', () => post('close', { ui: 'tablet' }));

  body().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    if (e.target.dataset.rf === 'q') { RS.f.q = e.target.value; return go('reports'); }
    if (e.target.id === 'rPerson') { e.preventDefault(); return addPerson(); }
    if (e.target.id === 'rAttach') { e.preventDefault(); return addAttach(); }
    if (e.target.dataset.hq !== undefined) { HS.q = e.target.value; return go('history'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.rf && t.dataset.rf !== 'q') { RS.f[t.dataset.rf] = t.value; return go('reports'); }
    if (t.dataset.ef && t.dataset.ef !== 'q') { ES.f[t.dataset.ef] = t.value; return drawEmployees(); }
    if (t.dataset.pg) {
      const gr = PS.data.list.find((x) => String(x.id) === t.dataset.pg);
      if (t.checked) gr.set.add(t.dataset.pk); else gr.set.delete(t.dataset.pk);
      PS.dirty[gr.id] = true;
      const n = Object.keys(PS.dirty).length;
      document.querySelectorAll('[data-p]').forEach((b) => { b.disabled = !n; });
      const lab = body().querySelector('.toolbar .muted'); if (lab) lab.textContent = `${n} grade(s) modifié(s)`;
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

  function addPerson() {
    const i = $('#rPerson'); const v = i.value.trim();
    if (!v) return;
    captureDraft();
    if (RS.draft.people.length >= 15) return toast('15 personnes maximum.', false);
    RS.draft.people.push(v); reportEdit(); $('#rPerson').focus();
  }
  function addAttach() {
    const i = $('#rAttach'); const v = i.value.trim();
    if (!v) return;
    if (!/^https?:\/\/\S+$/i.test(v)) return toast('Lien invalide (https://…).', false);
    captureDraft();
    RS.draft.attachments.push(v); reportEdit();
  }

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) { const q = b.dataset.q; return q === 'newReport' ? newReport() : go(q); }
    if ((b = e.target.closest('[data-open-report]'))) return openReport(Number(b.dataset.openReport));
    // Rapports
    if ((b = e.target.closest('[data-r]'))) {
      const a = b.dataset.r;
      if (a === 'search') { const q = body().querySelector('[data-rf="q"]'); RS.f.q = q ? q.value : ''; return go('reports'); }
      if (a === 'new') return newReport();
      if (a === 'back') { RS.mode = 'list'; return go('reports'); }
      if (a === 'edit') { const r = RS.loaded; RS.draft = { id: r.id, title: r.title, type: r.type, status: r.status, location: r.location || '', people: [...(r.people || [])], description: r.description || '', observations: r.observations || '', attachments: [...(r.attachments || [])] }; RS.mode = 'edit'; return reportEdit(); }
      if (a === 'cancelEdit') { RS.mode = RS.draft && RS.draft.id ? 'view' : 'list'; return go('reports', true); }
      if (a === 'archive') {
        const arch = b.dataset.arch === 'true';
        if (arch && !(await confirmBox('Archiver ce rapport ?', 'Il ne pourra plus être modifié, sauf s\'il est désarchivé.', 'Archiver', true))) return;
        const r = await call('reportArchive', { id: RS.current, archive: arch }, b);
        if (r.ok) { T.gen++; return reportView(T.gen); }
        return;
      }
      if (a === 'here') { const r = await post('street'); if (r && r.street) { captureDraft(); RS.draft.location = r.street; reportEdit(); } return; }
      if (a === 'addPerson') return addPerson();
      if (a === 'addAttach') return addAttach();
      if (a === 'save') {
        captureDraft();
        const r = await call('reportSave', RS.draft, b);
        if (r.ok) { RS.current = r.id; RS.mode = 'view'; T.gen++; return reportView(T.gen); }
        return;
      }
    }
    if ((b = e.target.closest('[data-rmp]'))) { captureDraft(); RS.draft.people.splice(Number(b.dataset.rmp), 1); return reportEdit(); }
    if ((b = e.target.closest('[data-rma]'))) { e.preventDefault(); captureDraft(); RS.draft.attachments.splice(Number(b.dataset.rma), 1); return reportEdit(); }
    // Carte
    if ((b = e.target.closest('[data-m]')) && T.map) { const m = b.dataset.m; if (m === 'in') T.map.zoom(1.4); else if (m === 'out') T.map.zoom(0.7); else T.map.fit(); return; }
    if ((b = e.target.closest('[data-focus]')) && T.map && MS.data) {
      const [kind, id] = b.dataset.focus.split(':');
      const list = kind === 'agent' ? MS.data.agents : kind === 'alert' ? MS.data.agentAlerts : MS.data.interventions;
      const o = list.find((x) => String(x.id) === id);
      if (o && o.x != null) { T.map.focus(o.x, o.y, 0.25); MS.sel = { kind, id: o.id, data: o }; renderSel(); }
      return;
    }
    // Agents
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter la police ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter la police', true))) return;
      const r = await call('resign');
      if (r.ok) post('close', { ui: 'tablet' });
      return;
    }
    // Recrutement
    if ((b = e.target.closest('[data-rc]'))) {
      const a = b.dataset.rc;
      if (a === 'clear') { RC.preview = null; return PAGES.recruit(); }
      if (a === 'find') { const r = await call('recruitPreview', {}, b); RC.preview = r.error ? null : r; return PAGES.recruit(); }
      if (a === 'send') {
        const p = RC.preview, gid = Number($('#rcGrade').value);
        const gr = p.grades.find((x) => x.id === gid);
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre la police au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Changer de grade', `Choisissez le nouveau grade de <b>${esc(emp.name)}</b> (actuellement ${esc(emp.grade)}).`, 'Continuer', false,
          `<label class="field"><span>Nouveau grade</span><select class="input" data-cfv="grade">${s.choices.map((g) => `<option value="${g.id}">${esc(g.name)} (niveau ${g.level})</option>`).join('')}</select></label>`);
        if (!v) return;
        const target = s.choices.find((g) => String(g.id) === v.grade);
        if (target) return changeGrade(emp, target, target.level > emp.level ? 'Promouvoir' : 'Rétrograder');
        return;
      }
      if (a === 'edit') {
        const v = await confirmBox('Modifier la fiche', `Informations professionnelles de <b>${esc(emp.name)}</b>.`, 'Enregistrer', false,
          `<div class="stack" style="display:flex;flex-direction:column;gap:.7rem"><label class="field"><span>Matricule</span><input class="input" data-cfv="matricule" maxlength="20" value="${esc(emp.matricule)}"></label>
           <label class="field"><span>Note</span><input class="input" data-cfv="note" maxlength="255" value="${esc(emp.note || '')}"></label></div>`);
        if (!v) return;
        const r = await call('editEmployee', { cid: emp.cid, matricule: v.matricule, note: v.note });
        if (r.ok) await PAGES.employees(T.gen);
        return;
      }
      if (a === 'fire') {
        const v = await confirmBox('Retirer de la police ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et tous ses accès.`, 'Retirer', true,
          '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="200"></label>');
        if (!v) return;
        const r = await call('fire', { cid: emp.cid, reason: v.reason });
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
        const data = { id: GS.edit ? GS.edit.id : undefined, name: $('#gName').value, level: Number($('#gLevel').value), salary: Number($('#gSalary').value), isDefault: $('#gDefault').checked };
        const r = await call('gradeSave', data, b);
        if (r.ok) { GS.edit = null; return PAGES.grades(T.gen); }
        return;
      }
      if (a === 'del') {
        const gr = GS.data.list.find((x) => String(x.id) === b.dataset.id);
        const others = GS.data.list.filter((x) => x.id !== gr.id && x.level < GS.data.myLevel);
        const extra = gr.members > 0 ? `<label class="field" style="margin-top:.7rem"><span>Réaffecter les ${gr.members} employé(s) au grade</span><select class="input" data-cfv="reassign">${others.map((o) => `<option value="${o.id}">${esc(o.name)}</option>`).join('')}</select></label>` : '';
        const v = await confirmBox('Supprimer le grade ?', `« <b>${esc(gr.name)}</b> » sera supprimé.${gr.members ? ' Ses employés doivent être réaffectés.' : ''}`, 'Supprimer', true, extra);
        if (!v) return;
        const r = await call('gradeDelete', { id: gr.id, reassign: v.reassign ? Number(v.reassign) : undefined });
        if (r.ok) return PAGES.grades(T.gen);
      }
      return;
    }
    // Permissions
    if ((b = e.target.closest('[data-p]'))) {
      if (b.dataset.p === 'reset') return PAGES.perms(T.gen);
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
  });

  setInterval(() => { const d = new Date(); $('#tabClock').textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }, 1000);

  /* ------------------------------------------------------------------ */
  window.Tablet = {
    open(st) {
      T.open = true;
      T.st = st || APP.st || T.st;
      T.perms = (T.st && T.st.perms) || {};
      $('#tablet').classList.remove('hidden');
      go(T.page || 'dashboard', T.page === 'reports');
    },
    hide() { T.open = false; stopTimers(); $('#tablet').classList.add('hidden'); },
    isOpen: () => T.open,
    back() {
      if (T.page === 'reports' && RS.mode !== 'list') { RS.mode = 'list'; go('reports'); return true; }
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
