extends SceneTree

const REFERENCE_PATHS: Array[String] = [
	"res://ref/ref40.png",
	"res://ref/ref41.png",
	"res://ref/ref42.png",
]
const MIDGROUND_PATHS: Array[String] = [
	"res://assets/scenes/scene7/scene7_midground_left.png",
	"res://assets/scenes/scene7/scene7_midground_center.png",
	"res://assets/scenes/scene7/scene7_midground_right.png",
]
const SAMPLE_STEP := 4
const BAND_RANGES: Array[Vector2] = [
	Vector2(0.42, 0.56),
	Vector2(0.56, 0.70),
	Vector2(0.70, 0.84),
	Vector2(0.84, 0.98),
]


func _initialize() -> void:
	var passed := true
	for resource_path: String in REFERENCE_PATHS:
		var absolute_path := ProjectSettings.globalize_path(resource_path)
		var image := Image.load_from_file(absolute_path)
		if image == null or image.is_empty():
			print("SCENE7_REFERENCE_WATER_PALETTE: FAIL path=", resource_path)
			passed = false
			continue
		print(
			"SCENE7_REFERENCE_WATER_PALETTE: image=", resource_path,
			" size=", image.get_width(), "x", image.get_height())
		for band: Vector2 in BAND_RANGES:
			_print_band_palette(image, resource_path, band)
	for resource_path: String in MIDGROUND_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
		if image == null or image.is_empty():
			print("SCENE7_REFERENCE_WATER_PALETTE: FAIL path=", resource_path)
			passed = false
			continue
		print(
			"SCENE7_MIDGROUND_PALETTE: image=", resource_path,
			" size=", image.get_width(), "x", image.get_height())
		_print_band_palette(image, resource_path, Vector2(0.0, 1.0))
		_print_band_palette(image, resource_path, Vector2(0.55, 1.0))
	quit(0 if passed else 1)


func _print_band_palette(
		image: Image, resource_path: String, band: Vector2) -> void:
	var y_start := floori(image.get_height() * band.x)
	var y_end := ceili(image.get_height() * band.y)
	var x_start := floori(image.get_width() * 0.04)
	var x_end := ceili(image.get_width() * 0.96)
	var buckets: Dictionary = {}
	var total := 0
	for y: int in range(y_start, y_end, SAMPLE_STEP):
		for x: int in range(x_start, x_end, SAMPLE_STEP):
			var color := image.get_pixel(x, y)
			if color.a < 0.12:
				continue
			var right := image.get_pixel(mini(x + SAMPLE_STEP, x_end - 1), y)
			var below := image.get_pixel(x, mini(y + SAMPLE_STEP, y_end - 1))
			var gradient := (_rgb_distance(color, right) + _rgb_distance(color, below)) * 0.5
			var key := _quantized_key(color)
			var stats: Vector4 = buckets.get(key, Vector4.ZERO)
			stats.x += 1.0
			stats.y += color.r
			stats.z += color.g
			stats.w += color.b
			buckets[key] = stats
			var gradient_key := -key - 1
			buckets[gradient_key] = float(buckets.get(gradient_key, 0.0)) + gradient
			total += 1
	var ranked: Array[int] = []
	for key: int in buckets:
		if key >= 0:
			ranked.append(key)
	ranked.sort_custom(func(a: int, b: int) -> bool:
		return (buckets[a] as Vector4).x > (buckets[b] as Vector4).x)
	var entries: Array[String] = []
	if total == 0:
		print(
			"SCENE7_REFERENCE_WATER_BAND: image=", resource_path.get_file(),
			" y=", snappedf(band.x, 0.01), "-", snappedf(band.y, 0.01),
			" palette=EMPTY")
		return
	for index: int in range(mini(10, ranked.size())):
		var key := ranked[index]
		var stats: Vector4 = buckets[key]
		var count := stats.x
		var color := Color(stats.y / count, stats.z / count, stats.w / count)
		var average_gradient := float(buckets[-key - 1]) / count
		entries.append(
			"#%s hsv(%.1f,%.1f,%.1f) share=%.3f grad=%.3f" % [
				color.to_html(false),
				color.h * 360.0,
				color.s * 100.0,
				color.v * 100.0,
				count / float(total),
				average_gradient,
			])
	print(
		"SCENE7_REFERENCE_WATER_BAND: image=", resource_path.get_file(),
		" y=", snappedf(band.x, 0.01), "-", snappedf(band.y, 0.01),
		" palette=", " | ".join(entries))


func _quantized_key(color: Color) -> int:
	var red := clampi(roundi(color.r * 15.0), 0, 15)
	var green := clampi(roundi(color.g * 15.0), 0, 15)
	var blue := clampi(roundi(color.b * 15.0), 0, 15)
	return (red << 8) | (green << 4) | blue


func _rgb_distance(a: Color, b: Color) -> float:
	var delta := Vector3(a.r - b.r, a.g - b.g, a.b - b.b)
	return delta.length()
