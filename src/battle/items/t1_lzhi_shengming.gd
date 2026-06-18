extends ItemEffect

## 劣质生命药水：己方出战回 0.5 HP（续航地板）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle._heal(player, target, int(data.params.get("heal", 1)))
