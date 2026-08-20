extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.reveal_enemy_backpack(player, int(data.params.get("count", 3)))
