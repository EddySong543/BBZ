extends Node

const SCENE7_PATH := "res://src/ui/scenes/scene7.tscn"
const MIDGROUND_NAMES: Array[String] = [
	"MidgroundLeft",
	"MidgroundCenter",
	"MidgroundRight",
]


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	RenderingServer.set_default_clear_color(Color.BLACK)
	var stage := (load(SCENE7_PATH) as PackedScene).instantiate() as BattleStage
	add_child(stage)
	stage.set_process(false)
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	var passed := true
	for node_name: String in MIDGROUND_NAMES:
		var layer := stage.get_node(node_name) as TextureRect
		layer.visible = true
		await RenderingServer.frame_post_draw
		var rendered := get_viewport().get_texture().get_image()
		var source_stats := _cool_stats(layer.texture.get_image(), 1, true)
		var rendered_stats := _cool_stats(rendered, 2, false)
		layer.visible = false

		var layer_passed := (
			source_stats.x > 0.0
			and rendered_stats.x >= source_stats.x * 0.72
			and rendered_stats.x <= source_stats.x * 1.10
			and rendered_stats.y <= 0.03
			and rendered_stats.z >= 0.52
			and rendered_stats.z <= 0.62
			and rendered_stats.z / rendered_stats.x <= 2.10
			and rendered_stats.w >= 0.20)
		passed = passed and layer_passed
		print(
			"SCENE7_MIDGROUND_BIOLUME_LAYER: ",
			"PASS" if layer_passed else "FAIL",
			" node=", node_name,
			" source_cool_mean=", snappedf(source_stats.x, 0.001),
			" rendered_cool_mean=", snappedf(rendered_stats.x, 0.001),
			" source_bright_fraction=", snappedf(source_stats.y, 0.001),
			" rendered_bright_fraction=", snappedf(rendered_stats.y, 0.001),
			" rendered_peak=", snappedf(rendered_stats.z, 0.001),
			" source_midtone_fraction=", snappedf(source_stats.w, 0.001),
			" rendered_midtone_fraction=", snappedf(rendered_stats.w, 0.001))

	print("SCENE7_MIDGROUND_BIOLUME_PROBE: ", "PASS" if passed else "FAIL")
	get_tree().quit(0 if passed else 1)


func _cool_stats(image: Image, step: int, use_alpha: bool) -> Vector4:
	var cool_value_sum := 0.0
	var cool_count := 0
	var bright_count := 0
	var midtone_count := 0
	var peak := 0.0
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample := image.get_pixel(x, y)
			if use_alpha and sample.a < 0.2:
				continue
			var cool_value := maxf(sample.g, sample.b)
			var warm_value := maxf(sample.r, minf(sample.g, sample.b) * 0.34)
			if cool_value < 0.10 or cool_value - warm_value < 0.08:
				continue
			cool_value_sum += cool_value
			cool_count += 1
			bright_count += 1 if cool_value >= 0.58 else 0
			midtone_count += 1 if cool_value >= 0.30 and cool_value < 0.58 else 0
			peak = maxf(peak, cool_value)
	if cool_count == 0:
		return Vector4.ZERO
	return Vector4(
		cool_value_sum / float(cool_count),
		float(bright_count) / float(cool_count),
		peak,
		float(midtone_count) / float(cool_count))
