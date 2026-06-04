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

## 待选爱心垂直对齐基线带高度（= 自适应 pip 的上限），不同 maxHP 的爱心在其中居中（任务6）。
const HEART_BAND := 16.0
## 出战血条低血红闪阈值（HP 占比 ≤ 此值）；闪烁在 IconPipRow 内部实现（任务5：红光改到剩余血量爱心上）。
const LOW_HP_RATIO := 0.3

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
@onready var turn_label: Label = $TurnLabel
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = $StatusLabel
@onready var event_label: Label = $EventLabel
@onready var big_turn_label: Label = $BigTurnLabel

@onready var p1_char_display: CharacterDisplay = $P1CharDisplay
@onready var p2_char_display: CharacterDisplay = $P2CharDisplay
@onready var p1_shadow: TextureRect = $P1Shadow
@onready var p2_shadow: TextureRect = $P2Shadow

@onready var p1_frames: Array[HeroFrame] = [$P1Frame0, $P1Frame1, $P1Frame2]
@onready var p2_frames: Array[HeroFrame] = [$P2Frame0, $P2Frame1, $P2Frame2]
@onready var p1_frame_hp_labels: Array[Label] = [$P1Frame0Hp, $P1Frame1Hp, $P1Frame2Hp]
@onready var p2_frame_hp_labels: Array[Label] = [$P2Frame0Hp, $P2Frame1Hp, $P2Frame2Hp]
@onready var p1_frame_shield_labels: Array[Label] = [$P1Frame0Shield, $P1Frame1Shield, $P1Frame2Shield]
@onready var p2_frame_shield_labels: Array[Label] = [$P2Frame0Shield, $P2Frame1Shield, $P2Frame2Shield]
# 待选英雄头像下的心形标记（美术资产，替代旧 ❤ 文字）。index 0 = 出战位 → null（出战血量看大心条）。
@onready var p1_frame_heart_icons: Array = [null, $P1Frame1Heart, $P1Frame2Heart]
@onready var p2_frame_heart_icons: Array = [null, $P2Frame1Heart, $P2Frame2Heart]
var p1_frame_slots: Array[int] = [-1, -1, -1]
var p2_frame_slots: Array[int] = [-1, -1, -1]

# ---- 技能展示格：顺序浏览 [己方0,1,2 → 对方0,1,2]，点击翻页 ----
var _skill_entries: Array = []   # [[player, slot], ...]
var _skill_index: int = 0

@onready var buttons_ctrl: Control = $Buttons
@onready var skill_card: SkillCard = $SkillCard
@onready var _death_switch_overlay: DeathSwitchOverlay = $DeathSwitchOverlay
@onready var game_timer: Timer = $GameTimer

@onready var btn_charge: Button = $Buttons/BtnCharge
@onready var btn_attack: Button = $Buttons/BtnAttack
@onready var btn_big_attack: Button = $Buttons/BtnBigAttack
@onready var btn_defend: Button = $Buttons/BtnDefend
@onready var btn_big_defend: Button = $Buttons/BtnBigDefend
@onready var btn_special: Button = $Buttons/BtnSpecial
@onready var btn_confirm: Button = $Buttons/BtnConfirm

# 新美术 HUD：心形血珠 + 金币能量点（替换旧 EnergyBar / ArcHealthBar）。
@onready var p1_heart_row: IconPipRow = $P1HeartRow
@onready var p2_heart_row: IconPipRow = $P2HeartRow
@onready var p1_coin_row: IconPipRow = $P1CoinRow
@onready var p2_coin_row: IconPipRow = $P2CoinRow

# ---- 选择 / 样式 ----
var action_btn_list: Array[Button] = []
var selected_action: int = -1
var selected_switch: int = -1
var selected_btn: Button = null

# ---- juice ----
var _shake := 0.0
var _cd_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 立绘原位（前冲 juice 复位用）
var _shadow_home: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]  # 阴影原位（跟随角色水平位移用）


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	battle = BattleCore.new()
	var p0: Array = _resolve_team(BattleSetup.p1_heroes, DEFAULT_P0)
	var p1: Array = _resolve_team(BattleSetup.p2_heroes, DEFAULT_P1)
	BattleSetup.reset()   # 消费即清空：防止下一局（未经 BP）复用本局阵容
	battle.setup(p0, p1, randi())

	_init_buttons()
	_connect_frame_signals()
	game_timer.timeout.connect(_on_timer_tick)

	# P2（对手）立绘 + 头像朝左（面向中间）；记录立绘原位供前冲 juice 复位
	_cd_home[0] = p1_char_display.position
	_cd_home[1] = p2_char_display.position
	_shadow_home[0] = p1_shadow.position
	_shadow_home[1] = p2_shadow.position
	p2_char_display.flip_h = true
	for f in p2_frames:
		f.flip_h = true

	_build_skill_entries()
	skill_card.advance_requested.connect(_on_skill_card_advance)
	_refresh_skill_card()

	# 低血红闪（任务5）：出战血条剩余爱心在 HP 占比低时红色呼吸（IconPipRow 内部实现）。
	for row in [p1_heart_row, p2_heart_row]:
		row.low_hp_flash = true
		row.low_hp_ratio = LOW_HP_RATIO

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


func _init_buttons() -> void:
	btn_charge.pressed.connect(_on_circle_pressed.bind(A.CHARGE, btn_charge))
	btn_attack.pressed.connect(_on_circle_pressed.bind(A.ATTACK, btn_attack))
	btn_big_attack.pressed.connect(_on_circle_pressed.bind(A.BIG_ATTACK, btn_big_attack))
	btn_defend.pressed.connect(_on_circle_pressed.bind(A.DEFEND, btn_defend))
	btn_big_defend.pressed.connect(_on_circle_pressed.bind(A.BIG_DEFEND, btn_big_defend))
	btn_special.pressed.connect(_on_circle_pressed.bind(ACTIVE, btn_special))
	btn_confirm.pressed.connect(_on_confirm_pressed)

	# 攒/波/大波/防/大防 用 HoverIcon 美术图标（节点在 battle_screen.tscn 内，编辑器可见可调）；
	# 技能按钮显示「技能」二字（详细说明仍放 tooltip，见 _layout_circles）。位置/尺寸由 .tscn 决定。
	btn_special.text = "技能"
	btn_confirm.text = "结束"

	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]:
		FontManager.apply_btn(btn, 16)
		btn.clip_text = true
	FontManager.apply_btn(btn_confirm, 16)
	btn_confirm.clip_text = true

	# 技能按钮「技能」二字单独放大 + 描边，叠在紫色果冻底上清晰可读。
	FontManager.apply_btn(btn_special, 30)
	btn_special.add_theme_color_override("font_color", Color.WHITE)
	btn_special.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	btn_special.add_theme_constant_override("outline_size", 4)

	# 结束按钮「结束」二字同样放大 + 描边，配绿色徽章底。
	FontManager.apply_btn(btn_confirm, 30)
	btn_confirm.add_theme_color_override("font_color", Color.WHITE)
	btn_confirm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	btn_confirm.add_theme_constant_override("outline_size", 4)

	action_btn_list = [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend, btn_special]

	FontManager.apply(turn_label, 22)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(timer_label, 80)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(status_label, 44)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	FontManager.apply(big_turn_label, 44)
	big_turn_label.add_theme_color_override("font_color", Color.WHITE)
	event_label.visible = false
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
# 技能展示格（点击翻页浏览全部英雄技能：己方 → 对方）
# ============================================================

## 构建浏览顺序：先己方 3 个（含替补），再对方 3 个，按阵容槽位顺序。
func _build_skill_entries() -> void:
	_skill_entries.clear()
	for p in [PLAYER, AI]:
		for slot in range(battle.heroes[p].size()):
			_skill_entries.append([p, slot])
	_skill_index = 0


## 把当前选中的英雄填进展示格。主动/被动取自运行时技能组件（h07 当先按主动算）。
func _refresh_skill_card() -> void:
	if _skill_entries.is_empty():
		return
	var e: Array = _skill_entries[_skill_index % _skill_entries.size()]
	var p: int = int(e[0])
	var slot: int = int(e[1])
	var h: HeroData = battle.heroes[p][slot]
	var sk: HeroSkill = battle._skills[p][slot]
	var is_active: bool = sk != null and (sk.has_active() or sk.has_free_switch())
	# 立绘一律朝右；阵营靠底色区分（己方冷蓝 / 对方暖红）。
	skill_card.populate(h.hero_name, h.skill_description, h.skill_detail, is_active, h.portrait_path, p == PLAYER)


## 点击展示格 → 翻到下一个英雄，循环。
func _on_skill_card_advance() -> void:
	if _skill_entries.is_empty():
		return
	_skill_index = (_skill_index + 1) % _skill_entries.size()
	_refresh_skill_card()


# ============================================================
# 回合流程（同时盲选）
# ============================================================

func _show_turn_intro() -> void:
	state = State.TURN_INTRO
	_set_buttons_active(false, false)   # 回合介绍：按钮按能量正常显示、不压暗（仅暂不可点）
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
	timer_label.text = "%d" % maxi(timer_seconds, 0)


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
	_set_btn_selected(btn, true)
	_set_confirm_active(true)


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
	status_label.visible = false

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

	# 头顶招式圆圈（揭示双方盲选出招）→ 消失 → 再播打斗动画
	await _show_action_indicators(r.get("p1_action", -1), r.get("p2_action", -1))
	await _play_battle_anims(r.get("p1_action", -1), r.get("p2_action", -1), dmg, [p0_dead, p1_dead])
	_update_all()

	if r.get("game_over", false):
		state = State.GAME_OVER
		var w: int = r.get("winner", BattleCore.WINNER_UNDECIDED)
		var msg := "平局"
		var col := Color("#dddddd")
		if w == BattleCore.WINNER_P1:
			msg = "你胜利！"
			col = Color("#5fd86b")
		elif w != BattleCore.WINNER_DRAW:
			msg = "你失败"
			col = Color("#e0574b")
		status_label.text = msg
		status_label.add_theme_color_override("font_color", col)
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
	_set_confirm_active(true)
	status_label.text = "切换 → %s（按结束确认）" % battle.heroes[player][hero_slot].hero_name


# ============================================================
# 按钮布局 / 状态
# ============================================================

## active=true：选择阶段，按钮按真实可用性亮/暗 + 可点。
## active=false 时按 dim_inactive 区分：
##   true（结算 / 换人 / 游戏结束）→ 全禁用 + 整体降透明度 0.4（不消失，保留"不可操作"反馈）；
##   false（开局 / 回合介绍）→ 仍按真实可用性显示亮/暗、不整体压暗，仅靠 state 守卫拦截点击
##     → 开局就是"正常"的按钮，不再一上来一片半透明（任务1）。
func _set_buttons_active(active: bool, dim_inactive: bool = true) -> void:
	# 底部 UI 始终可见。
	for btn in action_btn_list + [btn_confirm]:
		btn.visible = true
	_layout_circles()
	var show_affordance := active or not dim_inactive
	var alpha := 1.0 if show_affordance else 0.4
	buttons_ctrl.modulate = Color(1, 1, 1, alpha)
	if skill_card:
		skill_card.visible = true
		skill_card.modulate = Color(1, 1, 1, alpha)
	if show_affordance:
		_refresh_action_affordance()   # 按能量显示亮/暗（开局与选择阶段一致）
	else:
		for btn in action_btn_list + [btn_confirm]:
			btn.disabled = true        # 结算/过场：全禁用
	_refresh_skill_card()


## 编辑器可摆位：按钮位置/尺寸全部读 .tscn，代码只管显隐与技能 tooltip，不再覆盖坐标。
## 在 Godot 里随意移动/缩放 Buttons 下的按钮即可，运行时不会被弹回。
func _layout_circles() -> void:
	var has_active: bool = _player_has_active()
	btn_special.visible = has_active
	if has_active:
		# 技能按钮无文字，技能说明放 tooltip（悬停可见，信息不丢）。
		btn_special.tooltip_text = battle.active_hero(PLAYER).skill_description
	for btn in [btn_charge, btn_attack, btn_big_attack, btn_defend, btn_big_defend]:
		btn.visible = true
	btn_confirm.visible = true


## 出战英雄是否有主动技（访问 _skills，下划线约定但可读）。
func _player_has_active() -> bool:
	var sk: HeroSkill = battle._skills[PLAYER][battle.active_index[PLAYER]]
	return sk != null and sk.has_active()


func _reset_button_styles() -> void:
	for btn in action_btn_list:
		_set_btn_selected(btn, false)
	_set_confirm_active(false)


## 选中态视觉：果冻底常显，选中按钮整体提亮 + 从中心轻微放大
## （不再用不透明 StyleBox 盖住果冻 —— 那正是"点击后变回老版"的根因）。
func _set_btn_selected(btn: Button, on: bool) -> void:
	# 选中高亮用「冷亮蓝白」而非暖金 —— 暖金会撞 skill_card 的金色书本/羊皮纸（任务2）。
	# 银色按钮 × 冷亮 → 像通电发光，与金色图鉴格冷暖区分明显。
	btn.modulate = Color(1.28, 1.42, 1.6) if on else Color.WHITE
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2.ONE * (1.08 if on else 1.0)
	# 任务7：选中该动作按钮后，让按钮内的美术图标持续播 idle（取消选中则回静止帧）。
	var hi := btn.get_node_or_null("HoverIcon") as HoverIcon
	if hi != null:
		hi.set_selected_play(on)


## 结束按钮"可确认"高亮：选中动作/切换后整体暖亮（用 modulate，不再用已废弃的 StyleBox 覆盖）。
func _set_confirm_active(on: bool) -> void:
	btn_confirm.modulate = Color(1.35, 1.36, 1.18) if on else Color.WHITE


func _update_button_states() -> void:
	if state != State.PLAYER_SELECT:
		return
	_refresh_action_affordance()


## 按真实能量/可用性刷新每个动作按钮的 disabled（= 图标亮/暗 + 能否点）。
## 不依赖 state：开局回合介绍阶段也据此显示正确的亮/暗，能否实际操作交给 state 守卫拦截。
func _refresh_action_affordance() -> void:
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
	_update_hero_frames()
	_update_character_displays()
	_update_energy_labels()
	_update_hp_labels()
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
		var heart_icons: Array = p1_frame_heart_icons if p == 0 else p2_frame_heart_icons
		var frame_slots: Array[int] = p1_frame_slots if p == 0 else p2_frame_slots
		var active_idx: int = battle.active_index[p]
		var reserves := _get_reserve_slots(p)
		var pcolor := Color("#3388dd") if p == 0 else Color("#dd3333")

		frame_slots[0] = active_idx
		_update_single_frame(frames[0], hp_labels[0], shield_labels[0], heart_icons[0], p, active_idx, true, pcolor)

		for j in range(2):
			var fi := j + 1
			if j < reserves.size():
				var slot: int = reserves[j]
				frame_slots[fi] = slot
				_update_single_frame(frames[fi], hp_labels[fi], shield_labels[fi], heart_icons[fi], p, slot, false, pcolor)
			else:
				frame_slots[fi] = -1
				frames[fi].visible = false
				hp_labels[fi].visible = false
				shield_labels[fi].visible = false
				if heart_icons[fi] != null:
					heart_icons[fi].visible = false


## 出战位(is_active)：只画头像，血量/护盾文字隐藏（看上方大心条）。
## 待选位：头像 + 心形美术标记(heart_icon, 仅作图标) + 血量数字 + 护盾。
func _update_single_frame(frame: HeroFrame, hp_label: Label, shield_label: Label, heart_icon, player: int, slot: int, is_active: bool, pcolor: Color) -> void:
	if slot < 0 or slot >= battle.heroes[player].size():
		frame.visible = false
		hp_label.visible = false
		shield_label.visible = false
		if heart_icon != null:
			heart_icon.visible = false
		return

	frame.visible = true

	var h: HeroData = battle.heroes[player][slot]
	var dead: bool = battle.hp[player][slot] <= 0

	frame.hero_name = h.hero_name
	frame.portrait_path = h.portrait_path
	frame.is_active = is_active
	frame.is_dead = dead
	frame.player_color = pcolor
	frame.frame_size = Vector2(72, 72) if is_active else Vector2(68, 68)

	# 出战位：血量/护盾文字 + 心形图标全隐藏（出战血量由上方大心条显示）。
	if is_active:
		hp_label.visible = false
		shield_label.visible = false
		if heart_icon != null:
			heart_icon.visible = false
		return

	# 阵亡：灰头像，下方不显示 0hp / 护盾 / 心标记。
	if dead:
		hp_label.visible = false
		shield_label.visible = false
		if heart_icon != null:
			heart_icon.visible = false
		return

	hp_label.visible = false                        # 不再用 ♥+数字
	shield_label.visible = true

	var hp_now := battle.hp_display(battle.hp[player][slot])
	var hp_max := battle.hp_display(battle.max_hp[player][slot])

	# 待选血量 = 一排缩小的爱心（心数 = maxHP，pip 自适应缩到"整排不超头像框宽"）。
	if heart_icon != null:
		heart_icon.visible = true
		var maxn := maxi(int(ceil(hp_max - 0.0001)), 1)
		var fw: float = frame.size.x                # 头像框宽度（待选 68）
		var hsp := 1.0   # 爱心间距（本地 float，避免无类型 Array 元素属性的 Variant 推断失败）
		heart_icon.spacing = hsp
		var ps := clampf((fw - hsp * float(maxn - 1)) / float(maxn), 6.0, HEART_BAND)
		heart_icon.pip_size = ps
		# 对齐修复（任务6）：所有替补爱心在「框底下方一条固定 16px 高度带」内垂直居中，
		# 整排水平也在框内居中 → 不同 maxHP（pip 大小不同）的英雄爱心 y 视觉对齐、不再参差。
		var row_w := ps * float(maxn) + hsp * float(maxn - 1)
		var x_off := maxf((fw - row_w) * 0.5, 0.0)
		var y_off := frame.size.y + 2.0 + (HEART_BAND - ps) * 0.5
		heart_icon.position = frame.position + Vector2(x_off, y_off)
		heart_icon.show_empty = true                # 满槽=maxHP（暗色空心补齐），宽度恒定不超框
		heart_icon.allow_half = true
		heart_icon.set_value(hp_now, hp_max)

	var sh := battle.hp_display(battle.shield[player][slot])
	shield_label.text = "🛡%s" % _fmt_hp(sh) if sh > 0 else ""
	shield_label.add_theme_font_size_override("font_size", 11)


func _update_energy_labels() -> void:
	# 金币能量点：能量为整数，show_empty=false → 画 N 枚金币（在 .tscn 配置）。
	p1_coin_row.set_value(float(battle.energy[0]), float(battle.energy[0]))
	p2_coin_row.set_value(float(battle.energy[1]), float(battle.energy[1]))


func _update_hp_labels() -> void:
	p1_char_display.visible = true
	p2_char_display.visible = true
	for p in [0, 1]:
		var hp_now := battle.hp_display(battle.current_hp(p))
		var hp_max := battle.hp_display(battle.current_max_hp(p))
		var sh := battle.hp_display(battle.shield[p][battle.active_index[p]])
		# 心形血珠：满+半+暗色空心到 max；护盾作青色额外心追加。
		var row: IconPipRow = p1_heart_row if p == 0 else p2_heart_row
		row.set_value(hp_now, hp_max, sh)


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
			# A3：出招瞬间被自己的招式照亮（月光描边增强）。
			cd.pulse_rim(1.4 if action == A.BIG_ATTACK else 0.9, 0.3)
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
	cd.pulse_rim(0.7, 0.22)   # A3：被弧光照亮
	_char_pop(target_player, 0.08)   # A3：受击退弹（scale 弹一下）
	_spawn_slash(target_player)
	if dmg_half > 0:
		_pop_damage(target_player, float(dmg_half) / 2.0)


## A3：受击 scale-pop（绕立绘中心快速放大再回弹）。pivot 每次按当前尺寸取中心，稳健。
func _char_pop(player: int, amount: float) -> void:
	var cd := _cd(player)
	cd.pivot_offset = cd.size * 0.5
	var tw := create_tween()
	tw.tween_property(cd, "scale", Vector2(1.0 + amount, 1.0 + amount), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cd, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	# 阴影对角色动作反应：水平位移跟随 + 离地缩小淡出 + 冲刺拉长（接地/重量感）。
	_update_shadow(0)
	_update_shadow(1)


## A3：阴影随角色动作变形。
## - 水平位移：前冲时影子跟着横移；
## - 离地（攒上浮 / 前冲腾身，position.y < home.y）：影子缩小 + 变淡（角色离地）；
## - 横向冲刺：影子沿地面拉长（速度感）。
func _update_shadow(p: int) -> void:
	var cd: CharacterDisplay = p1_char_display if p == 0 else p2_char_display
	var sh: TextureRect = p1_shadow if p == 0 else p2_shadow
	var home: Vector2 = _cd_home[p]
	var dx: float = cd.position.x - home.x
	var lift: float = maxf(home.y - cd.position.y, 0.0)          # 上抬量（离地）
	sh.position.x = _shadow_home[p].x + dx
	var k: float = clampf(1.0 - lift / 140.0, 0.5, 1.0)          # 离地越多越小
	var stretch: float = 1.0 + clampf(absf(dx) / 190.0, 0.0, 1.0) * 0.4
	sh.scale = Vector2(k * stretch, k)
	sh.modulate.a = lerpf(0.4, 1.0, k)


# ============================================================
# 头顶招式圆圈（揭示盲选出招，占位待美术）/ 动作名
# ============================================================

## 双方各在角色头顶弹出一个气泡（揭示盲选出招）：有美术图标用图标、否则用文字。
## 进场带 pop 动画（缩放回弹 + 淡入），显示 1.2s 后收起淡出，告别"直接冒出来"的僵硬。
func _show_action_indicators(a0: int, a1: int) -> void:
	status_label.visible = false
	event_label.visible = false
	var c0 := _spawn_action_circle(0, a0)
	var c1 := _spawn_action_circle(1, a1)
	await get_tree().create_timer(1.2).timeout
	for c in [c0, c1]:
		if is_instance_valid(c):
			var tw := create_tween()
			tw.tween_property(c, "scale", Vector2(0.5, 0.5), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.14)
			tw.tween_callback(c.queue_free)


## 找动作对应的动作按钮（攒/波/大波/防/大防 有；技能/切换 无 → null）。
func _btn_for_action(action: int) -> Button:
	match action:
		A.CHARGE: return btn_charge
		A.ATTACK: return btn_attack
		A.BIG_ATTACK: return btn_big_attack
		A.DEFEND: return btn_defend
		A.BIG_DEFEND: return btn_big_defend
		ACTIVE: return btn_special
	return null


## 取动作按钮上的 HoverIcon（图标/帧/缩放的单一来源，在 .tscn 配置）；无则 null。
func _hover_icon_for(action: int) -> HoverIcon:
	var btn := _btn_for_action(action)
	if btn == null:
		return null
	return btn.get_node_or_null("HoverIcon") as HoverIcon


## 在 player 角色头顶生成揭示气泡（圆底 + 美术图标 / 文字回退）。
func _spawn_action_circle(player: int, action: int) -> Control:
	var cd := _cd(player)
	var sz := 92.0
	var circ := Control.new()
	circ.size = Vector2(sz, sz)
	circ.position = cd.position + Vector2(cd.size.x * 0.5 - sz * 0.5, -sz - 12.0)
	circ.pivot_offset = Vector2(sz, sz) * 0.5   # 从中心 pop
	circ.z_index = 80
	circ.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 果冻底：复用对应动作按钮的 jelly 材质 → 颜色/像素风格/Inspector 微调全与按钮一致。
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn := _btn_for_action(action)
	var btn_bg: ColorRect = null
	if btn != null:
		btn_bg = btn.get_node_or_null("Bg") as ColorRect
	if btn_bg != null and btn_bg.material != null:
		bg.material = btn_bg.material
		bg.color = Color.WHITE              # shader 输出 × COLOR；白 = 全强度
	else:
		bg.color = Color("#2a2a4a")         # 无对应按钮(如切换)→ 维持深蓝底
	circ.add_child(bg)

	var hi := _hover_icon_for(action)
	if hi != null and hi.sheet != null:
		# 气泡内放一个自动循环播放的 HoverIcon → 复用按钮图标的 sheet/帧/缩放，观感与按钮一致，
		# 且持续播放 idle 动画（动态，不再是静止帧0）。填满气泡，inset/content_scale 同按钮。
		var anim := HoverIcon.new()
		anim.sheet = hi.sheet
		anim.hframes = hi.hframes
		anim.vframes = hi.vframes
		anim.frame_count = hi.frame_count
		anim.fps = hi.fps
		# 比例与按钮一致：取按钮里图标的「显示占比」直接当 content_scale + inset 归零 →
		# 气泡内图标占气泡的比例 = 图标占按钮的比例（修复气泡图标偏大/比例不一致）。
		anim.inset_ratio = 0.0
		anim.content_scale = hi.display_ratio()
		anim.auto_play = true
		anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circ.add_child(anim)
	else:
		var lbl := Label.new()
		lbl.text = _action_name(action)
		FontManager.apply(lbl, 28)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circ.add_child(lbl)

	add_child(circ)
	_animate_bubble_pop(circ)
	return circ


## 气泡 pop 进场：从小放大（回弹）+ 淡入。
func _animate_bubble_pop(node: Control) -> void:
	node.scale = Vector2(0.2, 0.2)
	node.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.14, 1.14), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween()
	tw2.tween_property(node, "modulate:a", 1.0, 0.14).set_ease(Tween.EASE_OUT)


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
