/* =========================================================
   COFFRES DE VÉHICULES (ressource elyzea_inventory, permission « trunk_manage »)
   Emplacements et poids maximum du coffre pour chaque catégorie de véhicule.
   ========================================================= */
(() => {
    TABS.push({
        id: 'trunks', group: 2, label: 'Coffres véhicules', ico: '🚗',
        sub: 'Nombre d\'emplacements et poids maximum du coffre, par catégorie de véhicule.',
        show: () => has('trunk_manage') && !!(D && D.trunks),
    });

    const T = { draft: {} };
    const send = (name, data = {}) => action('trunks', { name, data });

    VIEWS.trunks = () => {
        const d = D.trunks;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_inventory')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        }
        const val = (c, k) => (T.draft[c.class] && T.draft[c.class][k] !== undefined ? T.draft[c.class][k] : c[k]);
        const rows = d.classes.map((c) => {
            const dirty = !!T.draft[c.class];
            const none = Number(val(c, 'slots')) <= 0 || Number(val(c, 'kg')) <= 0;
            return `<tr>
                <td><strong>${esc(c.label)}</strong><div class="muted" style="font-size:11px">Catégorie ${c.class} · par défaut ${c.defSlots} empl. / ${c.defKg} kg</div></td>
                <td><input class="input" type="number" min="0" max="200" step="1" data-trc="${c.class}" data-trk="slots" value="${esc(val(c, 'slots'))}" style="width:110px"></td>
                <td><input class="input" type="number" min="0" max="5000" step="1" data-trc="${c.class}" data-trk="kg" value="${esc(val(c, 'kg'))}" style="width:110px"></td>
                <td>${none ? '<span class="muted">Pas de coffre</span>' : `<span style="color:var(--ok)">${esc(val(c, 'slots'))} empl. · ${esc(val(c, 'kg'))} kg</span>`}</td>
                <td style="text-align:right"><button class="btn ${dirty ? 'primary' : ''}" data-trs="${c.class}" ${dirty ? '' : 'disabled'}>Enregistrer</button></td></tr>`;
        }).join('');
        const withTrunk = d.classes.filter((c) => c.slots > 0 && c.kg > 0).length;
        return `
            <div class="stats">
                <div class="stat"><b>${withTrunk} / ${d.classes.length}</b><span>Catégories avec un coffre</span></div>
                <div class="stat"><b>${d.playerSlots}</b><span>Emplacements de l'inventaire joueur</span></div>
            </div>
            <div class="section"><h2>🚗 Capacité des coffres</h2>
                <p class="hint">Les joueurs ouvrent le coffre d'un véhicule déverrouillé avec <span class="keycap">ALT</span> › « Ouvrir le coffre ».
                    <b>Emplacements</b> = nombre de cases, <b>poids</b> = maximum en kg. Mets 0 pour qu'une catégorie n'ait pas de coffre.
                    Le changement s'applique à la prochaine ouverture. Si tu réduis un coffre, rien n'est perdu : les objets en trop restent gardés et réapparaissent si tu l'agrandis.
                    Les véhicules des joueurs gardent leur coffre ; ceux sans propriétaire (PNJ) le gardent jusqu'au redémarrage.</p>
                <table class="loot wide"><tr><th>Catégorie</th><th style="width:140px">Emplacements</th><th style="width:140px">Poids max (kg)</th><th style="width:200px">Actuel</th><th style="width:130px"></th></tr>${rows}</table>
                <div class="btn-row" style="margin-top:12px"><button class="btn" data-tra="reset">Remettre les valeurs par défaut</button></div>
            </div>`;
    };

    document.addEventListener('input', (e) => {
        const el = e.target.closest('[data-trc]');
        if (!el) return;
        const c = el.dataset.trc;
        T.draft[c] = T.draft[c] || {};
        T.draft[c][el.dataset.trk] = el.value;
        const btn = document.querySelector(`[data-trs="${c}"]`);
        if (btn) { btn.disabled = false; btn.classList.add('primary'); }
    });
    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'trunks') return;
        let n;
        if ((n = e.target.closest('[data-trs]')) && !n.disabled) {
            const c = Number(n.dataset.trs);
            const cur = D.trunks.classes.find((x) => x.class === c) || {};
            const dr = T.draft[c] || {};
            send('set', { class: c, slots: Number(dr.slots ?? cur.slots), kg: Number(dr.kg ?? cur.kg) });
            delete T.draft[c];
            return;
        }
        if ((n = e.target.closest('[data-tra="reset"]'))) {
            if (!(await confirmBox('Valeurs par défaut ?', 'La capacité par défaut sera remise pour toutes les catégories de véhicules.'))) return;
            T.draft = {};
            send('reset');
        }
    });
})();
