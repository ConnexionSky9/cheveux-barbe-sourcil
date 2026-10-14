/* NOIR X — Ghostline : contacts clandestins, invitations, réputation, niveau de confiance. */
(function () {
  'use strict';
  const h = NX.h;
  let stack = null, offs = [];

  function trustDots(n) {
    const wrap = h('span', { class: 'trust' });
    for (let i = 0; i < 5; i++) wrap.append(h('span', { class: 'trust__d' + (i < n ? ' is-on' : '') }));
    return wrap;
  }

  function repLabel(rep) {
    if (rep > 0) return `+${rep}`;
    return String(rep);
  }

  function renderContacts(body) {
    const me = NX.ident.current;
    const head = h('div', { class: 'gl-head' }, NX.ident.switcher(),
      NX.ui.button(null, 'ghost', () => openAdd(), 'plus'));
    body.append(head);
    const listHost = h('div', {});
    body.append(listHost);

    function load() {
      listHost.textContent = '';
      listHost.append(NX.ui.loader());
      NX.rpc('contacts.list', { identity: NX.ident.id() }).then(res => {
        listHost.textContent = '';
        if (!res.ok) { listHost.append(NX.ui.empty('ghostline', 'Indisponible', res.message)); return; }
        const pendingIn = res.contacts.filter(c => c.status === 'pending_in');
        const accepted = res.contacts.filter(c => c.status === 'accepted');
        const pendingOut = res.contacts.filter(c => c.status === 'pending_out');

        if (pendingIn.length) {
          listHost.append(NX.ui.label('Invitations reçues'));
          const card = h('div', { class: 'card' });
          pendingIn.forEach(c => card.append(h('div', { class: 'lrow lrow--static' },
            NX.ui.avatar(c.handle, { small: true }),
            h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: c.handle }), h('span', { class: 'lrow__sub', text: 'veut te contacter' })),
            h('span', { class: 'lrow__side' },
              h('button', { class: 'icon-btn icon-btn--ok', on: { click: () => respond(c.id, true, load) } }, NX.icon('check')),
              h('button', { class: 'icon-btn', on: { click: () => respond(c.id, false, load) } }, NX.icon('close'))))));
          listHost.append(card);
        }

        listHost.append(NX.ui.label(`Contacts${accepted.length ? ' · ' + accepted.length : ''}`));
        if (!accepted.length) {
          listHost.append(h('div', { class: 'hint hint--pad', text: 'Aucun contact. Ajoute un pseudo pour lancer une invitation.' }));
        } else {
          const card = h('div', { class: 'card' });
          accepted.forEach(c => card.append(NX.ui.row({
            lead: NX.ui.avatar(c.handle, { small: true }),
            title: (c.favorite ? '★ ' : '') + (c.alias ? c.alias + ' · ' : '') + c.handle,
            sub: (c.blocked ? 'Bloqué · ' : '') + (c.offline ? 'hors ligne' : 'réputation ' + repLabel(c.reputation)),
            meta: c.burner ? 'burner' : '',
            onClick: () => stack.push(c.handle, (b) => renderContact(b, c, load)),
          })));
          listHost.append(card);
        }

        if (pendingOut.length) {
          listHost.append(NX.ui.label('Invitations envoyées'));
          const card = h('div', { class: 'card' });
          pendingOut.forEach(c => card.append(h('div', { class: 'lrow lrow--static is-dim' },
            NX.ui.avatar(c.handle, { small: true }),
            h('span', { class: 'lrow__main' }, h('span', { class: 'lrow__title', text: c.handle }), h('span', { class: 'lrow__sub', text: 'en attente' })))));
          listHost.append(card);
        }
        NX.applyIcons(listHost);
      });
    }

    const offId = NX.on('identity:changed', () => { stack.refresh(); });
    const offReq = NX.on('ghost:request', load);
    const offCon = NX.on('ghost:contacts', load);
    load();
    return () => { offId(); offReq(); offCon(); };
  }

  function respond(contact, accept, done) {
    NX.rpc('contacts.respond', { identity: NX.ident.id(), contact, accept }).then(res => {
      if (!res.ok) return NX.fail(res);
      NX.sound(accept ? 'win' : 'tap');
      done();
    });
  }

  function openAdd() {
    NX.ui.prompt('Ajouter un contact', { placeholder: 'pseudo exact', maxLength: 20, hint: 'Une invitation anonyme lui sera envoyée.', confirmLabel: 'Inviter' })
      .then(handle => {
        if (!handle) return;
        NX.rpc('contacts.request', { identity: NX.ident.id(), handle }).then(res => {
          if (!res.ok) return NX.fail(res);
          NX.sound('send');
          NX.notify('Ghostline', res.message || 'Invitation transmise.');
          stack.refresh();
        });
      });
  }

  function renderContact(body, c, refreshList) {
    body.append(h('div', { class: 'profile' },
      NX.ui.avatar(c.handle, {}),
      h('div', { class: 'profile__name', text: c.handle },),
      h('div', { class: 'profile__sub', text: c.burner ? 'Identité jetable' : 'Identité principale' }),
      h('div', { class: 'profile__rep' }, h('span', { text: 'Réputation ' }), h('b', { text: repLabel(c.reputation) }))));

    const rateRow = h('div', { class: 'rate' },
      h('button', { class: 'rate__btn' + (c.myRating > 0 ? ' is-on' : ''), on: { click: () => rate(1) } }, NX.icon('thumbup')),
      h('span', { class: 'rate__label', text: 'Confiance' }),
      h('button', { class: 'rate__btn rate__btn--down' + (c.myRating < 0 ? ' is-on' : ''), on: { click: () => rate(-1) } }, NX.icon('thumbdown')));

    function rate(v) {
      const nv = c.myRating === v ? 0 : v;
      NX.rpc('contacts.rate', { identity: NX.ident.id(), contact: c.id, value: nv }).then(res => {
        if (!res.ok) return NX.fail(res);
        c.myRating = nv; NX.sound('tap'); stack.refresh();
      });
    }

    const trustRow = h('div', { class: 'trust-row' },
      h('span', { text: 'Niveau de confiance' }), trustDots(c.trust));
    let trust = c.trust;
    const trustCtl = h('div', { class: 'trust-ctl' },
      h('button', { class: 'chip', text: '−', on: { click: () => setTrust(trust - 1) } }),
      h('button', { class: 'chip', text: '+', on: { click: () => setTrust(trust + 1) } }));
    function setTrust(v) {
      v = Math.max(0, Math.min(5, v));
      NX.rpc('contacts.update', { identity: NX.ident.id(), contact: c.id, trust: v }).then(res => {
        if (!res.ok) return NX.fail(res);
        trust = v; c.trust = v; NX.sound('tap'); stack.refresh();
      });
    }

    body.append(h('div', { class: 'card card--pad' }, rateRow, h('div', { class: 'sep' }), trustRow, trustCtl));

    const actions = h('div', { class: 'card' },
      NX.ui.row({ lead: NX.icon('darkchat', 'lrow__ic'), title: 'Envoyer un message', onClick: () => NX.openApp('darkchat', { dm: c.id, handle: c.handle }) }),
      NX.ui.row({ lead: NX.icon('edit', 'lrow__ic'), title: c.alias ? 'Modifier l\'alias' : 'Donner un alias', onClick: () => editAlias(c, refreshList) }),
      NX.ui.row({ lead: NX.icon('star', 'lrow__ic'), title: c.favorite ? 'Retirer des favoris' : 'Ajouter aux favoris', onClick: () => toggle('favorite', !c.favorite, c, refreshList) }),
      NX.ui.row({ lead: NX.icon('block', 'lrow__ic'), title: c.blocked ? 'Débloquer' : 'Bloquer', cls: 'lrow--danger', onClick: () => toggle('blocked', !c.blocked, c, refreshList) }),
      NX.ui.row({ lead: NX.icon('trash', 'lrow__ic'), title: 'Supprimer le contact', cls: 'lrow--danger', onClick: () => remove(c, refreshList) }));
    body.append(NX.ui.label('Actions'), actions);
  }

  function toggle(field, value, c, refreshList) {
    const args = { identity: NX.ident.id(), contact: c.id }; args[field] = value;
    NX.rpc('contacts.update', args).then(res => {
      if (!res.ok) return NX.fail(res);
      c[field] = value; NX.sound('tap'); stack.pop(); refreshList();
    });
  }

  function editAlias(c, refreshList) {
    NX.ui.prompt('Alias du contact', { value: c.alias || '', maxLength: 24, placeholder: 'ex. Fournisseur' }).then(alias => {
      if (alias === null) return;
      NX.rpc('contacts.update', { identity: NX.ident.id(), contact: c.id, alias }).then(res => {
        if (!res.ok) return NX.fail(res);
        c.alias = alias; NX.sound('tap'); stack.refresh(); refreshList();
      });
    });
  }

  function remove(c, refreshList) {
    NX.ui.confirm('Supprimer le contact', `« ${c.handle} » sera retiré de tes contacts.`, 'Supprimer', true).then(ok => {
      if (!ok) return;
      NX.rpc('contacts.remove', { identity: NX.ident.id(), contact: c.id }).then(res => {
        if (!res.ok) return NX.fail(res);
        NX.sound('close'); stack.pop(); refreshList();
      });
    });
  }

  NX.registerApp('ghostline', {
    title: 'Ghostline',
    render(body) {
      NX.ident.ensure(body, () => {
        body.textContent = '';
        stack = NX.ui.stack(body, 'Ghostline');
        stack.push('Ghostline', renderContacts);
      });
    },
    onBack() { return stack ? stack.pop() : false; },
    destroy() { if (stack) stack.destroy(); stack = null; offs.forEach(o => o()); offs = []; },
  });
})();
