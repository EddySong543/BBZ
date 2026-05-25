extends Control

## v4 战斗试玩台（最小可玩，纯文字+按钮，不依赖美术）。
## 运行：编辑器打开 playtest.tscn → F6。你控 P0，对面默认 AI 随机；可切手动。
##
## 目的：亲手打几局，感受新数值 / 新机制 / 半血 是否成立、好不好玩。
## 只是一次性原型，不接入正式 UI。

# 阵容（用已实装的 13 个英雄之一；[hero_id, 显示名, HP]）
const ROSTER_P0 := [["h05", "辰龙·天威", 6], ["h09", "申猴·凶兽", 4], ["h01", "子鼠·窃运", 4]]
const ROSTER_P1 := [["h21", "力量·降龙", 7], ["h03", "寅虎·渴血", 5], ["h23", "命运之轮", 5]]

const A := ActionDefV4.Action

var battle: BattleEngineV4
var _sel_action := [-1, -1]
var _sel_switch := [-1, -1]
var _p1_ai := true

var _status: RichTextLabel
var _log: RichTextLabel
var _p0_box: HBoxContainer
var _p0_switch_box: HBoxContainer
var _death_box: HBoxContainer
var _resolve_btn: Button
var _turn_lbl: Label
var _log_lines: Array[String] = []


func _ready() -> void:
	_build_ui()
	_new_game()


func _new_game() -> void:
	battle = BattleEngineV4.new()
	battle.setup(_team(ROSTER_P0), _team(ROSTER_P1), randi())
	_sel_action = [-1, -1]
	_sel_switch = [-1, -1]
	_log_lines.clear()
	_log_lines.append("[color=gray]新对局开始。你=P0（下），对手=P1（上）。[/color]")
	_refresh()


func _team(roster: Array) -> Array:
	var t: Array = []
	for r in roster:
		var h := HeroData.new()
		h.hero_id = r[0]
		h.hero_name = r[1]
		h.max_hp = r[2]
		h.skill_type = HeroData.SkillType.PASSIVE
		h.passive_id = ""
		h.extra_action_id = -1
		t.append(h)
	return t


# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 16
	root.offset_right = -24
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_turn_lbl = Label.new()
	_turn_lbl.add_theme_font_size_override("font_size", 28)
	root.add_child(_turn_lbl)

	_status = RichTextLabel.new()
	_status.bbcode_enabled = true
	_status.fit_content = true
	_status.custom_minimum_size = Vector2(0, 320)
	_status.add_theme_font_size_override("normal_font_size", 22)
	root.add_child(_status)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(0, 150)
	_log.add_theme_font_size_override("normal_font_size", 18)
	root.add_child(_log)

	# P0 主动作按钮行
	var p0_lbl := Label.new()
	p0_lbl.text = "你的动作（P0）："
	p0_lbl.add_theme_font_size_override("font_size", 22)
	root.add_child(p0_lbl)
	_p0_box = HBoxContainer.new()
	root.add_child(_p0_box)
	for spec in [[A.CHARGE, "攒"], [A.ATTACK, "波"], [A.DEFEND, "防"], [A.BIG_ATTACK, "大波"], [A.BIG_DEFEND, "大防"], [ActionDefV4.ACTIVE, "技能"]]:
		var btn := Button.new()
		btn.text = spec[1]
		btn.custom_minimum_size = Vector2(96, 56)
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("act", spec[0])
		btn.pressed.connect(_on_p0_action.bind(spec[0]))
		_p0_box.add_child(btn)

	# P0 切换行（动态填充目标）
	_p0_switch_box = HBoxContainer.new()
	root.add_child(_p0_switch_box)

	# 控制行
	var ctrl := HBoxContainer.new()
	root.add_child(ctrl)
	_resolve_btn = Button.new()
	_resolve_btn.text = "▶ 结算回合"
	_resolve_btn.custom_minimum_size = Vector2(160, 56)
	_resolve_btn.focus_mode = Control.FOCUS_NONE
	_resolve_btn.pressed.connect(_on_resolve)
	ctrl.add_child(_resolve_btn)

	var ai_chk := CheckButton.new()
	ai_chk.text = "P1 = AI 随机"
	ai_chk.button_pressed = true
	ai_chk.focus_mode = Control.FOCUS_NONE
	ai_chk.toggled.connect(func(on: bool) -> void: _p1_ai = on; _refresh())
	ctrl.add_child(ai_chk)

	var new_btn := Button.new()
	new_btn.text = "重开"
	new_btn.custom_minimum_size = Vector2(96, 56)
	new_btn.focus_mode = Control.FOCUS_NONE
	new_btn.pressed.connect(_new_game)
	ctrl.add_child(new_btn)

	# P1 手动动作行（AI 关时用）
	var p1_lbl := Label.new()
	p1_lbl.text = "对手动作（P1，AI 关时手动）："
	p1_lbl.add_theme_font_size_override("font_size", 18)
	root.add_child(p1_lbl)
	var p1_box := HBoxContainer.new()
	root.add_child(p1_box)
	for spec in [[A.CHARGE, "攒"], [A.ATTACK, "波"], [A.DEFEND, "防"], [A.BIG_ATTACK, "大波"], [A.BIG_DEFEND, "大防"]]:
		var btn := Button.new()
		btn.text = spec[1]
		btn.custom_minimum_size = Vector2(80, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_p1_action.bind(spec[0]))
		p1_box.add_child(btn)

	# 死亡换人行
	_death_box = HBoxContainer.new()
	root.add_child(_death_box)


# ============================================================
# 交互
# ============================================================

func _on_p0_action(act: int) -> void:
	if act == ActionDefV4.ACTIVE and not battle.can_use_active(0):
		return
	_sel_action[0] = act
	_sel_switch[0] = -1
	_refresh()


func _on_p0_switch(target_slot: int) -> void:
	_sel_action[0] = A.SWITCH
	_sel_switch[0] = target_slot
	_refresh()


func _on_p1_action(act: int) -> void:
	_sel_action[1] = act
	_sel_switch[1] = -1
	_refresh()


func _on_resolve() -> void:
	if battle.game_over or _has_pending():
		return
	if _p1_ai:
		_ai_pick(1)
	if _sel_action[0] < 0 or _sel_action[1] < 0:
		return
	for s in [0, 1]:
		match _sel_action[s]:
			ActionDefV4.ACTIVE:
				battle.select_active(s)
			A.SWITCH:
				battle.select_switch(s, _sel_switch[s])
			_:
				battle.select_action(s, _sel_action[s])
	var res := battle.resolve()
	_log_result(res)
	_sel_action = [-1, -1]
	_sel_switch = [-1, -1]
	_refresh()


func _on_death_switch(side: int, slot: int) -> void:
	battle.execute_death_switch(side, slot)
	_log_lines.append("[color=aqua]P%d 换上 %s[/color]" % [side + 1, battle.heroes[side][slot].hero_name])
	_refresh()


func _ai_pick(side: int) -> void:
	var opts: Array[int] = [A.CHARGE, A.CHARGE, A.DEFEND]
	if battle.energy[side] >= 1:
		opts.append(A.ATTACK)
		opts.append(A.ATTACK)
	if battle.energy[side] >= 2:
		opts.append(A.BIG_ATTACK)
		opts.append(A.BIG_DEFEND)
	_sel_action[side] = opts[randi() % opts.size()]
	_sel_switch[side] = -1


func _has_pending() -> bool:
	return battle.pending_death_switch[0] or battle.pending_death_switch[1]


# ============================================================
# 刷新显示
# ============================================================

func _refresh() -> void:
	_turn_lbl.text = "回合 %d" % (battle.turn_number + 1)
	if battle.game_over:
		var w := battle.winner
		var txt := "平局" if w == BattleEngineV4.WINNER_DRAW else ("你(P0)胜！" if w == BattleEngineV4.WINNER_P1 else "对手(P1)胜！")
		_turn_lbl.text = "对局结束 — " + txt

	_status.text = _team_str(1) + "\n[color=gray]————————————————[/color]\n" + _team_str(0)
	_log.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - 8)))

	# P0 主动作按钮可用性
	for btn in _p0_box.get_children():
		var act: int = btn.get_meta("act")
		var usable := true
		if act == ActionDefV4.ACTIVE:
			var act_skill: HeroSkillV4 = battle._skills[0][battle.active_index[0]]
			btn.visible = act_skill != null and act_skill.has_active()
			usable = battle.can_use_active(0)
		else:
			usable = battle.can_afford(0, act)
		btn.disabled = battle.game_over or _has_pending() or not usable
		btn.modulate = Color(1, 1, 0.4) if _sel_action[0] == act and _sel_switch[0] < 0 else Color.WHITE

	# P0 切换按钮（动态）
	for c in _p0_switch_box.get_children():
		c.queue_free()
	for slot in range(3):
		if slot == battle.active_index[0] or battle.hp[0][slot] <= 0:
			continue
		var sb := Button.new()
		sb.text = "切→%s" % battle.heroes[0][slot].hero_name
		sb.custom_minimum_size = Vector2(150, 44)
		sb.focus_mode = Control.FOCUS_NONE
		sb.disabled = battle.game_over or _has_pending()
		sb.modulate = Color(1, 1, 0.4) if _sel_action[0] == A.SWITCH and _sel_switch[0] == slot else Color.WHITE
		sb.pressed.connect(_on_p0_switch.bind(slot))
		_p0_switch_box.add_child(sb)

	# 死亡换人
	for c in _death_box.get_children():
		c.queue_free()
	for side in [0, 1]:
		if battle.pending_death_switch[side]:
			var lbl := Label.new()
			lbl.text = "P%d 选替补上场：" % (side + 1)
			_death_box.add_child(lbl)
			for slot in range(3):
				if battle.hp[side][slot] > 0 and slot != battle.active_index[side]:
					var db := Button.new()
					db.text = battle.heroes[side][slot].hero_name
					db.focus_mode = Control.FOCUS_NONE
					db.pressed.connect(_on_death_switch.bind(side, slot))
					_death_box.add_child(db)

	_resolve_btn.disabled = battle.game_over or _has_pending()


func _team_str(side: int) -> String:
	var who := "对手 P1" if side == 1 else "你 P0"
	var s := "[b]%s[/b]   能量: %d" % [who, battle.energy[side]]
	for i in range(3):
		var h: HeroData = battle.heroes[side][i]
		var hp_now := battle.hp_display(battle.hp[side][i])
		var hp_max := battle.hp_display(battle.max_hp[side][i])
		var active := "▶" if i == battle.active_index[side] else "   "
		var line := "\n %s %s  %.1f / %.1f" % [active, h.hero_name, hp_now, hp_max]
		if battle.hp[side][i] <= 0:
			line = "\n    [color=gray]%s  阵亡[/color]" % h.hero_name
		elif battle.shield[side][i] > 0:
			line += "  [盾%.1f]" % battle.hp_display(battle.shield[side][i])
		# 出战英雄的关键状态提示
		if i == battle.active_index[side]:
			var hint := _status_hint(side, i)
			if hint != "":
				line += "  [color=yellow]%s[/color]" % hint
		s += line
	return s


func _status_hint(side: int, slot: int) -> String:
	var st: Dictionary = battle.statuses[side][slot]
	var parts: Array[String] = []
	if int(st.get("combo", 0)) > 0:
		parts.append("连段%d" % st["combo"])
	if int(st.get("ku", 0)) > 0:
		parts.append("窟%d" % st["ku"])
	if st.get("charge_up", false):
		parts.append("蓄势")
	if int(st.get("xuexue", 0)) > 0:
		parts.append("渴血%d" % st["xuexue"])
	if int(st.get("yinzhe_atk", 0)) > 0:
		parts.append("隐者攻%d" % st["yinzhe_atk"])
	if st.get("wheel_atk", false):
		parts.append("轮·攻")
	if st.get("wheel_def", false):
		parts.append("轮·防")
	return " ".join(parts)


func _log_result(res: Dictionary) -> void:
	var a0 := _act_name(res.get("p1_action", -1))
	var a1 := _act_name(res.get("p2_action", -1))
	_log_lines.append("[color=white]回合%d: 你出[%s] / 对手出[%s][/color]" % [res.get("turn", 0), a0, a1])
	for ev in res.get("events", []):
		var t := _ev_text(ev)
		if t != "":
			_log_lines.append("   " + t)


func _act_name(act: int) -> String:
	match act:
		A.CHARGE: return "攒"
		A.ATTACK: return "波"
		A.DEFEND: return "防"
		A.BIG_ATTACK: return "大波"
		A.BIG_DEFEND: return "大防"
		A.SWITCH: return "切换"
		ActionDefV4.ACTIVE: return "技能"
	return "?"


func _ev_text(ev: Dictionary) -> String:
	var p: int = ev.get("player", -1)
	var who := "你" if p == 0 else "对手"
	match ev.get("id", ""):
		"damage_taken": return "[color=tomato]%s 受 %.1f 伤[/color]" % [who, float(ev.get("amount", 0)) / 2.0]
		"big_defend_block": return "[color=aqua]%s 大防格挡[/color]" % who
		"defend_block": return "[color=aqua]%s 防格挡[/color]" % who
		"shield_absorb": return "%s 护盾吸收 %.1f" % [who, float(ev.get("amount", 0)) / 2.0]
		"charge_gain": return "%s 攒能 +%d" % [who, ev.get("amount", 0)]
		"active_used": return "[color=orange]%s 发动主动技[/color]" % who
		"switch": return "%s 切换" % who
		"hero_died": return "[color=red]%s 一名英雄阵亡[/color]" % who
		"victory": return "[color=gold]胜负已分[/color]"
		"draw": return "[color=gold]平局[/color]"
	return ""
