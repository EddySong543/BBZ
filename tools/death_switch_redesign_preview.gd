extends Node

## 正式死亡换人浮层的 1920×1080 运行探针。
## 输出默认态、悬停态，并通过真实 gui_input 验证点击即选择。

const OUT_IDLE := "D:/Game/BoBoZan/_probe_output/death_switch_minimal_idle.png"
const OUT_HOVER := "D:/Game/BoBoZan/_probe_output/death_switch_minimal_hover.png"
const OUT_PRESSED := "D:/Game/BoBoZan/_probe_output/death_switch_minimal_pressed.png"

var _screen: Node
var _overlay: DeathSwitchOverlay


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	var player_team: Array[HeroData] = [
		load("res://assets/data/heroes/h05.tres") as HeroData,
		load("res://assets/data/heroes/h07.tres") as HeroData,
		load("res://assets/data/heroes/h11.tres") as HeroData,
	]
	var opponent_team: Array[HeroData] = [
		load("res://assets/data/heroes/h13.tres") as HeroData,
		load("res://assets/data/heroes/h17.tres") as HeroData,
		load("res://assets/data/heroes/h24.tres") as HeroData,
	]
	BattleSetup.configure_pve(player_team, opponent_team, [10, 8, 6], [10, 9, 7], 2468)
	_screen = (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	add_child(_screen)
	await get_tree().create_timer(3.2).timeout
	_screen.process_mode = Node.PROCESS_MODE_DISABLED
	_screen.call("_start_death_switch_timer")
	_overlay = _screen.get("_death_switch_overlay") as DeathSwitchOverlay
	_overlay.show_selection(0, [
		[1, player_team[1], 8.0],
		[2, player_team[2], 6.0],
	])
	await _shot(OUT_IDLE)

	var choices := _overlay.find_children("HeroFrame", "", true, false)
	assert(choices.size() == 2, "Death-switch probe expected two formal choices")
	var hovered := choices[1] as HeroFrame
	hovered.mouse_entered.emit()
	await get_tree().create_timer(0.16).timeout
	await _shot(OUT_HOVER)

	var selection := {"slot": -1}
	_overlay.selection_made.connect(func(slot: int) -> void: selection.slot = slot)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hovered.gui_input.emit(click)
	assert(selection.slot == 2, "Click must directly select the hovered reserve")
	await _shot(OUT_PRESSED)
	await get_tree().create_timer(0.08).timeout
	assert(not _overlay.visible, "Formal overlay must close immediately after selection")
	print("interaction_ok: selected_slot=", selection.slot)

	var timeout_selection := {"slot": -1}
	_overlay.show_selection(0, [[2, player_team[2], 6.0]])
	_overlay.selection_made.connect(func(slot: int) -> void: timeout_selection.slot = slot)
	_screen.set("state", 3) # BattleScreen.State.HERO_SELECT
	_screen.set("timer_seconds", 1)
	_screen.call("_on_timer_tick")
	assert(timeout_selection.slot == 2, "Timeout must select the first surviving reserve")
	assert((_screen.get("timer_label") as Label).text == "0",
		"Death switch timeout must stay on the shared top countdown")
	print("timeout_ok: selected_slot=", timeout_selection.slot)
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	assert(error == OK, "Failed to save death-switch probe: %s" % path)
	print("saved: ", path)
