extends ItemEffect

## 普通法力药水：本回合使用「攒」时额外获得能量。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 4)))


func apply_second_pre(battle: BattleCore, player: int, _target: int, data: ItemData,
		_events: Array) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 4)))
