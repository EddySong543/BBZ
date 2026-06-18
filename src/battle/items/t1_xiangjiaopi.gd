extends ItemEffect

## 滑不溜手的香蕉皮：对手本回合攻击 −0.5 伤（盲选赌对手出手·脚下一滑）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if not ActionDef.is_attack(battle.selected_action[opp]):
		return
	if battle.item_debuff_blocked(opp):
		return
	battle.add_item_mod(opp, "atk_penalty", int(data.params.get("penalty", 1)))
