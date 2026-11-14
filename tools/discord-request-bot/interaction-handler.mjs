import { MessageFlags, ActionRowBuilder, StringSelectMenuBuilder, ButtonBuilder, ButtonStyle } from 'discord.js';
import { randomUUID } from 'node:crypto';
import { allowed, allowedMentions, bridge, label, Choices } from './logic.mjs';

export function createHandler(cfg, { request = bridge, choices = new Choices() } = {}) {
const cooldowns = new Map();
const clip = (text, max = 100) => String(text).slice(0, max);
const button = (id, action, text, style = ButtonStyle.Secondary) => new ButtonBuilder().setCustomId(`spesh:${id}:${action}`).setLabel(text).setStyle(style);

function menu(id, state) {
  const page = state.page || 0;
  const items = state.items.slice(page * 25, (page + 1) * 25);
  if (!items.length) return { content: 'No matching items are available. Try a more specific title or another season.', components: [], allowedMentions };
  const selector = new StringSelectMenuBuilder().setCustomId(`spesh:${id}:select`).setPlaceholder(`Choose ${state.kind} (page ${page + 1})`).addOptions(items.map((item, index) => ({
    label: clip(label(item)), description: clip(`${item.type || state.kind} • ${item.year || 'Year unavailable'} • ID ${item.id}`), value: String(page * 25 + index),
  })));
  const nav = [button(id, 'cancel', 'Cancel')];
  if (page > 0) nav.unshift(button(id, 'prev', 'Previous page'));
  if ((page + 1) * 25 < state.items.length) nav.push(button(id, 'next', 'Next page'));
  return { content: `${state.heading || 'Select the exact title you want.'}${state.truncated ? '\nSearch is limited to 100 matches; narrow your title if needed.' : ''}`,
    components: [new ActionRowBuilder().addComponents(selector), new ActionRowBuilder().addComponents(...nav)], allowedMentions };
}

async function handle(interaction) {
  if (!(interaction.isChatInputCommand() || interaction.isStringSelectMenu() || interaction.isButton())) return;
  if (!allowed(interaction, cfg)) {
    await interaction.reply({ content: 'Requests are not enabled for your role or this channel.', flags: MessageFlags.Ephemeral, allowedMentions });
    return;
  }
  if (interaction.isChatInputCommand()) {
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    if (interaction.commandName === 'request') {
      const last = cooldowns.get(interaction.user.id) || 0;
      if (Date.now() - last < 5000) throw new Error('Wait a few seconds before searching again.');
      cooldowns.set(interaction.user.id, Date.now());
      if (cooldowns.size > 500) cooldowns.delete(cooldowns.keys().next().value);
      const result = await request(cfg, '/search', { query: interaction.options.getString('title', true) });
      const state = { items: result.items, kind: 'a movie or series', page: 0, truncated: result.truncated };
      const id = choices.add(interaction.user.id, state);
      await interaction.editReply(menu(id, choices.get(id, interaction.user.id)));
    } else {
      const status = await request(cfg, '/status');
      const current = status.current ? `${status.playing ? 'Now playing' : 'Paused or loading'}: ${label(status.current)}` : 'SpeshTV is on standby.';
      const upcoming = status.queue?.length ? `\n\nUpcoming:\n${status.queue.map((item, index) => `${index + 1}. ${label(item)}`).join('\n')}` : '\n\nThe queue is empty.';
      await interaction.editReply({ content: clip(current + (interaction.commandName === 'queue' ? upcoming : ''), 1900), allowedMentions });
    }
    return;
  }
  const [prefix, id, action] = interaction.customId.split(':');
  if (prefix !== 'spesh') return;
  const state = choices.get(id, interaction.user.id);
  if (state.busy) { await interaction.reply({ content: 'This selection is already being processed.', flags: MessageFlags.Ephemeral, allowedMentions }); return; }
  state.busy = true;
  await interaction.deferUpdate();
  try {
    if (action === 'cancel') {
      choices.entries.delete(id);
      await interaction.editReply({ content: 'Request cancelled.', components: [], allowedMentions });
    } else if (action === 'next' || action === 'prev') {
      state.page = Math.max(0, Math.min(Math.ceil(state.items.length / 25) - 1, state.page + (action === 'next' ? 1 : -1)));
      await interaction.editReply(menu(id, state));
    } else if (action === 'select') {
      const value = interaction.values[0];
      if (!/^\d+$/.test(value)) throw new Error('Invalid selection. Run /request again.');
      const item = state.items[Number(value)];
      if (!item) throw new Error('This selection is no longer available.');
      if (item.type === 'Series') {
        const result = await request(cfg, '/seasons', { seriesId: item.id });
        Object.assign(state, { seriesId: item.id, items: result.items, kind: 'a season', heading: `Choose a season of ${label(item)}.`, page: 0, truncated: false });
        await interaction.editReply(menu(id, state));
      } else if (item.type === 'Season') {
        const result = await request(cfg, '/episodes', { seriesId: state.seriesId, seasonId: item.id });
        Object.assign(state, { items: result.items, kind: 'an episode', heading: 'Choose the exact episode.', page: 0 });
        await interaction.editReply(menu(id, state));
      } else if (['Movie', 'Episode'].includes(item.type)) {
        state.selected = item;
        const status = await request(cfg, '/status');
        await interaction.editReply({ content: `Selected: ${label(item)}\n${status.active ? 'Confirm to add this item to the end of the queue.' : 'Confirm to start this item now.'}\nIf playback changes before confirmation, SpeshTV will queue it instead of interrupting.`,
          components: [new ActionRowBuilder().addComponents(button(id, 'confirm', status.active ? 'Add to queue' : 'Play now', ButtonStyle.Success), button(id, 'cancel', 'Cancel'))], allowedMentions });
      } else throw new Error('Select a movie, series, season, or episode.');
    } else if (action === 'confirm') {
      if (!state.selected) throw new Error('Select an item first.');
      state.requestId ||= randomUUID();
      const result = await request(cfg, '/request', { itemId: state.selected.id, requestId: state.requestId });
      choices.entries.delete(id);
      await interaction.editReply({ content: `${result.action === 'queued' ? 'Added to queue' : 'Started playing'}: ${label(result.item)}`, components: [], allowedMentions });
    }
  } finally { state.busy = false; }
}


return handle;
}
