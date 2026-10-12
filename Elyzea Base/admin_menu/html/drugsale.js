/* =========================================================
   VENTE DE DROGUE (ressource elyzea_illegal, permission « drugsale_manage »)
   Réglages du mode vente (F5) : clients PNJ, prix, vols, appels à la police.
   ========================================================= */
(() => {
    TABS.push({
        id: 'drugsale', group: 6, label: 'Vente de drogue', ico: '🌿',
        sub: 'Mode vente du F5 : clients PNJ, drogues et prix, vols, appels à la police.',
        show: () => has('drugsale_manage') && !!(D && D.drugsale),
    });

    const G = { draft: null };
    const send = (name, data = {}) => action('drugsale', { name, data });
    const PAY = { dirty: 'Argent sale', clean: 'Liquide (argent propre)' };

    VIEWS.drugsale = () => {
        const d = D.drugsale;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_illegal')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        }
        if (!G.draft) G.draft = JSON.parse(JSON.stringify(d.settings));
        const s = G.draft;
        const tog = (k, title, sub) => `<div class="tile toggle-tile ${s[k] ? 'on' : ''}" data-dsb="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
        const num = (path, label, extra = '') => {
            const v = path.split('.').reduce((o, k) => (o ? o[k] : ''), s);
            return `<div class="field"><label>${label}</label><input class="input" type="number" data-dsf="${path}" value="${esc(v)}" ${extra}></div>`;
        };
        const buyPct = Math.max(0, 100 - Number(s.stealChance || 0) - Number(s.policeChance || 0));
        const drugs = (s.drugs || []).map((x, i) => `<tr>
            <td><input class="input" list="ds-items" data-dsd="${i}" data-k="item" value="${esc(x.item)}" placeholder="nom de l'objet (ex : weed_pouch)"></td>
            <td><input class="input" data-dsd="${i}" data-k="label" value="${esc(x.label)}" placeholder="Nom affiché"></td>
            <td><input class="input" type="number" min="1" data-dsd="${i}" data-k="min" value="${esc(x.min)}" style="width:100px"></td>
            <td><input class="input" type="number" min="1" data-dsd="${i}" data-k="max" value="${esc(x.max)}" style="width:100px"></td>
            <td style="text-align:right"><button class="btn danger" data-dsa="delDrug" data-i="${i}">Retirer</button></td></tr>`).join('');
        const active = (d.active || []).map((a) => `<tr><td>${esc(a.name || '?')} <span class="muted">[${a.id}]</span></td><td>${a.sales}</td><td>${Number(a.earned || 0).toLocaleString('fr-FR')} $</td></tr>`).join('');
        return `
            <div class="stats">
                <div class="stat"><b>${d.settings.enabled ? 'Activée' : 'Coupée'}</b><span>Vente de drogue</span></div>
                <div class="stat"><b>${(d.active || []).length}</b><span>Vendeur(s) en ce moment</span></div>
                <div class="stat"><b>${d.police}</b><span>Policier(s) en service</span></div>
                <div class="stat"><b>${(d.settings.drugs || []).length}</b><span>Drogue(s) vendable(s)</span></div>
            </div>
            <div class="section"><h2>🌿 Fonctionnement</h2>
                <p class="hint">Un joueur qui a de la drogue sur lui active le mode vente dans son menu <span class="keycap">F5</span>. Des clients PNJ viennent à pied et demandent 1 à N pochons :
                    <span class="keycap">E</span> vendre, <span class="keycap">G</span> refuser. Chaque client peut <b>acheter</b>, <b>voler</b> quelques pochons et s'enfuir
                    (il faut le frapper : il se rend, puis <span class="keycap">ALT</span> › Fouiller pour récupérer les pochons) ou <b>appeler la police</b>
                    (alerte « Activité suspecte » avec une zone approximative sur la carte des policiers).</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('enabled', s.enabled ? 'Vente de drogue activée' : 'Vente de drogue coupée', 'Coupée : impossible d\'activer le mode vente.')}
                    ${tog('requireGroup', 'Réservée aux groupes illégaux', 'Sinon, tout joueur avec de la drogue peut vendre.')}
                    ${tog('noSaleInVehicle', 'Pas de client en véhicule', 'Les clients n\'arrivent que si le vendeur est à pied.')}
                    ${tog('territoryOnly', 'Seulement dans les territoires', 'Zones de l\'éditeur de map cochées « Territoire de vente ».')}
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1100px">
                    <div class="field"><label>Paiement</label><select class="input" data-dsf="payment">${Object.entries(PAY).map(([k, v]) => `<option value="${k}" ${s.payment === k ? 'selected' : ''}>${v}</option>`).join('')}</select></div>
                    ${num('minPolice', 'Policiers en service minimum', 'min="0" max="50"')}
                    ${num('interval.min', 'Délai entre deux clients : min (s)', 'min="5"')}
                    ${num('interval.max', 'Délai entre deux clients : max (s)', 'min="5"')}
                    ${num('maxPerBuyer', 'Pochons demandés par client (max)', 'min="1" max="50"')}
                    ${num('waitTime', 'Patience d\'un client (s)', 'min="10" max="300"')}
                    ${num('stealChance', 'Chance de vol (%)', 'min="0" max="100"')}
                    ${num('stealMax', 'Pochons volés (max)', 'min="1" max="50"')}
                    ${num('policeChance', 'Chance d\'appel à la police (%)', 'min="0" max="100"')}
                    ${num('policeRadius', 'Précision de l\'alerte police (m)', 'min="0" max="1000"')}
                    ${num('territoryGain', 'Contrôle gagné par pochon vendu (%)', 'min="0" max="100" step="0.5"')}
                </div>
                <p class="hint" style="margin-top:8px">Sur 100 clients : environ <b>${buyPct}</b> achètent, <b>${Number(s.stealChance || 0)}</b> volent, <b>${Number(s.policeChance || 0)}</b> appellent la police.</p>
            </div>
            <div class="section"><h2>Drogues vendables</h2>
                <p class="hint">Prix <b>par pochon</b>, tiré au hasard entre le minimum et le maximum à chaque client. L'objet doit exister dans l'inventaire.</p>
                <datalist id="ds-items">${(d.items || []).map((it) => `<option value="${esc(it.name)}">${esc(it.label)}</option>`).join('')}</datalist>
                <table class="loot wide"><tr><th>Objet</th><th>Nom affiché</th><th style="width:120px">Prix min ($)</th><th style="width:120px">Prix max ($)</th><th style="width:110px"></th></tr>
                    ${drugs || '<tr><td colspan="5" class="muted">Aucune drogue : personne ne pourra vendre.</td></tr>'}</table>
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-dsa="addDrug">+ Ajouter une drogue</button></div>
            </div>
            <div class="section"><div class="btn-row"><button class="btn primary" data-dsa="save">Enregistrer</button><button class="btn" data-dsa="cancel">Annuler les modifications</button>
                <button class="btn" data-dsa="reset">Valeurs par défaut</button><button class="btn danger" data-dsa="stopAll" ${(d.active || []).length ? '' : 'disabled'}>Arrêter tous les vendeurs</button></div></div>
            <div class="section"><h2>🗺️ Territoires</h2>
                <p class="hint">Les territoires se créent dans l'<b>éditeur de map › Zones</b> (type « Territoire (drogue) » ou case « Territoire de vente »). Zone neutre (blanche) : le premier groupe qui y vend prend 100 %.
                    Ensuite, chaque pochon vendu par un membre d'un autre groupe lui fait gagner ${Number(s.territoryGain || 0)} % (pris aux autres au prorata). Les joueurs voient tout dans F5 › tablette › Map.</p>
                <table class="loot wide"><tr><th>Territoire</th><th>Contrôle</th><th style="width:150px"></th></tr>
                    ${(d.territories || []).map((t) => `<tr><td><strong>${esc(t.name)}</strong></td>
                        <td>${t.shares.length ? t.shares.map((x) => `<span style="display:inline-flex;align-items:center;gap:5px;margin-right:12px"><i style="width:10px;height:10px;border-radius:3px;background:${esc(x.color)};display:inline-block"></i>${esc(x.label)} <b>${x.pct} %</b></span>`).join('') : '<span class="muted">Neutre</span>'}</td>
                        <td style="text-align:right"><button class="btn" data-dsa="resetTerritory" data-id="${t.id}" ${t.shares.length ? '' : 'disabled'}>Remettre neutre</button></td></tr>`).join('') || '<tr><td colspan="3" class="muted">Aucun territoire : crée une zone dans l\'éditeur de map.</td></tr>'}</table>
                ${(d.territories || []).some((t) => t.shares.length) ? '<div class="btn-row" style="margin-top:10px"><button class="btn danger" data-dsa="resetTerritory">Tout remettre neutre</button></div>' : ''}
            </div>
            ${active ? `<div class="section"><h2>Vendeurs en ce moment</h2><table class="loot wide"><tr><th>Joueur</th><th style="width:140px">Pochons vendus</th><th style="width:160px">Gains</th></tr>${active}</table></div>` : ''}`;
    };

    const setPath = (o, path, v) => { const ks = path.split('.'); const last = ks.pop(); ks.reduce((a, k) => (a[k] = a[k] || {}), o)[last] = v; };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'drugsale' || !G.draft) return;
        const t = ev.target;
        if (t.dataset.dsf && t.tagName !== 'SELECT') setPath(G.draft, t.dataset.dsf, t.type === 'number' ? Number(t.value) : t.value);
        if (t.dataset.dsd !== undefined) {
            const x = G.draft.drugs[Number(t.dataset.dsd)];
            if (x) x[t.dataset.k] = t.type === 'number' ? Number(t.value) : t.value;
        }
    });
    document.addEventListener('change', (ev) => {
        if (!isOpen || tab !== 'drugsale' || !G.draft) return;
        const t = ev.target;
        if (t.dataset.dsf && t.tagName === 'SELECT') setPath(G.draft, t.dataset.dsf, t.value);
        if (t.dataset.dsd !== undefined && t.dataset.k === 'item') {
            const x = G.draft.drugs[Number(t.dataset.dsd)];
            const it = (D.drugsale.items || []).find((i) => i.name === t.value);
            if (x && it && !x.label) { x.label = it.label; render(); }
        }
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'drugsale') return;
        let n;
        if ((n = ev.target.closest('[data-dsb]')) && G.draft) { G.draft[n.dataset.dsb] = !G.draft[n.dataset.dsb]; return render(); }
        if (!(n = ev.target.closest('[data-dsa]')) || n.disabled) return;
        switch (n.dataset.dsa) {
            case 'addDrug': G.draft.drugs = G.draft.drugs || []; G.draft.drugs.push({ item: '', label: '', min: 50, max: 100 }); return render();
            case 'delDrug': G.draft.drugs.splice(Number(n.dataset.i), 1); return render();
            case 'save': send('save', G.draft); G.draft = null; return;
            case 'cancel': G.draft = null; return render();
            case 'reset': if (await confirmBox('Valeurs par défaut ?', 'Tous les réglages de la vente de drogue reviennent à ceux du fichier config.lua.')) { G.draft = null; send('reset'); } return;
            case 'resetTerritory': {
                const id = n.dataset.id ? Number(n.dataset.id) : undefined;
                if (await confirmBox(id ? 'Remettre ce territoire neutre ?' : 'Tout remettre neutre ?', id ? 'Plus aucun groupe ne le contrôlera.' : 'Tous les territoires redeviennent neutres (blancs).')) send('resetTerritory', { id });
                return;
            }
            case 'stopAll': if (await confirmBox('Arrêter tous les vendeurs ?', 'Le mode vente sera coupé pour tous les joueurs qui vendent en ce moment.')) send('stopAll'); return;
        }
    });
})();
