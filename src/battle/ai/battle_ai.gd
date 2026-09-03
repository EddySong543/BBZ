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
const STOCHASTIC_SAMPLES := 3 # 随机道具（赌徒硬币/锦囊/疑兵）格的多采样次数 → 按期望值判断、去运气噪声（T3）
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
const FURNACE_ITEM_ID := "t1_ronglu"
const POINTSTONE_ITEM_ID := "t2_dianjinshi"

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
	var my: Array = _legal_actions_for_decision(b, player)
	if my.is_empty():
		return {action = ActionDef.Action.CHARGE, target = -1}
	if my.size() == 1:
		return my[0]
	var opp_acts: Array = _legal_actions_for_decision(b, opp)
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
	# 背包工具包含槽目标、私有候选或必须抢在资源结算前登记的转换效果，
	# 不能走下方无目标的通用 use_slot。所有选择只读取当前公开栏与自己的背包真相。
	_use_ready_backpack_tools(b, side, upgrade_slot, rng, smart)
	# 点金石先于其他道具：选择一件 ready T1，再从缓存的 T3 三选一；产物锁定到下回合。
	_use_ready_pointstones(b, side, upgrade_slot, rng, smart)
	# 随身熔炉需要明确燃料且立即产能：先挑当前价值最低的另一件就绪道具烧掉，
	# 避开本轮计划升级的槽；满能时不白白浪费两件道具。
	if b.energy[side] < b.energy_max[side]:
		var furnace_slot := -1
		for s in range(BattleCore.SLOT_COUNT):
			var item: ItemData = b.slot_item(side, s)
			if s != upgrade_slot and b.slot_ready(side, s) \
					and item != null and item.item_id == FURNACE_ITEM_ID:
				furnace_slot = s
				break
		if furnace_slot >= 0:
			var fuel_slot := -1
			var fuel_score := INF
			for s in range(BattleCore.SLOT_COUNT):
				if s == furnace_slot or s == upgrade_slot or not b.slot_ready(side, s):
					continue
				var candidate: ItemData = b.slot_item(side, s)
				if candidate == null:
					continue
				var candidate_score: float = score_item_option(b, side, candidate)
				if candidate_score < fuel_score:
					fuel_score = candidate_score
					fuel_slot = s
			if fuel_slot >= 0:
				b.use_slot(side, furnace_slot, -1, fuel_slot)
	# 1. 就绪槽（进攻向道具按兵不动 → 攻击回合由 commit_attack_items 一并甩出）
	for s in range(BattleCore.SLOT_COUNT):
		if not b.slot_ready(side, s):
			continue
		if s == upgrade_slot and b.can_upgrade(side, s):
			var uopts: Array = b.begin_upgrade_draft(side, s)
			if not uopts.is_empty():
				b.pick_upgrade(side, s, _pick_choice(b, side, uopts, rng, smart))
				continue
		var ready_item: ItemData = b.slot_item(side, s)
		if BattleCore.item_requires_enemy_item_slot_target(ready_item):
			var enemy_slot: int = _best_enemy_item_target(b, side, ready_item)
			if enemy_slot >= 0 and _should_use_ready_item(b, side, s, ready_item):
				b.use_slot(side, s, -1, enemy_slot)
			continue
		if _requires_item_slot_target(ready_item):
			continue   # 没有合法目标的点金石/熔炉不能空放。
		if BattleCore.item_requires_friendly_hero_target(ready_item):
			if ready_item.item_id == "t2_jieyin_pei":
				continue   # 必须等最终动作确定为攻击后，再与攻击一并提交。
			var hero_target: int = _best_friendly_item_target(b, side, ready_item)
			if hero_target >= 0:
				b.use_slot(side, s, hero_target)
			continue
		if not _should_use_ready_item(b, side, s, ready_item):
			continue
		if _is_attack_item(ready_item):
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


## 需要目标或选择的背包工具，以及必须先于治疗/产能登记的双向转换件。
static func _use_ready_backpack_tools(b: BattleCore, side: int, upgrade_slot: int,
		rng: RandomNumberGenerator, smart: bool) -> void:
	for source_slot: int in range(BattleCore.SLOT_COUNT):
		if source_slot == upgrade_slot or not b.slot_ready(side, source_slot):
			continue
		var data: ItemData = b.slot_item(side, source_slot)
		if data == null:
			continue
		match data.item_id:
			"t1_jicun_pai":
				if b.energy[side] >= b.energy_max[side]:
					continue
				var deposit_target: int = _best_friendly_slot_item_target(
					b, side, source_slot, upgrade_slot, true, false)
				if deposit_target >= 0:
					b.use_slot(side, source_slot, -1, deposit_target)
			"t2_baojia_feng":
				if _ready_hostile_item_count(b, 1 - side) <= 0:
					continue
				var insured_target: int = _best_friendly_slot_item_target(
					b, side, source_slot, upgrade_slot, true, true)
				if insured_target >= 0:
					b.use_slot(side, source_slot, -1, insured_target)
			"t2_huanqian_tong":
				var exchange_target: int = _best_friendly_slot_item_target(
					b, side, source_slot, upgrade_slot, false, false)
				if exchange_target < 0:
					continue
				var exchange_options: Array = b.begin_exchange_draft(
						side, source_slot, exchange_target)
				if not exchange_options.is_empty():
					b.use_slot(side, source_slot, -1, exchange_target,
						_pick_choice(b, side, exchange_options, rng, smart))
			"t2_huigou_quan":
				var repurchase_options: Array = b.begin_repurchase_draft(side, source_slot)
				if not repurchase_options.is_empty():
					b.use_slot(side, source_slot, -1, -1,
						_pick_choice(b, side, repurchase_options, rng, smart))
			"t2_yingji_xiang":
				if _backpack_has_tier(b, side, 1):
					b.use_slot(side, source_slot)
			"t2_chenglu_zhan":
				if b.energy[side] < b.energy_max[side] \
						and _has_healing_route_this_turn(b, side, source_slot):
					b.use_slot(side, source_slot)
			"t2_naying_hulu":
				var active: int = b.active_index[side]
				if b.hp[side][active] < b.max_hp[side][active] \
						and _can_overflow_energy_this_turn(b, side, source_slot):
					b.use_slot(side, source_slot)


static func _best_friendly_slot_item_target(b: BattleCore, side: int, source_slot: int,
		upgrade_slot: int, ready_only: bool, prefer_high: bool) -> int:
	var best_slot: int = -1
	var best_score: float = -INF if prefer_high else INF
	for target_slot: int in range(BattleCore.SLOT_COUNT):
		if target_slot == source_slot or target_slot == upgrade_slot:
			continue
		if ready_only and not b.slot_ready(side, target_slot):
			continue
		var slot: Dictionary = b.slots[side][target_slot]
		var candidate: ItemData = b.slot_item(side, target_slot)
		if candidate == null or bool(slot.get("used", false)):
			continue
		var score: float = score_item_option(b, side, candidate)
		if best_slot < 0 or (prefer_high and score > best_score) \
				or (not prefer_high and score < best_score):
			best_score = score
			best_slot = target_slot
	return best_slot


static func _backpack_has_tier(b: BattleCore, side: int, tier: int) -> bool:
	if not b.battle_backpack_enabled:
		return false
	for entry_variant in b.battle_backpacks[side]:
		var entry: Dictionary = entry_variant
		var data: ItemData = ItemCatalog.make(String(entry.get("item_id", "")))
		if data != null and data.tier == tier:
			return true
	return false


## 连续处理当前 ready 的点金石。AI 选择机会成本最低的 T1 目标，再按局面评估三个 T3 候选。
static func _use_ready_pointstones(b: BattleCore, side: int, upgrade_slot: int,
		rng: RandomNumberGenerator, smart: bool) -> void:
	for _step: int in range(BattleCore.SLOT_COUNT):
		var pointstone_slot := -1
		for s: int in range(BattleCore.SLOT_COUNT):
			var item: ItemData = b.slot_item(side, s)
			if s != upgrade_slot and b.slot_ready(side, s) and item != null \
					and item.item_id == POINTSTONE_ITEM_ID:
				pointstone_slot = s
				break
		if pointstone_slot < 0:
			return
		var target_slot: int = _best_pointstone_target(b, side, pointstone_slot, upgrade_slot)
		if target_slot < 0:
			return
		var options: Array = b.begin_pointstone_draft(side, pointstone_slot, target_slot)
		if options.is_empty():
			return
		var choice: int = _pick_choice(b, side, options, rng, smart)
		if not b.use_slot(side, pointstone_slot, -1, target_slot, choice):
			return


## 点金石可替换任意另一件 ready T1。传说候选与原 T1 无关，因此保留价值最高的 T1、牺牲最低者。
static func _best_pointstone_target(b: BattleCore, side: int, pointstone_slot: int,
		upgrade_slot: int = -1) -> int:
	var best_slot := -1
	var lowest_score := INF
	for s: int in range(BattleCore.SLOT_COUNT):
		if s == pointstone_slot or s == upgrade_slot or not b.slot_ready(side, s):
			continue
		var base_item: ItemData = b.slot_item(side, s)
		if base_item == null or base_item.tier != 1:
			continue
		var score: float = score_item_option(b, side, base_item)
		if score < lowest_score - 0.001:
			lowest_score = score
			best_slot = s
	return best_slot


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
				s += 6.0    # 自己进斩杀圈：护甲/挡件保命（轻推）
		"能量":
			if b.energy[side] <= 2:
				s += 4.0    # 缺能（≤1.0 能）：能量件回血线（轻推）
	if data.upgrade_to != "":
		s += 3.0            # 预设升级线 → 养成潜力
	# T3 的公开条件只作轻量修正：基础 EV 仍是主值，避免抽牌阶段用当前一拍
	# 过拟合未来局面；但残局、低血和对手明牌资源应能改变三选一优先级。
	match data.item_id:
		"t3_budongmingwang":
			s += 8.0 if b.energy[opp] >= ActionDef.ENERGY_UNIT else 2.0
		"t3_hedinghong":
			s += 8.0 * float(maxi(int(b.get_status(
				opp, b.active_index[opp], "poison", 0)), 0))
		"t3_jianyi":
			s += 8.0 if b.can_afford(side, ActionDef.Action.ATTACK) else 0.0
		"t3_mengdie":
			s += 10.0 if _dream_swap_is_favorable(b, side, -1) else -8.0
		"t3_morihuozhong":
			s += 18.0 if b.alive_count(side) == 1 else 4.0
		"t3_shixinding":
			s += 8.0 if _has_legal_base_attack(b, side) else -6.0
		"t3_tianluodiwang":
			s += 6.0 if _ready_item_count(b, opp) > 0 else 0.0
			s += 6.0 if not b.living_reserves(opp).is_empty() else 0.0
		"t3_yemingzhu":
			s += 8.0 if not b.living_reserves(side).is_empty() else -4.0
		"t3_yujin":
			s += 12.0 if my_hp <= int(data.params.get("threshold", 2)) else -4.0
		"t3_yiqi":
			s += 8.0 if _has_legal_base_attack(b, opp) else -4.0
		"t3_sanqi_zhong":
			s += 8.0 * float(_active_item_effect_count(b, opp) - _active_item_effect_count(b, side))
		"t3_zhaohun_fan":
			s += 18.0 if _best_friendly_item_target(b, side, data) >= 0 else -12.0
		"t3_lianhuan_gu":
			s += 12.0 if _has_lianhuan_action_pair(b, side) else -12.0
		"t3_jubao_pen":
			s += 10.0 if _has_empty_item_slot(b, side) else 4.0
		"t3_sheming_quan":
			s += 12.0 if b.energy[side] <= 2 * ActionDef.ENERGY_UNIT else -6.0
		"t3_huanming_qi":
			s += 12.0 if _best_friendly_item_target(b, side, data) >= 0 else -10.0
		"t3_jieming_deng":
			s += 12.0 if b.energy[side] <= 2 * ActionDef.ENERGY_UNIT and my_hp > BattleCore.HP_UNIT else -10.0
		"t3_qingnang_huopen":
			s += 6.0 * float(_ready_item_count(b, opp) - _ready_item_count(b, side))
		"t3_junneng_dou":
			s += 4.0 * float(b.energy[opp] - b.energy[side])
	return s


## 进攻向道具（chip 伤害 / 攻击增伤 / 命中骑乘）只在攻击回合甩出才有价值。
## 经济阶段按兵不动（见 _apply_economy），动作定为攻击后调本函数一并提交（与波/大波同吃对方防御门）。
## 修复 2026-07-03 死龟锁：免费道具流下若"每回合白扔 chip"，对手每回合都有已提交伤害 →
## 「防」恒有免费价值 → 双方全场防（冒烟 sim 防占 79%、90% 打满回合上限）。
static func commit_attack_items(b: BattleCore, side: int, action: int,
		second_action: int = -1) -> void:
	if side < 0 or side >= b.slots.size() or b.slots[side].size() < BattleCore.SLOT_COUNT:
		return
	for s in range(BattleCore.SLOT_COUNT):
		var data: ItemData = b.slot_item(side, s)
		if not b.slot_ready(side, s) or data == null:
			continue
		if _is_action_commit_item(data) \
				and _should_commit_action_item(b, side, action, data, second_action):
			if BattleCore.item_requires_friendly_hero_target(data):
				var hero_target: int = _best_friendly_item_target(b, side, data)
				if hero_target >= 0:
					b.use_slot(side, s, hero_target)
			else:
				b.use_slot(side, s)
		elif _is_attack_turn(b, side, action, second_action) and _is_attack_item(data) \
				and _should_commit_attack_item(b, side, action, data, second_action):
			b.use_slot(side, s)


## 本回合动作是否「攻击」（公共术语仅含波/大波）——进攻向道具的甩出门。
static func _is_attack_turn(_b: BattleCore, _side: int, action: int,
		second_action: int = -1) -> bool:
	return ActionDef.is_attack(action) or ActionDef.is_attack(second_action)


## 进攻向道具判定：维度=进攻（chip/增伤）或角色以「进攻」开头（进攻→X 导出骑乘，如血魔的獠牙）。
static func _is_attack_item(data: ItemData) -> bool:
	if data == null or data.item_id == "t2_pianfeng_jia":
		return false
	return (data.dimension == "进攻" or data.role.contains("攻") or data.role == "易伤") \
		and not _is_action_commit_item(data)


## 选招后才能确定是否有效的道具：经济阶段持有，动作锁定后再提交。
## 这里只读我方公开状态与已选 action，不查看对手的盲选动作。
static func _is_action_commit_item(data: ItemData) -> bool:
	return data != null and data.item_id in [
		"t1_deneng_hufu",
		"t1_huanfang_kou",
		"t1_huifeng_qiao",
		"t1_jijiu_ling",
		"t1_yazhen_zhui",
		"t1_xunxing_zhui",
		"t2_fuying_suo",
		"t2_huiliu_zhu",
		"t2_jieyin_pei",
		"t2_nuanyu",
	]


static func _requires_item_slot_target(data: ItemData) -> bool:
	return data != null and BattleCore.item_requires_friendly_item_slot_target(data)


static func _best_friendly_item_target(b: BattleCore, side: int, data: ItemData) -> int:
	if data == null:
		return -1
	match data.item_id:
		"t1_houzhen_qian":
			var active: int = b.active_index[side]
			var active_score: int = b.hp[side][active] + b.shield[side][active]
			var best_entry: int = -1
			var best_entry_score: int = active_score
			for slot in b.living_reserves(side):
				var score: int = b.hp[side][slot] + b.shield[side][slot]
				if score > best_entry_score:
					best_entry_score = score
					best_entry = slot
			return best_entry
		"t2_jieyin_pei":
			if not _has_legal_base_attack(b, side):
				return -1
			var best_mark: int = -1
			var best_mark_score: int = -1
			for slot in b.living_reserves(side):
				var hero_id: String = (b.heroes[side][slot] as HeroData).hero_id
				var score: int = 3 if hero_id == "h10" and int(
					b.get_team_status(side, "jianqi", 0)) < 4 else (2 if hero_id == "h06" else (1 if hero_id == "h20" else -1))
				if score > best_mark_score:
					best_mark_score = score
					best_mark = slot
			return best_mark
		"t2_daishang_san":
			if not _has_legal_base_attack(b, 1 - side):
				return -1
			var best_decoy: int = -1
			var best_decoy_score: int = -1
			for slot in b.living_reserves(side):
				var hero_bonus: int = 100 if (b.heroes[side][slot] as HeroData).hero_id == "h12" else 0
				var score: int = hero_bonus + b.hp[side][slot] + b.shield[side][slot]
				if score > best_decoy_score:
					best_decoy_score = score
					best_decoy = slot
			return best_decoy
		"t2_xingjun_yaonang":
			var most_injured: int = -1
			var missing: int = 0
			for slot in b.living_reserves(side):
				var slot_missing: int = b.max_hp[side][slot] - b.hp[side][slot]
				if slot_missing > missing:
					missing = slot_missing
					most_injured = slot
			return most_injured
		"t2_huzhen_ding":
			var reserves: Array[int] = b.living_reserves(side)
			if reserves.is_empty():
				return -1
			var best_reserve: int = reserves[0]
			for slot in reserves:
				if b.hp[side][slot] < b.hp[side][best_reserve]:
					best_reserve = slot
			return best_reserve
		"t2_yijia_huan":
			var total_shield: int = 0
			for value in b.shield[side]:
				total_shield += int(value)
			if total_shield <= 0:
				return -1
			var active: int = b.active_index[side]
			var best: int = active
			for slot in range(b.hp[side].size()):
				if b.hp[side][slot] > 0 and b.hp[side][slot] < b.hp[side][best]:
					best = slot
			return -1 if b.shield[side][best] == total_shield else best
		"t3_zhaohun_fan":
			var best_dead: int = -1
			var best_dead_score: int = -1
			for slot in range(b.hp[side].size()):
				if not b.is_dead_reserve(side, slot):
					continue
				var score: int = b.max_hp[side][slot]
				if score > best_dead_score:
					best_dead_score = score
					best_dead = slot
			return best_dead
		"t3_huanming_qi":
			var current: int = b.hp[side][b.active_index[side]] + b.shield[side][b.active_index[side]]
			var best_swap: int = -1
			var best_gain: int = 0
			for slot in b.living_reserves(side):
				var gain: int = b.hp[side][slot] + b.shield[side][slot] - current
				if gain > best_gain:
					best_gain = gain
					best_swap = slot
			return best_swap
		"t3_yiyuan_deng":
			var active: int = b.active_index[side]
			if b.hp[side][active] > 2 * BattleCore.HP_UNIT:
				return -1
			var best_heal: int = 0
			var best_reserve: int = -1
			for slot in b.living_reserves(side):
				var missing: int = b.max_hp[side][slot] - b.hp[side][slot]
				if missing > best_heal:
					best_heal = missing
					best_reserve = slot
			return best_reserve
	return -1


static func _best_enemy_item_target(b: BattleCore, side: int, data: ItemData) -> int:
	var best: int = -1
	var best_tier: int = -1
	var opponent: int = 1 - side
	for slot in range(BattleCore.SLOT_COUNT):
		if not b.valid_enemy_item_target_for(data, side, slot):
			continue
		var item: ItemData = b.slot_item(opponent, slot)
		var tier: int = item.tier if item != null else 0
		if tier > best_tier:
			best_tier = tier
			best = slot
	return best


static func _best_enemy_locked_item_target(b: BattleCore, side: int) -> int:
	return _best_enemy_item_target(b, side, ItemCatalog.make("t2_shizhi_jiasuo"))


## 非进攻 T3 在选动作前处理；只拦截当前公开信息已证明白板的使用。
## 隐藏博弈仍交给搜索，不以猜测对方盲选为由扣住道具。
static func _should_use_ready_item(b: BattleCore, side: int, source_slot: int,
		data: ItemData) -> bool:
	if data == null:
		return false
	if bool(data.params.get("relic", false)) \
			and String(data.params.get("stack_mode", "")) == "unique" \
			and _has_relic(b, side, data.item_id):
		return false
	var active: int = b.active_index[side]
	match data.item_id:
		"t1_deneng_hufu":
			return false   # 最终动作/受伤路线确定后由 commit_attack_items 决定，避免预用后白板。
		"t1_fentong_mupai":
			return not b.living_reserves(side).is_empty() and b.hp[side][active] > 0 \
				and _has_legal_base_attack(b, 1 - side)
		"t1_huanfang_kou", "t1_huifeng_qiao", "t1_jijiu_ling", \
				"t1_yazhen_zhui", "t1_xunxing_zhui", "t2_nuanyu":
			return false   # 需已选公共动作，由 commit_attack_items 统一提交。
		"t1_xuzhen_qi":
			return b.hp[side][active] <= 2 * BattleCore.HP_UNIT \
				and not b.living_reserves(side).is_empty()
		"t1_xuedu_jie":
			return _can_use_blood_ferry(b, side, active)
		"t1_tengman_xianjing":
			return not b.living_reserves(1 - side).is_empty()
		"t1_jiedu_yaoshui":
			var removable: int = int(int(b.get_status(side, active, "poison", 0)) > 0) \
				+ int(int(b.get_status(side, active, "vuln", 0)) > 0)
			return _queued_item_count(b, side, data.item_id) < removable
		"t2_huanhundan":
			return int(b.get_status(side, active, "huanhun_used", 0)) <= 0
		"t2_fuying_suo":
			return false   # 与已选攻击同行，避免锁定目标后本回合没有攻击。
		"t2_lianxin_suo":
			return b.alive_count(side) > 1 and _has_legal_base_attack(b, 1 - side)
		"t2_ningxue_gao":
			return _has_ready_healing_item(b, side, source_slot) \
				or _has_relic(b, side, "t3_xumingxiang")
		"t2_fencun_chi":
			var big_cost: int = int(ActionDef.BASE_ACTION_DEF[ActionDef.Action.BIG_ATTACK]["cost"])
			return b.hp[side][active] <= 2 * BattleCore.HP_UNIT \
				or (b.energy[1 - side] >= big_cost and b.energy[side] < big_cost)
		"t2_fengmai_zhen":
			return _has_injured_living_hero(b, 1 - side) \
				and (not _has_injured_living_hero(b, side) \
				or _has_ready_item_id(b, side, "t2_ningxue_gao"))
		"t2_zhenwen_zhen":
			return _team_has_hit_trigger_skill(b, 1 - side)
		"t2_suoquan_sai":
			var opponent: int = 1 - side
			return b.alive_count(opponent) > 0 \
				and int(b.item_buffs[opponent].get("energy_gain_lock_turn", -1)) < b.turn_number + 1 \
				and _queued_item_count(b, side, data.item_id) == 0
		"t2_huizhao_jing":
			return _queued_item_count(b, side, data.item_id) \
				< _ready_hostile_item_count(b, 1 - side)
		"t2_shizhi_jiasuo":
			return _best_enemy_locked_item_target(b, side) >= 0
		"t2_yawu_piao", "t2_cuiyong_pai":
			return _best_enemy_item_target(b, side, data) >= 0
		"t2_dingming_wan":
			return b.hp[side][active] > 0 \
				and b.hp[side][active] < int(data.params.get("hp", 6))
		"t2_duyong_feng":
			return _ready_item_count(b, side) == 1 \
				and _ready_item_count(b, 1 - side) >= 2
		"t2_pianfeng_jia":
			var opponent: int = 1 - side
			return b.usable_energy(opponent) >= b.action_cost(
				opponent, ActionDef.Action.ATTACK) \
				and b.usable_energy(opponent) < b.action_cost(
					opponent, ActionDef.Action.BIG_ATTACK)
		"t2_jingwen_zhou":
			return _pending_hit_skill_effect_count(b, 1 - side) \
				> _pending_hit_skill_effect_count(b, side)
		"t2_guiying_pai":
			return not b.living_reserves(side).is_empty() \
				and int(b.item_buffs[side].get("return_camp_heal", 0)) == 0
		"t2_miwu_doupeng":
			return not bool(b.info_distortion[side].get("hide_item_bar", false))
		"t2_nuanyu":
			return false   # 动作确定为「防/大防」后再提交，避免在非防御回合白白消耗。
		"t3_fali":
			return b.energy[side] < b.energy_max[side]
		"t3_mengdie":
			return _dream_swap_is_favorable(b, side, source_slot)
		"t3_shengming":
			return b.hp[side][active] < b.max_hp[side][active]
		"t3_tianluodiwang":
			var opp: int = 1 - side
			return _ready_item_count(b, opp) > 0 or not b.living_reserves(opp).is_empty()
		"t3_yiqi":
			return _has_legal_base_attack(b, 1 - side)
		"t3_sanqi_zhong":
			return _active_item_effect_count(b, 1 - side) > _active_item_effect_count(b, side)
		"t3_lianhuan_gu":
			return _has_lianhuan_action_pair(b, side)
		"t3_jubao_pen":
			return true
		"t3_sheming_quan":
			return int(b.item_buffs[side].get("exhausted_turn", -1)) < b.turn_number + 1 \
				and b.energy[side] <= 2 * ActionDef.ENERGY_UNIT
		"t3_jieming_deng":
			return b.hp[side][active] > BattleCore.HP_UNIT \
				and b.energy[side] <= 2 * ActionDef.ENERGY_UNIT
		"t3_qingnang_huopen":
			return _ready_item_count(b, 1 - side) > _ready_item_count(b, side)
		"t3_junneng_dou":
			return b.energy[1 - side] > b.energy[side]
		"t3_xiling_ling":
			return _team_skill_pressure(b, 1 - side) > _team_skill_pressure(b, side)
		"t3_yiyuan_deng":
			return _best_friendly_item_target(b, side, data) >= 0
		"t1_tingxia_tong":
			return b.battle_backpack_enabled \
				and b.battle_backpacks[1 - side].size() \
				> b.revealed_backpack_items_for(side, 1 - side).size()
		"t2_chenglu_zhan", "t2_naying_hulu", "t1_jicun_pai", \
				"t2_baojia_feng", "t2_huanqian_tong", "t2_huigou_quan", \
				"t2_yingji_xiang":
			return false   # 有目标/候选/结算顺序要求，已由背包工具预处理。
		_:
			return true


static func _has_injured_living_hero(b: BattleCore, side: int) -> bool:
	for slot in range(b.hp[side].size()):
		if b.hp[side][slot] > 0 and b.hp[side][slot] < b.max_hp[side][slot]:
			return true
	return false


static func _has_ready_healing_item(b: BattleCore, side: int, excluded_slot: int = -1) -> bool:
	for slot in range(BattleCore.SLOT_COUNT):
		if slot == excluded_slot or not b.slot_ready(side, slot):
			continue
		var item: ItemData = b.slot_item(side, slot)
		if item != null and int(item.params.get("heal", 0)) > 0:
			return true
	return false


static func _has_healing_route_this_turn(b: BattleCore, side: int,
		excluded_slot: int = -1) -> bool:
	if _has_ready_healing_item(b, side, excluded_slot) or _has_relic(b, side, "t3_xumingxiang"):
		return true
	for use_variant in b.item_uses[side]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and int(data.params.get("heal", 0)) > 0:
			return true
	return false


static func _can_overflow_energy_this_turn(b: BattleCore, side: int,
		excluded_slot: int = -1) -> bool:
	if b.energy[side] >= b.energy_max[side]:
		return true   # 「攒」是公开合法的保底产能来源。
	var gap: int = b.energy_max[side] - b.energy[side]
	for slot in range(BattleCore.SLOT_COUNT):
		if slot == excluded_slot or not b.slot_ready(side, slot):
			continue
		var data: ItemData = b.slot_item(side, slot)
		if data != null and int(data.params.get("energy", 0)) > gap:
			return true
	return false


static func _pending_hit_skill_effect_count(b: BattleCore, side: int) -> int:
	var count: int = 1 if int(b.get_team_status(side, "jianqi", 0)) > 0 else 0
	for slot in range(b.hp[side].size()):
		for key in ["poison", "vuln"]:
			if int(b.get_status(side, slot, key, 0)) > 0:
				count += 1
	return count


static func _team_skill_pressure(b: BattleCore, side: int) -> int:
	var pressure: int = 0
	for slot in range(b.heroes[side].size()):
		if b.hp[side][slot] <= 0:
			continue
		var hero_id: String = (b.heroes[side][slot] as HeroData).hero_id
		if hero_id.begins_with("h") and hero_id.length() == 3:
			pressure += 1
	return pressure


static func _has_ready_item_id(b: BattleCore, side: int, item_id: String) -> bool:
	for slot in range(BattleCore.SLOT_COUNT):
		var item: ItemData = b.slot_item(side, slot)
		if b.slot_ready(side, slot) and item != null and item.item_id == item_id:
			return true
	return false


static func _team_has_hit_trigger_skill(b: BattleCore, side: int) -> bool:
	for slot in range(b.heroes[side].size()):
		if b.hp[side][slot] <= 0:
			continue
		if (b.heroes[side][slot] as HeroData).hero_id in ["h06", "h09", "h10", "h19", "h20", "h23"]:
			return true
	return false


static func _can_use_blood_ferry(b: BattleCore, side: int, active: int) -> bool:
	if b.hp[side][active] <= 0:
		return false
	var queued: int = _queued_item_count(b, side, "t1_xuedu_jie")
	var projected_hp: int = b.hp[side][active]
	var immunity: bool = int(b.get_status(side, active, "fatal_damage_immunity", 0)) > 0
	for _prior in range(queued):
		if projected_hp <= BattleCore.HP_UNIT and immunity:
			immunity = false
		else:
			projected_hp -= BattleCore.HP_UNIT
	var can_pay: bool = projected_hp > BattleCore.HP_UNIT or immunity
	if not can_pay:
		return false
	var missing_hp: int = 0
	for slot in b.living_reserves(side):
		missing_hp += maxi(0, b.max_hp[side][slot] - b.hp[side][slot])
	return missing_hp > queued * 4


static func _queued_item_count(b: BattleCore, side: int, item_id: String) -> int:
	var count: int = 0
	for use_variant in b.item_uses[side]:
		var use: Dictionary = use_variant
		var data: ItemData = use.get("data", null)
		if data != null and data.item_id == item_id:
			count += 1
	return count


static func _should_commit_action_item(b: BattleCore, side: int, action: int,
		data: ItemData, second_action: int = -1) -> bool:
	match data.item_id:
		"t1_deneng_hufu":
			return b.energy[side] < b.energy_max[side] \
				and (action == ActionDef.Action.CHARGE or second_action == ActionDef.Action.CHARGE \
				or _has_active_energy_gain_route(b, side))
		"t1_huanfang_kou":
			return action == ActionDef.Action.SWITCH \
				or (b.free_switch_usage_turn[side] == b.turn_number \
				and b.free_switch_uses[side] > 0)
		"t1_jijiu_ling":
			return (ActionDef.is_attack(action) or ActionDef.is_attack(second_action)) \
				and _has_injured_living_hero(b, side)
		"t1_yazhen_zhui":
			return action == ActionDef.Action.BIG_DEFEND or second_action == ActionDef.Action.BIG_DEFEND
		"t1_huifeng_qiao":
			return action == ActionDef.Action.ATTACK or second_action == ActionDef.Action.ATTACK
		"t1_xunxing_zhui":
			return (action == ActionDef.Action.ATTACK or second_action == ActionDef.Action.ATTACK) \
				and _should_spend_xunxing(b, side)
		"t2_fuying_suo":
			return (ActionDef.is_attack(action) or ActionDef.is_attack(second_action)) \
				and not b.living_reserves(1 - side).is_empty()
		"t2_jieyin_pei":
			return (ActionDef.is_attack(action) or ActionDef.is_attack(second_action)) \
				and _best_friendly_item_target(b, side, data) >= 0
		"t2_nuanyu":
			return (action in ActionDef.DEFEND_ACTIONS or second_action in ActionDef.DEFEND_ACTIONS) \
				and _has_injured_living_hero(b, side)
		"t2_huiliu_zhu":
			var first_exact: bool = action >= 0 and b.action_cost(side, action) > 0 \
				and b.energy[side] == b.action_cost(side, action)
			var second_exact: bool = second_action >= 0 \
				and b.action_cost(side, second_action) > 0 \
				and b.energy[side] == b.action_cost(side, action) \
					+ b.action_cost(side, second_action)
			return first_exact or second_exact
		_:
			return false


## 进攻 T3 的条件在动作确定后检查，避免「波」烧掉龙息/「大波」烧掉至臻剑意。
static func _should_commit_attack_item(b: BattleCore, side: int, action: int,
		data: ItemData, second_action: int = -1) -> bool:
	if data == null:
		return false
	if bool(data.params.get("relic", false)) \
			and String(data.params.get("stack_mode", "")) == "unique" \
			and _has_relic(b, side, data.item_id):
		return false
	match data.item_id:
		"t2_dianjiang_gu":
			return (ActionDef.is_attack(action) or ActionDef.is_attack(second_action)) \
				and not b.living_reserves(1 - side).is_empty()
		"t3_jianyi":
			return action == ActionDef.Action.ATTACK or second_action == ActionDef.Action.ATTACK
		"t3_longxi":
			return action == ActionDef.Action.BIG_ATTACK or second_action == ActionDef.Action.BIG_ATTACK
		"t3_tinglong":
			return b.energy[side] >= ActionDef.ENERGY_UNIT
		"t3_yujin":
			return b.hp[side][b.active_index[side]] <= int(data.params.get("threshold", 2))
		_:
			return true


static func _has_relic(b: BattleCore, side: int, item_id: String) -> bool:
	for relic_variant in b.relics[side]:
		var relic: Dictionary = relic_variant
		var relic_data: ItemData = relic.get("data", null)
		if relic_data != null and relic_data.item_id == item_id:
			return true
	return false


static func _ready_item_count(b: BattleCore, side: int) -> int:
	var count := 0
	if side < 0 or side >= b.slots.size():
		return count
	for slot: int in range(b.slots[side].size()):
		if b.slot_ready(side, slot):
			count += 1
	return count


static func _has_empty_item_slot(b: BattleCore, side: int) -> bool:
	for slot in range(BattleCore.SLOT_COUNT):
		if b.slot_item(side, slot) == null:
			return true
	return false


## 散契钟只比较公开、仍在持续生效的道具状态，不把生命/能量/护甲等已结算数值算进去。
static func _active_item_effect_count(b: BattleCore, side: int) -> int:
	var count: int = b.relics[side].size() + b.timed_item_effects[side].size()
	const TEAM_KEYS: Array[String] = [
		"sealed_item_turns", "energy_debt_turns", "return_camp_heal",
		"energy_gain_lock_turn", "switch_lock_until_turn", "free_big_attack_until_turn",
		"exhausted_next", "exhausted_turn", "next_atk_bonus", "next_atk_total_bonus",
		"next_armor", "next_energy_penalty", "pending_death_replacement_shield",
	]
	for key in TEAM_KEYS:
		if b.item_buffs[side].has(key):
			count += 1
	for slot in range(b.hp[side].size()):
		if int(b.get_status(side, slot, "fatal_damage_immunity", 0)) > 0:
			count += 1
	return count


static func _has_lianhuan_action_pair(b: BattleCore, side: int) -> bool:
	var public_actions: int = 0
	for choice_variant in b.legal_actions(side):
		var action: int = int((choice_variant as Dictionary).get("action", -1))
		if action >= ActionDef.Action.CHARGE and action <= ActionDef.Action.BIG_DEFEND:
			public_actions += 1
			if public_actions >= 2:
				return true
	return false


static func _ready_hostile_item_count(b: BattleCore, side: int) -> int:
	var count := 0
	if side < 0 or side >= b.slots.size():
		return count
	for slot: int in range(b.slots[side].size()):
		if not b.slot_ready(side, slot):
			continue
		var data: ItemData = b.slot_item(side, slot)
		if data != null and data.effect != null \
				and data.target_mode == ItemData.Target.ENEMY \
				and not data.effect.resolves_before_hostile_item_counters():
			count += 1
	return count


static func _has_legal_base_attack(b: BattleCore, side: int) -> bool:
	for choice_variant in b.legal_actions(side):
		var choice: Dictionary = choice_variant
		if ActionDef.is_attack(int(choice.get("action", ActionDef.Action.CHARGE))):
			return true
	return false


## 不窥对手盲选，只看我方公开可选的主动得能来源。攒是保底来源；当前出战技能的
## energy_gain_bonus 由同一个 _gain_energy 管线结算，故无需额外枚举英雄ID。
static func _has_active_energy_gain_route(b: BattleCore, side: int) -> bool:
	var active: int = b.active_index[side]
	return active >= 0 and active < b.heroes[side].size() \
		and (b.heroes[side][active] as HeroData).hero_id == "h12" \
		and _has_legal_base_attack(b, 1 - side)


## 寻星坠与其他进攻道具一样，只在 AI 最终选招为「波」时才真正提交；
## 但“能打谁”又必须在选招时进入搜索。因此用克隆预提交就绪寻星坠，只取其
## 「波」合法目标补入决策集；真局仍在 commit_attack_items 中按最终 action 决定是否消耗。
## 所有存活目标都保留，让完整搜索自行评估后排残血、护甲和命中状态价值。
static func _legal_actions_for_decision(b: BattleCore, side: int) -> Array:
	var legal: Array = b.legal_actions(side)
	if _should_spend_xunxing(b, side):
		var preview: BattleCore = b.clone()
		commit_attack_items(preview, side, ActionDef.Action.ATTACK)
		if preview.can_target_any_enemy_with_base_attack(side, ActionDef.Action.ATTACK):
			var targeted: Array = []
			for choice_variant in legal:
				var choice: Dictionary = choice_variant
				if int(choice.get("action", ActionDef.Action.CHARGE)) != ActionDef.Action.ATTACK:
					targeted.append(choice)
			for choice_variant in preview.legal_actions(side):
				var choice: Dictionary = choice_variant
				if int(choice.get("action", ActionDef.Action.CHARGE)) == ActionDef.Action.ATTACK:
					targeted.append(choice)
			legal = targeted
	return _expand_lianhuan_choices(b, side, legal)


## 连环鼓不是额外的隐藏 AI 行为；把两个不同公共行动直接展开成搜索动作对，
## 让矩阵博弈同时评估顺序、费用与对手盲选。
static func _expand_lianhuan_choices(b: BattleCore, side: int, first_choices: Array) -> Array:
	if not b.has_lianhuan_gu_queued(side):
		return first_choices
	var pairs: Array = []
	for first_variant in first_choices:
		var first: Dictionary = first_variant
		var preview: BattleCore = b.clone()
		if not preview.apply_choice(side, first):
			continue
		for second_variant in preview.legal_second_actions(side):
			var second: Dictionary = second_variant
			var pair: Dictionary = first.duplicate(true)
			pair["second_action"] = int(second.get("action", -1))
			pair["second_target"] = int(second.get("target", -1))
			pairs.append(pair)
	return pairs


## 房日自身已经拥有同等选敌权；寻星坠只会把波减伤，AI 不得为零新增收益主动消耗。
static func _should_spend_xunxing(b: BattleCore, side: int) -> bool:
	if not _has_ready_item(b, side, "t1_xunxing_zhui"):
		return false
	return not b.can_target_any_enemy_with_base_attack(side, ActionDef.Action.ATTACK)


static func _best_wave_target(b: BattleCore, side: int) -> int:
	var opponent: int = 1 - side
	var best: int = -1
	var best_kill: int = -1
	var best_hp: int = 1 << 30
	for slot in b.living_heroes(opponent):
		var target_hp: int = b.hp[opponent][slot]
		var killable: int = 1 if target_hp <= BattleCore.HP_UNIT else 0
		if killable > best_kill or (killable == best_kill and target_hp < best_hp) \
				or (killable == best_kill and target_hp == best_hp \
				and slot == b.active_index[opponent]):
			best = slot
			best_kill = killable
			best_hp = target_hp
	return best


static func _has_ready_item(b: BattleCore, side: int, item_id: String) -> bool:
	if side < 0 or side >= b.slots.size():
		return false
	for slot in range(b.slots[side].size()):
		var data: ItemData = b.slot_item(side, slot)
		if b.slot_ready(side, slot) and data != null and data.item_id == item_id:
			return true
	return false


## 梦蝶只在对方公开资源总值更高时使用。来源梦蝶本身会被消耗，故不计入己方可交换栏价值。
static func _dream_swap_is_favorable(b: BattleCore, side: int, source_slot: int) -> bool:
	var opp: int = 1 - side
	var mine: float = float(b.energy[side]) * 6.0 + _item_bar_value(b, side, source_slot, false)
	# 对手本回合是否已在内部顺序中提交道具属于盲选信息；仍按其公开栏面值估算，避免 AI 偷看 used。
	var theirs: float = float(b.energy[opp]) * 6.0 + _item_bar_value(b, opp, -1, true)
	return theirs > mine + 0.001


static func _item_bar_value(b: BattleCore, side: int, ignored_slot: int,
		include_used: bool) -> float:
	var value := 0.0
	if side < 0 or side >= b.slots.size():
		return value
	for slot: int in range(b.slots[side].size()):
		if slot == ignored_slot:
			continue
		var data: ItemData = b.slot_item(side, slot)
		if data != null and (include_used or not bool(b.slots[side][slot].get("used", false))):
			value += float(data.ev_half) * 10.0
	return value


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
	# 动作绑定道具必须先进入待使用队列，带目标的「波」才会通过权威合法性校验。
	commit_attack_items(sim, player, int(ca["action"]), int(ca.get("second_action", -1)))
	commit_attack_items(sim, opp, int(cb["action"]), int(cb.get("second_action", -1)))
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
	var targetable_wave: bool = b.can_target_any_enemy_with_base_attack(
		player, ActionDef.Action.ATTACK) \
		or _should_spend_xunxing(b, player)
	# 攒也过 can_afford（2026-07-17 审计修复）：动作锁定拍（当前为保留基建·锁定动作可执行时）
	# 攒非法——旧"攒恒合法"假设早于锁招机制·非法行会稀释深层收益矩阵。
	if b.can_afford(player, ActionDef.Action.CHARGE):
		out.append({action = ActionDef.Action.CHARGE, target = -1})
	for a in [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK,
			ActionDef.Action.DEFEND, ActionDef.Action.BIG_DEFEND]:
		# 深层只保留一名代表目标；优先后排斩杀，其次最低血，避免状态目标被固定到出战位。
		var action_target: int = _best_wave_target(b, player) \
			if a == ActionDef.Action.ATTACK and targetable_wave else -1
		var forms: Array[Dictionary] = []
		if b.can_afford(player, a):
			forms.append({})
		if b.can_use_energy_cap_discount(player, a):
			forms.append({energy_cap_discount = true})
		if b.can_empower_wave_action(player, a):
			forms.append({empowered_wave = true})
		if b.can_empower_wave_action(player, a, false, true):
			forms.append({empowered_wave = true, energy_cap_discount = true})
		if b.can_split_big_wave_action(player, a):
			forms.append({split_big_wave = true})
		if b.can_split_big_wave_action(player, a, false, true):
			forms.append({split_big_wave = true, energy_cap_discount = true})
		if b.action_cost(player, a) > 0 and b.can_pay_action_with_blood(player, a):
			forms.append({blood_payment = true})
		if b.can_use_energy_cap_discount(player, a, false, true):
			forms.append({blood_payment = true, energy_cap_discount = true})
		if b.can_empower_wave_action(player, a, true):
			forms.append({empowered_wave = true, blood_payment = true})
		if b.can_empower_wave_action(player, a, true, true):
			forms.append({empowered_wave = true, blood_payment = true,
				energy_cap_discount = true})
		if b.can_split_big_wave_action(player, a, true):
			forms.append({split_big_wave = true, blood_payment = true})
		if b.can_split_big_wave_action(player, a, true, true):
			forms.append({split_big_wave = true, blood_payment = true,
				energy_cap_discount = true})
		if b.can_jianqi_attack_action(player, a):
			forms.append({jianqi_attack = true})
		if b.can_jianqi_attack_action(player, a, false, false, true):
			forms.append({jianqi_attack = true, energy_cap_discount = true})
		if b.can_jianqi_attack_action(player, a, false, true):
			forms.append({jianqi_attack = true, blood_payment = true})
		if b.can_jianqi_attack_action(player, a, false, true, true):
			forms.append({jianqi_attack = true, blood_payment = true,
				energy_cap_discount = true})
		if b.can_jianqi_attack_action(player, a, true):
			forms.append({empowered_wave = true, jianqi_attack = true})
		if b.can_jianqi_attack_action(player, a, true, false, true):
			forms.append({empowered_wave = true, jianqi_attack = true,
				energy_cap_discount = true})
		if b.can_jianqi_attack_action(player, a, true, true):
			forms.append({empowered_wave = true, jianqi_attack = true,
				blood_payment = true})
		if b.can_jianqi_attack_action(player, a, true, true, true):
			forms.append({empowered_wave = true, jianqi_attack = true,
				blood_payment = true, energy_cap_discount = true})
		for form in forms:
			var choice: Dictionary = {action = a, target = action_target}
			choice.merge(form)
			out.append(choice)
	var ask: HeroSkill = b.get_skill(player, b.active_index[player])
	if ask != null and ask.has_active():
		var active_target := -1
		if ask.active_needs_enemy_target():
			# 带敌方目标的主动技（h21）：深层剪枝只带一个代表目标=敌方最低血替补。
			var pull_hp := 9999
			for es in b.living_reserves(1 - player):
				if b.hp[1 - player][es] < pull_hp:
					pull_hp = b.hp[1 - player][es]
					active_target = es
		for blood_payment in [false, true]:
			for energy_cap_discount in [false, true]:
				if b.can_use_active(player, blood_payment, energy_cap_discount):
					var active_choice := {action = ActionDef.ACTIVE, target = active_target}
					if blood_payment:
						active_choice["blood_payment"] = true
					if energy_cap_discount:
						active_choice["energy_cap_discount"] = true
					out.append(active_choice)
	# 最优切换（换到血最高替补）——同过 can_afford（动作锁定时切换可能非法）。
	if b.can_afford(player, ActionDef.Action.SWITCH):
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
