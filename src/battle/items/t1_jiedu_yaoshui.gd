extends ItemEffect

func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var cleared: bool = false
	if int(battle.get_status(player, target, "poison", 0)) > 0:
		battle.statuses[player][target].erase("poison")
		cleared = true
	elif int(battle.get_status(player, target, "vuln", 0)) > 0:
		battle.statuses[player][target].erase("vuln")
		cleared = true
	if cleared:
		battle._heal(player, target, int(data.params.get("heal", 2)))
