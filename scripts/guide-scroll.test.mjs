import {readFileSync} from 'node:fs';
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {runInNewContext} from 'node:vm';

const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const script = html.match(/<script id="speshtv-surface-scroll">([\s\S]*?)<\/script>/)[1];
function gesture({route='#/live-tv/guide', tags=['CANVAS','FLT-GLASS-PANE'], touches=1, cancelable=true, editable=false}={}) {
    let handler, options, prevented=false;
    runInNewContext(script, {window:{location:{hash:route}}, document:{addEventListener(name, fn, config) {
        assert.equal(name,'touchmove'); handler=fn; options=config;
    }}});
    assert.equal(options.passive,false);
    assert.equal(options.capture,true);
    handler({cancelable,touches:Array(touches).fill({}),composedPath:()=>tags.map(tagName=>({tagName,isContentEditable:editable})),
        preventDefault(){prevented=true;}});
    return prevented;
}
test('the root viewport cannot rubber-band independently of Flutter', () => {
    assert.match(html,/html,\s*body\s*\{[^}]*overflow: hidden;[^}]*overscroll-behavior: none;/);
});
test('all Flutter screens consume one-finger native scrolling, including Home and libraries', () => {
    for (const route of ['#/home','#/library/example','#/library/example?sort=Name','#/search',
        '#/live-tv/guide','#/live-tv/guide?channel=5','#/live-tv/player','#/settings','']) {
        assert.equal(gesture({route}),true,route);
    }
});
test('native controls, editing, pinch zoom and uncancelable events remain untouched on every screen', () => {
    for (const route of ['#/home','#/library/example','#/search','#/live-tv/player']) {
        for (const tag of ['INPUT','TEXTAREA','SELECT','VIDEO','AUDIO','IFRAME']) {
            assert.equal(gesture({route,tags:[tag,'FLUTTER-VIEW']}),false,`${route}:${tag}`);
        }
        for (const scenario of [{editable:true},{touches:2},{touches:0},{cancelable:false},{tags:['DIV','BODY']}]) {
            assert.equal(gesture({route,...scenario}),false);
        }
    }
});
test('only the Flutter surface suppresses native scrolling; ordinary DOM stays scrollable', () => {
    for (const tag of ['FLUTTER-VIEW','FLT-GLASS-PANE','CANVAS']) {
        assert.equal(gesture({tags:['SPAN',tag,'BODY']}),true,tag);
    }
    assert.equal(gesture({tags:['SPAN','DIV','BODY','HTML']}),false);
});
