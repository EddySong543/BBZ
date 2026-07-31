extends Node

const OUT_A := "D:/Game/BoBoZan/_probe_output/scene1_bamboo_sway_a.png"
const OUT_B := "D:/Game/BoBoZan/_probe_output/scene1_bamboo_sway_b.png"
const OUT_C := "D:/Game/BoBoZan/_probe_output/scene1_bamboo_sway_c.png"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.08, 0.1, 0.16, 1.0)
	add_child(backdrop)

	var stage := (load("res://src/ui/scenes/scene1.tscn") as PackedScene).instantiate()
	add_child(stage)
	stage.pointer_parallax = false
	for child: Node in stage.get_children():
		if child.name not in ["BambooLeft", "BambooRight"] \
				and child is CanvasItem:
			(child as CanvasItem).visible = false

	await get_tree().create_timer(1.2).timeout
	await _shot(OUT_A)
	await get_tree().create_timer(2.4).timeout
	await _shot(OUT_B)
	await get_tree().create_timer(2.4).timeout
	await _shot(OUT_C)
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved: ", path)
