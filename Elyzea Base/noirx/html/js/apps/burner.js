/* NOIR X — Burner : pseudonymes temporaires payants. */
(function () {
  'use strict';
  const h = NX.h;
  let body = null, tickers = [];

  function clearTickers() { tickers.forEach(t => clearInterval(t)); tickers = []; }

  function load() {
    clearTickers();
    body.textContent = '';
    body.append(NX.ui.loader());
    NX.rpc('burner.list').then(res => {
      body.textContent = '';
      if (!res.ok) { body.append(NX.ui.empty('burner', 'Réseau indisponible', res.message)); return; }
      render(res);
    });
  }

  function render(res) {
    const offer = res.offer;
    const active = res.burners.filter(b => b.active);

    body.append(h('div', { class: 'card card--pad' },
      h('div', { class: 'burner-head' },
        NX.icon('burner', 'burner-head__icon'),
        h('div', {},
          h('div', { class: 'burner-head__title', text: 'Identité jetable' }),
          h('div', { class: 'burner-head__text', text: 'Un pseudonyme qui disparaît tout seul. Utilise-le puis brûle-le.' }))),
      h('div', { class: 'sum' },
        h('div', { class: 'sum__row' }, h('span', { text: 'Prix' }), h('span', { class: 'sum__v', text: `${NX.money(offer.price)} ${offer.currency === 'dirty' ? 'sale' : 'propre'}` })),
        h('div', { class: 'sum__row' }, h('span', { text: 'Actifs max' }), h('span', { class: 'sum__v', text: String(offer.maxActive) })))));

    const createBtn = NX.ui.button('Créer un burner', 'primary', () => openCreate(offer), 'plus');
    if (active.length >= offer.maxActive) { createBtn.disabled = true; }
    body.append(h('div', { class: 'stack-gap' }, createBtn,
      active.length >= offer.maxActive ? h('div', { class: 'hint', text: 'Limite atteinte : révoque un burner pour en créer un autre.' }) : null));

    if (res.burners.length) {
      body.append(NX.ui.label('Tes burners'));
      const list = h('div', { class: 'card' });
      res.burners.forEach(b => {
        const meta = h('span', { class: 'lrow__meta' });
        const row = h('div', { class: 'lrow lrow--static' + (b.active ? '' : ' is-dim') },
          NX.ui.avatar(b.handle, { small: true }),
          h('span', { class: 'lrow__main' },
            h('span', { class: 'lrow__title', text: b.handle }),
            h('span', { class: 'lrow__sub', text: b.revoked ? 'Révoqué' : (b.active ? 'Actif' : 'Expiré') })),
          h('span', { class: 'lrow__side' }, meta,
            b.active ? h('button', { class: 'icon-btn', attrs: { 'aria-label': 'Révoquer' }, on: { click: async () => {
              if (await NX.ui.confirm('Brûler ce burner', `« ${b.handle} » sera immédiatement inutilisable.`, 'Brûler', true)) {
                const r = await NX.rpc('burner.revoke', { identity: b.id });
                if (!r.ok) return NX.fail(r);
                NX.sound('close'); load();
              }
            } } }, NX.icon('trash')) : null));
        if (b.active) {
          const upd = () => { b.remaining -= 1; if (b.remaining <= 0) { load(); return; } meta.textContent = NX.ui.duration(b.remaining); };
          meta.textContent = NX.ui.duration(b.remaining);
          tickers.push(setInterval(upd, 1000));
        }
        list.append(row);
      });
      body.append(list);
    }
    NX.applyIcons(body);
  }

  function openCreate(offer) {
    const handle = NX.ui.input({ placeholder: 'laisser vide = aléatoire', maxLength: 20 });
    let dur = 0;
    const durChips = NX.ui.chips(offer.durations.map((s, i) => [i + 1, NX.ui.duration(s)]), null, v => { dur = v; });
    NX.ui.sheet({
      title: 'Nouveau burner',
      content: h('div', {},
        h('div', { class: 'field-label', text: 'Pseudo (optionnel)' }), handle,
        h('div', { class: 'field-label', text: 'Durée de validité' }), durChips,
        h('div', { class: 'hint', text: `Coût : ${NX.money(offer.price)} en argent ${offer.currency === 'dirty' ? 'sale' : 'propre'}.` })),
      actions: [
        { label: 'Annuler', kind: 'ghost' },
        { label: 'Payer et créer', kind: 'primary', onClick: (close) => {
          if (!dur) { NX.notify('Burner', 'Choisis une durée.', 'error'); return false; }
          NX.rpc('burner.create', { handle: handle.value.trim(), duration: dur }).then(res => {
            if (!res.ok) return NX.fail(res);
            NX.sound('win');
            NX.notify('Burner', `Identité « ${res.handle} » active.`);
            NX.refreshWallet();
            close();
            load();
          });
          return false;
        } },
      ],
    });
  }

  NX.registerApp('burner', {
    title: 'Burner',
    render(el) { body = el; load(); },
    destroy() { clearTickers(); },
  });
})();
