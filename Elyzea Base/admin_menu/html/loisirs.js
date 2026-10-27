/* =========================================================
   LOISIRS (ressource elyzea_loisirs, permission « loisirs_manage »)
   Parties en cours · Bowling · Billard · Golf
   Les positions sont prises côté serveur (là où se tient le staff) ; elyzea_loisirs revalide tout.
   ========================================================= */
(() => {
    TABS.push({
        id: 'loisirs', group: 5, label: 'Loisirs', ico: '🎳',
        sub: 'Pistes de bowling, tables de billard et parcours de golf : poser à ta position, régler, supprimer. Parties en cours (annuler).',
        show: () => has('loisirs_manage') && !!(D && D.loisirs),
        count: () => ((D && D.loisirs && D.loisirs.sessions) || []).filter((s) => s.state === 'IN_PROGRESS').length,
    });

    const L = { sub: 'sessions', course: null, hole: 1, draft: {} };
    const send = (name, data = {}) => action('loisirs', { name, data });
    const arr = (x) => (Array.isArray(x) ? x : Object.values(x || {}));
    const later = () => setTimeout(() => post('refresh'), 500);
    const SUBS = [['sessions', '🎮 Parties en cours'], ['bowling', '🎳 Bowling'], ['billiards', '🎱 Billard'], ['golf', '⛳ Golf']];
    const STATE = { WAITING: '🟦 Salon (attente)', STARTING: '🟨 Démarrage', IN_PROGRESS: '🟩 En cours', FINISHED: '🏁 Terminée', CANCELLED: '⛔ Annulée' };
    const GAME = { bowling: '🎳 Bowling', billiards: '🎱 Billard', golf: '⛳ Golf' };
    const HAZ = { water: '💧 Eau (+1, drop)', bunker: '🏖️ Bunker', ob: '🚫 Hors limites (+1, rejouer)', lost: '🌲 Balle perdue (+1, rejouer)' };
    const pos = (p) => (p ? `${Number(p.x).toFixed(1)}, ${Number(p.y).toFixed(1)}, ${Number(p.z || 0).toFixed(1)}` : '—');
    // Valeur saisie (gardée entre deux rafraîchissements automatiques) ou valeur enregistrée
    const val = (key, saved) => (L.draft[key] !== undefined ? L.draft[key] : (saved ?? ''));
    const numIn = (key, label, saved, min, max, step = 1) => `<div><label>${esc(label)}</label>
        <input class="input" type="number" data-lk="${key}" min="${min}" max="${max}" step="${step}" value="${esc(val(key, saved))}"></div>`;
    const sessBadge = (s) => (s ? `<span class="zbadge">${STATE[s.state] || esc(s.state)} · ${s.players} joueur(s)</span>` : '<span class="zbadge">libre</span>');
    const instOf = (kind) => arr(D.loisirs.installations).filter((i) => i.kind === kind);

    // Ligne commune : nom (renommer), position, partie, aller, supprimer
    function instHead(i, extra = '') {
        const p = i.kind === 'golf' ? (arr(i.data.holes)[0] || {}).tee : i.data;
        return `<div class="card-head"><strong>#${i.id} ${esc(i.name)}</strong><span class="muted">${pos(p)} ${sessBadge(i.session)}</span></div>
            <div class="inline" style="max-width:560px;margin-top:6px"><input class="input" data-lk="name:${i.id}" maxlength="40" value="${esc(val(`name:${i.id}`, i.name))}">
                <button class="btn" data-lren="${i.id}">✏️ Renommer</button></div>
            ${extra}
            <div class="btn-row" style="margin-top:8px">
                ${p ? `<button class="btn" data-ltp="${i.id}">🚀 Y aller</button>` : ''}
                ${i.session ? `<button class="btn danger" data-lcancel="${i.session.id}">🛑 Annuler la partie</button>` : ''}
                <button class="btn danger" data-ldel="${i.id}">🗑 Supprimer</button></div>`;
    }

    /* -------------------------------------------------- parties */
    function viewSessions(d) {
        const list = arr(d.sessions);
        const instName = (id) => (arr(d.installations).find((i) => i.id === id) || {}).name || `#${id}`;
        return `<div class="stats">
            <div class="stat"><b>${instOf('bowling').length}</b><span>Piste(s) de bowling</span></div>
            <div class="stat"><b>${instOf('billiards').length}</b><span>Table(s) de billard</span></div>
            <div class="stat"><b>${instOf('golf').length}</b><span>Parcours de golf</span></div>
            <div class="stat"><b>${list.length}</b><span>Partie(s) ouvertes</span></div></div>
        ${!list.length ? '<div class="empty">Aucune partie en cours. Les joueurs en créent en appuyant sur E près d\'une piste, d\'une table ou d\'un départ de golf.</div>'
        : `<table class="loot wide"><tr><th>Partie</th><th>Jeu</th><th>Lieu</th><th>État</th><th>Joueurs</th><th>Hôte</th><th></th></tr>
            ${list.map((s) => `<tr><td>#${s.id} ${esc(s.name || '')}</td><td>${GAME[s.game] || esc(s.game)}</td><td>${esc(instName(s.inst))}</td>
                <td>${STATE[s.state] || esc(s.state)}</td><td>${s.players}</td><td>${esc(s.host || '—')}</td>
                <td style="text-align:right">${s.state !== 'FINISHED' && s.state !== 'CANCELLED' ? `<button class="btn danger" data-lcancel="${s.id}">🛑 Annuler</button>` : ''}</td></tr>`).join('')}</table>`}
        <p class="hint">Annuler rend les droits d'entrée si la partie n'avait pas commencé, et libère la piste / la table / le parcours.</p>`;
    }

    /* -------------------------------------------------- bowling */
    function viewBowling() {
        const list = instOf('bowling');
        return `<div class="section"><h2>Nouvelle piste (à ta position)</h2>
            <p class="hint">Tiens-toi <b>sur la ligne de faute</b>, au milieu de la piste, <b>tourné vers les quilles</b>. Les quilles sont posées 18,3 m devant toi
                (piste réglementaire). Le jeu de base n'a pas de bowling : choisis un intérieur (MLO) ou un sol plat de 22 m de long.</p>
            <div class="inline" style="max-width:560px"><input class="input" data-lk="new:bowling" maxlength="40" placeholder="Nom (ex. Piste 1)" value="${esc(val('new:bowling', ''))}">
                <button class="btn primary" data-ladd="bowling">📍 Poser la piste ici</button>
                <button class="btn" data-ladd="bowling_align" title="Regarde vers les quilles du décor : la piste est calée sur la quille de tête">🎯 Aligner sur les quilles du décor</button></div>
            <p class="hint">Ton MLO a déjà des quilles ? Tiens-toi derrière la ligne de faute, regarde vers elles et clique <b>Aligner sur les quilles du décor</b> :
                la piste est calée exactement dans l'axe, et les quilles du décor sont cachées pour laisser place aux vraies quilles qui tombent.</p></div>
        ${!list.length ? '<div class="empty">Aucune piste.</div>' : list.map((i) => `<div class="card">${instHead(i)}</div>`).join('')}`;
    }

    /* -------------------------------------------------- billard */
    function viewBilliards() {
        const list = instOf('billiards');
        return `<div class="section"><h2>Nouvelle table</h2>
            <p class="hint"><b>Table neuve</b> : posée 1,6 m devant toi, dans l'axe de ton regard. <b>Table du jeu</b> : approche-toi à moins de 4 m d'une table déjà présente sur la carte (bars, villas),
                elle est reprise telle quelle. Règles : 8-ball, 2 joueurs.</p>
            <div class="form-grid" style="grid-template-columns:1fr 220px;max-width:640px;align-items:end">
                <div><label>Nom</label><input class="input" data-lk="new:billiards" maxlength="40" placeholder="Table du Yellow Jack" value="${esc(val('new:billiards', ''))}"></div>
                <div><label>Modèle (table neuve)</label><select class="input" data-lk="new:model">${['prop_pooltable_02', 'prop_pooltable_3b']
                    .map((m) => `<option value="${m}" ${val('new:model', 'prop_pooltable_02') === m ? 'selected' : ''}>${m}</option>`).join('')}</select></div></div>
            <div class="btn-row" style="margin-top:10px"><button class="btn primary" data-ladd="billiards">📍 Poser une table neuve devant moi</button>
                <button class="btn" data-ladd="billiards_existing">🎯 Utiliser la table du jeu la plus proche</button></div></div>
        ${!list.length ? '<div class="empty">Aucune table.</div>' : list.map((i) => {
            const c = i.data.calib || {};
            return `<div class="card">${instHead(i, `
                <p class="hint" style="margin-top:8px">Modèle ${esc(i.data.model || '?')} · ${i.data.spawn === false ? 'table de la carte' : 'table posée par le menu'}.
                    Dimensions de la surface de jeu : vides = valeurs de config.lua. À corriger seulement si les billes ne sont pas posées sur le tapis.</p>
                <div class="form-grid" style="grid-template-columns:repeat(3,160px) auto;align-items:end">
                    ${numIn(`cl:${i.id}`, 'Longueur (m)', c.length, 1.5, 3.2, 0.01)}
                    ${numIn(`cw:${i.id}`, 'Largeur (m)', c.width, 0.7, 1.7, 0.01)}
                    ${numIn(`ch:${i.id}`, 'Hauteur du tapis (m)', c.height, 0.3, 1.5, 0.01)}
                    <button class="btn" data-lcalib="${i.id}">💾 Enregistrer</button></div>`)}</div>`;
        }).join('')}`;
    }

    /* -------------------------------------------------- golf */
    function holeCard(i, h, n) {
        const k = `${i.id}:${n}`;
        const dist = h.flag ? Math.round(Math.hypot(h.flag.x - h.tee.x, h.flag.y - h.tee.y)) : null;
        const hz = arr(h.hazards);
        return `<div class="card recipe" style="margin-top:10px"><div class="card-head"><strong>Trou ${n} · par ${h.par}</strong>
                <span class="muted">${dist !== null ? `${dist} m` : '<b style="color:var(--danger)">drapeau à poser</b>'}</span></div>
            <p class="hint">Départ : ${pos(h.tee)} · Drapeau : ${pos(h.flag)}</p>
            <div class="btn-row"><button class="btn" data-lgolf="hole_tee" data-hole="${n}">⛳ Départ ici (remplace)</button>
                <button class="btn primary" data-lgolf="hole_flag" data-hole="${n}">🚩 Drapeau ici</button>
                <button class="btn danger" data-lholedel="${n}">🗑 Supprimer le trou</button></div>
            <div class="form-grid" style="grid-template-columns:repeat(3,170px) auto;align-items:end;margin-top:8px">
                ${numIn(`par:${k}`, 'Par (3 à 6)', h.par, 3, 6)}
                ${numIn(`gr:${k}`, 'Rayon du green (m)', h.greenR, 5, 40, 0.5)}
                ${numIn(`fw:${k}`, 'Largeur du fairway (m)', h.fairwayW, 10, 120, 1)}
                <button class="btn" data-lgolf="hole_set" data-hole="${n}">💾 Enregistrer</button></div>
            <h3 class="sub-h" style="font-size:14px;margin:12px 0 4px">Zones (${hz.length})</h3>
            <table class="loot wide"><tr><th>Type</th><th>Centre</th><th>Rayon</th><th></th></tr>
                ${hz.map((z, j) => `<tr><td>${HAZ[z.type] || esc(z.type)}</td><td>${Number(z.x).toFixed(1)}, ${Number(z.y).toFixed(1)}</td><td>${z.r} m</td>
                    <td style="text-align:right"><button class="sb-close" data-lhzdel="${n}" data-i="${j + 1}">✕</button></td></tr>`).join('') || '<tr><td colspan="4" class="muted">Aucune zone : tout ce qui n\'est ni green ni fairway est du rough.</td></tr>'}</table>
            <div class="form-grid" style="grid-template-columns:260px 150px auto;align-items:end;margin-top:6px">
                <div><label>Type de zone</label><select class="input" data-lk="hzt:${k}">${Object.entries(HAZ).map(([v, l]) => `<option value="${v}" ${val(`hzt:${k}`, 'water') === v ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
                ${numIn(`hzr:${k}`, 'Rayon (m)', 10, 2, 150)}
                <button class="btn" data-lhz="${n}">📍 Ajouter la zone autour de moi</button></div></div>`;
    }
    function viewGolf() {
        const list = instOf('golf');
        if (L.course && !list.some((i) => i.id === L.course)) L.course = null;
        if (!L.course && list.length) L.course = list[0].id;
        const c = list.find((i) => i.id === L.course);
        const holes = c ? arr(c.data.holes) : [];
        return `<div class="section"><h2>Nouveau parcours</h2>
            <p class="hint">Crée le parcours, puis pour chaque trou : tiens-toi au <b>départ</b> tourné vers le drapeau → « Nouveau trou », marche jusqu'au <b>trou</b> → « Drapeau ici ».
                Ajoute ensuite les zones (eau, bunkers, hors limites) en te tenant à leur centre. 1 à 18 trous. Le golf de Los Santos (GTA) convient très bien.</p>
            <div class="inline" style="max-width:560px"><input class="input" data-lk="new:golf" maxlength="40" placeholder="Golf de Los Santos" value="${esc(val('new:golf', ''))}">
                <button class="btn primary" data-ladd="golf">➕ Créer le parcours</button></div></div>
        <div class="btn-row" style="margin-bottom:12px">${list.map((i) => `<button class="btn ${i.id === L.course ? 'primary' : ''}" data-lcourse="${i.id}">⛳ ${esc(i.name)} · ${arr(i.data.holes).length} trou(s)</button>`).join('')}</div>
        ${!c ? '<div class="empty">Aucun parcours.</div>' : `<div class="card">${instHead(c)}
            <p class="hint" style="margin-top:8px">Par total : <b>${holes.reduce((a, h) => a + (Number(h.par) || 0), 0)}</b>
                ${holes.some((h) => !h.flag) ? ' · <b style="color:var(--danger)">des trous n\'ont pas de drapeau : le parcours ne peut pas être joué</b>' : ''}</p>
            <div class="btn-row"><button class="btn primary" data-lgolf="hole_tee" data-hole="new" ${holes.length >= 18 ? 'disabled' : ''}>➕ Nouveau trou (départ ici)</button></div>
            ${holes.map((h, j) => holeCard(c, h, j + 1)).join('')}</div>`}`;
    }

    VIEWS.loisirs = () => {
        const d = D.loisirs;
        if (!d.available) return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_loisirs')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ' : vérifie « ensure elyzea_loisirs » dans server.cfg'}.</span></div>`;
        const nav = `<div class="btn-row" style="margin-bottom:14px">${SUBS.map(([k, l]) => `<button class="btn ${L.sub === k ? 'primary' : ''}" data-lsub="${k}">${l}</button>`).join('')}</div>`;
        const body = L.sub === 'bowling' ? viewBowling() : L.sub === 'billiards' ? viewBilliards() : L.sub === 'golf' ? viewGolf() : viewSessions(d);
        return nav + (d.ready === false ? '<div class="protect">⏳ <span>Chargement des installations…</span></div>' : '') + body;
    };

    /* -------------------------------------------------- événements */
    const on = () => isOpen && tab === 'loisirs' && D && D.loisirs && D.loisirs.available;
    const take = (key) => { const v = L.draft[key]; delete L.draft[key]; return v; };
    document.addEventListener('click', async (ev) => {
        if (!on()) return;
        const t = ev.target.closest('[data-lsub],[data-ladd],[data-lren],[data-ltp],[data-ldel],[data-lcancel],[data-lcalib],[data-lcourse],[data-lgolf],[data-lholedel],[data-lhz],[data-lhzdel]');
        if (!t) return;
        const ds = t.dataset;
        if (ds.lsub) { L.sub = ds.lsub; return render(); }
        if (ds.lcourse) { L.course = Number(ds.lcourse); return render(); }
        if (ds.ladd) {
            if (ds.ladd === 'bowling') send('add_bowling', { name: take('new:bowling') || '' });
            else if (ds.ladd === 'bowling_align') send('add_bowling', { name: take('new:bowling') || '', align: true });
            else if (ds.ladd === 'billiards') send('add_billiards', { name: take('new:billiards') || '', model: L.draft['new:model'] || 'prop_pooltable_02' });
            else if (ds.ladd === 'billiards_existing') send('add_billiards', { name: take('new:billiards') || '', existing: true });
            else if (ds.ladd === 'golf') { send('add_course', { name: take('new:golf') || '' }); L.course = null; }
            return setTimeout(() => post('refresh'), ds.ladd === 'billiards_existing' || ds.ladd === 'bowling_align' ? 4500 : 500);
        }
        if (ds.lren) { send('rename', { id: Number(ds.lren), name: take(`name:${ds.lren}`) || '' }); return later(); }
        if (ds.ltp) return send('tp', { id: Number(ds.ltp) });
        if (ds.ldel) {
            if (await confirmBox('Supprimer cette installation ?', 'Elle disparaît pour tout le monde. Une partie en cours dessus est annulée et remboursée.')) { send('delete', { id: Number(ds.ldel) }); later(); }
            return;
        }
        if (ds.lcancel) {
            if (await confirmBox('Annuler cette partie ?', 'Les joueurs sont sortis de la partie. Les droits d\'entrée sont rendus si elle n\'avait pas commencé.')) { send('cancel_session', { session: Number(ds.lcancel) }); later(); }
            return;
        }
        if (ds.lcalib) {
            const id = ds.lcalib;
            send('billiards_calib', { id: Number(id), length: take(`cl:${id}`), width: take(`cw:${id}`), height: take(`ch:${id}`) });
            return later();
        }
        if (ds.lgolf) {
            const k = `${L.course}:${ds.hole}`;
            const data = { id: L.course };
            if (ds.hole !== 'new') data.hole = Number(ds.hole);
            if (ds.lgolf === 'hole_set') { data.par = take(`par:${k}`); data.greenR = take(`gr:${k}`); data.fairwayW = take(`fw:${k}`); }
            send(ds.lgolf, data);
            return later();
        }
        if (ds.lholedel) {
            if (await confirmBox(`Supprimer le trou ${ds.lholedel} ?`, 'Les trous suivants sont renumérotés.')) { send('hole_del', { id: L.course, hole: Number(ds.lholedel) }); later(); }
            return;
        }
        if (ds.lhz) {
            const k = `${L.course}:${ds.lhz}`;
            send('hole_hazard', { id: L.course, hole: Number(ds.lhz), type: L.draft[`hzt:${k}`] || 'water', radius: Number(L.draft[`hzr:${k}`] || 10) });
            return later();
        }
        if (ds.lhzdel) { send('hazard_del', { id: L.course, hole: Number(ds.lhzdel), index: Number(ds.i) }); return later(); }
    });
    const keep = (ev) => { if (on() && ev.target.dataset && ev.target.dataset.lk) L.draft[ev.target.dataset.lk] = ev.target.value; };
    document.addEventListener('input', keep);
    document.addEventListener('change', keep);
})();
