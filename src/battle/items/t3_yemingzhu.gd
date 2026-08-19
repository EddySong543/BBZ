extends ItemEffect


func relic_on_activate(_battle: BattleCore, _player: int, data: ItemData,
		state: Dictionary, _events: Array) -> void:
	state["charges"] = int(state.get("charges", 0)) + int(data.params.get("charges", 3))


func relic_on_switch_in(battle: BattleCore, player: int, slot: int, data: ItemData,
		state: Dictionary, events: Array) -> void:
	var charges: int = int(state.get("charges", 0))
	if charges <= 0:
		return
	var damage: int = int(data.params.get("dmg", 2))
	var armor: int = int(data.params.get("armor", 2))
	var opponent: int = 1 - player
	battle._apply_damage(opponent, damage, player, ActionDef.Action.ATTACK,
		ActionDef.Pen.NORMAL, ActionDef.Action.CHARGE, events, [], "item", slot)
	if battle.hp[player][slot] > 0:
		battle.shield[player][slot] += armor
	state["charges"] = charges - 1
	events.append({id = "relic_trigger", player = player, item_id = data.item_id,
		damage = damage, armor = armor, charges = charges - 1})


func relic_end(_battle: BattleCore, _player: int, _data: ItemData, state: Dictionary,
		_events: Array) -> bool:
	return int(state.get("charges", 0)) > 0
