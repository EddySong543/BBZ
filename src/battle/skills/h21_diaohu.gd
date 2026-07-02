extends HeroSkill

## h21 枭阳【惊蛰】主动技 · 干扰 · HP4（精准设局·目标选择）
## 主动技「调虎离山」(占动作·费 2 能·每局 cap 2·须亲自出战)：强制对手换人，把对手藏在后排的英雄
##   揪到台前 → 作废"出战保护"、使能你方整条进攻线（集火脆皮 carry / 触发光狗穷追 / 配暗蛇钳形）。
##
## 引擎实现（与打神鞭强制切换同语义·独立计揪）：
##   execute_active 在对手身上调 BattleCore.request_forced_pull(敌方, 揪目标槽)；
##   resolve Phase 2.7 在切换之后、伤害之前执行 _perform_switch(敌方, 出战→揪目标) →
##   被揪英雄成为对手出战(本回合攻击落它身上)、原出战下场触发我方 on_enemy_switch_out(穷追)。
##   目标默认 = 对手存活替补中血量最低者(脆皮 carry·并列取槽小=确定性)；玩家指定 UI 后续接入。
##
## 设计依据（design/heroes-dark-h21-h24.md）：维度=干扰·共享原语=目标选择。是暗蛇阴阳对子(蛇锁原地/猴拽出)。
##   cap：占动作 + 费 2 能 + 每局 2 次 + 须出战(暴露 HP4 脆皮)。对手出口=摊平血量/速攻点死猴/换回去。

const COST := 4   # 4 半能 = 2 能


func has_active() -> bool:
	return true


func active_action_id() -> String:
	return "diaohu"


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	# 对手须有【存活替补】才能揪（对手只剩 1 个出战 → 无人可调虎离山）。
	return battle.living_reserves(1 - player).size() > 0


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	# 默认揪对手存活替补中血量最低者（脆皮 carry）；并列取槽位小者（确定性·联机可复现）。
	var target := -1
	var best_hp := 0
	for s in battle.living_reserves(e):
		if target < 0 or battle.hp[e][s] < best_hp:
			best_hp = battle.hp[e][s]
			target = s
	if target >= 0:
		battle.request_forced_pull(e, target)
