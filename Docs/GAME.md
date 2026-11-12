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
   front room, **house upgrades** at the office (roof turrets, the Security
   PC, a stronger door).
2. **Night 3 — the raid.** Your sales got you noticed. When night falls on
   day 3 the back window closes, the clock stops and the police storm the
   house in **waves** (cops, later SWAT and a battering ram). Close and
   **bolt the front door**, then hold it with your guns and turrets. A wave
   ends when every raider is down; a short break follows, then the next.
3. **Raid beaten → next cycle.** The shift is won, the heat drops to 0 and
   the next three days of selling begin. Every raid is harder than the one
   before (more waves, more cops, SWAT and a ram from raid 2, tougher officers), and
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
| 2 (night 6) | 3 | 4–6 cops per wave, SWAT from wave 2, a battering ram in the last wave |
| 3 (night 9) | 4 | 5–8 cops, 2 SWAT every wave, +30% health, a ram in the last wave |
| every heat point | | up to 4 extra cops in the last wave at full heat |

**The house is the only world.** There are no levels, stars or a level
select: the main menu's Play (or putting on the headset) goes straight into
the house, on the day you're on, and the game is one day after another.

**Win the day:** reach dawn on a selling day, or beat every wave of the raid
— the day counter goes up. **Lose it:** the front door breaks — the stash is
lost and repairs cost 20% of your cash, but upgrades, guns, crew and banked
cash stay, and you play that day again (a lost raid is fought again). Either
way a **day summary** shows what the shift earned, sold and crafted (or what
it cost) with one button into the next morning — the house reloads as the
new day, in co-op the guest comes along (`DaySummaryPopup`).

## Controls

| | Headset | Flat simulator (no headset) |
|---|---|---|
| Pick up / put in | Dominant-hand trigger: point at a crate, ingredient or batch and pull; point at a station slot and pull again | Click an item / click where to put it |
| Carry by hand | Grip (either hand, at the hand or along the beam): hold to carry, let go at — or pointing at — a slot; a quick grip click keeps holding until the next click | — |
| Use (station buttons, screens, door bolt) | Dominant-hand trigger | Click |
| Fire your gun | Off-hand trigger (from the front room, the porch or the garden); the gun sits in that hand; hold it for the SMG | Right-click (hold for the SMG), or click a raider |
| Front door | Trigger on a handle swings it fully open / shut; grip a handle to swing it by hand | Click a handle |
| Talk to someone | Dominant-hand trigger on a person in the street; pick a reply on the panel beside them | Click a person, then a reply |
| Walk | Dominant-hand stick walks where you look (like VRChat; "Smooth Movement", on by default), easing in and out; push it all the way to sprint | WASD / arrows; 1–4 jump to lab, front, window, office |
| Run with your arms | Hold both grips (hands empty) and swing your arms like jogging: the harder you swing, the faster you run, toward where your hands point; footsteps and a light tap in both hands every stride | — |
| Reposition | Off-hand stick forward: aim a teleport, release to jump | — |
| Turn | Off-hand stick left / right: 30° snaps (or smooth turning) | Drag |
| Seated play | "Standing View When Seated" (on by default) lifts a seated player to standing eye height (1.8 m); after sitting down or standing up, hold the headset's system button to recenter | — |
| Admin (debug builds) | Terminal on the office wall | Same, or F3 |
| Pause | Menu or B / Y | Esc |
| Status | Look at your off-hand wrist | Lower left of the view |

Vive wands: trackpad click up teleports, left / right snap-turns. Bindings:
`openxr_action_map.tres`.

## The fronts

### Lab (inside, west)

**A new operation starts small:** one **shroom plant** on the grow shelf by
the back wall. It grows on its own (about 45 s); when it's ripe, point at
it and pull the trigger (or click) to harvest the shrooms straight into the
stash, then sell them at the back window. The office's **Lab** tab sells the
rest, one after the other: **More Plants** (up to three), the **Grinder**
(with the ingredient crates), then the **Cooker**, then the **Press** — each
shows up in the lab when bought, and the press unlocks Glow.

Ingredient crates charge their price when you take a piece (refunded if it
goes back unused). Ground pieces and batches dropped away from a station go
back to its tray, or — when that is taken — into the nearest free station
slot that takes them; nothing you worked on is ever destroyed or left
hanging in the air. Every step is a skill check: press the station's button
while the sweeping needle is in the green zone — the closer to its middle,
the better.

| Station | In | Out |
|---|---|---|
| Grinder | A raw ingredient that needs grinding | Its dust |
| Cooker (3 slots) | The ingredients of one recipe (ground where needed) | A batch |
| Press | A batch | Units in the stash (batch size from upgrades); waits while the stash has no room for the whole batch |

| Product | Ingredients | Fair price | Heat / unit | Unlock |
|---|---|---|---|---|
| Shrooms | — (grow on the plants) | $18 | 0.6 | — |
| Glow | Glowcap + Sugarsalt | $40 | 1.2 | Press |
| Fizz | Fizzroot + Sugarsalt | $70 | 1.8 | Recipe: Fizz (15 rep, after the Press) |
| Haze | Duskleaf + Glowcap + Fizzroot | $120 | 2.6 | Recipe: Haze (45 rep, after the Press) |

Quality = average step accuracy plus equipment → tiers **Cut, Street, Pure,
Premium** (`QualityMath`). Customers care: each wants a minimum tier and
pays more for better.

A **"How to cook" poster** above the grinder and cooker shows the plant and
the three gadget steps and the skill check; a gadget not bought yet is
dimmed and says where to get it. Empty station slots show a white ring; while you
hold something the ring it would go into turns blue, and a slot it doesn't
fit turns red — let go there and the station says why ("Grind it first").
Stop buttons only appear while a skill check runs.

The **recipe book** on the wall above the crates lists every product,
open: ingredients → product (or "Grows on the plant"), and for one the lab
can't make yet a lock with what it needs ("Needs Press", "Needs Recipe:
Fizz"). An upgrade that builds on another (the cooker on the grinder) shows
"Needs … first" in the office.

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

### The yard (outside, in front of the door)

A wide open field in front of the house — trees, pines, rocks, bushes and a
parked car, fenced at the far edges. Open the front door and **walk out**:
the whole garden is yours to walk, and a gate in its far fence leads out
into the town (around the trees, rocks
and the car). Defend from the **front room** (shoot through the windows),
the **porch** or out in the **garden**, with the gun in your hand and the
house's roof turrets.

Raiders enter at random points of the far edge and the sides and work
their way in **in squads of three**: they dash from cover to cover (only
part of a squad moves at once, the rest waits crouched behind a tree, rock
or the car — longer while being shot at), gather in the last cover before
the house, then **rush the door together** and hammer it. Cover really
covers: shots from the house, turrets and guards are stopped by anything
tall enough between them and the raider (rocks and bushes only hide a
crouching body from shots at the same height).

| Raider | Behavior | Comes |
|---|---|---|
| Cop | Riot shield, cap, armored (6 off every hit), uses cover | Every raid wave |
| SWAT | Helmet, plate carrier, carbine; tougher, heavy armor (12 off every hit) — bring armor-piercing rounds | From the 2nd wave of raid 2, every wave after |
| Battering ram | Two officers with a ram: no cover, wait at the house for the rush, then hit the door for 90 every 2.4 s | Last wave of raid 2, one more every 3 raids |

### The town (around the house)

The house stands on one block of a town: streets with sidewalks and zebra
crossings, brick, plaster and glass buildings rising into downtown towers,
two parks, a plaza with a fountain, street lamps and parked cars — about
250 × 260 m, closed off by a ring of buildings. Out of the front door and
through the **gate** in the garden fence you can walk anywhere: streets,
sidewalks, parks, the alleys between buildings. At night windows light up
and the street lamps glow.

People walk the sidewalks and mutter when you pass. **Point at someone and
pull the trigger to talk**: they stop, face you and answer out loud, and a
panel beside them shows what they said and your replies — small talk, a
goodbye, or *"Want to buy something?"*. Talk them into it (the better your
reputation, the likelier) and they come to the back window; each person
can be asked once. Details: `Scenes/Levels/House/Town/README.md`.

### Voices

Everyone talks, in German internet-meme slang, from where they stand
(positional, with a subtitle): customers greet you and order at the
window, thank you, haggle, complain about the price or the wait; people in
the street chat; the police shout when a raid wave comes, call for cover,
cry out when hit and on the way down, and announce the ram. Each kind of
customer has its own voice. Chatter is rationed (only a couple of voices at
once). The recordings are placeholders made with Windows' German speech
voices (`Tools/generate_voices.ps1`); a real recording with the same file
name replaces one.

### Roof turrets and the Security PC

Turrets are house upgrades, not things built in the yard: **Roof Turrets**
(office, defense branch) mounts up to three on the house front — above the
door, then left and right. Each swings toward the raider closest to the
door that it can see and fires when lined up. The **Security PC** upgrade
puts a monitor on the office desk with each turret's live camera view:
switch turrets, **take control**, point at the view to aim and pull the
trigger on it to fire (held = keeps firing); release it and it aims on its
own again.

**VR in VR:** beside the monitor lie the **turret goggles**. Put them on
(trigger or click) and you are in the turret on screen: your head where its
camera sits on the roof, the barrel right below you following your hand,
either trigger firing it, a visor frame with the turret's name around your
view. You can't walk while seated and your own gun is put away; the
"Take off goggles" button floating in front of you (or the end of the
shift) puts you back at the desk exactly where you stood.

### The front door

The door between the front room and the porch swings on a hinge. Pull the
trigger on a handle (inside or outside) to swing it fully open or shut, or
grip a handle and pull or push it by hand; let go nearly shut and it
latches. While it stands open (from 60°) the doorway is walkable, so you can
step onto the porch and back. Each side has a **bolt** (press it with the
trigger): it locks only a shut door, and a bolted door doesn't open.
In a raid the door's state matters — raiders hit an **open** door 3× and an
**unbolted** one 1.5× as hard as a bolted one; the **Steel Door Frame**
upgrade takes 25% off every hit per level.

### Armory (front room, back wall)

A terminal sells guns and ammo; the gun you buy goes straight into your
hand, and you can switch between guns you own. The pistol is free and never
runs dry, so you are never unarmed. "Better Rounds" adds damage to every gun.
Each gun has its own model in the off hand (lower right of the view in the
flat simulator) and is animated on every shot: kick, muzzle flash and its
moving part — the pistol's slide, the SMG's charging handle, the shotgun's
pump, the rifle's bolt. An empty gun only clicks. The models are built from
metal, polymer and wood materials (sights, serrations, curved magazine,
scope, wooden furniture). Every gun shoots its own way (`WeaponBallistics`)
and has its own sound.

| Gun | Cost | Damage | Shots/s | Range | Ammo (box) |
|---|---|---|---|---|---|
| Pistol | free | 20, falls off past 18 m | 3.3, semi-auto | 30 m | unlimited |
| SMG | $350 | 12, falls off past 12 m | 12.5, full auto (hold), spread grows during a burst | 25 m | 90 for $40 (max 360) |
| Shotgun | $500 | 9 pellets × 14 in a 5.5° cone, weak past 15 m | 1.2, pump | 18 m | 16 for $40 (max 64) |
| Rifle | $800 | 60, pierces armor, goes through one raider into the next | 1.8, bolt | 40 m | 20 for $50 (max 100) |

No single answer works: cops come in numbers and hide, SWAT shrug off the
SMG, the ram must die before it reaches the door, and the shotgun only
reaches the porch.

### Office (inside, east)

The wall screen sells the eight branches (two rows of tabs; also in the 2D Shop; each area
keeps its upgrades in its own catalog under `Ressources/Upgrades/`) and lets you
**bribe** the police (cost grows with heat). Upgrades need cash and
reputation and change how you play:

| Branch | Upgrades |
|---|---|
| Lab | More Plants, Grinder, Cooker, Press (the lab's gadgets, one after the other) |
| Automation | Dig the Cellar, Grow Racks, Grow Lights, Auto Picker, Grinder Motor, Cooker Timer, Press Motor, Conveyor Belts, Ingredient Hopper |
| Production | Better Equipment (quality, wider green zones), Bigger Batches, Recipe: Fizz, Recipe: Haze |
| Sales | Bigger Yard (queue spots), Waiting Bench (patience), VIP Access |
| Defense | Reinforced Door, Better Rounds, Roof Turrets (up to 3), Security PC |
| Workforce | Hire Crafter, Hire Dealer, Hire Guard, Crew Training |
| House | Bigger Stash, Steel Door Frame (less door damage), Patch the Walls, Fix the Floor, Clean the Brickwork, Repair the Roof (heat cools faster) |
| Perks | Running Shoes (walk faster), Green Thumb (more shrooms per hand harvest), Steady Hands (slower skill-check needle) |

### Renovating the house

A new operation moves into a shabby house: grimy green plaster, rotten
boards, dirty brick, a mossy roof, a rack of planks on concrete blocks. The
House branch fixes it up in two steps per part — **patched up**, then **well
kept** — until it is a nice old house (cream-painted plaster and ceiling,
varnished plank floor, clean red brick, new clay tiles), never a modern one:

| Upgrade | Level 1 | Level 2 | Bonus |
|---|---|---|---|
| Patch the Walls | Fresh plaster over the cracks | Painted walls and ceiling, refinished door and window frames | Heat cools 10% faster per level |
| Fix the Floor | New boards | Sanded and varnished | 〃 |
| Clean the Brickwork | Repointed, still grimy | Clean red brick | 〃 |
| Repair the Roof | Patched tiles | New tiles | 〃 |

A kept-up house looks like any other on the street, so the police lose
interest faster (`Operation.get_heat_cooling_multiplier()`). Other upgrades
show too: **Reinforced Door** bolts an iron strap pair, a middle strap and a
kick plate onto the door (one per level), **Steel Door Frame** puts a steel
frame and then heavy locks around it, and **Bigger Stash** swaps the boards
and blocks for a real wooden shelf, then adds crates beside it.

### The cellar and automation

The game grows into an incremental one: the Automation tab is a tree
(each upgrade needs the one before) that slowly takes the work off your
hands. Machines only work during a shift; nothing piles up while the game
is closed.

- **Dig the Cellar** (needs More Plants): the planks nailed over the
  opening in the stash-room floor come off. Wooden stairs lead down to a
  brick cellar under the stash room and the office; walk down them like
  anywhere else (smooth movement; teleports stay on the floor you are on;
  quick travel brings you back up).
- **Grow Racks** (3 levels): a rack of four shroom plants per level. They
  grow on their own; harvest them by hand like the lab's plant.
- **Grow Lights** (3 levels): +25% growth speed per level for the cellar.
- **Auto Picker** (3 levels): a gantry under the cellar ceiling rolls to the
  nearest ripe plant, lowers its arm and picks it into the stash (8 s, 6 s,
  4 s, 2 s per pick); it waits while the stash is full.
- **Grinder Motor, Cooker Timer, Press Motor**: the station stops its own
  skill check after 4 seconds with a Good result; press Stop yourself for
  Perfect.
- **Conveyor Belts** (after the press motor): the ground ingredient rides a
  belt into the cooker, the cooked batch an overhead rail into the press.
- **Ingredient Hopper** (after the belts): buys the ingredients of the last
  recipe you cooked from the crates (paid from the cash) and feeds them in,
  one at a time, again and again. With every motor the lab now cooks that
  recipe into the stash on its own.

### Perks

Upgrades for you rather than the house: **Running Shoes** (+20% walking
speed per level, stick, arm swing and keys), **Green Thumb** (+1 shroom per
level from every plant you harvest by hand, not the picker's) and **Steady
Hands** (the skill-check needle sweeps 15% slower per level).

### The ghost

On the night of day 4 a ghost turns up somewhere behind you, on your
floor, hovering and turned away. The moment you look at it, it freezes,
turns to stare at you for a second and fades away for good. Nothing else
reacts to it, and in co-op each player meets their own.

### Crew

| Role | Does | Limits |
|---|---|---|
| Crafter | Makes Street product (Pure after training) from cash | Lower quality than you |
| Dealer | Serves regulars, hagglers (takes their counteroffer) | Not bulk buyers or VIPs |
| Guard | Shoots raiders in the yard from the front room | Cover hides raiders from them |

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
  3 raiders (cop, SWAT, battering ram), 4 guns, 3 roof turrets, 37 upgrades.
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
    │   ├── Surroundings       HOUSE     Surroundings/Surroundings.tscn: lawn, approach path, trees, weeds, junk (its yard trees are COVER_ONLY obstacles in the Yard)
    │   ├── HouseShell         walls / doors / windows (framed) / floor / ceiling / gable roof built from a few numbers; renovations swap its materials
    │   ├── FrontGarden        DEFENSE   Garden/FrontGarden.tscn: open yard (Yard), swinging / bolting door, porch, roof turrets, Security PC, guards, raid squads, guns in hand
    │   ├── SalesWindow        CUSTOMERS Sales/SalesWindow.tscn: window, queue, board, dealers, CustomerFlow
    │   ├── Lab                HOUSE     Lab/Lab.tscn: crates, grinder, cooker, press, crafters, recipes; motors, belts, hopper (LabAutomation)
    │   ├── Cellar             HOUSE     Cellar/Cellar.tscn: the boarded opening, stairs, brick cellar, grow racks, auto picker
    │   ├── Ghost              HOUSE     Ghost/Ghost.tscn: the night-4 ghost (local to each player)
    │   ├── Office             HOUSE     Office/Office.tscn: upgrade board, bribes
    │   ├── Admin              HOUSE     Admin/Admin.tscn: admin terminal for testing (debug builds only)
    │   ├── Armory             DEFENSE   Armory/Armory.tscn: terminal for guns and ammo
    │   ├── StashShelf         StashShelf.tscn: one bag per unit in stock; boards on blocks, a wooden shelf and crates (Bigger Stash)
    │   ├── SteelDoorFrame     SteelDoorFrame.tscn: steel frame and locks around the front door (Steel Door Frame)
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
| `HouseLevel` | Runs the shift: time, wages for `Types.GROUP_CREW`, win at dawn (or when the raid is beaten), lose on `shift_lost`, wrist status from the cycle and the fronts' status lines; at the end the day summary, then the next day (the house reloads) |
| `HouseCycle` | The 3-day cycle: raid day, raid waves (`RaidPlanner` → `RaidWave`), tells the fronts through the raid hooks, closes the window during a raid |
| `Grabbable`, `ItemSocket`, `PointerButton`, `InteractionQuery` (`Scripts/XR/`) | Physics-free hand interaction: grab at the hand or along the beam, drop into sockets, press 3D buttons |
| `XRLocomotion` | Teleport, smooth movement, snap / smooth turning, flat WASD and travel spots; never leaves the `WalkableArea` |
| `Workstation` | StateChart Idle ⇄ Running; `TimingGauge` skill check; grinder / cooker / press by `step` |
| `Customer`, `CustomerFlow`, `SalesWindow`, `SalesBoard` | Pooled customers with StateChart Walking ⇄ Waiting → Leaving; the window runs the sale rules (`SalesMath`) |
| `Yard`, `Raider`, `RaidSquad`, `AttackerDirector` | The open yard (round obstacles, cover, line of sight; `YardNavigation`); pooled raiders with StateChart Alive { Moving ⇄ InCover, Attacking } → Dead, moving in squads that leapfrog and rush together |
| `HouseTurret`, `SecurityPc`, `TurretConsole` | Roof turrets (house upgrade) that aim on their own or from the office PC's camera view |
| `GunModel` | The animated gun in hand (slide, pump, bolt, flash, kick) |
| `RaiderBody` | A raider's jointed body (hips, torso, head, arms, legs) built from exports and animated procedurally: walk cycle, crouch, strike |
| `TurretSeat` | "VR in VR": the goggles put the player into a roof turret (view at its camera, barrel follows the hand) |
| `FrontDoor`, `HingeHandle` | The door: StateChart Closed { Unlocked ⇄ Locked } ⇄ Open; grab-and-swing handles, bolts on both sides, opens the doorway in the `WalkableArea` |
| `Armory`, `WeaponData`, `WeaponLoadout`, `Profile.armory` | Guns and ammo: bought at the terminal, fired by the FrontGarden |
| `Worker` | StateChart Absent → Working ⇄ Striking; lives in its front's scene |
| Pure logic (`Scripts/Game/`) | `TimingGauge`, `QualityMath`, `Stash`, `SalesMath`, `CustomerOrder`, `HeatMeter`, `DayClock`, `RaidPlanner`, `WeaponLoadout`, `YardNavigation`, `WeaponBallistics`, `WalkMotion` — unit-tested |

All numbers are data: ingredients, recipes, customer types, guns and raids in
`Ressources/`, upgrades in one catalog per area (`Ressources/Upgrades/<Area>/`),
raiders as exports on their scenes, the yard's obstacles on `Yard`, pacing on `AttackerDirector`,
`CustomerFlow`, `DayCycle` and `Operation`.

## VR design decisions

- **Space.** A 10 × 10 m house: every front is a few steps away. Rooms
  connect through doorways; the walkable floor is a handful of rectangles.
- **Splitting attention.** The wrist panel shows time, cash, reputation,
  stash, heat, door health and the queue, so you can decide where to go
  next without walking there. Raids, waves, rams and the door
  falling are announced in front of you with sound and a heavy rumble.
- **Readable yard.** The front room has two wide windows over the yard;
  raiders' glowing visors stand out at night, and cover is big and simple.
- **Hands.** The dominant trigger picks up and puts in by pointing, like
  the flat cursor's clicks; grip grabs with either hand (hold to carry, a
  quick click to keep holding). The off-hand trigger only shoots (the gun
  sits in that hand) or clicks a screen / button — it never picks anything
  up, so aiming past the door handle still fires. Distance grab along the
  beam keeps reach comfortable.
- **Comfort.** Stick walking where you look plus teleport and snap turning
  on the off-hand stick; smooth turning in Settings. Seated players are
  lifted to standing height (re-measured on recenter). No camera motion the
  player didn't make; popups and announcements appear where you look and
  stay world-locked.
- **Performance** (standalone headsets are phones): no physics for
  interaction or combat, pooled spawns, shared meshes and materials, blob
  shadows, one unshadowed light, fog instead of far draw distance, a few
  in-world screens plus the popup screen; the Security PC's small camera
  view renders only while someone looks at it.

## Co-op (two players)

Pause menu → **Play Together**. One player hosts, the other joins: a game
on the same Wi-Fi shows up in the list (one click); over the internet the
guest types the host's address with the keypad. The host's router is asked
to open UDP port 7777 by itself (UPnP); when it refuses, forward UDP 7777 to
the host's device by hand or put both players in a VPN such as Tailscale.

- **The host's game is the world.** The guest's copy reloads as a mirror
  (`HouseLevel.is_mirror`): nothing simulates there, it shows the host's
  snapshots (`HouseCoopSync`, `NetEntities`).
- **Same rules for both hands.** The guest's trigger, grip and clicks are
  sent to the host with their hand pose and carried out by a
  `HandInteractor` — the same class the host's own rig uses. Items the guest
  holds are drawn right at the guest's hand, so holding never lags.
- **Shared:** cash, stash, reputation, heat, upgrades, discovered recipes,
  the time of day, the wrist status, the lab (items, stations, Stop
  buttons), selling at the window, the front door (swing, bolts, health —
  the doorway opens for both), shooting (the guest's gun trigger fires the
  same gun with shared ammo; every tracer is shown to both), every in-world
  board (sales, office, armory, build board: `ControlMirror` sends a board's
  look when it changes), customers and raiders (as figures), announcements,
  floating texts and the guest's rumbles. Each player sees the other's head,
  hands, beam and name (`RemotePlayer`).
- **Not shared yet:** sounds, the gun model in the guest's hand, raiders'
  and customers' animations and health bars on the guest's side (they move
  but are frozen pictures), more than two players.
- The host's pause menu doesn't stop the world; the guest's copy never
  writes the guest's own save (it reloads it after leaving).
- Next after that: a relay server for players whose routers can't be
  opened (strict NAT), and more than two players.
- Test: `Tools/coop_test.sh` starts a host and a guest and plays a few steps.

## Not built yet / next steps

- **Co-op, part 3:** sounds, the guest's gun model, live raider / customer
  animations on the guest's side; a relay for strict NAT; more players.
- **Meta layer:** contracts, rival territory, random events, the campaign
  and bosses that change the world.
- **Yard overview:** a tabletop miniature of the yard in the hall.
- **More content:** recipes, customer types, traps, more raider types,
  more lab rooms; worker skill per person; raiders that also try windows.
- **Comfort:** a vignette for smooth movement.
- **On device:** tune reach, station heights, screen sizes and text, haptics.
- **Art and audio:** stand-in meshes and synthesized sounds; no music.
- **Town:** shops to enter, moving traffic, voice actors for the
  placeholder voices, raiders that come down the street instead of
  appearing at the yard's edge.
