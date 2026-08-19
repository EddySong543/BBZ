extends ItemEffect

## 双生咒符：下一次基础攻击增加整次总伤害，并额外触发命中效果。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 2)))
	battle.add_item_mod(player, "whole_attack_extra_hit_effects", int(data.params.get("triggers", 1)))
