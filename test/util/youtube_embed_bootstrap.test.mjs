import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

const source = readFileSync(new URL('../../lib/ui/widgets/web_youtube_trailer_io.dart', import.meta.url), 'utf8');
const values = {
  channelName: '"MoonfinYt"', bridgeName: '"__moonfinYtBridge"',
  playerElementId: '"player"', stageElementId: '"stage"',
  host: '"https://www.youtube.com"', pointerEventsJson: '"auto"',
  playerVarsJson: '{"autoplay":1,"mute":0,"loop":0,"cc_load_policy":0}',
  stageWidth: '1920', stageHeight: '1080', initialVideoId: '"abcdefghijk"',
};
const script = source.match(/    <script>\r?\n([\s\S]*?)    <\/script>/)[1]
  .replace(/\$([a-zA-Z]+)/g, (_, name) => {
    assert.ok(name in values, `Unknown interpolation ${name}`);
    return values[name];
  });

function boot() {
  const messages = [];
  const loads = [];
  let options;
  const elements = new Map();
  const element = () => ({style:{}, appendChild(child) { elements.set(child.id, child); }});
  const window = {innerWidth:1920, innerHeight:1080,
    MoonfinYt:{postMessage:json=>messages.push(JSON.parse(json))}, addEventListener() {}};
  const player = {loadVideoById:arg=>loads.push(arg), mute() {}, unMute() {},
    loadModule() {}, unloadModule() {}, stopVideo() {}};
  const document = {documentElement:element(), body:element(), createElement:element,
    getElementById:id=>elements.get(id), head:{appendChild() {
      assert.equal(typeof window.onYouTubeIframeAPIReady, 'function');
      window.onYouTubeIframeAPIReady();
    }}};
  runInNewContext(script, {window, document, YT:{Player:function(_, config) {
    options = config;
    return player;
  }}});
  return {window, options, messages, loads};
}

test('registers ready callback before loading API and does not restart initial video', () => {
  const state = boot();
  state.options.events.onReady();
  assert.equal(state.messages[0].event, 'Ready');
  assert.equal(state.loads.length, 0);
});
test('switching loads exactly once and preserves error/completion events', () => {
  const state = boot();
  state.window.__moonfinYtBridge.loadVideoById('zyxwvutsrqp');
  assert.equal(state.loads.length, 1);
  state.options.events.onError({data:153});
  state.options.events.onStateChange({data:0});
  assert.deepEqual(state.messages.map(({event,data,videoId})=>({event,data,videoId})), [
    {event:'PlayerError',data:153,videoId:'zyxwvutsrqp'},
    {event:'StateChange',data:0,videoId:'zyxwvutsrqp'},
  ]);
  assert.equal(state.loads.length, 1);
});
