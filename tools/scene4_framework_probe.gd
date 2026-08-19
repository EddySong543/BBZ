extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen4.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var platform := stage.get_node("BattlePlatform") as Control
	var world := screen.get_node("WorldGroup") as Control
	var stage_visibility := _capture_canvas_visibility(stage)
	var screen_visibility := _capture_canvas_visibility(screen)
	stage.set_process(false)
	screen.set_process(false)

	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	await _shot(ProbeOutput.path("scene4_framework_center.png"))
	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	await _shot(ProbeOutput.path("scene4_framework_pointer_right.png"))
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var leaf_spirits := stage.get_node("LeafSpirits")
	var leaf_spirits_triggered := bool(leaf_spirits.call("trigger_swarm", 1))
	var leaf_spirit_count := int(
			leaf_spirits.call("get_active_spirit_count"))
	await get_tree().create_timer(0.75).timeout
	await _shot(ProbeOutput.path("scene4_leaf_spirits_early.png"))
	await get_tree().create_timer(0.95).timeout
	await _shot(ProbeOutput.path("scene4_leaf_spirits_mid.png"))
	await get_tree().create_timer(1.15).timeout
	await _shot(ProbeOutput.path("scene4_leaf_spirits_late.png"))
	await get_tree().create_timer(2.4).timeout
	await _shot(ProbeOutput.path("scene4_ambient_fx_later.png"))
	await get_tree().create_timer(2.4).timeout
	await _shot(ProbeOutput.path("scene4_ambient_fx_alternate.png"))
	await _capture_layer_motion(screen, stage)
	_restore_canvas_visibility(stage_visibility)
	_restore_canvas_visibility(screen_visibility)
	_apply_ruin_recompose_preview(stage)
	await get_tree().create_timer(0.6).timeout
	await _shot(ProbeOutput.path("scene4_ruin_recompose_preview.png"))

	# Re-baseline immediately before the parallax assertion. The layered motion
	# capture intentionally hides most CanvasItems for several seconds.
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_center_x := platform.position.x
	var world_center_x := world.position.x
	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var platform_delta := platform.position.x - platform_center_x
	var world_delta := world.position.x - world_center_x
	var sync_error := absf(platform_delta - world_delta)
	await _shot(ProbeOutput.path("scene4_framework_right.png"))
	print(
			"SCENE4_FRAMEWORK_PROBE: PASS platform_delta=",
			platform_delta,
			" world_delta=",
			world_delta,
			" error=",
			sync_error,
			" leaf_spirits=",
			leaf_spirit_count)
	BattleSetup.reset()
	var passed := (
			is_zero_approx(sync_error)
			and leaf_spirits_triggered
			and leaf_spirit_count >= 2
			and leaf_spirit_count <= 3
	)
	get_tree().quit(0 if passed else 1)


func _capture_layer_motion(screen: Control, stage: BattleStage) -> void:
	# Stop countdown/tween callbacks from re-showing HUD nodes during the long
	# isolated captures. Shader TIME continues independently.
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in screen.get_children():
		if child is CanvasItem and child != screen.get_node("StageSlot"):
			(child as CanvasItem).visible = false

	var atmosphere_layers: Array[String] = [
		"PreviewBackdrop",
		"Sky",
		"FarForest",
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
		"BackgroundTree2",
		"BackgroundTree",
		"BackgroundBottomLeaves",
		"BackgroundTopLeaves2",
		"CanopyLightShafts",
		"MidgroundMist",
		"CanopyMotes",
		"RuinMotes1",
		"RuinMotes2",
		"RuinMotes3",
		"RuinMotes4",
		"BattlePlatformDepthShadow",
		"BattlePlatform",
		"ForegroundFog",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in atmosphere_layers
	await _shot(ProbeOutput.path("scene4_midground_atmosphere_a.png"))
	await get_tree().create_timer(3.6).timeout
	await _shot(ProbeOutput.path("scene4_midground_atmosphere_b.png"))

	var tree_grade_layers: Array[String] = [
		"PreviewBackdrop",
		"Sky",
		"FarForest",
		"BackgroundTree",
		"BackgroundTree2",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in tree_grade_layers
	await _shot(ProbeOutput.path("scene4_background_tree_grade.png"))

	var foreground_fog_layers: Array[String] = [
		"PreviewBackdrop",
		"BattlePlatformDepthShadow",
		"BattlePlatform",
		"LeftTree2",
		"RightTree2",
		"ForegroundFog",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in foreground_fog_layers
	await _shot(ProbeOutput.path("scene4_foreground_fog_a.png"))
	await get_tree().create_timer(3.2).timeout
	await _shot(ProbeOutput.path("scene4_foreground_fog_b.png"))

	var stone_layers: Array[String] = [
		"PreviewBackdrop",
		"Sky",
		"FarForest",
		"RuinStone1",
		"RuinStone2",
		"RuinStone3",
		"RuinStone4",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in stone_layers
	await _shot(ProbeOutput.path("scene4_stone_flow_a.png"))
	await get_tree().create_timer(0.75).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_smooth_b.png"))
	await get_tree().create_timer(0.75).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_smooth_c.png"))
	await get_tree().create_timer(5.5).timeout
	await _shot(ProbeOutput.path("scene4_stone_flow_b.png"))

	var sway_layers: Array[String] = [
		"PreviewBackdrop",
		"BackgroundBottomLeaves",
		"BackgroundTopLeaves2",
		"LeftTree2",
		"RightTree2",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in sway_layers
	await _shot(ProbeOutput.path("scene4_hanging_sway_a.png"))
	await get_tree().create_timer(2.2).timeout
	await _shot(ProbeOutput.path("scene4_hanging_sway_b.png"))

	var vine_layers: Array[String] = [
		"PreviewBackdrop",
		"LeftTree2",
		"RightTree2",
	]
	for child: Node in stage.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = child.name in vine_layers
	await _shot(ProbeOutput.path("scene4_vine_sway_a.png"))
	await get_tree().create_timer(2.2).timeout
	await _shot(ProbeOutput.path("scene4_vine_sway_b.png"))


func _capture_canvas_visibility(parent: Node) -> Dictionary:
	var visibility: Dictionary = {}
	for child: Node in parent.get_children():
		if child is CanvasItem:
			visibility[child] = (child as CanvasItem).visible
	return visibility


func _restore_canvas_visibility(visibility: Dictionary) -> void:
	for item: Variant in visibility:
		if is_instance_valid(item) and item is CanvasItem:
			(item as CanvasItem).visible = bool(visibility[item])


func _apply_ruin_recompose_preview(stage: BattleStage) -> void:
	# Preview-only composition: three unequal relic silhouettes replace the
	# current four evenly spaced markers. Nothing here is saved into scene4.tscn.
	var stone_layouts: Dictionary = {
		"RuinStone1": {
			"position": Vector2(570.0, 330.0),
			"scale": Vector2(1.45, 1.45),
			"modulate": Color(0.82, 0.91, 0.86, 0.8),
			"exposure": 0.75,
			"glow": 0.3,
			"charge": 0.09,
		},
		"RuinStone2": {
			"position": Vector2(1090.0, 255.0),
			"scale": Vector2(1.8, 1.8),
			"modulate": Color(0.88, 0.96, 0.91, 0.88),
			"exposure": 0.8,
			"glow": 0.36,
			"charge": 0.12,
		},
		"RuinStone4": {
			"position": Vector2(-48.0, 405.0),
			"scale": Vector2(1.08, 1.08),
			"modulate": Color(0.72, 0.84, 0.78, 0.68),
			"exposure": 0.66,
			"glow": 0.18,
			"charge": 0.05,
		},
	}
	for stone_name: String in stone_layouts:
		var stone := stage.get_node(stone_name) as TextureRect
		var layout := stone_layouts[stone_name] as Dictionary
		stone.position = layout["position"] as Vector2
		stone.scale = layout["scale"] as Vector2
		stone.modulate = layout["modulate"] as Color
		var preview_material := stone.material.duplicate() as ShaderMaterial
		stone.material = preview_material
		preview_material.set_shader_parameter("exposure", float(layout["exposure"]))
		preview_material.set_shader_parameter("glow_strength", float(layout["glow"]))
		preview_material.set_shader_parameter("base_charge", float(layout["charge"]))

	(stage.get_node("RuinStone3") as CanvasItem).visible = false
	(stage.get_node("RuinMotes3") as GPUParticles2D).visible = false
	var mote_layouts: Dictionary = {
		"RuinMotes1": {"position": Vector2(635.0, 675.0), "amount": 3},
		"RuinMotes2": {"position": Vector2(1185.0, 650.0), "amount": 4},
		"RuinMotes4": {"position": Vector2(75.0, 700.0), "amount": 2},
	}
	for mote_name: String in mote_layouts:
		var motes := stage.get_node(mote_name) as GPUParticles2D
		var layout := mote_layouts[mote_name] as Dictionary
		motes.position = layout["position"] as Vector2
		motes.amount = int(layout["amount"])


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self):
		return
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Scene4 framework probe could not save %s (error=%d)" % [path, error])
