extends SceneTree

## Deterministically derives the Boot menu icons from Eddy's exact source PNGs.
## Social backgrounds are removed only when near-white pixels are connected to
## one of the four canvas corners. Enclosed white logo pixels remain untouched.

const SOURCE_ROOT := "res://assets/ui/boot/menu_icons/source"
const OUTPUT_ROOT := "res://assets/ui/boot/menu_icons"
const BACKGROUND_TOLERANCE := 18
const FEEDBACK_CANVAS_SIZE := Vector2i(48, 48)
const FEEDBACK_SCALE := 2
const DISCORD_CANVAS_SIZE := Vector2i(48, 48)
const DISCORD_CONTENT_SIZE := Vector2i(44, 40)

const SOCIAL_ICONS: Array[String] = [
	"steam",
	"discord",
	"qq",
]


func _init() -> void:
	for icon_name: String in SOCIAL_ICONS:
		if not _build_social_icon(icon_name):
			quit(1)
			return
	if not _build_feedback_icon():
		quit(1)
		return
	print(
		"BOOT_MENU_ICONS_OK: social=%d feedback=%dx%d scale=%d"
		% [
			SOCIAL_ICONS.size(),
			FEEDBACK_CANVAS_SIZE.x,
			FEEDBACK_CANVAS_SIZE.y,
			FEEDBACK_SCALE,
		])
	quit()


func _build_social_icon(icon_name: String) -> bool:
	var source_path := "%s/%s.png" % [SOURCE_ROOT, icon_name]
	var output_path := "%s/%s.png" % [OUTPUT_ROOT, icon_name]
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(source_path))
	if source == null or source.is_empty():
		push_error("Boot menu icon source missing: %s" % source_path)
		return false
	var output := source.duplicate()
	output.convert(Image.FORMAT_RGBA8)
	var removed := _clear_corner_connected_white(output)
	var preserved_white := _count_preserved_white(output)
	if removed <= 0 or preserved_white <= 0:
		push_error(
			"Boot menu icon cleanup invalid: %s removed=%d white=%d"
			% [icon_name, removed, preserved_white])
		return false
	if not _opaque_pixels_match_source(source, output):
		push_error("Boot menu icon changed protected pixels: %s" % icon_name)
		return false
	if icon_name == "discord":
		output = _normalize_discord(output)
		preserved_white = _count_preserved_white(output)
	for corner: Vector2i in [
		Vector2i.ZERO,
		Vector2i(output.get_width() - 1, 0),
		Vector2i(0, output.get_height() - 1),
		Vector2i(output.get_width() - 1, output.get_height() - 1),
	]:
		if output.get_pixelv(corner).a > 0.0:
			push_error("Boot menu icon corner is not transparent: %s" % icon_name)
			return false
	var save_error: Error = output.save_png(
		ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error(
			"Boot menu icon save failed: %s" % error_string(save_error))
		return false
	var used_rect: Rect2i = output.get_used_rect()
	print(
		"BOOT_MENU_ICON_OK: %s size=%dx%d used=%dx%d removed=%d preserved_white=%d"
		% [
			icon_name,
			output.get_width(),
			output.get_height(),
			used_rect.size.x,
			used_rect.size.y,
			removed,
			preserved_white,
		])
	return true


func _normalize_discord(cleaned: Image) -> Image:
	var used_rect := cleaned.get_used_rect()
	var content := cleaned.get_region(used_rect)
	content.resize(
		DISCORD_CONTENT_SIZE.x,
		DISCORD_CONTENT_SIZE.y,
		Image.INTERPOLATE_NEAREST)
	var output := Image.create(
		DISCORD_CANVAS_SIZE.x,
		DISCORD_CANVAS_SIZE.y,
		false,
		Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var destination := Vector2i(
		(DISCORD_CANVAS_SIZE.x - DISCORD_CONTENT_SIZE.x) / 2,
		(DISCORD_CANVAS_SIZE.y - DISCORD_CONTENT_SIZE.y) / 2)
	output.blit_rect(
		content,
		Rect2i(Vector2i.ZERO, content.get_size()),
		destination)
	return output


func _clear_corner_connected_white(image: Image) -> int:
	var width := image.get_width()
	var height := image.get_height()
	var background := _corner_background(image)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue: Array[Vector2i] = []
	for corner: Vector2i in [
		Vector2i.ZERO,
		Vector2i(width - 1, 0),
		Vector2i(0, height - 1),
		Vector2i(width - 1, height - 1),
	]:
		_try_enqueue_background(image, corner, background, visited, queue)
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for delta: Vector2i in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			_try_enqueue_background(
				image,
				point + delta,
				background,
				visited,
				queue)
	for point: Vector2i in queue:
		image.set_pixelv(point, Color(0.0, 0.0, 0.0, 0.0))
	return queue.size()


func _try_enqueue_background(
		image: Image,
		point: Vector2i,
		background: Color,
		visited: PackedByteArray,
		queue: Array[Vector2i],
) -> void:
	if (
		point.x < 0
		or point.y < 0
		or point.x >= image.get_width()
		or point.y >= image.get_height()
	):
		return
	var index := point.y * image.get_width() + point.x
	if visited[index] != 0:
		return
	visited[index] = 1
	if _is_background_color(image.get_pixelv(point), background):
		queue.append(point)


func _corner_background(image: Image) -> Color:
	var width := image.get_width()
	var height := image.get_height()
	var corners: Array[Color] = [
		image.get_pixel(0, 0),
		image.get_pixel(width - 1, 0),
		image.get_pixel(0, height - 1),
		image.get_pixel(width - 1, height - 1),
	]
	var background := Color(0.0, 0.0, 0.0, 0.0)
	for color: Color in corners:
		background += color
	return background / float(corners.size())


func _is_background_color(color: Color, background: Color) -> bool:
	if color.a <= 0.0:
		return true
	return (
		absi(roundi(color.r * 255.0) - roundi(background.r * 255.0))
			<= BACKGROUND_TOLERANCE
		and absi(roundi(color.g * 255.0) - roundi(background.g * 255.0))
			<= BACKGROUND_TOLERANCE
		and absi(roundi(color.b * 255.0) - roundi(background.b * 255.0))
			<= BACKGROUND_TOLERANCE)


func _is_near_white(color: Color) -> bool:
	if color.a <= 0.0:
		return true
	return (
		absi(roundi(color.r * 255.0) - 255) <= BACKGROUND_TOLERANCE
		and absi(roundi(color.g * 255.0) - 255) <= BACKGROUND_TOLERANCE
		and absi(roundi(color.b * 255.0) - 255) <= BACKGROUND_TOLERANCE)


func _count_preserved_white(image: Image) -> int:
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.99 and _is_near_white(color):
				count += 1
	return count


func _opaque_pixels_match_source(source: Image, output: Image) -> bool:
	var comparable := source.duplicate()
	comparable.convert(Image.FORMAT_RGBA8)
	for y: int in output.get_height():
		for x: int in output.get_width():
			var output_color := output.get_pixel(x, y)
			if output_color.a <= 0.0:
				continue
			if output_color != comparable.get_pixel(x, y):
				return false
	return true


func _build_feedback_icon() -> bool:
	var source_path := "%s/feedback.png" % SOURCE_ROOT
	var output_path := "%s/feedback.png" % OUTPUT_ROOT
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(source_path))
	if source == null or source.is_empty():
		push_error("Boot feedback icon source missing: %s" % source_path)
		return false
	var used_rect := source.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		push_error("Boot feedback icon source is empty.")
		return false
	var content := source.get_region(used_rect)
	content.resize(
		content.get_width() * FEEDBACK_SCALE,
		content.get_height() * FEEDBACK_SCALE,
		Image.INTERPOLATE_NEAREST)
	if (
		content.get_width() > FEEDBACK_CANVAS_SIZE.x
		or content.get_height() > FEEDBACK_CANVAS_SIZE.y
	):
		push_error("Boot feedback icon exceeds its output canvas.")
		return false
	var output := Image.create(
		FEEDBACK_CANVAS_SIZE.x,
		FEEDBACK_CANVAS_SIZE.y,
		false,
		Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var destination := Vector2i(
		(FEEDBACK_CANVAS_SIZE.x - content.get_width()) / 2,
		(FEEDBACK_CANVAS_SIZE.y - content.get_height()) / 2)
	output.blit_rect(
		content,
		Rect2i(Vector2i.ZERO, content.get_size()),
		destination)
	var save_error: Error = output.save_png(
		ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error(
			"Boot feedback icon save failed: %s" % error_string(save_error))
		return false
	print(
		"BOOT_FEEDBACK_ICON_OK: source=%dx%d used=%dx%d output=%dx%d"
		% [
			source.get_width(),
			source.get_height(),
			used_rect.size.x,
			used_rect.size.y,
			output.get_width(),
			output.get_height(),
		])
	return true
