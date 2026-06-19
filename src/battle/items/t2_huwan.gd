extends ItemEffect

## 秘银护腕：弃 1 能 → +1.0 甲（能→防导出·盾狗能量流）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var cost: int = int(data.params.get("cost", 2))
	if battle.energy[player] >= cost:
		battle.energy[player] -= cost
		battle.shield[player][target] += int(data.params.get("armor", 2))
