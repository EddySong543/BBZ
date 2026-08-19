extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.arm_first_active_energy_gain_shield(player, int(data.params.get("armor", 2)))
