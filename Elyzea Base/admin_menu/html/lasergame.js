/* =========================================================
   LASERGAME (ressource elyzea_lasergame, permission « lasergame_manage »)
   Parties en cours (arrêter) · ouverture du panneau staff complet /lgadmin
   Chaque action est revérifiée par elyzea_lasergame auprès d'admin_menu.
   ========================================================= */
(() => {
    TABS.push({
        id: 'lasergame', group: 5, label: 'LaserGame', ico: '🔫',
        sub: 'Parties PVP et Zombie en cours (arrêter), puis le panneau staff complet : armes, prix, cartes, PNJ, joueurs, classements, journaux.',
        show: () => has('lasergame_manage') && !!(D && D.lasergame),
        count: () => ((D && D.lasergame && D.lasergame.games) || []).length,
    });
    const PHASE = { lobby: '🟦 Salon', loading: '🟨 Chargement', countdown: '🟨 Décompte', round: '🟥 Manche en cours', round_end: '🟩 Fin de manche',
        intermission: '🟩 Pause entre deux manches', ended: '🏁 Terminée', closed: 'Fermée' };
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    let armed = null;   // confirmation de l'arrêt (deuxième clic)

    VIEWS.lasergame = () => {
        const d = D.lasergame;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_lasergame')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_lasergame » dans server.cfg'}.</span></div>`;
        const st = d.stats || {};
        const games = d.games || [];
        return `<div class="card">
            <div class="btn-row"><button class="btn primary" data-lgopen>🔫 Ouvrir le panneau LaserGame</button></div>
            <p class="hint" style="margin-top:8px">Le panneau complet s'ouvre par-dessus le jeu (aussi avec <b>/${esc(d.command || 'lgadmin')}</b>) : réglages PVP et mises, armes, mode Zombie, prix, cartes (aperçu, « Placer ici »), PNJ, joueurs (points, rang, exclusion), journaux.
                Accès réservé aux rangs qui ont la case <b>LaserGame</b> dans Staff › Rangs.</p>
            <p class="hint" style="margin-top:8px">👥 <b>${fmt(st.players)}</b> joueurs · 🏁 <b>${fmt(st.matches)}</b> parties jouées · 💰 <b>$${fmt(st.held)}</b> de mises en jeu</p></div>
            <h3 class="sub-h">🎮 Parties en cours</h3>
            ${games.length ? games.map((g) => `<div class="card">
                <div style="display:flex;justify-content:space-between;gap:10px;align-items:center;flex-wrap:wrap">
                    <div><b>${g.mode === 'zombie' ? '🧟 Zombie' : '⚔️ PVP'} · ${esc(g.name || g.uid)}</b>
                        <span class="zbadge">${PHASE[g.phase] || esc(g.phase || '')}</span>
                        <p class="hint" style="margin:4px 0 0">${esc(g.map || '')}${g.format ? ' · ' + esc(g.format) : ''}${g.round ? ' · manche ' + esc(g.round) : ''}${g.stake ? ' · mise $' + fmt(g.stake) : ''} · hôte ${esc(g.host || '?')}</p></div>
                    <button class="btn danger" data-lgstop="${esc(g.uid)}">${armed === g.uid ? '⚠️ Confirmer l\'arrêt' : '⛔ Arrêter'}</button></div>
                <p class="hint" style="margin:6px 0 0">${(g.players || []).map((p) => `${p.team === 'red' ? '🔴' : p.team === 'blue' ? '🔵' : '🟣'} ${esc(p.name)} <small>(#${esc(p.id)})</small>`).join(' · ') || 'Aucun joueur'}</p></div>`).join('')
            : '<div class="empty">Aucune partie en cours.</div>'}`;
    };

    document.addEventListener('click', (ev) => {
        if (!isOpen || tab !== 'lasergame') return;
        const t = ev.target.closest('[data-lgopen],[data-lgstop]');
        if (!t) return;
        if (t.dataset.lgopen !== undefined) { action('lasergame', { name: 'open' }); post('close'); return; }
        const uid = t.dataset.lgstop;
        if (armed !== uid) { armed = uid; render(); setTimeout(() => { if (armed === uid) { armed = null; render(); } }, 4000); return; }
        armed = null;
        action('lasergame', { name: 'stop', data: { uid } });
        setTimeout(() => post('refresh'), 600);
    });
})();
