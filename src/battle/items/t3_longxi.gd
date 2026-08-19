extends ItemEffect


func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] != ActionDef.Action.BIG_ATTACK:
		return
	battle.set_item_mod(player, "atk_mult", 2)
	battle.add_base_attack_aftereffect(player, data)


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	apply_pre(battle, player, -1, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, events: Array) -> void:
	if not bool(context.get("blocked_by_big_defend", false)):
		return
	battle.item_buffs[player]["exhausted_next"] = true
	events.append({id = "longxi_exhausted", player = player, item_id = data.item_id})
