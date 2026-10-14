/* NOIR X — Police Hack : mini-jeu RP. Les rapports réels passent par l'adaptateur MDT. */
(function () {
  'use strict';
  const h = NX.h;
  let host = null, off = [], accessUntil = 0, deletionUsed = false;
  const esc = v => String(v == null ? '' : v);
  function msg(title, text) { NX.notify(title, text, 'alert'); }
  function button(label, cls, fn) { return NX.ui.button(label, cls || 'primary', fn); }

  function render(target) {
    host = target; host.textContent = '';
    if (accessUntil > Date.now()) { renderAccess({ remaining: Math.ceil((accessUntil - Date.now()) / 1000) }); return; }
    host.append(h('div', { class: 'ph-hero' },
      h('div', { class: 'ph-skull', text: '☠' }),
      h('div', { class: 'ph-kicker', text: 'NOIR X // INTRUSION MDT' }),
      h('h2', { class: 'section-title', text: 'Police Hack' }),
      h('p', { class: 'muted', text: 'Intrusion fictive RP : déclenche une alerte au poste, résiste au duel de frappe et accède temporairement aux dossiers MDT autorisés.' })));
    const status = h('div', { class: 'card card--pad ph-status', text: 'Vérification des conditions…' });
    host.append(status);
    NX.rpc('policehack.status', {}).then(res => {
      if (!host || !host.contains(status)) return;
      status.textContent = '';
      if (!res || !res.ok) { status.append(h('p', { text: res && res.message || 'Serveur indisponible.' })); return; }
      const rows = [
        ['Coût du lancement', `${NX.money(res.price)} ${res.currency === 'dirty' ? 'argent sale' : 'argent propre'}`],
        ['Distance maximale', `${res.radius} m du commissariat`],
        ['Délai d’alerte', `${res.warningSeconds} secondes`],
        ['Durée d’accès après victoire', `${res.accessSeconds} secondes`],
        ['Recharge', `${Math.round(res.cooldownSeconds / 60)} minutes`]
      ];
      rows.forEach(([k,v]) => status.append(h('div', { class: 'ph-row' }, h('span', { text: k }), h('b', { text: v }))));
      if (res.cooldown > 0) status.append(h('div', { class: 'ph-alert', text: `Système verrouillé : ${res.cooldown}s avant une nouvelle tentative.` }));
      if (!res.adapterReady) status.append(h('div', { class: 'ph-alert', text: 'Adaptateur MDT non configuré : le mini-jeu est disponible, mais les rapports réels ne seront pas affichés ni modifiés avant la connexion de la ressource police.' }));
      const launch = button('Lancer l’intrusion', 'primary', () => {
        launch.disabled = true; launch.textContent = 'Connexion au poste…';
        NX.rpc('policehack.start', {}).then(out => {
          if (!out || !out.ok) { msg('Police Hack', out && out.message || 'Lancement refusé.'); render(host); return; }
          msg('Police Hack', 'Alerte envoyée au poste. La phase de préparation commence.');
          render(host);
        });
      });
      launch.disabled = !res.canStart || res.cooldown > 0;
      status.append(launch);
      const refresh = button('Actualiser', 'ghost', () => render(host)); status.append(refresh);
    });
  }

  NX.on('policehack:warning', payload => {
    msg('ALERTE MDT', 'Tentative de piratage détectée au poste. Défendez le serveur depuis votre téléphone.');
    NX.sound('alert');
    const screen = document.getElementById('screen');
    if (!screen) return;
    const n = h('div', { class: 'ph-overlay' },
      h('div', { class: 'ph-overlay__skull', text: '☠' }),
      h('strong', { text: 'POLICE SERVER UNDER ATTACK' }),
      h('span', { text: 'SIGNAL D’INTRUSION DÉTECTÉ' }),
      h('b', { text: String(Math.ceil((payload && payload.remainingMs || 60000) / 1000)) }));
    screen.append(n);
    let left = payload && payload.remainingMs || 60000;
    const id = setInterval(() => {
      if (!n.isConnected || left <= 0) { clearInterval(id); n.remove(); return; }
      left -= 1000; n.lastElementChild.textContent = String(Math.ceil(left / 1000));
      n.classList.toggle('ph-overlay--flicker');
    }, 1000);
    NX.sound('alert');
  });
  NX.on('policehack:access', payload => {
    accessUntil = Date.now() + Math.max(0, Number(payload && payload.remaining || 30)) * 1000;
    deletionUsed = false;
    msg('Police Hack', 'Accès MDT obtenu pour une durée limitée.', 'alert');
    if (host) renderAccess(payload);
  });
  function renderAccess(payload) {
    if (!host) return;
    host.textContent = '';
    host.append(h('div', { class: 'ph-hero' }, h('div', { class: 'ph-skull', text: '☠' }),
      h('h2', { class: 'section-title', text: 'Accès MDT autorisé' }),
      h('p', { class: 'muted', text: `Fenêtre d’accès : ${payload && payload.remaining || 30} secondes. Un seul dossier peut être supprimé.` })));
    if (deletionUsed) { host.append(h('div', { class: 'ph-alert', text: 'La suppression unique a déjà été utilisée. La fenêtre d’accès reste ouverte jusqu’à son expiration.' })); return; }
    NX.rpc('policehack.reports', {}).then(res => {
      if (!host || !host.isConnected) return;
      if (!res || !res.ok) { host.append(h('p', { class: 'ph-alert', text: res && res.message || 'Adaptateur MDT indisponible.' })); return; }
      if (!res.reports || !res.reports.length) { host.append(h('p', { class: 'muted', text: 'Aucun rapport accessible.' })); return; }
      res.reports.forEach(r => {
        const card = h('div', { class: 'card card--pad ph-report' },
          h('strong', { text: esc(r.title || `Rapport #${r.id}`) }),
          h('p', { class: 'muted', text: esc(r.summary || 'Résumé indisponible') }));
        card.append(button('Supprimer ce dossier (unique)', 'danger', () => {
          NX.ui.confirm('Supprimer un rapport ?', 'Cette action RP est définitive. Un seul dossier peut être supprimé par intrusion.', 'Supprimer', true).then(ok => {
            if (!ok) return;
            NX.rpc('policehack.deleteReport', { id: r.id }).then(done => {
              if (!done || !done.ok) return NX.fail(done);
              deletionUsed = true;
              msg('Police Hack', 'Dossier supprimé. Limite d’une suppression atteinte.');
              renderAccess({ remaining: Math.max(0, Math.ceil((accessUntil - Date.now()) / 1000)) });
            });
          });
        }));
        host.append(card);
      });
    });
  }
  NX.registerApp('policehack', {
    title: 'Police Hack',
    render,
    onBack() { return false; },
    destroy() { host = null; off.forEach(f => f()); off = []; }
  });
})();