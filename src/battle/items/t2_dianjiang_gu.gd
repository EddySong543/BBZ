extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.item_debuff_blocked(1 - player):
		return
	battle.set_item_mod(player, "dianjiang_after_hit", true)
