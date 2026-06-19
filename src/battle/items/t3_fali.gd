extends ItemEffect

## 上等法力药水：立即 +2.0 能（法力线顶·超充燃料）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle._gain_energy(player, int(data.params.get("energy", 4)))
