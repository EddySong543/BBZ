extends ItemEffect

## 劣质法力药水：本回合若你「攒」，额外 +0.5 能（喂鼠 / 魔术师）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] == ActionDef.Action.CHARGE:
		battle._gain_energy(player, int(data.params.get("energy", 1)))
