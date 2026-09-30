import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const code = readFileSync(new URL('../web/startup-recovery.js', import.meta.url), 'utf8');
function launch(search = '') {
  const listeners = {}, timers = [], nodes = [], blobs = [];
  const location = {href: 'https://example.test/jellyfin/web/speshtv-0.1.0/moonfin/' + search + '#/home',
    pathname: '/jellyfin/web/speshtv-0.1.0/moonfin/', search, replace(value) { this.replaced = value; }};
  function node(tag) {
    const buttons = {};
    return {tag, setAttribute() {}, appendChild() {}, focus() {}, click() {},
      remove() { const index = nodes.indexOf(this); if (index >= 0) nodes.splice(index, 1); },
      querySelector(selector) { return buttons[selector] ??= {focus() {}}; }};
  }
  const document = {createElement: node, getElementById(id) { return nodes.find(n => n.id === id); },
    body: {appendChild(n) { nodes.push(n); }}};
  class TestBlob { constructor(parts) { blobs.push(parts.join('')); } }
  class TestURL extends URL {}
  TestURL.createObjectURL = () => 'blob:diagnostic'; TestURL.revokeObjectURL = () => {};
  const window = {speshRendererConfig: {renderer: 'canvaskit', canvasKitForceCpuOnly: true},
    addEventListener(name, callback) { listeners[name] = callback; }};
  vm.runInNewContext(code, {window, document, location,
    navigator: {userAgent: 'Mozilla Android 16; wv) Chrome/140.0.0.0 password=SECRET'},
    URL: TestURL, URLSearchParams, Blob: TestBlob, Date, Error,
    setTimeout(callback, delay) { const timer = {callback, delay}; timers.push(timer); return timer; },
    clearTimeout(timer) { if (timer) timer.canceled = true; }});
  return {listeners, timers, nodes, blobs, location,
    timeout() { const timer = timers.find(t => t.delay === 45000); if (!timer.canceled) timer.callback(); }};
}
const failed = launch('?token=SECRET');
failed.listeners.error({error: new Error('password=SECRET https://secret.example')});
failed.timeout();
assert.equal(failed.nodes.length, 1);
failed.nodes[0].querySelector('[data-action="report"]').onclick();
const report = JSON.parse(failed.blobs[0]);
assert.equal(report.chromiumVersion, '140.0.0.0');
assert.equal(report.renderer, 'canvaskit');
assert.equal(report.firstFrame, false);
assert.ok(!failed.blobs[0].includes('SECRET'));
assert.ok(!failed.blobs[0].includes('https:'));
failed.nodes[0].querySelector('[data-action="compatibility"]').onclick();
assert.equal(new URL(failed.location.replaced).searchParams.get('speshRenderer'), 'software');
assert.equal(new URL(failed.location.replaced).hash, '#/home');
const success = launch();
success.listeners['flutter-first-frame'](); success.timeout();
assert.equal(success.nodes.length, 0);
const manual = launch('?speshRecovery=1');
assert.equal(manual.nodes.length, 1);
manual.nodes[0].querySelector('[data-action="return"]').onclick();
assert.equal(manual.location.replaced, '/jellyfin/web/#/home');
manual.nodes[0].querySelector('[data-action="retry"]').onclick();
assert.equal(new URL(manual.location.replaced).searchParams.has('speshRecovery'), false);
console.log('Startup timeout, healthy startup, safe export, compatibility, retry, and server-prefix return checks passed.');
