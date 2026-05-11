extends Control

## Fighting-game layout. 1920x1080. Circular action buttons + timer.

const CX1 := 480.0
const CX2 := 1440.0
const CHAR_W := 160
const CHAR_H := 260
const FLOOR_Y := 750.0
const MAX_ENERGY := 20
const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0

enum State { P1_TURN, PASS_DEVICE, P2_TURN, RESOLVING, GAME_OVER }

var battle: BattleCore
var state: int = State.P1_TURN

# Circular buttons
var btn_charge: Button
var btn_attack: Button
var btn_big_attack: Button
var btn_defend: Button
var btn_big_defend: Button
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
var p1_energy_label: Label
var p2_energy_label: Label
var turn_label: Label
var timer_label: Label
var status_label: Label
var event_label: Label
var next_button: Button

var game_timer: Timer
var timer_seconds: int = 0


func _ready() -> void:
	battle = BattleCore.new()
	battle.setup([BattleSetup.p1_hero], [BattleSetup.p2_hero])
	_build_styles()
	_build_ui()
	_update_all()
	_start_p1_turn()


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

	# Floor
	var floor := ColorRect.new()
	floor.color = Color("#333355")
	floor.position = Vector2(120, FLOOR_Y)
	floor.size = Vector2(1680, 6)
	add_child(floor)

	# Characters
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

	# HP above characters
	p1_hp_label = _make_label("", 28, Color("#ff6666"), Vector2(CX1 - 70, FLOOR_Y - CHAR_H - 42), self, HORIZONTAL_ALIGNMENT_CENTER)
	p1_hp_label.size = Vector2(140, 34)
	p2_hp_label = _make_label("", 28, Color("#ff6666"), Vector2(CX2 - 70, FLOOR_Y - CHAR_H - 42), self, HORIZONTAL_ALIGNMENT_CENTER)
	p2_hp_label.size = Vector2(140, 34)

	# Hero name labels
	var p1_name := _make_label("", 22, Color.WHITE, Vector2(CX1 - 100, FLOOR_Y - CHAR_H - 78), self, HORIZONTAL_ALIGNMENT_CENTER)
	p1_name.size = Vector2(200, 30)
	p1_name.name = "P1Name"
	var p2_name := _make_label("", 22, Color.WHITE, Vector2(CX2 - 100, FLOOR_Y - CHAR_H - 78), self, HORIZONTAL_ALIGNMENT_CENTER)
	p2_name.size = Vector2(200, 30)
	p2_name.name = "P2Name"

	# Energy labels
	p1_energy_label = _make_label("", 22, Color("#f5c518"), Vector2(CX1 - 200, FLOOR_Y + 20), self, HORIZONTAL_ALIGNMENT_CENTER)
	p1_energy_label.size = Vector2(400, 52)
	p2_energy_label = _make_label("", 22, Color("#f5c518"), Vector2(CX2 - 200, FLOOR_Y + 20), self, HORIZONTAL_ALIGNMENT_CENTER)
	p2_energy_label.size = Vector2(400, 52)

	# Turn counter (top center)
	turn_label = _make_label("回合 0", 24, Color.WHITE, Vector2(760, 4), self, HORIZONTAL_ALIGNMENT_CENTER)
	turn_label.size = Vector2(400, 30)

	# Countdown timer
	timer_label = _make_label("", 20, Color("#aaccee"), Vector2(760, 30), self, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(400, 26)

	# Status / event labels
	status_label = _make_label("", 26, Color.WHITE, Vector2(460, 280), self, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.size = Vector2(1000, 36)
	event_label = _make_label("", 22, Color.WHITE, Vector2(460, 820), self, HORIZONTAL_ALIGNMENT_CENTER)
	event_label.size = Vector2(1000, 60)
	event_label.visible = false

	# Next button
	next_button = Button.new()
	next_button.text = "下一回合"
	next_button.add_theme_font_size_override("font_size", 22)
	next_button.position = Vector2(860, 820)
	next_button.size = Vector2(200, 55)
	next_button.visible = false
	next_button.pressed.connect(_on_next_pressed)
	add_child(next_button)

	# Timer
	game_timer = Timer.new()
	game_timer.one_shot = false
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)

	# Circular action buttons
	_create_circle_buttons()


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

	btn_confirm = _make_circle("结束")
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)
	btn_confirm.add_theme_stylebox_override("hover", _confirm_style_active)
	btn_confirm.pressed.connect(_on_confirm_pressed)

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]


func _make_circle(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size = Vector2(CIRCLE_D, CIRCLE_D)
	btn.add_theme_stylebox_override("normal", _circle_style_normal.duplicate())
	btn.add_theme_stylebox_override("hover", _circle_style_hover)
	btn.add_theme_stylebox_override("pressed", _circle_style_hover)
	btn.add_theme_stylebox_override("disabled", _circle_style_disabled)
	btn.add_theme_font_size_override("font_size", 16)
	btn.clip_text = true
	add_child(btn)
	return btn


func _layout_circles() -> void:
	var buttons: Array[Button] = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_confirm]
	var n := buttons.size()
	var total_w := n * CIRCLE_D + (n - 1) * CIRCLE_GAP
	var start_x := (1920.0 - total_w) / 2.0

	for i in range(n):
		buttons[i].position = Vector2(start_x + i * (CIRCLE_D + CIRCLE_GAP), CIRCLE_Y)
		buttons[i].visible = true


func _make_label(text: String, size: int, color: Color, pos: Vector2, parent: Node, halign: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = halign
	l.position = pos
	parent.add_child(l)
	return l


# --- Turn flow ---

func _start_p1_turn() -> void:
	state = State.P1_TURN
	status_label.text = "P1 - 选择动作"
	status_label.visible = true
	selected_action = -1
	selected_btn = null
	_set_buttons_active(true)
	_update_button_states()
	next_button.visible = false
	event_label.visible = false
	_start_timer()
	_update_all()


func _start_timer() -> void:
	var t := battle.turn_number + 1
	if t <= 3:
		timer_seconds = 10
	elif t <= 6:
		timer_seconds = 20
	else:
		timer_seconds = 30
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
	# Deselect if tapping same button
	if selected_btn == btn:
		selected_action = -1
		selected_btn = null
		_reset_button_styles()
		_update_button_states()
		return

	selected_action = action
	_reset_button_styles()
	selected_btn = btn
	btn.add_theme_stylebox_override("normal", _circle_style_selected)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style_active)


func _on_confirm_pressed() -> void:
	if selected_action < 0:
		selected_action = BattleCore.Action.CHARGE

	game_timer.stop()
	_reset_button_styles()
	battle.select_action(0 if state == State.P1_TURN else 1, selected_action)
	selected_action = -1
	selected_btn = null

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

	var r: Dictionary = battle.resolve()

	var a1_name: String = battle.get_action_name(r.p1_action)
	var a2_name: String = battle.get_action_name(r.p2_action)
	status_label.text = "P1: %s    vs    P2: %s" % [a1_name, a2_name]
	status_label.visible = true

	var txt := ""
	for ev in r.events:
		txt += ev + "\n"
	event_label.text = txt.strip_edges()
	event_label.visible = true

	next_button.visible = true
	next_button.text = "结束" if r.game_over else "下一回合"

	_update_all()


func _on_next_pressed() -> void:
	next_button.visible = false
	event_label.visible = false

	if battle.game_over:
		state = State.GAME_OVER
		status_label.text = "游戏结束！"
		_update_all()
	else:
		_start_p1_turn()


func _set_buttons_active(active: bool) -> void:
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = active
		btn.disabled = not active
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

	btn_confirm.disabled = false
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)


func _update_all() -> void:
	turn_label.text = "回合 %d" % (battle.turn_number + 1)
	_update_energy_labels()
	_update_hp_labels()
	_update_hero_names()


func _update_energy_labels() -> void:
	var e1: int = battle.energy[0]
	var e2: int = battle.energy[1]
	p1_energy_label.text = _energy_os(e1)
	p2_energy_label.text = _energy_os(e2)


func _energy_os(count: int) -> String:
	var s := ""
	for _i in range(min(count, 10)):
		s += "O "
	if count > 10:
		s += "\n"
		for _i in range(count - 10):
			s += "O "
	return s


func _update_hp_labels() -> void:
	var h1: int = battle.current_hp(0)
	var h2: int = battle.current_hp(1)

	p1_hp_label.text = "❤%d" % h1
	p2_hp_label.text = "❤%d" % h2

	var ratio1 := clampf(float(h1) / float(battle.current_max_hp(0)), 0.0, 1.0)
	var ratio2 := clampf(float(h2) / float(battle.current_max_hp(1)), 0.0, 1.0)
	p1_hp_label.add_theme_color_override("font_color", _hp_color(ratio1))
	p2_hp_label.add_theme_color_override("font_color", _hp_color(ratio2))

	var p1_dmg := state == State.RESOLVING and h1 < battle.current_max_hp(0)
	var p2_dmg := state == State.RESOLVING and h2 < battle.current_max_hp(1)
	p1_char_rect.modulate = Color.RED if p1_dmg else Color.WHITE
	p2_char_rect.modulate = Color.RED if p2_dmg else Color.WHITE


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
