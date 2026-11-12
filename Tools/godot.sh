#!/usr/bin/env bash
# Runs the Godot editor binary with the given arguments from the project root.
# Finds Godot via $GODOT, then `godot` on PATH, then the default macOS install.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${GODOT:-}" ]]; then
	GODOT_BIN="$GODOT"
elif command -v godot >/dev/null 2>&1; then
	GODOT_BIN="$(command -v godot)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Godot not found. Set GODOT=/path/to/godot (Godot 4.7+)." >&2
	exit 127
fi
cd "$PROJECT_DIR"
exec "$GODOT_BIN" "$@"
