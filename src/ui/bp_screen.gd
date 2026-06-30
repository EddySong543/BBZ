extends Control

## BP 选人屏 = 「双席牌局」（第二轮重构 2026-06-11·Eddy 批；同日优化批：席位上下对齐/
## 牌库均匀网格去系徽/阶段条撤掉改屏幕中央宣告/去全屏白闪）。
## BP 的本质是双方同时盲选 = 这局牌的第一手 → 界面从"商店货架"改为第一人称对坐牌桌。
## 纵深三层：对手席(顶带·你选择期间对手随机时刻盖下牌背=实时压力，本地 AI 演出/联机真信号)
##           牌库摊开(中·六列固定网格·首发 15=6+6+3·全池一屏无滚动)
##           我的手牌(底带·点池卡飞入 3 大牌位·再点退回·确认盖牌金钮)。
## 上下席对齐（2026-06-12 Eddy 反馈返工）：两条席位带同高 190、内容以带中心垂直居中镜像；
##             对手槽与手牌槽**同规格同坐标**（130×158 @ x 770/950/1130·卡原生尺寸不缩放——
##             缩放+ButtonJuice 中心 pivot 会让卡整体偏左上错位，已废）；
##             头像/名字列同 x（240/334），右列=信息/行动列（同 1460-1820）。
## 阶段提示 = 进入 BAN/PICK 时屏幕中央宣告横带（大字+副注，1.4s 自动退场），无常驻阶段条。
## 两次翻牌仪式：禁用揭晓=双方 3 张推中央同时翻开+撞车对原地标红✕（⛔合拢合并动画）；
##              出战亮相=3v3 对扣翻开对峙+开始战斗（⛔全屏白闪/⛔中央王冠均被 Eddy 否决，
##              中央空位预留联机加载动画）。
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

# ── 牌库网格（六列固定网格·首发 15 = 6+6+3 三行·对手席加高后整体下移 40）──
# 池高 664 原为 46 池四行(12/12/12/10)预留，六列三行绰绰有余（末行底 y826 < 池底 874）。
const POOL := Rect2(200, 210, 1520, 664)
const CARD_SCALE := 0.846          # 130×158 → 110×134
const STEP_X := 121.0
const ROW_H := 146.0
const ROW_Y0 := 256.0   # 4 行居中进池面板(210-874·原为"46 卡均匀四行"设计)；原 400 为 3 行(18 卡)底重布局
# [起始索引, 张数, 行起点x]；末值=该行左缘。六列固定网格：满行 6 卡居中(x0=602)，
# 每行 [起始索引, 卡数, x0]。**6 列锁定（Eddy 2026-06-24·与图鉴一致）**：首发 24 = 6×4 满四行（x0=602=6 卡居中起点·对齐池心 960）。
# 配 ROW_Y0=256 把 4 行居中进池面板（210-874·容得下）。
const ROWS: Array = [[0, 6, 602.0], [6, 6, 602.0], [12, 6, 602.0], [18, 6, 602.0]]

# ── 席位槽（OppBand / MyBand 内相对坐标）──
# 双方槽**同规格同坐标**（卡原生 130×158·x 770/950/1130）：上下严格对齐 + 手牌卡免缩放
# （HAND_SCALE 已废——缩放配合 ButtonJuice 中心 pivot 会让卡相对槽底偏左上）。
const OPP_SLOTS: Array = [Vector2(770, 16), Vector2(950, 16), Vector2(1130, 16)]
const OPP_SLOT_SIZE := Vector2(130, 158)
const HAND_SLOTS: Array = [Vector2(770, 16), Vector2(950, 16), Vector2(1130, 16)]
const HAND_SLOT_SIZE := Vector2(130, 158)

# ── 仪式排位（全局坐标）──
const CER_X0 := 700.0
const CER_DX := 200.0
const CER_OPP_Y := 320.0
const CER_MY_Y := 560.0

# 配色「典籍朱印」（2026-06-13 全局换肤）：暖羊皮 + 墨线 + 金箔 + 朱印。
# 暗底上用「暖骨边」中性框（mid/inner/outer），不再用冷钢灰；标题金、按钮朱砂。
const EDGE_OUTER := Color(0.05, 0.045, 0.04)   # 暖骨外轮廓（近黑暖）
const EDGE_MID := Color(0.70, 0.64, 0.52)      # 暖骨中段（替原冷灰）
const EDGE_INNER := Color(0.42, 0.36, 0.26)    # 暖骨内段（替原冷灰）
const GOLD_TEXT := Color("#f4c84b")            # 金字标题（暗底，节制）
const BAN_RED := Color("#d24a44")              # 敌方红（功能色，勿改）
const CINNABAR := Color(0.74, 0.24, 0.18)      # 朱砂（主行动/确认）
const CINNABAR_INK := Color(0.52, 0.18, 0.12)  # 朱砂墨（朱砂按钮的字）
# 暗底文字
const WARM_IVORY := Color(0.95, 0.91, 0.80)    # 暖米白（压暗背景）
const WARM_IVORY_DIM := Color(0.80, 0.74, 0.60)  # 暖米白次级
const DARK_WARM := Color(0.09, 0.085, 0.075)   # 近黑暖暗底（保留为暗的大块面）
# 确认钮 = 鎏金羊皮主行动钮（2026-06-13 回修：全朱砂大红填充读成危险/取消；主 CTA 应是
# "鎏金"——与主菜单金色匹配钮同级。羊皮提亮底 + 金箔内边 + 暗金外边，字用朱砂墨点睛）。
const TIER_GOLD := {
	"fill_top": Color(0.95, 0.90, 0.76), "fill_bottom": Color(0.89, 0.82, 0.67),
	"edge_inner": Color(0.97, 0.85, 0.48), "edge_outer": Color(0.40, 0.28, 0.10),
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
@onready var timer_label: Label = $OppBand/TimerLabel
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


func _ready() -> void:
	all_heroes = HeroData.create_launch_pool(HERO_DATA_DIR)   # 首发 24（12 生肖 + 黑暗全 12·子鼠…亥猪 h01-h24）
	_setup_ui()
	_build_pool()
	_enter_step(Step.PICK)   # 去 ban：12 池容不下 ban，直接 pick-only（BAN 分支保留为死路）
	_play_intro()


# ============================================================
# 初始化
# ============================================================

func _setup_ui() -> void:
	FontManager.apply(timer_label, 22)
	timer_label.add_theme_color_override("font_color", GOLD_TEXT)

	FontManager.apply($OppBand/OppName, 22)
	$OppBand/OppName.add_theme_color_override("font_color", Color("#e0938c"))   # 敌方暖红（暗底）
	FontManager.apply($OppBand/OppRank, 14)
	$OppBand/OppRank.add_theme_color_override("font_color", Color(WARM_IVORY_DIM, 0.8))
	FontManager.apply(opp_progress, 16)
	opp_progress.add_theme_color_override("font_color", Color("#e0938c"))      # 敌方暖红（暗底）
	FontManager.apply($MyBand/MyName, 22)
	$MyBand/MyName.add_theme_color_override("font_color", Color("#9cc0e8"))     # 我方蓝（阵营功能色·勿改）
	FontManager.apply($MyBand/MyHint, 14)
	$MyBand/MyHint.add_theme_color_override("font_color", Color(WARM_IVORY_DIM, 0.8))

	# 席位槽底（对手 3 + 手牌 3）
	for p in OPP_SLOTS:
		_make_slot_pit(opp_band, Rect2(p, OPP_SLOT_SIZE), "··")
	for p in HAND_SLOTS:
		_make_slot_pit(my_band, Rect2(p, HAND_SLOT_SIZE), "空")

	# 右上信息底板（2026-06-12 Eddy：裸文字格格不入）——槽位暗井同语言，
	# 与下方确认钮同列同宽（360 @ x1460）成上下呼应；文字 z 提到板上层。
	_make_slot_pit(opp_band, Rect2(1460, 50, 360, 90), "")
	opp_progress.z_index = 1
	timer_label.z_index = 1

	# 确认钮：鎏金羊皮大钮（主菜单匹配钮同级）·朱砂墨字（压在浅金羊皮上）
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		confirm_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(confirm_btn, 26)
	confirm_btn.add_theme_color_override("font_color", CINNABAR_INK)
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
	mat.set_shader_parameter("noise_amt", 0.08)   # 纸感
	mat.set_shader_parameter("wear", 0.24)         # 纸感
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


## 牌库摊开：霜玻璃桌面 + 46 卡均匀四行（系徽/分隔线已撤——正常排列，2026-06-11 Eddy）。
func _build_pool() -> void:
	_make_frosted(pool_area, POOL)
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
			card.compensate_name_scale(CARD_SCALE)   # 名字整数像素渲染（防糊）
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
	_play_phase_announce()


## 阶段宣告（替代常驻阶段条，2026-06-11 Eddy）：进入 BAN/PICK 时屏幕中央
## 暗带展开 + 大字弹入 + 副注浮现，停留约 1s 自动退场。不锁输入（纯演出层）。
func _play_phase_announce() -> void:
	var is_ban := step == Step.BAN
	var theme_col := BAN_RED if is_ban else GOLD_TEXT
	var layer := Control.new()
	layer.name = "PhaseAnnounce"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 80
	add_child(layer)

	# 中央暗带（全宽·从中线纵向展开）：busy 牌库上抬起一条安静的台面给大字
	var band := ColorRect.new()
	band.color = Color(0.09, 0.085, 0.075, 0.7)   # 近黑暖暗底（替原深蓝）
	band.position = Vector2(0, 462)
	band.size = Vector2(1920, 156)
	band.pivot_offset = band.size * 0.5
	band.scale = Vector2(1.0, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(band)
	var edge_top := ColorRect.new()
	edge_top.color = Color(theme_col, 0.55)
	edge_top.position = Vector2(0, 462)
	edge_top.size = Vector2(1920, 2)
	layer.add_child(edge_top)
	var edge_bot := ColorRect.new()
	edge_bot.color = Color(theme_col, 0.55)
	edge_bot.position = Vector2(0, 616)
	edge_bot.size = Vector2(1920, 2)
	layer.add_child(edge_bot)

	var title := Label.new()
	title.text = "禁 用 阶 段" if is_ban else "出 战 阶 段"
	FontManager.apply(title, 52)
	title.add_theme_color_override("font_color", theme_col)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	title.position = Vector2(0, 478)
	title.size = Vector2(1920, 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.pivot_offset = Vector2(960, 32)
	layer.add_child(title)

	var sub := Label.new()
	sub.text = "禁用 3 名英雄" if is_ban else "选择 3 名英雄"
	FontManager.apply(sub, 20)
	sub.add_theme_color_override("font_color", Color(WARM_IVORY, 0.92))
	sub.add_theme_constant_override("outline_size", 4)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
	sub.position = Vector2(0, 552)
	sub.size = Vector2(1920, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(sub)

	# 入场：带展开 → 大字砸落弹定（boot 之王同语言）→ 副注浮现
	for c: Control in [edge_top, edge_bot, title, sub]:
		c.modulate.a = 0.0
	var tb := create_tween()
	tb.tween_property(band, "scale:y", 1.0, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tb.parallel().tween_property(edge_top, "modulate:a", 1.0, 0.14)
	tb.parallel().tween_property(edge_bot, "modulate:a", 1.0, 0.14)
	title.scale = Vector2(1.6, 1.6)
	var tt := create_tween()
	tt.tween_interval(0.10)
	tt.tween_callback(func() -> void: title.modulate.a = 1.0)
	tt.tween_property(title, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var ts := create_tween()
	ts.tween_interval(0.26)
	ts.tween_property(sub, "modulate:a", 1.0, 0.15)
	# 停留后整层淡出 + 带收拢
	var out := create_tween()
	out.tween_interval(1.35)
	out.tween_property(layer, "modulate:a", 0.0, 0.22)
	out.parallel().tween_property(band, "scale:y", 0.0, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_callback(layer.queue_free)


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
	hc.position = HAND_SLOTS[slot]
	hc.set_meta("hero_idx", idx)
	hc.pressed.connect(_on_hand_card_pressed.bind(hc))
	my_band.add_child(hc)
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
	# BAN/PICK 统一「确认选择」（2026-06-12 Eddy）；REVEAL 的「开始战斗」另设不走此处。
	confirm_btn.text = "确认选择  %d/3" % my_sel.size()
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
	opp_progress.text = "敌方已选 %d/3" % _opp_covered


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
## ban=撞车对原地标红✕ → 应用并入下一步；pick=对峙亮相+开始战斗。
func _run_ceremony(is_ban: bool) -> void:
	_ceremony = true
	bp_timer.stop()
	timer_label.visible = false
	confirm_btn.visible = false

	# 对手剩余的牌快速补盖（演出收口）
	while _opp_covered < 3:
		_opp_cover_next()
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(0.45).timeout

	# 牌库暗幕（独立 ColorRect·⛔modulate）
	_pool_dim = ColorRect.new()
	_pool_dim.color = Color(0.09, 0.085, 0.075, 0.0)   # 近黑暖压暗幕（替原深蓝）
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
		c.position = start_pos
		var tw := create_tween()
		tw.tween_property(c, "position", target, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		my_cer.append(c)

	# 对手牌背推往上排 → 错落翻开
	for s in 3:
		var target := Vector2(CER_X0 + s * CER_DX, opp_y)
		if s < _opp_backs.size():
			_opp_backs[s].visible = false
		var back := _make_card_back(cer, Rect2(opp_band.global_position + (OPP_SLOTS[s] as Vector2), OPP_SLOT_SIZE))
		var tw := create_tween()
		tw.tween_property(back, "position", target, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await get_tree().create_timer(0.12).timeout
		opp_cer.append(null)   # 占位，翻开后回填
		_flip_open(cer, back, all_heroes[theirs[s]], target, opp_cer, s)
	await get_tree().create_timer(1.0).timeout

	if is_ban:
		_show_collisions(cer, my_cer, opp_cer)
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
		# 阵容亮相：3v3 对扣翻开对峙 + 开始战斗（仪式卡与暗幕保留=对峙画面）。
		# ⛔全屏白闪已删（2026-06-11）；⛔中央王冠砸落已删（2026-06-12 Eddy）——
		# 此时刻的中央空位预留给**联机「等待对手 / 加载」动画**（对峙静帧上叠
		# 加载指示，完成后接 _start_battle；本地版对峙+金钮自明，无需装饰）。
		step = Step.REVEAL
		confirm_btn.text = "开始战斗"
		confirm_btn.visible = true
		_set_confirm_enabled(true)
		_ceremony = false


## 撞车展示（2026-06-12 Eddy：⛔归一到中间的合拢动画——只需展示）：
## 双方同禁的卡**原地**转 BANNED（大红✕当场盖上）+ 中线金字说明，不再移动/合并/闪光。
func _show_collisions(cer: Control, my_cer: Array[HeroCard], opp_cer: Array) -> void:
	var collide: Array[int] = []
	for h in my_bans:
		if h in ai_bans:
			collide.append(h)
	if collide.is_empty():
		return
	for hero_idx in collide:
		my_cer[my_bans.find(hero_idx)].card_state = HeroCard.CardState.BANNED
		var oc: HeroCard = opp_cer[ai_bans.find(hero_idx)]
		if oc:
			oc.card_state = HeroCard.CardState.BANNED
	var note := "双方同禁「%s」" % all_heroes[collide[0]].hero_name \
		if collide.size() == 1 else "双方同禁 %d 名" % collide.size()
	var lbl := Label.new()
	lbl.text = note
	FontManager.apply(lbl, 24)
	lbl.add_theme_color_override("font_color", GOLD_TEXT)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	lbl.position = Vector2(660, 498)
	lbl.size = Vector2(600, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate.a = 0.0
	cer.add_child(lbl)
	create_tween().tween_property(lbl, "modulate:a", 1.0, 0.2)


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
	opp_band.position.y -= 210.0
	create_tween().tween_property(opp_band, "position", opp_home, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var my_home := my_band.position
	my_band.position.y += 200.0
	create_tween().tween_property(my_band, "position", my_home, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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

## 牌库桌面（B2）：暖骨细边 + 近黑暖暗底（替原月光青+深蓝；大块面保持暗，别抢立绘）。
func _make_frosted(parent: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(EDGE_MID, 0.35)
	border.position = r.position
	border.size = r.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(DARK_WARM, 0.45)
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)


## 席位暗井槽（近黑暖底 + 暖骨内线 + 暖米白次级提示字）。
func _make_slot_pit(parent: Control, r: Rect2, hint: String) -> void:
	var backing := ColorRect.new()
	backing.color = Color(DARK_WARM, 0.85)
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
		lbl.add_theme_color_override("font_color", Color(WARM_IVORY_DIM, 0.55))
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
	fill.color = Color(0.13, 0.10, 0.07, 0.97)   # 深羊皮书脊衬底（替原蓝黑牌背）
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
	# 2026-06-11 2A 去科幻感（与 ModeCard 同步）：撤月光青镀线+竹节，仅留方向光体积感
	m.set_shader_parameter("light_amount", 0.13)
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
