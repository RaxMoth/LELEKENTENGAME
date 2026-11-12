# Defense area — the front garden

Tower defense in front of the house: on the raid night at the end of every
3-day cycle the police walk three lanes to the front door in waves; the
player builds towers and shoots the gun in hand (bought at the armory) from
the front room or the porch. If the door breaks, the shift is lost. On
selling days the garden stays quiet.

## What this area owns

| Files | What |
|---|---|
| `FrontGarden.tscn`, `front_garden.gd` | The front: board, door, porch, build board, guards, director; building, firing the equipped gun, raid hooks, door → `shift_lost` |
| `attacker_director.gd` | Spawns the officers of each raid wave (`queue_wave`), counts who is left (`get_raiders_left`) |
| `LaneBoard.tscn`, `lane_board.gd`, `LaneGrid` | Lane math (no physics) |
| `Attacker.tscn` + `Cop/Swat.tscn` (and `Junkie/Goon/Boss.tscn`, not sent by the director), `lane_enemy.gd` | Attackers; tune with exports (health, speed, armor, tower resistance, theft) |
| `Turret.tscn`, `HeavyGun.tscn`, `Barricade.tscn`, `turret.gd`, `lane_defender.gd`, `LaneBolt.tscn` | Towers |
| `FrontDoor.tscn`, `front_door.gd` (+ `Scripts/XR/hinge_handle.gd`) | The objective and the way out: swing it by a handle, bolt it from either side; StateChart Closed { Unlocked ⇄ Locked } ⇄ Open |
| `BuildBoard.tscn`, `TowerCard.tscn` | The board above the gate |
| `../Armory/` | The armory terminal (guns, ammo) — also this area |
| `Ressources/Towers/`, `Ressources/Weapons/`, `Ressources/Raids/` | Tower, gun and raid data |
| `Ressources/Upgrades/Defense/` | Defense upgrades + `defense_upgrades.tres` catalog |
| `Tests/Smoke/defense_checks.gd` | This area's smoke checks |

## What it uses from outside

`context.operation` (cash for towers, `lose_stock` for theft,
`get_upgrade_value(Types.UPGRADE_DOOR / BLASTER / SECURITY)`),
`context.cycle` (spawn interval of raid waves), `context.rig` (trigger
actions, pointers, haptics, the `WalkableArea` for the porch and doorway),
`Profile.armory` (the equipped gun and its ammo). The House level calls the
raid hooks (`on_raid_started`, `on_raid_wave_started`, `get_raiders_left`)
through `HouseCycle`. Nothing else.

## Adding things

- **Raid officer:** inherited scene of `Attacker.tscn`, an export on
  `AttackerDirector`, a count on `RaidWave` and its escalation in `RaidData` /
  `RaidPlanner` (unit-tested in `Tests/Unit/raid_cycle_test.gd`).
- **Gun:** a `WeaponData` in `Ressources/Weapons/`, add it to
  `weapon_catalog.tres` (the armory lists it, the garden fires it).
- **Tower:** scene extending `LaneDefender` / `Turret` + a `TowerData` in
  `Ressources/Towers/`, add it to `FrontGarden.towers`.
- **Upgrade:** `UpgradeData` in `Ressources/Upgrades/Defense/`, add it to
  `defense_upgrades.tres`, id in the Defense block of `Types`.
