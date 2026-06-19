extends ItemEffect

## 续命香〔遗物·3 充〕：持有期间每回合 +0.5 HP，持续 3 回合。
func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary) -> bool:
	battle._heal(player, battle.active_index[player], int(data.params.get("heal", 1)))
	var used: int = int(state.get("used", 0)) + 1
	state["used"] = used
	return used < int(data.params.get("turns", 3))
