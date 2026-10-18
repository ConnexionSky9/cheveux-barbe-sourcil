// Exportateur de ressource FiveM.
// Garanties :
//  - tout est construit dans un dossier temporaire à côté de la destination ;
//  - la ressource finale n'apparaît (ou n'est remplacée) qu'à la toute fin, d'un bloc ;
//  - en cas d'erreur ou d'annulation, la destination reste dans son état d'origine ;
//  - aucun export n'est annoncé « prêt » s'il reste une étape externe.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { validateExport } from './validate.js';
import { generateManifest, checkManifest } from './manifest.js';
import { safeJoin, isInside, toPosix } from '../paths.js';
import { loadTextureDoc } from '../project/textures.js';
import { encodeImage } from '../image/codecs.js';
import { resize } from '../image/ops.js';
import { isPowerOfTwo } from '../image/rgba.js';

export class ExportCancelled extends Error {
  constructor() { super('Export annulé.'); this.name = 'ExportCancelled'; this.code = 'E_CANCELLED'; }
}
export class ExportError extends Error {
  constructor(msg, details = [], extra = {}) { super(msg); this.name = 'ExportError'; this.code = 'E_EXPORT'; this.details = details; Object.assign(this, extra); }
}

export const STATUS_LABEL = {
  ready: 'Prêt à installer (contrôles automatiques réussis — non testé en jeu)',
  incomplete: 'Incomplet : conversion externe requise avant installation',
  blocked: 'Bloqué : erreurs à corriger',
};

const sha = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

/**
 * @param {object} o
 *  dir, project, settings (exportSettings), destination (dossier parent),
 *  overwrite (bool, après confirmation), allowIncomplete (bool),
 *  onProgress(step, ratio), signal ({ cancelled }), config, appVersion
 */
export async function exportResource(o) {
  const { dir, project, destination, overwrite = false, allowIncomplete = false, onProgress = () => {}, signal = {}, config = {}, appVersion = '0.0.0' } = o;
  const settings = o.settings || project.exportSettings;
  const checkCancel = () => { if (signal.cancelled) throw new ExportCancelled(); };
  const tick = async (step, ratio) => { onProgress(step, ratio); checkCancel(); await new Promise((r) => setImmediate(r)); };

  await tick('Validation du projet', 0.02);
  const v = validateExport(dir, project, settings, { limits: config.limits });
  if (v.status === 'blocked') throw new ExportError('Export impossible : corrigez les erreurs bloquantes.', v.issues);
  if (v.status === 'incomplete' && !allowIncomplete) throw new ExportError('Le pack est incomplet : confirmez l\'export partiel.', v.issues);

  if (!destination || !fs.existsSync(destination) || !fs.statSync(destination).isDirectory()) {
    throw new ExportError('Dossier de destination introuvable.');
  }
  const name = v.plan.resourceName;
  const finalDir = path.join(destination, name);
  const convertDir = path.join(destination, `${name}_a_convertir`);
  if (!isInside(destination, finalDir)) throw new ExportError('Destination invalide.');
  if (fs.existsSync(finalDir) && !overwrite) throw new ExportError(`Le dossier « ${name} » existe déjà dans la destination. Confirmez le remplacement.`, [], { exists: true });

  const tmpRoot = path.join(destination, `.${name}.export-${process.pid}-${Date.now()}`);
  const tmpRes = path.join(tmpRoot, name);
  const tmpConv = path.join(tmpRoot, 'a_convertir');
  const t0 = Date.now();
  try {
    fs.mkdirSync(path.join(tmpRes, 'stream'), { recursive: true });

    // 1. Fichiers du jeu (copie binaire exacte)
    const files = [];
    const total = v.plan.stream.length + v.plan.dataFiles.length + v.plan.pending.length;
    let done = 0;
    for (const s of v.plan.stream) {
      const to = safeJoin(tmpRes, s.to);
      fs.copyFileSync(s.from, to, fs.constants.COPYFILE_EXCL);
      files.push({ path: s.to, role: s.role, bytes: fs.statSync(to).size, sha256: sha(to), source: path.basename(s.from) });
      await tick(`Copie de ${path.basename(s.to)}`, 0.05 + 0.6 * (++done / Math.max(1, total)));
    }
    // 2. Métadonnées (collections additionnelles)
    for (const d of v.plan.dataFiles) {
      const to = safeJoin(tmpRes, d.path);
      fs.mkdirSync(path.dirname(to), { recursive: true });
      fs.copyFileSync(d.from, to, fs.constants.COPYFILE_EXCL);
      files.push({ path: d.path, role: 'shopmeta', bytes: fs.statSync(to).size, sha256: sha(to) });
      await tick(`Métadonnées ${path.basename(d.path)}`, 0.05 + 0.6 * (++done / Math.max(1, total)));
    }
    // 3. Textures de travail à convertir en .ytd (hors ressource)
    const conversions = [];
    for (const p of v.plan.pending) {
      const meta = project.textureDocs.find((t) => t.id === p.textureDocId);
      let img = loadTextureDoc(dir, meta).composite();
      const notes = [];
      if (!isPowerOfTwo(img.width) || !isPowerOfTwo(img.height)) {
        const pw = 2 ** Math.round(Math.log2(img.width)), ph = 2 ** Math.round(Math.log2(img.height));
        img = resize(img, Math.min(4096, pw), Math.min(4096, ph));
        notes.push(`Redimensionnée en ${img.width} × ${img.height} (puissances de 2).`);
      }
      const format = img.hasAlpha() ? 'dxt5' : 'dxt1';
      const out = encodeImage(img, { format: 'dds', dds: { format, mipmaps: true } });
      fs.mkdirSync(tmpConv, { recursive: true });
      const ddsName = `${p.textureName}.dds`;
      fs.writeFileSync(path.join(tmpConv, ddsName), out.buffer);
      conversions.push({ dds: ddsName, ytd: p.ytdName, textureName: p.textureName, format: format.toUpperCase(), width: img.width, height: img.height, notes });
      await tick(`Texture ${ddsName}`, 0.05 + 0.6 * (++done / Math.max(1, total)));
    }

    // 4. Manifeste
    const manifest = generateManifest({ fxVersion: config.fivem?.fxVersion || 'cerulean', game: config.fivem?.game || 'gta5',
      name, description: settings.packName, dataFiles: v.plan.dataFiles.map((d) => ({ path: d.path, type: d.type })) });
    fs.writeFileSync(path.join(tmpRes, 'fxmanifest.lua'), manifest, 'utf8');
    await tick('Manifeste', 0.7);

    // 5. Vérification de la structure produite
    const present = new Set(listFiles(tmpRes).map((f) => toPosix(path.relative(tmpRes, f))));
    const problems = checkManifest(manifest, present);
    for (const f of files) {
      if (!present.has(f.path)) problems.push(`Fichier manquant après copie : ${f.path}`);
      const src = v.plan.stream.find((s) => s.to === f.path) || v.plan.dataFiles.find((d) => d.path === f.path);
      if (src && sha(src.from) !== f.sha256) problems.push(`Copie altérée : ${f.path}`);
    }
    if (problems.length) throw new ExportError('La ressource générée ne passe pas les contrôles.', problems.map((m) => ({ level: 'error', message: m })));
    await tick('Contrôles', 0.8);

    // 6. Documentation + rapport
    const status = v.status;
    const report = {
      tool: 'FiveM Clothing Studio', appVersion, generatedAt: new Date().toISOString(), durationMs: Date.now() - t0,
      resourceName: name, packName: settings.packName, mode: v.plan.mode, status, statusLabel: STATUS_LABEL[status],
      testedInGame: false,
      files, conversionsRequired: conversions,
      checks: { manifest: 'ok', copiesIdentical: true, structure: 'ok' },
      issues: v.issues,
    };
    fs.writeFileSync(path.join(tmpRes, 'README.txt'), installReadme(report), 'utf8');
    if (conversions.length) fs.writeFileSync(path.join(tmpConv, 'A_LIRE.txt'), conversionReadme(report), 'utf8');
    fs.writeFileSync(path.join(tmpRes, 'export_report.json'), JSON.stringify(report, null, 2), 'utf8');
    await tick('Rapport', 0.88);

    // 7. Mise en place atomique (remplacement d'un export précédent confirmé)
    checkCancel();
    const backups = [];
    try {
      for (const [from, to] of [[tmpRes, finalDir], ...(conversions.length ? [[tmpConv, convertDir]] : [])]) {
        if (fs.existsSync(to)) { const b = `${to}.old-${Date.now()}`; fs.renameSync(to, b); backups.push([b, to]); }
        fs.renameSync(from, to);
      }
    } catch (e) {
      for (const [b, to] of backups) { fs.rmSync(to, { recursive: true, force: true }); fs.renameSync(b, to); }
      throw new ExportError(`Impossible de placer la ressource dans la destination : ${e.message}`);
    }
    for (const [b] of backups) fs.rmSync(b, { recursive: true, force: true });
    onProgress('Terminé', 1);
    return { ...report, path: finalDir, convertPath: conversions.length ? convertDir : null, fileCount: listFiles(finalDir).length };
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
}

function listFiles(root) {
  const out = [];
  for (const e of fs.readdirSync(root, { withFileTypes: true })) {
    const p = path.join(root, e.name);
    if (e.isDirectory()) out.push(...listFiles(p)); else out.push(p);
  }
  return out;
}

export function installReadme(r) {
  const lines = [
    `${r.packName} — ressource FiveM « ${r.resourceName} »`,
    `Générée le ${new Date(r.generatedAt).toLocaleString('fr-FR')} par FiveM Clothing Studio ${r.appVersion}.`,
    '',
    `ÉTAT : ${r.statusLabel}`,
    '',
  ];
  if (r.conversionsRequired.length) {
    lines.push('AVANT D\'INSTALLER : des textures doivent encore être converties en .ytd.',
      `Suivez « ${r.resourceName}_a_convertir/A_LIRE.txt ». Sans cette étape, ces variantes ne sont pas dans la ressource.`, '');
  }
  lines.push(
    'INSTALLATION SUR VOTRE SERVEUR',
    `1. Copiez le dossier « ${r.resourceName} » dans le dossier « resources » de votre serveur`,
    '   (par exemple resources/[vetements]/' + r.resourceName + ').',
    `2. Le nom du dossier doit rester exactement « ${r.resourceName} ».`,
    '3. Ajoutez cette ligne dans server.cfg (après vos autres ressources) :',
    `      ensure ${r.resourceName}`,
    `4. Redémarrez le serveur (ou tapez « refresh » puis « ensure ${r.resourceName} » dans la console).`,
    '5. Vérifiez la console : aucune erreur ne doit mentionner cette ressource.',
    '6. En jeu, testez le vêtement avec le système de vêtements de votre serveur.',
    '',
  );
  if (r.mode === 'replace') {
    lines.push('MODE : remplacement de vêtements du jeu.',
      'Les numéros de vêtements remplacés sont visibles dans export_report.json.',
      'Tous les joueurs qui portent ces vêtements verront la nouvelle version.', '');
  } else {
    lines.push('MODE : collection additionnelle.',
      'Les nouveaux vêtements s\'ajoutent APRÈS ceux du jeu : leur numéro réel en jeu dépend des autres collections installées.',
      'Les boutiques ou menus de vêtements doivent proposer ces nouveaux numéros (selon votre script).', '');
  }
  lines.push('Fichiers :', ...r.files.map((f) => `  ${f.path}  (${(f.bytes / 1024).toFixed(0)} Ko)`), '',
    'Important : cette ressource a passé les contrôles automatiques de l\'application, mais elle n\'a pas été testée en jeu.');
  return lines.join('\r\n');
}

function conversionReadme(r) {
  return [
    'TEXTURES À CONVERTIR EN .YTD',
    '',
    'L\'application exporte vos textures en DDS (avec mipmaps), le format attendu dans un dictionnaire',
    'de textures GTA V, mais elle ne sait pas encore fabriquer le fichier .ytd lui-même.',
    '',
    'Pour chaque ligne ci-dessous :',
    '1. Ouvrez CodeWalker (https://github.com/dexyfex/CodeWalker) > Tools > RPF Explorer ou l\'éditeur YTD,',
    '   ou tout outil capable de créer / modifier un .ytd.',
    '2. Créez (ou ouvrez) le .ytd indiqué et ajoutez la texture DDS en la nommant comme indiqué.',
    `3. Placez le .ytd dans « ${r.resourceName}/stream/ », ou importez-le dans le projet et ré-exportez.`,
    '',
    ...r.conversionsRequired.map((c) => `- ${c.dds}  →  ${c.ytd}  (texture « ${c.textureName} », ${c.format}, ${c.width}×${c.height})${c.notes.length ? ' — ' + c.notes.join(' ') : ''}`),
    '',
    'Le nom de texture indiqué suit la convention des vêtements du jeu ; vérifiez-le dans l\'outil si votre modèle',
    'utilise un autre nom.',
  ].join('\r\n');
}
