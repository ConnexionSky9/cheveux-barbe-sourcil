/* =========================================================
   ONGLET 🪩 BOÎTES DE NUIT (permission « club_manage »)
   Ouvre le panneau de la ressource elyzea_club : créer plusieurs
   boîtes (métier, compte), placer leurs points, nommer le patron.
   ========================================================= */
(() => {
    TABS.push({
        id: 'club', group: 5, label: 'Boîtes de nuit', ico: '🪩',
        sub: 'Plusieurs boîtes de nuit : métier, compte, points (entrée, bar, coffre), patron, enceintes.',
        show: () => has('club_manage'),
    });

    VIEWS.club = () => `<div class="section"><h2>Boîtes de nuit</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_club</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/clubadmin</span>.</p>
        <button class="btn primary big" data-club="open">🪩 Ouvrir l'administration des boîtes</button></div>
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
