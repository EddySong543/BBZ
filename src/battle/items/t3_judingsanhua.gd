extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["charges"] = int(state.get("charges", 0)) + int(data.params.get("charges", 3))


func relic_pre(battle: BattleCore, player: int, data: ItemData, state: Dictionary,
		_events: Array) -> void:
	if int(state.get("charges", 0)) <= 0:
		return
	if battle.will_attack_this_turn(player):
		battle.add_item_mod(player, "whole_attack_extra_hit_effects",
			int(data.params.get("hits", 1)))


func relic_on_attack_resolved(_battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, state: Dictionary, events: Array) -> void:
	var charges: int = int(state.get("charges", 0))
	if charges <= 0 or int(context.get("source_slot", -1)) < 0:
		return
	state["charges"] = charges - 1
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		connected = bool(context.get("connected", false)), charges = charges - 1})


func relic_end(_battle: BattleCore, _player: int, _data: ItemData, state: Dictionary,
		_events: Array) -> bool:
	return int(state.get("charges", 0)) > 0
