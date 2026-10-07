const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_papiers';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

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

function head(title, sub) {
    return `<img class="watermark" src="logo.png" alt="">
        <div class="dc-head"><img src="logo.png" alt=""><div><h2>${title}</h2><small>${sub}</small></div></div>`;
}
function photo(m) { return `<div class="photo">${m.photo ? `<img src="${esc(m.photo)}" alt="">` : '👤'}</div>`; }
function field(label, value, cls = '') { return `<div class="field ${cls}"><small>${label}</small><b>${value}</b></div>`; }

function idCard(m) {
    const d = m.meta || {};
    const birth = frDate(d.birthdate);
    const l1 = `ID${mrzText('ELY', 3)}${mrzText(d.lastname, 14)}<<${mrzText(d.firstname, 12)}`;
    const l2 = `${mrzText(d.number, 10)}${mrzText(String(d.birthdate || '').replace(/\D/g, '').slice(2), 6)}${sexOf(d.gender)}${mrzText(d.citizenid, 12)}`;
    return `${head("CARTE D'IDENTITÉ", 'République d\'Elyzea · État de San Andreas')}
        <div class="dc-body">${photo(m)}
            <div class="fields">
                ${field('Nom', esc(String(d.lastname || '').toUpperCase()))}
                ${field('Prénom', esc(d.firstname))}
                ${field('Né(e) le', esc(birth))}
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
    const expired = d.expiresAt && m.now && m.now > d.expiresAt;
    return `${head("PERMIS DE PORT D'ARME", 'Aptitude médicale · Services médicaux d\'Elyzea')}
        <div class="dc-body">${photo(m)}
            <div class="fields">
                ${field('Nom', esc(String(d.lastname || '').toUpperCase()))}
                ${field('Prénom', esc(d.firstname))}
                ${field('Né(e) le', esc(frDate(d.birthdate)))}
                ${field('Délivré le', esc(d.issued))}
                ${field('Valide jusqu\'au', esc(d.expires || 'Illimité'))}
                ${field('Médecin', esc(d.doctor || '—'))}
                ${field('N° de PPA', `<span class="num">${esc(d.number)}</span>`, 'wide')}
            </div>
        </div>
        <div class="status">
            <span class="stamp ${expired ? 'bad' : 'ok'}">${expired ? 'EXPIRÉ' : 'APTE'}</span>
            <small>${expired ? 'Ce permis n\'est plus valide : nouvelle visite médicale nécessaire.' : 'Port d\'arme autorisé après examen médical.<br>Document personnel, à présenter sur demande.'}</small>
        </div>`;
}

function openCard(m) {
    const doc = $('#doc');
    doc.className = `doc ${m.kind}`;
    doc.innerHTML = m.kind === 'ppa' ? ppaCard(m) : idCard(m);
    const what = m.kind === 'ppa' ? 'le permis' : 'la carte';
    $('#actions').innerHTML = m.own
        ? `<button class="btn" data-a="close">Ranger</button><button class="btn primary" data-a="show" data-slot="${Number(m.slot)}">Montrer à la personne la plus proche</button>`
        : `<button class="btn primary" data-a="close">Rendre ${what}</button>`;
    $('#card').classList.remove('hidden');
}

function close() {
    $('#card').classList.add('hidden');
    nui('close');
}

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'card') openCard(m);
});
$('#actions').addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b) return;
    if (b.dataset.a === 'show') nui('show', { slot: Number(b.dataset.slot) });
    close();
});
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !$('#card').classList.contains('hidden')) close();
});
