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
const STOCHASTIC_SAMPLES := 3 # 随机道具（赌徒硬币/锦囊/命运骰子/疑兵）格的多采样次数 → 按期望值判断、去运气噪声（T3）
## 终局贴现（2026-06-18·B 选项）：只对【终局胜负】按"已推演步数"贴现——
## 立刻锁定的胜局 > 拖几回合才赢的同一胜局；同一败局拖得越晚越不糟。
## 仅作用于 ±W_WIN 终局值（远大于任何启发评估），故胜局恒压一切、只在"同为胜"时偏好更快那手；
## 非终局启发评估【不贴现】→ 不动已校准的局面权重。
const WIN_DISCOUNT := 0.95
## AI 道具经济（run_item_economy）补充/升级后想保留的最低能量（半能）：留一手攒/防/小波，
## 不被发展道具饿死动作。2 = 1.0 能（≥ 一次小波 cost）。
const AI_ITEM_ENERGY_RESERVE := 2
## 升级是「投资」（费能 + 锁 1 回合不能用）：AI 仅在能量【明显富余】（升级成本 + reserve 之上再留此 buffer）
## 时才升级、否则把就绪道具直接用掉；每回合最多升 1 个。buffer 越大 AI 越保守发展。2 = 1.0 能。
const AI_ITEM_UPGRADE_BUFFER := 2

var search_depth: int = 2
var plan_items: bool = true # 搜索推演里是否也跑道具经济（Part 2）：true=AI 规划会考虑未来道具发展；
                            # false=控制组（实战照常用道具、但 lookahead 当道具冻结·= 旧行为）。供 A/B 实测。
var smart_draft: bool = true # 道具 3 选 1 智能选牌（任务#6·2026-07-03）：true=启发式按局面挑 /
                             # false=纯随机（旧行为·A/B 对照组）。
var search_upgrade: bool = true # 升级择时：true=价值搜索默认(2026-07-04 T3 转正：新经济 100 局 A/B decisive 64.0%·
                                # 大波 3.6%→5.0%·数据 out_upgrade_ab_t3) / false=阈值(旧默认·"52.2%≈噪声不值 10×"
                                # 是死龟经济时代的结论·经济重做后已翻案·留作 A/B 对照开关)
var eval_profile: int = 0   # 0=v1 基础评估(现役默认) / 1=v2 进阶评估(牌感·熟练优秀玩家)
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
	# 疾风 h16：为每个可双的动作追加"附加同种"变体（root-only·让博弈搜索决定值不值得花 double）。
	if b.has_double(player):
		var doubles: Array = []
		for c in my:
			if b.can_double_action(player, int(c["action"])):
				var d: Dictionary = c.duplicate()
				d["double"] = true
				doubles.append(d)
		my += doubles
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


# === 道具经济启发（v1·非搜索）===

## 让 AI 像玩家一样操作道具栏，使试玩两边对等（sim / 测试 / 深层 lookahead 通用·纯函数·阈值升级择时）。
## 选动作【之前】调用：补充/升级立即扣能 → 动作据剩余能量决策（与玩家手动点击同语义）。
## 策略（2026-07-03 经济重做后·格自动解锁/抽免费）：
##   1. 就绪槽：能量【明显富余】(≥升级成本+reserve+buffer)→ 升级 1 个（投资·锁1回合·电报）；其余用掉。
##   2. 抽所有【可抽】已解锁槽（免费）。3. 富余能量补充 1 个空槽（每回合 ≤1）。
## ⚠ 阈值择时 = 仅靠「能量富余」近似「局面安全可投资」；**价值搜索版见 `plan_economy`（B）**。
static func run_item_economy(b: BattleCore, side: int, rng: RandomNumberGenerator,
		reserve: int = AI_ITEM_ENERGY_RESERVE, smart: bool = true) -> void:
	if side < 0 or side >= b.slots.size() or b.slots[side].size() < BattleCore.SLOT_COUNT:
		return
	_apply_economy(b, side, rng, reserve, _threshold_upgrade_slot(b, side, reserve), smart)


## 阈值升级择时：返回第一个「就绪 + 可升 + 能量明显富余(成本+reserve+buffer)」的槽；无则 -1。
static func _threshold_upgrade_slot(b: BattleCore, side: int, reserve: int) -> int:
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_ready(side, s) and b.can_upgrade(side, s) \
				and b.energy[side] >= b.upgrade_cost(side, s) + reserve + AI_ITEM_UPGRADE_BUFFER:
			return s
	return -1


## 应用一回合道具经济（机械执行·升级目标由调用方给）：
##   ① 就绪槽——upgrade_slot 那个升级、其余用掉（upgrade_slot=-1 → 全用不升）；
##   ② 抽所有可抽（免费·含到点自动解锁的格）；③ 富余能量补充 1 个空槽。
## smart=true → 3 选 1 走启发式选牌（_best_draft_choice）；false=纯随机（旧行为·A/B 对照）。
static func _apply_economy(b: BattleCore, side: int, rng: RandomNumberGenerator, reserve: int, upgrade_slot: int, smart: bool = true) -> void:
	if side < 0 or side >= b.slots.size() or b.slots[side].size() < BattleCore.SLOT_COUNT:
		return
	# 1. 就绪槽（进攻向道具按兵不动 → 攻击回合由 commit_attack_items 一并甩出）
	for s in range(BattleCore.SLOT_COUNT):
		if not b.slot_ready(side, s):
			continue
		if s == upgrade_slot and b.can_upgrade(side, s):
			var uopts: Array = b.begin_upgrade_draft(side, s)
			if not uopts.is_empty():
				b.pick_upgrade(side, s, _pick_choice(b, side, uopts, rng, smart))
				continue
		if _is_attack_item(b.slot_item(side, s)):
			continue
		b.use_slot(side, s)
	# 2. 抽可抽的槽（免费）
	for s in range(BattleCore.SLOT_COUNT):
		if b.can_draw_slot(side, s):
			var opts: Array = b.begin_draft(side, s)
			if not opts.is_empty():
				b.pick_draft(side, s, _pick_choice(b, side, opts, rng, smart))
	# 3. 富余能量补充 1 个空槽
	for s in range(BattleCore.SLOT_COUNT):
		if b.can_refill(side, s) and b.energy[side] >= BattleCore.ITEM_REFILL_COST + reserve:
			var opts2: Array = b.start_refill(side, s)
			if not opts2.is_empty():
				b.pick_draft(side, s, _pick_choice(b, side, opts2, rng, smart))
			break


## 3 选 1 出牌口：smart → 启发式最优（并列随机）；否则纯随机（旧行为）。
static func _pick_choice(b: BattleCore, side: int, opts: Array, rng: RandomNumberGenerator, smart: bool) -> int:
	if not smart:
		return rng.randi() % opts.size()
	return _best_draft_choice(b, side, opts, rng)


## 3 选 1 智能选牌（任务#6·2026-07-03·首版启发式·⚠非终态，见 [[item-system-skeleton]] 进阶加权待办）：
## 设计 EV 打底 + 局面修正。并列随机 → 保持全池覆盖、不固化套路。
static func _best_draft_choice(b: BattleCore, side: int, opts: Array, rng: RandomNumberGenerator) -> int:
	var best: Array[int] = [0]
	var best_s := -INF
	for i in range(opts.size()):
		var sc: float = score_item_option(b, side, opts[i])
		if sc > best_s + 0.001:
			best_s = sc
			best = [i]
		elif absf(sc - best_s) <= 0.001:
			best.append(i)
	return best[rng.randi() % best.size()]


## 单件道具在当前局面下的价值分（量纲对齐 BattleEval 半点 ≈10 分）。
## ⚠ 校准记录（2026-07-03）：首版"满血治疗倒扣 −8 + 强情境分"在 A/B 中输给随机（43.9%·60 局）——
##   选牌在部署锁之前、使用在 1+ 回合之后，按"当下局面"打重分 = 时机错配；
##   前期人人满血 → 系统性拒收治疗件 → 全局丢续航。v2 修正：去倒扣、情境分减半（只当轻推）。
static func score_item_option(b: BattleCore, side: int, data: ItemData) -> float:
	var s: float = float(data.ev_half) * 10.0
	var opp: int = 1 - side
	var aslot: int = b.active_index[side]
	var my_hp: int = b.hp[side][aslot]
	var opp_hp: int = b.hp[opp][b.active_index[opp]]
	match data.dimension:
		"进攻":
			if opp_hp > 0 and opp_hp <= 2 * BattleCore.HP_UNIT:
				s += 6.0    # 斩杀圈：进攻件是收割票（轻推）
		"防御":
			if data.params.has("heal"):
				if b.max_hp[side][aslot] - my_hp >= 2:
					s += 6.0   # 已掉血 → 治疗增值；满血不倒扣（用的时候多半已掉血）
			elif my_hp <= 2 * BattleCore.HP_UNIT:
				s += 6.0    # 自己进斩杀圈：护盾/挡件保命（轻推）
		"能量":
			if b.energy[side] <= 2:
				s += 4.0    # 缺能（≤1.0 能）：能量件回血线（轻推）
	if data.upgrade_to != "":
		s += 3.0            # 预设升级线 → 养成潜力
	return s


## 进攻向道具（chip 伤害 / 攻击增伤 / 命中骑乘）只在攻击回合甩出才有价值。
## 经济阶段按兵不动（见 _apply_economy），动作定为攻击后调本函数一并提交（与波/大波同吃对方防御门）。
## 修复 2026-07-03 死龟锁：免费道具流下若"每回合白扔 chip"，对手每回合都有已提交伤害 →
## 「防」恒有免费价值 → 双方全场防（冒烟 sim 防占 79%、90% 打满回合上限）。
static func commit_attack_items(b: BattleCore, side: int, action: int) -> void:
	if side < 0 or side >= b.slots.size() or b.slots[side].size() < BattleCore.SLOT_COUNT:
		return
	if not _is_attack_turn(b, side, action):
		return
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_ready(side, s) and _is_attack_item(b.slot_item(side, s)):
			b.use_slot(side, s)


## 本回合动作是否"攻击"（波/大波/攻击型主动技）——进攻向道具的甩出门。
static func _is_attack_turn(b: BattleCore, side: int, action: int) -> bool:
	if ActionDef.is_attack(action):
		return true
	if action == ActionDef.ACTIVE:
		var sk: HeroSkill = b.get_skill(side, b.active_index[side])
		return sk != null and sk.active_is_attack()
	return false


## 进攻向道具判定：维度=进攻（chip/增伤）或角色以「进攻」开头（进攻→X 导出骑乘，如血魔的獠牙）。
static func _is_attack_item(data: ItemData) -> bool:
	return data != null and (data.dimension == "进攻" or data.role.begins_with("进攻"))


## 加时赛选人（Q5·白板 1v1 禁技能 → 英雄差异只剩 max_hp）：选血量上限最高者（满血复活，平手取前）。
## 技能若将来在加时解禁，此处升级为逐候选 clone+_state_value 深比（同 choose_death_switch 机器）。
static func choose_overtime_pick(b: BattleCore, side: int) -> int:
	var best := 0
	var best_hp := -1
	for s in range(b.heroes[side].size()):
		var mh: int = int((b.heroes[side][s] as HeroData).max_hp)
		if mh > best_hp:
			best_hp = mh
			best = s
	return best


## 升级择时【进阶·价值搜索】（B·root-only）：把"就绪件 用 vs 升"交给搜索而非阈值。
## 枚举「不升 / 升某个就绪槽」变体，各 clone 应用后用根局面博弈值比较，挑价值最高那个再真应用。
## search_upgrade=false → 退回阈值 run_item_economy。仅用于 AI 真实根决策（实战 _ai_pick / sim）；
## 深层 lookahead 仍走便宜的 run_item_economy（见 _state_value）→ 无递归、性能可控。
func plan_economy(b: BattleCore, side: int, rng: RandomNumberGenerator) -> void:
	var up: int = plan_economy_decide(b, side)
	plan_economy_apply(b, side, rng, up)


## 任务G 拆分（2026-07-09·战斗内异步预想）：决策（贵·候选变体搜索·只在克隆上推演）与
## 应用（廉·真局落子）分离——后台线程在克隆上 decide、玩家确认时在真局上 apply；
## 同一 rng 起点 → 落子逐位一致。plan_economy 语义零变化（= decide + apply·sim/测试路径不动）。
## 返回：-3=守卫不通过(apply 无操作)；-2=非搜索模式(apply 走 run_item_economy)；
##       -1=不升级全用；≥0=升级该槽。
func plan_economy_decide(b: BattleCore, side: int) -> int:
	if side < 0 or side >= b.slots.size() or b.slots[side].size() < BattleCore.SLOT_COUNT:
		return -3
	if not search_upgrade:
		return -2
	# 候选升级目标 = -1(不升·全用) + 每个「就绪+可升+付得起(成本+reserve)」槽；是否值得交给搜索定。
	var candidates: Array[int] = [-1]
	for s in range(BattleCore.SLOT_COUNT):
		if b.slot_ready(side, s) and b.can_upgrade(side, s) \
				and b.energy[side] >= b.upgrade_cost(side, s) + AI_ITEM_ENERGY_RESERVE:
			candidates.append(s)
	if candidates.size() == 1:
		return -1   # 无升级抉择 → 直接全用 + 推进
	var best := -1
	var best_val := -INF
	for up in candidates:
		var sim: BattleCore = b.clone()
		_apply_economy(sim, side, _eval_rng, AI_ITEM_ENERGY_RESERVE, up, smart_draft)
		var v: float = _root_value(sim, side)
		if v > best_val:
			best_val = v
			best = up
	return best


## 经济落子（廉·决策结果应用到 b）。rng 起点相同 → 结果确定（异步重放与同步直算逐位一致的根基）。
func plan_economy_apply(b: BattleCore, side: int, rng: RandomNumberGenerator, up: int) -> void:
	if up == -3:
		return
	if up == -2:
		run_item_economy(b, side, rng, AI_ITEM_ENERGY_RESERVE, smart_draft)
		return
	_apply_economy(b, side, rng, AI_ITEM_ENERGY_RESERVE, up, smart_draft)


## 任务G：rng 状态快照/采纳——预想线程用副本推演，确认命中后真 AI 采纳终态，
## 使整局随机流与"当场同步跑一遍"完全一致（预想被弃/重跑不污染真 AI 的流）。
func rng_snapshot() -> Dictionary:
	return {"rng": rng.state, "eval": _eval_rng.state}


func rng_restore(s: Dictionary) -> void:
	rng.state = int(s["rng"])
	_eval_rng.state = int(s["eval"])


## 根局面博弈值：对剪枝动作集解一层根矩阵取安全值，供 plan_economy 比较经济变体（不再二次推进经济）。
## 用剪枝 _shortlist + RM_ITERS_INNER（值估即可·不需精确策略）→ 单变体 ≈ 一次便宜根求解。
func _root_value(b: BattleCore, player: int) -> float:
	if b.game_over:
		return _eval(b, player)
	var opp: int = 1 - player
	var my: Array = _shortlist(b, player)
	var opp_acts: Array = _shortlist(b, opp)
	var n: int = my.size()
	var m: int = opp_acts.size()
	if n == 0 or m == 0:
		return _eval(b, player)
	var payoff: Array = []
	for i in range(n):
		var row: Array[float] = []
		for j in range(m):
			row.append(_value_after(b, player, opp, my[i], opp_acts[j], search_depth - 1))
		payoff.append(row)
	var strat: Array[float] = _solve_mixed(payoff, n, m, RM_ITERS_INNER)
	return _security_value(payoff, strat, n, m)


# === 搜索 ===

## 局面评估分派：profile 1 用 v2 进阶(牌感)评估，否则 v1 基础评估。权重覆盖透传（T1 校准）。
func _eval(b: BattleCore, p: int) -> float:
	return BattleEvalV2.score(b, p, weights) if eval_profile == 1 else BattleEval.score(b, p, weights)


## 提交 (我=ca, 对手=cb) 结算一回合后，从 player 视角的子局价值（递归 depth 层）。
## 随机道具格：多次采样取均值 → 按期望值判断、去运气噪声（T3）。
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
	# 进攻向道具随攻击动作一并甩出（镜像实战 commit 时机）→ 矩阵格能算到"攻击带骑乘"的价值。
	commit_attack_items(sim, player, int(ca["action"]))
	commit_attack_items(sim, opp, int(cb["action"]))
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
	# 道具经济（Part 2）：模拟的未来回合，双方也按实战同款启发自动管理道具栏（抽/用/补/升），
	# 在枚举动作【前】跑 → AI 规划会考虑「道具就绪可收割 / 对手有道具威胁 / 该攒能升级」。
	# 槽未初始化（无经济战局 / 单元测试）时 run_item_economy 守卫早退 = 行为不变（测试安全）。
	if plan_items:
		run_item_economy(b, perspective, _eval_rng, AI_ITEM_ENERGY_RESERVE, smart_draft)
		run_item_economy(b, 1 - perspective, _eval_rng, AI_ITEM_ENERGY_RESERVE, smart_draft)
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
		if b.can_afford(player, a):
			out.append({action = a, target = -1})
	if b.can_use_active(player):
		var ask: HeroSkill = b.get_skill(player, b.active_index[player])
		if ask != null and ask.active_needs_enemy_target():
			# 带敌方目标的主动技（h21）：深层剪枝只带一个代表目标=敌方最低血替补
			# （揪软柿子启发·2026-07-05 批③④；顶层矩阵走 legal_actions 全目标枚举）。
			var pull := -1
			var pull_hp := 9999
			for es in b.living_reserves(1 - player):
				if b.hp[1 - player][es] < pull_hp:
					pull_hp = b.hp[1 - player][es]
					pull = es
			out.append({action = ActionDef.ACTIVE, target = pull})
		else:
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
