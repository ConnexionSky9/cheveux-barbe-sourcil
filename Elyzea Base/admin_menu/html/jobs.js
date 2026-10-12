/* =========================================================
   ONGLET 💼 MÉTIERS
   Un seul onglet dans la barre latérale : les métiers gérés par le
   menu (EMS, Police, LsCustom, Concession…) s'ouvrent depuis ici,
   et tous les autres métiers du serveur sont listés avec leurs effectifs.
   ========================================================= */
(() => {
    const CHILDREN = ['jobsmgr', 'ems', 'police', 'lscustom', 'concess', 'concessair', 'ent_taxi', 'ent_burgershot', 'ent_nightclub', 'permis', 'farm'];
    const BLURB = {
        ems: 'Tablette staff EMS, accès, tenues, rejoindre le métier.',
        police: 'Tablette staff Police, accès, tenues, rejoindre le métier.',
        lscustom: 'Grades, zones, prix, tenues, permissions, configuration.',
        concess: 'Tablette direction, grades, zones, tenues, permissions.',
        permis: 'Questions du code de la route et prix des permis B, A, C.',
        farm: 'Bûcheron… : temps de coupe, bûches obtenues, prix de revente, zones de travail, tenue.',
        concessair: 'Avions et hélicoptères : tablette direction, grades, zones, tenues, permissions.',
        ent_taxi: 'Compteur, courses PNJ, grades, zones, véhicules, tenues.',
        ent_burgershot: 'Carte et prix, recettes, fournisseur, grades, zones, tenues.',
        ent_nightclub: 'Bar, entrée, carte et prix, fournisseur, grades, zones, tenues.',
        jobsmgr: 'Tous les autres métiers : grades, salaires, points, véhicules de service, tenues, bureau du patron.',
    };
    for (const id of CHILDREN) {
        const t = TABS.find((x) => x.id === id);
        if (t) t.parent = 'jobs';
    }
    const visibleChildren = () => CHILDREN.map((id) => TABS.find((t) => t.id === id)).filter((t) => t && t.show());

    TABS.push({
        id: 'jobs', group: 5, label: 'Métiers', ico: '💼',
        sub: 'Tous les métiers du serveur : gestion des métiers Elyzea, effectifs en ville et en service.',
        show: () => visibleChildren().length > 0 || (has('manage_staff') && !!(D && D.jobsHub)),
    });

    VIEWS.jobs = () => {
        const hub = D.jobsHub || { list: [], groups: {} };
        const kids = visibleChildren();
        const stat = (g) => hub.groups && hub.groups[g];
        const cards = kids.map((t) => {
            const s = stat(t.id);
            return `<button class="tile job-card" data-tab-go="${t.id}">
                <div class="jc-head"><span class="jc-ico">${t.ico}</span><strong style="font-size:17px">${esc(t.label)}</strong></div>
                <span>${esc(BLURB[t.id] || t.sub || '')}</span>
                ${s ? `<div class="jc-stats"><span class="badge" style="color:var(--ok)">${s.duty} en service</span><span class="badge muted">${s.online} en ville</span></div>` : ''}
            </button>`;
        }).join('');
        const others = hub.list || [];
        return `
            ${kids.length ? `<div class="section"><h2>Métiers gérés par le menu</h2>
                <p class="hint">Clique sur un métier pour le gérer (tablettes staff, grades, zones, tenues, permissions…).</p>
                <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(250px,1fr))">${cards}</div></div>` : ''}
            <div class="section"><h2>Tous les métiers du serveur (${others.length})</h2>
                <p class="hint">Effectifs en direct (mis à jour toutes les 5 secondes). Les métiers marqués « Elyzea » se gèrent ci-dessus.</p>
                <div class="inline" style="max-width:420px;margin-bottom:10px"><input class="input" id="jobs-q" placeholder="Rechercher un métier" data-draft="jobsQ" value="${esc(draft('jobsQ', ''))}"></div>
                ${others.length ? `<table><tr><th>Métier</th><th>Identifiant</th><th>Grades</th><th>En ville</th><th>En service</th><th></th></tr>
                    ${others.filter((j) => { const q = String(draft('jobsQ', '')).toLowerCase(); return !q || j.label.toLowerCase().includes(q) || j.name.toLowerCase().includes(q); })
                        .map((j) => `<tr><td><strong>${esc(j.label)}</strong></td><td><span class="keycap">${esc(j.name)}</span></td><td class="muted">${j.grades}</td>
                        <td>${j.online ? `<b>${j.online}</b>` : '<span class="muted">0</span>'}</td><td>${j.duty ? `<span class="badge" style="color:var(--ok)">${j.duty}</span>` : '<span class="muted">0</span>'}</td>
                        <td style="text-align:right">${j.managed && kids.some((t) => t.id === j.managed) ? `<button class="btn" data-tab-go="${j.managed}">Gérer · Elyzea</button>`
                            : (window.JobsMgr && has('jobs_manage') && j.managed !== 'ems' && j.managed !== 'police' && j.managed !== 'lscustom' && j.managed !== 'concess')
                                ? `<button class="btn" data-jm-open="${esc(j.name)}">Paramétrer</button>` : ''}</td></tr>`).join('')}</table>`
                    : '<div class="empty">Aucun métier trouvé.</div>'}
            </div>`;
    };

    // Paramétrer un métier depuis la liste
    document.addEventListener('click', (e) => {
        const b = e.target.closest('[data-jm-open]');
        if (b && isOpen && tab === 'jobs' && window.JobsMgr) window.JobsMgr.open(b.dataset.jmOpen);
    });

    // La recherche filtre sans attendre le rafraîchissement
    document.addEventListener('input', (e) => {
        if (e.target.id !== 'jobs-q' || !isOpen || tab !== 'jobs') return;
        const pos = e.target.selectionStart;
        render();
        const el = document.getElementById('jobs-q');
        if (el) { el.focus(); el.setSelectionRange(pos, pos); }
    });
})();
