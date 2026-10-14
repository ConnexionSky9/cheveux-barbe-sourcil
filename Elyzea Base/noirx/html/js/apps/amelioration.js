/* NOIR X — Amélioration */
(function () {
  'use strict';
  const h = NX.h;
  let host = null;
  const sections = [
    {key:'policeRadiusLevel',title:'Portée du hack police',desc:'Distance maximale du commissariat.',vals:['500 m','600 m','700 m','800 m','900 m','1 km']},
    {key:'defenseLevel',title:'Défense automatique',desc:'Chance de repousser une attaque immédiatement.',vals:['0 %','5 %','10 %','15 %','20 %','25 %']},
    {key:'revealLevel',title:'Précision de la révélation',desc:'Rayon de recherche du pirate après une défense réussie.',vals:['Position exacte','50 m','100 m','150 m','200 m','250 m']},
    {key:'intelLevel',title:'Informations des PNJ',desc:'Débloque progressivement de nouveaux renseignements.',vals:['Vente et achat','Prix et filières de drogue','Points de farm d’armes','Tables d’armes légères','Tables d’armes moyennes','Tables d’armes lourdes']}
  ];
  function makeCard(section,data) {
    const level=Math.max(0,Math.min(5,Number(data.levels[section.key])||0));
    const card=h('div',{class:'card card--pad upgrade-card'});
    card.append(h('div',{class:'upgrade-card__top'},h('div',{},h('strong',{text:section.title}),h('p',{class:'muted',text:section.desc})),h('span',{class:'upgrade-level',text:`NIV. ${level}`})));
    card.append(h('div',{class:'upgrade-progress'},h('span',{style:`width:${level*20}%`})));
    card.append(h('div',{class:'upgrade-current',text:`Niveau actuel : ${section.vals[level]}`}));
    if(level<5){
      card.append(h('div',{class:'upgrade-next',text:`Prochain niveau : ${section.vals[level+1]}`}));
      const cost=(data.costs&&data.costs[level])||0;
      card.append(NX.ui.button(`Améliorer · ${NX.money(cost)}`,'primary',async()=>{
        const res=await NX.rpc('upgrades.buy',{upgrade:section.key});
        if(!res||!res.ok)return NX.notify('Amélioration',res&&res.message||'Achat impossible.','alert');
        NX.notify('Amélioration','Niveau amélioré.','success'); render(host);
      }));
    } else card.append(h('div',{class:'upgrade-max',text:'NIVEAU MAXIMUM ATTEINT'}));
    return card;
  }
  function render(target){
    host=target; host.textContent='';
    host.append(h('div',{class:'upgrade-hero'},h('div',{class:'upgrade-skull',text:'⬡'}),h('div',{class:'section-kicker',text:'NOIR X // PROGRESSION'}),h('h2',{class:'section-title',text:'Amélioration'}),h('p',{class:'muted',text:'Investis dans tes outils : portée, défense, discrétion et renseignements.'})));
    const loading=h('div',{class:'card card--pad',text:'Chargement des améliorations…'});host.append(loading);
    NX.rpc('upgrades.status',{}).then(data=>{
      if(!host||!host.contains(loading))return;loading.remove();
      if(!data||!data.ok){host.append(NX.ui.empty('alert','Progression indisponible',data&&data.message||'Serveur indisponible.'));return;}
      host.append(h('div',{class:'upgrade-wallet',text:`Solde : ${NX.money(data.balance)} · ${data.currency==='dirty'?'argent sale':'argent propre'}`}));
      sections.forEach(section=>host.append(makeCard(section,data)));
      host.append(h('p',{class:'muted upgrade-footnote',text:'Les renseignements PNJ et les bonus de gameplay nécessitent leur branchement aux ressources correspondantes.'}));
    });
  }
  NX.registerApp('amelioration',{title:'Amélioration',render,destroy(){host=null;}});
})();
