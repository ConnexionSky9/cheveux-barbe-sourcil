// Validation d'un projet avant export, et calcul du PLAN d'export (fichiers à produire).
// Trois niveaux : 'error' (bloquant), 'warning', 'info'.
import fs from 'node:fs';
import path from 'node:path';
import { safeJoin, isValidResourceName } from '../paths.js';
import { inspectRsc7 } from '../gta/rsc7.js';
import { garmentFileNames, slotInfo, PED_MODELS, VARIANT_LETTERS, isValidCollection } from '../gta/naming.js';
import { sniff } from '../detect.js';

export const EXPORT_MODES = {
  replace: {
    label: 'Remplacer des vêtements du jeu',
    help: 'Vos fichiers .ydd / .ytd remplacent des vêtements existants (même slot, même numéro). Aucune métadonnée requise.',
  },
  addon: {
    label: 'Collection additionnelle (nouveaux vêtements)',
    help: 'Ajoute des vêtements sans remplacer ceux du jeu. Nécessite, pour chaque personnage, le .ymt et le fichier .meta de la collection, produits par un outil spécialisé.',
  },
};

/**
 * @returns {{ status: 'blocked'|'incomplete'|'ready', issues: object[], plan: object }}
 *  ready      : tous les contrôles automatiques sont réussis (≠ testé en jeu) ;
 *  incomplete : export possible mais des textures attendent une conversion externe en .ytd ;
 *  blocked    : au moins une erreur bloquante.
 */
export function validateExport(dir, project, settings = project.exportSettings, { limits = {} } = {}) {
  const issues = [];
  const add = (level, message, ref) => issues.push({ level, message, ...(ref ? { ref } : {}) });
  const mode = settings.mode === 'addon' ? 'addon' : 'replace';
  const plan = { mode, resourceName: settings.resourceName, packName: settings.packName, stream: [], dataFiles: [], pending: [] };
  const warnBytes = limits.streamAssetWarnBytes ?? 16 * 1024 * 1024;

  if (!String(settings.packName || '').trim()) add('error', 'Donnez un nom au pack.');
  if (!isValidResourceName(settings.resourceName)) {
    add('error', 'Nom technique de ressource invalide : lettres minuscules, chiffres, « _ » ou « - » (2 à 48 caractères, sans espace ni accent).');
  }
  if (!project.garments.length) add('error', 'Le projet ne contient aucun vêtement.');

  const assetById = new Map(project.assets.map((a) => [a.id, a]));
  const checkedAssets = new Map();
  /** Vérifie qu'un fichier GTA du projet existe, a le bon rôle et est intègre. */
  const gtaAsset = (id, role, label) => {
    const a = assetById.get(id);
    if (!a) { add('error', `${label} : fichier .${role} non associé.`); return null; }
    if (checkedAssets.has(id)) return checkedAssets.get(id);
    let file;
    try { file = safeJoin(dir, a.file); } catch { add('error', `${label} : chemin de fichier invalide.`); return null; }
    if (!fs.existsSync(file)) { add('error', `${label} : fichier manquant « ${a.name} ».`); checkedAssets.set(id, null); return null; }
    const ext = path.extname(a.name).slice(1).toLowerCase();
    if (ext !== role) { add('error', `${label} : « ${a.name} » n'est pas un fichier .${role}.`); checkedAssets.set(id, null); return null; }
    const buf = fs.readFileSync(file);
    if (role === 'ymt' && sniff(buf, 'ymt').format === 'pso') {
      // PSO : non vérifiable plus finement
    } else {
      const r = inspectRsc7(buf, { ext });
      for (const i of r.issues) add(i.level, `${label} (${a.name}) : ${i.message}`);
      if (!r.ok) { checkedAssets.set(id, null); return null; }
    }
    if (buf.length > warnBytes) add('warning', `${label} : ${a.name} pèse ${(buf.length / 1048576).toFixed(1)} Mo. Au-delà de 16 Mo, FiveM signale un fichier trop lourd et le chargement peut échouer chez certains joueurs.`);
    const out = { asset: a, file };
    checkedAssets.set(id, out);
    return out;
  };

  // Collections additionnelles : préfixe déduit du .ymt fourni (jamais inventé)
  const prefixes = {};
  if (mode === 'addon') {
    const usedPeds = [...new Set(project.garments.map((g) => g.ped))];
    for (const ped of usedPeds) {
      const col = settings.collections?.[ped] || {};
      const label = `Collection ${ped}`;
      const ymt = gtaAsset(col.ymtAssetId, 'ymt', `${label} – métadonnées (.ymt)`);
      const metaAsset = assetById.get(col.metaAssetId);
      if (!metaAsset) add('error', `${label} : fichier .meta (ShopPedApparel) non associé.`);
      if (ymt) {
        const prefix = path.basename(ymt.asset.name, path.extname(ymt.asset.name)).toLowerCase();
        if (!prefix.startsWith(`${ped}_`) || !isValidCollection(prefix.slice(ped.length + 1))) {
          add('error', `${label} : le .ymt doit s'appeler « ${ped}_<collection>.ymt » (reçu : ${ymt.asset.name}).`);
        } else {
          prefixes[ped] = prefix;
          plan.stream.push({ from: ymt.file, to: `stream/${prefix}.ymt`, role: 'ymt' });
        }
      }
      if (metaAsset) {
        let txt = '';
        try { txt = fs.readFileSync(safeJoin(dir, metaAsset.file), 'utf8'); } catch { add('error', `${label} : fichier .meta manquant.`); }
        if (txt && !/<ShopPedApparel[\s>]/.test(txt)) add('error', `${label} : « ${metaAsset.name} » n'est pas un fichier ShopPedApparel.`);
        const pedName = /<pedName>\s*([^<\s]+)\s*<\/pedName>/.exec(txt)?.[1];
        if (txt && pedName !== ped) add('error', `${label} : le .meta est prévu pour « ${pedName ?? '?'} », pas pour ${ped}.`);
        if (prefixes[ped] && txt) {
          const metaName = `data/${prefixes[ped]}.meta`;
          plan.dataFiles.push({ from: safeJoin(dir, metaAsset.file), path: metaName, type: 'SHOP_PED_APPAREL_META_FILE' });
          const dlc = /<dlcName>\s*([^<\s]+)\s*<\/dlcName>/.exec(txt)?.[1];
          if (dlc && !prefixes[ped].includes(dlc)) add('warning', `${label} : le nom de collection du .meta (« ${dlc} ») ne correspond pas au .ymt (« ${prefixes[ped]} »). Vérifiez qu'ils viennent du même export.`);
        }
      }
    }
  }

  // Vêtements
  const seenSlots = new Map();
  const outputs = new Map();
  for (const g of project.garments) {
    const label = `« ${g.name} »`;
    if (!PED_MODELS.includes(g.ped)) { add('error', `${label} : personnage cible non choisi.`, g.id); continue; }
    if (!project.targetPeds.includes(g.ped)) add('warning', `${label} : personnage ${g.ped} absent des cibles du projet.`, g.id);
    if (!slotInfo(g.kind, g.slot)) { add('error', `${label} : slot GTA V non choisi (composant ou accessoire).`, g.id); continue; }
    if (!Number.isInteger(g.drawableIndex) || g.drawableIndex < 0 || g.drawableIndex > 999) { add('error', `${label} : numéro de modèle (0 à 999) non défini.`, g.id); continue; }
    const key = `${g.ped}|${g.kind}|${g.slot}|${g.drawableIndex}`;
    if (seenSlots.has(key)) { add('error', `${label} et « ${seenSlots.get(key)} » utilisent le même emplacement (${g.slot} n° ${g.drawableIndex}).`, g.id); continue; }
    seenSlots.set(key, g.name);
    const prefix = mode === 'addon' ? prefixes[g.ped] : g.ped;
    if (!prefix) continue; // erreur déjà signalée sur la collection
    const names = garmentFileNames({ prefix, kind: g.kind, slot: g.slot, index: g.drawableIndex });

    if (g.yddAssetId) {
      const y = gtaAsset(g.yddAssetId, 'ydd', `${label} – modèle`);
      if (y) plan.stream.push({ from: y.file, to: `stream/${names.ydd}`, role: 'ydd', garmentId: g.id });
    } else if (mode === 'addon') {
      add('error', `${label} : un vêtement additionnel a besoin de son modèle .ydd.`, g.id);
    } else {
      add('info', `${label} : aucun .ydd, seules les textures du vêtement ${g.slot} n° ${g.drawableIndex} du jeu seront remplacées.`, g.id);
    }
    if (g.modelAssetId && !g.yddAssetId) add('info', `${label} : le modèle 3D de travail (${assetById.get(g.modelAssetId)?.name ?? '?'}) sert à l'aperçu ; il n'est pas exporté (conversion en .ydd requise).`, g.id);

    if (!g.variants?.length) { add('error', `${label} : aucune variante de texture.`, g.id); continue; }
    const letters = new Set();
    for (const v of g.variants) {
      const vl = `${label} variante ${v.letter ?? '?'}`;
      if (!VARIANT_LETTERS.includes(v.letter)) { add('error', `${vl} : lettre de variante invalide (a à z).`, g.id); continue; }
      if (letters.has(v.letter)) { add('error', `${label} : la variante « ${v.letter} » existe deux fois.`, g.id); continue; }
      letters.add(v.letter);
      if (v.ytdAssetId) {
        const t = gtaAsset(v.ytdAssetId, 'ytd', vl);
        if (t) plan.stream.push({ from: t.file, to: `stream/${names.ytd(v.letter)}`, role: 'ytd', garmentId: g.id });
      } else if (v.textureDocId && project.textureDocs.some((d) => d.id === v.textureDocId)) {
        plan.pending.push({ garmentId: g.id, variantId: v.id, textureDocId: v.textureDocId, ytdName: names.ytd(v.letter), textureName: names.textureName(v.letter) });
        add('warning', `${vl} : texture créée dans l'application, à intégrer dans « ${names.ytd(v.letter)} » avec un outil externe (CodeWalker). Le pack sera marqué incomplet.`, g.id);
      } else {
        add('error', `${vl} : aucune texture (.ytd ou texture de travail) associée.`, g.id);
      }
    }
  }

  for (const s of plan.stream) {
    const low = s.to.toLowerCase();
    if (outputs.has(low)) add('error', `Deux fichiers produiraient le même nom : ${s.to}`);
    outputs.set(low, s);
  }
  if (!plan.stream.some((s) => s.role === 'ydd' || s.role === 'ytd') && !issues.some((i) => i.level === 'error')) {
    add(plan.pending.length ? 'warning' : 'error', 'Aucun fichier de vêtement prêt à diffuser (.ydd / .ytd).');
  }

  const status = issues.some((i) => i.level === 'error') ? 'blocked' : plan.pending.length || !plan.stream.length ? 'incomplete' : 'ready';
  return { status, issues, plan };
}
