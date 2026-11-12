---
paths:
  - "**/*.tscn"
  - "**/*.tres"
---
# Editing Godot scene and resource files by hand

- Files are in Godot 4.7 format: `uid` in the header, `unique_id=` on every
  node, no `load_steps`. Don't add `load_steps` or strip `unique_id`s; new
  nodes may omit `unique_id` (the editor assigns one on the next save).
- Exported Node references (e.g. `health_component = NodePath("../HealthComponent")`)
  must be listed in the node header as `node_paths=PackedStringArray("health_component")`,
  otherwise Godot silently leaves them null.
- New `ext_resource` entries may omit `uid=`; never invent uid strings.
- Inherited scenes (levels) reference base nodes by `parent="World"` etc. and
  only list changed properties.
- After editing, run `Tools/smoke_test.sh` (or the `smoke-test` skill).
