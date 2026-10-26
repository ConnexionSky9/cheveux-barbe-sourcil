// Échographie : l'image du fœtus s'affiche dans le cône de la sonde (netteté selon la position de la sonde).
// node tests/echo_ui.cjs <dossier captures>
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const path = require('path');
(async () => {
  const out = process.argv[2] || require('os').tmpdir();   // captures hors du dépôt par défaut
  const b = await chromium.launch();
  let fails = 0;
  const check = (c, l) => { console.log((c ? '  ok   ' : '  ÉCHEC ') + l); if (!c) fails++; };
  for (const [w, h] of [[1920, 1080], [1280, 720]]) {
    const page = await b.newPage({ viewport: { width: w, height: h } });
    const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
    await page.route('https://elyzea_ems/**', (r) => r.fulfill({ status: 200, contentType: 'application/json', body: '{}' }));
    await page.goto('file://' + path.resolve(__dirname, '../html/index.html'));
    const loaded = await page.evaluate(() => new Promise((res) => { const i = new Image(); i.onload = () => res([i.naturalWidth, i.naturalHeight]); i.onerror = () => res(null); i.src = 'img/echo_foetus.webp'; }));
    check(loaded && loaded[0] === 520 && loaded[1] === 600, `${w}×${h} : image chargée (${loaded})`);
    await page.evaluate(() => window.ProcMG.start({ id: 'T1', act: 'echo', title: 'Suivi de grossesse', difficulty: 2, duration: 32, maxMistakes: 3, seed: 3, extra: { type: 'pregnancy', typeLabel: 'Suivi de grossesse' } }));
    await page.waitForTimeout(300);
    await page.evaluate(() => window.ProcMG.cur.next());          // gel appliqué
    await page.waitForTimeout(200);
    await page.evaluate(() => { const S = window.ProcMG.cur, st = S.phases[S.pi].state; S.m.x = st.x; S.m.y = st.y; S.m.down = true; });
    await page.waitForTimeout(1500);
    await page.screenshot({ path: `${out}/echo_${w}x${h}.png` });
    // pixels du cône (sur la capture d'écran : le canevas ne se lit pas en file://) : le fœtus est dessiné
    const box = await page.locator('#pg canvas').boundingBox();
    const k = box.width / 760;
    const shot = await page.screenshot({ clip: { x: box.x + (470 + 60) * k, y: box.y + (40 + 70) * k, width: 140 * k, height: 160 * k } });
    const lum = Number(require('child_process').execFileSync('python3', ['-c',
      'import sys,io;from PIL import Image,ImageStat;im=Image.open(io.BytesIO(sys.stdin.buffer.read())).convert("L");print(ImageStat.Stat(im).mean[0])'], { input: shot }).toString());
    check(lum > 45, `${w}×${h} : fœtus visible dans le cône (luminosité moyenne ${lum.toFixed(0)})`);
    check(errors.length === 0, `${w}×${h} : aucune erreur JavaScript`);
    await page.close();
  }
  await b.close();
  console.log(`\n${fails} échec(s)`);
  process.exit(fails ? 1 : 0);
})();
