# QuietShuffle AI Coding Instructions

## Project Overview
World of Warcraft addon that mutes Solo Shuffle chat, captures filtered messages, and provides a UI for reviewing and reporting them.

## Architecture

### File Responsibilities
| File | Purpose |
|------|---------|
| `Core.lua` | Shared state, utility functions, chat output logic. Source of truth for `addon.messages`, `addon.matchPlayers`, `addon.CHAT_FILTER_EVENTS`. |
| `Detection.lua` | Solo Shuffle detection, session lifecycle, `PLAYER_LOGIN` initialization, SavedVariables loading. |
| `Filters.lua` | Chat event filters, message capture logic. `InterceptChatMessage()` suppresses and stores messages. |
| `UI.lua` | History window, session list, message display, report UI. Uses pooled frames. |
| `Settings.lua` | Settings panel UI, chat tab dropdown. |
| `Slash.lua` | Slash command handling (`/qs`). |

### Load Order (from QuietShuffle.toc)
1. Libs (LibStub, LibDataBroker, LibDBIcon)
2. Core.lua
3. Filters.lua
4. UI.lua
5. Detection.lua
6. Slash.lua
7. Settings.lua

### Data Flow
- `QuietShuffleSavedData` is loaded during `PLAYER_LOGIN` in Detection.lua
- `addon.savedData` references `QuietShuffleSavedData` after login
- Sessions are stored per-character in `savedData.characters["Name-Realm"].history`
- Current session messages live in `addon.messages` (transient until match ends)

## Code Standards

### General Principles
- **Clarity over cleverness**: Write code that is easy to read and reason about.
- **Small, focused functions**: Each function should do one thing well.
- **Predictable control flow**: Avoid hidden side effects and unexpected state changes.
- **Minimal coupling**: Systems should be independent and not interfere with each other.
- **Explicit naming**: Variable and function names should describe their purpose.

### Critical Rules
1. **Never call `addon.Print()` from within `GetDedicatedChatFrame()`** — this causes infinite recursion.
2. **`GetDedicatedChatFrame()` must be side-effect free** — it returns a frame or nil, nothing else.
3. **SavedVariables are only available after `PLAYER_LOGIN`** — don't access them during file load.
4. **Wrap filter callbacks in `pcall`** — errors in filters permanently break chat.
5. **Use `wipe(table)` instead of `table = {}`** — preserves references held elsewhere.

### Chat Frame Handling
The chat tab selection feature must be:
- **Isolated**: No interference with Solo Shuffle detection or any other system.
- **Side-effect free**: `GetDedicatedChatFrame()` only returns a frame, never modifies state.
- **Validated separately**: `ValidateChatFrameSelection()` handles missing tabs with deferred notifications.

### Solo Shuffle Detection
Detection runs independently via:
- Periodic ticker (`C_Timer.NewTicker` every 5 seconds)
- Event-driven checks (`PLAYER_ENTERING_WORLD`, `PVP_MATCH_ACTIVE`, etc.)

Detection logic:
1. `IsSoloShuffleMatch()` checks C_PvP APIs, scenario info, and battlefield status
2. `CheckSoloShuffleStatus()` enables/disables filtering based on match state
3. `EnableMessageFiltering()` registers chat filters (once only)
4. `DisableMessageFiltering()` sets flag to false but keeps filters registered

## Patterns

### State Management
```lua
-- Shared state on addon table
addon.inSoloShuffle = false
addon.filteringEnabled = false
addon.messages = {}

-- Use wipe() to clear, not reassignment
wipe(addon.messages)
```

### Frame Pooling
```lua
-- Reuse frames instead of creating new ones
addon.messageRows = addon.messageRows or {}
local row = addon.messageRows[index] or CreateFrame(...)
addon.messageRows[index] = row
```

### Error Resilience
```lua
-- Wrap critical callbacks in pcall
local ok, result = pcall(function()
    -- risky code
end)
if not ok then
    return false  -- fail gracefully
end
```

## Testing

### Commands
- `/qs` — Show status and help
- `/qs history` — Open history window
- `/qs test start` — Simulate Solo Shuffle (for UI testing)
- `/qs test stop` — End test mode
- `/qs debug on|off` — Toggle verbose logging

### Verification
1. Enter Solo Shuffle → "Solo Shuffle started! Muting chat." should print
2. Chat messages should be suppressed and captured
3. Exit Solo Shuffle → "Solo Shuffle ended! Chat restored." should print
4. History should show captured messages

## Common Pitfalls

### Infinite Recursion
Functions that call `addon.Print()` must never be called FROM `addon.Print()`.
Bad: `GetDedicatedChatFrame()` calls `Print()` → `Print()` calls `GetDedicatedChatFrame()` → crash

### SavedVariables Timing
`QuietShuffleSavedData` is nil until `PLAYER_LOGIN`. Code that runs at file load cannot access it.

### Filter Registration
Filters should be registered once and controlled via `addon.filteringEnabled` flag. Adding/removing filters repeatedly can cause duplicates or missed messages.

## References
- **WoW UI Source**: https://github.com/Gethe/wow-ui-source
- **WoW API**: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
