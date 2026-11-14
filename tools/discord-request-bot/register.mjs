import { REST, Routes, SlashCommandBuilder } from 'discord.js';
import { config } from './config.mjs';

try {
  const cfg = config();
  const commands = [
    new SlashCommandBuilder().setName('request').setDescription('Select a movie or episode to play or queue in SpeshTV')
      .addStringOption(o => o.setName('title').setDescription('Movie or series title').setRequired(true).setMinLength(2).setMaxLength(100)),
    new SlashCommandBuilder().setName('queue').setDescription('Show the current SpeshTV item and upcoming requests'),
    new SlashCommandBuilder().setName('nowplaying').setDescription('Show what SpeshTV is playing'),
  ].map(command => command.toJSON());
  await new REST({ version: '10' }).setToken(cfg.token).put(Routes.applicationGuildCommands(cfg.application, cfg.guild), { body: commands });
  console.log('Registered /request, /queue, and /nowplaying in the configured server.');
} catch (error) {
  console.error('Command registration failed. Check .env, your bot token, application/server IDs, and bot installation.');
  process.exitCode = 1;
}
