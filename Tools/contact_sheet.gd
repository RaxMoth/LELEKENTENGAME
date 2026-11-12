## Tiles screenshots into one image (used by Tools/screenshots.sh). Each shot
## is scaled to fit its cell, keeping its aspect ratio (portrait menus and
## wide game shots can share a sheet).
##   godot --headless --script Tools/contact_sheet.gd -- out.png columns cell_width cell_height a.png b.png ...
##
## Dependencies: none
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0]
	var columns: int = int(args[1])
	var cell_width: int = int(args[2])
	var cell_height: int = int(args[3])
	var files: PackedStringArray = args.slice(4)
	var gap: int = 8
	var rows: int = ceili(files.size() / float(columns))
	var sheet: Image = Image.create(columns * (cell_width + gap) + gap, rows * (cell_height + gap) + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for index: int in files.size():
		var image: Image = Image.load_from_file(files[index])
		image.convert(Image.FORMAT_RGBA8)
		var fit_scale: float = minf(cell_width / float(image.get_width()), cell_height / float(image.get_height()))
		var fitted_size: Vector2i = Vector2i(roundi(image.get_width() * fit_scale), roundi(image.get_height() * fit_scale))
		image.resize(fitted_size.x, fitted_size.y, Image.INTERPOLATE_LANCZOS)
		var cell_origin: Vector2i = Vector2i(gap + (index % columns) * (cell_width + gap), gap + (index / columns) * (cell_height + gap))
		var centering: Vector2i = (Vector2i(cell_width, cell_height) - fitted_size) / 2
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, fitted_size), cell_origin + centering)
	sheet.save_png(out_path)
	quit()
