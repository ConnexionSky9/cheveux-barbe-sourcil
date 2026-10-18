// Outils externes : détection, version et procédure d'installation.
// Aucun outil n'est téléchargé ni exécuté sans action de l'utilisateur ; l'appel de
// version utilise execFile avec un tableau d'arguments (jamais de ligne de commande shell).
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFile } from 'node:child_process';

export const TOOLS = [
  {
    id: 'blender', name: 'Blender',
    role: 'Modélisation 3D : modifier un vêtement, préparer squelette et poids, convertir avec Sollumz.',
    usedFor: ['Créer ou modifier la géométrie d\'un vêtement', 'Conversion modèle 3D → .ydd (avec Sollumz)'],
    docs: 'https://www.blender.org/download/',
    install: ['Téléchargez Blender sur blender.org (gratuit, licence GPL).', 'Installez-le normalement, puis relancez la détection.',
      'Si Blender est installé ailleurs, indiquez le chemin de blender.exe dans Paramètres.'],
  },
  {
    id: 'sollumz', name: 'Sollumz (extension Blender)',
    role: 'Importe / exporte les formats GTA V (.ydd, .ydr, .yft…) dans Blender.',
    usedFor: ['Conversion modèle 3D → .ydd', 'Ouverture d\'un .ydd existant pour le modifier'],
    docs: 'https://github.com/Sollumz/Sollumz',
    install: ['Téléchargez la dernière version publiée sur GitHub (Releases).', 'Dans Blender : Edit > Preferences > Add-ons > Install, choisissez le zip, activez « Sollumz ».',
      'Relancez la détection.'],
  },
  {
    id: 'codewalker', name: 'CodeWalker',
    role: 'Explorateur GTA V : textures (.ytd), métadonnées (.ymt), conversion XML ↔ binaire.',
    usedFor: ['Créer un .ytd à partir des DDS exportés', 'Lire / convertir un .ymt'],
    docs: 'https://github.com/dexyfex/CodeWalker',
    install: ['Téléchargez CodeWalker (version publiée sur GitHub ou sur le site de l\'auteur).', 'Décompressez-le dans un dossier de votre choix.',
      'Indiquez le chemin de CodeWalker.exe dans Paramètres (outil portable, aucune installation).'],
  },
];

function runVersion(exe, args, timeout = 15000) {
  return new Promise((resolve) => {
    execFile(exe, args, { timeout, windowsHide: true }, (err, stdout) => resolve(err ? null : String(stdout)));
  });
}

function blenderCandidates() {
  const out = [];
  if (process.platform === 'win32') {
    for (const root of [process.env.ProgramFiles, process.env['ProgramFiles(x86)']].filter(Boolean)) {
      const base = path.join(root, 'Blender Foundation');
      try { for (const d of fs.readdirSync(base)) out.push(path.join(base, d, 'blender.exe')); } catch { /* absent */ }
    }
  } else {
    out.push('/usr/bin/blender', '/usr/local/bin/blender', '/snap/bin/blender', '/Applications/Blender.app/Contents/MacOS/Blender');
  }
  return out.sort().reverse();
}

function sollumzCandidates(custom) {
  const out = custom ? [custom] : [];
  const base = process.platform === 'win32'
    ? path.join(process.env.APPDATA || path.join(os.homedir(), 'AppData', 'Roaming'), 'Blender Foundation', 'Blender')
    : path.join(os.homedir(), '.config', 'blender');
  try {
    for (const ver of fs.readdirSync(base)) {
      for (const sub of [['scripts', 'addons'], ['extensions', 'user_default'], ['extensions', 'blender_org']]) {
        const dir = path.join(base, ver, ...sub);
        try { for (const d of fs.readdirSync(dir)) if (/sollumz/i.test(d)) out.push(path.join(dir, d)); } catch { /* absent */ }
      }
    }
  } catch { /* Blender jamais lancé */ }
  return out;
}

/** État de chaque outil : { id, status: 'found'|'missing'|'error', path, version, message }. */
export async function detectTools(cfg = {}) {
  const res = [];
  // Blender
  const bl = [cfg.blender, ...blenderCandidates()].filter(Boolean).find((p) => fs.existsSync(p));
  if (!bl) res.push({ id: 'blender', status: 'missing', message: 'Blender non trouvé.' });
  else {
    const out = await runVersion(bl, ['--version']);
    const version = out && /Blender\s+([\d.]+)/.exec(out)?.[1];
    res.push(version ? { id: 'blender', status: 'found', path: bl, version } : { id: 'blender', status: 'error', path: bl, message: 'Blender trouvé mais ne répond pas.' });
  }
  // Sollumz
  const sz = sollumzCandidates(cfg.sollumzAddonDir).find((p) => fs.existsSync(p));
  res.push(sz ? { id: 'sollumz', status: 'found', path: sz, message: 'Dossier de l\'extension trouvé (activation dans Blender non vérifiée).' }
    : { id: 'sollumz', status: 'missing', message: 'Extension Sollumz non trouvée dans les dossiers de Blender.' });
  // CodeWalker (portable : seulement le chemin configuré)
  const cw = cfg.codewalker && fs.existsSync(cfg.codewalker) ? cfg.codewalker : null;
  res.push(cw ? { id: 'codewalker', status: 'found', path: cw } : { id: 'codewalker', status: 'missing', message: cfg.codewalker ? 'Chemin configuré introuvable.' : 'Chemin de CodeWalker.exe non configuré.' });
  return res.map((r) => ({ ...TOOLS.find((t) => t.id === r.id), ...r }));
}
