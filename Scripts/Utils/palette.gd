## Design tokens: the only colors gameplay code and new scenes should use.
## The UI theme (Assets/Themes/main_theme.tres) is built from the same values;
## see Docs/DESIGN.md for when to use which. Re-skinning a game starts here.
##
##   placeholder_mesh.color = Palette.ENEMY
##   FloatingText3D.spawn("+5", position, Palette.GOLD, effects_root)
##
## Dependencies: none
class_name Palette
extends RefCounted

# Surfaces, darkest to lightest.
const BACKGROUND: Color = Color("#0d1017")
const BACKGROUND_RAISED: Color = Color("#131824")
const SURFACE: Color = Color("#1a2030")
const SURFACE_RAISED: Color = Color("#242b3e")
const STROKE: Color = Color("#2e364b")

# Text.
const TEXT: Color = Color("#eef1f7")
const TEXT_MUTED: Color = Color("#8d96ac")
const TEXT_FAINT: Color = Color("#5b647b")

# Semantic.
const PRIMARY: Color = Color("#5b7cfa")
const SUCCESS: Color = Color("#2dbe78")
const WARNING: Color = Color("#f5b841")
const DANGER: Color = Color("#e5484d")

# Rewards.
const GOLD: Color = Color("#f5b841")
const GEM: Color = Color("#3cc8e8")
const STAR: Color = Color("#f7c548")
const XP: Color = Color("#3ddc97")

# Gameplay.
const PLAYER: Color = Color("#5b7cfa")
const ENEMY: Color = Color("#f06a6a")
const ENEMY_HEAVY: Color = Color("#c84755")
const ENEMY_FAST: Color = Color("#f59e4c")
const PROJECTILE: Color = Color("#ffe08a")
const WORLD: Color = Color("#151b28")
const WORLD_DETAIL: Color = Color("#1e2637")

# World lighting (day / night cycle). Muted on purpose: the world stays calm
# and dark enough for in-world UI to read in daylight too.
const SKY_DAY: Color = Color("#3d4c6b")
const SKY_DAY_HORIZON: Color = Color("#7d879e")
const SKY_NIGHT: Color = Color("#0d1017")
const SKY_NIGHT_HORIZON: Color = Color("#1a2030")
const DAYLIGHT: Color = Color("#fff1d6")
const MOONLIGHT: Color = Color("#8fa4d8")
const AMBIENT_DAY: Color = Color("#aab3c7")
const AMBIENT_NIGHT: Color = Color("#4b5675")

## Distinct, evenly bright hues for puzzle pieces, teams and categories.
const CATEGORY: Array[Color] = [
	Color("#f06a6a"),
	Color("#5b8dfa"),
	Color("#3ccf8e"),
	Color("#f5b841"),
	Color("#a37bf7"),
	Color("#3cc8e8"),
]
