import { Client, GatewayIntentBits, Events, MessageFlags } from 'discord.js';
import { config } from './config.mjs';
import { allowedMentions } from './logic.mjs';
import { createHandler } from './interaction-handler.mjs';

let cfg;
try { cfg = config(); } catch (error) { console.error(error.message); process.exit(1); }
const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const handle = createHandler(cfg);
const clip = (text, max = 1900) => String(text).slice(0, max);
client.on(Events.InteractionCreate, interaction => {
  handle(interaction).catch(async error => {
    const content = error instanceof Error ? error.message : 'Request failed. Check the bot and SpeshTV.';
    try {
      if (interaction.deferred || interaction.replied) await interaction.editReply({ content: clip(content, 1900), allowedMentions });
      else await interaction.reply({ content: clip(content, 1900), flags: MessageFlags.Ephemeral, allowedMentions });
    } catch { console.error('Could not deliver the command response. The interaction may have expired.'); }
  });
});
client.once(Events.ClientReady, () => console.log('SpeshTV request bot is online. Use /request in a configured channel.'));
client.on(Events.Error, () => console.error('Discord connection error. Check connectivity and your bot configuration.'));
process.on('SIGINT', () => { client.destroy(); process.exit(0); });
client.login(cfg.token).catch(() => { console.error('Discord login failed. Check the bot token and network connection.'); process.exitCode = 1; });
