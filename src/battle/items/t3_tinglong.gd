extends ItemEffect

## 停龙剑：弃光全部能量，每 1.0 能对敌造 0.5 伤穿大防（倾尽一击·扫地式）。
func hits(battle: BattleCore, player: int, _target: int, _data: ItemData) -> Array:
	var e: int = battle.energy[player]
	if e <= 0:
		return []
	battle.energy[player] = 0
	var dmg: int = e / ActionDef.ENERGY_UNIT   # 每 1.0 能（2 半能）→ 0.5 HP（1 半伤）
	if dmg <= 0:
		return []
	return [{damage = dmg, kind = ActionDef.Action.BIG_ATTACK, pen = ActionDef.Pen.PIERCE_BIGDEF}]
