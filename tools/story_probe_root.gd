extends Node

## 故事模式壳 E2E 探针（任务 B·2026-07-12）：选关屏 → 简介浮层 → BattleSetup 交接 →
## 真战斗注入速胜 → story_result 回程 → 新选关屏消费（✓+解锁链）。带窗口跑：
##   godot --path . res://tools/story_probe.tscn
## ⚠ 不点「开战」按钮/不等回程转场（TransitionManager 换场景会把探针根释放）——
##   交接与回程两步直接调私有/读总线断言，转场前把战斗屏收走。
## 输出：统一探针目录。故事进度写入独立探针存档，不接触真实进度。

const ProbeOutput := preload("res://tools/probe_output.gd")

var _probe_save_file := ""


func _ready() -> void:
	var fails: Array[String] = []
	_probe_save_file = ProbeOutput.path("story_progress_probe.cfg")
	_wipe_probe_save()

	# —— ① 选关屏：四列出齐·main_01 可点·main_02 带锁 ——
	var s: Node = load("res://src/ui/story_screen.tscn").instantiate()
	s.progress_path = _probe_save_file
	add_child(s)
	await _rt(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("story_select.png"))
	var b1 := s.find_child("Level_main_01", true, false) as Button
	var b2 := s.find_child("Level_main_02", true, false) as Button
	if b1 == null or b1.disabled:
		fails.append("①main_01 按钮缺失或被锁")
	if b2 == null or not b2.disabled:
		fails.append("①main_02 未按解锁链锁定")

	# —— ② 简介浮层：静态图占位 + 文本 + 开战/返回 ——
	if b1 != null:
		b1.pressed.emit()
	await _rt(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("story_intro.png"))
	if s.find_child("IntroPanel", true, false) == null:
		fails.append("②简介浮层未弹出")

	# —— ③ 交接态：直接调装填步（不含转场）·断言 BattleSetup ——
	var levels: Array = s._levels
	var lv: Dictionary = {}
	for l in levels:
		if String(l.get("id", "")) == "main_01":
			lv = l
	s._prepare_battle_setup(lv)
	if not BattleSetup.story_mode or BattleSetup.story_level_id != "main_01":
		fails.append("③story 旗标/关卡 id 未写入 BattleSetup")
	if BattleSetup.p1_heroes.size() != 3 or BattleSetup.p2_heroes.size() != 3:
		fails.append("③阵容未按关卡数据装填: %d/%d" % [BattleSetup.p1_heroes.size(), BattleSetup.p2_heroes.size()])
	remove_child(s)
	s.queue_free()
	await _rt(0.1)

	# —— ④ 真战斗：注入敌方残血 + 我方满能 → 大波速胜 → story_result 写回 ——
	var b: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(b)
	await _rt(2.2)   # 等进入选择态
	if not bool(b._story):
		fails.append("④battle_screen 未进入故事模式")
	var A := preload("res://src/battle/action_def.gd")
	b.battle.hp[1][0] = 1   # 摆拍垫残血（探针=测试夹具）·替补清空=一击定胜负
	b.battle.hp[1][1] = 0
	b.battle.hp[1][2] = 0
	b.battle.energy[0] = 8
	b.battle.select_action(0, A.Action.BIG_ATTACK)
	b.battle.select_action(1, A.Action.CHARGE)
	b._resolve()
	var got_result := false
	for i in 40:   # 终结演出 ≈2s·放宽轮询到 10s
		if not BattleSetup.story_result.is_empty():
			got_result = true
			break
		await _rt(0.25)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("story_battle_end.png"))
	if not got_result:
		fails.append("④战斗结束未写回 story_result")
	elif String(BattleSetup.story_result.get("outcome", "")) != "win" \
			or String(BattleSetup.story_result.get("level_id", "")) != "main_01":
		fails.append("④story_result 内容错误: %s" % [BattleSetup.story_result])
	remove_child(b)   # 赶在 _story_finish 1.4s 转场前收走（转场会释放探针根）
	b.queue_free()
	await _rt(0.2)

	# —— ⑤ 回程消费：新选关屏吃掉 story_result → main_01 打 ✓·main_02 解锁·总线自清 ——
	var s2: Node = load("res://src/ui/story_screen.tscn").instantiate()
	s2.progress_path = _probe_save_file
	add_child(s2)
	await _rt(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProbeOutput.path("story_cleared.png"))
	if not BattleSetup.story_result.is_empty():
		fails.append("⑤story_result 消费后未自清")
	var c1 := s2.find_child("Level_main_01", true, false) as Button
	var c2 := s2.find_child("Level_main_02", true, false) as Button
	if c1 == null or not c1.text.contains("✓"):
		fails.append("⑤main_01 未标记通关")
	if c2 == null or c2.disabled:
		fails.append("⑤main_02 未随通关解锁")

	_wipe_probe_save()
	print("STORY_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 只删探针专用进度（前=保证从零开始·后=不留测试数据）。
func _wipe_probe_save() -> void:
	if FileAccess.file_exists(_probe_save_file):
		DirAccess.remove_absolute(_probe_save_file)


## 真实时长等待（ignore_time_scale：hitstop/慢放不拖探针节奏）。
func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
