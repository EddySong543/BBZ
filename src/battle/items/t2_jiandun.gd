extends ItemEffect

## 坚固的护盾：己方出战英雄获得护盾。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.shield[player][target] += int(data.params.get("armor", 4))
