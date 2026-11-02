/* =========================================================
   ONGLET 🍽️ RESTAURANTS (permissions « Restaurants » : resto_manage = tout, ou case par case)
   Ouvre le panneau de la ressource elyzea_restaurant : créer plusieurs
   restaurants (métier, compte, logo), placer le point de commande et les
   stations de cuisine, nommer le patron, voir / annuler les commandes.
   ========================================================= */
(() => {
    TABS.push({
        id: 'resto', group: 5, label: 'Restaurants', ico: '🍽️',
        sub: 'Plusieurs restaurants : métier, compte, logo, point de commande, stations de cuisine, produits vendus, paiements (dont pesos), patron, commandes.',
        // Visible avec « tout » ou au moins une case « Restaurants » ; chaque action est revérifiée par elyzea_restaurant
        show: () => ['resto_manage', 'resto_view', 'resto_edit', 'resto_points', 'resto_boss', 'resto_toggle', 'resto_delete', 'resto_orders', 'resto_menu'].some((k) => has(k)),
    });

    VIEWS.resto = () => `<div class="section"><h2>Restaurants</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_restaurant</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/restoadmin</span>.</p>
        <button class="btn primary big" data-resto="open">🍽️ Ouvrir l'administration des restaurants</button>
        <p class="hint" style="margin-top:10px">Droits : réglés rang par rang dans l'éditeur de grades du menu admin (catégorie Métiers, cases « Restaurants »).</p></div>
      <div class="section"><h2>Mise en place d'un restaurant</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li><b>+ Nouveau restaurant</b> : nom, logo, couleur, métier et compte de société (créés automatiquement), 5 grades (Commis, Cuisinier, Serveur, Gérant, Patron).</li>
        <li><b>Points</b> : place-toi à l'endroit voulu puis « Placer ici » : <b>Point de commande</b> (obligatoire), Coffre, Bureau.</li>
        <li><b>Stations de cuisine</b> (au moins une) : coche ses types (grill, four, friteuse, fontaine, pâtisserie) puis « Poser ici ».</li>
        <li><b>🍽️ Répartition des plats</b> (en haut à gauche du panneau) : un tableau avec <b>chaque plat</b> (les 80 recettes + burgers, boissons…) et <b>chaque restaurant</b> ; coche une case = ce restaurant vend ce plat, tout de suite. « ✓ tout » met en vente tous les plats affichés (ex. toute la catégorie Restaurant italien).</li>
        <li><b>Produits vendus</b> (fiche d'un restaurant) : même choix restaurant par restaurant ; coche ce que ce restaurant a le droit de vendre (burgers, pizzas… et les 80 recettes italiennes, fast-food, japonaises et mexicaines de <b>elyzea_cuisine</b>). Chaque produit indique la station de cuisine qu'il demande.</li>
        <li><b>Paiements</b> : banque, espèces et/ou <b>pesos</b> (les pesos payés vont dans le coffre du restaurant).</li>
        <li><b>Nommer le patron</b> (ID du joueur), puis <b>Activer</b> le restaurant.</li>
        <li>Le patron règle la carte et les prix dans la tablette (parmi les produits autorisés) ; les employés reçoivent les commandes dans l'appli <b>Commande</b> du téléphone de service.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-resto]');
        if (n && n.dataset.resto === 'open') post('resto_open');
    });
})();
