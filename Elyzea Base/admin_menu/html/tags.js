/* =========================================================
   TAGS (ressource elyzea_tags, permission « tags_manage »)
   Graffitis des quartiers : réglages, mots interdits, liste des
   tags avec leur auteur, suppression (un tag, un joueur, une zone, tout).
   ========================================================= */
(() => {
    TABS.push({
        id: 'tags', group: 6, label: 'Tags', ico: '🎨',
        sub: 'Graffitis des quartiers : auteurs, suppression, mots interdits, limites.',
        show: () => has('tags_manage') && !!(D && D.tags),
    });

    const G = { draft: null, q: '' };
    const send = (name, data = {}) => action('tags', { name, data });
    const date = (t) => new Date(t * 1000).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });

    VIEWS.tags = () => {
        const d = D.tags;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_tags')}</b> ne répond pas${d.error ? ' (redémarre-la après la mise à jour)' : ''}.</span></div>`;
        }
        if (!G.draft) G.draft = JSON.parse(JSON.stringify(d.settings));
        const s = G.draft;
        const tog = (k, title, sub) => `<div class="tile toggle-tile ${s[k] ? 'on' : ''}" data-tgb="${k}"><div><strong>${title}</strong><span>${sub}</span></div><div class="switch"></div></div>`;
        const num = (k, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-tgf="${k}" value="${esc(s[k])}" ${extra}></div>`;

        const q = G.q.trim().toLowerCase();
        const list = (d.tags || []).filter((t) => !q || [t.text, t.author, t.cid, t.group, t.zone].some((v) => String(v || '').toLowerCase().includes(q)));
        const zones = {};
        (d.tags || []).forEach((t) => { const k = t.zoneId == null ? 'none' : t.zoneId; zones[k] = zones[k] || { id: t.zoneId, name: t.zone || 'Hors territoire', n: 0 }; zones[k].n++; });
        const rows = list.map((t) => `<tr>
            <td><span style="display:inline-flex;align-items:center;gap:8px"><i style="width:12px;height:12px;border-radius:3px;background:${esc(t.color)};display:inline-block;border:1px solid #0006"></i><strong>${esc(t.text)}</strong></span></td>
            <td>${esc(t.author || '?')} <span class="muted">${esc(t.cid || '')}</span></td>
            <td>${t.group ? esc(t.group) : '<span class="muted">—</span>'}</td>
            <td>${t.zone ? esc(t.zone) : '<span class="muted">Hors territoire</span>'}</td>
            <td class="muted">${date(t.created)}</td>
            <td style="text-align:right;white-space:nowrap"><button class="btn" data-tga="goto" data-id="${t.id}">Y aller</button>
                <button class="btn danger" data-tga="delete" data-id="${t.id}">Supprimer</button>
                ${t.cid ? `<button class="btn danger" data-tga="deleteAuthor" data-cid="${esc(t.cid)}" data-name="${esc(t.author || t.cid)}">Tous ses tags</button>` : ''}</td></tr>`).join('');

        return `
            <div class="stats">
                <div class="stat"><b>${d.total}</b><span>Tag(s) sur la map</span></div>
                <div class="stat"><b>${d.authors}</b><span>Auteur(s)</span></div>
                <div class="stat"><b>${d.zones}</b><span>Territoire(s) tagué(s)</span></div>
                <div class="stat"><b>${d.settings.enabled ? 'Activés' : 'Coupés'}</b><span>Tags</span></div>
            </div>
            <div class="section"><h2>🎨 Fonctionnement</h2>
                <p class="hint">Un joueur utilise une <b>Bombe de peinture</b> (<code>spraycan</code>) : il écrit son tag, choisit la couleur et le style, vise un mur
                    (<b>molette</b> pour la taille, <span class="keycap">E</span> pour peindre). Les tags sont <b>enregistrés en base</b> : ils restent après un redémarrage.
                    On les efface avec un <b>Solvant anti-graffiti</b> (<code>sprayremover</code>), ici, ou en jeu avec <code>/tagclean</code> (le plus proche, 6 m).
                    <code>/taginfo</code> montre l'auteur du tag le plus proche. Chaque tag peint ou effacé est écrit dans les Logs.</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-bottom:12px">
                    ${tog('enabled', s.enabled ? 'Tags activés' : 'Tags coupés', 'Coupés : plus personne ne peut peindre (les tags existants restent).')}
                    ${tog('territoryOnly', 'Seulement dans les territoires', 'Zones de l\'éditeur de map cochées « Territoire de vente ».')}
                    ${tog('requireGroup', 'Réservés aux groupes illégaux', 'Sinon, tout joueur avec une bombe peut taguer.')}
                    ${tog('overwrite', 'Repasse autorisée', 'Peindre sur un tag (moins de 1 m) le remplace.')}
                    ${tog('consumeSpray', 'Bombe utilisée', 'Une bombe de peinture par tag.')}
                    ${tog('consumeRemover', 'Solvant utilisé', 'Un solvant par tag effacé.')}
                </div>
                <div class="form-grid" style="display:grid;grid-template-columns:repeat(4,1fr);gap:12px;max-width:1100px">
                    ${num('cooldown', 'Délai entre deux tags (s)', 'min="0"')}
                    ${num('maxPerPlayer', 'Tags par personnage (max)', 'min="1"')}
                    ${num('maxPerZone', 'Tags par territoire (max)', 'min="1"')}
                    ${num('expireDays', 'Effacés après (jours, 0 = jamais)', 'min="0"')}
                    ${num('cleanReward', 'Prime par tag effacé ($)', 'min="0"')}
                </div>
                <p class="hint" style="margin-top:8px">Au-delà des maximums, le <b>plus ancien</b> tag du joueur (ou du territoire) disparaît.</p>
                <div class="field" style="margin-top:12px;max-width:1100px"><label>Mots interdits (un par ligne)</label>
                    <textarea class="input" data-tgw style="min-height:140px">${esc((s.blacklist || []).join('\n'))}</textarea></div>
                <p class="hint">Repérés malgré les majuscules, accents, lettres répétées, espaces, points et l33t (« P.u.u.t.3 » = « pute »).
                    Un mot de <b>6 lettres et plus</b> est refusé partout, même collé à un autre. Un mot plus court n'est refusé qu'<b>écrit seul</b>
                    (« pute » oui, « dispute » non), sauf s'il commence par <b>*</b> (« *nazi » : cherché partout).</p>
                <div class="btn-row" style="margin-top:10px"><button class="btn primary" data-tga="save">Enregistrer</button><button class="btn" data-tga="cancel">Annuler les modifications</button>
                    <button class="btn" data-tga="reset">Valeurs par défaut</button></div>
            </div>
            <div class="section"><h2>Tags sur la map</h2>
                <div class="btn-row" style="margin-bottom:10px">
                    <input class="input" data-tgq placeholder="Rechercher : texte, auteur, citizenid, groupe, territoire…" value="${esc(G.q)}" style="max-width:420px">
                    ${Object.values(zones).length ? `<select class="input" data-tgz style="max-width:280px"><option value="">Supprimer une zone…</option>${Object.values(zones).map((z) => `<option value="${z.id == null ? 'none' : z.id}">${esc(z.name)} (${z.n})</option>`).join('')}</select>` : ''}
                    <button class="btn danger" data-tga="deleteAll" ${d.total ? '' : 'disabled'}>Tout supprimer</button>
                </div>
                <table class="loot wide"><tr><th>Tag</th><th>Auteur</th><th>Groupe</th><th>Territoire</th><th style="width:150px">Date</th><th style="width:330px"></th></tr>
                    ${rows || `<tr><td colspan="6" class="muted">${d.total ? 'Aucun tag ne correspond.' : 'Aucun tag pour le moment.'}</td></tr>`}</table>
                ${d.total > (d.tags || []).length ? `<p class="hint" style="margin-top:8px">Seuls les ${(d.tags || []).length} plus récents sont affichés (sur ${d.total}).</p>` : ''}
            </div>`;
    };

    document.addEventListener('input', (ev) => {
        if (!isOpen || tab !== 'tags') return;
        const t = ev.target;
        if (t.dataset.tgf !== undefined && G.draft) G.draft[t.dataset.tgf] = Number(t.value);
        if (t.dataset.tgw !== undefined && G.draft) G.draft.blacklist = t.value.split('\n').map((w) => w.trim()).filter(Boolean);
        if (t.dataset.tgq !== undefined) {
            G.q = t.value;
            render();
            const i = document.querySelector('[data-tgq]');
            if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
        }
    });
    document.addEventListener('change', async (ev) => {
        if (!isOpen || tab !== 'tags') return;
        const t = ev.target;
        if (t.dataset.tgz === undefined || !t.value) return;
        const z = t.value === 'none' ? undefined : Number(t.value);
        const label = t.options[t.selectedIndex].textContent;
        t.value = '';
        if (await confirmBox('Supprimer les tags de cette zone ?', `${label} : tous ses tags seront effacés pour tout le monde.`)) send('deleteZone', { zoneId: z });
    });
    document.addEventListener('click', async (ev) => {
        if (!isOpen || tab !== 'tags') return;
        let n;
        if ((n = ev.target.closest('[data-tgb]')) && G.draft) { G.draft[n.dataset.tgb] = !G.draft[n.dataset.tgb]; return render(); }
        if (!(n = ev.target.closest('[data-tga]')) || n.disabled) return;
        switch (n.dataset.tga) {
            case 'save': send('save', G.draft); G.draft = null; return;
            case 'cancel': G.draft = null; return render();
            case 'reset': if (await confirmBox('Valeurs par défaut ?', 'Les réglages et les mots interdits reviennent à ceux du fichier config.lua.')) { G.draft = null; send('reset'); } return;
            case 'goto': send('goto', { id: Number(n.dataset.id) }); post('close'); return;
            case 'delete': if (await confirmBox('Supprimer ce tag ?', 'Il disparaît pour tout le monde.')) send('delete', { id: Number(n.dataset.id) }); return;
            case 'deleteAuthor': if (await confirmBox(`Supprimer tous les tags de ${n.dataset.name} ?`, 'Tous les tags de ce personnage disparaissent pour tout le monde.')) send('deleteAuthor', { cid: n.dataset.cid }); return;
            case 'deleteAll': if (await confirmBox('Supprimer TOUS les tags ?', 'Toutes les maps sont nettoyées. Impossible de revenir en arrière.')) send('deleteAll'); return;
        }
    });
})();
