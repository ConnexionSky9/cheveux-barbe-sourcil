/* =========================================================
   ONGLET 🚘 ADMINISTRATION AUTOMOBILE (permission « dealer_manage »)
   Ouvre le panneau de la ressource elyzea_concess : catalogue global,
   catégories, concessions (métier, compte, points, exposition, catalogue
   propre à chaque concession : catégories, modèles, prix).
   ========================================================= */
(() => {
    TABS.push({
        id: 'dealer', group: 5, label: 'Administration automobile', ico: '🚘',
        sub: 'Concessions : catalogue global, catégories, configuration et prix de chaque concession.',
        show: () => has('dealer_manage'),
    });

    VIEWS.dealer = () => `<div class="section"><h2>Administration automobile</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_concess</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/concessadmin</span>.</p>
        <button class="btn primary big" data-dealer="open">🚘 Ouvrir l'administration automobile</button></div>
      <div class="section"><h2>Mise en place d'une concession</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li><b>Modèles</b> : ajoute les véhicules au catalogue global (recherche dans le jeu, modèle vérifié), avec leur catégorie et un prix de référence.</li>
        <li><b>Concessions</b> › « + Nouvelle » : nom, métier, compte de société (créés automatiquement).</li>
        <li><b>Catégories</b> puis <b>Modèles et prix</b> de la concession : activé, visible, vendable, exposable, prix propre.</li>
        <li><b>Réglages et points</b> : point de consultation du catalogue, aperçu, gestion, places de sortie ; <b>Exposition</b> : emplacements.</li>
        <li>Nomme un responsable (ID du joueur), puis <b>Ouvrir</b> la concession.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-dealer]');
        if (n && n.dataset.dealer === 'open') post('dealer_open');
    });
})();
