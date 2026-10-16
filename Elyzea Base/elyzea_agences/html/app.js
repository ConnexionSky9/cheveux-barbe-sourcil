/* =====================================================================
   ELYZEA AGENCES - panneau staff
   · Liste des agences par métier, fiche (nom, métier, matricules, téléphone,
     couleur), nomination du directeur, suppression.
   · Carte satellite : zones d'alerte de toutes les agences du métier.
     Dessin : clic = un coin, « Fermer la forme » (ou double-clic) pour finir,
     plusieurs formes possibles, gomme pour en retirer une.
     Hors dessin : clic = « qui reçoit une alerte ici ? ».
   ===================================================================== */
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_agences';
  const $ = (s) => document.querySelector(s);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  async function post(name, body) {
    try {
      const r = await fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
      return await r.json();
    } catch (e) { return { error: 'Interface indisponible.' }; }
  }
  const req = (action, data) => post('req', { action, data });

  function toast(msg, kind) {
    if (!msg) return;
    const t = document.createElement('div');
    t.className = `toast ${kind || ''}`;
    t.textContent = msg;
    $('#toasts').appendChild(t);
    setTimeout(() => t.remove(), 4200);
  }
  function show(r) { if (r && r.error) toast(r.error, 'error'); else if (r && r.message) toast(r.message, 'success'); return r && !r.error; }

  const S = { data: null, kind: null, sel: null, mode: 'view', draft: null, route: null, me: null };

  const kindObj = () => (S.data ? S.data.kinds.find((k) => k.id === S.kind) : null);
  const agencies = () => (kindObj() ? kindObj().agencies : []);
  const selected = () => agencies().find((a) => a.id === S.sel) || null;

  /* ------------------------------------------------------------------
     Carte
     ------------------------------------------------------------------ */
  const BOUNDS = { minX: -4200, maxX: 4600, minY: -4200, maxY: 8200 };
  const M = { cx: 0, cy: 1800, scale: 0.05, img: null, W: 0, H: 0, dpr: 1, hover: null };
  const box = $('#map');
  const canvas = document.createElement('canvas');
  box.appendChild(canvas);
  const ctx = canvas.getContext('2d');

  function resize() {
    const r = box.getBoundingClientRect();
    M.dpr = window.devicePixelRatio || 1; M.W = r.width; M.H = r.height;
    canvas.width = Math.max(1, M.W * M.dpr); canvas.height = Math.max(1, M.H * M.dpr);
  }
  function fit() {
    resize();
    M.scale = Math.min(M.W / (BOUNDS.maxX - BOUNDS.minX), M.H / (BOUNDS.maxY - BOUNDS.minY)) * 0.95;
    M.cx = (BOUNDS.minX + BOUNDS.maxX) / 2; M.cy = (BOUNDS.minY + BOUNDS.maxY) / 2;
  }
  const sx = (x) => (x - M.cx) * M.scale + M.W / 2;
  const sy = (y) => -(y - M.cy) * M.scale + M.H / 2;
  const wx = (px) => (px - M.W / 2) / M.scale + M.cx;
  const wy = (py) => -(py - M.H / 2) / M.scale + M.cy;

  function hexA(hex, a) {
    const h = (hex || '#3b82f6').replace('#', '');
    return `rgba(${parseInt(h.slice(0, 2), 16)},${parseInt(h.slice(2, 4), 16)},${parseInt(h.slice(4, 6), 16)},${a})`;
  }
  function path(pts, close) {
    ctx.beginPath();
    pts.forEach((p, i) => (i ? ctx.lineTo(sx(p.x), sy(p.y)) : ctx.moveTo(sx(p.x), sy(p.y))));
    if (close) ctx.closePath();
  }
  function centroid(pts) {
    let x = 0, y = 0;
    pts.forEach((p) => { x += p.x; y += p.y; });
    return { x: x / pts.length, y: y / pts.length };
  }
  function inPoly(pts, x, y) {
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const xi = pts[i].x, yi = pts[i].y, xj = pts[j].x, yj = pts[j].y;
      if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / ((yj - yi) || 0.0001) + xi) inside = !inside;
    }
    return inside;
  }

  function drawZone(polys, color, strong, label) {
    polys.forEach((pts) => {
      if (pts.length < 3) return;
      path(pts, true);
      ctx.fillStyle = hexA(color, strong ? 0.3 : 0.16); ctx.fill();
      ctx.lineWidth = strong ? 2.6 : 1.6; ctx.strokeStyle = hexA(color, strong ? 1 : 0.75); ctx.stroke();
      if (label) {
        const c = centroid(pts);
        ctx.save();
        ctx.font = `700 ${strong ? 13 : 11}px Inter, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
        ctx.shadowColor = 'rgba(0,0,0,.9)'; ctx.shadowBlur = 4; ctx.fillStyle = '#fff';
        ctx.fillText(label, sx(c.x), sy(c.y));
        ctx.restore();
      }
    });
  }

  function frame() {
    ctx.setTransform(M.dpr, 0, 0, M.dpr, 0, 0);
    ctx.fillStyle = '#143d6b'; ctx.fillRect(0, 0, M.W, M.H);
    const b = S.data && S.data.map;
    if (M.img && b) {
      ctx.imageSmoothingQuality = 'high';
      ctx.drawImage(M.img, sx(b.minX), sy(b.maxY), (b.maxX - b.minX) * M.scale, (b.maxY - b.minY) * M.scale);
    }
    const sel = selected();
    agencies().forEach((a) => {
      if (S.draft && sel && a.id === sel.id) return;
      drawZone(a.zone.polys || [], a.color, sel && a.id === sel.id, a.short || a.label);
    });
    if (S.draft && sel) {
      drawZone(S.draft.polys, sel.color, true, sel.short || sel.label);
      const cur = S.draft.cur;
      if (cur.length) {
        path(cur, false);
        ctx.lineWidth = 2.5; ctx.strokeStyle = '#fff'; ctx.setLineDash([6, 4]); ctx.stroke(); ctx.setLineDash([]);
        if (M.hover && S.mode === 'draw') {
          const l = cur[cur.length - 1];
          ctx.beginPath(); ctx.moveTo(sx(l.x), sy(l.y)); ctx.lineTo(sx(M.hover.x), sy(M.hover.y));
          ctx.strokeStyle = 'rgba(255,255,255,.55)'; ctx.lineWidth = 1.5; ctx.stroke();
          if (cur.length >= 2) {
            ctx.beginPath(); ctx.moveTo(sx(M.hover.x), sy(M.hover.y)); ctx.lineTo(sx(cur[0].x), sy(cur[0].y));
            ctx.strokeStyle = 'rgba(255,255,255,.25)'; ctx.stroke();
          }
        }
        cur.forEach((p, i) => {
          ctx.beginPath(); ctx.arc(sx(p.x), sy(p.y), i === 0 ? 6 : 4.5, 0, Math.PI * 2);
          ctx.fillStyle = i === 0 ? sel.color : '#fff'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#0b1220'; ctx.stroke();
        });
      }
    }
    // Ma position
    if (S.me) {
      ctx.beginPath(); ctx.arc(sx(S.me.x), sy(S.me.y), 5, 0, Math.PI * 2);
      ctx.fillStyle = '#facc15'; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#0b1220'; ctx.stroke();
    }
    // Test d'alerte
    if (S.route) {
      const x = sx(S.route.x), y = sy(S.route.y);
      ctx.save(); ctx.translate(x, y); ctx.rotate(Math.PI / 4);
      ctx.fillStyle = '#fb923c'; ctx.strokeStyle = '#0b1220'; ctx.lineWidth = 2;
      ctx.fillRect(-6, -6, 12, 12); ctx.strokeRect(-6, -6, 12, 12); ctx.restore();
    }
    requestAnimationFrame(frame);
  }

  // Déplacement (glisser) / zoom (molette) / clic
  let drag = null;
  canvas.addEventListener('mousedown', (e) => {
    if (e.button === 2) return;
    drag = { x: e.clientX, y: e.clientY, cx: M.cx, cy: M.cy, moved: false };
  });
  window.addEventListener('mousemove', (e) => {
    const r = canvas.getBoundingClientRect();
    M.hover = { x: wx(e.clientX - r.left), y: wy(e.clientY - r.top) };
    if (!drag) return;
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.abs(dx) + Math.abs(dy) > 4) { drag.moved = true; box.classList.add('grab'); }
    if (drag.moved) { M.cx = drag.cx - dx / M.scale; M.cy = drag.cy + dy / M.scale; }
  });
  window.addEventListener('mouseup', (e) => {
    if (!drag) return;
    const moved = drag.moved;
    drag = null; box.classList.remove('grab');
    if (!moved && e.target === canvas) click(e);
  });
  canvas.addEventListener('dblclick', (e) => { e.preventDefault(); if (S.mode === 'draw') closeShape(); });
  canvas.addEventListener('contextmenu', (e) => { e.preventDefault(); if (S.mode === 'draw' && S.draft && S.draft.cur.length) { S.draft.cur.pop(); renderTools(); } });
  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    const f = e.deltaY < 0 ? 1.25 : 0.8;
    const bx = wx(e.offsetX), by = wy(e.offsetY);
    M.scale = Math.min(2.5, Math.max(0.02, M.scale * f));
    M.cx = bx - (e.offsetX - M.W / 2) / M.scale; M.cy = by + (e.offsetY - M.H / 2) / M.scale;
  }, { passive: false });
  new ResizeObserver(() => resize()).observe(box);

  async function click(e) {
    const r = canvas.getBoundingClientRect();
    const x = Math.round(wx(e.clientX - r.left) * 10) / 10, y = Math.round(wy(e.clientY - r.top) * 10) / 10;
    if (S.mode === 'draw') {
      const lim = S.data.limits || { points: 120 };
      if (S.draft.cur.length >= lim.points) return toast(`${lim.points} coins maximum par forme.`, 'error');
      // Clic sur le premier coin : la forme se ferme
      if (S.draft.cur.length >= 3) {
        const f = S.draft.cur[0];
        if (Math.hypot(sx(f.x) - (e.clientX - r.left), sy(f.y) - (e.clientY - r.top)) < 10) return closeShape();
      }
      // Même endroit que le coin précédent (double-clic) : ignoré
      const l = S.draft.cur[S.draft.cur.length - 1];
      if (l && Math.hypot(sx(l.x) - (e.clientX - r.left), sy(l.y) - (e.clientY - r.top)) < 4) return;
      S.draft.cur.push({ x, y });
      return renderTools();
    }
    if (S.mode === 'erase') {
      const i = S.draft.polys.findIndex((p) => inPoly(p, x, y));
      if (i < 0) return toast('Clique à l\'intérieur de la forme à retirer.', 'error');
      S.draft.polys.splice(i, 1);
      return renderTools();
    }
    const res = await req('route', { kind: S.kind, x, y });
    if (res.error) return toast(res.error, 'error');
    S.route = { x, y, names: res.names || [] };
    renderTools();
  }

  /* ------------------------------------------------------------------
     Dessin
     ------------------------------------------------------------------ */
  function startDraw() {
    const a = selected();
    if (!a) return;
    S.draft = { polys: JSON.parse(JSON.stringify(a.zone.polys || [])), cur: [] };
    S.mode = 'draw'; S.route = null;
    renderAll();
  }
  function closeShape() {
    if (!S.draft || S.draft.cur.length < 3) return toast('Pose au moins 3 coins.', 'error');
    const lim = S.data.limits || { polygons: 12 };
    if (S.draft.polys.length >= lim.polygons) return toast(`${lim.polygons} formes maximum par agence.`, 'error');
    S.draft.polys.push(S.draft.cur);
    S.draft.cur = [];
    renderTools();
  }
  function stopDraw() { S.draft = null; S.mode = 'view'; renderAll(); }
  async function saveDraw() {
    const a = selected();
    if (!a || !S.draft) return;
    if (S.draft.cur.length >= 3) closeShape();
    else if (S.draft.cur.length) return toast('Ferme d\'abord la forme en cours (3 coins minimum) ou retire ses coins (clic droit).', 'error');
    const r = await req('zone', { id: a.id, zone: { polys: S.draft.polys } });
    if (!show(r)) return;
    S.draft = null; S.mode = 'view';
    await reload();
  }

  /* ------------------------------------------------------------------
     Rendu
     ------------------------------------------------------------------ */
  function renderKinds() {
    $('#kinds').innerHTML = S.data.kinds.map((k) => `<button class="kind ${k.id === S.kind ? 'on' : ''}" data-kind="${esc(k.id)}">${esc(k.icon)} ${esc(k.label)}<span class="n">${k.agencies.length}</span></button>`).join('');
  }
  function renderList() {
    const k = kindObj();
    const list = agencies();
    $('#list').innerHTML = (!k.started ? `<div class="empty">Ressource <b>${esc(k.res)}</b> arrêtée : les agences ne sont pas actives.</div>` : '')
      + (list.length ? list.map((a) => `<button class="ag ${a.id === S.sel ? 'on' : ''}" data-ag="${a.id}">
          <span class="dot" style="background:${esc(a.color)}"></span>
          <span><b>${esc(a.label)}</b><small class="mono">${esc(a.job)} · ${esc(a.phone)}-XXXX</small></span>
          <span class="z ${a.hasZone ? 'yes' : ''}">${a.hasZone ? 'Zone' : 'Sans zone'}</span></button>`).join('')
        : '<div class="empty">Aucune agence.</div>');
  }
  function renderTools() {
    const a = selected();
    const k = kindObj();
    let tools = '', hint = '';
    if (S.mode === 'draw' || S.mode === 'erase') {
      const n = S.draft.cur.length;
      tools = `<button class="btn ${S.mode === 'draw' ? 'primary' : ''}" data-t="draw">✏️ Dessiner</button>
        <button class="btn" data-t="close" ${n < 3 ? 'disabled' : ''}>⬠ Fermer la forme</button>
        <button class="btn" data-t="undo" ${n ? '' : 'disabled'}>↶ Dernier coin</button>
        <button class="btn ${S.mode === 'erase' ? 'primary' : ''}" data-t="erase" ${S.draft.polys.length ? '' : 'disabled'}>🧽 Retirer une forme</button>
        <button class="btn danger" data-t="clear" ${S.draft.polys.length || n ? '' : 'disabled'}>Tout effacer</button>
        <span class="sep"></span>
        <button class="btn" data-t="cancel">Annuler</button>
        <button class="btn success" data-t="save">✔ Enregistrer la zone</button>`;
      hint = S.mode === 'erase' ? '<b>Gomme</b> : clique dans une forme pour la retirer.'
        : `<b>Dessin de la zone de ${esc(a.label)}</b> · clic gauche = un coin (${n} posé${n > 1 ? 's' : ''}), clic droit = retirer le dernier, double-clic ou clic sur le premier coin = fermer la forme. Glisser pour déplacer la carte, molette pour zoomer. ${S.draft.polys.length} forme(s) fermée(s).`;
    } else {
      tools = `<button class="btn" data-t="fit">⤢ Toute la carte</button>${S.me ? '<button class="btn" data-t="me">◎ Ma position</button>' : ''}
        <span class="sep"></span>
        ${a && k.alerts ? '<button class="btn primary" data-t="start">✏️ Dessiner la zone sur la carte</button><button class="btn" data-t="world">🧭 Dessiner en jeu</button>' : ''}`;
      if (!k.alerts) hint = `<b>${esc(k.label)}</b> ne reçoit pas d'alertes du public : la zone n'est pas utilisée pour ce métier.`;
      else if (S.route) hint = `Une alerte à cet endroit irait à : <b>${S.route.names.length ? S.route.names.map(esc).join(', ') : 'personne'}</b>.`;
      else hint = 'Clique sur la carte pour voir quelle agence recevrait une alerte à cet endroit. Les agences <b>sans zone</b> reçoivent les alertes qui ne tombent dans aucune zone'
        + (S.data.outside === 'all' ? ' ; si toutes ont une zone, l\'alerte va à toutes.' : ' ; si toutes ont une zone, l\'alerte va à l\'agence la plus proche.');
    }
    $('#maptools').innerHTML = tools;
    $('#hint').innerHTML = hint;
  }
  function renderDetail() {
    const k = kindObj();
    const a = S.sel === 'new' ? null : selected();
    const isNew = S.sel === 'new';
    if (!isNew && !a) { $('#detail').innerHTML = '<div class="empty">Choisis une agence ou crée-en une nouvelle.</div>'; return; }
    const v = a || { label: '', short: '', job: '', mat: '', phone: '', color: '#3b82f6' };
    const st = a && a.stats;
    $('#detail').innerHTML = `
      <div class="card"><h3>${isNew ? `Nouvelle agence · ${esc(k.label)}` : `<span class="dot" style="background:${esc(v.color)}"></span>${esc(v.label)}`}</h3>
        ${st ? `<div class="stats"><div class="stat"><b>${st.employees ?? 0}</b><span>employés</span></div><div class="stat"><b>${st.duty ?? 0}</b><span>en service</span></div><div class="stat"><b>${st.grades ?? 0}</b><span>grades</span></div></div>` : ''}
        <label class="field"><span>Nom de l'agence</span><input class="input" id="f-label" maxlength="60" value="${esc(v.label)}" placeholder="ex. Blaine County Sheriff"></label>
        <div class="row2">
          <label class="field"><span>Nom court</span><input class="input" id="f-short" maxlength="12" value="${esc(v.short)}" placeholder="ex. BCSO"></label>
          <label class="field"><span>Couleur</span><input class="input" type="color" id="f-color" value="${esc(v.color)}"></label>
        </div>
        <label class="field"><span>Métier (elyzea_core)</span><input class="input mono" id="f-job" maxlength="30" value="${esc(v.job)}" ${isNew ? '' : 'disabled'} placeholder="ex. bcso">
          <small>${isNew ? 'Minuscules, chiffres ou _. Ne peut plus être changé ensuite : c\'est aussi le compte de société.' : 'Compte de société : <span class="mono">' + esc(v.job) + '</span>'}</small></label>
        <div class="row2">
          <label class="field"><span>Préfixe matricule</span><input class="input mono" id="f-mat" maxlength="8" value="${esc(v.mat)}" placeholder="BCSO-"></label>
          <label class="field"><span>Téléphone de service</span><input class="input mono" id="f-phone" maxlength="3" value="${esc(v.phone)}" placeholder="921"><small>Numéros pro : ${esc(v.phone || 'XXX')}-XXXX</small></label>
        </div>
        <button class="btn primary block" data-d="save">${isNew ? 'Créer l\'agence' : 'Enregistrer'}</button>
        ${isNew ? '<p>Grades par défaut, métier et compte de société sont créés automatiquement. Ensuite : dessine sa zone et nomme son directeur.</p>' : ''}
      </div>
      ${a ? `
      <div class="card"><h3>Zone d'alerte</h3>
        <p>${!k.alerts ? 'Ce métier ne reçoit pas d\'alertes du public.' : a.hasZone ? `${a.zone.polys.length} forme(s) dessinée(s). Les alertes dans cette zone vont uniquement à ${esc(a.label)}.` : 'Aucune zone : cette agence reçoit les alertes qui ne tombent dans la zone d\'aucune autre agence.'}</p>
        ${k.alerts ? `<div class="inline"><button class="btn small" data-d="draw">✏️ Sur la carte</button><button class="btn small" data-d="world">🧭 En jeu</button>${a.hasZone ? '<button class="btn small danger" data-d="clearzone">Effacer</button>' : ''}</div>` : ''}
      </div>
      <div class="card"><h3>Nommer le directeur</h3>
        <p>Donne le plus haut grade de ${esc(a.label)} à un joueur connecté (ID serveur). Il recrute ensuite lui-même depuis sa tablette.</p>
        <div class="inline"><input class="input" id="f-target" type="number" min="1" placeholder="ID du joueur"><button class="btn" data-d="appoint">Nommer</button></div>
      </div>
      <div class="card"><h3>Supprimer l'agence</h3>
        <p>Les employés sont retirés du métier et les grades supprimés. Rapports, dossiers et argent du compte sont conservés.</p>
        <div class="inline"><input class="input mono" id="f-confirm" placeholder="${esc(a.job)}"><button class="btn danger" data-d="delete">Supprimer</button></div>
      </div>` : ''}`;
  }
  function renderAll() { renderKinds(); renderList(); renderTools(); renderDetail(); }

  async function reload() {
    const r = await req('data');
    if (r.error) return toast(r.error, 'error');
    setData(r);
  }
  function setData(d) {
    S.data = d;
    if (!S.kind || !d.kinds.find((k) => k.id === S.kind)) S.kind = d.kinds[0] && d.kinds[0].id;
    if (S.sel !== 'new' && !selected()) S.sel = agencies()[0] ? agencies()[0].id : null;
    if (!M.img && d.map && d.map.file) { const im = new Image(); im.onload = () => { M.img = im; }; im.src = d.map.file; }
    renderAll();
  }

  /* ------------------------------------------------------------------
     Événements
     ------------------------------------------------------------------ */
  const busy = () => S.mode !== 'view';
  document.addEventListener('click', async (e) => {
    const t = e.target.closest('[data-kind],[data-ag],[data-t],[data-d],#new,#close');
    if (!t) return;
    if (t.id === 'close') return close();
    if ((t.dataset.kind || t.dataset.ag || t.id === 'new') && busy()) return toast('Termine ou annule d\'abord le dessin en cours.', 'error');
    if (t.dataset.kind) { S.kind = t.dataset.kind; S.sel = agencies()[0] ? agencies()[0].id : null; S.route = null; return renderAll(); }
    if (t.dataset.ag) { S.sel = Number(t.dataset.ag); return renderAll(); }
    if (t.id === 'new') { S.sel = 'new'; return renderAll(); }
    const tool = t.dataset.t;
    if (tool === 'fit') return fit();
    if (tool === 'me' && S.me) { M.cx = S.me.x; M.cy = S.me.y; M.scale = Math.max(M.scale, 0.35); return; }
    if (tool === 'start') return startDraw();
    if (tool === 'world' || t.dataset.d === 'world') { const a = selected(); if (a) post('worldDraw', { id: a.id, name: a.label }); return; }
    if (tool === 'draw') { S.mode = 'draw'; return renderTools(); }
    if (tool === 'erase') { S.mode = 'erase'; return renderTools(); }
    if (tool === 'close') return closeShape();
    if (tool === 'undo') { S.draft.cur.pop(); return renderTools(); }
    if (tool === 'clear') { S.draft.polys = []; S.draft.cur = []; return renderTools(); }
    if (tool === 'cancel') return stopDraw();
    if (tool === 'save') return saveDraw();
    const d = t.dataset.d;
    if (d === 'draw') return startDraw();
    if (d === 'clearzone') { const a = selected(); if (show(await req('zone', { id: a.id, zone: { polys: [] } }))) await reload(); return; }
    if (d === 'save') {
      const body = { id: S.sel === 'new' ? null : S.sel, kind: S.kind, label: $('#f-label').value, short: $('#f-short').value, color: $('#f-color').value,
        job: $('#f-job').value, mat: $('#f-mat').value, phone: $('#f-phone').value };
      let r = await req('save', body);
      if (r.confirmJob && window.confirm(r.error)) r = await req('save', { ...body, force: true });
      else if (r.confirmJob) return;
      if (!show(r)) return;
      S.sel = r.id;
      return reload();
    }
    if (d === 'appoint') { show(await req('appoint', { id: S.sel, target: Number($('#f-target').value) })); return reload(); }
    if (d === 'delete') {
      const r = await req('delete', { id: S.sel, confirm: $('#f-confirm').value });
      if (!show(r)) return;
      S.sel = null;
      return reload();
    }
  });

  function close() {
    S.draft = null; S.mode = 'view';
    $('#app').classList.add('hidden');
    post('close');
  }
  document.addEventListener('keydown', (e) => {
    if ($('#app').classList.contains('hidden')) return;
    if (e.key === 'Escape') { if (busy()) stopDraw(); else close(); }
    if (e.key === 'Enter' && S.mode === 'draw' && document.activeElement === document.body) closeShape();
  });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
      S.me = m.me || null;
      $('#app').classList.remove('hidden');
      requestAnimationFrame(() => { fit(); setData(m.data); });
    } else if (m.action === 'data') setData(m.data);
    else if (m.action === 'close') { S.draft = null; S.mode = 'view'; $('#app').classList.add('hidden'); }
  });

  requestAnimationFrame(frame);
})();
