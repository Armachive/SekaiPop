# The Apps screen's order: A to Z, or most used

The Apps screen can list the apps you open most first, instead of A to Z. Issue
[#94](https://github.com/Blapples/SekaiPop/issues/94).

## Using it

- **Settings > General > Launcher & lock > Apps order:** *A to Z* (the default) or
  *Most used*. The setting is `launcher.order` (`az` | `used`).
- With *Most used*, the apps you have opened lately come first, most used at the top. Every
  app you have never opened (or not for months) follows, A to Z.
- Searching still ranks by how well the name matches. *Most used* only decides between two
  equally good matches, so with Firefox opened daily, typing `f` puts it before Files.
- From a script: `qs -c sekaipop ipc call options set launcher.order used` (or `az`).

## What counts

- An app opened from the Apps screen: clicked, or Enter on a pick or on the first match.
- Not counted: the dock's icons and anything started outside the shell (a terminal, a
  keybind). The dock already keeps its own apps at hand.
- The order moves on the next time the Apps screen opens, not as you launch: re-sorting
  there and then would shuffle the tiles while the phone slides away.

## How the score works

Each app keeps one number that halves every 14 days, and a launch adds 1 to it. So an app
opened every day for a month and then dropped sinks below one opened every day this week,
which a plain launch count could never do. Every score decays at the same rate, so the
order doesn't change just because time passes, and nothing needs a timer.

Apps whose score has fallen below about one launch eleven weeks ago are forgotten, and the
store keeps at most 200 apps.

## Where it lives

- `~/.local/state/sekaipop/app-usage.json` (`$XDG_STATE_HOME` if set):
  `{ "<desktop id>": { "s": <score>, "t": <ms of the last launch> } }`. Deleting it starts
  over. Switching back to *A to Z* keeps counting, so *Most used* is ready when you come back.
- `modules/common/functions/AppUsage.js`: the score, the order and the file format (no QML;
  `tests/app-usage-test` runs it in node).
- `services/AppSource.qml`: counts in `launch()`, loads and saves through
  `scripts/state/app-usage-state.sh`, and hands the grid `ordered`. `rankEntries()` uses
  the score to break ties.
- `modules/sekai/launcher/LauncherFace.qml`: the grid shows `source.ordered` while nothing
  is typed.
