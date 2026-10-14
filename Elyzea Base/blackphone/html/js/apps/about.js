/* BLACKPHONE - application À propos : appareil, numéro de série, version */
(() => {
  const P = window.BPPhone;
  P.registerApp({
    id: 'about', name: 'À propos', order: 99, icon: P.api.icon('info', 26),
    render(el, api) {
      const l = api.brand.logo({ color: '#ececee', accent: '#b3161b' });
      el.innerHTML = `<div class="about"><svg class="lg" viewBox="-6 -6 ${l.width + 12} ${l.height + 12}">${l.svg}</svg></div>
        <div class="group"><h3>Appareil</h3>
          <div class="row"><span class="lb">Modèle</span><span class="vl">BLACKPHONE</span></div>
          <div class="row"><span class="lb">Numéro de série</span><span class="vl" style="font-family:monospace">${api.serial() || '—'}</span></div>
          <div class="row"><span class="lb">Version</span><span class="vl">1.0</span></div>
          <div class="row"><span class="lb">Batterie</span><span class="vl">${Math.round(api.prefs.battery)} %</span></div></div>`;
    },
  });
})();
