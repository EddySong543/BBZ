extends Control

## 1920x1080. Layout now visually editable in battle_screen.tscn.
## HeroFrame + CharacterDisplay instances pre-placed in scene, script configures at runtime.

const MAX_ENERGY := 20
const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0

## Duration (seconds) to wait for each animation phase. Tune in Inspector.
@export var anim_phase_duration: float = 2.0
@export var action_phase_duration: float = 0.8

enum State { P1_TURN, P2_TURN, RESOLVING, GAME_OVER, TURN_INTRO, HERO_SELECT }

var battle: BattleCore
var state: int = State.TURN_INTRO

# ---- @onready: static nodes from battle_screen.tscn ----
@onready var bg: ColorRect = $Background
@onready var floor_line: ColorRect = $Floor
@onready var p1_name_label: Label = $P1Name
@onready var p2_name_label: Label = $P2Name
@onready var p1_hp_label: Label = $P1HP
@onready var p2_hp_label: Label = $P2HP
@onready var turn_label: Label = $TurnLabel
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var event_label: Label = $EventLabel
@onready var big_turn_label: Label = $BigTurnLabel

# Character displays (AnimatedSprite2D — pre-placed in .tscn)
@onready var p1_char_display: CharacterDisplay = $P1CharDisplay
@onready var p2_char_display: CharacterDisplay = $P2CharDisplay

# Hero frames (pre-placed in .tscn, 3 per player)
@onready var p1_frames: Array[HeroFrame] = [$P1Frame0, $P1Frame1, $P1Frame2]
@onready var p2_frames: Array[HeroFrame] = [$P2Frame0, $P2Frame1, $P2Frame2]
@onready var p1_frame_hp_labels: Array[Label] = [$P1Frame0Hp, $P1Frame1Hp, $P1Frame2Hp]
@onready var p2_frame_hp_labels: Array[Label] = [$P2Frame0Hp, $P2Frame1Hp, $P2Frame2Hp]
@onready var p1_frame_shield_labels: Array[Label] = [$P1Frame0Shield, $P1Frame1Shield, $P1Frame2Shield]
@onready var p2_frame_shield_labels: Array[Label] = [$P2Frame0Shield, $P2Frame1Shield, $P2Frame2Shield]
var p1_frame_slots: Array = [-1, -1, -1]
var p2_frame_slots: Array = [-1, -1, -1]

@onready var buttons_ctrl: Control = $Buttons
@onready var p1_clone_area: Control = $P1CloneArea
@onready var p2_clone_area: Control = $P2CloneArea
@onready var game_timer: Timer = $GameTimer

# Button references (from .tscn)
@onready var btn_charge: Button = $Buttons/BtnCharge
@onready var btn_attack: Button = $Buttons/BtnAttack
@onready var btn_big_attack: Button = $Buttons/BtnBigAttack
@onready var btn_defend: Button = $Buttons/BtnDefend
@onready var btn_big_defend: Button = $Buttons/BtnBigDefend
@onready var btn_special: Button = $Buttons/BtnSpecial
@onready var btn_confirm: Button = $Buttons/BtnConfirm

# ---- Dynamic arrays ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_btn: Button = null
var _circle_style_normal: StyleBoxFlat
var _circle_style_hover: StyleBoxFlat
var _circle_style_selected: StyleBoxFlat
var _circle_style_disabled: StyleBoxFlat
var _confirm_style: StyleBoxFlat
var _confirm_style_active: StyleBoxFlat

# Energy labels (dynamic, placed absolutely)
var p1_energy_labels: Array[Label] = []
var p2_energy_labels: Array[Label] = []

# Clone display (dynamic, inside P1CloneArea/P2CloneArea)
var p1_clone_rects: Array[ColorRect] = []
var p2_clone_rects: Array[ColorRect] = []
var p1_clone_hp_labels: Array[Label] = []
var p2_clone_hp_labels: Array[Label] = []
var _clone_target: int = -1
var _clone_target_rects: Array = []

# State
var timer_seconds: int = 0
var p1_hit := false
var p2_hit := false


# ---- Lifecycle ----

func _ready() -> void:
	battle = BattleCore.new()
	battle.setup(BattleSetup.p1_heroes, BattleSetup.p2_heroes)
	_init_styles()
	_connect_frame_signals()
	_init_energy_labels()
	_init_clone_rects()
	_init_buttons()
	game_timer.timeout.connect(_on_timer_tick)
	_update_all()
	_show_turn_intro()


func _init_styles() -> void:
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


# ---- Dynamic UI construction ----

func _connect_frame_signals() -> void:
	for i in range(3):
		p1_frames[i].gui_input.connect(_on_frame_gui_input.bind(0, i))
		p2_frames[i].gui_input.connect(_on_frame_gui_input.bind(1, i))


func _init_energy_labels() -> void:
	var p1_energy_x := 232.0
	for row in range(2):
		var lbl := _make_label("", 16, Color("#f5c518"), Vector2(p1_energy_x, 8.0 + row * 18), self)
		lbl.size = Vector2(400, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p1_energy_labels.append(lbl)

	var p2_energy_end := 1688.0
	for row in range(2):
		var lbl := _make_label("", 16, Color("#f5c518"), Vector2(p2_energy_end - 400, 8.0 + row * 18), self)
		lbl.size = Vector2(400, 22)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		p2_energy_labels.append(lbl)


func _init_clone_rects() -> void:
	for player in [0, 1]:
		var area: Control = p1_clone_area if player == 0 else p2_clone_area
		var rects: Array[ColorRect] = []
		var hp_labels: Array[Label] = []
		var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")
		var offsets := [-CLONE_W - CLONE_GAP, 0.0, CLONE_W + CLONE_GAP]
		for i in range(3):
			var r := ColorRect.new()
			r.color = base_color if i == 1 else Color("#555555")
			r.position = Vector2(offsets[i], 0)
			r.size = Vector2(CLONE_W, CLONE_H)
			r.visible = false
			r.mouse_filter = Control.MOUSE_FILTER_STOP
			r.gui_input.connect(_on_clone_target_input.bind(player, i))
			area.add_child(r)
			rects.append(r)

			var lbl := _make_label("", 12, Color("#ff6666"), Vector2(offsets[i], -18), area)
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


func _init_buttons() -> void:
	# Wire up .tscn button signals
	btn_charge.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.CHARGE, btn_charge))
	btn_attack.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.ATTACK, btn_attack))
	btn_big_attack.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.BIG_ATTACK, btn_big_attack))
	btn_defend.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.DEFEND, btn_defend))
	btn_big_defend.pressed.connect(_on_circle_pressed.bind(BattleCore.Action.BIG_DEFEND, btn_big_defend))
	btn_special.pressed.connect(_on_circle_pressed.bind(-1, btn_special))
	btn_confirm.pressed.connect(_on_confirm_pressed)

	# Apply styles to buttons from .tscn
	# Set button texts
	btn_charge.text = "攒"
	btn_attack.text = "波"
	btn_big_attack.text = "大波"
	btn_defend.text = "防"
	btn_big_defend.text = "大防"
	btn_special.text = ""
	btn_confirm.text = "结束"
	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]:
		btn.size = Vector2(CIRCLE_D, CIRCLE_D)
		btn.add_theme_stylebox_override("normal", _circle_style_normal.duplicate())
		btn.add_theme_stylebox_override("hover", _circle_style_hover)
		btn.add_theme_stylebox_override("pressed", _circle_style_hover)
		btn.add_theme_stylebox_override("disabled", _circle_style_disabled)
		FontManager.apply_btn(btn, 16)
		btn.clip_text = true
	btn_confirm.size = Vector2(CIRCLE_D, CIRCLE_D)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)
	btn_confirm.add_theme_stylebox_override("hover", _confirm_style_active)
	FontManager.apply_btn(btn_confirm, 16)
	btn_confirm.clip_text = true

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]

	# Style static labels from .tscn
	FontManager.apply(turn_label, 24)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(timer_label, 20)
	timer_label.add_theme_color_override("font_color", Color("#aaccee"))
	FontManager.apply(status_label, 26)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(event_label, 22)
	event_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(big_turn_label, 48)
	big_turn_label.add_theme_color_override("font_color", Color("#f5c518"))
	FontManager.apply(p1_name_label, 20)
	p1_name_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(p2_name_label, 20)
	p2_name_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(p1_hp_label, 28)
	p1_hp_label.add_theme_color_override("font_color", Color("#ff6666"))
	FontManager.apply(p2_hp_label, 28)
	p2_hp_label.add_theme_color_override("font_color", Color("#ff6666"))

	# Style frame HP/shield labels (pre-placed in .tscn)
	for lbl in p1_frame_hp_labels + p2_frame_hp_labels:
		FontManager.apply(lbl, 13)
		lbl.add_theme_color_override("font_color", Color("#ff6666"))
	for lbl in p1_frame_shield_labels + p2_frame_shield_labels:
		FontManager.apply(lbl, 11)
		lbl.add_theme_color_override("font_color", Color("#44ccff"))


func _make_label(text: String, size: int, color: Color, pos: Vector2, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	FontManager.apply(l, size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	parent.add_child(l)
	return l


# --- Frame interaction ---

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
	var active1_before: int = battle.active_hero_index[0]
	var active2_before: int = battle.active_hero_index[1]
	var r: Dictionary = battle.resolve()

	# Detect death — hero_hp at the old active slot is now 0 or below
	var p1_dead: bool = battle.hero_hp[0][active1_before] <= 0
	var p2_dead: bool = battle.hero_hp[1][active2_before] <= 0

	p1_hit = battle.hero_hp[0][active1_before] < hp1_before
	p2_hit = battle.hero_hp[1][active2_before] < hp2_before

	# Play battle animations
	await _play_battle_anims(r.p1_action, r.p2_action, p1_hit, p2_hit, p1_dead, p2_dead)

	var a1_name: String = battle.get_action_name(r.p1_action)
	var a2_name: String = battle.get_action_name(r.p2_action)
	status_label.text = "P1: %s    vs    P2: %s" % [a1_name, a2_name]
	status_label.visible = true

	var txt := ""
	for ev in r.events:
		txt += EventFormatter.format(ev) + "\n"
	event_label.text = txt.strip_edges()
	event_label.visible = true

	_update_all()

	if r.game_over:
		state = State.GAME_OVER
		status_label.text = "游戏结束！"
	else:
		if battle.pending_death_switch[0] > 0:
			await _show_death_switch_selection(0)
		if battle.pending_death_switch[1] > 0:
			await _show_death_switch_selection(1)
		await get_tree().create_timer(1.8).timeout
		_show_turn_intro()

func _show_death_switch_selection(player: int) -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	var pname := "P1" if player == 0 else "P2"
	status_label.text = "%s 英雄阵亡，选择替补英雄" % pname
	status_label.visible = true

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var prompt := Label.new()
	prompt.text = "%s 选择替补英雄" % pname
	FontManager.apply(prompt, 28)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(660, 300)
	prompt.size = Vector2(600, 40)
	overlay.add_child(prompt)

	var living := battle.get_living_reserves(player)
	var card_w := 160
	var card_h := 200
	var gap := 40
	var total_w: float = living.size() * card_w + (living.size() - 1) * gap
	var start_x: float = (1920.0 - total_w) / 2.0
	var card_y: float = 380.0

	# Waiter node — we await its tree_exited signal (fires when overlay is freed)
	var waiter := Node.new()
	waiter.name = "_SwitchWaiter"
	overlay.add_child(waiter)

	for j in range(living.size()):
		var slot: int = living[j]
		var h: HeroData = battle.heroes[player][slot]
		var captured_slot: int = slot

		var card := Button.new()
		card.position = Vector2(start_x + j * (card_w + gap), card_y)
		card.size = Vector2(card_w, card_h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#252540")
		sb.border_color = Color("#4488ff") if player == 0 else Color("#ff4444")
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.set_corner_radius_all(8)
		card.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = Color("#3a3a5a")
		sb_hover.border_color = Color("#ffdd44")
		card.add_theme_stylebox_override("hover", sb_hover)
		overlay.add_child(card)

		if h.portrait_path != "" and ResourceLoader.exists(h.portrait_path):
			var tex: Texture2D = load(h.portrait_path)
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.position = Vector2(10, 10)
			tr.size = Vector2(card_w - 20, card_h - 48)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(tr)

		var name_lbl := Label.new()
		name_lbl.text = h.hero_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, card_h - 36)
		name_lbl.size = Vector2(card_w, 20)
		FontManager.apply(name_lbl, 16)
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "❤ %d" % battle.hero_hp[player][slot]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.position = Vector2(0, card_h - 18)
		hp_lbl.size = Vector2(card_w, 16)
		FontManager.apply(hp_lbl, 13)
		hp_lbl.add_theme_color_override("font_color", Color("#ff6666"))
		hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hp_lbl)

		card.pressed.connect(func():
			battle.execute_death_switch(player, captured_slot)
			overlay.queue_free()
			_update_all()
		)

	await waiter.tree_exited


func _play_battle_anims(a1: int, a2: int, hit1: bool, hit2: bool, dead1: bool = false, dead2: bool = false) -> void:
	var has_action1: bool = a1 in [BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK, BattleCore.Action.DEFEND, BattleCore.Action.BIG_DEFEND]
	var has_action2: bool = a2 in [BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK, BattleCore.Action.DEFEND, BattleCore.Action.BIG_DEFEND]
	_play_action_anim(p1_char_display, a1)
	_play_action_anim(p2_char_display, a2)
	if has_action1 or has_action2:
		await get_tree().create_timer(action_phase_duration).timeout

	# Hide defend shields after action phase
	p1_char_display.show_defend_shield(false)
	p2_char_display.show_defend_shield(false)

	# Defeat animation plays first when a hero dies
	if dead1:
		p1_char_display.play_animation("defeat", false)
		p1_char_display.set_hit_flash(true)
	if dead2:
		p2_char_display.play_animation("defeat", false)
		p2_char_display.set_hit_flash(true)
	if dead1 or dead2:
		await get_tree().create_timer(0.45).timeout
		if dead1:
			p1_char_display.set_hit_flash(false)
		if dead2:
			p2_char_display.set_hit_flash(false)
		if anim_phase_duration > 0.45:
			await get_tree().create_timer(anim_phase_duration - 0.45).timeout

	# Hit animation — skip if dead (already played defeat)
	var clones1: bool = battle.clone_count[0] > 0
	var clones2: bool = battle.clone_count[1] > 0
	if hit1 and not dead1 and not clones1:
		p1_char_display.play_animation("hit")
		p1_char_display.set_hit_flash(true)
	if hit2 and not dead2 and not clones2:
		p2_char_display.play_animation("hit")
		p2_char_display.set_hit_flash(true)
	if (hit1 and not dead1 and not clones1) or (hit2 and not dead2 and not clones2):
		# Flash auto-clears after 0.2 s; animation plays full duration
		await get_tree().create_timer(0.45).timeout
		p1_char_display.set_hit_flash(false)
		p2_char_display.set_hit_flash(false)
		if anim_phase_duration > 0.45:
			await get_tree().create_timer(anim_phase_duration - 0.45).timeout

func _play_action_anim(cd: CharacterDisplay, action: int) -> void:
	match action:
		BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK:
			cd.play_animation("attack")
		BattleCore.Action.DEFEND, BattleCore.Action.BIG_DEFEND:
			cd.show_defend_shield(true)
			cd.play_animation("defend")

func _set_buttons_active(active: bool) -> void:
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = active
		btn.disabled = not active
	if not active:
		btn_special.visible = false
	if active:
		_layout_circles()


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
		buttons[i].position = Vector2(start_x + i * (CIRCLE_D + CIRCLE_GAP), CIRCLE_Y - buttons_ctrl.position.y)
		buttons[i].visible = true
	btn_special.visible = has_skill
	if is_fool:
		for b in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]:
			b.visible = false


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


# ---- Update all ----

func _update_all() -> void:
	turn_label.text = "回合 %d" % (battle.turn_number + 1)
	_update_hero_frames()
	_update_character_displays()
	_update_energy_labels()
	_update_hp_labels()
	_update_hero_names()
	_update_clone_display()
	if state in [State.P1_TURN, State.P2_TURN]:
		_update_button_states()


func _update_character_displays() -> void:
	for p in [0, 1]:
		var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
		var h: HeroData = battle.active_hero(p)
		if h.sprite_frames_path != "":
			cd.sprite_frames_path = h.sprite_frames_path
		else:
			cd.spritesheet_path = h.spritesheet_path
		cd.attack_spritesheet_path = h.attack_spritesheet_path
		cd.hit_spritesheet_path = h.hit_spritesheet_path
		cd.defend_spritesheet_path = h.defend_spritesheet_path
		cd.defeat_spritesheet_path = h.defeat_spritesheet_path


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
		var pcolor := Color("#3388dd") if p == 0 else Color("#dd3333")

		# Slot 0 = active hero (large frame)
		frame_slots[0] = active_idx
		_update_single_frame(frames[0], hp_labels[0], shield_labels[0], p, active_idx, true, pcolor)

		# Slots 1-2 = reserve heroes (small frames)
		for j in range(2):
			var fi := j + 1
			if j < reserves.size():
				var slot: int = reserves[j]
				frame_slots[fi] = slot
				_update_single_frame(frames[fi], hp_labels[fi], shield_labels[fi], p, slot, false, pcolor)
			else:
				frame_slots[fi] = -1
				frames[fi].visible = false
				hp_labels[fi].visible = false
				shield_labels[fi].visible = false


func _update_single_frame(frame: HeroFrame, hp_label: Label, shield_label: Label, player: int, slot: int, is_active: bool, pcolor: Color) -> void:
	if slot < 0 or slot >= battle.heroes[player].size():
		frame.visible = false
		hp_label.visible = false
		shield_label.visible = false
		return

	frame.visible = true
	hp_label.visible = true
	shield_label.visible = true

	var h: HeroData = battle.heroes[player][slot]
	var dead: bool = battle.hero_hp[player][slot] <= 0

	frame.hero_name = h.hero_name
	frame.portrait_path = h.portrait_path
	frame.is_active = is_active
	frame.is_dead = dead
	frame.player_color = pcolor
	frame.frame_size = Vector2(72, 72) if is_active else Vector2(48, 48)

	hp_label.text = "❤%d" % battle.hero_hp[player][slot]
	var hp_ratio := clampf(float(battle.hero_hp[player][slot]) / float(battle.hero_max_hp[player][slot]), 0.0, 1.0)
	hp_label.add_theme_color_override("font_color", _hp_color(hp_ratio))
	hp_label.add_theme_font_size_override("font_size", 13 if is_active else 11)

	var sh: int = battle.shield[player][slot]
	shield_label.text = "🛡%d" % sh if sh > 0 else ""
	shield_label.add_theme_font_size_override("font_size", 11 if is_active else 10)


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
	p1_char_display.visible = not clones1
	p2_char_display.visible = not clones2

	if not clones1:
		var s1: int = battle.shield[0][battle.active_hero_index[0]]
		p1_hp_label.text = "❤%d  🛡%d" % [h1, s1] if s1 > 0 else "❤%d" % h1
		var ratio1 := clampf(float(h1) / float(battle.current_max_hp(0)), 0.0, 1.0)
		p1_hp_label.add_theme_color_override("font_color", _hp_color(ratio1))
	if not clones2:
		var s2: int = battle.shield[1][battle.active_hero_index[1]]
		p2_hp_label.text = "❤%d  🛡%d" % [h2, s2] if s2 > 0 else "❤%d" % h2
		var ratio2 := clampf(float(h2) / float(battle.current_max_hp(1)), 0.0, 1.0)
		p2_hp_label.add_theme_color_override("font_color", _hp_color(ratio2))


func _update_hero_names() -> void:
	p1_name_label.text = battle.active_hero(0).hero_name
	p2_name_label.text = battle.active_hero(1).hero_name


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

		var order: Array = battle.clone_order[player]
		var clone_hps: Array = battle.clone_hp[player]
		var base_color := Color("#3388dd") if player == 0 else Color("#dd3333")
		var n: int = order.size()
		var total_w: float = n * CLONE_W + (n - 1) * CLONE_GAP
		var start_x: float = -total_w / 2.0

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
