import { randomUUID } from 'node:crypto';

export const allowedMentions = { parse: [], users: [], roles: [], repliedUser: false };
export function allowed(interaction, cfg) {
  if (interaction.guildId !== cfg.guild || !cfg.channels.includes(interaction.channelId)) return false;
  if (!cfg.roles.length) return true;
  const memberRoles = interaction.member?.roles;
  return cfg.roles.some(id => Array.isArray(memberRoles) ? memberRoles.includes(id) : memberRoles?.cache?.has(id));
}
export function label(item) {
  const year = item.year ? ` (${item.year})` : '';
  const episode = item.type === 'Episode' ? ` — ${item.season == null ? '' : `S${String(item.season).padStart(2, '0')}`}${item.episode == null ? '' : `E${String(item.episode).padStart(2, '0')}`}` : '';
  return `${item.type === 'Episode' && item.series ? `${item.series} — ` : ''}${item.name}${year}${episode}`;
}
export class Choices {
  constructor(now = () => Date.now()) { this.now = now; this.entries = new Map(); }
  add(user, state) {
    this.sweep();
    if (this.entries.size >= 200) this.entries.delete(this.entries.keys().next().value);
    const id = randomUUID();
    this.entries.set(id, { ...state, user, expires: this.now() + 10 * 60_000, busy: false });
    return id;
  }
  get(id, user) {
    const state = this.entries.get(id);
    if (!state || state.expires <= this.now()) { this.entries.delete(id); throw new Error('This selection expired. Run /request again.'); }
    if (state.user !== user) throw new Error('Only the person who requested this selection can use it.');
    return state;
  }
  sweep() { for (const [id, value] of this.entries) if (value.expires <= this.now()) this.entries.delete(id); }
}
export async function bridge(cfg, path, data, fetchImpl = fetch) {
  const url = new URL(path, cfg.bridgeUrl);
  if (data && path !== '/request') for (const [key, value] of Object.entries(data)) url.searchParams.set(key, String(value));
  let response;
  try {
    response = await fetchImpl(url, { method: path === '/request' ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${cfg.bridgeToken}`, 'Content-Type': 'application/json' },
      body: path === '/request' ? JSON.stringify(data) : undefined,
      redirect: 'error', signal: AbortSignal.timeout(90_000) });
  } catch {
    throw new Error('Cannot reach SpeshTV. Open the app on this PC, sign in, and enable chat requests. If submitting a request timed out, check /queue before retrying.');
  }
  let result;
  try { result = await response.json(); } catch { throw new Error('SpeshTV returned an invalid response.'); }
  if (!response.ok) throw new Error(result.error || 'SpeshTV could not complete the request.');
  return result;
}
