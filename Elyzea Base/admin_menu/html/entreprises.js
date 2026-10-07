/* =========================================================
   MÉTIERS › ENTREPRISES (ressource elyzea_entreprises, permission « entreprises_staff »)
   Un onglet par entreprise : Taxi, Burger Shot, Boîte de nuit.
   Informations, grades, permissions, zones, carte et prix, recettes,
   fournisseur, configuration (véhicules, compteur, courses, entrée), tenues.
   ========================================================= */
(() => {
    const COMPANIES = [
        { key: 'taxi', ico: '🚕', label: 'Taxi', sub: 'Compteur, courses PNJ, grades, zones, véhicules, tenues.' },
        { key: 'burgershot', ico: '🍔', label: 'Burger Shot', sub: 'Carte et prix, recettes, fournisseur, grades, zones, tenues.' },
        { key: 'nightclub', ico: '🍸', label: 'Boîte de nuit', sub: 'Bar, entrée, carte et prix, fournisseur, grades, zones, tenues.' },
    ];
    const ES = {};   // [company] = { sub, drafts… }
    const clone = (o) => JSON.parse(JSON.stringify(o));
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const tabId = (k) => `ent_${k}`;
    const companyOfTab = () => (tab || '').startsWith('ent_') ? tab.slice(4) : null;
    const dataOf = (k) => (D && D.entreprises && D.entreprises.companies ? D.entreprises.companies[k] : null);
    const send = (k, name, data = {}) => action('entreprises', { name, data: { company: k, ...data } });

    for (const c of COMPANIES) {
        TABS.push({
            id: tabId(c.key), group: 5, label: c.label, ico: c.ico, sub: c.sub,
            show: () => has('entreprises_staff') && !!(D && D.entreprises),
        });
        VIEWS[tabId(c.key)] = () => view(c.key);
    }

    function state(k) {
        ES[k] = ES[k] || { sub: 'info' };
        return ES[k];
    }

    function subs(d) {
        const f = d.features || {};
        const list = [{ id: 'info', label: 'Informations' }, { id: 'grades', label: 'Grades' }, { id: 'perms', label: 'Permissions' },
            { id: 'zones', label: 'Zones' }, { id: 'menu', label: 'Carte & prix' }];
        if (f.production) list.push({ id: 'recipes', label: 'Recettes' }, { id: 'supplies', label: 'Fournisseur' });
        if (f.meter || f.missions) list.push({ id: 'taxi', label: 'Compteur & courses' });
        list.push({ id: 'config', label: 'Configuration' }, { id: 'uniforms', label: 'Tenues' });
        return list;
    }

    function view(k) {
        const all = D.entreprises;
        if (!all.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(all.resource || 'elyzea_entreprises')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure elyzea_entreprises</span> dans server.cfg, après admin_menu.</span></div>`;
        }
        const d = dataOf(k);
        if (!d) return '<div class="empty">Entreprise introuvable.</div>';
        const s = state(k);
        if (!s.general) s.general = { label: d.job.label, type: d.job.type || '', defaultDuty: !!d.job.defaultDuty, offDutyPay: !!d.job.offDutyPay };
        if (!s.grades) s.grades = clone(d.job.grades);
        if (!s.perms) s.perms = clone(d.perms || {});
        if (!s.menu) s.menu = clone(d.menu || []);
        if (!s.recipes) s.recipes = clone(d.recipes || []);
        if (!s.supplies) s.supplies = clone(d.supplies || []);
        if (!s.settings) s.settings = clone(d.settings || {});
        if (!s.zoneType) s.zoneType = 'all';
        const list = subs(d);
        if (!list.find((x) => x.id === s.sub)) s.sub = 'info';
        const nav = `<div class="segmented">${list.map((x) => `<button class="seg ${x.id === s.sub ? 'active' : ''}" data-ens="${x.id}">${x.label}</button>`).join('')}</div>`;
        return nav + (SUB[s.sub] || SUB.info)(k, d, s);
    }

    const SUB = {};
    const tog = (k, title, sub, on) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-entog="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;

    /* ---------- Informations ---------- */
    SUB.info = (k, d, s) => {
        const st = d.stats, g = s.general;
        return `<div class="stats">
                <div class="stat"><b>${st.duty}</b><span>En service</span></div>
                <div class="stat"><b>${st.online}</b><span>Employés connectés</span></div>
                <div class="stat" data-ens="zones"><b>${st.zones}</b><span>Zones</span></div>
                <div class="stat"><b>${st.invoicesToday}</b><span>Factures aujourd'hui · ${money(st.revenueToday)}</span></div>
                <div class="stat"><b>${money(st.balance)}</b><span>Compte de l'entreprise</span></div></div>
            <div class="section"><h2>${esc(d.icon)} ${esc(d.job.label)}</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    <div class="tile toggle-tile ${d.enabled ? 'on' : ''}" data-ena="toggleEnabled"><div><strong>${d.enabled ? 'Ouvert' : 'Fermé'}</strong>
                        <span>${d.enabled ? 'Les employés peuvent travailler.' : 'Plus aucune vente ni préparation possible.'}</span></div><div class="switch"></div></div>
                    ${tog('general.defaultDuty', 'En service à la connexion', 'Sinon, prise de service au point prévu.', g.defaultDuty)}
                    ${tog('general.offDutyPay', 'Payé hors service', 'Salaire même hors service.', g.offDutyPay)}
                </div>
                <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:820px">
                    <div class="field"><label>Nom de l'entreprise</label><input class="input" data-enf="general.label" value="${esc(g.label)}"></div>
                    <div class="field"><label>Identifiant du job</label><input class="input" value="${esc(d.job.name)}" disabled></div>
                    <div class="field"><label>Type</label><input class="input" data-enf="general.type" value="${esc(g.type)}"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-ena="saveGeneral">Enregistrer</button><button class="btn" data-ena="reset" data-what="general">Annuler</button></div>
            </div>
            <div class="section"><h2>Employés connectés (${d.employees.length})</h2>
                ${d.employees.length ? `<table>${d.employees.map((e) => `<tr><td><strong>[${e.id}] ${esc(e.name)}</strong></td><td class="muted">${esc(e.grade)}</td>
                    <td>${e.onduty ? '<span class="badge" style="color:var(--ok)">En service</span>' : '<span class="badge muted">Hors service</span>'}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun employé connecté.</div>'}
            </div>
            ${window.JobTools ? (JobTools.select('entreprises', d.job.name), JobTools.sections('entreprises', 'join')) : ''}`;
    };

    /* ---------- Grades ---------- */
    SUB.grades = (k, d, s) => `<div class="section"><h2>Grades et salaires</h2>
        <p class="hint">Le grade 0 est le plus bas. Le salaire est versé à chaque paie (en service, ou toujours si « Payé hors service »).
            Les permissions de chaque grade se règlent dans l'onglet <b>Permissions</b>.</p>
        <table><tr><th style="width:70px">Grade</th><th>Nom</th><th>Label</th><th style="width:140px">Salaire</th><th style="width:80px">Patron</th><th style="width:150px"></th></tr>
            ${s.grades.map((g, i) => `<tr><td><span class="keycap">${i}</span></td>
                <td><input class="input" data-enf="grades.${i}.id" value="${esc(g.id || '')}"></td>
                <td><input class="input" data-enf="grades.${i}.label" value="${esc(g.label)}"></td>
                <td><input class="input" type="number" min="0" data-enf="grades.${i}.payment" value="${Number(g.payment) || 0}"></td>
                <td><input type="checkbox" data-enf="grades.${i}.isboss" ${g.isboss ? 'checked' : ''}></td>
                <td style="text-align:right;white-space:nowrap">
                    <button class="btn" data-ena="gradeUp" data-i="${i}" ${i === 0 ? 'disabled' : ''}>↑</button>
                    <button class="btn" data-ena="gradeDown" data-i="${i}" ${i === s.grades.length - 1 ? 'disabled' : ''}>↓</button>
                    <button class="btn danger" data-ena="gradeRemove" data-i="${i}" ${s.grades.length <= 1 ? 'disabled' : ''}>✕</button></td></tr>`).join('')}
        </table>
        <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="gradeAdd">+ Ajouter un grade</button><span style="flex:1"></span>
            <button class="btn" data-ena="reset" data-what="grades">Annuler</button><button class="btn primary" data-ena="saveGrades">Enregistrer les grades</button></div></div>`;

    /* ---------- Permissions ---------- */
    SUB.perms = (k, d, s) => `<div class="section"><h2>Permissions par grade</h2>
        <p class="hint">Coche ce que chaque grade peut faire dans la tablette des employés (F6).</p>
        <div style="overflow-x:auto"><table><tr><th>Permission</th>${d.job.grades.map((g, i) => `<th style="text-align:center">${esc(g.label)}<br><span class="muted">${i}</span></th>`).join('')}</tr>
            ${d.permissions.map((p) => `<tr><td>${esc(p.label)}</td>${d.job.grades.map((_, i) => `<td style="text-align:center">
                <input type="checkbox" data-enp="${i}:${p.key}" ${(s.perms[String(i)] || {})[p.key] ? 'checked' : ''}></td>`).join('')}</tr>`).join('')}
        </table></div>
        <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="reset" data-what="perms">Annuler</button><button class="btn primary" data-ena="savePerms">Enregistrer les permissions</button></div></div>`;

    /* ---------- Zones ---------- */
    const zoneLabel = (t) => ((D.entreprises.zoneTypes || []).find((z) => z.key === t) || {}).label || t;
    SUB.zones = (k, d, s) => {
        const list = d.zones.filter((z) => s.zoneType === 'all' || z.type === s.zoneType);
        return `<div class="section"><h2>Ajouter un point</h2>
                <p class="hint">Place-toi à l'endroit voulu puis « Utiliser ma position actuelle ». Les employés appuient sur <span class="keycap">E</span> dans le cercle.
                    Utiles ici : ${zoneHint(d)}.</p>
                <div class="btn-row"><button class="btn primary" data-ena="zoneAddHere">📍 Utiliser ma position actuelle</button></div></div>
            <div class="section"><h2>Points (${d.zones.length})</h2>
                <div class="chips" style="margin-bottom:12px"><button class="btn ${s.zoneType === 'all' ? 'on' : ''}" data-enzt="all">Tous</button>
                    ${D.entreprises.zoneTypes.map((t) => `<button class="btn ${s.zoneType === t.key ? 'on' : ''}" data-enzt="${t.key}">${esc(t.label)} (${d.zones.filter((z) => z.type === t.key).length})</button>`).join('')}</div>
                ${list.length ? `<table><tr><th>Point</th><th>Type</th><th style="width:80px">Rayon</th><th>Position</th><th style="width:90px">Actif</th><th></th></tr>
                    ${list.map((z) => `<tr style="${z.enabled === false ? 'opacity:.55' : ''}"><td><strong>${esc(z.label)}</strong> <span class="muted">#${z.id}</span></td>
                        <td><span class="badge" style="color:var(--signal)">${esc(zoneLabel(z.type))}</span></td><td>${Number(z.radius).toFixed(1)} m</td>
                        <td class="muted" style="font-size:12px;white-space:nowrap">${z.x.toFixed(1)}, ${z.y.toFixed(1)}, ${z.z.toFixed(1)}</td>
                        <td><div class="tile toggle-tile ${z.enabled !== false ? 'on' : ''}" data-ena="zoneToggle" data-id="${z.id}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                        <td style="text-align:right;white-space:nowrap"><button class="btn" data-ena="zoneTp" data-id="${z.id}">Y aller</button>
                            <button class="btn" data-ena="zoneEdit" data-id="${z.id}">Modifier</button>
                            <button class="btn" data-ena="zoneHere" data-id="${z.id}" title="Déplacer à ma position">📍</button>
                            <button class="btn danger" data-ena="zoneDel" data-id="${z.id}">✕</button></td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun point de ce type.</div>'}</div>`;
    };
    function zoneHint(d) {
        const f = d.features || {};
        const t = ['Prise de service', 'Coffre', 'Comptoir / caisse', 'Garage de service + Sortie + Rangement des véhicules'];
        if (f.production) t.push('Préparation (cuisine / bar)', 'Réserve (fournisseur)');
        if (f.entry) t.push('Entrée');
        return t.join(', ');
    }

    /* ---------- Carte et prix ---------- */
    SUB.menu = (k, d, s) => `<div class="section"><h2>Carte et prix de vente</h2>
        <p class="hint">Articles proposés dans l'onglet <b>Caisse / Facture</b> de la tablette : l'employé les ajoute, le client reçoit la facture.
            La commission de l'employé et le reste (compte de l'entreprise) se règlent dans <b>Configuration</b>.</p>
        <table><tr><th>Article</th><th style="width:160px">Prix ($)</th><th style="width:60px"></th></tr>
            ${s.menu.map((m, i) => `<tr><td><input class="input" data-enf="menu.${i}.label" value="${esc(m.label)}"></td>
                <td><input class="input" type="number" min="0" data-enf="menu.${i}.price" value="${Number(m.price) || 0}"></td>
                <td><button class="btn danger" data-ena="rowDel" data-list="menu" data-i="${i}">✕</button></td></tr>`).join('')}
        </table>
        <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="rowAdd" data-list="menu">+ Ajouter un article</button><span style="flex:1"></span>
            <button class="btn" data-ena="reset" data-what="menu">Annuler</button><button class="btn primary" data-ena="saveMenu">Enregistrer la carte</button></div></div>`;

    /* ---------- Recettes ---------- */
    const itemLabel = (d, name) => (d.itemLabels || {})[name] || name;
    SUB.recipes = (k, d, s) => `<div class="section"><h2>Recettes (${s.recipes.length})</h2>
        <p class="hint">Au poste de <b>préparation</b>, l'employé transforme des ingrédients de son inventaire en produit. Utilise les <b>noms d'objets</b>
            de l'inventaire (ex. <span class="keycap">bs_pain</span>). Le temps est en secondes.</p>
        ${s.recipes.map((r, i) => `<div class="card" style="margin-bottom:10px;padding:12px 14px">
            <div style="display:grid;grid-template-columns:2fr 2fr 90px 90px 40px;gap:8px;align-items:end">
                <div class="field"><label>Nom</label><input class="input" data-enf="recipes.${i}.label" value="${esc(r.label)}"></div>
                <div class="field"><label>Produit obtenu (objet)</label><input class="input" data-enf="recipes.${i}.item" value="${esc(r.item)}" title="${esc(itemLabel(d, r.item))}"></div>
                <div class="field"><label>Quantité</label><input class="input" type="number" min="1" data-enf="recipes.${i}.amount" value="${Number(r.amount) || 1}"></div>
                <div class="field"><label>Temps (s)</label><input class="input" type="number" min="1" data-enf="recipes.${i}.time" value="${Number(r.time) || 5}"></div>
                <button class="btn danger" data-ena="rowDel" data-list="recipes" data-i="${i}">✕</button></div>
            <div style="margin-top:8px"><label class="muted" style="font-size:12px">Ingrédients</label>
                ${(r.ingredients || []).map((x, j) => `<div class="inline" style="gap:8px;margin-top:6px">
                    <input class="input" style="max-width:260px" data-enf="recipes.${i}.ingredients.${j}.item" value="${esc(x.item)}" placeholder="objet">
                    <input class="input" style="max-width:100px" type="number" min="1" data-enf="recipes.${i}.ingredients.${j}.count" value="${Number(x.count) || 1}">
                    <span class="muted">${esc(itemLabel(d, x.item))}</span>
                    <button class="btn danger" data-ena="ingDel" data-i="${i}" data-j="${j}">✕</button></div>`).join('')}
                <button class="btn" style="margin-top:8px" data-ena="ingAdd" data-i="${i}">+ Ingrédient</button></div>
        </div>`).join('') || '<div class="empty">Aucune recette.</div>'}
        <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="rowAdd" data-list="recipes">+ Ajouter une recette</button><span style="flex:1"></span>
            <button class="btn" data-ena="reset" data-what="recipes">Annuler</button><button class="btn primary" data-ena="saveRecipes">Enregistrer les recettes</button></div></div>`;

    /* ---------- Fournisseur ---------- */
    SUB.supplies = (k, d, s) => `<div class="section"><h2>Fournisseur</h2>
        <p class="hint">Produits que les employés (permission « Commander au fournisseur ») achètent à la <b>réserve</b>, payés avec l'argent de l'entreprise.</p>
        <table><tr><th>Objet</th><th></th><th style="width:160px">Prix unitaire ($)</th><th style="width:60px"></th></tr>
            ${s.supplies.map((x, i) => `<tr><td><input class="input" data-enf="supplies.${i}.item" value="${esc(x.item)}" placeholder="objet"></td>
                <td class="muted">${esc(itemLabel(d, x.item))}</td>
                <td><input class="input" type="number" min="0" data-enf="supplies.${i}.price" value="${Number(x.price) || 0}"></td>
                <td><button class="btn danger" data-ena="rowDel" data-list="supplies" data-i="${i}">✕</button></td></tr>`).join('')}
        </table>
        <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="rowAdd" data-list="supplies">+ Ajouter un produit</button><span style="flex:1"></span>
            <button class="btn" data-ena="reset" data-what="supplies">Annuler</button><button class="btn primary" data-ena="saveSupplies">Enregistrer</button></div></div>`;

    /* ---------- Taxi : compteur et courses ---------- */
    const num = (key, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-enf="settings.${key}" value="${esc(state(companyOfTab()).settings[key] ?? '')}" ${extra}></div>`;
    SUB.taxi = (k, d, s) => {
        const pts = d.settings.missionPoints || [];
        return `<div class="section"><h2>🧾 Compteur</h2>
                <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:820px">
                    ${num('meterBase', 'Prise en charge ($)', 'min="0"')}${num('meterPerKm', 'Prix au kilomètre ($)', 'min="0"')}${num('meterPerMin', 'Prix par minute d\'attente ($)', 'min="0"')}</div></div>
            <div class="section"><h2>🧍 Courses (clients PNJ)</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('settings.missionsEnabled', 'Courses activées', 'Les chauffeurs peuvent chercher des clients PNJ.', s.settings.missionsEnabled)}</div>
                <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:820px">
                    ${num('missionPayMin', 'Paie minimum d\'une course ($)', 'min="0"')}${num('missionPayMax', 'Paie maximum (longue course) ($)', 'min="0"')}
                    ${num('missionDriverShare', 'Part du chauffeur (%)', 'min="0" max="100"')}</div>
                <div class="btn-row"><button class="btn primary" data-ena="saveSettings">Enregistrer</button><button class="btn" data-ena="reset" data-what="settings">Annuler</button></div></div>
            <div class="section"><h2>📍 Points de départ / d'arrivée (${pts.length})</h2>
                <p class="hint">Les clients attendent sur ces points et y sont déposés. Place-toi sur un trottoir puis « Ajouter un point à ma position ».</p>
                <div class="btn-row"><button class="btn primary" data-ena="pointAdd">📍 Ajouter un point à ma position</button></div>
                ${pts.length ? `<table style="margin-top:12px">${pts.map((p, i) => `<tr><td><strong>Point ${i + 1}</strong></td>
                    <td class="muted" style="font-size:12px">${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z).toFixed(1)}</td>
                    <td style="text-align:right"><button class="btn" data-ena="pointTp" data-i="${i + 1}">Y aller</button>
                        <button class="btn danger" data-ena="pointDel" data-i="${i + 1}">✕</button></td></tr>`).join('')}</table>` : ''}</div>`;
    };

    /* ---------- Configuration ---------- */
    SUB.config = (k, d, s) => {
        const f = d.features || {};
        const veh = s.settings.serviceVehicles || [];
        return `<div class="section"><h2>Factures et paiements</h2>
                <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:820px">
                    ${num('commission', 'Commission de l\'employé (%)', 'min="0" max="100"')}${num('maxInvoice', 'Facture maximum ($)', 'min="1"')}
                    ${num('invoiceTimeout', 'Délai pour accepter (secondes)', 'min="10"')}</div></div>
            ${f.entry ? `<div class="section"><h2>Entrée de la boîte</h2><div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:820px">
                ${num('entryPrice', 'Prix de l\'entrée ($)', 'min="0"')}${num('vipPrice', 'Prix de l\'entrée VIP ($)', 'min="0"')}</div></div>` : ''}
            <div class="section"><h2>Carte et coffre</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('settings.showBlips', 'Icône sur la carte', 'Visible par tous les joueurs (au comptoir / à l\'entrée).', s.settings.showBlips)}</div>
                <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:900px">
                    ${num('blipSprite', 'Icône (numéro GTA)', 'min="1"')}${num('blipColor', 'Couleur (numéro GTA)', 'min="0"')}
                    ${num('stashSlots', 'Places du coffre', 'min="1" placeholder="80"')}${num('stashWeight', 'Poids du coffre (kg)', 'min="1" placeholder="300"')}</div></div>
            <div class="section"><h2>Véhicules de service</h2>
                <div style="max-width:320px">${num('maxServiceVehicles', 'Véhicules par employé', 'min="1"')}</div>
                <table><tr><th>Modèle</th><th>Nom affiché</th><th style="width:120px">Grade min.</th><th style="width:60px"></th></tr>
                    ${veh.map((v, i) => `<tr><td><input class="input" data-enf="settings.serviceVehicles.${i}.model" value="${esc(v.model)}"></td>
                        <td><input class="input" data-enf="settings.serviceVehicles.${i}.label" value="${esc(v.label)}"></td>
                        <td><input class="input" type="number" min="0" data-enf="settings.serviceVehicles.${i}.grade" value="${Number(v.grade) || 0}"></td>
                        <td><button class="btn danger" data-ena="vehDel" data-i="${i}">✕</button></td></tr>`).join('')}</table>
                <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="vehAdd">+ Ajouter un véhicule</button><span style="flex:1"></span>
                    <button class="btn" data-ena="reset" data-what="settings">Annuler</button><button class="btn primary" data-ena="saveSettings">Enregistrer la configuration</button></div></div>`;
    };

    /* ---------- Tenues ---------- */
    SUB.uniforms = (k, d) => {
        if (!window.JobTools || !JobTools.available('entreprises')) return '<div class="empty">Les tenues ne sont pas disponibles.</div>';
        JobTools.select('entreprises', d.job.name);
        return `<p class="hint">Tenue mise automatiquement à la prise de service, par grade et par sexe.</p>${JobTools.sections('entreprises', 'uniforms')}`;
    };

    /* =========================================================
       Saisie et actions
       ========================================================= */
    function setPath(obj, path, value) {
        const keys = path.split('.');
        let o = obj;
        for (let i = 0; i < keys.length - 1; i++) {
            const kk = /^\d+$/.test(keys[i]) ? Number(keys[i]) : keys[i];
            if (o[kk] === undefined) o[kk] = /^\d+$/.test(keys[i + 1]) ? [] : {};
            o = o[kk];
        }
        o[/^\d+$/.test(keys[keys.length - 1]) ? Number(keys[keys.length - 1]) : keys[keys.length - 1]] = value;
    }

    document.addEventListener('input', (ev) => {
        const k = companyOfTab();
        if (!isOpen || !k || !ES[k]) return;
        const t = ev.target;
        if (t.dataset.enf) setPath(ES[k], t.dataset.enf, t.type === 'checkbox' ? t.checked : t.type === 'number' ? Number(t.value) : t.value);
        if (t.dataset.enp) {
            const [g, key] = t.dataset.enp.split(':');
            ES[k].perms[g] = ES[k].perms[g] || {};
            ES[k].perms[g][key] = t.checked;
        }
    });
    document.addEventListener('change', (ev) => {
        const k = companyOfTab();
        if (!isOpen || !k || !ES[k]) return;
        const t = ev.target;
        if (t.type === 'checkbox' && t.dataset.enf) setPath(ES[k], t.dataset.enf, t.checked);
        if (t.dataset.enp) {
            const [g, key] = t.dataset.enp.split(':');
            ES[k].perms[g] = ES[k].perms[g] || {};
            ES[k].perms[g][key] = t.checked;
        }
    });

    const zoneFields = (z) => [
        { name: 'type', label: 'Type', type: 'select', options: D.entreprises.zoneTypes.map((t) => ({ value: t.key, label: t.label })), value: z ? z.type : 'service' },
        { name: 'label', label: 'Nom', value: z ? z.label : '' },
        { name: 'radius', label: 'Rayon (m)', type: 'number', value: z ? z.radius : 1.5 },
    ];

    document.addEventListener('click', async (ev) => {
        const k = companyOfTab();
        if (!isOpen || !k) return;
        const d = dataOf(k);
        if (!d) return;
        const s = state(k);
        let n;
        if ((n = ev.target.closest('[data-ens]'))) { s.sub = n.dataset.ens; return render(); }
        if ((n = ev.target.closest('[data-enzt]'))) { s.zoneType = n.dataset.enzt; return render(); }
        if ((n = ev.target.closest('[data-entog]'))) {
            const path = n.dataset.entog.split('.');
            const obj = s[path[0]];
            obj[path[1]] = !obj[path[1]];
            return render();
        }
        if (!(n = ev.target.closest('[data-ena]')) || n.disabled) return;
        const a = n.dataset.ena, i = Number(n.dataset.i);
        const zone = () => d.zones.find((z) => z.id === Number(n.dataset.id));
        switch (a) {
            case 'toggleEnabled':
                if (d.enabled && !(await confirmBox(`Fermer ${d.job.label} ?`, 'Plus aucun employé ne pourra vendre ou préparer.'))) return;
                return send(k, 'setEnabled', { enabled: !d.enabled });
            case 'reset': s[n.dataset.what] = null; return render();
            case 'saveGeneral': send(k, 'saveGeneral', s.general); s.general = null; return;
            case 'gradeAdd': s.grades.push({ id: '', label: '', payment: 0, isboss: false }); return render();
            case 'gradeRemove': s.grades.splice(i, 1); return render();
            case 'gradeUp': [s.grades[i - 1], s.grades[i]] = [s.grades[i], s.grades[i - 1]]; return render();
            case 'gradeDown': [s.grades[i + 1], s.grades[i]] = [s.grades[i], s.grades[i + 1]]; return render();
            case 'saveGrades':
                if (s.grades.length < d.job.grades.length && !(await confirmBox('Supprimer des grades ?', 'Les permissions des grades supprimés seront perdues.'))) return;
                send(k, 'saveGrades', { grades: s.grades }); s.grades = null; s.perms = null; return;
            case 'savePerms': send(k, 'savePerms', { perms: s.perms }); s.perms = null; return;
            case 'zoneAddHere': { const v = await formModal('Nouveau point à ma position', zoneFields(null), 'Créer'); if (v) send(k, 'addZone', { ...v, useMyPosition: true }); return; }
            case 'zoneEdit': { const z = zone(); const v = z && await formModal(`Modifier « ${z.label} »`, zoneFields(z), 'Enregistrer'); if (v) send(k, 'updateZone', { id: z.id, ...v }); return; }
            case 'zoneHere': { const z = zone(); if (z && await confirmBox('Déplacer le point ici ?', `« ${z.label} » sera placé à ta position.`)) send(k, 'updateZone', { id: z.id, useMyPosition: true }); return; }
            case 'zoneToggle': { const z = zone(); if (z) send(k, 'updateZone', { id: z.id, enabled: z.enabled === false }); return; }
            case 'zoneTp': post('close'); return send(k, 'tpZone', { id: Number(n.dataset.id) });
            case 'zoneDel': { const z = zone(); if (z && await confirmBox('Supprimer le point ?', `« ${z.label} » sera supprimé.`)) send(k, 'deleteZone', { id: z.id }); return; }
            case 'rowAdd': {
                const list = n.dataset.list;
                if (list === 'menu') s.menu.push({ label: '', price: 0 });
                if (list === 'supplies') s.supplies.push({ item: '', price: 0 });
                if (list === 'recipes') s.recipes.push({ id: '', label: '', item: '', amount: 1, time: 5, ingredients: [{ item: '', count: 1 }] });
                return render();
            }
            case 'rowDel': s[n.dataset.list].splice(i, 1); return render();
            case 'ingAdd': (s.recipes[i].ingredients = s.recipes[i].ingredients || []).push({ item: '', count: 1 }); return render();
            case 'ingDel': s.recipes[i].ingredients.splice(Number(n.dataset.j), 1); return render();
            case 'saveMenu': send(k, 'saveMenu', { menu: s.menu }); s.menu = null; return;
            case 'saveRecipes': send(k, 'saveRecipes', { recipes: s.recipes }); s.recipes = null; return;
            case 'saveSupplies': send(k, 'saveSupplies', { supplies: s.supplies }); s.supplies = null; return;
            case 'vehAdd': (s.settings.serviceVehicles = s.settings.serviceVehicles || []).push({ model: '', label: '', grade: 0 }); return render();
            case 'vehDel': s.settings.serviceVehicles.splice(i, 1); return render();
            case 'saveSettings': {
                const st = { ...s.settings };
                delete st.missionPoints;
                send(k, 'saveSettings', st); s.settings = null; return;
            }
            case 'pointAdd': return send(k, 'addMissionPoint');
            case 'pointTp': post('close'); return send(k, 'tpMissionPoint', { index: i });
            case 'pointDel': return send(k, 'deleteMissionPoint', { index: i });
        }
    });
})();
