extends ItemEffect

## 坚固的护盾：己方出战 +1.0 甲（额外血量层；护盾升级线 T2）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.shield[player][target] += int(data.params.get("armor", 2))
