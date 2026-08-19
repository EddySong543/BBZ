extends ItemEffect

## 暖玉：成功防御后，所有存活英雄各回复 1 点生命。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "t2_block_team_heal", int(data.params.get("heal", 2)))
