/* NOIR X — connexion au réseau par burner.
 * À l'ouverture, tant que le joueur n'est pas connecté avec un burner actif, seul cet écran
 * est accessible : choisir un burner existant ou en créer un temporaire. Quand le burner
 * expire ou est révoqué, le serveur coupe la connexion (« auth:logout ») et l'écran revient. */
(function () {
  'use strict';
  const h = NX.h;
  const auth = { login: null, required: true, loadedAt: 0 };
  NX.auth = auth;

  const screen = document.getElementById('screen');
  const view = h('section', { class: 'view view--auth', attrs: { id: 'view-auth' } });
  screen.insertBefore(view, document.getElementById('sheet-host'));
  let ticker = null, notice = null;

  const remaining = () => Math.max(0, (auth.login ? auth.login.remaining : 0) - (Date.now() - auth.loadedAt) / 1000);

  function show(on) {
    view.classList.toggle('is-active', on);
    document.getElementById('view-home').classList.toggle('is-locked', on);
  }

  function durLabel(s) { return s >= 86400 ? `${Math.round(s / 86400)} j` : s >= 3600 ? `${Math.round(s / 3600)} h` : `${Math.round(s / 60)} min`; }

  function render(state) {
    view.textContent = '';
    const body = h('div', { class: 'auth' });
    body.append(h('img', { class: 'onboard__mark', attrs: { src: 'assets/emblem.svg', alt: '' } }),
      h('div', { class: 'onboard__title', text: 'Connexion au réseau' }),
      h('div', { class: 'onboard__text', text: 'Le réseau NOIR X n\'accepte que des identités jetables. Connecte-toi avec un burner : quand il expire, tu es déconnecté.' }));
    if (notice) { body.append(h('div', { class: 'notice' }, NX.icon('alert'), h('span', { text: notice }))); notice = null; }

    const list = state.burners || [];
    if (list.length) {
      const card = h('div', { class: 'card auth__list' });
      list.forEach(b => card.append(NX.ui.row({
        lead: NX.ui.avatar(b.handle, { small: true }), title: b.handle, sub: `Expire dans ${NX.ui.duration(b.remaining)}`, meta: 'Connexion',
        onClick: async () => {
          const res = await NX.rpc('auth.login', { identity: b.id });
          if (!res.ok) return NX.fail(res);
          loggedIn(res.login);
        },
      })));
      body.append(NX.ui.label('Tes burners actifs'), card);
    }

    const o = state.offer || { durations: [3600], price: 0, currency: 'clean', maxActive: 1 };
    let dur = 1;
    const input = NX.ui.input({ placeholder: 'Pseudo (facultatif, sinon aléatoire)', maxLength: 20 });
    const can = list.length < o.maxActive;
    const btn = NX.ui.button(`Créer un burner${o.price > 0 ? ` · ${NX.money(o.price)} ${o.currency === 'dirty' ? 'sale' : 'propre'}` : ''}`, 'primary', async () => {
      const res = await NX.rpc('auth.create', { duration: dur, handle: input.value.trim() || undefined });
      if (!res.ok) return NX.fail(res);
      NX.sound('win');
      loggedIn(res.login);
    }, 'burner');
    if (!can) btn.disabled = true;
    body.append(NX.ui.label('Nouveau burner temporaire'), h('div', { class: 'card card--pad' },
      input,
      h('div', { class: 'field-label', style: { marginTop: '12px' }, text: 'Durée de vie' }),
      NX.ui.chips(o.durations.map((d, i) => [i + 1, durLabel(d)]), dur, (v) => { dur = v; }),
      h('div', { class: 'stack-gap' }, btn),
      !can ? h('div', { class: 'hint', text: `Maximum ${o.maxActive} burner(s) actif(s) : connecte-toi avec celui que tu as.` }) : null));
    view.append(body);
    NX.applyIcons(view);
  }

  function badge() {
    let el = document.getElementById('auth-badge');
    if (!el) {
      el = h('button', { class: 'auth-badge', attrs: { id: 'auth-badge' } });
      el.addEventListener('click', async () => {
        if (!(await NX.ui.confirm('Se déconnecter ?', 'Tu pourras te reconnecter avec ce burner tant qu\'il n\'a pas expiré.', 'Déconnexion', true))) return;
        await NX.rpc('auth.logout');
        loggedOut('Déconnecté du réseau.');
      });
      const clock = document.querySelector('.home__clock');
      clock.parentNode.insertBefore(el, clock.nextSibling);
    }
    el.hidden = !auth.login;
    if (auth.login) el.textContent = `◉ ${auth.login.handle} · ${NX.ui.duration(remaining())}`;
  }

  function loggedIn(login) {
    auth.login = login;
    auth.loadedAt = Date.now();
    if (NX.ident) { NX.ident.current = null; NX.ident.loaded = false; }
    show(false);
    badge();
    clearInterval(ticker);
    ticker = setInterval(badge, 1000);
    NX.refreshWallet();
    NX.notify('NOIR X', `Connecté en tant que ${login.handle}.`);
  }

  function loggedOut(message) {
    auth.login = null;
    clearInterval(ticker);
    badge();
    if (NX.state.current) NX.closeApp(false);
    if (NX.ui && NX.ui.closeSheets) NX.ui.closeSheets();
    if (NX.ident) { NX.ident.current = null; NX.ident.list = []; NX.ident.loaded = false; }
    notice = message || null;
    refresh();
  }

  function refresh() {
    return NX.rpc('auth.state').then(res => {
      if (!res.ok) return;
      auth.required = res.required !== false;
      if (res.login) { auth.login = res.login; auth.loadedAt = Date.now(); show(false); badge(); clearInterval(ticker); ticker = setInterval(badge, 1000); return; }
      auth.login = null;
      badge();
      if (!auth.required) { show(false); return; }
      render(res);
      show(true);
    });
  }

  // À chaque ouverture du téléphone (le serveur répond après la création de la session)
  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') setTimeout(refresh, 50);
  });
  NX.on('auth:logout', (p) => loggedOut(p && p.message));
  // Un appel refusé faute de connexion ramène à l'écran de connexion
  const rpc = NX.rpc;
  NX.rpc = function (name, args) {
    return rpc(name, args).then(res => {
      if (res && res.ok === false && res.error === 'auth' && auth.login) loggedOut('Ta connexion a expiré.');
      else if (res && res.ok === false && res.error === 'auth' && !view.classList.contains('is-active')) refresh();
      return res;
    });
  };
  auth.refresh = refresh;
})();
