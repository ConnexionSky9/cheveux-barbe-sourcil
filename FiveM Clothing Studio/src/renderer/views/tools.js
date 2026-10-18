// Pages « Outils et dépendances », « Paramètres » et « Aide ».
import { h, fill, btn, toast, field, icon } from '../ui.js';
import { S, api, go } from '../app.js';
import { markdown } from './util.js';

export function renderTools(main) {
  const list = h('div', h('p.muted', 'Détection en cours…'));
  main.append(h('div.page', h('div.page-inner',
    h('h1', 'Outils et dépendances'),
    h('p.muted', 'Ces outils gratuits sont nécessaires pour certaines étapes que l\'application ne réalise pas elle-même (modèles GTA V, dictionnaires de textures .ytd, métadonnées .ymt). ',
      'Rien n\'est téléchargé ni installé automatiquement : suivez la procédure de chaque outil.'),
    h('div.row.tight', { style: { margin: '10px 0 16px' } }, btn('Relancer la détection', () => detect(), { icon: 'reset' }), btn('Chemins des outils (Paramètres)', () => go('settings'), { icon: 'gear' })),
    list,
    h('div.box', h('h3', 'Pris en charge sans outil externe'),
      h('ul.small', h('li', 'Lecture : PNG, JPEG, TGA (24/32 bits, RLE), DDS (DXT1, DXT3, DXT5, RGBA 8 bits).'),
        h('li', 'Écriture : PNG, JPEG, TGA 32 bits, DDS (DXT1, DXT5, BGRA 8 bits) avec mipmaps.'),
        h('li', 'Aperçu 3D : OBJ (+MTL), glTF, GLB ; FBX en prise en charge partielle.'),
        h('li', 'GTA V : contrôle d\'intégrité des .ydd, .ytd, .ymt (en-tête RSC7 + décompression), nommage, export en ressource FiveM.'),
        h('li', 'Non pris en charge : création / édition du contenu des .ydd, .ytd et .ymt (voir Aide › Formats).'))))));
  async function detect() {
    fill(list, h('p.muted', 'Détection en cours…'));
    const r = await api.toolsDetect();
    if (!r.ok) return fill(list, h('p', r.error));
    fill(list, ...r.tools.map((t) => h('div.box.tool-card',
      h('div', h('h2', h(`span.dot.${t.status === 'found' ? 'ok' : t.status === 'error' ? 'err' : 'warn'}`, { style: { display: 'inline-block', marginRight: '8px' } }), t.name),
        h('p', t.role), h('p.small.muted', 'Utilisé pour : ', t.usedFor.join(' · ')),
        h('p.small', h('b', t.status === 'found' ? 'Trouvé' : t.status === 'error' ? 'Problème' : 'Absent'), t.version ? ` · version ${t.version}` : '', t.path ? ` · ${t.path}` : '', t.message ? ` · ${t.message}` : ''),
        t.status !== 'found' ? h('ol.small', t.install.map((x) => h('li', x))) : null),
      h('div', btn('Documentation officielle', () => api.shellOpenExternal(t.docs), { icon: 'help', kind: 'small' })))));
  }
  detect();
}

export function renderSettings(main) {
  const cfg = JSON.parse(JSON.stringify(S.info.config));
  const num = (obj, key, label, help, min, max) => field(label, h('input.input', { type: 'number', min, max, value: obj[key], onchange: (e) => { obj[key] = Number(e.target.value); } }), help);
  const txt = (obj, key, label, help, pickDir) => field(label, h('div.row', h('input.input', { value: obj[key] || '', placeholder: 'Détection automatique', onchange: (e) => { obj[key] = e.target.value.trim(); } }),
    btn('Parcourir…', async () => {
      const r = pickDir ? await api.dialogPickDir(label) : await api.dialogPickFiles({ multi: false, title: label, filters: [{ name: 'Programme', extensions: ['exe', '*'] }] });
      const p = pickDir ? r.path : r.paths?.[0];
      if (p) { obj[key] = p; main.replaceChildren(); renderSettingsWith(main, cfg); }
    }, { kind: 'small' })), help);
  renderSettingsWith(main, cfg);
  function renderSettingsWith(el, c) {
    el.append(h('div.page', h('div.page-inner',
      h('h1', 'Paramètres'),
      h('div.box', h('h3', 'Général'),
        field('Nom de l\'application', h('input.input', { value: c.appName, onchange: (e) => { c.appName = e.target.value || 'FiveM Clothing Studio'; } }), 'Nom affiché dans la fenêtre (le nom du produit peut être changé ici).'),
        num(c, 'autosaveSeconds', 'Sauvegarde automatique (secondes)', 'Minimum 15 s. Utilisée pour récupérer le travail après une fermeture anormale.', 15, 3600),
        num(c, 'undoSteps', 'Nombre d\'étapes d\'annulation (textures)', 'Plus de mémoire utilisée sur les grandes textures.', 5, 200)),
      h('div.box', h('h3', 'Outils externes'),
        txt(c.tools, 'blender', 'Chemin de blender.exe', 'Laissez vide pour la détection automatique.'),
        txt(c.tools, 'codewalker', 'Chemin de CodeWalker.exe', 'CodeWalker est portable : indiquez où vous l\'avez décompressé.'),
        txt(c.tools, 'sollumzAddonDir', 'Dossier de l\'extension Sollumz', 'Facultatif : détection automatique dans les dossiers de Blender.', true)),
      h('div.box', h('h3', 'Limites'),
        num(c.limits, 'warnTextureSize', 'Avertir au-delà de (px)', '', 256, 8192), num(c.limits, 'maxTextureSize', 'Taille de texture maximale conseillée (px)', '', 256, 8192),
        num(c.limits, 'maxImportBytes', 'Taille maximale d\'un fichier importé (octets)', '268435456 = 256 Mo', 1048576, 2147483647)),
      h('div.row.tight', btn('Enregistrer les paramètres', async () => {
        const r = await api.configSet(c);
        if (!r.ok) return toast(r.error, 'error');
        S.info.config = r.config; S.info.appName = r.config.appName; toast('Paramètres enregistrés.', 'success'); go('settings');
      }, { kind: 'primary', icon: 'save' }), btn('Ouvrir le fichier de configuration', () => api.configOpenFile(), { icon: 'file' }),
      btn('Ouvrir le dossier des journaux', () => api.shellOpenPath(S.info.logsDir), { icon: 'folder' })),
      h('p.help', { style: { marginTop: '10px' } }, `Fichier : ${S.info.configFile}`))));
  }
}

const DOCS = [
  { file: 'GUIDE_UTILISATEUR.md', label: 'Guide utilisateur' },
  { file: 'INSTALLATION_FIVEM.md', label: 'Installer sur FiveM' },
  { file: 'FORMATS.md', label: 'Formats et limites' },
  { file: 'GUIDE_DEVELOPPEUR.md', label: 'Guide développeur' },
  { file: 'RAPPORT_TESTS.md', label: 'Tests réalisés' },
];
export function renderHelp(main) {
  const content = h('div.doc');
  const nav = h('div.help-nav', DOCS.map((d) => btn(d.label, () => show(d.file), { kind: 'small', dataset: {} })));
  nav.querySelectorAll('button').forEach((b, i) => { b.dataset.doc = DOCS[i].file; });
  main.append(h('div.page', h('div.page-inner', nav, content)));
  async function show(file) {
    nav.querySelectorAll('button').forEach((b) => b.classList.toggle('active', b.dataset.doc === file));
    const r = await api.docsRead(file);
    content.innerHTML = r.ok ? markdown(r.text) : `<p>${r.error}</p>`;
    content.querySelectorAll('a[href^="https://"]').forEach((a) => a.addEventListener('click', (e) => { e.preventDefault(); api.shellOpenExternal(a.href); }));
    main.querySelector('.page').scrollTop = 0;
  }
  show(DOCS[0].file);
}
