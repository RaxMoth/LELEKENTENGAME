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
  for visual changes and which shared files (contract, hotspots) were
  touched.
- **CI** (`.github/workflows/tests.yml`) runs the unit tests and the smoke
  test on Linux for every PR and every push to `main`.
- **Review:** the other person reviews (Claude can do a first pass with the
  `godot-reviewer` agent or `/code-review`, but a human approves).
- **Merge:** squash-merge, then delete the branch. Pull `main` afterwards.

## Areas

The game is split into three areas with their own scenes, data, upgrades
and smoke checks, so whoever works on one doesn't edit the other's files.
How the areas talk to each other is the contract in
[`Scenes/Levels/House/README.md`](../Scenes/Levels/House/README.md); each
area folder has a README listing its files and how to add things.

| Area | Owns |
|---|---|
| **Defense** (tower defense in the front garden) | `Scenes/Levels/House/Garden/`, `Ressources/Towers/`, `Ressources/Upgrades/Defense/`, `Tests/Smoke/defense_checks.gd` |
| **Customers** (the back sales window) | `Scenes/Levels/House/Sales/`, `Ressources/Customers/`, `Ressources/Upgrades/Sales/`, `Scripts/Game/sales_math.gd`, `customer_order.gd`, `Tests/Smoke/sales_checks.gd` |
| **House** (lab, office, crew, the shift) | `Scenes/Levels/House/Lab/`, `Office/`, `Workers/`, `Surroundings/`, `day_cycle.gd`, `house_shell.gd`, `stash_shelf.gd`, `wrist_status.gd`, `Ressources/Ingredients/`, `Ressources/Recipes/`, `Ressources/Upgrades/Lab/` and `House/`, `Scripts/Game/timing_gauge.gd`, `quality_math.gd`, `day_clock.gd`, `Tests/Smoke/lab_checks.gd`, `house_checks.gd` |

With two people and three areas, one of you usually holds two. Agree who
owns which for the current milestone, name the area in each PR, and tell
Claude which area a task is in (`CLAUDE.md` asks it to stay inside it).
Working in the other person's area is fine — say so first, so you don't
both change the same file.

Everything outside the three areas is shared. Change it in a small PR of
its own and tell the other person:

- **The contract:** `house_front.gd`, `house_context.gd`, `operation.gd`
  (with its rules `Scripts/Game/stash.gd`, `heat_meter.gd`),
  `house_level.gd`, `House.tscn`. A front that needs something new from
  another area (a value in `Operation`, a new hook) gets it here.
- **The foundation:** XR (`Scripts/XR/`, `Scenes/Entities/XRPlayerRig/`,
  `Scenes/Game/LevelBase/`), menus and UI kit (`Scenes/Menus/`,
  `Scenes/UI/`, `Scripts/UI/`, `Assets/Themes/`), autoloads (`Globals/`)
  and tooling (`Tools/`, `Tests/smoke_test.gd`, CI).

## Shared hotspots

These files are touched by almost every feature. Keep edits small, put
them in the right place, and expect to merge by hand now and then.

| File | Why it conflicts | How to stay out of trouble |
|---|---|---|
| `Scenes/Levels/House/House.tscn` | Places the house shell and all four fronts | Work inside your front's scene (`FrontGarden.tscn`, `SalesWindow.tscn`, `Lab.tscn`, `Office.tscn`). Touch `House.tscn` only to place a front or move the house, and don't both do that in parallel. |
| `Ressources/game_config.tres` | Lists (`achievements`, `levels`) are single lines | A new upgrade goes into your area's catalog (`Ressources/Upgrades/<Area>/<area>_upgrades.tres`), not here. For the other lists, add the resource as its own `.tres` file; on a conflict keep **both** sides' entries. |
| `Globals/types.gd` | Everyone adds constants | Upgrade ids and StateChart events have a block per area; add yours at the end of your area's block. On a conflict keep both. |
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
