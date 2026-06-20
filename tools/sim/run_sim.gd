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

const HERO_DATA_DIR := "res://assets/data/heroes/"
const ROSTER_SIZE := 3

## A/B 权重校准变体（B 侧用；A 侧恒为默认权重=空字典）。键 = BattleEval 常量名（T1）。
const AB_VARIANTS := {
	"energy_up": {"W_ENERGY": 18.0},          # 能量更值钱（更爱屯能）
	"energy_down": {"W_ENERGY": 6.0},         # 能量更不值（更激进出手）
	"alive_up": {"W_ALIVE": 900.0},           # 更重存活（更保守保人）
	"alive_down": {"W_ALIVE": 400.0},         # 更轻存活（更敢换）
	"hp_up": {"W_HP": 16.0},                  # 更重血量
	"flat_energy": {"W_ENERGY_EXTRA": 8.0},   # 屯多能不再廉价（弱化边际递减）
}

var games := 200
var base_seed := 12345
var pool_first := 1
var pool_last := 34
var max_turns := 120
var out_dir := "res://tools/sim/out/"
var use_draft := true   # true=DraftAI 选人 / false=随机阵容
var depth := 2          # 对战 AI 搜索深度
var profile := 0        # 对战 AI 评估档：0=基础 / 1=v3 牌感(熟练优秀玩家)
var ab_variant := ""    # A/B 校准：非空=A(默认权重) vs B(此变体) 头对头（见 AB_VARIANTS）
var plan_ab := false    # A/B：A(plan_items=true 规划道具) vs B(false 不规划) 头对头（验证 Part 2）

var _hero_data := {}    # hero_id → HeroData（加载一次复用）
var _pool_hd: Array = []  # Array[HeroData]，与 ids 平行（drafter 用，返回索引）


func _initialize() -> void:
	_parse_args()
	var pool: Array = _load_pool()
	if pool.size() < ROSTER_SIZE:
		push_error("英雄池不足 %d（实得 %d）" % [ROSTER_SIZE, pool.size()])
		quit(1)
		return

	print("=== AI 自对弈模拟 ===")
	print("对局=%d  种子=%d  池=h%02d–h%02d(%d)  回合上限=%d  选人=%s  AI深度=%d  评估=%s" % [
		games, base_seed, pool_first, pool_last, pool.size(), max_turns,
		("drafter" if use_draft else "随机"), depth, ("v3牌感" if profile == 1 else "基础")])

	# 聚合容器
	var csv_rows: Array = []
	var win := {0: 0, 1: 0, 2: 0, -1: 0}   # winner: 0 平 / 1 P1 / 2 P2 / -1 未决(capped)
	var turns_list: Array = []
	var item_stat := {}                      # 道具统计（used = 提交盲选的道具次数）
	var action_count := {}                  # action int → 次数
	var hero_present := {}                   # hero_id → 出场局数
	var hero_win := {}                       # hero_id → 所在队获胜局数
	var ab_a := 0      # A/B：A(默认权重)胜
	var ab_b := 0      # A/B：B(变体权重)胜
	var ab_draw := 0   # A/B：平/未决

	if ab_active():
		if plan_ab:
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
		# A/B 校准：A=默认权重、B=变体；偶数局 A=P0、奇数局 A=P1 → 抵消位置偏差
		var w0: Dictionary = {}
		var w1: Dictionary = {}
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

		var res: Dictionary = _play(b, ai0, ai1, action_count, item_stat)
		var w: int = res["winner"]
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

	_write_outputs(csv_rows, win, turns_list, action_count, hero_present, hero_win, item_stat)
	if ab_active():
		_write_ab(ab_a, ab_b, ab_draw)
	_write_progress(games)
	print("=== 完成 ===")
	quit()


func use_ab() -> bool:
	return ab_variant != ""


## A/B 计数 / 输出是否激活（权重变体 或 道具规划头对头）。
func ab_active() -> bool:
	return ab_variant != "" or plan_ab


## A/B 变体名（用于标签）。
func _ab_name() -> String:
	return "道具推演规划(plan_items)" if plan_ab else ab_variant


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
	var a_label := "规划道具" if plan_ab else "默认权重"
	var b_label := "不规划" if plan_ab else ("变体" + _ab_name())
	var desc := ("A=规划道具(plan_items=true) ｜ B=不规划（两方实战都用道具，仅 AI lookahead 不同）" if plan_ab
		else "A=默认权重 ｜ B=变体「%s」=%s" % [ab_variant, str(AB_VARIANTS.get(ab_variant, {}))])
	# 关注侧：plan_ab → A(新特性 plan_items)；权重 → B(变体)。
	var focus := "A(规划道具)" if plan_ab else "B(变体)"
	var f := FileAccess.open(out_dir + "ab_result.md", FileAccess.WRITE)
	if f != null:
		f.store_line("# A/B %s 结果\n" % ("道具推演规划" if plan_ab else "权重校准"))
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
func _play(b: BattleCore, ai0: BattleAI, ai1: BattleAI, action_count: Dictionary, item_stat: Dictionary) -> Dictionary:
	while not b.game_over and b.turn_number < max_turns:
		# 道具经济：选动作【前】双方自动管理道具栏（与实战 _ai_pick 同启发·开格立即扣能 → 动作据剩余能量）。
		BattleAI.run_item_economy(b, 0, ai0.rng)
		BattleAI.run_item_economy(b, 1, ai1.rng)
		item_stat["used"] = item_stat.get("used", 0) + b.item_uses[0].size() + b.item_uses[1].size()
		# 双方从同一结算前状态同时盲选
		var c0: Dictionary = ai0.choose_action(b, 0)
		var c1: Dictionary = ai1.choose_action(b, 1)
		_tally(action_count, int(c0["action"]))
		_tally(action_count, int(c1["action"]))
		if not b.apply_choice(0, c0):
			b.select_action(0, ActionDef.Action.CHARGE)
		if not b.apply_choice(1, c1):
			b.select_action(1, ActionDef.Action.CHARGE)
		b.resolve()
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
		item_stat: Dictionary = {}) -> void:
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
		("v3牌感" if profile == 1 else "基础")])

	md.store_line("## 胜负分布")
	md.store_line("| 结果 | 局数 | 占比 |")
	md.store_line("|------|------|------|")
	md.store_line("| P1 先手胜 | %d | %s |" % [win.get(1, 0), _pct(win.get(1, 0), total)])
	md.store_line("| P2 后手胜 | %d | %s |" % [win.get(2, 0), _pct(win.get(2, 0), total)])
	md.store_line("| 平局 | %d | %s |" % [win.get(0, 0), _pct(win.get(0, 0), total)])
	md.store_line("| 未决(达回合上限) | %d | %s |\n" % [win.get(-1, 0), _pct(win.get(-1, 0), total)])

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

	# 各英雄胜率（present 降序里按胜率排）
	md.store_line("## 各英雄胜率（出场 ≥1 局）")
	md.store_line("| 英雄 | 出场 | 胜 | 胜率 |")
	md.store_line("|------|------|----|------|")
	var ids: Array = hero_present.keys()
	ids.sort_custom(func(a, b): return _wr(hero_win, hero_present, a) > _wr(hero_win, hero_present, b))
	for id in ids:
		var pre: int = hero_present[id]
		var wn: int = hero_win.get(id, 0)
		md.store_line("| %s | %d | %d | %s |" % [id, pre, wn, _pct(wn, pre)])
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
			"--games": games = int(val)
			"--seed": base_seed = int(val)
			"--max-turns": max_turns = int(val)
			"--depth": depth = int(val)
			"--profile": profile = int(val)
			"--draft": use_draft = int(val) != 0
			"--ab": ab_variant = val
			"--plan-ab": plan_ab = int(val) != 0
			"--out": out_dir = val
			"--pool":
				var parts := val.split("-")
				if parts.size() == 2:
					pool_first = int(parts[0])
					pool_last = int(parts[1])
		i += 2
