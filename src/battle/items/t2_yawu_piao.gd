extends ItemEffect


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.arm_item_wager(player, target, int(data.params.get("energy", 4)))
