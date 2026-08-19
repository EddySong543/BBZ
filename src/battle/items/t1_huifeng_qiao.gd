extends ItemEffect

func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "blocked_wave_shield", int(data.params.get("armor", 3)))
