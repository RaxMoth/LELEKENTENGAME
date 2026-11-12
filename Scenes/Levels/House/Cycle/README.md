# The 3-day cycle (part of the house area)

Days 1–3 bring only customers; when night falls on day 3 the police raid
the house in waves; beating the last wave wins the shift and starts the
next cycle, which ends in a harder raid.

| Files | What |
|---|---|
| `HouseCycle.tscn`, `house_cycle.gd` | StateChart Selling → Raid { WaveBreak ⇄ WaveActive } → Cleared; plans the raid, calls the fronts' raid hooks |
| `Ressources/Raids/police_raids.tres` (`RaidData`) | Days per cycle, waves, cops, SWAT, escalation, heat bonus, breaks |
| `Scripts/Game/raid_planner.gd`, `raid_wave.gd` | Pure rules (unit-tested in `Tests/Unit/raid_cycle_test.gd`) |

Flow, driven by `HouseLevel`:

1. `_on_level_started` announces the day and the countdown (`get_day_announcement`).
2. `_on_nightfall` on a raid day calls `start_raid()`; from then on the clock stops.
3. `WaveBreak` counts down (`seconds_before_first_wave` / `seconds_between_waves`),
   `WaveActive` hands the `RaidWave` to every front (`on_raid_wave_started`) and
   ends when every front reports `get_raiders_left() == 0`.
4. `Cleared` → `raid_cleared` → the level wins the shift; heat is reset and the
   day counter moves on to day 1 of the next cycle.

Fronts ask `context.allows_customers()` / `context.is_raid_active()`; they
never reference the cycle's nodes.
