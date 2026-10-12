/* =========================================================
   GARDES DU CORPS (permission « guards » : SuperAdmin et Fondateur)
   Onglet « Mes outils › Gardes du corps » : faire apparaître 1 à 30 PNJ.
   Touche F11 : panneau des ordres (le client exécute, le serveur autorise).
   ========================================================= */
(() => {
    // Section affichée dans la page « Mes outils » (SuperAdmin et Fondateur)
    window.guardsSection = () => (has('guards') && D && D.guards && (D.me.level || 0) >= 40 ? VIEWS.guards() : '');

    const G = { count: 4, model: '', weapon: 'WEAPON_CARBINERIFLE', armor: true, invincible: false, holster: false };
    const send = (name, data = {}) => action('guards', { name, data });

    VIEWS.guards = () => {
        const d = D.guards;
        if (!G.model) G.model = (d.models[0] || {}).id || '';
        const free = d.max - d.count;
        return `
            <div class="section"><h2>🛡️ Gardes du corps</h2></div>
            <div class="stats">
                <div class="stat"><b>${d.count} / ${d.max}</b><span>Gardes à tes côtés</span></div>
                <div class="stat"><b><span class="keycap">F11</span></b><span>Ordres (touche modifiable : Échap › Paramètres › Raccourcis › FiveM)</span></div>
            </div>
            <div class="section"><h2>Faire apparaître des gardes</h2>
                <p class="hint">Ils apparaissent autour de toi et te suivent. Ils ripostent si on t'attaque. Ils disparaissent à ta déconnexion.</p>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1100px">
                    <div class="field"><label>Nombre (1 à ${free > 0 ? free : 0})</label><input class="input" type="number" min="1" max="${Math.max(1, free)}" data-gdf="count" value="${G.count}"></div>
                    <div class="field"><label>Tenue</label><select class="input" data-gdf="model"><option value="__me__" ${G.model === '__me__' ? 'selected' : ''}>👔 Ma tenue (identique à moi)</option>${d.models.map((m) => `<option value="${esc(m.id)}" ${G.model === m.id ? 'selected' : ''}>${esc(m.label)}</option>`).join('')}</select></div>
                    <div class="field"><label>Arme</label><select class="input" data-gdf="weapon">${d.weapons.map((w) => `<option value="${esc(w.id)}" ${G.weapon === w.id ? 'selected' : ''}>${esc(w.label)}</option>`).join('')}</select></div>
                    <div class="field"><label>&nbsp;</label><button class="btn primary" data-gda="spawn" ${free > 0 ? '' : 'disabled'}>Faire apparaître</button></div>
                </div>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin:12px 0">
                    <div class="tile toggle-tile ${G.armor ? 'on' : ''}" data-gdb="armor"><div><strong>Gilet pare-balles</strong><span>100 d'armure chacun.</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${G.invincible ? 'on' : ''}" data-gdb="invincible"><div><strong>Invincibles</strong><span>Ils ne peuvent pas mourir.</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${G.holster ? 'on' : ''}" data-gdb="holster"><div><strong>Armes rangées</strong><span>Sinon : arme en main. Modifiable avec F11.</span></div><div class="switch"></div></div>
                </div>
                <div class="btn-row"><button class="btn danger" data-gda="clear" ${d.count ? '' : 'disabled'}>Supprimer tous mes gardes</button></div>
            </div>
            <div class="section"><h2>Ordres (F11)</h2>
                <p class="hint">Choisis combien de gardes reçoivent l'ordre (les plus proches de toi). Pour « Prenez un véhicule », « Braquer », « Tirer », « Menotter » : le menu se ferme et une <b>flèche</b> apparaît au-dessus de ce que tu regardes ;
                    <span class="keycap">E</span> ou clic gauche pour choisir, clic droit pour annuler. Joueur ou PNJ. Les gardes déjà dans un véhicule ne bougent pas quand tu ordonnes de monter dans un véhicule.</p>
                <ul class="hint" style="line-height:1.7;margin-left:18px">
                    <li><b>À pied</b> : suivez-moi, restez ici, revenez, protéger la zone 10 à 50 m (surveillance sans tirer), mode défense (tir si quelqu'un approche), supprimer.</li>
                    <li><b>Véhicules</b> : montez dans mon véhicule, prenez le véhicule visé (le 1er au volant), allez à mon point GPS, suivez en convoi, descendez ; conduite normale ou grande vitesse (feux grillés, dépassements).</li>
                    <li><b>Cible</b> (choisie à la flèche) : braquer sans tirer, tirer, menotter, démenotter (joueur ou PNJ).</li>
                    <li><b>Équipement</b> : même tenue que moi (à l'identique), armes en main ou rangées.</li>
                </ul>
            </div>`;
    };

    document.addEventListener('input', (e) => { if (e.target.dataset && e.target.dataset.gdf === 'count') G.count = Number(e.target.value); });
    document.addEventListener('change', (e) => { const k = e.target.dataset && e.target.dataset.gdf; if (k && k !== 'count') G[k] = e.target.value; });
    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'self') return;
        let n;
        if ((n = e.target.closest('[data-gdb]'))) { G[n.dataset.gdb] = !G[n.dataset.gdb]; return render(); }
        if (!(n = e.target.closest('[data-gda]')) || n.disabled) return;
        if (n.dataset.gda === 'spawn') return send('spawn', { count: G.count, model: G.model, weapon: G.weapon, armor: G.armor, invincible: G.invincible, holster: G.holster });
        if (n.dataset.gda === 'clear' && await confirmBox('Supprimer tes gardes ?', 'Tous tes gardes du corps vont disparaître.')) send('clear');
    });

    /* ---------- Panneau F11 ---------- */
    const box = document.createElement('div');
    box.id = 'guards-menu';
    box.className = 'gm hidden';
    document.body.appendChild(box);
    const S = { count: 0, data: null };

    const btn = (order, label, opt, extra = '') => `<button class="gm-btn ${extra}" data-go="${order}" ${opt !== undefined ? `data-opt="${esc(opt)}"` : ''}>${label}</button>`;
    function draw() {
        const d = S.data || {};
        const counts = [0, 1, 2, 4, 6, 8, 10];
        box.innerHTML = `<div class="gm-panel">
            <div class="gm-head"><div><strong>Gardes du corps</strong><span>${d.alive || 0} / ${d.max || 30} · ${d.inVehicle || 0} en véhicule · ${d.drivers || 0} au volant</span></div>
                <button class="gm-x" data-gx="1" title="Fermer (Échap)">✕</button></div>
            <div class="gm-body">
                <div class="gm-sec"><h3>Gardes concernés (les plus proches)</h3><div class="gm-row">
                    ${counts.map((c) => `<button class="gm-chip ${S.count === c ? 'on' : ''}" data-gc="${c}">${c === 0 ? 'Tous' : c}</button>`).join('')}
                    <input class="gm-num" type="number" min="1" max="30" placeholder="N" data-gcn value="${counts.includes(S.count) ? '' : S.count}"></div></div>
                <div class="gm-cible"><span>🎯 Cible et véhicule : choisis-les <b>après</b> le clic, avec la flèche (E / clic gauche · clic droit pour annuler).</span></div>
                <div class="gm-sec"><h3>À pied</h3><div class="gm-grid">
                    ${btn('follow', '🚶 Suivez-moi')}${btn('stay', '✋ Restez ici')}${btn('come', '↩️ Revenez')}${btn('exitveh', '🚪 Descendez')}
                </div><div class="gm-row" style="margin-top:6px"><span class="gm-lbl">🛡️ Protéger la zone :</span>${[10, 20, 30, 40, 50].map((r) => btn('zone', `${r} m`, r, 'sm')).join('')}</div>
                <div class="gm-row" style="margin-top:6px"><span class="gm-lbl">⚔️ Mode défense :</span>${[5, 8, 12, 20].map((r) => btn('defense', `${r} m`, r, `sm ${d.defense === r ? 'on' : ''}`)).join('')}${btn('defense', 'Couper', 'off', `sm ${d.defense ? '' : 'on'}`)}</div></div>
                <div class="gm-sec"><h3>Cible</h3><div class="gm-grid">
                    ${btn('aim', '🔫 Braquer (sans tirer)')}${btn('attack', '💥 Tirer sur…', undefined, 'danger')}${btn('cuff', '⛓️ Menotter', 'on')}${btn('cuff', '🔓 Démenotter', 'off')}
                </div></div>
                <div class="gm-sec"><h3>Équipement</h3><div class="gm-grid">
                    ${btn('outfit', '👔 Même tenue que moi')}${btn('weapons', `🔫 Armes en main`, 'draw', d.holstered ? '' : 'on')}
                    ${btn('weapons', `🫳 Ranger les armes${d.holstered ? ` (${d.holstered})` : ''}`, 'holster', d.holstered ? 'on' : '')}
                </div></div>
                <div class="gm-sec"><h3>Véhicules</h3><div class="gm-grid">
                    ${btn('myveh', '🚘 Montez dans mon véhicule')}${btn('takeveh', '🔑 Prenez un véhicule (flèche)')}
                    ${btn('gps', `📍 Allez à mon point GPS${d.waypoint ? '' : ' (aucun)'}`)}${btn('convoy', '🚓 Suivez en convoi')}
                </div><div class="gm-row" style="margin-top:6px"><span class="gm-lbl">Conduite :</span>${btn('drivemode', 'Normale', 'normal', `sm ${d.drive !== 'fast' ? 'on' : ''}`)}${btn('drivemode', 'Grande vitesse', 'fast', `sm ${d.drive === 'fast' ? 'on' : ''}`)}</div></div>
                <div class="gm-sec"><div class="gm-row">${btn('delete', '🗑️ Supprimer ces gardes', undefined, 'danger')}</div></div>
                <p class="gm-tip">Ordre « Tous » ou les N gardes les plus proches. Pour monter dans un véhicule, seuls les gardes à pied sont pris.</p>
            </div></div>`;
    }
    function close() { box.classList.add('hidden'); post('guardsClose'); }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'guardsMenu') return;
        if (!m.show) { box.classList.add('hidden'); return; }
        S.data = m.data;
        draw();
        box.classList.remove('hidden');
    });
    box.addEventListener('click', async (e) => {
        let n;
        if (e.target === box || e.target.closest('[data-gx]')) return close();
        if ((n = e.target.closest('[data-gc]'))) { S.count = Number(n.dataset.gc); return draw(); }
        if ((n = e.target.closest('[data-go]'))) {
            // Suppression : deuxième clic pour confirmer (le menu staff n'est pas ouvert ici)
            if (n.dataset.go === 'delete' && !n.dataset.armed) { n.dataset.armed = '1'; n.textContent = S.count ? `Confirmer : supprimer ${S.count} garde(s)` : 'Confirmer : supprimer tous les gardes'; return; }
            n.classList.add('busy');
            const r = await post('guardsOrder', { order: n.dataset.go, opt: n.dataset.opt, count: S.count });
            n.classList.remove('busy');
            if (r && r.closed) { box.classList.add('hidden'); return; }
            if (r && r.data) { S.data = r.data; draw(); }
        }
    });
    box.addEventListener('input', (e) => { if (e.target.dataset.gcn !== undefined) S.count = Math.max(0, Math.min(30, Number(e.target.value) || 0)); });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !box.classList.contains('hidden')) close(); });
})();
