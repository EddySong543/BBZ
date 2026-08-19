extends ItemEffect

func prepare_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "healing_to_shield", true)
