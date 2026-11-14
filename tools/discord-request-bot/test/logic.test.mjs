import test from 'node:test';
import assert from 'node:assert/strict';
import { config } from '../config.mjs';
import { allowed, label, Choices, bridge, allowedMentions } from '../logic.mjs';

const env = { DISCORD_TOKEN: 'fake-token', DISCORD_APPLICATION_ID: '111111111111111111', DISCORD_GUILD_ID: '222222222222222222',
  ALLOWED_CHANNEL_IDS: '333333333333333333', ALLOWED_ROLE_IDS: '', SPESHTV_BRIDGE_TOKEN: 'fake-bridge-token' };
test('configuration requires valid IDs and localhost bridge', () => {
  assert.equal(config(env).bridgeUrl, 'http://127.0.0.1:47653');
  assert.throws(() => config({ ...env, ALLOWED_CHANNEL_IDS: '' }));
  assert.throws(() => config({ ...env, SPESHTV_BRIDGE_URL: 'https://example.com' }));
});
test('only configured server, channel, and role can request', () => {
  const cfg = config(env);
  const user = { guildId: cfg.guild, channelId: cfg.channels[0], member: { roles: ['444444444444444444'] } };
  assert.equal(allowed(user, cfg), true);
  assert.equal(allowed({ ...user, channelId: 'other' }, cfg), false);
  assert.equal(allowed({ ...user, guildId: 'other' }, cfg), false);
  cfg.roles = ['444444444444444444'];
  assert.equal(allowed(user, cfg), true);
  assert.equal(allowed({ ...user, member: { roles: [] } }, cfg), false);
});
test('selection belongs to requester, expires, and preserves unique IDs', () => {
  let now = 1000;
  const store = new Choices(() => now);
  const id = store.add('one', { items: [{ id: 'first', name: 'Batman' }, { id: 'second', name: 'Batman' }] });
  assert.throws(() => store.get(id, 'other'));
  assert.equal(store.get(id, 'one').items[1].id, 'second');
  now += 10 * 60_000;
  assert.throws(() => store.get(id, 'one'));
});
test('labels distinguish title year and episode; bot responses never ping', () => {
  assert.equal(label({ name: 'Batman', year: 1989, type: 'Movie' }), 'Batman (1989)');
  assert.equal(label({ name: 'Pilot', series: 'Show', season: 2, episode: 3, type: 'Episode' }), 'Show — Pilot — S02E03');
  assert.deepEqual(allowedMentions.parse, []);
  assert.deepEqual(allowedMentions.roles, []);
});
test('bridge submits confirmed item ID and receipt and handles offline errors', async () => {
  let captured;
  const cfg = config(env);
  const result = await bridge(cfg, '/request', { itemId: 'unique-id', requestId: 'receipt' }, async (url, options) => {
    captured = { url, options };
    return { ok: true, json: async () => ({ action: 'queued' }) };
  });
  assert.equal(result.action, 'queued');
  assert.equal(captured.options.headers.Authorization, 'Bearer fake-bridge-token');
  assert.deepEqual(JSON.parse(captured.options.body), { itemId: 'unique-id', requestId: 'receipt' });
  await assert.rejects(bridge(cfg, '/status', null, async () => { throw new Error('offline'); }), /Cannot reach SpeshTV/);
});
