---
name: design-review
description: Capture screenshots of every menu, popup and the VR game (flat simulator and in-world popup screen) and review them against Docs/DESIGN.md. Use after any visual change (theme, UI scene, icons, gameplay art) and whenever the user asks how something looks.
allowed-tools:
  - Bash(Tools/screenshots.sh*)
---
1. Run `Tools/screenshots.sh build/screenshots` (opens a Godot window briefly
   per shot; takes about a minute). For a single screen, run
   `Tools/godot.sh --resolution 720x1280 res://Tests/ScreenshotTool.tscn -- scene=res://... frames=90 out=build/screenshots/x.png`
   (`popup=res://...` is also supported). For a level use
   `--resolution 1280x720` and `level=<id>`; add `showcase=porchlight` for a
   staged mid-game moment, `pause=1 world_ui=1` for its popup on the
   in-world screen.
2. Read `build/screenshots/sheet_menus.png` and `sheet_levels.png`, then the
   individual screenshots of anything you changed.
3. Check against the golden rules and checklist in `Docs/DESIGN.md`:
   palette colors only, icons instead of glyphs, one primary action, 8 px
   spacing, readable text over gameplay, nothing clipped or overlapping, no
   outlines on shapes, consistent radii; in levels, in-world UI readable from
   the player's spot and nothing screen-space. The bar is "a shipped,
   professional VR game", never childish.
4. Fix what you find, re-capture, and report briefly what changed. Show the
   user the final sheet when they asked about visuals.
