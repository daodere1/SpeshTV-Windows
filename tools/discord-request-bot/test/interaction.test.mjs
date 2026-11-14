import test from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from '../interaction-handler.mjs';

const cfg = { guild: 'guild', channels: ['channel'], roles: [] };
function interaction(type, customId = '', values = []) {
  return { user: { id: 'user' }, guildId: 'guild', channelId: 'channel', member: { roles: [] }, customId, values,
    commandName: 'request', options: { getString: () => 'Batman' },
    isChatInputCommand: () => type === 'command', isStringSelectMenu: () => type === 'select', isButton: () => type === 'button',
    async deferReply() { this.deferred = true; }, async deferUpdate() { this.deferred = true; },
    async editReply(reply) { this.response = reply; }, async reply(reply) { this.response = reply; } };
}
const selectorId = reply => reply.components[0].toJSON().components[0].custom_id;
test('movie selection does not play until confirmed, and submits exact selected ID', async () => {
  const calls = [];
  const handle = createHandler(cfg, { request: async (_, path, data) => {
    calls.push({ path, data });
    if (path === '/search') return { items: [{ id: 'old', name: 'Batman', year: 1989, type: 'Movie' }, { id: 'new', name: 'Batman', year: 2022, type: 'Movie' }] };
    if (path === '/status') return { active: false };
    return { action: 'queued', item: { id: data.itemId, name: 'Batman', type: 'Movie' } };
  }});
  const command = interaction('command');
  await handle(command);
  assert.equal(calls.some(call => call.path === '/request'), false);
  const select = interaction('select', selectorId(command.response), ['1']);
  await handle(select);
  assert.match(select.response.content, /2022/);
  assert.equal(calls.some(call => call.path === '/request'), false);
  const confirmId = select.response.components[0].toJSON().components[0].custom_id;
  const confirm = interaction('button', confirmId);
  await handle(confirm);
  assert.equal(calls.at(-1).data.itemId, 'new');
  assert.ok(calls.at(-1).data.requestId);
  assert.match(confirm.response.content, /Added to queue/);
});
test('series requires season then episode selection before submitting', async () => {
  const calls = [];
  const handle = createHandler(cfg, { request: async (_, path, data) => {
    calls.push({ path, data });
    if (path === '/search') return { items: [{ id: 'series', name: 'Show', type: 'Series' }] };
    if (path === '/seasons') return { items: [{ id: 'season2', name: 'Season 2', type: 'Season' }] };
    if (path === '/episodes') return { items: [{ id: 'episode3', name: 'Pilot', type: 'Episode', season: 2, episode: 3 }] };
    if (path === '/status') return { active: true };
    return { action: 'queued', item: { id: data.itemId, name: 'Pilot', type: 'Episode' } };
  }});
  let current = interaction('command');
  await handle(current);
  for (let step = 0; step < 3; step++) {
    const next = interaction('select', selectorId(current.response), ['0']);
    await handle(next);
    current = next;
  }
  assert.equal(calls.find(call => call.path === '/episodes').data.seasonId, 'season2');
  assert.equal(calls.some(call => call.path === '/request'), false);
  const confirm = interaction('button', current.response.components[0].toJSON().components[0].custom_id);
  await handle(confirm);
  assert.equal(calls.at(-1).data.itemId, 'episode3');
});
test('unapproved channel is rejected before library access', async () => {
  const handle = createHandler(cfg, { request: async () => { throw new Error('must not call'); } });
  const command = interaction('command');
  command.channelId = 'other';
  await handle(command);
  assert.match(command.response.content, /not enabled/);
});
