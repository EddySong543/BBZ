extends ItemEffect

## 扭曲的饥渴：整次基础攻击命中后治疗全队存活英雄；每次攻击最多结算一次。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_base_attack_aftereffect(player, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, _events: Array) -> void:
	if not bool(context.get("connected", false)):
		return
	var amount: int = int(data.params.get("heal", 2))
	for slot in range(battle.hp[player].size()):
		if battle.hp[player][slot] > 0:
			battle._heal(player, slot, amount)
