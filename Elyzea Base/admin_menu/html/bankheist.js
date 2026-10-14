/* =========================================================
   BRAQUAGE DE BANQUE (ressource bank_heist, permission « bankheist_manage »)
   A. Général · B. Banques · C. Conditions · D. Marchands · E. Objets et prix · F. Piratage
   G. Coffre et butin · H. Dépôts · I. Visuels · J. Sessions en direct · K. Journal et compatibilité
   Les modifications se font dans un brouillon puis « Enregistrer » ; le serveur revalide tout.
   ========================================================= */
(() => {
    TABS.push({
        id: 'bankheist', group: 6, label: 'Braquage de banque', ico: '🏦',
        sub: 'Banques, marchand, prix, piratage, C4, coffre, dépôts, sessions en direct.',
        show: () => has('bankheist_manage') && !!(D && D.bankheist),
    });

    const G = { draft: null, sub: 'general', bi: 0, mi: 0, di: 0, logKind: '' };
    const send = (name, data = {}) => action('bankheist', { name, data });
    const SUBS = [['general', 'A. Général'], ['banks', 'B. Banques'], ['cond', 'C. Conditions'], ['merchants', 'D. Marchands'], ['items', 'E. Objets et prix'],
        ['hack', 'F. Piratage'], ['loot', 'G. Coffre et butin'], ['deposits', 'H. Dépôts'], ['visuals', 'I. Visuels'], ['live', 'J. Sessions en direct'], ['logs', 'K. Journal']];
    const PAY = { cash: 'Liquide', bank: 'Compte bancaire', item: 'Argent sale (objet)' };
    const PHASE = { available: '🟢 Disponible', cooldown: '⏳ Délai', started: '🔴 Braquage lancé', hacking: '💻 Piratage', exhausted: '🧨 Ordinateur grillé (C4)', c4: '💥 C4 posée', open: '💰 Coffre ouvert' };
    const copy = (o) => JSON.parse(JSON.stringify(o));
    const obj = (v) => (v && typeof v === 'object' && !Array.isArray(v) ? v : {});
    const arr = (v) => (Array.isArray(v) ? v : []);
    const get = (path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), G.draft);
    const setPath = (path, v) => {
        const ks = path.split('.'); const last = ks.pop();
        const parent = ks.reduce((o, k) => { if (o[k] == null || typeof o[k] !== 'object') o[k] = {}; return o[k]; }, G.draft);
        parent[last] = v;
    };
    const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} $`;
    function normalize(s) {
        s.banks = arr(s.banks); s.merchants = arr(s.merchants); s.deposits = arr(s.deposits);
        s.banks.forEach((b) => { b.cash = arr(b.cash); b.required = obj(b.required); b.hours = obj(b.hours); b.door = obj(b.door); b.blip = obj(b.blip); b.loot = obj(b.loot); });
        s.merchants.forEach((m) => { m.jobs = arr(m.jobs); m.sells = obj(m.sells); m.blip = obj(m.blip); });
        s.loot.extras = arr(s.loot.extras); s.police.jobs = arr(s.police.jobs);
        return s;
    }

    const num = (path, label, attrs = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-bf="${path}" value="${esc(get(path) ?? '')}" ${attrs}></div>`;
    const txt = (path, label, attrs = '') => `<div class="field"><label>${label}</label><input class="input" data-bf="${path}" value="${esc(get(path) ?? '')}" ${attrs}></div>`;
    const sel = (path, label, opts) => `<div class="field"><label>${label}</label><select class="input" data-bf="${path}">${Object.entries(opts).map(([k, v]) => `<option value="${esc(k)}" ${String(get(path)) === k ? 'selected' : ''}>${esc(v)}</option>`).join('')}</select></div>`;
    const tog = (path, title, sub) => `<div class="tile toggle-tile ${get(path) ? 'on' : ''}" data-bt="${path}"><div><strong>${title}</strong><span>${sub || ''}</span></div><div class="switch"></div></div>`;
    const grid = (cols, inner) => `<div style="display:grid;grid-template-columns:repeat(${cols},1fr);gap:12px;max-width:1150px;margin-bottom:10px">${inner}</div>`;
    const tiles = (inner) => `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">${inner}</div>`;
    const sec = (title, inner, hint) => `<div class="section"><h2>${title}</h2>${hint ? `<p class="hint">${hint}</p>` : ''}${inner}</div>`;
    const img = (name, size = 48) => `<img src="${esc((D.bankheist.imagePath || '').replace('%s', name))}" style="width:${size}px;height:${size}px;object-fit:contain" onerror="this.style.opacity=.2">`;
    const xyz = (p) => (p ? `${Number(p.x).toFixed(2)}, ${Number(p.y).toFixed(2)}, ${Number(p.z).toFixed(2)}${p.h !== undefined ? ` · ${Math.round(p.h)}°` : ''}` : '—');
    const anim = (path, label) => `<tr><td><strong>${label}</strong></td><td><input class="input" data-bf="${path}.dict" value="${esc(get(path + '.dict') || '')}"></td>
        <td><input class="input" data-bf="${path}.name" value="${esc(get(path + '.name') || '')}"></td><td style="width:110px"><input class="input" type="number" data-bf="${path}.flag" value="${esc(get(path + '.flag') ?? 0)}"></td></tr>`;
    const picker = (key, list, cur, mk) => `<div class="btn-row" style="margin-bottom:10px;flex-wrap:wrap">${list.map((x, i) => `<button class="btn ${i === cur ? 'primary' : ''}" data-bsel="${key}" data-i="${i}">${x.enabled === false ? '⏸ ' : ''}${esc(x.name || x.id)}</button>`).join('')}
        <button class="btn" data-ba="add" data-k="${key}">+ Nouveau</button>${mk || ''}</div>`;
    const placeBtn = (t, w, label, primary) => `<button class="btn ${primary ? 'primary' : ''}" data-ba="place" data-t="${t}" data-w="${w}">📍 ${label}</button>`;

    function vGeneral() {
        return sec('A. Paramètres généraux', tiles(tog('general.enabled', get('general.enabled') ? 'Braquages de banque activés' : 'Braquages de banque coupés', 'Coupés : marchands, lancements et collectes refusés.')
                + tog('general.lateJoin', 'Rejoindre en cours de route', 'Un joueur arrivé après le lancement peut participer (dans la limite du maximum).'))
            + grid(4, num('general.maxSimultaneous', 'Braquages simultanés (max.)', 'min="1" max="20"') + num('general.globalCooldown', 'Délai entre deux braquages, toutes banques (min)', 'min="0"')
                + num('general.participantRadius', 'Rayon de prise des braqueurs au lancement (m)', 'min="2" max="100"') + num('general.interactDistance', 'Distance d\'interaction (m)', 'step="0.1"'))
            + grid(4, num('general.bankRadius', 'Rayon de la banque (m)', 'min="10" max="300"') + num('general.abandonMinutes', 'Abandon si personne dans la banque (min)', 'min="1"')
                + num('general.depositKey', 'Touche d\'encaissement (code, 38 = E)') + txt('general.depositKeyLabel', 'Nom de la touche')),
        `Interactions : <span class="keycap">ALT</span> (menu ALT de la police) sur le point de départ, l'employé, le coffre, les billets et le marchand ;
            <span class="keycap">E</span> pour encaisser à un point de dépôt et pour poser le sac au sol (sac de jewelry_heist). Délai global restant : <b>${D.bankheist.globalCooldown} min</b>.`);
    }

    function vBanks() {
        const list = get('banks') || [];
        if (G.bi >= list.length) G.bi = Math.max(0, list.length - 1);
        const b = list[G.bi];
        if (!b) return sec('B. Banques', picker('banks', list, G.bi) + '<p class="hint">Aucune banque.</p>');
        const p = `banks.${G.bi}`;
        const cash = (b.cash || []).map((c, i) => `<tr><td>Chariot ${i + 1}</td><td class="mono">${xyz(c)}</td><td style="text-align:right"><button class="btn" data-ba="goto" data-x="${c.x}" data-y="${c.y}" data-z="${c.z}">Aller</button><button class="btn danger" data-ba="delCash" data-i="${i}">✕</button></td></tr>`).join('');
        return sec('B. Banques', picker('banks', list, G.bi)
            + tiles(tog(`${p}.enabled`, b.enabled ? 'Banque braquable' : 'Banque désactivée', 'Désactivée : employé retiré, aucun braquage possible.') + tog(`${p}.blip.enabled`, 'Blip sur la carte', '') + tog(`${p}.door.enabled`, 'Porte du coffre animée', 'Objet de la carte tourné à l\'ouverture.'))
            + grid(4, txt(`${p}.id`, 'Identifiant (unique)') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle de l'employé</label><input class="input" list="bh-peds" data-bf="${p}.clerk.model" value="${esc(get(p + '.clerk.model') || '')}"></div>`
                + num(`${p}.threatTime`, 'Durée de la menace (s)', 'min="1" max="120"'))
            + `<table class="loot wide"><tr><th>Point</th><th>Position</th><th style="width:330px"></th></tr>
                <tr><td><strong>Départ « Braquer la banque »</strong></td><td class="mono">${xyz(b.start)}</td><td style="text-align:right">${placeBtn('bank', 'start', 'Placer ici', true)}<button class="btn" data-ba="goto" data-x="${b.start.x}" data-y="${b.start.y}" data-z="${b.start.z}">Aller</button></td></tr>
                <tr><td><strong>Employé (PNJ)</strong></td><td class="mono">${xyz(b.clerk)}</td><td style="text-align:right">${placeBtn('bank', 'clerk', 'Placer ici')}</td></tr>
                <tr><td><strong>Coffre (piratage / C4)</strong></td><td class="mono">${xyz(b.vault)}</td><td style="text-align:right">${placeBtn('bank', 'vault', 'Placer ici')}<button class="btn" data-ba="goto" data-x="${b.vault.x}" data-y="${b.vault.y}" data-z="${b.vault.z}">Aller</button></td></tr>
                <tr><td><strong>Porte du coffre</strong> <span class="muted">(recherche autour du point)</span></td><td class="mono">${xyz(b.door)}</td><td style="text-align:right">${placeBtn('bank', 'door', 'Placer ici (devant la porte)')}</td></tr>
                ${cash}<tr><td colspan="2" class="muted">Chariots de billets : placez-vous à l'emplacement voulu.</td><td style="text-align:right">${placeBtn('bank', 'cash', 'Ajouter un chariot ici')}</td></tr></table>
            ${grid(4, `<div class="field"><label>Modèle de la porte</label><input class="input" data-bf="${p}.door.model" value="${esc(get(p + '.door.model') || '')}"></div>` + num(`${p}.door.closedHeading`, 'Orientation fermée (°, -1 = carte)', 'min="-1" max="360" step="0.1"') + num(`${p}.door.openOffset`, 'Rotation à l\'ouverture (°)', 'min="-180" max="180"')
                + num(`${p}.blip.sprite`, 'Blip : icône') + num(`${p}.blip.color`, 'Blip : couleur'))}
            <div class="btn-row"><button class="btn" data-ba="dup" data-k="banks">Dupliquer</button><button class="btn danger" data-ba="del" data-k="banks">Supprimer</button></div>`,
        'Les positions de départ sont celles de la Fleeca de Legion Square (intérieur d\'origine) : avec un intérieur modifié, replacez chaque point avec « Placer ici ». Les modifications de cette page sont enregistrées avec le placement.');
    }

    function vCond() {
        const rows = (get('banks') || []).map((b, i) => { const p = `banks.${i}`;
            const n = (k, a = 'min="0"') => `<td><input class="input" type="number" data-bf="${p}.${k}" value="${esc(get(p + '.' + k) ?? '')}" ${a} style="width:90px"></td>`;
            const c = (k) => `<td style="text-align:center"><input type="checkbox" class="check" data-bc="${p}.${k}" ${get(p + '.' + k) ? 'checked' : ''}></td>`;
            return `<tr><td><strong>${esc(b.name)}</strong></td>${n('minCops')}${n('minRobbers', 'min="1"')}${n('maxRobbers', 'min="1"')}${n('cooldown')}${n('hours.from', 'min="0" max="23"')}${n('hours.to', 'min="0" max="23"')}${c('required.laptop')}${c('required.bag')}${c('required.c4')}
                ${n('loot.min')}${n('loot.max')}</tr>`; }).join('');
        return sec('C. Conditions par banque', `<table class="loot wide"><tr><th>Banque</th><th>Policiers min.</th><th>Braqueurs min.</th><th>Braqueurs max.</th><th>Délai (min)</th><th>De (h)</th><th>À (h)</th>
                <th>💻</th><th>🎒</th><th>🧨</th><th>Butin min. ($)</th><th>Butin max. ($)</th></tr>${rows}</table>`,
            'Heures : 0 → 0 = toute la journée ; 18 → 4 = de 18 h à 4 h. 💻 🎒 🧨 = matériel exigé au lancement (au moins un braqueur présent doit l\'avoir). Le butin est tiré une seule fois, à l\'ouverture du coffre.')
            + sec('Règles communes', tiles(tog('hack.requireThreat', 'Menacer l\'employé avant le piratage', 'Sinon, le piratage est possible dès le lancement.')));
    }

    function vMerchants() {
        const list = get('merchants') || [];
        if (G.mi >= list.length) G.mi = Math.max(0, list.length - 1);
        const m = list[G.mi];
        if (!m) return sec('D. Marchands', picker('merchants', list, G.mi) + '<p class="hint">Aucun marchand.</p>');
        const p = `merchants.${G.mi}`;
        return sec('D. Marchands de matériel', picker('merchants', list, G.mi)
            + tiles(tog(`${p}.enabled`, m.enabled ? 'Marchand actif' : 'Marchand désactivé', '') + tog(`${p}.forbidPolice`, 'Refuse les policiers en service', '') + tog(`${p}.blip.enabled`, 'Blip sur la carte', 'Souvent caché.'))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle du PNJ</label><input class="input" list="bh-peds" data-bf="${p}.ped.model" value="${esc(get(p + '.ped.model') || '')}"></div>`
                + txt(`${p}.scenario`, 'Scénario / animation (ex. WORLD_HUMAN_SMOKING)'))
            + grid(4, num(`${p}.ped.x`, 'X', 'step="0.01"') + num(`${p}.ped.y`, 'Y', 'step="0.01"') + num(`${p}.ped.z`, 'Z', 'step="0.01"') + num(`${p}.ped.h`, 'Orientation (°)', 'min="0" max="360"'))
            + grid(4, num(`${p}.interactDistance`, 'Distance d\'interaction (m)', 'step="0.1"') + sel(`${p}.payment`, 'Paiement', PAY)
                + `<div class="field"><label>Métiers autorisés (vide = tous)</label><input class="input" data-bjobs="${p}.jobs" value="${esc((get(p + '.jobs') || []).join(', '))}"></div>`)
            + `<div class="hint">Vend : ${['laptop', 'bag', 'c4'].map((k) => `<label style="margin-right:12px"><input type="checkbox" class="check" data-bc="${p}.sells.${k}" ${get(`${p}.sells.${k}`) ? 'checked' : ''}> ${esc(get(`items.${k}.label`))}</label>`).join('')}</div>
              <div class="btn-row" style="margin-top:10px">${placeBtn('merchant', 'ped', 'Placer le PNJ ici', true)}<button class="btn" data-ba="goto" data-x="${m.ped.x}" data-y="${m.ped.y}" data-z="${m.ped.z}">Aller</button>
                <button class="btn" data-ba="dup" data-k="merchants">Dupliquer</button><button class="btn danger" data-ba="del" data-k="merchants">Supprimer</button></div>`);
    }

    function vItems() {
        const it = D.bankheist.items || {};
        const row = (k, extra) => `<tr><td>${img(get(`items.${k}.name`))}</td><td><strong>${esc(get(`items.${k}.label`))}</strong><br><span class="muted mono">${esc(get(`items.${k}.name`))}</span> ${it[k] ? '✅' : '⚠️ absent de l\'inventaire'}</td>
            <td><input class="input" data-bf="items.${k}.label" value="${esc(get(`items.${k}.label`))}"></td>
            <td><input class="input" type="number" min="0" data-bf="items.${k}.price" value="${esc(get(`items.${k}.price`))}"></td>
            <td><input class="input" type="number" min="0" data-bf="items.${k}.maxOwned" value="${esc(get(`items.${k}.maxOwned`))}"></td><td>${extra || ''}</td></tr>`;
        return sec('E. Objets et prix', `<table class="loot wide"><tr><th style="width:60px"></th><th>Objet</th><th>Nom affiché</th><th>Prix ($)</th><th>Possession max. (0 = illimité)</th><th></th></tr>
            ${row('laptop')}${row('bag')}${row('c4', `<label><input type="checkbox" class="check" data-bc="items.c4.sell" ${get('items.c4.sell') ? 'checked' : ''}> Vendu par les marchands</label>`)}</table>`,
        'Images : elyzea_inventory/html/img/bank_laptop.png, bank_bag.png, bank_c4.png. Le nom de l\'ordinateur affiche ses tentatives restantes, ex. « Ordinateur de piratage (2/3) ».');
    }

    function vHack() {
        const games = (D.bankheist.gameList || []).map((g) => { const p = `hack.games.${g}`; return `<tr><td><strong>${esc(D.bankheist.gameLabels[g])}</strong></td>
            <td style="text-align:center"><input type="checkbox" class="check" data-bc="${p}.enabled" ${get(p + '.enabled') ? 'checked' : ''}></td>
            <td><input class="input" type="number" min="0" max="100" data-bf="${p}.weight" value="${esc(get(p + '.weight'))}"></td>
            <td><input class="input" type="number" min="8" max="300" data-bf="${p}.time" value="${esc(get(p + '.time'))}"></td>
            <td><select class="input" data-bf="${p}.difficulty">${[1, 2, 3].map((n) => `<option value="${n}" ${Number(get(p + '.difficulty')) === n ? 'selected' : ''}>${['Facile', 'Normal', 'Difficile'][n - 1]}</option>`).join('')}</select></td></tr>`; }).join('');
        return sec('F. Piratage', grid(4, num('hack.attempts', 'Tentatives par ordinateur', 'min="1" max="10"') + num('hack.retryDelay', 'Délai entre deux tentatives (s)', 'min="0"')
                + txt('hack.prop', 'Objet tenu (ordinateur)'))
            + `<table class="loot wide"><tr><th>Animation</th><th>Dictionnaire</th><th>Nom</th><th>Option</th></tr>${anim('hack.anim', 'Utilisation de l\'ordinateur')}</table>`
            + `<h3 style="margin:12px 0 8px">Mini-jeux (tirés au sort à chaque tentative, selon le poids)</h3>
               <table class="loot wide"><tr><th>Mini-jeu</th><th>Activé</th><th>Poids</th><th>Durée (s)</th><th>Difficulté</th></tr>${games}</table>`,
        'Chaque tentative est consommée au lancement du mini-jeu : quitter, se déconnecter ou laisser filer le temps compte comme un échec. Les tentatives suivent le numéro de série de l\'ordinateur (base bh_laptops). Après la dernière, le coffre ne s\'ouvre plus qu\'à la C4.');
    }

    function vLoot() {
        const ex = (get('loot.extras') || []).map((e, i) => { const p = `loot.extras.${i}`; return `<tr><td><input type="checkbox" class="check" data-bc="${p}.enabled" ${e.enabled ? 'checked' : ''}></td>
            <td><input class="input" data-bf="${p}.item" value="${esc(e.item)}"></td><td><input class="input" type="number" min="0" max="100" data-bf="${p}.chance" value="${esc(e.chance)}"></td>
            <td><input class="input" type="number" min="1" data-bf="${p}.min" value="${esc(e.min)}"></td><td><input class="input" type="number" min="1" data-bf="${p}.max" value="${esc(e.max)}"></td>
            <td style="text-align:right"><button class="btn danger" data-ba="delExtra" data-i="${i}">✕</button></td></tr>`; }).join('');
        return sec('G. Coffre et butin', grid(4, sel('loot.rewardType', 'Encaissement versé en', PAY) + txt('loot.moneyItem', 'Objet « argent sale »') + num('loot.depositRate', 'Taux d\'encaissement (%)', 'min="1" max="200"')
                + num('loot.bagCapacity', 'Capacité d\'un sac ($)', 'min="1000"'))
            + grid(4, num('loot.perTick', 'Ramassé par seconde ($)', 'min="1"') + num('loot.openDuration', 'Coffre ouvert pendant (s)', 'min="30"')
                + num('c4.delay', 'C4 : délai avant explosion (s)', 'min="2"') + num('c4.plantTime', 'C4 : durée de pose (s)', 'min="1"'))
            + grid(4, tog('loot.bonus.enabled', 'Bonus possible', '') + num('loot.bonus.chance', 'Bonus : chance (%)') + num('loot.bonus.min', 'Bonus : min (%)') + num('loot.bonus.max', 'Bonus : max (%)'))
            + grid(4, tog('loot.malus.enabled', 'Malus possible', '') + num('loot.malus.chance', 'Malus : chance (%)') + num('loot.malus.min', 'Malus : min (%)') + num('loot.malus.max', 'Malus : max (%)'))
            + `<h3 style="margin:12px 0 8px">Récompenses complémentaires (« Prendre les objets du coffre »)</h3>
               <table class="loot wide"><tr><th>Actif</th><th>Objet</th><th>Chance (%)</th><th>Min</th><th>Max</th><th></th></tr>${ex || '<tr><td colspan="6" class="muted">Aucune.</td></tr>'}</table>
               <div class="btn-row" style="margin-top:8px"><button class="btn" data-ba="addExtra">+ Ajouter un objet</button></div>`,
        'Butin d\'une banque = tirage entre son minimum et son maximum (onglet C), puis bonus ou malus éventuel. Les billets sont partagés entre les braqueurs : le total ramassé ne dépasse jamais le butin.');
    }

    function vDeposits() {
        const list = get('deposits') || [];
        if (G.di >= list.length) G.di = Math.max(0, list.length - 1);
        const d = list[G.di];
        if (!d) return sec('H. Points de dépôt', picker('deposits', list, G.di) + '<p class="hint">Aucun point de dépôt : les sacs ne peuvent pas être encaissés.</p>');
        const p = `deposits.${G.di}`;
        return sec('H. Points de dépôt (encaissement)', picker('deposits', list, G.di)
            + tiles(tog(`${p}.enabled`, d.enabled ? 'Point actif' : 'Point désactivé', '') + tog(`${p}.allowPassenger`, 'Encaissement possible en passager', 'Jamais en conducteur.'))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom') + num(`${p}.radius`, 'Rayon (m)', 'step="0.5" min="0.5" max="20"'))
            + grid(3, num(`${p}.x`, 'X', 'step="0.01"') + num(`${p}.y`, 'Y', 'step="0.01"') + num(`${p}.z`, 'Z', 'step="0.01"'))
            + `<div class="btn-row">${placeBtn('deposit', 'point', 'Placer ici', true)}<button class="btn" data-ba="goto" data-x="${d.x}" data-y="${d.y}" data-z="${d.z}">Aller</button>
                <button class="btn danger" data-ba="del" data-k="deposits">Supprimer</button></div>`,
        'Le porteur d\'un sac de billets appuie sur E dans le rayon : le sac est retiré et son contenu versé selon l\'onglet G. Ailleurs, E pose le sac au sol (un autre joueur peut le ramasser avec ALT, contenu inchangé).');
    }

    function vVisuals() {
        return sec('I. Visuels et animations', grid(4, txt('visuals.trolleyFull', 'Chariot plein') + txt('visuals.trolleyEmpty', 'Chariot vide') + txt('c4.prop', 'Objet C4') + num('c4.explosionType', 'Type d\'explosion (2 = charge collante)', 'min="0" max="82"'))
            + `<table class="loot wide"><tr><th>Animation</th><th>Dictionnaire</th><th>Nom</th><th>Option</th></tr>${anim('visuals.collectAnim', 'Ramassage des billets')}${anim('visuals.threatPanic', 'Employé : mains levées')}
                ${anim('visuals.threatKneel', 'Employé : à genoux')}${anim('visuals.depositAnim', 'Dépôt du sac')}${anim('c4.anim', 'Pose de la C4')}</table>`,
        'Le sac porté (modèle, position et rotation sur le dos) se règle dans l\'onglet Braquage bijouterie › G. Sac : c\'est le même système de sac.');
    }

    function vLive() {
        const rows = (get('banks') || []).map((b) => {
            const x = (D.bankheist.banks || {})[b.id] || {}; const s = x.session;
            return `<tr><td><strong>${esc(b.name)}</strong><br><span class="muted mono">${esc(b.id)}</span></td><td>${PHASE[x.phase] || x.phase || '—'}${x.cooldown ? `<br><span class="muted">délai : ${x.cooldown} min</span>` : ''}</td>
                <td>${s ? `${esc(s.robbers.join(', ') || '—')}${s.hacker ? `<br><span class="muted">pirate : ${esc(s.hacker)}</span>` : ''}${s.threatened ? '<br><span class="muted">employé menacé</span>' : ''}` : '—'}</td>
                <td>${s ? `${money(s.initial)} tiré · ${money(s.distributed)} ramassé · ${money(s.pool)} restant${s.openLeft != null ? `<br><span class="muted">ouvert encore ${s.openLeft} s</span>` : ''}` : '—'}</td>
                <td style="text-align:right">${s ? `<button class="btn danger" data-ba="cancel" data-bank="${esc(b.id)}">Annuler</button>` : `<button class="btn" data-ba="resetBank" data-bank="${esc(b.id)}" ${x.cooldown ? '' : 'disabled'}>Rendre disponible</button>`}</td></tr>`;
        }).join('');
        return sec('J. Sessions en direct', `<table class="loot wide"><tr><th>Banque</th><th>État</th><th>Braqueurs</th><th>Butin</th><th style="width:170px"></th></tr>${rows}</table>
            <div class="btn-row" style="margin-top:10px"><button class="btn" data-ba="resetGlobal" ${D.bankheist.globalCooldown ? '' : 'disabled'}>Remettre le délai global à zéro (${D.bankheist.globalCooldown} min)</button></div>`,
        `Policiers en service : <b>${D.bankheist.police}</b>. Annuler ne redistribue rien et ne retire pas les sacs déjà remplis. Après un redémarrage, un braquage en cours est terminé et la banque reste en délai.`);
    }

    function vLogs() {
        const KINDS = { '': 'Tout', heist: 'Braquages', hack: 'Piratage', loot: 'Collecte', deposit: 'Encaissements', shop: 'Achats', admin: 'Staff', anomaly: 'Anomalies' };
        const j = D.bankheist;
        const line = (ok, label, detail) => `<tr><td>${ok ? '✅' : '⚠️'}</td><td><strong>${label}</strong></td><td class="muted">${detail}</td></tr>`;
        const logs = (j.logs || []).filter((l) => !G.logKind || l.kind === G.logKind).map((l) => `<tr><td class="muted" style="white-space:nowrap">${new Date(l.t * 1000).toLocaleString('fr-FR')}</td>
            <td>${esc(KINDS[l.kind] || l.kind)}</td><td>${esc(l.name || '—')}</td><td class="mono">${esc(l.ref || '')}</td><td>${esc(l.details || '')}</td></tr>`).join('');
        return sec('K. Compatibilité', `<table class="loot wide">
                ${line(j.inventoryRes, 'Inventaire', 'elyzea_inventory (objets, numéro de série de l\'ordinateur)')}
                ${line(j.bagRes, 'Sac', j.bagRes ? 'jewelry_heist (sac porté, posé, ramassé)' : 'jewelry_heist arrêté : collecte impossible')}
                ${line(j.policeRes, 'Police et menu ALT', j.policeRes ? 'elyzea_police (alerte, effectifs, menu ALT)' : 'elyzea_police arrêté : alerte interne et menu ALT autonome')}
                ${line(true, 'Argent', 'elyzea_core (liquide, banque) ou objet d\'inventaire')}</table>`)
            + sec('Journal', `<div class="btn-row" style="margin-bottom:8px;flex-wrap:wrap">${Object.entries(KINDS).map(([k, v]) => `<button class="btn ${G.logKind === k ? 'primary' : ''}" data-blog="${k}">${v}</button>`).join('')}</div>
                <table class="loot wide"><tr><th>Date</th><th>Type</th><th>Joueur</th><th>Réf.</th><th>Détail</th></tr>${logs || '<tr><td colspan="5" class="muted">Vide.</td></tr>'}</table>`);
    }

    VIEWS.bankheist = () => {
        const j = D.bankheist;
        if (!j.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(j.resource || 'bank_heist')}</b> ne répond pas${j.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (!G.draft) G.draft = normalize(copy(j.settings));
        const live = Object.values(j.banks || {}).filter((x) => x.session).length;
        const body = { general: vGeneral, banks: vBanks, cond: vCond, merchants: vMerchants, items: vItems, hack: vHack, loot: vLoot, deposits: vDeposits, visuals: vVisuals, live: vLive, logs: vLogs }[G.sub]();
        const bar = `<div class="section"><div class="btn-row"><button class="btn primary" data-ba="save">💾 Enregistrer</button><button class="btn" data-ba="cancelDraft">Annuler les modifications</button>
            <button class="btn" data-ba="reset">Valeurs par défaut</button><span class="muted" style="align-self:center">Appliqué après « Enregistrer », sans redémarrage.</span></div></div>`;
        return `<div class="stats"><div class="stat"><b>${j.settings.general.enabled ? 'Activés' : 'Coupés'}</b><span>Braquages de banque</span></div>
                <div class="stat"><b>${live}</b><span>Braquage(s) en cours</span></div><div class="stat"><b>${(j.settings.banks || []).length}</b><span>Banque(s)</span></div>
                <div class="stat"><b>${j.police}</b><span>Policier(s) en service</span></div></div>
            <div class="btn-row" style="flex-wrap:wrap;margin-bottom:12px">${SUBS.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-bsub="${k}">${l}</button>`).join('')}</div>
            <datalist id="bh-peds">${(j.pedModels || []).map((m) => `<option value="${esc(m)}">`).join('')}</datalist>${bar}${body}${bar}`;
    };

    const on = () => isOpen && tab === 'bankheist' && G.draft;
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.bf && t.tagName !== 'SELECT') setPath(t.dataset.bf, t.type === 'number' ? (t.value === '' ? null : Number(t.value)) : t.value);
        if (t.dataset.bjobs) setPath(t.dataset.bjobs, t.value.split(',').map((x) => x.trim()).filter(Boolean));
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.bf && t.tagName === 'SELECT') { setPath(t.dataset.bf, /^\d+$/.test(t.value) && t.dataset.bf.endsWith('difficulty') ? Number(t.value) : t.value); render(); }
        if (t.dataset.bc) setPath(t.dataset.bc, t.checked);
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'bankheist') return;
        let n;
        if ((n = ev.target.closest('[data-bsub]'))) { G.sub = n.dataset.bsub; return render(); }
        if ((n = ev.target.closest('[data-blog]'))) { G.logKind = n.dataset.blog; return render(); }
        if (!G.draft) return;
        if ((n = ev.target.closest('[data-bt]'))) { setPath(n.dataset.bt, !get(n.dataset.bt)); return render(); }
        if ((n = ev.target.closest('[data-bsel]'))) { G[{ banks: 'bi', merchants: 'mi', deposits: 'di' }[n.dataset.bsel]] = Number(n.dataset.i); return render(); }
        if (!(n = ev.target.closest('[data-ba]')) || n.disabled) return;
        const idx = { banks: () => G.bi, merchants: () => G.mi, deposits: () => G.di };
        const setIdx = (k, v) => { G[{ banks: 'bi', merchants: 'mi', deposits: 'di' }[k]] = v; };
        switch (n.dataset.ba) {
            case 'save': send('save', G.draft); G.draft = null; return;
            case 'cancelDraft': G.draft = null; return render();
            case 'reset': if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages du braquage de banque reviennent à ceux du fichier config.lua (banques, marchands et dépôts compris).')) { G.draft = null; send('reset'); } return;
            case 'add': {
                const k = n.dataset.k; const l = get(k) || []; const base = copy((D.bankheist.defaults[k] || [])[0] || {});
                base.id = `${k.slice(0, -1)}_${l.length + 1}`; base.name = `${{ banks: 'Banque', merchants: 'Marchand', deposits: 'Dépôt' }[k]} ${l.length + 1}`;
                if (k === 'banks') base.cash = [];
                l.push(base); setPath(k, l); setIdx(k, l.length - 1); return render();
            }
            case 'dup': { const k = n.dataset.k; const l = get(k); const e = l[idx[k]()]; if (!e) return; const c = copy(e); c.id = `${e.id}_copie`; c.name = `${e.name} (copie)`; l.push(c); setIdx(k, l.length - 1); return render(); }
            case 'del': {
                const k = n.dataset.k; const l = get(k); const e = l[idx[k]()]; if (!e) return;
                if (!(await confirmBox(`Supprimer « ${e.name} » ?`, 'Effectif après « Enregistrer ».'))) return;
                l.splice(idx[k](), 1); return render();
            }
            case 'delCash': G.draft.banks[G.bi].cash.splice(Number(n.dataset.i), 1); return render();
            case 'addExtra': G.draft.loot.extras.push({ item: 'goldbar', chance: 25, min: 1, max: 2, enabled: true }); return render();
            case 'delExtra': G.draft.loot.extras.splice(Number(n.dataset.i), 1); return render();
            case 'place': {
                const t = n.dataset.t; const index = (t === 'bank' ? G.bi : t === 'merchant' ? G.mi : G.di) + 1;
                send('place', { draft: G.draft, target: t, what: n.dataset.w, index }); G.draft = null; return;
            }
            case 'goto': send('teleport', { x: Number(n.dataset.x), y: Number(n.dataset.y), z: Number(n.dataset.z) }); return;
            case 'cancel': if (await confirmBox('Annuler ce braquage ?', 'La session est terminée (banque laissée en délai). Rien n\'est redistribué.')) send('cancel', { bank: n.dataset.bank }); return;
            case 'resetBank': send('resetBank', { bank: n.dataset.bank }); return;
            case 'resetGlobal': send('resetGlobal'); return;
        }
    });
})();
