extends Control

## BP 选人屏 = 「双席牌局」（第二轮重构 2026-06-11·Eddy 批）。
## BP 的本质是双方同时盲选 = 这局牌的第一手 → 界面从"商店货架"改为第一人称对坐牌桌。
## 纵深三层：对手席(顶带·你选择期间对手随机时刻盖下牌背=实时压力，本地 AI 演出/联机真信号)
##           牌库摊开(中·46 卡按 生肖12|塔罗11+11|星座12 四行三牌系分区·全池一屏无滚动)
##           我的手牌(底带·点池卡飞入 3 大牌位·再点退回·确认盖牌金钮)。
## 两次翻牌仪式：禁用揭晓=双方 3 张推中央同时翻开+撞车对白闪合并（并集规则的戏剧呈现）；
##              出战亮相=3v3 对扣翻开对峙+王冠+开始战斗。
## 流程保留：BAN → PICK → REVEAL（3B 本地留 Ban），超时自动补满，BattleSetup 交接，波幕转场。
## ⚠️ 仪式压暗用独立暗幕 ColorRect，禁用 modulate（会压黑霜玻璃衬底反而让亮波透出）。

enum Step { BAN, PICK, REVEAL }

const HERO_DATA_DIR := "res://assets/data/heroes/"
const HERO_CARD_SCENE := preload("res://src/ui/components/hero_card.tscn")
const FRAME_SHADER := preload("res://assets/shaders/canvas_ui_pixel_frame.gdshader")
const JELLY_SHADER := preload("res://assets/shaders/canvas_button_jelly.gdshader")

const STEP_TIME := 30
const BAN_COUNT := 3
const PICK_COUNT := 3

# ── 牌库网格（46 全池一屏：生肖12 / 塔罗11+11 / 星座12）──
const POOL := Rect2(200, 222, 1520, 612)
const CARD_SCALE := 0.846          # 130×158 → 110×134
const HAND_SCALE := 150.0 / 130.0  # 手牌大卡
const STEP_X := 121.0
const ROW_H := 146.0
const ROW_Y0 := 240.0
# [起始索引, 张数, 行起点x]；末值=该行左缘（12 张行 / 11 张行居中）
const ROWS: Array = [[0, 12, 270.0], [12, 11, 330.0], [23, 11, 330.0], [34, 12, 270.0]]

# ── 席位槽（OppBand / MyBand 内相对坐标）──
const OPP_SLOTS: Array = [Vector2(980, 16), Vector2(1100, 16), Vector2(1220, 16)]
const OPP_SLOT_SIZE := Vector2(92, 116)
const HAND_SLOTS: Array = [Vector2(760, 16), Vector2(940, 16), Vector2(1120, 16)]
const HAND_SLOT_SIZE := Vector2(150, 182)

# ── 仪式排位（全局坐标）──
const CER_X0 := 700.0
const CER_DX := 200.0
const CER_OPP_Y := 320.0
const CER_MY_Y := 560.0

# 配色（battle 框语言 + 阵营）
const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const EDGE_MID := Color(0.65, 0.67, 0.71)
const EDGE_INNER := Color(0.34, 0.36, 0.39)
const GOLD_TEXT := Color("#f4c84b")
const BAN_RED := Color("#d24a44")
const TIN_DIM := Color("#aab4c4")
const TIER_GOLD := {
	"fill_top": Color(0.64, 0.46, 0.17), "fill_bottom": Color(0.33, 0.21, 0.07),
	"edge_inner": Color(0.98, 0.82, 0.42), "edge_outer": Color(0.12, 0.08, 0.03),
}

var all_heroes: Array[HeroData] = []
var step: int = Step.BAN
var my_sel: Array[int] = []          # 手牌（顺序=槽位）
var my_bans: Array[int] = []
var ai_bans: Array[int] = []
var banned: Array[int] = []          # 双方 ban 并集
var my_picks: Array[int] = []
var ai_picks: Array[int] = []

@onready var pool_area: Control = $PoolArea
@onready var opp_band: Control = $OppBand
@onready var opp_progress: Label = $OppBand/OppProgress
@onready var phase_strip: Control = $PhaseStrip
@onready var phase_label: Label = $PhaseStrip/PhaseLabel
@onready var timer_label: Label = $PhaseStrip/TimerLabel
@onready var my_band: Control = $MyBand
@onready var confirm_btn: Button = $MyBand/ConfirmButton
@onready var bp_timer: Timer = $BPTimer

var card_cards: Array[HeroCard] = []
var hand_cards: Array[HeroCard] = []     # 槽位顺序，与 my_sel 对齐
var timer_seconds: int = STEP_TIME

# 对手盖牌演出（本地 AI 戏剧；联机时由真实"已提交"信号驱动）
var _ai_step_choice: Array[int] = []     # 本步 AI 的实际选择（步开始即定，盖牌只是演出）
var _opp_cover_times: Array[int] = []    # 第 N 张盖下的时刻（经过秒数）
var _opp_covered: int = 0
var _opp_backs: Array[Control] = []

var _ceremony: bool = false              # 仪式进行中=锁输入
var _pool_dim: ColorRect = null
var _glow_tween: Tween
var _dots: Array[ColorRect] = []
var _dot_color: Color = BAN_RED


func _ready() -> void:
	all_heroes = HeroData.create_pool_heroes(HERO_DATA_DIR)
	_setup_ui()
	_build_pool()
	_enter_step(Step.BAN)
	_play_intro()


# ============================================================
# 初始化
# ============================================================

func _setup_ui() -> void:
	FontManager.apply(phase_label, 24)
	phase_label.add_theme_color_override("font_color", Color("#e8edf4"))
	FontManager.apply(timer_label, 22)
	timer_label.add_theme_color_override("font_color", GOLD_TEXT)

	FontManager.apply($OppBand/OppName, 22)
	$OppBand/OppName.add_theme_color_override("font_color", Color("#e8a09c"))
	FontManager.apply($OppBand/OppRank, 14)
	$OppBand/OppRank.add_theme_color_override("font_color", Color(TIN_DIM, 0.7))
	FontManager.apply(opp_progress, 16)
	opp_progress.add_theme_color_override("font_color", Color("#e8a09c"))
	FontManager.apply($MyBand/MyName, 22)
	$MyBand/MyName.add_theme_color_override("font_color", Color("#9cc0e8"))
	FontManager.apply($MyBand/MyHint, 14)
	$MyBand/MyHint.add_theme_color_override("font_color", Color(TIN_DIM, 0.7))

	# 席位槽底（对手 3 + 手牌 3）
	for p in OPP_SLOTS:
		_make_slot_pit(opp_band, Rect2(p, OPP_SLOT_SIZE), "··")
	for p in HAND_SLOTS:
		_make_slot_pit(my_band, Rect2(p, HAND_SLOT_SIZE), "空")

	# 确认钮：金大钮（主菜单匹配钮同级）
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		confirm_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(confirm_btn, 26)
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = JELLY_SHADER
	for k in TIER_GOLD:
		mat.set_shader_parameter(k, TIER_GOLD[k])
	mat.set_shader_parameter("corner", 0.2)
	mat.set_shader_parameter("edge_px", 2.0)
	mat.set_shader_parameter("noise_amt", 0.05)
	mat.set_shader_parameter("wear", 0.18)
	mat.set_shader_parameter("pixel_grid", 38.0)
	mat.set_shader_parameter("fill_alpha", 0.95)
	mat.set_shader_parameter("aspect", confirm_btn.size.x / maxf(confirm_btn.size.y, 1.0))
	bg.material = mat
	confirm_btn.add_child(bg)
	confirm_btn.pressed.connect(_on_confirm)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	confirm_btn.add_child(bj)

	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_timer_tick)


## 牌库摊开：霜玻璃桌面 + 三牌系分区（竖排系徽）+ 46 卡四行。
func _build_pool() -> void:
	_make_frosted(pool_area, POOL)
	_make_section_tag(pool_area, "生肖", Vector2(214, ROW_Y0 + 30))
	_make_section_tag(pool_area, "塔罗", Vector2(214, ROW_Y0 + ROW_H * 1.5 + 10))
	_make_section_tag(pool_area, "星座", Vector2(214, ROW_Y0 + ROW_H * 3.0 + 30))
	for ln_y in [ROW_Y0 + ROW_H - 8.0, ROW_Y0 + ROW_H * 3.0 - 8.0]:
		var ln := ColorRect.new()
		ln.color = Color(0.30, 0.55, 0.85, 0.18)
		ln.position = Vector2(214, ln_y)
		ln.size = Vector2(1492, 1)
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pool_area.add_child(ln)

	for r in ROWS.size():
		var start: int = ROWS[r][0]
		var count: int = ROWS[r][1]
		var x0: float = ROWS[r][2]
		for c in count:
			var i: int = start + c
			if i >= all_heroes.size():
				break
			var h := all_heroes[i]
			var card := HERO_CARD_SCENE.instantiate() as HeroCard
			card.hero_id = h.hero_id
			card.hero_name = h.hero_name
			card.max_hp = h.max_hp
			card.role_text = h.role
			card.position_text = h.position
			card.portrait_path = h.portrait_path
			card.scale = Vector2(CARD_SCALE, CARD_SCALE)
			card.position = Vector2(x0 + c * STEP_X, ROW_Y0 + r * ROW_H)
			card.pressed.connect(_on_card_clicked.bind(i))
			pool_area.add_child(card)
			var bj := card.get_node_or_null("ButtonJuice") as ButtonJuice
			if bj:
				bj.base_scale = CARD_SCALE
			card_cards.append(card)
	pool_area.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ============================================================
# 阶段机
# ============================================================

func _enter_step(s: int) -> void:
	bp_timer.stop()
	step = s
	my_sel.clear()
	for hc in hand_cards:
		hc.queue_free()
	hand_cards.clear()
	_update_all_cards()
	_build_phase_deco(false)
	confirm_btn.visible = true
	timer_label.visible = true
	timer_seconds = STEP_TIME
	_update_timer_label()
	bp_timer.start(1.0)

	# 对手盲选演出：本步选择即刻定死，盖牌时刻随机铺在前 2/3 时间里（联机=换真信号）
	_ai_step_choice = _ai_choose(BAN_COUNT, []) if s == Step.BAN else _ai_choose(PICK_COUNT, banned)
	for b in _opp_backs:
		b.queue_free()
	_opp_backs.clear()
	_opp_covered = 0
	_opp_cover_times = []
	for k in 3:
		_opp_cover_times.append(2 + randi() % int(STEP_TIME * 0.66))
	_opp_cover_times.sort()
	_update_opp_progress()
	_sync_step_ui()


## 阶段条装饰：方印图记 + 标题 + 进度方点（仪式时只换文案）。
func _build_phase_deco(ceremony_mode: bool) -> void:
	var old := phase_strip.get_node_or_null("PhaseDeco")
	if old:
		old.free()
	var deco := Control.new()
	deco.name = "PhaseDeco"
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_strip.add_child(deco)
	_dots.clear()

	if step == Step.BAN:
		_dot_color = BAN_RED
		_make_seal(deco, Rect2(204, 8, 38, 38), "禁", BAN_RED)
		phase_label.text = "禁用揭晓 · 双方同时翻开" if ceremony_mode else "禁用阶段 · 盲选 3 名"
	elif step == Step.PICK:
		_dot_color = GOLD_TEXT
		_make_seal(deco, Rect2(204, 8, 38, 38), "选", GOLD_TEXT)
		phase_label.text = "阵容亮相" if ceremony_mode else "出战阶段 · 盲选 3 名 · 允许镜像"
	else:
		phase_label.text = "阵容已定 · 准备开战"

	if not ceremony_mode and step != Step.REVEAL:
		for i in 3:
			var backing := ColorRect.new()
			backing.color = EDGE_OUTER
			backing.position = Vector2(700 + i * 28.0, 20)
			backing.size = Vector2(16, 16)
			deco.add_child(backing)
			var dot := ColorRect.new()
			dot.color = Color(0.22, 0.25, 0.30)
			dot.position = backing.position + Vector2(2, 2)
			dot.size = Vector2(12, 12)
			deco.add_child(dot)
			_dots.append(dot)


# ============================================================
# 手牌交互
# ============================================================

func _on_card_clicked(idx: int) -> void:
	if _ceremony or step == Step.REVEAL:
		return
	if step == Step.PICK and idx in banned:
		return
	if idx in my_sel:
		_remove_from_hand(idx)
	elif my_sel.size() < 3:
		_add_to_hand(idx)


func _add_to_hand(idx: int, instant: bool = false) -> void:
	my_sel.append(idx)
	card_cards[idx].card_state = HeroCard.CardState.PICKED_P1   # 池中留印=已入手
	var slot := my_sel.size() - 1
	if not instant:
		_fly_ghost(card_cards[idx], slot)
	var hc := HERO_CARD_SCENE.instantiate() as HeroCard
	var h := all_heroes[idx]
	hc.hero_id = h.hero_id
	hc.hero_name = h.hero_name
	hc.max_hp = h.max_hp
	hc.portrait_path = h.portrait_path
	hc.card_state = HeroCard.CardState.SELECTED
	hc.scale = Vector2(HAND_SCALE, HAND_SCALE)
	hc.position = HAND_SLOTS[slot]
	hc.set_meta("hero_idx", idx)
	hc.pressed.connect(_on_hand_card_pressed.bind(hc))
	my_band.add_child(hc)
	var bj := hc.get_node_or_null("ButtonJuice") as ButtonJuice
	if bj:
		bj.base_scale = HAND_SCALE
	hand_cards.append(hc)
	if not instant:
		hc.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.22)
		tw.tween_property(hc, "modulate:a", 1.0, 0.12)
	_sync_step_ui()


func _on_hand_card_pressed(hc: HeroCard) -> void:
	if _ceremony:
		return
	_remove_from_hand(hc.get_meta("hero_idx"))


func _remove_from_hand(idx: int) -> void:
	var pos := my_sel.find(idx)
	if pos < 0:
		return
	my_sel.remove_at(pos)
	hand_cards[pos].queue_free()
	hand_cards.remove_at(pos)
	# 余牌左移补位
	for j in hand_cards.size():
		var tw := create_tween()
		tw.tween_property(hand_cards[j], "position", HAND_SLOTS[j], 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	card_cards[idx].card_state = HeroCard.CardState.NORMAL
	_sync_step_ui()


## 选中演出：池卡飞一个头像残影到手牌槽。
func _fly_ghost(card: HeroCard, slot_idx: int) -> void:
	var path := card.portrait_path
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var ghost := TextureRect.new()
	ghost.texture = load(path)
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 50
	add_child(ghost)
	var from := card.get_global_rect()
	ghost.global_position = from.position
	ghost.size = from.size
	var to_pos: Vector2 = my_band.global_position + (HAND_SLOTS[slot_idx] as Vector2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ghost, "global_position", to_pos, 0.26)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ghost, "size", HAND_SLOT_SIZE, 0.26)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(ghost.queue_free)


func _update_all_cards() -> void:
	for i in card_cards.size():
		var card := card_cards[i]
		if i in banned:
			card.card_state = HeroCard.CardState.BANNED
		elif i in my_sel:
			card.card_state = HeroCard.CardState.PICKED_P1
		else:
			card.card_state = HeroCard.CardState.NORMAL


func _sync_step_ui() -> void:
	for i in _dots.size():
		_dots[i].color = _dot_color if i < my_sel.size() else Color(0.22, 0.25, 0.30)
	var verb := "确认盖牌" if step == Step.BAN else "确认出战"
	confirm_btn.text = "%s  %d/3" % [verb, my_sel.size()]
	_set_confirm_enabled(my_sel.size() == 3)


func _set_confirm_enabled(on: bool) -> void:
	confirm_btn.disabled = not on
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	if on:
		confirm_btn.modulate = Color.WHITE
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(confirm_btn, "modulate", Color(1.25, 1.12, 0.8), 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.tween_property(confirm_btn, "modulate", Color.WHITE, 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		confirm_btn.modulate = Color(0.55, 0.55, 0.55)


# ============================================================
# 对手席演出（本地 AI 戏剧 / 联机换真"已提交"信号）
# ============================================================

func _on_timer_tick() -> void:
	timer_seconds -= 1
	_update_timer_label()
	var elapsed := STEP_TIME - timer_seconds
	while _opp_covered < 3 and elapsed >= _opp_cover_times[_opp_covered]:
		_opp_cover_next()
	if timer_seconds <= 0:
		bp_timer.stop()
		_auto_fill()


## 对手"啪"地盖下一张牌背（缩放 pop + 进度更新）。
func _opp_cover_next() -> void:
	if _opp_covered >= 3:
		return
	var back := _make_card_back(opp_band, Rect2(OPP_SLOTS[_opp_covered] as Vector2, OPP_SLOT_SIZE))
	back.pivot_offset = OPP_SLOT_SIZE * 0.5
	back.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(back, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_opp_backs.append(back)
	_opp_covered += 1
	_update_opp_progress()


func _update_opp_progress() -> void:
	opp_progress.text = "对手已盖 %d/3" % _opp_covered


func _update_timer_label() -> void:
	timer_label.text = "剩余 %ds" % maxi(timer_seconds, 0)
	timer_label.add_theme_color_override("font_color",
		Color("#ff4444") if timer_seconds <= 5 else GOLD_TEXT)


## 超时自动补满当前步并确认。
func _auto_fill() -> void:
	while my_sel.size() < 3:
		var pool: Array[int] = []
		for i in all_heroes.size():
			if i in my_sel:
				continue
			if step == Step.PICK and i in banned:
				continue
			pool.append(i)
		if pool.is_empty():
			break
		_add_to_hand(pool[randi() % pool.size()], true)
	if my_sel.size() == 3:
		_on_confirm()


## AI 盲选：从合法池随机 n 个不同（PICK 不排除我方 → 允许镜像）。
func _ai_choose(n: int, exclude: Array[int]) -> Array[int]:
	var pool: Array[int] = []
	for i in all_heroes.size():
		if not i in exclude:
			pool.append(i)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


# ============================================================
# 确认 → 翻牌仪式
# ============================================================

func _on_confirm() -> void:
	if _ceremony:
		return
	match step:
		Step.BAN:
			if my_sel.size() != BAN_COUNT:
				return
			my_bans = my_sel.duplicate()
			ai_bans = _ai_step_choice.duplicate()
			banned = my_bans.duplicate()
			for b in ai_bans:
				if not b in banned:
					banned.append(b)
			_run_ceremony(true)
		Step.PICK:
			if my_sel.size() != PICK_COUNT:
				return
			my_picks = my_sel.duplicate()
			ai_picks = _ai_step_choice.duplicate()
			_run_ceremony(false)
		Step.REVEAL:
			_start_battle()


## 翻牌仪式（共用骨架）：双方 3 张推中央 → 对手牌背翻开 →
## ban=撞车对白闪合并 → 应用并入下一步；pick=王冠+撞波闪+开始战斗。
func _run_ceremony(is_ban: bool) -> void:
	_ceremony = true
	bp_timer.stop()
	timer_label.visible = false
	confirm_btn.visible = false
	_build_phase_deco(true)

	# 对手剩余的牌快速补盖（演出收口）
	while _opp_covered < 3:
		_opp_cover_next()
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(0.45).timeout

	# 牌库暗幕（独立 ColorRect·⛔modulate）
	_pool_dim = ColorRect.new()
	_pool_dim.color = Color(0.015, 0.025, 0.05, 0.0)
	_pool_dim.position = POOL.position
	_pool_dim.size = POOL.size
	pool_area.add_child(_pool_dim)
	create_tween().tween_property(_pool_dim, "color:a", 0.78, 0.3)

	var cer := Control.new()
	cer.name = "CeremonyLayer"
	cer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cer)

	# ⚠ 类型化数组不能接三元表达式结果（demo 踩过坑）
	var mine: Array[int] = my_picks
	var theirs: Array[int] = ai_picks
	if is_ban:
		mine = my_bans
		theirs = ai_bans
	var opp_y := CER_OPP_Y if is_ban else 290.0
	var my_y := CER_MY_Y if is_ban else 590.0

	# 我方手牌推往下排（原手牌隐藏，仪式卡顶替）
	var my_cer: Array[HeroCard] = []
	var opp_cer: Array[HeroCard] = []
	for s in 3:
		var target := Vector2(CER_X0 + s * CER_DX, my_y)
		var start_pos: Vector2 = my_band.global_position + (HAND_SLOTS[s] as Vector2)
		if s < hand_cards.size():
			hand_cards[s].visible = false
		var c := _spawn_cer_card(cer, all_heroes[mine[s]], HeroCard.CardState.PICKED_P1)
		c.scale = Vector2(HAND_SCALE, HAND_SCALE)
		c.position = start_pos
		var tw := create_tween().set_parallel(true)
		tw.tween_property(c, "position", target, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.35)
		my_cer.append(c)

	# 对手牌背推往上排 → 错落翻开
	for s in 3:
		var target := Vector2(CER_X0 + s * CER_DX, opp_y)
		if s < _opp_backs.size():
			_opp_backs[s].visible = false
		var back := _make_card_back(cer, Rect2(opp_band.global_position + (OPP_SLOTS[s] as Vector2), OPP_SLOT_SIZE))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(back, "position", target, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(back, "size", Vector2(130, 158), 0.35)
		await get_tree().create_timer(0.12).timeout
		opp_cer.append(null)   # 占位，翻开后回填
		_flip_open(cer, back, all_heroes[theirs[s]], target, opp_cer, s)
	await get_tree().create_timer(1.0).timeout

	if is_ban:
		await _play_collisions(cer, my_cer, opp_cer)
		await get_tree().create_timer(0.9).timeout
		# 收场：仪式卡淡出 → 应用禁用 → 进 PICK
		var fade := create_tween()
		fade.tween_property(cer, "modulate:a", 0.0, 0.3)
		await fade.finished
		cer.queue_free()
		var dim_out := create_tween()
		dim_out.tween_property(_pool_dim, "color:a", 0.0, 0.3)
		dim_out.tween_callback(_pool_dim.queue_free)
		_ceremony = false
		_enter_step(Step.PICK)
	else:
		# 阵容亮相：王冠 + 撞波闪 + 开始战斗（仪式卡与暗幕保留=对峙画面）
		var crown := TextureRect.new()
		crown.texture = PixelGlyphs.crown_texture()
		crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		crown.stretch_mode = TextureRect.STRETCH_SCALE
		crown.size = Vector2(crown.texture.get_size()) * 3.0
		crown.position = Vector2(960 - crown.size.x * 0.5, 505)
		crown.modulate.a = 0.0
		cer.add_child(crown)
		create_tween().tween_property(crown, "modulate:a", 1.0, 0.3)
		_clash_flash()
		step = Step.REVEAL
		_build_phase_deco(false)
		confirm_btn.text = "开始战斗"
		confirm_btn.visible = true
		_set_confirm_enabled(true)
		_ceremony = false


## 撞车合并：双方同禁的对相向合拢 + 白闪 → 留一张盖「禁」。
func _play_collisions(cer: Control, my_cer: Array[HeroCard], opp_cer: Array) -> void:
	var collide: Array[int] = []
	for h in my_bans:
		if h in ai_bans:
			collide.append(h)
	if collide.is_empty():
		return
	for k in collide.size():
		var hero_idx: int = collide[k]
		var meet := Vector2(960 + (k - (collide.size() - 1) * 0.5) * 260 - 65, 430)
		var mc := my_cer[my_bans.find(hero_idx)]
		var oc: HeroCard = opp_cer[ai_bans.find(hero_idx)]
		var tw := create_tween().set_parallel(true)
		tw.tween_property(mc, "position", meet + Vector2(10, 24), 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if oc:
			tw.tween_property(oc, "position", meet, 0.3)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		# 白闪
		var flash := ColorRect.new()
		flash.color = Color(1, 0.95, 0.75, 0.45)
		flash.position = meet - Vector2(40, 40)
		flash.size = Vector2(220, 240)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cer.add_child(flash)
		create_tween().tween_property(flash, "color:a", 0.0, 0.4)
		if oc:
			oc.queue_free()
		mc.card_state = HeroCard.CardState.BANNED
	var note := "双方同禁「%s」· 并集合一" % all_heroes[collide[0]].hero_name \
		if collide.size() == 1 else "双方同禁 %d 名 · 并集合一" % collide.size()
	var lbl := Label.new()
	lbl.text = note
	FontManager.apply(lbl, 24)
	lbl.add_theme_color_override("font_color", GOLD_TEXT)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	lbl.position = Vector2(660, 700)
	lbl.size = Vector2(600, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cer.add_child(lbl)


## 牌背翻开：横向压缩 → 换英雄正面 → 展开（回填 opp_cer[slot]）。
func _flip_open(cer: Control, back: Control, h: HeroData, at: Vector2, opp_cer: Array, slot: int) -> void:
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(back, "scale:x", 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		back.queue_free()
		var c := _spawn_cer_card(cer, h, HeroCard.CardState.PICKED_P2)
		c.position = at
		c.pivot_offset = Vector2(65, 79)
		c.scale = Vector2(0.0, 1.0)
		opp_cer[slot] = c
		var tw2 := create_tween()
		tw2.tween_property(c, "scale:x", 1.0, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func _spawn_cer_card(cer: Control, h: HeroData, state: int) -> HeroCard:
	var c := HERO_CARD_SCENE.instantiate() as HeroCard
	c.hero_id = h.hero_id
	c.hero_name = h.hero_name
	c.max_hp = h.max_hp
	c.portrait_path = h.portrait_path
	c.card_state = state
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cer.add_child(c)
	return c


## 揭幕撞波闪：全屏白色快闪。
func _clash_flash() -> void:
	var f := ColorRect.new()
	f.color = Color.WHITE
	f.modulate.a = 0.0
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.z_index = 90
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.45, 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)


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
	# 波幕转场（2A）：胜方色波卷入 → 切 battle → 波退去揭幕（battle 多风格 scene 通用）
	TransitionManager.transition_to("res://src/ui/battle_screen.tscn")


# ============================================================
# 入场（C1 翻牌开桌）
# ============================================================

## 开桌：上下席位带滑入 + 牌库按行"翻开"扫过（scale.x 0→0.846 错落=发牌翻面）。
func _play_intro() -> void:
	var opp_home := opp_band.position
	opp_band.position.y -= 150.0
	create_tween().tween_property(opp_band, "position", opp_home, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var my_home := my_band.position
	my_band.position.y += 230.0
	create_tween().tween_property(my_band, "position", my_home, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	phase_strip.modulate.a = 0.0
	create_tween().tween_property(phase_strip, "modulate:a", 1.0, 0.5)

	for i in card_cards.size():
		var card := card_cards[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.001, CARD_SCALE)
		card.modulate.a = 0.0
		var delay := 0.15 + floorf(i / 12.0) * 0.14 + (i % 12) * 0.035
		var ta := create_tween()
		ta.tween_interval(delay)
		ta.tween_property(card, "modulate:a", 1.0, 0.1)
		var tp := create_tween()
		tp.tween_interval(delay)
		tp.tween_property(card, "scale:x", CARD_SCALE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================================================
# 自绘部件（demo 同源）
# ============================================================

## 霜玻璃桌面（B2）：月光青细边 + 极浅暗底。
func _make_frosted(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(0.30, 0.55, 0.85, 0.35)
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(0.01, 0.02, 0.05, 0.45)
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)


## 三牌系竖排系徽（生/肖 两字竖排）。
func _make_section_tag(parent: Control, txt: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = txt.substr(0, 1) + "\n" + txt.substr(1, 1)
	FontManager.apply(lbl, 20)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.88, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	lbl.position = pos
	lbl.size = Vector2(40, 80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)


## 阶段方印（禁=红 / 选=金）。
func _make_seal(parent: Control, r: Rect2, ch: String, col: Color) -> void:
	var backing := ColorRect.new()
	backing.color = Color(col, 0.18)
	backing.position = r.position
	backing.size = r.size
	parent.add_child(backing)
	for line_r: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 2)),
			Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)),
			Rect2(r.position, Vector2(2, r.size.y)),
			Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(col, 0.8)
		ln.position = line_r.position
		ln.size = line_r.size
		parent.add_child(ln)
	var lbl := Label.new()
	lbl.text = ch
	FontManager.apply(lbl, 24)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = r.position + Vector2(0, 7)
	lbl.size = Vector2(r.size.x, 28)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


## 席位暗井槽。
func _make_slot_pit(parent: Control, r: Rect2, hint: String) -> void:
	var backing := ColorRect.new()
	backing.color = Color(0.03, 0.04, 0.06, 0.85)
	backing.position = r.position
	backing.size = r.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backing)
	for line_r: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 2)),
			Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)),
			Rect2(r.position, Vector2(2, r.size.y)),
			Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(EDGE_INNER, 0.6)
		ln.position = line_r.position
		ln.size = line_r.size
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ln)
	if hint != "":
		var lbl := Label.new()
		lbl.text = hint
		FontManager.apply(lbl, 16)
		lbl.add_theme_color_override("font_color", Color(TIN_DIM, 0.5))
		lbl.position = r.position + Vector2(0, r.size.y * 0.5 - 12)
		lbl.size = Vector2(r.size.x, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)


## 王冠牌背（单容器：可整体 tween / 翻面 / 释放）。
func _make_card_back(parent: Control, r: Rect2) -> Control:
	var root := Control.new()
	root.position = r.position
	root.size = r.size
	root.pivot_offset = r.size * 0.5
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(0.065, 0.075, 0.10, 0.97)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 3
	fill.offset_top = 3
	fill.offset_right = -3
	fill.offset_bottom = -3
	root.add_child(fill)
	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = FRAME_SHADER
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", 23.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(f)
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.modulate = Color(1, 1, 1, 0.85)
	crown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(crown)
	return root
