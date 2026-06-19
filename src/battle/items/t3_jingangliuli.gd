extends ItemEffect

## 金刚琉璃体〔遗物·3 充〕：持有期间每回合末自动 +0.5 甲（额外血量层），3 充后碎。
## 注：design 的"护甲层上限 +1"暂无护甲上限系统，本实装只落每回合 +甲（待上限系统再补）。
func relic_end(battle: BattleCore, player: int, data: ItemData, state: Dictionary) -> bool:
	battle.shield[player][battle.active_index[player]] += int(data.params.get("armor", 1))
	var used: int = int(state.get("used", 0)) + 1
	state["used"] = used
	return used < int(data.params.get("charges", 3))
