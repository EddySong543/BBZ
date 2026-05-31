extends Control

## 1920x1080. 布局在 battle_screen.tscn 可视化编辑（保留，勿动节点）。
## v4 引擎（BattleCore）+ 同时盲选 vs AI（决策 B1）。
## 你 = P0（下），对手 = P1（上，AI）。玩家选动作 → 确认 → AI 后台选 → 同时结算。
##
## 半点制：HP/护盾内部为半点，显示用 battle.hp_display()。

const A := ActionDef.Action
const ACTIVE := ActionDef.ACTIVE

const CIRCLE_D := 160.0
const CIRCLE_GAP := 60.0
const CIRCLE_Y := 890.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

## 默认阵容 fallback：直接打开 battle_screen.tscn(F6) 测试用，BattleSetup 为空时启用。
const HERO_DATA_DIR := "res://assets/data/heroes/"
const DEFAULT_P0 := ["h01", "h05", "h13"]   # 窃运 / 天威 / 孤注（均有美术 h01-h17）
const DEFAULT_P1 := ["h02", "h09", "h16"]   # 怒目 / 凶兽 / 泽被苍生（均有美术）

## 各动画相位等待（秒），可在 Inspector 调。
@export var anim_phase_duration: float = 1.0
@export var action_phase_duration: float = 0.6
@export var turn_time_limit: int = 5   # 每回合思考时限（秒），归零自动结算；可在 Inspector 调

enum State { TURN_INTRO, PLAYER_SELECT, RESOLVING, HERO_SELECT, GAME_OVER }

var battle: BattleCore
var state: int = State.TURN_INTRO
var timer_seconds: int = 0

const PLAYER := 0   # 本地玩家固定 P0
const AI := 1       # 对手 AI

# ---- @onready: battle_screen.tscn 内预置节点（布局保留，路径勿改）----
@onready var p1_name_label: Label = $P1Name
@onready var p2_name_label: Label = $P2Name
@onready var p1_hp_label: Label = $P1HP
@onready var p2_hp_label: Label = $P2HP
@onready var turn_label: Label = $TurnLabel
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var event_label: Label = $EventLabel
@onready var big_turn_label: Label = $BigTurnLabel

@onready var p1_char_display: CharacterDisplay = $P1CharDisplay
@onready var p2_char_display: CharacterDisplay = $P2CharDisplay

@onready var p1_frames: Array[HeroFrame] = [$P1Frame0, $P1Frame1, $P1Frame2]
@onready var p2_frames: Array[HeroFrame] = [$P2Frame0, $P2Frame1, $P2Frame2]
@onready var p1_frame_hp_labels: Array[Label] = [$P1Frame0Hp, $P1Frame1Hp, $P1Frame2Hp]
@onready var p2_frame_hp_labels: Array[Label] = [$P2Frame0Hp, $P2Frame1Hp, $P2Frame2Hp]
@onready var p1_frame_shield_labels: Array[Label] = [$P1Frame0Shield, $P1Frame1Shield, $P1Frame2Shield]
@onready var p2_frame_shield_labels: Array[Label] = [$P2Frame0Shield, $P2Frame1Shield, $P2Frame2Shield]
var p1_frame_slots: Array[int] = [-1, -1, -1]
var p2_frame_slots: Array[int] = [-1, -1, -1]

@onready var buttons_ctrl: Control = $Buttons
@onready var _death_switch_overlay: DeathSwitchOverlay = $DeathSwitchOverlay
@onready var game_timer: Timer = $GameTimer

@onready var btn_charge: Button = $Buttons/BtnCharge
@onready var btn_attack: Button = $Buttons/BtnAttack
@onready var btn_big_attack: Button = $Buttons/BtnBigAttack
@onready var btn_defend: Button = $Buttons/BtnDefend
@onready var btn_big_defend: Button = $Buttons/BtnBigDefend
@onready var btn_special: Button = $Buttons/BtnSpecial
@onready var btn_confirm: Button = $Buttons/BtnConfirm

@onready var p1_energy_bar: EnergyBar = $P1EnergyBar
@onready var p2_energy_bar: EnergyBar = $P2EnergyBar

# ---- 选择 / 样式 ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_switch: int = -1
var selected_btn: Button = null

var _circle_style_normal: StyleBoxFlat
var _circle_style_selected: StyleBoxFlat
var _confirm_style: StyleBoxFlat
var _confirm_style_active: StyleBoxFlat

# ---- juice ----
var _shake := 0.0
var _cd_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 立绘原位（前冲 juice 复位用）


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	battle = BattleCore.new()
	var p0: Array = _resolve_team(BattleSetup.p1_heroes, DEFAULT_P0)
	var p1: Array = _resolve_team(BattleSetup.p2_heroes, DEFAULT_P1)
	battle.setup(p0, p1, randi())

	_init_styles()
	_init_buttons()
	_connect_frame_signals()
	game_timer.timeout.connect(_on_timer_tick)

	# P2（对手）立绘 + 头像朝左（面向中间）；记录立绘原位供前冲 juice 复位
	_cd_home[0] = p1_char_display.position
	_cd_home[1] = p2_char_display.position
	p2_char_display.flip_h = true
	for f in p2_frames:
		f.flip_h = true

	_update_all()
	_show_turn_intro()


## BattleSetup 有阵容就用，否则用默认（直接跑 battle_screen.tscn 测试）。
func _resolve_team(setup_heroes: Array, fallback_ids: Array) -> Array:
	if setup_heroes != null and not setup_heroes.is_empty():
		return setup_heroes
	var t: Array = []
	for id in fallback_ids:
		var path: String = HERO_DATA_DIR + str(id) + ".tres"
		if ResourceLoader.exists(path):
			t.append(load(path))
		else:
			var h := HeroData.new()
			h.hero_id = id
			h.hero_name = id
			h.max_hp = 5
			t.append(h)
	return t


func _init_styles() -> void:
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


func _init_buttons() -> void:
	btn_charge.pressed.connect(_on_circle_pressed.bind(A.CHARGE, btn_charge))
	btn_attack.pressed.connect(_on_circle_pressed.bind(A.ATTACK, btn_attack))
	btn_big_attack.pressed.connect(_on_circle_pressed.bind(A.BIG_ATTACK, btn_big_attack))
	btn_defend.pressed.connect(_on_circle_pressed.bind(A.DEFEND, btn_defend))
	btn_big_defend.pressed.connect(_on_circle_pressed.bind(A.BIG_DEFEND, btn_big_defend))
	btn_special.pressed.connect(_on_circle_pressed.bind(ACTIVE, btn_special))
	btn_confirm.pressed.connect(_on_confirm_pressed)

	btn_charge.text = "攒"
	btn_attack.text = "波"
	btn_big_attack.text = "大波"
	btn_defend.text = "防"
	btn_big_defend.text = "大防"
	btn_special.text = "技能"
	btn_confirm.text = "结束"

	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]:
		btn.size = Vector2(CIRCLE_D, CIRCLE_D)
		FontManager.apply_btn(btn, 16)
		btn.clip_text = true
	btn_confirm.size = Vector2(CIRCLE_D, CIRCLE_D)
	FontManager.apply_btn(btn_confirm, 16)
	btn_confirm.clip_text = true

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]

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

	for lbl in p1_frame_hp_labels + p2_frame_hp_labels:
		FontManager.apply(lbl, 13)
		lbl.add_theme_color_override("font_color", Color("#ff6666"))
	for lbl in p1_frame_shield_labels + p2_frame_shield_labels:
		FontManager.apply(lbl, 11)
		lbl.add_theme_color_override("font_color", Color("#44ccff"))


func _connect_frame_signals() -> void:
	for i in range(3):
		p1_frames[i].gui_input.connect(_on_frame_gui_input.bind(PLAYER, i))


# ============================================================
# 回合流程（同时盲选）
# ============================================================

func _show_turn_intro() -> void:
	state = State.TURN_INTRO
	_set_buttons_active(false)
	status_label.visible = false
	event_label.visible = false
	timer_label.text = ""

	big_turn_label.text = "回合 %d" % (battle.turn_number + 1)
	big_turn_label.visible = true
	await get_tree().create_timer(1.0).timeout
	big_turn_label.visible = false
	_start_player_select()


func _start_player_select() -> void:
	state = State.PLAYER_SELECT
	selected_action = -1
	selected_switch = -1
	selected_btn = null
	status_label.text = "选择你的动作"
	status_label.visible = true
	event_label.visible = false
	_set_buttons_active(true)
	_update_all()
	_start_timer()


func _start_timer() -> void:
	timer_seconds = turn_time_limit
	_update_timer_label()
	game_timer.start(1.0)


func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	if timer_seconds <= 0:
		game_timer.stop()
		if state == State.PLAYER_SELECT:
			_on_confirm_pressed()


func _update_timer_label() -> void:
	timer_label.text = "⏱ %d" % maxi(timer_seconds, 0)
	timer_label.add_theme_color_override("font_color", Color("#ff6666") if timer_seconds <= 5 else Color("#aaccee"))


func _on_circle_pressed(action: int, btn: Button) -> void:
	if state != State.PLAYER_SELECT:
		return
	if action == ACTIVE and not battle.can_use_active(PLAYER):
		return

	# 再点同一个 = 取消
	if selected_btn == btn:
		selected_action = -1
		selected_switch = -1
		selected_btn = null
		_reset_button_styles()
		_update_button_states()
		return

	selected_action = action
	selected_switch = -1
	_reset_button_styles()
	selected_btn = btn
	btn.add_theme_stylebox_override("normal", _circle_style_selected)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style_active)


func _on_confirm_pressed() -> void:
	if state != State.PLAYER_SELECT:
		return
	game_timer.stop()

	# 玩家提交（未选 → 默认攒）
	if selected_action == ACTIVE:
		battle.select_active(PLAYER)
	elif selected_action == A.SWITCH and selected_switch >= 0:
		battle.select_switch(PLAYER, selected_switch)
	elif selected_action >= 0:
		battle.select_action(PLAYER, selected_action)
	else:
		battle.select_action(PLAYER, A.CHARGE)

	# AI 选择
	_ai_pick(AI)

	selected_action = -1
	selected_switch = -1
	selected_btn = null
	_reset_button_styles()
	await _resolve()


func _ai_pick(side: int) -> void:
	var opts: Array[int] = [A.CHARGE, A.CHARGE, A.DEFEND]
	if battle.can_afford(side, A.ATTACK):
		opts.append(A.ATTACK)
		opts.append(A.ATTACK)
	if battle.can_afford(side, A.BIG_ATTACK):
		opts.append(A.BIG_ATTACK)
	if battle.can_afford(side, A.BIG_DEFEND):
		opts.append(A.BIG_DEFEND)
	var pick: int = opts[randi() % opts.size()]
	battle.select_action(side, pick)   # 被禁/付不起则引擎 resolve guard 兜底为攒


func _resolve() -> void:
	state = State.RESOLVING
	_set_buttons_active(false)
	timer_label.text = ""

	var a0_before: int = battle.active_index[0]
	var a1_before: int = battle.active_index[1]

	var r: Dictionary = battle.resolve()

	# 死亡判定：结算前的出战槽 HP 归零
	var p0_dead: bool = battle.hp[0][a0_before] <= 0
	var p1_dead: bool = battle.hp[1][a1_before] <= 0
	# 受伤量（半点）从 events 累加，准确（不受甲时机换人影响）
	var dmg: Array[int] = [0, 0]
	for ev in r.get("events", []):
		if ev.get("id", "") == "damage_taken":
			dmg[int(ev.get("player", 0))] += int(ev.get("amount", 0))

	await _play_battle_anims(r.get("p1_action", -1), r.get("p2_action", -1), dmg, [p0_dead, p1_dead])
	_show_events(r)
	_update_all()

	if r.get("game_over", false):
		state = State.GAME_OVER
		var w: int = r.get("winner", BattleCore.WINNER_UNDECIDED)
		status_label.text = "游戏结束！" + ("平局" if w == BattleCore.WINNER_DRAW else ("你胜利！" if w == BattleCore.WINNER_P1 else "你失败"))
		status_label.visible = true
		return

	# AI 死亡换人：自动选第一个存活替补
	if battle.pending_death_switch[AI]:
		var ai_reserves: Array[int] = battle.living_reserves(AI)
		if ai_reserves.size() > 0:
			battle.execute_death_switch(AI, ai_reserves[0])
		_update_all()

	# 玩家死亡换人：弹浮窗
	if battle.pending_death_switch[PLAYER]:
		await _show_death_switch_selection(PLAYER)

	await get_tree().create_timer(maxf(0.1, anim_phase_duration * 0.5)).timeout
	_show_turn_intro()


func _show_death_switch_selection(player: int) -> void:
	state = State.HERO_SELECT
	_set_buttons_active(false)
	status_label.text = "英雄阵亡，选择替补上场"
	status_label.visible = true

	var reserves: Array = []
	for slot in battle.living_reserves(player):
		reserves.append([slot, battle.heroes[player][slot], battle.hp_display(battle.hp[player][slot])])

	_death_switch_overlay.show_selection(player, reserves)
	var selected_slot: int = await _death_switch_overlay.selection_made
	battle.execute_death_switch(player, selected_slot)
	_update_all()


# ============================================================
# 英雄框交互（切换 / h07 免费切）
# ============================================================

func _on_frame_gui_input(event: InputEvent, player: int, frame_idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_on_frame_clicked(player, frame_idx)


func _on_frame_clicked(player: int, frame_idx: int) -> void:
	if state != State.PLAYER_SELECT or player != PLAYER:
		return
	if frame_idx == 0:
		return  # slot 0 = 当前出战，不可切自己

	var frame_slots: Array[int] = p1_frame_slots if player == 0 else p2_frame_slots
	if frame_idx >= frame_slots.size():
		return
	var hero_slot: int = frame_slots[frame_idx]
	if hero_slot < 0 or hero_slot == battle.active_index[player]:
		return
	if battle.hp[player][hero_slot] <= 0:
		return

	# h07 当先：可免费切 → 立即换人（不占动作，本回合继续行动）
	if battle.can_free_switch(player):
		if battle.free_switch(player, hero_slot):
			status_label.text = "当先！免费换上 %s，继续行动" % battle.active_hero(player).hero_name
			selected_action = -1
			selected_switch = -1
			selected_btn = null
			_reset_button_styles()
			_update_all()
		return

	# 普通切换 = 占动作槽，待确认
	selected_action = A.SWITCH
	selected_switch = hero_slot
	selected_btn = null
	_reset_button_styles()
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style_active)
	status_label.text = "切换 → %s（按结束确认）" % battle.heroes[player][hero_slot].hero_name


# ============================================================
# 按钮布局 / 状态
# ============================================================

func _set_buttons_active(active: bool) -> void:
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = active
		btn.disabled = not active
	if active:
		_layout_circles()
		_update_button_states()


func _layout_circles() -> void:
	var has_active: bool = _player_has_active()
	var buttons: Array[Button] = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]
	if has_active:
		buttons.append(btn_special)
		btn_special.text = battle.active_hero(PLAYER).skill_description
	buttons.append(btn_confirm)

	btn_special.visible = has_active

	var n := buttons.size()
	var total_w := n * CIRCLE_D + (n - 1) * CIRCLE_GAP
	var start_x := (SCREEN_W - total_w) / 2.0
	for i in range(n):
		buttons[i].position = Vector2(start_x + i * (CIRCLE_D + CIRCLE_GAP), CIRCLE_Y - buttons_ctrl.position.y)
		buttons[i].visible = true


## 出战英雄是否有主动技（访问 _skills，下划线约定但可读）。
func _player_has_active() -> bool:
	var sk: HeroSkill = battle._skills[PLAYER][battle.active_index[PLAYER]]
	return sk != null and sk.has_active()


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		btn.add_theme_stylebox_override("normal", _circle_style_normal)
	btn_confirm.add_theme_stylebox_override("normal", _confirm_style)


func _update_button_states() -> void:
	if state != State.PLAYER_SELECT:
		return
	_layout_circles()
	for btn in action_btn_list:
		if not btn.visible:
			continue
		if btn == btn_special:
			btn.disabled = not battle.can_use_active(PLAYER)
		else:
			var act: int = _btn_action(btn)
			btn.disabled = battle.is_action_disabled(PLAYER, act) or not battle.can_afford(PLAYER, act)
	btn_confirm.disabled = false


func _btn_action(btn: Button) -> int:
	if btn == btn_charge: return A.CHARGE
	if btn == btn_attack: return A.ATTACK
	if btn == btn_big_attack: return A.BIG_ATTACK
	if btn == btn_defend: return A.DEFEND
	if btn == btn_big_defend: return A.BIG_DEFEND
	return -1


# ============================================================
# 刷新显示
# ============================================================

func _update_all() -> void:
	turn_label.text = "回合 %d" % (battle.turn_number + 1)
	_update_hero_frames()
	_update_character_displays()
	_update_energy_labels()
	_update_hp_labels()
	_update_hero_names()
	if state == State.PLAYER_SELECT:
		_update_button_states()


func _update_character_displays() -> void:
	for p in [0, 1]:
		var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
		cd.modulate = Color.WHITE  # 复位（死亡变暗 / 防御蓝闪 / 攒黄闪）
		var h: HeroData = battle.active_hero(p)
		if h.sprite_frames_path != "":
			cd.sprite_frames_path = h.sprite_frames_path
		elif h.spritesheet_path != "":
			cd.spritesheet_path = h.spritesheet_path
		# A 方案：v4 数据无 attack/hit/defeat 帧，攻击靠 juice；仍喂（多为空，组件 fallback）。
		cd.attack_spritesheet_path = h.attack_spritesheet_path
		cd.hit_spritesheet_path = h.hit_spritesheet_path
		cd.defend_spritesheet_path = h.defend_spritesheet_path
		cd.defeat_spritesheet_path = h.defeat_spritesheet_path


func _get_reserve_slots(player: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(battle.heroes[player].size()):
		if i != battle.active_index[player]:
			result.append(i)
	return result


func _update_hero_frames() -> void:
	for p in [0, 1]:
		var frames := p1_frames if p == 0 else p2_frames
		var hp_labels := p1_frame_hp_labels if p == 0 else p2_frame_hp_labels
		var shield_labels := p1_frame_shield_labels if p == 0 else p2_frame_shield_labels
		var frame_slots: Array[int] = p1_frame_slots if p == 0 else p2_frame_slots
		var active_idx: int = battle.active_index[p]
		var reserves := _get_reserve_slots(p)
		var pcolor := Color("#3388dd") if p == 0 else Color("#dd3333")

		frame_slots[0] = active_idx
		_update_single_frame(frames[0], hp_labels[0], shield_labels[0], p, active_idx, true, pcolor)

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
	var dead: bool = battle.hp[player][slot] <= 0

	frame.hero_name = h.hero_name
	frame.portrait_path = h.portrait_path
	frame.is_active = is_active
	frame.is_dead = dead
	frame.player_color = pcolor
	frame.frame_size = Vector2(72, 72) if is_active else Vector2(48, 48)

	var hp_now := battle.hp_display(battle.hp[player][slot])
	var hp_max := battle.hp_display(battle.max_hp[player][slot])
	hp_label.text = "❤%s" % _fmt_hp(hp_now)
	var hp_ratio := clampf(hp_now / maxf(hp_max, 0.01), 0.0, 1.0)
	hp_label.add_theme_color_override("font_color", _hp_color(hp_ratio))
	hp_label.add_theme_font_size_override("font_size", 13 if is_active else 11)

	var sh := battle.hp_display(battle.shield[player][slot])
	shield_label.text = "🛡%s" % _fmt_hp(sh) if sh > 0 else ""
	shield_label.add_theme_font_size_override("font_size", 11 if is_active else 10)


func _update_energy_labels() -> void:
	p1_energy_bar.set_energy(battle.energy[0])
	p2_energy_bar.set_energy(battle.energy[1])


func _update_hp_labels() -> void:
	p1_char_display.visible = true
	p2_char_display.visible = true
	for p in [0, 1]:
		var lbl: Label = p1_hp_label if p == 0 else p2_hp_label
		var hp_now := battle.hp_display(battle.current_hp(p))
		var sh := battle.hp_display(battle.shield[p][battle.active_index[p]])
		lbl.text = "❤%s  🛡%s" % [_fmt_hp(hp_now), _fmt_hp(sh)] if sh > 0 else "❤%s" % _fmt_hp(hp_now)
		var ratio := clampf(hp_now / maxf(battle.hp_display(battle.current_max_hp(p)), 0.01), 0.0, 1.0)
		lbl.add_theme_color_override("font_color", _hp_color(ratio))


func _update_hero_names() -> void:
	p1_name_label.text = battle.active_hero(0).hero_name
	p2_name_label.text = battle.active_hero(1).hero_name


func _fmt_hp(v: float) -> String:
	v = maxf(v, 0.0)
	if is_equal_approx(v, roundf(v)):
		return "%d" % int(roundf(v))
	return "%.1f" % v


func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color("#44cc44")
	elif ratio > 0.3:
		return Color("#ffaa00")
	return Color("#ff4444")


# ============================================================
# 动画 / juice
# ============================================================

## A 方案 juice：出招（攻击前冲 / 防御蓝闪沉身 / 攒上浮黄闪）→ 命中（白闪 + 斩击光
## + 伤害数字 + 震屏）。dmg/dead 为 [p0, p1]。无逐帧 attack/hit 动画，全靠代码表现。
func _play_battle_anims(a0: int, a1: int, dmg: Array, dead: Array) -> void:
	_act_juice(0, a0)
	_act_juice(1, a1)
	await get_tree().create_timer(action_phase_duration * 0.45).timeout

	var any := false
	if int(dmg[1]) > 0 or bool(dead[1]):
		_impact(1, int(dmg[1]))
		any = true
	if int(dmg[0]) > 0 or bool(dead[0]):
		_impact(0, int(dmg[0]))
		any = true
	if any:
		_shake = 12.0 if (a0 == A.BIG_ATTACK or a1 == A.BIG_ATTACK) else 7.0
	if bool(dead[0]):
		p1_char_display.modulate = Color(0.35, 0.35, 0.35)
	if bool(dead[1]):
		p2_char_display.modulate = Color(0.35, 0.35, 0.35)

	await get_tree().create_timer(action_phase_duration).timeout


func _cd(player: int) -> CharacterDisplay:
	return p1_char_display if player == 0 else p2_char_display


## 出招 juice。攻击=蓄力前冲复位；防御=蓝闪沉身；攒=上浮黄闪。
func _act_juice(player: int, action: int) -> void:
	var cd := _cd(player)
	var home: Vector2 = _cd_home[player]
	var dir := 1.0 if player == 0 else -1.0
	match action:
		A.ATTACK, A.BIG_ATTACK:
			var reach := 190.0 if action == A.BIG_ATTACK else 140.0
			var tw := create_tween()
			tw.tween_property(cd, "position", home + Vector2(-28.0 * dir, 0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(cd, "position", home + Vector2(reach * dir, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(cd, "position", home, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		A.DEFEND, A.BIG_DEFEND:
			var glow := Color(0.55, 0.8, 1.4) if action == A.BIG_DEFEND else Color(0.7, 0.85, 1.2)
			var tw := create_tween()
			tw.tween_property(cd, "modulate", glow, 0.1)
			tw.tween_property(cd, "modulate", Color.WHITE, 0.35)
			var tw2 := create_tween()
			tw2.tween_property(cd, "position", home + Vector2(0, 10), 0.1)
			tw2.tween_property(cd, "position", home, 0.3).set_trans(Tween.TRANS_SINE)
		A.CHARGE:
			var tw := create_tween()
			tw.tween_property(cd, "position", home + Vector2(0, -16), 0.15).set_trans(Tween.TRANS_SINE)
			tw.tween_property(cd, "position", home, 0.28).set_trans(Tween.TRANS_SINE)
			var tw2 := create_tween()
			tw2.tween_property(cd, "modulate", Color(1.35, 1.25, 0.6), 0.12)
			tw2.tween_property(cd, "modulate", Color.WHITE, 0.32)


## 命中表现：白闪 + 斩击弧光 + 伤害数字。
func _impact(target_player: int, dmg_half: int) -> void:
	var cd := _cd(target_player)
	cd.flash_white(0.18)
	_spawn_slash(target_player)
	if dmg_half > 0:
		_pop_damage(target_player, float(dmg_half) / 2.0)


func _spawn_slash(target_player: int) -> void:
	var cd := _cd(target_player)
	var slash := SlashVFX.new()
	var s := 2.0
	slash.scale = Vector2(-s, s) if target_player == 0 else Vector2(s, s)  # 打左侧的镜像
	slash.global_position = cd.global_position + cd.size * 0.5
	slash.z_index = 60
	add_child(slash)
	slash.play()


func _pop_damage(player: int, amount: float) -> void:
	var cd: CharacterDisplay = p1_char_display if player == 0 else p2_char_display
	var lbl := Label.new()
	lbl.text = "-%s" % _fmt_hp(amount)
	FontManager.apply(lbl, 44)
	lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.global_position = cd.global_position + Vector2(20, -40)
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector2(0, -80), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.2)
	get_tree().create_timer(0.85).timeout.connect(lbl.queue_free)


func _process(delta: float) -> void:
	if _shake > 0.0:
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - 40.0 * delta)
		if _shake <= 0.0:
			position = Vector2.ZERO


# ============================================================
# 事件文案（v4，内联；S3 转正时考虑抽出 EventFormatter）
# ============================================================

func _show_events(r: Dictionary) -> void:
	var a0_name := _action_name(r.get("p1_action", -1))
	var a1_name := _action_name(r.get("p2_action", -1))
	status_label.text = "你：%s    vs    对手：%s" % [a0_name, a1_name]
	status_label.visible = true

	var lines: Array[String] = []
	for ev in r.get("events", []):
		var t := _event_text(ev)
		if t != "":
			lines.append(t)
	event_label.text = "\n".join(lines)
	event_label.visible = true


func _action_name(act: int) -> String:
	match act:
		A.CHARGE: return "攒"
		A.ATTACK: return "波"
		A.DEFEND: return "防"
		A.BIG_ATTACK: return "大波"
		A.BIG_DEFEND: return "大防"
		A.SWITCH: return "切换"
		ACTIVE: return "技能"
	return "?"


func _event_text(ev: Dictionary) -> String:
	var p: int = ev.get("player", -1)
	var who := "你" if p == 0 else "对手"
	var amt := float(ev.get("amount", 0)) / 2.0
	match ev.get("id", ""):
		"damage_taken": return "%s 受 %s 伤害" % [who, _fmt_hp(amt)]
		"deferred_damage": return "%s 延迟伤害 %s" % [who, _fmt_hp(amt)]
		"big_defend_block", "defend_block": return "%s 格挡" % who
		"shield_absorb": return "%s 护盾吸收 %s" % [who, _fmt_hp(amt)]
		"charge_gain": return "%s 攒能量 +%d" % [who, ev.get("amount", 0)]
		"active_used": return "%s 发动技能" % who
		"vulnerable": return "%s 易伤" % who
		"switch": return "%s 切换" % who
		"hero_died": return "%s 一名英雄阵亡" % who
		"victory", "draw": return "胜负已分"
	return ""
