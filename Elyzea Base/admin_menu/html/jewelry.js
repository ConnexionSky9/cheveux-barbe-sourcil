/* =========================================================
   BRAQUAGE DE BIJOUTERIE (ressource jewelry_heist, permission « heist_manage »)
   A. Général · B. Bijouteries · C. Conditions · D. Animations · E. Butin · F. Bijoux
   G. Sac · H. Police · I. Racheteurs · J. Sécurité et journal · K. Compatibilité
   Toutes les modifications se font dans un brouillon puis « Enregistrer » ;
   le serveur revalide chaque valeur (bornes, types, listes autorisées).
   ========================================================= */
(() => {
    TABS.push({
        id: 'jewelry', group: 6, label: 'Braquage bijouterie', ico: '💎',
        sub: 'Bijouteries, braquage, butin, cinq bijoux, sac, alerte police, racheteurs.',
        show: () => has('heist_manage') && !!(D && D.jewelry),
    });

    const G = { draft: null, sub: 'general', si: 0, bi: 0, logKind: '' };
    const send = (name, data = {}) => action('jewelry', { name, data });
    const SUBS = [['general', 'A. Général'], ['shops', 'B. Bijouteries'], ['cond', 'C. Conditions'], ['anims', 'D. Animations'], ['loot', 'E. Butin'],
        ['gems', 'F. Bijoux'], ['bag', 'G. Sac'], ['police', 'H. Police'], ['buyers', 'I. Racheteurs'], ['security', 'J. Sécurité'], ['compat', 'K. Compatibilité']];
    const PAY = { cash: 'Liquide', bank: 'Compte bancaire', item: 'Objet (argent sale)' };
    const copy = (o) => JSON.parse(JSON.stringify(o));
    const get = (path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), G.draft);
    const setPath = (path, v) => {
        const ks = path.split('.'); const last = ks.pop();
        const parent = ks.reduce((o, k) => { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; return o[k]; }, G.draft);
        parent[last] = v;
    };
    // Les tables Lua vides arrivent en tableaux JSON ([]) : on les remet en objets là où l'on utilise des clés
    const obj = (v) => (v && typeof v === 'object' && !Array.isArray(v) ? v : {});
    function normalize(s) {
        (s.shops || []).forEach((x) => { x.loot = x.loot || {}; x.loot.gems = obj(x.loot.gems); x.sale = obj(x.sale); x.robbery = obj(x.robbery); x.blip = obj(x.blip); });
        (s.buyers || []).forEach((x) => { x.accepted = obj(x.accepted); x.prices = obj(x.prices); x.blip = obj(x.blip); });
        Object.values(s.gems || {}).forEach((g) => { g.shops = Array.isArray(g.shops) ? g.shops : []; g.buyers = Array.isArray(g.buyers) ? g.buyers : []; });
        s.robbery.weapons = Array.isArray(s.robbery.weapons) ? s.robbery.weapons : [];
        s.police.jobs = Array.isArray(s.police.jobs) ? s.police.jobs : [];
        return s;
    }
    const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;

    // Champs
    const num = (path, label, attrs = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-jf="${path}" value="${esc(get(path) ?? '')}" ${attrs}></div>`;
    const txt = (path, label, attrs = '') => `<div class="field"><label>${label}</label><input class="input" data-jf="${path}" value="${esc(get(path) ?? '')}" ${attrs}></div>`;
    const sel = (path, label, opts) => `<div class="field"><label>${label}</label><select class="input" data-jf="${path}">${Object.entries(opts).map(([k, v]) => `<option value="${esc(k)}" ${String(get(path)) === k ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select></div>`;
    const tog = (path, title, sub) => `<div class="tile toggle-tile ${get(path) ? 'on' : ''}" data-jt="${path}"><div><strong>${title}</strong><span>${sub || ''}</span></div><div class="switch"></div></div>`;
    const grid = (cols, inner) => `<div style="display:grid;grid-template-columns:repeat(${cols},1fr);gap:12px;max-width:1150px;margin-bottom:10px">${inner}</div>`;
    const tiles = (inner) => `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">${inner}</div>`;
    const sec = (title, inner, hint) => `<div class="section"><h2>${title}</h2>${hint ? `<p class="hint">${hint}</p>` : ''}${inner}</div>`;
    const img = (id) => `<img src="${esc((D.jewelry.imagePath || '').replace('%s', id))}" style="width:40px;height:40px;object-fit:contain" onerror="this.style.opacity=.2">`;
    const anim = (path, label) => `<tr><td><strong>${label}</strong></td><td><input class="input" data-jf="${path}.dict" value="${esc(get(path + '.dict') || '')}"></td>
        <td><input class="input" data-jf="${path}.name" value="${esc(get(path + '.name') || '')}"></td><td style="width:110px"><input class="input" type="number" data-jf="${path}.flag" value="${esc(get(path + '.flag') ?? 0)}"></td></tr>`;
    const pos = (path, withH) => grid(withH ? 4 : 3, `${num(path + '.x', 'X', 'step="0.01"')}${num(path + '.y', 'Y', 'step="0.01"')}${num(path + '.z', 'Z', 'step="0.01"')}${withH ? num(path + '.h', 'Orientation (°)', 'step="0.1" min="0" max="360"') : ''}`);

    function vGeneral() {
        return sec('A. Paramètres généraux', tiles(tog('general.enabled', get('general.enabled') ? 'Braquages activés' : 'Braquages coupés', 'Coupés : PNJ, braquages, ventes et racheteurs désactivés.'))
            + grid(4, sel('general.locale', 'Langue des messages', { fr: 'Français', en: 'English' })
                + num('general.dropKey', 'Touche de dépôt du sac (code)', 'min="0" max="360"') + txt('general.dropKeyLabel', 'Nom de la touche affiché')
                + num('general.interactDistance', 'Distance d\'interaction (m)', 'step="0.1" min="0.5" max="10"')
                + num('general.notifyDuration', 'Durée des notifications (ms)', 'min="1000" max="30000" step="500"')),
        `Le menu d'interaction est le menu <span class="keycap">ALT</span> existant (elyzea_police) : maintenir ALT, cliquer sur le bijoutier, le racheteur ou près d'un sac.
            Sans elyzea_police, un menu autonome s'ouvre avec <span class="keycap">ALT</span> (modifiable par chaque joueur dans Paramètres › Touches › FiveM).
            Dépôt du sac : <span class="keycap">${esc(get('general.dropKeyLabel') || 'E')}</span> (code 38 = E).`);
    }

    function shopList(kind) {
        const list = get(kind) || []; const cur = kind === 'shops' ? G.si : G.bi;
        return `<div class="btn-row" style="margin-bottom:10px;flex-wrap:wrap">${list.map((s, i) => `<button class="btn ${i === cur ? 'primary' : ''}" data-jsel="${kind}" data-i="${i}">${s.enabled ? '' : '⏸ '}${esc(s.name || s.id)}</button>`).join('')}
            <button class="btn" data-ja="add" data-k="${kind}">+ Nouveau</button></div>`;
    }

    function vShops() {
        const list = get('shops') || [];
        if (G.si >= list.length) G.si = Math.max(0, list.length - 1);
        const s = list[G.si];
        if (!s) return sec('B. Bijouteries', shopList('shops') + '<p class="hint">Aucune bijouterie. Créez-en une, placez-vous derrière le comptoir puis « Placer le PNJ ici ».</p>');
        const p = `shops.${G.si}`; const cool = (D.jewelry.cool || {})[s.id] || {};
        return sec('B. Bijouteries', shopList('shops')
            + tiles(tog(`${p}.enabled`, s.enabled ? 'Bijouterie active' : 'Bijouterie désactivée', 'Désactivée : PNJ retiré, plus de vente ni de braquage.')
                + tog(`${p}.blip.enabled`, 'Blip sur la carte', 'Visible par tous les joueurs.'))
            + grid(4, txt(`${p}.id`, 'Identifiant (unique, sans espace)') + txt(`${p}.name`, 'Nom affiché')
                + `<div class="field"><label>Modèle du PNJ</label><input class="input" list="jh-peds" data-jf="${p}.ped.model" value="${esc(s.ped.model)}"></div>`
                + num(`${p}.interactDistance`, 'Distance d\'interaction (m)', 'step="0.1" min="0.5" max="10"'))
            + '<h3 style="margin:6px 0 8px">Position du bijoutier</h3>' + pos(`${p}.ped`, true)
            + '<h3 style="margin:6px 0 8px">Emplacement du sac remis (vide = devant le PNJ)</h3>' + pos(`${p}.bagSpot`, false)
            + `<div class="btn-row" style="flex-wrap:wrap"><button class="btn primary" data-ja="place" data-t="shop" data-w="ped">📍 Placer le PNJ ici</button>
                <button class="btn" data-ja="place" data-t="shop" data-w="bagSpot">🎒 Placer le sac ici</button><button class="btn" data-ja="clearBagSpot">Sac devant le PNJ</button>
                <button class="btn" data-ja="goto" data-t="shop">🚀 Aller au PNJ</button><button class="btn" data-ja="testRob">🧪 Tester le braquage (staff)</button>
                <button class="btn" data-ja="dup" data-k="shops">Dupliquer</button><button class="btn danger" data-ja="del" data-k="shops">Supprimer</button></div>
            <p class="hint" style="margin-top:6px">« Tester » lance un vrai braquage sans arme, sans policiers, sans délai et sans alerte police (tracé « TEST STAFF »). Délai restant : ${cool.cooldown || 0} min · indisponible : ${cool.closed || 0} min.</p>`)
            + sec('Vente normale de bijoux', tiles(tog(`${p}.sale.buy`, 'Les joueurs peuvent acheter', 'Prix = prix du bijou × majoration.') + tog(`${p}.sale.sell`, 'Les joueurs peuvent vendre', 'Prix = prix du bijou × taux de rachat.'))
                + grid(4, num(`${p}.sale.buyMarkup`, 'Majoration à l\'achat (%)', 'min="100" max="1000"') + num(`${p}.sale.sellRate`, 'Taux de rachat (%)', 'min="1" max="100"')
                    + num(`${p}.sale.maxPerTx`, 'Quantité max. par transaction', 'min="1" max="500"') + sel(`${p}.sale.payment`, 'Paiement', PAY))
                + grid(3, num(`${p}.blip.sprite`, 'Blip : icône', 'min="1" max="900"') + num(`${p}.blip.color`, 'Blip : couleur', 'min="0" max="85"') + num(`${p}.blip.scale`, 'Blip : taille', 'step="0.1" min="0.3" max="2"')));
    }

    function vCond() {
        const weapons = get('robbery.weapons') || [];
        const choices = Array.from(new Set([...(D.jewelry.weaponChoices || []), ...weapons]));
        const shops = (get('shops') || []).map((s, i) => { const p = `shops.${i}.robbery`; return `<tr><td><strong>${esc(s.name)}</strong></td>
            <td><input type="checkbox" class="check" data-jc="${p}.enabled" ${get(p + '.enabled') ? 'checked' : ''}></td>
            <td><input class="input" type="number" min="0" max="50" data-jf="${p}.minCops" value="${esc(get(p + '.minCops'))}"></td>
            <td><input class="input" type="number" min="0" data-jf="${p}.cooldown" value="${esc(get(p + '.cooldown'))}"></td>
            <td><input class="input" type="number" min="0" data-jf="${p}.unavailable" value="${esc(get(p + '.unavailable'))}"></td>
            <td><input class="input" type="number" step="0.5" min="1" max="15" data-jf="${p}.robDistance" value="${esc(get(p + '.robDistance'))}"></td>
            <td><input class="input" type="number" step="1" min="3" max="200" data-jf="${p}.cancelDistance" value="${esc(get(p + '.cancelDistance'))}"></td>
            <td><select class="input" data-jf="${p}.onLeave"><option value="cancel" ${get(p + '.onLeave') === 'cancel' ? 'selected' : ''}>Annuler</option><option value="continue" ${get(p + '.onLeave') === 'continue' ? 'selected' : ''}>Continuer</option></select></td>
            <td><select class="input" data-jf="${p}.onDeath"><option value="cancel" ${get(p + '.onDeath') === 'cancel' ? 'selected' : ''}>Annuler</option><option value="continue" ${get(p + '.onDeath') === 'continue' ? 'selected' : ''}>Continuer</option></select></td>
            <td><input type="checkbox" class="check" data-jc="${p}.cooldownOnCancel" ${get(p + '.cooldownOnCancel') ? 'checked' : ''}></td></tr>`; }).join('');
        return sec('C. Conditions du braquage', grid(4, num('robbery.globalCooldown', 'Délai entre deux braquages, toutes bijouteries (min)', 'min="0" max="1440"'))
            + `<h3 style="margin:8px 0">Armes autorisées</h3><div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:6px;margin-bottom:8px">
                ${choices.map((w) => `<label class="muted" style="display:flex;gap:6px;align-items:center"><input type="checkbox" class="check" data-jw="${esc(w)}" ${weapons.includes(w) ? 'checked' : ''}>${esc(w)}</label>`).join('')}</div>
              <div class="btn-row"><input class="input" data-jwadd placeholder="Autre arme (ex : WEAPON_DAGGER)" style="max-width:280px"><button class="btn" data-ja="addWeapon">Ajouter</button></div>`)
            + sec('Par bijouterie', `<table class="loot wide"><tr><th>Bijouterie</th><th>Braquable</th><th>Policiers min.</th><th>Délai (min)</th><th>Indisponible (min)</th><th>Distance pour braquer (m)</th>
                <th>Distance d'annulation (m)</th><th>Si le braqueur s'éloigne</th><th>Si le braqueur tombe</th><th>Délai même si annulé</th></tr>${shops}</table>`,
            'Le braquage est refusé si : bijouterie indisponible, délai non écoulé, braquage déjà en cours, pas d\'arme autorisée en main, pas assez de policiers en service, joueur trop loin ou portant déjà un sac. Une déconnexion du braqueur annule toujours le braquage.');
    }

    function vAnims() {
        const quick = [30, 60, 90, 120, 180].map((n) => `<button class="btn ${Number(get('anims.fillTime')) === n ? 'primary' : ''}" data-jfill="${n}">${n} s</button>`).join('');
        return sec('D. Animations et durées', grid(4, num('anims.panicTime', 'Durée de panique (s)', 'min="0" max="120"') + num('anims.fillTime', 'Durée de remplissage du sac (s)', 'min="5" max="900"')
                + num('anims.handoverDelay', 'Délai avant la remise du sac (s)', 'min="0" max="60"'))
            + `<div class="btn-row" style="margin-bottom:10px">${quick}</div>`
            + tiles(tog('anims.progress', 'Barre de progression', 'Affichée au braqueur, calée sur les durées du serveur.'))
            + `<table class="loot wide"><tr><th>Animation</th><th>Dictionnaire</th><th>Nom</th><th>Option (flag)</th></tr>${anim('anims.panic', 'Panique')}${anim('anims.fill', 'Remplissage')}${anim('anims.handover', 'Remise')}${anim('anims.pickup', 'Ramassage (joueur)')}</table>`
            + grid(2, txt('anims.fallbackPanic', 'Secours panique (scénario GTA)') + txt('anims.fallbackFill', 'Secours remplissage (scénario GTA)')),
        'Le sac n\'est jamais remis avant la fin du remplissage : les étapes sont chronométrées par le serveur. Si une animation ne charge pas, le scénario de secours est joué et la mission continue.');
    }

    function vLoot() {
        const shops = get('shops') || [];
        const gems = D.jewelry.gemOrder || [];
        const blocks = shops.map((s, i) => {
            const p = `shops.${i}.loot`;
            const rows = gems.map((g) => {
                const ov = get(`${p}.gems.${g}`);
                const base = get(`gems.${g}`) || {};
                return `<tr><td>${img(g)}</td><td><strong>${esc(base.label || g)}</strong></td>
                    <td><input type="checkbox" class="check" data-jov="${p}.gems.${g}" data-g="${g}" ${ov ? 'checked' : ''}> <span class="muted">${ov ? 'personnalisé' : `global (${base.min}-${base.max}, ${base.chance} %)`}</span></td>
                    ${ov ? `<td><input type="checkbox" class="check" data-jc="${p}.gems.${g}.enabled" ${ov.enabled ? 'checked' : ''}></td>
                        <td><input class="input" type="number" min="0" data-jf="${p}.gems.${g}.min" value="${esc(ov.min)}"></td>
                        <td><input class="input" type="number" min="0" data-jf="${p}.gems.${g}.max" value="${esc(ov.max)}"></td>
                        <td><input class="input" type="number" min="0" max="100" data-jf="${p}.gems.${g}.chance" value="${esc(ov.chance)}"></td>` : '<td colspan="4" class="muted">Valeurs de l\'onglet Bijoux</td>'}</tr>`;
            }).join('');
            return sec(`Butin · ${esc(s.name)}`, grid(4, num(`${p}.moneyMin`, 'Argent minimum ($)', 'min="0"') + num(`${p}.moneyMax`, 'Argent maximum ($)', 'min="0"'))
                + `<table class="loot wide"><tr><th style="width:56px"></th><th>Bijou</th><th>Réglage</th><th>Activé</th><th>Min</th><th>Max</th><th>Chance (%)</th></tr>${rows}</table>`);
        }).join('');
        return sec('E. Butin', grid(4, sel('loot.moneyType', 'Argent du sac versé en', PAY) + txt('loot.moneyItem', 'Objet « argent » (si Objet)')),
            'Le serveur tire l\'argent entre le minimum et le maximum et, pour chaque bijou, une quantité si le tirage de chance réussit (plafonnée par « max. par braquage »). Le client ne choisit jamais le butin.') + blocks;
    }

    function vGems() {
        const shops = get('shops') || []; const buyers = get('buyers') || [];
        const rows = (D.jewelry.gemOrder || []).map((g) => {
            const p = `gems.${g}`; const ok = (D.jewelry.items || {})[g];
            const chk = (listPath, items) => items.map((x) => `<label class="muted" style="display:inline-flex;gap:4px;margin-right:8px"><input type="checkbox" class="check" data-jl="${listPath}" data-v="${esc(x.id)}" ${(get(listPath) || []).includes(x.id) ? 'checked' : ''}>${esc(x.name)}</label>`).join('');
            return `<div class="section" style="display:grid;grid-template-columns:72px 1fr;gap:14px;align-items:start">
                <div style="text-align:center">${img(g).replace('40px;height:40px', '64px;height:64px')}<div class="muted" style="font-size:11px;margin-top:4px">${ok ? '✅ dans l\'inventaire' : '⚠️ absent de l\'inventaire'}</div></div>
                <div>${tiles(tog(`${p}.enabled`, `${esc(get(p + '.label'))} <span class="muted">(${g})</span>`, get(`${p}.enabled`) ? 'Activé : butin, vente et revente.' : 'Désactivé partout.'))}
                    ${grid(4, txt(`${p}.label`, 'Nom affiché') + num(`${p}.price`, 'Prix de revente unitaire ($)', 'min="0"') + num(`${p}.maxPerHeist`, 'Max. par braquage', 'min="0"') + num(`${p}.chance`, 'Probabilité d\'apparition (%)', 'min="0" max="100"'))}
                    ${grid(4, num(`${p}.min`, 'Quantité min. dans un braquage', 'min="0"') + num(`${p}.max`, 'Quantité max. dans un braquage', 'min="0"') + `<div class="field" style="grid-column:span 2"><label>Description</label><input class="input" data-jf="${p}.description" value="${esc(get(p + '.description') || '')}"></div>`)}
                    <div class="hint">Bijouteries où il peut apparaître (aucune cochée = toutes) : ${chk(`${p}.shops`, shops.map((s) => ({ id: s.id, name: s.name })))}</div>
                    <div class="hint">Racheteurs qui l'acceptent (aucun coché = tous ceux qui l'ont activé) : ${chk(`${p}.buyers`, buyers.map((s) => ({ id: s.id, name: s.name })))}</div></div></div>`;
        }).join('');
        return sec('F. Les cinq bijoux', '', `Objets de l'inventaire : <b>diamond</b>, <b>ruby</b>, <b>sapphire</b>, <b>emerald</b>, <b>amethyst</b> (elyzea_inventory/shared/items.lua, images dans elyzea_inventory/html/img).
            Le nom et la description modifiés ici s'affichent dans les menus du braquage ; l'inventaire garde les siens (fichier items.lua).`) + rows;
    }

    function vBag() {
        const bags = (D.jewelry.bags || []).map((b) => `<tr><td class="mono">${esc(b.id)}</td><td>${esc(b.state === 'ground' ? 'Au sol' : b.state === 'carried' ? 'Porté' : 'Hors ligne')}</td>
            <td>${esc(b.holder || b.owner || '—')}</td><td>${money(b.money)}${b.gems ? ` · ${esc(b.gems)}` : ''}</td>
            <td style="text-align:right"><button class="btn" data-ja="gotoXYZ" data-x="${b.x}" data-y="${b.y}" data-z="${b.z}">Aller</button><button class="btn danger" data-ja="deleteBag" data-id="${esc(b.id)}">Supprimer</button></td></tr>`).join('');
        return sec('G. Sac', grid(4, txt('bag.model', 'Modèle du sac') + sel('bag.mode', 'Affichage sur le personnage', { prop: 'Objet attaché au dos', component: 'Sac de tenue GTA (composant 5)' })
                + num('bag.bone', 'Os d\'attache (24818 = dos)') + num('bag.pickupDistance', 'Distance de ramassage (m)', 'step="0.1" min="0.5" max="10"'))
            + grid(6, num('bag.offset.x', 'Décalage X', 'step="0.01"') + num('bag.offset.y', 'Décalage Y', 'step="0.01"') + num('bag.offset.z', 'Décalage Z', 'step="0.01"')
                + num('bag.rotation.x', 'Rotation X', 'step="1"') + num('bag.rotation.y', 'Rotation Y', 'step="1"') + num('bag.rotation.z', 'Rotation Z', 'step="1"'))
            + grid(4, num('bag.component.male.drawable', 'Composant homme : modèle') + num('bag.component.male.texture', 'Composant homme : texture')
                + num('bag.component.female.drawable', 'Composant femme : modèle') + num('bag.component.female.texture', 'Composant femme : texture'))
            + grid(4, txt('bag.dropAnim.dict', 'Animation de dépôt : dictionnaire') + txt('bag.dropAnim.name', 'Animation de dépôt : nom') + num('bag.dropAnim.time', 'Durée (ms)', 'min="100" max="10000"'))
            + grid(4, sel('bag.pickupRule', 'Qui peut ramasser', { anyone: 'Tout le monde', owner: 'Le braqueur seulement (+ police)' }) + sel('bag.openRule', 'Qui peut ouvrir', { anyone: 'Tout le monde', owner: 'Le braqueur seulement' })
                + sel('bag.onDeath', 'Porteur à terre', { drop: 'Le sac tombe au sol', keep: 'Il garde le sac' }) + sel('bag.onDisconnect', 'Déconnexion du porteur', { drop: 'Sac laissé au sol', keep: 'Rendu à la reconnexion' }))
            + grid(4, num('bag.cleanupMinutes', 'Suppression d\'un sac abandonné au sol (min, 0 = jamais)', 'min="0"') + num('bag.maxGroundBags', 'Sacs au sol maximum', 'min="1" max="500"'))
            + tiles(tog('bag.policeSeize', 'Saisie par la police', 'Un policier en service peut ramasser tout sac et « Saisir le contenu » (sac vidé, tracé).')),
        `Porter : le sac suit le personnage à pied et en véhicule. Déposer : <span class="keycap">${esc(get('general.dropKeyLabel') || 'E')}</span> à pied. ALT près d'un sac : Ramasser / Ouvrir.`)
            + sec(`Sacs existants (${(D.jewelry.bags || []).length})`, bags ? `<table class="loot wide"><tr><th>Sac</th><th>État</th><th>Porteur / propriétaire</th><th>Contenu</th><th></th></tr>${bags}</table>
                <div class="btn-row" style="margin-top:10px"><button class="btn danger" data-ja="clearGroundBags">Supprimer tous les sacs au sol</button></div>` : '<p class="hint">Aucun sac.</p>');
    }

    function vPolice() {
        return sec('H. Alerte police', grid(4, sel('police.dispatch', 'Système d\'alerte', { auto: 'Automatique (elyzea_police, sinon interne)', elyzea_police: 'elyzea_police uniquement', internal: 'Interne uniquement', both: 'Les deux' })
                + sel('police.alertKind', 'Type d\'alerte elyzea_police', { robbery: 'Braquage', shots: 'Coups de feu', assault: 'Agression', distress: 'Détresse', suspect: 'Activité suspecte', other: 'Autre' })
                + txt('police.title', 'Titre de l\'alerte') + `<div class="field"><label>Métiers destinataires (alerte interne)</label><input class="input" data-jjobs value="${esc((get('police.jobs') || []).join(', '))}"></div>`)
            + tiles(tog('police.notify', 'Notification aux policiers', 'Message + son (alerte interne).') + tog('police.blip.flash', 'Blip clignotant', ''))
            + grid(4, num('police.blip.sprite', 'Blip : icône', 'min="1" max="900"') + num('police.blip.color', 'Blip : couleur', 'min="0" max="85"') + num('police.blip.scale', 'Blip : taille', 'step="0.1"')
                + num('police.blip.radius', 'Rayon de la zone (m)', 'min="0" max="2000"') + num('police.blip.radiusColor', 'Couleur de la zone', 'min="0" max="85"') + num('police.blip.duration', 'Durée d\'affichage (s)', 'min="10" max="3600"')),
        `Envoyée par le serveur dès le début du braquage : « ${esc(get('police.title'))} », nom et identifiant de la bijouterie, coordonnées GPS, heure. Policiers en service actuellement : <b>${D.jewelry.police}</b>.`);
    }

    function vBuyers() {
        const list = get('buyers') || [];
        if (G.bi >= list.length) G.bi = Math.max(0, list.length - 1);
        const b = list[G.bi];
        if (!b) return sec('I. Racheteurs', shopList('buyers') + '<p class="hint">Aucun racheteur.</p>');
        const p = `buyers.${G.bi}`;
        const gems = (D.jewelry.gemOrder || []).map((g) => `<tr><td>${img(g)}</td><td><strong>${esc(get(`gems.${g}.label`))}</strong></td>
            <td><input type="checkbox" class="check" data-jacc="${p}.accepted.${g}" ${get(`${p}.accepted.${g}`) ? 'checked' : ''}></td>
            <td><input class="input" type="number" min="0" data-jprice="${p}.prices.${g}" value="${esc(get(`${p}.prices.${g}`) ?? '')}" placeholder="global : ${esc(get(`gems.${g}.price`))}"></td></tr>`).join('');
        return sec('I. Racheteurs', shopList('buyers')
            + tiles(tog(`${p}.enabled`, b.enabled ? 'Rachat actif' : 'Rachat désactivé', '') + tog(`${p}.blip.enabled`, 'Blip sur la carte', 'Généralement caché pour un receleur.'))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle du PNJ</label><input class="input" list="jh-peds" data-jf="${p}.ped.model" value="${esc(b.ped.model)}"></div>`
                + num(`${p}.interactDistance`, 'Distance d\'interaction (m)', 'step="0.1" min="0.5" max="10"'))
            + pos(`${p}.ped`, true)
            + grid(4, num(`${p}.maxPerTx`, 'Quantité max. par transaction', 'min="1" max="1000"') + sel(`${p}.payment`, 'Paiement', PAY)
                + num(`${p}.blip.sprite`, 'Blip : icône', 'min="1" max="900"') + num(`${p}.blip.color`, 'Blip : couleur', 'min="0" max="85"'))
            + `<div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-ja="place" data-t="buyer" data-w="ped">📍 Placer le PNJ ici</button><button class="btn" data-ja="goto" data-t="buyer">🚀 Aller au PNJ</button>
                <button class="btn" data-ja="dup" data-k="buyers">Dupliquer</button><button class="btn danger" data-ja="del" data-k="buyers">Supprimer</button></div>
              <table class="loot wide"><tr><th style="width:56px"></th><th>Bijou</th><th>Accepté</th><th>Prix de rachat ($, vide = prix global)</th></tr>${gems}</table>`);
    }

    function vSecurity() {
        const heists = (D.jewelry.heists || []).map((h) => `<tr><td>${esc(h.shop)}</td><td>${esc(h.robber)}${h.test ? ' <span class="muted">(test)</span>' : ''}</td><td>${esc(h.stage)}</td><td>${h.left} s</td>
            <td style="text-align:right"><button class="btn danger" data-ja="cancelHeist" data-shop="${esc(h.shop)}">Annuler</button></td></tr>`).join('');
        const KINDS = { '': 'Tout', heist: 'Braquages', bag: 'Sacs', sale: 'Ventes', admin: 'Staff', anomaly: 'Anomalies' };
        const logs = (D.jewelry.logs || []).filter((l) => !G.logKind || l.kind === G.logKind).map((l) => `<tr><td class="muted" style="white-space:nowrap">${new Date(l.t * 1000).toLocaleString('fr-FR')}</td>
            <td>${esc(KINDS[l.kind] || l.kind)}</td><td>${esc(l.name || '—')}</td><td class="mono">${esc(l.ref || '')}</td><td>${esc(l.details || '')}</td></tr>`).join('');
        return sec('J. Sécurité', grid(4, num('security.rateLimit', 'Actions max. par joueur / 3 s', 'min="2" max="50"') + num('security.logRetentionDays', 'Conservation du journal (jours)', 'min="1" max="365"'))
            + `<p class="hint">Protections actives : identifiants uniques (missions, sacs), états tenus par le serveur, positions lues par le serveur, prix et butin calculés par le serveur,
                verrous (un transfert à la fois par sac et par joueur), retrait des objets avant paiement (rendus si le paiement échoue), sacs enregistrés en base après chaque changement,
                restauration après redémarrage, nettoyage des sacs abandonnés.</p>`)
            + sec('Braquages en cours', heists ? `<table class="loot wide"><tr><th>Bijouterie</th><th>Braqueur</th><th>Étape</th><th>Restant</th><th></th></tr>${heists}</table>` : '<p class="hint">Aucun.</p>'
                + '<div class="btn-row" style="margin-top:8px"><button class="btn" data-ja="resetCooldowns">Remettre les délais à zéro</button></div>')
            + sec('Journal', `<div class="btn-row" style="margin-bottom:8px">${Object.entries(KINDS).map(([k, v]) => `<button class="btn ${G.logKind === k ? 'primary' : ''}" data-jlog="${k}">${v}</button>`).join('')}</div>
                <table class="loot wide"><tr><th>Date</th><th>Type</th><th>Joueur</th><th>Réf.</th><th>Détail</th></tr>${logs || '<tr><td colspan="5" class="muted">Vide.</td></tr>'}</table>`);
    }

    function vCompat() {
        const j = D.jewelry; const it = j.items || {};
        const line = (ok, label, detail) => `<tr><td>${ok ? '✅' : '⚠️'}</td><td><strong>${label}</strong></td><td class="muted">${detail}</td></tr>`;
        return sec('K. Compatibilité', `<table class="loot wide">
            ${line(j.inventoryRes, 'Inventaire', 'elyzea_inventory : AddItem / RemoveItem / CanCarryItem / GetItemCount')}
            ${(j.gemOrder || []).map((g) => line(it[g], `Objet « ${g} »`, it[g] ? 'déclaré dans elyzea_inventory/shared/items.lua' : 'absent : redémarrer elyzea_inventory après la mise à jour')).join('')}
            ${line(true, 'Argent', 'elyzea_core : AddMoney / RemoveMoney (liquide, banque) ou objet d\'inventaire')}
            ${line(j.policeRes, 'Police et dispatch', j.policeRes ? 'elyzea_police : SendAlert, GetOnDutyCount, IsOnDuty' : 'elyzea_police arrêté : alerte interne et métiers de l\'onglet Police')}
            ${line(j.policeRes, 'Menu ALT', j.policeRes ? 'menu ALT d\'elyzea_police (fournisseur jewelry_heist)' : 'menu ALT autonome de jewelry_heist')}
            ${line(true, 'Notifications', 'elyzea_core:Notify')}
            ${line(true, 'Permissions', 'admin_menu : heist_manage (revérifiée par jewelry_heist)')}
            ${line(true, 'Admin_Menu', 'onglet Braquage bijouterie, catégorie Illégal')}</table>`);
    }

    VIEWS.jewelry = () => {
        const j = D.jewelry;
        if (!j.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(j.resource || 'jewelry_heist')}</b> ne répond pas${j.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (!G.draft) G.draft = normalize(copy(j.settings));
        const bar = `<div class="section"><div class="btn-row"><button class="btn primary" data-ja="save">💾 Enregistrer</button>
                <button class="btn" data-ja="cancel">Annuler les modifications</button><button class="btn" data-ja="reset">Valeurs par défaut</button>
                <span class="muted" style="align-self:center">Les modifications ne sont appliquées qu'après « Enregistrer ».</span></div></div>`;
        const body = { general: vGeneral, shops: vShops, cond: vCond, anims: vAnims, loot: vLoot, gems: vGems, bag: vBag, police: vPolice, buyers: vBuyers, security: vSecurity, compat: vCompat }[G.sub]();
        return `<div class="stats">
                <div class="stat"><b>${j.settings.general.enabled ? 'Activés' : 'Coupés'}</b><span>Braquages</span></div>
                <div class="stat"><b>${(j.heists || []).length}</b><span>Braquage(s) en cours</span></div>
                <div class="stat"><b>${(j.bags || []).length}</b><span>Sac(s) en jeu</span></div>
                <div class="stat"><b>${j.police}</b><span>Policier(s) en service</span></div></div>
            <div class="btn-row" style="flex-wrap:wrap;margin-bottom:12px">${SUBS.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-jsub="${k}">${l}</button>`).join('')}</div>
            <datalist id="jh-peds">${(j.pedModels || []).map((m) => `<option value="${esc(m)}">`).join('')}</datalist>
            ${bar}
            ${body}
            ${bar}`;
    };

    // ---------------- Événements ----------------
    const on = () => isOpen && tab === 'jewelry' && G.draft;
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.jf && t.tagName !== 'SELECT') setPath(t.dataset.jf, t.type === 'number' ? (t.value === '' ? null : Number(t.value)) : t.value);
        if (t.dataset.jprice) { const v = t.value === '' ? null : Number(t.value); if (v === null) { const ks = t.dataset.jprice.split('.'); const g = ks.pop(); const o = get(ks.join('.')); if (o) delete o[g]; } else setPath(t.dataset.jprice, v); }
        if (t.dataset.jjobs !== undefined) setPath('police.jobs', t.value.split(',').map((x) => x.trim()).filter(Boolean));
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.jf && t.tagName === 'SELECT') { setPath(t.dataset.jf, t.value); render(); }
        if (t.dataset.jc) setPath(t.dataset.jc, t.checked);
        if (t.dataset.jacc) setPath(t.dataset.jacc, t.checked);
        if (t.dataset.jw) {
            const l = get('robbery.weapons') || [];
            setPath('robbery.weapons', t.checked ? Array.from(new Set([...l, t.dataset.jw])) : l.filter((w) => w !== t.dataset.jw));
        }
        if (t.dataset.jl) {
            const l = get(t.dataset.jl) || [];
            setPath(t.dataset.jl, t.checked ? Array.from(new Set([...l, t.dataset.v])) : l.filter((x) => x !== t.dataset.v));
        }
        if (t.dataset.jov) {
            if (t.checked) { const b = get(`gems.${t.dataset.g}`) || {}; setPath(t.dataset.jov, { enabled: true, min: b.min, max: b.max, chance: b.chance }); }
            else { const ks = t.dataset.jov.split('.'); const g = ks.pop(); const o = get(ks.join('.')); if (o) delete o[g]; }
            render();
        }
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'jewelry') return;
        let n;
        if ((n = ev.target.closest('[data-jsub]'))) { G.sub = n.dataset.jsub; return render(); }
        if ((n = ev.target.closest('[data-jlog]'))) { G.logKind = n.dataset.jlog; return render(); }
        if (!G.draft) return;
        if ((n = ev.target.closest('[data-jt]'))) { setPath(n.dataset.jt, !get(n.dataset.jt)); return render(); }
        if ((n = ev.target.closest('[data-jfill]'))) { setPath('anims.fillTime', Number(n.dataset.jfill)); return render(); }
        if ((n = ev.target.closest('[data-jsel]'))) { if (n.dataset.jsel === 'shops') G.si = Number(n.dataset.i); else G.bi = Number(n.dataset.i); return render(); }
        if (!(n = ev.target.closest('[data-ja]')) || n.disabled) return;
        const cur = (k) => (k === 'shops' ? G.si : G.bi);
        switch (n.dataset.ja) {
            case 'save': send('save', G.draft); G.draft = null; return;
            case 'cancel': G.draft = null; return render();
            case 'reset': if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages du braquage de bijouterie reviennent à ceux du fichier config.lua (bijouteries et racheteurs compris).')) { G.draft = null; send('reset'); } return;
            case 'add': {
                const k = n.dataset.k; const l = get(k) || [];
                const base = copy((D.jewelry.defaults[k] || [])[0] || {});
                base.id = `${k === 'shops' ? 'bijouterie' : 'receleur'}_${l.length + 1}`; base.name = k === 'shops' ? `Bijouterie ${l.length + 1}` : `Racheteur ${l.length + 1}`;
                if (k === 'shops') delete base.bagSpot;
                l.push(base); setPath(k, l); if (k === 'shops') G.si = l.length - 1; else G.bi = l.length - 1; return render();
            }
            case 'dup': {
                const k = n.dataset.k; const l = get(k); const src = l[cur(k)]; if (!src) return;
                const c = copy(src); c.id = `${src.id}_copie`; c.name = `${src.name} (copie)`; l.push(c); if (k === 'shops') G.si = l.length - 1; else G.bi = l.length - 1; return render();
            }
            case 'del': {
                const k = n.dataset.k; const l = get(k); const e = l[cur(k)]; if (!e) return;
                if (!(await confirmBox(`Supprimer « ${e.name} » ?`, 'Le PNJ disparaît après « Enregistrer ». Les sacs déjà en jeu sont conservés.'))) return;
                l.splice(cur(k), 1); return render();
            }
            case 'clearBagSpot': delete G.draft.shops[G.si].bagSpot; return render();
            case 'place': send('place', { draft: G.draft, target: n.dataset.t, what: n.dataset.w, index: (n.dataset.t === 'buyer' ? G.bi : G.si) + 1 }); G.draft = null; return;
            case 'goto': { const e = n.dataset.t === 'buyer' ? G.draft.buyers[G.bi] : G.draft.shops[G.si]; if (e) send('teleport', { x: e.ped.x, y: e.ped.y, z: e.ped.z }); return; }
            case 'gotoXYZ': send('teleport', { x: Number(n.dataset.x), y: Number(n.dataset.y), z: Number(n.dataset.z) }); return;
            case 'testRob': { const e = G.draft.shops[G.si]; if (e) send('testRob', { shop: e.id }); return; }
            case 'cancelHeist': send('cancelHeist', { shop: n.dataset.shop }); return;
            case 'resetCooldowns': send('resetCooldowns'); return;
            case 'deleteBag': if (await confirmBox('Supprimer ce sac ?', 'Son contenu est perdu (tracé dans le journal).')) send('deleteBag', { id: n.dataset.id }); return;
            case 'clearGroundBags': if (await confirmBox('Supprimer tous les sacs au sol ?', 'Leur contenu est perdu (tracé dans le journal).')) send('clearGroundBags'); return;
            case 'addWeapon': {
                const inp = document.querySelector('[data-jwadd]'); const w = (inp.value || '').trim().toUpperCase().replace(/[^A-Z0-9_]/g, '');
                if (w) setPath('robbery.weapons', Array.from(new Set([...(get('robbery.weapons') || []), w]))); return render();
            }
        }
    });
})();
