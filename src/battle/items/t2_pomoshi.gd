extends ItemEffect

## 破魔矢：仅本回合基础「波」增加整次总伤害并穿防。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.ATTACK:
		battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 2)))
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_DEF)


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	apply_pre(battle, player, -1, data)
