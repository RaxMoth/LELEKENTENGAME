#!/usr/bin/env bash
# Captures every menu, popup and level at 720x1280 (opens a window, not
# headless) and builds contact sheets for a quick visual review. The XR level
# is also captured wide as xr_*.png (not part of the portrait sheets).
#   Tools/screenshots.sh [output_dir]   (default: build/screenshots)
set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-build/screenshots}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
# shot <name> <args...>; set SHOT_RESOLUTION for anything other than portrait.
shot() {
	local name="$1"; shift
	"$TOOLS_DIR/godot.sh" --resolution "${SHOT_RESOLUTION:-720x1280}" res://Tests/ScreenshotTool.tscn -- "$@" "out=$OUT_DIR/$name.png" >/dev/null 2>&1 || echo "failed: $name" >&2
}
MENU=res://Scenes/Menus/MainMenu/MainMenu.tscn
shot 01_main_menu scene=$MENU frames=120
shot 02_level_select scene=res://Scenes/Menus/LevelSelect/LevelSelect.tscn frames=90
shot 03_shop scene=res://Scenes/Menus/Shop/Shop.tscn frames=90
shot 04_settings scene=$MENU popup=res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn frames=60
shot 05_achievements scene=$MENU popup=res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn frames=60
for level in idle_tapper survivor tower_defense match3 runner; do
	shot "level_$level" "level=$level" frames=420
done
# The XR level in its flat simulator: portrait like the rest, then the wide
# view that is closer to a headset, and its pause menu on the in-world screen.
shot level_porchlight level=porchlight showcase=porchlight frames=200
SHOT_RESOLUTION=1280x720 shot xr_porchlight level=porchlight showcase=porchlight frames=200
SHOT_RESOLUTION=1280x720 shot xr_porchlight_pause level=porchlight showcase=porchlight frames=120 pause=1 world_ui=1
"$TOOLS_DIR/godot.sh" --headless --script "$TOOLS_DIR/contact_sheet.gd" -- "$OUT_DIR/sheet_menus.png" 5 360 \
	"$OUT_DIR"/0*.png >/dev/null 2>&1
"$TOOLS_DIR/godot.sh" --headless --script "$TOOLS_DIR/contact_sheet.gd" -- "$OUT_DIR/sheet_levels.png" 5 360 \
	"$OUT_DIR"/level_*.png >/dev/null 2>&1
echo "$OUT_DIR"
