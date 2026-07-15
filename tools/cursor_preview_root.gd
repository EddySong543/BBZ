extends Node

## 指针预览探针（G 件·2026-07-15）：OS 指针不进视口截图 → 把两枚指针贴图按实寸手动画在
## 亮宣纸/暗夜两块衬底上（1×/2×/4× 三档），截图自检形状与双衬底可见性。实机手感=Eddy F6。
## 带窗口跑：godot --path . res://tools/cursor_preview.tscn

const OUT := "C:/Users/Edzzz/AppData/Local/Temp/claude/D--Game-BoBoZan-Claude-Code-Game-Studios-cn-localization/ef8edc84-b5fb-49a6-967e-6aa8a4693e9f/scratchpad/cursor_preview.png"
const BACKDROP := preload("res://assets/ui/item_codex_backdrop.png")


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var root := Control.new()
	root.size = Vector2(1280, 720)
	add_child(root)
	# 左=亮宣纸衬底；右=战斗夜空近似暗底
	var paper := TextureRect.new()
	paper.texture = BACKDROP
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper.size = Vector2(640, 720)
	root.add_child(paper)
	var night := ColorRect.new()
	night.color = Color("101827")
	night.position = Vector2(640, 0)
	night.size = Vector2(640, 720)
	root.add_child(night)

	for side in 2:
		var x0 := 80.0 + side * 640.0
		for v in 2:
			var tex: Texture2D = load("res://assets/ui/cursor_%s.png" % (["arrow", "hand"][v]))
			for s in 3:
				var k: float = [1.0, 2.0, 4.0][s]
				var tr := TextureRect.new()
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.position = Vector2(x0 + v * 260.0, 80.0 + s * 190.0)
				tr.size = Vector2(48, 48) * k
				root.add_child(tr)

	await get_tree().create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
