# Getting and updating plugins

Settings > About / Update holds the plugins' own update and a way to get new ones, under the
shell's update: the core of [hako](https://github.com/masshirodev/hako.ranma), the plugin manager
of ranma. The design is the "Get and update plugins" page of the shared SekaiPop canvas (its
notes pm1 to pm4 are the decisions); this file says how it became code, where it departs from it,
and what it does not do yet. Writing a plugin is `docs/PLUGINS.md`.

## What the user sees

| Where                                   | What                                                                                     |
| --------------------------------------- | ---------------------------------------------------------------------------------------- |
| About / Update > **Plugins**            | how many repositories have updates; **Updates** (each with its commits, Update, Update all, then Updated and Go back); **Installed**, every plugin by where it came from; **Didn't load** |
| About / Update > **Get plugins**        | the **Reviewed list**, searched by name, word or tag, installed with one key; **From a URL**: Look reads a repository first, Install it anyway installs it |
| Desktop > Plugins                       | unchanged as the place to edit a plugin; each row says where it came from, how far behind it is, and has Update in About |
| A notification                          | one per batch of new commits, under the shell's own update rules; a click opens About on Plugins |

Where each plugin came from decides what can be done to it:

- **From a repository the shell installed** (it is in the lockfile): update, go back, pin, remove.
- **Managed by you**: the plugin's folder is a link to a folder of your own (a working clone).
  Never pulled, pinned or removed; only Open the folder.
- **Copied in by hand**: a real folder in the plugins folder. The same: never touched.

## The pieces

| File                                                        | What it does                                                                 |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `plugins.json` (the repository's root)                      | the reviewed list: `repo`, `description`, `tags`, `needs`, `sekaipop` (the oldest it works with) |
| `sekaipop/scripts/state/plugin-repos.sh`                    | everything git and the network: fetch the list, look, install (with progress), link, check, update, go back, remove, the lockfile |
| `sekaipop/modules/common/functions/PluginRepos.js`          | the rules: the list and its search, a typed source, where a plugin came from, the lockfile, updates, the notice, the words on the rows |
| `sekaipop/services/PluginRepoService.qml`                   | the state and the jobs (one at a time, a queue), the timed check and the notification |
| `sekaipop/modules/sekai/settings/SettingsPluginsUpdate.qml` | About > Plugins, with `PluginUpdateBox`, `PluginInstalledRow`, `PluginSourcePanel` (+ `PluginSourceRow`), `PluginRemoveAsk` |
| `sekaipop/modules/sekai/settings/SettingsGetPlugins.qml`    | About > Get plugins, with `PluginListEntry`, `PluginField`, `PluginNote`, `PluginMeter` |
| `PluginRow.qml`, `SettingsPluginsCard.qml`                  | Desktop > Plugins: the source line, the behind badge, Update in About         |
| `plugin-state.sh scan`, `PluginManifest.splitScan`          | each plugin folder's link target, which is how where it came from is known    |

Folders and files:

- `~/.local/share/sekaipop/plugin-repos/<owner>/<repo>`: the clones (`$XDG_DATA_HOME`).
- `~/.config/sekaipop/plugins/<id>`: a link per plugin folder of a clone (or your own folders).
- `~/.config/sekaipop/plugins-lock.json`: every repository the shell installed, its commit, the
  commit before its last update, pinned or not, reviewed or not, when, and its plugins.
- `~/.cache/sekaipop/plugins-list.json`: the last copy of the list, shown offline with its age.
- `~/.cache/sekaipop/plugin-updates-seen`: the batch of updates last announced.

`SEKAIPOP_PLUGIN_LIST` points the list elsewhere (a fork's, or a `file://` one for a test).

## How each action behaves

- **Install**: `git clone --progress` into the repos folder, its progress as the meter. Every
  `plugin.json` within three folders of the root is checked with `PluginManifest.parse`; every
  plugin folder is linked (a broken one too, so the scan lists it under Didn't load with its
  reason), the lockfile is written, the plugins are scanned again. "2 OF 3 INSTALLED" when one
  failed its check. A repository with no `plugin.json` keeps nothing. Then the next step, right
  there: turn the bar entry on, place the widget in Edit Desktop, its settings.
- **A repository on the reviewed list counts as reviewed** however it was installed (a URL, the
  ipc).
- **Look** (From a URL): a shallow clone into the cache, the plugins in it listed, the clone
  deleted. Nothing is installed until Install it anyway.
- **Check**: `git fetch` in each clone in the lockfile, then how many commits behind and those
  commits. When About / Update opens (if nothing has looked yet), on its key, and on the shell's
  own timer.
- **Update**: `git merge --ff-only` to upstream. Never a merge, never over local changes: a clone
  that can't move forward says so. The lockfile's `previous` is the commit it was really on.
- **Go back**: `git reset --hard` to `previous` (reset, not checkout: the branch stays, so the next
  update fast-forwards again). Going back twice swaps the two commits, which undoes it.
- **Pin**: updates skip the repository and say how many they skipped.
- **Remove**: its plugins come off the desktop and the bar, their links go, the clone is deleted.
  Their saved settings are kept (they come back on a reinstall) unless "Delete them too".
- **Restore** (`ipc call plugins restore`, no screen): every repository in the lockfile cloned if
  missing and moved to its commit. For a new machine with the old `~/.config`.

Nothing here ever asks for a password (`GIT_TERMINAL_PROMPT=0`, batch-mode ssh): a private or
missing repository fails with "no repository at … or it's private". Nothing is deleted outside
the repos folder: a repository's key is checked before it becomes a path.

## The notification

The shell's own update rules (`UpdateService.qml`): only while "Tell me about updates" is on,
50 s after the start and every "Look every" hours; one notification per batch (the same commits
never twice, new ones do), never for a look somebody asked for, and not in Game Mode (it waits
for the next look). Not the bar's Updates badge, which is system packages.

## Commands

```sh
qs -c sekaipop ipc call plugins install <owner/repo | git URL>
qs -c sekaipop ipc call plugins check
qs -c sekaipop ipc call plugins update [<repo>]          # "" = every repository with an update
qs -c sekaipop ipc call plugins goback <repo>
qs -c sekaipop ipc call plugins pin <repo> on|off
qs -c sekaipop ipc call plugins remove <repo> [keep|delete]
qs -c sekaipop ipc call plugins restore
qs -c sekaipop ipc call plugins open [get]               # Settings > About on Plugins (or Get plugins)
```

## Adding a plugin to the list

A pull request adding its entry to `plugins.json`, in order by repository, and the same plugin to
the README's list (between `<!-- plugin-list -->` markers; a test checks they match). Before it is
merged, someone reads the plugin's code: it does what its description says and nothing it does
not say, it loads in this SekaiPop, and its repository has a license and a README.

## Where it departs from the handoff, and why

- **The notification has no Show me / Later buttons.** The shell's notification server announces
  actions but draws none (`NotificationSource.qml`), so a click on the notification is Show me
  (its default action, opening About on the Plugins card) and dismissing it is Later.
- **Updated plugins run their new code from the next start of the shell.** A plugin's QML is
  loaded once, and plugin folders are not watched; the handoff's "Updated" did not know that. The
  Updates part says so once something has updated and offers Restart the shell (the same restart
  the shell's own update does).
- **"Before the last update" shows the commit, not "3 commits back"**: counting would mean asking
  git for every opened Source, for a number that says little.
- **From a URL does not read the README for needs** ("Its README mentions gh"): a repository off
  the list says nothing about what it needs, and the row says to check its README.
- **Reviewed list | From a URL is the shell's `SegmentSwitch`** (the clock's AM / PM switch), not
  a new segmented control; its labels are smaller than the board's.
- **The installed row's diamond is `PluginDiamond`** (the Plugins card's), the list's icon is
  `widgets` or `toolbar` by its tags (the list has no icons).

## What it does not do yet

- Restore from a screen (only the ipc).
- Show the commits a Go back would undo.
- Keep the clones of removed repositories for a later reinstall (a reinstall clones again).
- Update a repository that has local changes in its clone (it says so and stays where it is).
- A list other than `plugins.json` here (hako takes several lists; one is enough for now).
