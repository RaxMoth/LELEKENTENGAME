# Town — the streets around the house

The house stands on one block of a town: a grid of streets with sidewalks,
blocks of brick, plaster and glass buildings that grow into towers toward
downtown, two parks, a plaza with a fountain, street lamps and parked cars.
The player can walk anywhere outside: out of the front door, through the
gate in the garden fence, along the streets, through the parks and the
alleys between buildings. Buildings, parked cars, park trees and the
fountain block the way.

People walk the sidewalks from corner to corner. Point at one and pull the
trigger to talk: they stop, face you and answer out loud; a panel beside
them shows what they said and your replies. Talk them into buying and they
come to the back window (`Operation.refer_customer()` →
`CustomerFlow`). Each person can be asked once.

## Files

| File | What |
|---|---|
| `Town.tscn` · `town.gd` | The front: builds the town at load, adds its floor and blockers to the `WalkableArea`, spawns and recycles people, runs conversations, lights windows and lamps at night |
| `Pedestrian.tscn` · `pedestrian.gd` | A person in the street (pooled): `RaiderBody` as a civilian, an `NpcVoice`, an invisible `PointerButton` to talk. StateChart `Walking ⇄ Pausing`, both `→ Talking → Walking` |
| `DialogueBoard.tscn` · `dialogue_board.gd` | The conversation panel (on the Town's `WorldScreen`) |
| `Ressources/Town/town.tres` (`TownData`) | Street grid, park / plaza blocks, building heights, lamps, cars, people, recruiting chance |
| `Ressources/Dialogue/street_talk.tres` (`DialogueData`) | What you can talk about (nodes = what the NPC says by voice category, replies = your buttons, a roll node for "want to buy?") |
| `Scripts/Game/town_layout.gd` | Pure: blocks, building lots, walkable floor, lamps, cars, trees, sidewalk corners (unit-tested) |
| `Scripts/Utils/town_mesh_builder.gd` | Turns the layout into chunked meshes (a few draw calls per chunk); windows light up at night |

## Changing the town

- **Bigger or smaller**: add or remove entries in `street_x` / `street_z`
  (street centre lines). Keep the house's block (`home_block`) around the
  origin; the house's garden needs the block to reach 3 m beyond its fence.
- **Parks / plaza**: list block cells (column, row) in `park_blocks` /
  `plaza_blocks`.
- **Skyline**: `downtown_center`, `downtown_radius`, `low_height`,
  `high_height`.
- **People**: `pedestrian_count` (each one is about 25 small meshes, drawn
  only within 30 m), `pedestrian_voices`, `recruit_chance`.
- **Talk**: edit `street_talk.tres` in the inspector; a node's
  `line_category` must be a category the voices have.

## Voices

Every NPC speaks through an `NpcVoice` (`Scripts/Components/npc_voice.gd`)
with a `VoiceData` (`Ressources/Voices/*.tres`): customers by their type
(`CustomerTypeData.voice`), people in the street by `TownData`, the police
from `Garden/Raider.tscn`. The lines are German internet-meme humour and are
spoken and subtitled in German (not translated).

The recordings are placeholders made by Windows' built-in German speech
voices (Stefan, Katja, Hedda) with a pitch and tempo per character:

```bash
powershell -ExecutionPolicy Bypass -File Tools/generate_voices.ps1
```

Edit `Tools/Voices/lines.tsv` (who says what) or `Tools/Voices/voices.tsv`
(the characters) and rerun. A real recording dropped over a `.wav` with the
same name replaces the synthetic line without any other change.
