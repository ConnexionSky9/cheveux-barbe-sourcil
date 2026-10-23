/* =====================================================================
   ELYZEA PRESSE - tablette
   Rédaction : Tableau de bord · Rédiger · Mes articles · À valider · Publiés · Archives
   Terrain : Interviews · Photos et séquences · Diffusion : Flash info · Annonces
   Direction : Recrutement, Employés, Grades, Permissions, Historique, Cartes de presse, Locaux
   Finance : Vue d'ensemble, Transactions (pages reprises d'elyzea_dynasty)
   Chaque bouton appelle le serveur, qui revérifie les droits, la rédaction et les statuts.
   ===================================================================== */
(() => {
  const T = { open: false, page: 'dashboard', perms: {}, st: null, timer: null, gen: 0 };
  const body = () => $('#tabBody');
  const can = (p) => !!T.perms[p];
  const canAny = (...l) => l.some(can);
  const statusPill = (id) => { const s = statusOf(id); return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55">${esc(s.label)}</span>`; };
  const CAT = { ad: 'Annonces', refund: 'Remboursements', salary: 'Salaires', commission: 'Commissions', other: 'Autre' };
  const STL = { draft: 'Brouillon', pending: 'Soumis', published: 'Publié', rejected: 'Renvoyé', archived: 'Archivé' };
  const stTag = (s) => `<span class="st ${esc(s)}">${esc(STL[s] || s)}</span>`;
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const lim = () => (APP.cfg && APP.cfg.limits) || { titleMax: 120, summaryMax: 300, bodyMax: 12000, bodyMin: 40, titleMin: 6, maxMedia: 6 };

  const NAV = [
    { id: 'dashboard', label: 'Tableau de bord', ico: '◈', perm: ['tablet'] },
    { id: 'write', label: 'Rédiger', ico: '✍️', perm: ['write'] },
    { id: 'mine', label: 'Mes articles', ico: '🗂️', perm: ['write'] },
    { id: 'pending', label: 'À valider', ico: '✅', perm: ['review'] },
    { id: 'published', label: 'Publiés', ico: '📰', perm: ['tablet'] },
    { id: 'archives', label: 'Archives', ico: '🗄️', perm: ['tablet'] },
    { id: 'interviews', label: 'Interviews', ico: '🎙️', perm: ['interview'], group: 'Terrain' },
    { id: 'media', label: 'Photos et séquences', ico: '📷', perm: ['media', 'write'], group: 'Terrain' },
    { id: 'flash', label: 'Flash info', ico: '⚡', perm: ['flash'], group: 'Diffusion' },
    { id: 'ads', label: 'Annonces commandées', ico: '📣', perm: ['ads', 'ads_manage'], group: 'Diffusion' },
    { id: 'recruit', label: 'Recrutement', ico: '➕', perm: ['recruit'], group: 'Direction' },
    { id: 'employees', label: 'Employés', ico: '👥', perm: ['employees_view'], group: 'Direction' },
    { id: 'grades', label: 'Grades', ico: '🎖️', perm: ['direction'], group: 'Direction' },
    { id: 'perms', label: 'Permissions', ico: '🔐', perm: ['perms_manage'], group: 'Direction' },
    { id: 'history', label: 'Historique', ico: '🕘', perm: ['history_view'], group: 'Direction' },
    { id: 'cards', label: 'Cartes de presse', ico: '🪪', perm: ['cards_manage'], group: 'Direction' },
    { id: 'setup', label: 'Locaux, garage, tenues', ico: '🏢', perm: ['points_manage'], group: 'Direction' },
    { id: 'finance', label: 'Vue d\'ensemble', ico: '💰', perm: ['finance'], group: 'Finance' },
    { id: 'transactions', label: 'Transactions', ico: '🔁', perm: ['finance'], group: 'Finance' },
  ];
  const allowed = (n) => canAny(...n.perm) && (n.group !== 'Direction' || can('direction'));

  function renderNav() {
    const st = T.st || {};
    let last = null, html = `<div class="brand"><div class="shield">📰</div><div><b>${esc(st.agency || 'Rédaction')}</b><small>Rédaction</small></div></div>`;
    NAV.filter(allowed).forEach((n) => {
      if (n.group && n.group !== last) html += `<div class="nav-group">${n.group}</div>`;
      last = n.group;
      html += `<button class="nav-btn ${T.page === n.id ? 'active' : ''}" data-nav="${n.id}"><span class="ico">${n.ico}</span>${n.label}</button>`;
    });
    html += `<div class="nav-me"><b>${esc(st.grade || '')}</b><span class="mono">${esc(st.matricule || '')}</span></div>`;
    $('#tabNav').innerHTML = html;
    const pill = $('#tabDuty');
    pill.className = `pill ${st.duty ? 'on' : 'off'}`;
    pill.textContent = st.duty ? `En service · ${statusOf(st.status).label}` : 'Hors service';
  }

  function setTitle(t, eyebrow) { $('#tabTitle').textContent = t; $('#tabEyebrow').textContent = eyebrow || 'Rédaction'; }
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
    if (!keepSub) { ES.cid = null; AS.view = null; if (page !== 'write') ED.a = null; }
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
    const t = d.me.times || {}, c = d.counts || {}, mi = d.mine || {};
    body().innerHTML = `
      <div class="stats">
        <div class="stat green"><b>${c.published || 0}</b><span>Articles en ligne</span></div>
        <div class="stat orange"><b>${c.pending || 0}</b><span>En attente de validation</span></div>
        <div class="stat blue"><b>${d.week || 0}</b><span>Publiés ces 7 jours</span></div>
        <div class="stat red"><b>${(mi.draft || 0) + (mi.rejected || 0)}</b><span>Mes brouillons et renvoyés</span></div>
      </div>
      <div class="cols"><div>
        <div class="card"><h2>Derniers articles publiés</h2>${d.last.map((a) => `<div class="list-row click" data-art="${a.id}"><div class="main"><b>${esc(a.title)}</b>
          <small>${esc(catLabel(a.category))} · ${esc(a.author_name || '')} · ${fmtTime(a.t)}</small></div></div>`).join('') || empty('Aucun article publié.')}</div>
        ${d.interview ? `<div class="card"><h2>Interview en cours</h2><div class="kv"><span>Sujet</span><b>${esc(d.interview.subject)}</b><span>Avec</span><b>${esc(d.interview.other)}</b></div>
          ${d.interview.role === 'journalist' ? `<div class="actions-row"><button class="btn small primary" data-notes="${d.interview.id}">📝 Notes</button></div>` : ''}</div>` : ''}
      </div><div>
        <div class="card"><h2>Moi</h2><div class="kv"><span>Grade</span><b>${esc(d.me.grade)}</b><span>Matricule</span><b class="mono">${esc(d.me.matricule)}</b>
          <span>Service</span><b>${d.me.duty ? statusPill(d.me.status) : '<span class="pill off">Hors service</span>'}</b>
          <span>Session</span><b class="mono">${dur(t.session)}</b><span>Non payé</span><b class="mono">${dur(t.unpaid)} · ${money(t.unpaidAmount)}</b><span>Taux</span><b>${money(t.rate)} / h</b></div>
          <div class="actions-row">${can('write') ? '<button class="btn small primary" data-q="write">✍️ Rédiger</button>' : ''}<button class="btn small" data-q="published">📰 Publiés</button>
            <button class="btn danger small" data-resign="1">Quitter la rédaction</button></div></div>
        <div class="card"><h2>Équipe en service <span class="faint" style="font-size:.8rem">${d.crew.length}</span></h2>${d.crew.map((a) => `<div class="list-row"><span class="avatar">${initials(a.name)}</span>
          <div class="main"><b>${esc(a.name)}</b><small>${esc(a.grade)}${a.street ? ` · ${esc(a.street)}` : ''}</small></div>${statusPill(a.status)}</div>`).join('') || empty('Personne en service.')}</div>
      </div></div>`;
    every(10000, () => { if (T.page === 'dashboard' && !typing()) PAGES.dashboard(T.gen); });
  };

  /* ------------------------------------------------------------------ */
  /* Rédiger (création, modification, correction)                         */
  /* ------------------------------------------------------------------ */
  const ED = { a: null, media: null, preset: null };
  PAGES.write = async (g) => {
    const m = await req('media', {});
    if (stale(g)) return;
    ED.media = m.list || [];
    drawEditor();
  };
  function drawEditor() {
    const a = ED.a || ED.preset || {}, L = lim(), sel = new Set(a.mediaIds || []);
    const cats = (APP.cfg && APP.cfg.categories) || [];
    body().innerHTML = `${a.id ? `<div class="note">Modification de « ${esc(a.title)} » ${stTag(a.status)}${a.status === 'published' ? ' — <b>la correction est publiée immédiatement</b> et tracée.' : ''}${a.note ? `<br>Note du relecteur : <b>${esc(a.note)}</b>` : ''}</div>`
      : '<div class="note">Le brouillon n\'est visible que de vous. Soumettez-le à la validation, ou publiez-le directement si votre grade le permet.</div>'}
      <div class="split"><div class="card editor">
        <label class="field"><span>Titre (${L.titleMin} à ${L.titleMax} caractères)</span><input class="input" id="edTitle" maxlength="${L.titleMax}" value="${esc(a.title || '')}"></label>
        <label class="field"><span>Chapeau (résumé, facultatif)</span><input class="input" id="edSummary" maxlength="${L.summaryMax}" value="${esc(a.summary || '')}"></label>
        <label class="field"><span>Rubrique</span><select class="input" id="edCat">${cats.map((c) => `<option value="${c.id}" ${a.category === c.id ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></label>
        <label class="field"><span>Article</span><textarea class="input body" id="edBody" maxlength="${L.bodyMax}">${esc(a.body || '')}</textarea></label>
        <div class="count" id="edCount">${(a.body || '').length} / ${L.bodyMax}</div>
        <div class="actions-row"><button class="btn primary" data-ed="save">💾 Enregistrer</button>
          ${a.id && a.status !== 'published' ? `<button class="btn" data-ed="submit" ${a.status === 'pending' ? 'disabled' : ''}>Soumettre à validation</button>` : ''}
          ${a.id && can('publish') && a.status !== 'published' && a.mine !== false ? '<button class="btn success" data-ed="publish">Publier</button>' : ''}
          ${a.id ? '<button class="btn" data-ed="new">Nouvel article</button>' : ''}</div></div>
      <div class="detail"><div class="card"><h2>Photos et séquences jointes</h2><p class="faint" style="font-size:.78rem;margin-bottom:.5rem">${L.maxMedia} au maximum. Elles apparaissent en crédit sous l'article.</p>
        <div class="media-pick">${ED.media.map((m) => `<label><input type="checkbox" class="check" data-med="${m.id}" ${sel.has(m.id) ? 'checked' : ''}>${m.kind === 'video' ? '🎥' : '📷'} ${esc(m.caption)}</label>`).join('') || '<span class="faint">Aucune photo ou séquence de la rédaction.</span>'}</div></div>
        ${a.interviewId ? `<div class="card"><h2>Interview liée</h2><span class="faint">n° ${a.interviewId}</span></div>` : ''}</div></div>`;
  }
  function editorData() {
    const a = ED.a || {};
    return { id: a.id, version: a.version, title: $('#edTitle').value, summary: $('#edSummary').value, category: $('#edCat').value, body: $('#edBody').value,
      interviewId: a.interviewId || (ED.preset && ED.preset.interviewId), media: [...body().querySelectorAll('[data-med]:checked')].map((i) => Number(i.dataset.med)) };
  }
  async function openEditor(id) {
    const r = await req('article', { id });
    if (r.error) return toast(r.error, false);
    if (!r.article.canEdit) return toast('Vous ne pouvez pas modifier cet article.', false);
    ED.a = r.article; ED.preset = null;
    T.page = 'write'; renderNav(); setTitle('Rédiger');
    await PAGES.write(T.gen);
  }

  /* ------------------------------------------------------------------ */
  /* Listes d'articles et fiche                                          */
  /* ------------------------------------------------------------------ */
  const AS = { q: '', view: null };
  async function listPage(g, box) {
    const d = await req('articles', { box, q: AS.q });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const notes = { mine: 'Vos brouillons, vos articles soumis et ceux qu\'un relecteur vous a renvoyés.', pending: 'Articles soumis par la rédaction : publiez-les, corrigez-les ou renvoyez-les avec une note.',
      published: 'Articles en ligne dans le journal.', archived: 'Articles archivés : toujours lisibles dans les archives du journal.' };
    body().innerHTML = `<div class="note">${notes[box]}</div><div class="toolbar"><input class="input grow" id="aq" placeholder="Rechercher : titre, auteur, chapeau" value="${esc(AS.q)}"><button class="btn" data-asearch="1">Rechercher</button></div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Titre</th><th>Rubrique</th><th>Auteur</th><th>Statut</th><th>Date</th></tr>${d.list.map((a) => `<tr class="click" data-art="${a.id}">
        <td><b>${esc(a.title)}</b>${a.note && a.status === 'rejected' ? `<br><small style="color:#fca5a5">${esc(a.note)}</small>` : ''}</td><td class="muted">${esc(catLabel(a.category))}</td><td>${esc(a.author || '')}</td>
        <td>${stTag(a.status)}</td><td class="muted">${fmtTime(a.published || a.updated)}</td></tr>`).join('')}</table>` : empty('Aucun article.')}</div>`;
    if (box === 'pending') every(15000, () => { if (T.page === 'pending' && !typing()) listPage(T.gen, 'pending'); });
  }
  PAGES.mine = (g) => listPage(g, 'mine');
  PAGES.pending = (g) => listPage(g, 'pending');
  PAGES.published = (g) => listPage(g, 'published');
  PAGES.archives = (g) => listPage(g, 'archived');

  async function openArticle(id) {
    const r = await req('article', { id });
    if (r.error) return toast(r.error, false);
    const a = r.article;
    AS.view = a;
    body().innerHTML = `<div class="toolbar"><button class="btn small" data-back="1">‹ Retour</button><span style="flex:1"></span>
        ${a.canEdit ? '<button class="btn small" data-aa="edit">✎ Modifier</button>' : ''}${a.canSubmit ? '<button class="btn small" data-aa="submit">Soumettre</button>' : ''}
        ${a.canPublish ? '<button class="btn small success" data-aa="publish">Publier</button>' : ''}${a.canReject ? '<button class="btn small" data-aa="reject">Renvoyer à l\'auteur</button>' : ''}
        ${a.canArchive ? `<button class="btn small" data-aa="${a.status === 'archived' ? 'unarchive' : 'archive'}">${a.status === 'archived' ? 'Remettre en ligne' : 'Archiver'}</button>` : ''}
        ${a.canDelete ? '<button class="btn small danger" data-aa="delete">Retirer</button>' : ''}</div>
      <div class="split"><div class="card article-view"><div class="eyebrow">${esc(catLabel(a.category))} · ${stTag(a.status)}</div><h2 style="font-size:1.35rem;margin:.3rem 0">${esc(a.title)}</h2>
        ${a.summary ? `<p class="lead" style="font-weight:600">${esc(a.summary)}</p>` : ''}<div class="text">${esc(a.body)}</div>
        ${(a.media || []).length ? `<div style="margin-top:1rem" class="faint">${a.media.map((m) => `<div>${m.kind === 'video' ? '🎥' : '📷'} ${esc(m.caption)}${m.street ? ` — ${esc(m.street)}` : ''} · ${esc(m.author_name || '')}</div>`).join('')}</div>` : ''}</div>
      <div class="detail"><div class="card"><h2>Informations</h2><div class="kv"><span>Auteur</span><b>${esc(a.author || '')}</b><span>Créé</span><b>${fmtTime(a.created)}</b>
        <span>Modifié</span><b>${fmtTime(a.updated)}</b>${a.submitted ? `<span>Soumis</span><b>${fmtTime(a.submitted)}</b>` : ''}${a.published ? `<span>Publié</span><b>${fmtTime(a.published)}</b>` : ''}
        ${a.reviewer ? `<span>Relecteur</span><b>${esc(a.reviewer)}</b>` : ''}${a.note ? `<span>Note</span><b>${esc(a.note)}</b>` : ''}<span>Version</span><b class="mono">${a.version}</b></div></div>
        ${a.log ? `<div class="card"><h2>Historique</h2><div class="timeline">${a.log.map((h) => `<div><b>${esc(h.action)}</b><small>${esc(h.actor_name || '')} · ${fmtTime(h.t)}${h.details ? ` · ${esc(h.details)}` : ''}</small></div>`).join('') || '<span class="faint">—</span>'}</div></div>` : ''}</div></div>`;
  }
  async function articleAction(a, kind, btn) {
    if (kind === 'edit') return openEditor(a.id);
    if (kind === 'submit') { const r = await call('articleSubmit', { id: a.id }, btn); if (r.ok) openArticle(a.id); return; }
    if (kind === 'publish') {
      if (!(await confirmBox('Publier l\'article ?', `« <b>${esc(a.title)}</b> » sera lisible par toute la ville dans le journal.${can('flash') ? ' Il sera annoncé à tout le serveur (sauf annonce récente).' : ''}`, 'Publier'))) return;
      const r = await call('articlePublish', { id: a.id }, btn); if (r.ok) openArticle(a.id); return;
    }
    if (kind === 'reject') {
      const v = await confirmBox('Renvoyer à l\'auteur ?', 'L\'auteur pourra corriger puis soumettre à nouveau.', 'Renvoyer', false, '<label class="field" style="margin-top:.6rem"><span>Ce qu\'il faut corriger</span><input class="input" data-cfv="note" maxlength="255"></label>');
      if (!v) return;
      const r = await call('articleReject', { id: a.id, note: v.note }, btn); if (r.ok) go('pending'); return;
    }
    if (kind === 'archive' || kind === 'unarchive') { const r = await call('articleArchive', { id: a.id, on: kind === 'archive' }, btn); if (r.ok) openArticle(a.id); return; }
    if (kind === 'delete') {
      const v = await confirmBox('Retirer l\'article ?', 'Il disparaît du journal et de la rédaction (il reste dans l\'historique en base).', 'Retirer', true,
        `<label class="field" style="margin-top:.6rem"><span>Motif${a.mine ? ' (facultatif)' : ' (obligatoire)'}</span><input class="input" data-cfv="reason" maxlength="160"></label>`);
      if (!v) return;
      const r = await call('articleDelete', { id: a.id, reason: v.reason }, btn); if (r.ok) go(a.mine ? 'mine' : 'published');
    }
  }

  /* ------------------------------------------------------------------ */
  /* Interviews                                                          */
  /* ------------------------------------------------------------------ */
  const IS = { all: false };
  PAGES.interviews = async (g) => {
    const d = await req('interviews', { all: IS.all });
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">Une interview se demande avec <span class="kbd">ALT</span> sur la personne (micro sur vous, en service). Elle accepte ou refuse ; elle peut demander l'anonymat et arrêter quand elle veut. Rien n'est enregistré automatiquement : vos notes sont celles que vous écrivez.</div>
      ${d.canAll ? `<div class="toolbar"><button class="btn small ${IS.all ? '' : 'primary'}" data-ivall="0">Mes interviews</button><button class="btn small ${IS.all ? 'primary' : ''}" data-ivall="1">Toute la rédaction</button></div>` : ''}
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>Sujet</th><th>Personne</th><th>Journaliste</th><th>Date</th><th>Notes</th><th></th></tr>${d.list.map((i) => `<tr>
        <td><b>${esc(i.subject)}</b>${i.status === 'active' ? ' <span class="pill on">En cours</span>' : ''}<br><small class="faint">${esc(i.location || '')}</small></td><td>${esc(i.guest || '')}</td><td>${esc(i.journalist || '')}</td>
        <td class="muted">${fmtTime(i.started)}${i.ended ? `<br><small>${esc(i.endReason || '')}</small>` : ''}</td><td>${i.hasNotes ? '✔' : '—'}</td>
        <td style="text-align:right;white-space:nowrap">${i.mine ? `<button class="btn small" data-notes="${i.id}">📝 Notes</button>` : ''}${can('write') ? ` <button class="btn small" data-ivart="${i.id}">Article</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune interview.')}</div>`;
  };
  async function articleFromInterview(id) {
    const r = await req('interviewGet', { id });
    if (r.error) return toast(r.error, false);
    const i = r.interview;
    ED.a = null;
    ED.preset = { title: `Interview : ${i.subject}`.slice(0, lim().titleMax), category: 'interview', interviewId: i.id,
      summary: i.anonymous ? 'Entretien avec une personne ayant souhaité rester anonyme.' : `Entretien avec ${i.guest}.`, body: i.notes || '' };
    T.page = 'write'; renderNav(); setTitle('Rédiger');
    await PAGES.write(T.gen);
  }

  /* ------------------------------------------------------------------ */
  /* Photos et séquences                                                 */
  /* ------------------------------------------------------------------ */
  PAGES.media = async (g) => {
    const d = await req('media', {});
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">Appareil photo ou caméra en main (inventaire › Utiliser), <span class="kbd">G</span> pour le viseur, clic pour déclencher / filmer. Chaque photo ou séquence est une fiche (légende, lieu, heure, durée) à joindre aux articles : aucune image n'est capturée.</div>
      <div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th></th><th>Légende</th><th>Lieu</th><th>Auteur</th><th>Date</th><th></th></tr>${d.list.map((m) => `<tr><td>${m.kind === 'video' ? `🎥<br><small class="faint">${dur(m.seconds)}</small>` : '📷'}</td>
        <td><b>${esc(m.caption)}</b></td><td class="muted">${esc(m.street || '—')}</td><td>${esc(m.author_name || '')}</td><td class="muted">${fmtTime(m.t)}</td>
        <td style="text-align:right;white-space:nowrap">${m.mine ? `<button class="btn small" data-mcap="${m.id}">Légende</button>` : ''}${m.mine || d.canDeleteAll ? ` <button class="btn small danger" data-mdel="${m.id}">Supprimer</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune photo ni séquence.')}</div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Flash info                                                          */
  /* ------------------------------------------------------------------ */
  PAGES.flash = async (g) => {
    const d = await req('flashes');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const F = (APP.cfg && APP.cfg.flash) || { maxLength: 200, titleMax: 60 };
    const kinds = { flash: '⚡ Flash', publish: '📰 Nouvel article', ad: '💬 Annonce' };
    body().innerHTML = `<div class="note">Le flash s'affiche en bandeau chez <b>tous les joueurs</b>. Réservé aux grades autorisés, un flash par rédaction toutes les quelques minutes. À utiliser pour une information importante.</div>
      <div class="split"><div class="card"><h2>Diffuser un flash</h2><div class="form-grid"><label class="field full"><span>Titre (facultatif)</span><input class="input" id="flTitle" maxlength="${F.titleMax}"></label>
        <label class="field full"><span>Message</span><textarea class="input" id="flText" maxlength="${F.maxLength}"></textarea></label></div>
        <div class="actions-row"><button class="btn primary" data-flsend="1" ${d.wait > 0 || d.waitMe > 0 || !(T.st || {}).duty ? 'disabled' : ''}>⚡ Diffuser à tout le serveur</button></div>
        <p class="faint" style="font-size:.78rem;margin-top:.5rem">${!(T.st || {}).duty ? 'Prenez votre service pour diffuser.' : d.wait > 0 ? `Prochain flash de la rédaction possible dans ${d.wait} s.` : d.waitMe > 0 ? `Votre prochain flash est possible dans ${d.waitMe} s.` : 'Disponible.'}</p></div>
      <div class="detail"><div class="card"><h2>Diffusions de la rédaction</h2>${d.list.map((f) => `<div class="list-row"><div class="main"><b>${esc(kinds[f.kind] || f.kind)}${f.title ? ` · ${esc(f.title)}` : ''}</b><small>${esc(f.text)}<br>${esc(f.author_name || '')} · ${fmtTime(f.t)}</small></div></div>`).join('') || empty('Aucune diffusion.')}</div></div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Annonces commandées : tarif à l'unité, primes par grade, commandes   */
  /* ------------------------------------------------------------------ */
  const OST = { active: 'En cours', completed: 'Terminée', cancelled: 'Annulée' };
  PAGES.ads = async (g) => {
    const d = await req('adSettings');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    const M = d.canManage;
    body().innerHTML = `<div class="note">Les entreprises commandent leurs annonces sur leur <b>téléphone de service › Annonce</b> et paient depuis le compte de leur entreprise.
        Les diffusions arrivent dans l'application <b>Planning</b> des journalistes en service (prime ci-dessous) ; sans journaliste en service, elles partent toutes seules (sans prime).
        ${d.system ? '' : '<br><b style="color:#fca5a5">Le système d\'annonces est désactivé par le staff.</b>'}</div>
      <div class="split"><div class="card" style="padding:.3rem .6rem"><h2 style="padding:.6rem .4rem 0">Commandes</h2>${d.orders.length ? `<table class="tbl"><tr><th>Commande</th><th>Client</th><th>Diffusions</th><th>Montant</th><th>Statut</th><th></th></tr>${d.orders.map((o) => `<tr>
        <td><b class="mono" style="font-size:.76rem">${esc(o.uid)}</b><br>${esc(o.text)}<br><small class="faint">${esc(o.freqLabel)} · ${esc(o.start)} → ${esc(o.end)}</small></td>
        <td>${esc(o.client_label || '')}<br><small class="faint">${esc(o.client_name || '')}</small></td>
        <td class="mono">${o.sent} / ${o.slots}</td><td class="mono nw">${money(o.total)}<br><small class="faint">${money(o.unit_price)} / annonce${o.refunded ? ` · ${money(o.refunded)} remboursés` : ''}</small></td>
        <td>${esc(OST[o.status] || o.status)}${o.note ? `<br><small class="faint">${esc(o.note)}</small>` : ''}</td>
        <td style="text-align:right">${M && o.status === 'active' ? `<button class="btn small danger" data-adcancel="${o.id}" data-left="${o.slots - o.sent}" data-unit="${o.unit_price}">Annuler</button>` : ''}</td></tr>`).join('')}</table>` : empty('Aucune commande.')}</div>
      <div class="detail"><div class="card"><h2>Tarif</h2>
        ${M ? `<label class="field"><span>Prix d'une annonce ($)</span><input class="input" type="number" min="0" max="${d.maxPrice}" id="adPrice" value="${d.price}"></label>
          <label class="extra" style="margin-top:.5rem"><input type="checkbox" class="check" id="adOn" ${d.enabled ? 'checked' : ''}> Accepter les commandes</label>`
          : `<div class="kv"><span>Prix</span><b>${money(d.price)} / annonce</b><span>Commandes</span><b>${d.enabled ? 'acceptées' : 'fermées'}</b></div>`}
        <p class="faint" style="font-size:.76rem;margin-top:.5rem">Le client paie <b>nombre de diffusions × prix</b>. Une commande déjà payée garde son prix si vous changez le tarif.</p></div>
        <div class="card"><h2>Prime par diffusion manuelle</h2>${d.grades.map((gr) => `<div class="list-row"><div class="main"><b>${esc(gr.name)}</b><small>Niv. ${gr.level}</small></div>
          ${M ? `<div class="rate"><input class="input" type="number" min="0" data-adcom="${gr.id}" value="${gr.commission}"><span class="faint">$</span></div>` : `<b class="mono">${money(gr.commission)}</b>`}</div>`).join('')}
          <p class="faint" style="font-size:.76rem;margin-top:.5rem">Versée au journaliste qui appuie sur « Envoyer l'annonce », une seule fois, prise sur le compte de la rédaction et plafonnée au prix de l'annonce. Rien pour un envoi automatique.</p>
          ${M ? '<div class="actions-row"><button class="btn primary small" data-adsave="1">Enregistrer</button></div>' : ''}</div></div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Cartes de presse                                                    */
  /* ------------------------------------------------------------------ */
  PAGES.cards = async (g) => {
    const d = await req('cards');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    body().innerHTML = `<div class="note">La carte est un objet nominatif. Montrée (inventaire › Utiliser), elle affiche sa validité vérifiée par le serveur : carte révoquée, titulaire parti ou porteur différent sont signalés. Une nouvelle carte révoque l'ancienne.</div>
      <div class="split"><div class="card" style="padding:.3rem .6rem">${d.list.length ? `<table class="tbl"><tr><th>N°</th><th>Titulaire</th><th>Délivrée</th><th>État</th><th></th></tr>${d.list.map((c) => `<tr>
        <td class="mono" style="font-size:.78rem">${esc(c.number)}</td><td>${esc(c.name || '')}<br><small class="mono faint">${esc(c.matricule || '')}</small></td><td class="muted">${fmtTime(c.t)}<br><small>${esc(c.issued_by || '')}</small></td>
        <td>${c.r ? `<span class="pill bad">Révoquée</span><br><small class="faint">${esc(c.revoke_reason || '')}</small>` : '<span class="pill on">Valide</span>'}</td>
        <td style="text-align:right">${c.r ? '' : `<button class="btn small danger" data-cardrv="${esc(c.number)}">Révoquer</button>`}</td></tr>`).join('')}</table>` : empty('Aucune carte délivrée.')}</div>
      <div class="detail"><div class="card"><h2>Délivrer une carte</h2><label class="field"><span>Employé (connecté)</span><select class="input" id="cardCid">${d.employees.map((e) => `<option value="${esc(e.cid)}" ${e.online ? '' : 'disabled'}>${esc(e.name)} · ${esc(e.matricule)}${e.online ? '' : ' (hors ligne)'}</option>`).join('')}</select></label>
        <div class="actions-row"><button class="btn primary" data-cardnew="1">🪪 Délivrer</button></div></div></div></div>`;
  };

  /* ------------------------------------------------------------------ */
  /* Locaux : points, présentoirs, véhicules, tenues                     */
  /* ------------------------------------------------------------------ */
  const SU = { data: null };
  PAGES.setup = async (g) => {
    const d = await req('pointsSettings');
    if (stale(g)) return;
    if (d.error) { body().innerHTML = empty(d.error); return; }
    SU.data = d;
    const s = d.settings, pt = (p) => (p ? `<span class="mono faint">${p.x.toFixed(1)}, ${p.y.toFixed(1)}</span>` : '<span class="pill warn">Non placé</span>');
    body().innerHTML = `<div class="note">Placez-vous à l'endroit voulu (fermez la tablette, déplacez-vous, rouvrez-la), puis « Placer ici ». Rien n'est placé d'office : choisissez vous-même l'emplacement de la rédaction sur la carte.</div>
      <div class="cols"><div>
        <div class="card"><h2>Points de la rédaction</h2>${Object.entries(d.kinds).map(([k, l]) => `<div class="list-row"><div class="main"><b>${esc(l)}</b><small>${pt(s[k])}${k === 'spawn' ? ' · au volant, orienté vers la sortie' : ''}</small></div>
          <button class="btn small primary" data-pset="${k}">Placer ici</button>${s[k] ? ` <button class="btn small danger" data-pdel="${k}">Retirer</button>` : ''}</div>`).join('')}</div>
        <div class="card"><h2>Présentoirs du journal (tout le monde) <span class="faint" style="font-size:.8rem">${s.kiosks.length} / ${d.maxKiosks}</span></h2>
          ${s.kiosks.map((k, i) => `<div class="list-row"><div class="main"><b>${esc(k.label)}</b><small class="mono">${k.x.toFixed(1)}, ${k.y.toFixed(1)}</small></div><button class="btn small danger" data-kdel="${i + 1}">Retirer</button></div>`).join('') || empty('Aucun présentoir.')}
          <div class="actions-row"><input class="input" id="kLabel" maxlength="40" placeholder="Nom (ex : Kiosque de Legion Square)" style="flex:1"><button class="btn small primary" data-kadd="1">Placer ici</button></div></div>
      </div><div>
        <div class="card"><h2>Tenues du vestiaire</h2><p class="faint" style="font-size:.78rem;margin-bottom:.5rem">Habillez-vous (boutique de vêtements), puis enregistrez votre tenue actuelle pour le sexe de votre personnage.</p>
          ${d.outfits.map((o) => `<div class="list-row"><div class="main"><b>${esc(o.label)}</b><small>grade ${o.minLevel}+ · homme ${o.male ? '✔' : '—'} · femme ${o.female ? '✔' : '—'}</small></div>
            <button class="btn small primary" data-ocap="${esc(o.id)}">Enregistrer ma tenue</button>${o.male ? ` <button class="btn small" data-oclr="${esc(o.id)}" data-sex="male">Effacer H</button>` : ''}${o.female ? ` <button class="btn small" data-oclr="${esc(o.id)}" data-sex="female">Effacer F</button>` : ''}</div>`).join('')}</div>
        <div class="card"><h2>Véhicules de service</h2><table class="tbl" id="vehTbl"><tr><th>Modèle</th><th>Nom</th><th>Grade min.</th><th>Type</th></tr>
          ${s.vehicles.map((v) => `<tr><td><input class="input" data-vm value="${esc(v.model)}"></td><td><input class="input" data-vl value="${esc(v.label)}"></td>
            <td><input class="input" type="number" min="0" max="99" data-vg value="${v.minLevel}"></td><td><select class="input" data-vt>${['automobile', 'heli', 'bike', 'boat', 'plane'].map((t) => `<option ${v.type === t ? 'selected' : ''}>${t}</option>`).join('')}</select></td></tr>`).join('')}
          <tr><td><input class="input" data-vm placeholder="nouveau modèle"></td><td><input class="input" data-vl></td><td><input class="input" type="number" min="0" max="99" data-vg value="1"></td><td><select class="input" data-vt><option>automobile</option><option>heli</option><option>bike</option><option>boat</option><option>plane</option></select></td></tr></table>
          <div class="actions-row"><button class="btn primary small" data-vsave="1">Enregistrer les véhicules</button></div>
          <p class="faint" style="font-size:.76rem;margin-top:.4rem">Vide le nom du modèle pour retirer une ligne. Vérifiez que chaque modèle existe sur le serveur.</p></div>
      </div></div>`;
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
          ${p.target.already ? '<p style="color:#fca5a5;font-size:.84rem;margin-top:.6rem">Cette personne fait déjà partie de la rédaction.</p>' : ''}
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
        <span>Articles publiés</span><b>${e.articles || 0}</b><span>Interviews</span><b>${e.interviews || 0}</b><span>Note</span><b>${esc(e.note || '—')}</b></div>
      ${e.canAct ? `<div class="actions-row">
        ${can('promote') ? `<button class="btn success small" data-ea="up" ${s.up ? '' : 'disabled'}>▲ Promouvoir</button>` : ''}
        ${can('demote') ? `<button class="btn small" data-ea="down" ${s.down ? '' : 'disabled'}>▼ Rétrograder</button>` : ''}
        ${can('promote') || can('demote') ? '<button class="btn small" data-ea="change">Changer de grade</button>' : ''}
        ${can('employees_edit') ? '<button class="btn small" data-ea="edit">✎ Modifier</button>' : ''}
        ${can('fire') ? '<button class="btn danger small" data-ea="fire">Retirer de la rédaction</button>' : ''}</div>`
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
          <label class="field full"><span>Nom</span><input class="input" id="gName" maxlength="50" value="${esc(ed ? ed.name : '')}" placeholder="ex : Photographe"></label>
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
    const income = sm('in:ad').total;
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
        <div class="cols even"><div class="card"><h2>Détail sur 7 jours</h2><div class="kv"><span>Annonces vendues</span><b class="mono">+${money(sm('in:ad').total)} <span class="faint">(${sm('in:ad').n})</span></b>
            <span>Salaires</span><b class="mono">−${money(sm('out:salary').total)} <span class="faint">(${sm('out:salary').n})</span></b><span>Commissions</span><b class="mono">−${money(sm('out:commission').total)} <span class="faint">(${sm('out:commission').n})</span></b><span>Remboursements</span><b class="mono">−${money(sm('out:refund').total)}</b></div></div>
          <div class="card"><h2>Depuis l'ouverture</h2><div class="kv"><span>Annonces vendues</span><b class="mono">${money(al('in:ad').total)} <span class="faint">(${al('in:ad').n})</span></b>
            <span>Salaires versés</span><b class="mono">${money(al('out:salary').total)}</b><span>Commissions</span><b class="mono">${money(al('out:commission').total)}</b><span>Remboursements</span><b class="mono">${money(al('out:refund').total)}</b></div></div></div></div></div>
      </div><div class="detail">
        <div class="card"><h2>Taux horaire et commission</h2>${grades}<p class="faint" style="font-size:.74rem;margin-top:.5rem">$/h : salaire par heure de service. % : commission sur les annonces payantes vendues, versée par la rédaction. Appliqué à partir de maintenant.</p></div>
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
      if (!(await confirmBox('Changer la commission ?', `<b>${esc(gr ? gr.name : '')}</b> : ${gr ? gr.commission || 0 : 0} % → <b>${pct} %</b> sur les annonces vendues.<br>Versée depuis le compte de la rédaction à chaque encaissement, à partir de maintenant.`, 'Appliquer'))) return;
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
  $('#tabNav').addEventListener('click', (e) => { const b = e.target.closest('[data-nav]'); if (b) { if (b.dataset.nav === 'write') { ED.a = null; ED.preset = null; } go(b.dataset.nav); } });
  $('#tabClose').addEventListener('click', () => post('close', { ui: 'tablet' }));

  body().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || e.target.tagName === 'TEXTAREA') return;
    const t = e.target;
    if (t.dataset.hq !== undefined) { HS.q = t.value; return go('history'); }
    if (t.id === 'tq') { TS.q = t.value; return go('transactions'); }
    if (t.id === 'aq') { AS.q = t.value; return go(T.page); }
  });
  body().addEventListener('change', (e) => {
    const t = e.target;
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
    if (t.id === 'edBody') { const c = $('#edCount'); if (c) c.textContent = `${t.value.length} / ${lim().bodyMax}`; return; }
    const keep = (sel, fn) => { const pos = t.selectionStart; fn(); const n = body().querySelector(sel); if (n) { n.focus(); n.setSelectionRange(pos, pos); } };
    if (t.dataset.ef === 'q') { ES.f.q = t.value; return keep('[data-ef="q"]', drawEmployees); }
  });

  body().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-q]'))) { if (b.dataset.q === 'write') { ED.a = null; ED.preset = null; } return go(b.dataset.q); }
    if ((b = e.target.closest('[data-notes]'))) return post('openNotes', { id: Number(b.dataset.notes) });
    // Rédaction
    if ((b = e.target.closest('[data-ed]'))) {
      const a = b.dataset.ed;
      if (a === 'new') { ED.a = null; ED.preset = null; return drawEditor(); }
      const r = await call('articleSave', editorData(), b);
      if (r.error) return;
      const id = r.id;
      if (a === 'submit') { const s = await call('articleSubmit', { id }, b); if (s.ok) return go('mine'); }
      if (a === 'publish') {
        if (!(await confirmBox('Publier l\'article ?', 'Il sera lisible par toute la ville dans le journal.', 'Publier'))) return openEditor(id);
        const p = await call('articlePublish', { id }, b); if (p.ok) return go('published');
      }
      return openEditor(id);
    }
    if ((b = e.target.closest('[data-asearch]'))) { AS.q = ($('#aq') || {}).value || ''; return go(T.page); }
    if ((b = e.target.closest('[data-back]'))) return go(T.page, true);
    if ((b = e.target.closest('[data-aa]'))) return articleAction(AS.view, b.dataset.aa, b);
    if ((b = e.target.closest('[data-art]'))) return openArticle(Number(b.dataset.art));
    // Interviews et médias
    if ((b = e.target.closest('[data-ivall]'))) { IS.all = b.dataset.ivall === '1'; return go('interviews'); }
    if ((b = e.target.closest('[data-ivart]'))) return articleFromInterview(Number(b.dataset.ivart));
    if ((b = e.target.closest('[data-mcap]'))) {
      const v = await confirmBox('Légende', '', 'Enregistrer', false, '<input class="input" data-cfv="caption" maxlength="160">');
      if (!v) return;
      const r = await call('mediaCaption', { id: Number(b.dataset.mcap), caption: v.caption }); if (r.ok) go('media'); return;
    }
    if ((b = e.target.closest('[data-mdel]'))) {
      if (!(await confirmBox('Supprimer ce média ?', 'Il disparaît aussi des articles où il était joint.', 'Supprimer', true))) return;
      const r = await call('mediaDelete', { id: Number(b.dataset.mdel) }, b); if (r.ok) go('media'); return;
    }
    // Flash
    if ((b = e.target.closest('[data-flsend]'))) {
      const title = $('#flTitle').value, text = $('#flText').value;
      if (!(await confirmBox('Diffuser à tout le serveur ?', `<b>${esc(title || 'Flash info')}</b><br>${esc(text)}`, 'Diffuser'))) return;
      const r = await call('flashSend', { title, text }, b); if (r.ok) go('flash'); return;
    }
    // Annonces
    if ((b = e.target.closest('[data-adsave]'))) {
      const commissions = {};
      body().querySelectorAll('[data-adcom]').forEach((i) => { commissions[i.dataset.adcom] = Number(i.value) || 0; });
      const r = await call('adSettingsSave', { price: Number($('#adPrice').value), enabled: $('#adOn').checked, commissions }, b); if (r.ok) go('ads'); return;
    }
    if ((b = e.target.closest('[data-adcancel]'))) {
      const left = Number(b.dataset.left), unit = Number(b.dataset.unit);
      const v = await confirmBox('Annuler la commande ?', `Les diffusions pas encore faites sont annulées et remboursées au client depuis le compte de la rédaction (environ <b>${money(left * unit)}</b>). Les diffusions déjà faites restent payées.`, 'Annuler et rembourser', true,
        '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="120"></label>');
      if (!v) return;
      const r = await call('adOrderCancel', { id: Number(b.dataset.adcancel), reason: v.reason }, b); if (r.ok) go('ads'); return;
    }
    // Cartes
    if ((b = e.target.closest('[data-cardnew]'))) { const r = await call('cardIssue', { cid: $('#cardCid').value }, b); if (r.ok) go('cards'); return; }
    if ((b = e.target.closest('[data-cardrv]'))) {
      const v = await confirmBox('Révoquer la carte ?', 'Elle s\'affichera « invalide » à chaque présentation.', 'Révoquer', true, '<label class="field" style="margin-top:.6rem"><span>Motif</span><input class="input" data-cfv="reason" maxlength="120"></label>');
      if (!v) return;
      const r = await call('cardRevoke', { number: b.dataset.cardrv, reason: v.reason }, b); if (r.ok) go('cards'); return;
    }
    // Locaux
    if ((b = e.target.closest('[data-pset],[data-pdel]'))) { const r = await call('pointSet', { kind: b.dataset.pset || b.dataset.pdel, remove: !!b.dataset.pdel }, b); if (r.ok) go('setup'); return; }
    if ((b = e.target.closest('[data-kadd]'))) { const r = await call('kioskAdd', { label: $('#kLabel').value }, b); if (r.ok) go('setup'); return; }
    if ((b = e.target.closest('[data-kdel]'))) { const r = await call('kioskRemove', { i: Number(b.dataset.kdel) }, b); if (r.ok) go('setup'); return; }
    if ((b = e.target.closest('[data-ocap]'))) {
      if (!(await confirmBox('Enregistrer cette tenue ?', 'Les vêtements que vous portez deviennent cette tenue du vestiaire (pour le sexe de votre personnage).', 'Enregistrer'))) return;
      b.classList.add('loading');
      const r = await post('outfitCapture', { id: b.dataset.ocap });
      b.classList.remove('loading');
      if (r.error) toast(r.error, false); else { toast(r.message, true); go('setup'); }
      return;
    }
    if ((b = e.target.closest('[data-oclr]'))) { const r = await call('outfitClear', { id: b.dataset.oclr, sex: b.dataset.sex }, b); if (r.ok) go('setup'); return; }
    if ((b = e.target.closest('[data-vsave]'))) {
      const rows = [...body().querySelectorAll('#vehTbl tr')].slice(1);
      const vehicles = rows.map((tr) => ({ model: tr.querySelector('[data-vm]').value.trim(), label: tr.querySelector('[data-vl]').value.trim(), minLevel: Number(tr.querySelector('[data-vg]').value), type: tr.querySelector('[data-vt]').value })).filter((v) => v.model);
      const r = await call('garageVehicles', { vehicles }, b); if (r.ok) go('setup'); return;
    }
    // Démission
    if (e.target.closest('[data-resign]')) {
      if (!(await confirmBox('Quitter la rédaction ?', 'Vous perdrez votre grade et vos accès. Cette action est immédiate.', 'Quitter', true))) return;
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
        if (!(await confirmBox('Envoyer la demande ?', `<b>${esc(p.target.name)}</b> recevra une proposition pour rejoindre la rédaction au grade <b>${esc(gr ? gr.name : '')}</b>.`, 'Envoyer'))) return;
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
        const v = await confirmBox('Retirer de la rédaction ?', `<b>${esc(emp.name)}</b> (${esc(emp.grade)}) perdra son métier et ses accès.${emp.unpaidAmount > 0 ? `<br><b style="color:#fcd34d">${money(emp.unpaidAmount)} de salaire non payé</b> : payez-le d'abord dans Finance.` : ''}`, 'Retirer', true,
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
    if (o.page) { if (o.page === 'write') { ED.a = null; ED.preset = null; } go(o.page); return true; }
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
      if (AS.view) { AS.view = null; go(T.page, true); return true; }
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
