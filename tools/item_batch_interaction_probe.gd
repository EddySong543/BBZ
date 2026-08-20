extends Node

const SCREEN_SCENE := preload("res://src/ui/battle_screen1.tscn")
const SS := BattleCore.SlotState

var _failures: Array[String] = []


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	BattleSetup.configure_pve(
		[_hero("h01"), _hero("h02"), _hero("h03")],
		[_hero("h04"), _hero("h05"), _hero("h06")],
		[10, 10, 10], [10, 10, 10], 190_819)
	var screen := SCREEN_SCENE.instantiate()
	add_child(screen)
	await get_tree().create_timer(2.0).timeout
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	if screen.game_timer != null:
		screen.game_timer.stop()

	_check(get_window().size == Vector2i(1920, 1080),
		"runtime window is not 1920x1080")

	screen.battle.slots[0][0] = _ready_slot("t2_cuiyong_pai")
	screen.battle.slots[1][1] = _ready_slot("t2_feibiao")
	screen._update_all()
	_check(screen._toggle_ready_item_selection(0), "cuiyong selection did not start")
	_check(screen._pending_enemy_item_target_slot == 0,
		"cuiyong did not enter enemy item targeting")
	_check(screen._complete_enemy_item_slot_target(0, 1),
		"cuiyong could not select the ready enemy item")
	_check(int(screen.selected_item_targets.get(0, -1)) == 1,
		"cuiyong target was not retained in the live UI state")

	screen._clear_selected_items()
	screen.battle.hp[0] = [2, 4, 20]
	screen.battle.slots[0][0] = _ready_slot("t3_yiyuan_deng")
	screen._update_all()
	_check(screen._toggle_ready_item_selection(0), "last-wish selection did not start")
	_check(screen._pending_item_hero_target_slot == 0,
		"last-wish did not enter friendly hero targeting")
	_check(not screen._complete_friendly_item_target(0, 0),
		"last-wish incorrectly accepted the active hero")
	_check(screen._complete_friendly_item_target(0, 2),
		"last-wish rejected a living reserve hero")
	_check(int(screen.selected_item_hero_targets.get(0, -1)) == 2,
		"last-wish target was not retained in the live UI state")

	if _failures.is_empty():
		print("item_batch_interaction_probe: PASS 1920x1080; no image captured")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error("item_batch_interaction_probe: " + failure)
		get_tree().quit(1)


func _hero(item_id: String) -> HeroData:
	return load("res://assets/data/heroes/%s.tres" % item_id) as HeroData


func _ready_slot(item_id: String) -> Dictionary:
	return {
		state = SS.CHARGING,
		item = ItemCatalog.make(item_id),
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
		draft_entry_uids = [],
		instance_uid = -1,
		temporary = false,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
