extends Node

## A3b 事件注解飘字探针：boot 战斗屏 → 状态注入摆拍三个回合 → 断言注解飘字 + 截图。
## 带窗口跑（主场景模式·autoload 正常注册）：
##   godot --path . res://tools/event_tag_probe.tscn
## 回合① 敌带毒 2 层+印记 → 我波命中 → 「毒爆」「印记」注解（0.14s 错时逐条弹）
## 回合② 我带 2.0 护盾 → 敌波被全吸 → 「护盾-1」注解（无伤害字·血没少但有交代）
## 回合③ 我背 1.0 到期延迟伤害 → 出招拍余烬橙「-1」（引擎直写 HP 的旧账·原先完全隐形）
## 输出：D:/Game/BoBoZan/event_tags_poison.png / _shield.png / _burn.png（仓库外）

const OUT_DIR := "D:/Game/BoBoZan/"


func _ready() -> void:
	var s: Node = load("res://src/ui/battle_screen.tscn").instantiate()
	add_child(s)
	await _rt(2.2)   # 等进入选择态
	var fails: Array[String] = []
	var A := preload("res://src/battle/action_def.gd")

	# —— 回合①：敌方出战带毒 2 层 + 印记 2 → 我「波」命中引爆 → 毒爆/印记注解 ——
	var es: int = s.battle.active_index[1]
	s.battle.set_status(1, es, "poison", 2)
	s.battle.set_status(1, es, "marked", 2)
	s.battle.select_action(0, A.Action.ATTACK)
	s.battle.select_action(1, A.Action.CHARGE)
	s._resolve()   # 命中拍 ≈1.65s·注解错时 +0.08/+0.22s（活到 ≈2.7s）
	await _rt(2.15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "event_tags_poison.png")
	if _find_float(s, "毒爆") == null:
		fails.append("①「毒爆」注解未出现")
	if _find_float(s, "印记") == null:
		fails.append("①「印记」注解未出现")
	await _rt(2.4)   # 等回合过场结束

	# —— 回合②：我方出战垫 2.0 护盾 → 敌「波」被全吸 → 护盾注解（无 -N 伤害字）——
	await _wait_select(s)
	s.battle.shield[0][s.battle.active_index[0]] += 4
	s.battle.select_action(0, A.Action.CHARGE)
	s.battle.select_action(1, A.Action.ATTACK)
	s._resolve()
	await _rt(2.15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "event_tags_shield.png")
	if _find_float_prefix(s, "护盾-") == null:
		fails.append("②「护盾-N」注解未出现")
	await _rt(2.4)

	# —— 回合③：我方出战背 1.0 到期延迟伤害 → 出招拍余烬橙 -1（不走 damage_taken 的直写掉血）——
	await _wait_select(s)
	s.battle.pending_damage[0][s.battle.active_index[0]] = 2
	s.battle.select_action(0, A.Action.CHARGE)
	s.battle.select_action(1, A.Action.CHARGE)
	s._resolve()
	await _rt(1.8)   # 出招拍注解在动画开场即弹（≈1.4s）·此刻仍在飞
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_DIR + "event_tags_burn.png")
	var burn := _find_float_prefix(s, "-")
	if burn == null:
		fails.append("③延迟伤害 -N 未出现")
	elif burn.get_theme_color("font_color") != s.COL_DMG_BURN:
		fails.append("③延迟伤害飘字配色不是余烬橙: %s" % burn.get_theme_color("font_color"))

	print("EVENT_TAG_PROBE: %s" % ("PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit()


## 找当前可见、文本完全匹配的池化飘字。
func _find_float(s: Node, text: String) -> Label:
	for l in s._fx._dmg_pool:
		if l.visible and l.text == text:
			return l
	return null


## 找当前可见、文本以 prefix 开头的池化飘字。
func _find_float_prefix(s: Node, prefix: String) -> Label:
	for l in s._fx._dmg_pool:
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
