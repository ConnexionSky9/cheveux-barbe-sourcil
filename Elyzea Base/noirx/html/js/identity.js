/* NOIR X — identités clandestines (pseudonyme principal + burners) partagées par Dark Chat et Ghostline. */
(function () {
  'use strict';
  const h = NX.h;
  const KEY = 'noirx_identity';

  const ident = { list: [], current: null, rules: { min: 3, max: 20 }, loaded: false };

  function remember(id) { try { localStorage.setItem(KEY, String(id)); } catch (e) { /* stockage indisponible */ } }
  function recall() { try { return Number(localStorage.getItem(KEY)) || null; } catch (e) { return null; } }

  ident.load = function () {
    return NX.rpc('ghost.me').then(res => {
      if (!res.ok) { NX.fail(res); return false; }
      ident.list = res.identities || [];
      ident.rules = res.rules || ident.rules;
      ident.loaded = true;
      // Connecté avec un burner : on ne parle qu'en tant que ce burner
      const login = NX.auth && NX.auth.login;
      if (login) {
        ident.list = ident.list.filter(i => i.id === login.id);
        if (!ident.list.length) ident.list = [{ id: login.id, handle: login.handle, kind: 'burner', reputation: 0, expiresAt: Date.now() / 1000 + login.remaining }];
        ident.current = ident.list[0];
        return true;
      }
      const wanted = ident.current ? ident.current.id : recall();
      ident.current = ident.list.find(i => i.id === wanted) || ident.list.find(i => i.kind === 'main') || ident.list[0] || null;
      return true;
    });
  };

  ident.select = function (id) {
    const found = ident.list.find(i => i.id === id);
    if (!found) return;
    ident.current = found;
    remember(id);
    NX.emit('identity:changed', found);
  };

  ident.id = () => ident.current && ident.current.id;
  ident.owns = (id) => ident.list.some(i => i.id === id);

  /** Bouton affichant l'identité active ; ouvre le sélecteur. */
  ident.switcher = function () {
    const cur = ident.current;
    const btn = h('button', { class: 'idchip' + (cur && cur.kind === 'burner' ? ' idchip--burner' : '') },
      NX.icon(cur && cur.kind === 'burner' ? 'burner' : 'user'),
      h('span', { text: cur ? cur.handle : '—' }),
      ident.list.length > 1 ? NX.icon('chevron', 'idchip__chev') : null);
    btn.addEventListener('click', () => {
      if (ident.list.length < 2) return;
      NX.sound('tap');
      const list = h('div', { class: 'card' });
      ident.list.forEach(i => list.append(NX.ui.row({
        lead: NX.ui.avatar(i.handle, { small: true }),
        title: i.handle,
        sub: i.kind === 'burner' ? `Burner · expire dans ${NX.ui.duration(i.expiresAt - Date.now() / 1000)}` : 'Identité principale',
        meta: cur && cur.id === i.id ? 'active' : '',
        onClick: () => { ident.select(i.id); NX.ui.closeTopSheet(); },
      })));
      NX.ui.sheet({ title: 'Parler en tant que', content: list });
    });
    return btn;
  };

  /** Affiche la création d'identité si nécessaire, puis appelle onReady(). */
  ident.ensure = function (body, onReady) {
    body.textContent = '';
    body.append(NX.ui.loader());
    ident.load().then(ok => {
      if (!ok) { body.textContent = ''; body.append(NX.ui.empty('lock', 'Réseau indisponible', 'Impossible de charger ton identité.')); return; }
      if (ident.current) { onReady(); return; }
      body.textContent = '';
      const input = NX.ui.input({ placeholder: 'ex. corvus_07', maxLength: ident.rules.max });
      const submit = () => {
        NX.rpc('ghost.create', { handle: input.value.trim() }).then(res => {
          if (!res.ok) return NX.fail(res);
          ident.list = res.identities || [];
          ident.current = ident.list.find(i => i.kind === 'main') || ident.list[0];
          if (ident.current) remember(ident.current.id);
          NX.sound('win');
          onReady();
        });
      };
      input.addEventListener('keydown', e => { if (e.key === 'Enter') submit(); });
      body.append(h('div', { class: 'onboard' },
        h('img', { class: 'onboard__mark', attrs: { src: 'assets/emblem.svg', alt: '' } }),
        h('div', { class: 'onboard__title', text: 'Choisis ton nom de code' }),
        h('div', { class: 'onboard__text', text: 'Il remplace ton identité sur tout le réseau NOIR X. Personne ne verra ton vrai nom.' }),
        input,
        h('div', { class: 'hint', text: `${ident.rules.min} à ${ident.rules.max} caractères : lettres, chiffres, _ - .` }),
        NX.ui.button('Rejoindre le réseau', 'primary', submit)));
      NX.applyIcons(body);
      setTimeout(() => input.focus(), 50);
    });
  };

  NX.ident = ident;
})();
