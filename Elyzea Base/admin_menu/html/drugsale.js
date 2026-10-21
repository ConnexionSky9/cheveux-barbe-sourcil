/* =========================================================
   VENTE DE DROGUE (ressource elyzea_illegal, permission « drugsale_manage »)
   Réglages du mode vente (F5) : clients PNJ, prix, vols, appels à la police.
   ========================================================= */
(() => {
    TABS.push({
        id: 'drugsale', group: 6, label: 'Vente de drogue', ico: '🌿',
        sub: 'Mode vente du F5 : profils de clients (accro, riche, fêtard), drogues et prix, vols, couteau, appels à la police.',
        show: () => has('drugsale_manage') && !!(D && D.drugsale),
    });

    const G = { draft: null };
    const send = (name, data = {}) => action('drugsale', { name, data });
    const PAY = { dirty: 'Argent sale', clean: 'Liquide (argent propre)' };

    const PIDS = () => ((D.drugsale.settings || {}).profileOrder || ['addict', 'rich', 'party']).filter((p) => G.draft && G.draft.profiles && G.draft.profiles[p]);
    const pv = (o, path) => path.split('.').reduce((a, k) => (a ? a[k] : ''), o);
    function profileCard(pid, p) {
        const f = (path, label, extra = '') => `<div class="field"><label>${label}</label><input class="input" type="number" data-dsp="${pid}.${path}" value="${esc(pv(p, path))}" ${extra}></div>`;
        const buy = Math.max(0, 100 - p.steal - p.knife - p.police);
        return `<div class="card" style="padding:14px">
            <div class="inline" style="justify-content:space-between;margin-bottom:8px"><strong style="font-size:16px">${esc(p.icon)} ${esc(p.label)}</strong>
                <div class="tile toggle-tile ${p.enabled ? 'on' : ''}" data-dspb="${pid}" style="padding:6px 10px;min-height:0"><div><strong>${p.enabled ? 'Actif' : 'Désactivé'}</strong></div><div class="switch"></div></div></div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">
                <div class="field"><label>Nom</label><input class="input" data-dsp="${pid}.label" value="${esc(p.label)}"></div>
                <div class="field"><label>Icône</label><input class="input" data-dsp="${pid}.icon" value="${esc(p.icon)}"></div>
                ${f('weight', 'Fréquence', 'min="0" max="1000"')}${f('retries', 'Nouveaux prix possibles', 'min="0" max="5"')}
                ${f('qty.min', 'Quantité : min', 'min="1" max="50"')}${f('qty.max', 'Quantité : max', 'min="1" max="50"')}
                ${f('budget.min', 'Budget : min ($)', 'min="1"')}${f('budget.max', 'Budget : max ($)', 'min="1"')}
                ${f('accept.from', 'Prix max accepté : de (%)', 'min="1" max="300"')}${f('accept.to', 'à (%)', 'min="1" max="300"')}
                ${f('steal', 'Vol à l\'arrachée (%)', 'min="0" max="100"')}${f('knife', 'Couteau (%)', 'min="0" max="100"')}
                ${f('police', 'Appelle la police (%)', 'min="0" max="100"')}
                <div class="field"><label>Sur 100 clients</label><div class="hint" style="margin:6px 0 0">${buy} achètent · ${p.steal} volent · ${p.knife} couteau · ${p.police} police</div></div>
            </div>
            <div class="field" style="margin-top:8px"><label>Modèles de PNJ (séparés par des virgules)</label><input class="input" data-dspm="${pid}" value="${esc((p.models || []).join(', '))}"></div></div>`;
    }

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
        const autoRange = (x, pid) => { const p = s.profiles[pid].accept; return [Math.round(x.max * p.from / 100), Math.round(x.max * p.to / 100)]; };
        const drugs = (s.drugs || []).map((x, i) => `<tr>
            <td><input class="input" list="ds-items" data-dsd="${i}" data-k="item" value="${esc(x.item)}" placeholder="nom de l'objet (ex : weed_pouch)"></td>
            <td><input class="input" data-dsd="${i}" data-k="label" value="${esc(x.label)}" placeholder="Nom affiché"></td>
            <td><input class="input" type="number" min="1" data-dsd="${i}" data-k="min" value="${esc(x.min)}" style="width:85px"></td>
            <td><input class="input" type="number" min="1" data-dsd="${i}" data-k="max" value="${esc(x.max)}" style="width:85px"></td>
            ${PIDS().map((pid) => {
                const off = !!(x.skip && x.skip[pid]); const ov = (x.over && x.over[pid]) || {}; const [alo, ahi] = autoRange(x, pid);
                return `<td><div class="inline" style="gap:4px;align-items:center"><input type="checkbox" data-dsk="${i}|${pid}" ${off ? '' : 'checked'} title="Achète cette drogue">
                    <input class="input" type="number" min="1" data-dso="${i}|${pid}|lo" value="${ov.lo ?? ''}" placeholder="${alo}" style="width:70px" ${off ? 'disabled' : ''}>
                    <span class="muted">à</span><input class="input" type="number" min="1" data-dso="${i}|${pid}|hi" value="${ov.hi ?? ''}" placeholder="${ahi}" style="width:70px" ${off ? 'disabled' : ''}></div></td>`;
            }).join('')}
            <td style="text-align:right"><button class="btn danger" data-dsa="delDrug" data-i="${i}">Retirer</button></td></tr>`).join('');
        const have = new Set((s.drugs || []).map((x) => x.item));
        const known = new Set((d.items || []).map((it) => it.name));
        const missing = (d.defaults || []).filter((x) => !have.has(x.item) && (!known.size || known.has(x.item)));
        const active = (d.active || []).map((a) => `<tr><td>${esc(a.name || '?')} <span class="muted">[${a.id}]</span></td><td>${esc(a.selling || 'Tout')}</td><td>${a.sales}</td><td>${Number(a.earned || 0).toLocaleString('fr-FR')} $</td></tr>`).join('');
        return `
            <div class="stats">
                <div class="stat"><b>${d.settings.enabled ? 'Activée' : 'Coupée'}</b><span>Vente de drogue</span></div>
                <div class="stat"><b>${(d.active || []).length}</b><span>Vendeur(s) en ce moment</span></div>
                <div class="stat"><b>${d.police}</b><span>Policier(s) en service</span></div>
                <div class="stat"><b>${(d.settings.drugs || []).length}</b><span>Drogue(s) vendable(s)</span></div>
            </div>
            ${d.stats ? `<p class="hint" style="margin:-4px 0 14px">Depuis le démarrage : ${d.stats.buyers} client(s) · ${d.stats.sold} unité(s) vendue(s) pour ${Number(d.stats.earned || 0).toLocaleString('fr-FR')} $ ·
                ${d.stats.tooExpensive} « trop cher » · ${d.stats.stolen} unité(s) volée(s) · ${d.stats.knife} couteau(x) · ${d.stats.police} appel(s) à la police.</p>` : ''}
            <div class="section"><h2>🌿 Fonctionnement</h2>
                <p class="hint">Dans son menu <span class="keycap">F5</span>, le joueur choisit ce qu'il vend parmi les drogues qu'il a sur lui (une, plusieurs ou tout) puis active le mode vente.
                    Des clients PNJ viennent à pied (l'<b>accro</b>, le <b>riche</b>, le <b>fêtard</b>) et demandent une des drogues choisies. <span class="keycap">E</span> : le joueur fixe son
                    <b>prix à l'unité</b> au dollar près dans la fourchette de la drogue ; le client accepte ou trouve ça trop cher. <span class="keycap">G</span> : refuser.
                    Un client peut aussi <b>voler</b> et s'enfuir (le frapper, il se rend, puis <span class="keycap">ALT</span> › Fouiller), sortir un <b>couteau</b> et attaquer pour voler
                    (le frapper ou s'enfuir à temps) ou <b>appeler la police</b> : il part en courant, téléphone à la main, et la position est envoyée aux policiers en service.</p>
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
                    ${num('maxPerBuyer', 'Unités par client (plafond)', 'min="1" max="50"')}
                    ${num('waitTime', 'Patience d\'un client (s)', 'min="10" max="300"')}
                    ${num('stealMax', 'Unités volées (max)', 'min="1" max="50"')}
                    ${num('policeRadius', 'Alerte police : précision (m, 0 = exacte)', 'min="0" max="1000"')}
                    ${num('knifeWindow', 'Couteau : temps pour se défendre (s)', 'min="5" max="60"')}
                    ${num('knifeEscape', 'Couteau : distance pour lui échapper (m)', 'min="5" max="100"')}
                    ${num('territoryGain', 'Contrôle gagné par unité vendue (%)', 'min="0" max="100" step="0.5"')}
                </div>
            </div>
            <div class="section"><h2>👥 Profils de clients</h2>
                <p class="hint"><b>Fréquence</b> : chances relatives d'apparition. <b>Budget</b> : argent sur lui, il n'achète jamais plus que ce qu'il peut payer.
                    <b>Prix max accepté</b> : en % du prix maximum de la drogue (tiré au hasard entre les deux valeurs) ; au-dessus, il trouve ça trop cher.
                    <b>Nouveaux prix</b> : combien de fois le vendeur peut baisser son prix après un « trop cher ».</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(330px,1fr))">${PIDS().map((pid) => profileCard(pid, s.profiles[pid])).join('')}</div>
            </div>
            <div class="section"><h2>Drogues vendables et prix</h2>
                <p class="hint"><b>Prix min / max</b> : fourchette dans laquelle le vendeur choisit son prix à l'unité (au dollar près). Pour chaque profil : décoche pour qu'il n'achète pas
                    cette drogue ; « max accepté » vide = calcul automatique avec le % du profil (valeur grise), rempli = fourchette fixe en $. L'objet doit exister dans l'inventaire.</p>
                <datalist id="ds-items">${(d.items || []).map((it) => `<option value="${esc(it.name)}">${esc(it.label)}</option>`).join('')}</datalist>
                <div style="overflow-x:auto"><table class="loot wide"><tr><th>Objet</th><th>Nom affiché</th><th style="width:90px">Prix min ($)</th><th style="width:90px">Prix max ($)</th>
                    ${PIDS().map((pid) => `<th style="min-width:190px">${esc(s.profiles[pid].icon)} ${esc(s.profiles[pid].label)} · max accepté ($)</th>`).join('')}<th style="width:90px"></th></tr>
                    ${drugs || `<tr><td colspan="${5 + PIDS().length}" class="muted">Aucune drogue : personne ne pourra vendre.</td></tr>`}</table></div>
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-dsa="addDrug">+ Ajouter une drogue</button>
                    <button class="btn" data-dsa="addDefaults" ${missing.length ? '' : 'disabled'}>+ Ajouter les drogues du serveur manquantes (${missing.length})</button></div>
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
            ${active ? `<div class="section"><h2>Vendeurs en ce moment</h2><table class="loot wide"><tr><th>Joueur</th><th>Vend</th><th style="width:140px">Unités vendues</th><th style="width:160px">Gains</th></tr>${active}</table></div>` : ''}`;
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
        if (t.dataset.dsp) { const [pid, ...rest] = t.dataset.dsp.split('.'); setPath(G.draft.profiles[pid], rest.join('.'), t.type === 'number' ? Number(t.value) : t.value); }
        if (t.dataset.dspm) G.draft.profiles[t.dataset.dspm].models = t.value.split(',').map((m) => m.trim()).filter(Boolean);
        if (t.dataset.dso) {
            const [i, pid, k] = t.dataset.dso.split('|');
            const x = G.draft.drugs[Number(i)];
            if (!x) return;
            x.over = x.over && !Array.isArray(x.over) ? x.over : {};
            const o = x.over[pid] || {};
            if (t.value === '') delete o[k]; else o[k] = Number(t.value);
            if (o.lo === undefined && o.hi === undefined) delete x.over[pid];
            else { if (o.lo === undefined) o.lo = o.hi; if (o.hi === undefined) o.hi = o.lo; x.over[pid] = o; }
        }
    });
    document.addEventListener('change', (ev) => {
        if (!isOpen || tab !== 'drugsale' || !G.draft) return;
        const t = ev.target;
        if (t.dataset.dsf && t.tagName === 'SELECT') setPath(G.draft, t.dataset.dsf, t.value);
        if (t.dataset.dsk) {
            const [i, pid] = t.dataset.dsk.split('|');
            const x = G.draft.drugs[Number(i)];
            if (x) { x.skip = x.skip && !Array.isArray(x.skip) ? x.skip : {}; if (t.checked) delete x.skip[pid]; else x.skip[pid] = true; render(); }
        }
        if (t.dataset.dsp || t.dataset.dsd !== undefined) render();
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
        if ((n = ev.target.closest('[data-dspb]')) && G.draft) { const p = G.draft.profiles[n.dataset.dspb]; p.enabled = !p.enabled; return render(); }
        if (!(n = ev.target.closest('[data-dsa]')) || n.disabled) return;
        switch (n.dataset.dsa) {
            case 'addDrug': G.draft.drugs = G.draft.drugs || []; G.draft.drugs.push({ item: '', label: '', min: 50, max: 100, skip: {}, over: {} }); return render();
            case 'addDefaults': {
                const have = new Set(G.draft.drugs.map((x) => x.item));
                const known = new Set((D.drugsale.items || []).map((it) => it.name));
                (D.drugsale.defaults || []).forEach((x) => { if (!have.has(x.item) && (!known.size || known.has(x.item))) G.draft.drugs.push(JSON.parse(JSON.stringify({ skip: {}, over: {}, ...x }))); });
                return render();
            }
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
