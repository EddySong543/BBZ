extends Node

const OUT := "D:/Game/BoBoZan/_probe_output/battle_scene3_shot.png"
const OUT_RAYS := "D:/Game/BoBoZan/_probe_output/battle_scene3_rays_shot.png"
const OUT_FISH_EARLY := (
		"D:/Game/BoBoZan/_probe_output/battle_scene3_fish_early.png")
const OUT_FISH := "D:/Game/BoBoZan/_probe_output/battle_scene3_fish_shot.png"
const OUT_FISH_LATE := (
		"D:/Game/BoBoZan/_probe_output/battle_scene3_fish_late.png")
const OUT_POINTER_CENTER := (
		"D:/Game/BoBoZan/_probe_output/battle_scene3_pointer_center.png")
const OUT_POINTER_RIGHT := (
		"D:/Game/BoBoZan/_probe_output/battle_scene3_pointer_right.png")


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var screen: Node = (load("res://src/ui/battle_screen3.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	await get_tree().create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_RAYS)
	print("saved: ", OUT_RAYS)
	var stage := screen.get_node("StageSlot/Stage")
	(stage.get_node("FlyingFishFar") as Node).call("trigger_school", 1)
	(stage.get_node("FlyingFishNear") as Node).call("trigger_school", -1)
	await get_tree().create_timer(0.35).timeout
	await _shot(OUT_FISH_EARLY)
	await get_tree().create_timer(0.5).timeout
	await _shot(OUT_FISH)
	await get_tree().create_timer(0.55).timeout
	await _shot(OUT_FISH_LATE)
	await _probe_pointer_sync(screen)
	get_tree().quit()


func _probe_pointer_sync(screen: Node) -> void:
	var stage := screen.get_node("StageSlot/Stage") as Control
	var chain := stage.get_node("MainChain") as Control
	var world := screen.get_node("WorldGroup") as Control
	stage.set_process(false)
	screen.set_process(false)
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var center_chain_x := chain.position.x
	var center_world_x := world.position.x
	await _shot(OUT_POINTER_CENTER)
	stage.set("_pnx", 1.0)
	stage.call("_process", 0.0)
	screen.call("_process", 0.0)
	var chain_delta := chain.position.x - center_chain_x
	var world_delta := world.position.x - center_world_x
	await _shot(OUT_POINTER_RIGHT)
	print(
			"scene3 pointer sync: chain_delta=",
			chain_delta,
			" world_delta=",
			world_delta,
			" error=",
			absf(chain_delta - world_delta))


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
