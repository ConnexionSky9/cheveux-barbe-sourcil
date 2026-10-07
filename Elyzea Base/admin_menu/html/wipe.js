/* =========================================================
   ONGLET 🧹 WIPE (permission « wipe_character »)
   ID du joueur → ses personnages → suppression totale d'un personnage.
   Double confirmation : « Êtes-vous sûr ? » puis écrire ElyzeaFA.
   ========================================================= */
(() => {
    const at = TABS.findIndex((t) => t.id === 'logs');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'wipe', group: 4, label: 'Wipe', ico: '🧹',
        sub: 'Supprimer définitivement un personnage d\'un joueur.',
        show: () => has('wipe_character') && !!(D && D.wipe),
    });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;

    VIEWS.wipe = () => {
        const w = D.wipe;
        const L = w.lookup;
        return `
            <div class="protect" style="margin-bottom:14px">⚠️ <span>Un wipe est <b>définitif</b> : le personnage, son argent, ses véhicules, son
                apparence, ses permis et son casier sont supprimés. Rien ne peut être récupéré.</span></div>
            <div class="section"><h2>Trouver le joueur</h2>
                <div class="inline" style="max-width:420px"><input class="input" id="wipe-id" inputmode="numeric" placeholder="ID du joueur en jeu" value="${esc(draft('wipeId', ''))}" data-draft="wipeId">
                    <button class="btn primary" data-wipe="lookup">Voir ses personnages</button></div>
            </div>
            ${!L ? '' : L.error ? `<div class="empty" style="color:var(--danger)">${esc(L.error)}</div>` : `
            <div class="section"><h2>Personnages de ${esc(L.rp || '?')} <span class="muted" style="font-size:14px">(ID ${L.target})</span></h2>
                ${L.chars.length ? `<div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr))">${L.chars.map((c, i) => `
                    <div class="card" style="padding:16px">
                        <div class="inline" style="justify-content:space-between;align-items:flex-start">
                            <div><strong style="font-size:17px">${esc(c.name)}</strong>
                                <div class="muted" style="font-size:12px">Personnage ${c.slot || i + 1} · <span class="keycap">${esc(c.citizenid)}</span></div></div>
                            ${c.active ? '<span class="badge" style="color:var(--ok)">En jeu</span>' : ''}
                        </div>
                        <div class="muted" style="margin:10px 0;line-height:1.6">${c.birthdate ? `Né(e) le ${esc(c.birthdate)}<br>` : ''}${esc(c.job || 'Sans emploi')}<br>
                            Banque ${money(c.bank)} · Liquide ${money(c.cash)}</div>
                        <button class="btn danger" data-wipe="char" data-cid="${esc(c.citizenid)}" data-name="${esc(c.name)}">🧹 Wipe ce personnage</button>
                    </div>`).join('')}</div>` : '<div class="empty">Ce joueur n\'a aucun personnage.</div>'}
            </div>`}`;
    };

    // Deuxième confirmation : écrire le mot de confirmation exact
    function typeConfirm(name, word) {
        closeModal();
        $('#modal-root').innerHTML = `<div class="modal-backdrop"><div class="modal">
            <h2>Dernière confirmation</h2>
            <p class="muted" style="margin-bottom:12px;line-height:1.5">Pour supprimer définitivement <b>${esc(name)}</b>, écris
                <span class="keycap">${esc(word)}</span> ci-dessous.</p>
            <input class="input" id="wipe-confirm" autocomplete="off" spellcheck="false" placeholder="${esc(word)}">
            <div class="btn-row" style="margin-top:14px"><button class="btn" data-m="cancel">Annuler</button>
                <button class="btn danger" data-m="ok" id="wipe-ok" disabled>Wipe définitif</button></div>
        </div></div>`;
        const input = document.getElementById('wipe-confirm');
        const ok = document.getElementById('wipe-ok');
        input.focus();
        input.addEventListener('input', () => { ok.disabled = input.value !== word; });
        return new Promise((resolve) => {
            modalResolve = resolve;
            input.addEventListener('keydown', (e) => { if (e.key === 'Enter' && input.value === word) closeModal(input.value); });
            $('#modal-root').onclick = (e) => {
                if (e.target.classList.contains('modal-backdrop') || e.target.dataset.m === 'cancel') return closeModal(false);
                if (e.target.dataset.m === 'ok' && input.value === word) closeModal(input.value);
            };
        });
    }

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'wipe') return;
        const b = e.target.closest('[data-wipe]');
        if (!b) return;
        if (b.dataset.wipe === 'lookup') {
            const id = Number((document.getElementById('wipe-id') || {}).value);
            if (!id) return toast('Entre l\'ID du joueur.', 'error');
            return action('wipe_lookup', { target: id });
        }
        if (b.dataset.wipe === 'char') {
            const name = b.dataset.name;
            if (!(await confirmBox('Êtes-vous sûr ?', `Le personnage ${name} va être supprimé définitivement, avec tout ce qu'il possède.`))) return;
            const typed = await typeConfirm(name, D.wipe.confirm);
            if (!typed) return;
            action('wipe_character', { citizenid: b.dataset.cid, confirm: typed });
        }
    });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && e.target.id === 'wipe-id' && isOpen && tab === 'wipe') {
            const btn = document.querySelector('[data-wipe="lookup"]');
            if (btn) btn.click();
        }
    });
})();
