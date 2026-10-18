// Interface : état global, navigation, barre du haut, sauvegarde automatique, annuler / rétablir.
import { h, $, btn, icon, toast, modal, confirmBox } from './ui.js';
import { renderHome } from './views/home.js';
import { renderCatalog } from './views/catalog.js';
import { renderWorkspace, saveTexDoc } from './views/workspace.js';
import { renderTools } from './views/tools.js';
import { renderSettings, renderHelp } from './views/tools.js';

import { openExportWizard } from './views/exportWizard.js';
import { openImportDialog, newProjectDialog, openProjectFlow } from './views/dialogs.js';

export const api = window.fcs;

export const S = {
  info: null,
  dir: null,
  project: null,
  dirty: false,
  view: 'home',
  selection: null,          // { type: 'garment'|'asset'|'texture', id }
  center: 'viewer',         // 'viewer' | 'texture'
  panels: { left: true, right: true },
  missing: [],
  past: [], future: [],     // annuler / rétablir au niveau du projet
  editor: null,             // vue de l'éditeur de texture affichée
  texDoc: null,             // texture ouverte { meta, doc } (son historique lui est propre)
  viewer: null,
};

// ------------------------------------------------------------------ état du projet
/** Applique une modification ANNULABLE au projet. */
export function commit(label, fn, { render = true } = {}) {
  if (!S.project) return;
  S.past.push({ label, snap: JSON.stringify(S.project) });
  if (S.past.length > 100) S.past.shift();
  S.future = [];
  fn(S.project);
  markDirty();
  if (render) refresh();
}
export function markDirty() { S.dirty = true; renderTopbar(); }
/** Remplace le projet par la version renvoyée par le processus principal (import, texture…). */
export function adopt(project, label) {
  if (label) { S.past.push({ label, snap: JSON.stringify(S.project) }); S.future = []; }
  S.project = project;
  markDirty();
}
export function undo() {
  if (S.center === 'texture' && S.editor?.active && S.editor.undo()) return;
  const step = S.past.pop();
  if (!step) return toast('Rien à annuler.');
  S.future.push({ label: step.label, snap: JSON.stringify(S.project) });
  S.project = JSON.parse(step.snap);
  markDirty(); refresh();
  status(`Annulé : ${step.label}`);
}
export function redo() {
  if (S.center === 'texture' && S.editor?.active && S.editor.redo()) return;
  const step = S.future.pop();
  if (!step) return toast('Rien à rétablir.');
  S.past.push({ label: step.label, snap: JSON.stringify(S.project) });
  S.project = JSON.parse(step.snap);
  markDirty(); refresh();
  status(`Rétabli : ${step.label}`);
}

export async function saveProject({ quiet = false } = {}) {
  if (!S.project) return true;
  if (S.texDoc?.doc.dirty && !(await saveTexDoc())) return false;
  const r = await api.projectSave(S.project);
  if (!r.ok) { toast(`Enregistrement impossible : ${r.error}`, 'error'); return false; }
  S.dirty = false;
  $('#status-save').textContent = `Enregistré à ${new Date(r.savedAt).toLocaleTimeString('fr-FR')}`;
  renderTopbar();
  if (!quiet) toast('Projet enregistré.', 'success', 2000);
  return true;
}

/** Ouvre un projet : récupération proposée, fichiers manquants signalés. */
export async function loadProject(r) {
  S.editor?.dispose(); S.viewer?.dispose(); S.viewer = null; S.editor = null; S.texDoc = null; S.viewerStats = null; S.viewerInfo = ''; S.viewerError = null;
  S.dir = r.dir; S.project = r.project; S.dirty = false; S.past = []; S.future = []; S.selection = null; S.missing = r.missing || [];
  S.center = 'viewer';
  go('workspace');
  if (r.migrated) toast('Projet mis à jour vers le nouveau format (une copie de l\'ancien a été gardée).', 'info', 6000);
  if (r.recovery) {
    const yes = await confirmBox('Récupérer le travail non enregistré ?',
      `${r.recovery.abnormal ? 'L\'application ne s\'est pas fermée correctement. ' : ''}Une sauvegarde automatique plus récente existe (${new Date(r.recovery.updatedAt).toLocaleString('fr-FR')}). La récupérer ?`, { ok: 'Récupérer' });
    if (yes) {
      const rr = await api.projectRecover();
      if (rr.ok) { S.project = rr.project; refresh(); toast('Travail récupéré.', 'success'); } else toast(rr.error, 'error');
    }
  }
  if (S.missing.length) toast(`${S.missing.length} fichier(s) du projet introuvable(s) : ils sont barrés dans la liste.`, 'warning', 7000);
}

export async function closeProject({ quitting = false } = {}) {
  if (S.project && (S.dirty || S.texDoc?.doc.dirty)) {
    const choice = await new Promise((resolve) => {
      modal({ title: 'Modifications non enregistrées', body: h('p', 'Voulez-vous enregistrer le projet avant de le fermer ?'),
        actions: [{ label: 'Annuler', onclick: () => resolve('cancel') }, { label: 'Ne pas enregistrer', kind: 'danger', onclick: () => resolve('discard') },
          { label: 'Enregistrer', kind: 'primary', onclick: () => resolve('save') }], onClose: () => resolve('cancel') });
    });
    if (choice === 'cancel') return false;
    if (choice === 'save' && !(await saveProject())) return false;
  }
  S.editor?.dispose(); S.viewer?.dispose(); S.viewer = null; S.editor = null; S.texDoc = null; S.viewerStats = null; S.viewerInfo = ''; S.viewerError = null;
  await api.projectClose({ discardAutosave: true, quitting });
  S.dir = null; S.project = null; S.dirty = false; S.selection = null;
  if (!quitting) { go('home'); }
  return true;
}

// ------------------------------------------------------------------ navigation
export function go(view) {
  if (view !== 'workspace') { S.editor?.dispose(); S.editor = null; S.viewer?.dispose(); S.viewer = null; S.viewerStats = null; S.viewerInfo = ''; S.viewerError = null; }
  S.view = view;
  refresh();
}
export function refresh() {
  renderTopbar();
  const main = $('#main');
  main.replaceChildren();
  if (S.view === 'workspace' && S.project) renderWorkspace(main);
  else if (S.view === 'catalog') renderCatalog(main);
  else if (S.view === 'tools') renderTools(main);
  else if (S.view === 'settings') renderSettings(main);
  else if (S.view === 'help') renderHelp(main);
  else renderHome(main);
  updateIssuesPill();
}

export function status(text) { $('#status-text').textContent = text; }
export function progress(label, ratio) {
  const p = $('#status-progress');
  if (ratio === null || ratio === undefined) { p.hidden = true; return; }
  p.hidden = false;
  p.querySelector('i').style.width = `${Math.round(ratio * 100)}%`;
  p.querySelector('.label').textContent = label;
}
export function updateIssuesPill() {
  const el = $('#status-issues');
  el.replaceChildren();
  if (S.missing?.length) el.append(h('span.pill.err', `${S.missing.length} fichier(s) manquant(s)`));
}

function renderTopbar() {
  const bar = $('#topbar');
  const p = S.project;
  bar.replaceChildren(...[
    h('div.brand', h('div.logo', icon('shirt', 16)), S.info?.appName || 'FiveM Clothing Studio'),
    h('div.project', p ? [h('b', p.name), S.dirty ? h('span.dirty-dot', { title: 'Modifications non enregistrées' }) : null] : h('span', '')),
    btn('Accueil', () => go(S.project ? 'home' : 'home'), { icon: 'home', kind: 'ghost', title: 'Accueil' }),
    S.project ? btn('Projet', () => go('workspace'), { icon: 'layers', kind: `ghost${S.view === 'workspace' ? ' active' : ''}`, title: 'Espace de création' }) : null,
    btn('Vêtements du jeu', () => go('catalog'), { icon: 'shirt', kind: `ghost${S.view === 'catalog' ? ' active' : ''}`, title: 'Tous les vêtements de GTA V, pour créer les vôtres' }),
    S.project ? btn('Importer', () => openImportDialog(), { icon: 'import', kind: 'ghost', title: 'Importer des fichiers (Ctrl+I)' }) : null,
    S.project ? btn('Enregistrer', () => saveProject(), { icon: 'save', kind: 'ghost', title: 'Enregistrer (Ctrl+S)' }) : null,
    S.project ? h('span.sep') : null,
    S.project ? h('button.icon-btn', { title: 'Annuler (Ctrl+Z)', onclick: undo, type: 'button' }, icon('undo')) : null,
    S.project ? h('button.icon-btn', { title: 'Rétablir (Ctrl+Y)', onclick: redo, type: 'button' }, icon('redo')) : null,
    S.project ? h('span.sep') : null,
    S.project ? btn('Exporter pour FiveM', () => openExportWizard(), { icon: 'export', kind: 'primary' }) : null,
    btn('', () => go('tools'), { icon: 'tool', kind: 'ghost', title: 'Outils et dépendances' }),
    btn('', () => go('settings'), { icon: 'gear', kind: 'ghost', title: 'Paramètres' }),
    btn('', () => go('help'), { icon: 'help', kind: 'ghost', title: 'Aide (F1)' }),
  ].filter(Boolean));
}

// ------------------------------------------------------------------ commandes du menu et raccourcis
const COMMANDS = {
  new: () => newProjectDialog(), open: () => openProjectFlow(), save: () => saveProject(),
  import: () => (S.project ? openImportDialog() : toast('Ouvrez ou créez d\'abord un projet.')),
  export: () => (S.project ? openExportWizard() : toast('Ouvrez ou créez d\'abord un projet.')),
  close: () => closeProject(), undo, redo, help: () => go('help'), tools: () => go('tools'),
  'toggle-left': () => { S.panels.left = !S.panels.left; refresh(); },
  'toggle-right': () => { S.panels.right = !S.panels.right; refresh(); },
  'quit-request': async () => { if (!S.project) return api.projectClose({ quitting: true }); await closeProject({ quitting: true }); },
};
api.on('menu', (cmd) => COMMANDS[cmd]?.());
document.addEventListener('keydown', (e) => {
  const inField = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName);
  if (e.key === 'F1') { e.preventDefault(); go('help'); }
  if (!(e.ctrlKey || e.metaKey) || e.altKey) return;
  // Raccourcis gérés ici (le menu les affiche sans les intercepter : registerAccelerator: false)
  const k = e.key.toLowerCase();
  const map = { s: 'save', n: 'new', o: 'open', i: 'import', e: 'export', 1: 'toggle-left', 2: 'toggle-right' };
  if (k === 'z' || k === 'y') {
    if (inField) return;                    // annuler natif dans les champs de texte
    e.preventDefault();
    if (k === 'y' || e.shiftKey) redo(); else undo();
    return;
  }
  if (map[k] && document.querySelector('.overlay') && k !== 's') return; // une fenêtre est déjà ouverte
  if (map[k]) { e.preventDefault(); COMMANDS[map[k]](); }
});
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', (e) => e.preventDefault());

// ------------------------------------------------------------------ sauvegarde automatique
let autosaveTimer = null;
function startAutosave() {
  clearInterval(autosaveTimer);
  const sec = Math.max(15, Number(S.info?.config?.autosaveSeconds) || 60);
  autosaveTimer = setInterval(async () => {
    if (!S.project || !S.dirty) return;
    const r = await api.projectAutosave(S.project);
    if (r.ok) $('#status-save').textContent = `Sauvegarde automatique ${new Date(r.savedAt).toLocaleTimeString('fr-FR')}`;
  }, sec * 1000);
}

window.addEventListener('error', (e) => { console.error(e.error || e.message); toast(`Erreur inattendue : ${e.message}`, 'error'); });
window.addEventListener('unhandledrejection', (e) => { console.error(e.reason); toast(`Erreur inattendue : ${e.reason?.message || e.reason}`, 'error'); });

async function boot() {
  const r = await api.appInfo();
  S.info = r;
  document.title = r.appName;
  startAutosave();
  refresh();
  status('Prêt.');
}
window.__fcs = S; // inspection (tests automatisés, outils de développement)
boot();
