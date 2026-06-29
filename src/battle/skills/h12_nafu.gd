extends HeroSkill

## h12 室火【祸兮福倚】被动 · 能量 · 坦克(HP7)
## 室火受到伤害落 HP 时，己方能量池 +等量（1:1，受 N 半点伤 → +N 半能；吃苦换福）。
## 引擎 on_self_damaged 在落 HP 后调用（dealt = 实际掉的半点血）。

func on_self_damaged(battle: BattleCore, player: int, _slot: int, dealt: int, _attacker_player: int) -> void:
	if dealt <= 0:
		return
	battle.energy[player] = mini(battle.energy[player] + dealt, ActionDef.MAX_ENERGY)
