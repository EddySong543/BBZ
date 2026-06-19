extends ItemEffect

## 锋利的飞镖：对敌方出战造成 1.0 伤（飞镖升级线 T2·走防御门 + on-hit）。
func hits(_battle: BattleCore, _player: int, _target: int, data: ItemData) -> Array:
	return [{damage = int(data.params.get("dmg", 2)), kind = ActionDef.Action.ATTACK, pen = ActionDef.Pen.NORMAL}]
