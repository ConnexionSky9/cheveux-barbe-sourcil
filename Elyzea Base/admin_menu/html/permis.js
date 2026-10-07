/* =========================================================
   MÉTIERS › AUTO-ÉCOLE (ressource elyzea_permis)
   Questions du code (communes et par permis) et prix des permis.
   ========================================================= */
(() => {
    TABS.push({
        id: 'permis', group: 5, label: 'Auto-école', ico: '🪪',
        sub: 'Questions du code de la route et prix des permis B, A, C.',
        show: () => has('permis_manage') && !!(D && D.permis),
    });

    const PS = { sub: 'questions', cat: 'common', prices: null };
    const send = (name, data = {}) => action('permis', { name, data });
    const LETTERS = ['A', 'B', 'C', 'D'];

    VIEWS.permis = () => {
        const d = D.permis;
        if (!d.available) {
            return `<div class="protect">⚠️ <span>La ressource <b>${esc(d.resource || 'elyzea_permis')}</b> n'est pas démarrée.
                Ajoute <span class="keycap">ensure ${esc(d.resource || 'elyzea_permis')}</span> dans server.cfg, après admin_menu.</span></div>`;
        }
        const nav = `<div class="segmented">
            <button class="seg ${PS.sub === 'questions' ? 'active' : ''}" data-pss="questions">Questions du code</button>
            <button class="seg ${PS.sub === 'prices' ? 'active' : ''}" data-pss="prices">Prix des permis</button></div>`;
        return nav + (PS.sub === 'questions' ? questionsView(d) : pricesView(d));
    };

    function catTabs(d) {
        const all = [{ key: 'common', short: '★', label: 'Communes à tous les permis', icon: '📘' }, ...d.categories];
        return `<div class="chips" style="margin-bottom:12px">${all.map((c) => `<button class="chip ${PS.cat === c.key ? 'on' : ''}" data-pscat="${c.key}">
            ${c.icon} ${esc(c.key === 'common' ? 'Communes' : c.label)} <small style="opacity:.7">(${(d.questions[c.key] || []).length})</small></button>`).join('')}</div>`;
    }

    function questionsView(d) {
        const list = d.questions[PS.cat] || [];
        const total = (d.questions.common || []).length;
        return `
            <p class="hint">Les questions <b>communes</b> sont posées pour tous les permis, en plus de celles du permis choisi. À chaque examen,
                les questions et l'ordre des réponses sont tirés au hasard. ${total < 10 ? '<b style="color:var(--danger)">Ajoute assez de questions pour remplir un examen.</b>' : ''}</p>
            ${catTabs(d)}
            <div class="btn-row" style="margin-bottom:12px">
                <button class="btn primary" data-psa="add">＋ Ajouter une question</button>
                <span style="flex:1"></span>
                <button class="btn" data-psa="reset">Remettre les questions d'origine</button>
            </div>
            ${list.length ? list.map((q, i) => `<div class="card" style="margin-bottom:8px;padding:12px 14px">
                <div class="inline" style="align-items:flex-start"><strong style="flex:1">${i + 1}. ${esc(q.q)}</strong>
                    <button class="btn" data-psa="edit" data-i="${i}">Modifier</button>
                    <button class="btn danger" data-psa="del" data-i="${i}">✕</button></div>
                <div class="grid" style="grid-template-columns:1fr 1fr;gap:6px;margin-top:8px">${q.a.map((a, j) => `
                    <div style="padding:6px 10px;border-radius:7px;border:1px solid ${j + 1 === q.answer ? 'var(--ok)' : 'var(--line)'};${j + 1 === q.answer ? 'color:var(--ok)' : ''}">
                        <b>${LETTERS[j]}</b> · ${esc(a)} ${j + 1 === q.answer ? '✓' : ''}</div>`).join('')}</div>
            </div>`).join('') : '<div class="empty">Aucune question dans cette catégorie.</div>'}`;
    }

    function pricesView(d) {
        if (!PS.prices) PS.prices = JSON.parse(JSON.stringify(d.prices || {}));
        return `
            <p class="hint">Le prix du code est payé à <b>chaque tentative</b>. Le prix de la conduite est payé à chaque passage de l'examen pratique.
                ${d.holders} joueur(s) ont déjà au moins un permis.</p>
            <table><tr><th>Permis</th><th style="width:200px">Code ($)</th><th style="width:200px">Conduite ($)</th></tr>
                ${d.categories.map((c) => `<tr><td><strong>${c.icon} ${esc(c.label)}</strong></td>
                    <td><input class="input" type="number" min="0" data-psp="${c.key}.code" value="${Number((PS.prices[c.key] || {}).code) || 0}"></td>
                    <td><input class="input" type="number" min="0" data-psp="${c.key}.drive" value="${Number((PS.prices[c.key] || {}).drive) || 0}"></td></tr>`).join('')}
            </table>
            <div class="btn-row" style="margin-top:12px"><button class="btn primary" data-psa="savePrices">Enregistrer les prix</button>
                <button class="btn" data-psa="resetPrices">Annuler</button></div>`;
    }

    async function questionForm(q, index) {
        const v = await formModal(q ? 'Modifier la question' : 'Nouvelle question', [
            { name: 'q', label: 'Question', value: q ? q.q : '', placeholder: 'ex : En ville, la vitesse est limitée à :' },
            { name: 'a1', label: 'Réponse A', value: q ? q.a[0] || '' : '' },
            { name: 'a2', label: 'Réponse B', value: q ? q.a[1] || '' : '' },
            { name: 'a3', label: 'Réponse C (facultative)', value: q ? q.a[2] || '' : '' },
            { name: 'a4', label: 'Réponse D (facultative)', value: q ? q.a[3] || '' : '' },
            { name: 'answer', label: 'Bonne réponse', type: 'select', value: q ? q.answer : 1, options: LETTERS.map((l, i) => ({ value: i + 1, label: `Réponse ${l}` })) },
        ], q ? 'Enregistrer' : 'Ajouter');
        if (!v) return;
        // Les réponses vides sont retirées : la bonne réponse est recalculée sur la liste finale
        const raw = [v.a1, v.a2, v.a3, v.a4].map((x) => String(x || '').trim());
        const good = Number(v.answer);
        if (!raw[good - 1]) return toast('La bonne réponse choisie est vide.', 'error');
        const answers = [], map = {};
        raw.forEach((a, i) => { if (a) { answers.push(a); map[i + 1] = answers.length; } });
        send('saveQuestion', { cat: PS.cat, index: index !== undefined ? index + 1 : undefined, q: v.q, a: answers, answer: map[good] });
    }

    document.addEventListener('input', (e) => {
        if (!isOpen || tab !== 'permis' || !e.target.dataset.psp) return;
        const [cat, kind] = e.target.dataset.psp.split('.');
        (PS.prices[cat] = PS.prices[cat] || {})[kind] = Number(e.target.value) || 0;
    });

    document.addEventListener('click', async (e) => {
        if (!isOpen || tab !== 'permis') return;
        let n;
        if ((n = e.target.closest('[data-pss]'))) { PS.sub = n.dataset.pss; PS.prices = null; return render(); }
        if ((n = e.target.closest('[data-pscat]'))) { PS.cat = n.dataset.pscat; return render(); }
        if (!(n = e.target.closest('[data-psa]'))) return;
        const list = D.permis.questions[PS.cat] || [];
        const i = Number(n.dataset.i);
        switch (n.dataset.psa) {
            case 'add': return questionForm(null);
            case 'edit': return questionForm(list[i], i);
            case 'del':
                if (await confirmBox('Supprimer la question ?', list[i] ? list[i].q : '')) send('deleteQuestion', { cat: PS.cat, index: i + 1 });
                return;
            case 'reset':
                if (await confirmBox('Remettre les questions d\'origine ?', 'Les questions de cette catégorie sont remplacées par celles fournies avec la ressource.')) send('resetQuestions', { cat: PS.cat });
                return;
            case 'savePrices': send('savePrices', { prices: PS.prices }); PS.prices = null; return;
            case 'resetPrices': PS.prices = null; return render();
        }
    });
})();
