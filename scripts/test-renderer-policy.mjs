import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const script = html.match(/<script id="speshtv-renderer-policy">([\s\S]*?)<\/script>/)?.[1];
assert.ok(script);
function config(userAgent, search = '') {
  const context = {navigator: {userAgent}, location: {search}, window: {}, URLSearchParams};
  vm.runInNewContext(script, context);
  return context.window.speshRendererConfig;
}
const samsung = config('Mozilla/5.0 (Linux; Android 16; SM-S931B Build/AP3A; wv) AppleWebKit/537.36 Version/4.0 Chrome/140 Mobile Safari/537.36');
assert.equal(samsung.renderer, 'canvaskit');
assert.equal(samsung.canvasKitForceCpuOnly, true);
const generic = config('Mozilla/5.0 (Linux; Android 16; K; wv) Version/4.0 Chrome/140 Mobile Safari/537.36');
assert.equal(generic.renderer, 'canvaskit');
assert.equal(generic.canvasKitForceCpuOnly, false);
assert.equal(Object.keys(config('Mozilla/5.0 (Linux; Android 16; K) Chrome/140 Mobile Safari/537.36')).length, 0);
assert.equal(Object.keys(config('Mozilla/5.0 (Windows NT 10.0) Chrome/140')).length, 0);
assert.equal(config('Mozilla/5.0 (Linux; Android 16; K; wv)', '?speshRenderer=software').canvasKitForceCpuOnly, true);
assert.equal(config('Mozilla/5.0 Chrome/140', '?speshRenderer=canvaskit').renderer, 'canvaskit');
console.log('Six renderer policy checks passed.');
