extends ItemEffect


func apply_pre(battle: BattleCore, player: int, target: int, _data: ItemData) -> void:
	if battle.item_debuff_blocked(1 - player):
		return
	battle.arm_use_or_lock(player, target)
