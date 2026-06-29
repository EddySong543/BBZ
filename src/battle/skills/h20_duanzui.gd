extends HeroSkill

## h20 触邪【圣剑·断罪】主动技 · 状态 · HP5（圣斗士修罗·羊角圣剑·刚猛剑士）
## 主动技「断罪」(占动作·费 2 能·每局 cap 2)：以圣剑给敌方出战烙下「断罪印」——
##   印记目标【出战时】血量被压到 ≤ 阈值(BattleCore.DUANZUI_THRESHOLD = 1.0HP) 时，立即被斩杀(处决)。
##   印记跟身、不自动清；换下场可【暂避】(只在出战时检查)、换回来又悬着。处决走死亡结算(还魂仍可拦)。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 状态（持续的"死亡条件"印记·跨回合）。暗批 round 2 维度配额：填【状态】第 2 格(暗蛇缠绕为第1)。
##   主动技（Eddy 2026-06-22：暗批几乎全被动·主动当常规选项）——占动作+费能+cap，不超模、有抉择(何时烙/烙谁)。
##   为何宽 combo（roster 首个"处决"·收割端）：全队把印记目标往阈值线上压(蛇毒/集火/践踏/任意 chip)→ 到线即斩；
##     每一点伤害都在喂这把刀 = 极宽；区别于一堆 setup 英雄，这是 payoff/收割节点。
##   yomi：对手被烙印后必须 回血抬出阈值 / 换人甩印(暂避) / 抢杀羊 / race，否则随时被斩——持续死亡威胁逼对手改打法。
##   直觉一眼不同（第3关）：主动挥剑、给对手判死刑的"断罪剑士"·和谁都不像（修罗·圣剑·审判感）。
##   旋钮：处决阈值(起手 1.0HP·强了再降) / 费 2 能 / cap 2。

const COST := 4   # 4 半能 = 2 能


func has_active() -> bool:
	return true

func active_action_id() -> String:
	return "duanzui"

func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return COST

func active_per_game_cap() -> int:
	return 2

func can_use_active(battle: BattleCore, player: int, _slot: int) -> bool:
	return battle.hp[1 - player][battle.active_index[1 - player]] > 0   # 敌方出战存活才好烙印

func execute_active(battle: BattleCore, player: int, _slot: int) -> void:
	var e: int = 1 - player
	battle.set_status(e, battle.active_index[e], "duanzui", 1)   # 给敌方出战烙断罪印
