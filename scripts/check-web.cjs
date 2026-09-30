const { chromium } = require(process.env.PLAYWRIGHT_PATH);
const fs = require('node:fs');
const path = require('node:path');
(async () => {
  const out = path.resolve(__dirname, '../verification');
  fs.mkdirSync(out, {recursive:true});
  const browser = await chromium.launch({channel:'chrome', headless:true});
  const results = [];
  try {
    for (const [label, width, height] of [['desktop',1440,900],['mobile',390,844]]) {
      const context = await browser.newContext({viewport:{width,height}});
      const page = await context.newPage();
      const errors = [];
      const diagnostics = [];
      let phase = 'startup';
      page.on('pageerror', e => errors.push({message:e.message, stack:e.stack, phase}));
      page.on('console', message => {
        if (['warning','error'].includes(message.type()) && diagnostics.length < 40 &&
            !diagnostics.includes(message.text())) diagnostics.push(message.text());
      });
      await page.goto(process.env.PREVIEW_URL || 'http://127.0.0.1:8098/Moonfin/Web/', {waitUntil:'domcontentloaded'});
      await page.waitForSelector('flutter-view', {timeout:90000});
      await page.waitForTimeout(8000);
      phase = 'accessibility';
      const placeholders = page.locator('flt-semantics-placeholder');
      if (await placeholders.count()) await placeholders.first().press('Enter');
      await page.waitForTimeout(2000);
      const title = await page.title();
      const prefix = process.env.CHECK_LABEL || 'preview';
      await page.screenshot({path:path.join(out, `${prefix}-${label}.png`)});
      const semantics = await page.locator('flt-semantics-host').innerText().catch(() => '');
      results.push({label, title, errors, diagnostics, semantics});
      await context.close();
    }
  } finally { await browser.close(); }
  fs.writeFileSync(path.join(out, `${process.env.CHECK_LABEL || 'preview'}-browser-check.json`), JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  if (results.some(r => r.errors.length || r.title !== 'SpeshTV')) process.exitCode = 1;
})().catch(error => {console.error(error); process.exitCode = 1;});
