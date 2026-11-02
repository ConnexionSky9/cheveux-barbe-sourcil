/* =========================================================
   PAIEMENT DES BOUTIQUES PNJ (commun : supérette, armurerie,
   tatoueur, coiffeur) : liquide, carte, pesos ou objet.
   Le serveur envoie shop.methods (moyens acceptés, le 1er par
   défaut), shop.rate (pesos pour 1 $) et shop.wallet.
   ========================================================= */
window.PayUI = (() => {
    const NAMES = { cash: 'Liquide', bank: 'Carte', pesos: 'Pesos', item: 'Objet' };
    const ICONS = { cash: '💵', bank: '🏦', pesos: '🪙', item: '👜' };
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const nf = (n) => Number(n || 0).toLocaleString('fr-FR');
    const methods = (shop) => (shop && Array.isArray(shop.methods) && shop.methods.length ? shop.methods
        : shop && shop.payChoice ? ['cash', 'bank'] : [shop && shop.payment === 'bank' ? 'bank' : shop && shop.payment === 'item' ? 'item' : 'cash']);
    const initial = (shop) => methods(shop)[0];
    const valid = (shop, m) => (methods(shop).includes(m) ? m : initial(shop));
    const price = (shop, m, usd) => (m === 'pesos' ? Math.ceil(Number(usd || 0) * Number(shop.rate || 1) - 1e-9) : Number(usd || 0));
    const fmt = (shop, m, usd) => {
        const v = price(shop, m, usd);
        if (m === 'pesos') return `${nf(v)} pesos`;
        if (m === 'item') return `${nf(v)} ${esc(shop.paymentLabel || 'objet')}`;
        return `${nf(v)} $`;
    };
    const unit = (shop, m, v) => (m === 'pesos' ? `${nf(v)} pesos` : m === 'item' ? `${nf(v)} ${esc(shop.paymentLabel || '')}` : `${nf(v)} $`);
    const have = (shop, m) => {
        const w = (shop && shop.wallet) || {};
        return w[m] ?? (m === 'item' ? w.item ?? w[shop.payment] : undefined);
    };
    // Boutons de choix (ou mention « paiement uniquement »)
    const modes = (shop, current) => {
        const ms = methods(shop);
        if (ms.length > 1) {
            return `<div class="bb-modes">${ms.map((m) => `<button class="bb-mode ${current === m ? 'on' : ''}" data-method="${m}">${ICONS[m]} ${m === 'item' ? esc(shop.paymentLabel || 'Objet') : NAMES[m]}</button>`).join('')}</div>`;
        }
        const m = ms[0];
        const txt = m === 'pesos' ? 'pesos uniquement' : m === 'bank' ? 'carte bancaire' : m === 'item' ? esc(shop.paymentLabel || 'objet') : 'argent liquide';
        return `<p class="bb-note">Paiement : ${txt}</p>`;
    };
    const wallet = (shop) => methods(shop).map((m) => {
        const v = have(shop, m);
        return v === undefined ? '' : `<span><i>${ICONS[m]}</i>${unit(shop, m, v)}</span>`;
    }).join('');
    const missing = (shop, m, usd) => {
        const h = have(shop, m);
        const due = price(shop, m, usd);
        if (h === undefined || h >= due) return null;
        return m === 'pesos' ? `Il te manque ${nf(due - h)} pesos. Change de l'argent au bureau de change.` : `Il te manque ${unit(shop, m, due - h)}.`;
    };
    return { NAMES, ICONS, methods, initial, valid, price, fmt, unit, have, modes, wallet, missing };
})();
