extends Control

## 1920x1080. Hero frames top corners (clickable to switch), energy behind, buttons bottom.

const CX1 := 480.0
const CX2 := 1440.0
const CHAR_W := 160
const CHAR_H := 260
const FLOOR_Y := 750.0
const MAX_ENERGY := 20
const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0

const FRAME_L := 72.0
const FRAME_S := 48.0
const FRAME_GAP := 10.0
const FRAME_Y := 8.0
const FRAMES_TOTAL_W := FRAME_L + FRAME_GAP + FRAME_S + FRAME_GAP + FRAME_S

enum State { P1_TURN, P2_TURN, RESOLVING, GAME_OVER, TURN_INTRO }

var battle: BattleCore
var state: int = State.TURN_INTRO

# Circular buttons
var btn_charge: Button
var btn_attack: Button
var btn_big_attack: Button
var btn_defend: Button
var btn_big_defend: Button
var btn_special: Button
var btn_confirm: Button
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_btn: Button = null
var _circle_style_normal: StyleBoxFlat
var _circle_style_hover: StyleBoxFlat
var _circle_style_selected: StyleBoxFlat
var _circle_style_disabled: StyleBoxFlat
var _confirm_style: StyleBoxFlat
var _confirm_style_active: StyleBoxFlat

# UI
var p1_char_rect: ColorRect
var p2_char_rect: ColorRect
var p1_hp_label: Label
var p2_hp_label: Label
var p1_energy_labels: Array[Label] = []
var p2_energy_labels: Array[Label] = []
var turn_label: Label
var timer_label: Label
var status_label: Label
var event_label: Label
var big_turn_label: Label

var p1_frames: Array[Panel] = []
var p2_frames: Array[Panel] = []
var p1_frame_hp_labels: Array[Label] = []
var p2_frame_hp_labels: Array[Label] = []
var p1_frame_shield_labels: Array[Label] = []
var p2_frame_shield_labels: Array[Label] = []
var p1_frame_slots: Array = []
var p2_frame_slots: Array = []

var game_timer: Timer
var timer_seconds: int = 0

var p1_hit := false
var p2_hit := false

# Clone display (身外化身)
var p1_clone_rects: Array[ColorRect] = []
var p2_clone_rects: Array[ColorRect] = []
var p1_clone_hp_labels: Array[Label] = []
var p2_clone_hp_labels: Array[Label] = []
var _clone_target: int = -1
var _clone_target_rects: Array = []


func _ready() -> void:
	battle = BattleCore.new()
	battle.setup(BattleSetup.p1_heroes, BattleSetup.p2_heroes)
	_build_styles()
	_build_ui()
	_update_all()
	_show_turn_intro()


func _build_styles() -> void:
	var r := CIRCLE_D / 2.0

	_circle_style_normal = StyleBoxFlat.new()
	_circle_style_normal.bg_color = Color("#2a2a4a")
	_circle_style_normal.set_corner_radius_all(int(r))
	_circle_style_normal.border_width_left = 3
	_circle_style_normal.border_width_right = 3
	_circle_style_normal.border_width_top = 3
	_circle_style_normal.border_width_bottom = 3
	_circle_style_normal.border_color = Color("#4a4a6a")

	_circle_style_hover = _circle_style_normal.duplicate() as StyleBoxFlat
	_circle_style_hover.bg_color = Color("#3d3d66")
	_circle_style_hover.border_color = Color("#6a6acc")

	_circle_style_selected = _circle_style_normal.duplicate() as StyleBoxFlat
	_circle_style_selected.border_color = Color("#ffdd44")
	_circle_style_selected.border_width_left = 5
	_circle_style_selected.border_width_right = 5
	_circle_style_selected.border_width_top = 5
	_circle_style_selected.border_width_bottom = 5
	_circle_style_selected.bg_color = Color("#3a3a5a")

	_circle_style_disabled = _circle_style_normal.duplicate() as StyleBoxFlat
	_circle_style_disabled.bg_color = Color("#1a1a2a")
	_circle_style_disabled.border_color = Color("#2a2a3a")

	_confirm_style = StyleBoxFlat.new()
	_confirm_style.bg_color = Color("#2a4a2a")
	_confirm_style.set_corner_radius_all(int(r))
	_confirm_style.border_width_left = 3
	_confirm_style.border_width_right = 3
	_confirm_style.border_width_top = 3
	_confirm_style.border_width_bottom = 3
	_confirm_style.border_color = Color("#44aa44")

	_confirm_style_active = _confirm_style.duplicate() as StyleBoxFlat
	_confirm_style_active.bg_color = Color("#3a6a3a")
	_confirm_style_active.border_color = Color("#44ff44")
	_confirm_style_active.border_width_left = 4
	_confirm_style_active.border_width_right = 4
	_confirm_style_active.border_width_top = 4
	_confirm_style_active.border_width_bottom = 4


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#1a1a2e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var floor := ColorRect.new()
	floor.color = Color("#333355")
	floor.position = Vector2(120, FLOOR_Y)
	floor.size = Vector2(1680, 6)
	add_child(floor)

	p1_char_rect = ColorRect.new()
	p1_char_rect.color = Color("#3388dd")
	p1_char_rect.position = Vector2(CX1 - CHAR_W / 2.0, FLOOR_Y - CHAR_H)
	p1_char_rect.size = Vector2(CHAR_W, CHAR_H)
	add_child(p1_char_rect)

	p2_char_rect = ColorRect.new()
	p2_char_rect.color = Color("#dd3333")
	p2_char_rect.position = Vector2(CX2 - CHAR_W / 2.0, FLOOR_Y - CHAR_H)
	p2_char_rect.size = Vector2(CHAR_W, CHAR_H)
	add_child(p2_char_rect)

	p1_hp_label = _make_label("", 28, Color("#ff6666"), Vector2(CX1 - 70, FLOOR_Y - CHAR_H - 42), self)
	p1_hp_label.size = Vector2(140, 34)
	p1_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_hp_label = _make_label("", 28, Color("#ff6666"), Vector2(CX2 - 70, FLOOR_Y - CHAR_H - 42), self)
	p2_hp_label.size = Vector2(140, 34)
	p2_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var p1_name := _make_label("", 20, Color.WHITE, Vector2(CX1 - 100, FLOOR_Y - CHAR_H - 68), self)
	p1_name.size = Vector2(200, 26)
	p1_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_name.name = "P1Name"
	var p2_name := _make_label("", 20, Color.WHITE, Vector2(CX2 - 100, FLOOR_Y - CHAR_H - 68), self)
	p2_name.size = Vector2(200, 26)
	p2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_name.name = "P2Name"

	_create_hero_frames(0, 30.0)
	_create_hero_frames(1, 1920.0 - 30.0 - FRAMES_TOTAL_W)
	_create_energy_labels()
	_create_clone_rects()

	# Big centered turn label
	big_turn_label = Label.new()
	big_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontManager.apply(big_turn_label, 48)
	big_turn_label.add_theme_color_override("font_color", Color("#f5c518"))
	big_turn_label.position = Vector2(460, 350)
	big_turn_label.size = Vector2(1000, 64)
	big_turn_label.visible = false
	add_child(big_turn_label)

	turn_label = _make_label("回合 0", 24, Color.WHITE, Vector2(760, 4), self)
	turn_label.size = Vector2(400, 30)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	timer_label = _make_label("", 20, Color("#aaccee"), Vector2(760, 30), self)
	timer_label.size = Vector2(400, 26)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	status_label = _make_label("", 26, Color.WHITE, Vector2(460, 280), self)
	status_label.size = Vector2(1000, 36)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label = _make_label("", 22, Color.WHITE, Vector2(460, 820), self)
	event_label.size = Vector2(1000, 60)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.visible = false

	game_timer = Timer.new()
	game_timer.one_shot = false
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)

	_create_circle_buttons()


func _create_hero_frames(player: int, start_x: float) -> void:
	var frames: Array[Panel] = []
	var hp_labels: Array[Label] = []
	var shield_labels: Array[Label] = []
	var slots: Array = []
	var border_color := Color("#3388dd") if player == 0 else Color("#dd3333")

	var large := Panel.new()
	large.position = Vector2(start_x, FRAME_Y)
	large.size = Vector2(FRAME_L, FRAME_L)
	large.mouse_filter = Control.MOUSE_FILTER_STOP
	large.gui_input.connect(_on_frame_gui_input.bind(player, 0))
	_add_frame_style(large, Color("#ffdd44"), true)
	add_child(large)
	frames.append(large)

	var large_hp := _make_label("❤0", 13, Color("#ff6666"), Vector2(start_x, FRAME_Y + FRAME_L + 2), self)
	large_hp.size = Vector2(FRAME_L, 16)
	large_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_labels.append(large_hp)
	var large_sd := _make_label("", 11, Color("#44ccff"), Vector2(start_x, FRAME_Y + FRAME_L + 20), self)
	large_sd.size = Vector2(FRAME_L, 14)
	large_sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_labels.append(large_sd)
	slots.append(-1)

	for i in range(2):
		var small := Panel.new()
		var sx := start_x + FRAME_L + FRAME_GAP + i * (FRAME_S + FRAME_GAP)
		small.position = Vector2(sx, FRAME_Y + (FRAME_L - FRAME_S) / 2.0)
		small.size = Vector2(FRAME_S, FRAME_S)
		small.mouse_filter = Control.MOUSE_FILTER_STOP
		small.gui_input.connect(_on_frame_gui_input.bind(player, i + 1))
		_add_frame_style(small, border_color, false)
		add_child(small)
		frames.append(small)

		var small_hp := _make_label("❤0", 11, Color("#ff6666"), Vector2(sx, FRAME_Y + FRAME_L + 2), self)
		small_hp.size = Vector2(FRAME_S, 16)
		small_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_labels.append(small_hp)
		var small_sd := _make_label("", 10, Color("#44ccff"), Vector2(sx, FRAME_Y + FRAME_L + 20), self)
		small_sd.size = Vector2(FRAME_S, 14)
		small_sd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shield_labels.append(small_sd)
		slots.append(-1)

	if player == 0:
		p1_frames = frames
		p1_frame_hp_labels = hp_labels
		p1_frame_shield_labels = shield_labels
		p1_frame_slots = slots
	else:
		p2_frames = frames
		p2_frame_hp_labels = hp_labels
		p2_frame_shield_labels = shield_labels
		p2_frame_slots = slots


func _add_frame_style(panel: Panel, border_color: Color, highlight: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#222244")
	sb.border_width_left = 5 if highlight else 2
	sb.border_width_right = 5 if highlight else 2
	sb.border_width_top = 5 if highlight else 2
	sb.border_width_bottom = 5 if highlight else 2
	sb.border_color = border_color
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)


func _on_frame_gui_input(event: InputEvent, player: int, frame_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_try_switch_hero(player, frame_idx)


func _try_switch_hero(player: int, frame_idx: int) -> void:
	if not state in [State.P1_TURN, State.P2_TURN]:
		return
	var current_player := 0 if state == State.P1_TURN else 1
	if player != current_player:
		return

	var frame_slots: Array = p1_frame_slots if player == 0 else p2_frame_slots
	if frame_idx >= frame_slots.size():
		return
	var hero_slot: int = frame_slots[frame_idx]

	if frame_idx == 0:
		return

	if hero_slot < 0:
		return
	if hero_slot == battle.active_hero_index[player]:
		return
	if battle.hero_hp[player][hero_slot] <= 0:
		return
	if not battle.can_afford(player, BattleCore.Action.SWITCH):
		return

	battle.select_switch_target(player, hero_slot)
	_update_all()


func _create_energy_labels() -> void:
	var p1_energy_x := 30.0 + FRAMES_TOTAL_W + 14.0
	for row in range(2):
		var lbl := _make_label("", 16, Color("#f5c518"), Vector2(p1_energy_x, FRAME_Y + row * 18), self)
		lbl.size = Vector2(400, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p1_energy_labels.append(lbl)

	var p2_frames_start := 1920.0 - 30.0 - FRAMES_TOTAL_W
	var p2_energy_end := p2_frames_start - 14.0
	for row in range(2):
		var lbl := _make_label("", 16, Color("#f5c518"), Vector2(p2_energy_end - 400, FRAME_Y + row * 18), self)
		lbl.size = Vector2(400, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p2_energy_labels.append(lbl)


func _create_circle_buttons() -> void:
	btn_charge = _make_circle("攒")
	btn_charge.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.CHARGE, btn_charge))

	btn_attack = _make_circle("波")
	btn_attack.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.ATTACK, btn_attack))

	btn_big_attack = _make_circle("大波")
	btn_big_attack.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.BIG_ATTACK, btn_big_attack))

	btn_defend = _make_circle("防")
	btn_defend.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.DEFEND, btn_defend))

	btn_big_defend = _make_circle("大防")
	btn_big_defend.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.BIG_DEFEND, btn_big_defend))

	btn_special = _make_circle("")
	btn_special.pressed.connect(_on_circle_pressed.bind(-1, btn_special))
	btn_special.visible = false

	btn_confirm = _make_circle("结束")
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)
	btn_confirm.add_theme_stylebox_override("hover", _confirm_style_active)
	btn_confirm.pressed.connect(_on_confirm_pressed)

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]


func _make_circle(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size = Vector2(CIRCLE_D, CIRCLE_D)
	btn.add_theme_stylebox_override("normal", _circle_style_normal.duplicate())
	btn.add_theme_stylebox_override("hover", _circle_style_hover)
	btn.add_theme_stylebox_override("pressed", _circle_style_hover)
	btn.add_theme_stylebox_override("disabled", _circle_style_disabled)
	FontManager.apply_btn(btn, 16)
	btn.clip_text = true
	add_child(btn)
	return btn


func _layout_circles() -> void:
	var player: int = 0 if state in [State.P1_TURN] else 1
	var has_skill := false
	if state in [State.P1_TURN, State.P2_TURN]:
		has_skill = battle.active_hero(player).has_skill_type(HeroData.SkillType.EXTRA_ACTION)

	var is_fool: bool = has_skill and battle.active_hero(player).hero_id == "h13"
	var buttons: Array[Button]
	if is_fool:
		buttons = [btn_special]
		btn_special.text = battle.get_action_name(battle.active_hero(player).extra_action_id)
	else:
		buttons = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]
		if has_skill:
			buttons.append(btn_special)
			btn_special.text = battle.get_action_name(battle.active_hero(player).extra_action_id)
	buttons.append(btn_confirm)

	var n := buttons.size()
	var total_w := n * CIRCLE_D + (n - 1) * CIRCLE_GAP
	var start_x := (1920.0 - total_w) / 2.0

	for i in range(n):
		buttons[i].position = Vector2(start_x + i * (CIRCLE_D + CIRCLE_GAP), CIRCLE_Y)
		buttons[i].visible = true
	btn_special.visible = has_skill
	if is_fool:
		for b in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]:
			b.visible = false


func _make_label(text: String, size: int, color: Color, pos: Vector2, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	FontManager.apply(l, size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	parent.add_child(l)
	return l


# --- Turn flow ---

func _show_turn_intro() -> void:
	state = State.TURN_INTRO
	_set_buttons_active(false)
	status_label.visible = false
	event_label.visible = false
	timer_label.text = ""

	big_turn_label.text = "回合 %d" % (battle.turn_number + 1)
	big_turn_label.visible = true

	await get_tree().create_timer(1.2).timeout

	big_turn_label.visible = false
	_start_p1_turn()


func _start_p1_turn() -> void:
	p1_hit = false
	p2_hit = false
	state = State.P1_TURN
	status_label.text = "P1 - 选择动作"
	status_label.visible = true
	selected_action = -1
	selected_btn = null
	_set_buttons_active(true)
	_update_button_states()
	event_label.visible = false
	_start_timer()
	_update_all()


func _start_timer() -> void:
	timer_seconds = 5
	_update_timer_label()
	game_timer.start(1.0)


func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	if timer_seconds <= 0:
		game_timer.stop()
		_on_confirm_pressed()


func _update_timer_label() -> void:
	timer_label.text = "剩余 %ds" % timer_seconds
	if timer_seconds <= 5:
		timer_label.add_theme_color_override("font_color", Color("#ff6666"))
	else:
		timer_label.add_theme_color_override("font_color", Color("#aaccee"))


func _on_circle_pressed(action: int, btn: Button) -> void:
	var player: int = 0 if state in [State.P1_TURN] else 1

	if action == -1 and btn == btn_special:
		action = battle.active_hero(player).extra_action_id

	if selected_btn == btn:
		selected_action = -1
		selected_btn = null
		_reset_button_styles()
		_update_button_states()
		_update_clone_target_highlight()
		return

	selected_action = action
	_update_clone_target_highlight()
	_reset_button_styles()
	selected_btn = btn
	btn.add_theme_stylebox_override("normal", _circle_style_selected)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style_active)


func _on_confirm_pressed() -> void:
	if selected_action < 0:
		selected_action = BattleCore.Action.CHARGE

	var player: int = 0 if state == State.P1_TURN else 1
	var opp: int = 1 - player
	if selected_action in [BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK]:
		if battle.clone_count[opp] > 0 and _clone_target < 0:
			status_label.text = "请选择攻击对象！"
			return

	game_timer.stop()
	_reset_button_styles()
	battle.select_action(0 if state == State.P1_TURN else 1, selected_action)
	selected_action = -1
	selected_btn = null
	_clone_target = -1

	if state == State.P1_TURN:
		state = State.P2_TURN
		status_label.text = "P2 - 选择动作"
		_set_buttons_active(true)
		_update_button_states()
		_start_timer()
	else:
		_resolve()


func _resolve() -> void:
	state = State.RESOLVING
	_set_buttons_active(false)
	timer_label.text = ""

	var hp1_before: int = battle.current_hp(0)
	var hp2_before: int = battle.current_hp(1)
	var r: Dictionary = battle.resolve()
	p1_hit = battle.current_hp(0) < hp1_before
	p2_hit = battle.current_hp(1) < hp2_before

	var a1_name: String = battle.get_action_name(r.p1_action)
	var a2_name: String = battle.get_action_name(r.p2_action)
	status_label.text = "P1: %s    vs    P2: %s" % [a1_name, a2_name]
	status_label.visible = true

	var txt := ""
	for ev in r.events:
		txt += ev + "\n"
	event_label.text = txt.strip_edges()
	event_label.visible = true

	_update_all()

	if r.game_over:
		state = State.GAME_OVER
		status_label.text = "游戏结束！"
	else:
		await get_tree().create_timer(1.8).timeout
		_show_turn_intro()


func _set_buttons_active(active: bool) -> void:
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = active
		btn.disabled = not active
	if not active:
		btn_special.visible = false
	if active:
		_layout_circles()


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		btn.add_theme_stylebox_override("normal", _circle_style_normal)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)


func _update_button_states() -> void:
	_layout_circles()
	var player: int = 0 if state in [State.P1_TURN] else 1
	var en: int = battle.energy[player]

	for btn in action_btn_list:
		if not btn.visible:
			continue
		if btn == btn_charge:
			btn.disabled = false
		elif btn == btn_attack:
			btn.disabled = en < 1
		elif btn == btn_big_attack:
			btn.disabled = en < 3
		elif btn == btn_defend:
			btn.disabled = false
		elif btn == btn_big_defend:
			btn.disabled = en < 2
		elif btn == btn_special:
			var h: HeroData = battle.active_hero(player)
			btn.disabled = not battle.can_afford(player, h.extra_action_id)

	btn_confirm.disabled = false
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)
	_update_clone_target_highlight()


func _update_all() -> void:
	turn_label.text = "回合 %d" % (battle.turn_number + 1)
	_update_hero_frames()
	_update_energy_labels()
	_update_hp_labels()
	_update_hero_names()
	_update_clone_display()
	if state in [State.P1_TURN, State.P2_TURN]:
		_update_button_states()


func _get_reserve_slots(player: int) -> Array:
	var result: Array = []
	for i in range(battle.heroes[player].size()):
		if i != battle.active_hero_index[player]:
			result.append(i)
	return result


func _update_hero_frames() -> void:
	for p in [0, 1]:
		var frames := p1_frames if p == 0 else p2_frames
		var hp_labels := p1_frame_hp_labels if p == 0 else p2_frame_hp_labels
		var frame_slots: Array = p1_frame_slots if p == 0 else p2_frame_slots
		var shield_labels := p1_frame_shield_labels if p == 0 else p2_frame_shield_labels
		var active_idx: int = battle.active_hero_index[p]
		var reserves := _get_reserve_slots(p)

		var slot0: int = active_idx
		frame_slots[0] = slot0
		_update_single_frame(frames[0], hp_labels[0], shield_labels[0], p, slot0, true)

		for j in range(2):
			var fi := j + 1
			if j < reserves.size():
				var slot: int = reserves[j]
				frame_slots[fi] = slot
				_update_single_frame(frames[fi], hp_labels[fi], shield_labels[fi], p, slot, false)
			else:
				frame_slots[fi] = -1
				frames[fi].visible = false
				hp_labels[fi].visible = false


func _update_single_frame(frame: Panel, hp_label: Label, shield_label: Label, player: int, slot: int, is_active: bool) -> void:
	if slot < 0 or slot >= battle.heroes[player].size():
		frame.visible = false
		hp_label.visible = false
		shield_label.visible = false
		return

	frame.visible = true
	shield_label.visible = true
	hp_label.visible = true

	var sb := frame.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
	if not sb:
		return

	if is_active:
		sb.border_color = Color("#ffdd44")
		sb.border_width_left = 5
		sb.border_width_right = 5
		sb.border_width_top = 5
		sb.border_width_bottom = 5
	else:
		var dead: bool = battle.hero_hp[player][slot] <= 0
		var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")
		sb.border_color = Color("#444444") if dead else base_color
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2

	hp_label.text = "❤%d" % battle.hero_hp[player][slot]
	var hp_color := _hp_color(clampf(float(battle.hero_hp[player][slot]) / float(battle.hero_max_hp[player][slot]), 0.0, 1.0))
	hp_label.add_theme_color_override("font_color", hp_color)

	if frame.get_child_count() == 0:
		var hl := Label.new()
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		FontManager.apply(hl, 12)
		hl.add_theme_color_override("font_color", Color.WHITE)
		hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.add_child(hl)
	var sh: int = battle.shield[player][slot]
	shield_label.text = "🛡%d" % sh if sh > 0 else ""
	var hl := frame.get_child(0) as Label
	hl.text = battle.heroes[player][slot].hero_name.substr(0, 2)



func _update_energy_labels() -> void:
	var e1: int = battle.energy[0]
	var e2: int = battle.energy[1]

	for row in range(2):
		var start := row * 10
		var count := clampi(e1 - start, 0, 10)
		var txt := ""
		for _j in range(count):
			txt += "O "
		p1_energy_labels[row].text = txt

	for row in range(2):
		var start := row * 10
		var count := clampi(e2 - start, 0, 10)
		var txt := ""
		for _j in range(count):
			txt += "O "
		p2_energy_labels[row].text = txt


func _update_hp_labels() -> void:
	var h1: int = battle.current_hp(0)
	var h2: int = battle.current_hp(1)
	var clones1: bool = battle.clone_count[0] > 0
	var clones2: bool = battle.clone_count[1] > 0

	p1_hp_label.visible = not clones1
	p2_hp_label.visible = not clones2
	p1_char_rect.visible = not clones1
	p2_char_rect.visible = not clones2

	if not clones1:
		var s1: int = battle.shield[0][battle.active_hero_index[0]]
		p1_hp_label.text = "❤%d  🛡%d" % [h1, s1] if s1 > 0 else "❤%d" % h1
		var ratio1 := clampf(float(h1) / float(battle.current_max_hp(0)), 0.0, 1.0)
		p1_hp_label.add_theme_color_override("font_color", _hp_color(ratio1))
		p1_char_rect.modulate = Color("#663355") if (state == State.RESOLVING and p1_hit) else Color.WHITE
	if not clones2:
		var s2: int = battle.shield[1][battle.active_hero_index[1]]
		p2_hp_label.text = "❤%d  🛡%d" % [h2, s2] if s2 > 0 else "❤%d" % h2
		var ratio2 := clampf(float(h2) / float(battle.current_max_hp(1)), 0.0, 1.0)
		p2_hp_label.add_theme_color_override("font_color", _hp_color(ratio2))
		p2_char_rect.modulate = Color("#663333") if (state == State.RESOLVING and p2_hit) else Color.WHITE


func _update_hero_names() -> void:
	var n1 := get_node_or_null("P1Name") as Label
	var n2 := get_node_or_null("P2Name") as Label
	if n1:
		n1.text = battle.active_hero(0).hero_name
	if n2:
		n2.text = battle.active_hero(1).hero_name


func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color("#44cc44")
	elif ratio > 0.3:
		return Color("#ffaa00")
	return Color("#ff4444")


# --- Clone display (身外化身) ---

const CLONE_W := 50.0
const CLONE_H := 260.0
const CLONE_GAP := 5.0
const CLONE_Y_OFFSET := FLOOR_Y - CLONE_H


func _create_clone_rects() -> void:
	for player in [0, 1]:
		var cx := CX1 if player == 0 else CX2
		var rects: Array[ColorRect] = []
		var hp_labels: Array[Label] = []
		var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")

		var offsets := [-CLONE_W - CLONE_GAP, 0.0, CLONE_W + CLONE_GAP]
		for i in range(3):
			var r := ColorRect.new()
			r.color = base_color if i == 1 else Color("#555555")
			r.position = Vector2(cx + offsets[i], CLONE_Y_OFFSET)
			r.size = Vector2(CLONE_W, CLONE_H)
			r.visible = false
			r.mouse_filter = Control.MOUSE_FILTER_STOP
			r.gui_input.connect(_on_clone_target_input.bind(player, i))
			add_child(r)
			rects.append(r)

			var lbl := _make_label("", 12, Color("#ff6666"), Vector2(cx + offsets[i], CLONE_Y_OFFSET - 18), self)
			lbl.size = Vector2(CLONE_W, 16)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.visible = false
			hp_labels.append(lbl)

		if player == 0:
			p1_clone_rects = rects
			p1_clone_hp_labels = hp_labels
		else:
			p2_clone_rects = rects
			p2_clone_hp_labels = hp_labels


func _update_clone_display() -> void:
	for player in [0, 1]:
		var rects: Array = p1_clone_rects if player == 0 else p2_clone_rects
		var hp_labels: Array = p1_clone_hp_labels if player == 0 else p2_clone_hp_labels
		var cnt: int = battle.clone_count[player]

		var show_all := cnt > 0
		for i in range(3):
			rects[i].visible = show_all
			hp_labels[i].visible = show_all

		if not show_all:
			continue

		# From OWN perspective: center=real, left/right=clones (colored vs gray)
		# From OPPONENT perspective (during targeting): all same color
		var is_own: bool = (player == 0 and state == State.P1_TURN) or (player == 1 and state == State.P2_TURN)
		var order: Array = battle.clone_order[player]
		var clone_hps: Array = battle.clone_hp[player]
		var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")
		var n: int = order.size()
		var cx: float = CX1 if player == 0 else CX2
		var total_w: float = n * CLONE_W + (n - 1) * CLONE_GAP
		var start_x: float = cx - total_w / 2.0

		for display_pos in range(3):
			if display_pos >= n:
				rects[display_pos].visible = false
				hp_labels[display_pos].visible = false
				continue
			rects[display_pos].visible = true
			hp_labels[display_pos].visible = true
			rects[display_pos].position.x = start_x + display_pos * (CLONE_W + CLONE_GAP)
			hp_labels[display_pos].position.x = start_x + display_pos * (CLONE_W + CLONE_GAP)

			var actual: int = order[display_pos]
			if actual == 1:
				rects[display_pos].color = base_color
				hp_labels[display_pos].text = "❤%d" % battle.current_hp(player)
			else:
				rects[display_pos].color = Color("#555555")
				var ci: int = 0 if actual == 0 else 1
				var chp: int = clone_hps[ci] if ci < clone_hps.size() else 0
				hp_labels[display_pos].text = "❤%d" % chp

	# Update opponent target selection highlight
	_update_clone_target_highlight()


func _update_clone_target_highlight() -> void:
	var player: int = 0 if state == State.P1_TURN else 1
	var opp: int = 1 - player
	var sel: int = selected_action
	var is_attack := sel in [BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK]
	var show_targets := is_attack and battle.clone_count[opp] > 0

	var target_rects: Array = p2_clone_rects if state == State.P1_TURN else p1_clone_rects
	_clone_target_rects = target_rects if show_targets else []

	for r in target_rects:
		if show_targets:
			r.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not show_targets:
		_clone_target = -1


func _on_clone_target_input(event: InputEvent, player: int, display_pos: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var opp: int = 1 if state == State.P1_TURN else 0
	if player != opp:
		return
	if battle.clone_count[player] == 0:
		return
	_clone_target = display_pos
	battle.select_attack_target(1 - opp, display_pos)
	var pname := "P1" if state == State.P1_TURN else "P2"
	status_label.text = "%s - 已选攻击目标 #%d" % [pname, display_pos + 1]
