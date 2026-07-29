extends Node

const OUT := "D:/Game/BoBoZan/_probe_output/battle_scene2_shot.png"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	var screen := (load("res://src/ui/battle_screen2.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
