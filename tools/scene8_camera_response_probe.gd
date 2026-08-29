extends SceneTree

const SCENE8: PackedScene = preload("res://src/ui/scenes/scene8.tscn")


func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	call_deferred(&"_run")


func _run() -> void:
	var stage := SCENE8.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	stage.set_process(false)
	stage.pointer_parallax = false
	stage.idle_drift = false

	var pointer_contract := _pointer_contract(stage)
	var dolly_contract := _dolly_contract(stage)
	var legacy_contract := _legacy_scene_contract()
	var passed := (
			bool(pointer_contract.passed)
			and bool(dolly_contract.passed)
			and bool(legacy_contract.passed))
	print(
			"SCENE8_CAMERA_RESPONSE: ", "PASS" if passed else "FAIL",
			" dolly=", dolly_contract,
			" pointer=", pointer_contract,
			" legacy=", legacy_contract)
	stage.free()
	quit(0 if passed else 1)


func _dolly_contract(stage: BattleStage) -> Dictionary:
	var unified_layers: Array[String] = [
		"MirrorLake", "AuroraReflection", "FarMountainLeft",
		"FarSnowfield2", "FarMountainRight", "FarSnowfield",
		"FarGlacier", "SnowMotesFar", "PlatformWaterContact",
		"BattlePlatform", "SnowMotesNear", "ForegroundSnowfield",
		"ForegroundLeft", "ForegroundRight",
	]
	var cached_layers := stage.get("_layers") as Array
	var cached_dolly := stage.get("_dolly_factors") as PackedFloat32Array
	var runtime_factors := {}
	for index: int in cached_layers.size():
		var layer := cached_layers[index] as CanvasItem
		runtime_factors[String(layer.name)] = float(cached_dolly[index])
	var unified := true
	for node_name: String in unified_layers:
		unified = unified \
				and runtime_factors.has(node_name) \
				and is_equal_approx(float(runtime_factors[node_name]), 1.0)
	var static_sky := true
	for node_name: String in ["Sky", "Stars", "PixelAurora"]:
		static_sky = static_sky \
				and runtime_factors.has(node_name) \
				and is_zero_approx(float(runtime_factors[node_name]))

	var lake := stage.get_node("MirrorLake") as Control
	var platform := stage.get_node("BattlePlatform") as Control
	var sky := stage.get_node("Sky") as Control
	var lake_base_scale: Vector2 = lake.scale
	var platform_base_scale: Vector2 = platform.scale
	var sky_base_scale: Vector2 = sky.scale
	stage.set_focus(true)
	stage.set_punch(1.0)
	stage.call("_process", 2.0)
	var lake_ratio: float = lake.scale.x / lake_base_scale.x
	var platform_ratio: float = platform.scale.x / platform_base_scale.x
	var sky_ratio: float = sky.scale.x / sky_base_scale.x
	return {
		"passed": (
				unified and static_sky
				and absf(lake_ratio - platform_ratio) <= 0.0001
				and lake_ratio >= 1.064 and lake_ratio <= 1.066
				and is_equal_approx(sky_ratio, 1.0)),
		"unified_world": unified,
		"static_sky": static_sky,
		"lake_scale_ratio": snappedf(lake_ratio, 0.0001),
		"platform_scale_ratio": snappedf(platform_ratio, 0.0001),
		"sky_scale_ratio": snappedf(sky_ratio, 0.0001),
	}


func _pointer_contract(stage: BattleStage) -> Dictionary:
	var expected := {
		"Sky": 0.0,
		"Stars": 0.0,
		"PixelAurora": 0.0,
		"FarGlacier": 0.06,
		"SnowMotesFar": 0.08,
		"FarMountainLeft": 0.08,
		"FarMountainRight": 0.08,
		"FarSnowfield": 0.10,
		"FarSnowfield2": 0.10,
		"MirrorLake": 1.0,
		"AuroraReflection": 1.0,
		"PlatformWaterContact": 1.0,
		"BattlePlatform": 1.0,
		"SnowMotesNear": 1.04,
		"ForegroundSnowfield": 1.08,
		"ForegroundLeft": 1.08,
		"ForegroundRight": 1.08,
	}
	var cached_layers := stage.get("_layers") as Array
	var cached_pointer := stage.get("_pointer_factors") as PackedFloat32Array
	var runtime := {}
	for index: int in cached_layers.size():
		var layer := cached_layers[index] as CanvasItem
		runtime[String(layer.name)] = float(cached_pointer[index])
	var unchanged := true
	for node_name: String in expected:
		unchanged = unchanged \
				and runtime.has(node_name) \
				and is_equal_approx(
						float(runtime[node_name]), float(expected[node_name]))
	return {
		"passed": (
				unchanged and is_equal_approx(stage.pointer_strength, 2.0)
				and is_equal_approx(stage.pointer_smooth, 6.0)
				and is_zero_approx(stage.pointer_zoom)),
		"unchanged": unchanged,
		"strength": stage.pointer_strength,
		"smooth": stage.pointer_smooth,
		"zoom": stage.pointer_zoom,
	}


func _legacy_scene_contract() -> Dictionary:
	var scene_results := {}
	var all_unchanged := true
	for scene_id: int in range(1, 8):
		var scene_path := "res://src/ui/scenes/scene%d.tscn" % scene_id
		var legacy_stage := (
				load(scene_path) as PackedScene).instantiate() as BattleStage
		root.add_child(legacy_stage)
		legacy_stage.set_process(false)
		var factors := legacy_stage.get("_factors") as PackedFloat32Array
		var dolly := legacy_stage.get("_dolly_factors") as PackedFloat32Array
		var unchanged := factors.size() == dolly.size()
		for index: int in factors.size():
			unchanged = unchanged \
					and is_equal_approx(factors[index], dolly[index])
		scene_results["scene%d" % scene_id] = unchanged
		all_unchanged = all_unchanged and unchanged
		legacy_stage.free()
	return {"passed": all_unchanged, "scenes": scene_results}
