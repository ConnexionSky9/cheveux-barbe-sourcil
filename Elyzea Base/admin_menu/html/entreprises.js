/* =========================================================
   MÉTIERS › ENTREPRISES (ressource elyzea_entreprises, permission « entreprises_staff »)
   Un onglet par entreprise : Taxi, Burger Shot, Boîte de nuit.
   Informations, grades, permissions, zones, carte et prix, recettes,
   fournisseur, configuration (véhicules, compteur, courses, entrée), tenues.
   ========================================================= */
(() => {
    const COMPANIES = [
        { key: 'taxi', ico: '🚕', label: 'Taxi', sub: 'Compteur, courses PNJ, grades, zones, véhicules, tenues.' },
        { key: 'burgershot', ico: '🍔', label: 'Burger Shot', sub: 'Borne de commande, carte et prix, recettes, fournisseur, grades, zones, tenues.' },
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
        if (f.kiosk) list.push({ id: 'kiosk', label: '🍔 Borne de commande' });
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
        if (d.kiosk && !s.kiosk) { s.kiosk = clone(d.kiosk.settings); delete s.kiosk.products; }
        if (d.kiosk && !s.kprods) s.kprods = clone(d.kiosk.settings.products || []);
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
        if (f.kiosk) t.push('Borne de commande (clients)', 'Plan de travail (l\'employé y prépare la commande devant le client)');
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

    /* ---------- Borne de commande ---------- */
    // Aperçu des produits : visuels de la ressource (burgers couche par couche, boissons)
    if (!window.Viz && !document.getElementById('entViz')) {
        const sc = document.createElement('script');
        sc.id = 'entViz';
        sc.src = 'nui://elyzea_entreprises/html/visuals.js';
        sc.onload = () => { if (isOpen && companyOfTab()) render(); };
        document.head.appendChild(sc);
    }
    const LAYER_LABELS = { pain_bas: 'Pain (dessous)', pain_milieu: 'Pain (milieu)', pain_haut: 'Pain (dessus)', steak: 'Steak', poulet: 'Poulet pané',
        galette: 'Galette de légumes', cheddar: 'Cheddar', salade: 'Salade', tomate: 'Tomate', oignon: 'Oignons', bacon: 'Bacon',
        cornichon: 'Cornichons', sauce: 'Sauce', ketchup: 'Ketchup' };
    const VISUALS = [['', 'Image de l\'objet'], ['gobelet', 'Gobelet Burger Shot'], ['verre', 'Verre (glaçons)'], ['milkshake', 'Milkshake (chantilly)'], ['cafe', 'Café chaud']];
    const ORDER_ST = { pending: 'En attente', preparing: 'En préparation', ready: 'Prête (au comptoir)' };
    const knum = (key, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-enf="kiosk.${key}" value="${esc(state(companyOfTab()).kiosk[key] ?? '')}" ${extra}></div>`;
    const preview = (p) => {
        const box = 'width:92px;height:92px;border-radius:12px;background:radial-gradient(60% 70% at 50% 60%,rgba(224,67,59,.25),transparent 70%),rgba(4,6,12,.5);display:flex;align-items:center;justify-content:center;overflow:hidden;padding:6px';
        let inner = '';
        if (window.Viz && p.layers && p.layers.length) inner = Viz.burger(p.layers);
        else if (window.Viz && p.visual) inner = Viz.drink(p.visual, p.color);
        else inner = `<img src="nui://elyzea_inventory/html/img/${esc(p.item)}.png" style="max-width:100%;max-height:100%" onerror="this.style.visibility='hidden'">`;
        return `<div style="${box}"><div style="width:100%;height:100%;display:flex;align-items:center;justify-content:center">${inner.replace('class="viz-svg', 'style="width:100%;height:100%" class="viz-svg')}</div></div>`;
    };

    SUB.kiosk = (k, d, s) => {
        const kd = d.kiosk || {}, ks = s.kiosk, st = kd.stats || {};
        const orders = kd.orders || [];
        const cats = ks.categories || [];
        const catOf = (key) => cats.find((c) => c.key === key) || { label: key, icon: '' };
        return `<div class="stats">
                <div class="stat"><b>${orders.filter((o) => o.status === 'pending').length}</b><span>En attente</span></div>
                <div class="stat"><b>${orders.filter((o) => o.status === 'preparing').length}</b><span>En préparation</span></div>
                <div class="stat"><b>${orders.filter((o) => o.status === 'ready').length}</b><span>Prêtes (au comptoir)</span></div>
                <div class="stat"><b>${st.n || 0}</b><span>Commandes servies (24 h) · ${money(st.total)}</span></div>
                <div class="stat" data-ens="zones"><b>${d.zones.filter((z) => z.type === 'borne').length} / ${d.zones.filter((z) => z.type === 'assemblage').length}</b><span>Bornes / plans de travail</span></div></div>

            <div class="section"><h2>🧾 Commandes en cours (${orders.length})</h2>
                <p class="hint">Le client paie à la borne ; l'argent est gardé de côté jusqu'à la préparation (puis versé à l'entreprise et à l'employé).
                    Annuler rembourse le client, même déconnecté (à sa prochaine connexion).</p>
                ${orders.length ? `<table><tr><th>N°</th><th>Client</th><th>Articles</th><th>Total</th><th>État</th><th></th></tr>
                    ${orders.map((o) => `<tr><td><strong>${esc(o.number)}</strong></td><td>${esc(o.name)}<br><span class="muted" style="font-size:12px">il y a ${Math.floor((o.age || 0) / 60)} min · ${o.method === 'cash' ? 'liquide' : 'banque'}</span></td>
                        <td>${(o.lines || []).map((l) => `${l.qty} × ${esc(l.label)}`).join('<br>')}</td><td>${money(o.total)}</td>
                        <td><span class="badge">${ORDER_ST[o.status] || o.status}</span>${o.employee ? `<br><span class="muted" style="font-size:12px">${esc(o.employee)}</span>` : ''}</td>
                        <td style="text-align:right"><button class="btn danger" data-ena="kOrderCancel" data-id="${o.id}">Annuler et rembourser</button></td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucune commande en cours.</div>'}</div>

            <div class="section"><h2>⚙️ Réglages de la borne</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('kiosk.enabled', 'Borne ouverte', 'Les clients peuvent commander.', ks.enabled !== false)}
                    ${tog('kiosk.requireStaff', 'Employé en service obligatoire', 'Sinon, on peut commander même sans personne.', ks.requireStaff !== false)}
                    ${tog('kiosk.useIngredients', 'Consommer les ingrédients', 'L\'employé utilise les ingrédients de son inventaire.', ks.useIngredients !== false)}
                    ${tog('kiosk.announce', 'Alerte aux employés', 'Son et notification à chaque commande.', ks.announce !== false)}</div>
                <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1000px">
                    <div class="field"><label>Paiement</label><select class="input" data-enf="kiosk.payment">
                        ${[['both', 'Au choix du client'], ['bank', 'Banque uniquement'], ['cash', 'Liquide uniquement']].map(([v, l]) => `<option value="${v}" ${ks.payment === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                    ${knum('maxItems', 'Articles max. par commande', 'min="1" max="50"')}${knum('maxActive', 'Commandes en cours max. par client', 'min="1" max="10"')}
                    ${knum('orderTimeout', 'Remboursement si non préparée (min)', 'min="1"')}
                    ${knum('employeeShare', 'Part de l\'employé qui prépare (%)', 'min="0" max="100"')}${knum('deliverDistance', 'Remise directe si client à moins de (m)', 'min="1" step="0.5"')}</div>
                <h3 class="sub-h" style="margin-top:16px">Plateau posé devant le client</h3>
                <p class="hint">Le plateau apparaît devant le point « Plan de travail » (place-toi derrière le comptoir, face au client, pour poser ce point).
                    Chaque produit préparé y est posé, visible par tous.</p>
                <div style="display:grid;grid-template-columns:2fr 1fr 1fr;gap:12px;max-width:820px">
                    <div class="field"><label>Modèle du plateau</label><input class="input" data-enf="kiosk.trayModel" value="${esc(ks.trayModel || '')}"></div>
                    ${knum('trayForward', 'Distance devant le point (m)', 'step="0.05"')}${knum('trayHeight', 'Hauteur (m)', 'step="0.05"')}</div>
                <h3 class="sub-h" style="margin-top:16px">Catégories et animations de préparation</h3>
                <table><tr><th style="width:120px">Clé</th><th>Nom affiché</th><th style="width:90px">Icône</th><th>Animation (dict)</th><th>Animation (clip)</th><th style="width:60px"></th></tr>
                    ${cats.map((c, i) => `<tr><td><input class="input" data-enf="kiosk.categories.${i}.key" value="${esc(c.key)}"></td>
                        <td><input class="input" data-enf="kiosk.categories.${i}.label" value="${esc(c.label)}"></td>
                        <td><input class="input" data-enf="kiosk.categories.${i}.icon" value="${esc(c.icon || '')}"></td>
                        <td><input class="input" data-enf="kiosk.anims.${esc(c.key)}.dict" value="${esc(((ks.anims || {})[c.key] || {}).dict || '')}"></td>
                        <td><input class="input" data-enf="kiosk.anims.${esc(c.key)}.clip" value="${esc(((ks.anims || {})[c.key] || {}).clip || '')}"></td>
                        <td><button class="btn danger" data-ena="kCatDel" data-i="${i}" ${cats.length <= 1 ? 'disabled' : ''}>✕</button></td></tr>`).join('')}</table>
                <div class="btn-row" style="margin-top:12px"><button class="btn" data-ena="kCatAdd">+ Ajouter une catégorie</button><span style="flex:1"></span>
                    <button class="btn" data-ena="reset" data-what="kiosk">Annuler</button><button class="btn primary" data-ena="kSave">Enregistrer les réglages</button></div></div>

            <div class="section"><h2>🍔 Produits de la borne (${s.kprods.length})</h2>
                <p class="hint">Chaque produit donne un <b>objet</b> de l'inventaire au client. Les <b>couches</b> dessinent le burger, assemblé en direct pendant la préparation
                    (de bas en haut). Le <b>visuel</b> dessine une boisson ; sinon l'image de l'objet est utilisée. Le <b>modèle</b> est l'objet posé sur le plateau.</p>
                ${cats.map((c) => {
                    const list = s.kprods.map((p, i) => ({ p, i })).filter((x) => x.p.category === c.key);
                    return `<h3 class="sub-h" style="margin:14px 0 8px">${esc(c.icon || '')} ${esc(c.label)} (${list.length})</h3>
                        ${list.map(({ p, i }) => prodCard(d, p, i, cats)).join('') || '<div class="empty">Aucun produit.</div>'}
                        <div class="btn-row" style="margin-top:8px"><button class="btn" data-ena="kProdAdd" data-cat="${esc(c.key)}">+ Ajouter : ${esc(c.label)}</button></div>`;
                }).join('')}
                ${s.kprods.filter((p) => !cats.find((c) => c.key === p.category)).map((p) => prodCard(d, p, s.kprods.indexOf(p), cats)).join('')}
                <div class="btn-row" style="margin-top:14px"><span style="flex:1"></span>
                    <button class="btn" data-ena="reset" data-what="kprods">Annuler</button><button class="btn primary" data-ena="kProdsSave">Enregistrer les produits</button></div></div>`;
    };

    function prodCard(d, p, i, cats) {
        const isBurger = (p.layers && p.layers.length) || p.category === 'burger';
        return `<div class="card" style="margin-bottom:10px;padding:12px 14px;${p.enabled === false ? 'opacity:.6' : ''}">
            <div style="display:grid;grid-template-columns:92px 1fr;gap:14px">
                ${preview(p)}
                <div>
                    <div style="display:grid;grid-template-columns:2fr 1.6fr 90px 90px 1.2fr auto;gap:8px;align-items:end">
                        <div class="field"><label>Nom</label><input class="input" data-enf="kprods.${i}.label" value="${esc(p.label)}"></div>
                        <div class="field"><label>Objet donné</label><input class="input" data-enf="kprods.${i}.item" value="${esc(p.item)}" title="${esc(itemLabel(d, p.item))}"></div>
                        <div class="field"><label>Prix ($)</label><input class="input" type="number" min="0" data-enf="kprods.${i}.price" value="${Number(p.price) || 0}"></div>
                        <div class="field"><label>Temps (s)</label><input class="input" type="number" min="1" data-enf="kprods.${i}.time" value="${Number(p.time) || 5}"></div>
                        <div class="field"><label>Catégorie</label><select class="input" data-enf="kprods.${i}.category" data-enre="1">${cats.map((c) => `<option value="${esc(c.key)}" ${c.key === p.category ? 'selected' : ''}>${esc(c.label)}</option>`).join('')}</select></div>
                        <div style="white-space:nowrap"><label class="inline" style="gap:6px;margin-right:6px"><input type="checkbox" data-enf="kprods.${i}.enabled" ${p.enabled !== false ? 'checked' : ''}> Actif</label>
                            <button class="btn" data-ena="kProdUp" data-i="${i}">↑</button><button class="btn" data-ena="kProdDown" data-i="${i}">↓</button>
                            <button class="btn danger" data-ena="kProdDel" data-i="${i}">✕</button></div></div>
                    <div style="display:grid;grid-template-columns:3fr 1.4fr;gap:8px;margin-top:8px">
                        <div class="field"><label>Description (borne)</label><input class="input" data-enf="kprods.${i}.description" value="${esc(p.description || '')}" maxlength="200"></div>
                        <div class="field"><label>Modèle posé sur le plateau</label><input class="input" data-enf="kprods.${i}.prop" value="${esc(p.prop || '')}" placeholder="prop_cs_burger_01"></div></div>
                    ${isBurger ? `<div style="margin-top:8px"><label class="muted" style="font-size:12px">Couches (de bas en haut)</label>
                        <div class="chips" style="margin-top:6px;align-items:center">${(p.layers || []).map((l, j) => `<span class="badge" style="display:inline-flex;gap:6px;align-items:center">${j + 1}. ${esc(LAYER_LABELS[l] || l)}
                            <button class="btn" style="padding:0 6px" data-ena="kLayerDel" data-i="${i}" data-j="${j}">✕</button></span>`).join('')}
                            <select class="input" style="max-width:200px" data-klayer="${i}"><option value="">+ Ajouter une couche…</option>
                                ${Object.entries(LAYER_LABELS).map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}</select></div></div>`
                    : `<div style="display:grid;grid-template-columns:1.4fr 120px;gap:8px;margin-top:8px;max-width:420px">
                        <div class="field"><label>Visuel</label><select class="input" data-enf="kprods.${i}.visual" data-enre="1">${VISUALS.map(([v, l]) => `<option value="${v}" ${(p.visual || '') === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                        <div class="field"><label>Couleur</label><input class="input" type="color" data-enf="kprods.${i}.color" data-enre="1" value="${esc(p.color || '#4a2416')}" style="height:38px;padding:2px"></div></div>`}
                    <div style="margin-top:8px"><label class="muted" style="font-size:12px">Ingrédients utilisés par l'employé (si « Consommer les ingrédients »)</label>
                        ${(p.ingredients || []).map((x, j) => `<div class="inline" style="gap:8px;margin-top:6px">
                            <input class="input" style="max-width:220px" data-enf="kprods.${i}.ingredients.${j}.item" value="${esc(x.item)}" placeholder="objet">
                            <input class="input" style="max-width:90px" type="number" min="1" data-enf="kprods.${i}.ingredients.${j}.count" value="${Number(x.count) || 1}">
                            <span class="muted">${esc(itemLabel(d, x.item))}</span>
                            <button class="btn danger" data-ena="kIngDel" data-i="${i}" data-j="${j}">✕</button></div>`).join('')}
                        <button class="btn" style="margin-top:6px" data-ena="kIngAdd" data-i="${i}">+ Ingrédient</button></div>
                </div></div></div>`;
    }

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
        if (t.dataset.klayer !== undefined && t.value) {
            const p = ES[k].kprods[Number(t.dataset.klayer)];
            (p.layers = p.layers || []).push(t.value);
            return render();
        }
        if (t.dataset.enre) return render();
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
            case 'kSave': send(k, 'saveKioskSettings', { kiosk: s.kiosk }); s.kiosk = null; return;
            case 'kProdsSave': send(k, 'saveKioskProducts', { products: s.kprods }); s.kprods = null; return;
            case 'kCatAdd': s.kiosk.categories.push({ key: `cat${s.kiosk.categories.length + 1}`, label: 'Nouvelle catégorie', icon: '🍽️' }); return render();
            case 'kCatDel': s.kiosk.categories.splice(i, 1); return render();
            case 'kProdAdd': {
                const cat = n.dataset.cat;
                s.kprods.push({ id: '', category: cat, label: '', item: '', price: 0, time: 5, description: '', enabled: true, ingredients: [],
                    layers: cat === 'burger' ? ['pain_bas', 'steak', 'cheddar', 'salade', 'pain_haut'] : null, visual: cat === 'drink' ? 'gobelet' : '', color: '#4a2416', prop: '' });
                return render();
            }
            case 'kProdDel': {
                const p = s.kprods[i];
                if (!(await confirmBox('Supprimer le produit ?', `« ${p.label || 'sans nom'} » ne sera plus proposé à la borne (après enregistrement).`))) return;
                s.kprods.splice(i, 1); return render();
            }
            case 'kProdUp': if (i > 0) [s.kprods[i - 1], s.kprods[i]] = [s.kprods[i], s.kprods[i - 1]]; return render();
            case 'kProdDown': if (i < s.kprods.length - 1) [s.kprods[i + 1], s.kprods[i]] = [s.kprods[i], s.kprods[i + 1]]; return render();
            case 'kLayerDel': s.kprods[i].layers.splice(Number(n.dataset.j), 1); return render();
            case 'kIngAdd': (s.kprods[i].ingredients = s.kprods[i].ingredients || []).push({ item: '', count: 1 }); return render();
            case 'kIngDel': s.kprods[i].ingredients.splice(Number(n.dataset.j), 1); return render();
            case 'kOrderCancel':
                if (!(await confirmBox('Annuler la commande ?', 'Le client est remboursé et la préparation en cours est arrêtée.'))) return;
                return send(k, 'cancelOrder', { id: Number(n.dataset.id) });
            case 'pointAdd': return send(k, 'addMissionPoint');
            case 'pointTp': post('close'); return send(k, 'tpMissionPoint', { index: i });
            case 'pointDel': return send(k, 'deleteMissionPoint', { index: i });
        }
    });
})();
