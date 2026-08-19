extends ItemEffect

## 银质穿甲箭：我方原选「波」且敌方原选「防」时，总伤害 +1 并穿防。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.ATTACK \
			and battle.selected_action[1 - player] == ActionDef.Action.DEFEND:
		battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 2)))
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_DEF)


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	apply_pre(battle, player, -1, data)
