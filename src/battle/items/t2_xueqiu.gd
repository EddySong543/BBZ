extends ItemEffect

## 传说级雪球：本回合若重复上回合的动作类型 —— 连攻 → +0.5 伤 / 连防 → +0.5 甲（惯性）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var cur: int = battle.selected_action[player]
	var prev: int = battle._last_action[player]
	var n: int = int(data.params.get("bonus", 1))
	if ActionDef.is_attack(cur) and ActionDef.is_attack(prev):
		battle.add_item_mod(player, "atk_bonus", n)
	elif cur in ActionDef.DEFEND_ACTIONS and prev in ActionDef.DEFEND_ACTIONS:
		battle.shield[player][target] += n
