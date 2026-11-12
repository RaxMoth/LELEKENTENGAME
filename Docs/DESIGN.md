# Design System

Every screen and every placeholder should look like a shipped, professional
game: calm, consistent, readable. Never childish, noisy or "programmer art".
This file is the reference for colors, type, icons, layout and gameplay art.
The game is played in a headset: the world is 3D and UI lives in it
(WorldScreens, Label3Ds, the in-world popup screen). The menus are 2D
screens for the flat (no headset) flow and share the same theme.
Check visual work with screenshots (`/design-review`) before calling it done.

## Golden rules

1. **Colors come from `Palette`** (`Scripts/Utils/palette.gd`), UI styling from
   the theme (`Assets/Themes/main_theme.tres`). No ad-hoc `Color(...)` values
   in scripts or per-node color overrides.
2. **Icons, not glyphs.** Never use text symbols (`●`, `◆`, `★`, `♥`, `▶`) as
   icons. Use `Assets/Icons/*.svg` via `IconLabel`, `TextureRect` or a
   Button's `icon` with `expand_icon = true`.
3. **One accent per screen.** Exactly one primary (blue) action per screen.
   Secondary actions are `SecondaryButton`, and low-priority or destructive
   ones are `GhostButton` / `DangerGhostButton`.
4. **No outlines on UI text or shapes.** Text over gameplay uses
   `OverlayLabel`. Gameplay shapes use shading and a soft shadow, never a
   dark outline.
5. **Restraint over decoration.** Muted backgrounds, a few saturated accents
   for things the player must notice (player, enemies, rewards). No rainbow
   primitives, no clutter, no pulsing UI that isn't asking for attention.
6. **8 px grid.** Spacing is 8, 16, 24, 32 or 48. Radii are 12 (chips),
   16 (buttons), 20 (cards) and 28 (popups).
7. **Easy to point at.** UI is clicked with a controller ray (or a finger in
   the flat menus): interactive elements are at least 88 px tall (≈ 48 dp),
   and full-screen menus sit inside a `SafeAreaContainer`.
8. **Nothing glued to the face.** No screen-space HUD in levels; status goes
   on in-world UI placed where the player is already looking.

## Color tokens (`Palette`)

| Token | Hex | Use |
|---|---|---|
| `BACKGROUND` | `#0d1017` | App background / clear color |
| `BACKGROUND_RAISED` | `#131824` | Tracks, recessed areas |
| `SURFACE` | `#1a2030` | Cards, popups |
| `SURFACE_RAISED` | `#242b3e` | Secondary buttons, chips |
| `STROKE` | `#2e364b` | 1 px borders, separators |
| `TEXT` / `TEXT_MUTED` / `TEXT_FAINT` | `#eef1f7` / `#8d96ac` / `#5b647b` | Body / secondary / disabled text |
| `PRIMARY` | `#5b7cfa` | The main action, selection, player |
| `SUCCESS` | `#2dbe78` | Buy, claim, positive states |
| `WARNING` / `GOLD` | `#f5b841` | Coins, energy, crits |
| `DANGER` | `#e5484d` | Destructive actions, damage |
| `GEM` / `STAR` / `XP` | `#3cc8e8` / `#f7c548` / `#3ddc97` | Premium currency, stars, XP |
| `ENEMY` / `ENEMY_HEAVY` / `ENEMY_FAST` | `#f06a6a` / `#c84755` / `#f59e4c` | Threats |
| `WORLD` / `WORLD_DETAIL` | `#151b28` / `#1e2637` | Gameplay backgrounds |
| `CATEGORY[]` | 6 even hues | Puzzle pieces, teams, categories |

To re-skin a game, change `Palette` and regenerate the theme colors to match
(the theme was generated from the same values; keep them in sync).

## Typography (theme variations)

| Variation | Size | Use |
|---|---|---|
| `TitleLabel` | 68 | Screen / game title |
| `OverlayLabel` | 64 | Messages over gameplay ("Ready?", "Wave 3"); has a dark outline for legibility |
| `HeaderLabel` | 44 | Popup and section titles, scores |
| `AccentLabel` | 40 | Highlighted numbers (level index) |
| `Label` | 30 | Body |
| `SmallLabel` | 24 | Secondary text, captions (muted) |
| `CaptionLabel` | 22 | Tertiary text (faint) |
| `BigNumberLabel` | 96 | Final scores |

## Components

| Need | Use |
|---|---|
| Primary / secondary / positive / destructive action | `Button` / `SecondaryButton` / `SuccessButton` / `DangerButton` |
| Low-emphasis or destructive-but-rare action | `GhostButton` / `DangerGhostButton` |
| Tappable list item | `CardButton` |
| Square icon button | `IconButton` + `icon` + `expand_icon = true` |
| Content group | `CardPanel`; small tag / counter: `ChipPanel`; status pill: `PillPanel` |
| Amount, price or total | `IconLabel` (icon + text, centered together) |
| Reward line | `RewardList`; stars: `StarsDisplay`; balance: `CurrencyDisplay` |
| Screen background | Flat `BACKGROUND` plus `Assets/Themes/screen_glow.tres` at the top |
| Readability over a busy background | `Assets/Themes/top_scrim.tres` |

## Icons (`Assets/Icons`)

96 px SVGs on a 96 px canvas: solid shapes, rounded joins, no thin hairlines.
UI glyphs are pure white so they can be tinted (`self_modulate`, Button icon
colors). Objects (cash, coin, gem) are full color with 2–3 tones of one hue. New
icons follow the same style; keep them recognizable at 32 px.

Available: cash, coin, gem, star, heart, bolt, trophy, play, gift, bag, box,
check, close, lock, back, pause, settings, clock, sparkle, sprout, shield,
flame, sun, moon, person, plus, minus. App icon and logo:
`icon.svg`, `Assets/Branding/logo.svg`.

## Gameplay art

The **set** is real: the house shell, ground, front door, trees, weeds and
a little junk use photo-scanned CC0 textures and models (ambientCG, Poly
Haven; sources and licences in `Assets/CREDITS.md`), so the house reads as a
dirty, shabby, lived-in place — until the renovation upgrades turn it, step
by step, into a well-kept *old* house (painted plaster, varnished planks,
clean brick, new clay tiles; never modern or glossy). The **gameplay pieces** (stations, crates,
crew, attackers, towers, items, boards) are still `PlaceholderMesh3D`
primitives in `Palette` colors — matte, lit from above, grounded by a
`BlobShadow3D` — and they must stay clearly readable on top of the set.

- Player hands / beams and the crew `PRIMARY`, threats `ENEMY*`, money and
  quality `GOLD` / `SUCCESS`; products use one distinct hue each.
- Each raider has its own silhouette, not just a color (cop: riot shield
  and cap; SWAT: helmet and vest; the ram team: two officers and a ram).
- The night-4 ghost is the only translucent figure: a tall pale hooded
  shroud (unshaded, about 40% opaque) with dark eye hollows and no limbs —
  eerie, never cartoonish. It fades out; it never pops or jumps at the player.
- Machines (motors, belts, the hopper, the picker's gantry) are steel and
  iron `TexturedBox3D` parts with one small green status lamp (gold while
  busy); they sit on or above the stations and never block a walkway.
- Shapes ≥ 2 sizes apart for clear hierarchy (raider > turret > item).
- Sky and light come from the lighting tokens (`SKY_*`, `DAYLIGHT`,
  `MOONLIGHT`, `AMBIENT_*`) so day and night stay calm and on palette.
- `glow` is for the few things the player must notice (products, lamps,
  projectiles). Keep it below 1 on lit shapes so their shading stays readable.
- Terrain fades into fog of the horizon color; never a bright or textured
  sky behind gameplay. The set stays muted and dirty (worn wood, grimy
  plaster, old brick, patchy lawn, dark dirt lanes) so saturated gameplay
  colors pop against it; the lanes keep a soft checker of their cells.
- Floating numbers: `FloatingText3D` in `TEXT`, `GOLD` or `DANGER`;
  announcements: `LevelBase.announce()` (Label3D, `TEXT` or `DANGER`).
- UI in the world is the same theme on a `WorldScreen`; size type for the
  viewing distance (text should span at least 0.6° — about 1 cm per meter).

### Real art (set dressing)

| Piece | How it is built |
|---|---|
| Walls, floor, ceiling, frames, roof | `HouseShell` from lists, one surface per material (inside plaster, outside brick, floor planks, ceiling concrete, wood trim, roof tiles) |
| Boxes with a real surface (door leaf, fence, gate) | `TexturedBox3D` (`is_grain_vertical` for posts) |
| Renovated surfaces | A `ShellRenovation` per surface (`Ressources/Renovations/`): the shell's material per upgrade level, two steps (patched up, well kept); the next material is a cleaner texture or the same one less grimy, kept muted and warm |
| Stairs | `Stairs3D` (treads between closed side boards, one mesh) with a `WalkableRamp` over it |
| Parts an upgrade adds (door straps, steel frame, shelves, crates) | An `UpgradeLook` node with `TexturedBox3D` children in real materials (`iron_strap`, `steel_frame`, `wood_refinished`), not Palette primitives |
| Lawn, lanes, path, yard | `GroundPlane3D` (soft darker patches in vertex colors break up the tile); the lane board multiplies its cell checker over `ground_material` |
| Trees and weeds | Impostors from `Tools/bake_impostor.gd`, placed with `PropScatter3D` (one draw call per kind) in `Scenes/Levels/House/Surroundings/` |
| Junk (rubbish bags, tyres, chair, cans) | Poly Haven glTF props, instanced as they are |

- **Textures in meters.** Everything above has UVs in meters (`WorldUVMesh`),
  so a material's `uv1_scale` is 1 / its real tile size and the same brick
  is the same size on every wall. No triplanar mapping (too expensive).
- **Shared materials** live in `Assets/Materials/` (one `StandardMaterial3D`
  per surface type). Color + NormalGL (+ Roughness where it shows); no
  displacement, AO or metalness maps. Ground and floor materials use
  anisotropic filtering (seen at grazing angles).
- **Budgets (Quest at 72–90 Hz):** textures at most 1K, imported
  VRAM-compressed with mipmaps (ETC2/ASTC on Android); props under ~5k
  triangles with 512 px textures; trees and plants as impostors (6 / 4
  triangles, alpha scissor + alpha to coverage, both sides, never alpha
  blend); no new lights, no real-time shadows, no full-screen effects.
  Keep the repository addition small: no file over 10 MB, sources and
  heavy originals stay out of the project.
- **Licences:** CC0 only; every downloaded asset goes into
  `Assets/CREDITS.md` with its source URL. Downloads go to a scratch folder;
  only the image / model files the game uses are copied in, under
  `Assets/Textures/<Category>/<AssetId>/` or `Assets/Models/<Kind>/<Name>/`.

Replacing a placeholder gameplay piece with real art: swap
`PlaceholderMesh3D` for an imported mesh under the same budgets, keep the
palette for UI and accents, and match the light direction (from above) and
shadow softness. Keep real-time shadows off (standalone headsets).

## Motion

- Durations: 0.12–0.2 s for UI feedback, 0.25–0.35 s for popups, ≤ 0.6 s for
  celebrations. Ease out (`TRANS_QUAD`/`TRANS_BACK` + `EASE_OUT`).
- Use `TweenFX` (pop, bounce_in, shake, count_label) for UI. Animate
  scale/alpha, not layout. Don't loop animations on primary navigation buttons.
- In the world, move objects, never the camera: no screen shake, no forced
  camera motion — the player's head owns the view.

## Checklist for any visual change

- [ ] Only `Palette` colors and theme variations; no new hardcoded colors
- [ ] Icons from `Assets/Icons`, no text glyphs
- [ ] One primary action per screen; destructive actions are not primary
- [ ] Spacing on the 8 px grid; pointer / touch targets ≥ 88 px
- [ ] In-world UI readable from where the player stands; nothing screen-space in levels
- [ ] Screenshots checked with `/design-review` (menus at 720×1280, the game
      wide in the flat simulator and its popup on the in-world screen)
