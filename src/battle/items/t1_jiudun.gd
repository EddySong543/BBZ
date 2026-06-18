extends ItemEffect

## 破旧的护盾：己方出战 +0.5 甲（额外血量层，先扣甲后扣血；真伤无视）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.shield[player][target] += int(data.params.get("armor", 1))
