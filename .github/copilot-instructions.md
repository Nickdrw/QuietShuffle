# QuietShuffle AI coding instructions

## Project overview
- World of Warcraft addon that mutes Solo Shuffle chat, captures filtered messages, and provides a UI for reviewing/reporting them.
- Load order is defined in [QuietShuffle.toc](QuietShuffle.toc); global addon table is created in [Core.lua](Core.lua).

## Architecture & data flow
- `Core.lua` initializes shared `addon` state, saved variables (`QuietShuffleSavedData`), and character-scoped history helpers. This file is the source of truth for shared tables like `addon.messages`, `addon.matchPlayers`, and `addon.sessionButtons`. Also defines `addon.CHAT_FILTER_EVENTS` and dedicated chat frame output logic.
- `Detection.lua` owns Solo Shuffle detection and session lifecycle. It watches PvP/scenario events, toggles filtering, persists sessions to `QuietShuffleSavedData.characters[characterKey].history`, and handles `PLAYER_LOGIN` initialization.
- `Filters.lua` registers chat event filters and stores messages. `addon.InterceptChatMessage()` returns `true` to suppress messages while saving metadata (sender, GUID, lineID, class). Includes deduplication logic to prevent duplicate captures from multiple hooks, wrapped in `pcall` for error resilience.
- `UI.lua` renders the history window, session list, and report UI. It reads from `addon.messages` (current session) and saved history and uses pooled rows in `addon.messageRows`.
- `Settings.lua` wires the settings panel, clears history, and provides the dedicated chat frame output configuration.
- `Slash.lua` wires `/qs` commands including test mode (`/qs test start|stop`), debug mode (`/qs debug on|off`), and chat frame output (`/qs chatframe <name>`).

## Key conventions & patterns
- Shared state lives on the `addon` table (from `local _, addon = ...`). Prefer attaching new state/functions there instead of globals.
- Sessions are stored per-character in `QuietShuffleSavedData.characters["Name-Realm"].history`; legacy migration happens in [Detection.lua](Detection.lua).
- Chat filtering is event-based: update or add events in `addon.CHAT_FILTER_EVENTS` (in [Core.lua](Core.lua)) and ensure `Filters.lua` handles the event payload.
- UI uses reusable frames (`addon.messageRows`, `addon.sessionButtons`) instead of recreating on refresh; follow this pattern to avoid leaks.
- Use `wipe(table)` instead of `table = {}` when clearing tables to preserve references.
- Wrap critical filter callbacks in `pcall` to prevent errors from permanently breaking chat filtering.

## Features
- **Message filtering**: Suppresses party, instance, say, yell, emote, and whisper messages during Solo Shuffle.
- **Message capture**: Stores filtered messages with metadata (sender, class, GUID, lineID, timestamp) for later review.
- **History UI**: Multi-character session browser with message display and player right-click menus.
- **Report integration**: Report players directly from captured messages using Blizzard's `C_ReportSystem`.
- **Chat bubbles**: Automatically disables chat bubbles during Solo Shuffle and restores them after.
- **Dedicated chat output**: Route addon messages to a specific chat tab (configurable via settings or `/qs chatframe <name>`).
- **Debug mode**: `/qs debug on` prints filter events with red highlighting for failures.
- **Test mode**: `/qs test start|stop` simulates Solo Shuffle for UI testing without being in a match.

## Developer workflows (WoW addon)
- There is no build step; install by placing the folder under `Interface/AddOns/QuietShuffle` and use `/reload` in-game after edits.
- Use `/qs` to inspect status, `/qs history` to open the UI, and `/qs test start|stop` to simulate a Solo Shuffle session for UI testing.
- Use `/qs debug on` to enable verbose filter logging; failures appear in red.

## API Reference
- **WoW UI Source**: https://github.com/Gethe/wow-ui-source — Mirror of Blizzard's UI code. Use this to verify API signatures, event payloads, frame templates, and find implementation patterns.
- Relies on WoW API: chat filters (`ChatFrame_AddMessageEventFilter`), PvP/scenario state (`C_PvP`, `C_Scenario`), and UI frames.
- Report UI integrates with `ReportFrame`/`C_ReportSystem` using chat line IDs when available (see [UI.lua](UI.lua)).

## Examples to follow
- Session lifecycle and persistence: [Detection.lua](Detection.lua).
- Message capture and metadata extraction: [Filters.lua](Filters.lua).
- History UI layout and row pooling: [UI.lua](UI.lua).
- Settings panel with input fields: [Settings.lua](Settings.lua).
