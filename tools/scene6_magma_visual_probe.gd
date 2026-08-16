extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	var packed := load("res://src/ui/scenes/scene6.tscn") as PackedScene
	var stage := packed.instantiate() as Control
	add_child(stage)
	await get_tree().create_timer(0.8).timeout
	var magma := stage.get_node("MagmaLake") as ColorRect
	var material := magma.material.duplicate(true) as ShaderMaterial
	magma.material = material
	for phase_entry: Array in [
		[0.0, "00"],
		[0.25, "25"],
		[0.5, "50"],
		[0.75, "75"],
		[1.0, "100"],
	]:
		material.set_shader_parameter("phase_override", phase_entry[0] as float)
		await get_tree().process_frame
		await _shot(ProbeOutput.path(
				"scene6_magma_stage_phase_%s.png" % (phase_entry[1] as String)))
	var loop_zero := await _render_magma_sample(material, 0.0)
	var loop_one := await _render_magma_sample(material, 1.0)
	var loop_diff_pixels := _count_pixel_differences(loop_zero, loop_one)
	var lumas: Array[float] = [_average_visible_luma(loop_zero)]
	for sample_phase: float in [0.25, 0.5, 0.75]:
		lumas.append(_average_visible_luma(
				await _render_magma_sample(material, sample_phase)))
	var luma_amplitude := (lumas.max() as float) - (lumas.min() as float)
	loop_zero.save_png(ProbeOutput.path("scene6_magma_crisp_isolated_00.png"))
	loop_one.save_png(ProbeOutput.path("scene6_magma_crisp_isolated_100.png"))
	var passed := loop_diff_pixels == 0 and luma_amplitude <= 0.035
	print("SCENE6_MAGMA_VISUAL_PROBE: ", "PASS" if passed else "FAIL",
			" loop_diff_pixels=", loop_diff_pixels,
			" luma_amplitude=", luma_amplitude)
	get_tree().quit(0 if passed else 1)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save %s (error=%d)" % [path, error])


func _render_magma_sample(source_material: ShaderMaterial, phase: float) -> Image:
	var sample_viewport := SubViewport.new()
	sample_viewport.size = Vector2i(512, 128)
	sample_viewport.transparent_bg = true
	sample_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sample_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sample_viewport)
	var sample_rect := ColorRect.new()
	sample_rect.size = Vector2(512.0, 128.0)
	var sample_material := source_material.duplicate(true) as ShaderMaterial
	sample_material.set_shader_parameter("size_px", Vector2(512.0, 128.0))
	sample_material.set_shader_parameter("phase_override", phase)
	sample_rect.material = sample_material
	sample_viewport.add_child(sample_rect)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := sample_viewport.get_texture().get_image()
	sample_viewport.queue_free()
	return image


func _count_pixel_differences(first: Image, second: Image) -> int:
	if first == null or second == null or first.get_size() != second.get_size():
		return -1
	var differences := 0
	for y: int in first.get_height():
		for x: int in first.get_width():
			if first.get_pixel(x, y) != second.get_pixel(x, y):
				differences += 1
	return differences


func _average_visible_luma(image: Image) -> float:
	var total := 0.0
	var visible := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.9:
				continue
			total += color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			visible += 1
	return total / float(maxi(visible, 1))
