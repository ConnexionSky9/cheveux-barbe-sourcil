// Rend les SVG en PNG (Chromium headless) : node assets_src/render.js
const { chromium } = require('playwright'); const fs = require('fs'); const path = require('path');
const A = path.join(__dirname, '..', 'html', 'assets');
const D = (f) => 'data:image/png;base64,' + fs.readFileSync(path.join(A, f)).toString('base64');
const jobs = [['icon.svg', 'blackphone.png', 256, 256], ['police_laptop.svg', 'police_laptop.png', 256, 256], ['logo.svg', 'logo.png', 1132, 280],
  ['logo_red.svg', 'logo_red.png', 1132, 280], ['logo_mono_black.svg', 'logo_mono_black.png', 1132, 280], ['mark.svg', 'mark.png', 336, 480], ['wallpaper.svg', 'wallpaper.png', 400, 860]];
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
  const p = await b.newPage();
  for (const [src, dst, w, h] of jobs) {
    const svg = fs.readFileSync(path.join(A, src), 'utf8');
    await p.setViewportSize({ width: w, height: h });
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('<svg ', `<svg style="width:${w}px;height:${h}px;display:block" `)}</body></html>`);
    await p.screenshot({ path: path.join(A, dst), omitBackground: true });
  }
  // planche de contrôle
  await p.setViewportSize({ width: 1200, height: 760 });
  await p.setContent(`<body style="margin:0;font-family:sans-serif">
    <div style="background:#050506;padding:24px;display:flex;gap:30px;align-items:center"><img src="${D('logo.png')}" width="560"><img src="${D('blackphone.png')}" width="128"><img src="${D('blackphone.png')}" width="48"></div>
    <div style="background:#e9e9ec;padding:24px;display:flex;gap:30px;align-items:center"><img src="${D('logo_red.png')}" width="560"><img src="${D('logo_mono_black.png')}" width="400"></div>
    <div style="background:#1b1f2a;padding:24px;display:flex;gap:30px;align-items:center"><img src="${D('wallpaper.png')}" height="300"><img src="${D('mark.png')}" height="160"><img src="${D('police_laptop.png')}" width="128"></div></body>`);
  await p.waitForTimeout(300);
  await p.screenshot({ path: path.join(__dirname, 'sheet.png'), fullPage: true });
  await b.close(); console.log('ok');
})();
