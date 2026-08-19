extends ItemEffect

## 血魔的獠牙：下一次基础攻击命中后，按整次攻击实际造成的伤害回复（含护盾损失）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_base_attack_aftereffect(player, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		_data: ItemData, _events: Array) -> void:
	var slot: int = int(context.get("source_slot", battle.active_index[player]))
	if bool(context.get("connected", false)) and battle.hp[player][slot] > 0:
		battle._heal(player, slot, int(context.get("damage_total", 0)))
