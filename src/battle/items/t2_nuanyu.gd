extends ItemEffect

## 暖玉：你「防御」回合回 1.0 HP（绑防御 = 反 stall）。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	if battle.selected_action[player] in ActionDef.DEFEND_ACTIONS:
		battle._heal(player, target, int(data.params.get("heal", 2)))
