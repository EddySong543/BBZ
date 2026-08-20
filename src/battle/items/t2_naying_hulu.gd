extends ItemEffect


func resolves_on_submit() -> bool:
	return true


func apply_on_submit(battle: BattleCore, player: int, _target: int, _data: ItemData,
		_events: Array) -> void:
	battle.arm_overflow_energy_to_heal(player)


func prepare_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.arm_overflow_energy_to_heal(player)
