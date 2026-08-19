extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.arm_return_camp_heal(player, int(data.params.get("heal", 4)))
