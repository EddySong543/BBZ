extends HeroSkill

## h04 房日【灵跃藏锋】被动 · 节奏 · 脆皮
## 上场时：① 道具锁 −1（少挡一次封印/天罗地网的封锁、机灵挣脱）；② 获得 +0.5 护甲（=额外血量层、生存地板）。
## 可反复上场反复触发；护甲取地板（≥1 半点 = 0.5HP，不无限叠加）；道具锁取地板 0（无锁时不变负）。

func on_switch_in(battle: BattleCore, player: int, slot: int) -> void:
	battle.shield[player][slot] = maxi(battle.shield[player][slot], 1)   # 0.5HP = 1 半点
	var lock: int = int(battle.item_buffs[player].get("item_lock", 0))   # 道具锁 −1：上场挣脱一层封锁
	if lock > 0:
		battle.item_buffs[player]["item_lock"] = lock - 1
