extends SceneTree

const SCENE6 := preload("res://src/ui/scenes/scene6.tscn")
const P1_FRAMES := preload("res://assets/sprites/heroes/h01/h01_idle.tres")
const P2_FRAMES := preload("res://assets/sprites/heroes/h02/h02_idle.tres")
const CHARACTER_SPRITE_CENTER := Vector2(384.0, 384.0)
const CHARACTER_SCALE := 2.0


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var stage := SCENE6.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame

	var platform := stage.get_node("BattlePlatform") as TextureRect
	var p1_depth := _contact_depth(platform, P1_FRAMES, 480.0, 262.0)
	var p2_depth := _contact_depth(platform, P2_FRAMES, 1440.0, 265.0)
	var battle_source := FileAccess.get_file_as_string(
			"res://src/ui/battle_screen6.tscn")
	var grounded_offsets := battle_source.contains("offset_top = 262.0") \
			and battle_source.contains("offset_top = 265.0") \
			and battle_source.contains("offset_top = 719.0") \
			and battle_source.contains("offset_top = 721.0")
	var full_image_scale := platform != null \
			and platform.stretch_mode == TextureRect.STRETCH_SCALE \
			and platform.scale == Vector2(4.0, 4.0)
	var grounded := p1_depth >= 3.0 and p1_depth <= 12.0 \
			and p2_depth >= 3.0 and p2_depth <= 12.0 \
			and grounded_offsets
	var passed := full_image_scale and grounded
	print("SCENE6_GROUNDING_PROBE: ", "PASS" if passed else "FAIL",
			" full_image_scale=", full_image_scale,
			" p1_contact_depth=", snappedf(p1_depth, 0.01),
			" p2_contact_depth=", snappedf(p2_depth, 0.01),
			" grounded_offsets=", grounded_offsets)
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _contact_depth(
		platform: TextureRect,
		frames: SpriteFrames,
		foot_canvas_x: float,
		character_top_y: float
) -> float:
	var texture := frames.get_frame_texture(&"idle", 0)
	var character_image := texture.get_image()
	var foot_row := _bottom_alpha_row(character_image)
	var foot_canvas_y := character_top_y + CHARACTER_SPRITE_CENTER.y \
			+ (float(foot_row) + 0.5 - float(character_image.get_height()) * 0.5) \
					* CHARACTER_SCALE

	var platform_image := platform.texture.get_image()
	var platform_local_x := (foot_canvas_x - platform.position.x) / platform.scale.x
	var source_x := clampi(int(floor(
			platform_local_x / platform.size.x * platform_image.get_width())),
			0, platform_image.get_width() - 1)
	var surface_row := _top_alpha_row(platform_image, source_x)
	var surface_canvas_y := platform.position.y \
			+ (float(surface_row) + 0.5) / float(platform_image.get_height()) \
					* platform.size.y * platform.scale.y
	return foot_canvas_y - surface_canvas_y


func _bottom_alpha_row(image: Image) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= 0.5:
				return y
	return -1


func _top_alpha_row(image: Image, source_x: int) -> int:
	for y: int in image.get_height():
		if image.get_pixel(source_x, y).a >= 0.5:
			return y
	return image.get_height()
