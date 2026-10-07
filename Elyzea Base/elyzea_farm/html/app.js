const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_farm';
const nui = (endpoint, data = {}) =>
    fetch(`https://${RES}/${endpoint}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).catch(() => {});
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => `${Number(n || 0).toLocaleString('fr-FR')} $`;

let D = null;

function render() {
    const d = D;
    if (!d) return;
    const job = d.label.toLowerCase();
    const amount = d.minAmount === d.maxAmount ? `${d.minAmount}` : `${d.minAmount} à ${d.maxAmount}`;
    let body;
    if (!d.enabled && !d.working) {
        body = `<p>Le travail de ${esc(job)} est fermé pour le moment. Revenez plus tard.</p>`;
    } else if (d.otherFarm) {
        body = `<p>Vous travaillez déjà comme <b>${esc(d.otherFarm.toLowerCase())}</b>. Arrêtez d'abord ce travail auprès de son responsable.</p>`;
    } else if (d.working) {
        body = `<span class="status on">● En train de travailler</span>
            <p style="margin-top:12px">Voulez-vous <b>arrêter de travailler</b> en tant que ${esc(job)} ? Vous retrouverez votre tenue d'origine.</p>
            <div class="row"><button class="btn danger" data-a="stop">Arrêter de travailler</button></div>`;
    } else {
        body = `<p>Voulez-vous <b>travailler en tant que ${esc(job)}</b> ?<br>On vous donne votre tenue de travail. Rendez-vous ensuite dans une zone de travail
            (marquée sur votre carte) et appuyez sur <b>ALT</b> devant un arbre.</p>
            <div class="facts"><span class="chip">⏱️ ${d.time} s par coupe</span><span class="chip">🪵 ${amount} × ${esc(d.item.toLowerCase())}</span>
                <span class="chip">💰 ${money(d.price)} pièce</span><span class="chip">🗺️ ${d.zones} zone(s)</span></div>
            <div class="row"><button class="btn" data-a="close">Non merci</button><button class="btn primary" data-a="start" ${d.zones ? '' : 'disabled title="Aucune zone de travail"'}>Oui, je commence</button></div>`;
    }
    const sell = d.count > 0 ? `<div class="sell"><div class="txt"><b>Vendre ma récolte · ${esc(d.item)}</b>
            <small>${d.count} en inventaire · ${money(d.price)} pièce · payé en ${d.payWith === 'bank' ? 'banque' : 'liquide'}</small></div>
            <span class="price">${money(d.count * d.price)}</span><button class="btn primary" data-a="sell">Vendre</button></div>` : '';
    $('#box').innerHTML = `<button class="close" data-a="close" title="Fermer">✕</button>
        <img class="crest" src="logo.png" alt=""><span class="eyebrow">${esc(d.name)}</span>
        <div class="big-ico">${d.icon}</div><h2>${esc(d.label)}</h2>${body}${sell}`;
    $('#npc').classList.remove('hidden');
}

function close() {
    $('#npc').classList.add('hidden');
    D = null;
    nui('close');
}

$('#box').addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b || b.disabled) return;
    const a = b.dataset.a;
    if (a === 'close') return close();
    if (a === 'start') { nui('work', { state: true }); return close(); }
    if (a === 'stop') { nui('work', { state: false }); return close(); }
    if (a === 'sell') nui('sell');
});
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && D) close(); });

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'npc') { D = m.data; render(); }
    if (m.action === 'npcData' && D) { D = m.data; render(); }
});
