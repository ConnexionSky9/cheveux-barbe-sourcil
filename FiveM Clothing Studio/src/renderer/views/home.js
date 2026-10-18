// Écran d'accueil.
import { h, fill, icon, btn, fmtDate } from '../ui.js';
import { S, api, go, loadProject } from '../app.js';
import { newProjectDialog, openProjectFlow, openImportDialog } from './dialogs.js';
import { openExportWizard } from './exportWizard.js';
import { toast } from '../ui.js';

export function renderHome(main) {
  const hasProject = Boolean(S.project);
  const card = (ic, title, text, onclick, disabled, id) => h(`button.card${disabled ? '.disabled' : ''}`, { onclick: disabled ? () => toast(disabled) : onclick, type: 'button', id }, icon(ic), h('b', title), h('span', text));
  const recentBox = h('ul.list');
  const toolsBox = h('ul.list', h('li.muted', 'Détection en cours…'));
  const eventsBox = h('ul.list.events');
  main.append(h('div.home', h('div.home-grid',
    h('div',
      h('div.hero', h('h1', 'Bienvenue dans ', S.info.appName),
        h('p', 'Créez un projet, importez vos textures et modèles, retouchez-les, vérifiez-les puis exportez une ressource FiveM prête à installer. ',
          'Les étapes qui demandent un outil externe sont toujours signalées clairement.')),
      hasProject ? h('div.box', h('div.row.tight', icon('layers'), h('b', { style: { flex: 1 } }, `Projet ouvert : ${S.project.name}`), btn('Reprendre', () => go('workspace'), { kind: 'primary' }))) : null,
      h('div.cards',
        card('plus', 'Nouveau projet', 'Choisir le personnage et commencer un pack', () => newProjectDialog(), null, 'home-new'),
        card('folder', 'Ouvrir un projet', 'Reprendre un projet existant', () => openProjectFlow(), null, 'home-open'),
        card('shirt', 'Vêtements du jeu', 'Tous les vêtements de GTA V : choisir, modifier, créer', () => go('catalog'), null, 'home-catalog'),
        card('import', 'Importer des fichiers', 'Textures, logos, modèles 3D, fichiers GTA V', () => openImportDialog(), hasProject ? null : 'Créez ou ouvrez d\'abord un projet.'),
        card('shirt', 'Bibliothèque de vêtements', 'Vêtements, variantes et fichiers du projet', () => go('workspace'), hasProject ? null : 'Créez ou ouvrez d\'abord un projet.'),
        card('export', 'Exporter pour FiveM', 'Vérifier puis générer la ressource', () => openExportWizard(), hasProject ? null : 'Créez ou ouvrez d\'abord un projet.'),
        card('tool', 'Outils et dépendances', 'Blender, Sollumz, CodeWalker', () => go('tools')),
        card('gear', 'Paramètres', 'Chemins des outils, sauvegarde, limites', () => go('settings')),
        card('help', 'Documentation et aide', 'Guide pas à pas et formats pris en charge', () => go('help')),
      ),
      h('div.box', h('h3', 'Le parcours'), h('ol.muted', { style: { margin: 0, paddingLeft: '18px' } },
        h('li', 'Créer — un projet par pack, personnage homme et/ou femme.'),
        h('li', 'Modifier — textures en calques (couleurs, logos, texte), modèles 3D en aperçu.'),
        h('li', 'Prévisualiser — aperçu 3D des modèles OBJ / glTF / GLB / FBX avec vos textures.'),
        h('li', 'Vérifier — rapport erreurs / avertissements / informations.'),
        h('li', 'Exporter — ressource FiveM avec fxmanifest.lua, README et rapport.'),
        h('li', 'Installer — copier le dossier, ajouter « ensure » dans server.cfg.'))),
    ),
    h('div',
      h('div.box', h('h3', 'Projets récents'), recentBox),
      h('div.box', h('div.row.tight', h('h3', { style: { flex: 1, margin: 0 } }, 'État des outils'), btn('Détails', () => go('tools'), { kind: 'small ghost' })), toolsBox),
      h('div.box', h('h3', 'Dernières opérations'), eventsBox),
    ))));

  api.recentList().then((r) => {
    const list = (r.recent || []).filter((x) => x.exists);
    fill(recentBox, ...(list.length ? list.map((p) => h('li.clickable', { onclick: async () => {
      const o = await api.projectOpen(p.dir);
      if (!o.ok) return toast(o.error, 'error');
      loadProject(o);
    }, title: p.dir }, icon('folder'), h('span.grow', p.name, h('div.faint.small', fmtDate(p.openedAt))),
    h('button.icon-btn', { title: 'Retirer de la liste', type: 'button', onclick: async (e) => { e.stopPropagation(); await api.recentRemove(p.dir); go('home'); } }, icon('x', 14)))) : [h('li.muted', 'Aucun projet récent.')]));
  });
  api.toolsDetect().then((r) => {
    if (!r.ok) return fill(toolsBox, h('li.muted', r.error));
    fill(toolsBox, ...r.tools.map((t) => h('li', h(`span.dot.${t.status === 'found' ? 'ok' : t.status === 'error' ? 'err' : 'warn'}`),
      h('span.grow', t.name), h('span.faint.small', t.status === 'found' ? (t.version ? `v${t.version}` : 'trouvé') : 'absent'))));
  });
  api.appEvents().then((r) => {
    const ev = (r.events || []).filter((e) => e.level !== 'debug').slice(0, 12);
    fill(eventsBox, ...(ev.length ? ev.map((e) => h('li', h(`span.lvl.${e.level}`, e.level === 'error' ? 'erreur' : e.level === 'warn' ? 'alerte' : 'info'),
      h('span.grow', { style: { whiteSpace: 'normal' } }, e.message), h('span.faint', new Date(e.t).toLocaleTimeString('fr-FR')))) : [h('li.muted', 'Rien pour le moment.')]));
  });
}
