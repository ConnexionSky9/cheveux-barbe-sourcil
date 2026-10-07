/* =========================================================
   ONGLET 🛏️ RÉAPPARITION (permission « manage_respawn »)
   Où réapparaissent les joueurs morts qui n'ont pas été réanimés,
   et animation de réveil.
   ========================================================= */
(() => {
    const at = TABS.findIndex((t) => t.id === 'map');
    TABS.splice(at < 0 ? TABS.length : at + 1, 0, {
        id: 'respawn', group: 2, label: 'Réapparition', ico: '🛏️',
        sub: 'Lits / points où réapparaissent les joueurs non réanimés, et animation de réveil.',
        show: () => has('manage_respawn') && !!(D && D.respawn),
    });

    const TYPES = [
        { id: 'bed', label: '🛏️ Lit', sub: 'Allongé sur le lit, se lève en se frottant les yeux' },
        { id: 'ground', label: '🧍 Au sol', sub: 'Allongé par terre, se relève' },
        { id: 'stand', label: '🚶 Debout', sub: 'Debout, démarche hésitante' },
    ];
    const MODES = [
        { id: 'nearest', label: 'Le plus proche', sub: 'Le point le plus proche de l\'endroit de la mort' },
        { id: 'fixed', label: 'Toujours le même', sub: 'Un point choisi ci-dessous' },
        { id: 'random', label: 'Au hasard', sub: 'Un point au hasard parmi la liste' },
    ];
    const RS = { type: 'bed' };
    const typeLabel = (t) => (TYPES.find((x) => x.id === t) || TYPES[0]).label;
    const send = (name, data) => action(name, data);

    VIEWS.respawn = () => {
        const r = D.respawn;
        return `
            <p class="hint">Quand un joueur réapparaît après sa mort <b>sans avoir été réanimé</b>, il est placé sur un de ces points et se réveille avec une
                animation (écran flou qui se dissipe, il se relève). Ça fonctionne avec ton script de mort habituel : le menu repère que le joueur
                s'est relevé loin de l'endroit de sa mort. Un joueur réanimé sur place n'est pas concerné.</p>
            <div class="section"><h2>Réglages</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    <div class="tile toggle-tile ${r.enabled ? 'on' : ''}" data-rst="enabled"><div><strong>Réapparition personnalisée</strong><span>${r.enabled ? 'Active' : 'Désactivée : celle du script de mort'}</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${r.effects ? 'on' : ''}" data-rst="effects"><div><strong>Effets de réveil</strong><span>Flou, tremblement, démarche hésitante</span></div><div class="switch"></div></div>
                </div>
                <div class="grid" style="grid-template-columns:repeat(3,minmax(0,1fr))">
                    ${MODES.map((m) => `<button class="tile ${r.mode === m.id ? 'active' : ''}" data-rsmode="${m.id}"><strong>${m.label}</strong><span>${m.sub}</span></button>`).join('')}
                </div>
                ${r.mode === 'fixed' ? `<div class="field" style="max-width:360px;margin-top:10px"><label>Point utilisé</label>
                    <select class="input" id="rs-fixed">${r.points.map((p) => `<option value="${p.id}" ${r.fixed === p.id ? 'selected' : ''}>${esc(p.label)}</option>`).join('')}</select></div>` : ''}
            </div>
            <div class="section"><h2>Ajouter un point</h2>
                <p class="hint"><b>Lit</b> : monte sur le lit, place-toi au milieu, <b>dos à l'oreiller</b> (le personnage s'allongera dans ce sens).
                    Ajoute le point puis « Tester » : ajuste ensuite la hauteur et l'orientation jusqu'à ce que ce soit parfait.</p>
                <div class="chips" style="margin-bottom:10px">${TYPES.map((t) => `<button class="chip ${RS.type === t.id ? 'on' : ''}" data-rstype="${t.id}" title="${t.sub}">${t.label}</button>`).join('')}</div>
                <div class="inline" style="max-width:620px"><input class="input" id="rs-label" data-draft="rsLabel" placeholder="Nom (ex : Pillbox · lit 3)" value="${esc(draft('rsLabel', ''))}">
                    <button class="btn primary" data-rsa="add">📍 Ajouter à ma position</button></div>
            </div>
            <div class="section"><h2>Points (${r.points.length})</h2>
                ${r.points.length ? `<table><tr><th>Point</th><th>Type</th><th>Hauteur</th><th>Orientation</th><th></th></tr>
                    ${r.points.map((p) => `<tr data-rsid="${p.id}">
                        <td><strong>${esc(p.label)}</strong>${r.mode === 'fixed' && r.fixed === p.id ? ' <span class="badge" style="color:var(--ok)">utilisé</span>' : ''}
                            <div class="muted" style="font-size:12px">${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}</div></td>
                        <td><select class="input" data-rsfield="type" style="width:auto">${TYPES.map((t) => `<option value="${t.id}" ${p.type === t.id ? 'selected' : ''}>${t.label}</option>`).join('')}</select></td>
                        <td style="white-space:nowrap"><button class="btn" data-rsa="dz" data-v="-0.05">−</button> <span class="keycap">${(p.dz || 0) >= 0 ? '+' : ''}${(p.dz || 0).toFixed(2)} m</span> <button class="btn" data-rsa="dz" data-v="0.05">+</button></td>
                        <td style="white-space:nowrap"><button class="btn" data-rsa="dh" data-v="-15">↺</button> <span class="keycap">${Math.round(p.h || 0)}°</span> <button class="btn" data-rsa="dh" data-v="15">↻</button></td>
                        <td style="text-align:right;white-space:nowrap">
                            <button class="btn primary" data-rsa="test" title="Y aller et faire le réveil complet">▶ Tester</button>
                            <button class="btn" data-rsa="here" title="Déplacer le point à ta position">📍</button>
                            <button class="btn danger" data-rsa="del">✕</button></td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun point : la réapparition reste celle de ton script de mort.</div>'}
            </div>`;
    };

    const settings = (patch) => {
        const r = D.respawn;
        send('respawn_settings', { enabled: r.enabled, mode: r.mode, fixed: r.fixed, effects: r.effects, ...patch });
    };

    document.addEventListener('change', (e) => {
        if (!isOpen || tab !== 'respawn') return;
        if (e.target.id === 'rs-fixed') return settings({ fixed: Number(e.target.value) });
        const row = e.target.closest('[data-rsid]');
        if (row && e.target.dataset.rsfield === 'type') send('respawn_update', { id: Number(row.dataset.rsid), type: e.target.value });
    });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'respawn') return;
        let n;
        if ((n = e.target.closest('[data-rst]'))) { const k = n.dataset.rst; return settings({ [k]: !D.respawn[k] }); }
        if ((n = e.target.closest('[data-rsmode]'))) return settings({ mode: n.dataset.rsmode });
        if ((n = e.target.closest('[data-rstype]'))) { RS.type = n.dataset.rstype; return render(); }
        if (!(n = e.target.closest('[data-rsa]'))) return;
        const row = n.closest('[data-rsid]');
        const id = row ? Number(row.dataset.rsid) : null;
        switch (n.dataset.rsa) {
            case 'add': send('respawn_add', { label: draft('rsLabel', ''), type: RS.type }); drafts.rsLabel = ''; return;
            case 'dz': { const p = D.respawn.points.find((x) => x.id === id); return send('respawn_update', { id, dz: Math.round(((p.dz || 0) + Number(n.dataset.v)) * 100) / 100, quiet: true }); }
            case 'dh': return send('respawn_update', { id, dh: Number(n.dataset.v), quiet: true });
            case 'test': post('close'); return send('respawn_test', { id });
            case 'here':
                if (await confirmBox('Déplacer le point ici ?', 'Il prend ta position et ton orientation.')) send('respawn_update', { id, here: true });
                return;
            case 'del':
                if (await confirmBox('Supprimer ce point ?', '')) send('respawn_delete', { id });
        }
    });
})();
