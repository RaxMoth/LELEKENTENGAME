# The game

A VR crime-sim: you run a stylized, fictional drug operation out of a single
house. You craft product by hand in the lab, sell it to customers queuing at
the back window and defend the front door against attackers coming up the
garden — all at the same time, day and night, walking between the three
fronts. Drugs, recipes and ingredients are made up (Glow, Fizz, Haze;
Glowcap, Fizzroot, Duskleaf, Sugarsalt); there is no real-world chemistry.
The working title in the project is still **Porchlight VR**
(`project.godot`, `GameConfig.game_title`).

**Pillars:** one house, three fronts · pressure never stops · hands-on
first, management later · everything is an upgrade · co-op by design.

> **Status: first playable.** The 3-day cycle (selling days, the raid night) with all three
> fronts, the economy, the five upgrade branches and hired crew is built and
> covered by the unit and smoke tests in the flat simulator. The OpenXR path
> (headset rendering, tracked hands, grip / trigger / sticks, haptics)
> follows Godot's API but **has not been run on a headset yet** — expect to
> tune reach, sizes and comfort on device. Co-op and the meta layer are not
> built yet (see the end).

## The loop: three days of selling, then the raid

The game runs in **3-day cycles** (`HouseCycle`, tuned by
`Ressources/Raids/police_raids.tres`):

1. **Days 1–3 — build up.** Only customers come; nobody attacks.
   **Craft** in the lab (grab ingredients, grind, cook, press), **sell** at
   the back window, earn **cash** and **reputation** — every sale also adds
   **heat**. Spend it: **guns and ammo** at the armory terminal in the
   front room, **towers** on the garden tiles, **upgrades** at the office.
2. **Night 3 — the raid.** Your sales got you noticed. When night falls on
   day 3 the back window closes, the clock stops and the police storm the
   house in **waves** (cops, later SWAT). Close and **bolt the front door**,
   then hold it with your guns and towers. A wave ends when every officer is
   down; a short break follows, then the next.
3. **Raid beaten → next cycle.** The shift is won, the heat drops to 0 and
   the next three days of selling begin. Every raid is harder than the one
   before (more waves, more cops, SWAT from raid 2, tougher officers), and
   the heat you have when the raid starts adds cops to its last wave —
   bribes at the office make the raid smaller.

The wrist status and the announcement at the start of each day say where
you are in the cycle ("Raid in 2 days", "Raid tonight", "Wave 2/3 · 4 left").

A shift is one day: 07:00 to the next dawn (5 min of day, 4 min of night by
default — `DayCycle` on `House.tscn`); the raid night has no clock and lasts
until the last wave is beaten.

| | Day | Night (days 1–2, day 3 until dusk) | Night 3 |
|---|---|---|---|
| Customers | Many regulars, hagglers, bulk buyers | Fewer, richer: connoisseurs, VIPs (after "VIP Access") | None — the window is closed |
| Attackers | None | None | The police raid, in waves |

| Raid | Waves | Officers |
|---|---|---|
| 1 (night 3) | 2 | 3 then 4 cops |
| 2 (night 6) | 3 | 4–6 cops per wave, SWAT from wave 2 |
| 3 (night 9) | 4 | 5–8 cops, 2 SWAT every wave, +30% health |
| every heat point | | up to 4 extra cops in the last wave at full heat |

**Win:** reach dawn on a selling day, or beat every wave of the raid — the
day counter goes up and the shift's earnings are the score. **Lose:** the
front door breaks — the stash is lost and repairs cost 20% of your cash, but
upgrades, guns, crew and banked cash stay, and you replay that day (a lost
raid is fought again).

## Controls

| | Headset | Flat simulator (no headset) |
|---|---|---|
| Grab / let go | Grip (at the hand, or along the beam) | Click an item / click where to put it |
| Use (station buttons, screens, build, door bolt) | Dominant-hand trigger | Click |
| Fire your gun | Off-hand trigger (from the front room or porch) | Right-click, or click an attacker |
| Front door | Grip a handle, swing the door open or shut | Click a handle |
| Move | Off-hand stick forward: aim a teleport, release to jump (or smooth movement in Settings) | WASD / arrows; 1–4 jump to lab, front, window, office |
| Turn | Dominant-hand stick: 30° snaps (or smooth turning) | Drag |
| Pause | Menu or B / Y | Esc |
| Status | Look at your off-hand wrist | Lower left of the view |

Vive wands: trackpad click up teleports, left / right snap-turns. Bindings:
`openxr_action_map.tres`.

## The fronts

### Lab (inside, west)

Ingredient crates charge their price when you take a piece (refunded if it
goes back unused). Ground pieces and batches dropped away from a station go
back to its tray; nothing you worked on is ever destroyed by dropping it. Every step is a skill check: press the station's button
while the sweeping needle is in the green zone — the closer to its middle,
the better.

| Station | In | Out |
|---|---|---|
| Grinder | A raw ingredient that needs grinding | Its dust |
| Cooker (3 slots) | The ingredients of one recipe (ground where needed) | A batch |
| Press | A batch | Units in the stash (batch size from upgrades); waits while the stash has no room for the whole batch |

| Product | Ingredients | Fair price | Heat / unit | Unlock |
|---|---|---|---|---|
| Glow | Glowcap + Sugarsalt | $40 | 1.2 | — |
| Fizz | Fizzroot + Sugarsalt | $70 | 1.8 | Recipe: Fizz (15 rep) |
| Haze | Duskleaf + Glowcap + Fizzroot | $120 | 2.6 | Recipe: Haze (45 rep) |

Quality = average step accuracy plus equipment → tiers **Cut, Street, Pure,
Premium** (`QualityMath`). Customers care: each wants a minimum tier and
pays more for better.

### Back window (inside, west-back)

Customers walk into the yard, queue and wait as long as their patience
lasts. The board inside the window shows the one at the front: what they
want, how much, the minimum quality and what you'd hand over from the
stash. You set the price per unit (−/+), then **Sell** or **Decline**.

| Type | Wants | Pays | Notes |
|---|---|---|---|
| Regular | 1–2, Cut or Street | 1.15× | Steady, mostly by day |
| Bulk buyer | 5–9, any | 0.85× per unit | From 8 rep; dealers can't serve |
| Connoisseur | 1–3, Pure+ | 1.6× | From 15 rep |
| Haggler | 2–4 | 0.9× | Counters prices up to 25% too high |
| VIP | 3–6, Premium | 2.6× | Night only, after VIP Access; dealers can't serve |

Too high a price and they leave (reputation drops); too low and you leave
money on the table. Prices also change how many people come
(`SalesMath.get_demand_multiplier`). Every sale adds heat.

### Front garden (outside, in front of the door)

Three lanes run from the gate to the front door. Defend from the **front
room** or the **porch**: shoot through the windows with the gun in your
hand and build on garden tiles (pick a card on the board above the gate,
then point at a tile). Towers can be built on selling days to prepare.

| Raider | Behavior | Comes |
|---|---|---|
| Cop | Slow, armored (6 off every hit) | Every raid wave |
| SWAT | Tougher, heavy armor (12 off every hit) — bring armor-piercing rounds | From the 2nd wave of raid 2, every wave after |

Junkies (thieves), mafia goons and the boss stay in the project
(`Garden/*.tscn`, used by tests and showcases) but no longer come on their
own; the raid is police only.

### The front door

The door between the front room and the porch swings on a hinge. Grip a
handle (inside or outside) and pull or push; let go nearly shut and it
latches. While it stands open (from 60°) the doorway is walkable, so you can
step onto the porch and back. Each side has a **bolt** (press it with the
trigger): it locks only a shut door, and a bolted door doesn't open.
In a raid the door's state matters — raiders hit an **open** door 3× and an
**unbolted** one 1.5× as hard as a bolted one.

### Armory (front room, back wall)

A terminal sells guns and ammo; the gun you buy goes straight into your
hand, and you can switch between guns you own. The pistol is free and never
runs dry, so you are never unarmed. "Better Blaster" adds damage to every gun.

| Gun | Cost | Damage | Shots/s | Range | Ammo (box) |
|---|---|---|---|---|---|
| Pistol | free | 20 | 3.3 | 30 m | unlimited |
| SMG | $350 | 14 | 10 | 25 m | 90 for $40 (max 360) |
| Shotgun | $500 | 90 | 1.2 | 12 m | 16 for $40 (max 64) |
| Rifle | $800 | 60, pierces armor | 1.8 | 40 m | 20 for $50 (max 100) |

| Tower | Cost | Good against |
|---|---|---|
| Turret | $120 | Junkies (fast, weak bolts) |
| Heavy gun | $260 (unlock) | Cops (slow, strong, pierces armor) |
| Barricade | $80 | Holds anything in its lane |

No single answer works: cops come in numbers, SWAT shrug off light bolts
and the SMG, and the shotgun only reaches the door.

### Office (inside, east)

The wall screen sells the five branches (also in the 2D Shop; each area
keeps its upgrades in its own catalog under `Ressources/Upgrades/`) and lets you
**bribe** the police (cost grows with heat). Upgrades need cash and
reputation and change how you play:

| Branch | Upgrades |
|---|---|
| Production | Better Equipment (quality, wider green zones), Bigger Batches, Recipe: Fizz, Recipe: Haze |
| Sales | Bigger Yard (queue spots), Waiting Bench (patience), VIP Access |
| Defense | Reinforced Door, Better Blaster, Heavy Gun |
| Workforce | Hire Crafter, Hire Dealer, Hire Guard, Crew Training |
| House | Bigger Stash, Locks & Cameras (thieves take less) |

### Crew

| Role | Does | Limits |
|---|---|---|
| Crafter | Makes Street product (Pure after training) from cash | Lower quality than you |
| Dealer | Serves regulars, hagglers (takes their counteroffer) | Not bulk buyers or VIPs |
| Guard | Shoots attackers near the door | Bosses resist them |

Wages are paid every in-game hour; unpaid crew strike until the next payday.

## Decisions made for the design's open questions

These are the defaults this build uses; all are easy to change.

- **When the door falls:** the shift (day) is lost and replayed; the stash is
  destroyed and repairs cost 20% of cash; upgrades, crew and banked cash
  stay (`house_level.gd`, `REPAIR_COST_SHARE`).
- **Heat** is the link between sales and police (per-unit heat on each
  product, more cops in the raid at the end of the cycle, cooling over time,
  bribes; reset to 0 after a beaten raid).
- **The cycle:** 3 days of selling, the raid on night 3, endless with a
  harder raid each cycle (`Ressources/Raids/police_raids.tres`). Guns are
  bought, not upgraded; the free pistol keeps the player armed.
- **Tone:** stylized (the existing palette and placeholder art).
- **First playable size:** 3 products, 4 ingredients, 5 customer types,
  2 raid officers (cop, SWAT), 4 guns, 3 towers, 16 upgrades.
- **Platform:** both — Meta Quest (standalone) and PC VR (SteamVR).

## Running it

**Without a headset (any desktop, also macOS):** press F5 → Play → The
House. The rig runs the flat simulator. The game is designed for a wide
view, so resize the window to landscape. Add `-- world_ui=1` to the command
line to see popups on the in-world screen exactly as a headset would.

**PC headset with SteamVR (Windows):**
1. Install SteamVR and connect the headset (a Quest connects through Steam
   Link, Meta Link or Virtual Desktop).
2. In SteamVR open **Settings → OpenXR** and make SteamVR the current OpenXR
   runtime.
3. Start SteamVR, then run `build/windows/PorchlightVR.exe` (export it with
   `Tools/godot.sh --headless --export-debug "Windows Desktop" build/windows/PorchlightVR.exe`)
   or open the project in Godot 4.7 on the PC and press F5.
4. Boot detects the session and starts the house directly (the 2D menus
   can't be seen in a headset). The desktop window mirrors the headset view.
5. Use SteamVR's recenter if the house isn't around you.

If the 2D main menu appears with "No VR headset found", OpenXR did not
start: check that SteamVR is running and is the current OpenXR runtime.

**Standalone headset (Meta Quest):** install the Android SDK and Godot's
Android export templates, **Project → Install Android Build Template**,
then use the **Meta Quest** export preset (Gradle build, XR Mode OpenXR,
arm64). Pick your headset under XR Features (the optional "Godot OpenXR
Vendors" plugin adds vendor entries), set your own package name and release
keystore, and deploy. Not yet tried on a device.

**macOS** has no OpenXR runtime, so `project.godot` switches OpenXR off
there (`xr/openxr/enabled.macos=false`).

## How it is built

The level is split into **three areas** that can be developed in parallel —
defense, customers and the house — each a self-contained scene with its own
script, data, upgrade catalog and smoke checks. The contract between them is
`HouseFront` + `HouseContext` + `Operation`; see
[`Scenes/Levels/House/README.md`](../Scenes/Levels/House/README.md).

```
Scenes/Levels/House/House.tscn                inherits LevelBase; house_level.gd (HouseLevel) runs the shift
└── World
    ├── Stage
    │   ├── Operation          the shared house state: stash, heat, cash flow, prices, recipes, upgrade effects
    │   ├── DayCycle           DayClock + sun / sky / lamps; StateChart Day -> Night
    │   ├── HouseCycle         Cycle/HouseCycle.tscn: the 3-day cycle; StateChart Selling -> Raid { WaveBreak <-> WaveActive } -> Cleared
    │   ├── HouseShell         walls / doors / windows / floor built from a few numbers
    │   ├── FrontGarden        DEFENSE   Garden/FrontGarden.tscn: lanes, swinging / bolting door, porch, towers, build board, guards, raid waves, firing guns
    │   ├── SalesWindow        CUSTOMERS Sales/SalesWindow.tscn: window, queue, board, dealers, CustomerFlow
    │   ├── Lab                HOUSE     Lab/Lab.tscn: crates, grinder, cooker, press, crafters, recipes
    │   ├── Office             HOUSE     Office/Office.tscn: upgrade board, bribes
    │   ├── Armory             DEFENSE   Armory/Armory.tscn: terminal for guns and ammo
    │   ├── StashShelf         one bag per unit in stock
    │   ├── WalkableArea       floor rectangles the player may stand on
    │   ├── TravelSpots        lab, front, window, office (flat keys 1-4)
    │   └── WristStatus        moved onto the off-hand wrist at setup
    ├── XRPlayerRig            from LevelBase
    └── Announcer              from LevelBase; placed where the player looks
```

| Piece | Role |
|---|---|
| `HouseFront` / `HouseContext` | The front contract: setup with the context, hooks the level calls, signals back (announce, warn, score, lose) |
| `Operation` | One node every front reads and writes — the only shared state, and the natural place to replicate for co-op |
| `HouseLevel` | Runs the shift: time, wages for `Types.GROUP_CREW`, win at dawn (or when the raid is beaten), lose on `shift_lost`, wrist status from the cycle and the fronts. status lines |
| `HouseCycle` | The 3-day cycle: raid day, raid waves (`RaidPlanner` → `RaidWave`), tells the fronts through the raid hooks, closes the window during a raid |
| `Grabbable`, `ItemSocket`, `PointerButton`, `InteractionQuery` (`Scripts/XR/`) | Physics-free hand interaction: grab at the hand or along the beam, drop into sockets, press 3D buttons |
| `XRLocomotion` | Teleport, smooth movement, snap / smooth turning, flat WASD and travel spots; never leaves the `WalkableArea` |
| `Workstation` | StateChart Idle ⇄ Running; `TimingGauge` skill check; grinder / cooker / press by `step` |
| `Customer`, `CustomerFlow`, `SalesWindow`, `SalesBoard` | Pooled customers with StateChart Walking ⇄ Waiting → Leaving; the window runs the sale rules (`SalesMath`) |
| `LaneBoard`, `LaneEnemy`, `Turret`, `LaneDefender`, `AttackerDirector` | Lane math defense; raid officers are pooled with StateChart Alive { Advancing ⇄ Attacking } → Dead |
| `FrontDoor`, `HingeHandle` | The door: StateChart Closed { Unlocked ⇄ Locked } ⇄ Open; grab-and-swing handles, bolts on both sides, opens the doorway in the `WalkableArea` |
| `Armory`, `WeaponData`, `WeaponLoadout`, `Profile.armory` | Guns and ammo: bought at the terminal, fired by the FrontGarden |
| `Worker` | StateChart Absent → Working ⇄ Striking; lives in its front's scene |
| Pure logic (`Scripts/Game/`) | `TimingGauge`, `QualityMath`, `Stash`, `SalesMath`, `CustomerOrder`, `HeatMeter`, `DayClock`, `RaidPlanner`, `WeaponLoadout` — unit-tested |

All numbers are data: ingredients, recipes, customer types and towers in
`Ressources/`, upgrades in one catalog per area (`Ressources/Upgrades/<Area>/`),
attackers as exports on their scenes, pacing on `AttackerDirector`,
`CustomerFlow`, `DayCycle` and `Operation`.

## VR design decisions

- **Space.** A 10 × 10 m house: every front is a few steps away. Rooms
  connect through doorways; the walkable floor is a handful of rectangles.
- **Splitting attention.** The wrist panel shows time, cash, reputation,
  stash, heat, door health and the queue, so you can decide where to go
  next without walking there. Raids, crews, the boss, theft and the door
  falling are announced in front of you with sound and a heavy rumble.
- **Readable lane.** The front room has two wide windows down the garden;
  the board above the gate shows door health and heat at a glance.
- **Hands.** Grip always grabs (either hand). Triggers: dominant uses,
  off-hand shoots — a missed shot never builds or presses something.
  Distance grab along the beam keeps reach comfortable.
- **Comfort.** Teleport and snap turning by default, smooth movement /
  turning in Settings, no camera motion the player didn't make, popups and
  announcements appear where you look and stay world-locked.
- **Performance** (standalone headsets are phones): no physics for
  interaction or combat, pooled spawns, shared meshes and materials, blob
  shadows, one unshadowed light, fog instead of far draw distance, three
  in-world screens plus the popup screen.

## Not built yet / next steps

- **Co-op (2–4 players):** the shared state already lives in `Operation`;
  next is choosing a networking approach (Godot high-level multiplayer with
  a host-authoritative `Operation`), avatars and drop-in.
- **Meta layer:** contracts, rival territory, random events, the campaign
  and bosses that change the world.
- **Lane overview:** a tabletop miniature of the garden in the hall.
- **More content:** recipes, customer types, towers, traps, extra garden
  lanes, more lab rooms; worker skill per person.
- **Comfort:** a vignette for smooth movement; height calibration.
- **On device:** tune reach, station heights, screen sizes and text, haptics.
- **Art and audio:** stand-in meshes and synthesized sounds; no music.
