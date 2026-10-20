/* =========================================================
   GESTION DES DROGUES (ressource elyzea_drogues)
   Permission « drugs_manage » : tout · « drugs_effects » : onglet Effets seulement.
   Installations (placer avec l'outil de l'éditeur, déplacer, dupliquer, supprimer) · Recettes · Prix et vente ·
   Culture (variétés, pots des joueurs) · Récolte · Effets · Journal. Tout est revérifié par elyzea_drogues.
   ========================================================= */
(() => {
    TABS.push({
        id: 'drogues', group: 6, label: 'Gestion des drogues', ico: '💊',
        sub: 'Installations sur la carte, recettes et étapes, prix et vente, culture du cannabis, récolte, effets et hallucinations, journal.',
        show: () => (has('drugs_manage') || has('drugs_effects')) && !!(D && D.drogues),
    });
    const G = { sub: 'sites', draft: null, cat: 'all', drug: 'all', q: '', placeCat: 'station', placeType: '', placeModel: '', rdrug: 'weed' };
    const send = (name, data = {}) => action('drogues', { name, data });
    const later = (ms = 500) => setTimeout(() => post('refresh'), ms);
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const fmtS = (s) => (s >= 3600 ? `${Math.floor(s / 3600)} h ${String(Math.floor((s % 3600) / 60)).padStart(2, '0')}` : s >= 60 ? `${Math.floor(s / 60)} min${s % 60 ? ` ${s % 60} s` : ''}` : `${s} s`);
    const on = () => isOpen && tab === 'drogues' && D && D.drogues && D.drogues.available;
    const L = (i) => (D.drogues.labels || {})[i] || i;
    const DRUGS = () => D.drogues.drugs || [];
    const drugLabel = (id) => (DRUGS().find((x) => x.id === id) || { label: id }).label;
    const drugIcon = (id) => (DRUGS().find((x) => x.id === id) || { icon: '•' }).icon;
    const hex = (c) => `#${(c || [0, 0, 0]).map((v) => Number(v).toString(16).padStart(2, '0')).join('')}`;
    const rgb = (h) => [1, 3, 5].map((i) => parseInt(String(h).slice(i, i + 2), 16) || 0);
    const getPath = (o, p) => p.split('.').reduce((a, k) => (a == null ? a : a[k]), o);
    const setPath = (o, p, v) => { const ks = p.split('.'); let a = o; for (let i = 0; i < ks.length - 1; i++) a = a[ks[i]]; a[ks[ks.length - 1]] = v; };
    const num = (label, path, min, max, help, step = 1) => `<div><label>${esc(label)}</label><input class="input" type="number" min="${min}" max="${max}" step="${step}" data-dn="${path}" value="${esc(getPath(G.draft, path) ?? '')}">${help ? `<p class="hint" style="margin:3px 0 0">${esc(help)}</p>` : ''}</div>`;
    const txt = (label, path, ph = '') => `<div><label>${esc(label)}</label><input class="input" data-dt="${path}" value="${esc(getPath(G.draft, path) ?? '')}" placeholder="${esc(ph)}"></div>`;
    const tog = (path, labelOn, labelOff) => { const v = getPath(G.draft, path) !== false; return `<div class="tile toggle-tile ${v ? 'on' : ''}" data-dtg="${path}" style="padding:4px 10px"><div><span>${esc(v ? labelOn : (labelOff || labelOn))}</span></div><div class="switch"></div></div>`; };
    const SUBS_FULL = [['sites', '🏗️ Installations'], ['recipes', '🧪 Recettes'], ['prices', '💰 Prix et vente'], ['culture', '🌿 Culture'], ['harvest', '⛏️ Récolte'], ['effects', '✨ Effets'], ['logs', '📜 Journal']];
    const saveBar = (sections, reset) => `<div class="btn-row" style="margin-top:12px"><button class="btn primary" data-dsave="${sections}">💾 Enregistrer (appliqué tout de suite)</button>
        <button class="btn" data-dact="cancel">Annuler les modifications</button>${reset ? `<button class="btn danger" data-dreset="${reset}">Revenir à config.lua</button>` : ''}</div>`;

    /* ---------------------------------------------- installations */
    function catalogOf(cat) { const c = D.drogues.catalog; return cat === 'station' ? c.stations : cat === 'harvest' ? c.harvest : c.npc; }
    function viewSites(d) {
        const list = catalogOf(G.placeCat);
        if (!list.some((x) => x.id === G.placeType)) G.placeType = list[0] ? list[0].id : '';
        const t = list.find((x) => x.id === G.placeType);
        if (t && !t.models.includes(G.placeModel)) G.placeModel = t.models[0];
        const me = d.me;
        const dist = (s) => (me ? Math.round(Math.hypot(s.x - me.x, s.y - me.y, s.z - me.z)) : null);
        let rows = d.sites.filter((s) => (G.cat === 'all' || s.cat === G.cat) && (G.drug === 'all' || s.drug === G.drug)
            && (!G.q || `${s.id} ${s.typeLabel} ${s.model} ${s.type}`.toLowerCase().includes(G.q.toLowerCase())));
        rows = rows.map((s) => ({ ...s, dist: dist(s) })).sort((a, b) => (a.dist ?? 1e9) - (b.dist ?? 1e9));
        return `<div class="section"><h2>Placer une installation</h2>
            <p class="hint">Choisis le type et le modèle, puis place-le avec l'outil de l'éditeur (aperçu, rotation, hauteur, aimant). Les joueurs interagissent avec <b>ALT</b>.
                Les joueurs ne peuvent ni déplacer ni supprimer ces installations.</p>
            <div class="form-grid" style="grid-template-columns:180px 1fr 1fr auto;align-items:end">
                <div><label>Catégorie</label><select class="input" data-dsel="placeCat">${[['station', 'Postes de fabrication'], ['harvest', 'Points de récolte'], ['npc', 'PNJ (vente, fournisseur)']]
                    .map(([k, l]) => `<option value="${k}" ${G.placeCat === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                <div><label>Type</label><select class="input" data-dsel="placeType">${list.map((x) => `<option value="${esc(x.id)}" ${x.id === G.placeType ? 'selected' : ''}>${esc(x.icon)} ${esc(x.label)}${x.drug ? ` · ${esc(drugLabel(x.drug))}` : ''}</option>`).join('')}</select></div>
                <div><label>Modèle</label><select class="input" data-dsel="placeModel">${(t ? t.models : []).map((m) => `<option ${m === G.placeModel ? 'selected' : ''}>${esc(m)}</option>`).join('')}</select></div>
                <button class="btn primary" data-dplace>📍 Placer</button></div></div>
        <div class="section"><h2>Installations (${d.sites.length})</h2>
            <div class="form-grid" style="grid-template-columns:180px 200px 1fr;align-items:end;margin-bottom:8px">
                <div><label>Catégorie</label><select class="input" data-dsel="cat">${[['all', 'Toutes'], ['station', 'Postes'], ['harvest', 'Récolte'], ['npc', 'PNJ']].map(([k, l]) => `<option value="${k}" ${G.cat === k ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                <div><label>Drogue</label><select class="input" data-dsel="drug"><option value="all">Toutes</option>${DRUGS().map((x) => `<option value="${x.id}" ${G.drug === x.id ? 'selected' : ''}>${esc(x.icon)} ${esc(x.label)}</option>`).join('')}</select></div>
                <div><label>Rechercher (n°, nom, modèle)</label><input class="input" data-dq value="${esc(G.q)}"></div></div>
            <table class="loot wide"><tr><th>N°</th><th>Installation</th><th>Modèle</th><th>Position</th><th>Distance</th><th></th></tr>
            ${rows.map((s) => `<tr><td>#${s.id}</td><td>${esc(s.icon || '')} ${esc(s.typeLabel)}${s.regrow ? ` <span class="muted">(repousse ${fmtS(s.regrow)})</span>` : ''}<br><span class="muted">${esc(s.type)}${s.by ? ` · par ${esc(s.by)}` : ''}</span></td>
                <td><code>${esc(s.model)}</code></td><td class="muted">${s.x}, ${s.y}, ${s.z} · cap ${s.h}°</td><td>${s.dist !== null ? `${s.dist} m` : '—'}</td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-dtp="${s.id}" title="Y aller">🚀</button><button class="btn" data-dmove="${s.id}" title="Déplacer / tourner">✋</button>
                <button class="btn" data-ddup="${s.id}" title="Dupliquer (placer une copie)">⧉</button><button class="sb-close" data-ddel="${s.id}" title="Supprimer">✕</button></td></tr>`).join('')
                || '<tr><td colspan="6" class="muted">Aucune installation.</td></tr>'}</table>
            <p class="hint">Triées de la plus proche à la plus lointaine (« installations proches »).</p></div>`;
    }

    /* ---------------------------------------------- recettes */
    function ioRows(rid, kind) {
        const list = G.draft.recipes[rid][kind];
        return list.map((e, i) => `<div class="inline" style="margin-bottom:4px"><input class="input" style="flex:1" data-dt="recipes.${rid}.${kind}.${i}.0" value="${esc(e[0])}" title="${esc(L(e[0]))}">
            <input class="input" type="number" min="1" max="100" style="width:80px" data-dn="recipes.${rid}.${kind}.${i}.1" value="${e[1]}">
            <span class="muted" style="min-width:150px">${esc(L(e[0]))}</span><button class="sb-close" data-dio="${rid}|${kind}|${i}">✕</button></div>`).join('')
            + (list.length < 6 ? `<button class="btn" data-dioadd="${rid}|${kind}">+ ${kind === 'inputs' ? 'ingrédient' : 'produit'}</button>` : '');
    }
    function viewRecipes(d) {
        const metas = d.recipes.filter((r) => r.drug === G.rdrug);
        return `<div class="section"><h2>Drogues activées</h2><div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">
            ${DRUGS().map((x) => tog(`drugs.${x.id}.enabled`, `${x.icon} ${x.label} : activée`, `${x.icon} ${x.label} : désactivée`)).join('')}</div>
            <p class="hint">Une drogue désactivée : plus de consommation, de récolte ni de fabrication pour elle.</p></div>
        <div class="section"><h2>Étapes de fabrication</h2>
            <div class="btn-row" style="margin-bottom:10px">${DRUGS().map((x) => `<button class="btn ${G.rdrug === x.id ? 'primary' : ''}" data-drdrug="${x.id}">${x.icon} ${esc(x.label)}</button>`).join('')}</div>
            <p class="hint">Objets : identifiants de l'inventaire (le nom affiché est à droite). Perte : % de chance de perdre chaque unité produite. L'étape 1 (récolte / culture / achat) se règle dans Récolte, Culture et Prix.</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:12px">${metas.map((m) => { const r = G.draft.recipes[m.id]; return `<div class="card recipe">
                <div class="card-head"><strong>Étape ${m.step} · ${esc(m.label)}</strong>${tog(`recipes.${m.id}.enabled`, 'Active', 'Désactivée')}</div>
                <p class="hint" style="margin:2px 0 8px">Poste : ${esc(m.stationLabel)}${m.variety ? ` · variété ${esc(m.variety)}` : ''}${m.prepStep ? ' · étape « préparer » (désactivable par variété dans Culture)' : ''}${m.rollStep ? ' · sans préparation : roule les têtes' : ''}</p>
                <div class="form-grid" style="grid-template-columns:1fr 1fr">${num('Durée (s)', `recipes.${m.id}.duration`, 1, 600)}${num('Perte (%)', `recipes.${m.id}.loss`, 0, 90)}</div>
                <label style="margin-top:8px;display:block">Ingrédients</label>${ioRows(m.id, 'inputs')}
                <label style="margin-top:8px;display:block">Produits obtenus</label>${ioRows(m.id, 'outputs')}
                <p class="hint" style="margin-top:4px">Identifiant : <code>${esc(m.id)}</code>${r ? '' : ' (introuvable)'}</p></div>`; }).join('')}</div>
            ${saveBar('drugs,recipes', 'recipes')}</div>`;
    }

    /* ---------------------------------------------- prix et vente */
    function viewPrices() {
        const pr = G.draft.prices;
        const items = Object.keys(pr).sort((a, b) => L(a).localeCompare(L(b)));
        const sa = G.draft.sale;
        return `<div class="section"><h2>Prix de vente (acheteurs)</h2>
            <p class="hint">Prix à l'unité payé par les PNJ acheteurs (ALT › Vendre). 0 = l'acheteur ne prend pas cet objet. Max : unités par vente.</p>
            <table class="loot wide"><tr><th>Objet</th><th>Identifiant</th><th>Prix</th><th>Max / vente</th></tr>
            ${items.map((i) => `<tr><td>${esc(L(i))}</td><td><code>${esc(i)}</code></td><td><input class="input" type="number" min="0" style="width:110px" data-dn="prices.${i}.price" value="${pr[i].price}"></td>
                <td><input class="input" type="number" min="1" style="width:90px" data-dn="prices.${i}.max" value="${pr[i].max}"></td></tr>`).join('')}</table>
            <div class="inline" style="max-width:520px;margin-top:8px"><input class="input" id="drg-price-new" placeholder="identifiant d'un objet (ex. weed_bud_custom)"><button class="btn" data-dpriceadd>+ Ajouter un prix</button></div></div>
        <div class="section"><h2>Paiement des ventes</h2><div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">
            <div><label>Mode</label><select class="input" data-dsv="sale.paymentType"><option value="item" ${sa.paymentType === 'item' ? 'selected' : ''}>Objet (argent sale)</option><option value="money" ${sa.paymentType === 'money' ? 'selected' : ''}>Argent (compte)</option></select></div>
            ${sa.paymentType === 'item' ? txt('Objet de paiement', 'sale.paymentItem', 'black_money') : `<div><label>Compte</label><select class="input" data-dsv="sale.paymentAccount"><option value="cash" ${sa.paymentAccount === 'cash' ? 'selected' : ''}>Liquide</option><option value="bank" ${sa.paymentAccount === 'bank' ? 'selected' : ''}>Banque</option></select></div>`}
            ${num('Délai entre deux ventes (s)', 'sale.cooldown', 0, 300)}${num('Unités max par heure (0 = illimité)', 'sale.hourlyLimit', 0, 100000)}</div></div>
        <div class="section"><h2>Matériel du fournisseur</h2>
            <p class="hint">Vendu par les PNJ « Fournisseur » (ALT › Acheter), payé en liquide puis banque. Pots, lampes, graines, ingrédients fictifs…</p>
            <table class="loot wide"><tr><th>Objet</th><th>Identifiant</th><th>Prix</th><th></th></tr>
            ${G.draft.shop.map((e, i) => `<tr><td>${esc(L(e.item))}</td><td><input class="input" data-dt="shop.${i}.item" value="${esc(e.item)}"></td>
                <td><input class="input" type="number" min="0" style="width:110px" data-dn="shop.${i}.price" value="${e.price}"></td><td><button class="sb-close" data-dshopdel="${i}">✕</button></td></tr>`).join('')}</table>
            <button class="btn" data-dshopadd style="margin-top:6px">+ Ajouter un objet</button>
            ${saveBar('prices,sale,shop', 'prices')}</div>`;
    }

    /* ---------------------------------------------- culture */
    function viewCulture(d) {
        const c = 'culture';
        return `<div class="section"><h2>Variétés de cannabis</h2><div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px">
            ${d.varieties.map((v) => { const p = `varieties.${v.id}`; const cur = G.draft.varieties[v.id]; return `<div class="card recipe" style="border-left:4px solid ${hex(cur.color)}">
                <div class="card-head"><strong>${esc(cur.label)}</strong><input type="color" data-dcol="${p}.color" value="${hex(cur.color)}" title="Couleur de la fumée et de la lueur"></div>
                <div class="form-grid" style="grid-template-columns:1fr 1fr">${txt('Nom affiché', `${p}.label`)}${num('Croissance totale (min)', `${p}.growMinutes`, 1, 10080, fmtS(cur.growMinutes * 60))}
                ${num('Feuilles min', `${p}.yieldMin`, 1, 50)}${num('Feuilles max', `${p}.yieldMax`, 1, 50)}${num('Graine récupérée (%)', `${p}.seedChance`, 0, 100)}</div>
                <div style="margin-top:6px">${tog(`${p}.prepStep`, 'Étape « préparer » active', 'Sans préparation (roule les têtes)')}</div>
                <p class="hint" style="margin-top:4px">Graine <code>${esc(v.seed)}</code> · joint <code>${esc(v.joint)}</code> · pochon <code>${esc(v.pouch)}</code></p></div>`; }).join('')}</div></div>
        <div class="section"><h2>Règles de culture</h2><div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr))">
            ${num('Pots max par joueur', `${c}.maxPotsPerPlayer`, 0, 50)}${num('Distance min entre pots (m)', `${c}.minDistance`, 0.5, 20, '', 0.1)}
            ${num('Eau ajoutée par arrosage (%)', `${c}.waterPerUse`, 5, 100)}${num('Eau perdue par heure (%)', `${c}.waterDecayPerHour`, 0, 100, '', 0.5)}
            ${num('« Arroser » proposé sous (%)', `${c}.waterNeedBelow`, 5, 100)}${num('Santé perdue / h sans eau', `${c}.healthLossPerHourDry`, 0, 100, '', 0.5)}
            ${num('Vitesse avec lampe (×)', `${c}.lampFactor`, 0.1, 10, '', 0.05)}${num('Vitesse sans lampe (×, 0 = ne pousse pas)', `${c}.noLampFactor`, 0, 10, '', 0.05)}
            ${num('Engrais : vitesse (×)', `${c}.fertilizerBoost`, 1, 5, '', 0.05)}${num('Plante morte retirée après (h)', `${c}.deadRemoveHours`, 1, 720)}</div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-top:8px">${tog(`${c}.ownerOnlyHarvest`, 'Seul le propriétaire récolte', 'Tout le monde peut récolter (vol)')}
                ${tog(`${c}.policeCanDestroy`, 'La police peut détruire les plantes', 'La police ne peut pas détruire')}</div>
            <p class="hint">Zones interdites, modèles et étapes visibles : <code>elyzea_drogues/config/culture.lua</code>.</p>
            ${saveBar('varieties,culture', 'culture')}</div>
        <div class="section"><h2>Pots des joueurs (${d.plants.length})</h2>
            <table class="loot wide"><tr><th>N°</th><th>Propriétaire</th><th>Variété</th><th>Croissance</th><th>Eau</th><th>Santé</th><th>Lampe</th><th>Position</th><th></th></tr>
            ${d.plants.map((p) => `<tr><td>#${p.id}</td><td>${esc(p.owner)}</td><td>${p.variety ? esc(p.variety) : '<span class="muted">vide</span>'}${p.dead ? ' <b style="color:var(--danger)">morte</b>' : ''}</td>
                <td>${p.variety ? `${p.pct} %` : '—'}</td><td>${p.water} %</td><td>${p.health} %</td><td>${p.lamp ? '💡' : '—'}</td><td class="muted">${p.x}, ${p.y}, ${p.z}</td>
                <td style="text-align:right;white-space:nowrap"><button class="btn" data-dptp="${p.id}">🚀</button><button class="sb-close" data-dpdel="${p.id}">✕</button></td></tr>`).join('')
                || '<tr><td colspan="9" class="muted">Aucun pot posé.</td></tr>'}</table></div>`;
    }

    /* ---------------------------------------------- récolte */
    function viewHarvest(d) {
        return `<div class="section"><h2>Points de récolte</h2><p class="hint">Quantités, durée et repousse par type (les points eux-mêmes se placent dans Installations).</p>
            <table class="loot wide"><tr><th>Type</th><th>Objet</th><th>Actif</th><th>Min</th><th>Max</th><th>Durée (s)</th><th>Repousse (s)</th></tr>
            ${d.catalog.harvest.map((h) => { const p = `harvest.${h.id}`; return `<tr><td>${esc(h.icon)} ${esc(h.label)}</td><td>${esc(L(h.item))}</td><td>${tog(`${p}.enabled`, 'Oui', 'Non')}</td>
                ${['min', 'max', 'duration', 'respawn'].map((k) => `<td><input class="input" type="number" min="1" style="width:90px" data-dn="${p}.${k}" value="${getPath(G.draft, `${p}.${k}`)}"></td>`).join('')}</tr>`; }).join('')}</table>
            ${saveBar('harvest', 'harvest')}</div>`;
    }

    /* ---------------------------------------------- effets */
    function viewEffects(d) {
        const s = G.draft;
        return `<div class="section"><h2>Joueurs sous effet (${d.users.length})</h2>
            ${d.users.length ? `<table class="loot wide"><tr><th>Joueur</th><th>Drogues</th><th></th></tr>${d.users.map((u) => `<tr><td>${esc(u.name)} <span class="muted">#${u.id}</span></td>
                <td>${u.drugs.map((x) => `${esc(x.label)} <span class="muted">(${fmtS(x.left)})</span>`).join(' · ')}</td>
                <td style="text-align:right"><button class="btn" data-dstop="${u.id}">Arrêter les effets</button></td></tr>`).join('')}</table>` : '<p class="muted">Personne n\'est sous l\'effet d\'une drogue.</p>'}
            <div class="inline" style="max-width:420px;margin-top:8px"><input class="input" type="number" min="1" id="drg-stop-id" placeholder="ID du joueur"><button class="btn" data-dstopid>Arrêter ses effets</button></div></div>
        <div class="section"><h2>Effets par drogue</h2>
            <p class="hint">Durée de défonce, délai avant d'en reprendre, intensité (vision, tremblement). Reprendre la même drogue prolonge l'effet (jusqu'à 2 fois sa durée).
                ${d.emsLinked ? 'Chaque prise est enregistrée pour le laboratoire EMS.' : '<b>elyzea_ems n\'est pas démarré : les prises ne sont pas enregistrées pour le laboratoire.</b>'}</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:12px">${DRUGS().map((x) => `<div class="card recipe">
                <div class="card-head"><strong>${esc(x.icon)} ${esc(x.label)}</strong>${tog(`drugs.${x.id}.enabled`, 'Activée', 'Désactivée')}</div>
                <p class="hint" style="margin:4px 0 8px">${esc(x.desc)}</p>
                <div class="form-grid" style="grid-template-columns:1fr 1fr 1fr">${num('Durée (s)', `drugs.${x.id}.duration`, 10, 3600, fmtS(s.drugs[x.id].duration))}
                    ${num('Délai (s)', `drugs.${x.id}.cooldown`, 0, 3600)}${num('Intensité (%)', `drugs.${x.id}.intensity`, 25, 200)}</div>
                <p class="hint" style="margin-top:6px">Produits : ${d.products.filter((p) => p.drug === x.id).map((p) => `${esc(p.label)}${p.mult !== 1 ? ` (×${p.mult})` : ''}`).join(', ')}</p>
                <div class="btn-row" style="margin-top:6px"><button class="btn" data-dtest="${esc(x.id)}">🧪 Tester sur moi</button></div></div>`).join('')}</div></div>
        <div class="section"><h2>🍄 Hallucinations des champignons</h2>
            <p class="hint">Créatures visibles uniquement par le joueur qui a pris des champignons. Quand elles le frappent, il tombe sans perdre de vie.</p>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(180px,1fr))">
                ${num('Créatures en même temps', 'trip.maxCreatures', 1, 12)}${num('Une nouvelle toutes les (s)', 'trip.spawnEvery', 2, 120)}
                ${num('Délai entre deux coups (s)', 'trip.hitCooldown', 1, 60)}${num('Temps au sol (s)', 'trip.fallTime', 1, 15)}${num('Durée de vie (s)', 'trip.lifetime', 5, 300)}</div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));margin-top:10px">${d.creatures.map((c) => tog(`creatures.${c.model}`, `${c.label} : oui`, `${c.label} : non`)).join('')}</div>
            <p class="hint">Couleurs de fumée des joints : onglet Culture (couleur de chaque variété).</p>
            ${saveBar('drugs,trip,creatures', 'drugs')}</div>`;
    }

    function viewLogs(d) {
        return `<div class="section"><h2>Journal (60 dernières entrées)</h2><table class="loot wide"><tr><th>Date</th><th>Type</th><th>Joueur</th><th>Détail</th></tr>
            ${(d.logs || []).map((l) => `<tr><td class="muted">${l.t ? new Date(l.t * 1000).toLocaleString('fr-FR') : ''}</td><td>${esc(l.kind)}</td><td>${esc(l.name)}</td><td>${esc(l.detail)}</td></tr>`).join('')
            || '<tr><td colspan="4" class="muted">Rien pour l\'instant.</td></tr>'}</table><p class="hint">Mis à jour toutes les 30 s.</p></div>`;
    }

    VIEWS.drogues = () => {
        const d = D.drogues;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_drogues')}</b> ${d.loading ? 'démarre…' : 'ne répond pas'}${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (d.denied) return '<div class="protect">⛔ <span>Permission « drugs_manage » refusée par elyzea_drogues.</span></div>';
        if (!G.draft) G.draft = clone(d.settings);
        const subs = d.full ? SUBS_FULL : [['effects', '✨ Effets']];
        if (!subs.some(([k]) => k === G.sub)) G.sub = subs[0][0];
        const nav = `<div class="btn-row" style="margin-bottom:14px">${subs.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-dsub="${k}">${l}</button>`).join('')}</div>`;
        const V = { sites: viewSites, recipes: viewRecipes, prices: viewPrices, culture: viewCulture, harvest: viewHarvest, effects: viewEffects, logs: viewLogs };
        return nav + V[G.sub](d);
    };

    /* ---------------------------------------------- événements */
    const siteById = (id) => D.drogues.sites.find((s) => s.id === Number(id));
    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-dsub],[data-dtg],[data-dsave],[data-dreset],[data-dact],[data-dplace],[data-dtp],[data-dmove],[data-ddup],[data-ddel],[data-dio],[data-dioadd],[data-drdrug],[data-dpriceadd],[data-dshopadd],[data-dshopdel],[data-dptp],[data-dpdel],[data-dstop],[data-dstopid],[data-dtest]');
        if (!t) return;
        const ds = t.dataset;
        if (ds.dsub) { G.sub = ds.dsub; return render(); }
        if (ds.drdrug) { G.rdrug = ds.drdrug; return render(); }
        if (ds.dtg) { const v = getPath(G.draft, ds.dtg); setPath(G.draft, ds.dtg, v === false); return render(); }
        if (ds.dsave) { const sections = {}; ds.dsave.split(',').forEach((k) => { sections[k] = G.draft[k]; }); send('settings_save', { sections }); G.draft = null; return later(); }
        if (ds.dreset) { if (await confirmBox('Revenir aux valeurs de config.lua ?', 'Les réglages faits dans le menu pour cette partie seront effacés.')) { send('settings_reset', { section: ds.dreset }); G.draft = null; later(); } return; }
        if (ds.dact === 'cancel') { G.draft = null; return render(); }
        if (ds.dplace !== undefined) { if (G.placeType && G.placeModel) editorPost('drug_place', { type: G.placeType, model: G.placeModel, npc: G.placeCat === 'npc' }); return; }
        if (ds.dtp) return editorPost('drug_tp', { id: Number(ds.dtp) });
        if (ds.dmove) { const s = siteById(ds.dmove); if (s) editorPost('drug_place', { id: s.id, type: s.type, model: s.model, h: s.h, npc: s.cat === 'npc' }); return; }
        if (ds.ddup) { const s = siteById(ds.ddup); if (s) editorPost('drug_place', { type: s.type, model: s.model, h: s.h, npc: s.cat === 'npc' }); return; }
        if (ds.ddel) { if (await confirmBox(`Supprimer l'installation #${ds.ddel} ?`, 'Elle disparaît pour tout le monde (interactions ALT comprises).')) { send('site_delete', { id: Number(ds.ddel) }); later(); } return; }
        if (ds.dio) { const [rid, kind, i] = ds.dio.split('|'); G.draft.recipes[rid][kind].splice(Number(i), 1); return render(); }
        if (ds.dioadd) { const [rid, kind] = ds.dioadd.split('|'); G.draft.recipes[rid][kind].push(['drug_bag', 1]); return render(); }
        if (ds.dpriceadd !== undefined) { const id = ((document.getElementById('drg-price-new') || {}).value || '').trim(); if (/^[\w-]+$/.test(id)) { G.draft.prices[id] = G.draft.prices[id] || { price: 0, max: 10 }; render(); } return; }
        if (ds.dshopadd !== undefined) { G.draft.shop.push({ item: 'drug_bag', price: 0 }); return render(); }
        if (ds.dshopdel) { G.draft.shop.splice(Number(ds.dshopdel), 1); return render(); }
        if (ds.dptp) return editorPost('drug_tp', { plant: Number(ds.dptp) });
        if (ds.dpdel) { if (await confirmBox(`Supprimer le pot #${ds.dpdel} ?`, 'La plante et le pot disparaissent (rien n\'est rendu au joueur).')) { send('plant_delete', { id: Number(ds.dpdel) }); later(); } return; }
        if (ds.dstop) { send('stop_player', { id: Number(ds.dstop) }); return later(); }
        if (ds.dstopid !== undefined) { const id = Number((document.getElementById('drg-stop-id') || {}).value); if (id) { send('stop_player', { id }); later(); } return; }
        if (ds.dtest) return send('test_self', { id: ds.dtest });
    });
    document.addEventListener('input', (ev) => {
        if (!on() || !G.draft) return;
        const ds = ev.target.dataset;
        if (ds.dn) setPath(G.draft, ds.dn, Number(ev.target.value));
        else if (ds.dt) setPath(G.draft, ds.dt, ev.target.value.trim());
        else if (ds.dcol) setPath(G.draft, ds.dcol, rgb(ev.target.value));
        else if (ds.dq !== undefined) { G.q = ev.target.value; clearTimeout(G.qt); G.qt = setTimeout(() => { render(); const i = document.querySelector('[data-dq]'); if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); } }, 300); }
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const ds = ev.target.dataset;
        if (ds.dsel) { G[ds.dsel] = ev.target.value; return render(); }
        if (ds.dsv && G.draft) { setPath(G.draft, ds.dsv, ev.target.value); return render(); }
    });
})();
