/* =========================================================
   MÉTIERS › GESTION DES MÉTIERS (permission « jobs_manage »)
   Tous les métiers du serveur se paramètrent ici : informations,
   grades et salaires, points (service, coffre, garage, bureau du
   patron) posés à ta position, tenues de service.
   + fenêtres côté joueurs : garage de service et bureau du patron.
   ========================================================= */
(() => {
    TABS.push({
        id: 'jobsmgr', group: 5, parent: 'jobs', label: 'Gestion des métiers', ico: '🧰',
        sub: 'Paramètre n\'importe quel métier : grades, salaires, points, véhicules, tenues.',
        show: () => has('jobs_manage') && !!(D && D.jobsmgr),
    });

    const JM = { job: null, sub: 'info', q: '', draft: null, draftFor: null, ptype: 'service', veh: {} };
    const TYPE_ICO = { service: '🟢', stash: '📦', garage: '🚓', boss: '💼' };
    const TYPE_HELP = {
        service: 'Prise / fin de service (la tenue de service se met toute seule).',
        stash: 'Coffre partagé du métier.',
        garage: 'Véhicules de service par grade : sortie et rangement.',
        boss: 'Bureau du patron : recruter, changer les grades, renvoyer, solde du compte.',
    };
    const act = (name, data) => action(name, data);
    const jobOf = (name) => (D.jobsmgr.jobs || []).find((j) => j.name === name);
    const pointsOf = (name) => (D.jobsmgr.points || []).filter((p) => p.job === name);
    const gradeLabel = (g) => g.label || g.name || `Grade ${g.level}`;

    // Ouvrir un métier depuis l'onglet Métiers
    window.JobsMgr = { open: (name) => { JM.job = name; JM.sub = 'info'; JM.draft = null; tab = 'jobsmgr'; render(); } };

    function draftFor(j) {
        if (JM.draft && JM.draftFor === j.name) return JM.draft;
        const o = (D.jobsmgr.settings || {})[j.name];
        const grades = o ? o.grades.map((g) => ({ ...g }))
            : (j.grades || []).slice().sort((a, b) => a.level - b.level).map((g) => ({ label: gradeLabel(g), payment: g.payment || 0, isboss: !!g.isboss }));
        JM.draft = { label: o ? o.label : j.label, type: o ? o.type || '' : j.type || '', defaultDuty: o ? o.defaultDuty : !!j.defaultDuty,
            offDutyPay: o ? o.offDutyPay : !!j.offDutyPay, grades: grades.length ? grades : [{ label: 'Employé', payment: 50, isboss: false }] };
        JM.draftFor = j.name;
        return JM.draft;
    }

    VIEWS.jobsmgr = () => (JM.job && jobOf(JM.job) ? jobView(jobOf(JM.job)) : listView());

    /* ---------- Liste des métiers ---------- */
    function listView() {
        const q = JM.q.toLowerCase();
        const jobs = D.jobsmgr.jobs.filter((j) => !q || j.label.toLowerCase().includes(q) || j.name.toLowerCase().includes(q));
        return `
            <p class="hint">Choisis un métier pour le paramétrer : grades et salaires, points (prise de service, coffre, garage, bureau du patron)
                posés à ta position, véhicules de service, tenues. Les métiers marqués « page Elyzea » ont leur propre page dans Métiers.</p>
            <div class="inline" style="margin-bottom:12px;max-width:760px">
                <input class="input" id="jm-q" placeholder="Rechercher un métier" value="${esc(JM.q)}">
                <button class="btn primary" data-jm="create">＋ Créer un métier</button>
            </div>
            <table><tr><th>Métier</th><th>Identifiant</th><th>Grades</th><th>Points</th><th></th></tr>
                ${jobs.map((j) => {
                    const pts = pointsOf(j.name).length;
                    return `<tr><td><strong>${esc(j.label)}</strong> ${j.elyzea ? '<span class="badge" style="color:var(--signal)">Paramétré</span>' : ''}</td>
                        <td><span class="keycap">${esc(j.name)}</span></td><td class="muted">${(j.grades || []).length}</td><td class="muted">${pts}</td>
                        <td style="text-align:right">${j.managedBy ? `<span class="muted" style="font-size:12px">page Elyzea</span>`
                            : `<button class="btn" data-jm="open" data-name="${esc(j.name)}">Paramétrer</button>`}</td></tr>`;
                }).join('')}
            </table>`;
    }

    /* ---------- Page d'un métier ---------- */
    function jobView(j) {
        const subs = [['info', 'Informations et grades'], ['points', `Points (${pointsOf(j.name).length})`], ['uniforms', 'Tenues et essai']];
        return `
            <div class="inline" style="margin-bottom:12px;align-items:center">
                <button class="btn" data-jm="back">← Tous les métiers</button>
                <h2 style="margin:0 0 0 6px;flex:1">${esc(j.label)} <span class="keycap">${esc(j.name)}</span></h2>
            </div>
            <div class="segmented">${subs.map(([id, l]) => `<button class="seg ${JM.sub === id ? 'active' : ''}" data-jms="${id}">${l}</button>`).join('')}</div>
            ${JM.sub === 'info' ? infoView(j) : JM.sub === 'points' ? pointsView(j) : uniformsView(j)}`;
    }

    function infoView(j) {
        const d = draftFor(j);
        return `
            <div class="section"><h2>Informations</h2>
                <div class="form-grid" style="grid-template-columns:1fr 1fr;max-width:760px">
                    <div><label>Nom affiché</label><input class="input" data-jmf="label" value="${esc(d.label)}" maxlength="50"></div>
                    <div><label>Type (facultatif : leo, ems, mechanic…)</label><input class="input" data-jmf="type" value="${esc(d.type)}" maxlength="30"></div>
                </div>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(260px,1fr));margin-top:12px;max-width:760px">
                    <div class="tile toggle-tile ${d.defaultDuty ? 'on' : ''}" data-jmt="defaultDuty"><div><strong>En service à la connexion</strong><span>Sinon : point « Prise de service »</span></div><div class="switch"></div></div>
                    <div class="tile toggle-tile ${d.offDutyPay ? 'on' : ''}" data-jmt="offDutyPay"><div><strong>Payé hors service</strong><span>Salaire même hors service</span></div><div class="switch"></div></div>
                </div>
            </div>
            <div class="section"><h2>Grades et salaires</h2>
                <p class="hint">Du plus bas (grade 0) au plus haut. Le « patron » a accès au bureau du patron et au compte de l'entreprise.</p>
                <table><tr><th style="width:70px">Niveau</th><th>Nom du grade</th><th style="width:150px">Salaire ($)</th><th style="width:90px;text-align:center">Patron</th><th></th></tr>
                    ${d.grades.map((g, i) => `<tr>
                        <td class="muted">${i}</td>
                        <td><input class="input" data-jmg="${i}:label" value="${esc(g.label)}" maxlength="40"></td>
                        <td><input class="input" type="number" min="0" data-jmg="${i}:payment" value="${Number(g.payment) || 0}"></td>
                        <td style="text-align:center"><input type="checkbox" data-jmg="${i}:isboss" ${g.isboss ? 'checked' : ''}></td>
                        <td style="text-align:right;white-space:nowrap"><button class="btn" data-jm="gup" data-i="${i}" ${i === 0 ? 'disabled' : ''}>↑</button>
                            <button class="btn" data-jm="gdown" data-i="${i}" ${i === d.grades.length - 1 ? 'disabled' : ''}>↓</button>
                            <button class="btn danger" data-jm="gdel" data-i="${i}" ${d.grades.length === 1 ? 'disabled' : ''}>✕</button></td></tr>`).join('')}
                </table>
                <div class="btn-row" style="margin-top:10px"><button class="btn" data-jm="gadd">＋ Ajouter un grade</button></div>
            </div>
            <div class="btn-row">
                <button class="btn primary" data-jm="save">Enregistrer le métier</button>
                <button class="btn" data-jm="reset">Annuler les changements</button>
                <span style="flex:1"></span>
                ${j.elyzea ? '<button class="btn danger" data-jm="delete">Retirer les réglages Elyzea / supprimer</button>' : ''}
            </div>`;
    }

    function pointsView(j) {
        const d = draftFor(j);
        const pts = pointsOf(j.name);
        const gradeOpts = (cur) => d.grades.map((g, i) => `<option value="${i}" ${Number(cur) === i ? 'selected' : ''}>${i} · ${esc(g.label)}</option>`).join('');
        return `
            <div class="section"><h2>Ajouter un point à ta position</h2>
                <div class="chips" style="margin-bottom:8px">${Object.entries(D.jobsmgr.types).map(([k, l]) => `<button class="chip ${JM.ptype === k ? 'on' : ''}" data-jmp="${k}">${TYPE_ICO[k]} ${esc(l)}</button>`).join('')}</div>
                <p class="hint">${TYPE_HELP[JM.ptype]} Place-toi à l'endroit voulu (pour un garage : là où le joueur viendra demander le véhicule).</p>
                <div class="form-grid" style="grid-template-columns:2fr 1fr 1fr auto;max-width:900px;align-items:end">
                    <div><label>Nom</label><input class="input" id="jm-plabel" placeholder="${esc(D.jobsmgr.types[JM.ptype])}"></div>
                    <div><label>Grade minimum</label><select class="input" id="jm-pgrade">${gradeOpts(0)}</select></div>
                    <div><label>Rayon (m)</label><input class="input" type="number" id="jm-pradius" min="0.5" max="10" step="0.5" value="1.5"></div>
                    <button class="btn primary" data-jm="padd">📍 Ajouter ici</button>
                </div>
            </div>
            <div class="section"><h2>Points du métier</h2>
                ${pts.length ? pts.map((p) => `<div class="card" style="margin-bottom:10px;padding:12px 14px" data-jmpoint="${p.id}">
                    <div class="inline" style="align-items:center;flex-wrap:wrap">
                        <strong style="flex:1">${TYPE_ICO[p.type]} ${esc(p.label)} <span class="muted" style="font-weight:400">· ${esc(D.jobsmgr.types[p.type])} · ${p.x.toFixed(1)}, ${p.y.toFixed(1)}</span></strong>
                        <label class="muted" style="font-size:12px">Grade min.</label><select class="input" style="width:auto" data-jmpf="minGrade">${gradeOpts(p.minGrade)}</select>
                        <label class="muted" style="font-size:12px">Rayon</label><input class="input" style="width:80px" type="number" min="0.5" max="10" step="0.5" data-jmpf="radius" value="${p.radius || 1.5}">
                        <button class="btn ${p.blip ? 'on' : ''}" data-jm="pblip" title="Icône sur la carte (pour les membres du métier)">🗺️ ${p.blip ? 'Visible' : 'Masqué'}</button>
                        <button class="btn" data-jm="ptp">Y aller</button>
                        <button class="btn" data-jm="phere" title="Déplacer le point à ta position">📍</button>
                        <button class="btn danger" data-jm="pdel">✕</button>
                    </div>
                    ${p.type === 'stash' ? `<div class="inline" style="margin-top:10px;align-items:end;max-width:520px">
                        <div><label class="muted" style="font-size:12px">Emplacements</label><input class="input" type="number" min="5" max="500" data-jmpf="slots" value="${p.slots || 50}"></div>
                        <div><label class="muted" style="font-size:12px">Poids max (kg)</label><input class="input" type="number" min="10" max="5000" data-jmpf="weight" value="${p.weight || 200}"></div></div>` : ''}
                    ${p.type === 'garage' ? garageEditor(p, gradeOpts) : ''}
                </div>`).join('') : '<div class="empty">Aucun point : ajoute la prise de service, un coffre, un garage, le bureau du patron…</div>'}
            </div>`;
    }

    function garageEditor(p, gradeOpts) {
        const list = JM.veh[p.id] || (JM.veh[p.id] = (p.vehicles || []).map((v) => ({ ...v })));
        return `<div style="margin-top:10px">
            <p class="hint" style="margin-bottom:6px">Sortie des véhicules : ${p.spawn ? `${p.spawn.x.toFixed(1)}, ${p.spawn.y.toFixed(1)} (orientée ${Math.round(p.spawn.h)}°)` : 'sur le point lui-même'}.
                <button class="btn" data-jm="pspawn" style="margin-left:6px">📍 Sortie ici (tourné dans le sens du véhicule)</button></p>
            <table><tr><th>Modèle</th><th>Nom affiché</th><th>Grade minimum</th><th></th></tr>
                ${list.map((v, i) => `<tr><td><input class="input" data-jmv="${p.id}:${i}:model" value="${esc(v.model)}" placeholder="police"></td>
                    <td><input class="input" data-jmv="${p.id}:${i}:label" value="${esc(v.label)}" placeholder="Voiture de patrouille"></td>
                    <td><select class="input" data-jmv="${p.id}:${i}:minGrade">${gradeOpts(v.minGrade || 0)}</select></td>
                    <td><button class="btn danger" data-jm="vdel" data-i="${i}">✕</button></td></tr>`).join('')}
            </table>
            <div class="btn-row" style="margin-top:8px"><button class="btn" data-jm="vadd">＋ Véhicule</button><button class="btn primary" data-jm="vsave">Enregistrer les véhicules</button></div>
        </div>`;
    }

    function uniformsView(j) {
        if (!window.JobTools || !JobTools.available('custom')) return '<div class="empty">Tenues indisponibles.</div>';
        JobTools.select('custom', j.name);
        return JobTools.sections('custom');
    }

    /* ---------- Événements ---------- */
    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'jobsmgr') return;
        const t = e.target;
        if (t.id === 'jm-q') {
            JM.q = t.value;
            const pos = t.selectionStart;
            render();
            const el = document.getElementById('jm-q'); if (el) { el.focus(); el.setSelectionRange(pos, pos); }
            return;
        }
        if (!JM.draft) return;
        if (t.dataset.jmf) JM.draft[t.dataset.jmf] = t.value;
        if (t.dataset.jmg) {
            const [i, k] = t.dataset.jmg.split(':');
            const g = JM.draft.grades[Number(i)];
            if (g) g[k] = k === 'isboss' ? t.checked : k === 'payment' ? Number(t.value) || 0 : t.value;
        }
        if (t.dataset.jmv) {
            const [pid, i, k] = t.dataset.jmv.split(':');
            const v = (JM.veh[pid] || [])[Number(i)];
            if (v) v[k] = k === 'minGrade' ? Number(t.value) : t.value;
        }
    });
    document.addEventListener('change', (e) => {
        if (!isOpen || tab !== 'jobsmgr') return;
        const t = e.target;
        if (t.dataset.jmg && t.type === 'checkbox') { const [i] = t.dataset.jmg.split(':'); JM.draft.grades[Number(i)].isboss = t.checked; }
        if (t.dataset.jmv && t.tagName === 'SELECT') { const [pid, i] = t.dataset.jmv.split(':'); (JM.veh[pid] || [])[Number(i)].minGrade = Number(t.value); }
        const card = t.closest('[data-jmpoint]');
        if (card && t.dataset.jmpf) act('jm_point_update', { id: Number(card.dataset.jmpoint), [t.dataset.jmpf]: Number(t.value), quiet: true });
    });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'jobsmgr') return;
        let n;
        if ((n = e.target.closest('[data-jms]'))) { JM.sub = n.dataset.jms; return render(); }
        if ((n = e.target.closest('[data-jmp]'))) { JM.ptype = n.dataset.jmp; return render(); }
        if ((n = e.target.closest('[data-jmt]'))) { JM.draft[n.dataset.jmt] = !JM.draft[n.dataset.jmt]; return render(); }
        if (!(n = e.target.closest('[data-jm]')) || n.disabled) return;
        const j = JM.job && jobOf(JM.job);
        const card = n.closest('[data-jmpoint]');
        const pid = card ? Number(card.dataset.jmpoint) : null;
        const p = pid && D.jobsmgr.points.find((x) => x.id === pid);
        const i = Number(n.dataset.i);
        switch (n.dataset.jm) {
            case 'open': return window.JobsMgr.open(n.dataset.name);
            case 'back': JM.job = null; JM.draft = null; return render();
            case 'create': {
                const v = await formModal('Créer un métier', [
                    { name: 'name', label: 'Identifiant (minuscules, sans espace : taxi, burgershot…)', value: '' },
                    { name: 'label', label: 'Nom affiché', value: '' },
                ], 'Créer');
                if (!v) return;
                const name = String(v.name || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
                if (!name) return toast('Identifiant invalide.', 'error');
                act('jm_job_save', { name, isNew: true, label: v.label || name, type: '', defaultDuty: false, offDutyPay: false,
                    grades: [{ label: 'Employé', payment: 50 }, { label: 'Chef', payment: 90 }, { label: 'Patron', payment: 150, isboss: true }] });
                JM.job = name; JM.draft = null;
                return;
            }
            case 'gadd': JM.draft.grades.push({ label: 'Nouveau grade', payment: 0, isboss: false }); return render();
            case 'gdel': JM.draft.grades.splice(i, 1); return render();
            case 'gup': { const g = JM.draft.grades; [g[i - 1], g[i]] = [g[i], g[i - 1]]; return render(); }
            case 'gdown': { const g = JM.draft.grades; [g[i + 1], g[i]] = [g[i], g[i + 1]]; return render(); }
            case 'save': act('jm_job_save', { name: j.name, ...JM.draft }); JM.draft = null; return;
            case 'reset': JM.draft = null; return render();
            case 'delete':
                if (!(await confirmBox(`Retirer les réglages de « ${j.label} » ?`, 'Un métier créé ici est supprimé ; un métier existant reprend sa configuration d\'origine au prochain redémarrage. Ses points sont supprimés.'))) return;
                act('jm_job_delete', { name: j.name }); JM.job = null; JM.draft = null; return;
            case 'padd': {
                const label = (document.getElementById('jm-plabel') || {}).value || '';
                const minGrade = Number((document.getElementById('jm-pgrade') || {}).value || 0);
                const radius = Number((document.getElementById('jm-pradius') || {}).value || 1.5);
                return act('jm_point_add', { job: j.name, type: JM.ptype, label, minGrade, radius });
            }
            case 'pblip': return act('jm_point_update', { id: pid, blip: !p.blip, quiet: true });
            case 'ptp': post('close'); return act('jm_point_tp', { id: pid });
            case 'phere': if (await confirmBox('Déplacer le point ici ?', 'Il prend ta position et ton orientation.')) act('jm_point_update', { id: pid, here: true }); return;
            case 'pdel': if (await confirmBox(`Supprimer « ${p.label} » ?`, '')) act('jm_point_delete', { id: pid }); return;
            case 'pspawn': return act('jm_point_update', { id: pid, spawnHere: true });
            case 'vadd': (JM.veh[pid] = JM.veh[pid] || []).push({ model: '', label: '', minGrade: 0 }); return render();
            case 'vdel': JM.veh[pid].splice(i, 1); return render();
            case 'vsave': act('jm_point_update', { id: pid, vehicles: JM.veh[pid] }); delete JM.veh[pid]; return;
        }
    });

    /* =========================================================
       Fenêtres côté joueurs : garage de service, bureau du patron
       ========================================================= */
    const panel = document.createElement('div');
    panel.id = 'jobpanel';
    panel.className = 'jp hidden';
    document.body.appendChild(panel);
    let JP = null;
    const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
    const closeJP = () => { panel.classList.add('hidden'); JP = null; post('jp_close'); };

    function drawJP() {
        const d = JP.data;
        if (JP.kind === 'garage') {
            panel.innerHTML = `<div class="jp-card"><div class="jp-head"><b>🚓 ${esc(d.title)}</b><button class="btn" data-jp="close">✕</button></div>
                ${d.vehicles.length ? `<div class="jp-list">${d.vehicles.map((v) => `<button class="tile" data-jp="spawn" data-i="${v.index}"><strong>${esc(v.label)}</strong><span>${esc(v.model)}</span></button>`).join('')}</div>`
                    : '<div class="empty">Aucun véhicule disponible pour ton grade.</div>'}</div>`;
            return;
        }
        const gradeOpts = (cur) => d.grades.filter((g) => g.level < d.myGrade || g.level === cur)
            .map((g) => `<option value="${g.level}" ${g.level === cur ? 'selected' : ''}>${g.level} · ${esc(g.label || g.name)}</option>`).join('');
        panel.innerHTML = `<div class="jp-card wide"><div class="jp-head"><b>💼 ${esc(d.title)}</b><button class="btn" data-jp="close">✕</button></div>
            <div class="inline" style="margin-bottom:12px;align-items:center">
                <div class="stat" style="flex:1"><b>${d.balance != null ? money(d.balance) : '—'}</b><span>Compte de l'entreprise</span></div>
                <div class="stat" style="flex:1"><b>${d.members.length}</b><span>Employés</span></div>
                <button class="btn primary" data-jp="hire">＋ Recruter la personne la plus proche</button>
            </div>
            <div style="max-height:52vh;overflow-y:auto"><table><tr><th>Employé</th><th>Statut</th><th>Grade</th><th></th></tr>
                ${d.members.map((m) => `<tr data-cid="${esc(m.citizenid)}"><td><strong>${esc(m.name)}</strong></td>
                    <td>${m.online ? `<span class="badge" style="color:${m.duty ? 'var(--ok)' : 'var(--info)'}">${m.duty ? 'En service' : 'En ville'}</span>` : '<span class="badge muted">Hors ligne</span>'}</td>
                    <td>${m.grade < d.myGrade ? `<select class="input jp-grade">${gradeOpts(m.grade)}</select>` : `<span class="muted">${esc((d.grades.find((g) => g.level === m.grade) || {}).label || m.grade)}</span>`}</td>
                    <td style="text-align:right;white-space:nowrap">${m.grade < d.myGrade ? '<button class="btn" data-jp="grade">OK</button> <button class="btn danger" data-jp="fire">Renvoyer</button>' : ''}</td></tr>`).join('')}
            </table></div></div>`;
    }

    window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.action !== 'jobpanel') return;
        JP = { kind: m.kind, data: m.data };
        panel.classList.remove('hidden');
        drawJP();
    });
    document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && JP) closeJP(); });
    panel.addEventListener('click', (e) => {
        const b = e.target.closest('[data-jp]');
        if (!b || !JP) return;
        const d = JP.data;
        const row = b.closest('[data-cid]');
        switch (b.dataset.jp) {
            case 'close': return closeJP();
            case 'spawn': panel.classList.add('hidden'); JP = null; return post('jp_spawn', { id: d.id, index: Number(b.dataset.i) });
            case 'hire': return post('jp_boss', { id: d.id, kind: 'hire' });
            case 'grade': return post('jp_boss', { id: d.id, kind: 'grade', data: { citizenid: row.dataset.cid, grade: Number(row.querySelector('.jp-grade').value) } });
            case 'fire':
                // Deuxième clic pour confirmer (la fenêtre de confirmation du menu staff n'existe pas pour les joueurs)
                if (!b.classList.contains('confirm')) { b.classList.add('confirm'); b.textContent = 'Confirmer ?'; return; }
                return post('jp_boss', { id: d.id, kind: 'fire', data: { citizenid: row.dataset.cid } });
        }
    });
})();
