extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const GRASS_WIND_SHADER_PATH := (
		"res://assets/shaders/canvas_env_scene9_distant_grass_interlock.gdshader")
const TARGET_SOURCE_RECT := Vector4(0.0, 0.0, 109.0, 80.0)


func test_distant_left_trim_removes_only_the_annotated_source_pixels() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	stage.idle_drift = false
	stage.pointer_parallax = false

	var left := stage.get_node("DistantLeft") as Control
	var left2 := stage.get_node("DistantLeft2") as Control
	var right := stage.get_node("DistantRight") as Control
	var right2 := stage.get_node("DistantRight2") as Control
	var left_material := left.material as ShaderMaterial
	var left2_material := left2.material as ShaderMaterial
	var right_material := right.material as ShaderMaterial
	var right2_material := right2.material as ShaderMaterial

	assert_not_null(left_material)
	assert_not_same(left_material, left2_material,
			"Each copy keeps its own world-space contact rectangle")
	assert_same(right_material, right2_material)
	assert_not_same(left_material, right_material,
			"The left-only trim must not alter either right grass node")
	assert_eq(left_material.get_shader_parameter(&"source_trim_enabled"), true)
	assert_eq(left_material.get_shader_parameter(&"source_trim_rect_px"),
			TARGET_SOURCE_RECT)
	assert_eq(left2_material.get_shader_parameter(&"source_trim_enabled"), true)
	assert_eq(left2_material.get_shader_parameter(&"source_trim_rect_px"),
			TARGET_SOURCE_RECT)
	assert_eq(right_material.get_shader_parameter(&"source_trim_enabled"), false)

	var source := FileAccess.get_file_as_string(GRASS_WIND_SHADER_PATH)
	assert_true(source.contains("floor(UV / TEXTURE_PIXEL_SIZE)"),
			"The cut must stay locked to integer source pixels after mesh motion")
	assert_true(source.contains("source_trim_rect_px.x + source_trim_rect_px.z"))
	assert_true(source.contains("visibility *= 1.0 - inside_x * inside_y"))

	var image := (left2.get("texture") as Texture2D).get_image()
	assert_not_null(image)
	var removed_opaque_pixels := 0
	for y in range(80):
		for x in range(109):
			if image.get_pixel(x, y).a > 0.0:
				removed_opaque_pixels += 1
	assert_eq(removed_opaque_pixels, 983,
			"The mask must match the red-circled raised cap, not a broad rectangle")
