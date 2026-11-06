/* =========================================================
   LASERGAME (ressource elyzea_lasergame, permission « lasergame_manage »)
   Parties en cours (arrêter) · arènes créées en jeu (zone dessinée, apparitions, réglages, ouverture)
   · ouverture du panneau staff complet /lgadmin.
   Chaque action est revérifiée par elyzea_lasergame auprès d'admin_menu.
   ========================================================= */
(() => {
    TABS.push({
        id: 'lasergame', group: 5, label: 'LaserGame', ico: '🔫',
        sub: 'Parties PVP en cours (arrêter), arènes (créer à ta position, dessiner la zone, poser les apparitions, décorer avec l\'éditeur de map), puis le panneau staff complet.',
        show: () => has('lasergame_manage') && !!(D && D.lasergame),
        count: () => ((D && D.lasergame && D.lasergame.games) || []).length,
    });
    const PHASE = { lobby: '🟦 Salon', loading: '🟨 Chargement', countdown: '🟨 Décompte', round: '🟥 Manche en cours', round_end: '🟩 Fin de manche',
        ended: '🏁 Terminée', closed: 'Fermée' };
    const WEATHERS = ['', 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'FOGGY', 'RAIN', 'THUNDER', 'SMOG', 'SNOW', 'XMAS', 'HALLOWEEN'];
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const L = { sub: 'arenas', arena: null };
    let armed = null;   // confirmation d'une action dangereuse (deuxième clic)
    const arm = (key) => { armed = key; render(); setTimeout(() => { if (armed === key) { armed = null; render(); } }, 4000); };
    const send = (name, data = {}, later = 500) => { action('lasergame', { name, data }); if (later) setTimeout(() => post('refresh'), later); };

    // Silhouette de l'arène vue du dessus (coordonnées 0..100 calculées par elyzea_lasergame)
    const shape = (sh, size = 150) => {
        if (!sh || !sh.poly || sh.poly.length < 3) return `<div class="lg-shape" style="width:${size}px;height:${size}px"><span>zone à dessiner</span></div>`;
        const dots = (list, c) => (list || []).map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.8" fill="${c}" stroke="#fff" stroke-width=".7"/>`).join('');
        return `<div class="lg-shape" style="width:${size}px;height:${size}px"><svg viewBox="0 0 100 100" width="100%" height="100%"><polygon points="${sh.poly.map(([x, y]) => x + ',' + y).join(' ')}" fill="rgba(155,92,255,.22)" stroke="#B57BFF" stroke-width="1.6" stroke-linejoin="round"/>${dots(sh.A, '#FF2D46')}${dots(sh.B, '#288CFF')}</svg></div>`;
    };

    function gamesView(d) {
        const games = d.games || [];
        return games.length ? games.map((g) => `<div class="card">
                <div style="display:flex;justify-content:space-between;gap:10px;align-items:center;flex-wrap:wrap">
                    <div><b>⚔️ ${esc(g.name || g.uid)}</b>
                        <span class="zbadge">${PHASE[g.phase] || esc(g.phase || '')}</span>
                        <p class="hint" style="margin:4px 0 0">${esc(g.map || '')}${g.format ? ' · ' + esc(g.format) : ''}${g.round ? ' · manche ' + esc(g.round) : ''}${g.score ? ` · ${g.score.A ?? 0} - ${g.score.B ?? 0}` : ''}${g.stake ? ' · mise $' + fmt(g.stake) : ''} · hôte ${esc(g.host || '?')}</p></div>
                    <button class="btn danger" data-lgstop="${esc(g.uid)}">${armed === 'stop:' + g.uid ? '⚠️ Confirmer l\'arrêt' : '⛔ Arrêter'}</button></div>
                <p class="hint" style="margin:6px 0 0">${(g.players || []).map((p) => `${p.team === 'A' ? '🔴' : p.team === 'B' ? '🔵' : '🟣'} ${esc(p.name)} <small>(#${esc(p.id)})</small>`).join(' · ') || 'Aucun joueur'}</p></div>`).join('')
            : '<div class="empty">Aucune partie en cours.</div>';
    }

    function arenasView(d) {
        const list = d.arenas || [];
        const T = d.teams || { A: 'ROUGE', B: 'BLEUE' };
        // après « Créer ici » : la nouvelle arène est sélectionnée dès qu'elle apparaît dans la liste
        if (L.pending != null && list.length > L.pending) { L.arena = list[list.length - 1].id; L.pending = null; }
        if (!list.find((x) => x.id === L.arena)) L.arena = (list[0] || {}).id || null;
        const a = list.find((x) => x.id === L.arena);
        const chips = list.map((x) => `<button class="btn ${x.id === L.arena ? 'primary' : ''}" data-lgarena="${esc(x.id)}">${x.valid ? (x.enabled ? '🟢' : '⚪') : '🟠'} ${esc(x.label)}</button>`).join('');
        const head = `<div class="card">
            <p class="hint" style="margin:0 0 10px"><b>Créer une arène :</b> va à l'endroit voulu → <b>Créer ici</b> → <b>Dessiner la zone</b> (vise le sol pour chaque coin, ↑ ↓ plafond, ← → sol)
                → <b>Apparitions</b> de chaque équipe (vise le sol, la caméra donne la direction) → décore avec l'<b>Éditeur de map</b> → <b>Ouvrir aux joueurs</b>.
                Chaque partie se joue dans sa propre instance, les objets de l'éditeur y sont visibles. Plusieurs parties peuvent utiliser la même arène en même temps.</p>
            <div class="inline" style="max-width:520px"><input class="input" id="lg-new" maxlength="32" placeholder="Nom de la nouvelle arène"><button class="btn primary" data-lgnew>📍 Créer ici</button></div></div>
            ${list.length ? `<div class="btn-row" style="margin:12px 0">${chips}</div>` : '<div class="empty">Aucune arène pour le moment.</div>'}`;
        if (!a) return head;
        const st = a.valid ? (a.enabled ? '🟢 Ouverte aux joueurs' : '⚪ Fermée (prête)') : '🟠 Incomplète';
        const use = a.inUse ? ` · <b style="color:#f97362">${a.inUse === 'running' ? 'partie en cours' : 'lobby ouvert'}</b>` : '';
        const spawnRow = (team) => `<tr><td>${team === 'A' ? '🔴' : '🔵'} Apparitions ${esc(T[team])}</td><td><b>${a['spawns' + team]}</b> / 20</td>
            <td style="text-align:right"><button class="btn primary" data-lgspawn="${team}" ${a.corners >= 3 ? '' : 'disabled title="Dessine d\'abord la zone"'}>🎯 Placer en jeu (remplace)</button>
            ${a['spawns' + team] ? `<button class="btn" data-lgtp="${team}">🚀 Y aller</button><button class="btn danger" data-lgclear="${team}">${armed === 'clear:' + team ? '⚠️ Confirmer' : 'Effacer'}</button>` : ''}</td></tr>`;
        return head + `<div class="card">
            <div style="display:flex;gap:18px;align-items:flex-start;flex-wrap:wrap">${shape(a.shape, 170)}
            <div style="flex:1;min-width:280px"><h3 style="margin:0 0 4px">${esc(a.label)}</h3>
                <p class="hint" style="margin:0 0 8px">${st}${use} · ${esc(a.size)}${a.area ? ' · ' + fmt(a.area) + ' m²' : ''} · ${a.corners} coins · jusqu'à ${a.maxPerTeam} VS ${a.maxPerTeam}</p>
                ${a.issues && a.issues.length ? `<div class="protect" style="margin:0 0 10px">⚠️ <span>À faire : ${a.issues.map(esc).join(' · ')}</span></div>` : ''}
                <div class="btn-row">
                    <button class="btn ${a.enabled ? '' : 'primary'}" data-lgtoggle ${a.valid ? '' : 'disabled'}>${a.enabled ? '⏸ Fermer aux joueurs' : '▶️ Ouvrir aux joueurs'}</button>
                    <button class="btn" data-lgshow>👁️ Voir la zone (60 s)</button><button class="btn" data-lgtp="center">🚀 Aller au centre</button></div></div></div>
            <table class="loot wide" style="margin-top:14px">
                <tr><td>🟪 Zone de combat</td><td><b>${a.corners}</b> coins${a.zone && a.zone.minZ != null ? ` · sol ${a.zone.minZ} · plafond ${a.zone.maxZ}` : ''}</td>
                    <td style="text-align:right"><button class="btn primary" data-lgzone>✏️ Dessiner la zone en jeu</button>
                    ${a.corners ? `<button class="btn danger" data-lgclear="zone">${armed === 'clear:zone' ? '⚠️ Confirmer (efface aussi les apparitions)' : 'Effacer'}</button>` : ''}</td></tr>
                ${spawnRow('A')}${spawnRow('B')}
            </table></div>
            <div class="card"><h3 style="margin-top:0">Réglages</h3>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(210px,1fr))">
                <div><label>Nom affiché</label><input class="input" data-lgf="label" maxlength="32" value="${esc(a.label)}"></div>
                <div><label>Description (facultative)</label><input class="input" data-lgf="description" maxlength="160" value="${esc(a.description || '')}" placeholder="Entrepôt néon, deux étages…"></div>
                <div><label>Joueurs max. par équipe</label><select class="input" data-lgf="maxPerTeam">${[1, 2, 3, 4, 5, 6].map((n) => `<option value="${n}" ${n === a.maxPerTeam ? 'selected' : ''}>${n} VS ${n}</option>`).join('')}</select></div>
                <div><label>Heure forcée (0-23, vide = serveur)</label><input class="input" type="number" min="0" max="23" data-lgf="time" value="${a.time ?? ''}"></div>
                <div><label>Météo forcée</label><select class="input" data-lgf="weather">${WEATHERS.map((w) => `<option value="${w}" ${w === (a.weather || '') ? 'selected' : ''}>${w || 'Météo du serveur'}</option>`).join('')}</select></div>
                <div><label>Sol / plafond de la zone (z)</label><div class="inline"><input class="input" type="number" step="0.5" data-lgf="minZ" value="${a.zone?.minZ ?? ''}"><input class="input" type="number" step="0.5" data-lgf="maxZ" value="${a.zone?.maxZ ?? ''}"></div></div>
            </div>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-lgsave>💾 Enregistrer</button>
                <button class="btn" data-tab-go="editor" title="Onglet Éditeur de map : pose les objets autour de l'arène">🧱 Décorer avec l'éditeur de map</button>
                <button class="btn danger" data-lgdel>${armed === 'del:' + a.id ? '⚠️ Confirmer la suppression' : '🗑 Supprimer l\'arène'}</button></div>
            <p class="hint" style="margin-top:8px">Supprimer une arène ne retire pas les objets posés avec l'éditeur de map. Une arène utilisée par une partie ou un lobby ne peut pas être supprimée.</p></div>`;
    }

    VIEWS.lasergame = () => {
        const d = D.lasergame;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_lasergame')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_lasergame » dans server.cfg'}.</span></div>`;
        const st = d.stats || {};
        const nav = `<div class="btn-row" style="margin-bottom:14px">${[['arenas', `🗺️ Arènes (${(d.arenas || []).length})`], ['games', `🎮 Parties en cours (${(d.games || []).length})`]]
            .map(([k, l]) => `<button class="btn ${L.sub === k ? 'primary' : ''}" data-lgsub="${k}">${l}</button>`).join('')}
            <button class="btn" data-lgopen>🔫 Panneau LaserGame complet</button></div>`;
        return `${nav}<p class="hint" style="margin:0 0 12px">👥 <b>${fmt(st.players)}</b> joueurs · 🏁 <b>${fmt(st.matches)}</b> parties jouées · 💰 <b>$${fmt(st.held)}</b> de mises en jeu · le panneau complet (<b>/${esc(d.command || 'lgadmin')}</b>) règle les armes, les mises, les PNJ et les joueurs.</p>
            ${L.sub === 'games' ? gamesView(d) : arenasView(d)}`;
    };

    const val = (k) => { const el = document.querySelector(`[data-lgf="${k}"]`); return el ? el.value : undefined; };
    document.addEventListener('click', (ev) => {
        if (!isOpen || tab !== 'lasergame') return;
        const t = ev.target.closest('[data-lgopen],[data-lgstop],[data-lgsub],[data-lgarena],[data-lgnew],[data-lgzone],[data-lgspawn],[data-lgtp],[data-lgclear],[data-lgshow],[data-lgtoggle],[data-lgsave],[data-lgdel]');
        if (!t || t.disabled) return;
        const d = D.lasergame || {};
        const a = (d.arenas || []).find((x) => x.id === L.arena);
        const ds = t.dataset;
        if (ds.lgopen !== undefined) { action('lasergame', { name: 'open' }); post('close'); return; }
        if (ds.lgsub) { L.sub = ds.lgsub; return render(); }
        if (ds.lgarena) { L.arena = ds.lgarena; return render(); }
        if (ds.lgstop) {
            if (armed !== 'stop:' + ds.lgstop) return arm('stop:' + ds.lgstop);
            armed = null;
            return send('stop', { uid: ds.lgstop }, 600);
        }
        if (ds.lgnew !== undefined) {
            const label = (document.getElementById('lg-new') || {}).value || '';
            L.pending = (d.arenas || []).length;
            return send('arena_create', { label });
        }
        if (!a) return;
        if (ds.lgzone !== undefined) {
            const h = a.zone && a.zone.maxZ != null && a.zone.minZ != null ? Math.max(3, a.zone.maxZ - a.zone.minZ - 3) : 30;
            return editorPost('lg_zone_draw', { id: a.id, name: a.label, height: Math.min(h, 120), depth: 3, spawns: a.spawns });
        }
        if (ds.lgspawn) {
            const team = ds.lgspawn;
            return editorPost('lg_spawns_draw', { id: a.id, name: a.label, team, teamName: (d.teams || {})[team] || team, zone: a.zone, spawns: a.spawns });
        }
        if (ds.lgtp) return send('arena_tp', { id: a.id, what: ds.lgtp === 'center' ? 'center' : ds.lgtp, i: 1 }, 0);
        if (ds.lgshow !== undefined) { send('arena_show', { id: a.id }, 0); post('close'); return; }
        if (ds.lgclear) {
            if (armed !== 'clear:' + ds.lgclear) return arm('clear:' + ds.lgclear);
            armed = null;
            return send('arena_clear', { id: a.id, what: ds.lgclear });
        }
        if (ds.lgtoggle !== undefined) return send('arena_update', { id: a.id, enabled: !a.enabled });
        if (ds.lgsave !== undefined) {
            const num = (v) => (v === '' || v == null ? undefined : Number(v));
            return send('arena_update', { id: a.id, label: val('label'), description: val('description'), maxPerTeam: Number(val('maxPerTeam')),
                time: val('time'), weather: val('weather'), minZ: num(val('minZ')), maxZ: num(val('maxZ')) });
        }
        if (ds.lgdel !== undefined) {
            if (armed !== 'del:' + a.id) return arm('del:' + a.id);
            armed = null;
            return send('arena_delete', { id: a.id });
        }
    });

    // style de la silhouette (injecté une fois : aucun fichier CSS d'admin_menu modifié)
    const css = document.createElement('style');
    css.textContent = '.lg-shape{flex:none;border-radius:14px;overflow:hidden;display:grid;place-items:center;border:1px solid rgba(181,123,255,.35);'
        + 'background:repeating-linear-gradient(90deg,rgba(181,123,255,.08) 0 1px,transparent 1px 20px),repeating-linear-gradient(0deg,rgba(181,123,255,.08) 0 1px,transparent 1px 20px),#0a0518}'
        + '.lg-shape span{font-size:12px;color:rgba(255,255,255,.55)}.lg-shape svg{display:block}';
    document.head.appendChild(css);
})();
