extends SceneTree

const SCENE_PATH := "res://src/ui/scenes/scene9.tscn"
const OUTPUT_PATH := (
		"res://assets/scenes/scene9/scene9_battle_platform_assembled.png")
const OUTPUT_SIZE := Vector2i(480, 270)
const SCREEN_PIXEL_SCALE := 4
const PLATFORM_NAMES: Array[String] = [
	"BattlePlatform2",
	"BattlePlatform4",
	"BattlePlatform3",
	"BattlePlatform5",
	"BattlePlatform",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1920.0, 1080.0)
	root.add_child(host)
	var stage := (load(SCENE_PATH) as PackedScene).instantiate() as Control
	host.add_child(stage)
	await process_frame

	var layers: Array[TextureRect] = []
	var source_images: Array[Image] = []
	for node_name: String in PLATFORM_NAMES:
		var layer := stage.get_node(node_name) as TextureRect
		layers.append(layer)
		source_images.append(layer.texture.get_image())

	var output := Image.create(OUTPUT_SIZE.x, OUTPUT_SIZE.y, false,
			Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for output_y: int in OUTPUT_SIZE.y:
		for output_x: int in OUTPUT_SIZE.x:
			var screen_point := Vector2(
					output_x * SCREEN_PIXEL_SCALE + SCREEN_PIXEL_SCALE * 0.5,
					output_y * SCREEN_PIXEL_SCALE + SCREEN_PIXEL_SCALE * 0.5)
			var composed := Color.TRANSPARENT
			for layer_index: int in layers.size():
				var layer := layers[layer_index]
				var local_point := layer.get_global_transform().affine_inverse() \
						* screen_point
				if not Rect2(Vector2.ZERO, layer.size).has_point(local_point):
					continue
				var uv := local_point / layer.size
				var image := source_images[layer_index]
				var source_pixel := Vector2i(
						clampi(int(floor(uv.x * image.get_width())), 0,
								image.get_width() - 1),
						clampi(int(floor(uv.y * image.get_height())), 0,
								image.get_height() - 1))
				composed = composed.blend(image.get_pixelv(source_pixel))
			output.set_pixel(output_x, output_y, composed)

	var error := output.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save Scene9 platform assembly: %s" % error_string(error))
		quit(1)
		return
	var used_rect := output.get_used_rect()
	var opaque_count := 0
	for y: int in output.get_height():
		for x: int in output.get_width():
			if output.get_pixel(x, y).a >= 0.03:
				opaque_count += 1
	print("SCENE9_PLATFORM_ASSEMBLY path=", OUTPUT_PATH,
			" size=", output.get_size(), " used_rect=", used_rect,
			" opaque_pixels=", opaque_count)
	quit()
