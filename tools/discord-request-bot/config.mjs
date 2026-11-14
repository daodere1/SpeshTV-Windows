export function config(env = process.env) {
  const requireValue = key => {
    const value = env[key]?.trim();
    if (!value || value.startsWith('your_') || value === 'paste_connection_token_here') throw new Error(`Set ${key} in .env.`);
    return value;
  };
  const ids = value => (value ?? '').split(',').map(s => s.trim()).filter(Boolean);
  const channels = ids(requireValue('ALLOWED_CHANNEL_IDS'));
  const roles = ids(env.ALLOWED_ROLE_IDS);
  const guild = requireValue('DISCORD_GUILD_ID');
  const application = requireValue('DISCORD_APPLICATION_ID');
  if (![guild, application, ...channels, ...roles].every(id => /^\d{17,20}$/.test(id))) throw new Error('Server, application, channel, and role IDs must be numeric Discord IDs.');
  const bridgeUrl = new URL(env.SPESHTV_BRIDGE_URL || 'http://127.0.0.1:47653');
  if (bridgeUrl.protocol !== 'http:' || !['127.0.0.1', 'localhost'].includes(bridgeUrl.hostname) || bridgeUrl.username || bridgeUrl.password) throw new Error('The bridge URL must use HTTP on localhost. Run the bot on the same PC as SpeshTV.');
  return { token: requireValue('DISCORD_TOKEN'), application, guild, channels, roles,
    bridgeToken: requireValue('SPESHTV_BRIDGE_TOKEN'), bridgeUrl: bridgeUrl.origin };
}
