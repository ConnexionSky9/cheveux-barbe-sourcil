/* =========================================================
   BRAQUAGE DE BANQUE (ressource bank_heist, permission « bankheist_manage »)
   A. Général et guichet · B. Banques (banquier, porte, alarme) · C. Points de butin · D. Conditions
   E. Porte et outils (décryptage, C4, perceuse) · F. Alarme · G. Marchands · H. Indics · I. Objets et prix
   J. Butin et encaissement · K. Dépôts · L. Visuels · M. Sessions en direct · N. Journal
   Les modifications se font dans un brouillon puis « Enregistrer » ; le serveur revalide tout.
   ========================================================= */
(() => {
    TABS.push({
        id: 'bankheist', group: 6, label: 'Braquage de banque', ico: '🏦',
        sub: 'Banques, banquier, butin, porte, alarme, marchands, indics, guichet, sessions en direct.',
        show: () => has('bankheist_manage') && !!(D && D.bankheist),
    });

    const G = { draft: null, sub: 'general', bi: 0, mi: 0, ni: 0, di: 0, logKind: '', lootType: 'trolley_cash' };
    const send = (name, data = {}) => action('bankheist', { name, data });
    const SUBS = [['general', 'A. Général et guichet'], ['banks', 'B. Banques'], ['points', 'C. Points de butin'], ['cond', 'D. Conditions'], ['door', 'E. Porte et outils'],
        ['alarm', 'F. Alarme'], ['merchants', 'G. Marchands'], ['informants', 'H. Indics'], ['items', 'I. Objets et prix'], ['loot', 'J. Butin et encaissement'],
        ['deposits', 'K. Dépôts'], ['visuals', 'L. Visuels'], ['live', 'M. Sessions en direct'], ['logs', 'N. Journal']];
    const PAY = { cash: 'Liquide', bank: 'Compte bancaire', item: 'Argent sale (objet)' };
    const PHASE = { available: '🟢 Disponible', cooldown: '⏳ Délai', active: '🔴 Braquage en cours' };
    const DOORS = { locked: '🔒 Porte verrouillée', hacking: '💻 Décryptage en cours', c4: '💥 C4 posée', open: '💰 Coffre ouvert' };
    const TOOLS = { any: 'Ordinateur OU C4', laptop: 'Ordinateur obligatoire', c4: 'C4 obligatoire', none: 'Aucun outil' };
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
        s.banks = arr(s.banks); s.merchants = arr(s.merchants); s.informants = arr(s.informants); s.deposits = arr(s.deposits);
        s.banks.forEach((b) => { b.loot = arr(b.loot); b.required = obj(b.required); b.hours = obj(b.hours); b.door = obj(b.door); b.blip = obj(b.blip);
            b.banker = obj(b.banker); b.doorPoint = obj(b.doorPoint); b.alarm = obj(b.alarm); });
        s.merchants.forEach((m) => { m.jobs = arr(m.jobs); m.sells = obj(m.sells); m.blip = obj(m.blip); m.ped = obj(m.ped); });
        s.informants.forEach((n) => { n.ped = obj(n.ped); n.hours = obj(n.hours); });
        s.police = obj(s.police); s.police.jobs = arr(s.police.jobs);
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
    const placeBtn = (t, w, label, primary, li) => `<button class="btn ${primary ? 'primary' : ''}" data-ba="place" data-t="${t}" data-w="${w}" ${li ? `data-li="${li}"` : ''}>📍 ${label}</button>`;
    const goBtn = (p) => (p && p.x != null ? `<button class="btn" data-ba="goto" data-x="${p.x}" data-y="${p.y}" data-z="${p.z}">Aller</button>` : '');
    const lt = () => D.bankheist.lootTypes || {};
    const ltList = () => D.bankheist.lootTypeList || Object.keys(lt());

    function vGeneral() {
        return sec('A. Paramètres généraux', tiles(tog('general.enabled', get('general.enabled') ? 'Braquages de banque activés' : 'Braquages de banque coupés', 'Coupés : indics, marchands, lancements et collectes refusés.')
                + tog('general.lateJoin', 'Rejoindre en cours de route', 'Un joueur arrivé après le lancement peut participer (dans la limite du maximum).'))
            + grid(4, num('general.maxSimultaneous', 'Braquages simultanés (max.)', 'min="1" max="20"') + num('general.globalCooldown', 'Délai entre deux braquages, toutes banques (min)', 'min="0"')
                + num('general.participantRadius', 'Rayon de prise des braqueurs au lancement (m)', 'min="2" max="100"') + num('general.interactDistance', 'Distance d\'interaction (m)', 'step="0.1"'))
            + grid(4, num('general.bankRadius', 'Rayon de la banque (m)', 'min="10" max="300"') + num('general.abandonMinutes', 'Abandon si personne dans la banque (min)', 'min="1"')
                + num('general.depositKey', 'Touche d\'encaissement (code, 38 = E)') + txt('general.depositKeyLabel', 'Nom de la touche')),
        `<span class="keycap">ALT</span> sur le banquier : « Accéder à mon compte » ; arme en main : « BRAQUER LA BANQUE ». ALT aussi sur la porte du coffre, le butin, le boîtier d'alarme, les marchands et les indics.
            Délai global restant : <b>${D.bankheist.globalCooldown} min</b>.`)
        + sec('Guichet du banquier (hors braquage)', tiles(tog('banking.enabled', get('banking.enabled') ? 'Guichet ouvert' : 'Guichet fermé', 'Dépôt, retrait, virement, historique (ALT sur le banquier).'))
            + grid(4, num('banking.minAmount', 'Montant minimum ($)', 'min="1"') + num('banking.maxTransfer', 'Virement maximum ($)', 'min="1"') + num('banking.transferFee', 'Frais de virement (%)', 'min="0" max="50"')),
        'Le guichet ferme pendant un braquage de la banque. Virements vers un numéro de téléphone (comptes d\'elyzea_aura), destinataire en ligne ou non. Historique commun avec la banque du téléphone.');
    }

    function vBanks() {
        const list = get('banks') || [];
        if (G.bi >= list.length) G.bi = Math.max(0, list.length - 1);
        const b = list[G.bi];
        if (!b) return sec('B. Banques', picker('banks', list, G.bi) + '<p class="hint">Aucune banque.</p>');
        const p = `banks.${G.bi}`;
        return sec('B. Banques', picker('banks', list, G.bi)
            + tiles(tog(`${p}.enabled`, b.enabled ? 'Banque active' : 'Banque désactivée', 'Désactivée : banquier retiré, ni guichet ni braquage.') + tog(`${p}.blip.enabled`, 'Blip sur la carte', '') + tog(`${p}.door.enabled`, 'Porte du coffre animée', 'Objet de la carte tourné à l\'ouverture (lente au décryptage, soufflée à la C4).'))
            + grid(4, txt(`${p}.id`, 'Identifiant (unique)') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle du banquier</label><input class="input" list="bh-peds" data-bf="${p}.banker.model" value="${esc(get(p + '.banker.model') || '')}"></div>`
                + num(`${p}.threatTime`, 'Mains en l\'air avant de se mettre à genoux (s)', 'min="1" max="120"'))
            + `<table class="loot wide"><tr><th>Point</th><th>Position</th><th style="width:330px"></th></tr>
                <tr><td><strong>🏦 Banquier (PNJ banque)</strong><br><span class="muted">Guichet + « BRAQUER LA BANQUE »</span></td><td class="mono">${xyz(b.banker)}</td><td style="text-align:right">${placeBtn('bank', 'banker', 'Placer ici', true)}${goBtn(b.banker)}</td></tr>
                <tr><td><strong>🚪 Devant la porte du coffre</strong><br><span class="muted">Décryptage / pose de la C4</span></td><td class="mono">${xyz(b.doorPoint)}</td><td style="text-align:right">${placeBtn('bank', 'doorPoint', 'Placer ici')}${goBtn(b.doorPoint)}</td></tr>
                <tr><td><strong>🚨 Boîtier d'alarme</strong></td><td class="mono">${xyz(b.alarm)}</td><td style="text-align:right">${placeBtn('bank', 'alarm', 'Placer ici')}${goBtn(b.alarm)}</td></tr>
                <tr><td><strong>Porte du coffre (objet)</strong> <span class="muted">(recherche autour du point)</span></td><td class="mono">${xyz(b.door)}</td><td style="text-align:right">${placeBtn('bank', 'door', 'Placer ici (contre la porte)')}</td></tr></table>
            ${grid(4, `<div class="field"><label>Modèle de la porte</label><input class="input" data-bf="${p}.door.model" value="${esc(get(p + '.door.model') || '')}"></div>` + num(`${p}.door.closedHeading`, 'Orientation fermée (°, -1 = carte)', 'min="-1" max="360" step="0.1"') + num(`${p}.door.openOffset`, 'Rotation à l\'ouverture (°)', 'min="-180" max="180"')
                + num(`${p}.blip.sprite`, 'Blip : icône'))}
            <div class="btn-row"><button class="btn" data-ba="dup" data-k="banks">Dupliquer</button><button class="btn danger" data-ba="del" data-k="banks">Supprimer</button></div>`,
        'Positions de départ : Fleeca de Legion Square (intérieur d\'origine). Avec un intérieur modifié, replacez chaque point avec « Placer ici ». Les points de butin se règlent dans l\'onglet C.');
    }

    function vPoints() {
        const list = get('banks') || [];
        if (G.bi >= list.length) G.bi = Math.max(0, list.length - 1);
        const b = list[G.bi];
        if (!b) return sec('C. Points de butin', picker('banks', list, G.bi) + '<p class="hint">Aucune banque.</p>');
        const p = `banks.${G.bi}`; const T = lt();
        const opts = ltList().map((k) => `<option value="${esc(k)}">${esc((T[k] || {}).label || k)}</option>`).join('');
        const rows = (b.loot || []).map((l, i) => { const q = `${p}.loot.${i}`; const t = T[l.type] || {};
            return `<div class="section" style="margin:0 0 10px;padding:12px 14px;max-width:1150px">
                <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px"><strong>Point #${i + 1}</strong><span class="muted">${t.tool === 'drill' ? '🛠️ perceuse exigée' : (t.anim === 'trolley' ? 'animation : vider le chariot' : 'animation : ramasser sur la table')}</span>
                    <span class="muted mono" style="margin-left:auto">${xyz(l)}</span>${placeBtn('bank', 'loot', 'Déplacer ici', false, i + 1)}${goBtn(l)}<button class="btn danger" data-ba="delLoot" data-i="${i}">✕</button></div>
                ${grid(4, `<div class="field"><label>Type (objet)</label><select class="input" data-bf="${q}.type">${ltList().map((k) => `<option value="${esc(k)}" ${l.type === k ? 'selected' : ''}>${esc((T[k] || {}).label || k)}</option>`).join('')}</select></div>`
                    + `<div class="field"><label>Modèle (vide = celui du type)</label><input class="input" data-bf="${q}.model" value="${esc(l.model || '')}" placeholder="${esc(t.model || '(objets de la carte)')}"></div>`
                    + num(`${q}.min`, 'Butin min. ($)', 'min="0"') + num(`${q}.max`, 'Butin max. ($)', 'min="0"'))}
                ${grid(4, `<div class="field"><label>Objet à la place des billets (vide = billets)</label><input class="input" data-bf="${q}.item" value="${esc(l.item || '')}" placeholder="ex. goldbar"></div>`
                    + num(`${q}.itemMin`, 'Quantité min.', 'min="1"') + num(`${q}.itemMax`, 'Quantité max.', 'min="1"'))}</div>`; }).join('');
        return sec('C. Points de butin', picker('banks', list, G.bi)
            + (rows || '<p class="hint">Aucun point : le coffre est vide.</p>')
            + `<div class="btn-row" style="margin-top:10px;align-items:center"><select class="input" id="bh-lt" style="max-width:300px">${opts}</select>
                ${placeBtn('bank', 'loot', 'Ajouter ce type de butin à ma position', true)}</div>`,
        'Placez-vous à l\'endroit exact (devant l\'objet, face à lui) puis « Ajouter ». Chaque point a son propre montant (tiré entre min et max à l\'ouverture du coffre, bonus/malus compris) ou un objet à la place des billets (ex. goldbar, diamond). Chariots : ramassage animé, le chariot plein devient vide. Liasses / lingots : sur une table. Coffres individuels : perceuse obligatoire (mini-jeu), objets de la carte. Modèle personnalisé : n\'importe quel objet du jeu.');
    }

    function vCond() {
        const rows = (get('banks') || []).map((b, i) => { const p = `banks.${i}`;
            const n = (k, a = 'min="0"') => `<td><input class="input" type="number" data-bf="${p}.${k}" value="${esc(get(p + '.' + k) ?? '')}" ${a} style="width:86px"></td>`;
            const c = (k) => `<td style="text-align:center"><input type="checkbox" class="check" data-bc="${p}.${k}" ${get(p + '.' + k) ? 'checked' : ''}></td>`;
            return `<tr><td><strong>${esc(b.name)}</strong></td>${n('minCops')}${n('minRobbers', 'min="1"')}${n('maxRobbers', 'min="1"')}${n('cooldown')}${n('hours.from', 'min="0" max="23"')}${n('hours.to', 'min="0" max="23"')}
                <td><select class="input" data-bf="${p}.required.tool">${Object.entries(TOOLS).map(([k, v]) => `<option value="${k}" ${get(p + '.required.tool') === k ? 'selected' : ''}>${v}</option>`).join('')}</select></td>${c('required.bag')}</tr>`; }).join('');
        return sec('D. Conditions par banque', `<table class="loot wide"><tr><th>Banque</th><th>Policiers min.</th><th>Braqueurs min.</th><th>Braqueurs max.</th><th>Délai (min)</th><th>De (h)</th><th>À (h)</th><th>Outil exigé au lancement</th><th>🎒 Sac exigé</th></tr>${rows}</table>`,
            'Heures : 0 → 0 = toute la journée ; 18 → 4 = de 18 h à 4 h. Le matériel exigé doit être sur au moins un braqueur présent. Il faut une arme en main pour braquer le banquier ; un policier en service ne peut pas lancer de braquage.');
    }

    function vDoor() {
        const games = arr(D.bankheist.gameList).map((g) => { const p = `hack.games.${g}`; return `<tr><td><strong>${esc(D.bankheist.gameLabels[g])}</strong></td>
            <td style="text-align:center"><input type="checkbox" class="check" data-bc="${p}.enabled" ${get(p + '.enabled') ? 'checked' : ''}></td>
            <td><input class="input" type="number" min="0" max="100" data-bf="${p}.weight" value="${esc(get(p + '.weight'))}"></td>
            <td><input class="input" type="number" min="8" max="300" data-bf="${p}.time" value="${esc(get(p + '.time'))}"></td>
            <td><select class="input" data-bf="${p}.difficulty">${[1, 2, 3].map((n) => `<option value="${n}" ${Number(get(p + '.difficulty')) === n ? 'selected' : ''}>${['Facile', 'Normal', 'Difficile'][n - 1]}</option>`).join('')}</select></td></tr>`; }).join('');
        return sec('E. Porte du coffre', tiles(tog('door.hack', '💻 Décryptage autorisé', 'Ordinateur + mini-jeu : la porte s\'ouvre lentement.') + tog('door.c4', '🧨 C4 autorisée', 'La porte saute (explosion, fumée, secousse).')
                + tog('door.c4OnlyAfterHack', 'C4 seulement après un décryptage raté', 'Ordinateur grillé obligatoire avant la C4.') + tog('hack.requireThreat', 'Banquier à terre avant le décryptage', 'Il faut d\'abord le braquer (ALT, arme en main).'))
            + grid(4, num('door.openTime', 'Durée d\'ouverture de la porte (s)', 'min="1" max="30"')))
            + sec('Décryptage (ordinateur)', grid(4, num('hack.attempts', 'Tentatives par ordinateur', 'min="1" max="10"') + num('hack.retryDelay', 'Délai entre deux tentatives (s)', 'min="0"'))
                + `<table class="loot wide"><tr><th>Mini-jeu</th><th>Activé</th><th>Poids</th><th>Durée (s)</th><th>Difficulté</th></tr>${games}</table>`,
                'Scène GTA : le braqueur sort l\'ordinateur et la carte du sac et les branche sur la porte. Une tentative est consommée au lancement ; quitter ou laisser filer le temps = échec.')
            + sec('Charge C4', grid(4, num('c4.delay', 'Délai avant explosion (s)', 'min="2"') + num('c4.plantTime', 'Durée de la pose (s)', 'min="1"') + txt('c4.prop', 'Objet C4') + num('c4.explosionType', 'Type d\'explosion (2 = collante)', 'min="0" max="82"'))
                + grid(4, num('c4.shake', 'Secousse caméra (0 à 2)', 'step="0.1" min="0" max="2"') + tog('c4.alertPolice', 'L\'explosion alerte la police', '')))
            + sec('Perceuse (coffres individuels)', grid(4, num('drill.time', 'Durée de perçage efficace (s)', 'min="5" max="180"') + num('drill.heatRate', 'Vitesse de chauffe (1 = normale)', 'step="0.1" min="0.2" max="5"') + txt('drill.prop', 'Objet perceuse')),
                'Mini-jeu : maintenir pour percer, relâcher avant la surchauffe (la mèche se bloque à 100 %). Le serveur vérifie la durée réelle.');
    }

    function vAlarm() {
        return sec('F. Alarme de la banque', tiles(tog('alarm.enabled', get('alarm.enabled') ? 'Alarme activée' : 'Alarme silencieuse', 'Sirène et lumières rouges dès le début du braquage.') + tog('alarm.lights', 'Lumières rouges clignotantes', '')
                + tog('alarm.robbersCanDisable', 'Les braqueurs peuvent la couper', 'Mini-jeu des fils au boîtier.') + tog('alarm.policeCanDisable', 'Les policiers la coupent directement', '')
                + tog('alarm.failRealert', 'Mauvais fil = nouvelle alerte police', ''))
            + grid(4, num('alarm.maxMinutes', 'Coupure automatique après (min)', 'min="1" max="60"') + num('alarm.volume', 'Volume maximal (0 à 1)', 'step="0.05" min="0" max="1"') + num('alarm.wiresTime', 'Durée du mini-jeu des fils (s)', 'min="5" max="120"')),
        'La police reçoit l\'alerte et la position dès le lancement du braquage (alarme activée ou non). Le volume baisse avec la distance au boîtier.');
    }

    function vMerchants() {
        const list = get('merchants') || [];
        if (G.mi >= list.length) G.mi = Math.max(0, list.length - 1);
        const m = list[G.mi];
        if (!m) return sec('G. Marchands', picker('merchants', list, G.mi) + '<p class="hint">Aucun marchand.</p>');
        const p = `merchants.${G.mi}`;
        return sec('G. Marchands de matériel', picker('merchants', list, G.mi)
            + tiles(tog(`${p}.enabled`, m.enabled ? 'Marchand actif' : 'Marchand désactivé', '') + tog(`${p}.forbidPolice`, 'Refuse les policiers en service', '') + tog(`${p}.blip.enabled`, 'Blip sur la carte', 'Souvent caché : les indics donnent sa position.'))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle du PNJ</label><input class="input" list="bh-peds" data-bf="${p}.ped.model" value="${esc(get(p + '.ped.model') || '')}"></div>`
                + txt(`${p}.scenario`, 'Scénario (ex. WORLD_HUMAN_SMOKING)'))
            + grid(4, num(`${p}.interactDistance`, 'Distance d\'interaction (m)', 'step="0.1"') + sel(`${p}.payment`, 'Paiement', PAY)
                + `<div class="field"><label>Métiers autorisés (vide = tous)</label><input class="input" data-bjobs="${p}.jobs" value="${esc((get(p + '.jobs') || []).join(', '))}"></div>`)
            + `<div class="hint">Position : <span class="mono">${xyz(m.ped)}</span> · Vend : ${['laptop', 'bag', 'c4', 'drill'].map((k) => `<label style="margin-right:12px"><input type="checkbox" class="check" data-bc="${p}.sells.${k}" ${get(`${p}.sells.${k}`) ? 'checked' : ''}> ${esc(get(`items.${k}.label`))}</label>`).join('')}</div>
              <div class="btn-row" style="margin-top:10px">${placeBtn('merchant', 'ped', 'Placer le PNJ ici', true)}${goBtn(m.ped)}
                <button class="btn" data-ba="dup" data-k="merchants">Dupliquer</button><button class="btn danger" data-ba="del" data-k="merchants">Supprimer</button></div>`);
    }

    function vInformants() {
        const list = get('informants') || [];
        if (G.ni >= list.length) G.ni = Math.max(0, list.length - 1);
        const n = list[G.ni];
        if (!n) return sec('H. Indics', picker('informants', list, G.ni) + '<p class="hint">Aucun indic.</p>');
        const p = `informants.${G.ni}`;
        const mopts = Object.assign({ '': 'Le plus proche (actif)' }, ...(get('merchants') || []).map((m) => ({ [m.id]: m.name })));
        return sec('H. Indics (où trouver le vendeur)', picker('informants', list, G.ni)
            + tiles(tog(`${p}.enabled`, n.enabled ? 'Indic actif' : 'Indic désactivé', '') + tog(`${p}.forbidPolice`, 'Se tait devant un policier en service', ''))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom affiché') + `<div class="field"><label>Modèle du PNJ</label><input class="input" list="bh-peds" data-bf="${p}.ped.model" value="${esc(get(p + '.ped.model') || '')}"></div>`
                + txt(`${p}.scenario`, 'Scénario (ex. WORLD_HUMAN_LEANING)'))
            + grid(4, num(`${p}.price`, 'Prix de l\'information ($)', 'min="0"') + sel(`${p}.payment`, 'Paiement', PAY) + sel(`${p}.merchant`, 'Marchand indiqué', mopts) + num(`${p}.blipMinutes`, 'Repère GPS pendant (min)', 'min="1" max="60"'))
            + grid(4, num(`${p}.cooldown`, 'Délai avant de lui reparler (min)', 'min="0"') + num(`${p}.hours.from`, 'Présent de (h)', 'min="0" max="23"') + num(`${p}.hours.to`, 'Jusqu\'à (h)', 'min="0" max="23"') + num(`${p}.interactDistance`, 'Distance d\'interaction (m)', 'step="0.1"'))
            + `<div class="field" style="max-width:1150px;margin-bottom:10px"><label>Phrase d'accueil</label><input class="input" data-bf="${p}.greeting" value="${esc(get(p + '.greeting') || '')}"></div>
               <div class="field" style="max-width:1150px;margin-bottom:10px"><label>Réponse après paiement</label><input class="input" data-bf="${p}.answer" value="${esc(get(p + '.answer') || '')}"></div>
               <div class="hint">Position : <span class="mono">${xyz(n.ped)}</span></div>
               <div class="btn-row" style="margin-top:10px">${placeBtn('informant', 'ped', 'Placer le PNJ ici', true)}${goBtn(n.ped)}
                <button class="btn" data-ba="dup" data-k="informants">Dupliquer</button><button class="btn danger" data-ba="del" data-k="informants">Supprimer</button></div>`,
        'ALT sur l\'indic → dialogue ; contre paiement, la position du marchand est marquée sur le GPS (itinéraire + repère temporaire).');
    }

    function vItems() {
        const it = D.bankheist.items || {};
        const row = (k) => `<tr><td>${img(get(`items.${k}.name`))}</td><td><strong>${esc(get(`items.${k}.label`))}</strong><br><span class="muted mono">${esc(get(`items.${k}.name`))}</span> ${it[k] ? '✅' : '⚠️ absent de l\'inventaire'}</td>
            <td><input class="input" data-bf="items.${k}.label" value="${esc(get(`items.${k}.label`))}"></td>
            <td><input class="input" type="number" min="0" data-bf="items.${k}.price" value="${esc(get(`items.${k}.price`))}"></td>
            <td><input class="input" type="number" min="0" data-bf="items.${k}.maxOwned" value="${esc(get(`items.${k}.maxOwned`))}"></td>
            <td>${get(`items.${k}.sell`) !== undefined ? `<label><input type="checkbox" class="check" data-bc="items.${k}.sell" ${get(`items.${k}.sell`) ? 'checked' : ''}> Vendu par les marchands</label>` : ''}</td></tr>`;
        return sec('I. Objets et prix', `<table class="loot wide"><tr><th style="width:60px"></th><th>Objet</th><th>Nom affiché</th><th>Prix ($)</th><th>Possession max. (0 = illimité)</th><th></th></tr>
            ${['laptop', 'bag', 'c4', 'drill'].map((k) => row(k)).join('')}</table>`,
        'Images : elyzea_inventory/html/img/bank_laptop.png, bank_bag.png, bank_c4.png, bank_drill.png.');
    }

    function vLoot() {
        return sec('J. Butin et encaissement', grid(4, sel('loot.rewardType', 'Encaissement versé en', PAY) + txt('loot.moneyItem', 'Objet « argent sale »') + num('loot.depositRate', 'Taux d\'encaissement (%)', 'min="1" max="200"')
                + num('loot.bagCapacity', 'Capacité d\'un sac ($)', 'min="1000"'))
            + grid(4, num('loot.perTick', 'Ramassé par seconde ($)', 'min="1"') + num('loot.openDuration', 'Coffre ouvert pendant (s)', 'min="30"'))
            + grid(4, tog('loot.bonus.enabled', 'Bonus possible', '') + num('loot.bonus.chance', 'Bonus : chance (%)') + num('loot.bonus.min', 'Bonus : min (%)') + num('loot.bonus.max', 'Bonus : max (%)'))
            + grid(4, tog('loot.malus.enabled', 'Malus possible', '') + num('loot.malus.chance', 'Malus : chance (%)') + num('loot.malus.min', 'Malus : min (%)') + num('loot.malus.max', 'Malus : max (%)')),
        'Les billets vont dans le sac (sac de jewelry_heist) une tranche par seconde, avec l\'animation ; le HUD en haut à droite affiche le butin de l\'équipe, la part du joueur et le sac. Le total ne dépasse jamais le butin tiré.');
    }

    function vDeposits() {
        const list = get('deposits') || [];
        if (G.di >= list.length) G.di = Math.max(0, list.length - 1);
        const d = list[G.di];
        if (!d) return sec('K. Points de dépôt', picker('deposits', list, G.di) + '<p class="hint">Aucun point de dépôt : les sacs ne peuvent pas être encaissés.</p>');
        const p = `deposits.${G.di}`;
        return sec('K. Points de dépôt (encaissement)', picker('deposits', list, G.di)
            + tiles(tog(`${p}.enabled`, d.enabled ? 'Point actif' : 'Point désactivé', '') + tog(`${p}.allowPassenger`, 'Encaissement possible en passager', 'Jamais en conducteur.'))
            + grid(4, txt(`${p}.id`, 'Identifiant') + txt(`${p}.name`, 'Nom') + num(`${p}.radius`, 'Rayon (m)', 'step="0.5" min="0.5" max="20"'))
            + grid(3, num(`${p}.x`, 'X', 'step="0.01"') + num(`${p}.y`, 'Y', 'step="0.01"') + num(`${p}.z`, 'Z', 'step="0.01"'))
            + `<div class="btn-row">${placeBtn('deposit', 'point', 'Placer ici', true)}${goBtn(d)}<button class="btn" data-ba="add" data-k="deposits">+ Nouveau</button>
                <button class="btn danger" data-ba="del" data-k="deposits">Supprimer</button></div>`,
        'Le porteur d\'un sac de billets appuie sur E dans le rayon : le sac est retiré et son contenu versé selon l\'onglet J.');
    }

    function vVisuals() {
        return sec('L. Visuels et animations', `<table class="loot wide"><tr><th>Animation</th><th>Dictionnaire</th><th>Nom</th><th>Option</th></tr>${anim('visuals.bankerHandsUp', 'Banquier : mains levées')}
                ${anim('visuals.bankerKneel', 'Banquier : à genoux')}${anim('visuals.depositAnim', 'Encaissement du sac')}</table>`,
        'Décryptage, pose de la C4, ramassage (chariot / table) et perçage utilisent les scènes synchronisées des braquages GTA (sac, ordinateur, carte, liasses, perceuse). Le sac porté se règle dans l\'onglet Braquage bijouterie › Sac.');
    }

    function vLive() {
        const rows = (get('banks') || []).map((b) => {
            const x = (D.bankheist.banks || {})[b.id] || {}; const s = x.session;
            return `<tr><td><strong>${esc(b.name)}</strong><br><span class="muted mono">${esc(b.id)}</span></td><td>${PHASE[x.phase] || x.phase || '—'}${x.cooldown ? `<br><span class="muted">délai : ${x.cooldown} min</span>` : ''}
                    ${s ? `<br>${DOORS[s.door] || esc(s.door)}<br>${s.alarm ? '🚨 Alarme déclenchée' : '🔕 Alarme coupée'}` : ''}</td>
                <td>${s ? `${esc(s.robbers.join(', ') || '—')}${s.hacker ? `<br><span class="muted">décrypteur : ${esc(s.hacker)}</span>` : ''}` : '—'}</td>
                <td>${s ? `${money(s.initial)} tiré · ${money(s.distributed)} ramassé · ${money(s.pool)} restant${s.openLeft != null ? `<br><span class="muted">ouvert encore ${s.openLeft} s</span>` : ''}` : '—'}</td>
                <td style="text-align:right">${s ? `<button class="btn danger" data-ba="cancel" data-bank="${esc(b.id)}">Annuler</button>` : `<button class="btn" data-ba="resetBank" data-bank="${esc(b.id)}" ${x.cooldown ? '' : 'disabled'}>Rendre disponible</button>`}</td></tr>`;
        }).join('');
        return sec('M. Sessions en direct', `<table class="loot wide"><tr><th>Banque</th><th>État</th><th>Braqueurs</th><th>Butin</th><th style="width:170px"></th></tr>${rows}</table>
            <div class="btn-row" style="margin-top:10px"><button class="btn" data-ba="resetGlobal" ${D.bankheist.globalCooldown ? '' : 'disabled'}>Remettre le délai global à zéro (${D.bankheist.globalCooldown} min)</button></div>`,
        `Policiers en service : <b>${D.bankheist.police}</b>. Annuler ne redistribue rien et ne retire pas les sacs déjà remplis.`);
    }

    function vLogs() {
        const KINDS = { '': 'Tout', heist: 'Braquages', hack: 'Décryptage', loot: 'Collecte', deposit: 'Encaissements', shop: 'Achats', bank: 'Guichet', admin: 'Staff', anomaly: 'Anomalies' };
        const j = D.bankheist;
        const line = (ok, label, detail) => `<tr><td>${ok ? '✅' : '⚠️'}</td><td><strong>${label}</strong></td><td class="muted">${detail}</td></tr>`;
        const logs = arr(j.logs).filter((l) => !G.logKind || l.kind === G.logKind).map((l) => `<tr><td class="muted" style="white-space:nowrap">${new Date(l.t * 1000).toLocaleString('fr-FR')}</td>
            <td>${esc(KINDS[l.kind] || l.kind)}</td><td>${esc(l.name || '—')}</td><td class="mono">${esc(l.ref || '')}</td><td>${esc(l.details || '')}</td></tr>`).join('');
        return sec('Compatibilité', `<table class="loot wide">
                ${line(j.inventoryRes, 'Inventaire', 'elyzea_inventory (objets, numéro de série de l\'ordinateur)')}
                ${line(j.bagRes, 'Sac', j.bagRes ? 'jewelry_heist (sac porté, posé, ramassé)' : 'jewelry_heist arrêté : collecte impossible')}
                ${line(j.policeRes, 'Police et menu ALT', j.policeRes ? 'elyzea_police (alerte + position, effectifs, menu ALT)' : 'elyzea_police arrêté : alerte interne et menu ALT autonome')}
                ${line(true, 'Argent', 'elyzea_core (liquide, banque) ou objet d\'inventaire')}</table>`)
            + sec('N. Journal', `<div class="btn-row" style="margin-bottom:8px;flex-wrap:wrap">${Object.entries(KINDS).map(([k, v]) => `<button class="btn ${G.logKind === k ? 'primary' : ''}" data-blog="${k}">${v}</button>`).join('')}</div>
                <table class="loot wide"><tr><th>Date</th><th>Type</th><th>Joueur</th><th>Réf.</th><th>Détail</th></tr>${logs || '<tr><td colspan="5" class="muted">Vide.</td></tr>'}</table>`);
    }

    VIEWS.bankheist = () => {
        const j = D.bankheist;
        if (!j.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(j.resource || 'bank_heist')}</b> ne répond pas${j.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (!G.draft) G.draft = normalize(copy(j.settings));
        const live = Object.values(j.banks || {}).filter((x) => x.session).length;
        const body = ({ general: vGeneral, banks: vBanks, points: vPoints, cond: vCond, door: vDoor, alarm: vAlarm, merchants: vMerchants, informants: vInformants, items: vItems, loot: vLoot, deposits: vDeposits, visuals: vVisuals, live: vLive, logs: vLogs }[G.sub] || vGeneral)();
        const bar = `<div class="section"><div class="btn-row"><button class="btn primary" data-ba="save">💾 Enregistrer</button><button class="btn" data-ba="cancelDraft">Annuler les modifications</button>
            <button class="btn" data-ba="reset">Valeurs par défaut</button><span class="muted" style="align-self:center">Appliqué après « Enregistrer », sans redémarrage.</span></div></div>`;
        return `<div class="stats"><div class="stat"><b>${j.settings.general.enabled ? 'Activés' : 'Coupés'}</b><span>Braquages de banque</span></div>
                <div class="stat"><b>${live}</b><span>Braquage(s) en cours</span></div><div class="stat"><b>${(j.settings.banks || []).length}</b><span>Banque(s)</span></div>
                <div class="stat"><b>${j.police}</b><span>Policier(s) en service</span></div></div>
            <div class="btn-row" style="flex-wrap:wrap;margin-bottom:12px">${SUBS.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-bsub="${k}">${l}</button>`).join('')}</div>
            <datalist id="bh-peds">${arr(j.pedModels).map((m) => `<option value="${esc(m)}">`).join('')}</datalist>${bar}${body}${bar}`;
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
        if (t.id === 'bh-lt') { G.lootType = t.value; return; }
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
        if ((n = ev.target.closest('[data-bsel]'))) { G[{ banks: 'bi', merchants: 'mi', informants: 'ni', deposits: 'di' }[n.dataset.bsel]] = Number(n.dataset.i); return render(); }
        if (!(n = ev.target.closest('[data-ba]')) || n.disabled) return;
        const idx = { banks: () => G.bi, merchants: () => G.mi, informants: () => G.ni, deposits: () => G.di };
        const setIdx = (k, v) => { G[{ banks: 'bi', merchants: 'mi', informants: 'ni', deposits: 'di' }[k]] = v; };
        switch (n.dataset.ba) {
            case 'save': send('save', G.draft); G.draft = null; return;
            case 'cancelDraft': G.draft = null; return render();
            case 'reset': if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages du braquage de banque reviennent à ceux du fichier config.lua (banques, marchands et dépôts compris).')) { G.draft = null; send('reset'); } return;
            case 'add': {
                const k = n.dataset.k; const l = get(k) || []; const base = copy((D.bankheist.defaults[k] || [])[0] || {});
                base.id = `${k.slice(0, -1)}_${l.length + 1}`; base.name = `${{ banks: 'Banque', merchants: 'Marchand', informants: 'Indic', deposits: 'Dépôt' }[k]} ${l.length + 1}`;
                if (k === 'banks') base.loot = [];
                l.push(base); setPath(k, l); setIdx(k, l.length - 1); return render();
            }
            case 'dup': { const k = n.dataset.k; const l = get(k); const e = l[idx[k]()]; if (!e) return; const c = copy(e); c.id = `${e.id}_copie`; c.name = `${e.name} (copie)`; l.push(c); setIdx(k, l.length - 1); return render(); }
            case 'del': {
                const k = n.dataset.k; const l = get(k); const e = l[idx[k]()]; if (!e) return;
                if (!(await confirmBox(`Supprimer « ${e.name} » ?`, 'Effectif après « Enregistrer ».'))) return;
                l.splice(idx[k](), 1); return render();
            }
            case 'delLoot': G.draft.banks[G.bi].loot.splice(Number(n.dataset.i), 1); return render();
            case 'place': {
                const t = n.dataset.t; const index = ({ bank: G.bi, merchant: G.mi, informant: G.ni, deposit: G.di }[t] || 0) + 1;
                const data = { draft: G.draft, target: t, what: n.dataset.w, index };
                if (n.dataset.w === 'loot') { if (n.dataset.li) data.lootIndex = Number(n.dataset.li); else data.lootType = G.lootType; }
                send('place', data); G.draft = null; return;
            }
            case 'goto': send('teleport', { x: Number(n.dataset.x), y: Number(n.dataset.y), z: Number(n.dataset.z) }); return;
            case 'cancel': if (await confirmBox('Annuler ce braquage ?', 'La session est terminée (banque laissée en délai). Rien n\'est redistribué.')) send('cancel', { bank: n.dataset.bank }); return;
            case 'resetBank': send('resetBank', { bank: n.dataset.bank }); return;
            case 'resetGlobal': send('resetGlobal'); return;
        }
    });
})();
