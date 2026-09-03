extends GutTest

const SCENE9_PATH := "res://src/ui/scenes/scene9.tscn"
const RETIRED_RESOURCE_PATHS: Array[String] = [
	"res://src/ui/components/scene9_skyfaring_whale.gd",
	"res://assets/shaders/canvas_env_scene9_skyfaring_whale.gdshader",
	"res://assets/scenes/scene9/scene9_silver_sky_whale.png",
	"res://tools/scene9_whale_motion_probe.gd",
	"res://src/ui/components/scene9_eye_socket_glow.gd",
]


func test_scene9_old_whale_chain_is_fully_retired() -> void:
	var stage := (load(SCENE9_PATH) as PackedScene).instantiate() as BattleStage
	add_child_autofree(stage)
	assert_null(stage.get_node_or_null("SilverSkyWhale"))
	for resource_path: String in RETIRED_RESOURCE_PATHS:
		assert_false(ResourceLoader.exists(resource_path), resource_path)
	var scene_source := FileAccess.get_file_as_string(SCENE9_PATH).to_lower()
	var stage_source := FileAccess.get_file_as_string(
			"res://src/ui/components/scene9_battle_stage.gd").to_lower()
	assert_false(scene_source.contains("whale"))
	assert_false(stage_source.contains("whale"))
	assert_false(stage_source.contains("cloud_sequence"))
	assert_false(scene_source.contains("eyesocketglow"))
	assert_false(stage_source.contains("eye_socket_glow"))
