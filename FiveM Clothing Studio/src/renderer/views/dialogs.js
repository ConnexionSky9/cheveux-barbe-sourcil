// Dialogues : nouveau projet, ouverture, import de fichiers (analyse puis confirmation).
import { h, modal, toast, field, select, issueList, fmtBytes, icon } from '../ui.js';
import { S, api, loadProject, closeProject, adopt, refresh, status, progress } from '../app.js';

const PEDS = [
  { value: 'mp_m_freemode_01', label: 'Homme (mp_m_freemode_01)' },
  { value: 'mp_f_freemode_01', label: 'Femme (mp_f_freemode_01)' },
];

export async function newProjectDialog() {
  if (S.project && !(await closeProject())) return;
  const t = await api.projectTemplates();
  const st = { name: '', parent: '', peds: ['mp_m_freemode_01'], template: '' };
  const parentLabel = h('div.input', { style: { cursor: 'pointer' } }, 'Choisir…');
  const pick = async () => { const r = await api.dialogPickDir('Dossier où créer le projet'); if (r.path) { st.parent = r.path; parentLabel.textContent = r.path; } };
  parentLabel.onclick = pick;
  const pedBox = h('div', PEDS.map((p) => h('label.checkbox', h('input', { type: 'checkbox', checked: st.peds.includes(p.value),
    onchange: (e) => { st.peds = e.target.checked ? [...new Set([...st.peds, p.value])] : st.peds.filter((x) => x !== p.value); } }), p.label)));
  modal({
    title: 'Nouveau projet',
    body: h('div.form',
      field('Nom du projet', h('input.input#np-name', { placeholder: 'Ex. : Collection été', oninput: (e) => { st.name = e.target.value; } })),
      field('Dossier', parentLabel, 'Le projet sera un dossier « <nom>.fcsproj » dans ce dossier. Les accents et espaces sont acceptés.'),
      field('Personnage(s) cible(s)', pedBox, 'Un pack peut contenir des vêtements pour les deux personnages ; chaque vêtement a son personnage.'),
      (t.templates || []).length ? field('Modèle de projet (facultatif)', select([{ value: '', label: 'Aucun (projet vide)' }, ...t.templates.map((x) => ({ value: x, label: x.replace(/\.fcsproj$/, '') }))], '', (v) => { st.template = v; })) : null,
    ),
    actions: [{ label: 'Annuler' }, { label: 'Créer le projet', kind: 'primary', id: 'np-create', onclick: async () => {
      if (!st.name.trim()) { toast('Donnez un nom au projet.', 'error'); return true; }
      if (!st.parent) { await pick(); if (!st.parent) return true; }
      if (!st.peds.length) { toast('Choisissez au moins un personnage.', 'error'); return true; }
      const r = await api.projectCreate({ parent: st.parent, name: st.name.trim(), peds: st.peds, template: st.template || null });
      if (!r.ok) { toast(r.error, 'error'); return true; }
      toast('Projet créé.', 'success');
      loadProject(r);
      return false;
    } }],
  });
}

export async function openProjectFlow() {
  if (S.project && !(await closeProject())) return;
  const r = await api.dialogOpenProject();
  if (!r.dir) return;
  const o = await api.projectOpen(r.dir);
  if (!o.ok) return toast(o.error, 'error', 7000);
  loadProject(o);
}

/** Import : choix (ou dépôt) des fichiers → analyse → liste des opérations possibles → import. */
export async function openImportDialog(paths) {
  if (!S.project) return toast('Ouvrez ou créez d\'abord un projet.');
  if (!paths) {
    const r = await api.dialogPickFiles({ title: 'Importer des fichiers' });
    paths = r.paths || [];
  }
  if (!paths.length) return;
  status('Analyse des fichiers…');
  const r = await api.importInspect(paths);
  status('Prêt.');
  if (!r.ok) return toast(r.error, 'error');
  const choices = r.reports.map((rep) => ({ rep, take: !rep.issues.some((i) => i.level === 'error') || (rep.family === 'gta' && rep.status.readable) }));
  const ST = { readable: 'Lisible', viewable: 'Affichable', editable: 'Modifiable', convertible: 'Convertible', exportable: 'Exportable' };
  const body = h('div', h('p.muted', 'Les fichiers sont COPIÉS dans le projet : vos originaux ne sont jamais modifiés.'),
    choices.map((c) => h('div.import-item',
      h('header', h('input', { type: 'checkbox', checked: c.take, disabled: !c.take && c.rep.issues.some((i) => i.level === 'error'), onchange: (e) => { c.take = e.target.checked; } }),
        icon(c.rep.kind === 'model' ? 'cube' : c.rep.kind === 'texture' ? 'image' : 'file'), h('b', c.rep.name),
        h('span.faint.small', `${c.rep.format.toUpperCase()} · ${fmtBytes(c.rep.size)}`)),
      h('div.status-badges', Object.entries(ST).map(([k, l]) => h(`span.sbadge${c.rep.status[k] ? '.on' : ''}`, `${c.rep.status[k] ? '✓' : '✗'} ${l}`))),
      c.rep.operations.length ? h('div.small.muted', 'Possible : ', c.rep.operations.join(' · ')) : null,
      issueList(c.rep.issues))));
  modal({ title: `Importer ${paths.length} fichier(s)`, wide: true, body,
    actions: [{ label: 'Annuler' }, { label: 'Importer la sélection', kind: 'primary', id: 'import-go', onclick: async () => {
      const todo = choices.filter((c) => c.take);
      let n = 0, dup = 0, project = S.project;
      for (const [i, c] of todo.entries()) {
        progress(`Import ${i + 1}/${todo.length}`, i / todo.length);
        const res = await api.importAdd({ project, path: c.rep.path });
        if (!res.ok) { toast(`${c.rep.name} : ${res.error}`, 'error', 7000); continue; }
        project = res.project; if (res.duplicate) dup++; else n++;
      }
      progress(null, null);
      adopt(project, 'Import de fichiers');
      refresh();
      toast(`${n} fichier(s) importé(s)${dup ? `, ${dup} déjà présent(s)` : ''}.`, 'success');
    } }] });
}
