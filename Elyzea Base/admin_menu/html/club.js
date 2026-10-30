/* =========================================================
   ONGLET 🪩 BOÎTES DE NUIT (permissions « Boîtes de nuit » : club_manage = tout, ou case par case)
   Ouvre le panneau de la ressource elyzea_club : créer plusieurs
   boîtes (métier, compte), placer leurs points, nommer le patron.
   ========================================================= */
(() => {
    TABS.push({
        id: 'club', group: 5, label: 'Boîtes de nuit', ico: '🪩',
        sub: 'Plusieurs boîtes de nuit : métier, compte, points (entrée, bar, coffre), patron, enceintes.',
        // Visible avec « tout » ou au moins une case « Boîtes de nuit » ; chaque action est revérifiée par elyzea_club
        show: () => ['club_manage', 'club_view', 'club_edit', 'club_points', 'club_boss', 'club_toggle', 'club_delete', 'club_music'].some((k) => has(k)),
    });

    VIEWS.club = () => `<div class="section"><h2>Boîtes de nuit</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_club</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/clubadmin</span>.</p>
        <button class="btn primary big" data-club="open">🪩 Ouvrir l'administration des boîtes</button>
        <p class="hint" style="margin-top:10px">Droits : réglés rang par rang dans l'éditeur de grades du menu admin (catégorie Métiers, cases « Boîtes de nuit »). Une action non cochée est masquée et refusée.</p></div>
      <div class="section"><h2>Mise en place d'une boîte</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li><b>+ Nouvelle boîte</b> : nom, métier et compte de société (créés automatiquement), 5 grades (Serveur, Videur, DJ, Gérant, Patron).</li>
        <li><b>Points</b> : place-toi à l'endroit voulu puis « Placer ici » : <b>Entrée</b> et <b>Bar</b> (obligatoires), Intérieur, Coffre, Bureau.</li>
        <li><b>Nommer le patron</b> (ID du joueur), puis <b>Activer</b> la boîte.</li>
        <li>Le patron fait le reste en jeu : ouverture au public, prix d'entrée, carte et stock du bar, enceintes, playlist,
          et choisit dans <b>Direction › Permissions</b> quels grades peuvent utiliser les enceintes.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-club]');
        if (n && n.dataset.club === 'open') post('club_open');
    });
})();
