extends ItemEffect

func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var amount: int = mini(battle.shield[player][target], int(data.params.get("max_armor", 4)))
	battle.shield[player][target] -= amount
	battle.add_item_mod(player, "base_attack_total_bonus", amount)
