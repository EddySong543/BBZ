extends ItemEffect

## 幸运四叶草：0.5 伤；若你出战 HP 比对手低，改为 1.0 伤（绝地走运）。
func hits(battle: BattleCore, player: int, _target: int, data: ItemData) -> Array:
	var opp: int = 1 - player
	var dmg: int = int(data.params.get("dmg", 1))
	if battle.hp[player][battle.active_index[player]] < battle.hp[opp][battle.active_index[opp]]:
		dmg = int(data.params.get("boon", 2))
	return [{damage = dmg, kind = ActionDef.Action.ATTACK, pen = ActionDef.Pen.NORMAL}]
