extends Node

const BattleScreenScene := preload("res://src/ui/battle_screen8.tscn")


func _ready() -> void:
	call_deferred("_audit_actual_f6_root")


func _audit_actual_f6_root() -> void:
	var root := get_tree().root
	root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	var before := {
		"content_scale_mode": root.content_scale_mode,
		"content_scale_aspect": root.content_scale_aspect,
		"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
	}
	# 与编辑器直接 F6 battle_screen8 相同：Battle8 作为真实根窗口内容实例化，
	# 不再塞进固定 1920×1080 的测试 SubViewport。
	var screen: Control = BattleScreenScene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var strip := screen.get_node("CommandOrderStrip") as Control
	for child: Node in screen.get_children():
		if child is CanvasItem and child != strip:
			(child as CanvasItem).visible = false
	strip.modulate = Color.WHITE
	var skin := strip.get_node("Entries/NextSlot/SlotSkin") as Control
	skin.set("ornament_color", Color.WHITE)
	skin.set("tuning_shadow_color", Color.TRANSPARENT)
	skin.set("tuning_shadow_expand", 0.0)
	skin.set("tuning_shadow_offset", Vector2.ZERO)
	skin.call("set_hot", true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var raster: Image = root.get_texture().get_image()
	var visible_bounds := _alpha_bounds(raster, 0.02)
	var solid_bounds := _alpha_bounds(raster, 0.50)
	var edge_stats := _alpha_transition_stats(raster, visible_bounds)
	var visible_aspect: float = float(visible_bounds.size.x) / maxf(
		float(visible_bounds.size.y), 1.0)
	var solid_aspect: float = float(solid_bounds.size.x) / maxf(
		float(solid_bounds.size.y), 1.0)
	var canvas_transform := skin.get_global_transform_with_canvas()
	var screen_transform := root.get_screen_transform()
	var physical_transform := screen_transform * canvas_transform
	var x_scale: float = physical_transform.x.length()
	var y_scale: float = physical_transform.y.length()
	var geometry: Dictionary = skin.debug_geometry()
	var local_center: Vector2 = geometry["star_center"]
	var physical_center: Vector2 = physical_transform * local_center
	var physical_radii := Vector2(
		float((geometry["star_radii"] as Vector2).x) * x_scale,
		float((geometry["star_radii"] as Vector2).y) * y_scale)
	var coverage_stats := _coverage_reference_stats(
		raster, physical_center, physical_radii,
		float(geometry["profile_power"]), 16)
	print("COMMAND_STAR_ACTUAL_F6_ROOT ", JSON.stringify({
		"scene": screen.scene_file_path,
		"before": before,
		"after": {
			"content_scale_mode": root.content_scale_mode,
			"content_scale_aspect": root.content_scale_aspect,
			"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		},
		"window_size": [root.size.x, root.size.y],
		"raster_size": [raster.get_width(), raster.get_height()],
		"physical_axis_scale": [x_scale, y_scale],
		"visible_bounds": [visible_bounds.position.x, visible_bounds.position.y,
			visible_bounds.size.x, visible_bounds.size.y],
		"solid_bounds": [solid_bounds.position.x, solid_bounds.position.y,
			solid_bounds.size.x, solid_bounds.size.y],
		"visible_aspect": visible_aspect,
		"solid_aspect": solid_aspect,
		"fractional_alpha_pixels": edge_stats["fractional_alpha_pixels"],
		"fractional_alpha_levels": edge_stats["fractional_alpha_levels"],
		"render_path": geometry["render_path"],
		"coverage_mae": coverage_stats["mae"],
		"coverage_max_error": coverage_stats["max_error"],
	}))
	var passed: bool = screen.scene_file_path.ends_with("battle_screen8.tscn") \
		and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS \
		and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP \
		and root.content_scale_size == Vector2i(1920, 1080) \
		and absf(x_scale - y_scale) <= 0.001 \
		and visible_bounds.size.x >= 27 and visible_bounds.size.y >= 25 \
		and visible_aspect <= 1.25 and solid_aspect <= 1.25 \
		and int(edge_stats["fractional_alpha_pixels"]) >= 20 \
		and int(edge_stats["fractional_alpha_levels"]) >= 6 \
		and float(coverage_stats["mae"]) <= 0.015 \
		and String(geometry["render_path"]) == "analytic_ssaa_9x9"
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)


func _alpha_bounds(image: Image, threshold: float) -> Rect2i:
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a < threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	return Rect2i() if max_x < min_x else Rect2i(
		min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _alpha_transition_stats(image: Image, bounds: Rect2i) -> Dictionary:
	var fractional_pixels: int = 0
	var alpha_levels := {}
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var alpha: float = image.get_pixel(x, y).a
			if alpha <= 0.01 or alpha >= 0.99:
				continue
			fractional_pixels += 1
			alpha_levels[int(round(alpha * 255.0))] = true
	return {
		"fractional_alpha_pixels": fractional_pixels,
		"fractional_alpha_levels": alpha_levels.size(),
	}


func _coverage_reference_stats(image: Image, center: Vector2, radii: Vector2,
		profile_power: float, samples_per_axis: int) -> Dictionary:
	var padding: int = 3
	var minimum := Vector2i(floori(center.x - radii.x) - padding,
		floori(center.y - radii.y) - padding)
	var maximum := Vector2i(ceili(center.x + radii.x) + padding,
		ceili(center.y + radii.y) + padding)
	var total_error: float = 0.0
	var max_error: float = 0.0
	var pixel_count: int = 0
	var exponent: float = 2.0 / profile_power
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var covered: int = 0
			for sample_y: int in range(samples_per_axis):
				for sample_x: int in range(samples_per_axis):
					var sample_position := Vector2(
						float(x) + (float(sample_x) + 0.5) / float(samples_per_axis),
						float(y) + (float(sample_y) + 0.5) / float(samples_per_axis))
					var normalized := Vector2(
						absf(sample_position.x - center.x) / radii.x,
						absf(sample_position.y - center.y) / radii.y)
					if pow(normalized.x, exponent) \
							+ pow(normalized.y, exponent) <= 1.0:
						covered += 1
			var expected: float = float(covered) \
				/ float(samples_per_axis * samples_per_axis)
			var actual: float = image.get_pixel(x, y).a
			var error: float = absf(actual - expected)
			total_error += error
			max_error = maxf(max_error, error)
			pixel_count += 1
	return {
		"mae": total_error / maxf(float(pixel_count), 1.0),
		"max_error": max_error,
	}
