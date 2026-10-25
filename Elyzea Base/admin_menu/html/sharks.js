/* =========================================================
   ONGLET 🦈 REQUINS (permission « sharks_manage »)
   Zones dessinées en jeu, points d'apparition dans l'eau, délai de réapparition,
   joueurs protégés (jamais attaqués). Tout est sauvegardé (data/sharks.json).
   ========================================================= */
(() => {
    TABS.push({
        id: 'sharks', group: 2, label: 'Requins', ico: '🦈',
        sub: 'Requins agressifs dans des zones que tu dessines : ils attaquent les nageurs, jamais les bateaux, et réapparaissent quand ils sont tués.',
        show: () => has('sharks_manage') && !!(D && D.sharks),
    });

    const SK = { name: '', target: '', note: '' };
    const send = (name, data = {}) => action(name, data);
    const fmtS = (s) => { s = Math.max(0, Math.round(Number(s) || 0)); return s >= 60 ? `${Math.floor(s / 60)} min${s % 60 ? ` ${s % 60} s` : ''}` : `${s} s`; };
    const dt = (t) => (t ? new Date(t * 1000).toLocaleDateString('fr-FR') : '');

    function areaCard(a, S) {
        const L = S.limits;
        const modelOpts = S.models.map((m) => `<option value="${esc(m.id)}" ${a.model === m.id ? 'selected' : ''}>${esc(m.label)}</option>`).join('');
        const counts = (cur) => Array.from({ length: L.maxPerSpawn }, (_, i) => i + 1).map((n) => `<option value="${n}" ${Number(cur) === n ? 'selected' : ''}>${n} requin${n > 1 ? 's' : ''}</option>`).join('');
        const state = !a.enabled ? '<span class="badge" style="color:var(--muted)">désactivée</span>'
            : a.total === 0 ? '<span class="badge" style="color:var(--warn, #e0a33b)">aucun point d\'apparition</span>'
            : `<span class="badge" style="color:var(--ok)">${a.alive} / ${a.total} en vie</span>`;
        return `<div class="section" data-skid="${a.id}">
            <div class="inline" style="justify-content:space-between;flex-wrap:wrap;gap:8px">
                <h2 style="margin:0">🦈 ${esc(a.name)} ${state}</h2>
                <div class="tile toggle-tile ${a.enabled ? 'on' : ''}" data-ska="toggle" style="min-width:230px;padding:8px 12px"><div><strong>Zone active</strong></div><div class="switch"></div></div>
            </div>
            <div class="form-grid" style="grid-template-columns:repeat(auto-fill,minmax(200px,1fr));margin-top:12px;align-items:end">
                <div><label>Nom</label><input class="input" data-skf="name" value="${esc(a.name)}" maxlength="40"></div>
                <div><label>Espèce</label><select class="input" data-skf="model">${modelOpts}</select></div>
                <div><label>Réapparition après la mort (secondes)</label><input class="input" type="number" min="${L.minRespawn}" max="${L.maxRespawn}" data-skf="respawn" value="${a.respawn}"></div>
            </div>
            <p class="hint" style="margin:8px 0">Zone : ${a.points.length} coins · ${a.spawns.length} point(s) d'apparition · ${a.total} requin(s)
                ${a.dead ? ` · ${a.dead} mort(s), prochaine réapparition dans ${fmtS(a.next)}` : ''} · ${a.kills} requin(s) tué(s) au total</p>
            <div class="btn-row">
                <button class="btn primary" data-ska="spawns">📍 Poser les points d'apparition</button>
                <button class="btn" data-ska="draw">✏️ Redessiner la zone</button>
                <button class="btn" data-ska="tp">🧭 Y aller</button>
                <button class="btn" data-ska="reset" title="Retire les requins de la zone et les fait réapparaître à leur point">🔄 Faire réapparaître</button>
                <button class="btn danger" data-ska="delete">🗑️ Supprimer la zone</button>
            </div>
            ${a.spawns.length ? `<table style="margin-top:12px"><tr><th>Point</th><th>Position</th><th>Requins</th><th></th></tr>
                ${a.spawns.map((sp, i) => `<tr data-skidx="${i + 1}"><td><strong>n°${i + 1}</strong></td>
                    <td class="muted" style="font-size:12px">${sp.x.toFixed(1)}, ${sp.y.toFixed(1)}, ${sp.z.toFixed(1)}</td>
                    <td><select class="input" data-skcount style="width:auto">${counts(sp.count || 1)}</select></td>
                    <td style="text-align:right"><button class="btn danger" data-ska="spdel">✕</button></td></tr>`).join('')}</table>`
                : '<p class="hint" style="color:var(--danger)">Aucun point d\'apparition : clique sur « Poser les points d\'apparition » et vise l\'eau dans la zone.</p>'}
        </div>`;
    }

    VIEWS.sharks = () => {
        const S = D.sharks;
        const me = (D.me && D.me.id) || 0;
        const players = (D.players || []).slice().sort((a, b) => String(a.name).localeCompare(String(b.name)));
        return `
            <p class="hint">Dessine une zone dans l'eau, pose les points d'apparition : les requins y patrouillent et attaquent <b>tous les joueurs qui nagent</b> dans la zone
                jusqu'à les tuer. Ils ne visent jamais les joueurs en bateau (ou dans un véhicule) et ne sortent pas de la zone. Un requin tué réapparaît à son point
                après le délai de la zone. Tout est gardé après un redémarrage : les requins reviennent dès qu'un joueur s'approche (à ${Math.round(S.limits.activate)} m de la zone).</p>
            <div class="stats">
                <div class="stat"><b>${S.areas.length}</b><span>Zones</span></div>
                <div class="stat"><b>${S.alive}</b><span>Requins en vie</span></div>
                <div class="stat"><b>${S.immune.length}</b><span>Joueurs protégés</span></div>
            </div>
            <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr));margin:12px 0">
                <div class="tile toggle-tile ${S.enabled ? 'on' : ''}" data-ska="global"><div><strong>Requins activés</strong><span>${S.enabled ? 'Les zones actives ont leurs requins' : 'Désactivés : aucun requin sur le serveur'}</span></div><div class="switch"></div></div>
            </div>
            <div class="section"><h2>Nouvelle zone</h2>
                <div class="inline" style="max-width:620px"><input class="input" data-skd="name" placeholder="Nom (ex : Baie de Paleto)" maxlength="40" value="${esc(SK.name)}">
                    <button class="btn primary" data-ska="new">✏️ Dessiner la zone en jeu</button></div>
                <p class="hint">Le menu se ferme : vise l'eau et pose les coins de la zone un par un (le noclip marche aussi), puis termine. Pose ensuite les points d'apparition.</p>
            </div>
            ${S.areas.map((a) => areaCard(a, S)).join('') || '<div class="empty">Aucune zone de requins.</div>'}
            <div class="section"><h2>🛡️ Joueurs protégés</h2>
                <p class="hint">Ces joueurs peuvent nager dans les zones sans être attaqués ni tués par les requins. Enregistrés par leur licence : la protection est gardée après un redémarrage ou une reconnexion.</p>
                <div class="form-grid" style="grid-template-columns:minmax(220px,1.2fr) minmax(200px,1fr) auto;align-items:end;max-width:820px">
                    <div><label>Joueur connecté (ID)</label><input class="input" list="sk-players" data-skd="target" placeholder="ID serveur, ex : 12" value="${esc(SK.target)}">
                        <datalist id="sk-players">${players.map((p) => `<option value="${p.id}">${esc(p.name)}${p.id === me ? ' (toi)' : ''}</option>`).join('')}</datalist></div>
                    <div><label>Note (facultatif)</label><input class="input" data-skd="note" maxlength="60" placeholder="ex : biologiste marin" value="${esc(SK.note)}"></div>
                    <button class="btn primary" data-ska="immune">🛡️ Protéger</button>
                </div>
                ${S.immune.length ? `<table style="margin-top:12px"><tr><th>Joueur</th><th>État</th><th>Ajouté</th><th></th></tr>
                    ${S.immune.map((p) => `<tr data-skimm="${p.index}"><td><strong>${esc(p.name)}</strong>${p.note ? `<div class="muted" style="font-size:12px">${esc(p.note)}</div>` : ''}</td>
                        <td>${p.online ? `🟢 connecté (ID ${p.online})` : '⚪ hors ligne'}</td>
                        <td class="muted" style="font-size:12px">${esc(p.by || '')} ${dt(p.at)}</td>
                        <td style="text-align:right"><button class="btn danger" data-ska="unimmune">Retirer</button></td></tr>`).join('')}</table>`
                    : '<div class="empty" style="padding:16px 0">Aucun joueur protégé.</div>'}
            </div>`;
    };
    // Pendant la saisie dans un champ, l'actualisation automatique ne reconstruit pas l'onglet
    // (signature : la même que le dernier affichage pendant la saisie, une nouvelle sinon)
    let sigN = 0, lastSig = '';
    STABLE_VIEWS.sharks = () => {
        const a = document.activeElement;
        if (lastSig && a && a.matches && a.matches('#content input, #content select')) return lastSig;
        lastSig = `free|${++sigN}`;
        return lastSig;
    };

    const area = (el) => { const c = el.closest('[data-skid]'); return c ? D.sharks.areas.find((x) => x.id === Number(c.dataset.skid)) : null; };

    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'sharks') return;
        const k = e.target.dataset.skd;
        if (k) SK[k] = e.target.value;
    });

    document.addEventListener('change', (e) => {
        if (!isOpen || tab !== 'sharks') return;
        const t = e.target, a = area(t);
        if (!a) return;
        if (t.dataset.skf === 'name' && t.value.trim()) return send('sharks_area_update', { id: a.id, name: t.value.trim(), quiet: true });
        if (t.dataset.skf === 'model') return send('sharks_area_update', { id: a.id, model: t.value });
        if (t.dataset.skf === 'respawn') return send('sharks_area_update', { id: a.id, respawn: Number(t.value) });
        if (t.hasAttribute('data-skcount')) {
            const idx = Number(t.closest('[data-skidx]').dataset.skidx);
            return send('sharks_spawn_count', { id: a.id, index: idx, count: Number(t.value) });
        }
    });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'sharks') return;
        const n = e.target.closest('[data-ska]');
        if (!n) return;
        const S = D.sharks, a = area(n);
        switch (n.dataset.ska) {
            case 'global': return send('sharks_settings', { enabled: !S.enabled });
            case 'new': {
                const name = SK.name.trim();
                SK.name = '';
                return editorPost('sharks_zone_draw', { name: name || `Zone requins ${S.areas.length + 1}` });
            }
            case 'toggle': return send('sharks_area_update', { id: a.id, enabled: !a.enabled });
            case 'draw':
                if (a.spawns.length && !(await confirmBox('Redessiner la zone ?', 'Les points d\'apparition qui seront hors de la nouvelle zone seront retirés.'))) return;
                return editorPost('sharks_zone_draw', { id: a.id, name: a.name });
            case 'spawns': return editorPost('sharks_spawns_draw', { id: a.id, name: a.name, points: a.points, spawns: a.spawns });
            case 'tp': return editorPost('sharks_tp', a.center);
            case 'reset': return send('sharks_area_reset', { id: a.id });
            case 'delete':
                if (await confirmBox(`Supprimer « ${a.name} » ?`, 'La zone, ses points d\'apparition et ses requins sont supprimés définitivement.')) send('sharks_area_delete', { id: a.id });
                return;
            case 'spdel': {
                const idx = Number(n.closest('[data-skidx]').dataset.skidx);
                if (await confirmBox(`Supprimer le point n°${idx} ?`, 'Ses requins disparaissent.')) send('sharks_spawn_delete', { id: a.id, index: idx });
                return;
            }
            case 'immune': {
                const id = Number(String(SK.target).trim());
                if (!Number.isInteger(id) || id < 1) return;
                const note = SK.note;
                SK.target = ''; SK.note = '';
                render();
                return send('sharks_immune_add', { target: id, note });
            }
            case 'unimmune': {
                const row = n.closest('[data-skimm]');
                const p = S.immune.find((x) => x.index === Number(row.dataset.skimm));
                if (p && (await confirmBox(`Retirer la protection de ${p.name} ?`, 'Les requins pourront de nouveau l\'attaquer.'))) send('sharks_immune_remove', { index: p.index });
            }
        }
    });
})();
