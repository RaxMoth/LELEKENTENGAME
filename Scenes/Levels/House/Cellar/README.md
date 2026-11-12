# Cellar — automation under the house (part of the house area)

Bought as "Dig the Cellar" in the office's Automation tab: the planks over
the opening in the stash-room floor come off, stairs lead down to a brick
cellar under the stash room and the office. Grow racks, grow lights and the
auto picker come with the next Automation upgrades.

| Files | What |
|---|---|
| `Cellar.tscn`, `cellar.gd` | The front (a `HouseFront`): the boarded opening, the cellar shell (a `HouseShell` with a ceiling opening), the stairs (`Stairs3D`), railing, lamps, racks and picker; adds the stairs (`WalkableRamp`), the cellar floor (`WalkableFloor`) and the stairwell hole to the player's `WalkableArea` once open |
| `GrowRack.tscn`, `grow_rack.gd` | A rack of four `ShroomPlant`s with one label; grow lights are an `UpgradeLook` in the rack |
| `AutoPicker.tscn`, `auto_picker.gd` | The gantry picker (StateChart Idle → Moving → Picking): harvests the nearest ripe plant into the stash |
| `Ressources/Upgrades/Lab/lab_cellar.tres` … `lab_auto_picker.tres` | Its upgrades (in the Lab catalog, branch `automation`) |
| `Tests/Smoke/cellar_checks.gd` | Smoke checks (stairs, racks, picker, the lab's motors, belts and hopper, perks) |

The stairwell is the rect `(1.0, 1.62) – (4.3, 2.62)` (x, z) in three places:
`House.tscn` (`HouseShell.floor_openings`), `Cellar.tscn` (the cellar
shell's `ceiling_openings` and the `StairwellHole` `GroundHole` that keeps
the lawn and the town's asphalt out of it) and `cellar.gd`
(`stairwell_hole`, the part the player can't stand on). Move them together.
