// Construit la version Windows 64 bits (dossier portable + archive zip) dans dist/.
//   npm run build:win
// Fonctionne sous Windows, et sous Linux / macOS (pas d'icône personnalisée sans Wine).
import { packager } from '@electron/packager';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
const OUT = path.join(ROOT, 'dist');
fs.mkdirSync(OUT, { recursive: true });

const ignore = [/^\/test($|\/)/, /^\/dist($|\/)/, /^\/scripts($|\/)/, /^\/examples($|\/)/, /\.tmp($|\/)/, /^\/\.git/, /node_modules\/playwright/,
  /node_modules\/three\/(src|docs|manual|editor|examples\/(?!jsm)|build\/three\.(cjs|module\.min))/];

// FCS_PLATFORM=linux : même empaquetage pour Linux (sert aux tests automatiques de l'application empaquetée)
const platform = process.env.FCS_PLATFORM || 'win32';
const [appDir] = await packager({
  dir: ROOT, out: OUT, overwrite: true, platform, arch: 'x64', asar: true, prune: true, ignore,
  name: pkg.productName, executableName: pkg.productName, appVersion: pkg.version,
  appCopyright: 'Licence MIT', electronVersion: pkg.devDependencies.electron,
});
// Documentation et exemples à côté de l'exécutable
for (const f of ['README.md', 'app.config.json']) fs.copyFileSync(path.join(ROOT, f), path.join(appDir, f));
fs.cpSync(path.join(ROOT, 'docs'), path.join(appDir, 'docs'), { recursive: true });
fs.cpSync(path.join(ROOT, 'examples'), path.join(appDir, 'examples'), { recursive: true, filter: (s) => !s.includes('demo-sources') });
console.log(`Application : ${appDir}`);

if (platform !== 'win32') process.exit(0);
const zip = path.join(OUT, `${pkg.productName.replace(/ /g, '-')}-${pkg.version}-win-x64.zip`);
fs.rmSync(zip, { force: true });
try {
  if (process.platform === 'win32') {
    execFileSync('powershell', ['-NoProfile', '-Command', `Compress-Archive -Path '${appDir}\\*' -DestinationPath '${zip}'`], { stdio: 'inherit' });
  } else {
    execFileSync('zip', ['-qr', '-y', zip, path.basename(appDir)], { cwd: OUT, stdio: 'inherit' });
  }
  console.log(`Archive : ${zip}`);
} catch (e) {
  console.warn(`Archive non créée (${e.message}) : le dossier ${appDir} reste utilisable tel quel.`);
}
