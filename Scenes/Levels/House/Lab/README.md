# Lab — production (part of the house area)

Grab ingredients from crates, grind, cook and press them; each step is a
timing skill check that sets the quality. The press packs a `ProductBag`;
carried to the stash shelf's drop crate (by the player or a crafter), its
units go into the shared stash. Motors jam now and then; crafters free them.

| Files | What |
|---|---|
| `Lab.tscn`, `lab.gd` | The front: stations, crates, crafters, recipe book; registers the recipes with the Operation |
| `RecipeBoard.tscn`, `recipe_board.gd` | The recipe book on the wall (static WorldScreen): every product, open, with what it still needs |
| `ShroomPlant.tscn`, `shroom_plant.gd` | The plants on the grow shelf (StateChart Growing ⇄ Ripe): grow shrooms on their own; ripe, a grab picks a ProductBag into the hand (carried to the stash crate), the auto picker harvests into the stash |
| `LabGuideBoard.tscn`, `lab_guide_board.gd` | The "How to cook" poster: plant, then grinder, cooker, press — dimmed until bought |
| `Workstation.tscn` + `Grinder/Cooker/Press.tscn`, `workstation.gd` | Stations (StateChart Idle ⇄ Running); a bought motor (`set_motorized`) finishes the skill check on its own |
| `lab_automation.gd` (the `Automation` node in `Lab.tscn`) | Conveyor belts (grinder → cooker → press) and the ingredient hopper; motors, belts and hopper are `UpgradeLook`s in `Lab.tscn` |
| `IngredientCrate.tscn`, `IngredientItem.tscn`, `BatchItem.tscn`, `ProductBag.tscn` | Crates and the items you carry (a packed bag goes to `StashShelf`'s drop crate) |
| `Ressources/Ingredients/`, `Ressources/Recipes/` | Ingredients and products (add recipes to `Lab.recipes`) |
| `Ressources/Upgrades/Lab/` | Production upgrades + `lab_upgrades.tres` catalog |
| `Scripts/Game/timing_gauge.gd`, `quality_math.gd` | Pure rules (unit-tested in `Tests/Unit/craft_math_test.gd`) |
| `Tests/Smoke/lab_checks.gd` | Smoke checks |
