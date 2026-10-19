/* =====================================================================
   ELYZEA FAMILLE - interfaces NUI
   Tous les textes venant du serveur sont échappés (aucun HTML injecté).
   ===================================================================== */
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'elyzea_famille';
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => {});

let consentId = null;
let consentTimer = null;
let noirTimer = null;

function hideAll() {
  ['#consentement', '#proposer', '#panneau', '#grossesse'].forEach((s) => $(s).classList.add('hidden'));
  if (consentTimer) { clearTimeout(consentTimer); consentTimer = null; }
}

function renderOptions(box, options) {
  box.innerHTML = (options || []).map((o) => `
    <label class="option ${o.desactive ? 'off' : ''}">
      <input type="checkbox" data-cle="${esc(o.cle)}" ${o.desactive ? 'disabled' : ''}>
      <span>${esc(o.label)}${o.aide ? `<small>${esc(o.aide)}</small>` : ''}</span>
    </label>`).join('');
}

function readOptions(box) {
  const out = {};
  box.querySelectorAll('input[type=checkbox]').forEach((i) => { out[i.dataset.cle] = i.checked && !i.disabled; });
  return out;
}

/* ---------- Consentement ---------- */
function openConsent(d) {
  hideAll();
  consentId = d.id;
  const c = d.contenu || {};
  $('#c-badge').textContent = c.type === 'medical' ? '🩺' : '♡';
  $('#c-titre').textContent = c.titre || 'Demande';
  $('#c-texte').textContent = c.texte || '';
  $('#c-aide').textContent = c.aide || '';
  renderOptions($('#c-options'), c.options);
  $('#consentement').classList.remove('hidden');
  const bar = $('#c-barre');
  bar.style.transition = 'none'; bar.style.width = '100%';
  requestAnimationFrame(() => requestAnimationFrame(() => {
    bar.style.transition = `width ${Math.max(1, d.secondes || 30)}s linear`; bar.style.width = '0%';
  }));
  $('#c-accepter').focus();
}
function answerConsent(ok) {
  if (!consentId) return;
  const id = consentId; consentId = null;
  post('consentement', { id, accepte: ok, options: ok ? readOptions($('#c-options')) : {} });
  hideAll();
}
$('#c-accepter').addEventListener('click', () => answerConsent(true));
$('#c-refuser').addEventListener('click', () => answerConsent(false));

/* ---------- Proposer ---------- */
function openPropose(d) {
  hideAll();
  $('#p-texte').textContent = `Personne en face de vous (ID ${d.cible}). Durée : ${d.duree} secondes, écran noir.`;
  renderOptions($('#p-options'), d.options);
  $('#proposer').classList.remove('hidden');
  $('#p-envoyer').focus();
}
$('#p-envoyer').addEventListener('click', () => { post('proposer', { envoyer: true, options: readOptions($('#p-options')) }); hideAll(); });
$('#p-annuler').addEventListener('click', () => { post('proposer', { envoyer: false }); hideAll(); });

/* ---------- Ma contraception ---------- */
const ACTIONS = { prise: 'Prise', pose: 'Pose', retrait: 'Retrait', ordonnance: 'Ordonnance', utilise: 'Utilisé' };
const METHODES = { pilule: 'Pilule', implant: 'Implant', preservatif: 'Préservatif' };
const ETATS = { active: 'Active', expiree: 'Expirée', aucune: 'Aucune' };
function fmtDate(ts) {
  if (!ts) return '';
  const d = new Date(ts * 1000);
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' }) + ' ' + d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
}
function openPanel(d) {
  hideAll();
  const m = d.donnees || {};
  let html = (m.methodes || []).map((x) => `
    <div class="methode"><b>${esc(x.label)}</b><span class="etat ${esc(x.etat)}">${esc(ETATS[x.etat] || x.etat)}</span>
    <div class="sub">${esc(x.etat === 'active' ? x.texte : (x.fin ? 'fin le ' + fmtDate(x.fin) : x.texte))}</div></div>`).join('');
  if (m.preservatifs !== undefined && m.preservatifs !== null) {
    html += `<div class="methode"><b>Préservatifs</b><span class="etat ${m.preservatifs > 0 ? 'active' : 'aucune'}">${m.preservatifs} en inventaire</span>
      <div class="sub">À cocher dans la demande, ou à utiliser pendant le moment.</div></div>`;
  }
  $('#k-methodes').innerHTML = html;
  const h = m.historique || [];
  $('#k-historique').innerHTML = h.length ? h.map((r) => `<div class="row"><span>${esc(METHODES[r.methode] || r.methode)} · ${esc(ACTIONS[r.action] || r.action)}${r.jusqu_a ? ' (jusqu\'au ' + esc(fmtDate(r.jusqu_a)) + ')' : ''}</span><span>${esc(fmtDate(r.at))}</span></div>`).join('')
    : '<div class="vide">Aucun historique.</div>';
  $('#panneau').classList.remove('hidden');
}
$('#k-fermer').addEventListener('click', () => { post('fermer'); hideAll(); });

/* ---------- Ma grossesse (mêmes données que l'application du téléphone) ---------- */
function openGrossesse(d) {
  hideAll();
  const r = d.donnees || {};
  const g = r.grossesse || {};
  const ligne = (k, v) => `<div class="row"><span>${esc(k)}</span><span>${esc(v)}</span></div>`;
  if (r.statut === 'en_cours') {
    $('#g-jour').textContent = g.terme ? 'Terme atteint' : `${g.trimestre}${g.trimestre === 1 ? 'er' : 'e'} trimestre`;
    $('#g-etape').textContent = g.etape || '';
    $('#g-barre').style.width = `${Math.round((g.pct || 0) * 100)}%`;
    $('#g-infos').innerHTML = [
      ligne('Temps écoulé', `${g.ecouleTexte} (${g.joursEcoules} jour${g.joursEcoules > 1 ? 's' : ''})`),
      ligne('Durée totale', g.totalTexte),
      g.avantTrimestreTexte ? ligne('Avant le trimestre suivant', g.avantTrimestreTexte) : '',
      ligne('Avant l\'accouchement', g.terme ? 'terme atteint' : g.avantTermeTexte),
      ligne('Début (calendrier du serveur)', g.debutTexte),
      ligne('Bébés', g.bebes ? (g.bebes === 1 ? 'un bébé' : (g.bebes === 2 ? 'jumeaux' : 'triplés')) : 'examen EMS nécessaire'),
    ].join('');
  } else if (r.statut === 'terminee') {
    const f = r.fin || {};
    $('#g-jour').textContent = f.status === 'accouchee' ? 'Accouchement terminé' : 'Grossesse terminée';
    $('#g-etape').textContent = f.date || '';
    $('#g-barre').style.width = '100%';
    $('#g-infos').innerHTML = ligne('Début (calendrier du serveur)', f.debutTexte || '—');
  } else {
    $('#g-jour').textContent = 'Aucune grossesse connue';
    $('#g-etape').textContent = '';
    $('#g-barre').style.width = '0%';
    $('#g-infos').textContent = 'Un test de grossesse ou un examen EMS permet de le savoir.';
  }
  const h = r.historique || [];
  $('#g-historique').innerHTML = h.length ? h.map((e) => `<div class="row"><span><b>${esc(e.titre)}</b><br><small>${esc(e.description || '')}</small></span><span>${esc(e.date || fmtDate(e.at))}</span></div>`).join('')
    : '<div class="vide">Aucun événement.</div>';
  $('#grossesse').classList.remove('hidden');
}
$('#g-fermer').addEventListener('click', () => { post('fermer'); hideAll(); });

/* ---------- Écran noir ---------- */
function showNoir(d) {
  if (noirTimer) { clearInterval(noirTimer); noirTimer = null; }
  if (!d.visible) { $('#noir').classList.add('hidden'); return; }
  let reste = d.duree || 0;
  const tick = () => { $('#n-temps').textContent = `${Math.floor(reste / 60)}:${String(reste % 60).padStart(2, '0')}`; reste = Math.max(0, reste - 1); };
  tick(); noirTimer = setInterval(tick, 1000);
  $('#noir').classList.remove('hidden');
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'consentement': openConsent(d); break;
    case 'proposer': openPropose(d); break;
    case 'panneau': openPanel(d); break;
    case 'grossesse': openGrossesse(d); break;
    case 'noir': showNoir(d); break;
    case 'fermer': hideAll(); break;
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (!$('#consentement').classList.contains('hidden')) return answerConsent(false);
  if (!$('#proposer').classList.contains('hidden')) { post('proposer', { envoyer: false }); return hideAll(); }
  if (!$('#panneau').classList.contains('hidden') || !$('#grossesse').classList.contains('hidden')) { post('fermer'); hideAll(); }
});
