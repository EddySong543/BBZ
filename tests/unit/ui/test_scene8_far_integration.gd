extends GutTest

const SCENE8_PATH := "res://src/ui/scenes/scene8.tscn"
const TOPOLOGY_SCRIPT_PATH := (
		"res://src/ui/components/scene8_lake_topology.gd")
const OPEN_LAKE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_open_lake.gdshader")
const FAR_DEPTH_GRADE_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene8_far_depth_grade.gdshader")


func test_glacier_contact_is_encoded_without_replacing_the_authored_shore() -> void:
	var topology_source := FileAccess.get_file_as_string(TOPOLOGY_SCRIPT_PATH)
	assert_true(topology_source.contains("@export var glacier_path"))
	assert_true(topology_source.contains("glacier_contact_cells"))
	assert_true(topology_source.contains("glacier_contact"))
	if not topology_source.contains("@export var glacier_path"):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var topology := stage.get_node("LakeTopology")
	assert_eq(topology.get("glacier_path"), NodePath("../FarGlacier"))
	assert_between(int(topology.get("glacier_contact_cells")), 3, 5)
	assert_true(bool(topology.call("rebuild")))
	var image := topology.call("get_topology_image") as Image
	assert_not_null(image)
	if image == null:
		return

	var contact_cells := 0
	var open_water_cells := 0
	var contact_columns: Dictionary[int, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var topology_pixel := image.get_pixel(x, y)
			if topology_pixel.r < 0.5:
				continue
			if topology_pixel.a >= 0.05:
				contact_cells += 1
				contact_columns[x] = true
			else:
				open_water_cells += 1
	assert_between(contact_cells, 160, 2400,
			"Glacier contact must stay a thin measured field")
	assert_gte(contact_columns.size(), 260,
			"The authored glacier edge spans most of the far lake")
	assert_gt(open_water_cells, contact_cells * 5,
			"Glacier contact must not replace the open lake topology")

	var lake_source := FileAccess.get_file_as_string(OPEN_LAKE_SHADER_PATH)
	assert_true(lake_source.contains("topology.a"))
	assert_true(lake_source.contains("glacier_contact_mask"))
	assert_true(lake_source.contains("glacier_contact_shadow_color"))
	assert_true(lake_source.contains("glacier_contact_glint_color"))
	assert_true(lake_source.contains("shore_ice_glacier_mix"))


func test_far_mountains_use_an_opaque_inner_silhouette_palette_bridge() -> void:
	var source := FileAccess.get_file_as_string(FAR_DEPTH_GRADE_SHADER_PATH)
	assert_true(source.contains("silhouette_air"))
	assert_true(source.contains("TEXTURE_PIXEL_SIZE"))
	assert_true(source.contains("source_uv - vec2(0.0"),
			"Only source pixels above the current pixel should define the top edge")
	assert_true(source.contains("edge_sky_mix"))
	assert_true(source.contains("edge_aurora_mix"))
	assert_true(source.contains("COLOR = vec4(color, source.a)"),
			"The palette bridge must never lower authored opacity")
	assert_false(source.contains("uniform float opacity"))
	if not source.contains("uniform float edge_sky_mix"):
		return

	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	for node_name: String in [
		"FarMountainLeft", "FarMountainRight", "FarSnowfield", "FarGlacier",
	]:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		assert_between(float(material.get_shader_parameter("edge_sky_mix")),
				0.08, 0.24)
		assert_between(float(material.get_shader_parameter("edge_aurora_mix")),
				0.01, 0.10)
		assert_eq(layer.modulate.a, 1.0)
		var image := layer.texture.get_image()
		var opaque_pixels := 0
		var silhouette_air_pixels := 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var source_alpha := image.get_pixel(x, y).a
				if source_alpha < 0.03:
					continue
				opaque_pixels += 1
				var alpha_up_1 := image.get_pixel(x, y - 1).a if y >= 1 else 0.0
				var alpha_up_2 := image.get_pixel(x, y - 2).a if y >= 2 else 0.0
				var alpha_up_3 := image.get_pixel(x, y - 3).a if y >= 3 else 0.0
				var silhouette_air := source_alpha * maxf(
						1.0 - alpha_up_1,
						maxf((1.0 - alpha_up_2) * 0.64,
								(1.0 - alpha_up_3) * 0.34))
				silhouette_air_pixels += int(silhouette_air >= 0.08)
		var edge_ratio := float(silhouette_air_pixels) / maxf(
				float(opaque_pixels), 1.0)
		assert_between(edge_ratio, 0.02, 0.42,
				"%s needs a restrained but non-empty inner sky edge" % node_name)


func test_far_layers_recede_by_luminance_without_losing_color_or_opacity() -> void:
	var stage := (load(SCENE8_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	var brightness_by_name: Dictionary[String, float] = {}
	var expected_brightness: Dictionary[String, float] = {
		"FarMountainLeft": 0.70,
		"FarMountainRight": 0.70,
		"FarSnowfield": 0.68,
		"FarGlacier": 0.90,
	}
	for node_name: String in [
		"FarMountainLeft", "FarMountainRight", "FarSnowfield", "FarGlacier",
	]:
		var layer := stage.get_node(node_name) as TextureRect
		var material := layer.material as ShaderMaterial
		var brightness := float(material.get_shader_parameter("brightness"))
		brightness_by_name[node_name] = brightness
		assert_almost_eq(brightness, expected_brightness[node_name], 0.001,
				"Preserve Eddy's current restrained far-layer hierarchy")
		assert_lte(float(material.get_shader_parameter("visibility_lift")), 0.015,
				"Atmospheric lift must not make the far silhouette eye-catching")
		assert_gte(float(material.get_shader_parameter("saturation_retention")), 0.93,
				"Receding the background must not turn it grey")
		assert_eq(layer.modulate.a, 1.0,
				"Depth must not be faked by lowering authored opacity")
	assert_lt(brightness_by_name["FarSnowfield"],
			brightness_by_name["FarMountainLeft"])
	assert_eq(brightness_by_name["FarMountainLeft"],
			brightness_by_name["FarMountainRight"])
