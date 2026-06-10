extends Control

## BP 选人屏 —— 联机正式形态（同时盲选，2 步），单机由 AI 扮演对手（决策 Q1=b/Q2=b/Q3=b）。
## 3 态：BAN（双方盲选 3 禁用 → 取并集，撞车合并）→ PICK（双方盲选 3 出战，允许双方重复=镜像）
##        → REVEAL（亮出双方阵容，点「开始战斗」进 battle_screen）。
## 池 = assets/data/heroes 全 34（h18-h34 暂名字占位）。保留 bp_screen.tscn 布局。
## 最新方案出处：design/heroes-schools.md §8.3。

enum Step { BAN, PICK, REVEAL }

const HERO_DATA_DIR := "res://assets/data/heroes/"
const CARD_W := 130
const CARD_H := 158
const COLS := 8
const GAP_X := 24            # 列距加大：给卡片左上角"骑在边框上·覆盖角饰"的爱心留出向左探出的空隙(任务1)
const GAP_Y := 28            # 行距加大：给卡片左上角探出的爱心留出向上空隙
const TOP_PAD := 28          # 卡池顶部留白：让第一行卡片探出的爱心不被滚动容器裁掉
const STEP_TIME := 30        # 每步思考时限（秒），超时自动随机补满
const BAN_COUNT := 3
const PICK_COUNT := 3
const HERO_CARD_SCENE := preload("res://src/ui/components/hero_card.tscn")

var all_heroes: Array[HeroData] = []
var step: int = Step.BAN
var my_sel: Array[int] = []          # 当前步玩家多选（待确认）
var my_bans: Array[int] = []
var ai_bans: Array[int] = []
var banned: Array[int] = []          # 双方 ban 并集（撞车去重）
var my_picks: Array[int] = []
var ai_picks: Array[int] = []

@onready var phase_label: Label = $PhaseLabel
@onready var info_label: Label = $InfoLabel
@onready var timer_label: Label = $TimerLabel
@onready var p1_preview: BPPreviewPanel = $P1PreviewPanel
@onready var p2_preview: BPPreviewPanel = $P2PreviewPanel
@onready var card_area: Control = $CardScrollContainer/CardArea
@onready var confirm_btn: Button = $ConfirmButton
@onready var bp_timer: Timer = $BPTimer

var card_cards: Array[HeroCard] = []
var timer_seconds: int = STEP_TIME
var _glow_tween: Tween   # 确认按钮"可确认"时的呼吸金光循环


func _ready() -> void:
	all_heroes = HeroData.create_pool_heroes(HERO_DATA_DIR)
	_setup_ui()
	_enter_step(Step.BAN)


func _setup_ui() -> void:
	FontManager.apply(phase_label, 24)
	phase_label.add_theme_color_override("font_color", Color("#f5c518"))
	FontManager.apply(info_label, 16)
	info_label.add_theme_color_override("font_color", Color("#777799"))
	FontManager.apply(timer_label, 24)
	timer_label.add_theme_color_override("font_color", Color("#ffaa00"))
	FontManager.apply_btn(confirm_btn, 24)

	confirm_btn.pressed.connect(_on_confirm)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	confirm_btn.add_child(bj)
	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_timer_tick)

	_build_hero_cards()


func _build_hero_cards() -> void:
	var count := all_heroes.size()
	var rows := ceili(float(count) / COLS)
	var content_w := COLS * CARD_W + (COLS - 1) * GAP_X
	var content_h := TOP_PAD + rows * CARD_H + (rows - 1) * GAP_Y
	# 卡池在 ScrollContainer 视口内水平居中（start_x），高度=内容（驱动垂直滚动）。
	var scroll := card_area.get_parent() as Control
	var view_w: float = scroll.size.x if scroll and scroll.size.x > 0.0 else float(content_w)
	var start_x: float = maxf((view_w - float(content_w)) * 0.5, 0.0)
	card_area.custom_minimum_size = Vector2(maxf(view_w, float(content_w)), content_h)

	for i in range(count):
		var row := i / COLS
		var col := i % COLS
		var x := start_x + col * (CARD_W + GAP_X)
		var y := TOP_PAD + row * (CARD_H + GAP_Y)
		var h := all_heroes[i]
		var card := HERO_CARD_SCENE.instantiate() as HeroCard
		card.hero_id = h.hero_id
		card.hero_name = h.hero_name
		card.max_hp = h.max_hp
		card.role_text = h.role
		card.position_text = h.position
		card.portrait_path = h.portrait_path
		card.position = Vector2(x, y)
		card.pressed.connect(_on_card_clicked.bind(i))
		card_area.add_child(card)
		card_cards.append(card)


func _need() -> int:
	return BAN_COUNT if step == Step.BAN else PICK_COUNT


func _on_card_clicked(idx: int) -> void:
	if step == Step.REVEAL:
		return
	if step == Step.PICK and idx in banned:
		return
	# toggle 多选，上限 _need()
	if idx in my_sel:
		my_sel.erase(idx)
	elif my_sel.size() < _need():
		my_sel.append(idx)
	_update_all_cards()
	_update_info()
	_set_confirm_enabled(my_sel.size() == _need())


func _update_all_cards() -> void:
	for i in range(card_cards.size()):
		var card := card_cards[i]
		if i in banned:
			card.card_state = HeroCard.CardState.BANNED
		elif i in my_picks:
			card.card_state = HeroCard.CardState.PICKED_P1
		elif i in ai_picks:
			card.card_state = HeroCard.CardState.PICKED_P2
		elif i in my_sel:
			card.card_state = HeroCard.CardState.SELECTED
		else:
			card.card_state = HeroCard.CardState.NORMAL


func _update_previews() -> void:
	p1_preview.set_picks(my_picks, all_heroes)
	p2_preview.set_picks(ai_picks, all_heroes)


func _enter_step(s: int) -> void:
	bp_timer.stop()
	step = s
	my_sel.clear()
	_update_all_cards()
	_update_previews()
	_update_phase_label()
	_update_info()

	match s:
		Step.BAN, Step.PICK:
			confirm_btn.visible = true
			_set_confirm_enabled(false)
			confirm_btn.text = "确认禁用" if s == Step.BAN else "确认出战"
			timer_label.visible = true
			timer_seconds = STEP_TIME
			_update_timer_label()
			bp_timer.start(1.0)
		Step.REVEAL:
			confirm_btn.visible = true
			_set_confirm_enabled(true)
			confirm_btn.text = "开始战斗"
			timer_label.visible = false


func _update_phase_label() -> void:
	match step:
		Step.BAN:
			phase_label.text = "禁用阶段 — 盲选 3 名英雄禁用（与对手同时）"
		Step.PICK:
			phase_label.text = "选人阶段 — 选择你的 3 名出战英雄"
		Step.REVEAL:
			phase_label.text = "对阵已定！"


func _update_info() -> void:
	match step:
		Step.BAN:
			info_label.text = "已选禁用 %d / %d" % [my_sel.size(), BAN_COUNT]
		Step.PICK:
			var collide := _intersect_count(my_bans, ai_bans)
			var ban_note := "（与对手撞车 %d）" % collide if collide > 0 else ""
			info_label.text = "已禁用 %d 名%s | 已选出战 %d / %d" % [banned.size(), ban_note, my_sel.size(), PICK_COUNT]
		Step.REVEAL:
			info_label.text = "你的阵容 vs 对手阵容 — 点「开始战斗」进场"


func _on_confirm() -> void:
	bp_timer.stop()
	match step:
		Step.BAN:
			if my_sel.size() != BAN_COUNT:
				return
			my_bans = my_sel.duplicate()
			ai_bans = _ai_choose(BAN_COUNT, [])
			banned = my_bans.duplicate()
			for b in ai_bans:
				if not b in banned:
					banned.append(b)
			_enter_step(Step.PICK)
		Step.PICK:
			if my_sel.size() != PICK_COUNT:
				return
			my_picks = my_sel.duplicate()
			ai_picks = _ai_choose(PICK_COUNT, banned)   # 不排除 my_picks → 允许镜像
			_enter_step(Step.REVEAL)
		Step.REVEAL:
			_start_battle()


## AI 盲选：从合法池（排除 exclude）随机选 n 个不同。单机临时实现，联机时换网络对手。
func _ai_choose(n: int, exclude: Array[int]) -> Array[int]:
	var pool: Array[int] = []
	for i in range(all_heroes.size()):
		if not i in exclude:
			pool.append(i)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


func _intersect_count(a: Array[int], b: Array[int]) -> int:
	var c := 0
	for x in a:
		if x in b:
			c += 1
	return c


func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	if timer_seconds <= 0:
		bp_timer.stop()
		_auto_fill()


## 超时自动随机补满当前步选择并确认。
func _auto_fill() -> void:
	while my_sel.size() < _need():
		var pool: Array[int] = []
		for i in range(all_heroes.size()):
			if i in my_sel:
				continue
			if step == Step.PICK and i in banned:
				continue
			pool.append(i)
		if pool.is_empty():
			break
		my_sel.append(pool[randi() % pool.size()])
	_update_all_cards()
	if my_sel.size() == _need():
		_on_confirm()


## 确认按钮可用态 + 呼吸金光：可确认时循环脉冲 modulate，提示玩家"可以提交了"。
func _set_confirm_enabled(on: bool) -> void:
	confirm_btn.disabled = not on
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	confirm_btn.modulate = Color.WHITE
	if on:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(confirm_btn, "modulate", Color(1.32, 1.2, 0.82), 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(confirm_btn, "modulate", Color.WHITE, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_timer_label() -> void:
	timer_label.text = "剩余 %ds" % maxi(timer_seconds, 0)
	timer_label.add_theme_color_override("font_color", Color("#ff4444") if timer_seconds <= 5 else Color("#ffaa00"))


func _start_battle() -> void:
	var p1_lineup: Array[HeroData] = []
	for idx in my_picks:
		p1_lineup.append(all_heroes[idx])
	var p2_lineup: Array[HeroData] = []
	for idx in ai_picks:
		p2_lineup.append(all_heroes[idx])
	# 必须先 set BattleSetup 再切场，否则 battle_screen._ready() 拿到空 lineup
	BattleSetup.p1_heroes = p1_lineup
	BattleSetup.p2_heroes = p2_lineup
	get_tree().change_scene_to_file("res://src/ui/battle_screen.tscn")
