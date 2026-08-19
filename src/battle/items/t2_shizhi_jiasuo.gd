extends ItemEffect


func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	if battle.item_debuff_blocked(1 - player):
		return
	battle.delay_enemy_locked_item(player, target, int(data.params.get("turns", 1)))
