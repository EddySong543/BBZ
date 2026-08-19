extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "share_next_base_attack", true)
	battle.set_item_mod(player, "shared_damage_cursor", 0)
