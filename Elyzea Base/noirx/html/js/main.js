/* NOIR X — point d'entrée NUI : messages du client Lua, ouverture/fermeture, clavier. */
(function () {
  'use strict';
  const stage = document.getElementById('stage');
  const boot = document.getElementById('boot');

  NX.applyIcons();
  NX.rescale();

  function runBoot() {
    const dur = Number(NX.state.ui.bootDuration) || 0;
    const first = !NX.state.booted;
    if (dur <= 0 || (!first && !NX.state.ui.showBootEveryOpen)) { boot.hidden = true; return; }
    NX.state.booted = true;
    boot.hidden = false;
    boot.classList.remove('is-done');
    boot.style.setProperty('--boot', `${dur}ms`);
    // relance des animations CSS
    boot.querySelectorAll('.boot__emblem, .boot__word, .boot__bar span').forEach(el => {
      el.style.animation = 'none'; void el.offsetWidth; el.style.animation = '';
    });
    const line = document.getElementById('boot-line');
    const steps = ['Initialisation', 'Tunnel chiffré', 'Authentification', 'Connecté'];
    steps.forEach((s, i) => setTimeout(() => { line.textContent = s; }, (dur / steps.length) * i));
    setTimeout(() => {
      boot.classList.add('is-done');
      setTimeout(() => { boot.hidden = true; }, 460);
    }, dur);
  }

  function open(data) {
    const st = NX.state;
    st.serial = data.serial || '';
    if (data.settings) Object.assign(st.settings, data.settings);
    if (data.ui) st.ui = Object.assign(st.ui, data.ui);
    if (data.money && data.money.symbol) st.symbol = data.money.symbol;
    st.apps = Array.isArray(data.apps) ? data.apps : [];
    NX.setTime(data.time);
    NX.applySettings();
    NX.renderGrid();
    NX.closeApp(false);
    stage.hidden = false;
    st.open = true;
    runBoot();
    requestAnimationFrame(() => requestAnimationFrame(() => stage.classList.add('is-open')));
    NX.sound('open');
    NX.refreshWallet();
  }

  function hide() {
    if (!NX.state.open) return;
    NX.state.open = false;
    if (NX.duel) NX.duel.close();
    NX.closeApp(false);
    stage.classList.remove('is-open');
    setTimeout(() => { if (!NX.state.open) stage.hidden = true; }, 460);
    NX.sound('close');
  }

  /** Fermeture demandée par l'utilisateur : on prévient le client Lua (focus + serveur). */
  function requestClose() {
    if (!NX.state.open) return;
    // le niveau de batterie visuel est sauvegardé à la fermeture
    NX.post('saveSettings', { battery: Math.round(NX.state.settings.battery) });
    hide();
    NX.post('close');
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.action) {
      case 'open': open(d); break;
      case 'close': hide(); break;
      case 'time': NX.setTime(d.time); break;
      case 'notify': NX.notify(d.title, d.body, d.kind); break;
      case 'push':
        if (d.event === 'wallet:changed') NX.refreshWallet();
        NX.emit(d.event, d.payload);
        break;
    }
  });

  document.addEventListener('keydown', (e) => {
    if (!NX.state.open) return;
    if (e.key === 'Escape') { e.preventDefault(); requestClose(); }
  });

  // Retour / accueil
  document.getElementById('btn-back').addEventListener('click', () => NX.back());
  document.getElementById('btn-home').addEventListener('click', () => { if (NX.state.current) { NX.sound('tap'); NX.closeApp(false); } });

  // Saisie de texte : le client Lua coupe l'input jeu pour éviter que le personnage bouge.
  document.addEventListener('focusin', (e) => {
    if (e.target.matches('input[type=text], input:not([type]), textarea, [contenteditable]')) NX.post('inputFocus', { focused: true });
  });
  document.addEventListener('focusout', (e) => {
    if (e.target.matches('input[type=text], input:not([type]), textarea, [contenteditable]')) NX.post('inputFocus', { focused: false });
  });

  /* Aperçu hors jeu (ouvrir html/index.html dans un navigateur) */
  if (!NX.inGame) {
    document.body.style.background = 'radial-gradient(circle at 70% 60%, #1a1d24, #07080a)';
    open({
      serial: 'NX-PREV-1EW0',
      settings: { wallpaper: 'void', sounds: false, volume: 0.35, battery: 76 },
      money: { symbol: '$' },
      apps: [
        ['darkchat', 'Dark Chat'], ['ghostline', 'Ghostline'], ['ratline', 'Ratline'], ['launder', 'Blanchiment'],
        ['market', 'Dark Market'], ['contracts', 'Contrats'], ['blackbreach', 'Blackbreach'], ['mercs', 'Mercenaires'],
        ['blackfile', 'Blackfile'], ['burner', 'Burner'], ['deaddrop', 'Dead Drop'], ['auction', 'Black Auction'], ['settings', 'Réglages'],
      ].map(([id, label]) => ({ id, label })),
      ui: { bootDuration: 0, wallpapers: ['void', 'grid', 'ember'], battery: { enabled: true, drainPerMinute: 0.4, min: 8 }, sounds: { enabled: true } },
      time: { h: 23, m: 47 },
    });
    setTimeout(() => NX.notify('Ghostline', 'Nouveau contact chiffré en attente.'), 600);
  }
})();
