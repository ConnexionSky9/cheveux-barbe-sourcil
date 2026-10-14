/* NOIR X — Attaque, accès aux signaux de blanchiment. */
(function () {
  'use strict';
  const h = NX.h;
  let body = null, busy = false;
  function fmt(n) { n = Math.max(0, Number(n) || 0); return `${Math.floor(n/60)} min ${n%60} s`; }
  function load() {
    if (!body) return;
    body.textContent = '';
    body.append(h('div',{class:'section-kicker',text:'RÉSEAU CLANDESTIN'}),h('h2',{class:'section-title',text:'Attaque'}),h('p',{class:'muted',text:'Repère un blanchiment actif et déclenche une intrusion. La cible reçoit une alerte et dispose de 60 secondes avant le duel.'}),NX.ui.loader());
    NX.rpc('breach.signals').then(res => {
      if (!body) return; body.textContent='';
      body.append(h('div',{class:'section-kicker',text:'RÉSEAU CLANDESTIN'}),h('h2',{class:'section-title',text:'Cibles actives'}));
      if (!res || !res.ok) { body.append(NX.ui.empty('alert','Réseau indisponible',res && res.message || 'Impossible de lire les signaux.')); return; }
      if (!res.enabled) { body.append(NX.ui.empty('alert','Attaques désactivées','Active playerInterception dans Config.Laundering.hack.')); return; }
      if (res.cooldown > 0) body.append(h('div',{class:'attack-cooldown',text:`Délai de sécurité : ${fmt(res.cooldown)}`}));
      if (!res.signals.length) body.append(NX.ui.empty('launder','Aucune cible','Aucun blanchiment attaquable pour le moment.'));
      res.signals.forEach(sig => {
        const card=h('div',{class:'card card--pad attack-target'});
        card.append(h('div',{class:'attack-target__top'},h('strong',{text:`Signal ${sig.id}`}),h('span',{class:'attack-tag',text:String(sig.band||'ACTIF').toUpperCase()})));
        card.append(h('p',{class:'muted',text:`Blanchiment actif · ${fmt(sig.remaining)} restantes`}));
        const btn=NX.ui.button('Attaquer cette cible','primary',async()=>{
          if(busy || res.cooldown>0) return; busy=true; btn.disabled=true; btn.textContent='Initialisation…';
          const out=await NX.rpc('breach.intercept',{signal:sig.id}); busy=false;
          if(!out || !out.ok){NX.fail(out||{message:'Attaque impossible.'});load();return;}
          if (out.repelled) NX.notify('Attaque repoussée','La défense automatique de la cible a bloqué ton intrusion.','alert');
          else NX.notify('Attaque','Intrusion préparée. Le duel commencera après le compte à rebours.','alert');
          load();
        });
        btn.disabled=busy || res.cooldown>0; card.append(btn); body.append(card);
      });
      body.append(NX.ui.button('Actualiser','ghost',load)); NX.applyIcons(body);
    });
  }
  NX.registerApp('attaque',{title:'Attaque',render(target){body=target;load();},destroy(){body=null;busy=false;}});
})();