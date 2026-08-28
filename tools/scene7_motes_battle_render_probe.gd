extends Node

const BATTLE7 := preload("res://src/ui/battle_screen7.tscn")
const MOTE_LAYERS: Array[String] = [
	"OasisMotesFar", "OasisMotesMid", "OasisMotesNear",
]
const VISIBLE_DELTA := 0.025


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var screen := BATTLE7.instantiate() as Control
	viewport.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	for node_name: String in [
		"P1Shadow", "P2Shadow", "P1CharDisplay", "P2CharDisplay",
		"ForeDust", "LowerDust",
	]:
		var item := screen.get_node_or_null(node_name) as CanvasItem
		if item != null:
			item.visible = false
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	for source_name: String in [
		"MidgroundCenter", "MidgroundLeft", "MidgroundRight", "ForegroundLeft",
	]:
		var source_material := (stage.get_node(source_name) as TextureRect).material \
				as ShaderMaterial
		source_material.set_shader_parameter("branch_motion_enabled", 0.0)
	for node_name: String in [
		"MidgroundCenterGlowFX", "MidgroundCenterGrassGlowFX",
		"MidgroundLeftGlowFX", "MidgroundRightGlowFX",
		"MidgroundRightGrassGlowFX", "ForegroundLeftGlowFX",
		"RearWater", "RearWaterReflection", "FrontWater",
		"PlatformSpringContact",
	]:
		(stage.get_node(node_name) as CanvasItem).visible = false
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	_set_mote_time(stage, 0.0)
	await RenderingServer.frame_post_draw
	var first := viewport.get_texture().get_image()
	_set_mote_time(stage, 10.0)
	await RenderingServer.frame_post_draw
	var second := viewport.get_texture().get_image()
	var metrics := _difference_metrics(
			first, second, Rect2i(0, 430, 1920, 530))
	var passed := int(metrics["changed_pixels"]) >= 800 \
			and float(metrics["mean_changed_delta"]) >= 0.04 \
			and float(metrics["max_delta"]) >= 0.10
	print("SCENE7_MOTES_BATTLE_VISIBILITY: ",
			"PASS" if passed else "FAIL", " metrics=", metrics)
	get_tree().quit(0 if passed else 1)


func _set_mote_time(stage: BattleStage, value: float) -> void:
	for mote_name: String in MOTE_LAYERS:
		var material := (stage.get_node(mote_name) as ColorRect).material \
				as ShaderMaterial
		material.set_shader_parameter("diagnostic_time_sec", value)


func _difference_metrics(
		first: Image, second: Image, bounds: Rect2i) -> Dictionary:
	var changed_pixels := 0
	var delta_total := 0.0
	var max_delta := 0.0
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var before := first.get_pixel(x, y)
			var after := second.get_pixel(x, y)
			var delta := maxf(
					absf(after.r - before.r),
					maxf(absf(after.g - before.g), absf(after.b - before.b)))
			max_delta = maxf(max_delta, delta)
			if delta < VISIBLE_DELTA:
				continue
			changed_pixels += 1
			delta_total += delta
	return {
		"changed_pixels": changed_pixels,
		"mean_changed_delta": delta_total / maxf(float(changed_pixels), 1.0),
		"max_delta": max_delta,
	}
