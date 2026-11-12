# Defense area — the front garden

Tower defense in front of the house: attackers walk three lanes to the
front door; the player builds towers from the front room and shoots with
the blaster. If the door breaks, the shift is lost.

## What this area owns

| Files | What |
|---|---|
| `FrontGarden.tscn`, `front_garden.gd` | The front: board, door, build board, guards, director; building, blaster, theft, door → `shift_lost` |
| `attacker_director.gd` | Who comes when: junkies, patrols, raids (heat), mafia (night, reputation), boss wave |
| `LaneBoard.tscn`, `lane_board.gd`, `LaneGrid` | Lane math (no physics) |
| `Attacker.tscn` + `Junkie/Cop/Goon/Boss.tscn`, `lane_enemy.gd` | Attackers; tune with exports (health, speed, armor, tower resistance, theft) |
| `Turret.tscn`, `HeavyGun.tscn`, `Barricade.tscn`, `turret.gd`, `lane_defender.gd`, `LaneBolt.tscn` | Towers |
| `FrontDoor.tscn`, `front_door.gd` | The objective |
| `BuildBoard.tscn`, `TowerCard.tscn` | The board above the gate |
| `Ressources/Towers/` | Tower data (cost, cooldown, health, unlock) |
| `Ressources/Upgrades/Defense/` | Defense upgrades + `defense_upgrades.tres` catalog |
| `Tests/Smoke/defense_checks.gd` | This area's smoke checks |

## What it uses from outside

`context.operation` (cash for towers, heat for raids, `lose_stock` for
theft, `get_upgrade_value(Types.UPGRADE_DOOR / BLASTER / SECURITY)`),
`context.day_cycle` (night, boss hour), `context.rig` (trigger actions,
pointers, haptics). Nothing else.

## Adding things

- **Attacker:** inherited scene of `Attacker.tscn`, add it to
  `AttackerDirector` (export + spawn rule).
- **Tower:** scene extending `LaneDefender` / `Turret` + a `TowerData` in
  `Ressources/Towers/`, add it to `FrontGarden.towers`.
- **Upgrade:** `UpgradeData` in `Ressources/Upgrades/Defense/`, add it to
  `defense_upgrades.tres`, id in the Defense block of `Types`.
