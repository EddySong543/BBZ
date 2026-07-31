extends Node

const OUT_A := "D:/Game/BoBoZan/_probe_output/scene3_shot_a.png"
const OUT_B := "D:/Game/BoBoZan/_probe_output/scene3_shot_b.png"
const OUT_C := "D:/Game/BoBoZan/_probe_output/scene3_shot_c.png"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var stage: Node = (load("res://src/ui/scenes/scene3.tscn") as PackedScene).instantiate()
	add_child(stage)
	await get_tree().create_timer(1.3).timeout
	await _shot(OUT_A)
	await get_tree().create_timer(2.0).timeout
	await _shot(OUT_B)
	await get_tree().create_timer(2.1).timeout
	await _shot(OUT_C)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
