# The House — three areas, one contract

The level is split so that one developer can work on **defense**, another on
**customers** and another (or the same) on the **house**, without editing
the same files.

| Area | Scene + script | Data | Upgrades | Smoke checks |
|---|---|---|---|---|
| **Defense** (tower defense in the front garden) | `Garden/FrontGarden.tscn` · `front_garden.gd` (+ `attacker_director.gd`, attackers, towers, door, build board) | `Ressources/Towers/`, attacker exports in `Garden/*.tscn`, `AttackerDirector` exports | `Ressources/Upgrades/Defense/` | `Tests/Smoke/defense_checks.gd` |
| **Customers** (back window and yard) | `Sales/SalesWindow.tscn` · `sales_window.gd` (+ `customer_flow.gd`, customers, sales board) | `Ressources/Customers/`, `CustomerFlow` exports | `Ressources/Upgrades/Sales/` | `Tests/Smoke/sales_checks.gd` |
| **House** (lab, office, stash, crew, the shift) | `House.tscn` · `house_level.gd`, `Lab/Lab.tscn`, `Office/Office.tscn`, `Workers/`, `operation.gd`, `day_cycle.gd`, `house_shell.gd` | `Ressources/Ingredients/`, `Ressources/Recipes/`, `Lab.tscn` recipes | `Ressources/Upgrades/Lab/`, `Ressources/Upgrades/House/` | `Tests/Smoke/lab_checks.gd`, `house_checks.gd` |

Each area folder has its own README with the details.

## The contract

Every front (`FrontGarden`, `SalesWindow`, `Lab`, `Office`) extends
**`HouseFront`** and is its own scene, instanced once in `House.tscn`.

- At setup it receives a **`HouseContext`**: `level` (is a shift
  running?), `rig` (the player: pointers, signals, haptics), `operation`
  (shared state) and `day_cycle` (time, day / night).
- It talks back only through `HouseFront`'s signals:
  `announcement_requested`, `warning_requested`, `score_earned`,
  `shift_lost`.
- The House level calls its hooks: `setup`, `on_shift_started`,
  `process_shift` (→ `_shift_process`, `_refresh_displays`),
  `on_nightfall`, `apply_upgrades`, `finish_shift`, `get_status_line`.
- **Fronts never reference each other.** Everything shared goes through
  **`Operation`** (stash, heat, cash, prices, recipes, upgrade values).
  Crew live inside their front's scene; the House pays everyone in
  `Types.GROUP_CREW`.

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
