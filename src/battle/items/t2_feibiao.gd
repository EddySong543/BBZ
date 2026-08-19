extends ItemEffect

## 锋利的飞镖：对敌方出战英雄造成独立道具伤害。
func hits(_battle: BattleCore, _player: int, _target: int, data: ItemData) -> Array:
	return [{damage = int(data.params.get("dmg", 4)), kind = ActionDef.Action.ATTACK,
		pen = ActionDef.Pen.NORMAL}]
