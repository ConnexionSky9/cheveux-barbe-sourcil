/* BLACKPHONE - application Réglages : fond d'écran, sons, volume, luminosité (enregistrés sur le PC du joueur) */
(() => {
  const P = window.BPPhone;
  const WPS = [['noir', 'Noir profond'], ['trame', 'Trame'], ['rouge', 'Rouge sombre']];
  P.registerApp({
    id: 'settings', name: 'Réglages', order: 90, icon: P.api.icon('settings', 26),
    render(el, api) {
      const p = api.prefs;
      const draw = () => {
        el.innerHTML = `<div class="group"><h3>Fond d'écran</h3><div class="wps">${WPS.map(([k, l]) => `<div class="w wp-${k} ${p.wallpaper === k ? 'on' : ''}" data-wp="${k}" title="${l}" style="position:relative"></div>`).join('')}</div></div>
          <div class="group"><h3>Son</h3>
            <div class="row">${api.icon('sound', 18)}<span class="lb">Sons de l'interface</span><div class="tog ${p.sounds ? 'on' : ''}" data-tog="sounds"></div></div>
            <div class="row"><span class="lb" style="flex:none;width:70px">Volume</span><input type="range" min="0" max="100" value="${p.volume}" data-range="volume"></div></div>
          <div class="group"><h3>Affichage</h3>
            <div class="row">${api.icon('sun', 18)}<input type="range" min="40" max="100" value="${p.brightness}" data-range="brightness"></div></div>`;
        el.querySelectorAll('[data-wp]').forEach((n) => { n.onclick = () => { p.wallpaper = n.dataset.wp; api.save(); api.tick(); draw(); }; });
        el.querySelectorAll('[data-tog]').forEach((n) => { n.onclick = () => { p[n.dataset.tog] = !p[n.dataset.tog]; api.save(); api.tick(); draw(); }; });
        el.querySelectorAll('[data-range]').forEach((n) => { n.oninput = () => { p[n.dataset.range] = Number(n.value); api.save(); }; n.onchange = () => api.tick(); });
      };
      draw();
    },
  });
})();
