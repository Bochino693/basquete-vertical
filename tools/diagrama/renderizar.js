// Foto do diagrama (docs/diagrama_montagem.html -> .png) no Chromium, em 2x.
const path = require('path');
const { chromium } = require('playwright');
(async () => {
  const docs = path.join(__dirname, '..', '..', 'docs');
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 2400, height: 1780 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.join(docs, 'diagrama_montagem.html'));
  await p.waitForTimeout(300);
  await p.screenshot({ path: path.join(docs, 'diagrama_montagem.png'), fullPage: true });
  await b.close();
  console.log('ok: docs/diagrama_montagem.png');
})();
