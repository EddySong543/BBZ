extends Control

## v4 可视化战斗台（代码构建，便于后期换 UI 美术皮）。
## 加载真实 34 英雄 .tres 数据，接 BattleEngineV4。你控 P0、对面 AI 随机。
## juice：受伤闪白 + 震屏 + 伤害数字 + 血条动画。运行：打开 battle_ui.tscn 按 F6。
##
## 头像：有 portrait_path 就显示，没有就显示名字色块（美术后填）。

const A := ActionDefV4.Action
const HERO_DIR := "res://assets/data/heroes_v4/"

# 默认对阵阵容（hero_id；可改）
const ROSTER_P0 := ["h05", "h09", "h13"]   # 辰龙·天威 / 申猴·凶兽 / 愚者·孤注
const ROSTER_P1 := ["h21", "h03", "h26"]   # 力量·降龙 / 寅虎·渴血 / 死神

var battle: BattleEngineV4
var _sel_action := [-1, -1]
var _sel_switch := [-1, -1]
var _p1_ai := true

# 每个英雄面板的 UI 引用：_panel[player][slot] = {root,name,hpbar,hptext,portrait,frame}
var _panel := [[], []]
var _energy_lbl := [null, null]
var _turn_lbl: Label
var _log: RichTextLabel
var _action_bar: HBoxContainer
var _switch_bar: HBoxContainer
var _death_bar: HBoxContainer
var _resolve_btn: Button
var _stage: Control               # 震屏作用对象
var _log_lines: Array[String] = []
var _shake := 0.0


func _ready() -> void:
	_build_ui()
	_new_game()


func _new_game() -> void:
	battle = BattleEngineV4.new()
	battle.setup(_load_team(ROSTER_P0), _load_team(ROSTER_P1), randi())
	_sel_action = [-1, -1]
	_sel_switch = [-1, -1]
	_log_lines.clear()
	_log_lines.append("[color=gray]新对局：你=P0（下），对手=P1（上，AI）。[/color]")
	_rebuild_panels()
	_refresh()


func _load_team(ids: Array) -> Array:
	var t: Array = []
	for id in ids:
		var path: String = HERO_DIR + str(id) + ".tres"
		var h: HeroData = load(path) if ResourceLoader.exists(path) else null
		if h == null:
			h = HeroData.new()
			h.hero_id = id
			h.hero_name = id
			h.max_hp = 5
		t.append(h)
	return t


# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_top = 16
	root.offset_right = -30
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	_stage.add_child(root)

	_turn_lbl = Label.new()
	_turn_lbl.add_theme_font_size_override("font_size", 26)
	root.add_child(_turn_lbl)

	# 对手队伍（上）
	root.add_child(_make_team_row(1))
	# 中间日志
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(0, 140)
	_log.add_theme_font_size_override("normal_font_size", 17)
	root.add_child(_log)
	# 我方队伍（下）
	root.add_child(_make_team_row(0))

	# 动作条
	var act_title := Label.new()
	act_title.text = "你的动作："
	act_title.add_theme_font_size_override("font_size", 20)
	root.add_child(act_title)
	_action_bar = HBoxContainer.new()
	root.add_child(_action_bar)
	for spec in [[A.CHARGE, "攒"], [A.ATTACK, "波"], [A.DEFEND, "防"], [A.BIG_ATTACK, "大波"], [A.BIG_DEFEND, "大防"], [ActionDefV4.ACTIVE, "技能"]]:
		var btn := Button.new()
		btn.text = spec[1]
		btn.custom_minimum_size = Vector2(92, 52)
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_meta("act", spec[0])
		btn.pressed.connect(_on_action.bind(spec[0]))
		_action_bar.add_child(btn)
	_switch_bar = HBoxContainer.new()
	root.add_child(_switch_bar)

	# 控制
	var ctrl := HBoxContainer.new()
	root.add_child(ctrl)
	_resolve_btn = Button.new()
	_resolve_btn.text = "▶ 结算回合"
	_resolve_btn.custom_minimum_size = Vector2(150, 52)
	_resolve_btn.focus_mode = Control.FOCUS_NONE
	_resolve_btn.pressed.connect(_on_resolve)
	ctrl.add_child(_resolve_btn)
	var ai := CheckButton.new()
	ai.text = "P1=AI"
	ai.button_pressed = true
	ai.focus_mode = Control.FOCUS_NONE
	ai.toggled.connect(func(on: bool) -> void: _p1_ai = on)
	ctrl.add_child(ai)
	var ng := Button.new()
	ng.text = "重开"
	ng.custom_minimum_size = Vector2(90, 52)
	ng.focus_mode = Control.FOCUS_NONE
	ng.pressed.connect(_new_game)
	ctrl.add_child(ng)

	_death_bar = HBoxContainer.new()
	root.add_child(_death_bar)


func _make_team_row(player: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	var who := Label.new()
	who.text = "对手" if player == 1 else "你"
	who.custom_minimum_size = Vector2(60, 0)
	box.add_child(who)
	_energy_lbl[player] = Label.new()
	_energy_lbl[player].add_theme_font_size_override("font_size", 18)
	box.add_child(_energy_lbl[player])
	# 3 个英雄面板占位（_rebuild_panels 填充）
	var slots := HBoxContainer.new()
	slots.name = "Slots"
	slots.add_theme_constant_override("separation", 12)
	box.add_child(slots)
	box.set_meta("slots", slots)
	box.set_meta("player", player)
	if player == 1:
		_p1_row = box
	else:
		_p0_row = box
	return box

var _p0_row: HBoxContainer
var _p1_row: HBoxContainer


func _rebuild_panels() -> void:
	for player in [0, 1]:
		var row: HBoxContainer = _p1_row if player == 1 else _p0_row
		var slots: HBoxContainer = row.get_meta("slots")
		for c in slots.get_children():
			c.queue_free()
		_panel[player] = []
		for slot in range(battle.heroes[player].size()):
			var h: HeroData = battle.heroes[player][slot]
			var pnl := PanelContainer.new()
			pnl.custom_minimum_size = Vector2(150, 110)
			var vb := VBoxContainer.new()
			pnl.add_child(vb)
			# 头像位
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(60, 60)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if h.portrait_path != "" and ResourceLoader.exists(h.portrait_path):
				portrait.texture = load(h.portrait_path)
			vb.add_child(portrait)
			var nm := Label.new()
			nm.text = h.hero_name
			nm.add_theme_font_size_override("font_size", 16)
			vb.add_child(nm)
			var bar := ProgressBar.new()
			bar.max_value = battle.hp_display(battle.max_hp[player][slot])
			bar.value = battle.hp_display(battle.hp[player][slot])
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 16)
			vb.add_child(bar)
			var hpt := Label.new()
			hpt.add_theme_font_size_override("font_size", 14)
			vb.add_child(hpt)
			_panel[player].append({pnl = pnl, name = nm, bar = bar, hptext = hpt, portrait = portrait})
			slots.add_child(pnl)


# ============================================================
# 交互
# ============================================================

func _on_action(act: int) -> void:
	if act == ActionDefV4.ACTIVE and not battle.can_use_active(0):
		return
	_sel_action[0] = act
	_sel_switch[0] = -1
	_refresh()


func _on_switch(target: int) -> void:
	_sel_action[0] = A.SWITCH
	_sel_switch[0] = target
	_refresh()


func _on_free_switch(target: int) -> void:
	if battle.free_switch(0, target):
		_log_lines.append("[color=aqua]你 当先免费切换上 %s[/color]" % battle.active_hero(0).hero_name)
		_sel_action[0] = -1
		_refresh()


func _on_resolve() -> void:
	if battle.game_over or battle.pending_death_switch[0] or battle.pending_death_switch[1]:
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
	_animate(res)
	_sel_action = [-1, -1]
	_sel_switch = [-1, -1]
	_refresh()


func _on_death_switch(side: int, slot: int) -> void:
	battle.execute_death_switch(side, slot)
	_refresh()


func _ai_pick(side: int) -> void:
	var opts: Array[int] = [A.CHARGE, A.CHARGE, A.DEFEND]
	if battle.energy[side] >= 1:
		opts.append(A.ATTACK)
		opts.append(A.ATTACK)
	if battle.energy[side] >= 2:
		opts.append(A.BIG_ATTACK)
	_sel_action[side] = opts[randi() % opts.size()]
	_sel_switch[side] = -1


# ============================================================
# 刷新 + juice
# ============================================================

func _refresh() -> void:
	_turn_lbl.text = "回合 %d" % (battle.turn_number + 1)
	if battle.game_over:
		var w := battle.winner
		_turn_lbl.text = "结束 — " + ("平局" if w == BattleEngineV4.WINNER_DRAW else ("你胜！" if w == BattleEngineV4.WINNER_P1 else "对手胜！"))

	for player in [0, 1]:
		_energy_lbl[player].text = "能量 %d" % battle.energy[player]
		for slot in range(_panel[player].size()):
			var p: Dictionary = _panel[player][slot]
			var hp_now := battle.hp_display(battle.hp[player][slot])
			var hp_max := battle.hp_display(battle.max_hp[player][slot])
			(p.bar as ProgressBar).max_value = hp_max
			(p.bar as ProgressBar).value = maxf(hp_now, 0.0)
			(p.hptext as Label).text = "%.1f/%.1f" % [maxf(hp_now, 0.0), hp_max]
			var dead: bool = battle.hp[player][slot] <= 0
			var active: bool = slot == battle.active_index[player]
			var col := Color(0.3, 0.3, 0.3) if dead else (Color(1, 0.95, 0.6) if active else Color(1, 1, 1))
			(p.pnl as PanelContainer).modulate = col

	# P0 动作按钮可用性
	var busy := battle.game_over or battle.pending_death_switch[0] or battle.pending_death_switch[1]
	for btn in _action_bar.get_children():
		var act: int = btn.get_meta("act")
		var ok := battle.can_use_active(0) if act == ActionDefV4.ACTIVE else battle.can_afford(0, act)
		if act == ActionDefV4.ACTIVE:
			var sk: HeroSkillV4 = battle._skills[0][battle.active_index[0]]
			btn.visible = sk != null and sk.has_active()
		btn.disabled = busy or not ok
		btn.modulate = Color(1, 1, 0.4) if _sel_action[0] == act else Color.WHITE

	# 切换 / 免费切按钮
	for c in _switch_bar.get_children():
		c.queue_free()
	for slot in range(battle.heroes[0].size()):
		if slot == battle.active_index[0] or battle.hp[0][slot] <= 0:
			continue
		var sb := Button.new()
		sb.text = "切→%s" % battle.heroes[0][slot].hero_name
		sb.focus_mode = Control.FOCUS_NONE
		sb.custom_minimum_size = Vector2(120, 40)
		sb.disabled = busy
		sb.modulate = Color(1, 1, 0.4) if _sel_action[0] == A.SWITCH and _sel_switch[0] == slot else Color.WHITE
		sb.pressed.connect(_on_switch.bind(slot))
		_switch_bar.add_child(sb)
		if battle.can_free_switch(0):
			var fb := Button.new()
			fb.text = "免切→%s" % battle.heroes[0][slot].hero_name
			fb.focus_mode = Control.FOCUS_NONE
			fb.custom_minimum_size = Vector2(120, 40)
			fb.disabled = busy
			fb.pressed.connect(_on_free_switch.bind(slot))
			_switch_bar.add_child(fb)

	# 死亡换人
	for c in _death_bar.get_children():
		c.queue_free()
	for side in [0, 1]:
		if battle.pending_death_switch[side]:
			var lbl := Label.new()
			lbl.text = "P%d 选替补：" % (side + 1)
			_death_bar.add_child(lbl)
			for slot in range(battle.heroes[side].size()):
				if battle.hp[side][slot] > 0 and slot != battle.active_index[side]:
					var db := Button.new()
					db.text = battle.heroes[side][slot].hero_name
					db.focus_mode = Control.FOCUS_NONE
					db.pressed.connect(_on_death_switch.bind(side, slot))
					_death_bar.add_child(db)

	_resolve_btn.disabled = busy
	_log.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - 7)))


func _animate(res: Dictionary) -> void:
	_log_lines.append("[color=white]回合%d 你[%s]/对手[%s][/color]" % [res.get("turn", 0), _act_name(res.get("p1_action", -1)), _act_name(res.get("p2_action", -1))])
	for ev in res.get("events", []):
		var t := _ev_text(ev)
		if t != "":
			_log_lines.append("   " + t)
		# juice：受伤 → 闪白 + 震屏 + 伤害数字
		if ev.get("id", "") == "damage_taken":
			var pl: int = ev.get("player", 0)
			var sl: int = battle.active_index[pl]
			_flash(pl, sl)
			_shake = 9.0
			_pop_damage(pl, sl, float(ev.get("amount", 0)) / 2.0)


func _flash(player: int, slot: int) -> void:
	if slot >= _panel[player].size():
		return
	var pnl: PanelContainer = _panel[player][slot].pnl
	var tw := create_tween()
	tw.tween_property(pnl, "modulate", Color(1, 0.4, 0.4), 0.04)
	tw.tween_property(pnl, "modulate", Color.WHITE, 0.18)


func _pop_damage(player: int, slot: int, amount: float) -> void:
	if slot >= _panel[player].size():
		return
	var pnl: PanelContainer = _panel[player][slot].pnl
	var lbl := Label.new()
	lbl.text = "-%.1f" % amount
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.global_position = pnl.global_position + Vector2(50, 10)
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -70), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.2)
	get_tree().create_timer(0.85).timeout.connect(lbl.queue_free)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_stage.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - 40.0 * delta)
		if _shake <= 0.0:
			_stage.position = Vector2.ZERO


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
		"damage_taken": return "[color=tomato]%s 受 %.1f[/color]" % [who, float(ev.get("amount", 0)) / 2.0]
		"deferred_damage": return "[color=tomato]%s 延迟伤害 %.1f[/color]" % [who, float(ev.get("amount", 0)) / 2.0]
		"big_defend_block", "defend_block": return "[color=aqua]%s 格挡[/color]" % who
		"shield_absorb": return "%s 护盾吸收 %.1f" % [who, float(ev.get("amount", 0)) / 2.0]
		"charge_gain": return "%s 攒 +%d" % [who, ev.get("amount", 0)]
		"active_used": return "[color=orange]%s 发动技能[/color]" % who
		"vulnerable": return "[color=orange]%s 易伤[/color]" % who
		"switch": return "%s 切换" % who
		"hero_died": return "[color=red]%s 一英雄阵亡[/color]" % who
		"victory", "draw": return "[color=gold]胜负已分[/color]"
	return ""
