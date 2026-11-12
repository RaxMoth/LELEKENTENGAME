# Lab — production (part of the house area)

Grab ingredients from crates, grind, cook and press them; each step is a
timing skill check that sets the quality. Product goes into the shared stash.

| Files | What |
|---|---|
| `Lab.tscn`, `lab.gd` | The front: stations, crates, crafters, recipe book; registers the recipes with the Operation |
| `RecipeBoard.tscn`, `recipe_board.gd` | The recipe book on the wall (static WorldScreen): question marks until a product is first cooked, saved in `Profile.operation.discovered_recipe_ids` |
| `Workstation.tscn` + `Grinder/Cooker/Press.tscn`, `workstation.gd` | Stations (StateChart Idle ⇄ Running) |
| `IngredientCrate.tscn`, `IngredientItem.tscn`, `BatchItem.tscn` | Crates and the items you carry |
| `Ressources/Ingredients/`, `Ressources/Recipes/` | Ingredients and products (add recipes to `Lab.recipes`) |
| `Ressources/Upgrades/Lab/` | Production upgrades + `lab_upgrades.tres` catalog |
| `Scripts/Game/timing_gauge.gd`, `quality_math.gd` | Pure rules (unit-tested in `Tests/Unit/craft_math_test.gd`) |
| `Tests/Smoke/lab_checks.gd` | Smoke checks |
