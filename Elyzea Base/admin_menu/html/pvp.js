/* =========================================================
   ARÈNE PVP (ressource pvp_arena, permission « pvp_manage »)
   Parties en cours · Arènes (points posés à ta position) · Réglages · Historique et argent
   Chaque action est revalidée par pvp_arena.
   ========================================================= */
(() => {
    TABS.push({
        id: 'pvp', group: 5, label: 'Arène PvP', ico: '⚔️',
        sub: 'Parties en cours (annuler, sortir un joueur), arènes (apparitions, zone, hauteur), réglages des mises, paris, manches et armes, historique.',
        show: () => has('pvp_manage') && !!(D && D.pvp),
    });

    const P = { sub: 'live', arena: null, adraft: null, sdraft: null, open: {} };
    const send = (name, data = {}) => action('pvp', { name, data });
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const SUBS = [['live', '🎮 Parties en cours'], ['arenas', '🗺️ Arènes'], ['settings', '⚙️ Réglages'], ['history', '📜 Historique et argent']];
    const STATE = { LOBBY: '🟦 Lobby', PREPARATION: '🟨 Préparation', WEAPON_SELECTION: '🟩 Choix des armes', COUNTDOWN: '🟩 Décompte', IN_ROUND: '🟥 Manche en cours',
        ROUND_END: '🟩 Fin de manche', MATCH_END: '🏁 Fin de partie', CLEANUP: '🏁 Retour au RP', CLOSED: 'Fermée' };
    const team = (k) => { const t = (D.pvp.settings.teams || {})[k] || { name: k, color: '#888' }; return `<b style="color:${esc(t.color)}">${esc(t.name)}</b>`; };
    const tile = (key, label, help, on) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-pk="${key}"><div><strong>${esc(label)}</strong><span>${esc(help)}</span></div><div class="switch"></div></div>`;
    const numF = (path, label, v, min, max, step = 1, help = '') => `<div><label>${esc(label)}</label>
        <input class="input" type="number" data-pn="${path}" min="${min}" max="${max}" step="${step}" value="${esc(v ?? '')}">${help ? `<p class="hint" style="margin:3px 0 0">${esc(help)}</p>` : ''}</div>`;
    const sel = (path, label, v, opts) => `<div><label>${esc(label)}</label><select class="input" data-ps="${path}">${opts.map(([k, l]) => `<option value="${esc(k)}" ${String(k) === String(v) ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select></div>`;
    const getPath = (o, p) => p.split('.').reduce((a, k) => (a ? a[k] : undefined), o);
    const setPath = (o, p, v) => { const ks = p.split('.'); const last = ks.pop(); ks.reduce((a, k) => (a[k] = a[k] || {}), o)[last] = v; };

    /* -------------------------------------------------- parties en cours */
    function viewLive(p) {
        const list = p.matches || [];
        const inMatch = list.filter((m) => m.state !== 'LOBBY').length;
        const players = list.reduce((n, m) => n + m.members.length, 0);
        const held = list.reduce((n, m) => n + m.stakePot + m.betA + m.betB, 0);
        return `<div class="stats">
            <div class="stat"><b>${fmt(list.length)}</b><span>Partie(s) ouvertes</span></div>
            <div class="stat"><b>${fmt(inMatch)}</b><span>En cours dans l'arène</span></div>
            <div class="stat"><b>${fmt(players)}</b><span>Joueur(s) inscrits</span></div>
            <div class="stat"><b>${fmt(held)} $</b><span>Argent en jeu (mises + paris)</span></div></div>
        ${!list.length ? '<div class="empty">Aucune partie pour le moment. Les joueurs en créent avec le PNJ « ⚔️ Arène PvP » (éditeur de map).</div>' : list.map((m) => `
            <div class="card">
                <div class="card-head"><strong>${esc(m.name)}</strong><span class="muted">${STATE[m.state] || esc(m.state)} · ${esc(m.uid)}${m.bucket ? ` · instance ${m.bucket}` : ''}</span></div>
                <div class="field-stats">
                    <span class="zbadge">${esc(m.settings.mode)}</span><span class="zbadge">Premier à ${m.settings.wins}</span>
                    <span class="zbadge">Arène : ${esc(m.settings.arena)}</span><span class="zbadge">Manche ${m.settings.roundTime} s</span>
                    ${m.settings.friendlyFire ? '<span class="zbadge">Dégâts alliés</span>' : ''}
                    <span class="zbadge">Mise ${fmt(m.settings.stake)} $ · pot ${fmt(m.stakePot)} $</span>
                    <span class="zbadge">Paris ${fmt(m.betA)} $ / ${fmt(m.betB)} $</span>
                    ${m.state !== 'LOBBY' ? `<span class="zbadge">Manche ${m.round} · ${m.score.A} – ${m.score.B}</span>` : ''}
                </div>
                <table class="loot wide" style="margin-top:8px"><tr><th>Joueur</th><th>Équipe</th><th>État</th><th>Élim. / morts</th><th>Arme</th><th></th></tr>
                    ${m.members.map((x) => `<tr><td>${x.host ? '♛ ' : ''}${esc(x.name)} <span class="muted">[${x.id}]</span></td><td>${team(x.team)}</td>
                        <td>${m.state === 'LOBBY' ? `${x.ready ? '✔ prêt' : '… pas prêt'}${m.settings.stake > 0 ? (x.paid ? ' · mise payée' : ' · mise à payer') : ''}` : (x.alive ? '🟢 en vie' : '⚫ éliminé')}</td>
                        <td>${x.kills} / ${x.deaths}</td><td>${esc(String(x.weapon || '—').replace('WEAPON_', ''))}</td>
                        <td style="text-align:right"><button class="btn" data-pkick="${x.id}" title="Le renvoie au RP (position et instance d'avant)">Sortir</button></td></tr>`).join('')}
                </table>
                ${m.bets.length ? `<p class="hint" style="margin-top:6px">Paris : ${m.bets.map((b) => `${esc(b.name)} ${fmt(b.amount)} $ sur ${team(b.team)}`).join(' · ')}</p>` : ''}
                <div class="btn-row" style="margin-top:8px"><button class="btn danger" data-pcancel="${esc(m.uid)}">🛑 Annuler la partie (tout rembourser)</button></div>
            </div>`).join('')}
        <div class="section"><h2>Sortir un joueur par son ID</h2>
            <p class="hint">Pour un joueur bloqué (instance, arme ou état d'arène) même s'il n'apparaît plus dans une partie : il retrouve sa position et son instance RP.</p>
            <div class="inline" style="max-width:420px"><input class="input" type="number" min="1" id="pvp-kick-id" placeholder="ID du joueur"><button class="btn" data-pkickid>Sortir de l'arène</button></div></div>`;
    }

    /* -------------------------------------------------- arènes */
    function pointRows(a, what, list, label) {
        return `<tr><td colspan="4" class="muted" style="padding-top:10px"><b>${label}</b> (${list.length})
                <button class="btn" data-padd="${what}" style="margin-left:8px">📍 Ajouter à ma position</button>
                ${list.length ? `<button class="btn danger" data-preset="${what}">Tout effacer</button>` : ''}</td></tr>
            ${list.map((p, i) => `<tr><td>n°${i + 1}</td><td>${p.x.toFixed(1)}, ${p.y.toFixed(1)}${p.z !== undefined ? `, ${p.z.toFixed(1)}` : ''}</td><td>${p.h !== undefined ? `cap ${Math.round(p.h)}°` : ''}</td>
                <td style="text-align:right">${what !== 'corner' ? `<button class="btn" data-ptp="${what}" data-i="${i + 1}">🚀 Y aller</button>` : ''}<button class="sb-close" data-pdel="${what}" data-i="${i + 1}">✕</button></td></tr>`).join('')}`;
    }
    function viewArenas(p) {
        const list = p.arenas || [];
        if (P.arena && !list.some((a) => a.id === P.arena)) P.arena = null;
        if (!P.arena && list.length) P.arena = list[0].id;
        const a = list.find((x) => x.id === P.arena);
        if (a && (!P.adraft || P.adraft.id !== a.id)) P.adraft = { id: a.id, label: a.label, minZ: a.zone.minZ ?? '', maxZ: a.zone.maxZ ?? '', time: a.time ?? '', weather: a.weather ?? '' };
        const d = P.adraft;
        return `<div class="btn-row" style="margin-bottom:12px">${list.map((x) => `<button class="btn ${x.id === P.arena ? 'primary' : ''}" data-parena="${esc(x.id)}">${x.valid ? '🟢' : '🟠'} ${esc(x.label)}</button>`).join('')}</div>
        <div class="section"><h2>Nouvelle arène (à ta position)</h2>
            <p class="hint">Va à l'endroit de l'arène, crée-la, puis ajoute les points d'apparition de chaque équipe (un par joueur, en te tournant dans la direction voulue)
                et les <b>coins de la zone</b> dans l'ordre du contour (3 minimum). La première arène créée ici remplace les exemples de config.lua.</p>
            <div class="form-grid" style="grid-template-columns:200px 1fr auto;max-width:720px;align-items:end">
                <div><label>Identifiant</label><input class="input" id="pvp-new-id" placeholder="docks" maxlength="30"></div>
                <div><label>Nom affiché</label><input class="input" id="pvp-new-label" placeholder="Docks du port" maxlength="40"></div>
                <button class="btn primary" data-pnew>Créer ici</button></div></div>
        ${!a ? '<div class="empty">Aucune arène.</div>' : `<div class="card recipe">
            <div class="card-head"><strong>${esc(a.label)} <span class="muted">(${esc(a.id)})</span></strong>
                <span>${a.valid ? '<b style="color:var(--success,#4caf50)">Prête</b>' : `<b style="color:var(--danger)">Incomplète : ${esc(a.why || '')}</b>`}</span></div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(170px,1fr))">
                <div><label>Nom affiché</label><input class="input" data-pa="label" value="${esc(d.label)}" maxlength="40"></div>
                <div><label>Hauteur minimum (z)</label><input class="input" type="number" step="0.5" data-pa="minZ" value="${esc(d.minZ)}"></div>
                <div><label>Hauteur maximum (z)</label><input class="input" type="number" step="0.5" data-pa="maxZ" value="${esc(d.maxZ)}"></div>
                <div><label>Heure forcée (0-23, vide = serveur)</label><input class="input" type="number" min="0" max="23" data-pa="time" value="${esc(d.time)}"></div>
                <div><label>Météo forcée (vide = serveur)</label><select class="input" data-pa="weather">${['', 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'FOGGY', 'RAIN', 'THUNDER', 'SMOG', 'SNOW']
                    .map((w) => `<option value="${w}" ${w === d.weather ? 'selected' : ''}>${w || '—'}</option>`).join('')}</select></div>
            </div>
            <div class="btn-row" style="margin-top:10px">
                <button class="btn primary" data-pact="arena_edit">💾 Enregistrer</button>
                <button class="btn" data-padd="floor">⬇️ Sol = ma position − 2 m</button><button class="btn" data-padd="ceiling">⬆️ Plafond = ma position + 2 m</button>
                <button class="btn" data-padd="center">🎯 Centre = ma position</button>
                <button class="btn" data-pact="arena_show">👁️ Voir la zone (60 s)</button><button class="btn" data-ptp="center" data-i="1">🚀 Aller au centre</button>
                <button class="btn danger" data-pact="arena_delete">🗑 Supprimer l'arène</button></div>
            <table class="loot wide" style="margin-top:12px"><tr><th>Point</th><th>Position</th><th>Orientation</th><th></th></tr>
                ${pointRows(a, 'A', a.spawns.A || [], `Apparitions ${esc((D.pvp.settings.teams.A || {}).name || 'A')}`)}
                ${pointRows(a, 'B', a.spawns.B || [], `Apparitions ${esc((D.pvp.settings.teams.B || {}).name || 'B')}`)}
                ${pointRows(a, 'corner', a.zone.points || [], 'Coins de la zone de combat')}
                ${pointRows(a, 'safe', a.safe || [], 'Points sûrs (retour en cas de sortie de zone, facultatif)')}
            </table>
            <p class="hint">Un joueur qui sort de la zone (polygone + hauteur) est replacé sur un point sûr, sinon sur une apparition de son équipe. Les points d'apparition
                se posent à <b>ta</b> position et dans <b>ta</b> direction. Mets au moins autant d'apparitions que de joueurs par équipe.</p></div>`}`;
    }

    /* -------------------------------------------------- réglages */
    function viewSettings(p) {
        const s = P.sdraft || (P.sdraft = clone(p.settings));
        const dis = new Set(s.disabledWeapons || []);
        const cats = [...new Set(p.weapons.map((w) => w.cat))];
        return `<div class="section"><h2>Argent</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                ${tile('bet.enabled', 'Paris activés', 'Joueurs et spectateurs parient sur l\'équipe gagnante (pari mutuel).', s.bet.enabled)}
                ${tile('leaverForfeits', 'Un joueur qui part perd sa part', 'Sa mise reste dans le pot, partagée entre les gagnants restants.', s.leaverForfeits)}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr))">
                ${sel('account', 'Compte débité / crédité', s.account, [['bank', 'Banque'], ['cash', 'Liquide']])}
                ${numF('stake.min', 'Mise minimum ($)', s.stake.min, 0, 100000000)}
                ${numF('stake.max', 'Mise maximum ($)', s.stake.max, 0, 1000000000)}
                ${numF('stake.step', 'Pas de la mise ($)', s.stake.step, 1, 1000000)}
                ${numF('bet.min', 'Pari minimum ($)', s.bet.min, 1, 100000000)}
                ${numF('bet.max', 'Pari maximum ($)', s.bet.max, 1, 1000000000)}
                ${numF('fee.stake', 'Commission sur les mises (%)', s.fee.stake, 0, 50, 0.5)}
                ${numF('fee.bet', 'Commission sur les paris (%)', s.fee.bet, 0, 50, 0.5)}
                ${sel('participantBets', 'Paris des participants', s.participantBets, [['own', 'Seulement sur leur équipe'], ['none', 'Interdits'], ['any', 'Sur n\'importe quelle équipe']])}
                ${sel('abandon', 'Une équipe entière abandonne', s.abandon, [['forfeit', 'Victoire de l\'autre équipe (forfait)'], ['cancel', 'Partie annulée, tout remboursé']])}
            </div></div>
        <div class="section"><h2>Parties et manches</h2>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                ${tile('requireFull', 'Équipes complètes pour lancer', 'Sinon : équipes égales suffisent (ex. 2 contre 2 dans un 5 contre 5).', s.requireFull)}
                ${tile('allowFF', 'L\'hôte peut activer les dégâts alliés', '', s.allowFF)}</div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr))">
                ${numF('maxLobbies', 'Parties simultanées maximum', s.maxLobbies, 1, 30)}
                ${sel('defaultWins', 'Manches à gagner (par défaut)', s.defaultWins, p.winsOptions.map((w) => [w, `Premier à ${w}`]))}
                ${sel('defaultRoundTime', 'Durée d\'une manche (par défaut)', s.defaultRoundTime, p.roundTimes.map((r) => [r, `${r} s`]))}
                ${sel('timeoutRule', 'Fin du temps de manche', s.timeoutRule, [['most_alive', 'Plus de joueurs vivants, puis plus de vie'], ['draw', 'Manche nulle']])}
                ${numF('idle', 'Lobby fermé après (s sans lancement)', s.idle, 60, 86400)}
                ${numF('maxExits', 'Sorties de zone tolérées par manche', s.maxExits, 0, 20)}
                ${numF('timers.weaponSelect', 'Choix de l\'arme (s)', s.timers.weaponSelect, 5, 60)}
                ${numF('timers.countdown', 'Décompte avant la manche (s)', s.timers.countdown, 1, 10)}
                ${numF('timers.roundEnd', 'Affichage fin de manche (s)', s.timers.roundEnd, 2, 20)}
                ${numF('timers.matchEnd', 'Écran de fin avant retour au RP (s)', s.timers.matchEnd, 3, 60)}
                ${numF('timers.teleportGrace', 'Tolérance après téléportation (s)', s.timers.teleportGrace, 1, 15)}
                ${numF('timers.loading', 'Chargement après téléportation (s)', s.timers.loading, 0.5, 10, 0.5)}
            </div></div>
        <div class="section"><h2>Combat</h2>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr))">
                ${numF('health', 'Vie au début de la manche (101-200)', s.health, 101, 200)}
                ${numF('armor', 'Gilet au début de la manche (0-100)', s.armor, 0, 100)}
                ${numF('ammo', 'Munitions données (illimitées)', s.ammo, 30, 9999)}
                ${sel('defaultWeapon', 'Arme si pas de choix', s.defaultWeapon, p.weapons.filter((w) => !dis.has(w.name)).map((w) => [w.name, w.label]))}
            </div>
            <h3 class="sub-h" style="margin-top:14px">Armes disponibles</h3>
            ${cats.map((c) => `<div class="muted" style="margin:8px 0 4px">${esc(c)}</div><div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr))">
                ${p.weapons.filter((w) => w.cat === c).map((w) => `<div class="tile toggle-tile ${dis.has(w.name) ? '' : 'on'}" data-pw="${esc(w.name)}"><div><strong>${esc(w.label)}</strong><span>${esc(w.name)}</span></div><div class="switch"></div></div>`).join('')}</div>`).join('')}
        </div>
        <div class="section"><h2>Équipes</h2>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr));max-width:900px">
                <div><label>Nom équipe A</label><input class="input" data-pt="teams.A.name" value="${esc(s.teams.A.name)}" maxlength="16"></div>
                <div><label>Couleur équipe A</label><input class="input" type="color" data-pt="teams.A.color" value="${esc(s.teams.A.color)}"></div>
                <div><label>Nom équipe B</label><input class="input" data-pt="teams.B.name" value="${esc(s.teams.B.name)}" maxlength="16"></div>
                <div><label>Couleur équipe B</label><input class="input" type="color" data-pt="teams.B.color" value="${esc(s.teams.B.color)}"></div>
            </div></div>
        <div class="btn-row"><button class="btn primary" data-pact="settings_save">💾 Enregistrer (appliqué tout de suite)</button>
            <button class="btn" data-pact="settings_cancel">Annuler les modifications</button>
            <button class="btn danger" data-pact="settings_reset">Revenir à config.lua</button></div>
        <p class="hint">Les réglages sont gardés dans <b>pvp_arena/data/settings.json</b>. Les parties déjà lancées gardent leurs règles d'équipe ; les délais et l'argent s'appliquent dès la prochaine étape.
            Les instances utilisées sont les buckets ${p.bucketBase + 1} et suivants.${p.npcFallback ? ' Le PNJ de secours de config.lua est activé.' : ' PNJ : rôle « ⚔️ Arène PvP » dans l\'éditeur de map.'}</p>`;
    }

    /* -------------------------------------------------- historique */
    function viewHistory(p) {
        const ST = { held: 'en jeu', paid: 'payé', lost: 'perdu', refunded: 'remboursé' };
        const KD = { stake: 'Mises', bet: 'Paris' };
        const rows = p.history || [];
        return `<div class="section"><h2>Argent (toutes les parties)</h2><table class="loot wide"><tr><th>Type</th><th>Statut</th><th>Lignes</th><th>Montant</th><th>Versé</th></tr>
            ${(p.money || []).map((m) => `<tr><td>${KD[m.kind] || esc(m.kind)}</td><td>${ST[m.status] || esc(m.status)}</td><td>${fmt(m.n)}</td><td>${fmt(m.amount)} $</td><td>${fmt(m.payout)} $</td></tr>`).join('') || '<tr><td colspan="5" class="muted">Aucune transaction.</td></tr>'}
            </table>
            <p class="hint">${p.pending && p.pending.n ? `<b>${fmt(p.pending.n)} paiement(s) en attente</b> (${fmt(p.pending.amount)} $) : versés à la prochaine connexion des joueurs concernés.` : 'Aucun paiement en attente.'}
                Chaque ligne n'est réglée qu'une fois (table pvp_ledger).</p></div>
        <div class="section"><h2>Dernières parties</h2>
            <div class="btn-row" style="margin-bottom:8px"><button class="btn" data-pact="stats_refresh">🔄 Actualiser</button>
                <span class="muted" style="align-self:center">Mis à jour à ${p.statsAt ? new Date(p.statsAt * 1000).toLocaleTimeString('fr-FR') : '—'}</span></div>
            <table class="loot wide"><tr><th>Partie</th><th>Arène</th><th>Format</th><th>Score</th><th>Gagnant</th><th>Statut</th><th>Mises</th><th>Paris</th><th>Date</th></tr>
            ${rows.map((r) => `<tr><td>${esc(r.uid)}</td><td>${esc(r.arena)}</td><td>${esc(r.mode)} · à ${r.wins}</td><td>${r.score_a} – ${r.score_b}</td>
                <td>${r.winner ? team(r.winner) : '—'}</td><td>${esc({ running: 'en cours', finished: 'terminée', cancelled: 'annulée', aborted: 'interrompue' }[r.status] || r.status)}</td>
                <td>${fmt(r.stake_pot)} $</td><td>${fmt(r.bet_pot)} $</td><td>${r.created_at ? esc(new Date(typeof r.created_at === 'number' ? r.created_at * 1000 : r.created_at).toLocaleString('fr-FR')) : ''}</td></tr>`).join('')
                || '<tr><td colspan="9" class="muted">Aucune partie jouée.</td></tr>'}</table></div>`;
    }

    VIEWS.pvp = () => {
        const p = D.pvp;
        if (!p.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(p.resource || 'pvp_arena')}</b> ${p.loading ? 'démarre…' : 'ne répond pas'}${p.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (p.denied) return '<div class="protect">⛔ <span>Permission « pvp_manage » refusée par pvp_arena.</span></div>';
        const nav = `<div class="btn-row" style="margin-bottom:14px">${SUBS.map(([k, l]) => `<button class="btn ${P.sub === k ? 'primary' : ''}" data-psub="${k}">${l}</button>`).join('')}</div>`;
        const body = P.sub === 'arenas' ? viewArenas(p) : P.sub === 'settings' ? viewSettings(p) : P.sub === 'history' ? viewHistory(p) : viewLive(p);
        return nav + body;
    };

    /* -------------------------------------------------- événements */
    const on = () => isOpen && tab === 'pvp' && D && D.pvp && D.pvp.available;
    const later = () => setTimeout(() => post('refresh'), 400);
    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-psub],[data-parena],[data-pnew],[data-padd],[data-preset],[data-pdel],[data-ptp],[data-pact],[data-pk],[data-pw],[data-pkick],[data-pkickid],[data-pcancel]');
        if (!t) return;
        if (t.dataset.psub) { P.sub = t.dataset.psub; if (P.sub !== 'settings') P.sdraft = null; return render(); }
        if (t.dataset.parena) { P.arena = t.dataset.parena; P.adraft = null; return render(); }
        if (t.dataset.pnew !== undefined) {
            const id = (document.getElementById('pvp-new-id') || {}).value || '';
            const label = (document.getElementById('pvp-new-label') || {}).value || '';
            P.arena = id.toLowerCase().replace(/[^a-z0-9_]/g, ''); P.adraft = null;
            send('arena_new', { id, label }); return later();
        }
        if (t.dataset.padd) { send('arena_add', { id: P.arena, what: t.dataset.padd }); return later(); }
        if (t.dataset.preset) { if (await confirmBox('Effacer ces points ?', 'Ils seront supprimés de l\'arène.')) { send('arena_reset', { id: P.arena, what: t.dataset.preset }); later(); } return; }
        if (t.dataset.pdel) { send('arena_point_delete', { id: P.arena, what: t.dataset.pdel, index: Number(t.dataset.i) }); return later(); }
        if (t.dataset.ptp) return send('arena_tp', { id: P.arena, what: t.dataset.ptp, index: Number(t.dataset.i) });
        if (t.dataset.pkick) { if (await confirmBox('Sortir ce joueur ?', 'Il est renvoyé au RP (position et instance d\'avant). S\'il était en partie, sa mise reste dans le pot.')) { send('player_kick', { id: Number(t.dataset.pkick) }); later(); } return; }
        if (t.dataset.pkickid !== undefined) { const id = Number((document.getElementById('pvp-kick-id') || {}).value); if (id) { send('player_kick', { id }); later(); } return; }
        if (t.dataset.pcancel) { if (await confirmBox('Annuler cette partie ?', 'Les joueurs retournent au RP, toutes les mises et tous les paris sont remboursés.')) { send('match_cancel', { uid: t.dataset.pcancel }); later(); } return; }
        if (t.dataset.pk) { const s = P.sdraft; setPath(s, t.dataset.pk, !getPath(s, t.dataset.pk)); return render(); }
        if (t.dataset.pw) { const s = P.sdraft; const set = new Set(s.disabledWeapons || []); if (set.has(t.dataset.pw)) set.delete(t.dataset.pw); else set.add(t.dataset.pw); s.disabledWeapons = [...set]; return render(); }
        const a = t.dataset.pact;
        if (a === 'arena_edit') { send('arena_edit', P.adraft); return later(); }
        if (a === 'arena_show') return send('arena_show', { id: P.arena });
        if (a === 'arena_delete') { if (await confirmBox('Supprimer cette arène ?', 'Ses points d\'apparition et sa zone seront effacés.')) { send('arena_delete', { id: P.arena }); P.arena = null; later(); } return; }
        if (a === 'settings_save') { send('settings_save', { settings: P.sdraft }); P.sdraft = null; return later(); }
        if (a === 'settings_cancel') { P.sdraft = null; return render(); }
        if (a === 'settings_reset') { if (await confirmBox('Revenir aux réglages de config.lua ?', 'Les réglages faits dans le menu seront effacés.')) { send('settings_reset'); P.sdraft = null; later(); } return; }
        if (a === 'stats_refresh') { send('stats_refresh'); return setTimeout(() => post('refresh'), 1500); }
    });
    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.pn) setPath(P.sdraft, t.dataset.pn, t.value === '' ? '' : Number(t.value));
        else if (t.dataset.pt) setPath(P.sdraft, t.dataset.pt, t.value);
        else if (t.dataset.pa && P.adraft) P.adraft[t.dataset.pa] = t.value;
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.ps) { const v = t.value; setPath(P.sdraft, t.dataset.ps, /^\d+$/.test(v) ? Number(v) : v); }
        else if (t.dataset.pa && P.adraft) P.adraft[t.dataset.pa] = t.value;
    });
})();
