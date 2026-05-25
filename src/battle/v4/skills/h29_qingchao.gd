extends HeroSkillV4

## h29 塔【倾巢之下】被动 · 单英雄（溢出作用对手剩余队友）
## 塔【直接击杀】对手出战英雄时，溢出伤害（造成-被杀者剩余HP）平均分摊给对手剩余存活队友。
## Q5：溢出致死【不】再触发塔 splash（on_kill 只对直接攻击触发，splash 直接扣血不归因）。
## Q5b：平均分摊、落 0.5 档；除不尽时余量给靠前替补（守恒、确定）。

func on_kill(victim_player: int, victim_slot: int, overkill: int, battle: BattleEngineV4, _player: int, _slot: int) -> void:
	if overkill <= 0:
		return
	var targets: Array[int] = []
	for s in range(battle.hp[victim_player].size()):
		if s != victim_slot and battle.hp[victim_player][s] > 0:
			targets.append(s)
	var n: int = targets.size()
	if n == 0:
		return
	var each: int = overkill / n
	var rem: int = overkill % n
	for i in range(n):
		var amt: int = each + (1 if i < rem else 0)
		if amt > 0:
			battle.hp[victim_player][targets[i]] -= amt   # splash 直接扣
