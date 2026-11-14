# SpeshTV Discord request bot

This bot runs on the same Windows PC as SpeshTV. It uses a local authenticated connection to the desktop app. No Jellyfin server plugin, media-server password in the bot, public HTTP endpoint, or port forwarding is needed.

## What it does

- `/request title: Batman` searches the active server's accessible library. The requester chooses the exact movie, or chooses a series, season, and episode. Nothing plays until they confirm.
- A confirmed request starts playback when SpeshTV is on standby. When playback is active, including paused playback, it appends to the current queue without interrupting.
- `/queue` shows the current title and the next 25 entries. `/nowplaying` shows the current title.
- Selection menus have 25 choices per page with previous/next buttons. Search returns up to 100 matches; narrow the title if needed. Selections expire after 10 minutes.
- Commands and menus are private to the requester. Bot responses never ping anyone. Playback-start webhook announcements can ping the optional role configured in SpeshTV; finished announcements never ping.

The app must remain open, signed in, and have chat requests enabled. This feature does not start or stop Discord screen sharing. Start your Discord stream yourself. Requests only play items already in your library; this does not download or acquire missing movies.

## 1. Prepare SpeshTV

1. Extract the **entire** portable ZIP into a folder. Keep `SpeshTV.exe`, DLLs, and `data` together. Run `SpeshTV.exe` and sign in.
2. Use the built-in video player, disable queue repeat, and enable automatic next-item playback. Requests enable automatic queue advance while accepted, but existing repeat settings still affect the queue.
3. Open **Settings → Integrations → Discord announcements**.
4. Configure the existing webhook and optional announcement role if desired. Turn on **Announce to Discord** when you are streaming.
5. Under **Discord chat requests**, turn on **Enable chat requests**, then click **Copy connection token**. Keep the token private. The endpoint is `http://127.0.0.1:47653`.

Both announcement and request toggles reset to off when you close SpeshTV. Saved webhook, optional role, and connection token stay in secure Windows account storage. Enable the toggles again on the next launch.

## 2. Install Node.js

Install Node.js **22.12 or later** from [nodejs.org](https://nodejs.org/en/download). A current LTS release is suitable. Open a new terminal after installation and check:

```powershell
node --version
npm.cmd --version
```

Node.js is required for the bot, not for SpeshTV itself.

## 3. Create and invite a Discord bot

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and create a **New Application**, for example `SpeshTV Requests`.
2. In **General Information**, copy the **Application ID**.
3. Open **Bot**. Create the bot if prompted, then use **Reset Token** / **Copy** to obtain its token. Keep it private. You do **not** need Message Content, Server Members, or Presence privileged intents; this bot uses slash commands and the Guilds intent only.
4. In **OAuth2 → URL Generator**, select the `bot` and `applications.commands` scopes. Grant **View Channels** and **Send Messages**, then open the generated invite URL and install the bot in your Discord server. Grant channel access in the stage/chat channel where requests will be used. Do not grant Administrator.
5. In Discord **User Settings → Advanced**, enable **Developer Mode**. Right-click the server and use **Copy Server ID**. Right-click each request stage/text channel and use **Copy Channel ID**.
6. Optional: copy a requester role ID from the server's role settings if only that role should be able to request. This role is separate from the announcement-ping role.

See Discord's [slash-command registration guide](https://discordjs.guide/legacy/app-creation/deploying-commands) for the required application/server IDs and installation scope.

## 4. Configure the bot

Open a terminal in the bundled `Discord-Request-Bot` folder. Copy `.env.example` to `.env`, then edit `.env` in a text editor:

```powershell
Copy-Item .env.example .env
notepad .env
```

Fill in:

| Setting | Value |
| --- | --- |
| `DISCORD_TOKEN` | Bot token from the Developer Portal. This is not your user token or webhook URL. |
| `DISCORD_APPLICATION_ID` | Application ID from General Information. |
| `DISCORD_GUILD_ID` | Your Discord server ID. |
| `ALLOWED_CHANNEL_IDS` | Required: comma-separated stage/text channel IDs allowed to use commands. Example: `1556007978010681495`. |
| `ALLOWED_ROLE_IDS` | Optional: comma-separated role IDs allowed to request. Leave blank to allow all members who can use commands in the configured channels. |
| `SPESHTV_BRIDGE_TOKEN` | Connection token copied from SpeshTV settings. |
| `SPESHTV_BRIDGE_URL` | Keep `http://127.0.0.1:47653`. The bot must run on this PC. |

Install the exact dependencies in the supplied lockfile:

```powershell
npm.cmd ci
```

Alternatively, `Setup-Bot.cmd` creates `.env` if needed and installs dependencies. Edit `.env` before proceeding. Never upload `.env` or share a ZIP containing your configured copy. No secrets are shipped in this package.

## 5. Register commands and start

Register commands in your chosen Discord server (do this once, or after command definitions change):

```powershell
npm.cmd run register
```

Registration replaces the guild commands of this application. Use a dedicated bot application rather than an application already running other commands.

Then run:

```powershell
npm.cmd start
```

Or double-click **Start-Bot.cmd**. Keep its terminal open; Ctrl+C stops the bot. Once it says the bot is online, try `/nowplaying`, then `/request` in one of the configured channels. The bot can remain running while SpeshTV is closed; commands will explain that the app must be reopened and requests enabled.

## Confirmation and queue behavior

Choose by title, release year, and type. Episode labels also include season/episode numbers. Each choice retains the server's unique item ID, so identical titles are distinct. Confirming does not interrupt a current item: SpeshTV checks its current playback state at submission time and serializes simultaneous requests. Duplicate confirmation IDs are remembered in the running app, and items already in the upcoming queue are rejected.

Requests append to the current playback queue. Existing queued episodes or movies stay ahead of requests. A preloaded whole-season queue will finish those earlier entries first. The queue is the app's current in-memory queue, not a saved Jellyfin playlist; stopping playback or closing the app can clear it. Requests are not retained while SpeshTV is offline.

## Troubleshooting

- **Commands missing:** verify the application/server IDs, install with both scopes, run `npm.cmd run register`, and confirm Discord's Use Application Commands permission in the channel. Restart Discord if needed.
- **Requests not enabled for your role/channel:** check `ALLOWED_CHANNEL_IDS` and `ALLOWED_ROLE_IDS`; restart the bot after editing `.env`.
- **Cannot reach SpeshTV / unauthorized:** sign in, enable chat requests, and copy the connection token again. Run the bot on the same PC. Do not expose port 47653 to the network. If enabling fails, another copy of SpeshTV may already own that port.
- **No results:** search the active server's library with a more specific title. The logged-in user's server permissions and SpeshTV's parental controls apply. A different active server means different item IDs; search again after switching servers or users.
- **Playback does not start:** use SpeshTV's built-in player and test the item manually. Check server access and media availability. This connection does not launch a closed app or create a Discord stream.
- **Queue does not advance:** turn off repeat and turn on automatic next-item playback in the player.
- **A role mention appears but no notification:** the role must be in the webhook's server and permit mentions. Discord member notification settings also apply.
- **A request timed out:** check `/queue` before searching again. The original confirmation can be retried while its selection is valid; it uses the same confirmation ID.

## Validation and limits

Automated tests cover authorization, localhost restriction, menu ownership/expiry, exact movie selection, series/season/episode selection, explicit confirmation, role mention suppression, and playback completion behavior. Live bot registration, Discord interactions, and media playback with your server still require the setup smoke test above.

No bot application or token is pre-created. You supply those through `.env`. No Jellyfin server plugin installation is required.
