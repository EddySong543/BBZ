extends SceneTree

## 道具 3 选 1 弹窗预览（B1·jelly 卡自检）：godot --path . -s tools/draft_popup_preview.gd
## 摆 3 张不同维度的候选卡（进攻红/防御蓝/能量金）→ 截一帧看 jelly 卡 + 文字可读性。
## 输出：D:/Game/BoBoZan/draft_popup_preview.png（仓库外）

const OUT := "D:/Game/BoBoZan/draft_popup_preview.png"
const POPUP := preload("res://src/ui/components/item_draft_popup.gd")


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2a2f38")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var popup: Control = POPUP.new()
	root.add_child(popup)
	var opts := [
		ItemCatalog.make("t1_feibiao"),       # 进攻红
		ItemCatalog.make("t1_jiudun"),         # 防御蓝
		ItemCatalog.make("t1_lzhi_fali"),      # 能量金
	]
	popup.setup(opts, true, "升级道具（3 选 1）")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	quit()
