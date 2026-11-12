## Tiles portrait screenshots into one image (used by Tools/screenshots.sh).
##   godot --headless --script Tools/contact_sheet.gd -- out.png columns cell_width a.png b.png ...
##
## Dependencies: none
extends SceneTree

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0]
	var columns: int = int(args[1])
	var cell_width: int = int(args[2])
	var files: PackedStringArray = args.slice(3)
	var cell_height: int = int(cell_width * 1280.0 / 720.0)
	var gap: int = 8
	var rows: int = ceili(files.size() / float(columns))
	var sheet: Image = Image.create(columns * (cell_width + gap) + gap, rows * (cell_height + gap) + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.5, 0.5))
	for index: int in files.size():
		var image: Image = Image.load_from_file(files[index])
		image.convert(Image.FORMAT_RGBA8)
		image.resize(cell_width, cell_height, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(gap + (index % columns) * (cell_width + gap), gap + (index / columns) * (cell_height + gap)))
	sheet.save_png(out_path)
	quit()
