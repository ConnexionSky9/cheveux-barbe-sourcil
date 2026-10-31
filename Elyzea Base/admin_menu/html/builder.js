/* =========================================================
   ONGLET 🏗️ BUILDER STUDIO (permissions « Builder Studio » : builder_manage = tout, ou case par case)
   Ouvre l'éditeur de construction et de mapping 3D (ressource builder_studio),
   qui revérifie chaque droit à chaque action.
   ========================================================= */
(() => {
    TABS.push({
        id: 'builder', group: 5, label: 'Builder Studio', ico: '🏗️',
        sub: 'Construction et mapping 3D en jeu : murs, immeubles, intérieurs, terrains, routes, textures importées, export.',
        show: () => ['builder_manage', 'builder_access'].some((k) => has(k)),
    });

    VIEWS.builder = () => `<div class="section"><h2>Builder Studio</h2>
        <p class="hint">Éditeur de construction en jeu (ressource <b>builder_studio</b>). Aussi accessible avec <span class="keycap">/mapping</span>.</p>
        <button class="btn primary big" data-builder="open">🏗️ Ouvrir le studio</button>
        <p class="hint" style="margin-top:10px">Droits : éditeur de grades du menu admin, catégorie Gestion, cases « Builder Studio »
          (ouvrir, construire, modifier, supprimer, importer objets et textures, exporter, TOUT). Les droits ACE builder.* restent valables.</p></div>
      <div class="section"><h2>Textures</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li>Dans le studio : panneau de droite › <b>Matériaux</b> › Bibliothèque de textures.</li>
        <li><b>Image du PC</b> (redimensionnée en 128 à 2048 px) ou <b>lien https</b> : disponible tout de suite, sans fichier à copier ni redémarrage.</li>
        <li><b>Remplacements du projet</b> : choisis la texture du jeu visée (dictionnaire|texture, ou un matériau du kit architectural) et l'image de la bibliothèque, puis Appliquer.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-builder]');
        if (n && n.dataset.builder === 'open') post('builder_open');
    });
})();
