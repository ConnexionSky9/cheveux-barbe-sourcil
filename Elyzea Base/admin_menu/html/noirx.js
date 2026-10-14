/* =========================================================
   NOIR X (ressource noirx, permission « noirx_staff »)
   A. Informateurs · B. Informations · C. Blanchiments en cours · D. Réglages et applications
   E. Paiements bloqués · F. Identités · G. Journal
   Chaque action part tout de suite ; noirx revalide tout côté serveur.
   ========================================================= */
(() => {
    TABS.push({
        id: 'noirx', group: 6, label: 'NOIR X', ico: '📱',
        sub: 'Téléphone clandestin : informateurs, informations, blanchiments, réglages.',
        show: () => has('noirx_staff') && !!(D && D.noirx),
    });

    const G = { sub: 'informants', inf: 0 };
    const send = (name, data = {}) => action('noirx', { name, data });
    const SUBS = [['informants', 'A. Informateurs'], ['intel', 'B. Informations'], ['launders', 'C. Blanchiments'], ['mercs', 'Mercenaires'], ['market', 'Dark Market'], ['settings', 'D. Réglages'],
        ['payouts', 'E. Paiements bloqués'], ['identity', 'F. Identités'], ['audit', 'G. Journal']];
    const CUR = { dirty: 'Argent sale', clean: 'Argent propre' };
    const arr = (v) => (Array.isArray(v) ? v : []);
    const sec = (title, inner, hint) => `<div class="section"><h2>${title}</h2>${hint ? `<p class="hint">${hint}</p>` : ''}${inner}</div>`;
    const N = () => D.noirx;
    const money = (n) => `${Math.round(Number(n) || 0).toLocaleString('fr-FR')} ${N().symbol || '$'}`;
    const date = (t) => {
        if (!t) return '—';
        const d = typeof t === 'number' ? new Date(t * 1000) : new Date(t);
        return isNaN(d) ? esc(String(t)) : d.toLocaleString('fr-FR');
    };
    const dur = (s) => { s = Math.max(0, Math.round(Number(s) || 0)); return `${Math.floor(s / 60)} min ${String(s % 60).padStart(2, '0')} s`; };
    const xyz = (c) => (c ? `${Number(c.x).toFixed(1)}, ${Number(c.y).toFixed(1)}, ${Number(c.z).toFixed(1)}` : '—');

    function vInformants() {
        const rows = arr(N().informants).map((i) => `<tr><td>#${i.id}</td><td><strong>${esc(i.name)}</strong><div class="muted">${esc(i.tagline || '')}</div></td>
            <td class="muted">${esc(i.greeting || '')}</td><td>${i.enabled ? '🟢 Actif' : '⏸ Désactivé'}</td>
            <td>${arr(N().intel).filter((x) => x.informant_id === i.id).length}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="editInf" data-id="${i.id}">Modifier</button>
            <button class="btn" data-nx="toggleInf" data-id="${i.id}">${i.enabled ? 'Désactiver' : 'Activer'}</button>
            <button class="btn danger" data-nx="delInf" data-id="${i.id}">✕</button></td></tr>`).join('');
        return sec('A. Informateurs', `<div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-nx="newInf">+ Nouvel informateur</button></div>
            <table class="loot wide"><tr><th>N°</th><th>Nom</th><th>Message d'accueil</th><th>État</th><th>Infos</th><th></th></tr>${rows || '<tr><td colspan="6" class="muted">Aucun informateur.</td></tr>'}</table>`,
        'Les informateurs apparaissent dans l\'application Ratline. Supprimer un informateur supprime aussi ses informations.');
    }

    function vIntel() {
        const infs = arr(N().informants);
        const name = (id) => (infs.find((i) => i.id === id) || {}).name || `#${id}`;
        const rows = arr(N().intel).map((x) => `<tr><td>#${x.id}</td><td>${esc(name(x.informant_id))}</td><td>${esc(x.categoryLabel || x.category)}</td>
            <td><strong>${esc(x.title)}</strong><div class="muted">${esc(x.answer)}</div>${x.keywords ? `<div class="muted">🔑 ${esc(x.keywords)}</div>` : ''}</td>
            <td>${money(x.price)}<div class="muted">${CUR[x.currency] || esc(x.currency)}</div></td><td>${x.reliability} %</td>
            <td class="mono">${xyz(x.coords)}</td><td>${x.expires_at ? date(x.expires_at) : 'Jamais'}</td><td>${x.enabled ? '🟢' : '⏸'}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="editIntel" data-id="${x.id}">Modifier</button>
            <button class="btn" data-nx="toggleIntel" data-id="${x.id}">${x.enabled ? 'Désactiver' : 'Activer'}</button>
            <button class="btn danger" data-nx="delIntel" data-id="${x.id}">✕</button></td></tr>`).join('');
        return sec('B. Informations vendues', `<div class="btn-row" style="margin-bottom:10px"><button class="btn primary" data-nx="newIntel" ${infs.length ? '' : 'disabled'}>+ Nouvelle information</button>
            ${infs.length ? '' : '<span class="muted" style="align-self:center">Crée d\'abord un informateur.</span>'}</div>
            <table class="loot wide"><tr><th>N°</th><th>Informateur</th><th>Catégorie</th><th>Question / réponse</th><th>Prix</th><th>Fiabilité</th><th>Position</th><th>Expire</th><th></th><th></th></tr>
            ${rows || '<tr><td colspan="10" class="muted">Aucune information.</td></tr>'}</table>`,
        'Position : « ici » prend ta position actuelle (le GPS du joueur y mène après l\'achat). Fiabilité &lt; 100 % : l\'information peut être fausse.');
    }

    function vLaunders() {
        const rows = arr(N().launders).map((j) => `<tr><td>#${esc(j.id)}</td><td class="mono">${esc(j.owner || '')}</td><td>${money(j.amount)}</td><td>${money(j.fee)}</td>
            <td>${money(j.payout)}${j.stolen ? `<div class="muted">volé : ${money(j.stolen)}</div>` : ''}</td><td>${dur(j.remaining)}</td><td>${j.underAttack ? '⚠️ Piratage en cours' : '—'}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="cancelLaunder" data-id="${esc(j.id)}" data-refund="1">Annuler + rembourser</button>
            <button class="btn danger" data-nx="cancelLaunder" data-id="${esc(j.id)}" data-refund="0">Annuler sans rembourser</button></td></tr>`).join('');
        return sec('C. Blanchiments en cours', `<table class="loot wide"><tr><th>N°</th><th>Personnage</th><th>Montant</th><th>Commission</th><th>À verser</th><th>Reste</th><th>État</th><th></th></tr>
            ${rows || '<tr><td colspan="8" class="muted">Aucun blanchiment en cours.</td></tr>'}</table>`);
    }

    const MSTATUS = { pending: '⏳ En préparation', deploying: '🚙 En route', engaged: '🔴 Au contact', success: '✅ Rempli', failed: '💀 Équipe éliminée',
        expired: '⌛ Expiré', timeout: '⌛ Abandonné', target_left: '🚪 Cible déconnectée', cancelled: '✖ Annulé (staff)' };
    function vMercs() {
        const m = N().mercs || {};
        const act = arr(m.active).map((c) => `<tr><td>#${c.id}</td><td>${esc(c.buyerName || '')}<div class="muted mono">${esc(c.buyer || '')}</div></td>
            <td><strong>${esc(c.targetName)}</strong><div class="muted mono">${esc(c.target || '')}</div></td><td>${esc(c.label)} · ${c.size}${c.alive != null ? ` (${c.alive} debout)` : ''}</td>
            <td>${money(c.price)}<div class="muted">${CUR[c.currency] || esc(c.currency)}</div></td><td>${MSTATUS[c.status] || esc(c.status)}${c.waiting ? '<div class="muted">cible injoignable</div>' : ''}</td>
            <td>${dur(c.status === 'pending' && c.deployIn > 0 ? c.deployIn : c.expiresIn)}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="cancelMerc" data-id="${c.id}" data-refund="1">Annuler + rembourser</button>
            <button class="btn danger" data-nx="cancelMerc" data-id="${c.id}" data-refund="0">Annuler sans rembourser</button></td></tr>`).join('');
        const rec = arr(m.recent).map((c) => `<tr><td>#${c.id}</td><td>${esc(c.buyer_name || c.buyer)}</td><td>${esc(c.target_name)}</td><td>${c.size}</td>
            <td>${money(c.price)}</td><td>${MSTATUS[c.status] || esc(c.status)}</td><td>${Number(c.refund) > 0 ? money(c.refund) : '—'}</td><td>${date(Number(c.finished_at) || Number(c.created_at))}</td>
            <td class="muted">${esc(c.note || '')}</td></tr>`).join('');
        return sec('Contrats de mercenaires en cours', `<table class="loot wide"><tr><th>N°</th><th>Commanditaire</th><th>Cible</th><th>Équipe</th><th>Prix</th><th>État</th><th>Reste</th><th></th></tr>
                ${act || '<tr><td colspan="8" class="muted">Aucun contrat en cours.</td></tr>'}</table>`,
            'Annuler supprime l\'équipe (elle se retire puis disparaît). Prix, délais et limites : onglet D. Réglages, catégorie Mercenaires.')
            + sec('Derniers contrats terminés', `<table class="loot wide"><tr><th>N°</th><th>Commanditaire</th><th>Cible</th><th>Taille</th><th>Prix</th><th>Fin</th><th>Remboursé</th><th>Date</th><th>Note</th></tr>
                ${rec || '<tr><td colspan="9" class="muted">Aucun.</td></tr>'}</table>`);
    }

    function vMarket() {
        const m = N().market || {};
        const rows = arr(m.listings).map((l) => `<tr><td>#${l.id}</td><td><strong>${esc(l.label)}</strong><div class="muted">${esc(l.categoryLabel)}</div>${l.note ? `<div class="muted">« ${esc(l.note)} »</div>` : ''}</td>
            <td>${esc(l.seller)}<div class="muted mono">${esc(l.sellerId || '')}</div></td><td>${l.quantity} / ${l.initial}</td><td>${money(l.price)}<div class="muted">${CUR[l.currency] || esc(l.currency)}</div></td>
            <td>${dur(l.expiresIn)}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="mkRemove" data-id="${l.id}" data-ret="1">Retirer (rendre)</button>
            <button class="btn danger" data-nx="mkRemove" data-id="${l.id}" data-ret="0">Retirer + confisquer</button>
            <button class="btn danger" data-nx="mkBan" data-owner="${esc(l.sellerId || '')}" data-alias="${esc(l.seller)}">Exclure</button></td></tr>`).join('');
        const tx = arr(m.tx).map((t) => `<tr><td>#${t.id}</td><td>${date(Number(t.created_at))}</td><td>${esc(t.seller_alias)}</td><td>${esc(t.buyer_alias)}</td><td>${Number(t.quantity)} × ${esc(t.label)}</td>
            <td>${money(t.total)}<div class="muted">${CUR[t.currency] || esc(t.currency)}</div></td><td>${money(t.fee)}</td></tr>`).join('');
        const bans = arr(m.bans).map((b) => `<tr><td>${esc(b.alias || '—')}</td><td class="mono">${esc(b.owner)}</td><td class="muted">${esc(b.ban_reason || '')}</td>
            <td style="text-align:right"><button class="btn" data-nx="mkUnban" data-owner="${esc(b.owner)}">Réintégrer</button></td></tr>`).join('');
        return sec('Annonces actives', `<table class="loot wide"><tr><th>N°</th><th>Objet</th><th>Vendeur</th><th>Stock</th><th>Prix unitaire</th><th>Expire</th><th></th></tr>
                ${rows || '<tr><td colspan="7" class="muted">Aucune annonce.</td></tr>'}</table>`,
            'Retirer (rendre) : les objets restants reviennent au vendeur en colis. Confisquer : ils sont supprimés. Les offres en attente sont remboursées dans les deux cas.')
            + sec('Dernières ventes', `<table class="loot wide"><tr><th>N°</th><th>Date</th><th>Vendeur</th><th>Acheteur</th><th>Objet</th><th>Total</th><th>Commission</th></tr>${tx || '<tr><td colspan="7" class="muted">Aucune.</td></tr>'}</table>`)
            + sec('Vendeurs exclus', `<table class="loot wide"><tr><th>Pseudo</th><th>Personnage</th><th>Raison</th><th></th></tr>${bans || '<tr><td colspan="4" class="muted">Aucun.</td></tr>'}</table>`,
                'Objets autorisés et catégories : noirx/config.lua › Config.Market.items. Commission, frais et limites : onglet D. Réglages, catégorie Dark Market.');
    }

    function vSettings() {
        const cats = {};
        arr(N().settings).forEach((s) => { (cats[s.category] = cats[s.category] || []).push(s); });
        const blocks = Object.entries(cats).map(([c, list]) => sec(esc(c), `<table class="loot wide"><tr><th>Réglage</th><th style="width:200px">Valeur</th><th style="width:260px"></th></tr>
            ${list.map((s) => `<tr><td><strong>${esc(s.label)}</strong><div class="muted mono">${esc(s.path)}</div></td>
                <td><input class="input" type="number" step="any" data-nxs="${esc(s.path)}" value="${esc(s.value ?? '')}"></td>
                <td style="text-align:right"><button class="btn primary" data-nx="setSetting" data-path="${esc(s.path)}">Enregistrer</button>
                <button class="btn" data-nx="resetSetting" data-path="${esc(s.path)}">Par défaut</button></td></tr>`).join('')}</table>`)).join('');
        const apps = arr(N().apps).map((a) => `<div class="tile toggle-tile ${a.enabled ? 'on' : ''}" data-nx="app" data-path="${esc(a.path)}" data-on="${a.enabled ? 1 : 0}">
            <div><strong>${esc(a.label || a.id)}</strong><span>${a.enabled ? 'Visible sur le téléphone' : 'Masquée'}</span></div><div class="switch"></div></div>`).join('');
        return sec('Applications du téléphone', `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(240px,1fr))">${apps || '<p class="muted">Aucune.</p>'}</div>`)
            + blocks + '<p class="hint">« Enregistrer » s\'applique tout de suite. « Par défaut » supprime la surcharge : la valeur de config.lua revient au prochain redémarrage de noirx.</p>';
    }

    function vPayouts() {
        const rows = arr(N().stuckPayouts).map((p) => `<tr><td>#${p.id}</td><td class="mono">${esc(p.owner)}</td><td>${money(p.amount)}</td><td>${CUR[p.currency] || esc(p.currency)}</td>
            <td>${esc(p.reason || '')}</td><td>${date(p.created_at)}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-nx="payout" data-id="${p.id}" data-status="pending">Relancer le versement</button>
            <button class="btn danger" data-nx="payout" data-id="${p.id}" data-status="paid">Marquer comme payé</button></td></tr>`).join('');
        return sec('E. Paiements bloqués', `<table class="loot wide"><tr><th>N°</th><th>Personnage</th><th>Montant</th><th>Devise</th><th>Raison</th><th>Créé</th><th></th></tr>
            ${rows || '<tr><td colspan="7" class="muted">Aucun paiement bloqué.</td></tr>'}</table>`,
        'Un paiement reste « en traitement » si le serveur s\'est arrêté pendant le versement. Vérifie l\'inventaire / le compte du joueur avant de choisir.');
    }

    function vIdentity() {
        return sec('F. Identités (pseudos Ghostline)', `<div class="btn-row"><input class="input" id="nx-handle" placeholder="Pseudo à révoquer" style="max-width:260px">
            <button class="btn danger" data-nx="revoke">Révoquer l'identité</button></div>`, 'Le joueur devra recréer un pseudo au prochain usage du téléphone.');
    }

    function vAudit() {
        const rows = arr(N().audit).map((a) => `<tr><td>${date(a.created_at)}</td><td class="mono">${esc(a.actor)}</td><td>${esc(a.action)}</td>
            <td class="mono muted" style="max-width:520px;overflow:hidden;text-overflow:ellipsis">${esc(typeof a.details === 'string' ? a.details : JSON.stringify(a.details || ''))}</td></tr>`).join('');
        return sec('G. Journal (40 dernières entrées)', `<table class="loot wide"><tr><th>Date</th><th>Auteur</th><th>Action</th><th>Détail</th></tr>${rows || '<tr><td colspan="4" class="muted">Vide.</td></tr>'}</table>`);
    }

    VIEWS.noirx = () => {
        const n = N();
        if (!n.available) return `<div class="protect">⚠️ <span>${n.reason ? esc(n.reason) : `La ressource <b>${esc(n.resource || 'noirx')}</b> ne répond pas${n.error ? ' (redémarre-la puis rouvre le menu)' : ''}.`}</span></div>`;
        if (n.loading) return '<div class="section"><p class="muted">Chargement des données NOIR X…</p></div>';
        if (n.noDatabase) return '<div class="protect">⚠️ <span>NOIR X n\'a pas accès à la base de données (voir la console serveur).</span></div>';
        const s = n.stats || {};
        const body = { informants: vInformants, intel: vIntel, launders: vLaunders, mercs: vMercs, market: vMarket, settings: vSettings, payouts: vPayouts, identity: vIdentity, audit: vAudit }[G.sub]();
        return `<div class="stats"><div class="stat"><b>${s.informants || 0}</b><span>Informateur(s)</span></div><div class="stat"><b>${s.intel || 0}</b><span>Information(s)</span></div>
                <div class="stat"><b>${s.launders || 0}</b><span>Blanchiment(s) en cours</span></div><div class="stat"><b>${money(s.launderedTotal)}</b><span>Blanchi au total (${s.launderedCount || 0})</span></div>
                <div class="stat"><b>${money(s.stolenTotal)}</b><span>Volé par piratage</span></div><div class="stat"><b>${s.stuckPayouts || 0}</b><span>Paiement(s) bloqué(s)</span></div></div>
            <div class="btn-row" style="flex-wrap:wrap;margin-bottom:12px">${SUBS.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-nxsub="${k}">${l}</button>`).join('')}</div>${body}`;
    };

    async function informantForm(cur) {
        return formModal(cur ? `Modifier « ${cur.name} »` : 'Nouvel informateur', [
            { name: 'name', label: 'Nom (40 caractères max.)', value: cur ? cur.name : '' },
            { name: 'tagline', label: 'Sous-titre', value: cur ? cur.tagline : '' },
            { name: 'greeting', label: 'Message d\'accueil', value: cur ? cur.greeting : '' },
        ], cur ? 'Enregistrer' : 'Créer');
    }

    async function intelForm(cur) {
        const infs = arr(N().informants);
        const v = await formModal(cur ? `Modifier l'information #${cur.id}` : 'Nouvelle information', [
            { name: 'informant_id', label: 'Informateur', type: 'select', value: cur ? cur.informant_id : (infs[0] || {}).id, options: infs.map((i) => ({ value: i.id, label: i.name })) },
            { name: 'category', label: 'Catégorie', type: 'select', value: cur ? cur.category : 'other', options: arr(N().categories).map((c) => ({ value: c.id, label: c.label })) },
            { name: 'title', label: 'Question affichée (80 caractères max.)', value: cur ? cur.title : '' },
            { name: 'answer', label: 'Réponse donnée après achat', value: cur ? cur.answer : '' },
            { name: 'keywords', label: 'Mots-clés (séparés par des virgules)', value: cur ? cur.keywords : '' },
            { name: 'price', label: 'Prix', type: 'number', value: cur ? cur.price : 500 },
            { name: 'currency', label: 'Devise', type: 'select', value: cur ? cur.currency : 'dirty', options: [{ value: 'dirty', label: 'Argent sale' }, { value: 'clean', label: 'Argent propre' }] },
            { name: 'reliability', label: 'Fiabilité (0 à 100 %)', type: 'number', value: cur ? cur.reliability : 100 },
            { name: 'pos', label: 'Position GPS', type: 'select', value: 'keep', options: (cur ? [{ value: 'keep', label: cur.coords ? `Garder (${xyz(cur.coords)})` : 'Garder (aucune)' }] : [{ value: 'keep', label: 'Aucune' }])
                .concat([{ value: 'here', label: 'Ma position actuelle' }], cur && cur.coords ? [{ value: 'none', label: 'Retirer la position' }] : []) },
            { name: 'expires_in', label: 'Expire dans (minutes, 0 = jamais)', type: 'number', value: 0 },
        ], cur ? 'Enregistrer' : 'Créer');
        if (!v) return null;
        const d = { informant_id: Number(v.informant_id), category: v.category, title: v.title, answer: v.answer, keywords: v.keywords,
            price: Number(v.price) || 0, currency: v.currency, reliability: Number(v.reliability) };
        if (v.pos === 'here') d.here = true;
        else if (v.pos === 'none' || (!cur && v.pos === 'keep')) d.coords = false;
        const mins = Number(v.expires_in) || 0;
        if (mins > 0) d.expires_in = Math.round(mins * 60); else if (!cur) d.expires_in = 0;
        return d;
    }

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'noirx' || !D.noirx) return;
        let n;
        if ((n = ev.target.closest('[data-nxsub]'))) { G.sub = n.dataset.nxsub; return render(); }
        if (!(n = ev.target.closest('[data-nx]')) || n.disabled) return;
        const id = Number(n.dataset.id);
        const inf = () => arr(N().informants).find((i) => i.id === id);
        const intel = () => arr(N().intel).find((i) => i.id === id);
        switch (n.dataset.nx) {
            case 'newInf': { const v = await informantForm(); if (v) send('createInformant', v); return; }
            case 'editInf': { const c = inf(); if (!c) return; const v = await informantForm(c); if (v) send('updateInformant', { id, ...v }); return; }
            case 'toggleInf': { const c = inf(); if (c) send('updateInformant', { id, enabled: !c.enabled }); return; }
            case 'delInf': { const c = inf(); if (c && await confirmBox(`Supprimer « ${c.name} » ?`, 'L\'informateur et toutes ses informations sont supprimés définitivement.')) send('deleteInformant', { id }); return; }
            case 'newIntel': { const d = await intelForm(); if (d) send('createIntel', d); return; }
            case 'editIntel': { const c = intel(); if (!c) return; const d = await intelForm(c); if (d) send('updateIntel', { id, ...d }); return; }
            case 'toggleIntel': { const c = intel(); if (c) send('toggleIntel', { id, enabled: !c.enabled }); return; }
            case 'delIntel': if (await confirmBox(`Supprimer l'information #${id} ?`, 'Suppression définitive.')) send('deleteIntel', { id }); return;
            case 'cancelLaunder': {
                const refund = n.dataset.refund === '1';
                if (await confirmBox('Annuler ce blanchiment ?', refund ? 'L\'argent sale est rendu au joueur.' : 'Le joueur perd la somme engagée.')) send('cancelLaunder', { id: n.dataset.id, refund });
                return;
            }
            case 'mkRemove': {
                const ret = n.dataset.ret === '1';
                if (await confirmBox(`Retirer l'annonce #${id} ?`, ret ? 'Les objets restants reviennent au vendeur en colis.' : 'Les objets restants sont CONFISQUÉS (supprimés).')) send('marketRemove', { id, returnItems: ret });
                return;
            }
            case 'mkBan': {
                const v = await formModal(`Exclure « ${n.dataset.alias} » du marché`, [{ name: 'reason', label: 'Raison (visible par le joueur)', value: '' }], 'Exclure', true);
                if (v) send('marketBan', { owner: n.dataset.owner, banned: true, reason: v.reason });
                return;
            }
            case 'mkUnban': send('marketBan', { owner: n.dataset.owner, banned: false }); return;
            case 'cancelMerc': {
                const refund = n.dataset.refund === '1';
                if (await confirmBox(`Annuler le contrat #${id} ?`, refund ? 'L\'équipe se retire et le commanditaire est remboursé en totalité.' : 'L\'équipe se retire, aucun remboursement.')) send('cancelMerc', { id, refund });
                return;
            }
            case 'setSetting': {
                const inp = document.querySelector(`[data-nxs="${CSS.escape(n.dataset.path)}"]`);
                if (!inp || inp.value === '' || !isFinite(Number(inp.value))) return toast('Valeur invalide.', 'error');
                send('setSetting', { path: n.dataset.path, value: Number(inp.value) });
                return;
            }
            case 'resetSetting': send('resetSetting', { path: n.dataset.path }); return;
            case 'app': send('setSetting', { path: n.dataset.path, value: n.dataset.on !== '1' }); return;
            case 'payout': {
                const paid = n.dataset.status === 'paid';
                if (await confirmBox(paid ? 'Marquer comme payé ?' : 'Relancer le versement ?', paid ? 'Le joueur ne recevra rien de plus.' : 'Le versement sera retenté à la prochaine ouverture du téléphone du joueur.')) send('resolvePayout', { id, status: n.dataset.status });
                return;
            }
            case 'revoke': {
                const h = (document.getElementById('nx-handle') || {}).value || '';
                if (!h.trim()) return toast('Indique un pseudo.', 'error');
                if (await confirmBox(`Révoquer « ${h.trim()} » ?`, 'Le pseudo est retiré du réseau.')) send('revokeIdentity', { handle: h.trim() });
                return;
            }
        }
    });
})();
