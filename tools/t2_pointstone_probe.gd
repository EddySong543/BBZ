extends Node

const ProbeOutput := preload("res://tools/probe_output.gd")
const HERO_DIR := "res://assets/data/heroes/"


func _hero(hero_id: String) -> HeroData:
	return load(HERO_DIR + hero_id + ".tres") as HeroData


func _ready_slot(item_id: String) -> Dictionary:
	return {
		state = BattleCore.SlotState.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
	}


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.p1_heroes = [_hero("h01"), _hero("h07"), _hero("h14")]
	BattleSetup.p2_heroes = [_hero("h02"), _hero("h08"), _hero("h12")]
	BattleSetup.overtime = false
	BattleSetup.pve_mode = false

	var screen: Control = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(2.2).timeout
	var failures: Array[String] = []
	if int(screen.state) != int(screen.State.PLAYER_SELECT):
		failures.append("战斗界面未进入选招阶段")

	screen.battle.slots[screen.PLAYER] = [
		_ready_slot("t2_dianjinshi"),
		_ready_slot("t1_feibiao"),
		_ready_slot("t2_jiandun"),
	]
	screen._clear_selected_items()
	screen._update_all()

	# 来源 → 普通目标：必须弹出真实 T3 三选一。
	screen._on_p1_slot_clicked(0)
	await get_tree().process_frame
	if int(screen._pending_item_target_slot) != 0:
		failures.append("点击点金石后未进入目标选择")
	screen._on_p1_slot_clicked(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var popup: ItemDraftPopup = null
	for child in screen.get_children():
		if child is ItemDraftPopup:
			popup = child as ItemDraftPopup
			break
	if popup == null:
		failures.append("选择普通目标后未出现传说道具三选一")
	else:
		var cards: Array[Button] = []
		for child in popup.get_children():
			if child is Button and (child as Button).size.y > 300.0:
				cards.append(child as Button)
		if cards.size() != 3:
			failures.append("点金石候选卡数量不是3")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProbeOutput.path("t2_pointstone_t3_choice.png"))
		if not cards.is_empty():
			cards[0].pressed.emit()

	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	if int(screen.selected_item_targets.get(0, -1)) != 1:
		failures.append("点金石没有保留所选普通目标")
	if int(screen.selected_item_choices.get(0, -1)) != 0:
		failures.append("点金石没有保留所选传说候选")
	var projected: BattleCore = screen._battle_for_item_row()
	var projected_item: ItemData = projected.slot_item(screen.PLAYER, 1)
	if projected_item == null or projected_item.tier != 3:
		failures.append("目标槽没有显示为传说道具")
	if projected.slot_ready(screen.PLAYER, 1):
		failures.append("升级后的传说道具未显示为锁定一回合")
	if screen._toggle_ready_item_selection(1):
		failures.append("锁定的传说道具仍能在本回合追加使用")
	if not (screen.p1_item_row._mini_seals[1] as Control).visible:
		failures.append("目标槽未显示锁定封条")

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("t2_pointstone_locked_t3.png"))

	# 公开长期状态复用顶部英雄头像的既有悬停纸签，验证可查询且不新增常驻面板。
	var active_slot: int = screen.battle.active_index[screen.PLAYER]
	screen.battle.set_status(screen.PLAYER, active_slot, "fatal_damage_immunity", 2)
	screen.battle.item_buffs[screen.PLAYER]["next_base_attack_true_damage"] = true
	screen.battle.item_buffs[screen.PLAYER]["switch_lock_until_turn"] = screen.battle.turn_number + 1
	screen._update_all()
	var public_status_tip: String = screen._hero_status_tip(screen.PLAYER, 0)
	(screen.p1_frames[0] as Control).mouse_entered.emit()
	await get_tree().process_frame
	if not screen._tip_panel.visible:
		failures.append("英雄头像悬停未显示公开长期状态纸签")
	for expected_text in ["还魂丹", "×2", "下一次攻击造成真实伤害", "剩余2回合"]:
		if not public_status_tip.contains(expected_text):
			failures.append("公开状态纸签缺少：" + expected_text)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProbeOutput.path("t2_public_status_hover.png"))

	if failures.is_empty():
		print("T2_POINTSTONE_PROBE_PASS")
		print("T2_POINTSTONE_CHOICES=t2_pointstone_t3_choice.png")
		print("T2_POINTSTONE_LOCKED=t2_pointstone_locked_t3.png")
		print("T2_PUBLIC_STATUS_HOVER=t2_public_status_hover.png")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("T2_POINTSTONE_PROBE: " + failure)
		get_tree().quit(1)
