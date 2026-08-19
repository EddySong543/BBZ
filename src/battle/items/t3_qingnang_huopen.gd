extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "bag_bonfire_requested", true)
