extends ItemEffect

## 最后一箭：下一次基础攻击总伤害 +1.5；未击败目标则攻击者失去 1 生命。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	battle.add_item_mod(player, "base_attack_total_bonus", int(data.params.get("bonus", 3)))
	battle.add_base_attack_aftereffect(player, data)


func on_base_attack_resolved(battle: BattleCore, player: int, context: Dictionary,
		data: ItemData, events: Array) -> void:
	if bool(context.get("target_defeated", false)):
		return
	var slot: int = int(context.get("source_slot", battle.active_index[player]))
	var loss: int = int(data.params.get("backlash", 2))
	battle.lose_life(player, slot, loss, events, "last_arrow")
