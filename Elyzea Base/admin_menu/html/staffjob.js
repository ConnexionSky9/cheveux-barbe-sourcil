/* =========================================================
   MES OUTILS › MÉTIER STAFF (permission « staff_job »)
   Ressources « elyzea_police » et « elyzea_ems » : entrer dans le métier, recruter
   un joueur, lui donner un grade (direction comprise), le retirer, revenir à son métier.
   ========================================================= */
(() => {
    TABS.push({
        id: 'staffjob', group: 2, label: 'Métier staff', ico: '👮',
        sub: 'Police / EMS : prends un grade, recrute un joueur, nomme la direction.',
        show: () => has('staff_job') && !!(D && D.staffJob),
    });

    const SJ = { target: '', grade: '', q: '', job: 'police' };
    const send = (name, data = {}) => action('staffjob', { name, data: { ...data, job: SJ.job } });

    VIEWS.staffjob = () => {
        const all = D.staffJob.jobs || [];
        if (!all.some((j) => j.key === SJ.job)) SJ.job = (all[0] || {}).key || 'police';
        const d = all.find((j) => j.key === SJ.job) || { available: false, resource: '?' };
        const L = esc(d.label || 'Métier');
        const switcher = `<div class="chips" style="margin-bottom:10px">${all.map((j) => `<button class="btn ${j.key === SJ.job ? 'on' : ''}" data-sjjob="${j.key}">${esc(j.label)}${j.available ? '' : ' (arrêté)'}</button>`).join('')}</div>`;
        if (!d.available) return `<div class="section"><h2>Métier staff</h2>${switcher}<p class="hint">La ressource « ${esc(d.resource)} » n'est pas démarrée.</p></div>`;
        d.prev = D.staffJob.prev;
        const grades = [...(d.grades || [])].sort((a, b) => b.level - a.level);
        const gName = (g) => `${g.direction ? '👑 ' : ''}${esc(g.name)}`;
        const me = d.me;
        const players = (D.players || []).slice().sort((a, b) => a.id - b.id);
        if (SJ.target && !players.some((p) => String(p.id) === SJ.target)) SJ.target = '';
        if (!SJ.grade && grades.length) SJ.grade = String(grades[grades.length - 1].id);
        const tInfo = SJ.target ? d.members[SJ.target] : null;
        const q = SJ.q.toLowerCase();
        const rows = players.filter((p) => !q || String(p.id) === q || String(p.name).toLowerCase().includes(q)).map((p) => {
            const m = d.members[String(p.id)];
            return `<tr class="${String(p.id) === SJ.target ? 'sel' : ''}" data-sjpick="${p.id}" style="cursor:pointer${String(p.id) === SJ.target ? ';background:rgba(255,255,255,.06)' : ''}">
                <td>${p.id}</td><td>${esc(p.name)}</td>
                <td>${m ? `${esc(m.grade || '?')} <span class="muted">· ${esc(m.matricule || '')}</span>` : '<span class="muted">—</span>'}</td>
                <td>${m ? (m.duty ? '<span style="color:var(--ok)">En service</span>' : '<span class="muted">Hors service</span>') : ''}</td></tr>`;
        }).join('');
        return `<div class="section"><h2>Moi</h2>${switcher}
                <div class="stats">
                    <div class="stat"><b>${me ? esc(me.grade || '?') : `Pas dans le métier ${L}`}</b><span>${me ? `Matricule ${esc(me.matricule || '')}` : `Grade ${L}`}</span></div>
                    <div class="stat"><b style="color:${me && me.duty ? 'var(--ok)' : 'var(--muted)'}">${me && me.duty ? 'En service' : 'Hors service'}</b><span>Service</span></div>
                    <div class="stat"><b>${d.prev ? esc(d.prev) : '—'}</b><span>Métier d'origine</span></div></div>
                ${d.gradesNote ? `<p class="hint" style="color:var(--warn,#f5a524)">⚠️ ${esc(d.gradesNote)} Redémarre la ressource (ensure ${esc(d.resource)}) et regarde la console du serveur.</p>` : ''}
                ${grades.length ? '' : `<p class="hint">Aucun grade trouvé pour ${L}.</p>`}
                <div class="chips" style="margin:10px 0">${grades.map((g) => `<button class="btn ${me && me.gradeId === g.id ? 'on' : ''}" data-sjjoin="${g.id}">${gName(g)}</button>`).join('')}</div>
                <div class="btn-row">
                    <button class="btn ${me && me.duty ? '' : 'primary'}" data-sja="duty" ${me ? '' : 'disabled'}>${me && me.duty ? 'Quitter le service' : 'Prendre le service'}</button>
                    <button class="btn primary" data-sja="back" ${d.prev ? '' : 'disabled'}>↩ Revenir à mon métier d'origine</button></div>
                <p class="hint" style="margin-top:8px">Clique un grade pour entrer dans le métier ${L} (tu passes en service). Ton vrai métier est gardé : « Revenir » te le rend. 👑 = grade direction.</p></div>
            <div class="section"><h2>Recruter / nommer un joueur</h2>
                <div class="btn-row" style="align-items:center;flex-wrap:wrap">
                    <input class="input" id="sjSearch" placeholder="Rechercher (ID ou nom)" value="${esc(SJ.q)}" style="max-width:240px">
                    <select class="input" id="sjGrade" style="max-width:240px">${grades.map((g) => `<option value="${g.id}" ${String(g.id) === SJ.grade ? 'selected' : ''}>${g.direction ? '👑 ' : ''}${esc(g.name)}</option>`).join('')}</select>
                    <button class="btn primary" data-sja="set" ${SJ.target ? '' : 'disabled'}>${tInfo ? 'Changer le grade' : 'Recruter'}</button>
                    <button class="btn danger" data-sja="remove" ${tInfo ? '' : 'disabled'}>Retirer du métier ${L}</button></div>
                <p class="hint" style="margin:6px 0 10px">${SJ.target ? `Sélection : <b>${esc((players.find((p) => String(p.id) === SJ.target) || {}).name || '')}</b> [${esc(SJ.target)}]` : 'Clique un joueur dans la liste.'}</p>
                <table class="loot wide"><thead><tr><th>ID</th><th>Joueur</th><th>${L}</th><th>Service</th></tr></thead><tbody>${rows || '<tr><td colspan="4" class="muted">Aucun joueur.</td></tr>'}</tbody></table></div>`;
    };

    document.addEventListener('change', (e) => { if (e.target.id === 'sjGrade') SJ.grade = e.target.value; });
    document.addEventListener('input', (e) => {
        if (e.target.id !== 'sjSearch') return;
        SJ.q = e.target.value;
        const pos = e.target.selectionStart;
        render();
        const el = document.getElementById('sjSearch');
        if (el) { el.focus(); el.setSelectionRange(pos, pos); }
    });
    document.addEventListener('click', (e) => {
        if (!isOpen || tab !== 'staffjob') return;
        let n;
        if ((n = e.target.closest('[data-sjjob]'))) { SJ.job = n.dataset.sjjob; SJ.grade = ''; return render(); }
        if ((n = e.target.closest('[data-sjpick]'))) { SJ.target = n.dataset.sjpick; return render(); }
        if ((n = e.target.closest('[data-sjjoin]'))) return send('join', { grade: Number(n.dataset.sjjoin) });
        if (!(n = e.target.closest('[data-sja]')) || n.disabled) return;
        const a = n.dataset.sja;
        if (a === 'set') return send('set', { target: Number(SJ.target), grade: Number(SJ.grade) });
        if (a === 'remove') return send('remove', { target: Number(SJ.target) });
        send(a);
    });
})();
