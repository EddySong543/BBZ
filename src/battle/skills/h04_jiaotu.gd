extends HeroSkill

## h04 房日【狡兔】被动 · 节奏 · 脆皮
## 上场时：① 道具锁 −1 回合（道具系统未实装 → 待接）；② 获得 +0.5 护甲（=额外血量层、生存地板）。
## 可反复上场反复触发；护甲取地板（≥1 半点 = 0.5HP，不无限叠加）。

func on_switch_in(battle: BattleCore, player: int, slot: int) -> void:
	battle.shield[player][slot] = maxi(battle.shield[player][slot], 1)   # 0.5HP = 1 半点
	# 道具锁 −1：待道具系统实装后接入
