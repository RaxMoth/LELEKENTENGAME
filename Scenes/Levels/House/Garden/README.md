# Defense area — the yard and the front door

On the raid night at the end of every 3-day cycle the police cross the open
yard in front of the house in squads — from cover to cover — and rush the
front door together. The player holds it with the gun in hand (bought at
the armory) from the front room or the porch, the house's roof turrets and
hired guards. If the door breaks, the shift is lost. On selling days the
yard stays quiet.

## What this area owns

| Files | What |
|---|---|
| `FrontGarden.tscn`, `front_garden.gd` | The front: yard, door, porch, turrets, Security PC, guards, director; firing the equipped gun or striking with fists / a blade (headset swings, `MeleeMath`) and showing its model, raid hooks |
| `Yard` (`yard.gd`, in `FrontGarden.tscn`) | The open field: obstacles (x, z, radius, kind) → trees, pines, rocks, bushes, a car, the fence; raider registry, picking, line of sight (`is_shot_blocked`), door spots |
| `Raider.tscn`, `raider.gd` + `Cop/Swat/RamTeam.tscn` | Raiders; StateChart Alive { Moving ⇄ InCover, Attacking } → Dead; tune with exports (health, armor, speeds, cover times, door damage, `is_battering_ram`) |
| `raid_squad.gd` | `RaidSquad`: leapfrogging from cover to cover, gathering, the rush |
| `raider_body.gd` (`RaiderBody`) | The jointed raider body (uniform, vest, headgear, what it carries) built from exports, animated procedurally (walk, crouch, strike) |
| `attacker_director.gd` | Sends each raid wave through the town: squads from different directions along their own street routes (`Scripts/Game/street_routes.gd`, unit-tested), vehicles to the curb / the street in front / over the roofs; door spots, counts who is left |
| `Vehicles/` (`PoliceVehicle` + `SquadCar`, `ArmoredVehicle`, `PoliceHelicopter`) | Vehicles are Raiders to the rest of the game (registry, hits, wave count) but drive their route and do their own job: unload cops, shell the door, circle and drop SWAT |
| `crowd_lod.gd` (`CrowdLod`, in `FrontGarden.tscn`) | Draws far-away officers as simple figures in two MultiMeshes (a horde of 50 stays a few draw calls) |
| `Towers/` (`TowerField`, `FieldTower`, `TowerKit`, `TowerBoard`) | The tower depot by the porch, kits, building towers anywhere outside, the four tower kinds (a `FieldTower` is a `HouseTurret` on a post), upgrades, per-kind models built by `TowerModelBuilder` (`Scripts/Utils/`); data in `Ressources/Towers/`, saved in `Profile.towers` (`Scripts/Game/tower_placements.gd`, unit-tested) |
| `MonitorWall.tscn`, `monitor_wall.gd`, `TurretMonitor.tscn`, `turret_monitor.gd` | The office's monitor wall (Monitor Wall upgrade): four live turret views to switch, take over, aim and fire |
| `HouseTurret.tscn`, `house_turret.gd` | Roof turrets (Roof Turrets upgrade): auto-aim at visible raiders, or manual from the PC |
| `SecurityPc.tscn`, `security_pc.gd`, `TurretConsole.tscn`, `turret_console.gd` | The office desk PC (Security PC upgrade): live turret camera, take control, aim, fire |
| `Phone/` (`Phone`, `PhoneScreen`, `PhoneMapView`) | The player's phone (B / Y, M): the town map with the police and towers (`MapProjection`, unit-tested) and the weapons app (take any owned weapon) |
| `TurretSeat.tscn`, `turret_seat.gd` | "VR in VR": the goggles beside the PC put the player into a turret (head at its camera, barrel follows the hand, triggers fire); `TurretHud` (`TurretHudStatus.tscn` / `TurretHudControls.tscn`) is its overlay: status, previous / next turret, take off |
| `FrontDoor.tscn`, `front_door.gd` (+ `Scripts/XR/hinge_handle.gd`) | The objective and the way out: trigger or grip a handle to swing it, no lock; StateChart Closed ⇄ Open. Open in a raid, the raiders walk in (`FrontGarden._let_raiders_through_open_door`) |
| `BeamTracer.tscn` | Pooled shot tracer |
| `../Armory/` (+ `Guns/`) | The armory terminal and the animated gun models — also this area |
| `Ressources/Weapons/`, `Ressources/Raids/` | Gun and raid data |
| `Ressources/Upgrades/Defense/` | Defense upgrades (door, rounds, turrets, Security PC, guards) + `defense_upgrades.tres` |
| `Scripts/Game/yard_navigation.gd` | Pure movement rules (unit-tested in `Tests/Unit/yard_navigation_test.gd`) |
| `Tests/Smoke/defense_checks.gd` | This area's smoke checks |

## What it uses from outside

`context.operation` (`get_upgrade_value / get_upgrade_level` for
`Types.UPGRADE_DOOR / BLASTER / TURRETS / SECURITY_PC / SECURITY`),
`context.cycle` (spawn interval of raid waves), `context.rig` (trigger
actions, pointers, haptics, the gun anchor, the `WalkableArea` for the
porch and doorway), `Profile.armory` (the equipped gun and its ammo). The
House level calls the raid hooks (`on_raid_started`, `on_raid_wave_started`,
`get_raiders_left`, `remove_raiders`) through `HouseCycle`. Nothing else.
The Security PC stands on the office desk but belongs to this front.

## Adding things

- **Raider:** inherited scene of `Raider.tscn` with its exports, an export
  on `AttackerDirector`, a count on `RaidWave` and its escalation in
  `RaidData` / `RaidPlanner` (unit-tested in `Tests/Unit/raid_cycle_test.gd`).
- **Cover:** add a `Vector4(x, z, radius, kind)` to the Yard's `obstacles`
  in `FrontGarden.tscn` (kinds: pine, tree, rock, bush, car).
- **Gun / blade:** a `GunModel` scene in `../Armory/Guns/` (or a
  `MeleeModel` in `../Armory/Melee/`) and a `WeaponData` in
  `Ressources/Weapons/` pointing at it (kind, `required_weapon_id`); add it
  to `weapon_catalog.tres` in shop order.
- **Turret mount:** another `HouseTurret` under `Turrets` with the next
  `mount_level`, and raise `def_turrets.tres`'s `max_level`.
- **Upgrade:** `UpgradeData` in `Ressources/Upgrades/Defense/`, add it to
  `defense_upgrades.tres`, id in the Defense block of `Types`.
