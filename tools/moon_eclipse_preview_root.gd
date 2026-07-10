extends Node

## 日食月亮两配色实机预览：boot 战斗屏 → 依次换上金/紫日食贴图 → 各截一张。
##   godot --path . res://tools/moon_eclipse_preview.tscn
## 输出：D:/Game/BoBoZan/moon_eclipse_gold.png / moon_eclipse_purple.png（仓库外）


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await get_tree().create_timer(2.2, true, false, true).timeout
	var moon: TextureRect = s.get_node("Stage/Moon")
	for v in ["gold", "purple"]:
		moon.texture = load("res://assets/scenes/scene1/scene1_moon_eclipse_%s.png" % v)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("D:/Game/BoBoZan/moon_eclipse_%s.png" % v)
	print("MOON_ECLIPSE_PREVIEW done")
	get_tree().quit()
