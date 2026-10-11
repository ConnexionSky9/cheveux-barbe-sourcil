/* =====================================================================
   Tablette LSPD · POLICE SCIENTIFIQUE
   Tableau de bord, affaires, preuves (chaîne de conservation), laboratoire, rapports.
   Le serveur calcule et fige tous les résultats ; cette page ne fait qu'afficher et demander.
   ===================================================================== */
S.sci = { tab: 'dash', caseId: null, evId: null, reportId: null, caseFilter: 'open', evFilter: {}, repFilter: '', newCase: false, seize: false };

const SCI_TABS = [['dash', 'Tableau de bord'], ['cases', 'Affaires'], ['evidence', 'Preuves'], ['lab', 'Laboratoire'], ['reports', 'Rapports']];
const SCI_STATUS_TAG = { collected: 'amber', reception: 'blue', lab: 'blue', stored: '', returned: 'green', destroyed: 'red', invalid: 'red' };
const sciCan = (p) => !!S.perms[p];
const countdown = (ends, now) => { const s = Math.max(0, Number(ends) - Number(now)); return `${Math.floor(s / 60)} min ${String(s % 60).padStart(2, '0')} s`; };
const yesNo = (v) => (v ? 'Oui' : 'Non');

function sciShell(body) {
    return `<div class="sci">
        <div class="sci-head"><div><div class="sci-eyebrow">LSPD · Police scientifique</div><h1>Laboratoire et enquêtes</h1></div>
            ${S.sci.caseId || S.sci.evId || S.sci.reportId ? '<button class="btn" data-act="sciBack">← Retour</button>' : ''}</div>
        <div class="sci-tabs">${SCI_TABS.map(([k, l]) => `<button class="${S.sci.tab === k ? 'on' : ''}" data-act="sciTab" data-tab="${k}">${l}</button>`).join('')}</div>
        ${body}</div>`;
}

/* ---------- Tableau de bord ---------- */
async function sciDash() {
    const d = await mdt('sciDashboard');
    if (d.error) return empty(esc(d.error));
    const s = d.stats || {};
    return `
        <div class="sci-stats">
            <div class="stat"><b>${s.cases || 0}</b><span>Affaires en cours</span></div>
            <div class="stat ${s.pending ? 'hot' : ''}"><b>${s.pending || 0}</b><span>Preuves en attente</span></div>
            <div class="stat"><b>${s.running || 0}</b><span>Analyses en cours</span></div>
            <div class="stat"><b>${s.doneToday || 0}</b><span>Analyses terminées (jour)</span></div>
            <div class="stat ${s.drafts ? 'hot' : ''}"><b>${s.drafts || 0}</b><span>Rapports à finaliser</span></div>
            <div class="stat"><b>${s.scene || 0}</b><span>Preuves non collectées</span></div>
        </div>
        ${s.drafts ? `<div class="sci-alert">${s.drafts} rapport(s) attendent la relecture d'un technicien. <button class="btn" data-act="sciTab" data-tab="reports" data-rep="draft">Voir</button></div>` : ''}
        <div class="cols">
            <div><h2>Analyses en cours</h2>
                ${d.running.length ? `<div class="list">${d.running.map((a) => `<div class="row click" data-sci-ev-code="${esc(a.code)}"><div><b>${esc(a.label)} · ${esc(a.code)}</b><small>${esc(a.technician || '')}</small></div>
                    <span class="tag blue mono">${countdown(a.ends, d.now)}</span></div>`).join('')}</div>` : empty('Aucune analyse en cours.')}
                <h2>Prélèvements récents</h2>
                ${d.recent.length ? `<div class="list">${d.recent.map((e) => `<div class="row click" data-sci-ev="${e.id}"><div><b>${esc(e.code)} · ${esc(e.typeLabel)}</b>
                    <small>${esc(e.collected_by || '?')} · ${fmtTime(e.t)}${e.street ? ' · ' + esc(e.street) : ''}</small></div><span class="tag ${SCI_STATUS_TAG[e.status] || ''}">${esc(e.statusLabel)}</span></div>`).join('')}</div>` : empty('Aucun prélèvement.')}
            </div>
            <div><h2>Derniers rapports</h2>
                ${d.reports.length ? `<div class="list">${d.reports.map((r) => `<div class="row click" data-sci-rep="${r.id}"><div><b>${esc(r.code)} · ${esc(r.label)}</b>
                    <small>${esc(r.evidence)} · ${esc(r.technician || '')} · ${fmtTime(r.t)}</small></div><span class="tag ${r.status === 'final' ? 'green' : 'amber'}">${r.status === 'final' ? 'Finalisé' : 'Brouillon'}</span></div>`).join('')}</div>` : empty('Aucun rapport.')}
            </div>
        </div>`;
}

/* ---------- Affaires ---------- */
async function sciCases() {
    if (S.sci.caseId) return sciCaseOne();
    const d = await mdt('sciCases', { status: S.sci.caseFilter });
    if (d.error) return empty(esc(d.error));
    const chips = [['open', 'En cours'], ['closed', 'Clôturées'], ['all', 'Toutes']];
    return `
        <div class="sci-bar"><div class="sci-chips">${chips.map(([k, l]) => `<button class="${S.sci.caseFilter === k ? 'on' : ''}" data-act="sciCaseFilter" data-f="${k}">${l}</button>`).join('')}</div>
            ${sciCan('sci_cases') ? '<button class="btn primary" data-act="sciNewCase">Nouvelle affaire</button>' : ''}</div>
        ${S.sci.newCase ? `<div class="card" style="margin-bottom:12px">
            <label class="field">Titre<input type="text" id="sciCaseTitle" maxlength="120" placeholder="Ex. : Fusillade Grove Street"></label>
            <label class="field" style="margin-top:10px">Description<textarea id="sciCaseDesc" rows="3" maxlength="4000"></textarea></label>
            <div class="footer-actions"><button class="btn" data-act="sciNewCaseCancel">Annuler</button><button class="btn primary" data-act="sciCaseCreate">Créer l'affaire</button></div></div>` : ''}
        ${d.list.length ? `<div class="list">${d.list.map((c) => `<div class="row click" data-sci-case="${c.id}"><div><b>${esc(c.code)} · ${esc(c.title)}</b>
            <small>${c.evidence} preuve(s) · ouverte par ${esc(c.created_by || '?')} · mise à jour ${fmtTime(c.t)}</small></div>
            <span class="tag ${c.status === 'open' ? 'green' : ''}">${c.status === 'open' ? 'En cours' : 'Clôturée'}</span></div>`).join('')}</div>` : empty('Aucune affaire.')}`;
}

async function sciCaseOne() {
    const d = await mdt('sciCase', { id: S.sci.caseId });
    if (d.error) return empty(esc(d.error));
    const c = d.case;
    const edit = sciCan('sci_cases');
    return `
        <div class="profile-head"><div><h2 style="margin:0">${esc(c.code)} · ${esc(c.title)}</h2>
            <p class="lead">${c.status === 'open' ? 'En cours' : 'Clôturée'} · ouverte par ${esc(c.created_by || '?')} le ${fmtTime(c.t)}</p></div>
            <span class="tag ${c.status === 'open' ? 'green' : ''}">${c.status === 'open' ? 'En cours' : 'Clôturée'}</span></div>
        <div class="cols">
            <div>
                <div class="card">
                    <label class="field">Titre<input type="text" id="sciCTitle" maxlength="120" value="${esc(c.title)}" ${edit ? '' : 'disabled'}></label>
                    <label class="field" style="margin-top:10px">Description<textarea id="sciCDesc" rows="4" maxlength="4000" ${edit ? '' : 'disabled'}>${esc(c.description || '')}</textarea></label>
                    ${edit ? '<div class="footer-actions"><span></span><button class="btn primary" data-act="sciCaseSave">Enregistrer</button></div>' : ''}
                </div>
                ${edit ? `<div class="card" style="margin-top:12px"><label class="field">${c.status === 'open' ? 'Clôturer l\'affaire' : 'Rouvrir l\'affaire'} : justification
                    <input type="text" id="sciCReason" maxlength="500" placeholder="Raison (obligatoire)"></label>
                    <div class="footer-actions"><span></span><button class="btn ${c.status === 'open' ? 'danger' : 'primary'}" data-act="sciCaseStatus" data-s="${c.status === 'open' ? 'closed' : 'open'}">${c.status === 'open' ? 'Clôturer' : 'Rouvrir'}</button></div></div>` : ''}
                <h2>Preuves (${d.evidence.length})</h2>
                ${d.evidence.length ? `<div class="list">${d.evidence.map((e) => `<div class="row click" data-sci-ev="${e.id}"><div><b>${esc(e.code)} · ${esc(e.typeLabel)}</b>
                    <small>${esc(e.collected_by || '')}${e.street ? ' · ' + esc(e.street) : ''}</small></div><span class="tag ${SCI_STATUS_TAG[e.status] || ''}">${esc(e.statusLabel)}</span></div>`).join('')}</div>` : empty('Aucune preuve associée (Preuves › associer à une affaire).')}
                <h2>Rapports</h2>
                ${d.reports.length ? `<div class="list">${d.reports.map((r) => `<div class="row click" data-sci-rep="${r.id}"><div><b>${esc(r.code)} · ${esc(r.label)}</b><small>${esc(r.evidence)}</small></div>
                    <span class="tag ${r.status === 'final' ? 'green' : 'amber'}">${r.status === 'final' ? 'Finalisé' : 'Brouillon'}</span></div>`).join('')}</div>` : empty('Aucun rapport.')}
            </div>
            <div>
                <h2>Policiers impliqués</h2>
                <div class="card">${d.officers.length ? d.officers.map((o) => `<span class="tag blue" style="margin:2px">${esc(o)}</span>`).join('') : '<span class="lead">—</span>'}</div>
                <h2>Notes</h2>
                <div class="card"><label class="field">Ajouter une note<textarea id="sciNote" rows="2" maxlength="1000"></textarea></label>
                    <div class="footer-actions"><span></span><button class="btn" data-act="sciCaseNote">Ajouter</button></div></div>
                <h2>Chronologie</h2>
                ${d.timeline.length ? `<div class="sci-timeline">${d.timeline.map((t) => `<div><span class="mono">${fmtTime(t.t)}</span><b>${esc(t.action)}${t.code ? ' · ' + esc(t.code) : ''}</b>
                    <small>${esc(t.actor || '')}${t.details ? ' · ' + esc(t.details) : ''}</small></div>`).join('')}</div>` : empty('Rien pour l\'instant.')}
            </div>
        </div>`;
}

/* ---------- Preuves ---------- */
async function sciEvidence() {
    if (S.sci.evId) return sciEvidenceOne();
    const f = S.sci.evFilter;
    const d = await mdt('sciEvidence', f);
    if (d.error) return empty(esc(d.error));
    let seize = '';
    if (S.sci.seize) {
        const w = await mdt('sciMyWeapons');
        seize = w.error ? `<div class="card">${esc(w.error)}</div>` : `<div class="card" style="margin-bottom:12px"><b>Mettre une arme sous scellé</b>
            <p class="lead" style="margin:4px 0 10px">L'arme doit être dans votre inventaire (récupérée lors d'une fouille). Elle sera placée dans un sachet à déposer au laboratoire.</p>
            <label class="field" style="max-width:340px">Affaire (facultatif)<select id="sciSeizeCase"><option value="">— Aucune —</option>${w.cases.map((c) => `<option value="${c.id}">${esc(c.code)} · ${esc(c.title)}</option>`).join('')}</select></label>
            ${w.list.length ? `<div class="list" style="margin-top:10px">${w.list.map((x) => `<div class="row"><div><b>${esc(x.label)}</b><small>N° ${esc(x.serial)}${x.engraving ? ' · gravée « ' + esc(x.engraving) + ' »' : ''}</small></div>
                <div class="actions"><button class="btn primary" data-act="sciSeize" data-slot="${x.slot}">Mettre sous scellé</button></div></div>`).join('')}</div>` : empty('Aucune arme dans votre inventaire.')}
            <div class="footer-actions"><span></span><button class="btn" data-act="sciSeizeToggle">Fermer</button></div></div>`;
    }
    const statuses = [['', 'Tous les statuts'], ['collected', 'Collectée'], ['reception', 'Réception'], ['lab', 'Laboratoire'], ['stored', 'Scellés'], ['returned', 'Restituée'], ['destroyed', 'Détruite'], ['invalid', 'Dégradée']];
    const types = [['', 'Tous les types'], ['casing', 'Douilles'], ['bullet', 'Projectiles (véhicules)'], ['blood', 'Sang'], ['weapon', 'Armes']];
    return `
        <div class="sci-bar">
            <div class="sci-filters"><input type="text" id="sciEvQ" placeholder="N° de preuve, lieu, affaire…" value="${esc(f.q || '')}">
                <select id="sciEvType">${types.map(([k, l]) => `<option value="${k}" ${f.type === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
                <select id="sciEvStatus">${statuses.map(([k, l]) => `<option value="${k}" ${f.status === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
                <button class="btn" data-act="sciEvSearch">Filtrer</button></div>
            <div style="display:flex;gap:6px">${sciCan('sci_lab') || sciCan('sci_collect') ? '<button class="btn" data-act="sciReceive" title="Au laboratoire">Réceptionner mes scellés</button>' : ''}
                ${sciCan('sci_collect') ? '<button class="btn primary" data-act="sciSeizeToggle">Saisir une arme</button>' : ''}</div>
        </div>${seize}
        ${d.list.length ? `<div class="sci-table"><table><thead><tr><th>N°</th><th>Type</th><th>Statut</th><th>Lieu actuel</th><th>Collecteur</th><th>Affaire</th><th>Analyses</th></tr></thead><tbody>
            ${d.list.map((e) => `<tr class="click" data-sci-ev="${e.id}"><td class="mono"><b>${esc(e.code)}</b></td><td>${esc(e.typeLabel)}</td>
                <td><span class="tag ${SCI_STATUS_TAG[e.status] || ''}">${esc(e.statusLabel)}</span></td><td>${esc(e.location || '—')}</td>
                <td>${esc(e.collected_by || '—')}<small>${fmtTime(e.t)}</small></td><td class="mono">${esc(e.case_code || '—')}</td><td>${e.analyses || 0}</td></tr>`).join('')}
            </tbody></table></div>` : empty('Aucune preuve.')}`;
}

async function sciEvidenceOne() {
    const d = await mdt('sciEvidenceOne', { id: S.sci.evId });
    if (d.error) return empty(esc(d.error));
    const e = d.evidence;
    const v = e.visible || {};
    const linkable = sciCan('sci_cases') || sciCan('sci_collect') || sciCan('sci_lab');
    const inLab = ['reception', 'lab', 'stored'].includes(e.status);
    const doneKinds = new Set(d.analyses.map((a) => a.kind));
    return `
        <div class="profile-head"><div><h2 style="margin:0">${esc(e.code)} · ${esc(e.typeLabel)}</h2>
            <p class="lead">${esc(e.statusLabel)} · ${esc(e.location || '—')}${e.holder ? ' · responsable : ' + esc(e.holder) : ''}</p></div>
            <span class="tag ${SCI_STATUS_TAG[e.status] || ''}">${esc(e.statusLabel)}</span></div>
        <div class="cols">
            <div>
                <div class="card sci-kv">
                    <div><span>Découverte</span><b>${fmtTime(e.t)}${e.street ? ' · ' + esc(e.street) : ''}</b></div>
                    <div><span>Collecte</span><b>${esc(e.collected_by || '—')}${e.ct ? ' · ' + fmtTime(e.ct) : ''}</b></div>
                    ${v.calibre ? `<div><span>Calibre (visible)</span><b>${esc(v.calibre)}</b></div>` : ''}
                    ${v.plate ? `<div><span>Extrait du véhicule</span><b class="mono">${esc(v.plate)}</b></div>` : ''}
                    ${v.count > 1 ? `<div><span>Quantité</span><b>${v.count}</b></div>` : ''}
                    ${v.weapon ? `<div><span>Arme</span><b>${esc(v.weapon)}</b></div><div><span>N° de série</span><b class="mono">${esc(v.serial || '—')}</b></div>
                        <div><span>Gravure</span><b>${esc(v.engraving || '—')}</b></div>` : ''}
                    <div><span>Affaire</span><b>${e.case_code ? `${esc(e.case_code)} · ${esc(e.case_title || '')}` : '—'}</b></div>
                </div>
                ${linkable ? `<div class="card" style="margin-top:12px"><label class="field">Associer à une affaire<select id="sciLinkCase"><option value="0">— Aucune —</option>
                    ${d.cases.map((c) => `<option value="${c.id}" ${c.id === e.case_id ? 'selected' : ''}>${esc(c.code)} · ${esc(c.title)}</option>`).join('')}</select></label>
                    <div class="footer-actions"><span></span><button class="btn" data-act="sciLink">Enregistrer</button></div></div>` : ''}
                <h2>Analyses</h2>
                ${d.analyses.length ? `<div class="list">${d.analyses.map((a) => `<div class="row"><div><b>${esc(a.label)}</b><small>${esc(a.technician || '')}</small></div>
                    ${a.status === 'running' ? `<span class="tag blue mono">${countdown(a.ends, d.now)}</span>` : '<span class="tag green">Terminée</span>'}</div>`).join('')}</div>` : empty('Aucune analyse.')}
                ${sciCan('sci_lab') ? `<div class="sci-actions">${d.possible.map((p) => `<button class="btn primary" data-act="sciAnalyze" data-kind="${p.kind}" ${!inLab || doneKinds.has(p.kind) || !d.labNear ? 'disabled' : ''}
                    title="${!inLab ? 'Réceptionnez la preuve au laboratoire' : doneKinds.has(p.kind) ? 'Déjà faite' : !d.labNear ? 'Rendez-vous au laboratoire' : ''}">Lancer : ${esc(p.label)}</button>`).join('')}
                    <button class="btn" data-act="sciStore" ${e.status === 'reception' || e.status === 'lab' ? '' : 'disabled'}>Ranger aux scellés</button></div>
                    ${!d.labNear ? '<p class="lead" style="margin-top:6px">Les analyses se lancent depuis le laboratoire.</p>' : ''}` : ''}
                ${sciCan('sci_custody') && !['returned', 'destroyed', 'collected'].includes(e.status) ? `<div class="card" style="margin-top:12px"><b>Restitution / destruction</b>
                    <label class="field" style="margin-top:8px">Raison (destruction)<input type="text" id="sciDestroyReason" maxlength="200"></label>
                    <div class="footer-actions">${e.type === 'weapon' ? '<button class="btn" data-confirm="sciReturn">Restituer l\'arme</button>' : '<span></span>'}
                    <button class="btn danger" data-confirm="sciDestroy">Détruire la preuve</button></div></div>` : ''}
                <h2>Rapports</h2>
                ${d.reports.length ? `<div class="list">${d.reports.map((r) => `<div class="row click" data-sci-rep="${r.id}"><div><b>${esc(r.code)} · ${esc(r.label)}</b></div>
                    <span class="tag ${r.status === 'final' ? 'green' : 'amber'}">${r.status === 'final' ? 'Finalisé' : 'Brouillon'}</span></div>`).join('')}</div>` : empty('Aucun rapport.')}
            </div>
            <div><h2>Chaîne de conservation</h2>
                <div class="sci-timeline">${d.log.map((l) => `<div><span class="mono">${fmtTime(l.t)}</span><b>${esc(l.action)}</b><small>${esc(l.actor || '')}${l.details ? ' · ' + esc(l.details) : ''}</small></div>`).join('')}</div>
            </div>
        </div>`;
}

/* ---------- Laboratoire ---------- */
async function sciLab() {
    const [rec, lab] = await Promise.all([mdt('sciEvidence', { status: 'reception' }), mdt('sciEvidence', { status: 'lab' })]);
    if (rec.error) return empty(esc(rec.error));
    const all = [...(rec.list || []), ...(lab.list || [])];
    const analysed = all.filter((e) => e.analyses > 0);
    const stored = await mdt('sciEvidence', { status: 'stored' });
    const comparable = [...analysed, ...((stored.list || []).filter((e) => e.analyses > 0))];
    return `
        <p class="lead">Réceptionnez les scellés au laboratoire (ALT au laboratoire ou bouton ci-dessous), puis ouvrez une preuve pour lancer son analyse. Les résultats et les rapports sont produits par le laboratoire à la fin du délai d'analyse.</p>
        <div class="sci-bar"><span></span>${sciCan('sci_lab') || sciCan('sci_collect') ? '<button class="btn primary" data-act="sciReceive">Réceptionner mes scellés</button>' : ''}</div>
        <div class="cols">
            <div><h2>À traiter (${all.length})</h2>
                ${all.length ? `<div class="list">${all.map((e) => `<div class="row click" data-sci-ev="${e.id}"><div><b>${esc(e.code)} · ${esc(e.typeLabel)}</b><small>${e.analyses} analyse(s) terminée(s)${e.case_code ? ' · ' + esc(e.case_code) : ''}</small></div>
                    <span class="tag ${SCI_STATUS_TAG[e.status] || ''}">${esc(e.statusLabel)}</span></div>`).join('')}</div>` : empty('Aucune preuve au laboratoire.')}</div>
            <div><h2>Comparer deux preuves</h2>
                <div class="card">${comparable.length >= 2 ? `
                    <label class="field">Preuve A<select id="sciCmpA">${comparable.map((e) => `<option value="${e.id}">${esc(e.code)} · ${esc(e.typeLabel)}</option>`).join('')}</select></label>
                    <label class="field" style="margin-top:8px">Preuve B<select id="sciCmpB">${comparable.map((e, i) => `<option value="${e.id}" ${i === 1 ? 'selected' : ''}>${esc(e.code)} · ${esc(e.typeLabel)}</option>`).join('')}</select></label>
                    <div class="footer-actions"><span></span><button class="btn primary" data-act="sciCompare" ${sciCan('sci_lab') ? '' : 'disabled'}>Comparer</button></div>
                    <div id="sciCmpOut"></div>` : '<p class="lead" style="margin:0">Il faut au moins deux preuves analysées.</p>'}</div></div>
        </div>`;
}

/* ---------- Rapports ---------- */
function reportData(r) {
    const d = r.data || {};
    const rows = [];
    if (r.kind === 'ballistic') {
        rows.push(['Calibre', d.calibre], ['Type d\'arme', d.weaponType], ['Arme identifiée', yesNo(d.identified)]);
        const ws = { active: 'En circulation', seized: 'Saisie', destroyed: 'Détruite' };
        if (d.identified) rows.push(['N° de série', d.serial], ['Gravure', d.engraving || 'Aucune'], ['Propriétaire enregistré', d.owner], ['Statut de l\'arme (au moment de l\'analyse)', ws[d.weaponStatus] || d.weaponStatus || '—']);
        else rows.push(['Armes compatibles enregistrées', d.compatible ?? '—']);
        if (d.plate) rows.push(['Véhicule touché', d.plate]);
        if (d.count) rows.push([d.plate ? 'Impacts relevés' : 'Douilles relevées', d.count]);
    } else if (r.kind === 'dna') {
        rows.push(['Profil ADN', d.profile], ['Correspondance', d.match], ['Prélèvements', d.samples]);
    } else if (r.kind === 'prints') {
        rows.push(['Arme', d.weaponType], ['N° de série', d.serial]);
    }
    return rows;
}

async function sciReports() {
    if (S.sci.reportId) return sciReportOne();
    const d = await mdt('sciReports', { status: S.sci.repFilter });
    if (d.error) return empty(esc(d.error));
    const chips = [['', 'Tous'], ['draft', 'Brouillons'], ['final', 'Finalisés']];
    return `<div class="sci-bar"><div class="sci-chips">${chips.map(([k, l]) => `<button class="${S.sci.repFilter === k ? 'on' : ''}" data-act="sciRepFilter" data-f="${k}">${l}</button>`).join('')}</div></div>
        ${d.list.length ? `<div class="sci-table"><table><thead><tr><th>N°</th><th>Analyse</th><th>Preuve</th><th>Affaire</th><th>Technicien</th><th>Date</th><th>Statut</th></tr></thead><tbody>
            ${d.list.map((r) => `<tr class="click" data-sci-rep="${r.id}"><td class="mono"><b>${esc(r.code)}</b></td><td>${esc(r.label)}</td><td class="mono">${esc(r.evidence)}</td>
                <td class="mono">${esc(r.case_code || '—')}</td><td>${esc(r.technician || '')}</td><td>${fmtTime(r.t)}</td>
                <td><span class="tag ${r.status === 'final' ? 'green' : 'amber'}">${r.status === 'final' ? 'Finalisé' : 'Brouillon'}</span></td></tr>`).join('')}</tbody></table></div>` : empty('Aucun rapport.')}`;
}

async function sciReportOne() {
    const d = await mdt('sciReport', { id: S.sci.reportId });
    if (d.error) return empty(esc(d.error));
    const r = d.report;
    const data = r.data || {};
    const draft = r.status === 'draft';
    const canEdit = draft && sciCan('sci_lab');
    const matches = data.matches || [];
    return `
        <div class="sci-report">
            <div class="sci-report-head"><div><div class="sci-eyebrow">Rapport scientifique</div><h2>${esc(r.code)} · ${esc(r.label)}</h2></div>
                <span class="tag ${draft ? 'amber' : 'green'}">${draft ? 'Brouillon' : 'Finalisé'}</span></div>
            <div class="sci-kv grid">
                <div><span>Affaire</span><b>${r.case_code ? `${esc(r.case_code)} · ${esc(r.case_title || '')}` : '—'}</b></div>
                <div><span>Preuve</span><b class="mono">${esc(r.evidence)} · ${esc(r.typeLabel)}</b></div>
                <div><span>Type d'analyse</span><b>${esc(r.label)}</b></div>
                <div><span>Technicien</span><b>${esc(r.technician || '—')}</b></div>
                <div><span>Analyse terminée</span><b>${fmtTime(data.analysedAt)}</b></div>
                <div><span>Finalisé</span><b>${r.ft ? fmtTime(r.ft) : '—'}</b></div>
            </div>
            <h3>Données examinées</h3>
            <div class="sci-kv grid">${reportData(r).map(([k, v]) => `<div><span>${esc(k)}</span><b>${esc(v ?? '—')}</b></div>`).join('')}</div>
            ${r.kind === 'prints' ? `<h3>Empreintes</h3>${(data.prints || []).length ? `<div class="list">${data.prints.map((p) => `<div class="row"><div><b class="mono">${esc(p.fingerprint)}</b></div>
                <span class="tag ${p.identified ? 'green' : ''}">${p.identified ? esc(p.name) : 'Non identifiée'}</span></div>`).join('')}</div>` : empty('Aucune empreinte exploitable.')}` : ''}
            <h3>Résultat</h3><p class="sci-result">${esc(data.summary || '')}</p>
            ${matches.length ? `<h3>Correspondances (${matches.length})</h3><div class="sci-table"><table><thead><tr><th>Preuve</th><th>Type</th><th>Date</th><th>Lieu</th><th>Affaire</th></tr></thead><tbody>
                ${matches.map((m) => `<tr class="click" data-sci-ev="${m.id}"><td class="mono">${esc(m.code)}</td><td>${esc(m.typeLabel || '')}</td><td>${fmtTime(m.t)}</td><td>${esc(m.street || '—')}</td><td class="mono">${esc(m.case_code || '—')}</td></tr>`).join('')}
                </tbody></table></div>` : ''}
            <h3>Limites de l'analyse</h3><p class="lead">${esc(data.limits || '')}</p>
            <h3>Conclusion du technicien</h3>
            ${canEdit ? `<textarea id="sciConclusion" rows="4" maxlength="3000">${esc(r.conclusion || '')}</textarea>
                <div class="footer-actions"><button class="btn" data-act="sciReportSave">Enregistrer le brouillon</button><button class="btn primary" data-confirm="sciReportFinal">Finaliser et transmettre</button></div>`
                : `<p class="sci-result">${esc(r.conclusion || '—')}</p>`}
            <p class="lead sci-trace">Traçabilité : collecte par ${esc(r.collected_by || '?')} ${r.ct ? 'le ' + fmtTime(r.ct) : ''}${r.street ? ' · ' + esc(r.street) : ''}. Données figées au moment de l'analyse.</p>
        </div>`;
}

/* ---------- Page ---------- */
PAGES.sci = async () => {
    if (!S.me) { const d = await mdt('dashboard'); if (!d.error) updateMe(d.me); }
    if (!(sciCan('sci_view') || sciCan('sci_lab') || sciCan('sci_collect'))) return `<h1>Police scientifique</h1>${empty('Accès réservé à la police scientifique.')}`;
    const t = S.sci.tab;
    const body = t === 'cases' ? await sciCases() : t === 'evidence' ? await sciEvidence() : t === 'lab' ? await sciLab() : t === 'reports' ? await sciReports() : await sciDash();
    return sciShell(body);
};

const sciGo = (patch) => { Object.assign(S.sci, patch); go('sci', true); };

Object.assign(Acts, {
    sciTab: (b) => sciGo({ tab: b.dataset.tab, caseId: null, evId: null, reportId: null, newCase: false, seize: false, repFilter: b.dataset.rep || S.sci.repFilter }),
    sciBack: () => sciGo({ caseId: null, evId: null, reportId: null }),
    sciCaseFilter: (b) => sciGo({ caseFilter: b.dataset.f }),
    sciNewCase: () => sciGo({ newCase: true }),
    sciNewCaseCancel: () => sciGo({ newCase: false }),
    sciCaseCreate: async () => {
        const r = await run('sciCaseCreate', { title: $('#sciCaseTitle').value, description: $('#sciCaseDesc').value }, false);
        if (!r.error) sciGo({ newCase: false, caseId: r.id });
    },
    sciCaseSave: () => run('sciCaseUpdate', { id: S.sci.caseId, title: $('#sciCTitle').value, description: $('#sciCDesc').value }),
    sciCaseStatus: (b) => run('sciCaseStatus', { id: S.sci.caseId, status: b.dataset.s, reason: $('#sciCReason').value }),
    sciCaseNote: () => run('sciCaseNote', { id: S.sci.caseId, text: $('#sciNote').value }),
    sciEvSearch: () => sciGo({ evFilter: { q: $('#sciEvQ').value.trim(), type: $('#sciEvType').value, status: $('#sciEvStatus').value } }),
    sciSeizeToggle: () => sciGo({ seize: !S.sci.seize }),
    sciSeize: (b) => run('sciSeizeWeapon', { slot: Number(b.dataset.slot), caseId: Number($('#sciSeizeCase').value) || null }),
    sciReceive: () => run('sciReceive'),
    sciLink: () => run('sciEvidenceLink', { id: S.sci.evId, caseId: Number($('#sciLinkCase').value) || 0 }),
    sciAnalyze: (b) => run('sciAnalyze', { id: S.sci.evId, kind: b.dataset.kind }),
    sciStore: () => run('sciStore', { id: S.sci.evId }),
    sciCompare: async () => {
        const r = await mdt('sciCompare', { a: Number($('#sciCmpA').value), b: Number($('#sciCmpB').value) });
        $('#sciCmpOut').innerHTML = r.error ? `<p class="lead" style="color:#ff8a8d;margin-top:10px">${esc(r.error)}</p>`
            : `<div class="sci-cmp ${r.match === true ? 'ok' : r.match === false ? 'ko' : ''}">${esc(r.text)}</div>`;
    },
    sciRepFilter: (b) => sciGo({ repFilter: b.dataset.f }),
    sciReportSave: () => run('sciReportSave', { id: S.sci.reportId, conclusion: $('#sciConclusion').value }),
});

Object.assign(Confirmed, {
    sciReturn: () => run('sciReturn', { id: S.sci.evId }),
    sciDestroy: () => run('sciDestroy', { id: S.sci.evId, reason: $('#sciDestroyReason').value }),
    sciReportFinal: () => run('sciReportSave', { id: S.sci.reportId, conclusion: $('#sciConclusion').value, finalize: true }),
});

// Navigation par clic sur une ligne (affaire, preuve, rapport)
$('#page').addEventListener('click', async (e) => {
    const el = e.target.closest('[data-sci-case],[data-sci-ev],[data-sci-rep],[data-sci-ev-code]');
    if (!el || e.target.closest('button')) return;
    if (el.dataset.sciCase) return sciGo({ tab: 'cases', caseId: Number(el.dataset.sciCase), evId: null, reportId: null });
    if (el.dataset.sciEv) return sciGo({ tab: 'evidence', evId: Number(el.dataset.sciEv), caseId: null, reportId: null });
    if (el.dataset.sciRep) return sciGo({ tab: 'reports', reportId: Number(el.dataset.sciRep), caseId: null, evId: null });
    if (el.dataset.sciEvCode) {
        const r = await mdt('sciEvidence', { q: el.dataset.sciEvCode });
        const hit = (r.list || []).find((x) => x.code === el.dataset.sciEvCode);
        if (hit) sciGo({ tab: 'evidence', evId: hit.id, caseId: null, reportId: null });
    }
});

// Compte à rebours des analyses : rafraîchit la page scientifique toutes les 15 s
setInterval(() => {
    if (S.page === 'sci' && !$('#mdt').classList.contains('hidden') && !document.activeElement.closest('#page input, #page textarea, #page select')) go('sci', true);
}, 15000);
