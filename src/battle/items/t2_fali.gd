extends ItemEffect

## 普通法力药水：本回合若你「攒」，额外 +1.0 能（法力线 T2·喂鼠）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 2)))
