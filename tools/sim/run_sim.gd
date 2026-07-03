extends SceneTree

## AI 自对弈批量模拟器 —— 积累平衡测试数据。
##
## 两个 BattleAI（同时博弈短时最优）对打 N 局，随机阵容（默认 h01–h34 池），
## 输出：① 每局明细 CSV ② 汇总 md（胜率/回合分布/动作频率/各英雄胜率/道具使用）。
##
## 道具经济（2026-06-20 接入）：每局 econ_init() + 每回合双方在选动作前跑 BattleAI.run_item_economy
## （与实战 battle_screen._ai_pick 同启发）→ 批量平衡数据现已反映道具系统。
##
## 运行（项目根目录）：
##   godot --headless --path <proj> --script res://tools/sim/run_sim.gd -- --games 200 --seed 42
## 可选参数（-- 之后）：
##   --games N        对局数（默认 200）
##   --seed S         基础随机种子（默认 12345，决定阵容+rng → 可复现）
##   --pool A-B       英雄池 hAA..hBB（默认 1-34；星座白板 35-46 默认排除）
##   --max-turns T    单局回合上限（默认 120，超出记为未决 capped）
##   --out DIR        输出目录（默认 res://tools/sim/out/）
##   --plan-ab 1      A/B 验证 Part 2：A(规划道具 plan_items) vs B(不规划) 头对头 → out/ab_result.md
##   --upgrade-ab 1   A/B 验证 B：A(价值搜索升级) vs B(阈值升级) 头对头 → out/ab_result.md
##   --eval-ab 1      A/B 评估档转正：A(v1 基础) vs B(v2 牌感) 交叉头对头 → out/ab_result.md
##   --w K=V[,K=V]    双方【都】用此权重覆盖（生态观察模式；与 --ab 组合时 = A 侧基线权重）
##   --panel NAME     T1 测量面板：v1 内战(50) / v2 内战(50) / v1×v2 交叉(60) 三连跑
##                    → out_panel_NAME/{v1_eco,v2_eco,cross}/ 各完整报表 + panel_summary.md 对照表
##                    （--games N 可统一覆盖三份局数·冒烟用；推荐 --seed 42 保持面板间可比；
##                     并行版 = bash tools/sim/run_panel_parallel.sh·配 --panel-part / --panel-merge）

const HERO_DATA_DIR := "res://assets/data/heroes/"
const ROSTER_SIZE := 3
## 加时赛工程安全阀（规则上不限回合；白板 1v1 拖到此数按真平局计·防极端死循环）。
const OVERTIME_SAFETY_CAP := 300

## A/B 权重校准变体（B 侧用；A 侧恒为默认权重=空字典）。键 = BattleEval 常量名（T1）。
const AB_VARIANTS := {
	"energy_up": {"W_ENERGY": 18.0},          # 能量更值钱（更爱屯能）
	"energy_down": {"W_ENERGY": 6.0},         # 能量更不值（更激进出手）
	"alive_up": {"W_ALIVE": 900.0},           # 更重存活（更保守保人）
	"alive_down": {"W_ALIVE": 400.0},         # 更轻存活（更敢换）
	"hp_up": {"W_HP": 16.0},                  # 更重血量
	"flat_energy": {"W_ENERGY_EXTRA": 8.0},   # 屯多能更不廉价（默认已校准为 6.5·2026-07-03；此变体=再放宽一档）
	"status_off": {"W_STATUS_SCALE": 0.0},    # 关闭状态资产项（=#7 前旧行为·A/B 对照组）
}

var games := 200
var base_seed := 12345
var pool_first := 1
var pool_last := 34
var max_turns := 120
var out_dir := "res://tools/sim/out/"
var use_draft := true   # true=DraftAI 选人 / false=随机阵容
var depth := 2          # 对战 AI 搜索深度
var profile := 0        # 对战 AI 评估档：0=v1 基础 / 1=v2 进阶(牌感·熟练优秀玩家)
var ab_variant := ""    # A/B 校准：非空=A(默认权重) vs B(此变体) 头对头（见 AB_VARIANTS）
var both_weights := {}  # --w K=V[,K=V]：双方【都】用此权重覆盖（生态观察模式·区别于 --ab 的混打测强弱）
var plan_ab := false    # A/B：A(plan_items=true 规划道具) vs B(false 不规划) 头对头（验证 Part 2）
var upgrade_ab := false  # A/B：A(search_upgrade=true 价值搜索升级) vs B(false 阈值升级) 头对头（验证 B）
var eval_ab := false     # A/B：A(v1 基础评估) vs B(v2 进阶牌感) 交叉头对头（#4 转正对决·--eval-ab 1）
var pick_ab := false     # A/B：A(智能选牌 smart_draft) vs B(纯随机) 头对头（#6 验证·--pick-ab 1）
var panel_name := ""     # --panel NAME：T1 测量面板（v1 内战/v2 内战/v1×v2 交叉 + 汇总对照表）
var panel_part := ""     # --panel-part v1eco|v2eco|cross：只跑面板的一份（并行版·A 档·配 run_panel_parallel.sh）
var panel_merge := false # --panel-merge 1：读三份 part_metrics.json 合并出 panel_summary.md（并行版收尾）
var games_set := false   # --games 是否显式给出（panel 默认 50/50/60；显式则三份同 N·冒烟用）

var _hero_data := {}    # hero_id → HeroData（加载一次复用）
var _pool_hd: Array = []  # Array[HeroData]，与 ids 平行（drafter 用，返回索引）


func _initialize() -> void:
	_parse_args()
	var pool: Array = _load_pool()
	if pool.size() < ROSTER_SIZE:
		push_error("英雄池不足 %d（实得 %d）" % [ROSTER_SIZE, pool.size()])
		quit(1)
		return
	if panel_name != "":
		if panel_merge:
			_panel_merge()
		elif panel_part != "":
			_run_panel_part(pool)
		else:
			_run_panel(pool)   # 串行后备（并行版见 tools/sim/run_panel_parallel.sh）
	else:
		_run_batch(pool)
	print("=== 完成 ===")
	quit()


## 跑一批对局（按当前实例参数），完整报表写入 out_dir；返回关键指标字典（panel 汇总对照用）。
func _run_batch(pool: Array, label: String = "") -> Dictionary:
	print("=== AI 自对弈模拟 %s ===" % label)
	print("对局=%d  种子=%d  池=h%02d–h%02d(%d)  回合上限=%d  选人=%s  AI深度=%d  评估=%s" % [
		games, base_seed, pool_first, pool_last, pool.size(), max_turns,
		("drafter" if use_draft else "随机"), depth, ("v2进阶" if profile == 1 else "v1基础")])

	# 聚合容器
	var csv_rows: Array = []
	var win := {0: 0, 1: 0, 2: 0, -1: 0}   # winner: 0 平 / 1 P1 / 2 P2 / -1 未决(capped)
	var turns_list: Array = []
	var item_stat := {}                      # 道具统计（used = 提交盲选的道具次数）
	var action_count := {}                  # action int → 次数
	var hero_present := {}                   # hero_id → 出场局数
	var hero_win := {}                       # hero_id → 所在队获胜局数
	# 深层统计（2026-07-03·#1 统计增强）：伤害来源占比 / 大波拦截 / 各英雄主动技
	var stats := {dmg_action = 0, dmg_item = 0, bigwave_blocked = 0, active_uses = {}}
	# 加时赛统计（Q5）：主局平局/未决 → 3 选 1 白板 1v1 定胜负
	var ot := {count = 0, from_draw = 0, from_cap = 0, decided = 0, true_draw = 0, turns = []}
	var ab_a := 0      # A/B：A(默认权重)胜
	var ab_b := 0      # A/B：B(变体权重)胜
	var ab_draw := 0   # A/B：平/未决

	if ab_active():
		if eval_ab:
			print("【A/B】A=v1 基础评估 vs B=v2 进阶牌感 交叉头对头（交替先后手·#4 转正对决）")
		elif upgrade_ab:
			print("【A/B】A=价值搜索升级(search_upgrade=true) vs B=阈值升级(false) 头对头（交替先后手·验证 B）")
		elif plan_ab:
			print("【A/B】A=规划道具(plan_items=true) vs B=不规划(false) 头对头（两方实战都用道具·交替先后手）")
		else:
			print("【A/B 校准】A=默认权重  vs  B=变体「%s」=%s （交替先后手）" % [
				ab_variant, str(AB_VARIANTS.get(ab_variant, {}))])

	var setup_rng := RandomNumberGenerator.new()
	setup_rng.seed = base_seed

	for g in range(games):
		var seed_g: int = base_seed + g * 7919
		var r0: Array = []
		var r1: Array = []
		if use_draft:
			var d0 := DraftAI.new(seed_g + 11)
			var d1 := DraftAI.new(seed_g + 12)
			var ban0: Array = d0.choose_bans(_pool_hd, 3)
			var ban1: Array = d1.choose_bans(_pool_hd, 3)
			var banned: Array = ban0.duplicate()
			for bx in ban1:
				if not bx in banned:
					banned.append(bx)
			for idx in d0.choose_picks(_pool_hd, banned, 3):
				r0.append(pool[idx])
			for idx in d1.choose_picks(_pool_hd, banned, 3):
				r1.append(pool[idx])
		else:
			r0 = _pick_roster(pool, setup_rng)
			r1 = _pick_roster(pool, setup_rng)

		var b := BattleCore.new()
		b.setup(_to_heroes(r0), _to_heroes(r1), seed_g)
		b.econ_init()   # 启用道具经济（开局带 1 + 槽位状态机）→ AI 每回合走 run_item_economy
		# A/B 校准：A=默认权重、B=变体；偶数局 A=P0、奇数局 A=P1 → 抵消位置偏差。
		# --w 生态模式：双方同权重（与 --ab 互斥·--ab 优先）。
		var w0: Dictionary = both_weights.duplicate()
		var w1: Dictionary = both_weights.duplicate()
		if use_ab():
			var wb: Dictionary = AB_VARIANTS.get(ab_variant, {})
			if g % 2 == 0:
				w1 = wb   # A=P0, B=P1
			else:
				w0 = wb   # A=P1, B=P0
		var ai0 := BattleAI.new(seed_g + 1, depth, profile, w0)
		var ai1 := BattleAI.new(seed_g + 2, depth, profile, w1)
		if plan_ab:
			ai0.plan_items = (g % 2 == 0)   # A(规划道具)=偶数局 P0 / 奇数局 P1（抵消先后手偏差）
			ai1.plan_items = (g % 2 != 0)
		if upgrade_ab:
			ai0.search_upgrade = (g % 2 == 0)   # A(价值搜索升级)=偶数局 P0 / 奇数局 P1
			ai1.search_upgrade = (g % 2 != 0)
		if eval_ab:
			ai0.eval_profile = 0 if g % 2 == 0 else 1   # A(v1 基础)=偶数局 P0 / 奇数局 P1
			ai1.eval_profile = 1 if g % 2 == 0 else 0   # B(v2 牌感)=对侧
		if pick_ab:
			ai0.smart_draft = (g % 2 == 0)   # A(智能选牌)=偶数局 P0 / 奇数局 P1
			ai1.smart_draft = (g % 2 != 0)

		var res: Dictionary = _play(b, ai0, ai1, action_count, item_stat, stats)
		var w: int = res["winner"]
		# 加时赛（Q5·2026-07-03）：主局平局 / 打满上限 → 各自 3 选 1（AI=最大 HP）白板满血 1v1。
		# 加时动作/道具不计入主生态统计（传临时容器）→ 主报表口径不被稀释。
		if w == 0 or w == -1:
			ot["count"] = int(ot["count"]) + 1
			ot["from_draw" if w == 0 else "from_cap"] = int(ot["from_draw" if w == 0 else "from_cap"]) + 1
			var duel: BattleCore = BattleCore.create_overtime(
				b.heroes[0][BattleAI.choose_overtime_pick(b, 0)],
				b.heroes[1][BattleAI.choose_overtime_pick(b, 1)], seed_g + 777)
			var dai0 := BattleAI.new(seed_g + 3, depth, profile, w0)
			var dai1 := BattleAI.new(seed_g + 4, depth, profile, w1)
			dai0.eval_profile = ai0.eval_profile   # 加时沿用主局各侧评估档（eval_ab 交叉时一致）
			dai1.eval_profile = ai1.eval_profile
			var dres: Dictionary = _play(duel, dai0, dai1, {}, {}, {}, OVERTIME_SAFETY_CAP)
			(ot["turns"] as Array).append(int(dres["turns"]))
			var dw: int = int(dres["winner"])
			if dw == 1 or dw == 2:
				ot["decided"] = int(ot["decided"]) + 1
				w = dw
			else:
				ot["true_draw"] = int(ot["true_draw"]) + 1
				w = 0   # 加时再同归（或安全阀）= 真平局
		win[w] = win.get(w, 0) + 1
		turns_list.append(res["turns"])
		if ab_active():
			var a_side: int = 1 if (g % 2 == 0) else 2   # A 所在 player+1
			if w == a_side:
				ab_a += 1
			elif w == 1 or w == 2:
				ab_b += 1
			else:
				ab_draw += 1

		# 各英雄出场 / 胜场
		for id in r0:
			hero_present[id] = hero_present.get(id, 0) + 1
		for id in r1:
			hero_present[id] = hero_present.get(id, 0) + 1
		if w == 1:
			for id in r0:
				hero_win[id] = hero_win.get(id, 0) + 1
		elif w == 2:
			for id in r1:
				hero_win[id] = hero_win.get(id, 0) + 1

		csv_rows.append("%d,%d,%s,%s,%d,%d,%d,%d,%.1f,%.1f" % [
			g, seed_g, "|".join(r0), "|".join(r1), w, res["turns"],
			res["p0_alive"], res["p1_alive"], res["p0_hp"], res["p1_hp"]])

		if (g + 1) % 50 == 0:
			print("  ...%d/%d 局完成" % [g + 1, games])
			_write_progress(g + 1)

	_write_outputs(csv_rows, win, turns_list, action_count, hero_present, hero_win, item_stat, stats, ot)
	if ab_active():
		_write_ab(ab_a, ab_b, ab_draw)
	_write_progress(games)
	turns_list.sort()
	return {
		label = label, total = games, win = win,
		turns_med = (turns_list[turns_list.size() / 2] if not turns_list.is_empty() else 0),
		turns_avg = _avg(turns_list),
		actions = action_count, items_used = int(item_stat.get("used", 0)),
		stats = stats, ot = ot,
		ab = ({a = ab_a, b = ab_b, draw = ab_draw} if ab_active() else {}),
	}


const PANEL_ECO_GAMES := 50     # 面板生态份局数（Eddy 硬规：AI 优化期全小轮）
const PANEL_CROSS_GAMES := 60   # 面板交叉份局数


## T1 测量面板（2026-07-03 惯例）：每次平衡相关改动跑三份小轮——
##   ① v1 内战（大众生态）② v2 内战（高端局生态）③ v1×v2 交叉（强度追踪）。
## 输出：panel_<名>/ 下三份完整报表 + panel_summary.md 对照表。
## 判读：两份生态结论一致才采纳；不一致的行 = 对玩家水平敏感的设计（单独标记）；
##       交叉 decisive 大幅偏离 50% = 评估档强度漂移（复查最近改动）。
func _run_panel(pool: Array) -> void:
	print("=== T1 测量面板「%s」：v1 内战 / v2 内战 / v1×v2 交叉（串行） ===" % panel_name)
	var results: Array = []
	for part in _PANEL_PARTS:
		_apply_panel_part(String(part[0]))
		results.append(_run_batch(pool, String(part[1])))
	_write_panel_summary("res://tools/sim/out_panel_%s/" % panel_name, results)


## 面板分部定义：[part 名, 报表标签, 子目录]。
const _PANEL_PARTS := [
	["v1eco", "[v1 内战]", "v1_eco/"],
	["v2eco", "[v2 内战]", "v2_eco/"],
	["cross", "[v1×v2 交叉]", "cross/"],
]


## 按分部名设置实例参数（串行 _run_panel 与并行 _run_panel_part 共用）。
func _apply_panel_part(part: String) -> void:
	var root := "res://tools/sim/out_panel_%s/" % panel_name
	match part:
		"v1eco":
			profile = 0
			eval_ab = false
			games = games if games_set else PANEL_ECO_GAMES
			out_dir = root + "v1_eco/"
		"v2eco":
			profile = 1
			eval_ab = false
			games = games if games_set else PANEL_ECO_GAMES
			out_dir = root + "v2_eco/"
		"cross":
			profile = 0
			eval_ab = true
			games = games if games_set else PANEL_CROSS_GAMES
			out_dir = root + "cross/"
		_:
			push_error("未知 --panel-part：%s（可选 v1eco / v2eco / cross）" % part)


## 并行版·跑单份（A 档·2026-07-03）：跑完把指标存 part_metrics.json 供 --panel-merge 合并。
func _run_panel_part(pool: Array) -> void:
	var label := ""
	for p in _PANEL_PARTS:
		if String(p[0]) == panel_part:
			label = String(p[1])
	_apply_panel_part(panel_part)
	var r: Dictionary = _run_batch(pool, label)
	var f := FileAccess.open(out_dir + "part_metrics.json", FileAccess.WRITE)
	if f != null:
		# 头部字段随份存档 → merge 时以份内记录为准（不依赖 merge 调用方传对 --seed/--depth）
		f.store_string(JSON.stringify({seed = base_seed, depth = depth,
			pf = pool_first, pl = pool_last, m = r}))
		f.close()


## 并行版·合并（A 档）：读三份 part_metrics.json → panel_summary.md（JSON 数字键还原为 int）。
func _panel_merge() -> void:
	var root := "res://tools/sim/out_panel_%s/" % panel_name
	var results: Array = []
	for p in _PANEL_PARTS:
		var path: String = root + String(p[2]) + "part_metrics.json"
		var txt := FileAccess.get_file_as_string(path)
		if txt.is_empty():
			push_error("缺分部数据 %s——三份 --panel-part 都跑完了？" % path)
			return
		var wrap: Dictionary = JSON.parse_string(txt)
		base_seed = int(wrap.get("seed", base_seed))
		depth = int(wrap.get("depth", depth))
		pool_first = int(wrap.get("pf", pool_first))
		pool_last = int(wrap.get("pl", pool_last))
		var m: Dictionary = wrap.get("m", {})
		m["win"] = _intkeys(m.get("win", {}))
		m["actions"] = _intkeys(m.get("actions", {}))
		results.append(m)
	_write_panel_summary(root, results)


## JSON 往返后把字符串数字键还原为 int（win/actions 以 Action enum int 为键）。
func _intkeys(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[int(String(k))] = src[k]
	return out


## 面板汇总对照表：生态两列（v1/v2 内战）+ 交叉强度一节 + 判读指引。
func _write_panel_summary(root: String, results: Array) -> void:
	var v1: Dictionary = results[0]
	var v2: Dictionary = results[1]
	var cx: Dictionary = results[2]
	var f := FileAccess.open(root + "panel_summary.md", FileAccess.WRITE)
	if f == null:
		push_error("无法写 panel_summary.md")
		return
	f.store_line("# 测量面板「%s」汇总（T1 惯例）\n" % panel_name)
	f.store_line("- 生成：%s ｜ 种子：%d ｜ 池：h%02d–h%02d ｜ 深度：%d ｜ 局数：生态各 %d / 交叉 %d\n" % [
		Time.get_datetime_string_from_system(), base_seed, pool_first, pool_last, depth,
		int(v1["total"]), int(cx["total"])])
	f.store_line("## 生态对照（同种子·仅评估档不同）")
	f.store_line("| 指标 | v1 内战(大众) | v2 内战(高端) |")
	f.store_line("|------|------|------|")
	f.store_line(_prow("分出胜负", _decisive_pct(v1), _decisive_pct(v2)))
	f.store_line(_prow("真平局(含加时再平)", _win_pct(v1, 0), _win_pct(v2, 0)))
	f.store_line(_prow("回合 均值(中位)", "%.1f (%d)" % [float(v1["turns_avg"]), int(v1["turns_med"])],
		"%.1f (%d)" % [float(v2["turns_avg"]), int(v2["turns_med"])]))
	for a in _action_order():
		f.store_line(_prow(_action_label(a), _act_pct(v1, a), _act_pct(v2, a)))
	f.store_line(_prow("道具局均", "%.1f" % (float(v1["items_used"]) / maxf(1.0, float(v1["total"]))),
		"%.1f" % (float(v2["items_used"]) / maxf(1.0, float(v2["total"])))))
	f.store_line(_prow("道具伤害占比", _item_dmg_pct(v1), _item_dmg_pct(v2)))
	f.store_line(_prow("大波拦截率", _bw_block_pct(v1), _bw_block_pct(v2)))
	f.store_line(_prow("加时 触发/分出/再平", _ot_line(v1), _ot_line(v2)))
	var ab: Dictionary = cx.get("ab", {})
	var a_w: int = int(ab.get("a", 0))
	var b_w: int = int(ab.get("b", 0))
	f.store_line("\n## 强度追踪（v1×v2 交叉 %d 局·交替先后手）" % int(cx["total"]))
	f.store_line("- v1 胜 %d ｜ v2 胜 %d ｜ 平 %d → v1 decisive 占比 **%s**（基线 ≈50%%）\n" % [
		a_w, b_w, int(ab.get("draw", 0)), _pct(a_w, a_w + b_w)])
	f.store_line("## 判读指引")
	f.store_line("- 生态两列结论**一致** → 采纳该平衡判断；**不一致的行** = 对玩家水平敏感的设计（单独标记复查）。")
	f.store_line("- 交叉 decisive 大幅偏离 50% → 评估档强度漂移，复查最近对共享层/评估的改动。")
	f.store_line("- 局数为小轮（Eddy 硬规）：单行 ±5-8% 属噪声，只对大差距（≥10%）下结论。")
	f.close()
	print("写出 %spanel_summary.md" % root)


func _prow(name: String, a: String, b: String) -> String:
	return "| %s | %s | %s |" % [name, a, b]


func _decisive_pct(r: Dictionary) -> String:
	var w: Dictionary = r["win"]
	return _pct(int(w.get(1, 0)) + int(w.get(2, 0)), int(r["total"]))


func _win_pct(r: Dictionary, key: int) -> String:
	return _pct(int((r["win"] as Dictionary).get(key, 0)), int(r["total"]))


func _act_pct(r: Dictionary, action: int) -> String:
	var ac: Dictionary = r["actions"]
	var total := 0
	for k in ac:
		total += int(ac[k])
	return _pct(int(ac.get(action, 0)), total)


func _item_dmg_pct(r: Dictionary) -> String:
	var st: Dictionary = r["stats"]
	return _pct(int(st.get("dmg_item", 0)), int(st.get("dmg_item", 0)) + int(st.get("dmg_action", 0)))


func _bw_block_pct(r: Dictionary) -> String:
	var st: Dictionary = r["stats"]
	return _pct(int(st.get("bigwave_blocked", 0)), int((r["actions"] as Dictionary).get(ActionDef.Action.BIG_ATTACK, 0)))


func _ot_line(r: Dictionary) -> String:
	var ot: Dictionary = r["ot"]
	return "%d / %d / %d" % [int(ot.get("count", 0)), int(ot.get("decided", 0)), int(ot.get("true_draw", 0))]


func use_ab() -> bool:
	return ab_variant != ""


## A/B 计数 / 输出是否激活（权重变体 / 道具规划 / 升级择时 / 评估档 / 选牌 头对头）。
func ab_active() -> bool:
	return ab_variant != "" or plan_ab or upgrade_ab or eval_ab or pick_ab


## A/B 变体名（用于标签）。
func _ab_name() -> String:
	if pick_ab:
		return "智能选牌(smart_draft)"
	if eval_ab:
		return "评估档对决(v1 vs v2)"
	if upgrade_ab:
		return "升级价值搜索(search_upgrade)"
	if plan_ab:
		return "道具推演规划(plan_items)"
	return ab_variant


## 进度文件（每 50 局刷新，随时可 Read 查看进度；解决 stdout 缓冲不可见问题）。
func _write_progress(done: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var f := FileAccess.open(out_dir + "progress.txt", FileAccess.WRITE)
	if f != null:
		f.store_line("%d / %d 局完成 (%.1f%%)" % [done, games, 100.0 * float(done) / float(games)])
		f.close()


## A/B 校准结果（B 的 decisive 胜率 >50% → 变体更强）。
func _write_ab(a: int, b: int, draw: int) -> void:
	var total: int = a + b + draw
	var decisive: int = a + b
	var a_label: String
	var b_label: String
	var desc: String
	var focus: String
	var title: String
	if pick_ab:
		a_label = "智能选牌"
		b_label = "随机选牌"
		desc = "A=智能选牌(smart_draft=true·启发式) ｜ B=纯随机（同权重同评估·仅 3 选 1 选牌不同·#6 验证）"
		focus = "A(智能选牌)"
		title = "道具选牌(#6)"
	elif eval_ab:
		a_label = "v1基础评估"
		b_label = "v2进阶牌感"
		desc = "A=v1 基础评估(profile 0·现役默认) ｜ B=v2 进阶牌感(profile 1)（同权重同搜索·仅评估档不同·#4 转正对决）"
		focus = "B(v2牌感)"
		title = "评估档转正(v1 vs v2)"
	elif upgrade_ab:
		a_label = "价值搜索升级"
		b_label = "阈值升级"
		desc = "A=价值搜索升级(search_upgrade=true·plan_economy) ｜ B=阈值升级(run_item_economy)（两方实战同·仅升级择时不同）"
		focus = "A(价值搜索升级)"
		title = "升级择时(B)"
	elif plan_ab:
		a_label = "规划道具"
		b_label = "不规划"
		desc = "A=规划道具(plan_items=true) ｜ B=不规划（两方实战都用道具，仅 AI lookahead 不同）"
		focus = "A(规划道具)"
		title = "道具推演规划"
	else:
		a_label = "默认权重"
		b_label = "变体" + _ab_name()
		desc = "A=默认权重 ｜ B=变体「%s」=%s" % [ab_variant, str(AB_VARIANTS.get(ab_variant, {}))]
		focus = "B(变体)"
		title = "权重校准"
	var f := FileAccess.open(out_dir + "ab_result.md", FileAccess.WRITE)
	if f != null:
		f.store_line("# A/B %s 结果\n" % title)
		f.store_line("- %s" % desc)
		f.store_line("- 对局=%d（交替先后手抵消位置偏差）\n" % total)
		f.store_line("| 侧 | 胜 | 总占比 | decisive 占比 |")
		f.store_line("|----|----|------|------|")
		f.store_line("| A(%s) | %d | %s | %s |" % [a_label, a, _pct(a, total), _pct(a, decisive)])
		f.store_line("| B(%s) | %d | %s | %s |" % [b_label, b, _pct(b, total), _pct(b, decisive)])
		f.store_line("| 平/未决 | %d | %s | — |" % [draw, _pct(draw, total)])
		f.store_line("\n> 判读：%s 的 decisive 胜率显著 >50%% → 更强（可采纳）；≈50%% → 无差异；<50%% → 更弱。" % focus)
		f.close()
	print("【A/B】A(%s) %d 胜 / B(%s) %d 胜 / 平%d → %sab_result.md" % [a_label, a, b_label, b, draw, out_dir])


## 跑一局到结束或回合上限。返回 {winner, turns, p0_alive, p1_alive, p0_hp, p1_hp}。
## stats（可选）：深层统计累加器 {dmg_action, dmg_item, bigwave_blocked, active_uses:{hero_id:次数}}。
## cap（可选）：本局回合上限覆盖（加时赛安全阀用）；<=0 = 用全局 max_turns。
func _play(b: BattleCore, ai0: BattleAI, ai1: BattleAI, action_count: Dictionary, item_stat: Dictionary, stats: Dictionary = {}, cap: int = -1) -> Dictionary:
	var limit: int = cap if cap > 0 else max_turns
	while not b.game_over and b.turn_number < limit:
		# 道具经济：选动作【前】双方自动管理道具栏（与实战 _ai_pick 同启发·补/升扣能 → 动作据剩余能量；
		# 进攻向道具按兵不动 → 动作定为攻击后 commit_attack_items 一并甩出·2026-07-03）。
		ai0.plan_economy(b, 0, ai0.rng)
		ai1.plan_economy(b, 1, ai1.rng)
		# 双方从同一结算前状态同时盲选
		var c0: Dictionary = ai0.choose_action(b, 0)
		var c1: Dictionary = ai1.choose_action(b, 1)
		BattleAI.commit_attack_items(b, 0, int(c0["action"]))
		BattleAI.commit_attack_items(b, 1, int(c1["action"]))
		item_stat["used"] = item_stat.get("used", 0) + b.item_uses[0].size() + b.item_uses[1].size()
		_tally(action_count, int(c0["action"]))
		_tally(action_count, int(c1["action"]))
		# 各英雄主动技使用（选择时点记·出战英雄即释放者）
		if not stats.is_empty():
			for pc in [[0, c0], [1, c1]]:
				var pi: int = int(pc[0])
				if int((pc[1] as Dictionary)["action"]) == ActionDef.ACTIVE:
					var hid: String = (b.heroes[pi][b.active_index[pi]] as HeroData).hero_id
					var au: Dictionary = stats["active_uses"]
					au[hid] = int(au.get(hid, 0)) + 1
		if not b.apply_choice(0, c0):
			b.select_action(0, ActionDef.Action.CHARGE)
		if not b.apply_choice(1, c1):
			b.select_action(1, ActionDef.Action.CHARGE)
		var rr: Dictionary = b.resolve()
		if not stats.is_empty():
			_scan_events(rr.get("events", []), stats)
		# 出战阵亡 → AI 选替补上场
		for p in [0, 1]:
			if b.pending_death_switch[p]:
				var ai: BattleAI = ai0 if p == 0 else ai1
				var slot: int = ai.choose_death_switch(b, p)
				if slot >= 0:
					b.execute_death_switch(p, slot)

	return {
		winner = b.winner if b.game_over else -1,
		turns = b.turn_number,
		p0_alive = b.alive_count(0),
		p1_alive = b.alive_count(1),
		p0_hp = _team_hp(b, 0),
		p1_hp = _team_hp(b, 1),
	}


## 扫一回合事件流入深层统计：伤害来源占比（动作/技能 vs 道具）+ 大波被大防拦截数。
## 道具系伤害 = damage_taken(src=item) + 延迟伤害(妖火/藤蔓) + 尾后针反击。
func _scan_events(events: Array, stats: Dictionary) -> void:
	for ev in events:
		match String(ev.get("id", "")):
			"damage_taken":
				if String(ev.get("src", "action")) == "item":
					stats["dmg_item"] = int(stats["dmg_item"]) + int(ev.get("amount", 0))
				else:
					stats["dmg_action"] = int(stats["dmg_action"]) + int(ev.get("amount", 0))
			"deferred_damage":
				stats["dmg_item"] = int(stats["dmg_item"]) + int(ev.get("amount", 0))
			"weihouzhen_sting":
				stats["dmg_item"] = int(stats["dmg_item"]) + BattleCore.WEIHOUZHEN_STING_DMG
			"big_defend_block":
				if String(ev.get("src", "action")) == "action" and int(ev.get("kind", -1)) == ActionDef.Action.BIG_ATTACK:
					stats["bigwave_blocked"] = int(stats["bigwave_blocked"]) + 1


func _team_hp(b: BattleCore, p: int) -> float:
	var t := 0
	for v in b.hp[p]:
		t += maxi(int(v), 0)
	return float(t) / float(ActionDef.HP_UNIT)


func _tally(d: Dictionary, key: int) -> void:
	d[key] = d.get(key, 0) + 1


func _pick_roster(pool: Array, rng: RandomNumberGenerator) -> Array:
	var idxs: Array = []
	while idxs.size() < ROSTER_SIZE:
		var i: int = rng.randi_range(0, pool.size() - 1)
		if not idxs.has(i):
			idxs.append(i)
	var out: Array = []
	for i in idxs:
		out.append(pool[i])
	return out


func _to_heroes(roster: Array) -> Array:
	var arr: Array = []
	for id in roster:
		arr.append(_hero_data[id])
	return arr


func _load_pool() -> Array:
	var ids: Array = []
	for n in range(pool_first, pool_last + 1):
		var id := "h%02d" % n
		var path := HERO_DATA_DIR + id + ".tres"
		if not ResourceLoader.exists(path):
			continue
		var hd: HeroData = load(path)
		if hd == null:
			continue
		_hero_data[id] = hd
		_pool_hd.append(hd)
		ids.append(id)
	return ids


# === 输出 ===

func _write_outputs(csv_rows: Array, win: Dictionary, turns_list: Array,
		action_count: Dictionary, hero_present: Dictionary, hero_win: Dictionary,
		item_stat: Dictionary = {}, stats: Dictionary = {}, ot: Dictionary = {}) -> void:
	var abs_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	# --- 每局 CSV ---
	var csv := FileAccess.open(out_dir + "sim_games.csv", FileAccess.WRITE)
	if csv != null:
		csv.store_line("game,seed,p0_heroes,p1_heroes,winner,turns,p0_alive,p1_alive,p0_hp,p1_hp")
		for r in csv_rows:
			csv.store_line(r)
		csv.close()
		print("写出 %ssim_games.csv（%d 行）" % [out_dir, csv_rows.size()])

	# --- 汇总 md ---
	var md := FileAccess.open(out_dir + "sim_summary.md", FileAccess.WRITE)
	if md == null:
		push_error("无法写汇总 md")
		return
	var total: int = csv_rows.size()
	md.store_line("# AI 自对弈模拟汇总\n")
	md.store_line("- 对局数：**%d**" % total)
	md.store_line("- 基础种子：%d ｜ 英雄池：h%02d–h%02d ｜ 回合上限：%d ｜ 选人：%s ｜ AI深度：%d ｜ 评估：%s\n" % [
		base_seed, pool_first, pool_last, max_turns, ("drafter" if use_draft else "随机"), depth,
		("v2进阶" if profile == 1 else "v1基础")])

	md.store_line("## 胜负分布")
	md.store_line("| 结果 | 局数 | 占比 |")
	md.store_line("|------|------|------|")
	md.store_line("| P1 先手胜 | %d | %s |" % [win.get(1, 0), _pct(win.get(1, 0), total)])
	md.store_line("| P2 后手胜 | %d | %s |" % [win.get(2, 0), _pct(win.get(2, 0), total)])
	md.store_line("| 真平局(含加时再平) | %d | %s |" % [win.get(0, 0), _pct(win.get(0, 0), total)])
	md.store_line("| 未决(达回合上限) | %d | %s |\n" % [win.get(-1, 0), _pct(win.get(-1, 0), total)])

	# 加时赛（Q5·主局平局/未决 → 3 选 1 白板 1v1）
	if not ot.is_empty() and int(ot.get("count", 0)) > 0:
		var ot_turns: Array = ot.get("turns", [])
		md.store_line("## 加时赛（主局平局/未决 → 3 选 1 白板 1v1·无技能无道具）")
		md.store_line("- 触发 **%d** 局（主局平局 %d / 打满上限 %d）｜加时分出胜负 **%d** ｜ 加时再平 %d ｜ 加时均值 %.1f 回合\n" % [
			int(ot["count"]), int(ot["from_draw"]), int(ot["from_cap"]),
			int(ot["decided"]), int(ot["true_draw"]), _avg(ot_turns)])

	# 回合分布
	turns_list.sort()
	md.store_line("## 回合数分布")
	if not turns_list.is_empty():
		md.store_line("- 最短 %d ｜ 中位 %d ｜ 均值 %.1f ｜ 最长 %d\n" % [
			turns_list[0], turns_list[turns_list.size() / 2], _avg(turns_list), turns_list[-1]])

	# 动作频率
	md.store_line("## 动作频率（双方全部决策）")
	md.store_line("| 动作 | 次数 | 占比 |")
	md.store_line("|------|------|------|")
	var act_total := 0
	for k in action_count:
		act_total += action_count[k]
	for k in _action_order():
		if action_count.has(k):
			md.store_line("| %s | %d | %s |" % [_action_label(k), action_count[k], _pct(action_count[k], act_total)])
	md.store_line("")

	# 道具使用（验证经济已接入·总提交盲选道具次数 / 局均）
	var items_used: int = int(item_stat.get("used", 0))
	md.store_line("## 道具使用")
	md.store_line("- 总提交道具次数：**%d** ｜ 局均：%.2f 次/局\n" % [
		items_used, (float(items_used) / float(total) if total > 0 else 0.0)])

	# 深层统计（2026-07-03·#1 统计增强）：伤害来源占比 + 大波拦截率
	if not stats.is_empty():
		var da: int = int(stats.get("dmg_action", 0))
		var di: int = int(stats.get("dmg_item", 0))
		md.store_line("## 伤害来源占比（落 HP 的半点）")
		md.store_line("- 动作/技能伤害：**%d** ｜ 道具系伤害：**%d** ｜ 道具占比：**%s**\n" % [
			da, di, _pct(di, da + di)])
		var bw_total: int = int(action_count.get(ActionDef.Action.BIG_ATTACK, 0))
		var bw_blocked: int = int(stats.get("bigwave_blocked", 0))
		md.store_line("## 大波拦截")
		md.store_line("- 大波总数：**%d** ｜ 被大防挡下：**%d**（拦截率 %s）\n" % [
			bw_total, bw_blocked, _pct(bw_blocked, bw_total)])

	# 各英雄胜率 + 主动技使用（present 降序里按胜率排）
	var active_uses: Dictionary = stats.get("active_uses", {})
	md.store_line("## 各英雄胜率 / 主动技（出场 ≥1 局）")
	md.store_line("| 英雄 | 出场 | 胜 | 胜率 | 主动技次数 | 次/出场局 |")
	md.store_line("|------|------|----|------|-----------|----------|")
	var ids: Array = hero_present.keys()
	ids.sort_custom(func(a, b): return _wr(hero_win, hero_present, a) > _wr(hero_win, hero_present, b))
	for id in ids:
		var pre: int = hero_present[id]
		var wn: int = hero_win.get(id, 0)
		var act: int = int(active_uses.get(id, 0))
		md.store_line("| %s | %d | %d | %s | %d | %.2f |" % [
			id, pre, wn, _pct(wn, pre), act, (float(act) / float(pre) if pre > 0 else 0.0)])
	md.close()
	print("写出 %ssim_summary.md" % out_dir)


func _wr(hwin: Dictionary, hpre: Dictionary, id: String) -> float:
	var p: int = hpre.get(id, 0)
	return float(hwin.get(id, 0)) / float(p) if p > 0 else 0.0


func _pct(n: int, total: int) -> String:
	return "%.1f%%" % (100.0 * float(n) / float(total)) if total > 0 else "—"


func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0
	for v in arr:
		s += int(v)
	return float(s) / float(arr.size())


func _action_order() -> Array:
	return [ActionDef.Action.CHARGE, ActionDef.Action.ATTACK, ActionDef.Action.DEFEND,
		ActionDef.Action.BIG_ATTACK, ActionDef.Action.BIG_DEFEND, ActionDef.Action.SWITCH, ActionDef.ACTIVE]


func _action_label(a: int) -> String:
	match a:
		ActionDef.Action.CHARGE: return "攒"
		ActionDef.Action.ATTACK: return "波"
		ActionDef.Action.DEFEND: return "防"
		ActionDef.Action.BIG_ATTACK: return "大波"
		ActionDef.Action.BIG_DEFEND: return "大防"
		ActionDef.Action.SWITCH: return "切换"
		ActionDef.ACTIVE: return "主动技"
	return "?(%d)" % a


# === 参数解析 ===

func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key: String = args[i]
		var val: String = args[i + 1] if i + 1 < args.size() else ""
		match key:
			"--games":
				games = int(val)
				games_set = true
			"--panel": panel_name = val
			"--panel-part": panel_part = val
			"--panel-merge": panel_merge = int(val) != 0
			"--seed": base_seed = int(val)
			"--max-turns": max_turns = int(val)
			"--depth": depth = int(val)
			"--profile": profile = int(val)
			"--draft": use_draft = int(val) != 0
			"--ab": ab_variant = val
			"--w":
				for pair in val.split(","):
					var kv := (pair as String).split("=")
					if kv.size() == 2:
						both_weights[kv[0]] = float(kv[1])
			"--plan-ab": plan_ab = int(val) != 0
			"--upgrade-ab": upgrade_ab = int(val) != 0
			"--eval-ab": eval_ab = int(val) != 0
			"--pick-ab": pick_ab = int(val) != 0
			"--out": out_dir = val
			"--pool":
				var parts := val.split("-")
				if parts.size() == 2:
					pool_first = int(parts[0])
					pool_last = int(parts[1])
		i += 2
