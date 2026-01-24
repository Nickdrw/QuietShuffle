# QuietShuffle AI coding instructions

## Project overview
- World of Warcraft addon that mutes Solo Shuffle chat, captures filtered messages, and provides a UI for reviewing/reporting them.
- Load order is defined in [QuietShuffle.toc](QuietShuffle.toc); global addon table is created in [Core.lua](Core.lua).

## Architecture & data flow
- `Core.lua` initializes shared `addon` state, saved variables (`QuietShuffleSavedData`), and character-scoped history helpers. This file is the source of truth for shared tables like `addon.messages`, `addon.matchPlayers`, and `addon.sessionButtons`.
- `Detection.lua` owns Solo Shuffle detection and session lifecycle. It watches PvP/scenario events, toggles filtering, and persists sessions to `QuietShuffleSavedData.characters[characterKey].history`.
- `Filters.lua` registers chat event filters and stores messages. `addon.InterceptChatMessage()` returns `true` to suppress messages while saving metadata (sender, GUID, lineID, class).
- `UI.lua` renders the history window, session list, and report UI. It reads from `addon.messages` (current session) and saved history and uses pooled rows in `addon.messageRows`.
- `Settings.lua` wires the settings panel and clears history via the shared helpers.
- `Slash.lua` wires `/qs` commands including test mode (`/qs test start|stop`).

## Key conventions & patterns
- Shared state lives on the `addon` table (from `local _, addon = ...`). Prefer attaching new state/functions there instead of globals.
- Sessions are stored per-character in `QuietShuffleSavedData.characters["Name-Realm"].history`; legacy migration happens in [Detection.lua](Detection.lua).
- Chat filtering is event-based: update or add events in `addon.CHAT_FILTER_EVENTS` (in [Core.lua](Core.lua)) and ensure `Filters.lua` handles the event payload.
- UI uses reusable frames (`addon.messageRows`, `addon.sessionButtons`) instead of recreating on refresh; follow this pattern to avoid leaks.

## Developer workflows (WoW addon)
- There is no build step; install by placing the folder under `Interface/AddOns/QuietShuffle` and use `/reload` in-game after edits.
- Use `/qs` to inspect status, `/qs history` to open the UI, and `/qs test start|stop` to simulate a Solo Shuffle session for UI testing.

## Integration points
- Relies on WoW API: chat filters (`ChatFrame_AddMessageEventFilter`), PvP/scenario state (`C_PvP`, `C_Scenario`), and UI frames.
- Report UI integrates with `ReportFrame`/`C_ReportSystem` using chat line IDs when available (see [UI.lua](UI.lua)).

## Examples to follow
- Session lifecycle and persistence: [Detection.lua](Detection.lua).
- Message capture and metadata extraction: [Filters.lua](Filters.lua).
- History UI layout and row pooling: [UI.lua](UI.lua).
