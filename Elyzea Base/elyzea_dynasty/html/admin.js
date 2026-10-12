/* =====================================================================
   ELYZEA DYNASTY 8 - Gestion immobilière (staff, ouverte depuis admin_menu ou /d8admin)
   Biens : création, prix, intérieur, activation, points, garage et places, contrats, véhicules.
   Intérieurs : catalogue modifiable en jeu (position du staff, IPL, test).
   Décoration : modèles supplémentaires autorisés.
   Chaque bouton appelle le serveur (permission « property_manage » revérifiée).
   Les points se placent à la position du staff : fermez le panneau (Échap), placez-vous,
   rouvrez /d8admin puis « Placer ici ». La sélection est gardée.
   ===================================================================== */
(() => {
  const A = { open: false, data: null, tab: 'props', sel: null, prop: null, q: '', interior: null, preview: false };
  const root = () => $('#admin');
  const KIND = { sale: 'Vente', rent: 'Location' };
  const CSTAT = { active: 'En cours', expired: 'Expiré', ended: 'Terminé', cancelled: 'Annulé' };
  const POINTS = [
    { key: 'enter', label: 'Entrée de l\'habitation', where: 'Extérieur', color: '#22c55e', home: true },
    { key: 'bell', label: 'Sonnette (facultatif)', where: 'Extérieur', color: '#facc15', home: true },
    { key: 'exit', label: 'Sortie (rouge)', where: 'Dans l\'habitation', color: '#ef4444', home: true, inside: 'home' },
    { key: 'manage', label: 'Zone de gestion (bleue)', where: 'Dans l\'habitation', color: '#3b82f6', home: true, inside: 'home' },
    { key: 'stash', label: 'Coffre (orange)', where: 'Dans l\'habitation', color: '#f97316', home: true, inside: 'home' },
    { key: 'garage.enter', label: 'Entrée du garage', where: 'Extérieur', color: '#3b82f6', garage: true },
    { key: 'garage.spawn', label: 'Sortie des véhicules (au volant)', where: 'Extérieur', color: '#94a3b8', garage: true },
    { key: 'garage.inside', label: 'Arrivée à pied dans le garage', where: 'Dans le garage', color: '#22c55e', garage: true, inside: 'garage' },
    { key: 'garage.exit', label: 'Sortie du garage (rouge)', where: 'Dans le garage', color: '#ef4444', garage: true, inside: 'garage' },
  ];
  const cats = () => (A.data && A.data.categories) || APP.cats;
  const pill = (st) => { const s = ((A.data && A.data.statuses) || {})[st] || { label: st, color: '#94a3b8' }; return `<span class="pill plain" style="color:${s.color};border-color:${s.color}55"><span class="st-dot" style="background:${s.color}"></span>${esc(s.label)}</span>`; };
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const xyz = (p) => (p ? `${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)}` : '');
  const interiorsOf = (kinds) => ((A.data && A.data.interiors) || []).filter((i) => kinds.includes(i.kind));
  const intLabel = (id) => { const i = ((A.data && A.data.interiors) || []).find((x) => x.id === id); return i ? i.label : '—'; };
  const getPoint = (p, key) => (key.startsWith('garage.') ? (p.garage && p.garage.points || {})[key.slice(7)] : (p.points || {})[key]);
  const val = (sel) => { const el = root().querySelector(sel); return el ? (el.type === 'checkbox' ? el.checked : el.value) : undefined; };

  async function run(action, data, btn) { return act(adm(action, data), btn); }
  async function reload() {
    const d = await adm('data');
    if (d.error) { toast(d.error, false); return; }
    A.data = d;
    if (A.sel) {
      const r = await adm('prop', { id: A.sel });
      A.prop = r.error ? null : r.prop;
      if (!A.prop) A.sel = null;
    }
    draw();
  }
  // Après un déplacement (téléportation, test, coffre) : le panneau se ferme
  const hide = () => post('adminHide', {});

  /* ------------------------------------------------------------------ */
  function draw() {
    const d = A.data;
    if (!d) return;
    const ins = d.inside ? `<span class="pill on">Vous êtes dans le bien #${d.inside.pid} (${d.inside.area === 'garage' ? 'garage' : d.inside.area === 'test' ? 'test' : 'habitation'})</span>` : '<span class="pill off">À l\'extérieur</span>';
    root().innerHTML = `<div class="adm-head"><h1>🏠 Gestion immobilière <span class="faint" style="font-size:.8rem;font-weight:500">Dynasty 8 · staff</span></h1>${ins}
        ${[['props', 'Biens'], ['interiors', 'Intérieurs'], ['deco', 'Décoration']].map(([k, l]) => `<button class="btn small ${A.tab === k ? 'primary' : ''}" data-at="${k}">${l}</button>`).join('')}
        <label class="extra" title="Affiche les points des biens proches, avec leur nom"><input type="checkbox" class="check" data-apreview ${A.preview ? 'checked' : ''}> Aperçu en jeu</label>
        <button class="icon-btn" data-aclose="1" aria-label="Fermer">✕</button></div>
      <div class="adm-body">${A.tab === 'props' ? propsTab() : A.tab === 'interiors' ? interiorsTab() : decoTab()}</div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Biens                                                               */
  /* ------------------------------------------------------------------ */
  function propsTab() {
    const q = A.q.trim().toLowerCase();
    const list = A.data.list.filter((p) => !q || `#${p.id} ${p.name} ${p.address} ${cats()[p.category]}`.toLowerCase().includes(q));
    const items = list.map((p) => `<button class="adm-item ${A.sel === p.id ? 'on' : ''}" data-asel="${p.id}"><b>${CAT_ICO[p.category] || ''} #${p.id} ${esc(p.name)}</b>
        <small>${esc(cats()[p.category] || p.category)} · ${p.enabled ? esc((A.data.statuses[p.status] || {}).label || p.status) : 'désactivé'}${p.hasGarage ? ` · garage ${p.capacity} pl.` : ''}${p.contract ? ` · ${esc(p.contract.holder || '')}` : ''}</small></button>`).join('');
    return `<div class="adm-list"><div style="display:flex;gap:.4rem;margin-bottom:.5rem"><input class="input grow" data-aq placeholder="Rechercher un bien" value="${esc(A.q)}"><button class="btn small primary" data-anew="1">+ Nouveau</button></div>
        ${items || empty('Aucun bien. Créez le premier avec « + Nouveau ».')}</div>
      <div class="adm-main">${A.sel === 'new' ? propForm(null) : A.prop ? propDetail(A.prop) : '<div class="note">Sélectionnez un bien, ou créez-en un. Un nouveau bien est désactivé : placez ses points, puis activez-le pour qu\'il apparaisse dans la tablette Dynasty 8.</div>'}</div>`;
  }

  function propForm(p) {
    const isNew = !p;
    p = p || { category: 'apartment', salePrice: 0, rentPrice: 0, rentMin: A.data.defaults.rent.minDays, rentMax: A.data.defaults.rent.maxDays, forSale: true, forRent: true,
      stashSlots: A.data.defaults.stash.slots, stashWeight: A.data.defaults.stash.weight, decoLimit: A.data.defaults.deco };
    const homes = interiorsOf(['apartment', 'house', 'villa']);
    return `<div class="adm-section"><h3>${isNew ? 'Nouveau bien' : 'Informations et tarifs'}</h3><div class="form-grid">
        <label class="field"><span>Nom</span><input class="input" data-af="name" maxlength="80" value="${esc(p.name || '')}" placeholder="ex : Appartement Eclipse 12"></label>
        <label class="field"><span>Adresse</span><input class="input" data-af="address" maxlength="120" value="${esc(p.address || '')}"></label>
        <label class="field"><span>Catégorie</span><select class="input" data-af="category">${Object.entries(cats()).map(([k, l]) => `<option value="${k}" ${p.category === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select></label>
        ${isNew ? `<label class="field"><span>Intérieur (habitation)</span><select class="input" data-af="interiorId"><option value="">— Aucun (garage seul) —</option>${homes.filter((i) => i.enabled).map((i) => `<option value="${i.id}">${esc(i.label)} · ${esc(cats()[i.kind] || i.kind)}</option>`).join('')}</select></label>`
          : `<label class="field"><span>Intérieur</span><span style="display:flex;gap:.4rem;align-items:center"><b style="flex:1">${p.interiorId ? esc(intLabel(p.interiorId)) : '—'}</b>${p.category !== 'garage' ? '<button class="btn small" data-aint="1">Changer d\'intérieur</button>' : ''}</span></label>`}
        <label class="field"><span>Prix de vente ($)</span><input class="input" type="number" min="0" data-af="salePrice" value="${p.salePrice}"></label>
        <label class="field"><span>Location ($ / jour)</span><input class="input" type="number" min="0" data-af="rentPrice" value="${p.rentPrice}"></label>
        <label class="field"><span>Prolongation ($ / jour, vide = tarif du contrat)</span><input class="input" type="number" min="0" data-af="extendPrice" value="${p.extendPrice ?? ''}"></label>
        <label class="field"><span>Durée de location min / max (jours)</span><span style="display:flex;gap:.4rem"><input class="input" type="number" min="1" data-af="rentMin" value="${p.rentMin}"><input class="input" type="number" min="1" data-af="rentMax" value="${p.rentMax}"></span></label>
        <label class="field"><span>Coffre : emplacements / poids (kg)</span><span style="display:flex;gap:.4rem"><input class="input" type="number" min="0" data-af="stashSlots" value="${p.stashSlots}"><input class="input" type="number" min="0" data-af="stashWeight" value="${p.stashWeight}"></span></label>
        <label class="field"><span>Objets de décoration max.</span><input class="input" type="number" min="0" data-af="decoLimit" value="${p.decoLimit}"></label>
        ${isNew ? '' : `<label class="field full"><span>Notes internes</span><input class="input" data-af="notes" maxlength="255" value="${esc(p.notes || '')}"></label>`}
        <label class="extra"><input type="checkbox" class="check" data-af="forSale" ${p.forSale ? 'checked' : ''}> À vendre</label>
        <label class="extra"><input type="checkbox" class="check" data-af="forRent" ${p.forRent ? 'checked' : ''}> À louer</label></div>
      <div class="actions-row"><button class="btn primary" data-asave="1">${isNew ? 'Créer le bien' : 'Enregistrer'}</button>${isNew ? '<button class="btn" data-acancel="1">Annuler</button>' : ''}</div>
      ${isNew ? '<p class="faint" style="font-size:.78rem;margin-top:.5rem">Un bien « Garage » n\'a pas d\'intérieur d\'habitation : configurez son garage après la création.</p>' : ''}</div>`;
  }

  function propDetail(p) {
    const c = p.contract;
    const pts = POINTS.filter((x) => (x.home ? p.category !== 'garage' : true) && (x.garage ? p.garage && p.garage.enabled : true)).map((x) => {
      const pt = getPoint(p, x.key);
      return `<div class="pt-row"><span class="sw" style="background:${x.color}"></span><div><b>${esc(x.label)}</b><small>${esc(x.where)} · ${pt ? `${xyz(pt)}${pt.on === false ? ' · <b style="color:#fca5a5">désactivé</b>' : ''}` : '<span style="color:#fcd34d">non placé</span>'}</small></div>
        <div class="acts">${pt ? `<input class="input" type="number" step="0.1" min="0.6" max="10" value="${pt.r || ''}" data-apr="${x.key}" title="Rayon (m)"><label class="extra" title="Actif"><input type="checkbox" class="check" data-apon="${x.key}" ${pt.on !== false ? 'checked' : ''}></label>` : ''}
          <button class="btn small primary" data-apt="${x.key}">Placer ici</button>${pt && x.key !== 'enter' ? `<button class="btn small danger" data-aptdel="${x.key}">✕</button>` : ''}</div></div>`;
    }).join('');
    const g = p.garage || {};
    const sizes = A.data.sizes || {};
    const slots = (g.slots || []).map((s, i) => `<div class="list-row"><div class="main"><b>Place ${i + 1}</b><small>${xyz(s)} · cap ${Math.round(s.h || 0)}°</small></div><button class="btn small danger" data-aslotdel="${i + 1}">Retirer</button></div>`).join('');
    const veh = (p.vehicles || []).map((v) => `<div class="list-row"><div class="main"><b class="mono">${esc(v.plate || '?')}</b><small>${esc(v.model || '')} · place ${v.slot} · ${esc(v.owner_cid || '')}</small></div><button class="btn small" data-avrel="${v.vehicle_id}">Garage public</button></div>`).join('');
    const contracts = (p.contracts || []).map((x) => `<div class="list-row"><div class="main"><b>${esc(KIND[x.kind] || x.kind)} · ${esc(x.holder_name || '—')}</b>
        <small><span class="mono">${esc(x.uid || '')}</span> · ${fmtTime(x.s)}${x.e ? ` → ${fmtTime(x.e)}` : ''} · ${esc(CSTAT[x.status] || x.status)}${x.end_reason ? ` · ${esc(x.end_reason)}` : ''}</small></div>
        <span class="mono nw">${money(x.price)}</span>${x.stash_id ? `<button class="btn small" data-astash="${esc(x.stash_id)}">Coffre</button>` : ''}</div>`).join('');
    const log = (p.log || []).map((l) => `<div><b>${esc(l.action)}</b>${l.details ? ` · ${esc(l.details)}` : ''}<small>${esc(l.actor_name || '')} · ${fmtTime(l.t)}</small></div>`).join('');
    const missing = [];
    if (!getPoint(p, 'enter')) missing.push('entrée');
    if (p.category !== 'garage' && !p.interiorId) missing.push('intérieur');
    if (p.category !== 'garage' && !getPoint(p, 'exit')) missing.push('sortie (dans l\'habitation)');
    if (p.category !== 'garage' && !getPoint(p, 'manage')) missing.push('zone de gestion');
    if (p.category !== 'garage' && !getPoint(p, 'stash')) missing.push('coffre');
    if (g.enabled && !getPoint(p, 'garage.enter')) missing.push('entrée du garage');
    if (g.enabled && !getPoint(p, 'garage.spawn')) missing.push('sortie des véhicules');
    if (g.enabled && !getPoint(p, 'garage.inside')) missing.push('arrivée dans le garage');
    if (g.enabled && !getPoint(p, 'garage.exit')) missing.push('sortie du garage');
    if (g.enabled && !(g.slots || []).length) missing.push('places du garage');
    return `<div class="adm-section"><h3>Bien #${p.id}</h3><div style="display:flex;gap:.6rem;align-items:center;flex-wrap:wrap">
        <b style="font-size:1.1rem">${CAT_ICO[p.category] || ''} ${esc(p.name)}</b>${p.enabled ? pill(p.status) : pill('disabled')}
        <span style="flex:1"></span><button class="btn small ${p.enabled ? '' : 'success'}" data-aen="${p.enabled ? 0 : 1}">${p.enabled ? 'Désactiver' : 'Activer'}</button>
        <button class="btn small danger" data-adel="1">Supprimer</button></div>
        ${missing.length ? `<div class="warn-box" style="margin-top:.6rem">À compléter : ${missing.map(esc).join(', ')}.</div>` : ''}
        ${c ? `<div class="note" style="margin-top:.6rem">${esc(KIND[c.kind] || c.kind)} en cours · ${esc(c.holder || '')}${c.ends ? ` · jusqu'au ${fmtTime(c.ends)}` : ''} <button class="btn small danger" data-acend="1">Terminer le contrat</button></div>` : ''}</div>
      <div class="adm-section"><h3>Déplacements</h3><div class="actions-row">
        <button class="btn small" data-atp="outside">Devant le bien</button>${p.category !== 'garage' ? `<button class="btn small" data-atp="home" ${p.interiorId ? '' : 'disabled'}>Aller à l'intérieur</button>` : ''}
        ${g.enabled ? '<button class="btn small" data-atp="garage">Aller dans le garage</button>' : ''}</div>
        <p class="faint" style="font-size:.76rem;margin-top:.4rem">Mode staff : aucun droit n'est donné, /d8sortir pour revenir. Pour placer un point : fermez le panneau (Échap), placez-vous, rouvrez /d8admin puis « Placer ici ».</p></div>
      ${propForm(p)}
      <div class="adm-section"><h3>Points</h3>${pts}</div>
      <div class="adm-section"><h3>Garage</h3><div class="form-grid">
        <label class="extra"><input type="checkbox" class="check" data-ag="enabled" ${g.enabled ? 'checked' : ''}> Ce bien a un garage</label>
        <label class="field"><span>Taille</span><select class="input" data-ag="size">${Object.entries(sizes).map(([k, s]) => `<option value="${k}" ${g.size === k ? 'selected' : ''}>${esc(s.label)} (${s.capacity} pl.)</option>`).join('')}</select></label>
        <label class="field"><span>Capacité (1 à ${A.data.maxCapacity})</span><input class="input" type="number" min="1" max="${A.data.maxCapacity}" data-ag="capacity" value="${g.capacity || ''}" placeholder="selon la taille"></label>
        <label class="field"><span>Intérieur du garage</span><select class="input" data-ag="interiorId"><option value="">—</option>${interiorsOf(['garage']).filter((i) => i.enabled).map((i) => `<option value="${i.id}" ${g.interiorId === i.id ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></label></div>
        <div class="actions-row"><button class="btn primary small" data-agsave="1">Enregistrer le garage</button></div>
        ${g.enabled ? `<p class="faint" style="font-size:.8rem;margin:.6rem 0 .3rem">Places : ${(g.slots || []).length} placée(s) · capacité utilisable ${p.capacity} · ${p.stored} véhicule(s) rangé(s)</p>
          ${slots}<div class="actions-row"><button class="btn small primary" data-aslot="1">+ Place ici (dans le garage, au volant ou à pied)</button></div>
          <h3 style="margin-top:.8rem">Véhicules rangés</h3>${veh || empty('Aucun véhicule.')}` : ''}</div>
      <div class="adm-section"><h3>Contrats et coffres archivés</h3>${contracts || empty('Aucun contrat.')}</div>
      <div class="adm-section"><h3>Journal du bien</h3><div class="timeline">${log || '<span class="faint">Rien pour l\'instant.</span>'}</div></div>`;
  }

  function formData() {
    const g = (k) => val(`[data-af="${k}"]`);
    const n = (k) => { const v = g(k); return v === '' || v === undefined ? undefined : Number(v); };
    return { name: g('name'), address: g('address'), category: g('category'), interiorId: g('interiorId'), salePrice: n('salePrice'), rentPrice: n('rentPrice'),
      extendPrice: g('extendPrice') === '' ? '' : n('extendPrice'), rentMin: n('rentMin'), rentMax: n('rentMax'), stashSlots: n('stashSlots'), stashWeight: n('stashWeight'),
      decoLimit: n('decoLimit'), notes: g('notes'), forSale: g('forSale'), forRent: g('forRent') };
  }

  /* ------------------------------------------------------------------ */
  /* Intérieurs                                                          */
  /* ------------------------------------------------------------------ */
  function interiorsTab() {
    const list = A.data.interiors.map((i) => `<button class="adm-item ${A.interior === i.id ? 'on' : ''}" data-aisel="${i.id}"><b>${esc(i.label)}</b>
        <small>${esc(cats()[i.kind] || i.kind)}${i.enabled ? '' : ' · désactivé'}${i.code ? ` · ${esc(i.code)}` : ''}</small></button>`).join('');
    const i = A.interior === 'new' ? { label: '', kind: 'apartment', ipls: [], enabled: true } : A.data.interiors.find((x) => x.id === A.interior);
    const form = i ? `<div class="adm-section"><h3>${i.id ? `Intérieur #${i.id}` : 'Nouvel intérieur (à votre position actuelle)'}</h3><div class="form-grid">
        <label class="field"><span>Nom</span><input class="input" data-ai="label" maxlength="60" value="${esc(i.label)}"></label>
        <label class="field"><span>Type</span><select class="input" data-ai="kind">${Object.entries(cats()).map(([k, l]) => `<option value="${k}" ${i.kind === k ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select></label>
        <label class="field full"><span>IPL à charger (séparées par des virgules, facultatif)</span><input class="input" data-ai="ipls" value="${esc((i.ipls || []).join(', '))}"></label>
        <label class="field"><span>Ressource MLO requise (facultatif)</span><input class="input" data-ai="resource" maxlength="60" value="${esc(i.resource || '')}"></label>
        <label class="field"><span>Notes</span><input class="input" data-ai="notes" maxlength="255" value="${esc(i.notes || '')}"></label>
        ${i.id ? `<label class="field full"><span>Point d'arrivée</span><b class="mono">${xyz(i)} · ${Math.round(i.h || 0)}°</b></label>
          <label class="extra"><input type="checkbox" class="check" data-ai="here"> Remplacer le point d'arrivée par ma position</label>
          <label class="extra"><input type="checkbox" class="check" data-ai="enabled" ${i.enabled ? 'checked' : ''}> Disponible pour les biens</label>` : ''}</div>
      <div class="actions-row"><button class="btn primary" data-aisave="1">${i.id ? 'Enregistrer' : 'Créer à ma position'}</button>${i.id ? '<button class="btn" data-aitest="1">Tester (seul, instance privée)</button>' : ''}</div>
      <p class="faint" style="font-size:.76rem;margin-top:.5rem">Le point d'arrivée est l'endroit où le joueur apparaît. Les coordonnées fournies à l'installation sont des intérieurs GTA connus : vérifiez-les avec « Tester » avant de les utiliser. Un intérieur déjà utilisé peut être modifié ; pour changer celui d'un bien, utilisez « Changer d'intérieur » sur le bien.</p></div>`
      : '<div class="note">Sélectionnez un intérieur, ou ajoutez-en un : placez-vous à l\'endroit d\'arrivée (dans un MLO ou un intérieur GTA), puis « + Nouveau ».</div>';
    return `<div class="adm-list"><div style="margin-bottom:.5rem"><button class="btn small primary" data-ainew="1">+ Nouveau à ma position</button></div>${list || empty('Aucun intérieur.')}</div><div class="adm-main">${form}</div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Décoration                                                          */
  /* ------------------------------------------------------------------ */
  function decoTab() {
    const list = (A.data.decoCatalog || []).map((c, i) => `<div class="list-row"><div class="main"><b>${esc(c.label || c.model)}</b><small class="mono">${esc(c.model)} · ${esc(c.cat || '')}</small></div>
      ${i >= (A.data.decoBase || 0) ? `<button class="btn small danger" data-adecodel="${esc(c.model)}">Retirer</button>` : '<span class="faint" style="font-size:.74rem">config</span>'}</div>`).join('');
    return `<div class="adm-list"><div class="adm-section"><h3>Ajouter un modèle</h3><div style="display:flex;flex-direction:column;gap:.5rem">
        <input class="input" data-ad="model" placeholder="Nom du modèle (ex : prop_couch_01)" maxlength="60"><input class="input" data-ad="label" placeholder="Nom affiché" maxlength="40">
        <input class="input" data-ad="cat" placeholder="Catégorie (ex : Salon)" maxlength="30"><button class="btn primary small" data-adecoadd="1">Ajouter au catalogue</button></div>
        <p class="faint" style="font-size:.76rem;margin-top:.5rem">Les résidents ne peuvent poser que les modèles de ce catalogue. Le modèle doit exister sur le serveur (GTA ou ressource streamée).</p></div></div>
      <div class="adm-main"><div class="adm-section"><h3>Catalogue (${(A.data.decoCatalog || []).length})</h3>${list || empty('Catalogue vide.')}</div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Événements                                                          */
  /* ------------------------------------------------------------------ */
  root().addEventListener('input', (e) => {
    if (e.target.dataset.aq !== undefined) {
      A.q = e.target.value;
      const pos = e.target.selectionStart;
      draw();
      const n = root().querySelector('[data-aq]'); if (n) { n.focus(); n.setSelectionRange(pos, pos); }
    }
  });
  root().addEventListener('change', async (e) => {
    const t = e.target;
    if (t.dataset.apreview !== undefined) { const r = await post('adminPreview', { on: t.checked }); A.preview = !!(r && r.on); return; }
    if (t.dataset.apr) { await run('pointSet', { id: A.sel, key: t.dataset.apr, r: Number(t.value) }); return reload(); }
    if (t.dataset.apon) { await run('pointSet', { id: A.sel, key: t.dataset.apon, on: t.checked }); return reload(); }
    if (t.dataset.ag === 'size') {
      const s = (A.data.sizes || {})[t.value], cap = root().querySelector('[data-ag="capacity"]');
      if (s && cap) cap.value = s.capacity;
    }
  });
  root().addEventListener('click', async (e) => {
    let b;
    if (e.target.closest('[data-aclose]')) return post('close', { ui: 'admin' });
    if ((b = e.target.closest('[data-at]'))) { A.tab = b.dataset.at; return draw(); }
    // Biens
    if ((b = e.target.closest('[data-asel]'))) { A.sel = Number(b.dataset.asel); return reload(); }
    if (e.target.closest('[data-anew]')) { A.sel = 'new'; A.prop = null; return draw(); }
    if (e.target.closest('[data-acancel]')) { A.sel = null; return draw(); }
    if ((b = e.target.closest('[data-asave]'))) {
      const d = formData();
      if (A.sel !== 'new') { d.id = A.sel; d.interiorId = A.prop.interiorId ?? ''; }
      const r = await run('propSave', d, b);
      if (r.ok) { A.sel = r.id; await reload(); }
      return;
    }
    if (!A.prop && A.tab === 'props') return;
    const p = A.prop;
    if ((b = e.target.closest('[data-aen]'))) { await run('propEnable', { id: p.id, enabled: b.dataset.aen === '1' }, b); return reload(); }
    if (e.target.closest('[data-adel]')) {
      if (!(await confirmBox('Supprimer ce bien ?', `<b>${esc(p.name)}</b> sera supprimé. Impossible s'il a un historique (contrats, véhicules, décoration) : désactivez-le alors.`, 'Supprimer', true))) return;
      const r = await run('propDelete', { id: p.id });
      if (r.ok) { A.sel = null; A.prop = null; await reload(); }
      return;
    }
    if (e.target.closest('[data-acend]')) {
      const v = await confirmBox('Terminer le contrat ?', `Le bien <b>${esc(p.name)}</b> redevient disponible. Coffre archivé, décoration mise en réserve, véhicules renvoyés au garage public, occupants sortis. Aucun remboursement automatique.`, 'Terminer', true,
        '<label class="field" style="margin-top:.6rem"><span>Motif (obligatoire)</span><input class="input" data-cfv="reason" maxlength="120"></label>');
      if (!v) return;
      await run('contractEnd', { id: p.id, reason: v.reason });
      return reload();
    }
    if (e.target.closest('[data-aint]')) {
      const homes = interiorsOf(['apartment', 'house', 'villa']).filter((i) => i.enabled && i.id !== p.interiorId);
      if (!homes.length) return toast('Aucun autre intérieur d\'habitation disponible.', false);
      const v = await confirmBox('Changer d\'intérieur', `Intérieur actuel : <b>${esc(intLabel(p.interiorId))}</b>. Le propriétaire, le contrat, les paiements, le coffre et l'historique sont conservés.`, 'Continuer', false,
        `<label class="field" style="margin-top:.6rem"><span>Nouvel intérieur</span><select class="input" data-cfv="interior">${homes.map((i) => `<option value="${i.id}">${esc(i.label)} · ${esc(cats()[i.kind] || i.kind)}</option>`).join('')}</select></label>`);
      if (!v) return;
      const q = await adm('propInterior', { id: p.id, interiorId: Number(v.interior) });
      if (q.error) return toast(q.error, false);
      if (q.confirm) {
        if (!(await confirmBox('Confirmer le changement ?', esc(q.message), 'Changer d\'intérieur', true))) return;
        await run('propInterior', { id: p.id, interiorId: Number(v.interior), confirm: true });
      } else if (q.message) toast(q.message, true);
      return reload();
    }
    if ((b = e.target.closest('[data-atp]'))) { const r = await run('teleport', { id: p.id, area: b.dataset.atp }, b); if (r.ok) hide(); return; }
    if ((b = e.target.closest('[data-apt]'))) {
      const key = b.dataset.apt, pt = getPoint(p, key);
      if (pt && !(await confirmBox('Déplacer ce point ?', 'Il sera remplacé par votre position actuelle.', 'Déplacer'))) return;
      await run('point', { id: p.id, key }, b);
      return reload();
    }
    if ((b = e.target.closest('[data-aptdel]'))) {
      if (!(await confirmBox('Retirer ce point ?', 'Le point ne sera plus utilisable tant qu\'il n\'est pas replacé.', 'Retirer', true))) return;
      await run('point', { id: p.id, key: b.dataset.aptdel, remove: true }, b);
      return reload();
    }
    if ((b = e.target.closest('[data-agsave]'))) {
      const enabled = val('[data-ag="enabled"]');
      const cap = val('[data-ag="capacity"]');
      await run('garageSave', { id: p.id, enabled, size: val('[data-ag="size"]'), capacity: cap === '' ? undefined : Number(cap), interiorId: Number(val('[data-ag="interiorId"]')) || undefined }, b);
      return reload();
    }
    if ((b = e.target.closest('[data-aslot]'))) { await run('slot', { id: p.id }, b); return reload(); }
    if ((b = e.target.closest('[data-aslotdel]'))) {
      if (!(await confirmBox(`Retirer la place ${b.dataset.aslotdel} ?`, 'Impossible si un véhicule y est rangé (ou sur une place suivante).', 'Retirer', true))) return;
      await run('slot', { id: p.id, remove: true, index: Number(b.dataset.aslotdel) }, b);
      return reload();
    }
    if ((b = e.target.closest('[data-avrel]'))) {
      if (!(await confirmBox('Renvoyer au garage public ?', 'Le véhicule quitte ce garage et devient disponible au garage public pour son propriétaire.', 'Renvoyer'))) return;
      await run('vehicleRelease', { vehicleId: Number(b.dataset.avrel) }, b);
      return reload();
    }
    if ((b = e.target.closest('[data-astash]'))) { const r = await run('openStash', { stash: b.dataset.astash }, b); if (r.ok) hide(); }
  });
  // Intérieurs et décoration (onglets sans bien sélectionné)
  root().addEventListener('click', async (e) => {
    let b;
    if ((b = e.target.closest('[data-aisel]'))) { A.interior = Number(b.dataset.aisel); return draw(); }
    if (e.target.closest('[data-ainew]')) { A.interior = 'new'; return draw(); }
    if ((b = e.target.closest('[data-aisave]'))) {
      const g = (k) => val(`[data-ai="${k}"]`);
      const d = { label: g('label'), kind: g('kind'), ipls: g('ipls'), resource: g('resource'), notes: g('notes') };
      if (A.interior !== 'new') { d.id = A.interior; d.here = g('here') === true; d.enabled = g('enabled') === true; }
      const r = await run('interiorSave', d, b);
      if (r.ok) { A.interior = r.id; await reload(); }
      return;
    }
    if ((b = e.target.closest('[data-aitest]'))) { const r = await run('interiorTest', { id: A.interior }, b); if (r.ok) hide(); return; }
    if ((b = e.target.closest('[data-adecoadd]'))) {
      const r = await run('decoModel', { model: val('[data-ad="model"]'), label: val('[data-ad="label"]'), cat: val('[data-ad="cat"]') }, b);
      if (r.ok) await reload();
      return;
    }
    if ((b = e.target.closest('[data-adecodel]'))) {
      if (!(await confirmBox('Retirer ce modèle ?', 'Les objets déjà posés restent en place ; il ne pourra plus être ajouté.', 'Retirer', true))) return;
      await run('decoModel', { model: b.dataset.adecodel, remove: true }, b);
      return reload();
    }
  });

  window.Admin = {
    async open(data, preview) {
      A.open = true;
      A.data = data;
      A.preview = !!preview;
      root().classList.remove('hidden');
      if (A.sel && A.sel !== 'new') return reload();
      draw();
    },
    hide() { A.open = false; root().classList.add('hidden'); },
    isOpen: () => A.open,
  };
})();
