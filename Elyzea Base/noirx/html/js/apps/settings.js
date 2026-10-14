/* NOIR X — application Réglages : fond d'écran, sons, informations de l'appareil. */
(function () {
  function row(iconName, label, control) {
    const r = document.createElement('div'); r.className = 'row';
    const i = NX.icon(iconName); i.classList.add('row__icon');
    const l = document.createElement('span'); l.className = 'row__label'; l.textContent = label;
    r.append(i, l);
    if (control) r.append(control);
    return r;
  }
  function sectionLabel(text) {
    const d = document.createElement('div'); d.className = 'section-label'; d.textContent = text; return d;
  }
  function value(text) {
    const v = document.createElement('span'); v.className = 'row__value'; v.textContent = text; return v;
  }

  NX.registerApp('settings', {
    title: 'Réglages',
    render(body) {
      const s = NX.state.settings;

      // Fond d'écran
      body.append(sectionLabel('Fond d\'écran'));
      const walls = document.createElement('div'); walls.className = 'walls';
      (NX.state.ui.wallpapers || []).forEach(w => {
        const b = document.createElement('button');
        b.className = 'wall' + (s.wallpaper === w ? ' is-selected' : '');
        b.style.backgroundImage = `url(assets/wallpaper-${w}.svg)`;
        b.setAttribute('aria-label', w);
        b.addEventListener('click', () => {
          NX.sound('tap');
          walls.querySelectorAll('.wall').forEach(x => x.classList.remove('is-selected'));
          b.classList.add('is-selected');
          NX.updateSettings({ wallpaper: w });
        });
        walls.append(b);
      });
      body.append(walls);

      // Sons
      body.append(sectionLabel('Sons'));
      const card = document.createElement('div'); card.className = 'card';
      const sw = document.createElement('button');
      sw.className = 'switch'; sw.setAttribute('role', 'switch');
      sw.setAttribute('aria-checked', String(!!s.sounds));
      sw.addEventListener('click', () => {
        const on = sw.getAttribute('aria-checked') !== 'true';
        sw.setAttribute('aria-checked', String(on));
        NX.updateSettings({ sounds: on });
        NX.sound('tap');
      });
      card.append(row('sound', 'Sons du terminal', sw));
      const range = document.createElement('input');
      range.type = 'range'; range.className = 'range'; range.min = '0'; range.max = '100';
      range.value = String(Math.round(s.volume * 100));
      range.addEventListener('change', () => { NX.updateSettings({ volume: Number(range.value) / 100 }); NX.sound('tap'); });
      card.append(row('bell', 'Volume', range));
      body.append(card);

      // Appareil
      body.append(sectionLabel('Appareil'));
      const dev = document.createElement('div'); dev.className = 'card';
      dev.append(row('info', 'Numéro de série', value(NX.state.serial || '—')));
      dev.append(row('lock', 'Chiffrement', value('ACTIF')));
      dev.append(row('signal', 'Réseau', value('NOIR X · PRIVÉ')));
      body.append(dev);
    },
  });
})();
