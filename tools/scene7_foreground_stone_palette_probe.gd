extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")
const STONE_SHADER := \
		"res://assets/shaders/canvas_env_scene7_foreground_stone_grade.gdshader"


func _initialize() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	var stone := stage.get_node("ForegroundCenterStone") as TextureRect
	var left := stage.get_node("ForegroundLeft") as TextureRect
	var right := stage.get_node("ForegroundRight") as TextureRect
	var material := stone.material as ShaderMaterial
	var left_material := left.material as ShaderMaterial
	var right_material := right.material as ShaderMaterial
	var stone_mean := _stone_output_mean(stone.texture.get_image(), material)
	var left_mean := _foreground_body_mean(left.texture.get_image(), left_material)
	var right_mean := _foreground_body_mean(right.texture.get_image(), right_material)
	var side_mean := (left_mean + right_mean) * 0.5
	var shared_material_ready := true
	for node_name: String in [
		"ForegroundCenterStone",
		"ForegroundCenterStone2",
		"ForegroundCenterStone3",
	]:
		var layer := stage.get_node(node_name) as TextureRect
		shared_material_ready = (
			shared_material_ready
			and layer.material == material
			and layer.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	var palette_distance := (stone_mean - side_mean).length()
	var passed := (
		material.shader.resource_path == STONE_SHADER
		and shared_material_ready
		and float(material.get_shader_parameter("palette_strength")) >= 0.20
		and float(material.get_shader_parameter("palette_strength")) <= 0.24
		and float(material.get_shader_parameter("base_brightness")) <= 0.86
		and palette_distance <= 0.04
		and stone_mean.y <= side_mean.y * 1.25
		and stone_mean.z <= side_mean.z * 1.25
		and stone_mean.x < maxf(stone_mean.y, stone_mean.z)
		and maxf(stone_mean.x, maxf(stone_mean.y, stone_mean.z)) <= 0.14)
	print(
		"SCENE7_FOREGROUND_STONE_PALETTE: ",
		"PASS" if passed else "FAIL",
		" left_body_mean=", left_mean,
		" right_body_mean=", right_mean,
		" side_mean=", side_mean,
		" stone_mean=", stone_mean,
		" palette_distance=", snappedf(palette_distance, 0.001),
		" shared_material=", shared_material_ready)
	stage.free()
	quit(0 if passed else 1)


func _stone_output_mean(image: Image, material: ShaderMaterial) -> Vector3:
	var ambient := _rgb(material.get_shader_parameter("ambient_tint"))
	var cool_tint := _rgb(material.get_shader_parameter("cool_body_tint"))
	var shadow := _rgb(material.get_shader_parameter("shadow_palette"))
	var sunlit := _rgb(material.get_shader_parameter("sunlit_palette"))
	var cool_mix := float(material.get_shader_parameter("cool_body_tint_mix"))
	var palette_strength := float(material.get_shader_parameter("palette_strength"))
	var brightness := float(material.get_shader_parameter("base_brightness"))
	var highlight_ceiling := float(material.get_shader_parameter("highlight_ceiling"))
	var output_sum := Vector3.ZERO
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var sample := image.get_pixel(x, y)
			if sample.a < 0.5:
				continue
			var source := Vector3(sample.r, sample.g, sample.b)
			var source_value := maxf(source.x, maxf(source.y, source.z))
			var tint_peak := maxf(cool_tint.x, maxf(cool_tint.y, cool_tint.z))
			var teal_target := cool_tint * source_value / maxf(tint_peak, 0.001)
			var authored_body := source.lerp(
				teal_target, _cool_source_presence(source) * cool_mix)
			var source_luma := authored_body.dot(Vector3(0.2126, 0.7152, 0.0722))
			var oasis_palette := shadow.lerp(
				sunlit, smoothstep(0.12, 0.72, source_luma))
			var shaded := (authored_body * ambient).lerp(
				oasis_palette, palette_strength) * brightness
			var shaded_value := maxf(shaded.x, maxf(shaded.y, shaded.z))
			shaded *= minf(1.0, highlight_ceiling / maxf(shaded_value, 0.001))
			output_sum += shaded
			count += 1
	return output_sum / maxf(float(count), 1.0)


func _foreground_body_mean(image: Image, material: ShaderMaterial) -> Vector3:
	var ambient := _rgb(material.get_shader_parameter("ambient_tint"))
	var cool_tint := _rgb(material.get_shader_parameter("source_cyan_tint"))
	var shadow := _rgb(material.get_shader_parameter("shadow_palette"))
	var sunlit := _rgb(material.get_shader_parameter("sunlit_palette"))
	var palette_strength := float(material.get_shader_parameter("palette_strength"))
	var brightness := float(material.get_shader_parameter("base_brightness"))
	var cyan_start := float(material.get_shader_parameter("source_cyan_value_start"))
	var output_sum := Vector3.ZERO
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var sample := image.get_pixel(x, y)
			if sample.a < 0.5:
				continue
			var source := Vector3(sample.r, sample.g, sample.b)
			var cool_value := maxf(source.y, source.z)
			var bright_cool := _cool_source_presence(source) \
					* smoothstep(cyan_start, cyan_start + 0.12, cool_value)
			var tint_peak := maxf(cool_tint.x, maxf(cool_tint.y, cool_tint.z))
			var teal_target := cool_tint * cool_value / maxf(tint_peak, 0.001)
			var graded_source := source.lerp(
				source.lerp(teal_target, 0.18), bright_cool)
			var source_luma := graded_source.dot(Vector3(0.2126, 0.7152, 0.0722))
			var oasis_palette := shadow.lerp(
				sunlit, smoothstep(0.12, 0.72, source_luma))
			oasis_palette *= lerpf(0.78, 1.14, source_luma)
			var shaded := (graded_source * ambient).lerp(
				oasis_palette, palette_strength) * brightness
			output_sum += shaded
			count += 1
	return output_sum / maxf(float(count), 1.0)


func _cool_source_presence(color: Vector3) -> float:
	var cool_value := maxf(color.y, color.z)
	var warm_value := maxf(color.x, minf(color.y, color.z) * 0.34)
	return smoothstep(0.08, 0.34, cool_value - warm_value)


func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)
