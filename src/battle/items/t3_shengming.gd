extends ItemEffect

## 上等生命药水：己方出战回 2.0 HP（药水线顶·安全大回复）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle._heal(player, target, int(data.params.get("heal", 4)))
