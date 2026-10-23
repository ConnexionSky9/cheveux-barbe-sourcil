/* =========================================================
   ANNONCES PRESSE (ressource elyzea_presse, permission « presse_manage »)
   Réglages du système d'annonces commandées (activation, durée d'affichage,
   planificateur, reprise après erreur), rédactions, commandes, diffusions,
   file d'attente (pause, relance, annulation avec remboursement).
   ========================================================= */
(() => {
    TABS.push({
        id: 'presse', group: 5, label: 'Annonces presse', ico: '📣',
        sub: 'Annonces commandées aux rédactions : réglages, file d\'attente, commandes, diffusions.',
        show: () => has('presse_manage') && !!(D && D.presse),
    });

    const S = { draft: null, view: 'pending' };
    const send = (name, data = {}) => action('presse', { name, data });
    const money = (n) => `${Math.round(Number(n || 0)).toLocaleString('fr-FR')} $`;
    const ST = { scheduled: 'Programmée', offered: 'Proposée aux journalistes', queued: 'En file', broadcasting: 'À l\'écran', sent: 'Envoyée',
        failed: 'Échec', missed: 'Manquée (remboursée)', cancelled: 'Annulée' };
    const OST = { pending: 'Paiement…', charged: 'Paiement…', credited: 'Paiement…', active: 'En cours', completed: 'Terminée', cancelled: 'Annulée', failed: 'Échouée' };
    const FREQ = { '30m': '30 min', '1h': '1 h', '1d': '1 / jour' };

    VIEWS.presse = () => {
        const d = D.presse;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_presse')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_presse')}</span> dans server.cfg.</span></div>`;
        }
        if (!S.draft) S.draft = JSON.parse(JSON.stringify(d.settings));
        const s = S.draft, L = d.limits || {}, c = d.counts || {};
        const num = (k, label, hint) => `<div class="field"><label>${label}</label><input class="input" type="number" data-psf="${k}" value="${esc(s[k])}"
            min="${(L[k] || [])[0] ?? 0}" max="${(L[k] || [])[1] ?? ''}"><span class="muted" style="font-size:11px">${hint}</span></div>`;
        const slotRow = (x, acts) => `<tr><td class="muted">#${x.id}</td><td>${esc(x.dueLabel)}</td><td><strong>${esc(x.uid)}</strong><br><span class="muted">${esc(x.client_label || '')}</span></td>
            <td style="max-width:320px">${esc(x.text)}</td><td>${esc(ST[x.status] || x.status)}${x.mode ? `<br><span class="muted">${x.mode === 'manual' ? `manuel · ${esc(x.sent_by_name || '')}` : 'automatique'}</span>` : ''}
            ${x.last_error ? `<br><span class="muted" style="color:#f59e0b">${esc(x.last_error)}</span>` : ''}</td><td style="text-align:right;white-space:nowrap">${acts(x)}</td></tr>`;
        const pendActs = (x) => `${x.status === 'failed' ? `<button class="btn" data-psa="retry" data-id="${x.id}">Relancer</button>` : ''}
            ${x.status !== 'broadcasting' ? `<button class="btn danger" data-psa="cancelSlot" data-id="${x.id}">Annuler + rembourser</button>` : ''}`;
        let list = '';
        if (S.view === 'pending') {
            list = (d.pending || []).length ? `<table><tr><th></th><th>Prévue</th><th>Commande</th><th>Texte</th><th>État</th><th></th></tr>${d.pending.map((x) => slotRow(x, pendActs)).join('')}</table>`
                : '<div class="empty">Rien en attente : la file est vide.</div>';
        } else if (S.view === 'upcoming') {
            list = (d.upcoming || []).length ? `<table><tr><th></th><th>Prévue</th><th>Commande</th><th>Texte</th><th>État</th><th></th></tr>${d.upcoming.map((x) => slotRow(x, pendActs)).join('')}</table>`
                : '<div class="empty">Aucune diffusion programmée.</div>';
        } else if (S.view === 'sent') {
            list = (d.sent || []).length ? `<table><tr><th></th><th>Envoyée</th><th>Commande</th><th>Texte</th><th>Mode</th><th>Prime</th></tr>${d.sent.map((x) => `<tr><td class="muted">#${x.id}</td>
                <td>${esc(x.sentLabel || '')}<br><span class="muted">prévue ${esc(x.dueLabel)}</span></td><td><strong>${esc(x.uid)}</strong><br><span class="muted">${esc(x.client_label || '')}</span></td>
                <td style="max-width:320px">${esc(x.text)}</td><td>${x.mode === 'manual' ? `Manuel · ${esc(x.sent_by_name || '')}` : 'Automatique'}</td>
                <td>${x.commission ? `${money(x.commission)} <span class="muted">(${esc(x.commission_status || '')})</span>` : '—'}</td></tr>`).join('')}</table>` : '<div class="empty">Aucune diffusion.</div>';
        } else {
            list = (d.orders || []).length ? `<table><tr><th>Commande</th><th>Rédaction</th><th>Client</th><th>Texte</th><th>Diffusions</th><th>Montant</th><th>État</th><th></th></tr>${d.orders.map((o) => `<tr>
                <td><strong>${esc(o.uid)}</strong><br><span class="muted">${esc(FREQ[o.frequency] || o.frequency)} · ${esc(o.start_date)} → ${esc(o.end_date)}</span></td><td>${esc(o.agency_label || '')}</td>
                <td>${esc(o.client_label || '')}<br><span class="muted">${esc(o.client_name || '')}</span></td><td style="max-width:280px">${esc(o.text)}</td><td>${o.slots}</td>
                <td>${money(o.total)}<br><span class="muted">${money(o.unit_price)}/u${o.refunded ? ` · ${money(o.refunded)} remb.` : ''}</span></td><td>${esc(OST[o.status] || o.status)}${o.note ? `<br><span class="muted">${esc(o.note)}</span>` : ''}</td>
                <td>${o.status === 'active' ? `<button class="btn danger" data-psa="cancelOrder" data-id="${o.id}">Annuler + rembourser</button>` : ''}</td></tr>`).join('')}</table>` : '<div class="empty">Aucune commande.</div>';
        }
        const cur = d.current;
        return `
            <div class="stats">
                <div class="stat"><b>${d.settings.enabled ? (d.settings.queuePaused ? 'En pause' : 'Actif') : 'Coupé'}</b><span>Système d'annonces</span></div>
                <div class="stat"><b>${(c.queued || 0) + (c.broadcasting || 0)}</b><span>Dans la file</span></div>
                <div class="stat"><b>${c.offered || 0}</b><span>Proposées aux journalistes</span></div>
                <div class="stat"><b>${c.scheduled || 0}</b><span>Programmées</span></div>
                <div class="stat"><b>${c.sent || 0}</b><span>Envoyées</span></div>
                <div class="stat"><b>${c.failed || 0}</b><span>En échec</span></div>
            </div>
            <div class="section"><h2>📣 Réglages</h2>
                <p class="hint">Une seule annonce à l'écran à la fois, juste au-dessus de la mini-carte ; la suivante attend la fin de l'affichage. Heure du serveur : <b>${esc(d.serverTime)}</b>.
                    ${cur ? `<br>À l'écran : <b>${esc(cur.agency)}</b> — ${esc(cur.text)}` : ''}</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    <div class="tile toggle-tile ${s.enabled ? 'on' : ''}" data-psb="enabled"><div><strong>${s.enabled ? 'Annonces actives' : 'Annonces coupées'}</strong><span>Coupé : plus de commandes ni de diffusions (elles attendent).</span></div><div class="switch"></div></div>
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(5,1fr);gap:12px;max-width:1300px">
                    ${num('displaySeconds', 'Durée d\'affichage (secondes)', '5, 10, 15, 20…')}
                    ${num('tickSeconds', 'Vérification du planificateur (secondes)', 'Fréquence de contrôle des annonces dues.')}
                    ${num('manualWindow', 'Délai laissé aux journalistes (secondes)', 'Ensuite : envoi automatique, sans prime.')}
                    ${num('maxLate', 'Retard maximal (secondes)', 'Au-delà : annulée et remboursée au client.')}
                    ${num('maxAttempts', 'Essais avant « échec »', 'Une diffusion en échec se relance ici.')}
                </div>
                <div class="btn-row"><button class="btn primary" data-psa="save">Enregistrer</button><button class="btn" data-psa="reset">Annuler</button>
                    <button class="btn" data-psa="pause">${d.settings.queuePaused ? '▶ Relancer la file' : '⏸ Mettre la file en pause'}</button>
                    ${d.refundsFailed ? `<button class="btn danger" data-psa="refundRetry">Relancer ${d.refundsFailed} remboursement(s) en échec</button>` : ''}</div>
            </div>
            <div class="section"><h2>Entreprises de journalisme</h2>
                ${(d.agencies || []).length ? `<table><tr><th>Rédaction</th><th>Prix d'une annonce</th><th>Commandes</th><th>Commandes en cours</th><th>Encaissé (net)</th></tr>${d.agencies.map((a) => `<tr>
                    <td><strong>${esc(a.label)}</strong> <span class="muted">${esc(a.job)}</span></td><td>${money(a.price)}</td><td>${a.available ? 'Acceptées' : 'Fermées'}</td><td>${a.orders}</td><td>${money(a.revenue)}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucune rédaction : créez-en dans Agences des métiers › Presse.</div>'}
                <p class="hint">Tarif et primes : tablette de chaque rédaction (Diffusion › Annonces commandées).</p>
            </div>
            <div class="section"><h2>Suivi</h2>
                <div class="btn-row">${[['pending', 'File et attente'], ['upcoming', 'Programmées'], ['sent', 'Diffusions effectuées'], ['orders', 'Commandes']].map(([k, l]) => `<button class="btn ${S.view === k ? 'primary' : ''}" data-psv="${k}">${l}</button>`).join('')}</div>
                <div style="margin-top:12px">${list}</div>
            </div>`;
    };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'presse' || !S.draft) return;
        const t = ev.target;
        if (t.dataset.psf) S.draft[t.dataset.psf] = Number(t.value);
    });

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'presse') return;
        let n;
        if ((n = ev.target.closest('[data-psb]'))) { S.draft[n.dataset.psb] = !S.draft[n.dataset.psb]; return render(); }
        if ((n = ev.target.closest('[data-psv]'))) { S.view = n.dataset.psv; return render(); }
        if (!(n = ev.target.closest('[data-psa]')) || n.disabled) return;
        const a = n.dataset.psa, id = Number(n.dataset.id);
        switch (a) {
            case 'save': send('save', S.draft); S.draft = null; return;
            case 'reset': S.draft = null; return render();
            case 'pause': return send('pause', { on: !D.presse.settings.queuePaused });
            case 'retry': return send('retry', { id });
            case 'refundRetry': return send('refundRetry');
            case 'cancelSlot':
                if (await confirmBox('Annuler cette diffusion ?', 'Elle ne sera pas diffusée et son prix est remboursé au client depuis le compte de la rédaction.')) send('cancelSlot', { id });
                return;
            case 'cancelOrder': {
                const v = await formModal('Annuler la commande', [{ name: 'reason', label: 'Motif (obligatoire)', placeholder: 'ex : contenu contraire au règlement' }], 'Annuler et rembourser');
                if (v) send('cancelOrder', { id, reason: v.reason });
                return;
            }
        }
    });
})();
