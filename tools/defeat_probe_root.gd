extends Node

## defeat 死亡动画验收探针（2026-07-17 试点批 h01/h02·带窗口跑）：
## 默认阵容 P1=h01 虚日鼠 vs P2=h02 牛金——两方向各跑一次终结演出，
## 拍「倒地中段（慢放中）」+「演出结束末帧（躺地停帧）」共四张。
##   godot --path . res://tools/defeat_probe.tscn
## 输出：D:/Game/BoBoZan/defeat_h02_mid/end.png + defeat_h01_mid/end.png（仓库外）
## 断言：受害方 CharacterDisplay 有 defeat 动画且演出后停在末帧（非循环）+不变灰（modulate 白）。
## 批量 24 验收：改 BattleSetup 阵容重复跑或按本探针思路扩循环。

const OUT_DIR := "D:/Game/BoBoZan/"


func _ready() -> void:
	var fails: Array[String] = []
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await _rt(2.2)   # 等进入选择态

	# —— 方向①：P0(h01) 终结 P2(h02) → h02 播 defeat ——
	if not (s.p2_char_display as CharacterDisplay).has_action_anim("defeat"):
		fails.append("h02 tres 缺 defeat 动画")
	s._play_finisher([0, 4], true, false)
	await _rt(1.35)   # 命中(≈0.87s)后 ~0.5s=慢放中倒地中段
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_h02_mid.png")
	await _rt(1.6)    # 演出收尾+回正
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_h02_end.png")
	var cd2 := s.p2_char_display as CharacterDisplay
	if cd2._sprite.animation != "defeat":
		fails.append("① h02 演出后应停在 defeat 动画（实际 %s）" % cd2._sprite.animation)
	elif cd2._sprite.is_playing():
		fails.append("① h02 defeat 应非循环停末帧（仍在播放）")
	if cd2.modulate != Color.WHITE:
		fails.append("① 有 defeat 表不应再变灰（modulate=%s）" % cd2.modulate)

	# —— 方向②：P1(h02) 终结 P0(h01) → h01 播 defeat（同场景续跑·h02 躺着不碍事）——
	if not (s.p1_char_display as CharacterDisplay).has_action_anim("defeat"):
		fails.append("h01 tres 缺 defeat 动画")
	s._play_finisher([4, 0], false, true)
	await _rt(1.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_h01_mid.png")
	await _rt(1.6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "defeat_h01_end.png")
	var cd1 := s.p1_char_display as CharacterDisplay
	if cd1._sprite.animation != "defeat":
		fails.append("② h01 演出后应停在 defeat 动画（实际 %s）" % cd1._sprite.animation)
	if cd1.modulate != Color.WHITE:
		fails.append("② 有 defeat 表不应再变灰")

	print("DEFEAT_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 真实时长等待（终结演出全场慢放·普通 timer 会被拉长）。
func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
