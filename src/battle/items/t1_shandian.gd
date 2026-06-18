extends ItemEffect

## 闪电：对敌方出战 0.5 伤，无视「防」（穿防·大防仍挡）。
func hits(_battle: BattleCore, _player: int, _target: int, data: ItemData) -> Array:
	return [{damage = int(data.params.get("dmg", 1)), kind = ActionDef.Action.ATTACK, pen = ActionDef.Pen.PIERCE_DEF}]
