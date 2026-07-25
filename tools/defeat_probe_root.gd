extends Node

## defeat 死亡动画验收探针（2026-07-17 试点批 h01/h02·带窗口跑；同日批量版=支持指定英雄）：
## 默认阵容 P1=h01 虚日鼠 vs P2=h02 牛金——两方向各跑一次终结演出，
## 拍「倒地中段（慢放中）」+「演出结束末帧（躺地停帧）」共四张。
##   godot --path . res://tools/defeat_probe.tscn                       （默认 h01/h02）
##   godot --path . res://tools/defeat_probe.tscn -- --p1 h04 --p2 h17  （批量验收指定出战）
## 输出：D:/Game/BoBoZan/defeat_<p2>_mid/end.png + defeat_<p1>_mid/end.png（仓库外）
## 断言：受害方 CharacterDisplay 有 defeat 动画且演出后停在末帧（非循环）+不变灰（modulate 白）。

const OUT_DIR := "D:/Game/BoBoZan/"


func _ready() -> void:
	var p1_id := "h01"
	var p2_id := "h02"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--p1" and i + 1 < args.size():
			p1_id = args[i + 1]
		elif args[i] == "--p2" and i + 1 < args.size():
			p2_id = args[i + 1]
	if p1_id != "h01" or p2_id != "h02":
		var by_id := {}
		for h: HeroData in HeroData.create_pool_heroes():
			by_id[h.hero_id] = h
		# 出战位=指定者·替补任取（探针只打出战位 defeat·两侧替补错开防共享实例）
		var t1: Array[HeroData] = [by_id[p1_id] as HeroData,
			by_id["h05"] as HeroData, by_id["h06"] as HeroData]
		var t2: Array[HeroData] = [by_id[p2_id] as HeroData,
			by_id["h07"] as HeroData, by_id["h08"] as HeroData]
		BattleSetup.p1_heroes = t1
		BattleSetup.p2_heroes = t2
	var fails: Array[String] = []
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await _rt(2.2)   # 等进入选择态

	# —— 方向①：P0 终结 P2 → p2_id 播 defeat ——
	if not (s.p2_char_display as CharacterDisplay).has_action_anim("defeat"):
		fails.append("%s tres 缺 defeat 动画" % p2_id)
	s._play_finisher([0, 4], true, false)
	await _rt(1.35)   # 命中(≈0.87s)后 ~0.5s=慢放中倒地中段
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_%s_mid.png" % p2_id)
	await _rt(1.6)    # 演出收尾+回正
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_%s_end.png" % p2_id)
	var cd2 := s.p2_char_display as CharacterDisplay
	if cd2._sprite.animation != "defeat":
		fails.append("① %s 演出后应停在 defeat 动画（实际 %s）" % [p2_id, cd2._sprite.animation])
	elif cd2._sprite.is_playing():
		fails.append("① %s defeat 应非循环停末帧（仍在播放）" % p2_id)
	if cd2.modulate != Color.WHITE:
		fails.append("① 有 defeat 表不应再变灰（modulate=%s）" % cd2.modulate)

	# —— 方向②：P1 终结 P0 → p1_id 播 defeat（同场景续跑·躺者不碍事）——
	if not (s.p1_char_display as CharacterDisplay).has_action_anim("defeat"):
		fails.append("%s tres 缺 defeat 动画" % p1_id)
	s._play_finisher([4, 0], false, true)
	await _rt(1.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_%s_mid.png" % p1_id)
	await _rt(1.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_%s_end.png" % p1_id)
	var cd1 := s.p1_char_display as CharacterDisplay
	if cd1._sprite.animation != "defeat":
		fails.append("② %s 演出后应停在 defeat 动画（实际 %s）" % [p1_id, cd1._sprite.animation])
	if cd1.modulate != Color.WHITE:
		fails.append("② 有 defeat 表不应再变灰" )

	print("DEFEAT_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 真实时长等待（终结演出全场慢放·普通 timer 会被拉长）。
func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
