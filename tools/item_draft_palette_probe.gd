extends Node

const OUT := "D:/Game/BoBoZan/_probe_output/item_draft_shared_palette.png"


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#18243A")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var popup := ItemDraftPopup.new()
	add_child(popup)
	popup.setup([
		ItemCatalog.make("t1_feibiao"),
		ItemCatalog.make("t2_mojing"),
		ItemCatalog.make("t3_yemingzhu"),
	], true, "升级道具（3 选 1）")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()
