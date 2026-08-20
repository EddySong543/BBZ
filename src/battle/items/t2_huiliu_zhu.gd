extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "exact_spend_refund", int(data.params.get("energy", 4)))
