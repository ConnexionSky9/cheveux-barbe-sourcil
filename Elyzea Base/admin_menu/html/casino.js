/* =========================================================
   CASINO (ressource elyzea_casino, permission « casino_manage »)
   Général et statistiques · Blackjack · Roulette · Roues de la fortune · Guichet · PNJ et map · Historique
   Chaque enregistrement est revalidé par elyzea_casino (types, bornes, chances = 100 %).
   ========================================================= */
(() => {
    TABS.push({
        id: 'casino', group: 5, label: 'Casino', ico: '🎰',
        sub: 'Tables de blackjack et de roulette, roues de la fortune (lots et chances), guichet des jetons, statistiques et historique.',
        show: () => has('casino_manage') && !!(D && D.casino),
    });

    const C = { sub: 'home', table: null, tdraft: null, wheel: null, wdraft: null, cdraft: null, gdraft: null };
    const send = (name, data = {}) => action('casino', { name, data });
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const ROLE = { blackjack: '🃏 Blackjack', roulette: '🎡 Roulette', wheel: '🎰 Roue', cashier: '💰 Guichet' };
    const PHASE = { idle: 'libre', betting: 'mises', dealing: 'distribution', players: 'joueurs', dealer: 'croupier', payout: 'paiement', spinning: 'roue lancée', result: 'résultat' };
    const REWARD = { none: 'Rien (perdu)', chips: 'Jetons', money: 'Argent ($)', item: 'Objet', custom: 'Récompense spéciale' };
    const SUBS = [['home', '📊 Général'], ['blackjack', '🃏 Blackjack'], ['roulette', '🎡 Roulette'], ['wheels', '🎰 Roues'], ['cashier', '💰 Guichet'], ['map', '🗺️ PNJ et map'], ['history', '📜 Historique']];

    const tile = (key, label, help, on) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-ck="${key}"><div><strong>${esc(label)}</strong><span>${esc(help)}</span></div><div class="switch"></div></div>`;
    const numF = (scope, key, label, v, min, max, step = 1, help = '') => `<div><label>${esc(label)}</label>
        <input class="input" type="number" data-cn="${scope}:${key}" min="${min}" max="${max}" step="${step}" value="${esc(v ?? '')}">${help ? `<p class="hint" style="margin:3px 0 0">${esc(help)}</p>` : ''}</div>`;

    /* -------------------------------------------------- général */
    function viewHome(c) {
        const st = c.stats || {};
        const k = (name) => (st.byKind || []).find((x) => x.kind === name) || { n: 0, bet: 0, won: 0 };
        const bj = k('blackjack'), rl = k('roulette'), wh = k('wheel');
        const tx = (name) => (st.tx || []).find((x) => x.kind === name) || { n: 0, chips: 0, money: 0, fee: 0 };
        const buy = tx('buy'), sell = tx('sell');
        const g = C.gdraft || (C.gdraft = clone(c.global));
        const totalBet = bj.bet + rl.bet + wh.bet, totalWon = bj.won + rl.won + wh.won;
        return `<div class="stats">
            <div class="stat"><b>${c.global.enabled ? '🟢 Ouvert' : '🔴 Fermé'}</b><span>Casino</span></div>
            <div class="stat"><b>${fmt(c.seated)}</b><span>Joueur(s) assis maintenant</span></div>
            <div class="stat"><b>${fmt(bj.n + rl.n)}</b><span>Manches jouées (mains / tours)</span></div>
            <div class="stat"><b>${fmt(wh.n)}</b><span>Participations aux roues</span></div>
            <div class="stat"><b>${fmt(totalBet)}</b><span>Total misé</span></div>
            <div class="stat"><b>${fmt(totalWon)}</b><span>Total rendu aux joueurs</span></div>
            <div class="stat"><b>${fmt(totalBet - totalWon)}</b><span>Bénéfice du casino</span></div>
            <div class="stat"><b>${fmt(buy.money - sell.money)} $</b><span>Solde du guichet (achats − reventes)</span></div></div>
        <div class="section"><h2>Réglages généraux</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr));margin-bottom:12px">
                ${tile('g:enabled', 'Casino ouvert', 'Désactivé : les manches en cours se terminent, puis plus aucune table, roue ni guichet.', g.enabled)}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr));max-width:900px">
                ${numF('g', 'logRetentionDays', 'Garder l\'historique (jours, 0 = toujours)', g.logRetentionDays, 0, 3650)}</div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ca="global_save">💾 Enregistrer</button>
                <button class="btn" data-ca="stats_refresh">🔄 Actualiser les statistiques</button>
                <span class="muted" style="align-self:center">Statistiques du ${c.statsAt ? new Date(c.statsAt * 1000).toLocaleTimeString('fr-FR') : '—'} (mises à jour toutes les minutes).</span></div></div>
        <div class="section"><h2>Par jeu</h2><table class="loot wide"><tr><th>Jeu</th><th>Parties</th><th>Misé</th><th>Rendu</th><th>Bénéfice casino</th></tr>
            ${[['🃏 Blackjack', bj], ['🎡 Roulette', rl], ['🎰 Roues', wh]].map(([l, x]) => `<tr><td>${l}</td><td>${fmt(x.n)}</td><td>${fmt(x.bet)}</td><td>${fmt(x.won)}</td><td>${fmt(x.bet - x.won)}</td></tr>`).join('')}
            </table>
            <p class="hint">Aujourd'hui : ${fmt((st.today || {}).n)} partie(s), ${fmt((st.today || {}).bet)} misé(s), ${fmt((st.today || {}).won)} rendu(s).
                Guichet : ${fmt(buy.n)} achat(s) (${fmt(buy.chips)} jetons, ${fmt(buy.money)} $), ${fmt(sell.n)} revente(s) (${fmt(sell.chips)} jetons, ${fmt(sell.money)} $), commissions ${fmt(buy.fee + sell.fee)} $.
                ${(st.pending || {}).n ? `<b>${fmt(st.pending.n)} paiement(s) en attente</b> (${fmt(st.pending.chips)} jetons, ${fmt(st.pending.money)} $) : rendus à la prochaine connexion des joueurs concernés.` : ''}</p></div>
        <div class="section"><h2>Par table, roue et guichet</h2><table class="loot wide"><tr><th>Élément</th><th>Parties</th><th>Misé</th><th>Rendu</th></tr>
            ${(st.byRef || []).map((x) => `<tr><td>${ROLE[x.kind] || x.kind} ${x.kind === 'wheel' ? `« ${esc(x.ref)} »` : `#${esc(x.ref)}`}</td><td>${fmt(x.n)}</td><td>${fmt(x.bet)}</td><td>${fmt(x.won)}</td></tr>`).join('') || '<tr><td colspan="4" class="muted">Aucune partie enregistrée.</td></tr>'}
            ${(st.txByCashier || []).map((x) => `<tr><td>💰 Guichet #${esc(x.cashier)}</td><td>${fmt(x.n)} transaction(s)</td><td>${fmt(x.chips)} jetons</td><td>${fmt(x.money)} $</td></tr>`).join('')}
            </table></div>`;
    }

    /* -------------------------------------------------- tables */
    function tableForm(p) {
        const isR = p.role === 'roulette';
        const t = C.tdraft;
        const live = p.live || {};
        const seats = (live.seats || []).map((s) => `Place ${s.idx} : <b>${esc(s.name)}</b>${s.left ? ' (parti, paiement en cours)' : ''}`).join(' · ') || 'aucun joueur';
        return `<div class="card recipe"><h3 class="sub-h" style="font-size:17px">${ROLE[p.role]} #${p.id} ${esc(p.name || '')}</h3>
            <p class="hint">État : <b>${PHASE[live.phase] || live.phase}</b> · manche n°${fmt(live.round)} · ${seats}${!p.placed ? ' · <b style="color:var(--danger)">table pas encore posée (éditeur › PNJ)</b>' : ''}</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                ${tile('t:enabled', 'Table ouverte', 'Fermée : la manche en cours se termine, les mises en attente sont rendues.', t.enabled)}
                ${isR ? '' : tile('t:autoStart', 'Départ automatique', 'Activé : distribution à la fin du compte à rebours. Désactivé : quand tous les joueurs sont prêts.', t.autoStart)}
                ${isR ? '' : tile('t:dealerHitsSoft17', 'Le croupier tire sur 17 souple', 'Désactivé : il reste sur tous les 17 (règle la plus courante).', t.dealerHitsSoft17)}
                ${isR ? '' : tile('t:allowDouble', 'Doubler permis', 'Sur les 2 premières cartes.', t.allowDouble)}
                ${isR ? '' : tile('t:allowSplit', 'Séparer permis', 'Une paire devient deux mains.', t.allowSplit)}
                ${isR ? '' : tile('t:doubleAfterSplit', 'Doubler après séparation', '', t.doubleAfterSplit)}
                ${isR ? '' : tile('t:allowInsurance', 'Assurance', 'Proposée quand le croupier montre un As : moitié de la mise, payée 2:1 s\'il a blackjack.', t.allowInsurance !== false)}
                ${isR ? '' : tile('t:allowSurrender', 'Abandon', 'Sur les 2 premières cartes, le joueur rend sa main et récupère la moitié de sa mise.', t.allowSurrender !== false)}
            </div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr));max-width:1150px">
                ${numF('t', 'minBet', 'Mise minimale (jetons)', t.minBet, 1, 10000000)}
                ${numF('t', 'maxBet', isR ? 'Mises maximum par tour (jetons)' : 'Mise maximale (jetons)', t.maxBet, 1, 100000000)}
                ${numF('t', 'maxPlayers', 'Joueurs (1 à 4)', t.maxPlayers, 1, 4)}
                ${numF('t', 'betTime', 'Temps pour miser (s)', t.betTime, isR ? 10 : 5, 120)}
                ${isR ? numF('t', 'spinTime', 'Durée de la roue (s)', t.spinTime, 6, 20) : numF('t', 'actionTime', 'Temps pour jouer une main (s)', t.actionTime, 5, 120)}
                ${isR ? numF('t', 'history', 'Derniers résultats affichés', t.history, 0, 30) : numF('t', 'decks', 'Jeux de cartes dans le sabot', t.decks, 1, 8)}
                ${isR ? `<div><label>Variante</label><select class="input" data-cs="t:variant"><option value="eu" ${t.variant === 'eu' ? 'selected' : ''}>Européenne (0)</option><option value="us" ${t.variant === 'us' ? 'selected' : ''}>Américaine (0 et 00)</option></select></div>`
                    : `<div><label>Paiement du blackjack</label><select class="input" data-cs="t:blackjackPays"><option value="1.5" ${Number(t.blackjackPays) === 1.5 ? 'selected' : ''}>3:2 (×1,5)</option><option value="1.2" ${Number(t.blackjackPays) === 1.2 ? 'selected' : ''}>6:5 (×1,2)</option><option value="1" ${Number(t.blackjackPays) === 1 ? 'selected' : ''}>1:1</option></select></div>
                    <div><label>Doubler sur</label><select class="input" data-cs="t:doubleOn"><option value="any" ${t.doubleOn === 'any' ? 'selected' : ''}>N'importe quelles 2 cartes</option><option value="9-11" ${t.doubleOn === '9-11' ? 'selected' : ''}>Total de 9, 10 ou 11</option></select></div>
                    ${numF('t', 'maxHands', 'Mains après séparation (2 à 4)', t.maxHands, 2, 4)}`}
            </div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ca="table_save">💾 Enregistrer</button>
                <button class="btn" data-cx="tdefault">Valeurs par défaut</button>
                <button class="btn danger" data-ca="table_reset">♻️ Remettre à zéro (rend les mises, relève les joueurs)</button>
                <span class="muted" style="align-self:center">Appliqué à la prochaine manche.</span></div></div>`;
    }
    function viewTables(c, role) {
        const list = (c.points || []).filter((p) => p.role === role);
        if (!list.length) return `<div class="protect">ℹ️ <span>Aucune table de ${role === 'roulette' ? 'roulette' : 'blackjack'} : dans l'<b>Éditeur de map › PNJ</b>, pose un PNJ avec le rôle <b>Casino › ${role === 'roulette' ? 'Croupier de roulette' : 'Croupier de blackjack'}</b>, enregistre-le, puis « Poser la table ».</span></div>`;
        if (!C.table || !list.find((p) => p.id === C.table)) { C.table = list[0].id; C.tdraft = null; }
        const p = list.find((x) => x.id === C.table);
        if (!C.tdraft) C.tdraft = clone(p.cfg);
        return `<div class="btn-row" style="margin-bottom:12px">${list.map((x) => `<button class="btn ${x.id === C.table ? 'primary' : ''}" data-ctab="${x.id}">#${x.id} ${esc(x.name || '')} · ${PHASE[(x.live || {}).phase] || 'libre'} · ${((x.live || {}).seats || []).length}/${x.cfg.maxPlayers}${x.cfg.enabled ? '' : ' · fermée'}</button>`).join('')}</div>${tableForm(p)}`;
    }

    /* -------------------------------------------------- roues */
    function wheelPreview(w) {
        setTimeout(() => {
            const cv = document.getElementById('cs-wprev'); if (!cv) return;
            const g = cv.getContext('2d'); const segs = w.segments || []; const n = Math.max(1, segs.length); const R = cv.width / 2; const seg = (Math.PI * 2) / n;
            g.clearRect(0, 0, cv.width, cv.height); g.save(); g.translate(R, R);
            segs.forEach((s, i) => {
                const a0 = -Math.PI / 2 + i * seg - seg / 2;
                g.beginPath(); g.moveTo(0, 0); g.arc(0, 0, R - 6, a0, a0 + seg); g.closePath(); g.fillStyle = s.color || '#222'; g.fill();
                g.strokeStyle = '#f4d77a'; g.lineWidth = 2; g.stroke();
                g.save(); g.rotate(a0 + seg / 2); g.fillStyle = s.text || '#fff'; g.font = `bold ${n > 14 ? 10 : 12}px Arial`; g.textAlign = 'right';
                g.fillText(`${s.icon ? `${s.icon} ` : ''}${s.label}`.slice(0, 20), R - 14, 4); g.restore();
            });
            g.beginPath(); g.arc(0, 0, 22, 0, Math.PI * 2); g.fillStyle = '#d4af37'; g.fill(); g.restore();
            g.beginPath(); g.moveTo(R - 9, 0); g.lineTo(R + 9, 0); g.lineTo(R, 16); g.fillStyle = '#fff'; g.fill();
        }, 0);
    }
    const total = (segs) => Math.round(segs.reduce((a, s) => a + (Number(s.weight) || 0), 0) * 100) / 100;
    function normalizeDraft(segs) {
        const t = segs.reduce((a, s) => a + Math.max(0, Number(s.weight) || 0), 0);
        segs.forEach((s) => { s.weight = t > 0 ? Math.round(Math.max(0, Number(s.weight) || 0) / t * 10000) / 100 : Math.floor(10000 / segs.length) / 100; });
        const diff = Math.round((100 - total(segs)) * 100) / 100;
        if (diff) { let b = 0; segs.forEach((s, i) => { if (s.weight > segs[b].weight) b = i; }); segs[b].weight = Math.round((segs[b].weight + diff) * 100) / 100; }
    }
    function viewWheels(c) {
        const ws = c.wheels || [];
        if (C.wheel === null && ws.length) C.wheel = ws[0].id;
        const cur = ws.find((w) => w.id === C.wheel);
        if (!C.wdraft) C.wdraft = cur ? clone(cur) : null;
        const w = C.wdraft;
        const list = `<div class="btn-row" style="margin-bottom:12px">${ws.map((x) => `<button class="btn ${x.id === C.wheel ? 'primary' : ''}" data-cwh="${esc(x.id)}">${x.enabled ? '🟢' : '⚪'} ${esc(x.name)}${x.valid ? '' : ' ⚠️'}</button>`).join('')}
            <button class="btn" data-cx="wnew">+ Nouvelle roue</button></div>`;
        if (!w) return `${list}<p class="hint">Aucune roue. Crée-en une.</p>`;
        const t = total(w.segments);
        const ok = Math.abs(t - 100) <= 0.01;
        const sim = c.last && c.last.simulation && c.last.wheel === w.id ? c.last.simulation : null;
        const rows = w.segments.map((s, i) => `<tr>
            <td><input class="input" data-cg="${i}:label" value="${esc(s.label)}" maxlength="32" style="min-width:130px"></td>
            <td><input type="color" data-cg="${i}:color" value="${esc(s.color || '#1b1b1b')}"> <input type="color" data-cg="${i}:text" value="${esc(s.text || '#ffffff')}" title="Couleur du texte"></td>
            <td><input class="input" data-cg="${i}:icon" value="${esc(s.icon || '')}" maxlength="4" style="width:56px" placeholder="🎁"></td>
            <td><select class="input" data-cg="${i}:reward">${Object.entries(REWARD).map(([k, l]) => `<option value="${k}" ${s.reward === k ? 'selected' : ''}>${l}</option>`).join('')}</select></td>
            <td>${s.reward === 'item' ? `<input class="input" list="known-items" data-cg="${i}:item" value="${esc(s.item || '')}" placeholder="objet" style="min-width:110px"> × <input class="input" type="number" min="1" data-cg="${i}:count" value="${esc(s.count || 1)}" style="width:64px">`
                : s.reward === 'none' || s.reward === 'custom' ? '<span class="muted">—</span>' : `<input class="input" type="number" min="0" data-cg="${i}:value" value="${esc(s.value)}" style="width:110px">`}</td>
            <td><input class="input" type="number" min="0" max="100" step="0.01" data-cg="${i}:weight" value="${esc(s.weight)}" style="width:90px"> %</td>
            <td>${sim && sim[i] ? `<span class="muted">${sim[i].got} %</span>` : ''}</td>
            <td style="white-space:nowrap;text-align:right"><button class="btn" data-cseg="up" data-i="${i}" ${i === 0 ? 'disabled' : ''}>↑</button><button class="btn" data-cseg="down" data-i="${i}" ${i === w.segments.length - 1 ? 'disabled' : ''}>↓</button>
                <button class="btn" data-cseg="dup" data-i="${i}" title="Dupliquer">⧉</button><button class="sb-close" data-cseg="del" data-i="${i}">✕</button></td></tr>`).join('');
        wheelPreview(w);
        return `${list}<div class="card recipe" style="display:grid;grid-template-columns:1fr 280px;gap:18px">
            <div>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr));margin-bottom:12px">${tile('w:enabled', 'Roue active', 'Utilisable seulement si les chances font 100 %.', w.enabled)}</div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr))">
                    <div><label>Nom</label><input class="input" data-cw="name" value="${esc(w.name)}" maxlength="40"></div>
                    <div><label>Identifiant (lettres, chiffres, _)</label><input class="input" data-cw="id" value="${esc(w.id)}" maxlength="30"></div>
                    <div><label>Coût d'une participation</label><select class="input" data-cw="costType"><option value="chips" ${w.costType === 'chips' ? 'selected' : ''}>Jetons</option><option value="money" ${w.costType === 'money' ? 'selected' : ''}>Argent ($)</option><option value="free" ${w.costType === 'free' ? 'selected' : ''}>Gratuit</option></select></div>
                    <div><label>Montant</label><input class="input" type="number" min="0" data-cw="cost" value="${esc(w.cost)}"></div>
                    <div><label>Participations par jour et par joueur (0 = illimité)</label><input class="input" type="number" min="0" data-cw="maxPerDay" value="${esc(w.maxPerDay)}"></div>
                    <div><label>Attente entre deux tours (s)</label><input class="input" type="number" min="0" data-cw="cooldown" value="${esc(w.cooldown)}"></div>
                    <div><label>Modèle de la roue</label><input class="input" data-cw="model" value="${esc(w.model)}"></div>
                    <div><label>Modèle du socle (vide = aucun)</label><input class="input" data-cw="baseModel" value="${esc(w.baseModel || '')}"></div>
                    <div><label>Hauteur de la roue sur le socle (m)</label><input class="input" type="number" step="0.01" data-cw="wheelZ" value="${esc(w.wheelZ || 0)}"></div>
                </div>
                <h3 class="sub-h" style="margin-top:14px">Segments (${w.segments.length}) · total des chances <b style="color:${ok ? 'var(--success, #4caf50)' : 'var(--danger)'}">${t} %</b>${ok ? '' : ' — doit faire 100 %'}</h3>
                <table class="loot wide"><tr><th>Texte</th><th>Couleurs</th><th>Icône</th><th>Récompense</th><th>Valeur</th><th>Chance</th><th>${sim ? 'Simulé' : ''}</th><th></th></tr>${rows}</table>
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-cseg="add">+ Segment</button>
                    <button class="btn" data-cx="wnorm" ${ok ? 'disabled' : ''}>⚖️ Normaliser à 100 % (garde les proportions)</button></div>
                <div class="btn-row" style="margin-top:14px"><button class="btn primary" data-ca="wheel_save">💾 Enregistrer la roue</button>
                    <button class="btn" data-ca="wheel_test">🎲 Tester (sans récompense)</button><button class="btn" data-ca="wheel_simulate">📈 Simuler 10 000 tirages</button>
                    <button class="btn" data-ca="wheel_duplicate">⧉ Dupliquer</button><button class="btn danger" data-ca="wheel_delete">🗑 Supprimer</button></div>
                <p class="hint">Les tests et simulations utilisent la roue <b>enregistrée</b>. Le tirage est fait par le serveur, pondéré par les chances ; la roue s'arrête exactement sur le segment tiré.
                    L'apparence (couleurs, textes, modèle) ne change jamais les chances.</p>
            </div>
            <div style="text-align:center"><canvas id="cs-wprev" width="260" height="260"></canvas>
                ${c.last && c.last.testIdx && c.last.wheel === w.id ? `<p class="hint">Dernier test : <b>${esc((w.segments[c.last.testIdx - 1] || {}).label || '')}</b></p>` : ''}</div></div>`;
    }

    /* -------------------------------------------------- guichet */
    function viewCashier(c) {
        const d = C.cdraft || (C.cdraft = clone(c.cashier));
        const cashiers = (c.points || []).filter((p) => p.role === 'cashier');
        return `<div class="section"><h2>Guichet des jetons</h2>
            <p class="hint">Objet utilisé : <b>${esc(c.chipItem)}</b> (inventaire). ${cashiers.length ? `${cashiers.length} guichetier(s) posé(s).` : '<b>Aucun guichetier</b> : pose un PNJ avec le rôle Casino › Guichetier dans l\'éditeur.'}</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                ${tile('c:enabled', 'Service ouvert', 'Fermé : plus d\'achat ni de revente.', d.enabled)}
                ${tile('c:cash', 'Paiement en liquide', '', (d.accounts || {}).cash)}
                ${tile('c:bank', 'Paiement par banque', '', (d.accounts || {}).bank)}
                ${tile('c:hoursOn', 'Horaires d\'ouverture', 'Heure du serveur.', d.hoursOn)}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));max-width:1150px">
                ${numF('c', 'buyRate', 'Prix d\'un jeton à l\'achat ($)', d.buyRate, 0.01, 100000, 0.01)}
                ${numF('c', 'sellRate', 'Valeur d\'un jeton à la revente ($)', d.sellRate, 0, 100000, 0.01, 'Jamais plus que le prix d\'achat.')}
                ${numF('c', 'buyFeePct', 'Commission à l\'achat (%)', d.buyFeePct, 0, 50, 0.1)}
                ${numF('c', 'sellFeePct', 'Commission à la revente (%)', d.sellFeePct, 0, 50, 0.1)}
                ${numF('c', 'minTx', 'Jetons minimum par transaction', d.minTx, 1, 100000000)}
                ${numF('c', 'maxTx', 'Jetons maximum par transaction', d.maxTx, 1, 100000000)}
                ${numF('c', 'maxChips', 'Jetons maximum par joueur (0 = sans limite)', d.maxChips, 0, 1000000000)}
                ${d.hoursOn ? numF('c', 'hoursFrom', 'Ouverture (h)', d.hoursFrom, 0, 23) + numF('c', 'hoursTo', 'Fermeture (h)', d.hoursTo, 0, 23) : ''}</div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-ca="cashier_save">💾 Enregistrer</button><button class="btn" data-cx="cdefault">Valeurs par défaut</button></div></div>
        <div class="section"><h2>Dernières transactions</h2><table class="loot wide"><tr><th>Date</th><th>Joueur</th><th>Opération</th><th>Jetons</th><th>Argent</th><th>Commission</th><th>Compte</th><th>Guichet</th></tr>
            ${((c.stats || {}).txList || []).map((x) => `<tr><td>${esc(x.at)}</td><td>${esc(x.name)}</td><td>${x.kind === 'buy' ? 'Achat' : 'Revente'}</td><td>${fmt(x.chips)}</td><td>${fmt(x.money)} $</td><td>${fmt(x.fee)} $</td><td>${x.account === 'bank' ? 'Banque' : 'Liquide'}</td><td>#${esc(x.cashier)}</td></tr>`).join('') || '<tr><td colspan="8" class="muted">Aucune transaction.</td></tr>'}</table></div>`;
    }

    /* -------------------------------------------------- PNJ et map */
    function viewMap(c) {
        const pts = c.points || [];
        return `<div class="section"><h2>Points du casino (PNJ de l'éditeur)</h2>
            <p class="hint">Chaque élément est un PNJ de l'<b>Éditeur de map</b> avec le rôle <b>Casino</b> : place, orientation, apparence, animation et rôle se changent dans sa fiche (Éditeur › PNJ).
                La table ou la roue se pose / se déplace depuis cette fiche. Supprimer un PNJ libère sa table (les mises en jeu sont rendues) sans toucher au reste.</p>
            <table class="loot wide"><tr><th>#</th><th>Rôle</th><th>Nom</th><th>Table / roue</th><th>Position du PNJ</th><th>État</th><th></th></tr>
            ${pts.map((p) => `<tr><td>${p.id}</td><td>${ROLE[p.role]}</td><td>${esc(p.name || '')}${p.role === 'wheel' ? ` · roue <b>${esc(p.wheel || '')}</b>${(c.wheels || []).find((w) => w.id === p.wheel) ? '' : ' <b style="color:var(--danger)">introuvable</b>'}` : ''}</td>
                <td>${p.role === 'cashier' ? '—' : p.placed ? '✅ posée' : '<b style="color:var(--danger)">à poser</b>'}</td><td>${p.pos.x}, ${p.pos.y}, ${p.pos.z}</td>
                <td>${p.live ? `${PHASE[p.live.phase] || p.live.phase} · ${p.live.seats.length} joueur(s)` : ''}</td>
                <td style="white-space:nowrap">${p.placed ? `<button class="btn" data-ctp="${p.id}">🚀 Y aller</button>` : ''}${p.live ? `<button class="btn" data-creset="${p.id}">♻️</button>` : ''}</td></tr>`).join('') || '<tr><td colspan="7" class="muted">Aucun PNJ avec le rôle Casino.</td></tr>'}</table>
            <div class="btn-row" style="margin-top:10px"><button class="btn" data-ca="points_reload">🔄 Recharger depuis l'éditeur</button></div></div>`;
    }

    function viewHistory(c) {
        const logs = (c.stats || {}).logs || [];
        return `<div class="section"><h2>Historique (60 derniers événements)</h2><table class="loot wide"><tr><th>Date</th><th>Type</th><th>Élément</th><th>Joueur / staff</th><th>Misé</th><th>Rendu</th><th>Détail</th></tr>
            ${logs.map((x) => `<tr><td>${esc(x.at)}</td><td>${x.kind === 'admin' ? '🛡️ Admin' : ROLE[x.kind] || esc(x.kind)}${x.test ? ' (test)' : ''}</td><td>${esc(x.ref)}</td><td>${esc(x.name)}</td><td>${fmt(x.bet)}</td><td>${fmt(x.won)}</td><td class="muted">${esc(x.detail)}</td></tr>`).join('') || '<tr><td colspan="7" class="muted">Rien pour le moment.</td></tr>'}</table></div>`;
    }

    VIEWS.casino = () => {
        const c = D.casino;
        if (!c.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(c.resource || 'elyzea_casino')}</b> ${c.loading ? 'démarre…' : 'ne répond pas'}${c.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (c.denied) return '<div class="protect">⛔ <span>Permission « casino_manage » refusée par elyzea_casino.</span></div>';
        const nav = `<div class="btn-row" style="margin-bottom:14px">${SUBS.map(([k, l]) => `<button class="btn ${C.sub === k ? 'primary' : ''}" data-csub="${k}">${l}</button>`).join('')}</div>`;
        const body = C.sub === 'blackjack' ? viewTables(c, 'blackjack') : C.sub === 'roulette' ? viewTables(c, 'roulette') : C.sub === 'wheels' ? viewWheels(c)
            : C.sub === 'cashier' ? viewCashier(c) : C.sub === 'map' ? viewMap(c) : C.sub === 'history' ? viewHistory(c) : viewHome(c);
        return nav + body;
    };

    /* -------------------------------------------------- événements */
    const on = () => isOpen && tab === 'casino' && D && D.casino && D.casino.available;
    const reRender = () => render();
    document.addEventListener('click', (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-csub],[data-ck],[data-ca],[data-cx],[data-ctab],[data-cwh],[data-cseg],[data-ctp],[data-creset]');
        if (!t) return;
        const c = D.casino;
        if (t.dataset.csub) { C.sub = t.dataset.csub; C.tdraft = null; C.cdraft = null; C.gdraft = null; return reRender(); }
        if (t.dataset.ctab) { C.table = Number(t.dataset.ctab); C.tdraft = null; return reRender(); }
        if (t.dataset.cwh) { C.wheel = t.dataset.cwh; C.wdraft = null; return reRender(); }
        if (t.dataset.ctp) { editorPost('casino_table_tp', { id: Number(t.dataset.ctp) }); return; }
        if (t.dataset.creset) { send('table_reset', { id: Number(t.dataset.creset) }); return; }
        if (t.dataset.ck) {
            const [scope, key] = t.dataset.ck.split(':');
            if (scope === 'g') C.gdraft[key] = !C.gdraft[key];
            if (scope === 't') C.tdraft[key] = (key === 'allowInsurance' || key === 'allowSurrender') ? C.tdraft[key] === false : !C.tdraft[key];
            if (scope === 'w') C.wdraft[key] = !C.wdraft[key];
            if (scope === 'c') { if (key === 'cash' || key === 'bank') C.cdraft.accounts[key] = !C.cdraft.accounts[key]; else C.cdraft[key] = !C.cdraft[key]; }
            return reRender();
        }
        if (t.dataset.cseg) {
            const segs = C.wdraft.segments, i = Number(t.dataset.i);
            if (t.dataset.cseg === 'add') segs.push({ label: 'Nouveau lot', color: '#1e4fd6', text: '#ffffff', reward: 'chips', value: 100, weight: 0 });
            if (t.dataset.cseg === 'del' && segs.length > 2) segs.splice(i, 1);
            if (t.dataset.cseg === 'dup' && segs.length < 40) segs.splice(i + 1, 0, clone(segs[i]));
            if (t.dataset.cseg === 'up' && i > 0) [segs[i - 1], segs[i]] = [segs[i], segs[i - 1]];
            if (t.dataset.cseg === 'down' && i < segs.length - 1) [segs[i + 1], segs[i]] = [segs[i], segs[i + 1]];
            return reRender();
        }
        if (t.dataset.cx) {
            const x = t.dataset.cx;
            if (x === 'tdefault') { const p = (c.points || []).find((q) => q.id === C.table); C.tdraft = clone(c.defaults[p && p.role === 'roulette' ? 'roulette' : 'blackjack']); }
            if (x === 'cdefault') C.cdraft = clone(c.defaults.cashier);
            if (x === 'wnorm') normalizeDraft(C.wdraft.segments);
            if (x === 'wnew') {
                let n = 1; while ((c.wheels || []).some((w) => w.id === `roue_${n}`)) n++;
                C.wheel = null;
                C.wdraft = { id: `roue_${n}`, name: `Roue ${n}`, enabled: false, costType: 'chips', cost: 100, maxPerDay: 0, cooldown: 10, model: 'vw_prop_vw_luckywheel_02a', baseModel: 'vw_prop_vw_luckywheel_01a', wheelZ: 0,
                    segments: [{ label: 'Perdu', color: '#1b1b1b', text: '#ffffff', reward: 'none', value: 0, weight: 50 }, { label: '200 jetons', color: '#0a7d3b', text: '#ffffff', reward: 'chips', value: 200, weight: 50 }] };
                C.wdraft._new = true;
            }
            return reRender();
        }
        if (t.dataset.ca) {
            const a = t.dataset.ca;
            if (a === 'global_save') return send(a, C.gdraft);
            if (a === 'cashier_save') return send(a, C.cdraft);
            if (a === 'table_save') return send(a, { id: C.table, cfg: C.tdraft });
            if (a === 'table_reset') return send(a, { id: C.table });
            if (a === 'wheel_save') {
                const w = clone(C.wdraft); const orig = w._new ? w.id : C.wheel; delete w._new;
                C.wheel = w.id; C.wdraft = null;
                return send(a, { wheel: w, originalId: orig });
            }
            if (a === 'wheel_delete') { const id = C.wheel; C.wheel = null; C.wdraft = null; return send(a, { id }); }
            if (['wheel_test', 'wheel_simulate', 'wheel_duplicate'].includes(a)) return send(a, { id: C.wheel, n: 10000 });
            return send(a, {});
        }
    });
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.cn) {
            const [scope, key] = t.dataset.cn.split(':');
            const v = t.value === '' ? '' : Number(t.value);
            if (scope === 'g') C.gdraft[key] = v;
            if (scope === 't') C.tdraft[key] = v;
            if (scope === 'c') C.cdraft[key] = v;
        } else if (t.dataset.cw) {
            const k = t.dataset.cw;
            C.wdraft[k] = ['cost', 'maxPerDay', 'cooldown', 'wheelZ'].includes(k) ? (t.value === '' ? '' : Number(t.value)) : t.value;
        } else if (t.dataset.cg) {
            const [i, k] = t.dataset.cg.split(':');
            const s = C.wdraft.segments[Number(i)];
            s[k] = ['value', 'weight', 'count'].includes(k) ? (t.value === '' ? '' : Number(t.value)) : t.value;
            if (k === 'color' || k === 'text' || k === 'label' || k === 'icon') wheelPreview(C.wdraft);
            if (k === 'weight') { const h = document.querySelector('[data-cx="wnorm"]'); if (h) h.disabled = Math.abs(total(C.wdraft.segments) - 100) <= 0.01; }
        }
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.cs) {
            const [, key] = t.dataset.cs.split(':');
            C.tdraft[key] = key === 'blackjackPays' ? Number(t.value) : t.value;
        } else if (t.dataset.cw === 'costType') { C.wdraft.costType = t.value; reRender(); }
        else if (t.dataset.cg && t.dataset.cg.endsWith(':reward')) reRender();
        else if (t.dataset.cg && t.dataset.cg.endsWith(':weight')) reRender();
    });
})();
