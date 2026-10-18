// Transparence des textures d'un vêtement (.ytd) : analyse, puis réparation ciblée.
//
//   node scripts/transparence.js analyse <fichier.ytd> [--sortie dossier]
//   node scripts/transparence.js reparer <fichier.ytd> --texture <nom> (--masque masque.png | --zone x,y,largeur,hauteur)
//                                        [--sortie dossier] [--sans-remplissage]
//
// « analyse » écrit, pour chaque texture lisible : <nom>_couleur.png, <nom>_alpha.png, <nom>_apercu.png
// et un rapport (rapport_transparence.txt). Les zones magenta de l'aperçu sont invisibles en jeu.
// « reparer » ne modifie JAMAIS le fichier d'origine : le .ytd corrigé est écrit, sous le MÊME nom,
// dans le dossier de sortie (par défaut « corrige » à côté du fichier).
// Masque : une image de la taille de la texture, BLANC = à rendre opaque, NOIR = ne pas toucher.
// Le plus simple : copier <nom>_alpha.png et peindre en blanc les trous à boucher.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { readYtd, decodeYtdTexture, patchYtd } from '../src/core/gta/ytd.js';
import { readImageFile, encodeImage } from '../src/core/image/codecs.js';
import { analyseAlpha, colorOnly, alphaMap, alphaPreview, rectMask, makeOpaque, CUT } from '../src/core/gta/alpha.js';

function args(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--sans-remplissage') out.noFill = true;
    else if (a.startsWith('--')) out[a.slice(2)] = argv[++i];
    else out._.push(a);
  }
  return out;
}

const png = (file, img) => fs.writeFileSync(file, encodeImage(img, { format: 'png' }).buffer);

export function analyse(file, outDir) {
  const buf = fs.readFileSync(file);
  const ytd = readYtd(buf);
  fs.mkdirSync(outDir, { recursive: true });
  const lines = [`Analyse de la transparence : ${path.basename(file)}`, ''];
  const results = [];
  for (const t of ytd.textures) {
    const head = `• ${t.name} — ${t.width} × ${t.height}, ${t.format.toUpperCase()}, ${t.levels} niveaux`;
    if (!t.readable) { lines.push(head, '    lecture non prise en charge pour ce format', ''); continue; }
    const img = decodeYtdTexture(ytd, t.index);
    const s = analyseAlpha(img);
    results.push({ name: t.name, format: t.format, ...s });
    lines.push(head, `    opaque ${s.opaquePct} % · semi-transparent ${s.partialPct} % · INVISIBLE en jeu (alpha < ${CUT}) ${s.cutPct} %`);
    if (s.cutBox) {
      lines.push(`    zone invisible : x ${s.cutBox.x}, y ${s.cutBox.y}, ${s.cutBox.w} × ${s.cutBox.h} px · couleur cachée dessous ≈ rgb(${s.cutColor.join(', ')})`);
      if (/_n$|normal|_spec|_s$/i.test(t.name)) lines.push('    (texture de relief / brillance : son alpha ne crée pas de trou)');
    }
    lines.push('');
    png(path.join(outDir, `${t.name}_couleur.png`), colorOnly(img));
    png(path.join(outDir, `${t.name}_alpha.png`), alphaMap(img));
    png(path.join(outDir, `${t.name}_apercu.png`), alphaPreview(img));
  }
  lines.push('Lecture :',
    ' - 0 % invisible sur la texture « diff » du coloris concerné : les trous ne viennent PAS de la texture (voir le modèle .ydd).',
    ' - Zones invisibles là où la robe montre des trous : réparer avec « reparer » et un masque (blanc = à boucher).',
    ' - Une transparence voulue (dentelle, découpe) doit rester noire dans le masque.');
  fs.writeFileSync(path.join(outDir, 'rapport_transparence.txt'), lines.join('\n'));
  return { lines, results };
}

export function repair(file, { texture, mask, zone, outDir, fill = true }) {
  const buf = fs.readFileSync(file);
  const ytd = readYtd(buf);
  const t = ytd.textures.find((x) => x.name.toLowerCase() === String(texture || '').toLowerCase());
  if (!t) throw new Error(`Texture « ${texture} » absente. Textures du fichier : ${ytd.textures.map((x) => x.name).join(', ')}`);
  const img = decodeYtdTexture(ytd, t.index);
  let m;
  if (mask) m = readImageFile(mask).image;
  else if (zone) {
    const [x, y, w, h] = String(zone).split(',').map((v) => parseInt(v, 10));
    if ([x, y, w, h].some((v) => !Number.isFinite(v)) || w <= 0 || h <= 0) throw new Error('--zone attend x,y,largeur,hauteur (en pixels de la texture).');
    m = rectMask(img.width, img.height, { x, y, w, h });
  } else throw new Error('Indique --masque masque.png ou --zone x,y,largeur,hauteur.');
  const r = makeOpaque(img, m, { fill });
  if (!r.changed) throw new Error('Le masque ne couvre aucun pixel transparent : rien à réparer.');
  if (t.format === 'dxt1' && analyseAlpha(r.image).opaque !== img.width * img.height)
    throw new Error(`« ${t.name} » est en DXT1 et garde d'autres transparences : la réécriture les supprimerait toutes. Convertis d'abord la texture en DXT5.`);
  const res = patchYtd(buf, { [t.name]: r.image });
  fs.mkdirSync(outDir, { recursive: true });
  const out = path.join(outDir, path.basename(file));
  if (path.resolve(out) === path.resolve(file)) throw new Error('Le dossier de sortie doit être différent du dossier du fichier d\'origine.');
  fs.writeFileSync(out, res.buffer);
  return { out, texture: t.name, changed: r.changed, refilled: r.refilled, warnings: res.warnings };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const a = args(process.argv.slice(2));
  const [cmd, file] = a._;
  try {
    if (!file || !fs.existsSync(file)) throw new Error('Usage : node scripts/transparence.js analyse|reparer <fichier.ytd> …');
    if (cmd === 'analyse') {
      const outDir = a.sortie || path.join(path.dirname(file), `${path.basename(file, '.ytd')}_transparence`);
      console.log(analyse(file, outDir).lines.join('\n'));
      console.log(`\nImages et rapport : ${outDir}`);
    } else if (cmd === 'reparer') {
      const r = repair(file, { texture: a.texture, mask: a.masque, zone: a.zone, outDir: a.sortie || path.join(path.dirname(file), 'corrige'), fill: !a.noFill });
      console.log(`« ${r.texture} » : ${r.changed} pixels rendus opaques, dont ${r.refilled} recolorés depuis leurs voisins.`);
      for (const w of r.warnings) console.log(`Attention : ${w}`);
      console.log(`Fichier corrigé (l'original n'est pas modifié) : ${r.out}`);
    } else throw new Error(`Commande inconnue « ${cmd} » : analyse ou reparer.`);
  } catch (e) {
    console.error(`Erreur : ${e.message}`);
    process.exit(1);
  }
}
