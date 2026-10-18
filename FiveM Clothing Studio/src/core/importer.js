// Analyse d'un fichier AVANT import : format réel, lisibilité, limites, opérations possibles.
// Les états « lisible », « modifiable », « affichable », « convertible » et « exportable »
// sont distincts et ne sont jamais confondus (voir docs/FORMATS.md).
import fs from 'node:fs';
import path from 'node:path';
import { sniff } from './detect.js';
import { probeImage } from './image/codecs.js';
import { isPowerOfTwo } from './image/rgba.js';
import { inspectObj, inspectGltf, inspectFbx } from './model/inspect.js';
import { inspectRsc7 } from './gta/rsc7.js';
import { parseGarmentFileName } from './gta/naming.js';

const issue = (level, message) => ({ level, message });

export function inspectFile(file, { limits = {} } = {}) {
  const name = path.basename(file);
  const ext = path.extname(name).slice(1).toLowerCase();
  const res = { path: file, name, ext, size: 0, format: 'unknown', family: 'unknown', kind: null, role: null,
    status: { readable: false, editable: false, viewable: false, convertible: false, exportable: false },
    info: {}, issues: [], operations: [] };
  let st;
  try { st = fs.statSync(file); } catch { res.issues.push(issue('error', 'Fichier introuvable ou inaccessible.')); return res; }
  if (!st.isFile()) { res.issues.push(issue('error', 'Ce n\'est pas un fichier.')); return res; }
  res.size = st.size;
  const max = limits.maxImportBytes ?? 256 * 1024 * 1024;
  if (st.size === 0) { res.issues.push(issue('error', 'Fichier vide.')); return res; }
  if (st.size > max) { res.issues.push(issue('error', `Fichier trop volumineux (${mb(st.size)} ; maximum ${mb(max)}).`)); return res; }

  let buf;
  try { buf = fs.readFileSync(file); } catch (e) { res.issues.push(issue('error', `Lecture impossible : ${e.message}`)); return res; }
  const s = sniff(buf, ext);
  Object.assign(res, { format: s.format, family: s.family });
  if (s.mismatch) res.issues.push(issue('warning', `L'extension .${ext} ne correspond pas au contenu réel (${s.format.toUpperCase()}).`));

  try {
    switch (s.family) {
      case 'image': inspectImage(res, buf, limits); break;
      case 'model': inspectModel(res, buf); break;
      case 'gta': inspectGta(res, buf, ext); break;
      case 'archive':
        res.issues.push(issue('error', 'Archive ZIP : décompressez-la d\'abord, puis importez les fichiers qu\'elle contient.'));
        break;
      default:
        res.issues.push(issue('error', 'Format non reconnu. Formats acceptés : PNG, JPEG, TGA, DDS, OBJ (+MTL), glTF, GLB, FBX, YDD, YTD, YMT, META.'));
    }
  } catch (e) {
    res.status.readable = false;
    res.issues.push(issue('error', e.message));
  }
  return res;
}

function inspectImage(res, buf, limits) {
  const info = probeImage(buf, res.ext);
  res.kind = 'texture';
  res.info = info;
  res.status.readable = true;
  const decodable = info.format !== 'dds' || ['dxt1', 'dxt3', 'dxt5', 'rgb32', 'rgb24', 'rgba8', 'bgra8', 'lum8'].includes(info.ddsFormat);
  res.status.editable = decodable;
  res.status.viewable = decodable;
  res.status.convertible = decodable;   // vers PNG / TGA / DDS (DXT1, DXT5, BGRA8 + mipmaps)
  if (!decodable) res.issues.push(issue('error', `Ce DDS (${info.ddsFormat}) ne peut pas être décodé par l'application.`));
  const big = Math.max(info.width, info.height);
  if (big > (limits.maxTextureSize ?? 4096)) res.issues.push(issue('warning', `Texture de ${info.width} × ${info.height} : trop grande pour le jeu, réduisez-la (${limits.maxTextureSize ?? 4096} maximum conseillé).`));
  else if (big > (limits.warnTextureSize ?? 2048)) res.issues.push(issue('info', `Texture de ${info.width} × ${info.height} : grande résolution, pensez aux performances.`));
  if (!isPowerOfTwo(info.width) || !isPowerOfTwo(info.height)) res.issues.push(issue('warning', 'Dimensions qui ne sont pas des puissances de 2 (512, 1024, 2048…) : à redimensionner avant la conversion pour le jeu.'));
  if (info.format === 'jpeg') res.issues.push(issue('info', 'JPEG : pas de transparence et compression avec perte.'));
  res.operations = decodable ? ['Ouvrir dans l\'éditeur de textures', 'Utiliser comme logo / calque', 'Exporter en PNG, TGA ou DDS'] : [];
}

function inspectModel(res, buf) {
  let r;
  if (res.format === 'obj') r = inspectObj(buf.toString('utf8'));
  else if (res.format === 'gltf' || res.format === 'glb') r = inspectGltf(buf);
  else if (res.format === 'fbx') r = inspectFbx(buf);
  else if (res.format === 'mtl') {
    res.kind = 'material'; res.status.readable = true;
    res.info = { materials: (buf.toString('utf8').match(/^\s*newmtl\s+.+$/gm) || []).length };
    res.operations = ['Associer au modèle OBJ du même dossier'];
    return;
  }
  res.kind = 'model';
  res.info = r;
  res.issues.push(...r.issues);
  const blocking = r.issues.some((i) => i.level === 'error');
  res.status.readable = !blocking;
  res.status.viewable = !blocking;
  res.status.editable = !blocking;   // position / rotation / échelle, matériaux et textures dans l'aperçu
  res.status.exportable = false;
  res.issues.push(issue('info', 'Un modèle 3D générique n\'est pas un vêtement GTA V : il doit être converti en .ydd (squelette, poids, matériaux) avec Blender + Sollumz. Voir l\'aide « Préparer un vêtement ».'));
  res.operations = blocking ? [] : ['Afficher dans l\'aperçu 3D', 'Associer des textures aux matériaux', 'Enregistrer une copie de travail (GLB)'];
}

function inspectGta(res, buf, ext) {
  res.kind = 'gta';
  if (res.format === 'xml') {
    const head = buf.toString('utf8', 0, Math.min(buf.length, 4096));
    res.status.readable = true;
    if (/<ShopPedApparel[\s>]/.test(head)) {
      res.role = 'shopmeta';
      const ped = /<pedName>\s*([^<\s]+)\s*<\/pedName>/.exec(head)?.[1] ?? null;
      const dlc = /<dlcName>\s*([^<\s]+)\s*<\/dlcName>/.exec(head)?.[1] ?? null;
      res.info = { pedName: ped, dlcName: dlc };
      res.status.exportable = true;
      res.operations = ['Fichier de boutique (shop meta) d\'une collection additionnelle'];
    } else if (ext === 'ymt' && /<CPedVariationInfo[\s>]/.test(head)) {
      res.role = 'ymt-xml';
      res.issues.push(issue('error', 'YMT au format XML (export CodeWalker) : il doit être reconverti en .ymt binaire avec CodeWalker avant export.'));
    } else {
      res.issues.push(issue('error', 'Fichier XML non reconnu (attendu : métadonnées ShopPedApparel).'));
    }
    return;
  }
  if (res.format === 'pso') {
    res.role = ext === 'ymt' ? 'ymt' : null;
    res.status.readable = true;
    res.status.exportable = res.role === 'ymt';
    res.issues.push(issue('info', 'Métadonnées au format PSO : contenu non vérifié par l\'application.'));
    return;
  }
  const r = inspectRsc7(buf, { ext });
  res.info = r;
  res.issues.push(...r.issues);
  res.status.readable = r.ok;
  res.status.exportable = r.ok && ['ydd', 'ytd', 'ymt'].includes(ext);
  res.role = ['ydd', 'ytd', 'ymt'].includes(ext) ? ext : null;
  if (!res.role) res.issues.push(issue('warning', `.${ext} : pas utilisé par les exports de vêtements de cette version.`));
  const parsed = parseGarmentFileName(res.name);
  if (parsed) { res.info.garment = parsed; res.operations.push(`Reconnu : ${parsed.kind === 'prop' ? 'accessoire' : 'composant'} ${parsed.slot}, n° ${parsed.index}${parsed.letter ? `, variante ${parsed.letter}` : ''}`); }
  res.issues.push(issue('info', 'Fichier GTA V natif : contenu non décodé par l\'application (pas d\'aperçu 3D ni d\'édition). Il peut être exporté tel quel dans la ressource.'));
  if (res.role === 'ytd') res.operations.push('Associer comme textures d\'une variante');
  if (res.role === 'ydd') res.operations.push('Associer comme modèle d\'un vêtement');
  if (res.role === 'ymt') res.operations.push('Métadonnées d\'une collection additionnelle');
}

const mb = (n) => `${(n / 1048576).toFixed(1)} Mo`;
