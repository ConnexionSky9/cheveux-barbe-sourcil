/* =========================================================
   LABORATOIRES (ressource elyzea_labs, permission « labs_manage »)
   Laboratoires (créer à ta position, nom, intérieur, prix, propriétaire, niveau, XP, TP, entrer, supprimer) ·
   Attaques (activation, créneaux et jours, durée, zone, conditions de victoire, en cours, historique) ·
   Intérieurs (points corrigés en jeu, test) · Niveaux · Journal. Tout est revérifié par elyzea_labs.
   ========================================================= */
(() => {
    TABS.push({
        id: 'labs', group: 6, label: 'Laboratoires', ico: '🧪',
        sub: 'Laboratoires des groupes : création, propriétaires, niveaux, intérieurs, horaires et réglages des attaques, captures.',
        show: () => has('labs_manage') && !!(D && D.labs),
    });
    const G = { sub: 'labs', raid: null, edit: {}, create: { name: '', interior: '', price: '' } };
    const send = (name, data = {}) => action('labs', { name, data });
    const later = (ms = 700) => setTimeout(() => post('refresh'), ms);
    const clone = (x) => JSON.parse(JSON.stringify(x));
    const money = (n) => `${Math.floor(Number(n) || 0).toLocaleString('fr-FR')} $`;
    const date = (t) => (t ? new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—');
    const mmss = (s) => `${String(Math.floor(Math.max(0, s) / 60)).padStart(2, '0')}:${String(Math.max(0, s) % 60).padStart(2, '0')}`;
    const DAYS = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const STATUS = { preparing: 'Préparation', active: 'En cours', success: 'Capturé', failed: 'Défendu', cancelled: 'Annulée' };
    const SUBS = [['labs', '🧪 Laboratoires'], ['raids', '⚔️ Attaques'], ['interiors', '🏭 Intérieurs'], ['levels', '⬆️ Niveaux'], ['logs', '📜 Journal']];

    function viewLabs(d) {
        const ints = d.interiors;
        const c = G.create;
        const groups = d.groups || [];
        const rows = d.labs.map((l) => {
            const e = G.edit[l.id] || (G.edit[l.id] = { name: l.name, interior: l.interior, price: l.price, disabled: l.disabled, group: l.owner || 0, level: l.level, xp: l.xp });
            return `<tr><td>#${l.id}</td>
                <td><input class="input" data-le="${l.id}|name" value="${esc(e.name)}"><div class="hint" style="margin:3px 0 0">${l.present} présent(s) · ${l.placed}/${l.equipment} équipement(s) posé(s)${l.raid ? ` · ⚔️ ${STATUS[l.raid] || l.raid}` : ''}</div></td>
                <td><select class="input" data-le="${l.id}|interior">${ints.map((i) => `<option value="${esc(i.code)}" ${i.code === e.interior ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></td>
                <td><input class="input" type="number" min="0" data-le="${l.id}|price" value="${esc(e.price)}" style="width:110px"></td>
                <td><label class="hint" style="display:flex;gap:6px;align-items:center;margin:0"><input type="checkbox" data-le="${l.id}|disabled" ${e.disabled ? 'checked' : ''}> fermé</label></td>
                <td style="white-space:nowrap"><button class="btn primary" data-la="update" data-id="${l.id}" title="Enregistrer">💾</button> <button class="btn" data-la="tp" data-id="${l.id}" title="Aller à l'entrée">🚀</button>
                    <button class="btn" data-la="enter" data-id="${l.id}" title="Entrer (staff)">🚪</button> <button class="btn" data-la="move" data-id="${l.id}" title="Déplacer l'entrée à ta position">📍</button>
                    <button class="sb-close" data-la="delete" data-id="${l.id}" title="Supprimer">✕</button></td></tr>
                <tr><td></td><td colspan="5"><div class="form-grid" style="grid-template-columns:1.4fr auto 100px 120px auto;align-items:end;gap:8px">
                    <div><label>Propriétaire (actuel : ${esc(l.ownerLabel || 'aucun')})</label><select class="input" data-le="${l.id}|group"><option value="0">Aucun</option>${groups.map((g) => `<option value="${g.id}" ${Number(e.group) === g.id ? 'selected' : ''}>${esc(g.label)}</option>`).join('')}</select></div>
                    <button class="btn" data-la="setOwner" data-id="${l.id}">Changer le propriétaire</button>
                    <div><label>Niveau</label><input class="input" type="number" min="1" max="${d.levels.length}" data-le="${l.id}|level" value="${esc(e.level)}"></div>
                    <div><label>XP</label><input class="input" type="number" min="0" data-le="${l.id}|xp" value="${esc(e.xp)}"></div>
                    <button class="btn" data-la="setProgress" data-id="${l.id}">Appliquer niveau / XP</button></div></td></tr>`;
        }).join('');
        return `<div class="stats"><div class="stat"><b>${d.labs.length}</b><span>Laboratoire(s)</span></div>
                <div class="stat"><b>${d.labs.filter((l) => l.owner).length}</b><span>Possédé(s)</span></div>
                <div class="stat"><b>${d.raids.length}</b><span>Attaque(s) en cours</span></div>
                <div class="stat"><b>${d.open ? 'Ouvertes' : 'Fermées'}</b><span>Attaques maintenant (${esc(d.serverTime)} serveur)</span></div></div>
            <div class="section"><h2>Créer un laboratoire à ta position</h2>
                <p class="hint">Place-toi devant la porte du futur laboratoire (dehors), puis crée-le. Un groupe l'achète ensuite à l'entrée (chef du groupe, compte du groupe).
                    L'intérieur est une instance : plusieurs laboratoires peuvent utiliser le même intérieur sans se voir.</p>
                <div class="form-grid" style="grid-template-columns:1.4fr 1.2fr 140px auto;align-items:end">
                    <div><label>Nom</label><input class="input" data-lc="name" value="${esc(c.name)}" placeholder="Ex. : Entrepôt du port"></div>
                    <div><label>Intérieur</label><select class="input" data-lc="interior">${ints.map((i) => `<option value="${esc(i.code)}" ${(c.interior || d.defaultInterior) === i.code ? 'selected' : ''}>${esc(i.label)}</option>`).join('')}</select></div>
                    <div><label>Prix d'achat ($)</label><input class="input" type="number" min="0" data-lc="price" value="${esc(c.price === '' ? d.defaultPrice : c.price)}"></div>
                    <button class="btn primary" data-la="create">➕ Créer ici</button></div></div>
            <div class="section"><h2>Laboratoires</h2><table class="loot wide"><tr><th>N°</th><th>Nom</th><th>Intérieur</th><th>Prix</th><th></th><th></th></tr>
                ${rows || '<tr><td colspan="6" class="muted">Aucun laboratoire : crée le premier ci-dessus.</td></tr>'}</table>
                <p class="hint">Changer le propriétaire génère un nouveau code (envoyé au nouveau chef) et remet les autorisations à zéro ; le niveau, l'expérience, les équipements et le coffre restent.</p></div>`;
    }

    function viewRaids(d) {
        if (!G.raid) G.raid = clone(d.settings);
        const s = G.raid;
        const num = (k, label, min, max, step = 1) => `<div><label>${label}</label><input class="input" type="number" min="${min}" max="${max}" step="${step}" data-lr="${k}" value="${esc(s[k])}"></div>`;
        const tog = (k, label) => `<div class="tile toggle-tile ${s[k] ? 'on' : ''}" data-lt="${k}"><div><strong>${label}</strong></div><div class="switch"></div></div>`;
        const slots = (s.slots || []).map((x, i) => `<tr><td>${DAYS.map((dn, j) => `<label style="margin-right:8px;display:inline-flex;gap:4px;align-items:center"><input type="checkbox" data-ld="${i}|${j + 1}" ${x.days.includes(j + 1) ? 'checked' : ''}>${dn}</label>`).join('')}</td>
            <td><input class="input" type="time" data-ls="${i}|from" value="${esc(x.from)}" style="width:120px"></td><td><input class="input" type="time" data-ls="${i}|to" value="${esc(x.to)}" style="width:120px"></td>
            <td><button class="btn danger" data-la="slotDel" data-i="${i}">Retirer</button></td></tr>`).join('');
        return `<div class="section"><h2>⚔️ Réglages des attaques</h2>
            <p class="hint">Heure du serveur dans le fuseau réglé : <b>${esc(d.serverTime)}</b> (${DAYS[(d.serverDay || 1) - 1]}). Attaques ${d.open ? '<b>ouvertes</b>' : 'fermées'} maintenant. Un créneau peut passer minuit (ex. 22:00 → 02:00).</p>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr));margin-bottom:12px">
                ${tog('enabled', s.enabled ? 'Attaques activées' : 'Attaques désactivées')}${tog('starterBossOnly', 'Seul un chef lance l\'attaque')}
                ${tog('lockDuringRaid', 'Laboratoire verrouillé pendant l\'attaque')}${tog('kickOnCapture', 'Capture : sortir ceux qui perdent l\'accès')}${tog('notifyAllMembers', 'Prévenir tous les membres (sinon chefs)')}</div>
            <div class="form-grid" style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1100px">
                ${num('utcOffset', 'Fuseau (heures / UTC)', -12, 14, 0.5)}${num('prepSeconds', 'Préparation (s)', 0, 600)}${num('duration', 'Durée de capture (s)', 60, 7200)}${num('radius', 'Rayon de la zone (m)', 10, 500)}
                ${num('minAttackers', 'Attaquants vivants pour lancer', 1, 50)}${num('minDefendersOnline', 'Défenseurs connectés minimum', 0, 50)}${num('emptyGrace', 'Échec si zone vide pendant (s)', 5, 600)}
                <div><label>Victoire des attaquants</label><select class="input" data-lr="winRule"><option value="present" ${s.winRule === 'present' ? 'selected' : ''}>Au moins 1 attaquant vivant dans la zone à la fin</option>
                    <option value="majority" ${s.winRule === 'majority' ? 'selected' : ''}>Plus d'attaquants que de défenseurs vivants dans la zone</option></select></div>
                ${num('labCooldown', 'Repos d\'un laboratoire (min)', 0, 10080)}${num('groupCooldown', 'Repos d\'un groupe attaquant (min)', 0, 10080)}</div>
            <h2 style="margin-top:16px">Créneaux autorisés</h2>
            <table class="loot wide"><tr><th>Jours</th><th>Début</th><th>Fin</th><th></th></tr>${slots || '<tr><td colspan="4" class="muted">Aucun créneau : aucune attaque possible.</td></tr>'}</table>
            <div class="btn-row" style="margin-top:10px"><button class="btn" data-la="slotAdd">+ Ajouter un créneau</button></div>
            <div class="btn-row" style="margin-top:14px"><button class="btn primary" data-la="raidsSave">💾 Enregistrer (appliqué tout de suite)</button><button class="btn" data-la="raidsUndo">Annuler les modifications</button>
                <button class="btn danger" data-la="raidsReset">Revenir à config.lua</button></div></div>
            <div class="section"><h2>Attaques en cours (${d.raids.length})</h2><table class="loot wide"><tr><th>Laboratoire</th><th>Attaquant</th><th>Défenseur</th><th>État</th><th>Zone</th><th>Reste</th><th></th></tr>
                ${d.raids.map((r) => `<tr><td>${esc(r.name)}</td><td>${esc(r.attacker)}</td><td>${esc(r.defender)}</td><td>${STATUS[r.status] || r.status}</td><td>⚔️ ${r.attackers || 0} · 🛡️ ${r.defenders || 0}</td><td>${mmss(r.remaining)}</td>
                    <td><button class="btn danger" data-la="raidCancel" data-lab="${r.lab}">Annuler</button></td></tr>`).join('') || '<tr><td colspan="7" class="muted">Aucune.</td></tr>'}</table></div>
            <div class="section"><h2>Historique des attaques et captures</h2><table class="loot wide"><tr><th>Date</th><th>Labo</th><th>Attaquant</th><th>Défenseur</th><th>Résultat</th><th>Lancée par</th></tr>
                ${(d.history || []).map((h) => `<tr><td>${date(h.t)}</td><td>#${h.lab_id}</td><td>${esc(h.attacker_label)}</td><td>${esc(h.defender_label)}</td><td><b>${STATUS[h.status] || esc(h.status)}</b> <span class="muted">${esc(h.reason || '')}</span></td><td>${esc(h.started_by)}</td></tr>`).join('')
                || '<tr><td colspan="6" class="muted">Aucune attaque.</td></tr>'}</table></div>`;
    }

    function viewInteriors(d) {
        const pt = (p) => (p ? `${p.x.toFixed(1)}, ${p.y.toFixed(1)}, ${p.z.toFixed(1)}` : '—');
        return `<div class="section"><h2>🏭 Intérieurs</h2>
            <p class="hint">Intérieurs du jeu de base (aucun MLO requis). Leurs coordonnées viennent de la communauté : <b>teste chaque intérieur</b> et corrige les points en te plaçant au bon endroit
                (« Définir ici »). Sortie (rouge) = arrivée, cercle bleu = éditeur des équipements, cercle orange = coffre, zone = centre de la zone où les équipements peuvent être posés.
                Pendant un test : <span class="keycap">/labsortir</span> pour revenir.</p>
            <table class="loot wide"><tr><th>Intérieur</th><th>Arrivée / sortie</th><th>Cercle bleu</th><th>Coffre</th><th>Zone des équipements</th><th></th></tr>
            ${d.interiors.map((i) => `<tr><td><b>${esc(i.label)}</b><div class="hint" style="margin:2px 0 0">${esc(i.code)}${i.custom ? ' · points corrigés' : ''}</div></td>
                <td>${pt(i.spawn)}<br><button class="btn" data-li="${esc(i.code)}|spawn">Définir ici</button></td>
                <td>${pt(i.manage)}<br><button class="btn" data-li="${esc(i.code)}|manage">Définir ici</button></td>
                <td>${pt(i.stash)}<br><button class="btn" data-li="${esc(i.code)}|stash">Définir ici</button></td>
                <td>${pt(i.bounds)} · ${Math.round(i.bounds.r)} m<br><button class="btn" data-li="${esc(i.code)}|bounds">Centre ici</button>
                    <input class="input" type="number" min="5" max="150" data-lrad="${esc(i.code)}" value="${Math.round(i.bounds.r)}" style="width:70px;display:inline-block"> <button class="btn" data-la="radius" data-code="${esc(i.code)}">Rayon</button></td>
                <td style="white-space:nowrap"><button class="btn primary" data-la="test" data-code="${esc(i.code)}">Tester</button> ${i.custom ? `<button class="btn danger" data-la="ireset" data-code="${esc(i.code)}">Réinitialiser</button>` : ''}</td></tr>`).join('')}</table></div>`;
    }

    function viewLevels(d) {
        const cat = (c) => { const x = d.categories[c] || { label: c, icon: '' }; return `${x.icon} ${x.label}`; };
        return `<div class="section"><h2>⬆️ Niveaux des laboratoires</h2>
            <p class="hint">Le niveau appartient au laboratoire (il reste quand le propriétaire change). Les seuils, prix et déblocages se règlent dans <b>elyzea_labs/config.lua</b> (Config.Levels, Config.Equipment, Config.Recipes).</p>
            <table class="loot wide"><tr><th>Niveau</th><th>Expérience requise</th><th>Prix de l'amélioration</th><th>Débloque</th><th>Équipements max</th></tr>
            ${d.levels.map((l) => `<tr><td><b>${esc(l.label)}</b></td><td>${l.xp} XP</td><td>${l.n === 1 ? 'à l\'achat du laboratoire' : money(l.price)}</td><td>${(l.unlocks || []).map(cat).join(', ')}</td><td>${l.maxEquipment}</td></tr>`).join('')}</table></div>`;
    }

    function viewLogs(d) {
        return `<div class="section"><h2>📜 Journal (80 dernières lignes)</h2><table class="loot wide"><tr><th>Date</th><th>Labo</th><th>Type</th><th>Par</th><th>Détail</th></tr>
            ${(d.logs || []).map((l) => `<tr><td>${date(l.t)}</td><td>${l.lab_id ? `#${l.lab_id}` : '—'}</td><td>${esc(l.kind)}</td><td>${esc(l.actor)}</td><td>${esc(l.detail)}</td></tr>`).join('') || '<tr><td colspan="5" class="muted">Vide.</td></tr>'}</table></div>`;
    }

    VIEWS.labs = () => {
        const d = D.labs;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_labs')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        if (d.denied) return '<div class="protect">⚠️ <span>Permission « labs_manage » requise.</span></div>';
        const subs = `<div class="btn-row" style="margin-bottom:14px">${SUBS.map(([k, l]) => `<button class="btn ${G.sub === k ? 'primary' : ''}" data-lsub="${k}">${l}</button>`).join('')}</div>`;
        const v = { labs: viewLabs, raids: viewRaids, interiors: viewInteriors, levels: viewLevels, logs: viewLogs }[G.sub] || viewLabs;
        return subs + v(d);
    };

    const live = () => isOpen && tab === 'labs' && D && D.labs && D.labs.available;
    document.addEventListener('input', (ev) => {
        if (!live()) return;
        const t = ev.target;
        if (t.dataset.lc) G.create[t.dataset.lc] = t.value;
        if (t.dataset.le) { const [id, k] = t.dataset.le.split('|'); G.edit[id] = G.edit[id] || {}; G.edit[id][k] = t.type === 'checkbox' ? t.checked : t.value; }
        if (t.dataset.lr && G.raid) G.raid[t.dataset.lr] = t.tagName === 'SELECT' ? t.value : Number(t.value);
        if (t.dataset.ls && G.raid) { const [i, k] = t.dataset.ls.split('|'); G.raid.slots[Number(i)][k] = t.value; }
    });
    document.addEventListener('change', (ev) => {
        if (!live()) return;
        const t = ev.target;
        if (t.dataset.le) { const [id, k] = t.dataset.le.split('|'); G.edit[id] = G.edit[id] || {}; G.edit[id][k] = t.type === 'checkbox' ? t.checked : t.value; }
        if (t.dataset.lc) G.create[t.dataset.lc] = t.value;
        if (t.dataset.lr && G.raid) G.raid[t.dataset.lr] = t.tagName === 'SELECT' ? t.value : Number(t.value);
        if (t.dataset.ld && G.raid) {
            const [i, day] = t.dataset.ld.split('|').map(Number);
            const s = G.raid.slots[i];
            s.days = t.checked ? [...new Set([...s.days, day])].sort() : s.days.filter((x) => x !== day);
        }
    });
    document.addEventListener('click', async (ev) => {
        if (!live()) return;
        const d = D.labs;
        let n;
        if ((n = ev.target.closest('[data-lsub]'))) { G.sub = n.dataset.lsub; return render(); }
        if ((n = ev.target.closest('[data-lt]')) && G.raid) { G.raid[n.dataset.lt] = !G.raid[n.dataset.lt]; return render(); }
        if ((n = ev.target.closest('[data-li]'))) { const [interior, point] = n.dataset.li.split('|'); send('interiorPoint', { interior, point }); return later(); }
        if (!(n = ev.target.closest('[data-la]')) || n.disabled) return;
        const id = Number(n.dataset.id);
        const e = G.edit[id] || {};
        switch (n.dataset.la) {
            case 'create': send('create', { name: G.create.name, interior: G.create.interior || d.defaultInterior, price: G.create.price === '' ? d.defaultPrice : Number(G.create.price) }); G.create.name = ''; return later();
            case 'update': send('update', { id, name: e.name, interior: e.interior, price: Number(e.price), disabled: !!e.disabled }); delete G.edit[id]; return later();
            case 'tp': case 'enter': case 'move': return send(n.dataset.la, { id });
            case 'delete': if (await confirmBox('Supprimer ce laboratoire ?', 'Ses équipements sont supprimés. Le contenu du coffre reste en base (inventaire « lab_' + id + ' »).')) { send('delete', { id }); later(); } return;
            case 'setOwner': if (await confirmBox('Changer le propriétaire ?', 'Un nouveau code est créé et les autorisations sont remises à zéro. Les joueurs qui perdent l\'accès sont sortis du laboratoire.')) { send('setOwner', { id, group: Number(e.group) || 0 }); delete G.edit[id]; later(); } return;
            case 'setProgress': send('setProgress', { id, level: Number(e.level), xp: Number(e.xp) }); delete G.edit[id]; return later();
            case 'slotAdd': G.raid.slots.push({ days: [1, 2, 3, 4, 5, 6, 7], from: '20:00', to: '23:00' }); return render();
            case 'slotDel': G.raid.slots.splice(Number(n.dataset.i), 1); return render();
            case 'raidsSave': send('raids', { settings: G.raid }); G.raid = null; return later();
            case 'raidsUndo': G.raid = null; return render();
            case 'raidsReset': if (await confirmBox('Revenir à config.lua ?', 'Les réglages des attaques reviennent à ceux du fichier.')) { send('raidsReset'); G.raid = null; later(); } return;
            case 'raidCancel': if (await confirmBox('Annuler cette attaque ?', 'Rien ne change pour le laboratoire (propriétaire, niveau, coffre, équipements).')) { send('raidCancel', { lab: Number(n.dataset.lab) }); later(); } return;
            case 'test': return send('interiorTest', { interior: n.dataset.code });
            case 'radius': { const inp = document.querySelector(`[data-lrad="${n.dataset.code}"]`); send('interiorRadius', { interior: n.dataset.code, r: Number(inp && inp.value) }); return later(); }
            case 'ireset': if (await confirmBox('Réinitialiser les points ?', 'Les points de cet intérieur reviennent à ceux de config.lua.')) { send('interiorReset', { interior: n.dataset.code }); later(); } return;
        }
    });
})();
