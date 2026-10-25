// =====================================================================
//  ELYZEA SHOP — NUI
//  · Les textes venant du serveur sont insérés comme TEXTE (jamais comme HTML).
//  · La NUI n'envoie que des intentions (clé produit) : prix, compte et paiement sont décidés côté serveur.
//  · Un clic « Acheter avec Tebex » ouvre la boutique Tebex officielle : rien n'est livré avant la
//    confirmation du paiement par Tebex (commande exécutée dans la console du serveur).
// =====================================================================
(() => {
  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_shop';
  const $ = (id) => document.getElementById(id);
  const shop = $('shop'), content = $('content'), nav = $('nav'), title = $('title'), back = $('back'), modal = $('modal'), wallet = $('wallet');
  const S = { data: null, view: 'home', category: null, product: null, busy: false };
  const ICONS = { crown: '♛', coin: '◎', car: '🚘', star: '★', gift: '🎁' };

  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? '' : String(v));
    }
    for (const c of kids.flat()) if (c !== null && c !== undefined && c !== false) el.append(c instanceof Node ? c : document.createTextNode(String(c)));
    return el;
  }
  const post = (name, body) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).catch(() => undefined);
  const fmt = (n) => new Intl.NumberFormat('fr-FR').format(n || 0);
  const date = (d) => { if (!d) return '—'; const x = typeof d === 'number' ? new Date(d > 1e12 ? d : d * 1000) : new Date(String(d).replace(' ', 'T') + (String(d).includes('Z') ? '' : 'Z')); return isNaN(x) ? String(d) : x.toLocaleString('fr-FR', { dateStyle: 'medium', timeStyle: 'short' }); };
  const duration = (d) => (!d ? 'Permanent' : d % 30 === 0 ? `${d / 30} mois` : `${d} jours`);
  const fallback = (e) => { if (!e.target.src.endsWith('assets/logo.webp')) e.target.src = 'assets/logo.webp'; };
  const coinsOn = () => S.data && S.data.coins && S.data.coins.enabled;

  function toast(text, kind, ms) {
    const t = h('div', { class: `toast ${kind || ''}` }, text);
    $('toasts').append(t);
    setTimeout(() => t.remove(), ms || 4500);
    return t;
  }
  function openUrl(url) { try { if (window.invokeNative) { window.invokeNative('openUrl', url); return true; } } catch (e) { /* indisponible */ } return false; }
  function copy(text) {
    const ta = h('textarea', {}, text); document.body.append(ta); ta.select();
    let ok = false; try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    ta.remove(); toast(ok ? 'Lien copié.' : 'Copie impossible : sélectionnez le lien.', ok ? 'success' : 'error');
  }
  function confirmBox(titleText, body, okText, onOk) {
    modal.replaceChildren(h('div', { class: 'box' }, h('h3', {}, titleText), ...[].concat(body),
      h('div', { class: 'row', style: 'justify-content:flex-end;margin-top:1rem' },
        h('button', { class: 'btn btn-sm', onclick: () => modal.classList.add('hidden') }, okText ? 'Annuler' : 'Fermer'),
        okText ? h('button', { class: 'btn btn-gold btn-sm', onclick: () => { modal.classList.add('hidden'); onOk(); } }, okText) : null)));
    modal.classList.remove('hidden');
  }

  // ---------- Vues ----------
  const go = (view, extra) => { Object.assign(S, { view }, extra || {}); render(); content.scrollTop = 0; };
  const products = () => (S.data && S.data.catalog.products) || [];

  function priceTags(p) {
    const out = [];
    if (p.tebex) out.push(h('span', { class: 'price' }, p.displayPrice || 'Voir sur Tebex'));
    if (p.coinsPrice && coinsOn()) out.push(h('span', { class: 'price coins' }, fmt(p.coinsPrice)));
    if (!out.length) out.push(h('span', { class: 'badge badge-muted' }, 'Bientôt disponible'));
    return out;
  }

  function card(p) {
    return h('article', { class: 'card', tabindex: 0, onclick: () => go('product', { product: p.key }), onkeydown: (e) => { if (e.key === 'Enter') go('product', { product: p.key }); } },
      h('div', { class: 'media' }, h('img', { src: p.image || 'assets/logo.webp', alt: '', loading: 'lazy', onerror: fallback })),
      h('div', { class: 'tags' }, p.category === 'vip' || p.durationDays ? h('span', { class: `badge ${p.durationDays ? 'badge-blue' : ''}` }, duration(p.durationDays)) : null),
      h('div', { class: 'body' }, h('h3', { class: 'title' }, p.label), h('p', { class: 'muted small', style: 'margin:0' }, p.description || ''),
        h('div', { class: 'foot' }, priceTags(p))));
  }
  const grid = (list) => list.length ? h('div', { class: 'grid' }, list.map(card)) : h('div', { class: 'center' }, h('div', {}, h('h3', {}, 'Aucun produit pour le moment'), h('p', {}, 'Revenez bientôt.')));

  function viewHome() {
    title.textContent = 'Boutique';
    const cats = S.data.catalog.categories;
    return [
      S.data.noAccount ? h('p', { class: 'note error' }, 'Votre jeu n\'est pas relié à un compte Cfx.re : connectez-vous à votre compte dans FiveM pour acheter.') : null,
      h('div', { class: 'hero' }, h('div', { class: 'eyebrow' }, 'Boutique officielle'), h('h2', {}, 'Soutenez ', h('span', { class: 'gold' }, S.data.serverName || 'Elyzea RP')),
        h('p', { class: 'muted', style: 'max-width:36rem' }, 'Grades VIP, Elyzea Coins et véhicules premium. Les paiements sont traités par Tebex, partenaire officiel de FiveM ; vos achats sont livrés automatiquement en jeu après confirmation.')),
      h('div', { class: 'cat-cards' }, cats.map((c) => h('button', { class: 'cat-card', onclick: () => go('category', { category: c.id }) },
        h('span', { class: 'ico' }, ICONS[c.icon] || '★'), h('strong', {}, c.label), h('span', { class: 'muted small' }, c.description || '')))),
      h('h3', {}, 'Les grades VIP'), grid(products().filter((p) => p.category === 'vip')),
    ];
  }

  function viewCategory() {
    const c = S.data.catalog.categories.find((x) => x.id === S.category);
    title.textContent = c ? c.label : 'Catégorie';
    return [c && c.description ? h('p', { class: 'muted' }, c.description) : null, grid(products().filter((p) => p.category === S.category))];
  }

  function viewProduct() {
    const p = products().find((x) => x.key === S.product);
    if (!p) return [h('p', { class: 'muted' }, 'Produit introuvable.')];
    title.textContent = p.label;
    const box = h('div', { class: 'buy-box' });
    if (p.tebex) {
      box.append(h('div', { class: 'buy-line' }, h('div', {}, h('div', { class: 'eyebrow' }, 'Paiement sécurisé Tebex'), h('span', { class: 'price' }, p.displayPrice || 'Prix affiché sur Tebex')),
        h('button', { class: 'btn btn-gold', disabled: S.data.noAccount || S.busy, onclick: () => buyTebex(p) }, 'Acheter avec Tebex')));
    }
    if (p.coinsPrice && coinsOn()) {
      const enough = (S.data.player.coins || 0) >= p.coinsPrice;
      box.append(h('div', { class: 'buy-line' }, h('div', {}, h('div', { class: 'eyebrow' }, S.data.coins.label), h('span', { class: 'price coins' }, fmt(p.coinsPrice))),
        h('button', { class: 'btn', disabled: S.data.noAccount || S.busy || !enough, title: enough ? '' : 'Solde insuffisant', onclick: () => buyCoins(p) }, enough ? 'Acheter avec des coins' : 'Solde insuffisant')));
    }
    if (!p.tebex && !(p.coinsPrice && coinsOn())) box.append(h('p', { class: 'muted', style: 'margin:0' }, 'Ce produit n\'est pas encore disponible à l\'achat.'));
    return [h('div', { class: 'detail' },
      h('div', { class: 'visual' }, h('img', { src: p.image || 'assets/logo.webp', alt: '', onerror: fallback })),
      h('div', {},
        h('div', { class: 'row' }, h('span', { class: 'badge' }, (S.data.catalog.categories.find((c) => c.id === p.category) || {}).label || p.category),
          p.durationDays ? h('span', { class: 'badge badge-blue' }, `Durée : ${duration(p.durationDays)}`) : null),
        h('p', { style: 'margin-top:.8rem' }, p.description || ''),
        p.perks && p.perks.length ? h('ul', { class: 'perks' }, p.perks.map((k) => h('li', {}, k))) : null,
        p.durationDays ? h('p', { class: 'note' }, `Produit temporaire : retiré automatiquement après ${duration(p.durationDays)}. Un nouvel achat prolonge la durée.`) : null,
        box))];
  }

  function viewHistory() {
    title.textContent = 'Historique';
    const pl = S.data.player || {};
    const parts = [];
    if (pl.vip && pl.vip.length) parts.push(h('h3', {}, 'Avantages actifs'), h('div', { class: 'row', style: 'margin-bottom:1rem' }, pl.vip.map((v) => h('span', { class: 'badge' }, `${v.label || v.name}${Number(v.permanent) ? '' : ' · jusqu\'au ' + date(v.expires_at)}`))));
    parts.push(h('h3', {}, 'Achats et récompenses'));
    const st = { delivered: ['Livré', 'badge-green'], pending: ['En attente (prochaine connexion)', 'badge-amber'], failed: ['Échec — contactez le staff', 'badge-red'], cancelled: ['Annulé', 'badge-muted'] };
    const src = { tebex: 'Tebex', coins: 'Coins', admin: 'Staff' };
    if (!pl.history || !pl.history.length) parts.push(h('p', { class: 'muted' }, 'Aucun achat pour le moment.'));
    else parts.push(h('div', { class: 'list' }, pl.history.map((r) => h('div', { class: 'item' },
      h('div', {}, h('strong', {}, `${r.action === 'revoke' ? 'Retrait · ' : ''}${r.label}`), h('div', { class: 'muted small' }, `${date(r.created_at)} · ${src[r.source] || r.source}`), r.transaction_id ? h('div', { class: 'ref' }, `Transaction ${r.transaction_id}`) : null),
      h('span', { class: `badge ${(st[r.status] || [])[1] || 'badge-muted'}` }, (st[r.status] || [r.status])[0])))));
    if (coinsOn()) {
      parts.push(h('h3', { style: 'margin-top:1.2rem' }, `Mouvements ${S.data.coins.label}`));
      const ch = pl.coinHistory || [];
      parts.push(ch.length ? h('div', { class: 'list' }, ch.map((m) => h('div', { class: 'item' }, h('div', {}, h('strong', {}, m.reason), h('div', { class: 'muted small' }, date(m.created_at))),
        h('span', { class: m.delta >= 0 ? 'delta-plus' : 'delta-minus' }, `${m.delta >= 0 ? '+' : ''}${fmt(m.delta)}`)))) : h('p', { class: 'muted' }, 'Aucun mouvement.'));
    }
    return parts;
  }

  function renderNav() {
    nav.replaceChildren(h('button', { class: `nav-item ${S.view === 'home' ? 'on' : ''}`, onclick: () => go('home') }, h('span', { class: 'ico' }, '✦'), 'Accueil'),
      ...S.data.catalog.categories.map((c) => h('button', { class: `nav-item ${(S.view === 'category' && S.category === c.id) ? 'on' : ''}`, onclick: () => go('category', { category: c.id }) }, h('span', { class: 'ico' }, ICONS[c.icon] || '★'), c.label)));
    document.querySelector('[data-view="history"]').classList.toggle('on', S.view === 'history');
    if (coinsOn() && S.data.player && S.data.player.coins !== undefined) {
      wallet.replaceChildren(h('small', {}, S.data.coins.label), h('strong', {}, `${fmt(S.data.player.coins)} ${S.data.coins.short}`));
      wallet.classList.remove('hidden');
    } else wallet.classList.add('hidden');
  }

  function render() {
    if (!S.data) { content.replaceChildren(h('div', { class: 'center' }, h('div', {}, h('div', { class: 'spinner' }), 'Chargement de la boutique…'))); return; }
    if (S.data.error) { nav.replaceChildren(); content.replaceChildren(h('div', { class: 'center' }, h('div', {}, h('p', { class: 'note error' }, S.data.error), h('button', { class: 'btn btn-sm', onclick: () => { S.data = null; render(); post('refresh'); } }, 'Réessayer')))); return; }
    $('server-name').textContent = S.data.serverName || 'Elyzea RP';
    renderNav();
    back.classList.toggle('hidden', S.view === 'home');
    const v = { home: viewHome, category: viewCategory, product: viewProduct, history: viewHistory }[S.view] || viewHome;
    content.replaceChildren(...[].concat(v()).filter(Boolean));
  }

  // ---------- Achats ----------
  function buyTebex(p) {
    confirmBox('Acheter avec Tebex', [
      h('p', {}, `« ${p.label} » se paie sur la boutique officielle Tebex, dans votre navigateur.`),
      h('p', { class: 'note' }, 'Connectez-vous à Tebex avec le même compte Cfx.re que dans le jeu. La livraison est automatique dès que Tebex confirme le paiement (en ligne ou à votre prochaine connexion).'),
    ], 'Ouvrir Tebex', () => { S.busy = true; render(); post('tebex', { key: p.key }); });
  }
  function buyCoins(p) {
    confirmBox('Confirmer l\'achat', [h('p', {}, `Acheter « ${p.label} » pour ${fmt(p.coinsPrice)} ${S.data.coins.short} ?`),
      h('p', { class: 'muted small' }, `Solde après achat : ${fmt((S.data.player.coins || 0) - p.coinsPrice)} ${S.data.coins.short}`)],
    'Confirmer', () => { S.busy = true; render(); S.loadingToast = toast('Achat en cours…', 'loading', 15000); post('buyCoins', { key: p.key }); });
  }

  // ---------- Événements ----------
  back.addEventListener('click', () => {
    if (S.view === 'product') { const p = products().find((x) => x.key === S.product); return go(p ? 'category' : 'home', { category: p && p.category }); }
    go('home');
  });
  document.querySelector('[data-view="history"]').addEventListener('click', () => go('history'));
  $('close').addEventListener('click', () => post('close'));
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || shop.classList.contains('hidden')) return;
    if (!modal.classList.contains('hidden')) modal.classList.add('hidden'); else post('close');
  });

  window.addEventListener('message', (ev) => {
    const m = ev.data || {};
    if (m.action === 'open') {
      shop.classList.remove('hidden', 'closing'); modal.classList.add('hidden');
      S.data = null; S.view = 'home'; S.busy = false; render();
    } else if (m.action === 'close') {
      shop.classList.add('closing'); modal.classList.add('hidden');
      setTimeout(() => { shop.classList.add('hidden'); shop.classList.remove('closing'); }, 200);
    } else if (m.action === 'data') {
      S.data = m.data; render();
    } else if (m.action === 'result') {
      S.busy = false;
      if (S.loadingToast) { S.loadingToast.remove(); S.loadingToast = null; }
      const d = m.data || {};
      if (d.error) { toast(d.error, 'error'); render(); return; }
      if (m.kind === 'tebex') {
        const opened = openUrl(d.url);
        confirmBox(opened ? 'Paiement ouvert dans votre navigateur' : 'Ouvrez ce lien pour payer', [
          h('div', { class: 'url' }, d.url),
          h('div', { class: 'row' }, h('button', { class: 'btn btn-sm', onclick: () => copy(d.url) }, 'Copier le lien'), h('button', { class: 'btn btn-sm', onclick: () => openUrl(d.url) || toast('Ouverture impossible : copiez le lien.', 'error') }, 'Ouvrir')),
          h('p', { class: 'note warn', style: 'margin-top:.8rem' }, 'Rien n\'est livré tant que Tebex n\'a pas confirmé le paiement. Si vous abandonnez le paiement, aucun montant n\'est prélevé.'),
        ], null);
        render();
      } else if (m.kind === 'coins') {
        toast(d.status === 'delivered' ? `${d.label} : livré !` : `${d.label} : acheté, livraison en cours.`, 'success');
        if (S.data && S.data.player) S.data.player.coins = d.coins;
        post('refresh');
      }
    }
  });
})();
