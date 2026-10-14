/* NOIR X — Blanchiment : convertir l'argent sale en argent propre, sous la menace des pirates. */
(function () {
  'use strict';
  const h = NX.h;
  let body = null, state = null, ticker = null, offs = [];

  function duration(rules, amount) {
    return Math.min(rules.maxSeconds, rules.baseSeconds + Math.ceil(amount / 1000) * rules.secondsPer1000);
  }

  function load() {
    return NX.rpc('launder.state').then(res => {
      if (!res.ok) { body.textContent = ''; body.append(NX.ui.empty('launder', 'Réseau indisponible', res.message)); return; }
      state = res;
      state.loadedAt = Date.now();
      NX.state.symbol = res.rules.symbol || NX.state.symbol;
      render();
    });
  }

  function ring(progress) {
    const r = 54, c = 2 * Math.PI * r;
    const svgNS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(svgNS, 'svg');
    svg.setAttribute('viewBox', '0 0 128 128');
    svg.setAttribute('class', 'ring');
    const bg = document.createElementNS(svgNS, 'circle');
    bg.setAttribute('cx', 64); bg.setAttribute('cy', 64); bg.setAttribute('r', r); bg.setAttribute('class', 'ring__bg');
    const fg = document.createElementNS(svgNS, 'circle');
    fg.setAttribute('cx', 64); fg.setAttribute('cy', 64); fg.setAttribute('r', r); fg.setAttribute('class', 'ring__fg');
    fg.setAttribute('stroke-dasharray', c.toFixed(1));
    fg.setAttribute('stroke-dashoffset', (c * (1 - progress)).toFixed(1));
    svg.append(bg, fg);
    return { svg, set: p => fg.setAttribute('stroke-dashoffset', (c * (1 - p)).toFixed(1)) };
  }

  function stat(label, value, cls) {
    return h('div', { class: 'stat' + (cls ? ' ' + cls : '') }, h('span', { class: 'stat__label', text: label }), h('span', { class: 'stat__value', text: value }));
  }

  function renderJob(job) {
    const elapsedLocal = () => (Date.now() - state.loadedAt) / 1000;
    const remaining = () => Math.max(0, job.remaining - elapsedLocal());
    const rg = ring(1 - remaining() / job.total);
    const time = h('div', { class: 'ring__time', text: NX.ui.duration(remaining()) });
    const card = h('div', { class: 'card card--pad launder-job' + (job.underAttack ? ' is-attacked' : '') },
      h('div', { class: 'ring-wrap' }, rg.svg, h('div', { class: 'ring__center' }, time, h('div', { class: 'ring__label', text: job.underAttack ? 'SOUS ATTAQUE' : 'en cours' }))),
      h('div', { class: 'stats' },
        stat('Montant', NX.money(job.amount)),
        stat('Frais', NX.money(job.fee)),
        job.stolen > 0 ? stat('Volé', NX.money(job.stolen), 'stat--bad') : null,
        stat('Tu recevras', NX.money(job.payout), 'stat--good')),
      h('div', { class: 'notice' }, NX.icon('alert'), h('span', { text: 'Garde ton terminal à portée : un pirate peut frapper pendant l\'opération. Si tu ne réagis pas, il se sert.' })));
    ticker = setInterval(() => {
      const rem = remaining();
      rg.set(1 - rem / job.total);
      time.textContent = NX.ui.duration(rem);
      if (rem <= 0) { clearInterval(ticker); ticker = null; time.textContent = 'Finalisation…'; setTimeout(load, 2500); }
    }, 1000);
    return card;
  }

  function renderForm() {
    const rules = state.rules;
    const dirty = state.dirty;
    const maxAllowed = dirty === null || dirty === undefined ? rules.max : Math.min(rules.max, dirty);
    const canLaunder = maxAllowed >= rules.min && state.cooldown <= 0;

    let amount = Math.max(rules.min, Math.min(maxAllowed, Math.round(maxAllowed / 2 / 100) * 100));
    const input = NX.ui.input({ type: 'number', value: canLaunder ? amount : '', placeholder: String(rules.min) });
    input.classList.add('field--money');
    const slider = h('input', { class: 'range range--wide', attrs: { type: 'range', min: rules.min, max: Math.max(rules.min, maxAllowed), step: 100 } });
    slider.value = amount;
    const fee = h('span', { class: 'sum__v' }), net = h('span', { class: 'sum__v sum__v--good' }), dur = h('span', { class: 'sum__v' });

    function update(v, from) {
      amount = Math.floor(Number(v) || 0);
      if (from !== 'input') input.value = amount;
      if (from !== 'slider') slider.value = amount;
      const f = Math.floor(amount * rules.feePercent / 100);
      fee.textContent = `${NX.money(f)} (${rules.feePercent} %)`;
      net.textContent = NX.money(amount - f);
      dur.textContent = NX.ui.duration(duration(rules, amount));
    }
    input.addEventListener('input', () => update(input.value, 'input'));
    slider.addEventListener('input', () => update(slider.value, 'slider'));
    update(amount);

    const chips = h('div', { class: 'chips' }, ...[['25 %', 0.25], ['50 %', 0.5], ['Max', 1]].map(([label, k]) => h('button', {
      class: 'chip', text: label, on: { click: () => { NX.sound('tap'); update(Math.max(rules.min, Math.floor(maxAllowed * k / 100) * 100)); } },
    })));

    const start = NX.ui.button('Lancer le blanchiment', 'primary', async () => {
      if (amount < rules.min || amount > maxAllowed) return NX.notify('Blanchiment', `Montant entre ${NX.money(rules.min)} et ${NX.money(maxAllowed)}.`, 'error');
      const ok = await NX.ui.confirm('Confirmer l\'opération',
        `${NX.money(amount)} d'argent sale vont quitter ta poche. Tu recevras ${NX.money(amount - Math.floor(amount * rules.feePercent / 100))} propres dans ${NX.ui.duration(duration(rules, amount))}, si personne ne te pirate.`,
        'Blanchir');
      if (!ok) return;
      const res = await NX.rpc('launder.start', { amount });
      if (!res.ok) return NX.fail(res);
      NX.sound('send');
      load();
    }, 'launder');
    if (!canLaunder) start.disabled = true;

    return h('div', {},
      h('div', { class: 'card card--pad' },
        h('div', { class: 'field-label', text: 'Montant à blanchir' }),
        input, slider, chips,
        h('div', { class: 'sum' },
          h('div', { class: 'sum__row' }, h('span', { text: 'Commission du réseau' }), fee),
          h('div', { class: 'sum__row' }, h('span', { text: 'Durée de l\'opération' }), dur),
          h('div', { class: 'sum__row sum__row--total' }, h('span', { text: 'Tu reçois (propre)' }), net))),
      state.cooldown > 0 ? h('div', { class: 'notice' }, NX.icon('clock'), h('span', { text: `Réseau saturé : prochain blanchiment possible dans ${NX.ui.duration(state.cooldown)}.` })) : null,
      maxAllowed < rules.min && state.cooldown <= 0 ? h('div', { class: 'notice' }, NX.icon('alert'), h('span', { text: `Minimum ${NX.money(rules.min)} d'argent sale.` })) : null,
      h('div', { class: 'stack-gap' }, start));
  }

  function renderHistory() {
    if (!state.history || !state.history.length) return null;
    const list = h('div', { class: 'card' });
    state.history.forEach(j => list.append(h('div', { class: 'lrow lrow--static' },
      h('span', { class: 'lrow__main' },
        h('span', { class: 'lrow__title', text: `${NX.money(j.amount)} → ${NX.money(j.payout)}` }),
        h('span', { class: 'lrow__sub', text: j.status === 'cancelled' ? 'Annulé par le staff' : (j.stolen > 0 ? `Piraté : −${NX.money(j.stolen)}` : 'Opération propre') })),
      h('span', { class: 'lrow__side' }, h('span', { class: 'lrow__meta', text: NX.ui.ago(j.at) })))));
    return h('div', {}, NX.ui.label('Historique'), list);
  }

  function render() {
    if (ticker) { clearInterval(ticker); ticker = null; }
    body.textContent = '';
    body.append(h('div', { class: 'balance' },
      h('span', { class: 'balance__label', text: 'Argent sale disponible' }),
      h('span', { class: 'balance__value', text: state.dirty === null || state.dirty === undefined ? 'Non relié' : NX.money(state.dirty) })));
    body.append(state.job ? renderJob(state.job) : renderForm());
    const hist = renderHistory();
    if (hist) body.append(hist);
    NX.applyIcons(body);
  }

  NX.registerApp('launder', {
    title: 'Blanchiment',
    render(el) {
      body = el;
      body.append(NX.ui.loader());
      offs = [
        NX.on('launder:update', load),
        NX.on('launder:done', load),
        NX.on('duel:end', p => { if (p.role === 'defender') load(); }),
      ];
      load();
    },
    destroy() {
      if (ticker) clearInterval(ticker);
      ticker = null;
      offs.forEach(off => off());
      offs = [];
    },
  });

  // La notification de fin est envoyée par le serveur ; ici on rafraîchit le solde.
  NX.on('launder:done', () => NX.refreshWallet());
})();
