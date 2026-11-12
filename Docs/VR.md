# VR: Porchlight and the XR building blocks

**Porchlight VR** is a lane-defense prototype you stand inside. You are on
the porch of a house at night; a lawn of five lanes stretches away from you
to a gate. Attackers come through the gate and walk down the lanes. You
plant defenders on the lawn, catch the sparks that pay for them and shoot
what gets through. Three attackers on the porch and the run is over.

It is an original game in the lane-defense genre (own name, cast and look),
built from this template's systems: `LevelBase`, pools, components,
StateCharts, the theme and the test tooling.

> **Status.** Game logic, UI and the whole pointer → world-screen input path
> are covered by the unit and smoke tests and were checked in screenshots in
> the flat simulator. The OpenXR path (headset rendering, controller
> tracking, buttons, haptics) follows Godot's documented API but **has not
> been run on a headset yet** — expect to tune comfort and reach on device.

## How to play

| | Headset | Flat simulator |
|---|---|---|
| Plant the selected defender | Point the dominant hand at a tile, pull the trigger | Tap / click a tile |
| Choose a defender | Point at a card on the board above the gate, pull the trigger — or flick a thumbstick, or click the left / right half of a trackpad | Click a card |
| Catch a spark | Sweep either beam over it | Hover or tap it |
| Blaster | Off-hand trigger: fires along that hand's beam | Tap an attacker, or right-click anywhere |
| Pause | Menu button, or B / Y | Pause button, Esc |
| Look around | Your head | Drag |

- **Sparkbloom** (50): grows a spark every few seconds. Your economy.
- **Boltbloom** (100): shoots down its lane while an attacker is in it.
- **Stonecap** (50): a wall with a lot of health.
- **Husk**, **Dasher** (fast), **Brute** (tough) walk; they stop to bite the
  defender in their way. **Wisps** fly over everything — only your blaster
  reaches them, which is why you have one.

All numbers are data: defenders in `Ressources/Defenders/*.tres`, attackers
as exports on their scenes in `Scenes/Levels/Porchlight/`, waves on the
`WaveSpawner` node of `Porchlight.tscn`, start values in
`Ressources/Levels/porchlight.tres` (`custom_parameters`).

## Running it

**Without a headset (any desktop, also macOS):** press F5 → Levels →
Porchlight VR. The rig detects that no headset is active and runs the flat
simulator. The game is designed for a wide view, so resize the window to
landscape. Add `-- world_ui=1` to the command line to see popups on the
in-world screen exactly as a headset would (`Tools/godot.sh -- world_ui=1`).

**PC headset with SteamVR (Windows):**
1. Install SteamVR and connect the headset (a Quest connects through Steam
   Link, Meta Link or Virtual Desktop).
2. In SteamVR open **Settings → OpenXR** and make SteamVR the current OpenXR
   runtime.
3. Start SteamVR, then start the game one of two ways:
   - Run the exported build. `build/windows/BaseTemplate.exe` is a single
     file you can copy to the PC; `BaseTemplate.console.exe` next to it
     runs the same game with a log window. Rebuild it from any machine with
     `Tools/godot.sh --headless --export-debug "Windows Desktop" build/windows/BaseTemplate.exe`
     (the "Windows Desktop" export preset). The build is unsigned, so
     Windows may ask for confirmation the first time.
   - Or open the project in Godot 4.7 on the PC and press F5.
4. Boot detects the session and starts the level from
   `GameConfig.xr_start_level_id` directly, because the 2D menus cannot be
   seen inside a headset. The desktop window switches to 1280×720 and
   mirrors the headset view (`XRPlayerRig.spectator_window_size`).
5. If the lawn is not in front of you, face forward and use SteamVR's
   recenter ("Reset Seated Position"): SteamVR places the "Local Floor"
   space at its seated position, which may be from an earlier session.

If the 2D main menu appears instead, with the note "No VR headset found",
OpenXR did not start: check that SteamVR is running and is the current
OpenXR runtime, and read the reason in the log window of the console build.

Controller bindings live in `openxr_action_map.tres` (edit them in Godot's
**OpenXR Action Map** bottom panel). It is Godot's default map plus an
explicit **HTC Vive wand** profile (`/interaction_profiles/htc/vive_controller`);
SteamVR translates other controllers, such as Index or Touch, from the
profiles that are there. On the wands: right trigger plants and clicks UI,
left trigger fires the blaster, a click on the left or right half of either
trackpad changes the seed (a resting thumb does nothing — wand trackpads are
bound to `secondary` and read on click), and the menu button above the
trackpad pauses. None of this has been tried on hardware yet.

Linux works the same way from the editor; add a Linux export preset for a
standalone build.

**Standalone headset (Meta Quest and other Android devices):** follow
Godot's "Deploying to Android" guide:
1. Install the Android SDK and Godot's Android export templates.
2. **Project → Install Android Build Template**.
3. Add an Android export preset (e.g. "Meta Quest"): enable **Use Gradle
   Build**, set **XR Mode** to **OpenXR**, and under **XR Features** pick
   your headset's entry — or the Khronos plugin if there is none. The
   "Godot OpenXR Vendors" plugin (Asset Library) adds the vendor entries; it
   is optional since Godot 4.6 but recommended for store releases.
4. One-click deploy to the headset.

**macOS:** there is no OpenXR runtime, so `project.godot` switches OpenXR
off there (`xr/openxr/enabled.macos=false`) to keep startup free of errors.
Remove that line if you install a simulator runtime.

Project settings that were added for XR: `xr/openxr/enabled`,
`xr/shaders/enabled`, reference space **Local Floor** (the player stands on
the rig's origin and the runtime handles recentering — do not call
`XRServer.center_on_hmd()`), foveation, and 4× MSAA for 3D.

## How it is built

```
Scenes/Levels/Porchlight/Porchlight.tscn      inherits LevelBase
└── World/Stage (Node3D)
    ├── WorldEnvironment, Moon, Porch, Gate, Garden      scenery (PlaceholderMesh3D)
    ├── LaneBoard          lawn + LaneGrid + everything standing on it
    ├── BoardScreen        WorldScreen showing SeedBoard.tscn (wave, lives, sparks, cards)
    ├── Announcer          Label3D for "Wave 2", "Breach!"
    ├── XRPlayerRig        headset + controllers, or the flat simulator
    └── WaveSpawner        LaneWaveSpawner with the WaveData list
```

| Piece | Role |
|---|---|
| `XRPlayerRig` | Detects an initialized OpenXR interface. XR: enables `use_xr`, matches the physics tick rate to the display, maps triggers / menu / thumbstick to signals, pauses when the headset is taken off. Flat: a `Camera3D` with drag-look and a cursor ray. Both modes drive the same `XRPointer` API, so game code has one path. |
| `XRPointer` | A ray. Hovers and clicks `WorldScreen`s itself; presses that hit no screen go to the game. |
| `WorldScreen` | A panel in the world showing a `Control` scene through a `SubViewport`; turns pointer hits into mouse events, so ordinary Buttons work. |
| `UI.set_world_space_enabled()` | Moves popups / toasts / loading into a viewport owned by the `UI` autoload, which the rig shows on a panel in front of the player. Pause, results, settings and the mock ads therefore work unchanged in a headset. |
| `LaneBoard` + `LaneGrid` | All combat is lane math on a small roster: who blocks me, is something in my lane, which attacker does this ray hit. No physics bodies. |
| `RayMath` | Ray vs. plane / sphere / screen rectangle. |
| `LaneEnemy` | Pooled, StateChart `Alive { Advancing ⇄ Attacking } → Dead`. |
| `LaneDefender` (+ `Sparkbloom`, `Boltbloom`) | Placed by hand, so plain instances; stateless helpers with `_physics_process`. |
| Pooled effects | `LaneBolt`, `SparkOrb`, `BeamTracer`, `FloatingText3D`, `PopEffect3D` via `Pools.spawn_3d()`. |

## Design decisions, by dimension

- **Space and scale.** Life-size: 1.2 m tiles, attackers 1–2 m tall, you on
  a 1.2 m porch. The height is deliberate — from eye level on the ground the
  far tiles would be a 1° sliver and impossible to point at; from the porch
  every tile is a comfortable target and the near lawn is not hidden by the
  porch edge.
- **Height as gameplay.** Wisps fly above the lawn where no defender
  reaches. They are the reason the player's own hands matter, and they make
  you look up, not only down.
- **Hands.** One job per hand so a missed shot never plants something by
  accident: the dominant hand points and plants, the other hand shoots.
  Both beams catch sparks and click UI. `XRPlayerRig.dominant_hand` swaps
  them.
- **UI.** Nothing is glued to the face. Status and seed cards are one board
  above the gate — always in view while you watch the lawn, and outside the
  lines of sight to the tiles. Popups appear on a panel 1.9 m in front of
  you. Messages are `Label3D` over the lawn.
- **Comfort.** No artificial locomotion or camera motion at all; the horizon
  and ground stay fixed; everything important is inside a ~100° arc; the
  game pauses when the headset comes off.
- **Performance** (standalone headsets are phones): no physics for combat,
  pooled spawns, shared meshes and materials, blob shadows instead of
  shadow maps, one unshadowed light, depth fog instead of a far draw
  distance, bloom off on mobile, the popup viewport renders only while it
  shows something.
- **Sound.** Positional (`Audio.play_sfx_at_3d`), so you hear which lane is
  being chewed on.
- **Testing without a headset.** The flat simulator uses the same pointer,
  screen and game code as XR. `Tools/smoke_test.sh` clicks a card on the
  board, plants, fights, catches a spark and presses a popup button on the
  in-world screen through that path.

## Known gaps and next steps

- Try it on a headset and tune: porch height, board size and distance,
  beam and popup placement, blaster feel, haptics.
- The board viewport redraws every frame; switch it to redraw on change if
  it shows up in a headset profile.
- Menus (main menu, shop, level select) are still 2D. In a headset the game
  boots straight into the level and "Main Menu" restarts the run. A world-
  space menu room is the natural next step.
- Stand-in art and synthesized sounds; no music.
- Far tiles are still the hardest to hit. A curved (ballistic) planting arc
  would make them as easy as near ones.
