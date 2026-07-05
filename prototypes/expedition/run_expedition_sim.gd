extends SceneTree

## 远征原型·PvE 战斗 headless 校准（prototypes 隔离区·可丢弃）
## 用法：godot --headless --path <proj> --script res://prototypes/expedition/run_expedition_sim.gd
## 每只怪 × FIGHTS 场：白板 HP5 单英雄玩家（BattleAI v1·depth2）vs 怪物驾驶员——
## 无道具无技能 = 纯动作层校准。验收三件事（design/expedition-monsters.md §8）：
##   ① 明牌真实性：显示概率（逐拍期望累加）vs 实际采样频率 ≤2pp
##   ② 遭遇拍数带：T1 6-12 / T2 12-18 / T3 18-25（中位数·±20%）
##   ③ 玩家胜率（应 >50%·怪是关卡不是对手）+ 循环 fallback 计数（>0 = 设计异味）
## 输出：res://prototypes/expedition/out_calibration.md

const MonsterPolicy := preload("res://prototypes/expedition/monster_policy.gd")

const FIGHTS := 60
const FIGHT_CAP := 60          # 单场拍数安全阀
const PLAYER_HP := 5
const BASE_SEED := 20260705
const BANDS := {1: [6, 12], 2: [12, 18], 3: [18, 25]}


func _initialize() -> void:
	var f := FileAccess.open("res://prototypes/expedition/expedition_monsters.json", FileAccess.READ)
	var defs: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var lines: Array[String] = []
	lines.append("# 远征 PvE 战斗校准报告（原型·%d 场/怪·白板玩家 vs 怪物驾驶员）" % FIGHTS)
	lines.append("")
	lines.append("| 怪 | 层 | 拍数中位(带) | 玩家胜率 | 明牌最大偏差 | 表采样拍数 | fallback | 判定 |")
	lines.append("|----|----|--------------|----------|--------------|-----------|----------|------|")
	var ids: Array = defs.keys()
	ids.sort()
	var all_pass := true
	for id in ids:
		var d: Dictionary = defs[id]
		var r: Dictionary = _calibrate_monster(id, d)
		var band: Array = BANDS[int(d["tier"])]
		var band_ok: bool = r["median"] >= int(band[0]) * 0.8 and r["median"] <= int(band[1]) * 1.2
		var odds_ok: bool = r["maxDiff"] <= 2.0
		var ok: bool = band_ok and odds_ok and int(r["fallback"]) == 0
		if not ok:
			all_pass = false
		lines.append("| %s %s | T%d | %d (%d-%d)%s | %.0f%% | %.1fpp%s | %d | %d | %s |" % [
			id, d["name"], d["tier"], r["median"], band[0], band[1], "✓" if band_ok else "✗",
			100.0 * r["playerWins"] / FIGHTS, r["maxDiff"], "✓" if odds_ok else "✗",
			r["oddsBeats"], r["fallback"], "✅" if ok else "⚠"])
	lines.append("")
	lines.append("总判定：%s（带宽判定含 ±20% 容差；明牌偏差阈 2pp=设计验收标准）" % ("✅ 全部通过" if all_pass else "⚠ 有未过项·见上表"))
	var out := FileAccess.open("res://prototypes/expedition/out_calibration.md", FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("\n".join(lines))
	quit(0)


func _calibrate_monster(id: String, d: Dictionary) -> Dictionary:
	var beats_list: Array[int] = []
	var player_wins: int = 0
	var fallback: int = 0
	# 明牌对账：exp[action]=显示概率累加(期望次数) / act[action]=实际采样次数 —— 只累计有表的拍
	var exp_cnt: Dictionary = {}
	var act_cnt: Dictionary = {}
	var odds_beats: int = 0
	for fi in range(FIGHTS):
		var seed_f: int = BASE_SEED + id.hash() % 100000 + fi * 7
		var player := _vanilla("player", PLAYER_HP)
		var monster := _vanilla(String(d["name"]), int(d["hp"]))
		var b := BattleCore.new()
		b.setup([player], [monster], seed_f)
		var ai := BattleAI.new(seed_f + 1, 2)
		var policy: RefCounted = MonsterPolicy.new(d, seed_f + 2)
		while not b.game_over and b.turn_number < FIGHT_CAP:
			var c0: Dictionary = ai.choose_action(b, 0)
			var m: Dictionary = policy.pick(b, 1)
			var shown: Dictionary = m["odds"]
			if not shown.is_empty():
				odds_beats += 1
				for k in shown:
					exp_cnt[k] = float(exp_cnt.get(k, 0.0)) + float(shown[k]) / 100.0
				var ck: String = String(m.get("chosenKey", ""))
				act_cnt[ck] = int(act_cnt.get(ck, 0)) + 1
			if not b.apply_choice(0, c0):
				b.select_action(0, ActionDef.Action.CHARGE)
			b.select_action(1, int(m["action"]))
			b.resolve()
		beats_list.append(b.turn_number)
		if b.winner == BattleCore.WINNER_P1:
			player_wins += 1
		fallback += int(policy.fallback_count)
		policy.fallback_count = 0
	beats_list.sort()
	# 明牌偏差：每动作 |期望% − 实际%|（分母=有表拍数）取最大
	var max_diff: float = 0.0
	if odds_beats > 0:
		var keys: Dictionary = {}
		for k in exp_cnt:
			keys[k] = true
		for k in act_cnt:
			keys[k] = true
		for k in keys:
			var e: float = 100.0 * float(exp_cnt.get(k, 0.0)) / odds_beats
			var a: float = 100.0 * float(act_cnt.get(k, 0)) / odds_beats
			max_diff = maxf(max_diff, absf(e - a))
	return {
		median = beats_list[beats_list.size() / 2], playerWins = player_wins,
		maxDiff = max_diff, oddsBeats = odds_beats, fallback = fallback,
	}


func _vanilla(display_name: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = ""          # 空 id = 不注册技能组件（白板）
	h.hero_name = display_name
	h.max_hp = hp
	return h
