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

> **Status: first playable.** One shift (a day and a night) with all three
> fronts, the economy, the five upgrade branches and hired crew is built and
> covered by the unit and smoke tests in the flat simulator. The OpenXR path
> (headset rendering, tracked hands, grip / trigger / sticks, haptics)
> follows Godot's API but **has not been run on a headset yet** — expect to
> tune reach, sizes and comfort on device. Co-op and the meta layer are not
> built yet (see the end).

## A shift

1. **Craft** in the lab: grab ingredients from the crates, grind, cook and
   press them.
2. **Sell** at the back window: set your price, sell or decline.
3. Earn **cash** and **reputation**; every sale also adds **heat**.
4. **Upgrade** at the office: production, sales, defense, workforce, house.
5. **Survive** the attackers walking up the garden to the front door.

A shift runs from 07:00 to the next dawn (5 min of day, 4 min of night by
default — `DayCycle` on `House.tscn`). Customers and attackers come all the
time; day and night change what comes and how hard:

| | Day | Night |
|---|---|---|
| Customers | Many regulars, hagglers, bulk buyers | Fewer, richer: connoisseurs, VIPs (after "VIP Access") |
| Attackers | Junkies, the odd police patrol | More junkies, mafia crews (after 10 reputation), the boss wave at 01:00 |
| Always | Heat from sales sends police raids at 50 and 80 heat | |

**Win:** reach dawn — the day counter goes up and the shift's earnings are
the score. **Lose:** the front door breaks — the stash is lost and repairs
cost 20% of your cash, but upgrades, crew and banked cash stay, and you
replay that day.

## Controls

| | Headset | Flat simulator (no headset) |
|---|---|---|
| Grab / let go | Grip (at the hand, or along the beam) | Click an item / click where to put it |
| Use (station buttons, screens, build) | Dominant-hand trigger | Click |
| Blaster | Off-hand trigger (from the front room) | Right-click, or click an attacker |
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
room**: shoot through the windows with the blaster and build on garden
tiles (pick a card on the board above the gate, then point at a tile).

| Attacker | Behavior | Comes because |
|---|---|---|
| Junkie | Fast, weak; grabs stock at the door and runs | Always; more with a full stash |
| Cop | Slow, armored (6 off every hit) | Patrols; raids when heat crosses 50 / 80 |
| Mafia goon | Tough, light armor | At night once you have 10 reputation |
| Mafia boss | Huge; towers and guards do only 40% damage | 01:00 every night, with three goons |

| Tower | Cost | Good against |
|---|---|---|
| Turret | $120 | Junkies (fast, weak bolts) |
| Heavy gun | $260 (unlock) | Cops (slow, strong, pierces armor) |
| Barricade | $80 | Holds anything in its lane |

No single answer works: junkies swarm, cops shrug off light bolts, the boss
mostly needs your blaster.

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
  product, raids at thresholds, cooling over time, bribes).
- **Tone:** stylized (the existing palette and placeholder art).
- **First playable size:** 3 products, 4 ingredients, 5 customer types,
  4 attackers, 3 towers, 16 upgrades.
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
    │   ├── HouseShell         walls / doors / windows / floor built from a few numbers
    │   ├── FrontGarden        DEFENSE   Garden/FrontGarden.tscn: lanes, door, towers, build board, guards, AttackerDirector
    │   ├── SalesWindow        CUSTOMERS Sales/SalesWindow.tscn: window, queue, board, dealers, CustomerFlow
    │   ├── Lab                HOUSE     Lab/Lab.tscn: crates, grinder, cooker, press, crafters, recipes
    │   ├── Office             HOUSE     Office/Office.tscn: upgrade board, bribes
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
| `HouseLevel` | Runs the shift: time, wages for `Types.GROUP_CREW`, win at dawn, lose on `shift_lost`, wrist status from the fronts' status lines |
| `Grabbable`, `ItemSocket`, `PointerButton`, `InteractionQuery` (`Scripts/XR/`) | Physics-free hand interaction: grab at the hand or along the beam, drop into sockets, press 3D buttons |
| `XRLocomotion` | Teleport, smooth movement, snap / smooth turning, flat WASD and travel spots; never leaves the `WalkableArea` |
| `Workstation` | StateChart Idle ⇄ Running; `TimingGauge` skill check; grinder / cooker / press by `step` |
| `Customer`, `CustomerFlow`, `SalesWindow`, `SalesBoard` | Pooled customers with StateChart Walking ⇄ Waiting → Leaving; the window runs the sale rules (`SalesMath`) |
| `LaneBoard`, `LaneEnemy`, `Turret`, `LaneDefender`, `FrontDoor`, `AttackerDirector` | Lane math defense; attackers are pooled with StateChart Alive { Advancing ⇄ Attacking } → Dead |
| `Worker` | StateChart Absent → Working ⇄ Striking; lives in its front's scene |
| Pure logic (`Scripts/Game/`) | `TimingGauge`, `QualityMath`, `Stash`, `SalesMath`, `CustomerOrder`, `HeatMeter`, `DayClock` — unit-tested |

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
