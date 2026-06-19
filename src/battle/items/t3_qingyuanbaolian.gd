extends ItemEffect

## 青元宝莲〔遗物·3 充〕：持有期间每回合自动 +0.5 能，3 回合后消失。
func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary) -> bool:
	battle._gain_energy(player, int(data.params.get("energy", 1)))
	var used: int = int(state.get("used", 0)) + 1
	state["used"] = used
	return used < int(data.params.get("turns", 3))
