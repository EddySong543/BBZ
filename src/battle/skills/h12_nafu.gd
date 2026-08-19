extends HeroSkill

## h12 室火【祸兮福倚】被动 · 能量 · 坦克(HP7)
## 室火受到伤害落 HP 时，己方能量池 +一半（1:2，受 N 半点伤 → +N/2 半能·向下取整；吃苦换福）。
## 引擎 on_self_damaged 在落 HP 后调用（dealt = 实际掉的半点血）。
## 2026-07-05 平衡批②：1:1 → 1:2（510 局验收卷 65.7%/n=108 新头部——1:1 时"波打它=白给 1 能"，
##   对攻击方是 2 能摆动的重税 + HP7 墙绕不开；折半保机制身份、只砍税率。Eddy 批 A 案）。

func on_self_damaged(battle: BattleCore, player: int, _slot: int, dealt: int, _attacker_player: int) -> void:
	if dealt <= 1:
		return   # 0.5 伤（1 半点）不足 2 半点起转，向下取整为 0
	battle._gain_energy(player, dealt / 2, false)
