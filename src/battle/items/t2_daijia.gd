extends ItemEffect

## 力量的代价：本回合基础攻击总伤害增加2点，回合末处决当时的出战英雄。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "turn_base_attack_total_bonus", int(data.params.get("bonus", 4)))
	battle.set_item_mod(player, "strength_price_execution", true)
