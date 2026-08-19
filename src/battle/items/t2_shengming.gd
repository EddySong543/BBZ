extends ItemEffect

## 普通生命药水：己方出战英雄回复生命。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle._heal(player, target, int(data.params.get("heal", 4)))
