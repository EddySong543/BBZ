extends GutTest

const CHARACTER_SCENE_PATH := (
	"res://src/ui/components/boot_character_idle.tscn")
const BOOT_SCREEN_PATH := "res://src/ui/boot_screen.tscn"
const SHADOW_SHADER_PATH := (
	"res://assets/shaders/canvas_boot_character_shadow.gdshader")


func test_boot_character_keeps_only_the_base_offset_pixel_shadow() -> void:
	var packed := load(CHARACTER_SCENE_PATH) as PackedScene
	var character := packed.instantiate()
	add_child_autofree(character)
	await get_tree().process_frame

	var base := character.get_node("Rig/Base") as Sprite2D
	var shadow := base.get_node("Shadow") as Sprite2D
	assert_not_null(shadow)
	assert_eq(shadow.texture, base.texture)
	assert_eq(shadow.position, Vector2(2.1, 3.2))
	assert_eq(shadow.z_index, 0)
	assert_true(shadow.show_behind_parent)
	assert_false(shadow.centered)
	var material := shadow.material as ShaderMaterial
	assert_not_null(material)
	assert_eq(material.shader.resource_path, SHADOW_SHADER_PATH)
	var shadow_color: Color = material.get_shader_parameter(
			&"shadow_color")
	assert_true(
		shadow_color.is_equal_approx(
			Color(0.0313725, 0.0392157, 0.0509804, 0.82)))

	var shadowless_part_paths: Array[NodePath] = [
		^"Rig/WaistScreenRightPivot/WaistScreenRight",
		^"Rig/WaistScreenLeftPivot/WaistScreenLeft",
		^"Rig/FurRightTips",
		^"Rig/HairLeftTips",
		^"Rig/HairRightTips",
		^"Rig/HairFrontTips",
	]
	for part_path: NodePath in shadowless_part_paths:
		var part := character.get_node(part_path) as Sprite2D
		assert_null(part.get_node_or_null("Shadow"))


func test_boot_screen_draws_character_shadows_after_the_background() -> void:
	var packed := load(BOOT_SCREEN_PATH) as PackedScene
	var boot := packed.instantiate() as Control
	add_child_autofree(boot)
	await get_tree().process_frame

	var background_stage := boot.get_node("BackgroundStage") as Control
	var character := boot.get_node("Character") as Control
	var base_shadow := character.get_node("Rig/Base/Shadow") as Sprite2D
	assert_lt(background_stage.get_index(), character.get_index())
	assert_eq(base_shadow.z_index, 0)
	assert_true(base_shadow.show_behind_parent)


func test_boot_character_energy_is_not_duplicated_into_shadow() -> void:
	var packed := load(CHARACTER_SCENE_PATH) as PackedScene
	var character := packed.instantiate()
	add_child_autofree(character)
	await get_tree().process_frame

	assert_null(
		character.get_node_or_null(
			"Rig/RearHandEnergyAnchor/RearHandGlow/Shadow"))
	assert_null(
		character.get_node_or_null(
			"Rig/RearHandEnergyAnchor/RearHandStar/Shadow"))


func test_boot_character_base_uses_selective_foreground_hand_depth() -> void:
	var packed := load(CHARACTER_SCENE_PATH) as PackedScene
	var character := packed.instantiate()
	add_child_autofree(character)
	await get_tree().process_frame

	var base := character.get_node("Rig/Base") as Sprite2D
	var material := base.material as ShaderMaterial
	assert_not_null(material)
	assert_eq(
		material.shader.resource_path,
		"res://assets/shaders/canvas_boot_character_depth.gdshader")
	assert_eq(
		material.get_shader_parameter(&"hand_center"),
		Vector2(0.82, 0.32))
	assert_eq(
		material.get_shader_parameter(&"hand_radius"),
		Vector2(0.27, 0.34))
	assert_almost_eq(
		float(material.get_shader_parameter(&"blur_texels")),
		1.0,
		0.001)
	assert_almost_eq(
		float(material.get_shader_parameter(&"blur_mix")),
		0.58,
		0.001)
	assert_almost_eq(
		float(material.get_shader_parameter(&"desaturation")),
		0.06,
		0.001)
