extends ItemEffect

## 不死鸟的余烬：若你出战 HP ≤ 1.0，这次攻击 +3.0 伤穿大防（背水一战·gate 在濒死公开 condition）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	if not ActionDef.is_attack(battle.selected_action[player]):
		return
	if battle.hp[player][battle.active_index[player]] <= int(data.params.get("threshold", 2)):
		battle.add_item_mod(player, "atk_bonus", int(data.params.get("bonus", 6)))
		battle.set_item_mod(player, "atk_pen", ActionDef.Pen.PIERCE_BIGDEF)
