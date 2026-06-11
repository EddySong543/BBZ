extends SceneTree

## 主菜单静态预览（开发调试用）：
##   godot --path . -s tools/menu_preview.gd
## -s 模式不加载 autoload → 手动以同名节点补 FontManager / TransitionManager，
## 等入场动画落定后截图保存退出。
## 输出：D:/Game/BoBoZan/menu_preview.png（仓库外）

const OUT_PATH := "D:/Game/BoBoZan/menu_preview.png"
const AUTOLOADS: Array = [
	["FontManager", "res://src/core/font_manager.gd"],
	["TransitionManager", "res://src/core/transition_manager.gd"],
]


func _initialize() -> void:
	for entry_v in AUTOLOADS:
		var entry: Array = entry_v
		var node := (load(entry[1]) as GDScript).new() as Node
		node.name = entry[0]
		root.add_child(node)
	var menu := (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	# 入场错落浮入约 1.1s 完成 → 1.6s 截一帧
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()
