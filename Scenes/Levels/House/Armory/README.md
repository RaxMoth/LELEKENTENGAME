# Armory (part of the defense area)

A terminal on the front room's back wall: spend the cash from the selling
days on weapons and ammo for the raid at the end of the cycle. A new player
has only fists; the terminal sells the knife, then the axe, then the pistol,
then the other guns (`WeaponData.required_weapon_id`).

| Files | What |
|---|---|
| `Armory.tscn`, `armory.gd` | The front: terminal screen, rack, sign; buys weapons and ammo with `context.operation` cash (only what's unlocked) |
| `ArmoryBoard.tscn`, `armory_board.gd` | The screen: a row per weapon (buy / equip / in hand / locked "Needs …"; no fists, no knife once the axe is owned unless in hand), an ammo row for the gun in hand |
| `weapon_model.gd`, `Guns/`, `Melee/` | The model in hand: `WeaponModel` base, `GunModel` (pistol, SMG, shotgun, rifle), `MeleeModel` (knife, axe) |
| `Scripts/Resources/weapon_data.gd`, `weapon_catalog.gd` | Weapon data (kind gun / melee, cost, unlock chain); instances in `Ressources/Weapons/` |
| `Scripts/Game/weapon_loadout.gd` | Owned weapons, ammo, the weapon in hand, what's for sale (unit-tested in `Tests/Unit/weapon_loadout_test.gd`) |
| `Scripts/Profile/armory_progress.gd` | Saves the loadout (`Profile.armory`) |

The FrontGarden uses the equipped weapon (`FrontGarden.fire_weapon` /
`strike`, swings in a headset); the two fronts share nothing but
`Profile.armory` and the catalog resource. The fists (cost 0) are always
owned, so the player is never unarmed in a raid.
