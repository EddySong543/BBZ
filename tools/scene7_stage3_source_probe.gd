extends SceneTree

const INPUTS: Array[String] = [
	"res://assets/scenes/scene7/scene7_battle_platform.png",
	"res://assets/scenes/scene7/scene7_midground_left.png",
	"res://assets/scenes/scene7/scene7_midground_center.png",
	"res://assets/scenes/scene7/scene7_midground_right.png",
	"res://assets/scenes/scene7/scene7_foreground_left.png",
	"res://assets/scenes/scene7/scene7_foreground_right.png",
	"res://assets/scenes/scene7/scene7_foreground_center_stone.png",
]


func _initialize() -> void:
	var passed := true
	for path: String in INPUTS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			print("SCENE7_STAGE3_SOURCE: FAIL path=", path)
			passed = false
			continue
		_print_shape(path, image)
		if "midground" in path.get_file():
			_print_biolume_palette(path, image)
	var stage := (load("res://src/ui/scenes/scene7.tscn") as PackedScene).instantiate()
	for node_name: String in ["MidgroundLeft", "MidgroundCenter", "MidgroundRight"]:
		var layer := stage.get_node(node_name) as TextureRect
		passed = _print_biolume_core_contract(layer) and passed
	stage.free()
	quit(0 if passed else 1)


func _print_shape(path: String, image: Image) -> void:
	var used := _alpha_used_rect(image, 0.5)
	var occupancy := 0
	for y: int in range(used.position.y, used.end.y):
		for x: int in range(used.position.x, used.end.x):
			occupancy += 1 if image.get_pixel(x, y).a >= 0.5 else 0
	var top_envelope: Array[int] = []
	var bottom_envelope: Array[int] = []
	for sample_index: int in 9:
		var x := clampi(
				roundi(lerpf(float(used.position.x), float(used.end.x - 1),
						float(sample_index) / 8.0)),
				0, image.get_width() - 1)
		var top := -1
		var bottom := -1
		for y: int in range(used.position.y, used.end.y):
			if image.get_pixel(x, y).a >= 0.5:
				top = y
				break
		for y: int in range(used.end.y - 1, used.position.y - 1, -1):
			if image.get_pixel(x, y).a >= 0.5:
				bottom = y
				break
		top_envelope.append(top)
		bottom_envelope.append(bottom)
	print(
		"SCENE7_STAGE3_SOURCE: PASS asset=", path.get_file(),
		" size=", image.get_size(),
		" used=", used,
		" occupancy=", snappedf(
				float(occupancy) / maxf(float(used.get_area()), 1.0), 0.001),
		" top9=", top_envelope,
		" bottom9=", bottom_envelope)


func _alpha_used_rect(image: Image, threshold: float) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _print_biolume_palette(path: String, image: Image) -> void:
	var cool_count := 0
	var bright_cool_count := 0
	var vivid_core_count := 0
	var cool_sum := 0.0
	var peak := 0.0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var sample := image.get_pixel(x, y)
			if sample.a < 0.2:
				continue
			var cool_value := maxf(sample.g, sample.b)
			var cyan_signal := minf(sample.g, sample.b) - sample.r * 0.62
			if cool_value < 0.10 or cyan_signal < 0.08:
				continue
			cool_count += 1
			cool_sum += cool_value
			peak = maxf(peak, cool_value)
			bright_cool_count += 1 if cool_value >= 0.58 else 0
			vivid_core_count += 1 if cool_value >= 0.68 and cyan_signal >= 0.18 else 0
	print(
		"SCENE7_BIOLUME_SOURCE: asset=", path.get_file(),
		" cool_count=", cool_count,
		" cool_mean=", snappedf(cool_sum / maxf(float(cool_count), 1.0), 0.001),
		" bright_fraction=", snappedf(
				float(bright_cool_count) / maxf(float(cool_count), 1.0), 0.001),
		" vivid_core_fraction=", snappedf(
				float(vivid_core_count) / maxf(float(cool_count), 1.0), 0.001),
		" peak=", snappedf(peak, 0.001))


func _print_biolume_core_contract(layer: TextureRect) -> bool:
	var image := layer.texture.get_image()
	var material := layer.material as ShaderMaterial
	var core_start := float(material.get_shader_parameter("core_start"))
	var core_full := float(material.get_shader_parameter("core_full"))
	var preservation := float(material.get_shader_parameter("core_preservation"))
	var bright_count := 0
	var retained_weight := 0.0
	var readable_core_count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var sample := image.get_pixel(x, y)
			if sample.a < 0.2:
				continue
			var cool_value := maxf(sample.g, sample.b)
			var cyan_signal := minf(sample.g, sample.b) - sample.r * 0.62
			if cool_value < 0.58 or cyan_signal < 0.08:
				continue
			bright_count += 1
			var vivid_cyan := smoothstep(0.08, 0.24, cyan_signal)
			var bright_tip := smoothstep(core_start, maxf(core_full, core_start + 0.02),
					cool_value)
			var core_weight := vivid_cyan * bright_tip * preservation
			retained_weight += core_weight
			readable_core_count += 1 if core_weight >= 0.35 else 0
	var weighted_retention := retained_weight / maxf(float(bright_count), 1.0)
	var readable_retention := float(readable_core_count) / maxf(float(bright_count), 1.0)
	var passed := (
		bright_count > 0
		and weighted_retention >= 0.45
		and weighted_retention <= 0.80
		and readable_retention >= 0.45
		and readable_retention <= 0.85
		and float(material.get_shader_parameter("core_value_floor")) >= 0.66
		and float(material.get_shader_parameter("core_value_ceiling")) <= 0.88
		and float(material.get_shader_parameter("halo_radius")) == 1.0)
	print(
		"SCENE7_BIOLUME_CORE_CONTRACT: ", "PASS" if passed else "FAIL",
		" node=", layer.name,
		" bright_count=", bright_count,
		" weighted_retention=", snappedf(weighted_retention, 0.001),
		" readable_retention=", snappedf(readable_retention, 0.001),
		" core_floor=", material.get_shader_parameter("core_value_floor"),
		" core_ceiling=", material.get_shader_parameter("core_value_ceiling"))
	return passed
