extends HeroSkill

## h21 枭阳【惊蛰】主动技 · 干扰 · HP4（精准设局·目标选择）
## 主动技「惊蛰」(占动作·费 2 能·每局 cap 2·须亲自出战)：强制对手换人，把对手藏在后排的英雄
##   揪到台前，并取消原出战英雄尚未结算的基础行动；已支付的行动能量不返还。
## 2026-08-31 方案 A：由旧版 1 能纯换人调整为 2 能控制。取消只覆盖尚未执行的
##   攒/波/防/大波/大防；已经完成的切换或主动技不倒退，也不追加伤害或锁换人。
##
## 引擎实现（与打神鞭强制切换同语义·独立计揪）：
##   execute_active 在对手身上调 BattleCore.request_forced_pull(敌方, 揪目标槽)；
##   resolve Phase 2.7 在切换之后、伤害之前执行 _perform_switch(敌方, 出战→揪目标) →
##   被揪英雄成为对手出战，并由核心撤销受害方尚未结算的基础行动。
##   影狩只在娄金出战时监听；枭阳发动本技能时娄金在替补，二者不联动。
##   目标 = 玩家指定的对手存活替补(UI 点选敌方替补框·battle.active_target 读)；
##   指定目标已死 / 无效 → 作废(不改揪别人)；未指定(AI / 未选) → 随机揪一个存活替补(battle.rng·确定性)。（Eddy 2026-07-02 定）
##
## 设计依据（design/heroes.md）：主定位=控制·共享原语=目标选择。是暗蛇阴阳对子(蛇锁原地/猴拽出)。
##   cap：占动作 + 费 2 能 + 每局 2 次 + 须出战(暴露 HP4 脆皮)。对手出口=摊平血量/速攻点死猴/换回去。

const COST := 4   # 4 半能 = 2 能（2026-08-31 方案 A）


func has_active() -> bool:
	return true


func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST


func active_per_game_cap() -> int:
	return 2


func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	# 对手须有【存活替补】才能揪（对手只剩 1 个出战 → 无人可调虎离山）。
	return battle.living_reserves(1 - player).size() > 0


func active_needs_enemy_target() -> bool:
	return true   # UI 点选敌方存活替补作揪目标（未选 → execute_active 随机揪）


func active_preempts_enemy_basic_action() -> bool:
	return true


func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	var reserves := battle.living_reserves(e)
	if reserves.is_empty():
		return   # 对手无存活替补（can_use_active 已挡·此处防御）
	var pick: int = battle.active_target(player)   # 玩家指定的敌方替补槽（-1=未指定）
	if pick >= 0:
		# 玩家指定：目标须仍是存活替补才揪；已死 / 无效 → 作废（不改揪别人·Eddy 2026-07-02）。
		if pick in reserves:
			battle.request_forced_pull(e, pick)
	else:
		# 未指定（玩家未选 / AI）→ 随机揪一个存活替补（battle.rng·确定性可复现·Eddy 2026-07-02）。
		battle.request_forced_pull(e, reserves[battle.rng.randi() % reserves.size()])
