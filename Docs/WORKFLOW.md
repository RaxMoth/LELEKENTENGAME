# Team workflow (two developers, each with Claude)

Two people work on this repository at the same time, each with their own
Claude Code sessions. The rules below keep you out of each other's way.
`CLAUDE.md` points every Claude session here, so both Claudes follow them
too.

## The short version

1. `main` always works and is never committed to directly.
2. Every task gets its own short-lived branch from an up-to-date `main`.
3. Changes reach `main` only through a pull request that passes CI and the
   other person has looked at.
4. Split work by area, and coordinate before touching a shared hotspot.
5. Pull `main` into your branch often; merge small PRs often.

## Branches

```bash
git switch main
git pull --ff-only
git switch -c anna/sales-loyalty      # <name>/<short-topic>
```

- Name: `<your-name>/<topic>` in lowercase with hyphens, e.g.
  `anna/sales-loyalty`, `ben/garden-traps`. The prefix shows at a glance
  whose branch it is; never push to the other person's branch unless
  asked.
- One task per branch. A branch that lives longer than 2–3 days collects
  conflicts; split the work into smaller PRs instead.
- Keep your branch current with `main` (at least daily, and always before
  opening a PR):

  ```bash
  git fetch origin
  git rebase origin/main              # or: git merge origin/main
  ```

  After a rebase, push with `git push --force-with-lease` (only on your own
  branch — never on `main`).

### One person, several Claude sessions

Run parallel Claude sessions on separate **git worktrees** (the Claude Code
app offers a worktree per session; on the command line
`git worktree add ../lelekente-garden -b ben/garden-traps`). Each worktree
is its own folder on its own branch with its own `.godot/` cache, so two
sessions — or a session and your open Godot editor — never write the same
files. Remove finished worktrees with `git worktree remove <folder>`.

## Pull requests

```bash
Tools/unit_tests.sh && Tools/smoke_test.sh     # both must exit 0
git push -u origin anna/sales-loyalty
gh pr create --fill                            # or ask Claude to open it
```

- The template asks what changed, which area, which tests ran, screenshots
  for visual changes and whether a shared hotspot was touched.
- **CI** (`.github/workflows/tests.yml`) runs the unit tests and the smoke
  test on Linux for every PR and every push to `main`.
- **Review:** the other person reviews (Claude can do a first pass with the
  `godot-reviewer` agent or `/code-review`, but a human approves).
- **Merge:** squash-merge, then delete the branch. Pull `main` afterwards.

## Areas

Agree on who owns which part of the game for the current milestone, so
day-to-day work rarely touches the same files. For example:

| Area | Folders |
|---|---|
| Lab & production | `Scenes/Levels/House/Lab/`, `Ressources/Ingredients/`, `Ressources/Recipes/` |
| Sales & customers | `Scenes/Levels/House/Sales/`, `Ressources/Customers/` |
| Garden & defense | `Scenes/Levels/House/Garden/`, `Ressources/Towers/` |
| Office, crew, economy | `Scenes/Levels/House/Office/`, `Scenes/Levels/House/Workers/`, `Ressources/Upgrades/`, `operation.gd` |
| XR foundation | `Scripts/XR/`, `Scenes/Entities/XRPlayerRig/`, `Scenes/Game/LevelBase/` |
| Menus & UI kit | `Scenes/Menus/`, `Scenes/UI/`, `Scripts/UI/`, `Assets/Themes/` |

Write the current split into the PR descriptions or an issue; change it
whenever it suits you. Working in the other person's area is fine — say so
first, so you don't both change the same file.

## Shared hotspots

These files are touched by almost every feature. Keep edits small, put
them in the right place, and expect to merge by hand now and then.

| File | Why it conflicts | How to stay out of trouble |
|---|---|---|
| `Scenes/Levels/House/House.tscn` | The whole level in one file | Build features as their own scenes (like `SalesWindow.tscn`, `Workstation.tscn`) and only add an instance here. Don't both rearrange the house in parallel. |
| `Ressources/game_config.tres` | Lists (`upgrades`, `achievements`) are single lines | Add new resources as their own `.tres` files; on a conflict keep **both** sides' entries in the list. |
| `Globals/types.gd` | Everyone adds constants | Add yours at the end of the matching section; on a conflict keep both. |
| `Assets/Localization/translations.csv` | Everyone adds strings | Append rows at the end. Git merges this file by keeping both sides' lines (`merge=union` in `.gitattributes`); check for duplicate keys afterwards. The `.translation` files are generated on import and not committed. |
| `project.godot` | The editor rewrites it | Change settings deliberately, one at a time; never commit incidental rewrites. |

### Godot rewrites files you didn't mean to change

Opening a project or a scene in the editor can rewrite `.import`,
`.tscn` and `.tres` files (new import parameters, `unique_id`s, reordered
lines). Before every commit look at `git status` / `git diff` and drop
changes you didn't make on purpose:

```bash
git restore path/to/file.import
```

Both of you should use the **same Godot version** (4.7.2) — a different
version rewrites many files at once.

### Resolving a scene conflict

`.tscn` and `.tres` files are text. On a conflict:

1. Keep both sides' new `[ext_resource]`, `[sub_resource]` and `[node]`
   blocks; make sure every `id` is unique and every `ExtResource("…")`
   points at an existing id.
2. For a property both sides changed, pick one value.
3. Open the scene in Godot, check it, save it, and run
   `Tools/smoke_test.sh` before committing the resolution.

Turn on `git config rerere.enabled true` so Git remembers resolutions you
already made once.

## Personal settings

Each person keeps personal Claude settings out of the repository:
`.claude/settings.local.json` and `CLAUDE.local.md` are ignored by Git.
Shared rules belong in `CLAUDE.md`, `Docs/` and `.claude/` (skills, the
reviewer agent, rules).
