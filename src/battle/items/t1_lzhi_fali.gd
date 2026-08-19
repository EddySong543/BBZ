extends ItemEffect

## 劣质法力药水：本回合若你「攒」，额外 +1 能量。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 1)))


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 1)))
