// Rendu de fichiers SVG en PNG (fond transparent) avec le Chromium préinstallé.
//   node tools/assets/render_svgs.cjs <dossier_sortie> <taille> fichier1.svg fichier2.svg ...
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  const [outDir, size, ...files] = process.argv.slice(2);
  const px = parseInt(size, 10) || 512;
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: px, height: px }, deviceScaleFactor: 1 });
  for (const f of files) {
    const svg = fs.readFileSync(f, 'utf8');
    await page.setContent(`<html><body style="margin:0;background:transparent">${svg.replace(/width="\d+" height="\d+"/, `width="${px}" height="${px}"`)}</body></html>`);
    const out = path.join(outDir, path.basename(f).replace(/\.svg$/, '.png'));
    await page.screenshot({ path: out, omitBackground: true, clip: { x: 0, y: 0, width: px, height: px } });
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
