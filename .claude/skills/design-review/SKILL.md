---
name: design-review
description: Capture screenshots of every menu, popup and level and review them against Docs/DESIGN.md. Use after any visual change (theme, UI scene, icons, gameplay art) and whenever the user asks how something looks.
allowed-tools:
  - Bash(Tools/screenshots.sh*)
---
1. Run `Tools/screenshots.sh build/screenshots` (opens a Godot window briefly
   per shot; takes about a minute). For a single screen, run
   `Tools/godot.sh --resolution 720x1280 res://Tests/ScreenshotTool.tscn -- scene=res://... frames=90 out=build/screenshots/x.png`
   (`level=<id>` and `popup=res://...` are also supported).
2. Read `build/screenshots/sheet_menus.png` and `sheet_levels.png`, then the
   individual screenshots of anything you changed.
3. Check against the golden rules and checklist in `Docs/DESIGN.md`:
   palette colors only, icons instead of glyphs, one primary action, 8 px
   spacing, readable text over gameplay, nothing clipped or overlapping, no
   outlines on shapes, consistent radii. The bar is "a shipped, professional
   mobile game", never childish.
4. Fix what you find, re-capture, and report briefly what changed. Show the
   user the final sheet when they asked about visuals.
