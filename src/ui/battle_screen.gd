extends Control

## 1920x1080. Layout now visually editable in battle_screen.tscn.
## HeroFrame + CharacterDisplay instances pre-placed in scene, script configures at runtime.

const MAX_ENERGY := 20
const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0

## P1-5d: UI 坐标常量（避免散落的 1920.0 / 1080.0 魔法数字）
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

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
@onready var p1_clone_area: CloneArea = $P1CloneArea
@onready var p2_clone_area: CloneArea = $P2CloneArea
@onready var _death_switch_overlay: DeathSwitchOverlay = $DeathSwitchOverlay
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
# Stylebox：normal/disabled/hover/pressed 已在 .tscn theme_override_styles 内 set。
# 这里保留 normal/confirm reference 供 runtime 切换 normal ↔ selected 用；
# selected 是逻辑层"用户选中"反馈，非 Button 自带 state，仍 code 构造。
var _circle_style_normal: StyleBoxFlat
var _circle_style_selected: StyleBoxFlat
var _confirm_style: StyleBoxFlat
var _confirm_style_active: StyleBoxFlat

# Energy bars (P1-5g 抽组件)
@onready var p1_energy_bar: EnergyBar = $P1EnergyBar
@onready var p2_energy_bar: EnergyBar = $P2EnergyBar

# Clone display (P1-5c: CloneArea 组件接管 slot/label/event)
var _clone_target: int = -1

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
	_init_clone_rects()
	_init_buttons()
	game_timer.timeout.connect(_on_timer_tick)
	_update_all()
	_show_turn_intro()


func _init_styles() -> void:
	# Stylebox 主要在 battle_screen.tscn 内 set（CircleNormal/Hover/Disabled,
	# ConfirmNormal/Active SubResource）。这里只:
	#   1. 取 normal/confirm reference 供 runtime 切换 normal ↔ selected 用
	#   2. 构造 selected style（逻辑层反馈，非 Button 自带 state）
	_circle_style_normal = btn_charge.get_theme_stylebox("normal") as StyleBoxFlat
	_confirm_style = btn_confirm.get_theme_stylebox("normal") as StyleBoxFlat
	_confirm_style_active = btn_confirm.get_theme_stylebox("hover") as StyleBoxFlat

	_circle_style_selected = StyleBoxFlat.new()
	_circle_style_selected.bg_color = Color("#3a3a5a")
	_circle_style_selected.border_color = Color("#ffdd44")
	_circle_style_selected.border_width_left = 5
	_circle_style_selected.border_width_right = 5
	_circle_style_selected.border_width_top = 5
	_circle_style_selected.border_width_bottom = 5
	_circle_style_selected.set_corner_radius_all(int(CIRCLE_D / 2.0))


# ---- Dynamic UI construction ----

func _connect_frame_signals() -> void:
	for i in range(3):
		p1_frames[i].gui_input.connect(_on_frame_gui_input.bind(0, i))
		p2_frames[i].gui_input.connect(_on_frame_gui_input.bind(1, i))


func _init_clone_rects() -> void:
	# P1-5c: CloneArea 内部已有 slot/label 节点；这里只 connect target_clicked signal
	p1_clone_area.target_clicked.connect(func(display_pos: int) -> void: _on_clone_target_clicked(0, display_pos))
	p2_clone_area.target_clicked.connect(func(display_pos: int) -> void: _on_clone_target_clicked(1, display_pos))


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
	# stylebox 已在 .tscn theme_override_styles set (P1-5a)；这里只 set size/font/clip
	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]:
		btn.size = Vector2(CIRCLE_D, CIRCLE_D)
		FontManager.apply_btn(btn, 16)
		btn.clip_text = true
	btn_confirm.size = Vector2(CIRCLE_D, CIRCLE_D)
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

	# P1-5b: 浮窗逻辑搬到 DeathSwitchOverlay 组件，这里只准备数据 + await selection
	var reserves: Array = []
	for slot in battle.get_living_reserves(player):
		reserves.append([slot, battle.heroes[player][slot], battle.hero_hp[player][slot]])

	_death_switch_overlay.show_selection(player, reserves)
	var selected_slot: int = await _death_switch_overlay.selection_made
	battle.execute_death_switch(player, selected_slot)
	_update_all()


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
	var start_x := (SCREEN_W - total_w) / 2.0

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
	p1_energy_bar.set_energy(battle.energy[0])
	p2_energy_bar.set_energy(battle.energy[1])


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
		var area: CloneArea = p1_clone_area if player == 0 else p2_clone_area
		var cnt: int = battle.clone_count[player]
		if cnt == 0:
			area.set_state([], [], 0)
		else:
			area.set_state(battle.clone_order[player], battle.clone_hp[player], battle.current_hp(player))
	_update_clone_target_highlight()


func _update_clone_target_highlight() -> void:
	var current: int = 0 if state == State.P1_TURN else 1
	var opp: int = 1 - current
	var is_attack := selected_action in [BattleCore.Action.ATTACK, BattleCore.Action.BIG_ATTACK]
	var show_targets := is_attack and battle.clone_count[opp] > 0
	p1_clone_area.set_target_mode(show_targets and current == 1)
	p2_clone_area.set_target_mode(show_targets and current == 0)
	if not show_targets:
		_clone_target = -1


func _on_clone_target_clicked(area_player: int, display_pos: int) -> void:
	var current: int = 0 if state == State.P1_TURN else 1
	var opp: int = 1 - current
	if area_player != opp:
		return
	if battle.clone_count[area_player] == 0:
		return
	_clone_target = display_pos
	battle.select_attack_target(current, display_pos)
	var pname := "P1" if state == State.P1_TURN else "P2"
	status_label.text = "%s - 已选攻击目标 #%d" % [pname, display_pos + 1]
