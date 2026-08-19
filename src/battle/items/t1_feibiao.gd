extends ItemEffect

## 生锈的暗器：对敌方出战造成 1 点伤害（走防御门 + on-hit·D1）。
func hits(_battle: BattleCore, _player: int, _target: int, data: ItemData) -> Array:
	return [{damage = int(data.params.get("dmg", 1)), kind = ActionDef.Action.ATTACK, pen = ActionDef.Pen.NORMAL}]
