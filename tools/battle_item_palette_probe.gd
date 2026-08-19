extends Node

const OUT_FULL := "D:/Game/BoBoZan/_probe_output/battle_item_gallery_palette.png"
const OUT_DETAIL := "D:/Game/BoBoZan/_probe_output/battle_item_gallery_palette_detail.png"
const ITEM_IDS := ["t1_feibiao", "t2_mojing", "t3_yemingzhu"]


func _ready() -> void:
	var player_team: Array[HeroData] = [
		load("res://assets/data/heroes/h05.tres") as HeroData,
		load("res://assets/data/heroes/h07.tres") as HeroData,
	]
	var opponent_team: Array[HeroData] = [
		load("res://assets/data/heroes/h13.tres") as HeroData,
		load("res://assets/data/heroes/h17.tres") as HeroData,
	]
	BattleSetup.configure_pve(player_team, opponent_team, [7, 10], [9, 12], 2468)
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(3.2).timeout
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	for player in range(2):
		for slot in range(3):
			screen.battle.slots[player][slot] = {
				"state": BattleCore.SlotState.CHARGING,
				"item": ItemCatalog.make(ITEM_IDS[slot]),
				"since": screen.battle.turn_number - 1,
				"used": false,
				"draft": [],
				"upg_draft": [],
			}
	screen.p1_item_row.interactive = false
	screen.p1_item_row.refresh(screen.battle, 0)
	screen.p2_item_row.refresh(screen.battle, 1)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var full := get_viewport().get_texture().get_image()
	full.save_png(OUT_FULL)
	var row := screen.p1_item_row as ItemSlotRow
	var top_left := Vector2i(row.global_position) - Vector2i(24, 24)
	var detail_size := Vector2i(
			int(row.size.x * row.scale.x) + 48,
			int(row.size.y * row.scale.y) + 48)
	var detail := full.get_region(Rect2i(top_left, detail_size))
	detail.resize(detail.get_width() * 4, detail.get_height() * 4,
			Image.INTERPOLATE_NEAREST)
	detail.save_png(OUT_DETAIL)
	print("saved: ", OUT_FULL)
	print("saved: ", OUT_DETAIL)
	get_tree().quit()
