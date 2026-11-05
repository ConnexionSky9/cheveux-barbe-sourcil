'use strict';
/* =========================================================
   VENDEUR DE TÉLÉPHONES (PNJ de l'éditeur de map, rôle « Vendeur de téléphones »)
   Vitrine des 6 ElyAura : rendu de chaque modèle, prix, ce qu'il apporte,
   achat en liquide ou par carte. L'ElyAura 6 est réservé aux abonnés Royale (vérifié par le serveur).
   PhoneArt.render(n) : dessin d'un modèle (vitrine, images d'inventaire, aperçus).
   ========================================================= */
const PhoneArt = (() => {
  const apps = (n) => n === 1 ? ['#3FBF8E', '#4C8DFF', '#F5A524', '#9B5CFF', '#8A90A8']
    : ['#3FBF8E', '#4C8DFF', '#F5A524', '#FF6F9E', '#2FC9D9', '#9B5CFF', '#FF6B7A', '#7FCB3A', '#8A90A8', '#E2569A', '#4C6FFF', '#F2711C'].slice(0, n >= 4 ? 12 : n === 3 ? 12 : 8);
  function screen(n) {
    const ic = apps(n).map((c) => `<i style="background:linear-gradient(150deg,${c},color-mix(in srgb,${c} 55%,#000))"></i>`).join('');
    return `<div class="pa-scr"><div class="pa-wp"></div>${n >= 4 ? '<span class="pa-island"></span>' : ''}<b class="pa-time">${n === 1 ? '12:30' : '21:47'}</b>
      ${n >= 5 ? '<div class="pa-wds"><s></s><s></s></div>' : ''}<div class="pa-grid">${ic}</div>${n === 1 ? '' : '<span class="pa-bar"></span>'}</div>`;
  }
  function render(n, opts = {}) {
    const open = (n === 5 || n === 6) && opts.open;
    return `<div class="pa" data-m="${n}" ${open ? 'data-open="1"' : ''}>
      <div class="pa-body">${n === 1 ? '<i class="pa-spk"></i><i class="pa-cam1"></i><em>ElyAura</em>' : ''}${n === 2 ? '<i class="pa-notch"></i><em>ElyAura</em>' : ''}${n === 3 ? '<i class="pa-hole"></i>' : ''}
        ${screen(n)}${open ? `<i class="pa-hinge"></i>${screen(n)}` : ''}${n === 1 ? '<i class="pa-home"></i>' : ''}</div>
      ${n >= 4 ? '<div class="pa-glow"></div>' : ''}</div>`;
  }
  return { render };
})();

const PHONE_FEATURES = {
  1: ['Appels, messages, contacts', 'Banque et papiers (identité, permis, PPA)', 'Partager son numéro', 'Code de verrouillage (pas de Face ID)'],
  2: ['Toutes les applications du quotidien', 'Face ID', 'Thème clair / sombre, 3 fonds, 3 couleurs'],
  3: ['+ Livrézy et HelpMécano', 'Écran bord à bord, cadre aluminium', 'Tous les fonds, couleurs, cadres, icônes'],
  4: ['+ Itoune', 'Effets animés de l\'accueil', 'Coques, couleur et fond d\'écran libres'],
  5: ['Pliable : deux écrans, tenu à deux mains', 'Widgets de l\'accueil', 'Sonnerie personnalisée, écran verrouillé'],
  6: ['Pliable : deux écrans, tenu à deux mains', '+ CarPlay et Garage', 'Liseré arc-en-ciel, couleur libre', 'Cadres et fonds exclusifs, police, icônes'],
};

const PShop = (() => {
  let root, data = null, sel = 1, busy = false;
  const money = (v) => `${Math.round(Number(v) || 0).toLocaleString('fr-FR')} $`;
  function ensure() {
    if (root) return root;
    root = document.createElement('div');
    root.id = 'pshop'; root.className = 'hidden';
    document.body.appendChild(root);
    root.addEventListener('click', (e) => {
      const b = e.target.closest('[data-ps]');
      if (b) {
        const a = b.dataset.ps;
        if (a === 'close') return close();
        if (a === 'sel') { sel = Number(b.dataset.n); return draw(); }
        if (a === 'buy' && !busy) { busy = true; draw(); post('phoneShopBuy', { n: sel, method: b.dataset.method }); }
      }
    });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && root && !root.classList.contains('hidden')) close(); });
    return root;
  }
  function draw(msg) {
    const list = data.list || [], m = list.find((x) => x.n === sel) || list[0];
    if (!m) return;
    const locked = m.vip && !data.vip;
    root.innerHTML = `<div class="ps">
      <header class="ps-head"><div><small>Boutique officielle</small><b>${esc(data.name || 'ElyAura Store')}</b></div>
        <div class="ps-wallet"><span>💵 ${money(data.cash)}</span>${data.allowBank ? `<span>💳 ${money(data.bank)}</span>` : ''}</div>
        <button class="ps-x" data-ps="close" aria-label="Fermer">✕</button></header>
      <nav class="ps-range">${list.map((x) => `<button class="${x.n === sel ? 'on' : ''}" data-ps="sel" data-n="${x.n}">
        <span class="ps-thumb">${PhoneArt.render(x.n)}</span><b>${esc(x.label)}</b><small>${money(x.price)}</small>${x.owned ? '<em>Possédé</em>' : ''}${x.vip ? '<i>Royale</i>' : ''}</button>`).join('')}</nav>
      <section class="ps-main">
        <div class="ps-stage" data-m="${m.n}">${PhoneArt.render(m.n, { open: m.fold })}</div>
        <div class="ps-info">
          <p class="ps-gen">Génération ${m.n}${m.fold ? ' · pliable' : ''}${m.vip ? ' · exclusif abonnés' : ''}</p>
          <h1>${esc(m.label)}</h1><p class="ps-tag">${esc(m.tagline || '')}</p>
          <ul>${(PHONE_FEATURES[m.n] || []).map((f) => `<li>${esc(f)}</li>`).join('')}</ul>
          <div class="ps-price">${money(m.price)}</div>
          ${locked ? '<p class="ps-lock">🔒 Réservé aux abonnés <b>Elyzea Royale</b> (ou supérieur). Abonnez-vous depuis la boutique du serveur.</p>'
            : `<div class="ps-buy"><button class="ps-btn" data-ps="buy" data-method="cash" ${busy ? 'disabled' : ''}>Payer en liquide</button>
               ${data.allowBank ? `<button class="ps-btn ps-btn--ghost" data-ps="buy" data-method="bank" ${busy ? 'disabled' : ''}>Payer par carte</button>` : ''}</div>`}
          ${m.owned ? '<p class="ps-note">Vous l\'avez déjà : « Utiliser » dans l\'inventaire pour en faire votre téléphone.</p>' : ''}
          ${msg ? `<p class="ps-msg ${msg.ok ? 'ok' : 'ko'}">${esc(msg.text)}</p>` : ''}
        </div></section></div>`;
  }
  function open(d) {
    ensure(); data = d; busy = false;
    sel = Math.min(6, Math.max(1, ...(d.list || []).filter((x) => x.owned).map((x) => x.n + 1), 1));
    root.classList.remove('hidden'); draw();
  }
  function close() { if (!root) return; root.classList.add('hidden'); post('phoneShopClose', {}); }
  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'phoneShop') open(m.data || {});
    if (m.action === 'phoneShopResult' && data) {
      const r = m.data || {}; busy = false;
      if (r.list) data.list = r.list;
      if (r.cash != null) data.cash = r.cash;
      if (r.bank != null) data.bank = r.bank;
      draw({ ok: r.ok, text: r.ok ? r.message : r.error });
    }
  });
  return { open, close };
})();
