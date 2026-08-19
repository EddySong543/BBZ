extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if not battle.will_attack_this_turn(player):
		return
	var slot: int = battle.active_index[player]
	if battle.hp[player][slot] > int(data.params.get("threshold", 2)):
		return
	battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 6)))
	battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_BIGDEF)
