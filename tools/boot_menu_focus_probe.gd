extends Node

const BOOT_SCENE := preload("res://src/ui/boot_screen.tscn")
const BLADE_COLOR := Color("eda63a")
const SEPARATOR_COLOR := Color("0f1b26")


func _ready() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var boot := BOOT_SCENE.instantiate() as Control
	add_child(boot)
	await get_tree().process_frame
	var intro := boot.get_node_or_null("IntroController")
	if intro != null:
		intro.call(&"finish_immediately")
	await get_tree().process_frame
	var start_button := boot.get_node(
		"InterfaceLayer/BootMenu/MainButtons/StartGame") as Button
	var focus_mark := start_button.get_node("FocusMark") as Control
	start_button.grab_focus()
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var state: Dictionary = focus_mark.call(&"debug_state")
	var local_center: Vector2 = state["center"]
	var screen_center: Vector2 = (
		focus_mark.get_global_transform_with_canvas() * local_center)
	var image := get_viewport().get_texture().get_image()
	var blade_pixels: int = _count_near_color(
		image, screen_center, Vector2i(12, 18), BLADE_COLOR)
	var separator_pixels: int = _count_near_color(
		image, screen_center, Vector2i(12, 18), SEPARATOR_COLOR)
	var failures: Array[String] = []
	if not bool(state["active"]):
		failures.append("focus mark is inactive")
	if not is_equal_approx(float(state["blade_height"]), 18.0):
		failures.append("blade height is not 18 px")
	if blade_pixels < 18:
		failures.append("gold blade footprint is too small: %d" % blade_pixels)
	if separator_pixels < 18:
		failures.append(
			"dark separator footprint is too small: %d" % separator_pixels)
	if not failures.is_empty():
		push_error("BOOT_MENU_FOCUS_PROBE: %s" % "; ".join(failures))
		get_tree().quit(1)
		return
	print(
		"BOOT_MENU_FOCUS_PROBE_OK: blade=%d separator=%d height=%.1f"
		% [blade_pixels, separator_pixels, float(state["blade_height"])])
	get_tree().quit(0)


func _count_near_color(
		image: Image,
		center: Vector2,
		half_extent: Vector2i,
		target: Color) -> int:
	var count: int = 0
	var center_pixel := Vector2i(roundi(center.x), roundi(center.y))
	var minimum := Vector2i(
		maxi(center_pixel.x - half_extent.x, 0),
		maxi(center_pixel.y - half_extent.y, 0))
	var maximum := Vector2i(
		mini(center_pixel.x + half_extent.x, image.get_width() - 1),
		mini(center_pixel.y + half_extent.y, image.get_height() - 1))
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var pixel := image.get_pixel(x, y)
			if (
				absf(pixel.r - target.r) <= 0.06
				and absf(pixel.g - target.g) <= 0.06
				and absf(pixel.b - target.b) <= 0.06
				and pixel.a >= 0.95
			):
				count += 1
	return count
