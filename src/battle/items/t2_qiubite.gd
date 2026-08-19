extends ItemEffect

## 心脏掌握魔法：仅本回合令下一次基础攻击改为真实伤害。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "next_base_attack_true_damage", true)
