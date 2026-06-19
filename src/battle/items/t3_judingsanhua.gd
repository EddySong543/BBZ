extends ItemEffect

## 聚鼎三花〔遗物·3 充〕：你每次攻击额外多 1 次命中（伤害不变），3 次攻击后散。
func relic_pre(battle: BattleCore, player: int, data: ItemData, _state: Dictionary) -> void:
	battle.add_item_mod(player, "extra_hits", int(data.params.get("hits", 1)))

func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary) -> bool:
	if ActionDef.is_attack(battle.selected_action[player]):
		var used: int = int(state.get("used", 0)) + 1
		state["used"] = used
		return used < int(data.params.get("charges", 3))
	return true
