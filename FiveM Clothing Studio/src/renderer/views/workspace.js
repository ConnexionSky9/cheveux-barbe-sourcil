// Espace de création : bibliothèque (gauche), zone de travail (centre), propriétés (droite).
import { h, fill, icon, btn, toast, field, select, issueList, fmtBytes, fmtDate, confirmBox, prompt, modal } from '../ui.js';
import { S, api, commit, adopt, refresh, status, loadProject, go } from '../app.js';
import { COMPONENTS, PROPS, VARIANT_LETTERS } from '../../core/gta/naming.js';
import { Viewer, analyse } from './viewer3d.js';
import { createTextureEditor, payloadToDoc } from './textureEditor.js';
import { openImportDialog } from './dialogs.js';

const PED_OPTS = [{ value: 'mp_m_freemode_01', label: 'Homme (mp_m_freemode_01)' }, { value: 'mp_f_freemode_01', label: 'Femme (mp_f_freemode_01)' }];
const newId = () => crypto.randomUUID();
const filters = { q: '', ped: '', category: '' };

export function renderWorkspace(main) {
  const P = S.project;
  const ws = h(`div.workspace${S.panels.left ? '' : '.no-left'}${S.panels.right ? '' : '.no-right'}`);
  const left = h('aside.panel.left'), centerPane = h('section.center'), right = h('aside.panel.right');
  ws.append(left, centerPane, right);
  main.append(ws);
  renderLeft(left);
  renderCenter(centerPane, right);
  if (S.center !== 'texture' || !S.editor) renderRight(right);
}

// ===================================================================== gauche
function renderLeft(el) {
  const P = S.project;
  const missing = new Set(S.missing.map((m) => m.id));
  const sel = S.selection || {};
  const item = (type, id, ic, name, meta, extra = {}) => h(`div.tree-item${sel.type === type && sel.id === id ? '.selected' : ''}${missing.has(id) ? '.missing' : ''}`,
    { onclick: () => selectItem(type, id), title: name, ondblclick: extra.dbl }, icon(ic, 16), h('span.name', name), meta ? h('span.meta', meta) : null);
  const section = (title, add, children, empty) => h('div.tree-section', h('div.ts-head', h('span', title), add), children.length ? children : h('div.empty-hint', empty));

  const q = filters.q.toLowerCase();
  const garments = P.garments.filter((g) => (!q || g.name.toLowerCase().includes(q)) && (!filters.ped || g.ped === filters.ped) && (!filters.category || g.category === filters.category));
  const byKind = (k) => P.assets.filter((a) => a.kind === k);
  const gtaAssets = P.assets.filter((a) => a.kind === 'gta' || a.kind === 'material');
  fill(el, 
    h('div.panel-head', h('h3', 'Bibliothèque'), h('button.icon-btn', { title: 'Importer (Ctrl+I)', type: 'button', onclick: () => openImportDialog() }, icon('import'))),
    h('div.panel-body',
      h('div.search', h('input.input', { placeholder: 'Rechercher un vêtement…', value: filters.q, oninput: (e) => { filters.q = e.target.value; renderLeft(el); el.querySelector('input').focus(); el.querySelector('input').setSelectionRange(99, 99); } })),
      h('div.row', { style: { marginBottom: '10px' } },
        select([{ value: '', label: 'Tous personnages' }, ...PED_OPTS.map((p) => ({ value: p.value, label: p.value.includes('_m_') ? 'Homme' : 'Femme' }))], filters.ped, (v) => { filters.ped = v; renderLeft(el); }),
        select([{ value: '', label: 'Toutes catégories' }, ...P.categories.map((c) => ({ value: c, label: c }))], filters.category, (v) => { filters.category = v; renderLeft(el); })),
      h('button.btn.primary', { type: 'button', style: { width: '100%', marginBottom: '12px', justifyContent: 'center' }, onclick: () => go('catalog'), id: 'ws-catalog' }, icon('shirt'), h('span', 'Partir d\'un vêtement du jeu')),
      section('Vêtements', h('button.icon-btn', { title: 'Nouveau vêtement vide', type: 'button', id: 'add-garment', onclick: addGarment }, icon('plus', 16)),
        garments.map((g) => { const st = garmentState(g); return h(`div.tree-item${sel.type === 'garment' && sel.id === g.id ? '.selected' : ''}`, { onclick: () => selectItem('garment', g.id) },
          h(`span.dot.${st}`), h('span.name', g.name), h('span.meta', `${g.ped.includes('_m_') ? 'H' : 'F'} · ${g.slot || '?'}${Number.isInteger(g.drawableIndex) ? ` ${g.drawableIndex}` : ''}`)); }),
        P.garments.length ? 'Aucun résultat.' : 'Aucun vêtement. Cliquez sur + pour en créer un.'),
      section('Textures de travail', h('button.icon-btn', { title: 'Nouvelle texture vide', type: 'button', onclick: newBlankTexture }, icon('plus', 16)),
        P.textureDocs.map((t) => item('texture', t.id, 'layers', t.name, t.width ? `${t.width}×${t.height}` : '', { dbl: () => openTexture(t.id) })),
        'Ouvrez une image importée pour créer une texture modifiable.'),
      section('Images et logos', null, byKind('texture').map((a) => item('asset', a.id, 'image', a.name, a.info?.summary?.split(' · ')[0])), 'Importez des PNG, JPEG, TGA ou DDS.'),
      section('Modèles 3D', null, byKind('model').map((a) => item('asset', a.id, 'cube', a.name, a.format?.toUpperCase(), { dbl: () => showModel(a.id) })), 'Importez des OBJ, glTF, GLB ou FBX.'),
      section('Fichiers GTA V', null, gtaAssets.map((a) => item('asset', a.id, 'file', a.name, (a.info?.role || a.format || '').toUpperCase())), 'Importez des .ydd, .ytd, .ymt ou .meta.'),
    ));
}

function garmentState(g) {
  if (!g.slot || !Number.isInteger(g.drawableIndex) || !g.variants?.length) return 'err';
  if (g.variants.some((v) => !v.ytdAssetId && !v.textureDocId)) return 'err';
  if (g.variants.some((v) => !v.ytdAssetId)) return 'warn';
  return 'ok';
}

function selectItem(type, id) {
  S.selection = { type, id };
  if (type === 'texture') { openTexture(id); return; }
  if (S.center === 'texture') S.center = 'viewer';
  refresh();
  if (type === 'garment') { const g = S.project.garments.find((x) => x.id === id); if (g?.modelAssetId) showModel(g.modelAssetId, { garment: g }); }
}

function addGarment() {
  const ped = S.project.targetPeds[0] || 'mp_m_freemode_01';
  const g = { id: newId(), name: `Vêtement ${S.project.garments.length + 1}`, description: '', category: S.project.categories[0] || 'Autres', ped,
    kind: 'component', slot: null, drawableIndex: null, yddAssetId: null, modelAssetId: null, materials: [], variants: [{ id: newId(), name: '', letter: 'a', ytdAssetId: null, textureDocId: null }] };
  commit('Nouveau vêtement', (p) => p.garments.push(g), { render: false });
  S.selection = { type: 'garment', id: g.id };
  S.center = 'viewer';
  refresh();
}

async function newBlankTexture() {
  const st = { name: 'Nouvelle texture', size: 1024, color: '#ffffff', transparent: false };
  modal({ title: 'Nouvelle texture', body: h('div.form',
    field('Nom', h('input.input', { value: st.name, oninput: (e) => { st.name = e.target.value; } })),
    field('Dimensions', select([256, 512, 1024, 2048, 4096].map((v) => ({ value: v, label: `${v} × ${v}` })), 1024, (v) => { st.size = Number(v); })),
    h('div.row.tight', h('label.checkbox', h('input', { type: 'checkbox', onchange: (e) => { st.transparent = e.target.checked; } }), 'Fond transparent'),
      h('input', { type: 'color', value: st.color, oninput: (e) => { st.color = e.target.value; } }))),
  actions: [{ label: 'Annuler' }, { label: 'Créer', kind: 'primary', onclick: async () => {
    const c = [1, 3, 5].map((i) => parseInt(st.color.slice(i, i + 2), 16));
    const r = await api.textureBlank({ project: S.project, name: st.name || 'Texture', width: st.size, height: st.size, color: st.transparent ? null : [...c, 255] });
    if (!r.ok) return toast(r.error, 'error');
    adopt(r.project, 'Nouvelle texture');
    S.selection = { type: 'texture', id: r.meta.id };
    openTexture(r.meta.id, r);
  } }] });
}

// ===================================================================== centre
function renderCenter(el, right) {
  const tab = (id, label, ic) => btn(label, () => switchCenter(id), { icon: ic, kind: `small ghost${S.center === id ? ' active' : ''}` });
  const body = h('div.center-body', h('div.drop-overlay', 'Déposez vos fichiers pour les importer'));
  el.append(h('div.center-tabs', tab('viewer', 'Aperçu 3D', 'cube'), S.texDoc ? tab('texture', `Texture : ${S.texDoc.doc.name}${S.texDoc.doc.dirty ? ' •' : ''}`, 'layers') : null,
    h('span', { style: { flex: 1 } }),
    h('button.icon-btn', { title: 'Panneau de gauche (Ctrl+1)', type: 'button', onclick: () => { S.panels.left = !S.panels.left; refresh(); } }, icon('layers', 16)),
    h('button.icon-btn', { title: 'Panneau de droite (Ctrl+2)', type: 'button', onclick: () => { S.panels.right = !S.panels.right; refresh(); } }, icon('gear', 16))), body);
  // Glisser-déposer depuis l'explorateur Windows
  let depth = 0;
  el.addEventListener('dragenter', (e) => { e.preventDefault(); depth++; el.classList.add('dragging'); });
  el.addEventListener('dragleave', () => { if (--depth <= 0) { depth = 0; el.classList.remove('dragging'); } });
  el.addEventListener('dragover', (e) => e.preventDefault());
  el.addEventListener('drop', (e) => {
    e.preventDefault(); depth = 0; el.classList.remove('dragging');
    const paths = [...e.dataTransfer.files].map((f) => api.pathForFile(f)).filter(Boolean);
    if (paths.length) openImportDialog(paths);
  });

  // Le visualiseur est créé une fois par projet et gardé en mémoire (patron UV, aperçu en direct)
  if (!S.viewer) {
    S.viewerEl = h('div.viewer');
    S.viewer = new Viewer(S.viewerEl, {
      onSelect: (o) => { if (S.viewerInfoEl) S.viewerInfoEl.textContent = o ? `Sélection : ${o.name} · matériau ${o.material || '—'} · ${o.vertices} sommets` : (S.viewerInfo || ''); renderViewerTools(); },
    });
    S.viewerInfo = '';
  }
  S.editor?.dispose(); S.editor = null;
  if (S.center === 'texture' && S.texDoc) {
    S.viewer.paused = true;
    const ed = createTextureEditor(body, right, S.texDoc);
    ed.onClose = closeTexture;
    ed.onLiveUpdate = (canvas) => {
      for (const g of S.project.garments) for (const m of g.materials || []) {
        if (m.textureDocId === ed.meta.id && S.viewerStats && S.viewer.materials().includes(m.name)) S.viewer.applyTexture(m.name, canvas);
      }
    };
    S.editor = ed;
    return;
  }
  S.viewer.paused = false;
  const info = h('div.viewer-info', S.viewerInfo || 'Aucun modèle affiché. Double-cliquez sur un modèle 3D dans la bibliothèque, ou associez un modèle à un vêtement.');
  S.viewerInfoEl = info;
  const toolbar = h('div.viewer-toolbar',
    ...['front', 'back', 'left', 'right', 'top'].map((v) => btn({ front: 'Face', back: 'Dos', left: 'Gauche', right: 'Droite', top: 'Dessus' }[v], () => S.viewer?.setView(v), { kind: 'small' })),
    btn('', () => S.viewer?.resetView(), { icon: 'reset', kind: 'small', title: 'Réinitialiser la vue' }),
    btn('Fil de fer', (e) => { const on = !S.viewer.wire; S.viewer.setWireframe(on); e.currentTarget.classList.toggle('active', on); }, { kind: `small${S.viewer.wire ? ' active' : ''}` }),
    btn('Normales', (e) => { const on = !e.currentTarget.classList.contains('active'); S.viewer.setNormals(on); e.currentTarget.classList.toggle('active', on); }, { kind: `small${S.viewer.helpers.length ? ' active' : ''}` }),
    btn('Grille', (e) => { S.viewer.toggleGrid(!S.viewer.grid.visible); e.currentTarget.classList.toggle('active', S.viewer.grid.visible); }, { kind: `small${S.viewer.grid.visible ? ' active' : ''}` }),
    h('label.small.muted', { style: { display: 'flex', alignItems: 'center', gap: '6px', background: 'var(--panel2)', padding: '0 8px', borderRadius: '8px' } }, 'Lumière',
      h('input', { type: 'range', min: 10, max: 250, value: 100, style: { width: '90px' }, oninput: (e) => S.viewer?.setLight(Number(e.target.value) / 100) })));
  body.append(S.viewerEl, toolbar, info);
  S.viewer.attach(S.viewerEl);
  if (S.viewerError) body.append(S.viewerError);
}

function switchCenter(id) {
  if (id === S.center) return;
  if (id === 'texture' && !S.texDoc) return;
  S.center = id;
  refresh();
}

/** Ouvre une texture de travail dans l'éditeur. L'aperçu 3D reste chargé en arrière-plan. */
export async function openTexture(id, preloaded) {
  if (S.texDoc?.meta.id === id) { S.center = 'texture'; S.selection = { type: 'texture', id }; refresh(); return; }
  if (S.texDoc?.doc.dirty) {
    const ok = await confirmBox('Texture modifiée', `Enregistrer « ${S.texDoc.doc.name} » avant d'ouvrir une autre texture ?`, { ok: 'Enregistrer' });
    if (ok && !(await saveTexDoc())) return;
  }
  const r = preloaded?.doc ? preloaded : await api.textureLoad({ project: S.project, id });
  if (!r.ok && !preloaded) return toast(r.error, 'error');
  S.texDoc = { meta: r.meta, doc: payloadToDoc(r.doc, S.info?.config?.undoSteps ?? 40) };
  S.texDoc.doc.dirty = false;
  S.selection = { type: 'texture', id };
  S.center = 'texture';
  refresh();
}

/** Enregistre la texture ouverte (appelé aussi par « Enregistrer le projet »). */
export async function saveTexDoc() {
  if (!S.texDoc) return true;
  const { doc, meta } = S.texDoc;
  const payload = { name: doc.name, width: doc.width, height: doc.height,
    layers: doc.layers.map(({ image, ...l }) => ({ ...l, w: image.width, h: image.height, data: new Uint8Array(image.data.buffer, image.data.byteOffset, image.data.byteLength) })) };
  const r = await api.textureSave({ project: S.project, id: meta.id, doc: payload });
  if (!r.ok) { toast(`Texture non enregistrée : ${r.error}`, 'error'); return false; }
  adopt(r.project);
  doc.dirty = false;
  return true;
}

async function closeTexture() {
  if (S.texDoc?.doc.dirty) {
    const ok = await confirmBox('Texture modifiée', 'Enregistrer la texture avant de fermer l\'éditeur ?', { ok: 'Enregistrer' });
    if (ok && !(await saveTexDoc())) return;
  }
  S.editor?.dispose(); S.editor = null; S.texDoc = null; S.center = 'viewer';
  refresh();
}

// ===================================================================== modèles
async function showModel(assetId, opts = {}) {
  if (S.center !== 'viewer') { S.center = 'viewer'; refresh(); }
  S.viewerError?.remove(); S.viewerError = null;
  const r = await api.modelLoad({ project: S.project, assetId });
  if (!r.ok) return toast(r.error, 'error');
  status(`Chargement de ${r.name}…`);
  try {
    S.viewer.clear();
    const stats = await S.viewer.load(r);
    const g = opts.garment || currentGarment();
    const ref = g && S.project.referenceModels?.[g.ped];
    let refNote = '';
    if (ref) {
      const rr = await api.modelLoad({ project: S.project, assetId: ref });
      if (rr.ok) { try { await S.viewer.load(rr, { reference: true }); refNote = ' · personnage de référence affiché'; } catch (e) { refNote = ` · personnage de référence illisible (${e.message})`; } }
    } else if (g) refNote = ` · aucun modèle de personnage ${g.ped} fourni (voir Propriétés du projet)`;
    S.viewerInfo = `${r.name} · ${stats.meshes} maillage(s) · ${stats.triangles} triangles · ${stats.dimensions.join(' × ')} unités${stats.scaled ? ' (affiché réduit)' : ''}${refNote}`;
    if (S.viewerInfoEl) S.viewerInfoEl.textContent = S.viewerInfo;
    S.viewerStats = { name: r.name, assetId, ...stats };
    // Textures associées aux matériaux du vêtement
    if (g) for (const m of g.materials || []) if (m.textureDocId) await applyDocToMaterial(m.name, m.textureDocId);
    renderViewerTools();
    status('Prêt.');
  } catch (e) {
    S.viewerStats = null;
    S.viewerInfo = '';
    if (S.viewerInfoEl) S.viewerInfoEl.textContent = '';
    S.viewerError = h('div.viewer-msg', h('div.box', h('h2', 'Aperçu 3D impossible'), h('p', e.message),
      h('p.muted', 'Vérifiez que le fichier est un OBJ, glTF/GLB ou FBX valide. Les autres opérations (textures, export) restent disponibles.')));
    document.querySelector('.center-body')?.append(S.viewerError);
    renderViewerTools();
    status('Échec du chargement du modèle.');
  }
}

async function applyDocToMaterial(matName, docId) {
  if (S.editor?.active && S.editor.meta.id === docId && S.editor.canvas) { S.viewer.applyTexture(matName, S.editor.canvas); return; }
  if (S.texDoc?.meta.id === docId) {
    const img = S.texDoc.doc.composite();
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(img.data), img.width, img.height), 0, 0);
    S.viewer.applyTexture(matName, c); return;
  }
  const r = await api.textureLoad({ project: S.project, id: docId });
  if (!r.ok) return;
  // Composition rapide (canvas) pour l'aperçu
  const c = document.createElement('canvas'); c.width = r.doc.width; c.height = r.doc.height;
  const ctx = c.getContext('2d');
  for (const l of r.doc.layers) {
    if (!l.visible) continue;
    const lc = document.createElement('canvas'); lc.width = l.w; lc.height = l.h;
    lc.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(l.data), l.w, l.h), 0, 0);
    const w = l.w * l.scale, hh = l.h * l.scale;
    ctx.save(); ctx.globalAlpha = l.opacity; ctx.translate(l.x + w / 2, l.y + hh / 2); ctx.rotate((l.rotation * Math.PI) / 180);
    ctx.drawImage(lc, -w / 2, -hh / 2, w, hh); ctx.restore();
  }
  S.viewer.applyTexture(matName, c);
}

function currentGarment() {
  return S.selection?.type === 'garment' ? S.project.garments.find((g) => g.id === S.selection.id) : null;
}

/** Outils du visualiseur dans le panneau de droite (sous les propriétés). */
function renderViewerTools() {
  const box = document.getElementById('viewer-tools');
  if (!box) return;
  const st = S.viewerStats;
  if (!S.viewer) { fill(box, h('p.help', 'Aucun modèle 3D affiché.')); return; }
  if (!st) { fill(box, h('p.help', 'Aucun modèle 3D affiché. Vous pouvez aussi partir de zéro avec les formes ci-dessous.'), create3dTools()); return; }
  const g = currentGarment();
  const mats = S.viewer.materials();
  fill(box, 
    h('dl.kv', h('dt', 'Modèle'), h('dd', st.name), h('dt', 'Maillages'), h('dd', String(st.meshes)), h('dt', 'Triangles'), h('dd', String(st.triangles)),
      h('dt', 'Dimensions'), h('dd', `${st.dimensions.join(' × ')}`)),
    issueList(st.issues),
    h('h3', { style: { marginTop: '12px' } }, 'Matériaux et textures'),
    mats.map((m) => {
      const link = g?.materials?.find((x) => x.name === m);
      return field(m, select([{ value: '', label: '— Aucune texture —' }, ...S.project.textureDocs.map((t) => ({ value: t.id, label: t.name }))], link?.textureDocId || '', async (v) => {
        if (g) commit('Associer une texture', () => { g.materials = (g.materials || []).filter((x) => x.name !== m); if (v) g.materials.push({ name: m, textureDocId: v }); }, { render: false });
        if (v) await applyDocToMaterial(m, v); else S.viewer.removeTexture(m);
        if (!g) toast('Aperçu uniquement : sélectionnez un vêtement pour mémoriser l\'association.', 'info');
      }));
    }),
    h('h3', { style: { marginTop: '12px' } }, 'Objet sélectionné'),
    S.viewer.selected ? h('div.row.tight', { style: { flexWrap: 'wrap', gap: '4px' } },
      btn('Déplacer', () => S.viewer.setTransformMode('translate'), { kind: 'small' }), btn('Tourner', () => S.viewer.setTransformMode('rotate'), { kind: 'small' }),
      btn('Échelle', () => S.viewer.setTransformMode('scale'), { kind: 'small' }), btn('Réinitialiser', () => S.viewer.resetTransform(), { kind: 'small' }),
      btn('Désélectionner', () => S.viewer.select(null), { kind: 'small' }),
      /^(box|sphere|cylinder|cone|torus|plane|button|capsule)_\d+$/.test(S.viewer.selected.name) ? h('label.small.muted', { style: { display: 'flex', alignItems: 'center', gap: '6px' } }, 'Couleur',
        h('input', { type: 'color', value: '#cccccc', oninput: (e) => S.viewer.setColor(S.viewer.selected, e.target.value) })) : null,
      btn('Supprimer la pièce', () => { if (S.viewer.removeSelected()) { renderViewerTools(); toast('Pièce supprimée de l\'aperçu (enregistrez une copie GLB pour la garder).'); } }, { kind: 'small danger' })) : h('p.help', 'Cliquez sur une pièce du modèle pour la sélectionner.'),
    create3dTools(),
    h('div.row', { style: { marginTop: '10px' } }, btn('Enregistrer une copie de travail (GLB)', async () => {
      try {
        const data = await S.viewer.exportGlb();
        const r = await api.modelSaveWork({ project: S.project, name: `${(st?.name || 'creation').replace(/\.[^.]+$/, '')}_travail`, data });
        if (!r.ok) return toast(r.error, 'error');
        adopt(r.project, 'Copie de travail GLB'); toast('Copie de travail enregistrée dans le projet (Modèles 3D).', 'success'); renderLeftOnly();
      } catch (e) { toast(e.message, 'error'); }
    }, { kind: 'small' })),
    h('p.help', 'La copie GLB garde les transformations et textures appliquées. Elle reste un modèle intermédiaire : la conversion en .ydd se fait dans Blender + Sollumz.'),
  );
}
/** Formes 3D et effacement de zone sur le modèle affiché. */
function create3dTools() {
  const st = { color: '#c8c8c8', size: 10, radius: 4 };
  const SH = [['box', 'Cube'], ['sphere', 'Sphère'], ['cylinder', 'Cylindre'], ['cone', 'Cône'], ['torus', 'Anneau'], ['plane', 'Plaque'], ['button', 'Bouton'], ['capsule', 'Capsule']];
  const eraseBtn = btn(S.viewer.eraseOn ? 'Effacement actif : cliquer sur le modèle' : 'Effacer une zone', () => {
    S.viewer.onErase = (n) => status(`${n} triangle(s) effacé(s).`);
    S.viewer.setEraseMode(!S.viewer.eraseOn, st.radius / 100);
    renderViewerTools();
  }, { kind: `small${S.viewer.eraseOn ? ' active' : ''}`, icon: 'eraser', id: 'erase3d' });
  return h('div', { style: { marginTop: '12px' } },
    h('h3', 'Créer et modifier en 3D'),
    h('div.row.tight', { style: { flexWrap: 'wrap', gap: '6px', marginBottom: '6px' } },
      h('label.small.muted', { style: { display: 'flex', alignItems: 'center', gap: '6px' } }, 'Couleur', h('input', { type: 'color', value: st.color, oninput: (e) => { st.color = e.target.value; } })),
      h('label.small.muted', { style: { display: 'flex', alignItems: 'center', gap: '6px' } }, 'Taille (cm)', h('input.input', { type: 'number', min: 1, max: 200, value: st.size, style: { width: '70px' }, oninput: (e) => { st.size = Number(e.target.value) || 10; } }))),
    h('div.shape-grid', SH.map(([id, label]) => h('button', { type: 'button', dataset: { shape3d: id }, onclick: () => {
      try {
        S.viewer.addShape(id, { color: st.color, size: st.size / 100 });
        const main = S.viewer.models.find((m) => !m.reference);
        const a = analyse(main.object);
        S.viewerStats = { name: S.viewerStats?.name || 'Création', assetId: S.viewerStats?.assetId, ...a };
        renderViewerTools();
        toast(`${label} ajouté(e) : déplacez-le avec les poignées.`, 'info', 2500);
      } catch (e) { toast(e.message, 'error'); }
    } }, icon(id === 'sphere' ? 'sphere' : 'cube', 22), label))),
    h('div.row.tight', { style: { flexWrap: 'wrap', gap: '6px', marginTop: '8px' } }, eraseBtn,
      h('label.small.muted', { style: { display: 'flex', alignItems: 'center', gap: '6px' } }, 'Rayon (cm)', h('input', { type: 'range', min: 1, max: 30, value: st.radius, style: { width: '90px' },
        oninput: (e) => { st.radius = Number(e.target.value); if (S.viewer.eraseOn) S.viewer.eraseRadius = st.radius / 100; } })),
      btn('Annuler l\'effacement', () => { if (!S.viewer.undoErase()) toast('Rien à annuler.'); }, { kind: 'small' })),
    h('p.help', 'Formes, pièces supprimées et zones effacées font partie de la copie GLB. Pour les porter en jeu, ce GLB doit être converti en .ydd dans Blender + Sollumz (squelette et poids du personnage). Pour un rendu immédiat en jeu, utilisez plutôt les formes de l\'éditeur de texture (boutons, coutures, logos…).'));
}

function renderLeftOnly() { const el = document.querySelector('.panel.left'); if (el) renderLeft(el); }

// ===================================================================== droite
function renderRight(el) {
  const sel = S.selection;
  const P = S.project;
  let content;
  if (sel?.type === 'garment') content = garmentProps(P.garments.find((g) => g.id === sel.id));
  else if (sel?.type === 'asset') content = assetProps(P.assets.find((a) => a.id === sel.id));
  else if (sel?.type === 'texture') content = textureProps(P.textureDocs.find((t) => t.id === sel.id));
  else content = projectProps();
  fill(el, h('div.panel-head', h('h3', 'Propriétés')), content || projectProps(), h('div.props-section', h('h3', 'Aperçu 3D'), h('div#viewer-tools')));
  renderViewerTools();
}

function garmentProps(g) {
  if (!g) return null;
  const P = S.project;
  const upd = (label, fn) => commit(label, () => fn(g));
  const slots = g.kind === 'prop' ? PROPS : COMPONENTS;
  const gtaOf = (role) => P.assets.filter((a) => a.kind === 'gta' && (a.info?.role === role || a.name.toLowerCase().endsWith(`.${role}`)));
  const models = P.assets.filter((a) => a.kind === 'model');
  const usedLetters = new Set(g.variants.map((v) => v.letter));
  const issuesBox = h('div');
  return h('div',
    h('div.props-section',
      field('Nom', h('input.input#g-name', { value: g.name, onchange: (e) => upd('Renommer le vêtement', (x) => { x.name = e.target.value.trim() || x.name; }) })),
      field('Description', h('textarea.input', { rows: 2, onchange: (e) => upd('Description', (x) => { x.description = e.target.value; }) }, g.description || '')),
      field('Catégorie (organisation)', select(P.categories.map((c) => ({ value: c, label: c })), g.category, (v) => upd('Catégorie', (x) => { x.category = v; })),
        'Sert seulement à ranger : elle ne choisit pas l\'emplacement dans le jeu.'),
      field('Personnage cible', select(PED_OPTS, g.ped, (v) => upd('Personnage cible', (x) => { x.ped = v; })),
        'Un vêtement est fait pour UN personnage : le modèle homme et le modèle femme ont des corps différents.')),
    h('div.props-section', h('h3', 'Emplacement GTA V'),
      field('Type', select([{ value: 'component', label: 'Composant (vêtement porté)' }, { value: 'prop', label: 'Accessoire (chapeau, lunettes, montre…)' }], g.kind,
        (v) => upd('Type de vêtement', (x) => { x.kind = v; x.slot = null; }))),
      field('Slot', select([{ value: '', label: '— Choisir —' }, ...slots.map((s) => ({ value: s.key, label: `${s.label} · ${s.key}` }))], g.slot || '', (v) => upd('Slot GTA V', (x) => { x.slot = v || null; }), { id: 'g-slot' }),
        'À choisir selon le vêtement d\'origine (même slot que le fichier .ydd).'),
      field('Numéro du modèle (0–999)', h('input.input#g-index', { type: 'number', min: 0, max: 999, value: Number.isInteger(g.drawableIndex) ? g.drawableIndex : '',
        onchange: (e) => upd('Numéro du modèle', (x) => { const n = Number(e.target.value); x.drawableIndex = e.target.value === '' || !Number.isInteger(n) ? null : Math.max(0, Math.min(999, n)); }) }),
      P.exportSettings.mode === 'addon' ? 'Collection additionnelle : numéro dans VOTRE collection (à partir de 0).' : 'Remplacement : numéro du vêtement du jeu à remplacer.')),
    h('div.props-section', h('h3', 'Fichiers'),
      field('Modèle GTA V (.ydd)', select([{ value: '', label: g.kind === 'prop' || P.exportSettings.mode === 'replace' ? '— Aucun (textures seulement) —' : '— Aucun —' }, ...gtaOf('ydd').map((a) => ({ value: a.id, label: a.name }))], g.yddAssetId || '',
        (v) => upd('Modèle .ydd', (x) => { x.yddAssetId = v || null; }))),
      field('Modèle 3D de travail (aperçu)', h('div.row', select([{ value: '', label: '— Aucun —' }, ...models.map((a) => ({ value: a.id, label: a.name }))], g.modelAssetId || '',
        (v) => { upd('Modèle 3D de travail', (x) => { x.modelAssetId = v || null; }); if (v) showModel(v, { garment: g }); }),
      g.modelAssetId ? btn('', () => showModel(g.modelAssetId, { garment: g }), { icon: 'eye', kind: 'small', title: 'Afficher' }) : null),
      'OBJ / glTF / GLB / FBX : sert à l\'aperçu et au patron UV. Il n\'est pas exporté tel quel.')),
    h('div.props-section', h('div.row.tight', h('h3', { style: { flex: 1, margin: 0 } }, 'Variantes de texture'),
      btn('Ajouter', () => { const l = VARIANT_LETTERS.find((x) => !usedLetters.has(x)); if (!l) return toast('26 variantes maximum.'); upd('Nouvelle variante', (x) => x.variants.push({ id: newId(), name: '', letter: l, ytdAssetId: null, textureDocId: null })); }, { icon: 'plus', kind: 'small' })),
      g.variants.map((v) => h('div.variant',
        h('div.variant-head', h('b', `Variante ${v.letter}`),
          select(VARIANT_LETTERS.map((l) => ({ value: l, label: l })), v.letter, (val) => upd('Lettre de variante', () => { v.letter = val; }), { style: { width: '64px' } }),
          h('button.icon-btn', { title: 'Supprimer la variante', type: 'button', onclick: () => upd('Supprimer la variante', (x) => { x.variants = x.variants.filter((y) => y.id !== v.id); }) }, icon('trash', 15))),
        v.ytdAssetId ? btn(v.textureDocId ? 'Modifier la texture' : 'Modifier la texture du jeu', async () => {
          if (v.textureDocId && S.project.textureDocs.some((t) => t.id === v.textureDocId)) return openTexture(v.textureDocId);
          const res = await api.textureFromYtd({ project: S.project, assetId: v.ytdAssetId, textureName: null });
          if (!res.ok) return toast(res.error, 'error', 7000);
          adopt(res.project, 'Modifier la texture');
          const vv = S.project.garments.find((x) => x.id === g.id)?.variants.find((x) => x.id === v.id);
          if (vv) vv.textureDocId = res.meta.id;
          openTexture(res.meta.id, res);
        }, { icon: 'brush', kind: 'small primary', id: `edit-var-${v.letter}` }) : null,
        field('Textures GTA V (.ytd)', select([{ value: '', label: '— Aucun —' }, ...gtaOf('ytd').map((a) => ({ value: a.id, label: a.name }))], v.ytdAssetId || '', (val) => upd('Texture .ytd', () => { v.ytdAssetId = val || null; }))),
        field('ou texture de travail', h('div.row', select([{ value: '', label: '— Aucune —' }, ...P.textureDocs.map((t) => ({ value: t.id, label: t.name }))], v.textureDocId || '', (val) => upd('Texture de travail', () => { v.textureDocId = val || null; })),
          v.textureDocId ? btn('', () => openTexture(v.textureDocId), { icon: 'layers', kind: 'small', title: 'Ouvrir dans l\'éditeur' }) : null),
        v.ytdAssetId && v.textureDocId ? 'Votre texture sera écrite dans ce .ytd à l\'export.' : !v.ytdAssetId && v.textureDocId ? 'Exportée en DDS ; le .ytd est à créer avec un outil externe (pack marqué incomplet).' : null)))),
    h('div.props-section', h('div.row.tight', h('h3', { style: { flex: 1, margin: 0 } }, 'Vérification'),
      btn('Vérifier', async () => {
        const r = await api.exportValidate({ project: S.project, settings: { ...S.project.exportSettings, resourceName: S.project.exportSettings.resourceName || 'verification', packName: S.project.exportSettings.packName || S.project.name } });
        if (!r.ok) return toast(r.error, 'error');
        fill(issuesBox, issueList(r.issues.filter((i) => i.ref === g.id)));
      }, { icon: 'check', kind: 'small' })), issuesBox),
    h('div.props-section', h('div.row', btn('Dupliquer', () => {
      const copy = JSON.parse(JSON.stringify(g)); copy.id = newId(); copy.name = `${g.name} (copie)`; copy.drawableIndex = null;
      copy.variants.forEach((v) => { v.id = newId(); });
      commit('Dupliquer le vêtement', (p) => p.garments.push(copy), { render: false }); S.selection = { type: 'garment', id: copy.id }; refresh();
    }, { icon: 'copy', kind: 'small' }), btn('Supprimer', async () => {
      if (!(await confirmBox('Supprimer le vêtement', `Supprimer « ${g.name} » du projet ? Les fichiers importés restent dans la bibliothèque. (Ctrl+Z pour annuler)`, { ok: 'Supprimer', danger: true }))) return;
      S.selection = null; commit('Supprimer le vêtement', (p) => { p.garments = p.garments.filter((x) => x.id !== g.id); });
    }, { icon: 'trash', kind: 'small danger' }))),
  );
}

function assetProps(a) {
  if (!a) return null;
  const ST = { readable: 'Lisible', viewable: 'Affichable', editable: 'Modifiable', convertible: 'Convertible', exportable: 'Exportable' };
  const st = a.info?.status || {};
  const missing = S.missing.some((m) => m.id === a.id);
  return h('div',
    h('div.props-section',
      h('dl.kv', h('dt', 'Nom'), h('dd', a.name), h('dt', 'Type'), h('dd', `${(a.format || '?').toUpperCase()}${a.info?.role ? ` · ${a.info.role}` : ''}`),
        h('dt', 'Détails'), h('dd', a.info?.summary || '—'), h('dt', 'Taille'), h('dd', fmtBytes(a.size)), h('dt', 'Importé le'), h('dd', fmtDate(a.importedAt)),
        h('dt', 'Original'), h('dd.small', a.originalPath || '—'), h('dt', 'Empreinte'), h('dd.mono', (a.sha256 || '').slice(0, 16) + '…')),
      missing ? h('p', { style: { color: 'var(--err)' } }, 'Fichier introuvable dans le projet : réimportez-le.') : null,
      h('div.status-badges', Object.entries(ST).map(([k, l]) => h(`span.sbadge${st[k] ? '.on' : ''}`, `${st[k] ? '✓' : '✗'} ${l}`)))),
    a.info?.issues?.length ? h('div.props-section', h('h3', 'Analyse à l\'import'), issueList(a.info.issues)) : null,
    /\.ytd$/i.test(a.name) ? ytdTextures(a) : null,
    h('div.props-section', h('div.row', { style: { flexWrap: 'wrap' } },
      a.kind === 'texture' ? btn('Ouvrir dans l\'éditeur', async () => {
        const r = await api.textureFromAsset({ project: S.project, assetId: a.id });
        if (!r.ok) return toast(r.error, 'error');
        adopt(r.project, 'Nouvelle texture de travail');
        openTexture(r.meta.id, r);
      }, { icon: 'layers', kind: 'small primary' }) : null,
      a.kind === 'texture' && S.texDoc ? btn(`Ajouter comme calque à « ${S.texDoc.doc.name} »`, async () => {
        const d = await api.textureDecodeAsset({ project: S.project, assetId: a.id });
        S.center = 'texture'; S.selection = { type: 'texture', id: S.texDoc.meta.id }; refresh();
        S.editor?.addImageLayer?.(d, a.name);
      }, { icon: 'image', kind: 'small' }) : null,
      a.kind === 'model' ? btn('Afficher en 3D', () => showModel(a.id), { icon: 'cube', kind: 'small primary' }) : null,
      a.kind === 'model' ? btn('Personnage de référence…', () => setReference(a), { kind: 'small' }) : null,
      btn('Retirer du projet', async () => {
        if (!(await confirmBox('Retirer du projet', `Retirer « ${a.name} » ? La copie dans le projet est supprimée ; votre fichier d'origine n'est pas touché. Les associations à ce fichier sont effacées.`, { ok: 'Retirer', danger: true }))) return;
        const r = await api.assetRemove({ project: S.project, assetId: a.id });
        if (!r.ok) return toast(r.error, 'error');
        adopt(r.project, 'Retirer un fichier'); S.selection = null;
        S.missing = S.missing.filter((m) => m.id !== a.id);
        await (await import('../app.js')).saveProject({ quiet: true });
        refresh();
      }, { icon: 'trash', kind: 'small danger' }))));
}

/** Textures contenues dans un .ytd, avec « Modifier » (ouvre l'éditeur, relie à la variante). */
function ytdTextures(a) {
  const box = h('div.props-section', h('h3', 'Textures de ce .ytd'), h('p.muted.small', 'Lecture…'));
  api.ytdList({ project: S.project, assetId: a.id }).then((r) => {
    if (!r.ok) return fill(box, h('h3', 'Textures de ce .ytd'), h('p.small', { style: { color: 'var(--warn)' } }, `Lecture impossible : ${r.error}`),
      h('p.help', 'Le fichier reste utilisable tel quel dans l\'export ; seule la modification de ses textures n\'est pas possible.'));
    fill(box, h('h3', 'Textures de ce .ytd'), r.textures.map((t) => h('div.ytd-tex',
      t.url ? h('img', { src: t.url, alt: '' }) : h('div.ytd-noimg', t.format.toUpperCase()),
      h('div', { style: { flex: 1, minWidth: 0 } }, h('b.small', t.name), h('div.faint.small', `${t.width} × ${t.height} · ${t.format.toUpperCase()} · ${t.levels} mipmap(s)`),
        !t.writable ? h('div.small', { style: { color: 'var(--warn)' } }, 'Format non réécrivable par l\'application') : null),
      t.readable ? btn('Modifier', async () => {
        const res = await api.textureFromYtd({ project: S.project, assetId: a.id, textureName: t.name });
        if (!res.ok) return toast(res.error, 'error');
        adopt(res.project, 'Modifier une texture du jeu');
        for (const g of S.project.garments) for (const v of g.variants) if (v.ytdAssetId === a.id && !v.textureDocId) v.textureDocId = res.meta.id;
        openTexture(res.meta.id, res);
      }, { kind: 'small primary' }) : null)));
  });
  return box;
}

function setReference(a) {
  const st = { ped: 'mp_m_freemode_01' };
  modal({ title: 'Personnage de référence', body: h('div.form',
    h('p', 'Affiche ce modèle en transparence derrière les vêtements du personnage choisi.'),
    h('p.help', 'Utilisez uniquement un modèle que vous avez le droit d\'utiliser. L\'application ne fournit pas les modèles du jeu : un modèle générique n\'est PAS le personnage freemode exact.'),
    field('Personnage', select(PED_OPTS, st.ped, (v) => { st.ped = v; }))),
  actions: [{ label: 'Annuler' }, { label: 'Utiliser', kind: 'primary', onclick: () => commit('Personnage de référence', (p) => { p.referenceModels = { ...(p.referenceModels || {}), [st.ped]: a.id }; }) }] });
}

function textureProps(t) {
  if (!t) return null;
  const used = S.project.garments.filter((g) => g.variants.some((v) => v.textureDocId === t.id) || (g.materials || []).some((m) => m.textureDocId === t.id));
  return h('div', h('div.props-section',
    h('dl.kv', h('dt', 'Nom'), h('dd', t.name), h('dt', 'Dimensions'), h('dd', t.width ? `${t.width} × ${t.height}` : '—'), h('dt', 'Calques'), h('dd', String(t.layers ?? '—')),
      h('dt', 'Modifiée le'), h('dd', fmtDate(t.updatedAt)), h('dt', 'Utilisée par'), h('dd', used.map((g) => g.name).join(', ') || 'aucun vêtement')),
    h('div.row', { style: { marginTop: '10px', flexWrap: 'wrap' } },
      btn('Ouvrir', () => openTexture(t.id), { icon: 'layers', kind: 'small primary' }),
      btn('Renommer', async () => { const n = await prompt('Renommer la texture', { value: t.name }); if (n) commit('Renommer la texture', () => { t.name = n; }); }, { kind: 'small' }),
      btn('Supprimer', async () => {
        if (!(await confirmBox('Supprimer la texture', `Supprimer « ${t.name} » et ses calques ? Cette action est définitive.`, { ok: 'Supprimer', danger: true }))) return;
        if (S.texDoc?.meta.id === t.id) { S.editor?.dispose(); S.editor = null; S.texDoc = null; S.center = 'viewer'; }
        const r = await api.textureDelete({ project: S.project, id: t.id });
        if (!r.ok) return toast(r.error, 'error');
        adopt(r.project); S.past = []; S.selection = null;
        await (await import('../app.js')).saveProject({ quiet: true });
        refresh();
      }, { icon: 'trash', kind: 'small danger' }))));
}

function projectProps() {
  const P = S.project;
  return h('div',
    h('div.props-section', h('h3', 'Projet'),
      field('Nom', h('div.row', h('input.input', { value: P.name, disabled: true }), btn('Renommer', async () => {
        const n = await prompt('Renommer le projet', { value: P.name, help: 'Le dossier du projet est renommé aussi.' });
        if (!n || n === P.name) return;
        if (!(await (await import('../app.js')).saveProject({ quiet: true }))) return;
        const r = await api.projectRename(n);
        if (!r.ok) return toast(r.error, 'error');
        loadProject(r); toast('Projet renommé.', 'success');
      }, { kind: 'small' }))),
      field('Description', h('textarea.input', { rows: 2, onchange: (e) => commit('Description du projet', (p) => { p.description = e.target.value; }, { render: false }) }, P.description || '')),
      field('Personnages du projet', h('div', PED_OPTS.map((p) => h('label.checkbox', h('input', { type: 'checkbox', checked: P.targetPeds.includes(p.value),
        onchange: (e) => commit('Personnages du projet', (pp) => { pp.targetPeds = e.target.checked ? [...new Set([...pp.targetPeds, p.value])] : pp.targetPeds.filter((x) => x !== p.value); }) }), p.label)))),
      h('dl.kv', h('dt', 'Dossier'), h('dd.small', S.dir), h('dt', 'Créé le'), h('dd', fmtDate(P.createdAt)), h('dt', 'Vêtements'), h('dd', String(P.garments.length)),
        h('dt', 'Fichiers'), h('dd', String(P.assets.length)), h('dt', 'Textures'), h('dd', String(P.textureDocs.length)), h('dt', 'Exports'), h('dd', String(P.reports.length)))),
    h('div.props-section', h('h3', 'Personnages de référence (aperçu)'),
      PED_OPTS.map((p) => h('p.small', `${p.label} : `, P.referenceModels?.[p.value] ? h('b', P.assets.find((a) => a.id === P.referenceModels[p.value])?.name || '?') : h('span.muted', 'non fourni'))),
      h('p.help', 'Le modèle 3D officiel des personnages freemode n\'est pas fourni (fichiers du jeu). Importez un modèle que vous avez le droit d\'utiliser, puis « Personnage de référence… ».')),
    h('div.props-section', h('div.row.tight', h('h3', { style: { flex: 1, margin: 0 } }, 'Catégories'), btn('Ajouter', async () => {
      const n = await prompt('Nouvelle catégorie', { placeholder: 'Ex. : Uniformes' });
      if (n && !P.categories.includes(n)) commit('Nouvelle catégorie', (p) => p.categories.push(n));
    }, { icon: 'plus', kind: 'small' })), h('div.status-badges', P.categories.map((c) => h('span.sbadge.on', c)))),
    S.missing.length ? h('div.props-section', h('h3', 'Fichiers manquants'), h('ul.list', S.missing.map((m) => h('li.small', icon('warn', 14), h('span.grow', `${m.name} (${m.file})`))))) : null,
    h('div.props-section', h('h3', 'Actions'), h('div.row', { style: { flexWrap: 'wrap' } },
      btn('Dupliquer le projet', async () => {
        const n = await prompt('Nom de la copie', { value: `${P.name} (copie)` }); if (!n) return;
        await (await import('../app.js')).saveProject({ quiet: true });
        const r = await api.projectDuplicate(n); if (!r.ok) return toast(r.error, 'error'); toast(`Copie créée : ${r.dir}`, 'success', 6000);
      }, { icon: 'copy', kind: 'small' }),
      btn('Enregistrer comme modèle', async () => {
        const n = await prompt('Nom du modèle de projet', { value: P.name, help: 'Réutilisable lors de la création d\'un nouveau projet.' }); if (!n) return;
        await (await import('../app.js')).saveProject({ quiet: true });
        const r = await api.projectSaveTemplate(n); if (!r.ok) return toast(r.error, 'error'); toast('Modèle de projet enregistré.', 'success');
      }, { kind: 'small' }),
      btn('Ouvrir le dossier', () => api.shellOpenPath(S.dir), { icon: 'folder', kind: 'small' }),
      btn('Supprimer le projet…', async () => {
        const dir = S.dir;
        const r = await api.projectDelete(dir);
        if (!r.ok) return toast(r.error, 'error');
        if (r.deleted) { S.project = null; S.dir = null; S.dirty = false; (await import('../app.js')).go('home'); toast('Projet placé dans la corbeille.', 'success'); }
      }, { icon: 'trash', kind: 'small danger' }))),
    h('div.props-section', h('h3', 'Historique récent'), h('ul.list', [...P.history].reverse().slice(0, 8).map((x) => h('li.small', h('span.grow', x.action), h('span.faint', fmtDate(x.t)))))),
  );
}

