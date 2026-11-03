const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1600, height: 900 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.route(/^https?:/, r => r.abort());
  await p.goto('file://' + require('path').resolve(__dirname, '../html') + '/index.html');
  // fond « jeu » simulé sous la NUI
  await p.addStyleTag({ content: 'body{background:linear-gradient(#3b6b9a,#c98d5a 60%,#2d2d33 61%) !important}' });
  const send = (m) => p.evaluate((m) => window.postMessage(Object.assign({ action: 'welcome' }, m), '*'), m);
  const out = process.argv[2] || require('os').tmpdir();
  await send({ stage: 'intro', title: 'Bienvenue sur', name: 'Elyzea FA' });
  await p.waitForTimeout(1600); await p.screenshot({ path: out + '/wl_1.png' });
  await p.waitForTimeout(3800); await p.screenshot({ path: out + '/wl_2.png' });
  const ok = [];
  ok.push(['nom en lettres', await p.$$eval('#wlName span', s => s.length) >= 9]);
  ok.push(['FA violet', await p.$$eval('#wlName span.v', s => s.map(x => x.textContent).join('')) === 'FA']);
  ok.push(['emblème', !!(await p.$('#wlMark svg'))]);
  ok.push(['skyline', !!(await p.$('#wlCity svg'))]);
  await send({ stage: 'reveal' });
  await p.waitForTimeout(700); await p.screenshot({ path: out + '/wl_3.png' });
  await p.waitForTimeout(1200);
  ok.push(['intro cachée', await p.$eval('#wlIntro', e => e.classList.contains('hidden'))]);
  await send({ stage: 'city', district: 'Vinewood', street: 'Power St', time: '21:45', name: 'Lina <b>Moreau' });
  await p.waitForTimeout(3000); await p.screenshot({ path: out + '/wl_4.png' });
  ok.push(['nom échappé', (await p.$eval('#wlWho b', e => e.innerHTML)).includes('&lt;b&gt;')]);
  ok.push(['bandes', await p.$eval('#welcome', e => e.classList.contains('cinema'))]);
  await send({ stage: 'outro', message: 'Ta nouvelle vie commence ici. Respecte la ville, et elle te le rendra.', signature: "L'équipe Elyzea FA" });
  await p.waitForTimeout(3200); await p.screenshot({ path: out + '/wl_5.png' });
  ok.push(['scène cachée', await p.$eval('#wlScene', e => e.classList.contains('hidden'))]);
  await send({ stage: 'end' }); await p.waitForTimeout(1700);
  ok.push(['fin cachée', await p.$eval('#welcome', e => e.classList.contains('hidden'))]);
  // rejouer une 2e fois
  await send({ stage: 'intro', name: 'Elyzea FA' }); await p.waitForTimeout(300);
  ok.push(['rejouable', await p.$eval('#welcome', e => !e.classList.contains('hidden') && !e.classList.contains('reveal'))]);
  ok.push(['aucune erreur JS', errs.length === 0]);
  for (const [n, v] of ok) console.log(v ? 'OK ' : 'ÉCHEC', n);
  if (errs.length) console.log(errs);
  await b.close();
})();
