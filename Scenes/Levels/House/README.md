# The House — three areas, one contract

The level is split so that one developer can work on **defense**, another on
**customers** and another (or the same) on the **house**, without editing
the same files.

| Area | Scene + script | Data | Upgrades | Smoke checks |
|---|---|---|---|---|
| **Defense** (the yard and its raids, the door, roof turrets, the Security PC, the armory) | `Garden/FrontGarden.tscn` · `front_garden.gd` (+ yard, raiders, squads, director, door, turrets, PC), `Armory/Armory.tscn` | `Ressources/Weapons/`, `Ressources/Raids/`, raider exports in `Garden/*.tscn`, yard obstacles | `Ressources/Upgrades/Defense/` | `Tests/Smoke/defense_checks.gd` |
| **Customers** (back window and yard) | `Sales/SalesWindow.tscn` · `sales_window.gd` (+ `customer_flow.gd`, customers, sales board) | `Ressources/Customers/`, `CustomerFlow` exports | `Ressources/Upgrades/Sales/` | `Tests/Smoke/sales_checks.gd` |
| **House** (lab, office, stash, crew, the shift, the 3-day cycle) | `House.tscn` · `house_level.gd`, `Cycle/HouseCycle.tscn`, `Lab/Lab.tscn`, `Office/Office.tscn`, `Workers/`, `operation.gd`, `day_cycle.gd`, `house_shell.gd`, `StashShelf.tscn`, `SteelDoorFrame.tscn`, `Cellar/Cellar.tscn`, `Ghost/Ghost.tscn`, `Surroundings/Surroundings.tscn` (lawn, trees, weeds, junk) | `Ressources/Ingredients/`, `Ressources/Recipes/`, `Ressources/Renovations/`, `Lab.tscn` recipes | `Ressources/Upgrades/Lab/`, `Ressources/Upgrades/House/` | `Tests/Smoke/lab_checks.gd`, `cellar_checks.gd`, `house_checks.gd` |
| **Town** (the streets around the house, people in them, street talk) | `Town/Town.tscn` · `town.gd` (+ `pedestrian.gd`, `dialogue_board.gd`) | `Ressources/Town/town.tres`, `Ressources/Dialogue/`, voices in `Ressources/Voices/` (generated, see `Tools/generate_voices.ps1`) | — | `Tests/Smoke/town_checks.gd` |

Each area folder has its own README with the details.

## The contract

Every front (`FrontGarden`, `SalesWindow`, `Lab`, `Office`, `Armory`, `AdminPanel`, `Town`) extends
**`HouseFront`** and is its own scene, instanced once in `House.tscn`.

- At setup it receives a **`HouseContext`**: `level` (is a shift
  running?), `rig` (the player: pointers, signals, haptics), `operation`
  (shared state), `day_cycle` (time, day / night) and `cycle` (the 3-day
  cycle: `allows_customers()`, `is_raid_active()`).
- It talks back only through `HouseFront`'s signals:
  `announcement_requested`, `warning_requested`, `score_earned`,
  `shift_lost`.
- The House level calls its hooks: `setup`, `on_shift_started`,
  `process_shift` (→ `_shift_process`, `_refresh_displays`),
  `on_nightfall`, `apply_upgrades`, `finish_shift`, `get_status_line`, and
  through `HouseCycle` the raid hooks `on_raid_started`,
  `on_raid_wave_started(RaidWave)`, `get_raiders_left`, `remove_raiders`,
  `on_raid_cleared`.
- **Fronts never reference each other.** Everything shared goes through
  **`Operation`** (stash, heat, cash, prices, recipes, upgrade values).
  Crew live inside their front's scene; the House pays everyone in
  `Types.GROUP_CREW`.
- **Upgrades that change the look** go into the scene of the area that owns
  the part: an `UpgradeLook` node (`Scripts/Components/`) with the upgrade
  id and the level it shows from, its parts as children (the door's iron
  straps in `Garden/FrontDoor.tscn`, the steel frame in
  `SteelDoorFrame.tscn`, shelves and crates in `StashShelf.tscn`). The House
  level re-applies every look in `Types.GROUP_UPGRADE_LOOK` (and the
  shell's `ShellRenovation`s in `Ressources/Renovations/`) whenever upgrades
  change, on a co-op guest too — a front needs no code for it.
- **The house grows:** `HouseStages` (in `House.tscn`) builds the cabin or
  the full house from `Ressources/HouseLayouts/` by the level of "Extend the
  House". Anything an area keeps in the house's right side must have a
  place in the cabin too: an `UpgradePlacement` with a cabin marker (the
  office board, the stash shelf, the right turret, the second guard), or an
  upgrade that needs the house (the Security PC, the cellar).
- **Furniture:** a `WalkBlocker` child keeps the player out of a table,
  shelf or rack while it is shown (bought); the House level hands them to
  the walkable area whenever upgrades change.
- **More floors:** the player's `WalkableArea` can hold floors at other
  heights, ramps (stairs) and holes; the Cellar adds its own. A ground
  plane under the house leaves out every `GroundHole` (the cellar's
  stairwell), so the garden's lawn and the town's asphalt never cover it.

If a front needs something new from another area (a new value in
`Operation`, a new hook), make that change in a **small PR of its own**
and tell the other developer — that's the only place the areas meet.

## Shared files (change rarely, in small PRs)

`house_front.gd`, `house_context.gd`, `operation.gd`, `house_level.gd`,
`House.tscn` (only to place a front or move the house), `Globals/types.gd`
(each area has its own block — add at the end of yours),
`Ressources/game_config.tres` (lists the four upgrade catalogs; no need to
touch it for a new upgrade) and `Assets/Localization/translations.csv`
(append rows).
