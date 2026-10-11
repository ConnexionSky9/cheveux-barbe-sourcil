/* =========================================================
   STATIONS ESSENCE (ressource elyzea_fuel, permission « fuel_manage »)
   Consommation, prix au litre, stations posées à la position du staff.
   ========================================================= */
(() => {
    TABS.push({
        id: 'fuel', group: 2, label: 'Stations essence', ico: '⛽',
        sub: 'Consommation d\'essence, prix au litre et stations-service.',
        show: () => has('fuel_manage') && !!(D && D.fuel),
    });

    const F = { draft: null, q: '' };
    const send = (name, data = {}) => action('fuel', { name, data });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const PAY = { auto: 'Liquide, sinon banque', cash: 'Liquide seulement', bank: 'Banque seulement' };

    VIEWS.fuel = () => {
        const d = D.fuel;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_fuel')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_fuel')}</span> dans server.cfg, après elyzea_core.</span></div>`;
        }
        if (!F.draft) F.draft = JSON.parse(JSON.stringify(d.settings));
        const s = F.draft;
        const list = d.stations || [];
        const active = list.filter((x) => x.enabled !== false);
        const avg = active.length ? active.reduce((a, x) => a + Number(x.price || 0), 0) / active.length : 0;
        const tog = (k, title, sub) => `<div class="tile toggle-tile ${s[k] ? 'on' : ''}" data-fub="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
        const num = (k, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-fuf="${k}" value="${esc(s[k])}" ${extra}></div>`;
        const q = F.q.trim().toLowerCase();
        const shown = q ? list.filter((x) => `${x.label} ${x.id}`.toLowerCase().includes(q)) : list;
        return `
            <div class="stats">
                <div class="stat"><b>${active.length}</b><span>Station(s) ouverte(s)</span></div>
                <div class="stat"><b>${money(Math.round(avg * 100) / 100)}</b><span>Prix moyen du litre</span></div>
                <div class="stat"><b>×${Number(d.settings.consumption).toFixed(2)}</b><span>Consommation</span></div>
                <div class="stat"><b>${d.settings.enabled ? 'Oui' : 'Non'}</b><span>Essence consommée</span></div>
            </div>
            <div class="section"><h2>⛽ Réglages</h2>
                <p class="hint">Le conducteur consomme l'essence selon le régime moteur. <b>À 0 %, le moteur s'arrête et ne redémarre plus</b> tant que le plein n'est pas fait.
                    Dans une station, à pied près du véhicule (ou au volant, à l'arrêt) : <span class="keycap">E</span> pour faire le plein, payé au litre.</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('enabled', s.enabled ? 'Consommation active' : 'Consommation coupée', 'Coupée : les réservoirs ne baissent plus.')}
                    ${tog('showBlips', 'Stations sur la carte', 'Icône de pompe à essence pour tous les joueurs.')}
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1100px">
                    ${num('consumption', 'Vitesse de consommation (1 = normal, 2 = deux fois plus vite)', 'min="0" max="10" step="0.1"')}
                    ${num('price', 'Prix du litre pour une nouvelle station ($)', 'min="0" step="0.1"')}
                    ${num('refuelTime', 'Durée du plein (millisecondes par litre)', 'min="0" max="2000"')}
                    <div class="field"><label>Paiement du plein</label><select class="input" data-fuf="payWith">
                        ${Object.entries(PAY).map(([k, v]) => `<option value="${k}" ${s.payWith === k ? 'selected' : ''}>${v}</option>`).join('')}</select></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-fua="save">Enregistrer</button><button class="btn" data-fua="reset">Annuler</button>
                    <button class="btn" data-fua="setAll">Même prix pour toutes les stations…</button>
                    <button class="btn" data-fua="fillMine" title="Remplit le véhicule dans lequel tu es (gratuit, noté dans les logs)">⛽ Remplir mon véhicule</button></div>
            </div>
            <div class="section"><h2>Stations-service</h2>
                <p class="hint">Place-toi au milieu de la station (entre les pompes) puis « Ajouter une station à ma position ».
                    Le <b>rayon</b> est la zone où l'on peut faire le plein. Chaque station a son propre <b>prix au litre</b>.</p>
                <div class="btn-row"><button class="btn primary" data-fua="add">📍 Ajouter une station à ma position</button>
                    <input class="input" style="max-width:260px" placeholder="Rechercher une station…" data-fuq value="${esc(F.q)}"></div>
                ${shown.length ? `<table style="margin-top:12px"><tr><th>Station</th><th style="width:120px">Prix du litre</th><th style="width:80px">Rayon</th><th>Position</th><th style="width:90px">Ouverte</th><th></th></tr>
                    ${shown.map((x) => `<tr style="${x.enabled === false ? 'opacity:.55' : ''}">
                        <td><strong>${esc(x.label)}</strong> <span class="muted">#${x.id}</span></td>
                        <td>${money(x.price)}</td><td>${Number(x.radius).toFixed(0)} m</td>
                        <td class="muted" style="font-size:12px">${Number(x.x).toFixed(1)}, ${Number(x.y).toFixed(1)}, ${Number(x.z).toFixed(1)}</td>
                        <td><div class="tile toggle-tile ${x.enabled !== false ? 'on' : ''}" data-fua="toggle" data-id="${x.id}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                        <td style="text-align:right;white-space:nowrap"><button class="btn" data-fua="tp" data-id="${x.id}">Y aller</button>
                            <button class="btn" data-fua="edit" data-id="${x.id}">Modifier</button>
                            <button class="btn" data-fua="here" data-id="${x.id}" title="Déplacer la station à ma position">📍</button>
                            <button class="btn danger" data-fua="del" data-id="${x.id}">✕</button></td></tr>`).join('')}</table>`
                    : `<div class="empty" style="margin-top:12px">${q ? 'Aucune station ne correspond.' : 'Aucune station : personne ne peut faire le plein.'}</div>`}
            </div>`;
    };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'fuel') return;
        const t = ev.target;
        if (t.dataset.fuf && F.draft) F.draft[t.dataset.fuf] = t.type === 'number' ? Number(t.value) : t.value;
        if (t.dataset.fuq !== undefined) {
            F.q = t.value;
            const pos = t.selectionStart;
            render();
            const n = document.querySelector('[data-fuq]');
            if (n) { n.focus(); try { n.setSelectionRange(pos, pos); } catch (e) { /* champ sans curseur */ } }
        }
    });
    document.addEventListener('change', (ev) => {
        if (!isOpen || tab !== 'fuel' || !F.draft) return;
        const t = ev.target;
        if (t.dataset.fuf && t.tagName === 'SELECT') F.draft[t.dataset.fuf] = t.value;
    });

    const byId = (id) => (D.fuel.stations || []).find((x) => x.id === Number(id));

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'fuel') return;
        let n;
        if ((n = ev.target.closest('[data-fub]'))) { F.draft[n.dataset.fub] = !F.draft[n.dataset.fub]; return render(); }
        if (!(n = ev.target.closest('[data-fua]')) || n.disabled) return;
        const a = n.dataset.fua;
        switch (a) {
            case 'save': send('saveSettings', F.draft); F.draft = null; return;
            case 'reset': F.draft = null; return render();
            case 'fillMine': return send('fillMine');
            case 'setAll': {
                const v = await formModal('Prix du litre pour toutes les stations', [
                    { name: 'price', label: 'Prix du litre ($)', type: 'number', value: D.fuel.settings.price },
                ], 'Appliquer');
                if (v) send('setAllPrices', v);
                return;
            }
            case 'add': {
                const v = await formModal('Nouvelle station à ma position', [
                    { name: 'label', label: 'Nom', placeholder: 'ex : Station Grove Street' },
                    { name: 'price', label: 'Prix du litre ($)', type: 'number', value: D.fuel.settings.price },
                    { name: 'radius', label: 'Rayon (mètres)', type: 'number', value: 12 },
                ], 'Créer');
                if (v) send('addStation', { ...v, useMyPosition: true });
                return;
            }
            case 'edit': {
                const x = byId(n.dataset.id);
                const v = x && await formModal(`Modifier « ${x.label} »`, [
                    { name: 'label', label: 'Nom', value: x.label },
                    { name: 'price', label: 'Prix du litre ($)', type: 'number', value: x.price },
                    { name: 'radius', label: 'Rayon (mètres)', type: 'number', value: x.radius },
                ], 'Enregistrer');
                if (v) send('updateStation', { id: x.id, ...v });
                return;
            }
            case 'here': {
                const x = byId(n.dataset.id);
                if (x && await confirmBox('Déplacer la station ici ?', `« ${x.label} » sera placée à ta position.`)) send('updateStation', { id: x.id, useMyPosition: true });
                return;
            }
            case 'toggle': { const x = byId(n.dataset.id); if (x) send('updateStation', { id: x.id, enabled: x.enabled === false }); return; }
            case 'del': {
                const x = byId(n.dataset.id);
                if (x && await confirmBox('Supprimer la station ?', `« ${x.label} » sera supprimée.`)) send('deleteStation', { id: x.id });
                return;
            }
            case 'tp': post('close'); return send('tp', { id: Number(n.dataset.id) });
        }
    });
})();
