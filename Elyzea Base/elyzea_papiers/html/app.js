const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_papiers';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;
const LETTERS = ['A', 'B', 'C', 'D'];

// 2000-01-31 -> 31/01/2000 (déjà au bon format : inchangé)
function frDate(v) {
    const m = String(v || '').match(/^(\d{4})-(\d{2})-(\d{2})/);
    return m ? `${m[3]}/${m[2]}/${m[1]}` : String(v || '');
}
const sexOf = (g) => (g === 1 || g === '1' ? 'F' : 'M');

// Bande « MRZ » : lettres sans accents, chevrons à la place des espaces
function mrzText(s, len) {
    const t = String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z0-9]/g, '<');
    return (t + '<'.repeat(len)).slice(0, len);
}

const S = { gov: null, govPhoto: null, view: 'home', pay: 'bank', offer: null, offerTimer: null, test: null, index: 0, answers: [], busy: false };

/* =========================================================
   Papiers
   ========================================================= */
function head(title, sub) {
    return `<img class="watermark" src="logo.png" alt="">
        <div class="dc-head"><img src="logo.png" alt=""><div><h2>${title}</h2><small>${sub}</small></div></div>`;
}
function photo(src) { return `<div class="photo">${src ? `<img src="${esc(src)}" alt="">` : '👤'}</div>`; }
function field(label, value, cls = '') { return `<div class="field ${cls}"><small>${label}</small><b>${value}</b></div>`; }

function idCard(m) {
    const d = m.meta || {};
    const l1 = `ID${mrzText('ELY', 3)}${mrzText(d.lastname, 14)}<<${mrzText(d.firstname, 12)}`;
    const l2 = `${mrzText(d.number, 10)}${mrzText(String(d.birthdate || '').replace(/\D/g, '').slice(2), 6)}${sexOf(d.gender)}${mrzText(d.citizenid, 12)}`;
    return `${head("CARTE D'IDENTITÉ", 'République d\'Elyzea · État de San Andreas')}
        <div class="dc-body">${photo(m.photo)}
            <div class="fields">
                ${field('Nom', esc(String(d.lastname || '').toUpperCase()))}
                ${field('Prénom', esc(d.firstname))}
                ${field('Né(e) le', esc(frDate(d.birthdate)))}
                ${field('Sexe', sexOf(d.gender))}
                ${field('Nationalité', esc(d.nationality))}
                ${field('Délivrée le', esc(d.issued))}
                ${field('N° de carte', `<span class="num">${esc(d.number)}</span>`, 'wide')}
            </div>
        </div>
        <div class="mrz">${esc(l1)}<br>${esc(l2)}</div>`;
}

function ppaCard(m) {
    const d = m.meta || {};
    const fdo = m.sub === 'fdo';
    const expired = d.expiresAt && m.now && m.now > d.expiresAt;
    const cats = Array.isArray(d.categories) && d.categories.length ? d.categories : (fdo ? ['Arme légère', 'Arme lourde'] : ['Pistolet']);
    return `${head("PERMIS DE PORT D'ARME", fdo ? 'Forces de l\'ordre · Aptitude médicale' : 'Civil · Aptitude médicale · Elyzea')}
        <div class="dc-body">${photo(m.photo)}
            <div class="fields">
                ${field('Nom', esc(String(d.lastname || '').toUpperCase()))}
                ${field('Prénom', esc(d.firstname))}
                ${field('Né(e) le', esc(frDate(d.birthdate)))}
                ${field('Délivré le', esc(d.issued))}
                ${field('Valide jusqu\'au', esc(d.expires || 'Illimité'))}
                ${field('Médecin', esc(d.doctor || '—'))}
                ${field(fdo ? 'N° de PPA FDO' : 'N° de PPA', `<span class="num">${esc(d.number)}</span>`, 'wide')}
            </div>
        </div>
        <div class="wcats">${cats.map((c) => `<div class="wcat"><span class="chk">✓</span><b>${esc(c)}</b></div>`).join('')}</div>
        <div class="status">
            <span class="stamp ${expired ? 'bad' : 'ok'}">${expired ? 'EXPIRÉ' : 'APTE'}</span>
            <small>${expired ? 'Ce permis n\'est plus valide : nouveau test PPA nécessaire.' : `Catégorie${cats.length > 1 ? 's' : ''} autorisée${cats.length > 1 ? 's' : ''} ci-dessus.<br>Document personnel, à présenter sur demande.`}</small>
        </div>`;
}

function openCard(m) {
    const doc = $('#doc');
    doc.className = `doc ${m.kind} ${m.sub || ''}`;
    doc.innerHTML = m.kind === 'ppa' ? ppaCard(m) : idCard(m);
    const what = m.kind === 'ppa' ? 'le permis' : 'la carte';
    $('#actions').innerHTML = m.own
        ? `<button class="btn" data-a="close">Ranger</button><button class="btn primary" data-a="show" data-slot="${Number(m.slot)}">Montrer à la personne la plus proche</button>`
        : `<button class="btn primary" data-a="close">Rendre ${what}</button>`;
    $('#card').classList.remove('hidden');
}
$('#actions').addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b) return;
    if (b.dataset.a === 'show') nui('show', { slot: Number(b.dataset.slot) });
    closeAll();
});

/* =========================================================
   Paiement (banque / liquide)
   ========================================================= */
function payPicker(gov) {
    if ((gov ? S.gov.payWith : (S.offer && S.offer.payWith)) !== 'choice') return '';
    const m = gov ? S.gov.money : null;
    return `<div class="pay"><small>Payer par :</small>
        <button class="seg ${S.pay === 'bank' ? 'on' : ''}" data-pay="bank">🏦 Banque${m ? ` · ${money(m.bank)}` : ''}</button>
        <button class="seg ${S.pay === 'cash' ? 'on' : ''}" data-pay="cash">💵 Liquide${m ? ` · ${money(m.cash)}` : ''}</button></div>`;
}
document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-pay]');
    if (!b) return;
    S.pay = b.dataset.pay;
    b.parentElement.querySelectorAll('.seg').forEach((x) => x.classList.toggle('on', x === b));
});

/* =========================================================
   Guichet du gouvernement
   ========================================================= */
function showApp(eyebrow, title) {
    $('#appEyebrow').textContent = eyebrow;
    $('#appTitle').textContent = title;
    $('#app').classList.remove('hidden');
}

function renderGov() {
    const g = S.gov;
    if (!g) return;
    showApp('Gouvernement d\'Elyzea', g.name);
    const id = g.identity || {};
    const ic = g.idCard, ch = g.change;
    if (S.view === 'change') return renderChange();
    $('#screen').innerHTML = `
        <p class="lead">Bienvenue au guichet. Vos papiers officiels sont délivrés ici, avec votre photo d'identité.</p>
        <div class="idline" style="margin-bottom:18px">${photo(S.govPhoto)}<div><b>${esc(id.firstname)} ${esc(String(id.lastname || '').toUpperCase())}</b>
            <small>Né(e) le ${esc(frDate(id.birthdate))} · ${esc(id.nationality || '')} · ${sexOf(id.gender) === 'F' ? 'Femme' : 'Homme'}</small></div></div>
        <div class="services">
            <div class="service ${ic.enabled ? '' : 'off'}">
                <span class="ico">🪪</span><h2>Carte d'identité</h2>
                <p class="note">Carte officielle avec photo, à présenter lors des contrôles.</p>
                <span class="price gold-text">${ic.free ? 'Gratuite' : money(ic.price)}</span>
                ${ic.free ? '<p class="note">Votre première carte est offerte.</p>' : ''}
                ${ic.hasCard && ic.onlyOne ? '<p class="note warn">Vous avez déjà une carte d\'identité sur vous.</p>' : ''}
                ${ic.free ? '' : payPicker(true)}
                <button class="btn primary" data-gov="buy" ${!ic.enabled || (ic.hasCard && ic.onlyOne) ? 'disabled' : ''}>Obtenir ma carte</button>
            </div>
            <div class="service ${ch.enabled ? '' : 'off'}">
                <span class="ico">✍️</span><h2>Changement d'identité</h2>
                <p class="note">Modifier ${[ch.fields.firstname && 'le prénom', ch.fields.lastname && 'le nom', ch.fields.birthdate && 'la date de naissance', ch.fields.nationality && 'la nationalité', ch.fields.gender && 'le sexe'].filter(Boolean).join(', ')}.
                    ${ch.newCard ? 'Une nouvelle carte d\'identité vous est remise.' : ''}</p>
                <span class="price gold-text">${money(ch.price)}</span>
                ${ch.cooldownDays > 0 ? `<p class="note warn">Prochain changement possible dans ${ch.cooldownDays} jour${ch.cooldownDays > 1 ? 's' : ''}.</p>` : ''}
                <button class="btn primary" data-gov="change" ${!ch.enabled || ch.cooldownDays > 0 ? 'disabled' : ''}>Faire une demande</button>
            </div>
        </div>`;
}

function renderChange() {
    const g = S.gov, id = g.identity || {}, ch = g.change, f = ch.fields;
    const max = new Date(); max.setFullYear(max.getFullYear() - ch.minAge);
    const min = new Date(); min.setFullYear(min.getFullYear() - ch.maxAge);
    const iso = (d) => d.toISOString().slice(0, 10);
    $('#screen').innerHTML = `
        <button class="btn back" data-gov="home">← Retour</button>
        <p class="lead">Remplissez votre nouvelle identité. Les champs grisés ne peuvent pas être modifiés.
            Prix : <b class="gold-text">${money(ch.price)}</b>${ch.newCard ? ' · nouvelle carte d\'identité offerte' : ''}.</p>
        <div class="form">
            <div><label>Prénom</label><input class="input" id="fFirst" maxlength="${ch.nameMax}" value="${esc(id.firstname)}" ${f.firstname ? '' : 'disabled'}></div>
            <div><label>Nom</label><input class="input" id="fLast" maxlength="${ch.nameMax}" value="${esc(id.lastname)}" ${f.lastname ? '' : 'disabled'}></div>
            <div><label>Date de naissance</label><input class="input" id="fBirth" type="date" min="${iso(min)}" max="${iso(max)}" value="${esc(String(id.birthdate || '').slice(0, 10))}" ${f.birthdate ? '' : 'disabled'}></div>
            <div><label>Nationalité</label><select class="input" id="fNat" ${f.nationality ? '' : 'disabled'}>
                ${[...new Set([id.nationality, ...(ch.nationalities || [])].filter(Boolean))].map((n) => `<option ${n === id.nationality ? 'selected' : ''}>${esc(n)}</option>`).join('')}</select></div>
            <div><label>Sexe</label><select class="input" id="fGender" ${f.gender ? '' : 'disabled'}>
                <option value="0" ${String(id.gender) !== '1' ? 'selected' : ''}>Homme</option><option value="1" ${String(id.gender) === '1' ? 'selected' : ''}>Femme</option></select></div>
        </div>
        ${payPicker(true)}
        <p class="note" style="margin-top:12px">Noms : ${ch.nameMin} à ${ch.nameMax} lettres, sans chiffres. Âge : ${ch.minAge} à ${ch.maxAge} ans.</p>
        <div class="row-end"><button class="btn" data-gov="home">Annuler</button><button class="btn primary" data-gov="send">Valider et payer ${money(ch.price)}</button></div>`;
}

$('#screen').addEventListener('click', (e) => {
    const b = e.target.closest('[data-gov]');
    if (b && !b.disabled) {
        const a = b.dataset.gov;
        if (a === 'buy') return nui('govBuy', { method: S.pay });
        if (a === 'change') { S.view = 'change'; return renderGov(); }
        if (a === 'home') { S.view = 'home'; return renderGov(); }
        if (a === 'send') {
            const data = {
                firstname: $('#fFirst').value, lastname: $('#fLast').value, birthdate: $('#fBirth').value,
                nationality: $('#fNat').value, gender: Number($('#fGender').value),
            };
            S.view = 'home';
            return nui('govChange', { data, method: S.pay });
        }
    }
    const ans = e.target.closest('[data-answer]');
    if (ans) answer(Number(ans.dataset.answer));
    if (e.target.closest('[data-test="close"]')) closeAll();
});

/* =========================================================
   Test PPA : demande (avec le prix), questions, résultat
   ========================================================= */
function openOffer(o) {
    S.offer = o;
    let left = o.timeout || 45;
    $('#offerBox').innerHTML = `<img class="crest" src="logo.png" alt=""><span class="eyebrow">Services médicaux d'Elyzea</span>
        <h2>${esc(o.label)}</h2>
        <p><b>${esc(o.ems)}</b> vous propose de passer le test du permis de port d'arme :
            ${o.questions} questions et mises en situation, ${o.passScore} bonnes réponses pour réussir.</p>
        <p style="margin-top:8px">Catégorie${(o.categories || []).length > 1 ? 's' : ''} : <b>${(o.categories || []).map(esc).join(', ')}</b></p>
        <div class="price gold-text">${o.price > 0 ? money(o.price) : 'Gratuit'}</div>
        ${o.price > 0 ? payPicker(false) : ''}
        <div class="row-end"><button class="btn danger" data-offer="no">Refuser</button><button class="btn primary" data-offer="yes">Accepter${o.price > 0 ? ' et payer' : ''}</button></div>
        <div class="timer"><span id="offerBar" style="width:100%"></span></div>`;
    $('#offer').classList.remove('hidden');
    clearInterval(S.offerTimer);
    S.offerTimer = setInterval(() => {
        left -= 1;
        const bar = $('#offerBar');
        if (bar) bar.style.width = `${Math.max(0, left / (o.timeout || 45) * 100)}%`;
        if (left <= 0) answerOffer(false);
    }, 1000);
}
function answerOffer(accept) {
    clearInterval(S.offerTimer);
    if (!S.offer) return;
    S.offer = null;
    $('#offer').classList.add('hidden');
    nui('offerAnswer', { accept, method: S.pay });
}
$('#offerBox').addEventListener('click', (e) => {
    const b = e.target.closest('[data-offer]');
    if (b) answerOffer(b.dataset.offer === 'yes');
});

function openTest(t) {
    S.test = t; S.index = 0; S.answers = []; S.busy = false;
    showApp('Test du permis de port d\'arme', t.label);
    renderQuestion();
}
function renderQuestion() {
    const t = S.test, q = t.questions[S.index];
    $('#screen').innerHTML = `
        <div class="progress"><span style="width:${S.index / t.questions.length * 100}%"></span></div>
        <div class="qhead"><span class="qnum">Question ${S.index + 1} / ${t.questions.length}</span>
            <span class="badge ${q.kind === 'situation' ? 'sit' : ''}">${q.kind === 'situation' ? 'Mise en situation' : 'Connaissances'}</span></div>
        <div class="question">${esc(q.text)}</div>
        <div class="answers">${q.answers.map((a, i) => `<button class="answer" data-answer="${i + 1}" style="animation-delay:${i * 50}ms"><span class="key">${LETTERS[i]}</span><span>${esc(a)}</span></button>`).join('')}</div>`;
}
function answer(n) {
    if (!S.test || S.busy) return;
    S.answers[S.index] = n;
    S.index += 1;
    if (S.index < S.test.questions.length) return renderQuestion();
    S.busy = true;
    $('#screen').innerHTML = '<div class="result"><h2>Correction en cours…</h2></div>';
    nui('testSubmit', { answers: S.answers });
}
function showResult(r) {
    S.test = null;
    showApp('Test du permis de port d\'arme', r.label);
    $('#screen').innerHTML = `<div class="result ${r.passed ? 'ok' : 'ko'}">
        <span class="eyebrow">${r.passed ? 'Test réussi' : 'Test échoué'}</span>
        <div class="big">${r.score} / ${r.total}</div>
        <h2>${r.passed ? 'Félicitations !' : 'Ce n\'est pas suffisant.'}</h2>
        <p class="lead" style="margin-top:10px">${r.passed
            ? 'Présentez-vous à l\'EMS : il peut maintenant vous remettre votre permis de port d\'arme.'
            : `Il fallait ${r.passScore} bonnes réponses. L'EMS ne peut pas vous délivrer le PPA : il faudra repasser le test.`}</p>
        <div class="row-end" style="justify-content:center"><button class="btn primary" data-test="close">Fermer</button></div></div>`;
}

/* =========================================================
   Messages du jeu, fermeture
   ========================================================= */
function closeAll() {
    const cancelTest = !!S.test;
    $('#card').classList.add('hidden');
    $('#app').classList.add('hidden');
    S.gov = null; S.test = null; S.view = 'home';
    nui('close', { cancelTest });
}
$('#closeBtn').addEventListener('click', closeAll);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#offer').classList.contains('hidden')) return answerOffer(false);
    if (e.key === 'Escape' && (!$('#card').classList.contains('hidden') || !$('#app').classList.contains('hidden'))) return closeAll();
    if (S.test && !S.busy && !$('#app').classList.contains('hidden')) {
        const k = e.key.toUpperCase();
        const i = ['1', '2', '3', '4'].includes(k) ? Number(k) - 1 : LETTERS.indexOf(k);
        const q = S.test.questions[S.index];
        if (i >= 0 && q && i < q.answers.length) answer(i + 1);
    }
});

window.addEventListener('message', (e) => {
    const m = e.data || {};
    switch (m.action) {
        case 'card': return openCard(m);
        case 'gov': S.gov = m.data; S.govPhoto = m.photo; S.view = 'home'; S.pay = m.data.payWith === 'cash' ? 'cash' : 'bank'; return renderGov();
        case 'govData': if (S.gov) { S.gov = m.data; renderGov(); } return;
        case 'offer': S.pay = m.data.payWith === 'cash' ? 'cash' : 'bank'; return openOffer(m.data);
        case 'test': return openTest(m.data);
        case 'result': return showResult(m.data);
        case 'closeAll': $('#card').classList.add('hidden'); $('#app').classList.add('hidden'); S.gov = null; return;
    }
});
