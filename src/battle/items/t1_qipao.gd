extends ItemEffect

## 残缺的佛像：若对手本回合「大波」且你「防」→ 你这次「防」临时升级为可挡大波一次。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	if battle.selected_action[1 - player] == ActionDef.Action.BIG_ATTACK and battle.selected_action[player] == ActionDef.Action.DEFEND:
		battle.set_item_mod(player, "def_upgrade", 1)
