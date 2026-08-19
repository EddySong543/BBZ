extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "damage_immune", 1)
