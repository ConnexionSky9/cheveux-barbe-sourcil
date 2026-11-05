'use strict';
/* =========================================================
   LES 6 TÉLÉPHONES ELYAURA
   · Le serveur indique le modèle utilisé (S.profile.device) : design du boîtier,
     applications disponibles et niveau de personnalisation.
     1 : bloc plastique, gros bords, bouton physique, rien à personnaliser, code seulement.
     2 : premier smartphone (encoche goutte) : thèmes, 3 fonds, 3 couleurs.
     3 : bord à bord (caméra perforée) : tous les fonds, couleurs, cadres, icônes, horloge.
     4 : verre premium : effets animés, coques, couleur et image libres.
     5 : pliable (deux écrans) : widgets, sonnerie personnalisée, styles d'écran verrouillé.
     6 : ultra pliable (titane, liseré holographique) : LED libre / arc-en-ciel, cadres et fonds
         exclusifs, forme des icônes, police.
   · Les choix plus avancés restent enregistrés : ils reviennent avec un meilleur téléphone.
   ========================================================= */
const EFFECTS = {
  none: ['Aucun', 4], etoiles: ['Poussière d\'étoiles', 4], aurore: ['Aurore', 4], pluie: ['Pluie néon', 4], bulles: ['Bulles', 4],
  feux: ['Feux d\'artifice', 5], matrice: ['Matrice', 5], holo: ['Hologramme', 6],
};
const CASES = {
  none: ['Sans coque', 4, 'transparent'], silicone_noir: ['Silicone noire', 4, '#15151b'], silicone_rose: ['Silicone rose', 4, '#ff8fb8'],
  silicone_menthe: ['Silicone menthe', 4, '#7fe0c0'], silicone_bleu: ['Silicone bleue', 4, '#5d8dff'],
  transparente: ['Transparente à paillettes', 4, 'linear-gradient(135deg,rgba(255,255,255,.25),rgba(255,255,255,.05))'],
  carbone: ['Carbone', 4, 'repeating-linear-gradient(45deg,#2b2b31 0 5px,#141418 5px 10px)'],
  cuir: ['Cuir', 5, 'linear-gradient(150deg,#8a5a3c,#4a2c1a)'], neon: ['Néon', 5, '#0b0b12'],
};
const WIDGETS = { analog: 'Horloge analogique', calendar: 'Calendrier', favs: 'Contacts favoris', note: 'Dernière note', music: 'Musique' };
const LOCKS = { classic: 'Classique', grand: 'Grande horloge', minimal: 'Minimaliste' };
const EDGE_MODES = { auto: 'Couleur d\'accent', rainbow: 'Arc-en-ciel', pulse: 'Pulsation' };
const SHAPES = { squircle: 'Arrondies', cercle: 'Rondes', carre: 'Carrées', goutte: 'Gouttes' };
const FONTS = { manrope: ['Manrope', "'Manrope', sans-serif"], exo: ['Exo 2', "'Exo 2', sans-serif"], unbounded: ['Unbounded', "'Unbounded', sans-serif"], mono: ['Mono', "'JetBrains Mono', Consolas, monospace"] };

// ---------- Boîtier : éléments matériels (haut-parleur, bouton, marque, coque, effets) ----------
(function hardware() {
  if (!$('#phone .hw')) {
    const hw = document.createElement('div');
    hw.className = 'hw'; hw.setAttribute('aria-hidden', 'true');
    hw.innerHTML = '<i class="hw__speaker"></i><i class="hw__cam"></i><i class="hw__sensor"></i><i class="hw__home"></i><b class="hw__brand">ElyAura</b><i class="hw__antenna"></i>';
    phoneEl.prepend(hw);
    const cs = document.createElement('div');
    cs.className = 'case'; cs.setAttribute('aria-hidden', 'true');
    phoneEl.prepend(cs);
  }
  if (!$('#fx')) {
    const fx = document.createElement('div');
    fx.id = 'fx'; fx.setAttribute('aria-hidden', 'true');
    $('#wp').after(fx);
  }
})();

function drawEffect(name) {
  const fx = $('#fx');
  if (!fx || fx.dataset.fx === name) return;
  fx.dataset.fx = name;
  const rnd = (a, b) => (a + Math.random() * (b - a)).toFixed(2);
  const n = { etoiles: 40, pluie: 26, bulles: 18, feux: 6, matrice: 16 }[name] || 0;
  let html = '';
  for (let i = 0; i < n; i++) {
    if (name === 'matrice') html += `<i style="left:${rnd(0, 100)}%;animation-delay:-${rnd(0, 6)}s;animation-duration:${rnd(4, 8)}s">${Array.from({ length: 14 }, () => String.fromCharCode(0x30A0 + Math.floor(Math.random() * 90))).join('<br>')}</i>`;
    else if (name === 'feux') html += `<i style="left:${rnd(10, 90)}%;top:${rnd(10, 55)}%;animation-delay:-${rnd(0, 3)}s;--h:${Math.floor(Math.random() * 360)}"></i>`;
    else html += `<i style="left:${rnd(0, 100)}%;top:${rnd(0, 100)}%;animation-delay:-${rnd(0, 8)}s;animation-duration:${rnd(3, 9)}s;--s:${rnd(.4, 1.4)}"></i>`;
  }
  fx.innerHTML = html;
}

// ---------- Application du modèle et des réglages avancés ----------
function applyDevice() {
  const d = DEV(), s = effSettings(), root = document.documentElement.style;
  phoneEl.dataset.model = d.n || 0;
  phoneEl.dataset.fold = d.fold === false ? '0' : '1';
  phoneEl.dataset.tier = devTier();
  phoneEl.dataset.case = s.case || 'none';
  phoneEl.dataset.edge = s.edgeMode || 'auto';
  screenEl.dataset.shape = s.iconShape || 'squircle';
  screenEl.dataset.lockstyle = s.lockStyle || 'classic';
  const cs = CASES[s.case] || CASES.none;
  phoneEl.style.setProperty('--case', cs[2]);
  if (s.edgeColor && /^#[0-9a-f]{6}$/i.test(s.edgeColor)) phoneEl.style.setProperty('--edge-c', s.edgeColor); else phoneEl.style.removeProperty('--edge-c');
  root.setProperty('--font-body', (FONTS[s.font] || FONTS.manrope)[1]);
  $('.hw__brand').textContent = d.label || 'ElyAura';
  drawEffect(EFFECTS[s.effect] ? s.effect : 'none');
  // Seuls les modèles pliables (ElyAura 5 et 6) se déplient
  const fb = $('#fold-btn');
  if (fb) fb.hidden = d.fold === false;
  if (d.fold === false && typeof Fold !== 'undefined' && Fold.isOpen()) Fold.set(false, false);
}
const baseApply = applySettings;
applySettings = function (...a) { baseApply(...a); try { applyDevice(); } catch (e) { console.error(e); } };

// Accueil : moins d'applications sur la première page quand il y a des widgets
function firstPageApps() { return (effSettings().widgets || []).length ? 4 : FIRST_PAGE_APPS; }

function widgetHtml(id) {
  const now = new Date();
  if (id === 'analog') {
    const h = (S.gameTime ? S.gameTime.h : now.getHours()) % 12, m = S.gameTime ? S.gameTime.m : now.getMinutes();
    return `<div class="wd wd--analog"><div class="wd-clock"><i class="h" style="transform:rotate(${h * 30 + m / 2}deg)"></i><i class="m" style="transform:rotate(${m * 6}deg)"></i><b></b></div></div>`;
  }
  if (id === 'calendar') {
    return `<div class="wd wd--cal"><small>${esc(now.toLocaleDateString(locale(), { weekday: 'long' }))}</small><b>${now.getDate()}</b><span>${esc(now.toLocaleDateString(locale(), { month: 'long' }))}</span></div>`;
  }
  if (id === 'favs') {
    const favs = (S.contacts || []).filter((c) => c.favorite).slice(0, 4);
    return `<div class="wd wd--favs"><small>${t('Favoris')}</small><div>${favs.length ? favs.map((c) => `<button data-wd-call="${esc(c.number)}" title="${esc(c.name)}">${avatar(c.name, c.number)}</button>`).join('') : `<span>${t('Aucun favori')}</span>`}</div></div>`;
  }
  if (id === 'note') {
    const n = (S.notes || [])[0];
    return `<button class="wd wd--note" data-open="notes"><small>${t('Note')}</small><span>${esc(n ? (n.title || n.body || '').slice(0, 70) : t('Aucune note'))}</span></button>`;
  }
  if (id === 'music') {
    const tr = typeof Music !== 'undefined' ? Music.track : null;
    return `<button class="wd wd--music" data-open="itoune"><small>Itoune</small><b>${esc(tr ? (tr.title || '') : t('Rien en lecture'))}</b><span>${tr && Music.playing ? '▶ ' + t('En lecture') : ''}</span></button>`;
  }
  return '';
}
function afterHome() {
  const s = effSettings(), list = (s.widgets || []).filter((w) => WIDGETS[w]);
  if (!list.length) return;
  const anchor = $('.page--main .widgets', homeEl);
  if (!anchor) return;
  const box = document.createElement('div');
  box.className = 'wd-grid';
  box.innerHTML = list.map(widgetHtml).join('');
  anchor.after(box);
  $$('[data-wd-call]', box).forEach((b) => b.onclick = (e) => { e.stopPropagation(); if (S.dragged) return; startCall?.(b.dataset.wdCall); });
}

// ---------- Réglages : fiche du téléphone + page « Effets, coques et designs » ----------
function deviceCard() {
  const d = DEV();
  if (!d.n) return '';
  return `<div class="dev-card" data-dev-n="${d.n}"><div class="dev-card__art"><span class="dev-mini" data-m="${d.n}"></span></div>
    <div><small>${t('Mon téléphone')}</small><b>${esc(d.label)}</b>
    <span>${t('Pour changer de téléphone : « Utiliser » un autre ElyAura dans l\'inventaire.')}</span></div></div>`;
}

const baseSettings = Views.settings;
Views.settings = (params = {}) => {
  if (params.page !== 'device') return baseSettings(params);
  const s = S.settings, tier = devTier();
  const pick = (title, key, entries, min = 4) => tier < min ? '' : `<p class="section-label">${title}</p>
    <div class="list"><div class="dev-picks">${entries.filter(([, v]) => (Array.isArray(v) ? v[1] : min) <= tier).map(([k, v]) => `<button class="dev-pick ${String(s[key] ?? '') === k ? 'active' : ''}" data-dset="${key}" data-val="${k}">${key === 'case' ? `<i style="background:${CASES[k][2]}"></i>` : ''}${t(Array.isArray(v) ? v[0] : v)}</button>`).join('')}</div></div>`;
  frame({ title: t('Effets, coques et designs'), small: true, body: `
    ${pick(t('Effet de l\'écran d\'accueil'), 'effect', Object.entries(EFFECTS))}
    ${pick(t('Coque'), 'case', Object.entries(CASES))}
    ${tier >= 5 ? `<p class="section-label">${t('Widgets de l\'accueil')}</p>
      <div class="list"><div class="dev-picks">${Object.entries(WIDGETS).map(([k, l]) => `<button class="dev-pick ${(s.widgets || []).includes(k) ? 'active' : ''}" data-wd="${k}">${t(l)}</button>`).join('')}</div></div>
      ${pick(t('Écran verrouillé'), 'lockStyle', Object.entries(LOCKS), 5)}
      <p class="section-label">${t('Sonnerie personnalisée')}</p>
      <div class="list"><div class="row row--stack"><div class="form" style="width:100%">
        <input class="field" id="ring-url" placeholder="https://…/sonnerie.mp3" value="${esc(s.ringtoneUrl || '')}">
        <div class="grid-2"><button class="btn btn--ghost" id="ring-test">${t('Écouter')}</button><button class="btn" id="ring-save">${t('Enregistrer')}</button></div>
        <p class="row__sub row__sub--wrap">${t('Lien https vers un fichier audio (.mp3, .ogg). Vide = sonnerie choisie dans Sons.')}</p></div></div></div>` : ''}
    ${tier >= 6 ? `${pick(t('Liseré lumineux'), 'edgeMode', Object.entries(EDGE_MODES), 6)}
      <div class="list" style="margin-top:8px"><div class="row"><span class="row__main row__title row__title--light">${t('Couleur du liseré')}</span>
        <label class="accent-dot accent-dot--custom ${s.edgeColor ? 'active' : ''}"><input type="color" id="edge-c" value="${s.edgeColor || accentHex()}"></label>
        ${s.edgeColor ? `<button class="chip" id="edge-reset">${t('Accent')}</button>` : ''}</div></div>
      ${pick(t('Forme des icônes'), 'iconShape', Object.entries(SHAPES), 6)}
      ${pick(t('Police'), 'font', Object.entries(FONTS).map(([k, v]) => [k, v[0]]), 6)}` : `<p class="row__sub row__sub--wrap" style="margin:14px 8px">${t('Liseré arc-en-ciel, cadres exclusifs, police et forme des icônes : ElyAura 6 Ultra.')}</p>`}` });
  $$('[data-dset]', appView).forEach((b) => b.onclick = () => { saveSettings({ [b.dataset.dset]: b.dataset.val }); Views.settings(params); });
  $$('[data-wd]', appView).forEach((b) => b.onclick = () => {
    const cur = (S.settings.widgets || []).slice(), k = b.dataset.wd, i = cur.indexOf(k);
    if (i >= 0) cur.splice(i, 1); else if (cur.length < 4) cur.push(k);
    saveSettings({ widgets: cur }); Views.settings(params);
  });
  $('#ring-test')?.addEventListener('click', () => { const v = $('#ring-url').value.trim(); if (/^https:\/\//.test(v)) Sound.previewUrl(v); });
  $('#ring-save')?.addEventListener('click', () => {
    const v = $('#ring-url').value.trim();
    if (v && !/^https:\/\//.test(v)) return notify({ app: 'settings', title: t('Sonnerie'), text: t('Le lien doit commencer par https://') });
    saveSettings({ ringtoneUrl: v }); notify({ app: 'settings', title: t('Sonnerie'), text: v ? t('Sonnerie personnalisée enregistrée.') : t('Sonnerie par défaut.') });
  });
  $('#edge-c')?.addEventListener('change', (e) => { saveSettings({ edgeColor: e.target.value }); Views.settings(params); });
  $('#edge-reset')?.addEventListener('click', () => { saveSettings({ edgeColor: '' }); Views.settings(params); });
};
