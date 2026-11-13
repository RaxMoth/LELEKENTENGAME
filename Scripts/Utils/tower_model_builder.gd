## Builds what a field tower looks like for its kind, out of a few primitive
## meshes with real materials (the guns' metal, worn steel, polymer, burlap)
## and painted accents — so a mortar looks like a mortar and a shock coil
## like a coil:
##   GUN    — a tripod with a twin-barreled machine gun, a shield plate and an ammo box.
##   MORTAR — a base plate in a ring of sandbags, a bipod and a steep tube.
##   BEAM   — a column with cooling fins and an emitter dish with a glowing lens.
##   SHOCK  — a coil tower: insulators, copper windings, a crown and a glowing sphere.
## The parts go under three nodes the tower hands in: the base (the ground),
## the head (turns to aim) and the barrel (pitches); the FieldTower hides the
## turret's generic housing and tube.
##
##   TowerModelBuilder.build(tower_data, base_root, head_root, barrel_root, head_height)
##
## Standalone headsets pay per draw call: the parts of each root are merged
## into one mesh with one surface per material (a handful of draws per
## tower instead of dozens of nodes), and the merged meshes are cached per
## tower kind and height, so a pooled tower or an upgrade only adds three
## MeshInstance3Ds. Call clear_cache() when the game shuts down (the
## PoolManager does).
##
## Dependencies: TowerData, PlaceholderMesh3D, Palette
class_name TowerModelBuilder
extends RefCounted

const METAL: Material = preload("res://Assets/Materials/gun_metal.tres")
const WORN: Material = preload("res://Assets/Materials/gun_metal_worn.tres")
const POLYMER: Material = preload("res://Assets/Materials/gun_polymer.tres")
const STEEL: Material = preload("res://Assets/Materials/steel_frame.tres")
const BURLAP: Material = preload("res://Assets/Materials/burlap.tres")
## How steeply the mortar's tube points up (radians).
const MORTAR_TUBE_PITCH: float = PI * 0.3

## Merged meshes per model key: [base, head, barrel] (null where a root has no parts).
static var _models: Dictionary[String, Array] = {}


## Builds the model of a [param tower] tower. [param head_height] is where
## the head sits above the ground (the base reaches up to it).
static func build(tower: TowerData, base: Node3D, head: Node3D, barrel: Node3D, head_height: float) -> void:
	var roots: Array[Node3D] = [base, head, barrel]
	var key: String = "%s|%d|%.3f|%s" % [tower.resource_path, tower.kind, head_height, tower.color.to_html()]
	if not _models.has(key):
		if not base.is_inside_tree():
			# Painted parts only get their mesh in the tree: keep the parts unmerged.
			_build_parts(tower, base, head, barrel, head_height)
			return
		_build_parts(tower, base, head, barrel, head_height)
		var merged: Array[Mesh] = []
		for root: Node3D in roots:
			merged.append(_merge_children(root))
		_models[key] = merged
	var meshes: Array = _models[key]
	for root_index: int in roots.size():
		var mesh: Mesh = meshes[root_index] as Mesh
		if mesh == null:
			continue
		var model: MeshInstance3D = MeshInstance3D.new()
		model.name = &"Model"
		model.mesh = mesh
		_finish(roots[root_index], model)


## Frees the merged meshes (before the renderer shuts down).
static func clear_cache() -> void:
	_models.clear()


## Merges [param root]'s part nodes into one mesh, a surface per material,
## and frees the parts. Null when the root got no parts.
static func _merge_children(root: Node3D) -> Mesh:
	var tools: Dictionary[Material, SurfaceTool] = {}
	var parts: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		var part: MeshInstance3D = child as MeshInstance3D
		if part == null or part.mesh == null:
			continue
		parts.append(part)
		for surface_index: int in part.mesh.get_surface_count():
			var material: Material = part.material_override if part.material_override != null else part.mesh.surface_get_material(surface_index)
			if not tools.has(material):
				var surface_tool: SurfaceTool = SurfaceTool.new()
				surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = surface_tool
			tools[material].append_from(part.mesh, surface_index, part.transform)
	for part: MeshInstance3D in parts:
		root.remove_child(part)
		part.free()
	if tools.is_empty():
		return null
	var merged: ArrayMesh = ArrayMesh.new()
	for material: Material in tools:
		tools[material].commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, material)
	return merged


static func _build_parts(tower: TowerData, base: Node3D, head: Node3D, barrel: Node3D, head_height: float) -> void:
	match tower.kind:
		TowerData.Kind.MORTAR:
			_build_mortar(tower, base, head, barrel)
		TowerData.Kind.BEAM:
			_build_lance(tower, base, head, barrel, head_height)
		TowerData.Kind.SHOCK:
			_build_coil(tower, base, head_height)
		_:
			_build_sentry(tower, base, head, barrel, head_height)


static func _build_sentry(tower: TowerData, base: Node3D, head: Node3D, barrel: Node3D, head_height: float) -> void:
	# A tripod: three splayed legs and a center post.
	for leg_index: int in 3:
		var angle: float = TAU * leg_index / 3.0
		var foot: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.55
		var top: Vector3 = Vector3(0.0, head_height * 0.55, 0.0)
		_add_strut(base, foot, top, 0.035, WORN)
	_add_cylinder(base, Vector3(0.0, head_height * 0.77, 0.0), 0.06, head_height * 0.46, METAL)
	# The gun: receiver, feed cover, shield plate, ammo box, sight.
	_add_box(head, Vector3(0.0, 0.2, -0.05), Vector3(0.3, 0.22, 0.56), METAL)
	_add_box(head, Vector3(0.0, 0.33, 0.0), Vector3(0.22, 0.05, 0.34), WORN)
	_add_box(head, Vector3(0.0, 0.26, -0.4), Vector3(0.66, 0.44, 0.025), WORN)
	_add_painted(head, Vector3(0.27, 0.16, 0.02), PlaceholderMesh3D.ShapeKind.BOX, Vector3(0.2, 0.18, 0.28), tower.color.darkened(0.5))
	_add_box(head, Vector3(-0.12, 0.38, -0.12), Vector3(0.06, 0.06, 0.16), POLYMER)
	# Twin barrels with cooling jackets and muzzle brakes.
	for side: float in [-0.055, 0.055]:
		_add_cylinder(barrel, Vector3(side, 0.0, -0.42), 0.028, 0.84, METAL, true)
		_add_cylinder(barrel, Vector3(side, 0.0, -0.2), 0.045, 0.3, WORN, true)
		_add_cylinder(barrel, Vector3(side, 0.0, -0.82), 0.04, 0.07, METAL, true)


static func _build_mortar(tower: TowerData, base: Node3D, head: Node3D, barrel: Node3D) -> void:
	# Base plate in a ring of sandbags, two layers.
	_add_cylinder(base, Vector3(0.0, 0.03, 0.0), 0.42, 0.06, WORN)
	for layer: int in 2:
		var bags: int = 11 if layer == 0 else 9
		for bag_index: int in bags:
			var angle: float = TAU * (bag_index + layer * 0.5) / bags
			var spot: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (0.78 - layer * 0.06)
			var bag: MeshInstance3D = _add_capsule(base, spot + Vector3(0.0, 0.1 + layer * 0.16, 0.0), 0.1, 0.42, BURLAP)
			bag.rotation = Vector3(0.0, -angle, PI * 0.5)
	# Bipod legs from the head down to the plate's front edge, a traverse wheel.
	for side: float in [-0.22, 0.22]:
		_add_strut(head, Vector3(side, -0.4, -0.3), Vector3(side * 0.3, 0.15, -0.15), 0.02, WORN)
	var wheel: MeshInstance3D = _add_torus(head, Vector3(0.12, 0.12, 0.05), 0.05, 0.075, STEEL)
	wheel.rotation.z = PI * 0.5
	# The tube points up steeply (the shell flies in an arc).
	var tube_root: Node3D = Node3D.new()
	tube_root.rotation.x = MORTAR_TUBE_PITCH
	barrel.add_child(tube_root)
	_add_cylinder(tube_root, Vector3(0.0, 0.0, -0.45), 0.075, 1.1, METAL, true)
	_add_sphere(tube_root, Vector3(0.0, 0.0, 0.1), 0.085, WORN)
	var muzzle_ring: MeshInstance3D = _add_torus(tube_root, Vector3(0.0, 0.0, -1.0), 0.075, 0.095, WORN)
	muzzle_ring.rotation.x = PI * 0.5
	_add_painted(tube_root, Vector3(0.0, 0.0, -0.75), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.16, 0.04, 0.16), tower.color, 0.0, true)


static func _build_lance(tower: TowerData, base: Node3D, head: Node3D, barrel: Node3D, head_height: float) -> void:
	# A foundation and a column with cooling fins and a cable run.
	_add_cylinder(base, Vector3(0.0, 0.12, 0.0), 0.42, 0.24, POLYMER)
	_add_cylinder(base, Vector3(0.0, head_height * 0.5, 0.0), 0.11, head_height, STEEL)
	for fin_index: int in 6:
		_add_cylinder(base, Vector3(0.0, 0.6 + fin_index * (head_height - 0.9) / 6.0, 0.0), 0.26, 0.02, METAL)
	_add_painted(base, Vector3(0.13, head_height * 0.5, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.035, head_height * 0.9, 0.035), tower.color.darkened(0.3))
	# The emitter housing and a focusing tube with a dish and a glowing lens.
	_add_sphere(head, Vector3(0.0, 0.2, 0.0), 0.24, POLYMER, Vector3(1.0, 0.8, 1.2))
	_add_cylinder(barrel, Vector3(0.0, 0.0, -0.35), 0.075, 0.6, METAL, true)
	var dish: MeshInstance3D = MeshInstance3D.new()
	var dish_mesh: CylinderMesh = CylinderMesh.new()
	dish_mesh.top_radius = 0.24
	dish_mesh.bottom_radius = 0.08
	dish_mesh.height = 0.18
	dish.mesh = dish_mesh
	dish.material_override = WORN
	dish.position = Vector3(0.0, 0.0, -0.68)
	dish.rotation.x = -PI * 0.5
	_finish(barrel, dish)
	_add_painted(barrel, Vector3(0.0, 0.0, -0.72), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(0.14, 0.14, 0.14), tower.color, 1.0)


static func _build_coil(tower: TowerData, base: Node3D, head_height: float) -> void:
	# A heavy foot, a stack of insulators, copper windings, a crown and a sphere.
	_add_cylinder(base, Vector3(0.0, 0.15, 0.0), 0.4, 0.3, WORN)
	var insulator_top: float = head_height * 0.55
	for insulator_index: int in 4:
		var height: float = 0.3 + (insulator_top - 0.3) * (insulator_index + 0.5) / 4.0
		_add_painted(base, Vector3(0.0, height, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.36 - insulator_index * 0.04, (insulator_top - 0.3) / 4.0 * 0.8, 0.36 - insulator_index * 0.04), Palette.TOWER_CERAMIC)
	_add_cylinder(base, Vector3(0.0, (insulator_top + head_height) * 0.5, 0.0), 0.09, head_height - insulator_top, STEEL)
	var windings: int = 9
	for winding_index: int in windings:
		var height: float = insulator_top + 0.1 + (head_height - insulator_top - 0.25) * winding_index / float(windings - 1)
		var ring: PlaceholderMesh3D = _add_painted(base, Vector3(0.0, height, 0.0), PlaceholderMesh3D.ShapeKind.CYLINDER, Vector3(0.36, 0.035, 0.36), Palette.TOWER_COPPER)
		ring.glow = 0.1
	_add_torus(base, Vector3(0.0, head_height + 0.05, 0.0), 0.2, 0.34, STEEL)
	_add_painted(base, Vector3(0.0, head_height + 0.2, 0.0), PlaceholderMesh3D.ShapeKind.SPHERE, Vector3(0.24, 0.24, 0.24), tower.color, 1.0)

# ============================================
# PARTS
# ============================================

static func _add_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, at, material)


static func _add_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, along_z: bool = false) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var part: MeshInstance3D = _add_mesh(parent, mesh, at, material)
	if along_z:
		part.rotation.x = PI * 0.5
	return part


static func _add_sphere(parent: Node3D, at: Vector3, radius: float, material: Material, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var part: MeshInstance3D = _add_mesh(parent, mesh, at, material)
	part.scale = stretch
	return part


static func _add_capsule(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 2
	return _add_mesh(parent, mesh, at, material)


static func _add_torus(parent: Node3D, at: Vector3, inner_radius: float, outer_radius: float, material: Material) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	return _add_mesh(parent, mesh, at, material)


## A strut (a leg, a cable) from [param from] to [param to].
static func _add_strut(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var part: MeshInstance3D = _add_cylinder(parent, (from + to) * 0.5, radius, from.distance_to(to), material)
	var up: Vector3 = (to - from).normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	part.basis = Basis(side, up, side.cross(up))
	return part


## A painted part in one of the shared colors (accents, lights).
static func _add_painted(parent: Node3D, at: Vector3, shape: PlaceholderMesh3D.ShapeKind, size: Vector3, color: Color, glow: float = 0.0, along_z: bool = false) -> PlaceholderMesh3D:
	var part: PlaceholderMesh3D = PlaceholderMesh3D.new()
	part.shape_kind = shape
	part.size = size
	part.color = color
	part.glow = glow
	part.position = at
	if along_z:
		part.rotation.x = PI * 0.5
	_finish(parent, part)
	return part


static func _add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	_finish(parent, part)
	return part


static func _finish(parent: Node3D, part: GeometryInstance3D) -> void:
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
