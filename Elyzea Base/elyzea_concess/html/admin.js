/* =====================================================================
   ELYZEA CONCESSION - Administration automobile (staff, permission « dealer_manage »)
   Onglets : Concessions (création, points, sorties, exposition, catalogue propre :
   catégories et modèles avec Activé / Visible / Vendable / Exposable / Prix),
   Modèles (catalogue global, ajout vérifié dans le jeu), Catégories, Journal.
   Chaque bouton appelle le serveur, qui revérifie la permission.
   Les points se placent à la position du staff : fermez le panneau (Échap),
   placez-vous, rouvrez (/concessadmin) puis « Placer ici ». La sélection est gardée.
   ===================================================================== */
(() => {
  const A = { open: false, data: null, tab: 'shops', shop: null, sd: null, sub: 'setup', mq: '', mcat: '', dirtyM: {}, dirtyC: {}, model: null, check: null, results: null, rq: '',
    cat: null, preview: false, log: null };
  const root = () => $('#admin');
  const empty = (t) => `<div class="empty">${esc(t)}</div>`;
  const yesNo = (v) => (v ? '<span class="pill on">Oui</span>' : '<span class="pill off">Non</span>');
  const xyz = (p) => (p ? `${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)} · ${Math.round(p.h || 0)}°` : '');
  const val = (sel) => { const el = root().querySelector(sel); return el ? (el.type === 'checkbox' ? el.checked : el.value) : undefined; };
  const cats = () => (A.data ? A.data.categories : []);
  const catName = (id) => { const c = cats().find((x) => x.id === id); return c ? c.name : '—'; };

  async function run(action, data, btn) { return act(adm(action, data), btn); }
  async function reload() {
    const d = await adm('data');
    if (d.error) return toast(d.error, false);
    A.data = d;
    if (A.shop && A.shop !== 'new') {
      const s = await adm('shopData', { id: A.shop });
      A.sd = s.error ? null : s;
      if (!A.sd) A.shop = null;
      else if (A.preview) post('admPreview', { shop: previewShop() });
    }
    draw();
  }
  const previewShop = () => (A.sd ? { name: A.sd.shop.name, points: A.sd.shop.points, slots: A.sd.slots } : null);

  function draw() {
    if (!A.data) return;
    root().innerHTML = `<div class="adm-head"><h1>🚘 Administration automobile <span class="faint" style="font-size:.8rem;font-weight:500">Concessions · staff</span></h1>
        ${[['shops', 'Concessions'], ['models', 'Modèles'], ['cats', 'Catégories'], ['log', 'Journal']].map(([k, l]) => `<button class="btn small ${A.tab === k ? 'primary' : ''}" data-at="${k}">${l}</button>`).join('')}
        <label class="extra" title="Affiche les points de la concession choisie"><input type="checkbox" class="check" data-apreview ${A.preview ? 'checked' : ''}> Aperçu en jeu</label>
        <button class="icon-btn" data-aclose="1" aria-label="Fermer">✕</button></div>
      <div class="adm-body">${A.tab === 'shops' ? shopsTab() : A.tab === 'models' ? modelsTab() : A.tab === 'cats' ? catsTab() : logTab()}</div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Concessions                                                         */
  /* ------------------------------------------------------------------ */
  function shopsTab() {
    const list = A.data.shops.map((s) => `<button class="adm-item ${A.shop === s.id ? 'on' : ''}" data-ashop="${s.id}" style="${s.deleted ? 'opacity:.45' : ''}"><b>#${s.id} ${esc(s.name)}</b>
      <small>${s.deleted ? 'supprimée' : s.enabled ? 'ouverte' : 'fermée'} · ${s.offered} modèle(s) · ${s.employees} employé(s) · ${esc(s.job)}</small></button>`).join('');
    let main;
    if (A.shop === 'new') main = shopForm(null);
    else if (A.sd) main = shopDetail();
    else main = '<div class="note">Sélectionnez une concession ou créez-en une. Chaque concession a son métier, son compte de société, ses grades, ses points et SON catalogue (catégories, modèles, prix) : la modifier ne change jamais les autres.</div>';
    return `<div class="adm-list"><div style="margin-bottom:.5rem"><button class="btn small primary" data-anew="1">+ Nouvelle concession</button></div>${list || empty('Aucune concession.')}</div><div class="adm-main">${main}</div>`;
  }

  function shopForm(s) {
    const o = (s && s.options) || {};
    return `<div class="adm-section"><h3>${s ? 'Informations' : 'Nouvelle concession'}</h3><div class="form-grid">
        <label class="field"><span>Nom</span><input class="input" data-sf="name" maxlength="80" value="${esc(s ? s.name : '')}" placeholder="ex : Premium Deluxe Motorsport"></label>
        <label class="field"><span>Adresse</span><input class="input" data-sf="address" maxlength="120" value="${esc(s ? s.address : '')}"></label>
        <label class="field"><span>Métier (elyzea_core)</span><input class="input mono" data-sf="job" maxlength="40" value="${esc(s ? s.job : '')}" placeholder="ex : cardealer"></label>
        <label class="field"><span>Nom du métier affiché</span><input class="input" data-sf="jobLabel" maxlength="60" value="${esc(s ? s.jobLabel : '')}"></label>
        <label class="field"><span>Compte de société (vide = même nom que le métier)</span><input class="input mono" data-sf="society" maxlength="40" value="${esc(s ? s.society : '')}"></label>
        <label class="field"><span>Préfixe des matricules</span><input class="input mono" data-sf="matPrefix" maxlength="8" value="${esc(s ? s.matPrefix : 'CD-')}"></label>
        <label class="field"><span>Remise maximale (%)</span><input class="input" type="number" min="0" max="50" data-sf="maxDiscount" value="${o.maxDiscount ?? 10}"></label>
        <label class="field"><span>Blip : icône / couleur</span><span style="display:flex;gap:.4rem"><input class="input" type="number" min="1" max="900" data-sf="blipSprite" value="${o.blipSprite ?? 326}"><input class="input" type="number" min="0" max="85" data-sf="blipColor" value="${o.blipColor ?? 3}"></span></label>
        <label class="extra"><input type="checkbox" class="check" data-sf="requireDuty" ${o.requireDuty !== false ? 'checked' : ''}> Service obligatoire pour vendre / exposer</label>
        <label class="extra"><input type="checkbox" class="check" data-sf="blip" ${o.blip !== false ? 'checked' : ''}> Blip sur la carte</label></div>
      <div class="actions-row"><button class="btn primary" data-ssave="1">${s ? 'Enregistrer' : 'Créer la concession'}</button>${s ? '' : '<button class="btn" data-acancel="1">Annuler</button>'}</div>
      ${s ? '' : '<p class="faint" style="font-size:.78rem;margin-top:.5rem">La concession est créée fermée, avec 4 grades par défaut (modifiables dans sa tablette). Le métier et le compte de société sont créés dans elyzea_core s\'ils n\'existent pas.</p>'}</div>`;
  }

  function shopDetail() {
    const s = A.sd.shop, pts = s.points || {};
    const missing = [];
    if (!pts.catalog) missing.push('point de consultation du catalogue');
    if (!(pts.exits || []).length) missing.push('place de sortie des véhicules');
    if (!s.offered) missing.push('modèles proposés (onglet Catalogue)');
    const subs = [['setup', 'Réglages et points'], ['cats', 'Catégories'], ['models', 'Modèles et prix'], ['display', 'Exposition']];
    let body = '';
    if (A.sub === 'setup') body = shopForm(s) + pointsSection(s) + `<div class="adm-section"><h3>Personnel</h3>
        <p class="faint" style="font-size:.8rem;margin-bottom:.4rem">Nommer un responsable : le joueur reçoit le plus haut grade de cette concession (métier ${esc(s.job)}).</p>
        <div style="display:flex;gap:.4rem;max-width:26rem"><input class="input" type="number" min="1" data-boss placeholder="ID serveur du joueur"><button class="btn" data-sboss="1">Nommer</button></div></div>`;
    else if (A.sub === 'cats') body = catsConfig();
    else if (A.sub === 'models') body = modelsConfig();
    else body = slotsSection();
    return `<div class="adm-section"><div style="display:flex;gap:.6rem;align-items:center;flex-wrap:wrap"><b style="font-size:1.1rem">#${s.id} ${esc(s.name)}</b>
        ${s.deleted ? '<span class="pill bad">Supprimée</span>' : s.enabled ? '<span class="pill on">Ouverte</span>' : '<span class="pill off">Fermée</span>'}
        <span class="faint" style="font-size:.8rem">${s.offered} proposés · ${s.sellable} vendables · ${s.shown}/${s.slots} exposés · solde ${money(s.balance)}</span><span style="flex:1"></span>
        ${s.deleted ? '' : `<button class="btn small ${s.enabled ? '' : 'success'}" data-sen="${s.enabled ? 0 : 1}">${s.enabled ? 'Fermer' : 'Ouvrir'}</button><button class="btn small danger" data-sdel="1">Supprimer</button>`}</div>
        ${missing.length && !s.deleted ? `<div class="warn-box" style="margin-top:.6rem">À compléter avant l'ouverture : ${missing.map(esc).join(', ')}.</div>` : ''}
        <div class="mgr-tabs" style="margin-top:.7rem">${subs.map(([k, l]) => `<button class="${A.sub === k ? 'on' : ''}" data-asub="${k}">${l}</button>`).join('')}</div></div>${body}`;
  }

  function pointsSection(s) {
    const pts = s.points || {};
    const row = (key, label, color, help) => {
      const p = pts[key];
      return `<div class="pt-row"><span class="sw" style="background:${color}"></span><div><b>${label}</b><small>${help} · ${p ? `${xyz(p)}${p.on === false ? ' · <b style="color:#fca5a5">désactivé</b>' : ''}` : '<span style="color:#fcd34d">non placé</span>'}</small></div>
        <div class="acts">${p ? `<input class="input" type="number" step="0.1" min="0.6" max="10" value="${p.r || 1.5}" data-pr="${key}" title="Rayon (m)"><label class="extra" title="Actif"><input type="checkbox" class="check" data-pon="${key}" ${p.on !== false ? 'checked' : ''}></label>
          <button class="btn small" data-ptp="${key}">Aller</button>` : ''}<button class="btn small primary" data-pset="${key}">Placer ici</button>${p ? `<button class="btn small danger" data-pdel="${key}">✕</button>` : ''}</div></div>`;
    };
    const exits = (pts.exits || []).map((p, i) => `<div class="pt-row"><span class="sw" style="background:#22c55e"></span><div><b>Sortie ${i + 1}</b><small>${xyz(p)}${p.on === false ? ' · désactivée' : ''}</small></div>
      <div class="acts"><input class="input" type="number" step="5" value="${Math.round(p.h || 0)}" data-exh="${i + 1}" title="Orientation (°)"><label class="extra" title="Active"><input type="checkbox" class="check" data-exon="${i + 1}" ${p.on !== false ? 'checked' : ''}></label>
        <button class="btn small" data-extp="${i + 1}">Aller</button><button class="btn small danger" data-exdel="${i + 1}">✕</button></div></div>`).join('');
    return `<div class="adm-section"><h3>Points</h3>
      ${row('catalog', 'Consultation du catalogue', '#3b82f6', 'Clients : E → catalogue sans achat')}
      ${row('preview', 'Aperçu du véhicule', '#a855f7', 'Où apparaît le véhicule d\'aperçu (orientation comprise)')}
      ${row('manage', 'Point de gestion', '#f59e0b', 'Employés : E → tablette')}
      <h3 style="margin-top:.8rem">Zone de sortie des véhicules achetés</h3>${exits || empty('Aucune place de sortie.')}
      <div class="actions-row"><button class="btn small primary" data-exadd="1">+ Place de sortie ici (au volant, orientée vers la sortie)</button></div>
      <p class="faint" style="font-size:.76rem;margin-top:.4rem">Les positions et orientations sont celles du staff (ou de son véhicule) au moment du clic. Fermez le panneau (Échap), placez-vous, rouvrez /concessadmin.</p></div>`;
  }

  function slotsSection() {
    const slots = A.sd.slots.map((s) => `<div class="pt-row"><span class="sw" style="background:#ec4899"></span><div><b>${esc(s.label || `Emplacement ${s.id}`)}</b><small>${xyz(s)} · ${s.model ? `exposé : ${esc(s.model)}` : 'libre'}${s.enabled ? '' : ' · désactivé'}</small></div>
      <div class="acts"><input class="input" type="number" step="5" value="${Math.round(s.h || 0)}" data-slh="${s.id}" title="Orientation (°)"><label class="extra" title="Actif"><input type="checkbox" class="check" data-slon="${s.id}" ${s.enabled ? 'checked' : ''}></label>
        <button class="btn small" data-sltp="${s.id}">Aller</button><button class="btn small" data-slmove="${s.id}">Déplacer ici</button><button class="btn small danger" data-sldel="${s.id}">✕</button></div></div>`).join('');
    return `<div class="adm-section"><h3>Emplacements d'exposition</h3>${slots || empty('Aucun emplacement.')}
      <div style="display:flex;gap:.4rem;margin-top:.6rem;max-width:30rem"><input class="input" data-sllabel maxlength="40" placeholder="Nom (facultatif) : ex. Vitrine 1"><button class="btn primary" data-sladd="1">+ Emplacement ici</button></div>
      <p class="faint" style="font-size:.76rem;margin-top:.4rem">Les employés autorisés y placent les modèles exposables. Un emplacement = un véhicule. Les véhicules exposés sont restaurés après un redémarrage.</p></div>`;
  }

  function catsConfig() {
    const rows = A.sd.categories.map((c) => {
      const d = A.dirtyC[c.id] || {};
      const v = (k) => (d[k] !== undefined ? d[k] : c[k]);
      return `<tr style="${c.global ? '' : 'opacity:.5'}"><td>${esc(c.icon || '')} <b>${esc(c.name)}</b>${c.global ? '' : '<br><small class="faint">désactivée globalement</small>'}</td>
        ${['enabled', 'visible', 'sellable'].map((k) => `<td><input type="checkbox" class="check" data-cc="${c.id}" data-ck="${k}" ${v(k) ? 'checked' : ''}></td>`).join('')}
        <td><input class="input" type="number" style="width:5rem" data-cc="${c.id}" data-ck="sort" value="${v('sort') ?? 0}"></td>
        <td><button class="btn small" data-caddall="${c.id}" title="Active la catégorie et ajoute tous ses modèles au prix de référence">+ Tous ses modèles</button></td></tr>`;
    }).join('');
    const n = Object.keys(A.dirtyC).length;
    return `<div class="adm-section"><h3>Catégories de cette concession</h3>
      <div class="note">Activée = proposée par la concession · Visible = affichée dans le catalogue client · Vendable = les employés peuvent vendre ses modèles. Indépendant des autres concessions.</div>
      <table class="tbl"><tr><th>Catégorie</th><th>Activée</th><th>Visible</th><th>Vendable</th><th>Ordre</th><th></th></tr>${rows}</table>
      <div class="actions-row"><button class="btn primary" data-ccsave="1" ${n ? '' : 'disabled'}>Enregistrer (${n})</button></div></div>`;
  }

  function modelsConfig() {
    const q = A.mq.trim().toLowerCase();
    const list = A.sd.models.filter((m) => (!q || `${m.label} ${m.model}`.toLowerCase().includes(q)) && (!A.mcat || String(m.categoryId) === A.mcat));
    const rows = list.map((m) => {
      const d = A.dirtyM[m.id] || {};
      const v = (k) => (d[k] !== undefined ? d[k] : m[k]);
      const eff = m.effective;
      return `<tr style="${m.global && m.categoryId ? '' : 'opacity:.55'}"><td><b>${esc(m.label)}</b><br><small class="mono faint">${esc(m.model)} · ${esc(catName(m.categoryId))}</small>
          ${!m.global ? '<br><small style="color:#fca5a5">désactivé globalement</small>' : ''}${!m.commercial ? '<br><small style="color:#fcd34d">vente interdite (global)</small>' : ''}</td>
        ${['enabled', 'visible', 'sellable', 'displayable'].map((k) => `<td><input type="checkbox" class="check" data-mm="${m.id}" data-mk="${k}" ${v(k) ? 'checked' : ''}></td>`).join('')}
        <td><input class="input" type="number" min="1" style="width:8rem" data-mm="${m.id}" data-mk="price" value="${v('price') ?? ''}" placeholder="${m.refPrice != null ? `réf. ${m.refPrice}` : 'à définir'}"></td>
        <td>${eff ? `${eff.sellable ? '<span class="pill on">Vendable</span>' : `<span class="pill bad" title="${esc(eff.reason || '')}">Non vendable</span>`}${eff.visible ? '' : ' <span class="pill off">Masqué</span>'}<br><small class="faint">${money(eff.price)}</small>` : '<span class="pill off">Non proposé</span>'}</td></tr>`;
    }).join('');
    const n = Object.keys(A.dirtyM).length;
    return `<div class="adm-section"><h3>Modèles de cette concession</h3>
      <div class="toolbar"><input class="input grow" data-amq placeholder="Rechercher un modèle" value="${esc(A.mq)}">
        <select class="input" data-amcat><option value="">Toutes catégories</option>${cats().map((c) => `<option value="${c.id}" ${A.mcat === String(c.id) ? 'selected' : ''}>${esc(c.name)}</option>`).join('')}</select>
        <button class="btn primary" data-mmsave="1" ${n ? '' : 'disabled'}>Enregistrer (${n})</button></div>
      <div class="note">Activé = proposé · Visible = dans le catalogue client · Vendable = vente autorisée · Exposable = exposition autorisée · Prix propre à CETTE concession (vide = prix de référence). Le statut tient compte des réglages globaux et de la catégorie.</div>
      ${list.length ? `<table class="tbl"><tr><th>Modèle</th><th>Activé</th><th>Visible</th><th>Vendable</th><th>Exposable</th><th>Prix ($)</th><th>Résultat</th></tr>${rows}</table>` : empty('Aucun modèle dans le catalogue global : ajoutez-en dans l\'onglet Modèles.')}</div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Catalogue global : modèles                                          */
  /* ------------------------------------------------------------------ */
  function modelsTab() {
    const q = A.mq.trim().toLowerCase();
    const list = A.data.models.filter((m) => !q || `${m.label} ${m.model} ${m.brand || ''}`.toLowerCase().includes(q));
    const items = list.map((m) => `<button class="adm-item ${A.model === m.id ? 'on' : ''}" data-amod="${m.id}" style="${m.removed ? 'opacity:.45' : ''}"><b>${esc(m.label)}</b>
      <small><span class="mono">${esc(m.model)}</span> · ${esc(m.category || 'sans catégorie')}${m.removed ? ' · retiré' : !m.enabled ? ' · désactivé' : ''}</small></button>`).join('');
    const m = A.model === 'new' ? null : A.data.models.find((x) => x.id === A.model);
    return `<div class="adm-list"><div style="display:flex;gap:.4rem;margin-bottom:.5rem"><input class="input grow" data-amq placeholder="Rechercher" value="${esc(A.mq)}"><button class="btn small primary" data-amnew="1">+ Ajouter</button></div>
        ${items || empty('Aucun modèle.')}</div>
      <div class="adm-main">${A.model === 'new' ? addModel() : m ? modelForm(m) : '<div class="note">Le catalogue global contient les modèles autorisés sur le serveur. Chaque concession choisit ensuite ceux qu\'elle propose, affiche, vend et expose, avec ses propres prix.</div>'}</div>`;
  }

  function addModel() {
    const c = A.check;
    const res = (A.results || []).map((r) => `<div class="list-row"><div class="main"><b>${esc(r.label)}</b><small class="mono">${esc(r.model)}${r.brand ? ` · ${esc(r.brand)}` : ''} · classe ${r.class} · ${r.seats} place(s)</small></div>
      <button class="btn small" data-apick="${esc(r.model)}">Choisir</button></div>`).join('');
    return `<div class="adm-section"><h3>1. Trouver le modèle dans le jeu</h3>
        <div style="display:flex;gap:.4rem;max-width:34rem"><input class="input grow" data-arq placeholder="Nom ou nom de spawn (2 lettres min.)" value="${esc(A.rq)}"><button class="btn" data-asearch="1">Rechercher</button></div>
        <p class="faint" style="font-size:.76rem;margin:.4rem 0">Recherche dans la liste réelle des modèles chargés par votre jeu (véhicules ajoutés par des ressources compris).</p>${A.results ? (res || empty('Aucun modèle trouvé.')) : ''}
        <div style="display:flex;gap:.4rem;max-width:34rem;margin-top:.6rem"><input class="input grow mono" data-amodel placeholder="ou saisir le nom de spawn exact" value="${esc(c ? c.model : '')}"><button class="btn" data-acheck="1">Vérifier dans le jeu</button></div>
        ${c ? (c.ok ? `<div class="note" style="margin-top:.6rem">✅ <b>${esc(c.model)}</b> existe : ${esc(c.label)}${c.brand ? ` · ${esc(c.brand)}` : ''} · classe ${c.class} · ${c.seats} place(s).</div>`
          : `<div class="warn-box" style="margin-top:.6rem">${esc(c.error)}</div>`) : ''}</div>
      ${c && c.ok ? `<div class="adm-section"><h3>2. Fiche du modèle</h3>${modelFields({ label: c.label, brand: c.brand, commercial: true, displayable: true, enabled: true })}
        <div class="actions-row"><button class="btn primary" data-amsave="1">Ajouter au catalogue global</button></div></div>` : ''}`;
  }

  function modelFields(m) {
    return `<div class="form-grid">
      <label class="field"><span>Nom commercial</span><input class="input" data-mf="label" maxlength="80" value="${esc(m.label || '')}"></label>
      <label class="field"><span>Marque</span><input class="input" data-mf="brand" maxlength="50" value="${esc(m.brand || '')}"></label>
      <label class="field"><span>Catégorie</span><select class="input" data-mf="categoryId"><option value="">— Sans catégorie (non proposé) —</option>${cats().map((c) => `<option value="${c.id}" ${m.categoryId === c.id ? 'selected' : ''}>${esc(c.name)}${c.enabled ? '' : ' (désactivée)'}</option>`).join('')}</select></label>
      <label class="field"><span>Prix de référence ($, facultatif)</span><input class="input" type="number" min="0" data-mf="refPrice" value="${m.refPrice ?? ''}"></label>
      <label class="field full"><span>Image (adresse web, facultatif : sinon image du jeu de base)</span><input class="input" data-mf="image" maxlength="255" value="${esc(m.image || '')}"></label>
      <label class="field full"><span>Description</span><textarea class="input" data-mf="description" maxlength="500">${esc(m.description || '')}</textarea></label>
      <label class="extra"><input type="checkbox" class="check" data-mf="enabled" ${m.enabled !== false ? 'checked' : ''}> Actif (désactivé : plus vendable nulle part)</label>
      <label class="extra"><input type="checkbox" class="check" data-mf="commercial" ${m.commercial !== false ? 'checked' : ''}> Usage commercial autorisé (vente)</label>
      <label class="extra"><input type="checkbox" class="check" data-mf="displayable" ${m.displayable !== false ? 'checked' : ''}> Mise en exposition autorisée</label></div>`;
  }

  function modelForm(m) {
    return `<div class="adm-section"><h3>${esc(m.label)} <span class="mono faint" style="text-transform:none;letter-spacing:0">${esc(m.model)}</span></h3>
        <p class="faint" style="font-size:.8rem;margin-bottom:.5rem">Vérifié en jeu par ${esc(m.validatedBy || '—')} · classe ${m.vclass ?? '—'} · ${m.seats ?? '—'} place(s) · proposé par : ${m.shops.length ? m.shops.map(esc).join(', ') : 'aucune concession'}</p>
        ${modelFields(m)}
        <div class="actions-row"><button class="btn primary" data-amsave="1">Enregistrer</button>
          <button class="btn ${m.removed ? 'success' : 'danger'}" data-amrem="${m.removed ? 'restore' : 'remove'}">${m.removed ? 'Remettre au catalogue' : 'Retirer du catalogue'}</button>
          <button class="btn" data-amlog="1">Historique</button></div>
        <p class="faint" style="font-size:.76rem;margin-top:.5rem">Retirer ne supprime jamais les véhicules déjà achetés, leurs clés, leurs garages ni l'historique des ventes.</p></div>`;
  }
  function modelData() {
    const g = (k) => val(`[data-mf="${k}"]`);
    return { label: g('label'), brand: g('brand'), categoryId: g('categoryId'), refPrice: g('refPrice'), image: g('image'), description: g('description'),
      enabled: g('enabled'), commercial: g('commercial'), displayable: g('displayable') };
  }

  /* ------------------------------------------------------------------ */
  /* Catégories globales                                                 */
  /* ------------------------------------------------------------------ */
  function catsTab() {
    const list = cats().map((c) => `<button class="adm-item ${A.cat === c.id ? 'on' : ''}" data-acat="${c.id}" style="${c.enabled ? '' : 'opacity:.5'}"><b>${esc(c.icon || '•')} ${esc(c.name)}</b>
      <small>${c.models} modèle(s) · ${c.shops.length} concession(s)${c.enabled ? '' : ' · désactivée'}</small></button>`).join('');
    const c = A.cat === 'new' ? {} : cats().find((x) => x.id === A.cat);
    let main = '<div class="note">Les catégories ne sont pas figées dans le code : créez-les, renommez-les, ordonnez-les, désactivez-les. Désactiver une catégorie la retire des nouvelles ventes partout ; rien n\'est supprimé.</div>';
    if (c) {
      const inCat = A.data.models.filter((m) => m.categoryId === c.id && !m.removed);
      const others = A.data.models.filter((m) => m.categoryId !== c.id && !m.removed);
      main = `<div class="adm-section"><h3>${c.id ? 'Catégorie' : 'Nouvelle catégorie'}</h3><div class="form-grid">
          <label class="field"><span>Nom</span><input class="input" data-cf2="name" maxlength="50" value="${esc(c.name || '')}"></label>
          <label class="field"><span>Icône (emoji)</span><input class="input" data-cf2="icon" maxlength="16" value="${esc(c.icon || '')}"></label>
          <label class="field"><span>Ordre d'affichage</span><input class="input" type="number" data-cf2="sort" value="${c.sort ?? 0}"></label>
          <label class="field"><span>Image (adresse web, facultatif)</span><input class="input" data-cf2="image" maxlength="255" value="${esc(c.image || '')}"></label>
          <label class="field full"><span>Description</span><input class="input" data-cf2="description" maxlength="255" value="${esc(c.description || '')}"></label>
          <label class="extra"><input type="checkbox" class="check" data-cf2="enabled" ${c.enabled !== false ? 'checked' : ''}> Active</label></div>
          <div class="actions-row"><button class="btn primary" data-csave="1">${c.id ? 'Enregistrer' : 'Créer'}</button></div>
          ${c.id ? `<p class="faint" style="font-size:.78rem;margin-top:.5rem">Utilisée par : ${c.shops.length ? c.shops.map(esc).join(', ') : 'aucune concession'}.</p>` : ''}</div>
        ${c.id ? `<div class="adm-section"><h3>Modèles de la catégorie (${inCat.length})</h3>${inCat.map((m) => `<div class="list-row"><div class="main"><b>${esc(m.label)}</b><small class="mono">${esc(m.model)}</small></div>
            <button class="btn small danger" data-cunassign="${m.id}">Retirer</button></div>`).join('') || empty('Aucun modèle.')}
          <div style="display:flex;gap:.4rem;margin-top:.6rem;max-width:34rem"><select class="input grow" data-cpick>${others.map((m) => `<option value="${m.id}">${esc(m.label)} (${esc(m.model)}) · ${esc(m.category || 'sans catégorie')}</option>`).join('')}</select>
            <button class="btn" data-cassign="1" ${others.length ? '' : 'disabled'}>Associer</button></div></div>` : ''}`;
    }
    return `<div class="adm-list"><div style="margin-bottom:.5rem"><button class="btn small primary" data-acnew="1">+ Nouvelle catégorie</button></div>${list || empty('Aucune catégorie.')}</div><div class="adm-main">${main}</div>`;
  }

  function logTab() {
    const l = A.log || [];
    return `<div class="adm-main" style="grid-column:1/-1"><div class="adm-section"><h3>Journal des modifications</h3>
      ${l.length ? `<table class="tbl"><tr><th>Date</th><th>Action</th><th>Détail</th><th>Par</th></tr>${l.map((x) => `<tr><td class="muted">${fmtTime(x.t)}</td><td><b>${esc(x.action)}</b></td><td class="muted">${esc(x.details || '')}</td><td>${esc(x.actor_name || '')}</td></tr>`).join('')}</table>` : empty('Aucune entrée.')}</div></div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Événements                                                          */
  /* ------------------------------------------------------------------ */
  const keepInput = (sel, fn) => { const el = root().querySelector(sel); const pos = el ? el.selectionStart : 0; fn(); const n = root().querySelector(sel); if (n) { n.focus(); n.setSelectionRange(pos, pos); } };
  root().addEventListener('input', (e) => {
    const t = e.target;
    if (t.dataset.amq !== undefined) { A.mq = t.value; return keepInput('[data-amq]', draw); }
  });
  root().addEventListener('keydown', (e) => {
    if (e.key !== 'Enter') return;
    if (e.target.dataset.arq !== undefined) { e.preventDefault(); root().querySelector('[data-asearch]').click(); }
    if (e.target.dataset.amodel !== undefined) { e.preventDefault(); root().querySelector('[data-acheck]').click(); }
  });
  root().addEventListener('change', async (e) => {
    const t = e.target;
    if (t.dataset.apreview !== undefined) {
      A.preview = t.checked;
      const r = await post('admPreview', { shop: A.preview ? previewShop() : null });
      if (A.preview && !(r && r.on)) toast('Choisissez d\'abord une concession.', false);
      return;
    }
    if (t.dataset.amcat !== undefined) { A.mcat = t.value; return draw(); }
    if (t.dataset.cc) { A.dirtyC[t.dataset.cc] = A.dirtyC[t.dataset.cc] || {}; A.dirtyC[t.dataset.cc][t.dataset.ck] = t.type === 'checkbox' ? t.checked : Number(t.value); return draw(); }
    if (t.dataset.mm) {
      A.dirtyM[t.dataset.mm] = A.dirtyM[t.dataset.mm] || {};
      A.dirtyM[t.dataset.mm][t.dataset.mk] = t.type === 'checkbox' ? t.checked : (t.value === '' ? '' : Number(t.value));
      return draw();
    }
    const id = A.shop;
    if (t.dataset.pr) { await run('pointSet', { id, key: t.dataset.pr, r: Number(t.value) }); return reload(); }
    if (t.dataset.pon) { await run('pointSet', { id, key: t.dataset.pon, on: t.checked }); return reload(); }
    if (t.dataset.exh) { await run('pointSet', { id, key: 'exit', index: Number(t.dataset.exh), h: Number(t.value) }); return reload(); }
    if (t.dataset.exon) { await run('pointSet', { id, key: 'exit', index: Number(t.dataset.exon), on: t.checked }); return reload(); }
    if (t.dataset.slh) { await run('slot', { id, slot: Number(t.dataset.slh), h: Number(t.value) }); return reload(); }
    if (t.dataset.slon) { await run('slot', { id, slot: Number(t.dataset.slon), enabled: t.checked }); return reload(); }
  });

  root().addEventListener('click', async (e) => {
    let b;
    if (e.target.closest('[data-aclose]')) return post('close', { ui: 'admin' });
    if ((b = e.target.closest('[data-at]'))) {
      A.tab = b.dataset.at;
      if (A.tab === 'log') { const r = await adm('log', {}); A.log = r.list || []; }
      return draw();
    }
    // Concessions
    if ((b = e.target.closest('[data-ashop]'))) { A.shop = Number(b.dataset.ashop); A.dirtyM = {}; A.dirtyC = {}; return reload(); }
    if (e.target.closest('[data-anew]')) { A.shop = 'new'; A.sd = null; return draw(); }
    if (e.target.closest('[data-acancel]')) { A.shop = null; return draw(); }
    if ((b = e.target.closest('[data-asub]'))) { A.sub = b.dataset.asub; return draw(); }
    if ((b = e.target.closest('[data-ssave]'))) {
      const g = (k) => val(`[data-sf="${k}"]`);
      const d = { name: g('name'), address: g('address'), job: g('job'), jobLabel: g('jobLabel'), society: g('society'), matPrefix: g('matPrefix'), maxDiscount: Number(g('maxDiscount')),
        blipSprite: Number(g('blipSprite')), blipColor: Number(g('blipColor')), requireDuty: g('requireDuty'), blip: g('blip') };
      if (A.shop !== 'new') d.id = A.shop;
      const r = await run('shopSave', d, b);
      if (r.ok) { A.shop = r.id; await reload(); }
      return;
    }
    if ((b = e.target.closest('[data-sen]'))) { await run('shopEnable', { id: A.shop, enabled: b.dataset.sen === '1' }, b); return reload(); }
    if (e.target.closest('[data-sdel]')) {
      const s = A.sd.shop;
      const v = await confirmBox('Supprimer la concession ?', `<b>${esc(s.name)}</b> sera fermée définitivement, ses employés retirés du métier. Les véhicules vendus, les clés, les garages, les ventes et les finances sont <b>conservés</b>.`, 'Supprimer', true,
        `<label class="field" style="margin-top:.6rem"><span>Tapez le nom exact pour confirmer</span><input class="input" data-cfv="confirm"></label>`);
      if (!v) return;
      const r = await run('shopDelete', { id: s.id, confirm: v.confirm });
      if (r.ok) await reload();
      return;
    }
    if (e.target.closest('[data-sboss]')) { const r = await run('setBoss', { id: A.shop, target: Number(val('[data-boss]')) }); if (r.ok) await reload(); return; }
    if ((b = e.target.closest('[data-pset]'))) { await run('point', { id: A.shop, key: b.dataset.pset }, b); return reload(); }
    if ((b = e.target.closest('[data-pdel]'))) { if (!(await confirmBox('Retirer ce point ?', '', 'Retirer', true))) return; await run('point', { id: A.shop, key: b.dataset.pdel, remove: true }); return reload(); }
    if ((b = e.target.closest('[data-ptp]'))) { const r = await run('teleport', { id: A.shop, key: b.dataset.ptp }); if (r.ok) post('adminHide', {}); return; }
    if ((b = e.target.closest('[data-exadd]'))) { await run('point', { id: A.shop, key: 'exit' }, b); return reload(); }
    if ((b = e.target.closest('[data-exdel]'))) { await run('point', { id: A.shop, key: 'exit', remove: true, index: Number(b.dataset.exdel) }); return reload(); }
    if ((b = e.target.closest('[data-extp]'))) { const r = await run('teleport', { id: A.shop, key: 'exit', index: Number(b.dataset.extp) }); if (r.ok) post('adminHide', {}); return; }
    if ((b = e.target.closest('[data-sladd]'))) { await run('slot', { id: A.shop, label: val('[data-sllabel]') }, b); return reload(); }
    if ((b = e.target.closest('[data-slmove]'))) { await run('slot', { id: A.shop, slot: Number(b.dataset.slmove), move: true }, b); return reload(); }
    if ((b = e.target.closest('[data-sldel]'))) {
      if (!(await confirmBox('Supprimer l\'emplacement ?', 'Le véhicule exposé dessus est retiré.', 'Supprimer', true))) return;
      await run('slot', { id: A.shop, slot: Number(b.dataset.sldel), remove: true }); return reload();
    }
    if ((b = e.target.closest('[data-sltp]'))) { const r = await run('teleport', { id: A.shop, key: 'slot', slot: Number(b.dataset.sltp) }); if (r.ok) post('adminHide', {}); return; }
    if ((b = e.target.closest('[data-ccsave]'))) {
      const list = Object.entries(A.dirtyC).map(([id, f]) => ({ id: Number(id), ...f }));
      const r = await run('shopCats', { id: A.shop, list }, b);
      if (r.ok) { A.dirtyC = {}; await reload(); }
      return;
    }
    if ((b = e.target.closest('[data-caddall]'))) { await run('shopAddCategory', { id: A.shop, cat: Number(b.dataset.caddall) }, b); A.dirtyC = {}; return reload(); }
    if ((b = e.target.closest('[data-mmsave]'))) {
      const list = Object.entries(A.dirtyM).map(([id, f]) => ({ id: Number(id), ...f }));
      const r = await run('shopModels', { id: A.shop, list }, b);
      if (r.ok) { A.dirtyM = {}; await reload(); }
      return;
    }
    // Modèles
    if ((b = e.target.closest('[data-amod]'))) { A.model = Number(b.dataset.amod); return draw(); }
    if (e.target.closest('[data-amnew]')) { A.model = 'new'; A.check = null; A.results = null; return draw(); }
    if ((b = e.target.closest('[data-asearch]'))) {
      A.rq = val('[data-arq]') || '';
      b.classList.add('loading');
      const r = await post('admVehSearch', { q: A.rq });
      A.results = r.list || [];
      return draw();
    }
    if ((b = e.target.closest('[data-apick]'))) { A.check = await post('admVehCheck', { model: b.dataset.apick }); return draw(); }
    if (e.target.closest('[data-acheck]')) { A.check = await post('admVehCheck', { model: val('[data-amodel]') || '' }); return draw(); }
    if ((b = e.target.closest('[data-amsave]'))) {
      const d = modelData();
      if (A.model === 'new') { d.model = A.check.model; d.check = A.check; } else d.id = A.model;
      const r = await run('modelSave', d, b);
      if (r.ok) { A.model = r.id; A.check = null; A.results = null; await reload(); }
      return;
    }
    if ((b = e.target.closest('[data-amrem]'))) {
      const restore = b.dataset.amrem === 'restore';
      if (!restore && !(await confirmBox('Retirer ce modèle du catalogue ?', 'Il ne sera plus proposé, vendu ni exposé nulle part. Les véhicules déjà achetés, leurs clés et l\'historique restent intacts.', 'Retirer', true))) return;
      await run('modelRemove', { id: A.model, restore });
      return reload();
    }
    if (e.target.closest('[data-amlog]')) {
      const r = await adm('log', { model: A.model });
      return confirmBox('Historique du modèle', (r.list || []).map((x) => `<div class="list-row"><div class="main"><b>${esc(x.action)}</b><small>${esc(x.details || '')} · ${esc(x.actor_name || '')} · ${fmtTime(x.t)}</small></div></div>`).join('') || 'Aucune entrée.', 'Fermer');
    }
    // Catégories
    if ((b = e.target.closest('[data-acat]'))) { A.cat = Number(b.dataset.acat); return draw(); }
    if (e.target.closest('[data-acnew]')) { A.cat = 'new'; return draw(); }
    if ((b = e.target.closest('[data-csave]'))) {
      const g = (k) => val(`[data-cf2="${k}"]`);
      const d = { name: g('name'), icon: g('icon'), sort: Number(g('sort')), image: g('image'), description: g('description'), enabled: g('enabled') };
      if (A.cat !== 'new') d.id = A.cat;
      const r = await run('catSave', d, b);
      if (r.ok) { A.cat = r.id; await reload(); }
      return;
    }
    if ((b = e.target.closest('[data-cassign]'))) { await run('catAssign', { id: A.cat, models: [Number(val('[data-cpick]'))] }, b); return reload(); }
    if ((b = e.target.closest('[data-cunassign]'))) { await run('catAssign', { id: A.cat, models: [Number(b.dataset.cunassign)], remove: true }, b); return reload(); }
  });

  window.Admin = {
    open(data, preview) {
      A.open = true;
      A.data = data;
      A.preview = !!preview;
      root().classList.remove('hidden');
      if (A.shop && A.shop !== 'new') return reload();
      draw();
    },
    hide() { A.open = false; root().classList.add('hidden'); },
    isOpen: () => A.open,
  };
})();
