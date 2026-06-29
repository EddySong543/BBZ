extends ItemEffect

## 一气：立 2 个纸扎替身，对手本回合的攻击在真身 + 替身间随机命中 → 命中真身概率 1/(替身数+1)，
## 否则落空（唯一合法"信息博弈"·赌自己·源紫火纸扎）。
func apply_pre(battle: BattleCore, player: int, _target: int, data: ItemData) -> void:
	var opp: int = 1 - player
	if not ActionDef.is_attack(battle.selected_action[opp]):
		return
	var decoys: int = int(data.params.get("decoys", 2))
	if battle.rng.randi() % (decoys + 1) != 0:
		battle.set_item_mod(opp, "atk_nullify", true)
