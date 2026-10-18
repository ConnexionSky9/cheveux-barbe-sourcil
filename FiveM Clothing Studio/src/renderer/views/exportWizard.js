// Assistant « Exporter pour FiveM » : configuration → validation → génération → résultat.
import { h, fill, modal, toast, field, select, issueList, btn, fmtBytes } from '../ui.js';
import { S, api, commit, adopt, saveProject, status } from '../app.js';
import { toResourceNameClient } from './util.js';

const MODES = [
  { value: 'replace', label: 'Remplacer des vêtements du jeu', help: 'Vos .ydd / .ytd remplacent des vêtements existants (même slot, même numéro). Aucune métadonnée à fournir.' },
  { value: 'addon', label: 'Collection additionnelle (nouveaux vêtements)', help: 'Ajoute des vêtements sans rien remplacer. Il faut, pour chaque personnage, le .ymt et le .meta de la collection (produits par un outil spécialisé, voir Aide).' },
];

export async function openExportWizard() {
  if (!S.project) return toast('Ouvrez d\'abord un projet.');
  if (!(await saveProject({ quiet: true }))) return;
  const P = S.project;
  const es = P.exportSettings;
  const st = {
    step: 1,
    packName: es.packName || P.name,
    resourceName: es.resourceName || toResourceNameClient(es.packName || P.name),
    autoName: !es.resourceName,
    destination: es.destination || '',
    mode: es.mode || 'replace',
    collections: JSON.parse(JSON.stringify(es.collections || {})),
    validation: null, result: null, running: false,
  };
  const body = h('div');
  const steps = ['Configuration', 'Vérification', 'Génération', 'Résultat'];
  let m;

  const settings = () => ({ packName: st.packName.trim(), resourceName: st.resourceName, mode: st.mode, destination: st.destination, collections: st.collections });
  const persist = () => commit('Paramètres d\'export', (p) => { p.exportSettings = { ...p.exportSettings, ...settings() }; }, { render: false });

  function draw() {
    const head = h('div.steps', steps.map((s, i) => h(`span${i + 1 === st.step ? '.on' : ''}`, `${i + 1}. ${s}`)));
    fill(body, head, [null, step1, step2, step3, step4][st.step]());
    m?.footer.replaceChildren(...footer());
  }

  function step1() {
    const usedPeds = [...new Set(P.garments.map((g) => g.ped))];
    const gta = (ext) => P.assets.filter((a) => a.name.toLowerCase().endsWith(`.${ext}`));
    const destLabel = h('div.input', { style: { cursor: 'pointer' }, onclick: async () => { const r = await api.dialogPickDir('Dossier de destination'); if (r.path) { st.destination = r.path; draw(); } } }, st.destination || 'Choisir le dossier…');
    const resInput = h('input.input#exp-resource', { value: st.resourceName, oninput: (e) => { st.resourceName = e.target.value; st.autoName = false; hint.textContent = check(st.resourceName); } });
    const hint = h('small.help', check(st.resourceName));
    return h('div.form',
      field('Nom du pack', h('input.input#exp-pack', { value: st.packName, oninput: (e) => {
        st.packName = e.target.value;
        if (st.autoName) { st.resourceName = toResourceNameClient(st.packName); resInput.value = st.resourceName; hint.textContent = check(st.resourceName); }
      } })),
      h('label.field', h('span', 'Nom technique de la ressource'), resInput, hint),
      field('Dossier de destination', destLabel, 'La ressource sera créée dans un sous-dossier portant son nom technique (par exemple le dossier « resources » d\'une copie de votre serveur).'),
      field('Mode d\'installation', select(MODES, st.mode, (v) => { st.mode = v; draw(); }), MODES.find((x) => x.value === st.mode).help),
      st.mode === 'addon' ? h('div.box', h('h3', 'Métadonnées des collections'), usedPeds.length ? usedPeds.map((ped) => {
        st.collections[ped] = st.collections[ped] || {};
        return h('div', h('b', ped),
          h('div.row', field('Fichier .ymt', select([{ value: '', label: '— Choisir —' }, ...gta('ymt').map((a) => ({ value: a.id, label: a.name }))], st.collections[ped].ymtAssetId || '', (v) => { st.collections[ped].ymtAssetId = v || null; })),
            field('Fichier .meta (ShopPedApparel)', select([{ value: '', label: '— Choisir —' }, ...gta('meta').map((a) => ({ value: a.id, label: a.name }))], st.collections[ped].metaAssetId || '', (v) => { st.collections[ped].metaAssetId = v || null; }))));
      }) : h('p.muted', 'Aucun vêtement dans le projet.'), h('p.help', 'Importez d\'abord ces fichiers (Importer). Leur nom fixe le nom de la collection : mp_m_freemode_01_<collection>.ymt.')) : null,
      h('p.help', `Personnages concernés : ${usedPeds.join(', ') || 'aucun'} · ${P.garments.length} vêtement(s).`));
  }
  function check(n) {
    return /^[a-z0-9][a-z0-9_-]{1,47}$/.test(n) ? `Ligne server.cfg : ensure ${n}` : 'Lettres minuscules, chiffres, « _ » ou « - » uniquement (2 à 48 caractères).';
  }

  function step2() {
    const v = st.validation;
    if (!v) return h('p.muted', 'Vérification…');
    const n = (lvl) => v.issues.filter((i) => i.level === lvl).length;
    const label = { ready: ['result-ok', 'Tout est prêt pour la génération.'], incomplete: ['result-warn', 'Export possible, mais le pack sera INCOMPLET : des textures doivent encore être converties en .ytd avec un outil externe.'], blocked: ['', 'Export impossible : corrigez les erreurs bloquantes.'] }[v.status];
    return h('div',
      h('p', h(`b.${label[0]}`, label[1])),
      h('div.status-badges', h('span.pill.err', `${n('error')} erreur(s) bloquante(s)`), h('span.pill.warn', `${n('warning')} avertissement(s)`), h('span.pill', `${n('info')} information(s)`),
        h('span.pill.ok', `${v.plan.stream.length} fichier(s) à diffuser`)),
      issueList(v.issues),
      v.plan.stream.length ? h('details', { style: { marginTop: '10px' } }, h('summary.muted', 'Fichiers qui seront produits'),
        h('ul.list.small', v.plan.stream.map((s) => h('li.mono', s.to)), v.plan.dataFiles.map((d) => h('li.mono', d.path)), h('li.mono', 'fxmanifest.lua'), h('li.mono', 'README.txt'), h('li.mono', 'export_report.json'))) : null);
  }

  const prog = { step: '', ratio: 0 };
  let off = null;
  function step3() {
    return h('div', h('p', prog.step || 'Préparation…'), h('div.big-progress', h('i', { style: { width: `${Math.round(prog.ratio * 100)}%` } })),
      h('p.help', 'La ressource est construite dans un dossier temporaire et n\'apparaît dans la destination qu\'une fois terminée et vérifiée. Annuler ne laisse aucun fichier partiel.'));
  }

  function step4() {
    const r = st.result;
    if (!r) return h('p', 'Aucun résultat.');
    return h('div',
      h('h2', { class: r.status === 'ready' ? 'result-ok' : 'result-warn' }, r.statusLabel),
      h('dl.kv', h('dt', 'Ressource'), h('dd.mono', r.path), h('dt', 'Fichiers'), h('dd', `${r.fileCount} (dont ${r.files.length} de vêtements / métadonnées)`),
        h('dt', 'Mode'), h('dd', MODES.find((x) => x.value === r.mode)?.label), h('dt', 'Taille'), h('dd', fmtBytes(r.files.reduce((s, f) => s + f.bytes, 0))),
        h('dt', 'Ligne server.cfg'), h('dd.mono', `ensure ${r.resourceName}`)),
      h('h3', { style: { marginTop: '14px' } }, 'Contrôles réussis'),
      h('ul.small', h('li', 'Structure de la ressource et chemins relatifs'), h('li', 'fxmanifest.lua (syntaxe et fichiers déclarés)'), h('li', 'Copies identiques aux fichiers du projet (empreintes SHA-256)'), h('li', 'Intégrité des fichiers GTA V (en-tête RSC7 et décompression)')),
      h('h3', 'Reste à faire'),
      h('ul.small', r.conversionsRequired.length ? h('li', h('b', `${r.conversionsRequired.length} texture(s) à intégrer dans un .ytd`), ` : voir ${r.convertPath}`) : null,
        h('li', 'Installer la ressource sur le serveur (README.txt)'), h('li', 'Tester le vêtement en jeu : ce test n\'est pas réalisé par l\'application.')),
      r.issues.some((i) => i.level === 'warning') ? h('details', h('summary.muted', 'Avertissements'), issueList(r.issues.filter((i) => i.level === 'warning'))) : null,
      h('div.row', { style: { marginTop: '14px', flexWrap: 'wrap' } },
        btn('Ouvrir le dossier', () => api.shellOpenPath(r.path), { icon: 'folder', kind: 'primary' }),
        btn('Instructions d\'installation (README)', () => api.shellOpenPath(`${r.path}${S.info.platform === 'win32' ? '\\' : '/'}README.txt`), { icon: 'file' }),
        r.convertPath ? btn('Textures à convertir', () => api.shellOpenPath(r.convertPath), { icon: 'image' }) : null,
        btn('Guide d\'installation FiveM', async () => { m.close(); (await import('../app.js')).go('help'); setTimeout(() => document.querySelector('[data-doc="INSTALLATION_FIVEM.md"]')?.click(), 50); })));
  }

  function footer() {
    const b = (label, onclick, opt) => btn(label, onclick, opt);
    if (st.step === 1) return [b('Annuler', () => m.close()), b('Vérifier', async () => {
      if (!st.packName.trim()) return toast('Donnez un nom au pack.', 'error');
      if (!st.destination) return toast('Choisissez le dossier de destination.', 'error');
      persist();
      st.step = 2; st.validation = null; draw();
      const r = await api.exportValidate({ project: S.project, settings: settings() });
      if (!r.ok) { toast(r.error, 'error'); st.step = 1; return draw(); }
      st.validation = r; draw();
    }, { kind: 'primary', id: 'exp-validate' })];
    if (st.step === 2) return [b('Retour', () => { st.step = 1; draw(); }), b('Revérifier', async () => { st.validation = await api.exportValidate({ project: S.project, settings: settings() }); draw(); }),
      b(st.validation?.status === 'incomplete' ? 'Générer (incomplet)' : 'Générer la ressource', () => run(false), { kind: 'primary', disabled: !st.validation || st.validation.status === 'blocked', id: 'exp-run' })];
    if (st.step === 3) return [b('Annuler l\'export', async () => { await api.exportCancel(); }, { kind: 'danger' })];
    return [b('Fermer', () => m.close(), { kind: 'primary' })];
  }

  async function run(overwrite) {
    st.step = 3; prog.step = ''; prog.ratio = 0; draw();
    off?.(); off = api.on('export:progress', (p) => { Object.assign(prog, p); if (st.step === 3) draw(); status(`Export : ${p.step}`); });
    const r = await api.exportRun({ project: S.project, settings: settings(), destination: st.destination, overwrite, allowIncomplete: st.validation.status === 'incomplete' });
    off?.(); off = null; status('Prêt.');
    if (!r.ok) {
      if (r.exists && !overwrite) {
        const ok = await (await import('../ui.js')).confirmBox('Remplacer la ressource existante ?',
          `Le dossier « ${st.resourceName} » existe déjà dans la destination. Le remplacer par ce nouvel export ? L'ancien dossier sera supprimé seulement si le nouvel export réussit.`, { ok: 'Remplacer', danger: true });
        if (ok) return run(true);
        st.step = 2; return draw();
      }
      if (r.code === 'E_CANCELLED') { toast('Export annulé : aucun fichier n\'a été laissé dans la destination.', 'info'); st.step = 2; return draw(); }
      toast(r.error, 'error', 8000);
      st.step = 2;
      if (r.details?.length) st.validation = { ...st.validation, issues: r.details.map((d) => (typeof d === 'string' ? { level: 'error', message: d } : d)) };
      return draw();
    }
    adopt(r.project);
    await saveProject({ quiet: true });
    st.result = r.result; st.step = 4; draw();
    toast(r.result.status === 'ready' ? 'Ressource générée.' : 'Ressource générée (incomplète).', r.result.status === 'ready' ? 'success' : 'warning');
  }

  m = modal({ title: 'Exporter pour FiveM', wide: true, body, actions: [{ label: '…' }], closable: true, onClose: () => { off?.(); } });
  draw();
}
