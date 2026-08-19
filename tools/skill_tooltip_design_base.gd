extends Node

const OUT := "D:/Game/BoBoZan/_probe_output/skill_tooltip_design_base.png"


func _ready() -> void:
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var target := screen.btn_special as Control
	screen._show_tip_at(target.get_global_rect(),
			"【龙御极】\n额外消耗1点能量，使「波」伤害增加1点\n消耗1点能量")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
