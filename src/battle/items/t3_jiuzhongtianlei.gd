extends ItemEffect

## 九重天雷〔遗物〕：连续攻击每回合伤害 +0.5 累加（碾压），被打断 / 换动作清零。
func relic_pre(battle: BattleCore, player: int, _data: ItemData, state: Dictionary) -> void:
	var stack: int = int(state.get("stack", 0))
	if stack > 0:
		battle.add_item_mod(player, "atk_bonus", stack)

func relic_end(battle: BattleCore, player: int, _data: ItemData, state: Dictionary) -> bool:
	if ActionDef.is_attack(battle.selected_action[player]):
		state["stack"] = int(state.get("stack", 0)) + 1
	else:
		state["stack"] = 0   # 打断 / 换动作 → 清零
	return true
