extends Node

## 新 Boot Screen 的真实场景截图探针。
## 输出：D:/Game/BoBoZan/boot_char2_preview.png

const OUT_PATH := "D:/Game/BoBoZan/boot_char2_preview.png"
const NEXT_SCENE := "res://src/ui/main_menu.tscn"
const TITLE_CONTROLLER_PATH := (
		"res://src/ui/components/boot_title_controller.gd")
const TITLE_FACE_COLOR := Color(0.960784, 0.909804, 0.819608, 1.0)
const TITLE_STRUCTURE_COLOR := Color(0.058824, 0.105882, 0.149020, 1.0)
const TITLE_ENERGY_COLOR := Color(0.866667, 0.337255, 0.223529, 1.0)
const TITLE_ENERGY_PEAK_COLOR := Color(0.960784, 0.909804, 0.819608, 1.0)
const TITLE_TEST_FACE_COLOR := Color(0.45, 0.72, 0.92, 1.0)
const TITLE_TEST_STRUCTURE_COLOR := Color(0.05, 0.08, 0.16, 1.0)
const TITLE_TEST_ENERGY_COLOR := Color(0.78, 0.35, 0.92, 1.0)
const TITLE_TEST_ENERGY_PEAK_COLOR := Color(0.95, 0.82, 1.0, 1.0)
const TITLE_FLOW_PERIOD_SECONDS := 4.2
const TITLE_FLOW_STAGGER_SECONDS := 0.28
const TITLE_FLOW_DURATION_SECONDS := 1.35
const TITLE_RELEASE_DURATION_SECONDS := 0.70
const TITLE_HEAD_WIDTH_TEXELS := 6.0
const TITLE_TAIL_LENGTH_TEXELS := 28.0
const TITLE_STRUCTURE_TINT_STRENGTH := 0.42
const TITLE_FRAGMENT_STRENGTH := 0.85
const TITLE_TEXTURE_SIZE := 252.0
const TITLE_FLOW_START_PIXELS: Array[float] = [63.5, 45.5, 45.5]
const TITLE_FLOW_END_PIXELS: Array[float] = [224.5, 224.5, 215.5]
const TITLE_FRAGMENT_ORIGIN_Y_PIXELS: Array[float] = [78.5, 78.5, 90.5]


class TransitionObserver extends Node:
	var elapsed: float = 0.0


	func _process(delta: float) -> void:
		elapsed += delta
		var current := get_tree().current_scene
		if current != null and current.scene_file_path == NEXT_SCENE:
			print("BOOT_CHAR2_INPUT_OK: ", current.scene_file_path)
			get_tree().quit()
			return
		if elapsed > 4.0:
			push_error("Boot 点击后未在时限内进入 Main Menu")
			get_tree().quit(1)


func _shader_color_equals(
		shader_material: ShaderMaterial,
		parameter: StringName,
		expected: Color,
) -> bool:
	var value: Variant = shader_material.get_shader_parameter(parameter)
	if typeof(value) != TYPE_COLOR:
		return false
	var actual: Color = value
	return actual.is_equal_approx(expected)


func _materials_match_palette(
		materials: Array[ShaderMaterial],
		expected_face: Color,
		expected_structure: Color,
		expected_energy: Color,
		expected_energy_peak: Color,
) -> bool:
	for shader_material: ShaderMaterial in materials:
		if (
			not _shader_color_equals(
				shader_material,
				&"face_color",
				expected_face)
			or not _shader_color_equals(
				shader_material,
				&"structure_color",
				expected_structure)
			or not _shader_color_equals(
				shader_material,
				&"energy_color",
				expected_energy)
			or not _shader_color_equals(
				shader_material,
				&"energy_peak_color",
				expected_energy_peak)
		):
			return false
	return true


func _color_distance_squared(first: Color, second: Color) -> float:
	var red_delta := first.r - second.r
	var green_delta := first.g - second.g
	var blue_delta := first.b - second.b
	return (
		red_delta * red_delta
		+ green_delta * green_delta
		+ blue_delta * blue_delta
	)


func _control_image_bounds(
		control: Control,
		image: Image,
		right_limit: int = -1,
) -> Rect2i:
	var control_rect := control.get_global_rect()
	var start := Vector2i(
		floori(control_rect.position.x),
		floori(control_rect.position.y))
	var finish := Vector2i(
		ceili(control_rect.end.x),
		ceili(control_rect.end.y))
	if right_limit >= 0:
		finish.x = mini(finish.x, right_limit)
	var image_bounds := Rect2i(Vector2i.ZERO, image.get_size())
	return Rect2i(start, finish - start).intersection(image_bounds)


func _count_pixels_near(
		image: Image,
		bounds: Rect2i,
		expected: Color,
		tolerance: float,
) -> int:
	var count := 0
	var tolerance_squared := tolerance * tolerance
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if (
				_color_distance_squared(
					image.get_pixel(x, y),
					expected)
				<= tolerance_squared
			):
				count += 1
	return count


func _energy_flow_metrics(
		baseline: Image,
		flow_image: Image,
		bounds: Rect2i,
) -> Vector4:
	var energy_pixel_count := 0
	var changed_pixel_count := 0
	var total_rgb_difference := 0.0
	var weighted_x_total := 0.0
	var centroid_weight := 0.0
	var energy_tolerance_squared := 0.08 * 0.08
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var baseline_pixel := baseline.get_pixel(x, y)
			if (
				_color_distance_squared(
					baseline_pixel,
					TITLE_ENERGY_COLOR)
				> energy_tolerance_squared
			):
				continue
			energy_pixel_count += 1
			var flow_pixel := flow_image.get_pixel(x, y)
			var rgb_difference := (
				absf(baseline_pixel.r - flow_pixel.r)
				+ absf(baseline_pixel.g - flow_pixel.g)
				+ absf(baseline_pixel.b - flow_pixel.b)
			)
			total_rgb_difference += rgb_difference
			if rgb_difference >= 0.02:
				changed_pixel_count += 1
				weighted_x_total += float(x) * rgb_difference
				centroid_weight += rgb_difference
	if energy_pixel_count == 0:
		return Vector4.ZERO
	var changed_centroid_x := 0.0
	if centroid_weight > 0.0:
		changed_centroid_x = weighted_x_total / centroid_weight
	return Vector4(
		float(energy_pixel_count),
		float(changed_pixel_count) / float(energy_pixel_count),
		total_rgb_difference / float(energy_pixel_count),
		changed_centroid_x)


func _is_baseline_energy_pixel(color: Color) -> bool:
	return (
		_color_distance_squared(color, TITLE_ENERGY_COLOR)
		<= 0.08 * 0.08
	)


func _has_energy_above(
		baseline: Image,
		position: Vector2i,
		bounds: Rect2i,
) -> bool:
	for distance: int in range(1, 5):
		var neighbor := position + Vector2i(0, -distance)
		if not bounds.has_point(neighbor):
			continue
		if _is_baseline_energy_pixel(
				baseline.get_pixel(neighbor.x, neighbor.y)
		):
			return true
	return false


func _structure_tint_metrics(
		baseline: Image,
		flow_image: Image,
		bounds: Rect2i,
) -> Vector4:
	var structure_pixel_count := 0
	var changed_pixel_count := 0
	var total_rgb_difference := 0.0
	var weighted_x_total := 0.0
	var centroid_weight := 0.0
	var structure_tolerance_squared := 0.08 * 0.08
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var position := Vector2i(x, y)
			var baseline_pixel := baseline.get_pixel(x, y)
			if (
				_color_distance_squared(
					baseline_pixel,
					TITLE_STRUCTURE_COLOR)
				> structure_tolerance_squared
				or not _has_energy_above(
					baseline,
					position,
					bounds)
			):
				continue
			structure_pixel_count += 1
			var flow_pixel := flow_image.get_pixel(x, y)
			var rgb_difference := (
				absf(baseline_pixel.r - flow_pixel.r)
				+ absf(baseline_pixel.g - flow_pixel.g)
				+ absf(baseline_pixel.b - flow_pixel.b)
			)
			total_rgb_difference += rgb_difference
			if rgb_difference >= 0.004:
				changed_pixel_count += 1
				weighted_x_total += float(x) * rgb_difference
				centroid_weight += rgb_difference
	if structure_pixel_count == 0:
		return Vector4.ZERO
	var changed_centroid_x := 0.0
	if centroid_weight > 0.0:
		changed_centroid_x = weighted_x_total / centroid_weight
	return Vector4(
		float(structure_pixel_count),
		float(changed_pixel_count) / float(structure_pixel_count),
		total_rgb_difference / float(structure_pixel_count),
		changed_centroid_x)


func _rightmost_energy_x(baseline: Image, bounds: Rect2i) -> int:
	var rightmost := bounds.position.x
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			if _is_baseline_energy_pixel(baseline.get_pixel(x, y)):
				rightmost = maxi(rightmost, x)
	return rightmost


func _fragment_release_metrics(
		baseline: Image,
		release_image: Image,
		bounds: Rect2i,
) -> Vector2:
	var rightmost_energy := _rightmost_energy_x(baseline, bounds)
	var changed_background_count := 0
	var total_rgb_difference := 0.0
	var background_tolerance_squared := 0.025 * 0.025
	var background_color := Color(0.004, 0.003, 0.009, 1.0)
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(rightmost_energy + 1, bounds.end.x):
			var baseline_pixel := baseline.get_pixel(x, y)
			if (
				_color_distance_squared(
					baseline_pixel,
					background_color)
				> background_tolerance_squared
			):
				continue
			var release_pixel := release_image.get_pixel(x, y)
			var rgb_difference := (
				absf(baseline_pixel.r - release_pixel.r)
				+ absf(baseline_pixel.g - release_pixel.g)
				+ absf(baseline_pixel.b - release_pixel.b)
			)
			if rgb_difference < 0.04:
				continue
			changed_background_count += 1
			total_rgb_difference += rgb_difference
	if changed_background_count == 0:
		return Vector2.ZERO
	return Vector2(
		float(changed_background_count),
		total_rgb_difference / float(changed_background_count))


func _ready() -> void:
	var scene := load("res://src/ui/boot_screen.tscn") as PackedScene
	if scene == null:
		push_error("boot_screen.tscn 无法加载")
		get_tree().quit(1)
		return

	var boot := scene.instantiate()
	add_child(boot)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var character := boot.get_node_or_null("Character") as Control
	var base_sprite := (
			character.get_node_or_null("Rig/Base") as Sprite2D
			if character != null
			else null)
	if character == null or base_sprite == null or base_sprite.texture == null:
		push_error("Boot Character 未正确加载")
		get_tree().quit(1)
		return
	var background := boot.get_node_or_null("Background") as ColorRect
	var title_column := boot.get_node_or_null("TitleColumn") as Control
	if (
			boot.get_child_count() != 3
			or background == null
			or background.material != null
			or not background.color.is_equal_approx(
				Color(0.004, 0.003, 0.009, 1.0))
			or title_column == null):
		push_error("Boot vertical title or clean near-black background did not load.")
		get_tree().quit(1)
		return
	if (
			boot.get_node_or_null("Title") != null
			or FileAccess.file_exists("res://assets/ui/boot/title_bobozan.png")
			or FileAccess.file_exists("res://assets/ui/boot/title_bobozan.png.import")):
		push_error("The rejected horizontal Boot title still exists.")
		get_tree().quit(1)
		return
	var bo_top := title_column.get_node_or_null("BoTop") as TextureRect
	var bo_middle := title_column.get_node_or_null("BoMiddle") as TextureRect
	var zan_bottom := title_column.get_node_or_null("ZanBottom") as TextureRect
	if (
			title_column.get_child_count() != 3
			or not title_column.position.is_equal_approx(Vector2(176.0, 146.0))
			or not title_column.size.is_equal_approx(Vector2(252.0, 788.0))
			or title_column.mouse_filter != Control.MOUSE_FILTER_IGNORE
			or bo_top == null
			or bo_middle == null
			or zan_bottom == null):
		push_error("Boot TitleColumn structure or layout is incorrect.")
		get_tree().quit(1)
		return
	var title_controller_script := title_column.get_script() as Script
	if (
			title_controller_script == null
			or title_controller_script.resource_path != TITLE_CONTROLLER_PATH
			or not title_column.has_method(&"apply_palette")
			or not title_column.has_method(&"current_flow_phase")
	):
		push_error("Boot title engraving-flow controller did not load.")
		get_tree().quit(1)
		return
	if (
			bo_top.texture == null
			or bo_middle.texture == null
			or zan_bottom.texture == null
			or bo_top.texture.resource_path != "res://assets/ui/boot/title_bo_top.png"
			or bo_middle.texture.resource_path != "res://assets/ui/boot/title_bo_middle.png"
			or zan_bottom.texture.resource_path != "res://assets/ui/boot/title_zan_bottom.png"
			or bo_top.position != Vector2.ZERO
			or bo_middle.position != Vector2(0.0, 268.0)
			or zan_bottom.position != Vector2(0.0, 536.0)
			or not bo_top.size.is_equal_approx(Vector2(252.0, 252.0))
			or not bo_middle.size.is_equal_approx(Vector2(252.0, 252.0))
			or not zan_bottom.size.is_equal_approx(Vector2(252.0, 252.0))
			or bo_top.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST
			or bo_middle.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST
			or zan_bottom.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST
			or bo_top.mouse_filter != Control.MOUSE_FILTER_IGNORE
			or bo_middle.mouse_filter != Control.MOUSE_FILTER_IGNORE
			or zan_bottom.mouse_filter != Control.MOUSE_FILTER_IGNORE):
		push_error("Boot title glyph textures or vertical spacing are incorrect.")
		get_tree().quit(1)
		return
	var bo_top_material := bo_top.material as ShaderMaterial
	var bo_middle_material := bo_middle.material as ShaderMaterial
	var zan_bottom_material := zan_bottom.material as ShaderMaterial
	if (
			bo_top_material == null
			or bo_middle_material == null
			or zan_bottom_material == null
			or bo_top_material.shader == null
			or bo_middle_material.shader == null
			or zan_bottom_material.shader == null
			or bo_top_material == bo_middle_material
			or bo_top_material == zan_bottom_material
			or bo_middle_material == zan_bottom_material):
		push_error("Each Boot title glyph must have an independent ShaderMaterial.")
		get_tree().quit(1)
		return
	var title_materials: Array[ShaderMaterial] = [
		zan_bottom_material,
		bo_middle_material,
		bo_top_material,
	]
	if (
			not is_equal_approx(
				float(bo_top_material.get_shader_parameter(
					&"perspective_strength")), 0.26)
			or not is_equal_approx(
				float(bo_middle_material.get_shader_parameter(
					&"perspective_strength")), 0.26)
			or not is_equal_approx(
				float(zan_bottom_material.get_shader_parameter(
					&"perspective_strength")), 0.26)
			or not is_equal_approx(
				float(bo_top_material.get_shader_parameter(&"edge_padding")), 0.04)
			or not is_equal_approx(
				float(bo_middle_material.get_shader_parameter(&"edge_padding")), 0.04)
			or not is_equal_approx(
				float(zan_bottom_material.get_shader_parameter(&"edge_padding")), 0.04)):
		push_error("Boot title perspective parameters are incorrect.")
		get_tree().quit(1)
		return
	var normalized_stagger := (
			TITLE_FLOW_STAGGER_SECONDS / TITLE_FLOW_PERIOD_SECONDS)
	var normalized_flow_duration := (
			TITLE_FLOW_DURATION_SECONDS / TITLE_FLOW_PERIOD_SECONDS)
	var normalized_release_duration := (
			TITLE_RELEASE_DURATION_SECONDS / TITLE_FLOW_PERIOD_SECONDS)
	if (
			not _materials_match_palette(
				title_materials,
				TITLE_FACE_COLOR,
				TITLE_STRUCTURE_COLOR,
			TITLE_ENERGY_COLOR,
			TITLE_ENERGY_PEAK_COLOR)
			or not is_equal_approx(
				float(zan_bottom_material.get_shader_parameter(
					&"flow_delay")), 0.0)
			or not is_equal_approx(
				float(bo_middle_material.get_shader_parameter(
					&"flow_delay")), normalized_stagger)
			or not is_equal_approx(
				float(bo_top_material.get_shader_parameter(
					&"flow_delay")), normalized_stagger * 2.0)
	):
		push_error("Boot title palette or engraving-flow order is incorrect.")
		get_tree().quit(1)
		return
	for index: int in title_materials.size():
		var shader_material := title_materials[index]
		if (
			not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"flow_duration")), normalized_flow_duration)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"release_duration")), normalized_release_duration)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"head_width_texels")), TITLE_HEAD_WIDTH_TEXELS)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"tail_length_texels")), TITLE_TAIL_LENGTH_TEXELS)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"structure_tint_strength")),
				TITLE_STRUCTURE_TINT_STRENGTH)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"fragment_strength")),
				TITLE_FRAGMENT_STRENGTH)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"flow_start_uv_x")),
				TITLE_FLOW_START_PIXELS[index] / TITLE_TEXTURE_SIZE)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"flow_end_uv_x")),
				TITLE_FLOW_END_PIXELS[index] / TITLE_TEXTURE_SIZE)
			or not is_equal_approx(
				float(shader_material.get_shader_parameter(
					&"fragment_origin_uv_y")),
				TITLE_FRAGMENT_ORIGIN_Y_PIXELS[index] / TITLE_TEXTURE_SIZE)
		):
			push_error("Boot title engraving-flow parameters are incorrect.")
			get_tree().quit(1)
			return
	if FileAccess.file_exists(
			"res://assets/shaders/canvas_boot_graphic_wave_field.gdshader"):
		push_error("The rejected graphic wave-field shader still exists.")
		get_tree().quit(1)
		return
	var animation_player := character.get_node_or_null(
		"AnimationPlayer") as AnimationPlayer
	var waist_animation_player := character.get_node_or_null(
		"WaistAnimationPlayer") as AnimationPlayer
	if animation_player == null or not animation_player.has_animation(&"idle"):
		push_error("Boot Character Idle 动画未正确加载")
		get_tree().quit(1)
		return
	if (
			waist_animation_player == null
			or not waist_animation_player.has_animation(&"waist_idle")):
		push_error("Boot dual-waist idle animation did not load.")
		get_tree().quit(1)
		return
	var waist_screen_left := character.get_node_or_null(
		"Rig/WaistScreenLeftPivot/WaistScreenLeft") as Sprite2D
	var waist_screen_right := character.get_node_or_null(
		"Rig/WaistScreenRightPivot/WaistScreenRight") as Sprite2D
	if (
			waist_screen_left == null
			or waist_screen_left.texture == null
			or waist_screen_right == null
			or waist_screen_right.texture == null):
		push_error("Both boot waist cloth layers must be present.")
		get_tree().quit(1)
		return
	var rear_hand_anchor := character.get_node_or_null(
			"Rig/RearHandEnergyAnchor") as Marker2D
	var rear_hand_glow := character.get_node_or_null(
			"Rig/RearHandEnergyAnchor/RearHandGlow") as ColorRect
	var rear_hand_star := character.get_node_or_null(
			"Rig/RearHandEnergyAnchor/RearHandStar") as ColorRect
	if (
			rear_hand_anchor == null
			or rear_hand_glow == null
			or rear_hand_star == null
			or rear_hand_glow.material == null
			or rear_hand_star.material == null):
		push_error("Boot Character 后手星芒未正确加载")
		get_tree().quit(1)
		return
	animation_player.seek(0.0, true)
	waist_animation_player.seek(0.0, true)
	if boot.find_children("*", "GPUParticles2D", true, false).size() > 0:
		push_error("新 Boot 中仍残留旧粒子层")
		get_tree().quit(1)
		return

	var phase_before_swap := float(
			title_column.call(&"current_flow_phase"))
	title_column.call(
		&"apply_palette",
		TITLE_TEST_FACE_COLOR,
		TITLE_TEST_STRUCTURE_COLOR,
		TITLE_TEST_ENERGY_COLOR,
		TITLE_TEST_ENERGY_PEAK_COLOR)
	if not _materials_match_palette(
			title_materials,
			TITLE_TEST_FACE_COLOR,
			TITLE_TEST_STRUCTURE_COLOR,
			TITLE_TEST_ENERGY_COLOR,
			TITLE_TEST_ENERGY_PEAK_COLOR):
		push_error("Boot title temporary palette did not reach every glyph.")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.08).timeout
	var phase_after_swap := float(
			title_column.call(&"current_flow_phase"))
	if absf(phase_after_swap - phase_before_swap) < 0.001:
		push_error(
			"Boot title engraving flow stopped after the runtime palette swap.")
		get_tree().quit(1)
		return
	for shader_material: ShaderMaterial in title_materials:
		if not is_equal_approx(
			float(shader_material.get_shader_parameter(&"flow_phase")),
			phase_after_swap,
		):
			push_error("Boot title flow phase did not reach every glyph.")
			get_tree().quit(1)
			return

	var title_phase_tween := title_column.get("_phase_tween") as Tween
	if title_phase_tween == null or not title_phase_tween.is_valid():
		push_error(
			"Boot title engraving-flow tween was not available for probing.")
		get_tree().quit(1)
		return
	title_phase_tween.pause()
	title_column.call(&"_set_flow_phase", 0.5)
	await RenderingServer.frame_post_draw
	var palette_image := get_viewport().get_texture().get_image()
	var title_nodes: Array[TextureRect] = [
		zan_bottom,
		bo_middle,
		bo_top,
	]
	for title_node: TextureRect in title_nodes:
		var bounds := _control_image_bounds(title_node, palette_image)
		var face_pixel_count := _count_pixels_near(
			palette_image,
			bounds,
			TITLE_TEST_FACE_COLOR,
			0.08)
		var structure_pixel_count := _count_pixels_near(
			palette_image,
			bounds,
			TITLE_TEST_STRUCTURE_COLOR,
			0.08)
		var energy_pixel_count := _count_pixels_near(
			palette_image,
			bounds,
			TITLE_TEST_ENERGY_COLOR,
			0.08)
		print(
			"BOOT_TITLE_PALETTE_PIXELS: %s face=%d structure=%d energy=%d"
			% [
				title_node.name,
				face_pixel_count,
				structure_pixel_count,
				energy_pixel_count,
			])
		if (
			face_pixel_count < 12
			or structure_pixel_count < 12
			or energy_pixel_count < 12
		):
			push_error(
				"Boot title test palette was not rendered by %s."
				% title_node.name)
			get_tree().quit(1)
			return

	title_column.call(
		&"apply_palette",
		TITLE_FACE_COLOR,
		TITLE_STRUCTURE_COLOR,
		TITLE_ENERGY_COLOR,
		TITLE_ENERGY_PEAK_COLOR)
	if not _materials_match_palette(
			title_materials,
			TITLE_FACE_COLOR,
			TITLE_STRUCTURE_COLOR,
			TITLE_ENERGY_COLOR,
			TITLE_ENERGY_PEAK_COLOR):
		push_error("Boot title default palette was not restored.")
		get_tree().quit(1)
		return
	title_column.call(&"_set_flow_phase", 0.5)
	await RenderingServer.frame_post_draw
	var flow_baseline := get_viewport().get_texture().get_image()
	var flow_bounds: Array[Rect2i] = []
	for title_node: TextureRect in title_nodes:
		flow_bounds.append(
			_control_image_bounds(title_node, flow_baseline, 428))

	var energy_early_metrics: Array[Vector4] = []
	var energy_late_metrics: Array[Vector4] = []
	var structure_early_metrics: Array[Vector4] = []
	var structure_late_metrics: Array[Vector4] = []
	var fragment_metrics: Array[Vector2] = []
	for index: int in title_nodes.size():
		var glyph_delay := float(index) * normalized_stagger
		var early_phase := glyph_delay + normalized_flow_duration * 0.25
		var late_phase := glyph_delay + normalized_flow_duration * 0.75
		var release_phase := (
				glyph_delay
				+ normalized_flow_duration
				+ normalized_release_duration * 0.45)

		title_column.call(&"_set_flow_phase", early_phase)
		await RenderingServer.frame_post_draw
		var early_image := get_viewport().get_texture().get_image()
		energy_early_metrics.append(
			_energy_flow_metrics(
				flow_baseline,
				early_image,
				flow_bounds[index]))
		structure_early_metrics.append(
			_structure_tint_metrics(
				flow_baseline,
				early_image,
				flow_bounds[index]))

		title_column.call(&"_set_flow_phase", late_phase)
		await RenderingServer.frame_post_draw
		var late_image := get_viewport().get_texture().get_image()
		energy_late_metrics.append(
			_energy_flow_metrics(
				flow_baseline,
				late_image,
				flow_bounds[index]))
		structure_late_metrics.append(
			_structure_tint_metrics(
				flow_baseline,
				late_image,
				flow_bounds[index]))

		title_column.call(&"_set_flow_phase", release_phase)
		await RenderingServer.frame_post_draw
		var release_image := get_viewport().get_texture().get_image()
		fragment_metrics.append(
			_fragment_release_metrics(
				flow_baseline,
				release_image,
				flow_bounds[index]))

	print(
		"BOOT_TITLE_FLOW_RENDER: early=%s late=%s"
		% [energy_early_metrics, energy_late_metrics])
	print(
		"BOOT_TITLE_STRUCTURE_RENDER: early=%s late=%s"
		% [structure_early_metrics, structure_late_metrics])
	print("BOOT_TITLE_FRAGMENT_RENDER: %s" % [fragment_metrics])

	for index: int in title_nodes.size():
		var early_energy := energy_early_metrics[index]
		var late_energy := energy_late_metrics[index]
		if (
			early_energy.x < 50.0
			or late_energy.x < 50.0
			or early_energy.y < 0.04
			or late_energy.y < 0.04
			or early_energy.z < 0.015
			or late_energy.z < 0.015
			or late_energy.w - early_energy.w < 40.0
		):
			push_error(
				"Boot title energy head does not travel left-to-right on %s."
				% title_nodes[index].name)
			get_tree().quit(1)
			return

		var early_structure := structure_early_metrics[index]
		var late_structure := structure_late_metrics[index]
		var peak_structure := early_structure
		var matching_energy := early_energy
		if late_structure.y > early_structure.y:
			peak_structure = late_structure
			matching_energy = late_energy
		if (
			peak_structure.x < 8.0
			or peak_structure.y < 0.02
			or peak_structure.z < 0.001
			or absf(peak_structure.w - matching_energy.w) > 25.0
		):
			push_error(
				"Boot title structure tint is missing or detached on %s."
				% title_nodes[index].name)
			get_tree().quit(1)
			return

		var glyph_fragments := fragment_metrics[index]
		if glyph_fragments.x < 4.0 or glyph_fragments.y < 0.08:
			push_error(
				"Boot title endpoint fragments were not rendered on %s."
				% title_nodes[index].name)
			get_tree().quit(1)
			return

	title_phase_tween.play()

	print("BOOT_TITLE_PALETTE_SWAP_OK")
	print("BOOT_TITLE_FLOW_OK")
	print("BOOT_TITLE_STRUCTURE_TINT_OK")
	print("BOOT_TITLE_FRAGMENT_RELEASE_OK")
	await get_tree().create_timer(0.75).timeout
	await RenderingServer.frame_post_draw

	var error := get_viewport().get_texture().get_image().save_png(OUT_PATH)
	if error != OK:
		push_error("Boot 截图保存失败：%s" % error_string(error))
		get_tree().quit(1)
		return

	print("BOOT_CHAR2_PROBE_OK: ", OUT_PATH)
	var observer := TransitionObserver.new()
	get_tree().root.add_child(observer)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(960.0, 540.0)
	get_viewport().push_input(click, true)
