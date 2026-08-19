extends ItemEffect

## 秘银充能护手：整次基础攻击命中后获得能量；每次攻击最多结算一次。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_base_attack_aftereffect(player, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, _events: Array) -> void:
	if not bool(context.get("connected", false)):
		return
	battle._gain_energy(player, int(data.params.get("energy", 3)))
