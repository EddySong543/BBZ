extends ItemEffect


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle._heal(player, target, int(data.params.get("heal", 6)))
