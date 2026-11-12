## Bakes a Quest-friendly cross-billboard impostor from a heavy glTF model
## (a Poly Haven tree: 0.3–4 M triangles) — a few intersecting alpha-cutout
## quads around the trunk (2 triangles each), textured with orthographic
## renders of the model from as many directions.
##
## Writes, next to [out]:
##   <name>_Albedo.webp     atlas of the views (unlit color + alpha, back
##                          leaves darkened a little for depth)
##   <name>_NormalGL.webp   matching normals (OpenGL convention), so the
##                          quads take the level's sun, moon and ambient
##   <name>_Impostor.tres   the quads (ArrayMesh, base of the model at the origin)
##   <name>_Material.tres   alpha scissor + alpha to coverage, both sides
##
## Place copies with a PropScatter3D (one draw call for all of them), or a
## MeshInstance3D with the mesh and the material (shadows off).
##
## The model is loaded at run time (GLTFDocument) from anywhere on disk, so a
## 50 MB download never has to enter the project. Opens a window (rendering
## needs a GPU), takes a few seconds, quits.
##
##   Tools/godot.sh --xr-mode off --script Tools/bake_impostor.gd -- \
##       model=/abs/path/tree.gltf out=res://Assets/Models/Trees/Oak/Oak \
##       [views=3] [cell=1024] [node=<name part>] [depth_shading=0.45] [cutoff=0.5]
##
## cell is the longer side of each view in pixels (1024 keeps every view
## within the 1K texture budget); the atlas holds the views side by side.
##
## Dependencies: none (runs as a SceneTree script, outside the game)
extends SceneTree

## Renders at this multiple of the cell size, then scales down (smooth edges).
const SUPERSAMPLING: int = 2
## Room around the model in each view.
const FRAME_MARGIN: float = 1.03
const FLAT_NORMAL: Color = Color(0.5, 0.5, 1.0, 1.0)
const WEBP_QUALITY: float = 0.9
const ALPHA_SCISSOR_THRESHOLD: float = 0.4

## Unlit color of the model's materials with alpha cut out; leaves further back
## in the view get darker so the flat card keeps some depth.
const ALBEDO_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform float alpha_cutoff = 0.5;
uniform float near_depth = 0.0;
uniform float depth_range = 1.0;
uniform float depth_shading = 0.45;
void fragment() {
	vec4 color = albedo_color;
	if (use_albedo_texture) {
		color *= texture(albedo_texture, UV);
	}
	if (color.a < alpha_cutoff) {
		discard;
	}
	float depth_amount = clamp((-VERTEX.z - near_depth) / depth_range, 0.0, 1.0);
	ALBEDO = color.rgb * (1.0 - depth_shading * depth_amount);
}
"""

## View-space normal (with the model's normal map) written as a color. The
## viewport encodes its output as sRGB, so the value is linearized first.
const NORMAL_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform bool use_normal_texture = false;
uniform float alpha_cutoff = 0.5;
vec3 srgb_to_linear(vec3 color) {
	return mix(pow((color + vec3(0.055)) / vec3(1.055), vec3(2.4)), color / vec3(12.92), lessThan(color, vec3(0.04045)));
}
void fragment() {
	float alpha = albedo_color.a;
	if (use_albedo_texture) {
		alpha *= texture(albedo_texture, UV).a;
	}
	if (alpha < alpha_cutoff) {
		discard;
	}
	vec3 normal = normalize(NORMAL);
	if (use_normal_texture) {
		vec3 detail = texture(normal_texture, UV).xyz * 2.0 - 1.0;
		normal = normalize(TANGENT * detail.x + BINORMAL * detail.y + NORMAL * detail.z);
	}
	ALBEDO = srgb_to_linear(normal * 0.5 + 0.5);
}
"""

var _options: Dictionary[String, String] = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.split("=", true, 1)
		if parts.size() == 2:
			_options[parts[0]] = parts[1]
	if not _options.has("model") or not _options.has("out"):
		push_error("usage: model=/abs/path.gltf out=res://path/Name [views=3] [cell=1024] [node=part] [depth_shading=0.45] [cutoff=0.5]")
		quit(1)
		return
	_bake.call_deferred()


func _bake() -> void:
	var view_count: int = int(_options.get("views", "3"))
	var cell_size: int = int(_options.get("cell", "1024"))
	var out_prefix: String = _options["out"]
	var asset_name: String = out_prefix.get_file()
	var model: Node3D = _load_model(_options["model"], _options.get("node", ""))
	if model == null:
		quit(1)
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(model)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	# Bounds around the trunk axis (the model's origin): radius in XZ, height in Y.
	var radius: float = 0.0
	var bottom: float = INF
	var top: float = -INF
	for mesh_instance: MeshInstance3D in meshes:
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_instance.global_transform * PackedVector3Array(mesh_instance.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX])
			for vertex: Vector3 in vertices:
				radius = maxf(radius, Vector2(vertex.x, vertex.z).length())
				bottom = minf(bottom, vertex.y)
				top = maxf(top, vertex.y)
	var view_height: float = (top - bottom) * FRAME_MARGIN
	var aspect: float = radius * 2.0 * FRAME_MARGIN / view_height
	# Both sides multiples of 4 (block compression); the camera keeps the height,
	# so the width it shows follows from the rounded cell.
	var cell_width: int = int(ceilf(cell_size * minf(aspect, 1.0) / 4.0)) * 4
	var cell_height: int = int(ceilf(cell_size / maxf(aspect, 1.0) / 4.0)) * 4
	var view_width: float = view_height * cell_width / cell_height
	print("%s: %d meshes, radius %.2f m, height %.2f..%.2f m, cell %dx%d" % [asset_name, meshes.size(), radius, bottom, top, cell_width, cell_height])
	viewport.size = Vector2i(cell_width, cell_height) * SUPERSAMPLING
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = view_height
	var camera_distance: float = radius * 2.0 + 2.0
	camera.near = 0.05
	camera.far = camera_distance + radius * 2.0 + 1.0
	viewport.add_child(camera)
	camera.current = true
	var albedo_materials: Array[ShaderMaterial] = _apply_pass(meshes, ALBEDO_SHADER)
	for material: ShaderMaterial in albedo_materials:
		material.set_shader_parameter("near_depth", camera_distance - radius)
		material.set_shader_parameter("depth_range", radius * 2.0)
		material.set_shader_parameter("depth_shading", float(_options.get("depth_shading", "0.45")))
	var albedo_atlas: Image = Image.create(cell_width * view_count, cell_height, false, Image.FORMAT_RGBA8)
	var normal_atlas: Image = Image.create(cell_width * view_count, cell_height, false, Image.FORMAT_RGBA8)
	var center: Vector3 = Vector3(0.0, bottom + view_height * 0.5, 0.0)
	for view_index: int in view_count:
		var angle: float = PI * view_index / view_count
		camera.position = center + Vector3(sin(angle), 0.0, cos(angle)) * camera_distance
		camera.look_at(center, Vector3.UP)
		_apply_pass(meshes, ALBEDO_SHADER, albedo_materials)
		var albedo: Image = await _capture(viewport)
		_apply_pass(meshes, NORMAL_SHADER)
		var normal: Image = await _capture(viewport)
		# Transparent texels take their neighbours' color so mipmaps keep no dark fringe.
		albedo.fix_alpha_edges()
		var flat: Image = Image.create(normal.get_width(), normal.get_height(), false, Image.FORMAT_RGBA8)
		flat.fill(FLAT_NORMAL)
		flat.blend_rect(normal, Rect2i(Vector2i.ZERO, normal.get_size()), Vector2i.ZERO)
		for image: Image in [albedo, flat]:
			image.resize(cell_width, cell_height, Image.INTERPOLATE_LANCZOS)
		albedo_atlas.blit_rect(albedo, Rect2i(Vector2i.ZERO, albedo.get_size()), Vector2i(cell_width * view_index, 0))
		normal_atlas.blit_rect(flat, Rect2i(Vector2i.ZERO, flat.get_size()), Vector2i(cell_width * view_index, 0))
	normal_atlas.convert(Image.FORMAT_RGB8)
	var out_directory: String = ProjectSettings.globalize_path(out_prefix.get_base_dir())
	DirAccess.make_dir_recursive_absolute(out_directory)
	albedo_atlas.save_webp(ProjectSettings.globalize_path(out_prefix + "_Albedo.webp"), true, WEBP_QUALITY)
	normal_atlas.save_webp(ProjectSettings.globalize_path(out_prefix + "_NormalGL.webp"), true, WEBP_QUALITY)
	var impostor: ArrayMesh = _build_impostor_mesh(view_count, view_width * 0.5, bottom, view_height)
	ResourceSaver.save(impostor, out_prefix + "_Impostor.tres")
	_write_text(out_prefix + "_Material.tres", _get_material_text(out_prefix))
	print("%s: %d views, %.2f x %.2f m quads, written to %s" % [asset_name, view_count, view_width, view_height, out_directory])
	quit()


func _load_model(path: String, node_part: String) -> Node3D:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var error: Error = document.append_from_file(path, state)
	if error != OK:
		push_error("could not load %s: %s" % [path, error_string(error)])
		return null
	var scene: Node3D = document.generate_scene(state) as Node3D
	if node_part.is_empty():
		return scene
	# Keep one variant of a multi-model file, moved to the origin.
	for child: Node in scene.get_children():
		if child is Node3D and child.name.contains(node_part):
			scene.remove_child(child)
			(child as Node3D).position = Vector3.ZERO
			scene.free()
			return child as Node3D
	push_error("no node containing '%s' in %s" % [node_part, path])
	return null


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, meshes)


## Puts a pass shader on every surface, carrying over the model's textures.
## Reuses [param existing] materials (same order) when given.
func _apply_pass(meshes: Array[MeshInstance3D], shader_code: String, existing: Array[ShaderMaterial] = []) -> Array[ShaderMaterial]:
	var shader: Shader = null
	var materials: Array[ShaderMaterial] = []
	var material_index: int = 0
	for mesh_instance: MeshInstance3D in meshes:
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			if material_index < existing.size():
				mesh_instance.set_surface_override_material(surface_index, existing[material_index])
				materials.append(existing[material_index])
				material_index += 1
				continue
			if shader == null:
				shader = Shader.new()
				shader.code = shader_code
			var source: BaseMaterial3D = mesh_instance.mesh.surface_get_material(surface_index) as BaseMaterial3D
			var pass_material: ShaderMaterial = ShaderMaterial.new()
			pass_material.shader = shader
			pass_material.set_shader_parameter("alpha_cutoff", float(_options.get("cutoff", "0.5")))
			if source != null:
				pass_material.set_shader_parameter("albedo_color", source.albedo_color)
				pass_material.set_shader_parameter("albedo_texture", source.albedo_texture)
				pass_material.set_shader_parameter("use_albedo_texture", source.albedo_texture != null)
				if source.normal_enabled and source.normal_texture != null:
					pass_material.set_shader_parameter("normal_texture", source.normal_texture)
					pass_material.set_shader_parameter("use_normal_texture", true)
			mesh_instance.set_surface_override_material(surface_index, pass_material)
			materials.append(pass_material)
			material_index += 1
	return materials


func _capture(viewport: SubViewport) -> Image:
	for frame: int in 3:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## One quad per view through the trunk axis, each facing its camera, with
## UVs into that view's cell of the atlas (both sides drawn by the material).
func _build_impostor_mesh(view_count: int, half_width: float, bottom: float, height: float) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for view_index: int in view_count:
		var angle: float = PI * view_index / view_count
		var facing: Vector3 = Vector3(sin(angle), 0.0, cos(angle))
		var right: Vector3 = Vector3(cos(angle), 0.0, -sin(angle))
		var u_from: float = float(view_index) / view_count
		var u_to: float = float(view_index + 1) / view_count
		var top_left: Vector3 = -right * half_width + Vector3.UP * (bottom + height)
		var top_right: Vector3 = right * half_width + Vector3.UP * (bottom + height)
		var bottom_right: Vector3 = right * half_width + Vector3.UP * bottom
		var bottom_left: Vector3 = -right * half_width + Vector3.UP * bottom
		var corners: Array[Vector3] = [top_left, top_right, bottom_right, top_left, bottom_right, bottom_left]
		var uvs: Array[Vector2] = [Vector2(u_from, 0.0), Vector2(u_to, 0.0), Vector2(u_to, 1.0), Vector2(u_from, 0.0), Vector2(u_to, 1.0), Vector2(u_from, 1.0)]
		for corner_index: int in corners.size():
			surface_tool.set_normal(facing)
			surface_tool.set_uv(uvs[corner_index])
			surface_tool.add_vertex(corners[corner_index])
	surface_tool.index()
	surface_tool.generate_tangents()
	return surface_tool.commit()


func _get_material_text(out_prefix: String) -> String:
	return """[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="%s_Albedo.webp" id="albedo"]
[ext_resource type="Texture2D" path="%s_NormalGL.webp" id="normal"]

[resource]
transparency = 2
alpha_scissor_threshold = %s
alpha_antialiasing_mode = 1
cull_mode = 2
albedo_texture = ExtResource("albedo")
metallic_specular = 0.2
roughness = 1.0
normal_enabled = true
normal_texture = ExtResource("normal")
""" % [out_prefix, out_prefix, ALPHA_SCISSOR_THRESHOLD]


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
