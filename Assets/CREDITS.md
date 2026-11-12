# Third-party assets

Every downloaded asset in the project is **CC0 1.0 (public domain)**: free
to use, modify and ship commercially, no attribution required. They are
listed here anyway, so anyone can find the source, check the licence and
fetch a higher resolution.

- ambientCG — licence: <https://docs.ambientcg.com/license/>
- Poly Haven — licence: <https://polyhaven.com/license>

Only the maps the game uses are committed (Color, NormalGL, sometimes
Roughness; no displacement, AO or metalness). Textures are the 1K versions,
re-encoded as JPEG (quality 85) to keep the repository small; Godot imports
them VRAM-compressed with mipmaps (ETC2/ASTC on Quest, S3TC/BPTC on desktop).

## Textures (`Assets/Textures/`)

| Used for | Asset | Source | Licence | Changes |
|---|---|---|---|---|
| Inside walls | Painted Plaster 011 | <https://ambientcg.com/view?id=PaintedPlaster011> | CC0 | Color + NormalGL, re-encoded |
| Outside walls, gables | Bricks 097 | <https://ambientcg.com/view?id=Bricks097> | CC0 | Color + NormalGL, re-encoded |
| Roof | Roofing Tiles 015 C | <https://ambientcg.com/view?id=RoofingTiles015C> | CC0 | Color + NormalGL, re-encoded |
| Floor, door and window frames, eaves, garden fence and gate, stash boards and crates | Planks 037 A | <https://ambientcg.com/view?id=Planks037A> | CC0 | Color + NormalGL + Roughness, re-encoded |
| Ceiling, stash shelf blocks | Concrete 035 | <https://ambientcg.com/view?id=Concrete035> | CC0 | Color + NormalGL, re-encoded |
| Patched inside walls (renovation level 1) | Plaster 006 | <https://ambientcg.com/view?id=Plaster006> | CC0 | Color + NormalGL, re-encoded |
| Painted inside walls and ceiling (renovation level 2) | Painted Plaster 017 | <https://ambientcg.com/view?id=PaintedPlaster017> | CC0 | Color + NormalGL, re-encoded |
| Renovated floor, refinished frames, wooden stash shelf | Wood Floor 043 | <https://ambientcg.com/view?id=WoodFloor043> | CC0 | Color + NormalGL + Roughness, re-encoded |
| Renovated outside walls | Bricks 059 | <https://ambientcg.com/view?id=Bricks059> | CC0 | Color + NormalGL, re-encoded |
| Renovated roof | Roofing Tiles 015 A | <https://ambientcg.com/view?id=RoofingTiles015A> | CC0 | Color + NormalGL, re-encoded |
| Lawn | Ground 037 | <https://ambientcg.com/view?id=Ground037> | CC0 | Color + NormalGL, re-encoded |
| Garden path, lanes | Ground 023 | <https://ambientcg.com/view?id=Ground023> | CC0 | Color + NormalGL, re-encoded |
| Back yard | Gravel 032 | <https://ambientcg.com/view?id=Gravel032> | CC0 | Color + NormalGL, re-encoded |
| Front door | Door 001 | <https://ambientcg.com/view?id=Door001> | CC0 | Cropped to the leaf, glass panes boarded up with OSB (below), stretched to 512×1024 (`Door001_Boarded_*`) |
| Front door (boards behind the panes) | Oriented Strand Board | <https://polyhaven.com/a/oriented_strand_board> | CC0 | Diffuse composited into Door 001; not committed on its own |

## Models (`Assets/Models/`)

Trees and plants are **impostors** baked with `Tools/bake_impostor.gd`: a few
crossed alpha-cutout quads (6 triangles for a tree, 4 for a plant) textured
with renders of the original model. The original models (0.3–4 M triangles,
50–100 MB each) are not in the repository.

| Used for | Asset | Source | Licence | In the project |
|---|---|---|---|---|
| Large trees | Island Tree 01 | <https://polyhaven.com/a/island_tree_01> | CC0 | `Trees/IslandTree01/` impostor, 3 views |
| Wide trees | Island Tree 02 | <https://polyhaven.com/a/island_tree_02> | CC0 | `Trees/IslandTree02/` impostor, 3 views |
| Slender trees | Tree Small 02 | <https://polyhaven.com/a/tree_small_02> | CC0 | `Trees/SmallTree02/` impostor, 3 views |
| Tall dry grass | Grass Medium 02 (variants d, e) | <https://polyhaven.com/a/grass_medium_02> | CC0 | `Plants/GrassTuftD/`, `Plants/GrassTuftE/` impostors, 2 views |
| Weeds | Nettle Plant (variants tall a, medium a) | <https://polyhaven.com/a/nettle_plant> | CC0 | `Plants/NettleTall/`, `Plants/NettleMedium/` impostors, 2 views |
| Rubbish bags | Trashbag | <https://polyhaven.com/a/trashbag> | CC0 | `Props/Trashbag/` glTF (4.5k triangles), textures scaled to 512 px |
| Old tyres | Old Tyre | <https://polyhaven.com/a/old_tyre> | CC0 | `Props/OldTyre/` glTF (2.9k triangles), textures scaled to 512 px |
| Yard chair | Plastic Monobloc Chair 01 | <https://polyhaven.com/a/plastic_monobloc_chair_01> | CC0 | `Props/MonoblocChair/` glTF (3.4k triangles), textures scaled to 512 px |
| Rusty cans | Can Rusted | <https://polyhaven.com/a/can_rusted> | CC0 | `Props/RustedCan/` glTF (3.5k triangles), textures scaled to 512 px |
