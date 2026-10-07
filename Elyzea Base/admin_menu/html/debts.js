/* =========================================================
   ONGLET 💸 BANQUE NÉGATIVE (permission « view_debts »)
   Joueurs dont le compte en banque est à découvert (amendes,
   prélèvements…), connectés ou non.
   ========================================================= */
(() => {
    const at = TABS.findIndex((t) => t.id === 'players');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'debts', group: 1, label: 'Banque négative', ico: '💸',
        sub: 'Joueurs à découvert en banque, connectés ou non.',
        show: () => has('view_debts') && !!(D && D.debts),
        count: () => (D && D.debts ? D.debts.list.length : 0),
    });

    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;

    VIEWS.debts = () => {
        const d = D.debts;
        const q = String(draft('debtQ', '')).toLowerCase();
        const list = d.list.filter((e) => !q || String(e.name).toLowerCase().includes(q) || String(e.citizenid).toLowerCase().includes(q) || String(e.online || '') === q);
        const online = d.list.filter((e) => e.online).length;
        return `
            <div class="stats">
                <div class="stat"><b>${d.list.length}</b><span>Joueurs à découvert</span></div>
                <div class="stat"><b style="color:var(--danger)">${money(d.total)}</b><span>Découvert total</span></div>
                <div class="stat"><b>${online}</b><span>Connectés en ce moment</span></div>
            </div>
            <div class="inline" style="max-width:640px;margin:14px 0">
                <input class="input" id="debt-q" data-draft="debtQ" placeholder="Rechercher (nom, citizen ID, ID en jeu)" value="${esc(draft('debtQ', ''))}">
                <button class="btn" data-debt="refresh">↻ Actualiser</button>
            </div>
            <p class="hint">${d.updated ? `Mis à jour à ${esc(d.updated)}. ` : 'Chargement… '}Le solde des joueurs connectés est en direct ; celui des joueurs hors ligne vient de la base.</p>
            ${list.length ? `<table><tr><th>Joueur</th><th>Citizen ID</th><th style="text-align:right">Solde en banque</th><th>Statut</th><th></th></tr>
                ${list.map((e) => `<tr>
                    <td><strong>${esc(e.name)}</strong>${e.rp ? `<div class="muted" style="font-size:12px">${esc(e.rp)}</div>` : ''}</td>
                    <td><span class="keycap">${esc(e.citizenid)}</span></td>
                    <td style="text-align:right"><b style="color:var(--danger)">${money(e.bank)}</b></td>
                    <td>${e.online ? `<span class="badge" style="color:var(--ok)">En ligne · ID ${e.online}</span>` : '<span class="badge muted">Hors ligne</span>'}</td>
                    <td style="text-align:right">${e.online ? `<button class="btn" data-debt="player" data-id="${e.online}">Fiche</button>` : ''}</td></tr>`).join('')}
            </table>` : `<div class="empty">${d.updated ? (q ? 'Aucun joueur ne correspond.' : '✓ Aucun joueur n\'est à découvert.') : 'Recherche en cours…'}</div>`}`;
    };

    document.addEventListener('input', (e) => {
        if (e.target.id !== 'debt-q' || !isOpen || tab !== 'debts') return;
        const pos = e.target.selectionStart;
        render();
        const el = document.getElementById('debt-q');
        if (el) { el.focus(); el.setSelectionRange(pos, pos); }
    });

    document.addEventListener('click', (e) => {
        if (!isOpen || tab !== 'debts') return;
        const b = e.target.closest('[data-debt]');
        if (!b) return;
        if (b.dataset.debt === 'refresh') { action('debts_refresh'); return toast('Actualisation…', 'info'); }
        if (b.dataset.debt === 'player') { tab = 'players'; selectedPlayer = Number(b.dataset.id); render(); }
    });
})();
