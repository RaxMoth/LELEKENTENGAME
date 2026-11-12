# Armory (part of the defense area)

A terminal on the front room's back wall: spend the cash from the selling
days on guns and ammo for the raid at the end of the cycle.

| Files | What |
|---|---|
| `Armory.tscn`, `armory.gd` | The front: terminal screen, rack, sign; buys guns and ammo with `context.operation` cash |
| `ArmoryBoard.tscn`, `armory_board.gd` | The screen: a row per gun (buy / equip / in hand), an ammo row per owned gun |
| `Scripts/Resources/weapon_data.gd`, `weapon_catalog.gd` | Gun data; instances in `Ressources/Weapons/` |
| `Scripts/Game/weapon_loadout.gd` | Owned guns, ammo, the gun in hand (unit-tested in `Tests/Unit/weapon_loadout_test.gd`) |
| `Scripts/Profile/armory_progress.gd` | Saves the loadout (`Profile.armory`) |

The FrontGarden fires the equipped gun (`FrontGarden.fire_weapon`); the two
fronts share nothing but `Profile.armory` and the catalog resource.
The free pistol (cost 0, unlimited ammo) is always owned, so the player is
never unarmed in a raid.
