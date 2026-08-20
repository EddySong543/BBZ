extends ItemEffect


func can_use(battle: BattleCore, player: int, _target: int, data: ItemData) -> bool:
	return battle.is_only_ready_item_slot(player, data)


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 4)))
