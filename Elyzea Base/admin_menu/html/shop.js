/* =========================================================
   BOUTIQUE (ressource elyzea_shop)
   Visible avec « shop_view ». Toute modification est réservée aux FONDATEURS :
   vérifié par le serveur de l'admin menu, puis par elyzea_shop (qui revalide chaque valeur).
   Ici, les boutons de modification sont seulement masqués pour les autres grades.
   ========================================================= */
(() => {
    TABS.push({
        id: 'shop', group: 2, label: 'Boutique', ico: '🛒',
        sub: 'Produits de la boutique (VIP, Elyzea Coins, véhicules), catégories, paquets Tebex, livraisons et coins des joueurs. Modification : Fondateurs.',
        show: () => has('shop_view') && !!(D && D.shop),
    });

    const S = { sub: 'home', edit: null, cats: null, ver: 0, lookup: '', adjust: { amount: '', reason: '' }, giveKey: '', delivFilter: 'all' };
    const send = (name, data = {}) => action('shop', { name, data });
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const date = (d) => { if (!d) return '—'; const x = new Date(String(d).replace(' ', 'T') + (/[zZ+]/.test(String(d)) ? '' : 'Z')); return isNaN(x) ? String(d) : x.toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }); };
    const SUBS = [['home', '📊 Général'], ['products', '🛍️ Produits'], ['categories', '🗂️ Catégories'], ['deliveries', '📦 Livraisons'], ['players', '👤 Joueurs et coins'], ['logs', '📜 Journal']];
    const ST = { delivered: '🟢 livrée', pending: '🟡 en attente', failed: '🔴 échouée', cancelled: '⚪ annulée' };
    const RW = {
        group: { label: 'Grade (ACE group.nom)', fields: [['name', 'Nom (ex. vip_sapphire)', 'text']] },
        perk: { label: 'Avantage (HasPerk)', fields: [['name', 'Nom de l\'avantage', 'text']] },
        coins: { label: 'Elyzea Coins', fields: [['amount', 'Montant', 'number']] },
        vehicle: { label: 'Véhicule', fields: [['model', 'Modèle (nom de spawn)', 'text'], ['garage', 'Garage (facultatif)', 'text']] },
        item: { label: 'Objet', fields: [['name', 'Nom de l\'objet', 'text'], ['count', 'Quantité', 'number']] },
        money: { label: 'Argent de jeu', fields: [['account', 'Compte (bank, cash)', 'text'], ['amount', 'Montant', 'number']] },
        command: { label: 'Commande prédéfinie', fields: [['name', 'Nom (Config.Commands)', 'text']] },
    };
    const canEdit = () => !!(D && D.shop && D.shop.canEdit);
    const dis = () => (canEdit() ? '' : 'disabled');
    const ro = () => (canEdit() ? '' : '<div class="protect" style="margin-bottom:12px">🔒 <span>Lecture seule : seuls les <b>Fondateurs</b> peuvent modifier la boutique.</span></div>');
    const reRender = () => { S.ver++; render(); };

    /* ---------------- Général ---------------- */
    function viewHome(s) {
        const vis = s.products.filter((p) => p.enabled).length;
        const sale = s.products.filter((p) => p.enabled && (p.tebexPackageId || p.coinsPrice)).length;
        return `<div class="stats">
            <div class="stat"><b>${vis} / ${s.products.length}</b><span>Produits visibles</span></div>
            <div class="stat"><b>${sale}</b><span>Achetables (Tebex ou coins)</span></div>
            <div class="stat"><b>${fmt(s.stats.tebex)}</b><span>Livraisons Tebex réussies</span></div>
            <div class="stat"><b>${fmt(s.stats.coins)}</b><span>Achats en coins</span></div>
            <div class="stat"><b>${fmt(s.stats.pending)}</b><span>Livraisons en attente</span></div>
            <div class="stat"><b style="${s.stats.failed ? 'color:var(--danger)' : ''}">${fmt(s.stats.failed)}</b><span>Livraisons échouées</span></div>
            <div class="stat"><b>${s.coins.enabled ? fmt(s.coins.total) + ' ' + esc(s.coins.short) : 'désactivés'}</b><span>${esc(s.coins.label)} en circulation</span></div></div>
        <div class="section"><h2>Tebex</h2>
            <p class="hint">${s.tebex.secretSet ? '🟢 <b>sv_tebexSecret</b> est présent dans server.cfg.' : '🔴 <b>sv_tebexSecret</b> absent : les paiements Tebex ne seront pas livrés.'}
            Boutique Tebex : <b>${esc(s.tebex.storeUrl)}</b> (config.lua).</p>
            <p class="hint">Commandes à mettre dans chaque paquet Tebex :<br>
            à l'achat <code>elyzea_shop_deliver {transaction} {id} CLE</code> · à l'expiration / au retrait <code>elyzea_shop_revoke {transaction} {id} CLE</code><br>
            (CLE = clé du produit, colonne « Clé » de l'onglet Produits).</p></div>`;
    }

    /* ---------------- Produits ---------------- */
    function viewProducts(s) {
        if (S.edit) return viewEditor(s);
        const cat = (id) => (s.categories.find((c) => c.id === id) || {}).label || id;
        return `${ro()}<div class="btn-row" style="margin-bottom:12px">${canEdit() ? '<button class="btn primary" data-sa="new">➕ Nouveau produit</button>' : ''}</div>
        <table class="loot wide"><tr><th>Produit</th><th>Clé</th><th>Catégorie</th><th>Tebex</th><th>Coins</th><th>Durée</th><th>Récompenses</th><th>État</th><th></th></tr>
        ${s.products.map((p) => `<tr>
            <td><b>${esc(p.label)}</b>${p.displayPrice ? `<div class="hint" style="margin:0">${esc(p.displayPrice)}</div>` : ''}</td>
            <td><code>${esc(p.key)}</code></td><td>${esc(cat(p.category))}</td>
            <td>${p.tebexPackageId ? `#${esc(p.tebexPackageId)}` : '<span class="muted">—</span>'}</td>
            <td>${p.coinsPrice ? fmt(p.coinsPrice) : '<span class="muted">—</span>'}</td>
            <td>${p.durationDays ? `${p.durationDays} j` : 'permanent'}</td>
            <td>${(p.rewards || []).map((r) => esc(r.type)).join(', ') || '<span style="color:var(--danger)">aucune</span>'}</td>
            <td>${p.enabled ? '🟢 visible' : '⚪ masqué'}</td>
            <td><div class="btn-row"><button class="btn" data-sedit="${esc(p.key)}">${canEdit() ? '✏️ Modifier' : '👁️ Voir'}</button>
                ${canEdit() ? `<button class="btn" data-stoggle="${esc(p.key)}">${p.enabled ? 'Masquer' : 'Afficher'}</button>` : ''}</div></td></tr>`).join('')}
        </table>`;
    }

    function viewEditor(s) {
        const e = S.edit, p = e.product;
        const opt = (v, cur, l) => `<option value="${esc(v)}" ${String(v) === String(cur) ? 'selected' : ''}>${esc(l)}</option>`;
        const f = (key, label, type = 'text', help = '') => `<div><label>${esc(label)}</label><input class="input" type="${type}" data-sp="${key}" value="${esc(p[key] ?? '')}" ${dis()}>${help ? `<p class="hint" style="margin:3px 0 0">${esc(help)}</p>` : ''}</div>`;
        const rewards = (p.rewards || []).map((r, i) => `<div class="card" style="padding:10px;margin-bottom:8px">
            <div class="form-grid" style="grid-template-columns:200px repeat(2,minmax(160px,1fr)) auto;align-items:end">
                <div><label>Type</label><select class="input" data-srt="${i}" ${dis()}>${Object.entries(RW).map(([k, v]) => opt(k, r.type, v.label)).join('')}</select></div>
                ${(RW[r.type] || RW.item).fields.map(([k, l, t]) => `<div><label>${esc(l)}</label><input class="input" type="${t}" data-srf="${i}:${k}" value="${esc(r[k] ?? '')}" ${dis()}></div>`).join('')}${(RW[r.type] || RW.item).fields.length < 2 ? '<div></div>' : ''}
                ${canEdit() ? `<button class="btn" data-srdel="${i}">🗑️</button>` : ''}</div>
            ${r.type === 'command' ? `<p class="hint" style="margin:6px 0 0">Commandes disponibles : ${(s.commands || []).map(esc).join(', ') || 'aucune (à déclarer dans config.lua › Config.Commands)'}</p>` : ''}
            ${(r.type === 'money' && !(s.integrations || {}).money) ? '<p class="hint" style="margin:6px 0 0;color:var(--danger)">Livraison d\'argent désactivée (Config.Integrations.money).</p>' : ''}</div>`).join('');
        return `${ro()}<div class="section"><h2>${e.isNew ? 'Nouveau produit' : esc(p.label || e.key)}</h2>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr))">
                <div><label>Clé (utilisée dans la commande Tebex)</label><input class="input" data-skey value="${esc(e.key)}" ${e.isNew && canEdit() ? '' : 'disabled'}><p class="hint" style="margin:3px 0 0">minuscules, chiffres et _ · ne change plus après création</p></div>
                ${f('label', 'Nom affiché')}
                <div><label>Catégorie</label><select class="input" data-sp="category" ${dis()}>${s.categories.map((c) => opt(c.id, p.category, c.label)).join('')}</select></div>
                ${f('image', 'Image', 'text', 'assets/products/nom.webp (dans elyzea_shop/html) ou https://…')}
                ${f('displayPrice', 'Prix affiché (texte, ex. 9,99 €)', 'text', 'Vide : « Prix affiché sur Tebex ». Le prix payé est toujours celui de Tebex.')}
                ${f('tebexPackageId', 'ID du paquet Tebex', 'number', 'Vide : non vendu en argent réel')}
                ${f('coinsPrice', `Prix en ${s.coins.label}`, 'number', 'Vide : non achetable en coins')}
                ${f('durationDays', 'Durée (jours)', 'number', 'Vide : permanent (grades / avantages)')}
                ${f('sort', 'Ordre d\'affichage', 'number')}</div>
            <div style="margin-top:10px"><label>Description</label><textarea class="input" rows="3" data-sp="description" ${dis()}>${esc(p.description || '')}</textarea></div>
            <div style="margin-top:10px"><label>Avantages affichés (un par ligne)</label><textarea class="input" rows="4" data-sperks ${dis()}>${esc((p.perks || []).join('\n'))}</textarea></div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-top:12px">
                <div class="tile toggle-tile ${p.enabled !== false ? 'on' : ''}" ${canEdit() ? 'data-sena' : ''}><div><strong>Visible dans la boutique</strong><span>Masqué : invisible en jeu, mais les achats Tebex déjà payés restent livrés.</span></div><div class="switch"></div></div></div></div>
        <div class="section"><h2>Ce que le produit donne en jeu</h2>${rewards || '<p class="hint" style="color:var(--danger)">Aucune récompense : ajoutez-en au moins une.</p>'}
            ${canEdit() ? '<button class="btn" data-sradd>➕ Ajouter une récompense</button>' : ''}
            <p class="hint">Les livraisons déjà commencées gardent les récompenses du moment de l'achat.</p></div>
        <div class="btn-row">${canEdit() ? '<button class="btn primary" data-sa="save">💾 Enregistrer</button>' : ''}<button class="btn" data-sa="cancel">← Retour à la liste</button>
            ${canEdit() && !e.isNew && e.fromConfig ? '<button class="btn" data-sa="reset">↺ Valeurs de config.lua</button>' : ''}
            ${canEdit() && !e.isNew ? '<button class="btn danger" data-sa="delete">🗑️ Supprimer</button>' : ''}</div>`;
    }

    /* ---------------- Catégories ---------------- */
    function viewCategories(s) {
        const list = S.cats || (S.cats = clone(s.categories));
        const icons = { crown: '♛ Couronne', coin: '◎ Pièce', car: '🚘 Voiture', star: '★ Étoile', gift: '🎁 Cadeau' };
        return `${ro()}<table class="loot wide"><tr><th>Identifiant</th><th>Nom</th><th>Icône</th><th>Description</th><th>Visible</th><th></th></tr>
            ${list.map((c, i) => `<tr><td><input class="input" data-sc="${i}:id" value="${esc(c.id)}" ${dis()}></td><td><input class="input" data-sc="${i}:label" value="${esc(c.label)}" ${dis()}></td>
                <td><select class="input" data-sc="${i}:icon" ${dis()}>${Object.entries(icons).map(([k, l]) => `<option value="${k}" ${c.icon === k ? 'selected' : ''}>${l}</option>`).join('')}</select></td>
                <td><input class="input" data-sc="${i}:description" value="${esc(c.description || '')}" ${dis()}></td>
                <td><input type="checkbox" data-scen="${i}" ${c.enabled !== false ? 'checked' : ''} ${dis()}></td>
                <td>${canEdit() ? `<div class="btn-row"><button class="btn" data-scmv="${i}:-1">↑</button><button class="btn" data-scmv="${i}:1">↓</button><button class="btn" data-scdel="${i}">🗑️</button></div>` : ''}</td></tr>`).join('')}</table>
            ${canEdit() ? `<div class="btn-row" style="margin-top:12px"><button class="btn" data-sa="cat_add">➕ Catégorie</button><button class="btn primary" data-sa="cat_save">💾 Enregistrer les catégories</button><button class="btn" data-sa="cat_reset">Annuler les changements</button></div>` : ''}
            <p class="hint">Une catégorie qui contient encore des produits ne peut pas être supprimée (déplacez d'abord les produits).</p>`;
    }

    /* ---------------- Livraisons ---------------- */
    function viewDeliveries(s) {
        const list = s.deliveries.filter((d) => S.delivFilter === 'all' || d.status === S.delivFilter);
        return `${ro()}<div class="btn-row" style="margin-bottom:12px">${['all', 'failed', 'pending', 'delivered', 'cancelled'].map((k) => `<button class="btn ${S.delivFilter === k ? 'primary' : ''}" data-sdf="${k}">${k === 'all' ? 'Toutes' : ST[k]}</button>`).join('')}</div>
        <table class="loot wide"><tr><th>#</th><th>Date</th><th>Produit</th><th>Joueur</th><th>Origine</th><th>Transaction</th><th>État</th><th></th></tr>
        ${list.map((d) => `<tr><td>${d.id}</td><td>${date(d.created_at)}</td><td>${d.action === 'revoke' ? '↩️ retrait · ' : ''}${esc(d.label)}</td><td><code>fivem:${esc(d.account)}</code></td>
            <td>${esc(d.source)}</td><td><code>${esc(d.transaction_id)}</code></td>
            <td>${ST[d.status] || esc(d.status)}${d.last_error ? `<div class="hint" style="margin:0">${esc(d.last_error)}</div>` : ''}</td>
            <td>${canEdit() && d.status !== 'delivered' && d.status !== 'cancelled' ? `<div class="btn-row"><button class="btn" data-sretry="${d.id}">Relancer</button><button class="btn" data-scancel="${d.id}">Annuler</button></div>` : ''}</td></tr>`).join('') || '<tr><td colspan="8" class="muted">Aucune livraison.</td></tr>'}</table>`;
    }

    /* ---------------- Joueurs et coins ---------------- */
    function viewPlayers(s) {
        const L = s.lookup;
        return `${ro()}<div class="section"><h2>Rechercher un joueur</h2>
            <div class="btn-row"><input class="input" style="max-width:320px" placeholder="ID serveur (connecté) ou fivem:XXXX" data-slook value="${esc(S.lookup)}">
            <button class="btn primary" data-sa="lookup">🔎 Afficher</button></div></div>
        ${L ? `<div class="section"><h2>Compte fivem:${esc(L.account)}</h2>
            <div class="stats"><div class="stat"><b>${fmt(L.coins)} ${esc(s.coins.short)}</b><span>Solde</span></div>
                <div class="stat"><b>${(L.vip || []).map((v) => esc(v.name)).join(', ') || '—'}</b><span>Grades / avantages actifs</span></div></div>
            ${canEdit() ? `<div class="form-grid" style="grid-template-columns:160px 1fr auto;align-items:end;max-width:760px;margin-top:10px">
                <div><label>Coins (+ / −)</label><input class="input" type="number" data-sadj="amount" value="${esc(S.adjust.amount)}"></div>
                <div><label>Raison</label><input class="input" data-sadj="reason" value="${esc(S.adjust.reason)}" maxlength="48"></div>
                <button class="btn primary" data-sa="coins">Appliquer</button></div>
            <div class="form-grid" style="grid-template-columns:1fr auto;align-items:end;max-width:760px;margin-top:10px">
                <div><label>Donner un produit (geste commercial, journalisé)</label><select class="input" data-sgive><option value="">— produit —</option>${s.products.map((p) => `<option value="${esc(p.key)}" ${S.giveKey === p.key ? 'selected' : ''}>${esc(p.label)}</option>`).join('')}</select></div>
                <button class="btn" data-sa="give">🎁 Donner</button></div>` : ''}
            <h3 class="sub-h">Mouvements de coins</h3><table class="loot wide"><tr><th>Date</th><th>Mouvement</th><th>Solde après</th><th>Raison</th></tr>
                ${(L.coinHistory || []).map((m) => `<tr><td>${date(m.created_at)}</td><td>${m.delta > 0 ? '+' : ''}${fmt(m.delta)}</td><td>${fmt(m.balance_after)}</td><td>${esc(m.reason)}</td></tr>`).join('') || '<tr><td colspan="4" class="muted">Aucun.</td></tr>'}</table>
            <h3 class="sub-h">Livraisons</h3><table class="loot wide"><tr><th>#</th><th>Date</th><th>Produit</th><th>Origine</th><th>État</th></tr>
                ${(L.deliveries || []).map((d) => `<tr><td>${d.id}</td><td>${date(d.created_at)}</td><td>${d.action === 'revoke' ? '↩️ ' : ''}${esc((s.products.find((p) => p.key === d.product_key) || {}).label || d.product_key)}</td><td>${esc(d.source)}</td><td>${ST[d.status] || esc(d.status)}</td></tr>`).join('') || '<tr><td colspan="5" class="muted">Aucune.</td></tr>'}</table></div>` : ''}`;
    }

    function viewLogs(s) {
        return `<table class="loot wide"><tr><th>Date</th><th>Niveau</th><th>Action</th><th>Joueur</th><th>Référence</th><th>Détails</th></tr>
            ${s.logs.map((l) => `<tr><td>${date(l.created_at)}</td><td>${l.level === 'error' ? '🔴' : l.level === 'warn' ? '🟡' : '🔵'} ${esc(l.level)}</td><td>${esc(l.action)}</td><td>${l.account ? `<code>${esc(l.account)}</code>` : ''}</td><td><code>${esc(l.ref || '')}</code></td><td>${esc(l.details || '')}</td></tr>`).join('') || '<tr><td colspan="6" class="muted">Rien à signaler.</td></tr>'}</table>
            <p class="hint">Erreurs, avertissements et actions des Fondateurs. Journal complet : table elyzea_shop_logs.</p>`;
    }

    VIEWS.shop = () => {
        const s = D.shop;
        if (!s.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(s.resource || 'elyzea_shop')}</b> ne répond pas${s.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        const nav = `<div class="btn-row" style="margin-bottom:14px">${SUBS.map(([k, l]) => `<button class="btn ${S.sub === k ? 'primary' : ''}" data-ssub="${k}">${l}</button>`).join('')}</div>`;
        const v = { products: viewProducts, categories: viewCategories, deliveries: viewDeliveries, players: viewPlayers, logs: viewLogs }[S.sub] || viewHome;
        return nav + v(s);
    };
    // Pendant une modification (fiche produit, catégories), l'actualisation automatique ne reconstruit pas le formulaire
    // (onglet Joueurs : seulement pendant la saisie dans un champ ; la fiche reçue est dans la signature pour s'afficher quand même)
    const typing = () => { const a = document.activeElement; return !!(a && a.matches && a.matches('#content input, #content select, #content textarea')); };
    STABLE_VIEWS.shop = () => {
        if (!D || !D.shop) return null;
        if (S.edit || (S.sub === 'categories' && S.cats)) return `${S.sub}|${S.ver}|${S.edit ? S.edit.key : ''}|${canEdit()}`;
        if (S.sub === 'players' && typing()) return `${S.sub}|${S.ver}|${canEdit()}|${JSON.stringify(D.shop.lookup || null)}`;
        return null;
    };

    /* ---------------- événements ---------------- */
    const on = () => isOpen && tab === 'shop' && D && D.shop && D.shop.available;
    function openEditor(key) {
        const p = D.shop.products.find((x) => x.key === key);
        if (!p) return;
        const { key: k, fromConfig, ...rest } = clone(p);
        S.edit = { key: k, isNew: false, fromConfig, product: rest };
    }
    function productPayload() {
        const p = clone(S.edit.product);
        ['tebexPackageId', 'coinsPrice', 'durationDays', 'sort'].forEach((k) => { p[k] = p[k] === '' || p[k] === undefined || p[k] === null ? null : Number(p[k]); });
        (p.rewards || []).forEach((r) => { ['amount', 'count'].forEach((k) => { if (r[k] !== undefined && r[k] !== '') r[k] = Number(r[k]); }); });
        return { key: S.edit.key, isNew: S.edit.isNew, product: p };
    }

    document.addEventListener('click', (ev) => {
        if (!on()) return;
        const t = ev.target.closest('button, .tile, [data-sena]');
        if (!t) return;
        const s = D.shop;
        if (t.dataset.ssub) { S.sub = t.dataset.ssub; S.edit = null; S.cats = null; return reRender(); }
        if (t.dataset.sedit) { openEditor(t.dataset.sedit); return reRender(); }
        if (t.dataset.stoggle) return send('product_toggle', { key: t.dataset.stoggle });
        if (t.dataset.sdf) { S.delivFilter = t.dataset.sdf; return reRender(); }
        if (t.dataset.sretry) return send('delivery_retry', { id: Number(t.dataset.sretry) });
        if (t.dataset.scancel) { if (window.confirm('Annuler cette livraison ? Le joueur ne la recevra pas.')) send('delivery_cancel', { id: Number(t.dataset.scancel) }); return; }
        if (t.hasAttribute && t.hasAttribute('data-sena') && S.edit) { S.edit.product.enabled = S.edit.product.enabled === false; return reRender(); }
        if (t.hasAttribute('data-sradd') && S.edit) { (S.edit.product.rewards = S.edit.product.rewards || []).push({ type: 'item', name: '', count: 1 }); return reRender(); }
        if (t.dataset.srdel !== undefined && S.edit) { S.edit.product.rewards.splice(Number(t.dataset.srdel), 1); return reRender(); }
        if (t.dataset.scmv) { const [i, dir] = t.dataset.scmv.split(':').map(Number); const j = i + dir; if (j >= 0 && j < S.cats.length) [S.cats[i], S.cats[j]] = [S.cats[j], S.cats[i]]; return reRender(); }
        if (t.dataset.scdel !== undefined && t.dataset.scdel !== '') { S.cats.splice(Number(t.dataset.scdel), 1); return reRender(); }
        const a = t.dataset.sa;
        if (!a) return;
        if (a === 'new') { S.edit = { key: '', isNew: true, product: { label: '', category: (s.categories[0] || {}).id, description: '', perks: [], enabled: false, rewards: [], sort: 0 } }; return reRender(); }
        if (a === 'cancel') { S.edit = null; return reRender(); }
        if (a === 'save') { const payload = productPayload(); S.edit = null; reRender(); return send('product_save', payload); }
        if (a === 'reset') { if (!window.confirm('Remettre ce produit aux valeurs de config.lua ?')) return; const key = S.edit.key; S.edit = null; reRender(); return send('product_reset', { key }); }
        if (a === 'delete') { if (!window.confirm('Supprimer définitivement ce produit ?')) return; const key = S.edit.key; S.edit = null; reRender(); return send('product_delete', { key }); }
        if (a === 'cat_add') { S.cats.push({ id: `categorie_${S.cats.length + 1}`, label: 'Nouvelle catégorie', icon: 'star', description: '', enabled: true }); return reRender(); }
        if (a === 'cat_reset') { S.cats = null; return reRender(); }
        if (a === 'cat_save') { const list = clone(S.cats); S.cats = null; reRender(); return send('categories_save', { categories: list }); }
        if (a === 'lookup') return send('account_lookup', { account: S.lookup.trim() });
        if (a === 'coins') { const acc = (s.lookup || {}).account; if (!acc) return; const d = { account: `fivem:${acc}`, amount: Number(S.adjust.amount), reason: S.adjust.reason }; S.adjust = { amount: '', reason: '' }; send('coins_adjust', d); return setTimeout(() => send('account_lookup', { account: `fivem:${acc}` }), 400); }
        if (a === 'give') { const acc = (s.lookup || {}).account; if (!acc || !S.giveKey) return; if (!window.confirm('Donner ce produit à ce joueur ?')) return; send('give', { account: `fivem:${acc}`, key: S.giveKey }); return setTimeout(() => send('account_lookup', { account: `fivem:${acc}` }), 400); }
    });

    document.addEventListener('input', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.sp !== undefined && S.edit) S.edit.product[t.dataset.sp] = t.value;
        else if (t.hasAttribute('data-skey') && S.edit) S.edit.key = t.value.toLowerCase();
        else if (t.hasAttribute('data-sperks') && S.edit) S.edit.product.perks = t.value.split('\n').map((x) => x.trim()).filter(Boolean);
        else if (t.dataset.srf && S.edit) { const [i, k] = t.dataset.srf.split(':'); S.edit.product.rewards[Number(i)][k] = t.value; }
        else if (t.dataset.sc && S.cats) { const [i, k] = t.dataset.sc.split(':'); S.cats[Number(i)][k] = t.value; }
        else if (t.hasAttribute('data-slook')) S.lookup = t.value;
        else if (t.dataset.sadj) S.adjust[t.dataset.sadj] = t.value;
    });
    document.addEventListener('change', (ev) => {
        if (!on()) return;
        const t = ev.target;
        if (t.dataset.sp === 'category' && S.edit) S.edit.product.category = t.value;
        else if (t.dataset.srt !== undefined && S.edit) { S.edit.product.rewards[Number(t.dataset.srt)] = { type: t.value }; reRender(); }
        else if (t.dataset.sc && S.cats) { const [i, k] = t.dataset.sc.split(':'); S.cats[Number(i)][k] = t.value; }
        else if (t.dataset.scen !== undefined && S.cats) S.cats[Number(t.dataset.scen)].enabled = t.checked;
        else if (t.hasAttribute('data-sgive')) S.giveKey = t.value;
    });
})();
