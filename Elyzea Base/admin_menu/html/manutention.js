/* =========================================================
   GESTION DU MÉTIER MANUTENTIONNAIRE (ressource elyzea_manutention, permission « manut_manage »)
   Sous-catégories : configuration générale · PNJ · points de récupération · palettes · Fenwick ·
   livraisons · rémunérations · tenue · sauvegardes · joueurs au travail.
   « Enregistrer ma position actuelle » : la position et l'orientation sont lues par le serveur sur ton personnage.
   Tout est enregistré en base (table manut_settings) et gardé après un redémarrage.
   ========================================================= */
(() => {
    TABS.push({
        id: 'manut', group: 5, label: 'Manutentionnaire', ico: '📦',
        sub: 'Gestion du métier manutentionnaire (intérim) : emplacements, Fenwick, rémunérations, cartons par palette, course avec un carton, tenue, sauvegardes.',
        show: () => has('manut_manage') && !!(D && D.manut),
        count: () => ((D && D.manut && D.manut.workers) || []).length,
    });

    const SECTIONS = [
        ['general', '⚙️ Configuration générale'], ['npc', '🧑‍🔧 PNJ'], ['pickups', '📦 Points de récupération'], ['pallets', '🟫 Palettes'],
        ['spawns', '🚜 Fenwick'], ['deliveries', '🏁 Livraisons'], ['pay', '💰 Rémunérations'], ['outfit', '🦺 Tenue'],
        ['saves', '💾 Sauvegardes'], ['workers', '👷 Au travail'],
    ];
    const KIND = {
        pickups: { one: 'point de récupération', title: 'Points de récupération des cartons', ph: 'ex : Rayonnage A',
            help: 'Les joueurs y prennent un carton (touche E). Ajoute-en autant que tu veux, partout dans l\'entrepôt.' },
        pallets: { one: 'emplacement de palette', title: 'Emplacements des palettes', ph: 'ex : Quai 1',
            help: 'Chaque joueur reçoit une palette vide sur un de ces emplacements (un emplacement libre en priorité). Ton orientation = l\'orientation de la palette.' },
        spawns: { one: 'point de spawn', title: 'Points de spawn des Fenwick', ph: 'ex : Garage Fenwick 1',
            help: 'Le Fenwick du joueur apparaît sur un point libre, dans ton orientation. Un point est occupé tant qu\'un véhicule s\'y trouve : deux Fenwick n\'apparaissent jamais au même endroit.' },
        deliveries: { one: 'zone de livraison', title: 'Zones de livraison', ph: 'ex : Quai d\'expédition',
            help: 'La palette doit être posée dans le rayon de la zone. Le serveur vérifie la position de la palette elle-même avant de payer.' },
    };
    const st = { sec: 'general', show: false, armed: null };
    const fmt = (n) => Number(n || 0).toLocaleString('fr-FR');
    const pos = (p) => p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}` : '—';
    const send = (name, data = {}, refresh = true) => { action('manut', { name, data }); if (refresh) setTimeout(() => post('refresh'), 450); };
    const tog = (id, on, title, sub) => `<div class="tile toggle-tile ${on ? 'on' : ''}" data-mtog="${id}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;

    function pointsView(kind, S, L) {
        const k = KIND[kind];
        const list = S[kind] || [];
        return `<div class="section"><h2>${k.title}</h2><p class="hint">${k.help}</p>
            <div class="inline" style="max-width:760px;gap:8px;flex-wrap:wrap">
                <input class="input" data-mnew="${kind}" placeholder="Nom (facultatif) : ${esc(k.ph)}" maxlength="40" style="flex:1;min-width:200px">
                ${kind === 'deliveries' ? `<input class="input" type="number" data-mnewr min="1.5" max="25" step="0.5" value="${L.deliveryRadius}" title="Rayon de validation (m)" style="width:110px">` : ''}
                <button class="btn primary" data-madd="${kind}">📍 Enregistrer ma position actuelle</button>
            </div>
            ${list.length ? `<table style="margin-top:12px"><tr><th>#</th><th>Nom</th><th>Orientation</th>${kind === 'deliveries' ? '<th>Rayon (m)</th>' : ''}<th>Position</th>${kind === 'spawns' ? '<th>État</th>' : ''}<th></th></tr>
                ${list.map((p, i) => `<tr data-mrow="${kind}" data-i="${i + 1}"><td><b>${i + 1}</b></td>
                    <td><input class="input" data-mf="label" value="${esc(p.label || '')}" maxlength="40" placeholder="${esc(k.one)} ${i + 1}"></td>
                    <td><input class="input" type="number" data-mf="h" value="${Math.round(p.h || 0)}" min="0" max="359" style="width:80px"></td>
                    ${kind === 'deliveries' ? `<td><input class="input" type="number" data-mf="radius" value="${p.radius}" min="1.5" max="25" step="0.5" style="width:80px"></td>` : ''}
                    <td class="muted" style="font-size:12px">${pos(p)}</td>
                    ${kind === 'spawns' ? `<td><span class="badge" style="color:${p.state === 'libre' ? 'var(--ok)' : 'var(--warn, #e0a33b)'}">${esc(p.state || '?')}</span></td>` : ''}
                    <td style="text-align:right;white-space:nowrap">
                        <button class="btn" data-mpt="save" title="Enregistrer le nom / l'orientation / le rayon">💾</button>
                        <button class="btn" data-mpt="move" title="Déplacer à ma position actuelle">📍</button>
                        <button class="btn" data-mpt="tp" title="Y aller">🧭</button>
                        <button class="btn danger" data-mpt="del" title="Supprimer">${st.armed === `${kind}:${i + 1}` ? '⚠️ Confirmer' : '🗑️'}</button></td></tr>`).join('')}</table>`
                : `<div class="empty" style="margin-top:10px">Aucun ${k.one}. Va sur place et clique « Enregistrer ma position actuelle ».</div>`}
        </div>`;
    }

    function view() {
        const d = D.manut;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_manutention')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_manutention » dans server.cfg'}.</span></div>`;
        const S = d.settings, L = d.limits, P = S.pay, F = S.forklift;
        const missing = [];
        if (!S.npc.placed) missing.push('le PNJ');
        if (!S.pickups.length) missing.push('un point de récupération');
        if (!S.pallets.length) missing.push('un emplacement de palette');
        if (F.enabled && !S.spawns.length) missing.push('un spawn de Fenwick');
        if (!S.deliveries.length) missing.push('une zone de livraison');
        const head = `
            <div class="stats">
                <div class="stat"><b>${S.enabled ? '🟢' : '🔴'}</b><span>${S.enabled ? 'Métier ouvert' : 'Métier fermé'}</span></div>
                <div class="stat"><b>${fmt(P.delivery)} $</b><span>Par palette livrée</span></div>
                <div class="stat"><b>${S.boxesPerPallet}</b><span>Cartons / palette</span></div>
                <div class="stat"><b>${d.workers.length}</b><span>Au travail</span></div>
            </div>
            ${missing.length ? `<div class="protect" style="margin:10px 0">⚠️ <span>Pour que le métier fonctionne, place encore : <b>${missing.join(', ')}</b>.</span></div>` : ''}
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin:10px 0">
                ${tog('show', st.show, '👁️ Voir les emplacements en jeu', 'Marqueurs, numéros et orientations de tous les points (seulement chez toi)')}
            </div>
            <div class="btn-row" style="margin:6px 0 14px">${SECTIONS.map(([id, l]) => `<button class="btn ${st.sec === id ? 'primary' : ''}" data-msec="${id}">${l}</button>`).join('')}</div>`;
        let body = '';
        if (st.sec === 'general') {
            body = `<div class="section"><h2>Configuration générale</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                    ${tog('enabled', S.enabled, 'Métier activé', S.enabled ? 'Les joueurs peuvent accepter le travail au PNJ' : 'Fermé : le PNJ refuse les nouvelles missions')}
                    ${tog('allowSprint', S.allowSprint, 'Autoriser la course avec un carton', S.allowSprint ? 'Activé : on peut courir carton en main' : 'Désactivé : on marche avec le carton (course bloquée jusqu\'au dépôt)')}
                </div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));align-items:end">
                    <div><label>Cartons par palette (1 à ${L.maxBoxes})</label><input class="input" type="number" data-mg="boxesPerPallet" min="1" max="${L.maxBoxes}" value="${S.boxesPerPallet}"></div>
                    <div><label>Paiement versé</label><select class="input" data-mg="account"><option value="bank" ${S.account === 'bank' ? 'selected' : ''}>Sur le compte en banque</option><option value="cash" ${S.account === 'cash' ? 'selected' : ''}>En liquide</option></select></div>
                </div>
                <p class="hint">Une palette ne peut être chargée et livrée que si elle contient <b>exactement</b> ce nombre de cartons (par défaut ${d.defaults.boxesPerPallet}). Le changement s'applique aux nouvelles palettes.</p>
                <div class="btn-row"><button class="btn primary" data-msave="general">💾 Enregistrer</button></div></div>
                <div class="section"><h2>Modèles utilisés</h2>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));align-items:end">
                    <div><label>Fenwick</label><input class="input" data-mm="forklift" value="${esc(S.models.forklift)}"></div>
                    <div><label>Carton porté dans les bras</label><input class="input" data-mm="box" value="${esc(S.models.box)}"></div>
                    <div><label>Cartons empilés sur la palette</label><input class="input" data-mm="boxOnPallet" value="${esc(S.models.boxOnPallet)}"></div>
                    <div><label>Palette</label><input class="input" data-mm="pallet" value="${esc(S.models.pallet)}"></div>
                    <div><label>PNJ</label><input class="input" data-mm="npc" value="${esc(S.models.npc)}"></div>
                </div>
                <p class="hint">Noms de modèles GTA (ex : forklift, prop_pallet_02a, hei_prop_heist_box). Un modèle introuvable chez un joueur est remplacé par celui d'origine.</p>
                <div class="btn-row"><button class="btn primary" data-msave="models">💾 Enregistrer les modèles</button></div></div>`;
        } else if (st.sec === 'npc') {
            body = `<div class="section"><h2>PNJ manutentionnaire</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                    ${tog('npcEnabled', S.npc.enabled, 'PNJ affiché', S.npc.enabled ? 'Le PNJ est présent (point de départ et de fin du travail)' : 'PNJ désactivé : personne ne peut commencer')}
                </div>
                <p class="hint">Position : <b>${S.npc.placed ? pos(S.npc) + ` · orientation ${Math.round(S.npc.h)}°` : 'pas encore placé'}</b></p>
                <div class="btn-row" style="margin-bottom:12px">
                    <button class="btn primary" data-mact="npcHere">📍 Enregistrer ma position actuelle (et mon orientation)</button>
                    ${S.npc.placed ? '<button class="btn" data-mact="tpNpc">🧭 Y aller</button>' : ''}
                </div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));align-items:end">
                    <div><label>Modèle du PNJ</label><input class="input" data-mn="model" value="${esc(S.models.npc)}"></div>
                    <div><label>Orientation (0 à 359°)</label><input class="input" type="number" data-mn="h" min="0" max="359" value="${Math.round(S.npc.h || 0)}" ${S.npc.placed ? '' : 'disabled'}></div>
                    <div><label>Animation (scénario GTA, vide = aucune)</label><input class="input" data-mn="scenario" value="${esc(S.npc.scenario || '')}" placeholder="WORLD_HUMAN_CLIPBOARD"></div>
                </div>
                <div class="btn-row"><button class="btn primary" data-msave="npc">💾 Enregistrer</button></div></div>`;
        } else if (st.sec === 'spawns') {
            body = `<div class="section"><h2>Réglages des Fenwick</h2>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin-bottom:12px">
                    ${tog('fkEnabled', F.enabled, 'Système de Fenwick activé', F.enabled ? 'Un Fenwick est donné à chaque joueur qui accepte' : 'Désactivé : aucune palette ne peut être livrée')}
                </div>
                <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(220px,1fr));align-items:end">
                    <div><label>Fenwick simultanés maximum (0 = autant que de points)</label><input class="input" type="number" data-mf2="max" min="0" max="64" value="${F.max}"></div>
                    <div><label>Retrait automatique après N minutes sans activité (0 = jamais)</label><input class="input" type="number" data-mf2="idleMinutes" min="0" max="240" value="${F.idleMinutes}"></div>
                    <div><label>Modèle du Fenwick</label><input class="input" data-mf2="model" value="${esc(S.models.forklift)}"></div>
                </div>
                <p class="hint">Points libres : <b>${S.spawns.filter((p) => p.state === 'libre').length}</b> / ${S.spawns.length}. Le Fenwick apparaît seulement quand le joueur accepte le travail et disparaît quand il termine, se déconnecte ou reste inactif.</p>
                <div class="btn-row"><button class="btn primary" data-msave="forklift">💾 Enregistrer</button></div></div>
                ${pointsView('spawns', S, L)}`;
        } else if (KIND[st.sec]) {
            body = pointsView(st.sec, S, L);
        } else if (st.sec === 'pay') {
            const row = (k, on, label, sub) => `<div class="tile toggle-tile ${P[on] ? 'on' : ''}" data-mpayt="${on}"><div><strong>${label}</strong><span>${sub}</span></div><div class="switch"></div></div>
                <div><label>${label} ($)</label><input class="input" type="number" data-mp="${k}" min="0" max="${L.maxPay}" value="${P[k]}" ${P[on] ? '' : 'disabled'}></div>`;
            body = `<div class="section"><h2>Rémunération par palette livrée</h2>
                <div class="form-grid" style="grid-template-columns:minmax(220px,320px) auto;align-items:end;max-width:640px">
                    <div><label>Montant payé quand une palette complète est déposée au bon endroit ($)</label><input class="input" type="number" data-mp="delivery" min="0" max="${L.maxPay}" value="${P.delivery}"></div>
                    <div class="btn-row">${[100, 250, 500, 750, 1000].map((v) => `<button class="btn" data-mquick="${v}">${v} $</button>`).join('')}</div>
                </div>
                <p class="hint">Par défaut, le joueur est payé <b>uniquement</b> à la livraison de la palette complète. Le serveur calcule et verse le paiement : un joueur ne peut ni le modifier ni le déclencher.</p></div>
                <div class="section"><h2>Paiements intermédiaires (facultatifs)</h2>
                <div class="form-grid" style="grid-template-columns:minmax(260px,1fr) minmax(200px,260px);align-items:center;max-width:760px">
                    ${row('perBox', 'perBoxOn', 'Par carton déposé', 'Versé à chaque carton posé sur la palette')}
                    ${row('palletDone', 'palletDoneOn', 'Palette complète', 'Versé quand la palette atteint le nombre de cartons')}
                    ${row('transport', 'transportOn', 'Transport', 'Versé quand la palette est chargée sur le Fenwick')}
                </div>
                <div class="btn-row"><button class="btn primary" data-msave="pay">💾 Enregistrer les rémunérations</button></div></div>`;
        } else if (st.sec === 'outfit') {
            const n = (g) => Object.keys((S.outfit[g] || {}).c || {}).length;
            body = `<div class="section"><h2>Tenue de manutentionnaire</h2>
                <p class="hint">Quand un joueur accepte, sa tenue actuelle est sauvegardée puis remplacée par celle-ci ; elle lui est rendue à l'identique quand il termine (même après un crash).
                    Pour la changer : habille ton personnage (boutique de vêtements, ou menu staff), puis clique « Copier ma tenue actuelle ».</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(280px,1fr))">
                    ${['male', 'female'].map((g) => `<div class="card"><b>${g === 'male' ? '👨 Homme' : '👩 Femme'}</b><p class="hint">${n(g)} vêtement(s) enregistré(s)</p>
                        <div class="btn-row"><button class="btn primary" data-moutfit="${g}">👕 Copier ma tenue actuelle</button><button class="btn" data-moreset="${g}">↺ Tenue d'origine</button></div></div>`).join('')}
                </div></div>`;
        } else if (st.sec === 'saves') {
            body = `<div class="section"><h2>Sauvegardes</h2>
                <p class="hint">Chaque modification est déjà enregistrée en base de données (table <b>manut_settings</b>) et conservée après un redémarrage.</p>
                <div class="btn-row">
                    <button class="btn primary" data-mact="save">💾 Sauvegarder les paramètres</button>
                    <button class="btn" data-mact="reload">🔄 Charger les paramètres enregistrés</button>
                    <button class="btn danger" data-mact="resetKeep">${st.armed === 'resetKeep' ? '⚠️ Confirmer' : '↺ Réglages par défaut (garder les emplacements)'}</button>
                    <button class="btn danger" data-mact="resetAll">${st.armed === 'resetAll' ? '⚠️ Confirmer : TOUT effacer' : '🗑️ Tout remettre à zéro'}</button>
                </div></div>`;
        } else if (st.sec === 'workers') {
            const STAGE = { collect: '📦 Cartons', ready: '🟫 Palette complète', carry: '🚜 Transport' };
            body = `<div class="section"><h2>Joueurs au travail</h2>
                ${d.workers.length ? `<table><tr><th>Joueur</th><th>Étape</th><th>Cartons</th><th>Livrées</th><th>Gagné</th><th>Fenwick</th><th></th></tr>
                    ${d.workers.map((w) => `<tr><td><b>${esc(w.name)}</b> <small class="muted">#${w.id}</small></td><td>${STAGE[w.stage] || esc(w.stage)}</td>
                        <td>${w.boxes}/${w.required}</td><td>${w.delivered}</td><td>${fmt(w.earned)} $</td><td>${w.forklift ? esc(w.plate || 'oui') : '—'}</td>
                        <td style="text-align:right"><button class="btn danger" data-mstop="${w.id}">${st.armed === `stop:${w.id}` ? '⚠️ Confirmer' : '⛔ Arrêter'}</button></td></tr>`).join('')}</table>`
                : '<div class="empty">Personne ne travaille en ce moment.</div>'}</div>`;
        }
        return head + body;
    }
    VIEWS.manut = view;

    const arm = (key) => {
        if (st.armed === key) { st.armed = null; return true; }
        st.armed = key; render();
        setTimeout(() => { if (st.armed === key) { st.armed = null; render(); } }, 4000);
        return false;
    };
    const val = (sel) => { const e = document.querySelector(sel); return e ? e.value : undefined; };

    document.addEventListener('click', (ev) => {
        if (!isOpen || tab !== 'manut' || !D.manut || !D.manut.available) return;
        const S = D.manut.settings;
        const t = ev.target.closest('[data-msec],[data-mtog],[data-msave],[data-madd],[data-mpt],[data-mact],[data-mquick],[data-mpayt],[data-moutfit],[data-moreset],[data-mstop]');
        if (!t) return;
        if (t.dataset.msec) { st.sec = t.dataset.msec; st.armed = null; render(); return; }
        if (t.dataset.mtog) {
            const k = t.dataset.mtog;
            if (k === 'show') { st.show = !st.show; send('show', { on: st.show }, false); render(); return; }
            if (k === 'enabled') return send('general', { enabled: !S.enabled });
            if (k === 'allowSprint') return send('general', { allowSprint: !S.allowSprint });
            if (k === 'npcEnabled') return send('npc', { enabled: !S.npc.enabled });
            if (k === 'fkEnabled') return send('forklift', { enabled: !S.forklift.enabled });
        }
        if (t.dataset.mpayt) { const k = t.dataset.mpayt; return send('pay', { [k]: !S.pay[k] }); }
        if (t.dataset.mquick) { const i = document.querySelector('[data-mp="delivery"]'); if (i) i.value = t.dataset.mquick; return; }
        if (t.dataset.msave) {
            const w = t.dataset.msave;
            if (w === 'general') return send('general', { boxesPerPallet: Number(val('[data-mg="boxesPerPallet"]')), account: val('[data-mg="account"]') });
            if (w === 'models') {
                const m = {}; document.querySelectorAll('[data-mm]').forEach((e) => { m[e.dataset.mm] = e.value.trim(); });
                return send('models', m);
            }
            if (w === 'npc') return send('npc', { model: val('[data-mn="model"]'), h: S.npc.placed ? Number(val('[data-mn="h"]')) : undefined, scenario: val('[data-mn="scenario"]') });
            if (w === 'forklift') {
                send('forklift', { max: Number(val('[data-mf2="max"]')), idleMinutes: Number(val('[data-mf2="idleMinutes"]')) }, false);
                return send('models', { forklift: val('[data-mf2="model"]') });
            }
            if (w === 'pay') {
                const p = {}; document.querySelectorAll('[data-mp]').forEach((e) => { if (!e.disabled) p[e.dataset.mp] = Number(e.value); });
                return send('pay', p);
            }
        }
        if (t.dataset.madd) {
            const kind = t.dataset.madd;
            return send('pointAdd', { kind, label: val(`[data-mnew="${kind}"]`), radius: kind === 'deliveries' ? Number(val('[data-mnewr]')) : undefined });
        }
        if (t.dataset.mpt) {
            const row = t.closest('[data-mrow]');
            const kind = row.dataset.mrow, i = Number(row.dataset.i);
            const a = t.dataset.mpt;
            if (a === 'save') {
                const f = (k) => { const e = row.querySelector(`[data-mf="${k}"]`); return e ? e.value : undefined; };
                return send('pointEdit', { kind, i, label: f('label'), h: Number(f('h')), radius: f('radius') !== undefined ? Number(f('radius')) : undefined });
            }
            if (a === 'move') return send('pointMove', { kind, i });
            if (a === 'tp') { send('teleport', { kind, i }, false); post('close'); return; }
            if (a === 'del' && arm(`${kind}:${i}`)) return send('pointDel', { kind, i });
            return;
        }
        if (t.dataset.mact) {
            const a = t.dataset.mact;
            if (a === 'npcHere') return send('npcHere');
            if (a === 'tpNpc') { send('teleport', { kind: 'npc' }, false); post('close'); return; }
            if (a === 'save' || a === 'reload') return send(a);
            if ((a === 'resetKeep' || a === 'resetAll') && arm(a)) return send('reset', { confirm: true, keepPoints: a === 'resetKeep' });
            return;
        }
        if (t.dataset.moutfit) return send('outfitAsk', { gender: t.dataset.moutfit });
        if (t.dataset.moreset) return send('outfitReset', { gender: t.dataset.moreset });
        if (t.dataset.mstop && arm(`stop:${t.dataset.mstop}`)) return send('stopWorker', { id: Number(t.dataset.mstop) });
    });
})();
