/* NOIR X — Dark Market : annonces entre joueurs, offres privées, colis, profils vendeurs.
 * Le serveur valide tout (objets autorisés, stock, prix, paiements, remises). */
(function () {
  'use strict';
  const h = NX.h;
  let body = null, tab = 'browse', cat = '', search = '', offs = [], data = null, rules = null;

  const CUR = { dirty: 'sale', clean: 'propre' };
  const curShort = c => (c === 'dirty' ? 'sale' : 'propre');
  const price = (n, c) => `${NX.money(n)} ${curShort(c)}`;
  const REASON = { purchase: 'Achat', listing_cancelled: 'Annonce annulée', listing_expired: 'Invendus', listing_removed: 'Retirée par le réseau', listing_failed: 'Retour' };
  const OSTATUS = { pending: 'En attente', accepted: 'Acceptée', declined: 'Refusée', cancelled: 'Annulée', expired: 'Expirée' };

  function img(src) {
    const el = h('img', { class: 'mk-img', attrs: { src, alt: '' } });
    el.addEventListener('error', () => { el.style.visibility = 'hidden'; });
    return el;
  }
  function rep(r) {
    if (!r) return '';
    return `👍 ${r.up} · 👎 ${r.down} · ${r.sales} vente${r.sales > 1 ? 's' : ''}`;
  }
  function durLabel(s) { return s >= 86400 ? `${Math.round(s / 86400 * 10) / 10} j`.replace('.0', '') : `${Math.round(s / 3600)} h`; }

  function render() {
    if (!body) return;
    body.textContent = '';
    const pend = data && data.pickups ? data.pickups.length : 0;
    const inc = data && data.incoming ? data.incoming.length : 0;
    body.append(NX.ui.tabs([['browse', 'Marché'], ['sell', 'Vendre'], ['me', `Mon espace${pend + inc ? ` (${pend + inc})` : ''}`]], tab, (id) => { tab = id; load(); }));
    const host = h('div', {});
    body.append(host);
    if (tab === 'browse') host.append(viewBrowse());
    else if (tab === 'sell') host.append(viewSell());
    else host.append(viewMe());
    NX.applyIcons(body);
  }

  function load() {
    if (!body) return;
    const call = tab === 'browse' ? NX.rpc('market.browse', { category: cat || null, search })
      : tab === 'sell' ? NX.rpc('market.sellable') : NX.rpc('market.mine');
    return call.then(res => {
      if (!body) return;
      if (!res.ok) { body.textContent = ''; body.append(NX.ui.empty('market', 'Réseau indisponible', res.message)); return; }
      rules = res.rules || rules;
      if (rules && rules.symbol) NX.state.symbol = rules.symbol;
      if (tab === 'me') { data = res; NX.badge('market', (res.pickups || []).length + (res.incoming || []).length); }
      if (res.delivered > 0) NX.notify('Dark Market', `${res.delivered} colis remis dans ton inventaire.`);
      body._res = res;
      render();
    });
  }

  /* ── Marché ──────────────────────────────────────────────────── */
  function viewBrowse() {
    const res = body._res || { listings: [] };
    const wrap = h('div', {});
    const input = NX.ui.input({ placeholder: 'Rechercher un objet ou un vendeur', value: search, maxLength: 40, onEnter: (v) => { search = v.trim(); load(); } });
    wrap.append(input);
    const cats = [['', 'Tout']].concat((rules && rules.categories || []).map(c => [c.id, c.label]));
    wrap.append(NX.ui.chips(cats, cat, (v) => { cat = v; load(); }));
    const list = res.listings || [];
    if (!list.length) { wrap.append(NX.ui.empty('market', 'Aucune annonce', search || cat ? 'Rien ne correspond à ta recherche.' : 'Le marché est vide pour le moment.')); return wrap; }
    const card = h('div', { class: 'card mk-list' });
    list.forEach(l => card.append(h('button', { class: 'lrow mk-row', on: { click: () => { NX.sound('tap'); openListing(l); } } },
      img(l.image),
      h('span', { class: 'lrow__main' },
        h('span', { class: 'lrow__title', text: `${l.label} × ${l.quantity}` }),
        h('span', { class: 'lrow__sub', text: [l.mine ? 'Ton annonce' : l.seller, rep(l.rep)].filter(Boolean).join(' · ') })),
      h('span', { class: 'lrow__side' },
        h('span', { class: 'mk-price', text: price(l.price, l.currency) }),
        h('span', { class: 'lrow__meta', text: `${NX.ui.duration(l.expiresIn)}` })))));
    wrap.append(h('div', { class: 'hint hint--pad', text: 'Prix à l\'unité. Les objets achetés arrivent directement dans ton inventaire, ou en colis si tu n\'as pas la place.' }), card);
    return wrap;
  }

  function openListing(l) {
    let qty = 1;
    const max = l.quantity;
    const qInput = NX.ui.input({ type: 'number', value: 1, maxLength: 6 });
    const total = h('span', { class: 'sum__v' });
    const upd = () => { qty = Math.max(1, Math.min(max, Math.floor(Number(qInput.value) || 1))); total.textContent = price(l.price * qty, l.currency); };
    qInput.addEventListener('input', upd);
    upd();
    const content = h('div', {},
      h('div', { class: 'mk-head' }, img(l.image), h('div', {},
        h('div', { class: 'mk-head__t', text: l.label }),
        h('div', { class: 'hint', text: `${l.categoryLabel} · vendu par ${l.mine ? 'toi' : l.seller}` }),
        l.rep ? h('div', { class: 'hint', text: rep(l.rep) }) : null)),
      l.note ? h('p', { class: 'sheet__text', text: `« ${l.note} »` }) : null,
      h('div', { class: 'stats' },
        h('div', { class: 'stat' }, h('span', { class: 'stat__label', text: 'Prix unitaire' }), h('span', { class: 'stat__value', text: price(l.price, l.currency) })),
        h('div', { class: 'stat' }, h('span', { class: 'stat__label', text: 'En stock' }), h('span', { class: 'stat__value', text: String(l.quantity) }))),
      l.mine ? null : h('div', {}, h('div', { class: 'field-label', style: { marginTop: '14px' }, text: 'Quantité' }), qInput,
        h('div', { class: 'sum' }, h('div', { class: 'sum__row sum__row--total' }, h('span', { text: 'Total' }), total))));
    const actions = l.mine
      ? [{ label: 'Fermer', kind: 'ghost' }, { label: 'Retirer l\'annonce', kind: 'danger', onClick: () => { cancelListing(l); } }]
      : [{ label: 'Faire une offre', kind: 'ghost', onClick: () => { makeOffer(l, qty); } },
        { label: 'Acheter', kind: 'primary', onClick: () => { buy(l, qty); } }];
    NX.ui.sheet({ title: 'Annonce', content, actions });
  }

  async function buy(l, qty) {
    const ok = await NX.ui.confirm('Confirmer l\'achat', `${qty} × ${l.label} pour ${price(l.price * qty, l.currency)}.`, 'Acheter');
    if (!ok) return;
    const res = await NX.rpc('market.buy', { listing: l.id, quantity: qty });
    if (!res.ok) return NX.fail(res);
    NX.sound('send');
    NX.notify('Dark Market', res.waiting > 0 ? 'Achat conclu. Pas assez de place : ton colis t\'attend dans « Mon espace ».' : 'Achat conclu. Objets dans ton inventaire.');
    NX.refreshWallet();
    load();
  }

  async function makeOffer(l, qty) {
    const v = await NX.ui.prompt(`Offre pour ${qty} × ${l.label}`, { placeholder: 'Prix unitaire proposé', hint: `Prix affiché : ${price(l.price, l.currency)} l'unité. La somme est bloquée jusqu'à la réponse du vendeur (${rules ? rules.offerHours : 24} h max.), puis rendue si l'offre n'aboutit pas.`, confirmLabel: 'Envoyer l\'offre' });
    if (v === null || v === '') return;
    const unit = Math.floor(Number(v));
    if (!(unit > 0)) return NX.notify('Dark Market', 'Prix invalide.', 'error');
    const res = await NX.rpc('market.offer', { listing: l.id, quantity: qty, price: unit });
    if (!res.ok) return NX.fail(res);
    NX.sound('send');
    NX.notify('Dark Market', 'Offre envoyée au vendeur.');
    NX.refreshWallet();
  }

  async function cancelListing(l) {
    const ok = await NX.ui.confirm('Retirer l\'annonce ?', 'Les objets restants te reviennent (inventaire ou colis). Les offres en attente sont remboursées.', 'Retirer', true);
    if (!ok) return;
    const res = await NX.rpc('market.cancel', { listing: l.id });
    if (!res.ok) return NX.fail(res);
    NX.notify('Dark Market', 'Annonce retirée.');
    load();
  }

  /* ── Vendre ──────────────────────────────────────────────────── */
  function viewSell() {
    const res = body._res || { items: [] };
    const wrap = h('div', {});
    if (!res.alias) wrap.append(h('div', { class: 'notice' }, NX.icon('user'), h('span', { text: 'Il te faut un pseudo Ghostline : c\'est ton profil vendeur sur le marché.' })));
    const items = res.items || [];
    if (!items.length) { wrap.append(NX.ui.empty('market', 'Rien à vendre', 'Aucun objet accepté par le marché dans ton inventaire.')); return wrap; }
    const card = h('div', { class: 'card' });
    items.forEach(it => card.append(h('button', { class: 'lrow mk-row', on: { click: () => { NX.sound('tap'); sellSheet(it, res.alias); } } },
      img(it.image),
      h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: it.label }), h('span', { class: 'lrow__sub', text: `Sur toi : ${it.count}` })),
      h('span', { class: 'lrow__side' }, NX.icon('chevron')))));
    wrap.append(NX.ui.label('Tes objets vendables'), card,
      h('div', { class: 'hint hint--pad', text: `Commission du réseau : ${rules ? rules.feePercent : 10} % sur chaque vente.${rules && rules.listingFee > 0 ? ` Frais de publication : ${NX.money(rules.listingFee)}.` : ''} Les objets quittent ton inventaire pendant la mise en vente.` }));
    return wrap;
  }

  function sellSheet(it, alias) {
    const r = rules || { currencies: ['dirty'], durations: [86400], feePercent: 10 };
    let cur = r.currencies[0], dur = r.durations[Math.min(1, r.durations.length - 1)];
    const qInput = NX.ui.input({ type: 'number', value: it.count, maxLength: 6 });
    const pInput = NX.ui.input({ type: 'number', placeholder: 'Prix unitaire', maxLength: 9 });
    pInput.classList.add('field--money');
    const note = NX.ui.input({ placeholder: 'Message (facultatif)', maxLength: 140 });
    const net = h('span', { class: 'sum__v sum__v--good' });
    const upd = () => {
      const q = Math.max(0, Math.floor(Number(qInput.value) || 0)), p = Math.max(0, Math.floor(Number(pInput.value) || 0));
      const t = q * p;
      net.textContent = `${NX.money(t - Math.floor(t * r.feePercent / 100))} ${curShort(cur)}`;
    };
    [qInput, pInput].forEach(i => i.addEventListener('input', upd));
    upd();
    const content = h('div', {},
      h('div', { class: 'mk-head' }, img(it.image), h('div', {}, h('div', { class: 'mk-head__t', text: it.label }), h('div', { class: 'hint', text: `Sur toi : ${it.count} · vendeur : ${alias || '—'}` }))),
      h('div', { class: 'field-label', style: { marginTop: '12px' }, text: 'Quantité' }), qInput,
      h('div', { class: 'field-label', style: { marginTop: '12px' }, text: 'Prix unitaire' }), pInput,
      h('div', { class: 'field-label', style: { marginTop: '12px' }, text: 'Paiement' }),
      NX.ui.chips(r.currencies.map(c => [c, c === 'dirty' ? 'Argent sale' : 'Argent propre']), cur, (v) => { cur = v; upd(); }),
      h('div', { class: 'field-label', style: { marginTop: '12px' }, text: 'Durée' }),
      NX.ui.chips(r.durations.map(d => [d, durLabel(d)]), dur, (v) => { dur = v; }),
      h('div', { style: { marginTop: '12px' } }, note),
      h('div', { class: 'sum' }, h('div', { class: 'sum__row sum__row--total' }, h('span', { text: `Tu touches si tout part (−${r.feePercent} %)` }), net)));
    NX.ui.sheet({
      title: 'Mettre en vente', content,
      actions: [{ label: 'Annuler', kind: 'ghost' }, { label: 'Publier', kind: 'primary', onClick: () => {
        publish({ item: it.item, quantity: Math.floor(Number(qInput.value) || 0), price: Math.floor(Number(pInput.value) || 0), currency: cur, duration: dur, note: note.value });
      } }],
    });
  }

  async function publish(args) {
    if (!(args.quantity > 0) || !(args.price > 0)) return NX.notify('Dark Market', 'Indique une quantité et un prix.', 'error');
    const res = await NX.rpc('market.list', args);
    if (!res.ok) return NX.fail(res);
    NX.sound('send');
    NX.notify('Dark Market', 'Annonce publiée.');
    tab = 'me';
    load();
  }

  /* ── Mon espace ──────────────────────────────────────────────── */
  function viewMe() {
    const d = data || {};
    const wrap = h('div', {});
    const p = d.profile || {};
    wrap.append(h('div', { class: 'card card--pad mk-profile' },
      h('div', { class: 'mk-head__t', text: p.alias || 'Pas de pseudo Ghostline' }),
      h('div', { class: 'hint', text: `${rep(p.rep)} · ${p.purchases || 0} achat${(p.purchases || 0) > 1 ? 's' : ''}` }),
      p.banned ? h('div', { class: 'notice' }, NX.icon('block'), h('span', { text: 'Exclu du marché par le réseau.' })) : null));

    if ((d.pickups || []).length) {
      const card = h('div', { class: 'card' });
      d.pickups.forEach(x => card.append(h('div', { class: 'lrow lrow--static mk-row' }, img(x.image),
        h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: `${x.label} × ${x.quantity}` }), h('span', { class: 'lrow__sub', text: REASON[x.reason] || x.reason })),
        h('span', { class: 'lrow__side' }, h('span', { class: 'lrow__meta', text: NX.ui.ago(x.at) })))));
      wrap.append(NX.ui.label('Colis à récupérer'), card, h('div', { class: 'stack-gap' }, NX.ui.button('Tout récupérer', 'primary', async () => {
        const res = await NX.rpc('market.pickup');
        if (!res.ok) return NX.fail(res);
        NX.notify('Dark Market', res.waiting > 0 ? `${res.delivered} colis récupéré(s). Fais de la place pour le reste.` : `${res.delivered} colis récupéré(s).`);
        load();
      }, 'check')));
    }

    if ((d.incoming || []).length) {
      const card = h('div', { class: 'card' });
      d.incoming.forEach(o => card.append(h('div', { class: 'lrow lrow--static mk-row' }, img(o.image),
        h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: `${o.quantity} × ${o.label}` }),
          h('span', { class: 'lrow__sub', text: `${o.from} propose ${price(o.unit, o.currency)} (affiché ${NX.money(o.listPrice)}) · ${NX.ui.duration(o.expiresIn)}` })),
        h('span', { class: 'lrow__side mk-actions' },
          h('button', { class: 'chip', text: 'Refuser', on: { click: () => respond(o, false) } }),
          h('button', { class: 'chip is-active', text: 'Accepter', on: { click: () => respond(o, true) } })))));
      wrap.append(NX.ui.label('Offres reçues'), card);
    }

    const listings = d.listings || [];
    if (listings.length) {
      const card = h('div', { class: 'card' });
      listings.forEach(l => card.append(h('button', { class: 'lrow mk-row', on: { click: () => { if (l.status === 'active') { NX.sound('tap'); openListing(l); } } } }, img(l.image),
        h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: `${l.label} · ${l.quantity}/${l.initial}` }),
          h('span', { class: 'lrow__sub', text: l.status === 'active' ? `${price(l.price, l.currency)} · reste ${NX.ui.duration(l.expiresIn)}` : ({ sold: 'Tout vendu', cancelled: 'Retirée', expired: 'Expirée', removed: 'Retirée par le réseau' }[l.status] || l.status) })),
        h('span', { class: 'lrow__side' }, l.status === 'active' ? NX.icon('chevron') : null))));
      wrap.append(NX.ui.label('Mes annonces'), card);
    }

    if ((d.sent || []).length) {
      const card = h('div', { class: 'card' });
      d.sent.forEach(o => card.append(h('div', { class: 'lrow lrow--static mk-row' }, img(o.image),
        h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: `${o.quantity} × ${o.label}` }),
          h('span', { class: 'lrow__sub', text: `à ${o.to} · ${price(o.unit, o.currency)} l'unité · ${OSTATUS[o.status] || o.status}` })),
        h('span', { class: 'lrow__side' }, o.status === 'pending' ? h('button', { class: 'chip', text: 'Annuler', on: { click: () => cancelOffer(o) } }) : null))));
      wrap.append(NX.ui.label('Mes offres'), card);
    }

    const hist = d.history || [];
    if (hist.length) {
      const card = h('div', { class: 'card' });
      hist.forEach(t => card.append(h('div', { class: 'lrow lrow--static mk-row' }, img(t.image),
        h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: `${t.bought ? 'Acheté' : 'Vendu'} · ${t.quantity} × ${t.label}` }),
          h('span', { class: 'lrow__sub', text: `${t.bought ? 'à' : 'par'} ${t.other} · ${price(t.total, t.currency)}${!t.bought && t.fee ? ` (−${NX.money(t.fee)})` : ''} · ${NX.ui.ago(t.at)}` })),
        h('span', { class: 'lrow__side mk-actions' }, t.canRate
          ? [h('button', { class: 'chip', text: '👍', on: { click: () => rate(t, true) } }), h('button', { class: 'chip', text: '👎', on: { click: () => rate(t, false) } })]
          : (t.rating ? h('span', { class: 'lrow__meta', text: t.rating > 0 ? '👍' : '👎' }) : null)))));
      wrap.append(NX.ui.label('Historique'), card);
    }
    if (!(d.pickups || []).length && !(d.incoming || []).length && !listings.length && !(d.sent || []).length && !hist.length) {
      wrap.append(NX.ui.empty('market', 'Rien pour l\'instant', 'Tes annonces, offres, colis et transactions apparaîtront ici.'));
    }
    return wrap;
  }

  async function respond(o, accept) {
    if (accept && !(await NX.ui.confirm('Accepter l\'offre ?', `${o.quantity} × ${o.label} pour ${price(o.total, o.currency)} (avant commission).`, 'Accepter'))) return;
    const res = await NX.rpc('market.offerRespond', { offer: o.id, accept });
    if (!res.ok) return NX.fail(res);
    NX.notify('Dark Market', accept ? 'Offre acceptée : vente conclue.' : 'Offre refusée.');
    load();
  }
  async function cancelOffer(o) {
    const res = await NX.rpc('market.offerCancel', { offer: o.id });
    if (!res.ok) return NX.fail(res);
    NX.notify('Dark Market', 'Offre annulée : somme rendue.');
    NX.refreshWallet();
    load();
  }
  async function rate(t, up) {
    const res = await NX.rpc('market.rate', { tx: t.id, up });
    if (!res.ok) return NX.fail(res);
    NX.notify('Dark Market', 'Merci pour ton avis.');
    load();
  }

  NX.registerApp('market', {
    title: 'Dark Market',
    render(el) {
      body = el;
      body._res = null;
      data = null;
      body.append(NX.ui.loader());
      offs = [NX.on('market:update', () => { if (tab !== 'sell') load(); })];
      load();
    },
    destroy() { offs.forEach(off => off()); offs = []; body = null; },
  });

  // Badge (colis + offres reçues) mis à jour à chaque notification du marché
  NX.on('market:update', () => {
    if (body) return;
    NX.rpc('market.mine').then(res => { if (res.ok) NX.badge('market', (res.pickups || []).length + (res.incoming || []).length); });
  });
})();
