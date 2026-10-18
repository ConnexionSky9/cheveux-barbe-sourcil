// « Vêtements du jeu » : catalogue de tous les vêtements extraits de votre GTA V,
// classés par catégorie, avec vignettes, et création d'un vêtement modifiable en un clic.
import { h, fill, icon, btn, toast, select } from '../ui.js';
import { S, api, go, adopt, refresh, saveProject, status } from '../app.js';

const state = { ped: 'mp_m_freemode_01', slot: 'jbib', collection: '', q: '', offset: 0, selected: null };
const LIMIT = 60;

let lastReport = null;   // dernier rapport d'indexation (affiché tant que l'utilisateur ne l'a pas fermé)

export function renderCatalog(main) {
  const page = h('div.catalog', h('div.drop-overlay', 'Déposez ici le dossier des vêtements extraits'));
  main.append(page);
  // Glisser-déposer d'un dossier (ou de fichiers .ydd / .ytd) depuis l'explorateur
  let depth = 0;
  page.addEventListener('dragenter', (e) => { e.preventDefault(); depth++; page.classList.add('dragging'); });
  page.addEventListener('dragleave', () => { if (--depth <= 0) { depth = 0; page.classList.remove('dragging'); } });
  page.addEventListener('dragover', (e) => e.preventDefault());
  page.addEventListener('drop', async (e) => {
    e.preventDefault(); depth = 0; page.classList.remove('dragging');
    const p = [...e.dataTransfer.files].map((f) => api.pathForFile(f)).find(Boolean);
    if (!p) return toast('Impossible de lire ce que vous avez déposé : utilisez le bouton « Choisir le dossier ».', 'warning', 6000);
    const info = await api.catalogInfo();
    scan(page, { root: p, merge: Boolean(info.catalog?.rootExists) });
  });
  api.catalogInfo().then((r) => draw(page, r));
}

const keepOverlay = (page) => page.querySelector(':scope > .drop-overlay');

function setup(page, info) {
  fill(page, keepOverlay(page), h('div.page', h('div.page-inner',
    h('h1', 'Vêtements du jeu'),
    lastReport ? reportBox(page, info, lastReport) : null,
    info?.catalog && !info.catalog.rootExists ? h('div.box', { style: { borderColor: 'var(--warn)' } }, `Le dossier indexé n'existe plus : ${info.catalog.root}`) : null,
    h('p', 'Retrouvez ici TOUS les vêtements de GTA V (hauts, gants, chapeaux, lunettes…) pour créer les vôtres à partir d\'eux. ',
      'L\'application ne contient aucun fichier du jeu : elle lit ceux que vous extrayez de VOTRE copie de GTA V, une seule fois.'),
    h('div.box.cat-drop', h('h3', 'Le plus simple'),
      h('p', 'Glissez le dossier où se trouvent vos fichiers ', h('code', '.ydd'), ' / ', h('code', '.ytd'), ' directement sur cette page, ou cliquez sur le bouton. ',
        'Le nom du dossier n\'a pas d\'importance : s\'il manque l\'information homme / femme, l\'application vous la demande, et si quelque chose ne va pas elle vous dit exactement quoi.'),
      h('div.row', btn(info?.catalog ? 'Choisir un autre dossier…' : 'Choisir le dossier des vêtements extraits…', () => scan(page), { icon: 'folder', kind: 'primary', id: 'cat-scan' }),
        info?.catalog?.rootExists ? btn('Retour au catalogue', () => { lastReport = null; draw(page, info); }, { kind: 'small' }) : null)),
    h('div.box', h('h3', 'Extraire les vêtements avec CodeWalker (gratuit, une seule fois)'),
      h('ol',
        h('li', 'Téléchargez CodeWalker (Outils et dépendances › CodeWalker) et lancez « CodeWalker RPF Explorer ». Il trouve GTA V tout seul.'),
        h('li', 'Double-cliquez sur ', h('code', 'x64v.rpf'), ' › ', h('code', 'models'), ' › ', h('code', 'cdimages'), ' › ', h('code', 'streamedpeds_mp.rpf'), '.'),
        h('li', 'Ouvrez le dossier ', h('code', 'mp_m_freemode_01'), ' (homme), sélectionnez tout (Ctrl+A), clic droit › ', h('b', 'Extract Raw…'),
          ' (pas « Export XML », pas « Extract Uncompressed ») et choisissez un dossier vide, par exemple ', h('code', 'Documents\\GTA vêtements\\homme'), '.'),
        h('li', 'Même chose avec ', h('code', 'mp_f_freemode_01'), ' (femme) vers ', h('code', 'Documents\\GTA vêtements\\femme'), '.'),
        h('li', 'Accessoires (chapeaux, lunettes, montres…) : ', h('code', 'x64v.rpf › models › cdimages › streamedpedprops.rpf'), ', dossiers ', h('code', 'mp_m_freemode_01_p'), ' et ', h('code', 'mp_f_freemode_01_p'), ', vers les mêmes dossiers homme / femme.'),
        h('li', 'Glissez le dossier ', h('code', 'GTA vêtements'), ' sur cette page. C\'est tout.')),
      h('p.help', 'À ne pas faire : choisir le dossier d\'installation de GTA V (les vêtements y sont dans des archives .rpf chiffrées que l\'application ne peut pas ouvrir). ',
        'Les vêtements des mises à jour (DLC) sont dans ', h('code', 'update › x64 › dlcpacks'), ' : facultatif, même méthode, un dossier par pack.')))));
}

const LEVEL_COLOR = { error: 'var(--err)', warning: 'var(--warn)', question: 'var(--accent)', info: 'var(--muted)' };

function reportBox(page, info, r) {
  const found = [[r.ydd, 'modèle(s) .ydd'], [r.ytd, 'texture(s) .ytd'], [r.rpf, 'archive(s) .rpf'], [r.xml, '.xml'], [r.images, 'image(s)'], [r.others, 'autre(s) fichier(s)']]
    .filter(([n]) => n).map(([n, l]) => `${n} ${l}`).join(' · ') || 'rien';
  const pending = r.pending;
  return h('div.box.cat-report#cat-report', { style: { borderColor: LEVEL_COLOR[r.advice.find((x) => x.level !== 'info')?.level || 'info'] } },
    h('h3', pending ? 'Encore une question' : r.items ? 'Résultat de l\'indexation' : 'Aucun vêtement utilisable trouvé'),
    h('p.small.mono', r.root),
    h('p.small', `Trouvé : ${found}.${r.items ? ` ${r.items} vêtement(s) reconnu(s).` : ''}`),
    r.advice.map((a) => h('div.cat-advice', { style: { borderLeftColor: LEVEL_COLOR[a.level] } }, h('b', a.title), h('p', a.text))),
    pending ? h('div.row', { style: { marginTop: '10px' } },
      btn('Ce sont des vêtements HOMME', () => scan(page, { root: r.root, merge: r.merge, defaultPed: 'mp_m_freemode_01' }), { kind: 'primary', id: 'cat-ped-m' }),
      btn('Ce sont des vêtements FEMME', () => scan(page, { root: r.root, merge: r.merge, defaultPed: 'mp_f_freemode_01' }), { kind: 'primary', id: 'cat-ped-f' }),
      r.items ? btn('Ignorer ces fichiers', () => scan(page, { root: r.root, merge: r.merge, defaultPed: 'skip' }), { kind: 'small' }) : null) : null,
    pending ? h('p.help', 'Astuce : rangez les fichiers homme et femme dans deux dossiers séparés (par exemple « homme » et « femme ») : l\'application reconnaît ces noms et ne posera plus la question.') : null,
    !pending ? btn('Fermer', () => { lastReport = null; setup(page, info); }, { kind: 'small' }) : null);
}

async function scan(page, opts) {
  status('Indexation des vêtements du jeu…');
  const off = api.on('app:event', (e) => { if (e.type === 'catalog-progress') status(`Indexation : ${e.files} fichiers…`); });
  const r = await api.catalogScan(opts);
  off(); status('Prêt.');
  if (!r.ok) return toast(r.error, 'error', 8000);
  const info = await api.catalogInfo();
  if (r.pending || r.empty) {
    lastReport = { ...r.report, pending: Boolean(r.pending), merge: r.merge };
    return setup(page, info);
  }
  lastReport = null;
  if (r.added) {
    toast(`${r.added} vêtements indexés${r.catalog.stats.items > r.added ? ` (${r.catalog.stats.items} au total)` : ''}.`, 'success', 6000);
    const notes = (r.report?.advice || []).filter((a) => a.level === 'warning' || a.level === 'error');
    for (const n of notes) toast(`${n.title}. ${n.text}`, 'warning', 12000);
    // Ouvre directement le personnage qui a des vêtements
    if (!r.catalog.stats[state.ped]) state.ped = r.catalog.stats.mp_f_freemode_01 ? 'mp_f_freemode_01' : 'mp_m_freemode_01';
  }
  draw(page, info);
}

function draw(page, info) {
  const c = info.catalog;
  if (!c || !c.rootExists || lastReport) return setup(page, info);
  const cats = info.categories;
  const grid = h('div.cat-grid');
  const detail = h('aside.cat-detail', h('p.muted', 'Choisissez un vêtement.'));
  const more = h('div', { style: { textAlign: 'center', margin: '14px 0' } });
  const count = h('span.muted.small');
  const catList = h('div.cat-list', cats.map((k) => h(`button.cat-item${state.slot === k.id ? '.on' : ''}`, { type: 'button', onclick: () => { state.slot = k.id; state.offset = 0; draw(page, info); } },
    h('span', k.label), h('span.faint', String(c.stats[k.id] ?? 0)))));
  fill(page, keepOverlay(page), h('div.cat-layout',
    h('div.cat-side', h('h3', 'Catégories'), catList,
      h('p.help', { style: { marginTop: '10px' } }, 'Dans GTA V, les gants font partie des « bras » : choisissez « Bras et gants ».'),
      h('div.row.tight', { style: { flexWrap: 'wrap', gap: '6px' } },
        btn('Ajouter un dossier…', () => scan(page, { merge: true }), { kind: 'small', icon: 'plus', id: 'cat-add', title: 'Ajouter d\'autres vêtements (femme, accessoires, DLC…) au catalogue' }),
        btn('Recommencer…', () => scan(page), { kind: 'small', icon: 'folder', title: 'Remplacer le catalogue par un autre dossier' })),
      h('p.help', `${c.stats.items} vêtements (homme ${c.stats.mp_m_freemode_01 ?? '?'}, femme ${c.stats.mp_f_freemode_01 ?? '?'})`),
      (c.roots || [c.root]).map((r) => h('p.help.mono', { style: { wordBreak: 'break-all' } }, r)),
      h('p.help', 'Astuce : glissez un dossier sur cette page pour l\'ajouter.')),
    h('div.cat-main',
      h('div.cat-filters',
        h('div.row.tight', ['mp_m_freemode_01', 'mp_f_freemode_01'].map((p) => btn(p.includes('_m_') ? 'Homme' : 'Femme', () => { state.ped = p; state.offset = 0; draw(page, info); }, { kind: `small${state.ped === p ? ' active' : ''}` }))),
        select([{ value: '', label: 'Jeu de base' }, ...c.collections.filter(Boolean).map((x) => ({ value: x, label: `DLC : ${x}` })), { value: '*', label: 'Tout' }], state.collection, (v) => { state.collection = v; state.offset = 0; draw(page, info); }, { style: { width: '220px' } }),
        h('input.input', { placeholder: 'N° du vêtement…', value: state.q, style: { width: '160px' }, onchange: (e) => { state.q = e.target.value; state.offset = 0; draw(page, info); } }),
        count),
      grid, more),
    detail));
  load();
  async function load(append = false) {
    const r = await api.catalogQuery({ ped: state.ped, slot: state.slot, collection: state.collection, q: state.q, offset: state.offset, limit: LIMIT });
    count.textContent = `${r.total} vêtement(s)`;
    if (!append) grid.replaceChildren();
    if (!r.total) grid.append(h('p.muted', 'Aucun vêtement dans cette catégorie pour ce personnage.'));
    for (const it of r.items) grid.append(card(it));
    fill(more, state.offset + LIMIT < r.total ? btn('Afficher plus', () => { state.offset += LIMIT; load(true); }, { kind: 'small' }) : null);
  }
  function card(it) {
    const img = h('div.cat-thumb', h('span.faint.small', '…'));
    const el = h(`button.cat-card${state.selected === it.key ? '.on' : ''}`, { type: 'button', title: it.key, onclick: () => { state.selected = it.key; grid.querySelectorAll('.cat-card').forEach((x) => x.classList.toggle('on', x === el)); showDetail(it, img); } },
      img, h('b', `${it.slot} ${it.index}`), h('span.small.muted', `${it.textures.length} variante(s)${it.ydd ? '' : ' · sans modèle'}`));
    const io = new IntersectionObserver((ents) => {
      if (!ents.some((e) => e.isIntersecting)) return;
      io.disconnect();
      api.catalogThumb(it.key).then((t) => fill(img, t.url ? h('img', { src: t.url, alt: '' }) : h('span.faint.small', t.error ? 'illisible' : 'sans texture')));
    });
    io.observe(el);
    return el;
  }
  function showDetail(it, thumbEl) {
    const imgSrc = thumbEl.querySelector('img')?.src;
    fill(detail,
      h('h2', `${cats.find((k) => k.id === it.slot)?.label} n° ${it.index}`),
      imgSrc ? h('img.cat-big', { src: imgSrc, alt: '' }) : null,
      h('dl.kv', h('dt', 'Personnage'), h('dd', it.ped.includes('_m_') ? 'Homme' : 'Femme'), h('dt', 'Collection'), h('dd', it.collection || 'Jeu de base'),
        h('dt', 'Modèle'), h('dd.mono', it.yddStream || '—'), h('dt', 'Variantes'), h('dd', it.textures.map((t) => `${t.letter}${t.suffix && t.suffix !== 'uni' ? ` (${t.suffix})` : ''}`).join(', ') || '—')),
      h('div', { style: { marginTop: '14px' } }, btn('Créer un vêtement à partir de celui-ci', () => createFrom(it), { icon: 'plus', kind: 'primary', id: 'cat-create', disabled: !S.project })),
      !S.project ? h('p.help', 'Ouvrez ou créez d\'abord un projet.') : null,
      h('p.help', { style: { marginTop: '10px' } }, 'Le vêtement est copié dans votre projet. Vous pourrez modifier ses textures (couleurs, logos, texte, boutons…) ; à l\'export, vos textures sont réécrites dans les fichiers du jeu et la ressource remplace ce vêtement sur votre serveur.'));
  }
}

async function createFrom(it) {
  status('Copie du vêtement dans le projet…');
  const r = await api.catalogCreate({ project: S.project, key: it.key });
  status('Prêt.');
  if (!r.ok) return toast(r.error, 'error', 8000);
  adopt(r.project, 'Vêtement créé depuis le jeu');
  await saveProject({ quiet: true });
  if (r.warning) toast(r.warning, 'warning', 8000);
  const { openTexture } = await import('./workspace.js');
  go('workspace');
  if (r.meta) await openTexture(r.meta.id, r);
  S.selection = { type: 'garment', id: r.garmentId };
  toast('Vêtement créé : modifiez sa texture, puis « Exporter pour FiveM ».', 'success', 6000);
  refresh();
}
