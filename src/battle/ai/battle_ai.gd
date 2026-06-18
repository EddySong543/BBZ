class_name BattleAI
extends RefCounted

## 同时博弈短时最优 AI（v2，2026-05-30：剪枝 depth-2 + 适中评估）。
##
## 本游戏双方"同时盲选"→ 每一步是零和矩阵博弈，最优 = 纳什混合策略。
##   1. 对每个 (我方动作 i, 对手动作 j) 克隆战局、结算、**递归求子局价值**（depth>1 时再展开一层）。
##   2. regret-matching 解出我方混合策略（带概率，抗剥削）。
##   3. 按概率抽样动作。
##
## v2 加"一定深度"（默认 depth=2）：子局不再用静态评估，而是再解一层 1-ply 子博弈取其博弈值
##   → AI 能看到"这回合攒/铺垫、下回合收益"和"别同归于尽"，从而会用主动技、减少换死平局、缩短对局。
## 为控成本，深层用动作短名单（_shortlist）剪枝 + 较少迭代。
## depth=1 时退化为纯 1-ply（= v1 行为）。

const RM_ITERS_ROOT := 600    # 根节点 regret-matching 迭代（出抽样策略，要准）
const RM_ITERS_INNER := 120   # 深层节点迭代（只取博弈值，近似即可）
const STOCHASTIC_SAMPLES := 3 # 随机技（h13/h23）格的多采样次数 → 按期望值判断、去运气噪声（T3）
## 终局贴现（2026-06-18·B 选项）：只对【终局胜负】按"已推演步数"贴现——
## 立刻锁定的胜局 > 拖几回合才赢的同一胜局；同一败局拖得越晚越不糟。
## 仅作用于 ±W_WIN 终局值（远大于任何启发评估），故胜局恒压一切、只在"同为胜"时偏好更快那手；
## 非终局启发评估【不贴现】→ 不动已校准的局面权重。
const WIN_DISCOUNT := 0.95

var search_depth: int = 2
var eval_profile: int = 0   # 0=基础评估(v2) / 1=v3 牌感评估(熟练优秀玩家)
var weights: Dictionary = {} # 评估权重覆盖（空=用默认常量）；A/B 校准用（T1）
var rng := RandomNumberGenerator.new()        # 动作抽样
var _eval_rng := RandomNumberGenerator.new()  # 推演重播种：解除"预知真实 rng 未来"的透视


func _init(seed_value: int = 0, depth: int = 2, profile: int = 0, weight_overrides: Dictionary = {}) -> void:
	var s: int = seed_value if seed_value != 0 else randi()
	rng.seed = s
	_eval_rng.seed = s ^ 0x9E3779B9
	search_depth = maxi(depth, 1)
	eval_profile = profile
	weights = weight_overrides


## 为 player 选一个动作。返回 {action:int, target:int}。
func choose_action(b: BattleCore, player: int) -> Dictionary:
	var opp: int = 1 - player
	var my: Array = b.legal_actions(player)
	if my.is_empty():
		return {action = ActionDef.Action.CHARGE, target = -1}
	if my.size() == 1:
		return my[0]
	var opp_acts: Array = b.legal_actions(opp)
	if opp_acts.is_empty():
		opp_acts = [{action = ActionDef.Action.CHARGE, target = -1}]

	var n: int = my.size()
	var m: int = opp_acts.size()
	var payoff: Array = []
	for i in range(n):
		var row: Array[float] = []
		for j in range(m):
			row.append(_value_after(b, player, opp, my[i], opp_acts[j], search_depth - 1))
		payoff.append(row)

	var strat: Array[float] = _solve_mixed(payoff, n, m, RM_ITERS_ROOT)
	return my[_sample(strat)]


## 出战阵亡后选替补上场：**对位感知**——模拟换入每个替补 + 前瞻下一轮交手，选局面最优者
## （而非只看血量）。复用 _state_value 深搜机器；search_depth=1 时退化为静态评估(=旧血量行为)。
func choose_death_switch(b: BattleCore, player: int) -> int:
	var best := -1
	var best_score := -INF
	for slot in range(b.hp[player].size()):
		if b.hp[player][slot] > 0 and slot != b.active_index[player]:
			var sim := b.clone()
			sim.execute_death_switch(player, slot)
			_auto_death_switch(sim)   # 解析对手可能的同时阵亡换人 → 干净决策态
			var sc := _state_value(sim, player, search_depth - 1)
			if sc > best_score:
				best_score = sc
				best = slot
	return best


# === 搜索 ===

## 局面评估分派：profile 1 用 v3 牌感评估，否则基础评估。权重覆盖透传（T1 校准）。
func _eval(b: BattleCore, p: int) -> float:
	return BattleEvalV3.score(b, p, weights) if eval_profile == 1 else BattleEval.score(b, p, weights)


## 提交 (我=ca, 对手=cb) 结算一回合后，从 player 视角的子局价值（递归 depth 层）。
## 随机技（h13/h23）格：多次采样取均值 → 按期望值判断、去运气噪声（T3）。
## 仅对真消耗 rng 的格多采样（结算后比对 rng 状态检测）；确定性格 1 次即精确，零额外开销。
func _value_after(b: BattleCore, player: int, opp: int, ca: Dictionary, cb: Dictionary, depth: int) -> float:
	var first: Dictionary = _rollout_once(b, player, opp, ca, cb, depth)
	if not first["stochastic"]:
		return first["value"]
	var total: float = first["value"]
	for _k in range(STOCHASTIC_SAMPLES - 1):
		total += float(_rollout_once(b, player, opp, ca, cb, depth)["value"])
	return total / float(STOCHASTIC_SAMPLES)


## 单次推演：克隆 → 重播种(随机技独立采样，不预知真实未来) → 结算 → 子局价值。
## 返回 {value:float, stochastic:bool}（stochastic = 本格结算/补位是否消耗了 rng）。
## 非法组合兜底 / 终局 / 空动作集 均走 _eval 分派。
func _rollout_once(b: BattleCore, player: int, opp: int, ca: Dictionary, cb: Dictionary, depth: int) -> Dictionary:
	var sim := b.clone()
	sim.rng.seed = _eval_rng.randi()
	var rng_before: int = sim.rng.state
	sim.apply_choice(player, ca)
	sim.apply_choice(opp, cb)
	if not sim.both_ready():
		return {value = _eval(b, player), stochastic = false}
	sim.resolve()
	_auto_death_switch(sim)            # 自动补位 → 子局是干净的决策态
	var stochastic: bool = sim.rng.state != rng_before
	return {value = _state_value(sim, player, depth), stochastic = stochastic}


## 从 perspective 视角评估状态：终局/深度耗尽 → 静态评估；否则解一层子博弈取博弈值。
func _state_value(b: BattleCore, perspective: int, depth: int) -> float:
	if b.game_over:
		# 终局按已推演步数(search_depth-depth)贴现 → 越早的胜局越值钱、越晚的败局越不糟
		return _eval(b, perspective) * pow(WIN_DISCOUNT, float(search_depth - depth))
	if depth <= 0:
		return _eval(b, perspective)
	var opp: int = 1 - perspective
	var my: Array = _shortlist(b, perspective)
	var opp_acts: Array = _shortlist(b, opp)
	var n: int = my.size()
	var m: int = opp_acts.size()
	if n == 0 or m == 0:
		return _eval(b, perspective)
	var payoff: Array = []
	for i in range(n):
		var row: Array[float] = []
		for j in range(m):
			row.append(_value_after(b, perspective, opp, my[i], opp_acts[j], depth - 1))
		payoff.append(row)
	var strat: Array[float] = _solve_mixed(payoff, n, m, RM_ITERS_INNER)
	return _security_value(payoff, strat, n, m)


## 深层剪枝：返回代表性动作集（攒 / 波 / 大波 / 防 / 大防 / 主动技 / 最优切换，仅合法可负担者）。
## T4 放宽：波与大波、防与大防均【独立】纳入（不再只留最大档）→ 深层能完整考虑攻防克制 RPS
## （波被"防"挡、大波被"大防"挡，错配则穿）。深层矩阵 ~5×5→~7×7（约 2× 慢），换取深层评估更全面。
func _shortlist(b: BattleCore, player: int) -> Array:
	var out: Array = []
	out.append({action = ActionDef.Action.CHARGE, target = -1})   # 攒恒合法
	for a in [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK,
			ActionDef.Action.DEFEND, ActionDef.Action.BIG_DEFEND]:
		if b.can_afford(player, a) and not b.is_action_disabled(player, a):
			out.append({action = a, target = -1})
	if b.can_use_active(player):
		out.append({action = ActionDef.ACTIVE, target = -1})
	# 最优切换（换到血最高替补）
	var best_sw := -1
	var best_hp := -1
	for s in b.living_reserves(player):
		if b.hp[player][s] > best_hp:
			best_hp = b.hp[player][s]
			best_sw = s
	if best_sw >= 0:
		out.append({action = ActionDef.Action.SWITCH, target = best_sw})
	return out


## 子局结算后若有出战阵亡待补 → 用高血替补自动补位（便宜规则，不递归）。
func _auto_death_switch(b: BattleCore) -> void:
	for p in [0, 1]:
		if b.pending_death_switch[p]:
			var best := -1
			var best_hp := -1
			for s in range(b.hp[p].size()):
				if b.hp[p][s] > 0 and s != b.active_index[p] and b.hp[p][s] > best_hp:
					best_hp = b.hp[p][s]
					best = s
			if best >= 0:
				b.execute_death_switch(p, best)


# === 零和矩阵博弈求解（regret-matching）===

## 返回行玩家（我方）平均混合策略（长度 n，和为 1）。
func _solve_mixed(payoff: Array, n: int, m: int, iters: int) -> Array[float]:
	var reg_row: Array[float] = _zeros(n)
	var reg_col: Array[float] = _zeros(m)
	var sum_row: Array[float] = _zeros(n)
	for _t in range(iters):
		var p_row: Array[float] = _regret_to_strategy(reg_row, n)
		var p_col: Array[float] = _regret_to_strategy(reg_col, m)
		for i in range(n):
			sum_row[i] += p_row[i]
		var u_row: Array[float] = _zeros(n)
		var val_row := 0.0
		for i in range(n):
			var u := 0.0
			for j in range(m):
				u += payoff[i][j] * p_col[j]
			u_row[i] = u
			val_row += p_row[i] * u
		for i in range(n):
			reg_row[i] += u_row[i] - val_row
		var u_col: Array[float] = _zeros(m)
		var val_col := 0.0
		for j in range(m):
			var u := 0.0
			for i in range(n):
				u += -payoff[i][j] * p_row[i]
			u_col[j] = u
			val_col += p_col[j] * u
		for j in range(m):
			reg_col[j] += u_col[j] - val_col
	return _normalize(sum_row, n)


## 给定我方策略的安全（保证）值 = min_j Σ_i p_row[i]·payoff[i][j]，作为父节点子局价值。
func _security_value(payoff: Array, p_row: Array, n: int, m: int) -> float:
	var worst := INF
	for j in range(m):
		var col := 0.0
		for i in range(n):
			col += p_row[i] * payoff[i][j]
		worst = minf(worst, col)
	return worst if worst != INF else 0.0


func _regret_to_strategy(regret: Array, k: int) -> Array[float]:
	var s: Array[float] = _zeros(k)
	var pos_sum := 0.0
	for i in range(k):
		if regret[i] > 0.0:
			s[i] = regret[i]
			pos_sum += regret[i]
	if pos_sum > 0.0:
		for i in range(k):
			s[i] /= pos_sum
	else:
		for i in range(k):
			s[i] = 1.0 / float(k)
	return s


func _normalize(v: Array, k: int) -> Array[float]:
	var total := 0.0
	for i in range(k):
		total += v[i]
	var out: Array[float] = _zeros(k)
	if total > 0.0:
		for i in range(k):
			out[i] = v[i] / total
	else:
		for i in range(k):
			out[i] = 1.0 / float(k)
	return out


func _sample(strat: Array) -> int:
	var r := rng.randf()
	var acc := 0.0
	for i in range(strat.size()):
		acc += strat[i]
		if r <= acc:
			return i
	return strat.size() - 1


func _zeros(k: int) -> Array[float]:
	var a: Array[float] = []
	a.resize(k)
	a.fill(0.0)
	return a
