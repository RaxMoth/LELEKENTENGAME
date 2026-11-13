#!/usr/bin/env bash
# Captures every menu and popup at 720x1280 and the game in its flat
# simulator (wide 1280x720, plus one portrait shot), then builds contact
# sheets for a quick visual review. Opens a window, not headless.
#   Tools/screenshots.sh [output_dir]   (default: build/screenshots)
set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-build/screenshots}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
# Keep Godot from importing the captures when they land inside the project.
touch "$OUT_DIR/.gdignore"
# shot <name> <args...>; set SHOT_RESOLUTION for anything other than portrait.
shot() {
	local name="$1"; shift
	"$TOOLS_DIR/godot.sh" --resolution "${SHOT_RESOLUTION:-720x1280}" res://Tests/ScreenshotTool.tscn -- "$@" "out=$OUT_DIR/$name.png" >/dev/null 2>&1 || echo "failed: $name" >&2
}
MENU=res://Scenes/Menus/MainMenu/MainMenu.tscn
shot 01_main_menu scene=$MENU frames=120
shot 03_shop scene=res://Scenes/Menus/Shop/Shop.tscn frames=90
shot 04_settings scene=$MENU popup=res://Scenes/UI/Popups/SettingsPopup/SettingsPopup.tscn frames=60
shot 05_achievements scene=$MENU popup=res://Scenes/UI/Popups/AchievementsPopup/AchievementsPopup.tscn frames=60
shot 06_play_together scene=$MENU popup=res://Scenes/UI/Popups/CoopPopup/CoopPopup.tscn frames=60
shot 07_day_summary scene=$MENU popup=res://Scenes/UI/Popups/DaySummaryPopup/DaySummaryPopup.tscn frames=60
# The game in the rig's flat simulator, wide like a headset view: each front
# from its travel spot (1 lab, 2 front, 3 back window, 4 office), the pause
# menu on the in-world popup screen, the night, and one portrait phone shot.
WIDE=1280x720
SHOT_RESOLUTION=$WIDE shot level_1_front level=house showcase=house spot=2 frames=200
SHOT_RESOLUTION=$WIDE shot level_2_lab level=house showcase=house spot=1 frames=160
SHOT_RESOLUTION=$WIDE shot level_3_window level=house showcase=house spot=3 frames=900
SHOT_RESOLUTION=$WIDE shot level_4_office level=house showcase=house spot=4 frames=120
SHOT_RESOLUTION=$WIDE shot level_5_night level=house showcase=house_night spot=2 frames=200
SHOT_RESOLUTION=$WIDE shot level_6_pause level=house showcase=house spot=2 frames=120 pause=1 world_ui=1
shot level_7_portrait level=house showcase=house spot=2 frames=200
# The 3-day cycle: the armory terminal, the front door (inside, bolts and
# handles), and the raid night with cops and SWAT in the garden.
SHOT_RESOLUTION=$WIDE shot level_8_armory level=house showcase=house stand=-3,-3.3 look=-3,1.4,-2.1 frames=120
SHOT_RESOLUTION=$WIDE shot level_9_door level=house showcase=house stand=0.3,-3.7 look=0,1.1,-5 frames=120
SHOT_RESOLUTION=$WIDE shot level_10_raid level=house showcase=house_raid spot=2 frames=600
# The lab's recipe book on the wall above the ingredient crates.
SHOT_RESOLUTION=$WIDE shot level_11_recipes level=house showcase=house stand=-2.6,0 look=-4.9,1.55,0 frames=120
# Co-op: a second player in the lab (head, hands, beam, name, a held glowcap).
SHOT_RESOLUTION=$WIDE shot level_12_coop level=house showcase=house_coop stand=-1.6,0.4 look=-3.6,1.3,-0.3 frames=120
# Out in the garden: the house from the yard, the player walks here through the front door.
SHOT_RESOLUTION=$WIDE shot level_13_garden level=house stand=2.5,-11.5 look=0,1.6,-5 frames=150
# The town around the house: a street corner and a conversation with a passer-by.
SHOT_RESOLUTION=$WIDE shot level_14_town level=house stand=24,-35 look=85,20,-110 frames=200
SHOT_RESOLUTION=$WIDE shot level_15_talk level=house showcase=house_town_talk frames=200
# The house after its renovations (walls, floor, brickwork, roof) and the
# upgrades that show: door straps, steel frame, wooden stash shelf and crates.
SHOT_RESOLUTION=$WIDE shot level_16_renovated level=house showcase=house_renovated stand=2.5,-11.5 look=0,1.6,-5 frames=150
SHOT_RESOLUTION=$WIDE shot level_17_renovated_inside level=house showcase=house_renovated stand=2.2,3.0 look=4.68,1.0,3.25 frames=120
# Automation: the cellar's grow racks and picker, its stairwell, the lab's
# motors, belts and hopper, and the night-4 ghost staring back.
SHOT_RESOLUTION=$WIDE shot level_18_cellar level=house showcase=house_cellar stand=1.6,1.0 look=3.0,-1.9,-1.6 frames=120
SHOT_RESOLUTION=$WIDE shot level_19_stairwell level=house showcase=house_automation stand=2.0,3.8 look=2.4,-0.8,2.0 frames=120
SHOT_RESOLUTION=$WIDE shot level_20_lab_automation level=house showcase=house_automation stand=-2.6,0.4 look=-2.6,1.2,-1.6 frames=120
SHOT_RESOLUTION=$WIDE shot level_21_ghost level=house showcase=house_ghost frames=60
# The door is down: raiders stormed into the front room, the player is hurt (wrist health).
SHOT_RESOLUTION=$WIDE shot level_22_storm level=house showcase=house_storm stand=0.3,-1.2 look=0,1.0,-5 frames=40
# A new player: rats in the one-room cabin, fists, then a knife and an axe from the armory.
SHOT_RESOLUTION=$WIDE shot level_23_rats level=house showcase=house_rats stand=-1.9,1.3 look=-1.9,0.0,-0.5 frames=60
SHOT_RESOLUTION=$WIDE shot level_24_melee level=house showcase=house_melee stand=0.1,-2.9 look=0.1,1.0,-4.3 frames=60
"$TOOLS_DIR/godot.sh" --headless --script "$TOOLS_DIR/contact_sheet.gd" -- "$OUT_DIR/sheet_menus.png" 5 360 640 \
	"$OUT_DIR"/0*.png >/dev/null 2>&1
"$TOOLS_DIR/godot.sh" --headless --script "$TOOLS_DIR/contact_sheet.gd" -- "$OUT_DIR/sheet_levels.png" 3 640 360 \
	"$OUT_DIR"/level_*.png >/dev/null 2>&1
echo "$OUT_DIR"
