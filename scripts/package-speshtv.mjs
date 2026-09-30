import {readFileSync, writeFileSync, copyFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../build/web');
const files = ['main.dart.js','main.dart.mjs','main.dart.wasm'];
const hash = createHash('sha256');
for (const file of files) hash.update(readFileSync(path.join(root, file)));
// Shell-only fixes also need a distinct deployment version.
hash.update(readFileSync(new URL('../web/index.html', import.meta.url)));
hash.update(readFileSync(new URL('../web/startup-recovery.js', import.meta.url)));
const version = hash.digest('hex').slice(0,16);
const names = Object.fromEntries(files.map(file => [file, `speshtv-${version}.${file}`]));
for (const [original, versioned] of Object.entries(names)) copyFileSync(path.join(root,original), path.join(root,versioned));
let bootstrap = readFileSync(path.join(root,'flutter_bootstrap.js'),'utf8');
let replaced = false;
bootstrap = bootstrap.replace(/_flutter\.buildConfig = ([^\r\n]+);/, (_, json) => {
  const config = JSON.parse(json);
  assert.ok(Array.isArray(config.builds));
  for (const build of config.builds) {
    for (const field of ['mainJsPath','mainWasmPath','jsSupportRuntimePath']) {
      if (build[field]) { assert.ok(names[build[field]]); build[field] = names[build[field]]; }
    }
  }
  replaced = true;
  return `_flutter.buildConfig = ${JSON.stringify(config)};`;
});
assert.ok(replaced, 'Flutter bootstrap structure changed; do not deploy.');
assert.match(bootstrap, /_flutter\.loader\.load\(\{/);
bootstrap = bootstrap.replace(/_flutter\.loader\.load\(\{/, '_flutter.loader.load({config: window.speshRendererConfig || {},');
const bootstrapName = `speshtv-${version}.bootstrap.js`;
const recoveryName = `speshtv-${version}.recovery.js`;
copyFileSync(new URL('../web/startup-recovery.js', import.meta.url), path.join(root, recoveryName));
writeFileSync(path.join(root,bootstrapName),bootstrap);
const builtHtml = readFileSync(path.join(root,'index.html'),'utf8');
const baseHref = builtHtml.match(/<base href="([^"]*)">/)?.[1];
assert.ok(baseHref && !baseHref.includes('$FLUTTER_BASE_HREF'));
let html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8').replace('$FLUTTER_BASE_HREF', baseHref);
assert.match(html, /src="(?:flutter_bootstrap|speshtv-[a-f0-9]+\.bootstrap)\.js"/);
html = html.replace(/src="(?:flutter_bootstrap|speshtv-[a-f0-9]+\.bootstrap)\.js"/, `src="${bootstrapName}"`);
html = html.replace('src="startup-recovery.js"', `src="${recoveryName}"`);
writeFileSync(path.join(root,'index.html'),html);
writeFileSync(path.join(root,'speshtv-assets.json'), JSON.stringify({version, bootstrap:bootstrapName, assets:names},null,2));
console.log(`Packaged SpeshTV ${version} with content-versioned browser entrypoints.`);
