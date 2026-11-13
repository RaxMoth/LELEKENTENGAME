#!/usr/bin/env bash
# Which tests a change needs: maps the files changed since the base branch
# (commits, edits and new files) to the smoke test's areas, so a pull
# request only plays the areas it touches. Prints shell assignments:
#   SMOKE=yes|no        no: only docs, showcases or unit tests changed
#   AREAS=full|a,b,...  full: shared code changed (globals, entities, XR, UI,
#                       the house level...); empty: the house's skeleton only
#   COOP=yes|no         the co-op test (co-op code changed, or AREAS=full)
# The file -> area table is below; a file it doesn't know runs everything.
#   eval "$(Tools/affected_areas.sh [base-ref])"   (default origin/main)
#   Tools/affected_areas.sh --files a.gd b.tscn    (those files instead of a diff)
# The files and the area each maps to go to stderr.
set -uo pipefail
GIVEN_FILES=""
if [ "${1:-}" = "--files" ]; then
	shift
	GIVEN_FILES="$(printf '%s\n' "$@")"
else
	BASE="${1:-origin/main}"
	MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"
fi

# One file -> an area (lab, cellar, sales, town, defense, towers), "house"
# (the skeleton that always runs), "none" (no smoke test needed) or "all".
area_of() {
	case "$1" in
		*.md|Docs/*|LICENSE|.claude/*|.github/pull_request_template.md|Tests/Showcases/*|Tests/Unit/*|Tools/screenshots.sh|Tools/bake_impostor.gd|Tools/generate_voices.ps1|*.import)
			echo none ;;
		Scenes/Levels/House/Lab/*|Scenes/Levels/House/Workers/*|Scenes/Levels/House/stash_shelf.gd*|Scenes/Levels/House/StashShelf.tscn|\
		Ressources/Ingredients/*|Ressources/Recipes/*|Ressources/Upgrades/Lab/*|Tests/Smoke/lab_checks.gd*|\
		Scripts/Utils/ingredient_look.gd*|Scripts/Utils/sack_mesh_3d.gd*|Scripts/Utils/crate_mesh_3d.gd*|Assets/Textures/Fabric/*|\
		Scripts/Game/timing_gauge.gd*|Scripts/Game/quality_math.gd*|Scripts/Game/automation_math.gd*)
			echo lab ;;
		Scenes/Levels/House/Cellar/*|Tests/Smoke/cellar_checks.gd*)
			echo cellar ;;
		Scenes/Levels/House/Sales/*|Ressources/Customers/*|Ressources/Upgrades/Sales/*|Tests/Smoke/sales_checks.gd*|\
		Scripts/Game/sales_math.gd*|Scripts/Game/customer_order.gd*)
			echo sales ;;
		Scenes/Levels/House/Town/*|Ressources/Town/*|Ressources/Dialogue/*|Ressources/Voices/*|Assets/Audio/Voices/*|Tests/Smoke/town_checks.gd*|\
		Scripts/Game/town_layout.gd*|Scripts/Game/street_routes.gd*|Scripts/Game/dialogue_runner.gd*|Scripts/Game/line_picker.gd*|Scripts/Game/map_projection.gd*|\
		Scripts/Utils/town_mesh_builder.gd*)
			echo town ;;
		Scenes/Levels/House/Garden/Towers/*|Ressources/Towers/*|Tests/Smoke/tower_checks.gd*|Scripts/Game/tower_placements.gd*)
			echo towers ;;
		Scenes/Levels/House/Garden/*|Scenes/Levels/House/Armory/*|Scenes/Levels/House/Cycle/*|Ressources/Weapons/*|Ressources/Raids/*|\
		Ressources/Upgrades/Defense/*|Tests/Smoke/defense_checks.gd*|\
		Scripts/Game/raid_planner.gd*|Scripts/Game/raid_wave.gd*|Scripts/Game/weapon_ballistics.gd*|Scripts/Game/melee_math.gd*|\
		Scripts/Game/holster_rules.gd*|Scripts/Game/weapon_loadout.gd*|Scripts/Game/yard_navigation.gd*|Scripts/Game/player_health.gd*)
			echo defense ;;
		Scenes/Levels/House/Office/*|Scenes/Levels/House/Admin/*|Scenes/Levels/House/Ghost/*|Scenes/Levels/House/Rats/*|\
		Scenes/Levels/House/FuseBox/*|Scenes/Levels/House/Breach/*|Scenes/Levels/House/Holsters/*|Scenes/Levels/House/Surroundings/*|\
		Scenes/Levels/House/CoopBoard/*|Ressources/Upgrades/House/*|Ressources/Renovations/*|Ressources/Skills/*|Ressources/HouseLayouts/*|\
		Tests/Smoke/house_checks.gd*|Scripts/Game/day_clock.gd*|Scripts/Game/heat_meter.gd*|Scripts/Game/skill_book.gd*|Scripts/Game/ghost_odds.gd*|\
		Scripts/Game/stash.gd*|Scripts/Game/level_result.gd*|Scripts/Game/walk_motion.gd*)
			echo house ;;
		*)
			echo all ;;
	esac
}

if [ -n "$GIVEN_FILES" ]; then
	FILES="$GIVEN_FILES"
else
	FILES="$( { git diff --name-only "$MERGE_BASE"; git ls-files --others --exclude-standard; } | sort -u )"
fi
AREAS=""
SMOKE="no"
COOP="no"
IS_FULL="no"
while IFS= read -r file; do
	[ -z "$file" ] && continue
	area="$(area_of "$file")"
	echo "  $area	$file" >&2
	if echo "$file" | grep -qiE 'coop|remote_?player|net_entities|control_mirror'; then
		COOP="yes"
	fi
	case "$area" in
		none) ;;
		all) IS_FULL="yes"; SMOKE="yes" ;;
		house) SMOKE="yes" ;;
		*) SMOKE="yes"; case ",$AREAS," in *",$area,"*) ;; *) AREAS="${AREAS:+$AREAS,}$area" ;; esac ;;
	esac
done <<< "$FILES"
if [ "$IS_FULL" = "yes" ]; then
	AREAS="full"
	COOP="yes"
fi
echo "SMOKE=$SMOKE"
echo "AREAS=$AREAS"
echo "COOP=$COOP"
