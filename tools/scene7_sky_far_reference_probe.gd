extends SceneTree

const INPUTS: Array[String] = [
	"res://ref/ref40.png",
	"res://ref/ref41.png",
	"res://ref/ref42.png",
	"res://assets/scenes/scene7/scene7_sky.png",
	"res://assets/scenes/scene7/scene7_far_background.png",
]
const BANDS: Array[Vector2] = [
	Vector2(0.02, 0.16),
	Vector2(0.16, 0.30),
	Vector2(0.30, 0.46),
	Vector2(0.46, 0.62),
]


func _initialize() -> void:
	var passed := true
	for path: String in INPUTS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			print("SCENE7_SKY_FAR_REFERENCE: FAIL path=", path)
			passed = false
			continue
		print(
			"SCENE7_SKY_FAR_IMAGE: path=", path,
			" size=", image.get_width(), "x", image.get_height(),
			" alpha_used=", image.get_used_rect())
		for band: Vector2 in BANDS:
			_print_band(image, path, band)
	quit(0 if passed else 1)


func _print_band(image: Image, path: String, band: Vector2) -> void:
	var x0 := floori(float(image.get_width()) * 0.08)
	var x1 := ceili(float(image.get_width()) * 0.92)
	var y0 := floori(float(image.get_height()) * band.x)
	var y1 := ceili(float(image.get_height()) * band.y)
	var step_size := maxi(1, mini(image.get_width(), image.get_height()) / 240)
	var rgb_sum := Vector3.ZERO
	var luma_sum := 0.0
	var saturation_sum := 0.0
	var cyan_green_count := 0
	var warm_count := 0
	var edge_count := 0
	var isolated_count := 0
	var count := 0
	for y: int in range(y0, y1, step_size):
		for x: int in range(x0, x1, step_size):
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			var rgb := Vector3(color.r, color.g, color.b)
			var luma := _luma(color)
			var maximum := maxf(color.r, maxf(color.g, color.b))
			var minimum := minf(color.r, minf(color.g, color.b))
			var saturation := (maximum - minimum) / maxf(maximum, 0.001)
			rgb_sum += rgb
			luma_sum += luma
			saturation_sum += saturation
			cyan_green_count += 1 if (
				color.g >= color.r * 1.12 and color.b >= color.r * 1.08) else 0
			warm_count += 1 if (
				color.r >= color.b * 1.16 and color.g >= color.b * 0.82) else 0
			var right := image.get_pixel(mini(x + step_size, x1 - 1), y)
			var down := image.get_pixel(x, mini(y + step_size, y1 - 1))
			var edge := maxf(_delta(color, right), _delta(color, down))
			edge_count += 1 if edge >= 0.10 else 0
			if x > x0 and x < x1 - 1 and y > y0 and y < y1 - 1:
				var mean := (
					image.get_pixel(x - 1, y)
					+ image.get_pixel(x + 1, y)
					+ image.get_pixel(x, y - 1)
					+ image.get_pixel(x, y + 1)) * 0.25
				var spread := maxf(
					_delta(image.get_pixel(x - 1, y), mean),
					maxf(
						_delta(image.get_pixel(x + 1, y), mean),
						maxf(
							_delta(image.get_pixel(x, y - 1), mean),
							_delta(image.get_pixel(x, y + 1), mean))))
				isolated_count += 1 if (
					_delta(color, mean) >= 0.16 and spread <= 0.10) else 0
			count += 1
	var mean_rgb := rgb_sum / maxf(float(count), 1.0)
	print(
		"SCENE7_SKY_FAR_BAND: image=", path.get_file(),
		" y=", snappedf(band.x, 0.01), "-", snappedf(band.y, 0.01),
		" mean_rgb=", Color(mean_rgb.x, mean_rgb.y, mean_rgb.z),
		" luma=", snappedf(luma_sum / maxf(float(count), 1.0), 0.001),
		" saturation=", snappedf(
			saturation_sum / maxf(float(count), 1.0), 0.001),
		" cyan_green_fraction=", snappedf(
			float(cyan_green_count) / maxf(float(count), 1.0), 0.001),
		" warm_fraction=", snappedf(
			float(warm_count) / maxf(float(count), 1.0), 0.001),
		" edge_fraction=", snappedf(
			float(edge_count) / maxf(float(count), 1.0), 0.0001),
		" isolated_fraction=", snappedf(
			float(isolated_count) / maxf(float(count), 1.0), 0.0001))


func _luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


func _delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
