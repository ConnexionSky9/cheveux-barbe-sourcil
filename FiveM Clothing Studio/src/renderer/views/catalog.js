// « Vêtements du jeu » : catalogue de tous les vêtements extraits de votre GTA V,
// classés par catégorie, avec vignettes, et création d'un vêtement modifiable en un clic.
import { h, fill, icon, btn, toast, select } from '../ui.js';
import { S, api, go, adopt, refresh, saveProject, status } from '../app.js';

const state = { ped: 'mp_m_freemode_01', slot: 'jbib', collection: '', q: '', offset: 0, selected: null };
const LIMIT = 60;

export function renderCatalog(main) {
  const page = h('div.catalog');
  main.append(page);
  api.catalogInfo().then((r) => draw(page, r));
}

function setup(page, info) {
  fill(page, h('div.page', h('div.page-inner',
    h('h1', 'Vêtements du jeu'),
    info?.catalog && !info.catalog.rootExists ? h('div.box', { style: { borderColor: 'var(--warn)' } }, `Le dossier indexé n'existe plus : ${info.catalog.root}`) : null,
    h('p', 'Retrouvez ici TOUS les vêtements de GTA V (hauts, gants, chapeaux, lunettes…) pour créer les vôtres à partir d\'eux. ',
      'L\'application ne contient aucun fichier du jeu : elle lit ceux que vous extrayez de VOTRE copie de GTA V, une seule fois.'),
    h('div.box', h('h3', 'Extraire les vêtements avec CodeWalker (gratuit, une seule fois)'),
      h('ol',
        h('li', 'Téléchargez CodeWalker (Outils et dépendances › CodeWalker) et lancez « CodeWalker RPF Explorer ».'),
        h('li', 'Ouvrez ', h('code', 'x64v.rpf › models › cdimages › streamedpeds_mp.rpf'), '.'),
        h('li', 'Clic droit sur les dossiers ', h('code', 'mp_m_freemode_01'), ' et ', h('code', 'mp_f_freemode_01'), ' › Extract, vers un même dossier (par exemple ', h('code', 'Documents\\GTA vêtements'), ').'),
        h('li', 'Pour les accessoires (chapeaux, lunettes, montres…) : ', h('code', 'streamedpedprops.rpf'), ' › dossiers ', h('code', 'mp_m_freemode_01_p'), ' et ', h('code', 'mp_f_freemode_01_p'), ', même dossier de destination.'),
        h('li', 'Facultatif : les vêtements des mises à jour (DLC) se trouvent dans les packs de ', h('code', 'update › x64 › dlcpacks'), ' ; extrayez leurs dossiers mp_m_freemode_01_… de la même façon.'),
        h('li', 'Cliquez ci-dessous et choisissez ce dossier : l\'application range tout automatiquement.')),
      h('p.help', 'Les chemins peuvent légèrement varier selon la version du jeu. Seuls les noms de fichiers comptent : jbib_000_u.ydd, jbib_diff_000_a_uni.ytd…'),
      btn(info?.catalog ? 'Réindexer / changer de dossier…' : 'Choisir le dossier des vêtements extraits…', () => scan(page), { icon: 'folder', kind: 'primary', id: 'cat-scan' })))));
}

async function scan(page) {
  status('Indexation des vêtements du jeu…');
  const off = api.on('app:event', (e) => { if (e.type === 'catalog-progress') status(`Indexation : ${e.files} fichiers…`); });
  const r = await api.catalogScan();
  off(); status('Prêt.');
  if (!r.ok) return toast(r.error, 'error', 8000);
  if (r.catalog) toast(`${r.catalog.stats.items} vêtements indexés.`, 'success');
  draw(page, await api.catalogInfo());
}

function draw(page, info) {
  const c = info.catalog;
  if (!c || !c.rootExists) return setup(page, info);
  const cats = info.categories;
  const grid = h('div.cat-grid');
  const detail = h('aside.cat-detail', h('p.muted', 'Choisissez un vêtement.'));
  const more = h('div', { style: { textAlign: 'center', margin: '14px 0' } });
  const count = h('span.muted.small');
  const catList = h('div.cat-list', cats.map((k) => h(`button.cat-item${state.slot === k.id ? '.on' : ''}`, { type: 'button', onclick: () => { state.slot = k.id; state.offset = 0; draw(page, info); } },
    h('span', k.label), h('span.faint', String(c.stats[k.id] ?? 0)))));
  fill(page, h('div.cat-layout',
    h('div.cat-side', h('h3', 'Catégories'), catList,
      h('p.help', { style: { marginTop: '10px' } }, 'Dans GTA V, les gants font partie des « bras » : choisissez « Bras et gants ».'),
      btn('Changer de dossier…', () => scan(page), { kind: 'small', icon: 'folder' }),
      h('p.help', `${c.stats.items} vêtements · ${c.root}`)),
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
