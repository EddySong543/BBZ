extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "next_damage_redirect", int(data.params.get("redirect", 2)))
