/* =====================================================================
   ELYZEA RESTAURANT - administration des restaurants (staff : permissions « Restaurants » du menu admin)
   Créer plusieurs restaurants (logo, couleur), placer leurs points et stations de
   cuisine, nommer le patron, activer, supprimer, voir / annuler les commandes.
   ===================================================================== */
(() => {
  const A = { data: null, sel: null, edit: null, draft: null, q: '' };
  const PAY = { bank: '💳 Banque', cash: '💵 Espèces', pesos: '🪙 Pesos' };
  const wrap = $('#admin');
  const el = () => $('#admin .modal');
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  // Permissions staff du menu admin (le serveur revérifie chaque action) : un bouton non autorisé n'est pas affiché
  const can = (k) => !A.data || !A.data.can || A.data.can[k] === true;
  const RIGHTS = [['edit', 'créer / modifier'], ['points', 'points'], ['boss', 'patron'], ['toggle', 'activer'], ['delete', 'supprimer'], ['orders', 'commandes'], ['menu', 'produits / paiements']];
  const rightsLine = () => {
    const c = A.data && A.data.can;
    if (!c || c.all) return '';
    const yes = RIGHTS.filter(([k]) => c[k]).map(([, l]) => l);
    return `<p class="faint mono-note" style="font-size:.75rem;margin:.4rem 0 0">Tes droits (menu admin) : ${yes.length ? esc(yes.join(' · ')) : 'lecture seule'}</p>`;
  };
  const POINTS = [
    ['order', '🧾 Point de commande', 'Obligatoire. Les clients y appuient sur E : carte, panier, paiement.'],
    ['stash', '📦 Coffre', 'Coffre du restaurant (grades avec la permission « coffre »).'],
    ['manage', '💼 Bureau', 'Les employés y ouvrent la tablette.'],
  ];

  function form(s) {
    const o = (s && s.options) || {};
    return `<div class="form-grid">
      <label class="field"><span>Nom du restaurant</span><input class="input" data-af="name" maxlength="80" value="${esc(s ? s.name : '')}" placeholder="Ex : Pizza This"></label>
      <label class="field"><span>Adresse</span><input class="input" data-af="address" maxlength="120" value="${esc(s ? s.address : '')}"></label>
      <label class="field"><span>Métier (elyzea_core)</span><input class="input mono" data-af="job" maxlength="40" value="${esc(s ? s.job : '')}" placeholder="vide = créé depuis le nom"></label>
      <label class="field"><span>Nom du métier affiché</span><input class="input" data-af="jobLabel" maxlength="60" value="${esc(s ? s.jobLabel : '')}"></label>
      <label class="field"><span>Compte de société</span><input class="input mono" data-af="society" maxlength="40" value="${esc(s ? s.society : '')}" placeholder="vide = nom du métier"></label>
      <label class="field"><span>Début des matricules</span><input class="input mono" data-af="matPrefix" maxlength="8" value="${esc(s ? s.matPrefix : 'RS-')}"></label>
      <label class="field"><span>Logo (emoji ou lien d'image https://…)</span><input class="input" data-af="logo" maxlength="300" value="${esc(o.logo || '🍽️')}"></label>
      <label class="field"><span>Couleur du restaurant</span><input class="input" type="color" data-af="color" value="${esc(o.color || '#f97316')}"></label>
      <label class="field"><span>Icône sur la carte (sprite)</span><input class="input" type="number" data-af="blipSprite" value="${o.blipSprite || 93}"></label>
      <label class="field"><span>Couleur de l'icône</span><input class="input" type="number" data-af="blipColor" value="${o.blipColor != null ? o.blipColor : 47}"></label>
      <label class="check"><input type="checkbox" data-af="blip" ${o.blip !== false ? 'checked' : ''}> Icône sur la carte</label>
      <label class="check"><input type="checkbox" data-af="requireDuty" ${o.requireDuty !== false ? 'checked' : ''}> Service obligatoire pour cuisiner / livrer</label>
    </div>`;
  }

  /* ---------- Produits vendus et paiements ---------- */
  // Brouillon de la liste cochée (gardé tant qu'on reste sur ce restaurant)
  function draftOf(s) {
    if (!A.draft || A.draft.id !== s.id) {
      const cat = (s.options || {}).catalog;
      A.draft = { id: s.id, all: !Array.isArray(cat), set: new Set(Array.isArray(cat) ? cat : (s.onMenu || [])) };
    }
    return A.draft;
  }
  const stationTypesOf = (s) => new Set(((s.points || {}).stations || []).flatMap((st) => st.types || []));
  const norm = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  function catalogCard(s) {
    const d = A.data, dr = draftOf(s), have = stationTypesOf(s), edit = can('menu');
    const types = Object.fromEntries((d.stationTypes || []).map((t) => [t.id, t]));
    const prods = d.products || [];
    const cats = (d.categories || []).filter((c) => prods.some((p) => p.cat === c.id));
    const cu = d.cuisine || {};
    return `<div class="card" id="catalogCard"><h2>🍽️ Produits vendus</h2>
      <p class="faint" style="font-size:.8rem;margin-bottom:.5rem">Ce que <b>${esc(s.name)}</b> a le droit de vendre. Le patron règle ensuite sa carte et ses prix dans la tablette, parmi ces produits.
        ${cu.count ? `<br>${cu.count} recettes de <b>elyzea_cuisine</b> sont au catalogue (italien, fast-food, japonais, mexicain).` : (cu.error ? `<br><span style="color:#fca5a5">Recettes elyzea_cuisine non chargées : ${esc(cu.error)}</span>` : '')}</p>
      <div class="cat-mode"><label><input type="radio" name="catmode" value="all" ${dr.all ? 'checked' : ''} ${edit ? '' : 'disabled'}> Tout le catalogue (le patron choisit)</label>
        <label><input type="radio" name="catmode" value="list" ${dr.all ? '' : 'checked'} ${edit ? '' : 'disabled'}> Seulement les produits cochés <b class="mono" id="catCount">${dr.set.size}</b></label></div>
      <p class="cat-warn" id="catWarn" hidden></p>
      <div class="cat-tools ${dr.all ? 'dim' : ''}"><input class="input" data-catq placeholder="Rechercher un produit…" value="${esc(A.q)}"></div>
      <div class="cat-list ${dr.all ? 'dim' : ''}">${cats.map((c) => {
        const list = prods.filter((p) => p.cat === c.id);
        const n = list.filter((p) => dr.set.has(p.id)).length;
        return `<details class="cat-grp" ${A.q ? 'open' : ''} data-grp="${esc(c.id)}"><summary><span>${esc(c.icon || '')} ${esc(c.label)}</span><span class="faint mono" data-grpn="${esc(c.id)}">${n} / ${list.length}</span>
          ${edit ? `<button class="btn small" data-catall="${esc(c.id)}">Tout</button><button class="btn small" data-catnone="${esc(c.id)}">Rien</button>` : ''}</summary>
          ${list.map((p) => { const st = types[p.station] || {}; const ok = !p.station || have.has(p.station);
            return `<label class="cat-row" data-name="${esc(norm(p.label + ' ' + p.id))}"><input type="checkbox" data-prod="${esc(p.id)}" data-pc="${esc(c.id)}" ${dr.set.has(p.id) ? 'checked' : ''} ${edit ? '' : 'disabled'}>
              <img src="${esc(imgUrl(p.image))}" alt="" loading="lazy"><span class="nm"><b>${esc(p.label)}</b><small class="mono">${esc(p.id)} · ${money(p.price)}</small></span>
              <span class="pill plain ${ok ? '' : 'warn'}" title="${ok ? 'Station posée' : 'Aucune station de ce type dans ce restaurant'}">${esc(st.icon || '')} ${esc(st.label || p.station || '?')}</span></label>`; }).join('')}</details>`;
      }).join('')}</div>
      ${edit ? '<div class="actions"><button class="btn primary" data-ad="catalog">Enregistrer les produits vendus</button></div>' : ''}</div>`;
  }
  function payCard(s) {
    const d = A.data, edit = can('menu'), cur = new Set(s.methods || []);
    return `<div class="card"><h2>💰 Paiements acceptés</h2>
      <div style="display:flex;gap:1rem;flex-wrap:wrap;margin:.3rem 0 .5rem">${(d.methods || []).map((m) => `<label class="check-lbl"><input type="checkbox" data-pay="${esc(m)}" ${cur.has(m) ? 'checked' : ''} ${edit ? '' : 'disabled'}> ${esc(PAY[m] || m)}</label>`).join('')}</div>
      <p class="faint" style="font-size:.78rem">Pesos : prix en pesos = prix × ${Number(d.pesosRate || 1)} (arrondi au-dessus). Les pesos payés vont dans le <b>coffre</b> du restaurant (actuellement <b>${Number(s.pesos || 0).toLocaleString('fr-FR')}</b> pesos), pas sur le compte. Une commande annulée est remboursée en pesos depuis ce coffre.</p>
      ${edit ? '<div class="actions"><button class="btn primary" data-ad="payments">Enregistrer les paiements</button></div>' : ''}</div>`;
  }
  // Stations qu'il faut encore poser pour préparer les produits choisis
  function updateWarn() {
    const w = $('#catWarn'), dr = A.draft, s = A.data && (A.data.shops || []).find((x) => x.id === A.sel);
    if (!w || !dr || !s) return;
    const have = stationTypesOf(s), types = Object.fromEntries((A.data.stationTypes || []).map((t) => [t.id, t]));
    const missing = [...new Set((A.data.products || []).filter((p) => (dr.all || dr.set.has(p.id)) && p.station && !have.has(p.station)).map((p) => p.station))];
    w.hidden = missing.length === 0;
    w.textContent = missing.length ? `⚠️ Station(s) à poser pour préparer ces produits : ${missing.map((t) => `${(types[t] || {}).icon || ''} ${(types[t] || {}).label || t}`).join(' · ')}` : '';
  }
  function refreshCounts() {
    updateWarn();
    const dr = A.draft; if (!dr) return;
    const c = $('#catCount'); if (c) c.textContent = dr.set.size;
    el().querySelectorAll('[data-grpn]').forEach((n) => {
      const id = n.dataset.grpn, all = [...el().querySelectorAll(`[data-pc="${id}"]`)];
      n.textContent = `${all.filter((x) => x.checked).length} / ${all.length}`;
    });
  }
  function filterRows() {
    const q = norm(A.q).trim();
    el().querySelectorAll('.cat-row').forEach((r) => { r.style.display = !q || r.dataset.name.includes(q) ? '' : 'none'; });
    el().querySelectorAll('.cat-grp').forEach((g) => {
      const vis = [...g.querySelectorAll('.cat-row')].some((r) => r.style.display !== 'none');
      g.style.display = vis ? '' : 'none';
      if (q) g.open = true;
    });
  }

  function draw() {
    const d = A.data || { shops: [] };
    const s = d.shops.find((x) => x.id === A.sel);
    let main;
    if (A.edit === 'new') {
      main = `<h2>Nouveau restaurant</h2><p class="lead">Il est créé <b>désactivé</b>, avec 5 grades (Commis, Cuisinier, Serveur, Gérant, Patron) et une carte de départ (produits « default » de config.lua).</p>
        ${form(null)}<div class="actions"><button class="btn" data-ad="cancel">Annuler</button><button class="btn primary" data-ad="save">Créer</button></div>`;
    } else if (!s) {
      main = empty('Choisissez un restaurant à gauche, ou créez-en un.');
    } else if (A.edit === s.id) {
      main = `<h2>Modifier · ${esc(s.name)}</h2>${form(s)}<div class="actions"><button class="btn" data-ad="cancel">Annuler</button><button class="btn primary" data-ad="save">Enregistrer</button></div>`;
    } else {
      const types = d.stationTypes || [];
      const stations = (s.points || {}).stations || [];
      const typeBoxes = (sel, idx) => types.map((t) => `<label class="check"><input type="checkbox" data-st="${idx}" value="${esc(t.id)}" ${sel.includes(t.id) ? 'checked' : ''} ${can('points') ? '' : 'disabled'}> ${esc(t.icon)} ${esc(t.label)}</label>`).join(' ');
      main = `<div class="adm-hero">${logoHTML((s.options || {}).logo, 'logo')}<div><h2>${esc(s.name)}</h2><small class="faint">${esc(s.address || '')} · métier <span class="mono">${esc(s.job)}</span> · compte <span class="mono">${esc(s.society)}</span></small></div>
          <div class="chips">${s.enabled ? '<span class="pill on">Activé</span>' : '<span class="pill off">Désactivé</span>'}${s.publicOpen ? '<span class="pill on">Commandes ouvertes</span>' : '<span class="pill off">Commandes fermées</span>'}</div></div>
        <div class="stats"><div class="stat green"><b>${money(s.balance)}</b><span>Compte</span></div><div class="stat blue"><b>${s.employees}</b><span>Employé(s)</span></div>
          <div class="stat violet"><b>${stations.length}</b><span>Station(s) de cuisine</span></div><div class="stat orange"><b>${s.activeOrders}</b><span>Commande(s) en cours</span></div></div>
        <div class="actions-row">${can('toggle') ? `<button class="btn ${s.enabled ? 'danger' : 'primary'}" data-ad="enable">${s.enabled ? 'Désactiver' : 'Activer'}</button>` : ''}
          ${can('edit') ? '<button class="btn" data-ad="edit">Modifier</button>' : ''}${can('boss') ? '<button class="btn" data-ad="boss">👑 Nommer le patron</button>' : ''}
          ${can('orders') ? '<button class="btn" data-ad="orders">🧾 Commandes en cours</button>' : ''}${can('delete') ? '<button class="btn danger" data-ad="delete">Supprimer</button>' : ''}</div>
        ${A.orders ? `<div class="card"><h2>Commandes en cours</h2>${A.orders.map((o) => `<div class="list-row"><div class="main"><b>${esc(o.num)} · ${esc(o.statusLabel)}</b>
            <small>${esc(o.customer || '')}${o.employee ? ` · ${esc(o.employee)}` : ''} · ${paidTxt(o)} · ${o.lines.map((l) => `${l.qty} × ${esc(l.label)}`).join(', ')}</small></div>
            <button class="btn small danger" data-ocan="${o.id}">Annuler et rembourser</button></div>`).join('') || empty('Aucune commande en cours.')}</div>` : ''}
        ${can('menu') || can('view') ? payCard(s) + catalogCard(s) : ''}
        <div class="card"><h2>Points</h2><p class="faint" style="font-size:.8rem;margin-bottom:.5rem">Placez-vous à l'endroit voulu (fermez ce panneau, marchez, rouvrez-le avec /restoadmin), puis « Placer ici ».</p>
          ${POINTS.map(([k, label, hint]) => { const pt = (s.points || {})[k]; return `<div class="list-row"><div class="main"><b>${label}</b><small>${pt ? `${pt.x.toFixed(1)}, ${pt.y.toFixed(1)}, ${pt.z.toFixed(1)}` : hint}</small></div>
            ${pt ? '<span class="pill on">Placé</span>' : '<span class="pill off">Non placé</span>'}${can('points') ? `<button class="btn small primary" data-pt="${k}">Placer ici</button>` : ''}
            ${pt ? `<button class="btn small" data-tp="${k}">Aller</button>${can('points') ? `<button class="btn small danger" data-ptdel="${k}">Retirer</button>` : ''}` : ''}</div>`; }).join('')}</div>
        <div class="card"><h2>Stations de cuisine</h2><p class="faint" style="font-size:.8rem;margin-bottom:.5rem">Chaque station prépare un ou plusieurs types de produits (le type de chaque produit est dans config.lua).</p>
          ${stations.map((st, i) => `<div class="list-row" style="flex-wrap:wrap"><div class="main"><b>Station ${i + 1}</b><small class="mono">${st.x.toFixed(1)}, ${st.y.toFixed(1)}, ${st.z.toFixed(1)}</small></div>
            <div style="flex-basis:100%;display:flex;gap:.6rem;flex-wrap:wrap;margin:.3rem 0">${typeBoxes(st.types || [], i + 1)}</div>
            ${can('points') ? `<button class="btn small primary" data-stsave="${i + 1}">Enregistrer les types</button><button class="btn small" data-stmove="${i + 1}">Déplacer ici</button>` : ''}
            <button class="btn small" data-tpst="${i + 1}">Aller</button>${can('points') ? `<button class="btn small danger" data-stdel="${i + 1}">Retirer</button>` : ''}</div>`).join('') || empty('Aucune station.')}
          ${can('points') ? `<div class="list-row" style="flex-wrap:wrap"><div class="main"><b>+ Nouvelle station à ma position</b></div>
            <div style="flex-basis:100%;display:flex;gap:.6rem;flex-wrap:wrap;margin:.3rem 0">${typeBoxes([], 0)}</div><button class="btn small primary" data-stsave="0">Poser ici</button></div>` : ''}</div>`;
    }
    el().innerHTML = `<div class="modal-head"><div><div class="eyebrow">Staff</div><h2>Restaurants</h2></div><button class="icon-btn" data-ad="close" aria-label="Fermer">✕</button></div>
      <div class="adm-split"><div class="adm-list">${d.shops.map((x) => `<button class="pick ${x.id === A.sel ? 'on' : ''}" data-sel="${x.id}"><b>${esc(x.name)}</b>
          <small>${x.enabled ? 'Activé' : 'Désactivé'} · ${x.employees} employé(s)</small></button>`).join('') || '<p class="faint">Aucun restaurant.</p>'}
        ${can('edit') ? '<button class="btn primary block" data-ad="new" style="margin-top:.6rem">+ Nouveau restaurant</button>' : ''}${rightsLine()}</div>
      <div class="adm-main">${main}</div></div>`;
    if (s && A.edit !== s.id) { filterRows(); updateWarn(); }
  }

  async function reload() { const r = await post('admReload'); if (!r.error) { A.data = r; draw(); } return r; }
  async function run(action, data, btn) { const r = await act(adm(action, data), btn); if (r.ok) await reload(); return r; }

  wrap.addEventListener('change', (e) => {
    const t = e.target;
    if (t.matches('[data-prod]') && A.draft) { if (t.checked) A.draft.set.add(t.dataset.prod); else A.draft.set.delete(t.dataset.prod); return refreshCounts(); }
    if (t.name === 'catmode' && A.draft) { A.draft.all = t.value === 'all'; el().querySelectorAll('.cat-list,.cat-tools').forEach((n) => n.classList.toggle('dim', A.draft.all)); updateWarn(); }
  });
  wrap.addEventListener('input', (e) => { if (e.target.matches('[data-catq]')) { A.q = e.target.value; filterRows(); } });

  wrap.addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-catall],[data-catnone]'))) {
      e.preventDefault();
      const id = b.dataset.catall || b.dataset.catnone, on = !!b.dataset.catall;
      el().querySelectorAll(`[data-pc="${id}"]`).forEach((c) => {
        if (c.closest('.cat-row').style.display === 'none') return;
        c.checked = on; if (on) A.draft.set.add(c.dataset.prod); else A.draft.set.delete(c.dataset.prod);
      });
      if (on && A.draft.all) { A.draft.all = false; const r = el().querySelector('input[name="catmode"][value="list"]'); if (r) r.checked = true; el().querySelectorAll('.cat-list,.cat-tools').forEach((n) => n.classList.remove('dim')); }
      return refreshCounts();
    }
    if ((b = e.target.closest('[data-sel]'))) { A.sel = Number(b.dataset.sel); A.edit = null; A.orders = null; A.draft = null; A.q = ''; return draw(); }
    if ((b = e.target.closest('[data-pt]'))) return run('point', { id: A.sel, key: b.dataset.pt }, b);
    if ((b = e.target.closest('[data-ptdel]'))) return run('point', { id: A.sel, key: b.dataset.ptdel, remove: true }, b);
    if ((b = e.target.closest('[data-tp]'))) return act(adm('teleport', { id: A.sel, key: b.dataset.tp }), b);
    const types = (idx) => [...el().querySelectorAll(`[data-st="${idx}"]`)].filter((c) => c.checked).map((c) => c.value);
    if ((b = e.target.closest('[data-stsave]'))) { const i = Number(b.dataset.stsave); return run('station', { id: A.sel, index: i || undefined, types: types(i) }, b); }
    if ((b = e.target.closest('[data-stmove]'))) { const i = Number(b.dataset.stmove); return run('station', { id: A.sel, index: i, types: types(i), move: true }, b); }
    if ((b = e.target.closest('[data-tpst]'))) return act(adm('teleport', { id: A.sel, key: 'station', index: Number(b.dataset.tpst) }), b);
    if ((b = e.target.closest('[data-stdel]'))) {
      if (!(await confirmBox('Retirer la station ?', 'Les employés ne pourront plus y cuisiner.', 'Retirer', true))) return;
      return run('station', { id: A.sel, index: Number(b.dataset.stdel), remove: true }, b);
    }
    if ((b = e.target.closest('[data-ocan]'))) {
      if (!(await confirmBox('Annuler la commande ?', 'Le client est remboursé depuis le compte du restaurant.', 'Annuler et rembourser', true))) return;
      const r = await act(adm('orderCancel', { order: Number(b.dataset.ocan) }), b);
      if (r.ok) { const o = await adm('orders', { id: A.sel }); A.orders = o.list || []; draw(); }
      return;
    }
    if (!(b = e.target.closest('[data-ad]'))) return;
    const a = b.dataset.ad;
    const s = (A.data.shops || []).find((x) => x.id === A.sel);
    if (a === 'close') return post('close', { ui: 'admin' });
    if (a === 'new') { A.edit = 'new'; return draw(); }
    if (a === 'edit') { A.edit = A.sel; return draw(); }
    if (a === 'cancel') { A.edit = null; return draw(); }
    if (a === 'save') {
      const v = {};
      el().querySelectorAll('[data-af]').forEach((i) => { v[i.dataset.af] = i.type === 'checkbox' ? i.checked : i.value; });
      v.blipSprite = Number(v.blipSprite); v.blipColor = Number(v.blipColor);
      if (A.edit !== 'new') v.id = A.sel;
      const r = await act(adm('shopSave', v), b);
      if (r.ok) { A.sel = r.id; A.edit = null; await reload(); }
      return;
    }
    if (!s) return;
    if (a === 'enable') return run('shopEnable', { id: s.id, enabled: !s.enabled }, b);
    if (a === 'catalog') {
      const dr = draftOf(s);
      const r = await act(adm('catalogSet', dr.all ? { id: s.id, all: true } : { id: s.id, products: [...dr.set] }), b);
      if (r.ok) { A.draft = null; await reload(); }
      return;
    }
    if (a === 'payments') {
      const methods = [...el().querySelectorAll('[data-pay]')].filter((c) => c.checked).map((c) => c.dataset.pay);
      return run('paymentsSet', { id: s.id, methods }, b);
    }
    if (a === 'orders') { const o = await act(adm('orders', { id: s.id }), b); if (!o.error) { A.orders = o.list || []; draw(); } return; }
    if (a === 'boss') {
      const v = await confirmBox('Nommer le patron', `Le joueur reçoit le plus haut grade de <b>${esc(s.name)}</b> (il est recruté s'il ne l'est pas).`, 'Nommer', false,
        '<label class="field" style="margin-top:.6rem"><span>ID serveur du joueur</span><input class="input" type="number" min="1" data-cfv="target"></label>');
      if (!v) return;
      return run('setBoss', { id: s.id, target: Number(v.target) });
    }
    if (a === 'delete') {
      const v = await confirmBox('Supprimer le restaurant ?', `Les employés sont retirés du métier. Les commandes et les finances sont gardées.<br>Tapez <b>${esc(s.name)}</b> pour confirmer.`, 'Supprimer', true,
        '<label class="field" style="margin-top:.6rem"><input class="input" data-cfv="confirm"></label>');
      if (!v) return;
      const r = await act(adm('shopDelete', { id: s.id, confirm: v.confirm }), b);
      if (r.ok) { A.sel = null; await reload(); }
    }
  });

  window.Admin = {
    open(d) { A.data = d; A.draft = null; if (!A.sel && d.shops.length) A.sel = d.shops[0].id; A.edit = null; wrap.classList.remove('hidden'); draw(); },
    hide() { wrap.classList.add('hidden'); },
    isOpen: () => !wrap.classList.contains('hidden'),
  };
})();
