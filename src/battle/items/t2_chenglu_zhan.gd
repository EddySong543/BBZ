extends ItemEffect


func prepare_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "overheal_to_energy", true)
