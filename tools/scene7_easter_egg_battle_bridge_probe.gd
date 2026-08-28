extends SceneTree

const BATTLE_SCREEN7_PATH := "res://src/ui/battle_screen7.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BATTLE_SCREEN7_PATH) as PackedScene
	var screen := packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	await process_frame
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var resonance := stage.get_node("OasisResonance")
	var tortoise := stage.get_node("CrystalTortoise")
	screen.call("_scene7_set_countdown_idle", true)
	tortoise.call("set_next_spawn_roll_for_test", 0.0)
	for click_x: float in [160.0, 960.0, 1760.0]:
		resonance.call("register_water_click", Vector2(click_x, 710.0))

	var battle := screen.get("battle") as BattleCore
	var player_selected := battle.select_action(0, ActionDef.Action.ATTACK)
	var opponent_selected := battle.select_action(1, ActionDef.Action.CHARGE)
	screen.call("_resolve")
	var passed := player_selected and opponent_selected \
			and not bool(resonance.call("is_countdown_idle")) \
			and bool(tortoise.call("is_rolling_out")) \
			and bool(tortoise.call("is_visit_active"))
	print("SCENE7_EASTER_EGG_BATTLE_BRIDGE: ", "PASS" if passed else "FAIL",
			" player_attack=", player_selected,
			" opponent_charge=", opponent_selected,
			" countdown_idle=", resonance.call("is_countdown_idle"),
			" rolling_exit=", tortoise.call("is_rolling_out"),
			" visitor_visible=", tortoise.call("is_visit_active"))
	quit(0 if passed else 1)
