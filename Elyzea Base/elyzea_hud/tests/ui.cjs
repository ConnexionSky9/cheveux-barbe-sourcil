const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + require("path").join(__dirname, "..", "html", "index.html")); await p.waitForTimeout(300);
  await p.evaluate(() => {
    document.body.classList.add('demo');
    const aspect = 16 / 9, w = 1 / (4 * aspect), h = 1 / 5.674, m = 0.05 * (Math.abs(0.9 - 1) * 10) / 1;
    window.postMessage({ action: 'rect', rect: { x: 0.05 * 0.1 * 10 * 0.0 + 0.0125, y: 1 - 0.0125 - h, w, h, align: 'LB' }, frame: { inner: 8, outer: 12 } }, '*');
    window.postMessage({ action: 'ident', firstname: 'Léna', lastname: 'Duval', id: 12 }, '*');
    window.postMessage({ action: 'update', show: true, map: true, health: 74, armor: 40, hunger: 62, thirst: 18, voice: { mode: 2, distance: 8 }, talking: true }, '*');
    window.postMessage({ action: 'vehicle', vehicle: { speed: 128, max: 240, rpm: .72, gear: '4', fuel: 46, engine: 88, engineOn: true, lights: true, left: true, dir: 'NO', street: 'Vinewood Blvd · Downtown' } }, '*');
  });
  await p.waitForTimeout(900);
  await p.screenshot({ path: (process.argv[2] || __dirname) + "/hud.png" });
  console.log('errs', errs); await b.close();
})();
