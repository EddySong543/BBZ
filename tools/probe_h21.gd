## h21 枭阳【调虎离山】AI 用后率查案探针（批④·Eddy 批）：
##   godot --headless --path <项目根> --script res://tools/probe_h21.gd
## 方法：构造代表性局面 → 镜像 choose_action 根求解 → 读混合策略里 ACTIVE 的概率质量。
## 回答：搜索"不按"是接线坏了，还是它算出来真不值。
extends SceneTree

const HERO_DIR := "res://assets/data/heroes/"


func _hero(id: String) -> HeroData:
	return load(HERO_DIR + id + ".tres") as HeroData


func _mk(p0_ids: Array, p1_ids: Array, seed_v: int, e0: int, e1: int) -> BattleCore:
	var t0: Array = []
	for id: String in p0_ids:
		t0.append(_hero(id))
	var t1: Array = []
	for id: String in p1_ids:
		t1.append(_hero(id))
	var b := BattleCore.new()
	b.setup(t0, t1, seed_v)
	b.energy = [e0, e1]
	return b


func _act_name(entry: Dictionary) -> String:
	var a: int = int(entry["action"])
	if a == ActionDef.ACTIVE:
		return "主动技(揪槽%d)" % int(entry["target"])
	match a:
		ActionDef.Action.CHARGE: return "攒"
		ActionDef.Action.ATTACK: return "波"
		ActionDef.Action.DEFEND: return "防"
		ActionDef.Action.BIG_ATTACK: return "大波"
		ActionDef.Action.BIG_DEFEND: return "大防"
		ActionDef.Action.SWITCH: return "切换(槽%d)" % int(entry["target"])
	return "?%d" % a


## 镜像 choose_action 根求解，返回 {mass_active, top:[[name,prob]...]}
func _root_strategy(b: BattleCore, player: int) -> Dictionary:
	var ai := BattleAI.new(20260706, 2, 0)
	var opp: int = 1 - player
	var my: Array = b.legal_actions(player)
	var opp_acts: Array = b.legal_actions(opp)
	var payoff: Array = []
	for i: int in my.size():
		var row: Array[float] = []
		for j: int in opp_acts.size():
			row.append(ai._value_after(b, player, opp, my[i], opp_acts[j], ai.search_depth - 1))
		payoff.append(row)
	var strat: Array[float] = ai._solve_mixed(payoff, my.size(), opp_acts.size(), BattleAI.RM_ITERS_ROOT)
	var mass_active: float = 0.0
	var pairs: Array = []
	for i: int in my.size():
		pairs.append([_act_name(my[i]), strat[i]])
		if int(my[i]["action"]) == ActionDef.ACTIVE:
			mass_active += strat[i]
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	return {"mass": mass_active, "top": pairs.slice(0, 4)}


func _report(title: String, b: BattleCore) -> void:
	var r: Dictionary = _root_strategy(b, 0)
	var tops: Array = []
	for p: Array in r["top"]:
		tops.append("%s %.0f%%" % [String(p[0]), float(p[1]) * 100.0])
	print("  %s\n    主动技概率质量 = %.1f%%   前 4：%s" % [title, float(r["mass"]) * 100.0, " | ".join(tops)])


func _init() -> void:
	print("=== h21 调虎离山 探针（深度2·v1·根策略概率）===")
	# S1 基线：枭阳出战·双方健康·能量都够（4 能）
	var s1 := _mk(["h21", "h05", "h03"], ["h16", "h19", "h09"], 7, 8, 8)
	_report("S1 基线（敌全健康·双方 4 能）", s1)
	# S2 软柿子：敌替补槽1 残血 0.5HP（揪上来一波带走）
	var s2 := _mk(["h21", "h05", "h03"], ["h16", "h19", "h09"], 7, 8, 8)
	s2.hp[1][1] = 1
	_report("S2 敌替补残血 0.5HP（斩杀窗）", s2)
	# S3 配穷追：我方带娄金 h11（敌切换→2 真伤·揪+切回=双触发）
	var s3 := _mk(["h21", "h11", "h05"], ["h16", "h19", "h09"], 7, 8, 8)
	_report("S3 我方带娄金穷追（切换惩罚 combo）", s3)
	# S4 穷追+软柿子 双合流
	var s4 := _mk(["h21", "h11", "h05"], ["h16", "h19", "h09"], 7, 8, 8)
	s4.hp[1][2] = 1
	_report("S4 穷追+敌替补残血 双合流", s4)
	# S5 敌能量枯竭（切回去也得白挨打·揪最划算的时机?）
	var s5 := _mk(["h21", "h05", "h03"], ["h16", "h19", "h09"], 7, 8, 0)
	s5.hp[1][1] = 1
	_report("S5 敌 0 能+替补残血（无反抗窗）", s5)
	# S6 我方 2 能整（刚好付得起技能·机会成本最大化）
	var s6 := _mk(["h21", "h05", "h03"], ["h16", "h19", "h09"], 7, 4, 8)
	s6.hp[1][1] = 1
	_report("S6 我方仅 2 能+敌替补残血", s6)
	print("=== 探针结束 ===")
	quit(0)
