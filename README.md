# QuietShuffle

Tired of being rage‑baited during your games? QuietShuffle lets you play the way you want, the best you can, without getting disturbed by ragers. After the game, you can peacefully review messages and take action if necessary. Compatible with **TWW** and **Midnight**.

## Features
- Automatic Solo Shuffle detection and session tracking.
- Chat filtering with full message capture (nothing is lost).
- Per‑character session history.
- Lightweight history UI with efficient row reuse.
- Report workflow integration when line IDs are available.

## Commands
- `/qs` — Show status/help.
- `/qs history` — Open the history UI.
- `/qs test start` — Simulate a Solo Shuffle session (for UI testing).
- `/qs test stop` — End the simulated session.

## Installation
1. Copy the QuietShuffle folder into:
	- `World of Warcraft/_retail_/Interface/AddOns/`
2. In game, type `/reload` or restart the client.
3. Enable the addon from the character select screen if needed.

You can also download QuietShuffle from Wago.io or CurseForge.

## Usage
1. Queue for Solo Shuffle as usual.
2. During the match, Solo Shuffle chat is muted and captured in the background.
3. After the match, open `/qs history` to review messages and report if needed.

## Saved data
Session history is stored per character in `QuietShuffleSavedData`. Each character keeps a list of sessions and their captured messages.

## Support
If you run into issues or have feature requests, open an issue or make a pull request.
