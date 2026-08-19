extends ItemEffect

## 先手：本回合下一次基础攻击的总伤害 +1。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 2)))
