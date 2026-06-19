extends ItemEffect

## 藤蔓陷阱：对手本回合若「切换」，被换下者受 0.5 伤（延迟结算·非真伤·punish 切换）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if battle.item_debuff_blocked(opp):
		return
	if battle.selected_action[opp] == ActionDef.Action.SWITCH:
		var leaver: int = battle.active_index[opp]
		battle.pending_damage[opp][leaver] += int(data.params.get("dmg", 1))
