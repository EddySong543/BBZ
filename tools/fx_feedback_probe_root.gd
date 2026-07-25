extends Node

## 战斗反馈演出探针（②被挡 ③治疗/能量 ⑧伤害阶梯）：boot 战斗屏 → 直接驱动引擎摆拍三个回合 →
## 断言飘字文本/配色 + 截图。带窗口跑（主场景模式·autoload 正常注册）：
##   godot --path . res://tools/fx_feedback_probe.tscn
## 回合① 我防 vs 敌波 → 被挡（银灰「被挡」+钢蓝火花+轻震）
## 回合② 双方攒 → 能量金粒飞向 HUD 金币行
## 回合③ 敌大波(穿防) vs 我防 → 靛紫穿透伤害飘字
## 输出：D:/Game/BoBoZan/fx_block.png / fx_charge.png / fx_pierce.png（仓库外）

const OUT_DIR := "D:/Game/BoBoZan/"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen1.tscn").instantiate()
	add_child(s)
	await _rt(2.2)   # 等进入选择态
	var fails: Array[String] = []
	var A := preload("res://src/battle/action_def.gd")

	# —— 回合①：我「防」敌「波」→ defend_block → 被挡演出 ——
	s.battle.select_action(0, A.Action.DEFEND)
	s.battle.select_action(1, A.Action.ATTACK)
	s._resolve()   # 不 await 全程（含回合过场）·只等到命中拍（气泡 1.35s + 0.45×action_phase ≈1.65s·飘字活到 ≈2.55s）
	await _rt(2.05)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "fx_block.png")
	if _find_float(s, "被挡") == null:
		fails.append("①被挡飘字未出现")
	await _rt(2.5)   # 等回合过场结束回到选择态

	# —— 回合②：双方「攒」→ charge_gain → 能量金粒 ——
	await _wait_select(s)
	s.battle.select_action(0, A.Action.CHARGE)
	s.battle.select_action(1, A.Action.CHARGE)
	s._resolve()
	await _rt(1.75)   # 动作拍粒子在飞（气泡 1.2s 后才进动画）
	var flying := 0
	for m in s._mote_pool:
		if m.visible:
			flying += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "fx_charge.png")
	if flying == 0:
		fails.append("②能量金粒未起飞")
	await _rt(3.0)

	# —— 回合③：敌「大波」(Pen.PIERCE_DEF) vs 我「防」→ 穿透伤害=靛紫飘字 ——
	await _wait_select(s)
	s.battle.energy[1] = 8   # 摆拍垫能量（探针=测试夹具·非 UI 生产代码）
	s.battle.select_action(0, A.Action.DEFEND)
	s.battle.select_action(1, A.Action.BIG_ATTACK)
	s._resolve()
	await _rt(2.05)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "fx_pierce.png")
	var pl := _find_float_prefix(s, "-")
	if pl == null:
		fails.append("③穿透伤害飘字未出现")
	elif pl.get_theme_color("font_color") != s.COL_DMG_PIERCE:
		fails.append("③穿透飘字配色不是靛紫: %s" % pl.get_theme_color("font_color"))

	print("FX_FEEDBACK_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 找当前可见、文本完全匹配的池化飘字。
func _find_float(s: Node, text: String) -> Label:
	for l in s._dmg_pool:
		if l.visible and l.text == text:
			return l
	return null


## 找当前可见、文本以 prefix 开头的池化飘字。
func _find_float_prefix(s: Node, prefix: String) -> Label:
	for l in s._dmg_pool:
		if l.visible and l.text.begins_with(prefix):
			return l
	return null


## 等回到玩家选择态（State.PLAYER_SELECT = 1·见 battle_screen State 枚举）。
func _wait_select(s: Node) -> void:
	for i in 40:
		if int(s.state) == 1:
			return
		await _rt(0.25)


## 真实时长等待（ignore_time_scale：hitstop/慢放不拖探针节奏）。
func _rt(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
