/* =========================================================
   ONGLET 🏠 GESTION IMMOBILIÈRE (permission « property_manage »)
   Ouvre le panneau de la ressource elyzea_dynasty : biens (appartements,
   maisons, villas, garages), intérieurs, points, garages, contrats.
   ========================================================= */
(() => {
    TABS.push({
        id: 'dynasty', group: 5, label: 'Gestion immobilière', ico: '🏠',
        sub: 'Dynasty 8 : créer et configurer les biens, intérieurs, points et garages.',
        show: () => has('property_manage'),
    });

    VIEWS.dynasty = () => `<div class="section"><h2>Gestion immobilière</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_dynasty</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/d8admin</span>.</p>
        <button class="btn primary big" data-d8="open">🏠 Ouvrir la gestion immobilière</button></div>
      <div class="section"><h2>Mise en place d'un bien</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li>« + Nouveau » : nom, adresse, catégorie, intérieur, prix (le bien est créé désactivé).</li>
        <li>Place l'entrée (et la sonnette) devant la porte, à ta position.</li>
        <li>« Aller à l'intérieur » puis place la sortie (rouge), la zone de gestion (bleue) et le coffre (orange).</li>
        <li>Garage : taille, capacité, intérieur, puis entrée, sortie des véhicules, arrivée, sortie et les places.</li>
        <li>Active le bien : il apparaît dans la tablette des agents Dynasty 8.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-d8]');
        if (n && n.dataset.d8 === 'open') post('d8_open');
    });
})();
