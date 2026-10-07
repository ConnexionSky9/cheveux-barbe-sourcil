/* =========================================================
   MES OUTILS › MÉTIER STAFF (permission « staff_job »)
   Prendre n'importe quel métier / grade en un clic, passer en service,
   revenir à son métier d'origine.
   ========================================================= */
(() => {
    TABS.push({
        id: 'staffjob', group: 2, label: 'Métier staff', ico: '💼',
        sub: 'Prends n\'importe quel métier et grade en un clic, puis reviens à ton métier d\'origine.',
        show: () => has('staff_job') && !!(D && D.staffJob),
    });

    const SJ = { q: '' };
    const send = (name, data = {}) => action('staffjob', { name, data });
    const norm = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

    VIEWS.staffjob = () => {
        const d = D.staffJob, c = d.current || {};
        const prev = c.prev;
        const cards = (d.jobs || []).map((j) => {
            const mine = j.name === c.name;
            return `<div class="card sj-card" data-sjname="${esc(norm(j.label + ' ' + j.name))}" style="padding:12px 14px;${mine ? 'border-color:var(--signal)' : ''}">
                <div style="display:flex;justify-content:space-between;align-items:baseline;gap:8px;margin-bottom:8px">
                    <strong>${esc(j.label)}</strong><span class="muted" style="font-size:12px">${esc(j.name)}${j.type ? ` · ${esc(j.type)}` : ''}</span></div>
                <div class="chips">${j.grades.map((g) => `<button class="btn ${mine && g.level === c.level ? 'on' : ''}" data-sjset="${esc(j.name)}" data-g="${g.level}"
                    title="Grade ${g.level}${g.payment ? ` · ${g.payment} $` : ''}">${g.isboss ? '👑 ' : ''}${esc(g.name)}</button>`).join('')}</div></div>`;
        }).join('');
        return `<div class="section"><h2>Mon métier actuel</h2>
                <div class="stats">
                    <div class="stat"><b>${esc(c.label || 'Sans emploi')}</b><span>${esc(c.grade || '')}${c.isboss ? ' · 👑 patron' : ''}</span></div>
                    <div class="stat"><b style="color:${c.onduty ? 'var(--ok)' : 'var(--muted)'}">${c.onduty ? 'En service' : 'Hors service'}</b><span>Service</span></div>
                    <div class="stat"><b>${prev ? esc(prev.label || prev.name) : '—'}</b><span>Métier d'origine${prev ? ` · ${esc(prev.gradeLabel ?? prev.grade)}` : ''}</span></div></div>
                <div class="btn-row">
                    <button class="btn ${c.onduty ? '' : 'primary'}" data-sja="duty">${c.onduty ? 'Quitter le service' : 'Prendre le service'}</button>
                    <button class="btn primary" data-sja="back" ${prev ? '' : 'disabled'}>↩ Revenir à mon métier d'origine</button>
                    <button class="btn" data-sja="keep" ${prev ? '' : 'disabled'} title="Le métier actuel devient ton métier normal">Garder ce métier</button></div>
                <p class="hint" style="margin-top:8px">Au premier changement, ton vrai métier est gardé : « Revenir » te le rend (même après une déconnexion).
                    Tu passes en service automatiquement. 👑 = grade patron.</p></div>
            <div class="section"><h2>Tous les métiers (${(d.jobs || []).length})</h2>
                <input class="input" id="sjSearch" placeholder="Rechercher un métier (police, ems, burger…)" value="${esc(SJ.q)}" style="max-width:420px;margin-bottom:12px">
                <div class="grid" id="sjGrid" style="grid-template-columns:repeat(auto-fill,minmax(300px,1fr))">${cards}</div></div>`;
    };

    function filter() {
        const q = norm(SJ.q);
        document.querySelectorAll('#sjGrid .sj-card').forEach((el) => { el.style.display = !q || el.dataset.sjname.includes(q) ? '' : 'none'; });
    }

    document.addEventListener('input', (e) => {
        if (e.target.id !== 'sjSearch') return;
        SJ.q = e.target.value;
        filter();
    });
    document.addEventListener('click', (e) => {
        if (!isOpen || tab !== 'staffjob') return;
        let n;
        if ((n = e.target.closest('[data-sjset]'))) return send('set', { job: n.dataset.sjset, grade: Number(n.dataset.g) });
        if ((n = e.target.closest('[data-sja]')) && !n.disabled) return send(n.dataset.sja);
    });
    // Le filtre reste appliqué après chaque mise à jour du menu
    new MutationObserver(() => { if (tab === 'staffjob' && document.getElementById('sjGrid')) filter(); })
        .observe(document.body, { childList: true, subtree: true });
})();
