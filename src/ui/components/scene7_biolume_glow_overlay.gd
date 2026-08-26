class_name Scene7BiolumeGlowOverlay
extends MeshInstance2D

## Scene7-only additive bioluminescence pass.
##
## It scans the source art once, converts complete small cyan components into
## independently phased point lights, and builds a separate explicit mask for
## authored cluster zones. The static source material remains untouched by the
## animation, so neither effect can wash the whole midground layer.

const GLOW_SHADER := preload(
		"res://assets/shaders/canvas_env_scene7_biolume_glow_fx.gdshader")
const CLUSTER_RELIGHT_SHADER := preload(
		"res://assets/shaders/canvas_env_scene7_biolume_cluster_relight.gdshader")
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

@export var source_layer_path: NodePath
@export var glow_color: Color = Color(0.28, 0.92, 0.75, 1.0)
@export var include_point_components: bool = true
@export var collective_relight: bool = false
@export_range(3, 16, 1) var maximum_point_components: int = 9
@export_range(1, 8, 1) var minimum_point_area: int = 1
@export_range(4, 96, 1) var maximum_point_area: int = 36
@export_range(0.4, 0.9, 0.01) var point_value_threshold: float = 0.62
@export_range(0.02, 0.3, 0.01) var point_cyan_threshold: float = 0.10
@export_range(0.02, 0.3, 0.01) var minimum_point_spacing: float = 0.055
## Authored plant clumps that must never be split into point flashes.
@export var point_exclusion_zones: Array[Vector4] = []
## Normalized ellipses: center_x, center_y, radius_x, radius_y.
@export var cluster_zones: Array[Vector4] = []
## Normalized seed positions for complete connected luminous plant components.
## Use this when an irregular grass silhouette must be selected exactly instead
## of approximated by an ellipse.
@export var cluster_component_seeds: Array[Vector2] = []
@export_range(0.3, 0.8, 0.01) var cluster_value_threshold: float = 0.46
@export_range(0.01, 0.2, 0.01) var cluster_cyan_threshold: float = 0.055
@export_range(2.5, 8.0, 0.1) var point_cycle_sec: float = 4.8
@export_range(0.0, 1.0, 0.01) var point_time_phase: float = 0.0
@export_range(0.0, 0.4, 0.01) var point_core_base: float = 0.06
@export_range(0.0, 0.8, 0.01) var point_core_peak: float = 0.24
@export_range(0.0, 0.2, 0.005) var point_halo_base: float = 0.015
@export_range(0.0, 0.5, 0.01) var point_halo_peak: float = 0.12
@export_range(3.0, 10.0, 0.1) var cluster_cycle_sec: float = 6.2
@export_range(0.0, 1.0, 0.01) var cluster_time_phase: float = 0.0
@export_range(0.0, 0.4, 0.01) var cluster_core_base: float = 0.05
@export_range(0.0, 0.6, 0.01) var cluster_core_peak: float = 0.10
@export_range(0.0, 0.2, 0.005) var cluster_halo_base: float = 0.015
@export_range(0.0, 0.4, 0.01) var cluster_halo_peak: float = 0.06
@export_range(0.4, 1.0, 0.01) var relight_trough_brightness: float = 0.72
@export_range(1.0, 1.5, 0.01) var relight_peak_brightness: float = 1.16
@export_range(0.0, 0.5, 0.01) var relight_peak_tint_mix: float = 0.18
@export_range(0.0, 0.2, 0.005) var relight_halo_base: float = 0.018
@export_range(0.0, 0.3, 0.005) var relight_halo_peak: float = 0.085

var _source_layer: TextureRect


func _ready() -> void:
	_source_layer = get_node_or_null(source_layer_path) as TextureRect
	if _source_layer == null or _source_layer.texture == null:
		push_error("Scene7 biolume overlay needs a textured source layer")
		visible = false
		return
	var source_image := _source_layer.texture.get_image()
	if source_image == null or source_image.is_empty():
		push_error("Scene7 biolume overlay could not read source pixels")
		visible = false
		return
	_copy_source_presentation()
	var masks := _build_masks(source_image)
	_apply_material(masks[0], masks[1])


func _copy_source_presentation() -> void:
	position = _source_layer.position
	scale = _source_layer.scale
	rotation = _source_layer.rotation
	texture = _source_layer.texture
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var authored_size := _source_layer.size
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2.ZERO,
		Vector2(authored_size.x, 0.0),
		Vector2(0.0, authored_size.y),
		authored_size,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2.ZERO,
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2.ONE,
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
	var quad_mesh := ArrayMesh.new()
	quad_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = quad_mesh
	set_meta("authored_size", authored_size)


func _build_masks(source_image: Image) -> Array[ImageTexture]:
	var point_mask := Image.create(
			source_image.get_width(), source_image.get_height(),
			false, Image.FORMAT_RGBA8)
	var cluster_mask := Image.create(
			source_image.get_width(), source_image.get_height(),
			false, Image.FORMAT_RGBA8)
	# Color.TRANSPARENT is white with zero alpha in Godot.  The shader stores
	# semantic data in RGB, so masks must start as explicit transparent black.
	point_mask.fill(Color(0.0, 0.0, 0.0, 0.0))
	cluster_mask.fill(Color(0.0, 0.0, 0.0, 0.0))

	var selected_components: Array[Dictionary] = []
	if include_point_components:
		var point_components := _find_point_components(source_image)
		selected_components = _select_spaced_components(
				point_components, source_image.get_size())
	for component_index: int in range(selected_components.size()):
		var component: Dictionary = selected_components[component_index]
		var phase := fposmod(
				float(component_index) * 0.61803398875
				+ point_time_phase * 0.37, 1.0)
		_write_component_with_halo(
				point_mask, component["pixels"], phase)

	var cluster_core := _collect_cluster_core(source_image)
	_write_cluster_with_halo(cluster_mask, cluster_core)

	set_meta("point_component_count", selected_components.size())
	set_meta("point_core_pixel_count", _count_channel_pixels(point_mask, 0))
	set_meta("point_halo_pixel_count", _count_channel_pixels(point_mask, 1))
	set_meta("cluster_core_pixel_count", _count_channel_pixels(cluster_mask, 0))
	set_meta("cluster_halo_pixel_count", _count_channel_pixels(cluster_mask, 1))
	set_meta("cluster_core_source_bounds", _pixel_bounds(cluster_core))
	return [
		ImageTexture.create_from_image(point_mask),
		ImageTexture.create_from_image(cluster_mask),
	]


func _find_point_components(source_image: Image) -> Array[Dictionary]:
	var width := source_image.get_width()
	var height := source_image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var components: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var start_index := y * width + x
			if visited[start_index] != 0:
				continue
			visited[start_index] = 1
			var start := Vector2i(x, y)
			if not _is_point_pixel(source_image.get_pixelv(start)) \
					or _inside_point_exclusion(start, source_image.get_size()):
				continue
			var queue: Array[Vector2i] = [start]
			var head := 0
			var pixels: Array[Vector2i] = []
			var value_total := 0.0
			var position_total := Vector2.ZERO
			while head < queue.size():
				var pixel := queue[head]
				head += 1
				pixels.append(pixel)
				var color := source_image.get_pixelv(pixel)
				value_total += maxf(color.g, color.b)
				position_total += Vector2(pixel)
				for offset: Vector2i in NEIGHBORS_8:
					var neighbor := pixel + offset
					if neighbor.x < 0 or neighbor.y < 0 \
							or neighbor.x >= width or neighbor.y >= height:
						continue
					var neighbor_index := neighbor.y * width + neighbor.x
					if visited[neighbor_index] != 0:
						continue
					visited[neighbor_index] = 1
					if _is_point_pixel(source_image.get_pixelv(neighbor)) \
							and not _inside_point_exclusion(
									neighbor, source_image.get_size()):
						queue.append(neighbor)
			if pixels.size() < minimum_point_area \
					or pixels.size() > maximum_point_area:
				continue
			components.append({
				"pixels": pixels,
				"centroid": position_total / float(pixels.size()),
				"score": value_total / float(pixels.size())
						+ minf(float(pixels.size()), 8.0) * 0.015,
			})
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	return components


func _select_spaced_components(
		components: Array[Dictionary], image_size: Vector2i) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for candidate: Dictionary in components:
		var candidate_uv: Vector2 = candidate["centroid"] / Vector2(image_size)
		var spaced := true
		for existing: Dictionary in selected:
			var existing_uv: Vector2 = existing["centroid"] / Vector2(image_size)
			if candidate_uv.distance_to(existing_uv) < minimum_point_spacing:
				spaced = false
				break
		if not spaced:
			continue
		selected.append(candidate)
		if selected.size() >= maximum_point_components:
			break
	return selected


func _collect_cluster_core(source_image: Image) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	if cluster_zones.is_empty() and cluster_component_seeds.is_empty():
		return pixels
	var image_size := source_image.get_size()
	var selected := PackedByteArray()
	selected.resize(image_size.x * image_size.y)
	if not cluster_zones.is_empty():
		for y: int in range(image_size.y):
			for x: int in range(image_size.x):
				var pixel := Vector2i(x, y)
				if _inside_cluster_zone(pixel, image_size) \
						and _is_cluster_pixel(source_image.get_pixelv(pixel)):
					selected[y * image_size.x + x] = 1
					pixels.append(pixel)

	var component_visited := PackedByteArray()
	component_visited.resize(image_size.x * image_size.y)
	for seed_uv: Vector2 in cluster_component_seeds:
		var seed := _nearest_cluster_pixel(source_image, seed_uv, 8)
		if seed.x < 0:
			continue
		var seed_index := seed.y * image_size.x + seed.x
		if component_visited[seed_index] != 0:
			continue
		component_visited[seed_index] = 1
		var queue: Array[Vector2i] = [seed]
		var head := 0
		while head < queue.size():
			var pixel := queue[head]
			head += 1
			var pixel_index := pixel.y * image_size.x + pixel.x
			if selected[pixel_index] == 0:
				selected[pixel_index] = 1
				pixels.append(pixel)
			for offset: Vector2i in NEIGHBORS_8:
				var neighbor := pixel + offset
				if not _inside_image(neighbor, image_size):
					continue
				var neighbor_index := neighbor.y * image_size.x + neighbor.x
				if component_visited[neighbor_index] != 0:
					continue
				component_visited[neighbor_index] = 1
				if _is_cluster_pixel(source_image.get_pixelv(neighbor)):
					queue.append(neighbor)
	return pixels


func _nearest_cluster_pixel(
		source_image: Image, seed_uv: Vector2, search_radius: int) -> Vector2i:
	var image_size := source_image.get_size()
	var seed := Vector2i(
			clampi(int(floor(seed_uv.x * float(image_size.x))), 0, image_size.x - 1),
			clampi(int(floor(seed_uv.y * float(image_size.y))), 0, image_size.y - 1))
	var nearest := Vector2i(-1, -1)
	var nearest_distance_squared := INF
	for y: int in range(
			maxi(0, seed.y - search_radius),
			mini(image_size.y, seed.y + search_radius + 1)):
		for x: int in range(
				maxi(0, seed.x - search_radius),
				mini(image_size.x, seed.x + search_radius + 1)):
			var candidate := Vector2i(x, y)
			if not _is_cluster_pixel(source_image.get_pixelv(candidate)):
				continue
			var distance_squared := Vector2(candidate - seed).length_squared()
			if distance_squared < nearest_distance_squared:
				nearest = candidate
				nearest_distance_squared = distance_squared
	return nearest


func _write_component_with_halo(
		mask: Image, pixels: Array[Vector2i], phase: float) -> void:
	for pixel: Vector2i in pixels:
		mask.set_pixelv(pixel, Color(1.0, 0.0, phase, 1.0))
	for pixel: Vector2i in pixels:
		for offset: Vector2i in NEIGHBORS_8:
			var neighbor := pixel + offset
			if not _inside_image(neighbor, mask.get_size()):
				continue
			var current := mask.get_pixelv(neighbor)
			if current.r >= 0.5:
				continue
			mask.set_pixelv(neighbor, Color(0.0, 1.0, phase, 1.0))


func _write_cluster_with_halo(mask: Image, pixels: Array[Vector2i]) -> void:
	for pixel: Vector2i in pixels:
		mask.set_pixelv(pixel, Color(1.0, 0.0, 0.0, 1.0))
	for pixel: Vector2i in pixels:
		for offset: Vector2i in NEIGHBORS_8:
			var neighbor := pixel + offset
			if not _inside_image(neighbor, mask.get_size()):
				continue
			var current := mask.get_pixelv(neighbor)
			if current.r < 0.5:
				mask.set_pixelv(neighbor, Color(0.0, 1.0, 0.0, 1.0))


func _apply_material(point_texture: ImageTexture, cluster_texture: ImageTexture) -> void:
	var glow_material := ShaderMaterial.new()
	glow_material.resource_local_to_scene = true
	glow_material.shader = CLUSTER_RELIGHT_SHADER if collective_relight else GLOW_SHADER
	glow_material.set_shader_parameter("cluster_mask", cluster_texture)
	glow_material.set_shader_parameter("glow_color", glow_color)
	glow_material.set_shader_parameter("cluster_cycle_sec", cluster_cycle_sec)
	glow_material.set_shader_parameter("cluster_time_phase", cluster_time_phase)
	if collective_relight:
		glow_material.set_shader_parameter(
				"trough_brightness", relight_trough_brightness)
		glow_material.set_shader_parameter("peak_brightness", relight_peak_brightness)
		glow_material.set_shader_parameter("peak_tint_mix", relight_peak_tint_mix)
		glow_material.set_shader_parameter("halo_base", relight_halo_base)
		glow_material.set_shader_parameter("halo_peak", relight_halo_peak)
	else:
		glow_material.set_shader_parameter("point_mask", point_texture)
		glow_material.set_shader_parameter("point_cycle_sec", point_cycle_sec)
		glow_material.set_shader_parameter("point_time_phase", point_time_phase)
		glow_material.set_shader_parameter("point_core_base", point_core_base)
		glow_material.set_shader_parameter("point_core_peak", point_core_peak)
		glow_material.set_shader_parameter("point_halo_base", point_halo_base)
		glow_material.set_shader_parameter("point_halo_peak", point_halo_peak)
		glow_material.set_shader_parameter("cluster_core_base", cluster_core_base)
		glow_material.set_shader_parameter("cluster_core_peak", cluster_core_peak)
		glow_material.set_shader_parameter("cluster_halo_base", cluster_halo_base)
		glow_material.set_shader_parameter("cluster_halo_peak", cluster_halo_peak)
	material = glow_material


func _is_point_pixel(color: Color) -> bool:
	var cool_value := maxf(color.g, color.b)
	var cyan_signal := minf(color.g, color.b) - color.r * 0.62
	return color.a > 0.08 \
			and cool_value >= point_value_threshold \
			and cyan_signal >= point_cyan_threshold


func _is_cluster_pixel(color: Color) -> bool:
	var cool_value := maxf(color.g, color.b)
	var cyan_signal := minf(color.g, color.b) - color.r * 0.62
	return color.a > 0.08 \
			and cool_value >= cluster_value_threshold \
			and cyan_signal >= cluster_cyan_threshold


func _inside_cluster_zone(pixel: Vector2i, image_size: Vector2i) -> bool:
	return _inside_any_zone(pixel, image_size, cluster_zones)


func _inside_point_exclusion(pixel: Vector2i, image_size: Vector2i) -> bool:
	return _inside_any_zone(pixel, image_size, cluster_zones) \
			or _inside_any_zone(pixel, image_size, point_exclusion_zones)


func _inside_any_zone(
		pixel: Vector2i, image_size: Vector2i, zones: Array[Vector4]) -> bool:
	var uv := (Vector2(pixel) + Vector2(0.5, 0.5)) / Vector2(image_size)
	for zone: Vector4 in zones:
		var normalized := Vector2(
				(uv.x - zone.x) / maxf(zone.z, 0.001),
				(uv.y - zone.y) / maxf(zone.w, 0.001))
		if normalized.length_squared() <= 1.0:
			return true
	return false


func _inside_image(pixel: Vector2i, image_size: Vector2i) -> bool:
	return pixel.x >= 0 and pixel.y >= 0 \
			and pixel.x < image_size.x and pixel.y < image_size.y


func _count_channel_pixels(image: Image, channel: int) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var value := color.r if channel == 0 else color.g
			if value >= 0.5:
				count += 1
	return count


func _pixel_bounds(pixels: Array[Vector2i]) -> Rect2i:
	if pixels.is_empty():
		return Rect2i()
	var minimum := pixels[0]
	var maximum := pixels[0]
	for pixel: Vector2i in pixels:
		minimum.x = mini(minimum.x, pixel.x)
		minimum.y = mini(minimum.y, pixel.y)
		maximum.x = maxi(maximum.x, pixel.x)
		maximum.y = maxi(maximum.y, pixel.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
