/* =========================================================
   MÉTIERS › MÉTIERS DE FARM (ressource elyzea_farm, permission « farm_manage »)
   Bûcheron… : temps de récolte, quantités, prix de revente, zones de
   travail, arbres posés à la main, tenue de travail homme / femme.
   Le PNJ se pose avec l'éditeur de map (rôle « 🪓 Métier de farm »).
   ========================================================= */
(() => {
    TABS.push({
        id: 'farm', group: 5, label: 'Métiers de farm', ico: '🪓',
        sub: 'Bûcheron… : temps de coupe, bûches obtenues, prix de revente, zones, tenue.',
        show: () => has('farm_manage') && !!(D && D.farm),
    });

    const F = { farm: null, sub: 'settings', draft: null, draftFor: null };
    const send = (name, data = {}) => action('farm', { name, data: { farm: F.farm, ...data } });
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const SUBS = [{ id: 'settings', label: 'Réglages' }, { id: 'zones', label: 'Zones de travail' }, { id: 'outfit', label: 'Tenue' }];
    const cur = () => (D.farm.farms || []).find((f) => f.key === F.farm);

    VIEWS.farm = () => {
        const d = D.farm;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_farm')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_farm')}</span> dans server.cfg, après admin_menu.</span></div>`;
        }
        if (!F.farm || !cur()) F.farm = (d.farms[0] || {}).key;
        const f = cur();
        if (!f) return '<div class="empty">Aucun métier de farm.</div>';
        if (!F.draft || F.draftFor !== f.key) { F.draft = JSON.parse(JSON.stringify(f.settings)); F.draftFor = f.key; }
        const pick = d.farms.length > 1 ? `<div class="chips" style="margin-bottom:12px">${d.farms.map((x) => `<button class="btn ${x.key === F.farm ? 'on' : ''}" data-fmk="${x.key}">${x.icon} ${esc(x.label)}</button>`).join('')}</div>` : '';
        const nav = `<div class="segmented">${SUBS.map((s) => `<button class="seg ${s.id === F.sub ? 'active' : ''}" data-fms="${s.id}">${s.label}</button>`).join('')}</div>`;
        const head = `<div class="stats">
            <div class="stat"><b>${f.working}</b><span>Joueurs au travail</span></div>
            <div class="stat"><b>${f.settings.zones.length}</b><span>Zone(s) de travail</span></div>
            <div class="stat"><b>${f.settings.time} s</b><span>Par récolte</span></div>
            <div class="stat"><b>${money(f.settings.sellPrice)}</b><span>Prix d'une ${esc(f.itemLabel.toLowerCase())}</span></div></div>`;
        return pick + head + nav + ({ settings, zones, outfit }[F.sub] || settings)(f);
    };

    function settings(f) {
        const s = F.draft;
        const tog = (k, title, sub) => `<div class="tile toggle-tile ${s[k] ? 'on' : ''}" data-fmb="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
        const num = (k, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-fmf="${k}" value="${esc(s[k])}" ${extra}></div>`;
        return `
            <div class="section"><h2>${f.icon} ${esc(f.label)}</h2>
                <p class="hint">Les joueurs commencent et arrêtent le travail auprès du <b>PNJ</b> (éditeur de map › PNJ › rôle <b>🪓 Métier de farm</b>).
                    Ils récoltent avec <span class="keycap">ALT</span> dans les <b>zones de travail</b> et revendent au même PNJ.
                    Ce travail se fait <b>en plus</b> du métier principal.</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('enabled', s.enabled ? 'Ouvert' : 'Fermé', 'Les joueurs peuvent commencer à travailler.')}
                    ${tog('requireTarget', 'Devant un arbre', 'Sinon : n\'importe où dans la zone.')}
                    ${tog('requireTool', 'Outil obligatoire', 'Il faut l\'outil dans l\'inventaire.')}
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;max-width:900px">
                    ${num('time', 'Temps de récolte (secondes)', 'min="1" max="120"')}
                    ${num('minAmount', `${esc(f.itemLabel)} minimum par récolte`, 'min="1" max="100"')}
                    ${num('maxAmount', `${esc(f.itemLabel)} maximum par récolte`, 'min="1" max="100"')}
                    ${num('sellPrice', `Prix de revente d'une ${esc(f.itemLabel.toLowerCase())} ($)`, 'min="0"')}
                    <div class="field"><label>Revente payée en</label><select class="input" data-fmf="payWith">
                        <option value="cash" ${s.payWith !== 'bank' ? 'selected' : ''}>Liquide</option><option value="bank" ${s.payWith === 'bank' ? 'selected' : ''}>Banque</option></select></div>
                    ${num('maxPerHour', 'Maximum par heure et par joueur (0 = illimité)', 'min="0"')}
                    <div class="field"><label>Outil (si obligatoire)</label><input class="input" data-fmf="tool" value="${esc(s.tool)}" placeholder="WEAPON_HATCHET"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-fma="save">Enregistrer</button><button class="btn" data-fma="reset">Annuler</button></div>
            </div>`;
    }

    function zones(f) {
        const s = f.settings;
        return `
            <div class="section"><h2>Zones de travail</h2>
                <p class="hint">On ne peut récolter <b>que dans ces zones</b> (cercles affichés sur la carte des joueurs au travail).
                    Place-toi au centre de la zone puis « Ajouter une zone à ma position ». Les arbres ne disparaissent pas : on peut rester sur le même.</p>
                <div class="btn-row"><button class="btn primary" data-fma="zoneAdd">📍 Ajouter une zone à ma position</button></div>
                ${s.zones.length ? `<table style="margin-top:12px"><tr><th>Zone</th><th style="width:90px">Rayon</th><th>Position</th><th style="width:90px">Active</th><th></th></tr>
                    ${s.zones.map((z) => `<tr style="${z.enabled === false ? 'opacity:.55' : ''}">
                        <td><strong>${esc(z.label)}</strong> <span class="muted">#${z.id}</span></td><td>${Number(z.radius).toFixed(0)} m</td>
                        <td class="muted" style="font-size:12px">${z.x.toFixed(1)}, ${z.y.toFixed(1)}, ${z.z.toFixed(1)}</td>
                        <td><div class="tile toggle-tile ${z.enabled !== false ? 'on' : ''}" data-fma="zoneToggle" data-id="${z.id}" style="padding:6px 8px"><span></span><div class="switch"></div></div></td>
                        <td style="text-align:right;white-space:nowrap"><button class="btn" data-fma="tp" data-id="${z.id}">Y aller</button>
                            <button class="btn" data-fma="zoneEdit" data-id="${z.id}">Modifier</button>
                            <button class="btn" data-fma="zoneHere" data-id="${z.id}" title="Déplacer au centre de ma position">📍</button>
                            <button class="btn danger" data-fma="zoneDel" data-id="${z.id}">✕</button></td></tr>`).join('')}</table>`
                    : '<div class="empty" style="margin-top:12px">Aucune zone : personne ne peut encore travailler.</div>'}
            </div>
            <div class="section"><h2>Arbres posés à la main (facultatif)</h2>
                <p class="hint">Les arbres de la carte sont reconnus tout seuls. Si un arbre n'est pas reconnu (arbre ajouté par une map),
                    place-toi contre lui, dans une zone, puis « Ajouter un arbre à ma position ».</p>
                <div class="btn-row"><button class="btn" data-fma="pointAdd">🌲 Ajouter un arbre à ma position</button></div>
                ${s.points.length ? `<table style="margin-top:12px">${s.points.map((p) => `<tr><td><strong>Arbre #${p.id}</strong></td>
                    <td class="muted" style="font-size:12px">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</td>
                    <td style="text-align:right"><button class="btn" data-fma="tp" data-id="${p.id}">Y aller</button>
                        <button class="btn danger" data-fma="pointDel" data-id="${p.id}">✕</button></td></tr>`).join('')}</table>` : ''}
            </div>`;
    }

    function outfit(f) {
        const o = f.settings.outfit || {};
        const count = (g) => Object.keys((o[g] || {}).c || {}).length + Object.keys((o[g] || {}).p || {}).length;
        return `
            <div class="section"><h2>Tenue de travail</h2>
                <p class="hint">Mise automatiquement quand le joueur commence à travailler, retirée quand il arrête (il retrouve sa tenue d'origine).
                    Pour la changer : habille ton personnage comme tu veux, puis « Copier ma tenue actuelle » (elle est enregistrée pour ton sexe).</p>
                <table><tr><th>Tenue</th><th>Éléments</th><th></th></tr>
                    ${['male', 'female'].map((g) => `<tr><td><strong>${g === 'male' ? '👨 Homme' : '👩 Femme'}</strong></td><td class="muted">${count(g)} élément(s)</td>
                        <td style="text-align:right"><button class="btn" data-fma="outfitReset" data-g="${g}">Remettre la tenue d'origine</button></td></tr>`).join('')}
                </table>
                <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-fma="outfitCopy">👕 Copier ma tenue actuelle</button></div>
            </div>`;
    }

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'farm' || !F.draft) return;
        const t = ev.target;
        if (t.dataset.fmf) F.draft[t.dataset.fmf] = t.type === 'number' ? Number(t.value) : t.value;
    });
    document.addEventListener('change', (ev) => {
        if (!isOpen || tab !== 'farm' || !F.draft) return;
        const t = ev.target;
        if (t.dataset.fmf && t.tagName === 'SELECT') F.draft[t.dataset.fmf] = t.value;
    });

    const zoneById = (id) => cur().settings.zones.find((z) => z.id === Number(id));

    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'farm') return;
        let n;
        if ((n = ev.target.closest('[data-fmk]'))) { F.farm = n.dataset.fmk; F.draft = null; return render(); }
        if ((n = ev.target.closest('[data-fms]'))) { F.sub = n.dataset.fms; return render(); }
        if ((n = ev.target.closest('[data-fmb]'))) { F.draft[n.dataset.fmb] = !F.draft[n.dataset.fmb]; return render(); }
        if (!(n = ev.target.closest('[data-fma]')) || n.disabled) return;
        const a = n.dataset.fma;
        switch (a) {
            case 'save': send('saveSettings', F.draft); F.draft = null; return;
            case 'reset': F.draft = null; return render();
            case 'zoneAdd': {
                const v = await formModal('Nouvelle zone de travail à ma position', [
                    { name: 'label', label: 'Nom', placeholder: 'ex : Forêt de Paleto' },
                    { name: 'radius', label: 'Rayon (mètres)', type: 'number', value: 40 },
                ], 'Créer');
                if (v) send('addZone', { ...v, useMyPosition: true });
                return;
            }
            case 'zoneEdit': {
                const z = zoneById(n.dataset.id);
                const v = z && await formModal(`Modifier « ${z.label} »`, [
                    { name: 'label', label: 'Nom', value: z.label },
                    { name: 'radius', label: 'Rayon (mètres)', type: 'number', value: z.radius },
                ], 'Enregistrer');
                if (v) send('updateZone', { id: z.id, ...v });
                return;
            }
            case 'zoneHere': {
                const z = zoneById(n.dataset.id);
                if (z && await confirmBox('Déplacer la zone ici ?', `Le centre de « ${z.label} » sera placé à ta position.`)) send('updateZone', { id: z.id, useMyPosition: true });
                return;
            }
            case 'zoneToggle': { const z = zoneById(n.dataset.id); if (z) send('updateZone', { id: z.id, enabled: z.enabled === false }); return; }
            case 'zoneDel': {
                const z = zoneById(n.dataset.id);
                if (z && await confirmBox('Supprimer la zone ?', `« ${z.label} » sera supprimée.`)) send('deleteZone', { id: z.id });
                return;
            }
            case 'pointAdd': return send('addPoint');
            case 'pointDel': return send('deletePoint', { id: Number(n.dataset.id) });
            case 'tp': post('close'); return send('tp', { id: Number(n.dataset.id) });
            case 'outfitCopy': {
                const r = await post('uniform_capture');
                if (!r || r.error || !r.outfit) return;
                return send('saveOutfit', { gender: r.gender, outfit: r.outfit });
            }
            case 'outfitReset':
                if (await confirmBox('Remettre la tenue d\'origine ?', 'La tenue de bûcheron fournie de base sera remise pour ce sexe.')) send('saveOutfit', { gender: n.dataset.g, reset: true });
                return;
        }
    });
})();
