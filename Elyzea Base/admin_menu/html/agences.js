/* =========================================================
   ONGLET 🏢 AGENCES DES MÉTIERS (permission « agencies_manage »)
   Ouvre le panneau de la ressource elyzea_agences : plusieurs polices,
   EMS, garages mécano et agences Dynasty 8, chacune avec son métier,
   ses grades, son téléphone de service et sa zone d'alerte.
   ========================================================= */
(() => {
    TABS.push({
        id: 'agences', group: 5, label: 'Agences des métiers', ico: '🏢',
        sub: 'Plusieurs polices, EMS, mécanos, Dynasty 8 : métier, téléphone de service et zone d\'alerte de chacune.',
        show: () => has('agencies_manage'),
    });

    VIEWS.agences = () => `<div class="section"><h2>Agences des métiers</h2>
        <p class="hint">Le panneau s'ouvre en jeu (ressource <b>elyzea_agences</b>). Tu peux aussi l'ouvrir avec <span class="keycap">/agences</span>.</p>
        <button class="btn primary big" data-agences="open">🏢 Ouvrir les agences</button></div>
      <div class="section"><h2>Créer une deuxième police (ou EMS, mécano, Dynasty 8)</h2><ol class="hint" style="line-height:1.7;padding-left:18px">
        <li>Choisis le métier en haut (Police, EMS…), puis <b>+ Nouvelle agence</b> : nom (ex. Blaine County Sheriff), nom court, métier (ex. <b>bcso</b>), préfixe des matricules, préfixe du téléphone de service, couleur.</li>
        <li>Grades par défaut, métier et compte de société sont créés tout seuls : la tablette, le F6, la paie et la direction marchent comme pour la première agence.</li>
        <li><b>Dessiner la zone sur la carte</b> (clic = un coin) ou <b>Dessiner en jeu</b> (outil de l'éditeur de map, coin par coin) : les alertes dans la zone ne vont qu'à cette agence.</li>
        <li>Nomme son directeur (ID du joueur) : il recrute ensuite lui-même.</li></ol></div>`;

    document.addEventListener('click', (ev) => {
        const n = ev.target.closest('[data-agences]');
        if (n && n.dataset.agences === 'open') post('agences_open');
    });
})();
