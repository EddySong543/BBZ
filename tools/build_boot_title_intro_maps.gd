extends SceneTree

const SOURCE_ENERGY := Color8(221, 86, 57, 255)
const TITLE_DURATION_SECONDS := 0.76
const CRACK_START_SECONDS := 0.08
const CRACK_END_SECONDS := 0.46
const FACE_TRAIL_START_SECONDS := 0.08
const FACE_TRAIL_SPAN_SECONDS := 0.10
const FACE_DISTANCE_PIXELS := 42.0
const PIXEL_BLOCK_SIZE := 4

const TITLE_PARTS: Array[Dictionary] = [
	{
		"source": "res://assets/ui/boot/title_bo_top.png",
		"output": "res://assets/ui/boot/title_intro_bo_top.png",
		"group_start": 0.0,
		"group_end": 270.0 / 726.0,
	},
	{
		"source": "res://assets/ui/boot/title_bo_middle.png",
		"output": "res://assets/ui/boot/title_intro_bo_middle.png",
		"group_start": 228.0 / 726.0,
		"group_end": 498.0 / 726.0,
	},
	{
		"source": "res://assets/ui/boot/title_zan_bottom.png",
		"output": "res://assets/ui/boot/title_intro_zan_bottom.png",
		"group_start": 456.0 / 726.0,
		"group_end": 1.0,
	},
	{
		"source": "res://assets/ui/boot/title_chuan.png",
		"output": "res://assets/ui/boot/title_intro_chuan.png",
		"group_start": 0.0,
		"group_end": 1.0,
	},
	{
		"source": "res://assets/ui/boot/title_shuo.png",
		"output": "res://assets/ui/boot/title_intro_shuo.png",
		"group_start": 0.0,
		"group_end": 1.0,
	},
]


func _init() -> void:
	for part: Dictionary in TITLE_PARTS:
		if not _build_part(part):
			quit(1)
			return
	print("BOOT_TITLE_INTRO_MAPS_OK: parts=%d block=%d" % [
		TITLE_PARTS.size(),
		PIXEL_BLOCK_SIZE,
	])
	quit()


func _build_part(part: Dictionary) -> bool:
	var source_path := String(part["source"])
	var source := Image.load_from_file(
		ProjectSettings.globalize_path(source_path))
	if source == null or source.is_empty():
		push_error("Boot title source could not be loaded: %s" % source_path)
		return false
	source.convert(Image.FORMAT_RGBA8)

	var width := source.get_width()
	var height := source.get_height()
	var pixel_count := width * height
	var distances := PackedInt32Array()
	distances.resize(pixel_count)
	distances.fill(-1)
	var nearest_crack_time := PackedFloat32Array()
	nearest_crack_time.resize(pixel_count)
	nearest_crack_time.fill(1.0)
	var queue := PackedInt32Array()
	var group_start := float(part["group_start"])
	var group_end := float(part["group_end"])

	for y: int in height:
		for x: int in width:
			if not _is_energy_pixel(source.get_pixel(x, y)):
				continue
			var index := y * width + x
			distances[index] = 0
			nearest_crack_time[index] = _crack_time(
				x,
				width,
				group_start,
				group_end)
			queue.append(index)

	if queue.is_empty():
		push_error("Boot title source contains no energy cuts: %s" % source_path)
		return false

	var queue_head := 0
	while queue_head < queue.size():
		var index := queue[queue_head]
		queue_head += 1
		var x := index % width
		var y := index / width
		var next_distance := distances[index] + 1
		for offset: Vector2i in [
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.UP,
			Vector2i.DOWN,
		]:
			var next_x := x + offset.x
			var next_y := y + offset.y
			if (
				next_x < 0
				or next_x >= width
				or next_y < 0
				or next_y >= height
			):
				continue
			var next_index := next_y * width + next_x
			if distances[next_index] >= 0:
				continue
			distances[next_index] = next_distance
			nearest_crack_time[next_index] = nearest_crack_time[index]
			queue.append(next_index)

	var output := Image.create(
		width,
		height,
		false,
		Image.FORMAT_RGBA8)
	for block_y: int in range(0, height, PIXEL_BLOCK_SIZE):
		for block_x: int in range(0, width, PIXEL_BLOCK_SIZE):
			var sample_x := mini(
				block_x + PIXEL_BLOCK_SIZE / 2,
				width - 1)
			var sample_y := mini(
				block_y + PIXEL_BLOCK_SIZE / 2,
				height - 1)
			var sample_index := sample_y * width + sample_x
			var crack_activation := nearest_crack_time[sample_index]
			var distance_ratio := clampf(
				float(distances[sample_index]) / FACE_DISTANCE_PIXELS,
				0.0,
				1.0)
			var face_activation := clampf(
				crack_activation
					+ FACE_TRAIL_START_SECONDS / TITLE_DURATION_SECONDS
					+ distance_ratio
						* FACE_TRAIL_SPAN_SECONDS
						/ TITLE_DURATION_SECONDS,
				0.0,
				0.842105)
			for y: int in range(
				block_y,
				mini(block_y + PIXEL_BLOCK_SIZE, height)):
				for x: int in range(
					block_x,
					mini(block_x + PIXEL_BLOCK_SIZE, width)):
					output.set_pixel(
						x,
						y,
						Color(
							face_activation,
							crack_activation,
							0.0,
							1.0))

	var output_path := String(part["output"])
	var save_error := output.save_png(
		ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		push_error("Boot title intro map could not be saved: %s" % output_path)
		return false
	return true


func _crack_time(
	x: int,
	width: int,
	group_start: float,
	group_end: float,
) -> float:
	var local_x := float(x) / maxf(float(width - 1), 1.0)
	var global_x := lerpf(group_start, group_end, local_x)
	return lerpf(
		CRACK_START_SECONDS / TITLE_DURATION_SECONDS,
		CRACK_END_SECONDS / TITLE_DURATION_SECONDS,
		1.0 - global_x)


func _is_energy_pixel(color: Color) -> bool:
	return (
		color.a > 0.5
		and color.is_equal_approx(SOURCE_ENERGY)
	)
