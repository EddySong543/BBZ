extends ItemEffect


func prepare_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.set_item_mod(player, "enemy_wave_no_damage", true)
	battle.set_item_mod(player, "enemy_big_wave_total_bonus", maxi(
		int(battle.item_mod(player, "enemy_big_wave_total_bonus", 0)),
		int(data.params.get("big_bonus", 4))))
