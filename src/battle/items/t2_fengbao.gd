extends ItemEffect

## 瓶装风暴：你「防御」后，下回合攻击 +0.5（防→攻导出·跨回合·非反弹）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if battle.selected_action[player] in ActionDef.DEFEND_ACTIONS:
		battle.item_buffs[player]["next_atk_bonus"] = int(data.params.get("bonus", 1))
