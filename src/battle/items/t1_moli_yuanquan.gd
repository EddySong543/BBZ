extends ItemEffect

## 魔力源泉：本回合你「防御」成功（挡下一次攻击）时 +0.5 能（守而生魔·每回合一次）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.set_item_mod(player, "block_energy", int(data.params.get("energy", 1)))
