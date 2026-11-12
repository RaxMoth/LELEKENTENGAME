# Design System

Every screen and every placeholder should look like a shipped, professional
game: calm, consistent, readable. Never childish, noisy or "programmer art".
This file is the reference for colors, type, icons, layout and gameplay art.
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
7. **Touch first.** Interactive elements are at least 88 px tall (≈ 48 dp)
   and sit inside a `SafeAreaContainer`.

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
| Tappable list item | `CardButton` (see `LevelCard`) |
| Square icon button | `IconButton` + `icon` + `expand_icon = true` |
| Content group | `CardPanel`; small tag / counter: `ChipPanel`; HUD pill: `PillPanel` |
| Amount, price or total | `IconLabel` (icon + text, centered together) |
| Reward line | `RewardList`; stars: `StarsDisplay`; balance: `CurrencyDisplay` |
| Screen background | Flat `BACKGROUND` plus `Assets/Themes/screen_glow.tres` at the top |
| Readability over gameplay | `Assets/Themes/top_scrim.tres` behind the HUD |

## Icons (`Assets/Icons`)

96 px SVGs on a 96 px canvas: solid shapes, rounded joins, no thin hairlines.
UI glyphs are pure white so they can be tinted (`self_modulate`, Button icon
colors). Objects (coin, gem) are full color with 2–3 tones of one hue. New
icons follow the same style; keep them recognizable at 32 px.

Available: coin, gem, star, heart, bolt, trophy, play, gift, bag, check, close,
lock, back, pause, settings, clock, sparkle. App icon and logo:
`icon.svg`, `Assets/Branding/logo.svg`.

## Gameplay art

Until final art exists, entities use `PlaceholderShape`, which draws clean
vector shapes: rounded corners, top-light shading and a soft drop shadow.

- Player `PLAYER`, enemies `ENEMY*`, pickups in their reward color.
- Backgrounds and terrain: `WORLD` tones, `shadow_enabled = false`, low shading.
- Things that rotate every frame (projectiles, turret barrels) and
  translucent shapes (range rings): `shading = 0`, `shadow_enabled = false`.
- Floating numbers: `FloatingText` in `TEXT`, `GOLD` or `WARNING`.
- Shapes ≥ 2 sizes apart for clear hierarchy (player > enemy > pickup).

Replacing with real art: swap `PlaceholderShape` for `Sprite2D` /
`AnimatedSprite2D`, keep the palette for UI, and match the art's light
direction (from above) and shadow softness.

### 3D scenes

- Stand-ins are `PlaceholderMesh3D` primitives in `Palette` colors: matte,
  lit from above, grounded by a `BlobShadow3D`. Same hierarchy rules as 2D
  (player `PRIMARY`, threats `ENEMY*`, rewards `GOLD`).
- `glow` is for the few things the player must notice (sparks, projectiles,
  lamps). Keep it below 1 on lit shapes so their shading stays readable.
- Terrain uses `WORLD` tones and fades into fog of the horizon color; never
  a bright or textured sky behind gameplay.
- UI in the world is the same theme on a `WorldScreen`; size type for the
  viewing distance (text should span at least 0.6° — about 1 cm per meter).

## Motion

- Durations: 0.12–0.2 s for UI feedback, 0.25–0.35 s for popups, ≤ 0.6 s for
  celebrations. Ease out (`TRANS_QUAD`/`TRANS_BACK` + `EASE_OUT`).
- Use `TweenFX` (pop, bounce_in, shake, count_label). Animate scale/alpha, not
  layout. Don't loop animations on primary navigation buttons.

## Checklist for any visual change

- [ ] Only `Palette` colors and theme variations; no new hardcoded colors
- [ ] Icons from `Assets/Icons`, no text glyphs
- [ ] One primary action per screen; destructive actions are not primary
- [ ] Spacing on the 8 px grid; touch targets ≥ 88 px
- [ ] Screenshot checked at 720×1280 (and a tall 20:9 phone) with `/design-review`
