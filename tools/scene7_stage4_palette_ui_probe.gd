extends Node

const BATTLE7_PATH := "res://src/ui/battle_screen7.tscn"

const P1_HUD_REGION := Rect2i(16, 0, 740, 150)
const P2_HUD_REGION := Rect2i(1164, 0, 740, 150)
const TIMER_REGION := Rect2i(760, 0, 400, 110)
const LEFT_TOP_GAP_REGION := Rect2i(742, 0, 42, 160)
const RIGHT_TOP_GAP_REGION := Rect2i(1136, 0, 42, 160)
const P1_FADE_UPPER_REGION := Rect2i(96, 100, 570, 24)
const P1_FADE_LOWER_REGION := Rect2i(96, 140, 570, 24)
const BUTTON_REGION := Rect2i(580, 890, 800, 150)
const PLAYFIELD_REGION := Rect2i(720, 300, 480, 350)


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (load(BATTLE7_PATH) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(0.75).timeout
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	stage.set_process(false)
	screen.set_process(false)
	await RenderingServer.frame_post_draw
	var ui_frame := get_viewport().get_texture().get_image()

	var ui_nodes: Array[CanvasItem] = []
	for node_name: String in ["P1Hud", "P2Hud", "TimerLabel", "Buttons"]:
		var item := screen.get_node(node_name) as CanvasItem
		ui_nodes.append(item)
		item.visible = false
	await RenderingServer.frame_post_draw
	var shaded_background := get_viewport().get_texture().get_image()

	var veil := screen.get_node("UiReadabilityVeil") as ColorRect
	veil.visible = false
	await RenderingServer.frame_post_draw
	var unshaded_background := get_viewport().get_texture().get_image()

	var p1_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, P1_HUD_REGION, 3)
	var p2_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, P2_HUD_REGION, 3)
	var timer_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, TIMER_REGION, 3)
	var button_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, BUTTON_REGION, 3)
	var playfield_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, PLAYFIELD_REGION, 4)
	var left_gap_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, LEFT_TOP_GAP_REGION, 2)
	var right_gap_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, RIGHT_TOP_GAP_REGION, 2)
	var p1_fade_upper_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, P1_FADE_UPPER_REGION, 2)
	var p1_fade_lower_attenuation := _luma_attenuation(
			unshaded_background, shaded_background, P1_FADE_LOWER_REGION, 2)
	var fade_transition_delta := absf(
			p1_fade_upper_attenuation - p1_fade_lower_attenuation)
	var p1_bright_attenuation := _conditional_attenuation(
			unshaded_background, shaded_background, P1_HUD_REGION, 0.55, 1.0, 3)
	var p2_bright_attenuation := _conditional_attenuation(
			unshaded_background, shaded_background, P2_HUD_REGION, 0.55, 1.0, 3)
	var hud_dark_attenuation := maxf(
			_conditional_attenuation(
					unshaded_background, shaded_background, P1_HUD_REGION, 0.0, 0.40, 3),
			_conditional_attenuation(
					unshaded_background, shaded_background, P2_HUD_REGION, 0.0, 0.40, 3))
	var p1_contrast := _ui_contrast_stats(ui_frame, shaded_background, P1_HUD_REGION, 2)
	var p2_contrast := _ui_contrast_stats(ui_frame, shaded_background, P2_HUD_REGION, 2)
	var timer_contrast := _ui_contrast_stats(ui_frame, shaded_background, TIMER_REGION, 2)
	var button_contrast := _ui_contrast_stats(ui_frame, shaded_background, BUTTON_REGION, 2)
	var high_saturation_fraction := _fraction_above_saturation(ui_frame, 0.65, 4)
	var top_luma := _mean_luma(ui_frame, Rect2i(640, 150, 640, 140), 4)
	var center_luma := _mean_luma(ui_frame, Rect2i(640, 300, 640, 400), 4)
	var edge_luma := (
			_mean_luma(ui_frame, Rect2i(0, 180, 320, 600), 4)
			+ _mean_luma(ui_frame, Rect2i(1600, 180, 320, 600), 4)) * 0.5
	var road_luma := _mean_luma(ui_frame, Rect2i(760, 745, 270, 100), 4)
	var water_luma := _mean_luma(ui_frame, Rect2i(760, 875, 270, 45), 4)
	var water_color := _mean_color(ui_frame, Rect2i(760, 875, 270, 45), 4)
	var water_hue := water_color.h * 360.0
	var sky_clear_ready := (
			(stage.get_node("Sky") as TextureRect).material == null
			and (stage.get_node("OasisMotesFar") as ColorRect).position.y >= 500.0
			and (stage.get_node("OasisMotesMid") as ColorRect).position.y >= 420.0
			and (stage.get_node("OasisMotesNear") as ColorRect).position.y >= 600.0)
	var midground_grade_ready := true
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var material := (stage.get_node(node_name) as TextureRect).material as ShaderMaterial
		midground_grade_ready = (
				midground_grade_ready
				and float(material.get_shader_parameter("base_brightness")) <= 1.0
				and float(material.get_shader_parameter("emission_strength")) <= 0.16
				and float(material.get_shader_parameter("halo_strength")) <= 0.24
				and float(material.get_shader_parameter("halo_alpha")) <= 0.12
				and is_equal_approx(float(material.get_shader_parameter("halo_radius")), 1.0)
				and float(material.get_shader_parameter("core_preservation")) >= 0.76
				and float(material.get_shader_parameter("core_preservation")) <= 0.86
				and float(material.get_shader_parameter("source_cyan_compression")) >= 0.20
				and float(material.get_shader_parameter("source_cyan_compression")) <= 0.28
				and float(material.get_shader_parameter("source_cyan_value_ceiling")) >= 0.66
				and float(material.get_shader_parameter("core_value_floor")) >= 0.63
				and float(material.get_shader_parameter("core_value_ceiling")) <= 0.80
				and float(material.get_shader_parameter("source_cyan_midtone_lift")) >= 0.08
				and float(material.get_shader_parameter("highlight_shoulder_strength")) >= 1.2
				and float(material.get_shader_parameter("highlight_shoulder_strength")) <= 1.5)
	var platform_material := (
			stage.get_node("BattlePlatform") as TextureRect).material as ShaderMaterial
	var platform_elevation_ready := (
			float(platform_material.get_shader_parameter("dry_edge_strength")) >= 0.34
			and float(platform_material.get_shader_parameter("wet_edge_strength")) >= 0.22
			and float(platform_material.get_shader_parameter("contact_shadow_strength")) >= 0.28
			and road_luma >= water_luma + 0.18)

	var localized_backplates_ready := (
			p1_bright_attenuation >= 0.025
			and p2_bright_attenuation >= 0.025
			and timer_attenuation >= 0.025
			and hud_dark_attenuation <= 0.010
			and absf(left_gap_attenuation) <= 0.006
			and absf(right_gap_attenuation) <= 0.006
			and p1_fade_upper_attenuation >= p1_fade_lower_attenuation
			and p1_fade_lower_attenuation >= 0.002
			and fade_transition_delta <= 0.025
			and absf(playfield_attenuation) <= 0.01)
	var ui_signal_ready := (
			p1_contrast.x >= 0.08
			and p2_contrast.x >= 0.08
			# The timer is one narrow glyph group inside a deliberately wide safety
			# region, so coverage is lower than the framed HUD and button groups.
			and timer_contrast.x >= 0.035
			and button_contrast.x >= 0.065
			and p1_contrast.y >= 1.55
			and p2_contrast.y >= 1.55
			and timer_contrast.y >= 1.55
			and button_contrast.y >= 1.45)
	var palette_ready := (
			high_saturation_fraction <= 0.38
			and top_luma >= 0.48
			and top_luma <= 0.72
			and center_luma >= edge_luma * 1.15
			and center_luma <= edge_luma * 1.5
			and water_hue >= 160.0
			and water_hue <= 190.0
			and platform_elevation_ready)
	var passed := (
			localized_backplates_ready
			and ui_signal_ready
			and palette_ready
			and sky_clear_ready
			and midground_grade_ready)
	print(
			"SCENE7_STAGE4_PALETTE_UI_PROBE: ", "PASS" if passed else "FAIL",
			" localized_backplates_ready=", localized_backplates_ready,
			" ui_signal_ready=", ui_signal_ready,
			" palette_ready=", palette_ready,
			" sky_clear_ready=", sky_clear_ready,
			" midground_grade_ready=", midground_grade_ready,
			" platform_elevation_ready=", platform_elevation_ready,
			" p1_attenuation=", snappedf(p1_attenuation, 0.0001),
			" p2_attenuation=", snappedf(p2_attenuation, 0.0001),
			" timer_attenuation=", snappedf(timer_attenuation, 0.0001),
			" button_attenuation=", snappedf(button_attenuation, 0.0001),
			" playfield_attenuation=", snappedf(playfield_attenuation, 0.0001),
			" left_gap_attenuation=", snappedf(left_gap_attenuation, 0.0001),
			" right_gap_attenuation=", snappedf(right_gap_attenuation, 0.0001),
			" p1_fade_upper_attenuation=", snappedf(p1_fade_upper_attenuation, 0.0001),
			" p1_fade_lower_attenuation=", snappedf(p1_fade_lower_attenuation, 0.0001),
			" fade_transition_delta=", snappedf(fade_transition_delta, 0.0001),
			" p1_bright_attenuation=", snappedf(p1_bright_attenuation, 0.0001),
			" p2_bright_attenuation=", snappedf(p2_bright_attenuation, 0.0001),
			" hud_dark_attenuation=", snappedf(hud_dark_attenuation, 0.0001),
			" p1_ui_signal_fraction=", snappedf(p1_contrast.x, 0.0001),
			" p1_ui_mean_contrast=", snappedf(p1_contrast.y, 0.001),
			" p2_ui_signal_fraction=", snappedf(p2_contrast.x, 0.0001),
			" p2_ui_mean_contrast=", snappedf(p2_contrast.y, 0.001),
			" timer_ui_signal_fraction=", snappedf(timer_contrast.x, 0.0001),
			" timer_ui_mean_contrast=", snappedf(timer_contrast.y, 0.001),
			" button_ui_signal_fraction=", snappedf(button_contrast.x, 0.0001),
			" button_ui_mean_contrast=", snappedf(button_contrast.y, 0.001),
			" high_saturation_fraction=", snappedf(high_saturation_fraction, 0.0001),
			" top_luma=", snappedf(top_luma, 0.001),
			" center_luma=", snappedf(center_luma, 0.001),
			" edge_luma=", snappedf(edge_luma, 0.001),
			" water_hue=", snappedf(water_hue, 0.1),
			" road_water_luma_delta=", snappedf(road_luma - water_luma, 0.001))
	for item: CanvasItem in ui_nodes:
		item.visible = true
	veil.visible = true
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _luma_attenuation(
		unshaded: Image, shaded: Image, region: Rect2i, step: int) -> float:
	return _mean_luma(unshaded, region, step) - _mean_luma(shaded, region, step)


func _conditional_attenuation(
		unshaded: Image,
		shaded: Image,
		region: Rect2i,
		minimum_luma: float,
		maximum_luma: float,
		step: int) -> float:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, unshaded.get_size()))
	var sum := 0.0
	var count := 0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var before := _luma(unshaded.get_pixel(x, y))
			if before < minimum_luma or before > maximum_luma:
				continue
			sum += before - _luma(shaded.get_pixel(x, y))
			count += 1
	return sum / float(count) if count > 0 else 0.0


func _ui_contrast_stats(
		ui_frame: Image, background: Image, region: Rect2i, step: int) -> Vector2:
	var bounds := Rect2i(Vector2i.ZERO, ui_frame.get_size())
	var clipped := region.intersection(bounds)
	var signal_count := 0
	var sampled_count := 0
	var ratio_sum := 0.0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var foreground_luma := _luma(ui_frame.get_pixel(x, y))
			var background_luma := _luma(background.get_pixel(x, y))
			var delta := absf(foreground_luma - background_luma)
			sampled_count += 1
			if delta < 0.12:
				continue
			var lighter := maxf(foreground_luma, background_luma)
			var darker := minf(foreground_luma, background_luma)
			ratio_sum += (lighter + 0.05) / (darker + 0.05)
			signal_count += 1
	if sampled_count == 0 or signal_count == 0:
		return Vector2.ZERO
	return Vector2(
			float(signal_count) / float(sampled_count),
			ratio_sum / float(signal_count))


func _mean_luma(image: Image, region: Rect2i, step: int) -> float:
	return _luma(_mean_color(image, region, step))


func _mean_color(image: Image, region: Rect2i, step: int) -> Color:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var sum := Vector3.ZERO
	var count := 0
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var sample := image.get_pixel(x, y)
			sum += Vector3(sample.r, sample.g, sample.b)
			count += 1
	if count == 0:
		return Color.BLACK
	var mean := sum / float(count)
	return Color(mean.x, mean.y, mean.z, 1.0)


func _fraction_above_saturation(image: Image, threshold: float, step: int) -> float:
	var saturated_count := 0
	var sampled_count := 0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			var maximum := maxf(sample.r, maxf(sample.g, sample.b))
			var minimum := minf(sample.r, minf(sample.g, sample.b))
			var saturation := (maximum - minimum) / maxf(maximum, 0.001)
			saturated_count += 1 if saturation >= threshold else 0
			sampled_count += 1
	return float(saturated_count) / float(sampled_count) if sampled_count > 0 else 0.0


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
