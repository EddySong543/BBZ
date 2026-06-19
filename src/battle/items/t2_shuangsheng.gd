extends ItemEffect

## 双生咒符：你本回合攻击的命中次数 +1（多触发一次 on-hit，伤害不变·泛连携放大）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "extra_hits", int(data.params.get("hits", 1)))
