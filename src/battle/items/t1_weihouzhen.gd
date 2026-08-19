extends ItemEffect

## 尾后针：仅本回合绑定使用时的英雄槽；无论死因，死亡时反击 2 点普通道具伤害。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	battle.add_death_retaliation(player, target, int(data.params.get("damage", 4)))
