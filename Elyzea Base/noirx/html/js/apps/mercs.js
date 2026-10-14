/* NOIR X — Mercenaires : commander une équipe de PNJ armés contre une cible connectée.
 * Toutes les règles (prix, cible, limites, résultat) sont décidées par le serveur. */
(function () {
  'use strict';
  const h = NX.h;
  let body = null, state = null, tab = 'order', tier = null, ticker = null, offs = [], seen = false;

  const STATUS = {
    pending: ['En préparation', 'wait'], deploying: ['En route', 'run'], engaged: ['Au contact', 'hot'],
    success: ['Contrat rempli', 'good'], failed: ['Équipe éliminée', 'bad'], expired: ['Expiré', 'dim'],
    timeout: ['Abandonné', 'dim'], target_left: ['Cible disparue', 'dim'], cancelled: ['Annulé', 'dim'],
  };
  const curLabel = c => (c === 'dirty' ? 'sale' : 'propre');

  function load() {
    return NX.rpc('mercs.state').then(res => {
      if (!body) return;
      if (!res.ok) { body.textContent = ''; body.append(NX.ui.empty('mercs', 'Réseau indisponible', res.message)); return; }
      const draft = state && state.draftTarget;
      state = res;
      state.draftTarget = draft;
      state.loadedAt = Date.now();
      NX.state.symbol = res.rules.symbol || NX.state.symbol;
      if (!tier || !res.rules.tiers.find(t => t.id === tier)) tier = (res.rules.tiers[1] || res.rules.tiers[0] || {}).id;
      if (res.active.length && tab === 'order' && !seen) tab = 'contracts';
      seen = true;
      render();
    });
  }

  const since = () => (Date.now() - state.loadedAt) / 1000;
  const left = v => Math.max(0, (v || 0) - since());

  function pill(status) {
    const [label, kind] = STATUS[status] || [status, 'dim'];
    return h('span', { class: `merc-pill merc-pill--${kind}`, text: label });
  }
  function stat(label, value, cls) {
    return h('div', { class: 'stat' + (cls ? ' ' + cls : '') }, h('span', { class: 'stat__label', text: label }), h('span', { class: 'stat__value', text: value }));
  }

  /* ── Commander ───────────────────────────────────────────────── */
  function renderOrder() {
    const r = state.rules;
    const busy = state.active.length > 0;
    const input = NX.ui.input({ placeholder: 'Prénom Nom', maxLength: 60 });
    input.value = state.draftTarget || '';
    input.addEventListener('input', () => { state.draftTarget = input.value; });

    const sum = { price: h('span', { class: 'sum__v' }), size: h('span', { class: 'sum__v' }) };
    const tiers = h('div', { class: 'merc-tiers' });
    function refresh() {
      const t = r.tiers.find(x => x.id === tier) || r.tiers[0];
      tiers.querySelectorAll('.merc-tier').forEach(el => el.classList.toggle('is-active', el.dataset.tier === tier));
      sum.price.textContent = `${NX.money(t.price)} ${curLabel(r.currency)}`;
      sum.size.textContent = `${t.size} mercenaire${t.size > 1 ? 's' : ''}`;
    }
    r.tiers.forEach(t => tiers.append(h('button', {
      class: 'merc-tier', dataset: { tier: t.id },
      on: { click: () => { NX.sound('tap'); tier = t.id; refresh(); } },
    }, h('span', { class: 'merc-tier__n', text: String(t.size) }), h('span', { class: 'merc-tier__l', text: t.label }), h('span', { class: 'merc-tier__p', text: NX.money(t.price) }))));
    refresh();

    const btn = NX.ui.button('Obtenir un devis', 'primary', () => quote(input.value), 'mercs');
    if (busy || state.cooldown > 0) btn.disabled = true;

    return h('div', {},
      h('div', { class: 'card card--pad' },
        h('div', { class: 'field-label', text: 'Cible' }), input,
        h('div', { class: 'hint', text: 'Prénom et nom exacts d\'une personne actuellement en ville.' }),
        h('div', { class: 'field-label', style: { marginTop: '16px' }, text: 'Équipe' }), tiers,
        h('div', { class: 'sum' },
          h('div', { class: 'sum__row' }, h('span', { text: 'Taille de l\'équipe' }), sum.size),
          h('div', { class: 'sum__row' }, h('span', { text: 'Arrivée estimée' }), h('span', { class: 'sum__v', text: `~ ${NX.ui.duration(r.deployDelay)}` })),
          h('div', { class: 'sum__row' }, h('span', { text: 'Validité du contrat' }), h('span', { class: 'sum__v', text: NX.ui.duration(r.validity) })),
          h('div', { class: 'sum__row sum__row--total' }, h('span', { text: 'Coût' }), sum.price))),
      busy ? h('div', { class: 'notice' }, NX.icon('clock'), h('span', { text: 'Un contrat est déjà en cours. Suis-le dans l\'onglet Contrats.' })) : null,
      !busy && state.cooldown > 0 ? h('div', { class: 'notice' }, NX.icon('clock'), h('span', { text: `Les équipes ne reprennent pas tes appels avant ${NX.ui.duration(left(state.cooldown))}.` })) : null,
      h('div', { class: 'stack-gap' }, btn),
      h('div', { class: 'hint hint--pad', text: 'Paiement à la commande. Si l\'équipe ne trouve pas la cible à temps ou si elle quitte la ville, une partie est remboursée. Une équipe éliminée n\'est pas remboursée.' }));
  }

  async function quote(name) {
    name = String(name || '').trim();
    if (name.length < 3) return NX.notify('Mercenaires', 'Indique le prénom et le nom de la cible.', 'error');
    const res = await NX.rpc('mercs.quote', { target: name, tier });
    if (!res.ok) return NX.fail(res);
    const content = h('div', {},
      h('div', { class: 'stats' },
        stat('Cible', res.targetName),
        stat('Équipe', `${res.label} · ${res.size}`),
        stat('Arrivée', `~ ${NX.ui.duration(res.deployDelay)}`),
        stat('Validité', NX.ui.duration(res.validity))),
      h('div', { class: 'sum' }, h('div', { class: 'sum__row sum__row--total' }, h('span', { text: 'À payer maintenant' }),
        h('span', { class: 'sum__v', text: `${NX.money(res.price)} ${curLabel(res.currency)}` }))),
      h('p', { class: 'sheet__text', text: `Devis valable ${res.quoteExpires} s.` }));
    NX.ui.sheet({
      title: 'Devis', content,
      actions: [
        { label: 'Annuler', kind: 'ghost' },
        { label: 'Commander', kind: 'primary', onClick: () => { order(res.quote); } },
      ],
    });
    NX.applyIcons(document.getElementById('sheet-host'));
  }

  async function order(id) {
    const res = await NX.rpc('mercs.order', { quote: id });
    if (!res.ok) return NX.fail(res);
    NX.sound('send');
    NX.notify('Mercenaires', 'Contrat accepté. L\'équipe se prépare.');
    state.draftTarget = '';
    tab = 'contracts';
    NX.refreshWallet();
    load();
  }

  /* ── Contrats ────────────────────────────────────────────────── */
  function activeCard(c) {
    const timer = h('span', { class: 'stat__value' });
    const timerLabel = h('span', { class: 'stat__label' });
    function tick() {
      if (c.status === 'pending' && left(c.deployIn) > 0) { timerLabel.textContent = 'Arrivée dans'; timer.textContent = NX.ui.duration(left(c.deployIn)); }
      else if (c.status === 'engaged' && c.engageLeft !== null && c.engageLeft !== undefined) { timerLabel.textContent = 'Combat'; timer.textContent = NX.ui.duration(left(c.engageLeft)); }
      else { timerLabel.textContent = 'Validité'; timer.textContent = NX.ui.duration(left(c.expiresIn)); }
    }
    tick();
    const cell = h('div', { class: 'stat' }, timerLabel, timer);
    cell._tick = tick;
    const card = h('div', { class: 'card card--pad merc-card' + (c.status === 'engaged' ? ' is-hot' : '') },
      h('div', { class: 'merc-card__head' }, h('span', { class: 'merc-card__t', text: c.targetName }), pill(c.status)),
      h('div', { class: 'stats' },
        stat('Équipe', c.alive !== null && c.alive !== undefined ? `${c.alive} / ${c.size} debout` : `${c.label} · ${c.size}`),
        stat('Coût', NX.money(c.price)),
        cell,
        stat('Commandé', NX.ui.clock(c.createdAt))),
      c.waiting === 'unreachable' ? h('div', { class: 'notice' }, NX.icon('signal'), h('span', { text: 'Cible injoignable pour le moment : l\'équipe attend qu\'elle réapparaisse.' })) : null);
    card._tick = () => cell._tick();
    return card;
  }

  function renderContracts() {
    const wrap = h('div', {});
    const cards = state.active.map(activeCard);
    if (cards.length) {
      wrap.append(NX.ui.label('En cours'), ...cards);
      ticker = setInterval(() => cards.forEach(c => c._tick()), 1000);
    }
    if (state.history.length) {
      const list = h('div', { class: 'card' });
      state.history.forEach(x => list.append(h('div', { class: 'lrow lrow--static' },
        h('span', { class: 'lrow__main' },
          h('span', { class: 'lrow__title', text: x.targetName }),
          h('span', { class: 'lrow__sub', text: `${x.label} · ${x.size} · ${NX.money(x.price)}${x.refund > 0 ? ` · remboursé ${NX.money(x.refund)}` : ''}` })),
        h('span', { class: 'lrow__side' }, pill(x.status), h('span', { class: 'lrow__meta', text: NX.ui.ago(x.at) })))));
      wrap.append(NX.ui.label('Historique'), list);
    }
    if (!cards.length && !state.history.length) wrap.append(NX.ui.empty('mercs', 'Aucun contrat', 'Tes contrats apparaîtront ici.'));
    return wrap;
  }

  function render() {
    if (ticker) { clearInterval(ticker); ticker = null; }
    body.textContent = '';
    body.append(NX.ui.tabs([['order', 'Commander'], ['contracts', `Contrats${state.active.length ? ` (${state.active.length})` : ''}`]], tab, (id) => { tab = id; render(); }));
    body.append(tab === 'order' ? renderOrder() : renderContracts());
    NX.applyIcons(body);
  }

  NX.registerApp('mercs', {
    title: 'Mercenaires',
    render(el) {
      body = el;
      state = null;
      seen = false;
      body.append(NX.ui.loader());
      offs = [NX.on('mercs:update', () => load())];
      load();
    },
    destroy() {
      if (ticker) clearInterval(ticker);
      ticker = null;
      offs.forEach(off => off());
      offs = [];
      body = null;
    },
  });
})();
