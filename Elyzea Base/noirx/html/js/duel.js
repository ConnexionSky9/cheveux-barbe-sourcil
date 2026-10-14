/* NOIR X — Duel de piratage (course de frappe)
 * S'affiche par-dessus tout le téléphone, que l'on soit la cible (défenseur) ou le pirate.
 * Le client ne fait qu'afficher et envoyer le texte tapé : le serveur chronomètre,
 * vérifie la ligne et désigne le gagnant.
 */
(function () {
  'use strict';
  const h = NX.h;
  const duel = { active: null };
  let timer = null;

  function root() { return document.getElementById('duel'); }

  function stopTimer() { if (timer) { clearInterval(timer); timer = null; } }

  function renderLine(line, typed) {
    const wrap = h('div', { class: 'duel__code' });
    for (let i = 0; i < line.length; i++) {
      let cls = 'c';
      if (i < typed.length) cls += typed[i] === line[i] ? ' c--ok' : ' c--bad';
      else if (i === typed.length) cls += ' c--caret';
      wrap.append(h('span', { class: cls, text: line[i] === ' ' ? ' ' : line[i] }));
    }
    return wrap;
  }

  duel.open = function (view) {
    if (!view || !view.attack) return;
    if (duel.active && duel.active.attack === view.attack && !duel.active.finished) {
      // déjà affiché (ex. téléphone rouvert pendant le duel) : on redonne le focus au champ
      const inp = root().querySelector('.duel__input');
      if (inp) setTimeout(() => inp.focus(), 80);
      return;
    }
    stopTimer();
    const startedAt = performance.now();
    const state = Object.assign({}, view, { typed: '', submitting: false, finished: false, startedAt });
    duel.active = state;
    NX.ui.closeSheets();

    const el = root();
    el.hidden = false;
    el.className = 'duel' + (view.role === 'defender' ? ' duel--defend' : ' duel--attack');
    el.textContent = '';

    const codeHost = h('div', { class: 'duel__codehost' }, renderLine(view.line, ''));
    const bar = h('span', { class: 'duel__barfill' });
    const secs = h('span', { class: 'duel__secs', text: '' });
    const status = h('div', { class: 'duel__status', text: '' });
    const input = h('input', { class: 'duel__input', attrs: { type: 'text', spellcheck: 'false', autocomplete: 'off', autocorrect: 'off', autocapitalize: 'off', maxlength: view.line.length + 4, placeholder: 'Tape la séquence…' } });

    ['paste', 'drop', 'contextmenu'].forEach(ev => input.addEventListener(ev, e => {
      e.preventDefault();
      status.textContent = 'Copier-coller bloqué.';
    }));

    input.addEventListener('input', () => {
      if (state.finished) return;
      state.typed = input.value;
      NX.sound('key');
      codeHost.textContent = '';
      codeHost.append(renderLine(view.line, state.typed));
      const wrongAt = [...state.typed].findIndex((c, i) => c !== view.line[i]);
      input.classList.toggle('is-wrong', wrongAt !== -1);
      if (state.typed === view.line) submit();
    });
    input.addEventListener('keydown', e => {
      if (e.key === 'Escape') return; // laisse la fermeture du téléphone se faire
      e.stopPropagation();
      if (e.key === 'Enter') { e.preventDefault(); if (state.typed === view.line) submit(); else shake(); }
    });

    function shake() {
      NX.sound('error');
      input.classList.remove('shake'); void input.offsetWidth; input.classList.add('shake');
    }

    function submit() {
      if (state.submitting || state.finished) return;
      state.submitting = true;
      status.textContent = 'Transmission…';
      NX.rpc('duel.submit', { attack: view.attack, text: state.typed }).then(res => {
        state.submitting = false;
        if (!res.ok) {
          status.textContent = res.message || 'Séquence rejetée.';
          if (res.error === 'over') return;
          shake();
          return;
        }
        if (!res.correct) { status.textContent = 'Séquence incorrecte.'; shake(); return; }
        status.textContent = 'Séquence acceptée. Vérification…';
      });
    }

    const defender = view.role === 'defender';
    el.append(h('div', { class: 'duel__panel' },
      h('div', { class: 'duel__head' },
        NX.icon(defender ? 'alert' : 'blackbreach', 'duel__icon'),
        h('div', {},
          h('div', { class: 'duel__title', text: defender ? 'Intrusion détectée' : 'Intrusion en cours' }),
          h('div', { class: 'duel__sub', text: defender
            ? 'Un pirate vise ton blanchiment. Recopie la séquence avant lui pour couper l\'accès.'
            : 'Recopie la séquence avant que la cible ne coupe la liaison.' }))),
      h('div', { class: 'duel__timer' }, h('span', { class: 'duel__bar' }, bar), secs),
      codeHost,
      input,
      status,
      h('div', { class: 'duel__hint', text: 'Respecte les espaces et les tirets · copier-coller bloqué' })));
    NX.applyIcons(el);
    NX.sound('alert');

    const total = view.windowMs || 25000;
    const tick = () => {
      const left = Math.max(0, view.remainingMs - (performance.now() - startedAt));
      bar.style.width = `${(left / total) * 100}%`;
      secs.textContent = `${(left / 1000).toFixed(1)} s`;
      el.classList.toggle('is-critical', left < 6000);
      if (left <= 0) stopTimer();
    };
    tick();
    timer = setInterval(tick, 100);
    setTimeout(() => input.focus(), 80);
  };

  duel.finish = function (p) {
    const state = duel.active;
    if (!state || state.attack !== p.attack) return;
    state.finished = true;
    stopTimer();
    const el = root();
    el.textContent = '';
    let title, text, good;
    if (p.role === 'defender') {
      good = p.won;
      title = p.won ? 'Intrusion bloquée' : 'Accès compromis';
      text = p.won ? 'Le pirate est éjecté. Ton blanchiment continue.'
        : (p.loss > 0 ? `Le pirate a siphonné ${NX.money(p.loss)} de ton opération.` : 'Le pirate est passé, mais il n\'y avait plus rien à prendre.');
    } else {
      good = p.won;
      title = p.won ? 'Transfert réussi' : 'Liaison coupée';
      text = p.won ? (p.reward > 0 ? `${NX.money(p.reward)} d'argent sale récupérés.` : 'Rien à récupérer sur cette cible.')
        : (p.reason === 'timeout' ? 'Temps écoulé. La cible a fermé le tunnel.' : 'La cible a été plus rapide que toi.');
    }
    NX.sound(good ? 'win' : 'lose');
    el.className = 'duel duel--result' + (good ? ' is-win' : ' is-lose');
    el.append(h('div', { class: 'duel__panel duel__panel--result' },
      NX.icon(good ? 'shield' : 'alert', 'duel__bigicon'),
      h('div', { class: 'duel__title', text: title }),
      h('div', { class: 'duel__sub', text }),
      NX.ui.button('Fermer', good ? 'primary' : 'ghost', () => duel.close())));
    NX.applyIcons(el);
    NX.refreshWallet();
  };

  duel.close = function () {
    stopTimer();
    duel.active = null;
    const el = root();
    el.hidden = true;
    el.textContent = '';
  };

  NX.on('duel:start', v => duel.open(v));
  NX.on('duel:end', p => duel.finish(p));

  NX.duel = duel;
})();
