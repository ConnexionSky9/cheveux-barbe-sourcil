/* =====================================================================
   ELYZEA BOÎTE DE NUIT - tablette (toujours limitée à la boîte de l'employé)
   Boîte : Tableau de bord · Bar (carte, prix, stock) · Ventes · Entrée et listes · Musique · Fiche
   Direction : Recrutement, Employés, Grades, Permissions, Historique · Finance : Vue d'ensemble, Transactions
   Chaque bouton appelle le serveur, qui revérifie les droits et recalcule les montants.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, map: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const initials = (n) => (String(n || '').split(/\s+/).filter((p) => /^\p{L}/u.test(p)).map((p) => p[0]).join('').slice(0, 2) || '?').toUpperCase();
  const CAT = { sale: 'Bar', entry: 'Entrées', stock: 'Stock', refund: 'Remboursements', salary: 'Salaires', commission: 'Commissions', other: 'Autre' };
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'bar', label: 'Bar : carte et stock', ico: '🍸', perm: ['tablet'] },
    { id: 'sales', label: 'Ventes', ico: '🧾', perm: ['tablet'] },
    { id: 'entry', label: 'Entrée et listes', ico: '🎟️', perm: ['tablet'] },
    { id: 'music', label: 'Musique', ico: '🎵', perm: ['tablet'] },
    { id: 'config', label: 'Fiche de la boîte', ico: '⚙️', perm: ['tablet'] },
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
    let last = null, html = `<div class="brand"><div class="shield">🪩</div><div><b>${esc((T.st || {}).shopName || 'Boîte de nuit')}</b><small>Boîte de nuit</small></div></div>`;
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

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || ((T.st && T.st.shopName) || 'Boîte de nuit'); }
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
  const lineTxt = (l) => (l.lines || []).map((x) => `${x.qty} × ${esc(x.label)}`).join(', ') || (l.kind === 'entry' ? 'Entrée' : '');
  PAGES.dashboard = async (g) => {
    const d = await req('dashboard');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const t = d.me.times || {}, s = d.stats;
    body().innerHTML = `
      <div class="stats">
        <div class="stat ${d.publicOpen ? 'green' : 'orange'}"><b>${d.publicOpen ? 'Ouverte' : 'Fermée'}</b><span>Au public · entrée ${d.fee > 0 ? money(d.fee) : 'gratuite'} · ${d.bands} bracelet(s) valable(s)</span></div>
        <div class="stat green"><b>${money(s.barToday.total)}</b><span>Bar aujourd'hui · ${s.barToday.n} commande(s) · ${money(s.barWeek.total)} sur 7 jours</span></div>
        <div class="stat blue"><b>${money(s.entryToday.total)}</b><span>Entrées aujourd'hui · ${s.entryToday.n} · ${money(s.entryWeek.total)} sur 7 jours</span></div>
        <div class="stat violet"><b>${d.music ? (d.music.paused ? '⏸' : '▶') : '—'}</b><span>${d.music ? esc(d.music.title || 'Musique en cours') : 'Pas de musique'} · ${d.speakers} enceinte(s)</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Dernières ventes</h2>${d.last.map((l) => `<div class="list-row"><div class="main"><b>${lineTxt(l)}</b>
          <small>${esc(l.buyer_name || '')}${l.seller_name ? ` · servi par ${esc(l.seller_name)}` : ''} · ${fmtTime(l.t)}</small></div><span class="mono nw">${money(l.price)}</span></div>`).join('') || empty('Aucune vente.')}</div>
        ${d.lowStock.length ? `<div class="card"><h2>Stock bas</h2>${d.lowStock.map((x) => `<div class="list-row"><div class="main"><b>${esc(x.label)}</b></div><span class="pill ${x.stock ? 'warn' : 'bad'}">${x.stock} restant(s)</span></div>`).join('')}
          <div class="actions-row"><button class="btn small" data-q="bar">🍸 Commander du stock</button></div></div>` : ''}
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Boîte</span><b>${esc(d.shop.name)}</b><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session</span><b class="mono">${dur(t.session)}</b><span>Non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b>
          <span>Taux</span><b>${money(t.rate)} / h${t.commission ? ` · ${t.commission} % sur mes ventes au bar` : ''}</b>${d.balance != null ? `<span>Compte de la boîte</span><b class="mono">${money(d.balance)}</b>` : ''}</div>
          <div class="actions-row"><button class="btn small" data-q="bar">🍸 Bar</button><button class="btn small" data-q="entry">🎟️ Entrée</button><button class="btn small" data-q="music">🎵 Musique</button>
            <button class="btn danger small" data-resign="1">Quitter la boîte</button></div></div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)} · ${dur(a.session)}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div></div>`;
    every(15000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Bar : carte, prix, stock                                            */
  /* ------------------------------------------------------------------ */
  PAGES.bar = async (g) => {
    const d = await req('menu');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    T.menu = d;
    const cats = [...new Set(d.list.map((x) => x.cat))];
    body().innerHTML = `<div class="note">La carte est propre à votre boîte. ${d.canEdit ? 'Changez un prix, retirez une boisson de la carte ou remettez-la.' : 'Seuls les grades avec la permission « carte et prix » la modifient.'}
        ${d.canStock ? ` Le stock se commande avec l'argent de la boîte (solde : <b>${money(d.balance)}</b>).` : ''} Une boisson sans stock ne peut plus être servie.</div>
      ${cats.map((c) => `<div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">${esc(c)}</h2><table class="tbl"><tr><th>Boisson</th><th>Prix</th><th>Stock</th><th>Carte</th><th></th></tr>
        ${d.list.filter((x) => x.cat === c).map((x) => `<tr style="${x.enabled ? '' : 'opacity:.55'}"><td><b>${esc(x.label)}</b><br><small class="faint mono">${esc(x.item)} · achat ${money(x.cost)}</small></td>
          <td class="mono">${money(x.price)}</td><td><span class="pill ${x.stock > 5 ? 'on' : x.stock > 0 ? 'warn' : 'bad'}">${x.stock}</span></td>
          <td>${x.enabled ? '<span class="pill on">À la carte</span>' : '<span class="pill off">Retirée</span>'}</td>
          <td class="nw">${d.canEdit ? `<button class="btn small" data-mprice="${esc(x.item)}">Prix</button> <button class="btn small" data-mtoggle="${esc(x.item)}">${x.enabled ? 'Retirer' : 'Remettre'}</button>` : ''}
            ${d.canStock ? ` <button class="btn small primary" data-mstock="${esc(x.item)}">+ Stock</button>` : ''}</td></tr>`).join('')}</table></div>`).join('')}`;
  };

  /* ------------------------------------------------------------------ */
  /* Ventes (bar et entrées)                                             */
  /* ------------------------------------------------------------------ */
  const SS = { kind: '' };
  PAGES.sales = async (g) => {
    const d = await req('sales', { kind: SS.kind });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const total = d.list.reduce((a, x) => a + (Number(x.price) || 0), 0);
    body().innerHTML = `<div class="toolbar"><select class="input" data-sk>${[['', 'Bar et entrées'], ['bar', 'Bar'], ['entry', 'Entrées']].map(([k, l]) => `<option value="${k}" ${SS.kind === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
        <span class="faint">${d.all ? 'Toutes les ventes' : 'Mes ventes'} · ${d.list.length} · ${money(total)}</span></div>
      <div class="card" style="padding:.3rem .6rem"><table class="tbl"><tr><th>Date</th><th>Détail</th><th>Client</th><th>Servi par</th><th>Paiement</th><th>Total</th></tr>
        ${d.list.map((x) => `<tr><td class="nw">${fmtTime(x.t)}</td><td>${x.kind === 'entry' ? '🎟️ Entrée' : lineTxt(x)}</td><td>${esc(x.buyer_name || '')}</td><td>${esc(x.seller_name || '—')}</td>
          <td>${x.method === 'cash' ? 'Espèces' : 'Banque'}</td><td class="mono nw">${money(x.price)}</td></tr>`).join('') || `<tr><td colspan="6">${empty('Aucune vente.')}</td></tr>`}</table></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Entrée : ouverture, prix, annonce, bracelets, liste VIP, liste noire */
  /* ------------------------------------------------------------------ */
  PAGES.entry = async (g) => {
    const [o, l] = await Promise.all([req('openState'), can('door') ? req('lists') : Promise.resolve(null)]);
    if (stale(g)) return;
    if (o.error) { body().innerHTML = empty(o.error); return; }
    T.openState = o;
    const row = (x, kind) => `<div class="list-row"><div class="main"><b>${esc(x.name || x.cid)}</b><small>${x.reason ? esc(x.reason) + ' · ' : ''}${x.expires ? `jusqu'au ${fmtTime(x.expires)}` : kind === 'ban' ? 'définitif' : 'permanent'}${x.by ? ` · par ${esc(x.by)}` : ''}</small></div>
      ${l && l.canEdit ? `<button class="btn small danger" data-lrem="${esc(x.cid)}" data-kind="${kind}">Retirer</button>` : ''}</div>`;
    body().innerHTML = `<div class="cols"><div>
        <div class="card"><h2>Ouverture au public</h2>
          <div class="kv"><span>État</span><b>${o.publicOpen ? '<span class="pill on">Ouverte</span>' : '<span class="pill off">Fermée</span>'}</b><span>Prix d'entrée</span><b>${o.fee > 0 ? money(o.fee) : 'Gratuite'}</b>
            <span>Intérieur</span><b>${o.hasInside ? 'Payer l\'entrée fait entrer dans la boîte' : 'Pas de point intérieur : l\'entrée donne un bracelet'}</b></div>
          ${!o.hasDoor ? '<div class="warn-box">Le staff n\'a pas encore placé le point Entrée.</div>' : ''}
          ${o.canEdit ? `<div class="actions-row"><button class="btn ${o.publicOpen ? 'danger' : 'primary'}" data-open="${o.publicOpen ? 0 : 1}">${o.publicOpen ? 'Fermer au public' : 'Ouvrir au public'}</button>
            <button class="btn" data-fee="1">Prix d'entrée</button></div><p class="faint" style="font-size:.78rem;margin-top:.5rem">Le personnel entre toujours. La liste VIP entre gratuitement quand la boîte est ouverte ; la liste noire n'entre jamais.</p>` : ''}</div>
        ${o.canAnnounce ? `<div class="card"><h2>Annonce à toute la ville</h2><textarea class="input" id="annText" rows="3" maxlength="200" placeholder="Ex : Soirée Neon ce soir à 22 h, entrée 50 $, DJ en live !"></textarea>
          <div class="actions-row"><button class="btn primary" data-announce="1" ${o.announceIn > 0 ? 'disabled' : ''}>📣 Envoyer l'annonce</button>
          <span class="faint" style="font-size:.8rem">${o.announceIn > 0 ? `Prochaine annonce dans ${Math.ceil(o.announceIn / 60)} min` : 'Une annonce toutes les 10 minutes au plus'}</span></div></div>` : ''}
        ${l ? `<div class="card"><h2>Bracelets valables <span class="faint" style="font-size:.8rem">${l.bands.length}</span></h2>${l.bands.map((x) => `<div class="list-row"><div class="main"><b>${esc(x.name)}</b><small>jusqu'à ${fmtTime(x.expires)}${x.online ? '' : ' · hors ligne'}</small></div></div>`).join('') || empty('Aucun bracelet en cours.')}</div>` : ''}
      </div><div>
        ${l ? `<div class="card"><h2>Liste VIP <span class="faint" style="font-size:.8rem">${l.vip.length}</span></h2>${l.vip.map((x) => row(x, 'vip')).join('') || empty('Personne.')}
            ${l.canEdit ? '<div class="actions-row"><button class="btn small" data-ladd="vip">+ Ajouter (ID serveur)</button></div>' : ''}</div>
          <div class="card"><h2>Liste noire <span class="faint" style="font-size:.8rem">${l.ban.length}</span></h2>${l.ban.map((x) => row(x, 'ban')).join('') || empty('Personne.')}
            ${l.canEdit ? '<div class="actions-row"><button class="btn small danger" data-ladd="ban">+ Interdire (ID serveur)</button></div>' : ''}</div>` : '<div class="card">' + empty('Les listes sont réservées aux grades « Contrôler l\'entrée ».') + '</div>'}
      </div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Musique : playlist et enceintes (même panneau que la platine)        */
  /* ------------------------------------------------------------------ */
  PAGES.music = async (g) => {
    const d = await req('music');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = '<div id="tabDj"></div>';
    if (window.Dj) Dj.mount($('#tabDj'), d, true);
  };

  /* ------------------------------------------------------------------ */
  /* Fiche de la boîte                                                   */
  /* ------------------------------------------------------------------ */
  PAGES.config = async (g) => {
    const d = await req('config');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const yes = (v) => (v ? '<span class="pill on">Placé</span>' : '<span class="pill off">Non placé</span>');
    body().innerHTML = `<div class="cols"><div><div class="card"><h2>Boîte de nuit</h2><div class="kv"><span>Nom</span><b>${esc(d.shop.name)}</b><span>Adresse</span><b>${esc(d.shop.address || '—')}</b>
        <span>Métier</span><b class="mono">${esc(d.shop.job)}</b><span>Compte</span><b class="mono">${esc(d.shop.society)}</b><span>Service obligatoire</span><b>${d.shop.requireDuty ? 'Oui' : 'Non'}</b>
        <span>Enceintes</span><b>${d.speakers} / ${d.maxSpeakers}</b></div>
        <p class="faint" style="font-size:.78rem;margin-top:.6rem">Le métier, le compte et les points sont réglés par le staff (admin_menu › Boîtes de nuit).</p></div></div>
      <div><div class="card"><h2>Points</h2><div class="kv"><span>Entrée</span><b>${yes(d.points.door)}</b><span>Intérieur (facultatif)</span><b>${yes(d.points.inside)}</b>
        <span>Bar</span><b>${yes(d.points.bar)}</b><span>Coffre</span><b>${yes(d.points.stash)}</b><span>Bureau</span><b>${yes(d.points.manage)}</b></div></div></div></div>`;
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
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne travaille déjà dans une boîte.</p>' : ''}
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
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de la boîte</button>' : ''}</div>`
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
        <div class="cols even"><div class="card"><h2>Détail sur 7 jours</h2><div class="kv"><span>Bar</span><b class="mono">+${money(sm('in:sale').total)} <span class="faint">(${sm('in:sale').n})</span></b>
            <span>Entrées</span><b class="mono">+${money(sm('in:entry').total)} <span class="faint">(${sm('in:entry').n})</span></b>
            <span>Stock acheté</span><b class="mono">−${money(sm('out:stock').total)} <span class="faint">(${sm('out:stock').n})</span></b>
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)}</b></div></div>
          <div class="card"><h2>Depuis l'ouverture</h2><div class="kv"><span>Bar</span><b class="mono">${money(al('in:sale').total)} <span class="faint">(${al('in:sale').n})</span></b>
            <span>Entrées</span><b class="mono">${money(al('in:entry').total)} <span class="faint">(${al('in:entry').n})</span></b><span>Stock acheté</span><b class="mono">${money(al('out:stock').total)}</b>
            <span>Salaires versés</span><b class="mono">${money(al('out:salary').total)}</b><span>Remboursements</span><b class="mono">${money(al('out:refund').total)}</b></div></div></div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur les commandes servies au bar, versée par la boîte. Appliqué à partir de maintenant.</p></div>
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
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
    if (t.dataset.sk !== undefined) { SS.kind = t.value; return go('sales'); }
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
    if (t.dataset.ef === 'q') { ES.f.q = t.value; return keep('[data-ef="q"]', drawEmployees); }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) return go(b.dataset.q);
    // Bar : prix, carte, stock
    if ((b = e.target.closest('[data-mprice]'))) {
      const x = T.menu.list.find((y) => y.item === b.dataset.mprice);
      const v = await confirmBox(`Prix : ${x.label}`, `Prix actuel : <b>${money(x.price)}</b>. Les commandes déjà payées ne changent pas.`, 'Enregistrer', false,
        `<label class="field" style="margin-top:.6rem"><span>Nouveau prix ($)</span><input class="input" type="number" min="1" max="${T.menu.maxPrice}" data-cfv="price" value="${x.price}"></label>`);
      if (!v) return;
      const r = await call('menuSet', { item: x.item, price: Number(v.price) });
      if (r.ok) return PAGES.bar(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-mtoggle]'))) {
      const x = T.menu.list.find((y) => y.item === b.dataset.mtoggle);
      const r = await call('menuSet', { item: x.item, enabled: !x.enabled }, b);
      if (r.ok) return PAGES.bar(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-mstock]'))) {
      const x = T.menu.list.find((y) => y.item === b.dataset.mstock);
      const v = await confirmBox(`Commander : ${x.label}`, `Stock actuel : <b>${x.stock}</b>. Prix d'achat : <b>${money(x.cost)}</b> l'unité, payé par le compte de la boîte (${money(T.menu.balance)}).`, 'Commander', false,
        `<label class="field" style="margin-top:.6rem"><span>Quantité</span><input class="input" type="number" min="1" max="${T.menu.maxStock}" data-cfv="qty" value="20"></label>`);
      if (!v) return;
      const r = await call('stockOrder', { item: x.item, qty: Number(v.qty) });
      if (r.ok) return PAGES.bar(T.gen);
      return;
    }
    // Entrée
    if ((b = e.target.closest('[data-open]'))) { const r = await call('openSet', { publicOpen: b.dataset.open === '1' }, b); if (r.ok) return PAGES.entry(T.gen); return; }
    if (e.target.closest('[data-fee]')) {
      const v = await confirmBox('Prix d\'entrée', 'Payé à l\'entrée par les clients (0 = gratuit). Il va directement sur le compte de la boîte.', 'Enregistrer', false,
        `<label class="field" style="margin-top:.6rem"><span>Prix ($, 0 à ${(T.openState || {}).maxFee || 10000})</span><input class="input" type="number" min="0" data-cfv="fee" value="${(T.openState || {}).fee || 0}"></label>`);
      if (!v) return;
      const r = await call('openSet', { fee: Number(v.fee) });
      if (r.ok) return PAGES.entry(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-announce]'))) {
      const r = await call('announce', { text: ($('#annText') || {}).value || '' }, b);
      if (r.ok) return PAGES.entry(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-ladd]'))) {
      const ban = b.dataset.ladd === 'ban';
      const v = await confirmBox(ban ? 'Liste noire' : 'Liste VIP', ban ? 'La personne ne pourra plus entrer (son bracelet est retiré).' : 'La personne entre gratuitement quand la boîte est ouverte.', 'Ajouter', ban,
        `<div class="stack" style="margin-top:.6rem"><label class="field"><span>ID serveur du joueur (connecté)</span><input class="input" type="number" min="1" data-cfv="target"></label>
         <label class="field"><span>Raison (facultatif)</span><input class="input" maxlength="160" data-cfv="reason"></label>
         ${ban ? '<label class="field"><span>Durée en jours (0 = définitif)</span><input class="input" type="number" min="0" max="365" data-cfv="days" value="0"></label>' : ''}</div>`);
      if (!v) return;
      const r = await call('listAdd', { kind: b.dataset.ladd, target: Number(v.target), reason: v.reason, days: Number(v.days || 0) });
      if (r.ok) return PAGES.entry(T.gen);
      return;
    }
    if ((b = e.target.closest('[data-lrem]'))) {
      if (!(await confirmBox('Retirer de la liste ?', '', 'Retirer', true))) return;
      const r = await call('listRemove', { kind: b.dataset.kind, cid: b.dataset.lrem }, b);
      if (r.ok) return PAGES.entry(T.gen);
      return;
    }
    // Démission
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter la boîte ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter', true))) return;
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
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre la boîte au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Retirer de la boîte ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
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
