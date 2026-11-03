const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('file://' + require("path").join(__dirname, "..", "html", "index.html")); await p.waitForTimeout(2800);
  await p.click('[data-n="2"]'); await p.click('#enterBtn'); await p.waitForTimeout(1500);
  await p.screenshot({ path: (process.argv[2] || __dirname) + "/multichar.png" });
  await p.click('.char[data-slot="2"]'); await p.waitForTimeout(400);
  const t = await p.textContent('#detail');
  await p.evaluate(() => { characters = characters.slice(0, 1); renderSelect(); selectSlot(2); });
  await p.waitForTimeout(500);
  const t2 = await p.textContent('#detail');
  console.log('errs', errs, '| slot2:', t.includes('Marco'), '| vide:', t2.includes('Créer'));
  await b.close();
})();
