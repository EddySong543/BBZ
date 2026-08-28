extends "res://src/ui/battle_screen.gd"

## Scene7-only bridge between the shared turn flow and the local oasis easter
## egg. No shared battle code or action behavior is changed.

const OASIS_RESONANCE_PATH := NodePath("StageSlot/Stage/OasisResonance")


func _start_player_select() -> void:
	super()
	_scene7_set_countdown_idle(true)


func _resolve() -> void:
	var attack_committed := _scene7_any_attack_committed()
	_scene7_set_countdown_idle(false, attack_committed)
	await super()


func _scene7_set_countdown_idle(
		active: bool, interrupted_by_attack: bool = false) -> void:
	var resonance := get_node_or_null(OASIS_RESONANCE_PATH)
	if resonance != null and resonance.has_method("set_countdown_idle"):
		resonance.call(
				"set_countdown_idle", active, interrupted_by_attack)


func _scene7_any_attack_committed() -> bool:
	if battle == null:
		return false
	for side: int in 2:
		if battle.will_attack_this_turn(side):
			return true
	return false
