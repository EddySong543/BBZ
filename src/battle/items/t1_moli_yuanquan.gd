extends ItemEffect

## 盗版太极图：本回合成功防御时获得 1 能量。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "block_energy", int(data.params.get("energy", 2)))
