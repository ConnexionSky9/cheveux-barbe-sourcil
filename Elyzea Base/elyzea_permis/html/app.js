const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_permis';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
const LETTERS = ['A', 'B', 'C', 'D'];

const S = { status: null, quiz: null, lastQuiz: null, index: 0, answers: [], busy: false };
// 1996-04-12 → 12/04/1996
const frDate = (d) => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(d || '')); return m ? `${m[3]}/${m[2]}/${m[1]}` : (d || '—'); };

window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'open': S.status = m.status; S.quiz = null; show(); return renderHome();
        case 'hide': return $('#app').classList.add('hidden');
        case 'quiz': S.quiz = m.data; S.index = 0; S.answers = []; S.busy = false; show(); return renderQuestion();
        case 'quizResult': S.status = m.data.status; return renderResult(m.data);
        case 'examHud':
            $('#hud').classList.toggle('hidden', !m.show);
            if (m.show) $('#hudLabel').textContent = m.label || '';
            return;
        case 'examTick': return examTick(m);
        case 'fault': return fault(m.text);
        case 'examResult': show(); return renderExamResult(m.data);
        case 'card': return openCard(m);
    }
});

function show() { $('#app').classList.remove('hidden'); }
function close() {
    $('#app').classList.add('hidden');
    $('#card').classList.add('hidden');
    nui('close');
}
$('#closeBtn').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && (!$('#app').classList.contains('hidden') || !$('#card').classList.contains('hidden'))) close();
    // Touches 1 à 4 / A à D pendant le code
    if (S.quiz && !S.busy && !$('#app').classList.contains('hidden')) {
        const k = e.key.toUpperCase();
        const i = ['1', '2', '3', '4'].indexOf(k) >= 0 ? ['1', '2', '3', '4'].indexOf(k) : LETTERS.indexOf(k);
        if (i >= 0 && S.quiz.questions[S.index] && i < S.quiz.questions[S.index].a.length) answer(i + 1);
    }
});

/* ---------- Accueil ---------- */
function renderHome() {
    const st = S.status;
    $('#schoolName').textContent = st.name;
    $('#screen').innerHTML = `
        <p class="lead">Choisis ton permis. Chaque permis se passe en deux étapes : <b>le code</b> (${st.questions} questions, ${st.passScore} bonnes réponses
            pour réussir), puis <b>la conduite</b> : un parcours qui revient à l'auto-école, en respectant les limitations de vitesse.</p>
        <div class="cats">${st.categories.map((c, i) => {
            const btn = c.license ? '<button class="btn" disabled>✓ Permis obtenu</button>'
                : c.theory ? `<button class="btn primary" data-exam="${c.key}" ${st.routeReady ? '' : 'disabled title="Parcours pas encore prêt"'}>Passer la conduite · ${money(c.drivePrice)}</button>`
                : `<button class="btn primary" data-quiz="${c.key}">Passer le code · ${money(c.codePrice)}</button>`;
            return `<div class="cat ${c.license ? 'done' : ''}" style="animation-delay:${i * 60}ms">
                <span class="letter">${c.short}</span><span class="ico">${c.icon}</span><h2>${esc(c.label)}</h2>
                <div class="steps"><span class="step ${c.theory || c.license ? 'ok' : ''}">${c.theory || c.license ? '✓ ' : ''}Code</span>
                    <span class="step ${c.license ? 'ok' : ''}">${c.license ? '✓ ' : ''}Conduite</span></div>
                ${btn}</div>`;
        }).join('')}</div>
        <div class="rules">
            ${st.categories.map((c) => `<span class="chip">${c.icon} ${c.short} : code ${money(c.codePrice)} · conduite ${money(c.drivePrice)}</span>`).join('')}
            ${st.routeMinutes ? `<span class="chip">⏱️ Parcours d'environ ${st.routeMinutes} min</span>` : '<span class="chip">⚠️ Parcours pas encore prêt</span>'}
            <span class="chip">⚠️ ${st.maxFaults} faute${st.maxFaults > 1 ? 's' : ''} maximum à la conduite</span>
        </div>`;
}

/* ---------- Code ---------- */
function renderQuestion() {
    const q = S.quiz.questions[S.index];
    const n = S.quiz.questions.length;
    $('#schoolName').textContent = S.quiz.label;
    $('#screen').innerHTML = `
        <div class="progress"><span style="width:${(S.index / n) * 100}%"></span></div>
        <div class="qnum">Question ${S.index + 1} sur ${n}</div>
        <div class="question">${esc(q.q)}</div>
        <div class="answers">${q.a.map((a, i) => `<button class="answer" data-answer="${i + 1}" style="animation-delay:${i * 40}ms"><span class="key">${LETTERS[i]}</span>${esc(a)}</button>`).join('')}</div>
        <p class="muted" style="margin-top:16px;font-size:.82rem">Clique sur une réponse (ou touche A à D / 1 à 4). Pas de retour en arrière.</p>`;
}

function answer(i) {
    if (S.busy) return;
    S.busy = true;
    const btn = document.querySelector(`[data-answer="${i}"]`);
    if (btn) btn.classList.add('picked');
    S.answers[S.index] = i;
    setTimeout(() => {
        S.busy = false;
        S.index += 1;
        if (S.index < S.quiz.questions.length) return renderQuestion();
        S.busy = true;
        S.lastQuiz = S.quiz;
        $('#screen').innerHTML = '<div class="result"><div class="big gold-text">…</div><h2>Correction en cours</h2></div>';
        nui('submitQuiz', { answers: S.answers });
    }, 260);
}

function renderResult(r) {
    S.quiz = null; S.busy = false;
    const qs = r.corrections || [];
    $('#screen').innerHTML = `
        <div class="result ${r.passed ? 'win' : 'lose'}">
            <div class="eyebrow">${r.passed ? 'Code réussi' : 'Code échoué'}</div>
            <div class="big">${r.score}/${r.total}</div>
            <h2>${r.passed ? 'Félicitations ! Vous pouvez passer à la conduite.' : 'Échec. Repayez le code et recommencez.'}</h2>
            <p class="muted" style="margin-top:6px">Il fallait ${r.need} bonne${r.need > 1 ? 's' : ''} réponse${r.need > 1 ? 's' : ''}.</p>
        </div>
        ${!r.passed && qs.some((c) => c.given !== c.good) ? `<div class="corr">${qs.map((c, i) => {
            if (c.given === c.good) return '';
            const q = S.lastQuiz && S.lastQuiz.questions[i];
            const txt = (n) => (q && q.a[n - 1] ? `${LETTERS[n - 1]} · ${esc(q.a[n - 1])}` : LETTERS[n - 1] || '—');
            return `<div class="corr-item"><b>${q ? esc(q.q) : `Question ${i + 1}`}</b><br>
                Ta réponse : <span class="bad">${c.given ? txt(c.given) : 'aucune'}</span> · bonne réponse : <span class="good">${txt(c.good)}</span></div>`;
        }).join('')}</div>` : ''}
        <div class="row-end" style="justify-content:center">
            ${r.passed ? `<button class="btn" data-home>Plus tard</button><button class="btn primary" data-exam="${r.cat}" ${S.status.routeReady ? '' : 'disabled'}>Passer à la conduite · ${money((S.status.categories.find((c) => c.key === r.cat) || {}).drivePrice)}</button>`
                : `<button class="btn" data-home>Retour</button><button class="btn primary" data-quiz="${r.cat}">Repayer et recommencer · ${money(r.codePrice)}</button>`}
        </div>`;
}

function renderExamResult(r) {
    $('#schoolName').textContent = r.label;
    $('#screen').innerHTML = `
        <div class="result ${r.passed ? 'win' : 'lose'}">
            <div class="eyebrow">Examen de conduite</div>
            <div class="big">${r.passed ? '🎉' : '✕'}</div>
            <h2>${r.passed ? 'Permis obtenu !' : 'Examen échoué'}</h2>
            <p class="muted" style="margin-top:8px">${esc(r.reason || '')}</p>
            <p style="margin-top:12px">${r.passed ? 'Ton <b>permis de conduire</b> est dans ton inventaire : utilise-le pour le regarder ou le montrer.'
                : 'Ton code reste valable : reviens à l\'auto-école pour repasser la conduite.'}</p>
        </div>
        <div class="row-end" style="justify-content:center"><button class="btn primary" data-close>Fermer</button></div>`;
}

$('#screen').addEventListener('click', (e) => {
    const a = e.target.closest('[data-answer]');
    if (a) return answer(Number(a.dataset.answer));
    const q = e.target.closest('[data-quiz]');
    if (q && !q.disabled) { q.disabled = true; return nui('startQuiz', { cat: q.dataset.quiz }); }
    const x = e.target.closest('[data-exam]');
    if (x && !x.disabled) return nui('startExam', { cat: x.dataset.exam });
    if (e.target.closest('[data-home]')) return renderHome();
    if (e.target.closest('[data-close]')) return close();
});

/* ---------- Compteur de conduite ---------- */
function examTick(m) {
    $('#hudSpeed').textContent = m.speed;
    $('#hudLimit').textContent = m.limit;
    $('#gauge').classList.toggle('over', m.speed > m.limit);
    $('#hudPoint').textContent = `${m.point}/${m.total}`;
    $('#hudFaults').textContent = `${m.faults}/${m.max}`;
    $('#hudTime').textContent = mmss(m.elapsed);
}
function fault(text) {
    const el = document.createElement('div');
    el.className = 'fault';
    el.textContent = `Faute : ${text}`;
    $('#faults').appendChild(el);
    setTimeout(() => el.remove(), 3500);
}

/* ---------- Permis de conduire ---------- */
function openCard(m) {
    const d = m.meta || {};
    const have = {};
    (d.categories || []).forEach((c) => { have[c.short] = c.date; });
    const sex = d.gender === 1 || d.gender === '1' ? 'F' : 'M';
    $('#license').innerHTML = `
        <div class="lc-head"><img src="logo.png" alt=""><div><h2>PERMIS DE CONDUIRE</h2><small>État de San Andreas · Elyzea</small></div></div>
        <div class="lc-body">
            <div class="photo">${m.photo ? `<img src="${esc(m.photo)}" alt="">` : '👤'}</div>
            <div class="fields">
                <div class="field"><small>Nom</small><b>${esc((d.lastname || '').toUpperCase())}</b></div>
                <div class="field"><small>Prénom</small><b>${esc(d.firstname || '')}</b></div>
                <div class="field"><small>Né(e) le</small><b>${esc(frDate(d.birthdate))}</b></div>
                <div class="field"><small>Sexe</small><b>${sex}</b></div>
                <div class="field wide"><small>N° de permis</small><b class="num">${esc(d.number || '')}</b></div>
            </div>
        </div>
        <div class="lc-cats">${[['A', 'Moto'], ['B', 'Voiture'], ['C', 'Poids lourd']].map(([k, l]) => `<div class="lc-cat ${have[k] ? 'on' : ''}"><b class="${have[k] ? 'gold-text' : ''}">${k}</b><small>${have[k] ? esc(have[k]) : l}</small></div>`).join('')}</div>`;
    $('#licenseActions').innerHTML = m.own
        ? `<button class="btn" data-card="close">Ranger</button><button class="btn primary" data-card="show" data-slot="${m.slot}">Montrer à la personne la plus proche</button>`
        : '<button class="btn primary" data-card="close">Rendre le permis</button>';
    $('#app').classList.add('hidden');
    $('#card').classList.remove('hidden');
}
$('#licenseActions').addEventListener('click', (e) => {
    const b = e.target.closest('[data-card]');
    if (!b) return;
    if (b.dataset.card === 'show') nui('showLicense', { slot: Number(b.dataset.slot) });
    close();
});
