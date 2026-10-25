// =====================================================================
//  server_shop — NUI (boutique en jeu)
//  Le texte venant de l'API est toujours inséré comme texte (jamais en HTML).
//  La NUI n'envoie que des intentions (id produit, quantité) : le serveur décide de tout.
// =====================================================================
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'server_shop';
  const $ = (id) => document.getElementById(id);
  const shop = $('shop'), content = $('content'), nav = $('nav'), title = $('title'), back = $('back'), statusEl = $('status');

  const state = { data: null, view: 'home', category: null, product: null, pending: null, link: null, loading: false };

  // ---------- Outils ----------
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? '' : String(v));
    }
    for (const k of kids.flat()) if (k !== null && k !== undefined && k !== false) el.append(k instanceof Node ? k : document.createTextNode(String(k)));
    return el;
  }
  const post = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).catch(() => undefined);
  const money = (c, cur) => new Intl.NumberFormat('fr-FR', { style: 'currency', currency: cur || 'EUR' }).format((c || 0) / 100);
  const duration = (d) => (!d ? 'Permanent' : d % 30 === 0 ? `${d / 30} mois` : `${d} jour${d > 1 ? 's' : ''}`);
  const date = (d) => (d ? new Date(d).toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }) : '—');
  const img = (u) => {
    if (!u) return 'logo.webp';
    if (/^https:\/\//.test(u)) return u;
    const base = (state.data && state.data.siteUrl) || '';
    return u.startsWith('/') && /^https:\/\//.test(base) ? base.replace(/\/+$/, '') + u : 'logo.webp';
  };
  // Image introuvable (site injoignable…) : logo du serveur à la place
  function fallback(e) { if (!e.target.src.endsWith('logo.webp')) e.target.src = 'logo.webp'; }
  function toast(text, kind) {
    const t = h('div', { class: `toast ${kind || ''}` }, text);
    $('toasts').append(t);
    setTimeout(() => t.remove(), 4500);
  }
  function openUrl(url) {
    try { if (window.invokeNative) { window.invokeNative('openUrl', url); return true; } } catch (e) { /* non disponible */ }
    return false;
  }
  function copy(text) {
    const ta = h('textarea', {}, text);
    document.body.append(ta); ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    ta.remove();
    toast(ok ? 'Copié dans le presse-papiers.' : 'Copie impossible : sélectionnez le texte.', ok ? 'success' : 'error');
  }

  const STATUS = { pending: ['En attente de paiement', 'badge-amber'], paid: ['Payée', 'badge-green'], failed: ['Paiement refusé', 'badge-red'], cancelled: ['Annulée', 'badge-muted'], refunded: ['Remboursée', 'badge-blue'], chargeback: ['Litige bancaire', 'badge-red'] };
  const DELIVERY = { delivered: ['Livré', 'badge-green'], pending: ['À la prochaine connexion', 'badge-amber'], failed: ['Échec — contactez le support', 'badge-red'], cancelled: ['Annulé', 'badge-muted'], none: ['—', 'badge-muted'] };
  const ICONS = { crown: '♛', car: '🚗', package: '📦', sparkles: '✦', star: '★', gift: '🎁', bolt: '⚡', shield: '🛡' };

  // ---------- Rendu ----------
  function go(view, extra) { Object.assign(state, { view }, extra || {}); render(); content.scrollTop = 0; }

  function renderNav() {
    nav.replaceChildren();
    const cats = (state.data && state.data.catalog && state.data.catalog.categories) || [];
    const products = (state.data && state.data.catalog && state.data.catalog.products) || [];
    nav.append(h('button', { class: `nav-item ${state.view === 'home' ? 'on' : ''}`, onclick: () => go('home') }, '✦ Accueil'));
    for (const c of cats) {
      const n = products.filter((p) => p.category.id === c.id).length;
      nav.append(h('button', { class: `nav-item ${state.view === 'category' && state.category === c.id ? 'on' : ''}`, onclick: () => go('category', { category: c.id }) },
        `${ICONS[c.icon] || '★'} ${c.name}`, h('span', { class: 'n' }, n)));
    }
  }

  function card(p) {
    return h('article', { class: 'product-card', tabindex: 0, onclick: () => go('product', { product: p.id }), onkeydown: (e) => { if (e.key === 'Enter') go('product', { product: p.id }); } },
      h('div', { class: 'media' }, h('img', { src: img(p.imageUrl), alt: '', loading: 'lazy', onerror: fallback })),
      h('div', { class: 'tags' }, p.popular && h('span', { class: 'badge' }, 'Populaire'), h('span', { class: `badge ${p.durationDays ? 'badge-blue' : 'badge-muted'}` }, duration(p.durationDays))),
      h('div', { class: 'body' },
        h('span', { class: 'eyebrow', style: 'font-size:.7rem' }, p.category.name),
        h('h3', { class: 'title' }, p.name),
        h('p', { class: 'muted small', style: 'margin:0' }, p.shortDescription),
        h('div', { class: 'foot' }, h('span', { class: 'price' }, money(p.priceCents, p.currency)), p.available ? h('span', { class: 'badge badge-green' }, 'Disponible') : h('span', { class: 'badge badge-muted' }, 'Indisponible'))));
  }

  function grid(list, emptyText) {
    if (!list.length) return h('div', { class: 'empty' }, h('div', { class: 'icon' }, '★'), h('h3', {}, 'Aucun produit pour le moment'), h('p', {}, emptyText || 'Revenez bientôt.'));
    return h('div', { class: 'product-grid' }, list.map(card));
  }

  function viewHome() {
    const ps = state.data.catalog.products;
    const featured = ps.filter((p) => p.featured);
    const popular = ps.filter((p) => p.popular && !p.featured);
    title.textContent = 'Boutique';
    const parts = [];
    if (state.data.noCfx) parts.push(h('p', { class: 'alert alert-error' }, 'Votre jeu n\'est pas connecté à un compte Cfx.re : les achats sont impossibles. Connectez-vous dans les paramètres de FiveM puis relancez le jeu.'));
    if (featured.length) parts.push(h('h2', { class: 'section-title' }, 'À la une'), grid(featured));
    if (popular.length) parts.push(h('h2', { class: 'section-title' }, 'Populaires'), grid(popular));
    if (!featured.length && !popular.length) parts.push(grid(ps));
    parts.push(h('p', { class: 'muted small', style: 'margin-top:1.4rem' }, 'Paiement sécurisé par Tebex dans votre navigateur. Livraison automatique en jeu après confirmation du paiement.'));
    return parts;
  }

  function viewCategory() {
    const c = state.data.catalog.categories.find((x) => x.id === state.category);
    title.textContent = c ? c.name : 'Catégorie';
    return [c && c.description ? h('p', { class: 'muted' }, c.description) : null, grid(state.data.catalog.products.filter((p) => p.category.id === state.category))];
  }

  function viewProduct() {
    const p = state.data.catalog.products.find((x) => x.id === state.product);
    if (!p) return [h('p', { class: 'muted' }, 'Produit introuvable.')];
    title.textContent = p.name;
    let qty = 1;
    const qtySel = p.maxQuantity > 1 ? h('select', { class: 'input qty', onchange: (e) => { qty = Number(e.target.value); } }, Array.from({ length: p.maxQuantity }, (_, i) => h('option', { value: i + 1 }, i + 1))) : null;
    const buyBtn = h('button', { class: 'btn btn-primary', disabled: !p.available || state.data.noCfx || state.loading, onclick: () => {
      state.loading = true; state.pending = { productId: p.id, name: p.name }; buyBtn.disabled = true; buyBtn.textContent = 'Préparation du paiement…';
      post('checkout', { productId: p.id, quantity: qty });
    } }, state.loading ? 'Préparation du paiement…' : 'Acheter');
    return [h('div', { class: 'detail' },
      h('div', { class: 'visual' }, h('img', { src: img(p.imageUrl), alt: '', onerror: fallback })),
      h('div', {},
        h('div', { class: 'eyebrow' }, p.category.name),
        h('div', { class: 'row' }, h('span', { class: `badge ${p.durationDays ? 'badge-blue' : ''}` }, p.durationDays ? `Durée : ${duration(p.durationDays)}` : 'Permanent'), p.available ? h('span', { class: 'badge badge-green' }, 'Disponible') : h('span', { class: 'badge badge-muted' }, 'Indisponible')),
        h('span', { class: 'price' }, money(p.priceCents, p.currency)),
        h('p', {}, p.shortDescription),
        p.description ? h('p', { class: 'muted small' }, p.description) : null,
        p.perks.length ? h('ul', { class: 'perks' }, p.perks.map((k) => h('li', {}, k))) : null,
        p.durationDays ? h('p', { class: 'alert alert-info small', style: 'margin-top:1rem' }, `Produit temporaire : retiré automatiquement ${duration(p.durationDays)} après l'achat.`) : null,
        h('div', { class: 'row', style: 'margin-top:1.2rem' }, qtySel, buyBtn),
        h('p', { class: 'muted small', style: 'margin-top:.8rem' }, 'Le paiement se fait dans votre navigateur, sur Tebex, avec votre compte Cfx.re.')))];
  }

  function viewCheckout() {
    const r = state.checkout;
    title.textContent = 'Finaliser le paiement';
    const opened = r.opened;
    return [h('div', { class: 'panel panel-pad', style: 'max-width:44rem' },
      h('h3', {}, state.pending ? state.pending.name : 'Commande'),
      h('p', {}, opened ? 'La page de paiement s\'est ouverte dans votre navigateur.' : 'Ouvrez ce lien dans votre navigateur pour payer :'),
      h('div', { class: 'url' }, r.url),
      h('div', { class: 'row', style: 'margin-top:.8rem' },
        h('button', { class: 'btn btn-primary btn-sm', onclick: () => { if (!openUrl(r.url)) toast('Ouverture impossible : copiez le lien.', 'error'); } }, 'Ouvrir dans le navigateur'),
        h('button', { class: 'btn btn-sm', onclick: () => copy(r.url) }, 'Copier le lien')),
      h('div', { class: 'box small' },
        h('p', {}, '1. Connectez-vous avec votre compte Cfx.re (le même qu\'en jeu).'),
        h('p', {}, '2. Payez sur Tebex.'),
        h('p', { style: 'margin:0' }, '3. Restez en jeu : l\'achat est livré automatiquement dès que Tebex confirme le paiement (en général moins d\'une minute).')),
      h('p', { class: 'muted small', style: 'margin-top:1rem' }, 'Rien n\'est livré tant que Tebex n\'a pas confirmé le paiement. Si vous fermez la page de paiement, aucun montant n\'est prélevé.'),
      h('button', { class: 'btn btn-sm btn-ghost', onclick: () => { post('refresh'); go('history'); } }, 'Voir mon historique'))];
  }

  function viewHistory() {
    title.textContent = 'Historique des achats';
    const s = state.data.summary;
    if (!s) return [h('p', { class: 'alert' }, state.data.noCfx ? 'Compte Cfx.re non détecté.' : 'Historique indisponible pour le moment.')];
    const parts = [];
    if (s.entitlements && s.entitlements.length) {
      parts.push(h('h2', { class: 'section-title' }, 'Avantages actifs'), h('div', { class: 'row' }, s.entitlements.map((e) => h('span', { class: 'badge' }, `${e.product}${e.expiresAt ? ' · jusqu\'au ' + date(e.expiresAt) : ''}`))));
    }
    parts.push(h('h2', { class: 'section-title' }, 'Achats'));
    if (!s.history.length) parts.push(h('div', { class: 'empty' }, h('h3', {}, 'Aucun achat pour le moment')));
    for (const o of s.history) {
      const st = STATUS[o.status] || [o.status, 'badge-muted'];
      parts.push(h('div', { class: 'order' },
        h('header', {}, h('strong', {}, date(o.createdAt)), h('span', { class: `badge ${st[1]}` }, st[0]), h('strong', { class: 'price', style: 'font-size:1rem' }, money(o.totalCents, o.currency))),
        h('ul', {}, o.items.map((i) => h('li', {}, h('span', {}, `${i.quantity} × ${i.name}${i.expiresAt ? ' — jusqu\'au ' + date(i.expiresAt) : ''}`),
          o.status === 'paid' ? h('span', { class: `badge ${(DELIVERY[i.delivery] || DELIVERY.none)[1]}` }, (DELIVERY[i.delivery] || DELIVERY.none)[0]) : null)))));
    }
    return parts;
  }

  function viewAccount() {
    title.textContent = 'Mon compte web';
    const linked = state.data.summary && state.data.summary.linked;
    return [h('div', { class: 'panel panel-pad', style: 'max-width:44rem' },
      h('p', {}, linked ? 'Votre compte est déjà lié au site. Vous pouvez générer un nouveau code pour vous connecter sur un autre appareil.' : 'Liez votre compte pour suivre vos achats sur le site de la boutique.'),
      state.link && state.link.code ? [h('div', { class: 'code' }, state.link.code), h('p', { class: 'muted small' }, 'Valable 10 minutes, une seule fois. Saisissez-le sur :'), h('div', { class: 'url' }, state.link.url),
        h('div', { class: 'row', style: 'margin-top:.8rem' }, h('button', { class: 'btn btn-sm', onclick: () => { if (!openUrl(state.link.url)) copy(state.link.url); } }, 'Ouvrir le site'), h('button', { class: 'btn btn-sm', onclick: () => copy(state.link.code) }, 'Copier le code'))] : null,
      h('div', { class: 'row', style: 'margin-top:1rem' }, h('button', { class: 'btn btn-primary btn-sm', disabled: state.data.noCfx || state.loading, onclick: () => { state.loading = true; render(); post('link'); } }, state.loading ? 'Génération…' : 'Générer un code')),
      h('p', { class: 'muted small', style: 'margin-top:1rem' }, `Aussi disponible avec la commande /boutique_lier. Ne communiquez jamais ce code.`))];
  }

  function render() {
    statusEl.textContent = state.data && state.data.account ? state.data.account.name : '';
    statusEl.classList.toggle('hidden', !statusEl.textContent);
    if (!state.data) { content.replaceChildren(h('div', { class: 'center' }, h('div', {}, h('div', { class: 'spinner', style: 'margin:0 auto 1rem' }), 'Chargement de la boutique…'))); return; }
    if (state.data.error) { content.replaceChildren(h('div', { class: 'center' }, h('div', {}, h('p', { class: 'alert alert-error' }, state.data.error), h('button', { class: 'btn btn-sm', onclick: () => { state.data = null; render(); post('refresh'); } }, 'Réessayer')))); nav.replaceChildren(); return; }
    renderNav();
    back.classList.toggle('hidden', state.view === 'home');
    const views = { home: viewHome, category: viewCategory, product: viewProduct, checkout: viewCheckout, history: viewHistory, account: viewAccount };
    content.replaceChildren(...[].concat((views[state.view] || viewHome)()).filter(Boolean));
  }

  // ---------- Événements ----------
  back.addEventListener('click', () => {
    if (state.view === 'product') {
      const p = state.data.catalog.products.find((x) => x.id === state.product);
      return go(p ? 'category' : 'home', { category: p ? p.category.id : null });
    }
    go('home');
  });
  document.querySelectorAll('[data-view]').forEach((b) => b.addEventListener('click', () => go(b.dataset.view)));
  $('close').addEventListener('click', () => post('close'));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !shop.classList.contains('hidden')) post('close'); });

  window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'open') {
      shop.classList.remove('hidden', 'closing');
      state.data = null; state.view = 'home'; state.loading = false;
      render();
    } else if (m.action === 'close') {
      shop.classList.add('closing');
      setTimeout(() => { shop.classList.add('hidden'); shop.classList.remove('closing'); }, 200);
    } else if (m.action === 'data') {
      state.data = m.data;
      $('server-name').textContent = (m.data && m.data.serverName) || 'Boutique';
      if (state.view !== 'checkout') render();
    } else if (m.action === 'result') {
      state.loading = false;
      const d = m.data || {};
      if (d.error) { toast(d.error, 'error'); render(); return; }
      if (m.kind === 'checkout') { state.checkout = { url: d.url, opened: openUrl(d.url) }; go('checkout'); }
      else if (m.kind === 'link') { state.link = d; render(); }
    }
  });
})();
