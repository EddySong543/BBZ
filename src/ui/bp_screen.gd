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
# ── 家族换装（2026-07-16 Epic 项⑭·裸件全退役：灰蓝平板/黑方块槽/黑信息板/鎏金 jelly 钮）──
const TOOLTIP_TEX := preload("res://assets/ui/ui_tooltip.png")            # 深框奶油纸（战场悬浮件语言·牌池桌面+信息板）
const CELL_BG_SHADER := preload("res://assets/shaders/canvas_ui_item_cell_bg.gdshader")   # 席位槽格底（图鉴/资料同配方）
const NAV_PLATE_TEX := preload("res://assets/ui/ui_nav_button.png")       # 确认钮=导航钮皮（全游戏导航一语言）
const NAV_PLATE_MARGIN_X := 22
const NAV_PLATE_MARGIN_Y := 20
const TOOLTIP_MARGIN := 20        # ui_tooltip 9-slice 边距（battle _tip_panel 同值）
const SHADOW_TINT := Color(0.10, 0.07, 0.05, 0.38)   # 贴形投影暖黑（牌匾/纸卡同值）
const INK := Color(0.24, 0.19, 0.12)                 # 墨字（奶油纸上·图鉴家族同值）
const OPP_INK := Color("a83a2c")                     # 朱墨（敌方语义·纸上深红=图鉴 HP 同值）
const CELL_FILL := Color("221c15")                   # 槽格底四角=暖深（资料大格同值）
const CELL_CENTER := Color("2e2720")                 # 槽格底中心=略浅暖深
const OPP_FRAME_TINT := Color("c86a5e")              # 敌方槽框=亮赤陶（敌方头像框同族）

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
# （旧朱砂 CINNABAR/CINNABAR_INK 已随鎏金 jelly 钮退役——确认钮墨字见 INK）
# 暗底文字
const WARM_IVORY := Color(0.95, 0.91, 0.80)    # 暖米白（压暗背景）
const WARM_IVORY_DIM := Color(0.80, 0.74, 0.60)  # 暖米白次级
const DARK_WARM := Color(0.09, 0.085, 0.075)   # 近黑暖暗底（保留为暗的大块面）
# （旧确认钮 TIER_GOLD 鎏金 jelly 已退役——2026-07-16 换导航钮皮·全游戏导航一语言）

var all_heroes: Array[HeroData] = []
var _draft_ai := DraftAI.new()       # 对手选人 AI（任务#5·2026-07-03 接入·随机种子）
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
	# B4 启动断言：ROWS 布局容量必须 == 英雄池 size（防"加/减英雄忘同步 ROWS"的静默错位）
	var _rows_cap: int = 0
	for _r in ROWS.size():
		_rows_cap += int(ROWS[_r][1])
	assert(_rows_cap == all_heroes.size(),
		"BP 池布局 ROWS 容量(%d) ≠ 英雄池 size(%d)——加/减英雄后忘同步 ROWS（见 create_launch_pool / ROWS 常量）" % [_rows_cap, all_heroes.size()])
	_setup_ui()
	_build_pool()
	_enter_step(Step.PICK)   # 去 ban：12 池容不下 ban，直接 pick-only（BAN 分支保留为死路）
	_play_intro()


# ============================================================
# 初始化
# ============================================================

func _setup_ui() -> void:
	FontManager.apply(timer_label, 22)
	timer_label.add_theme_color_override("font_color", INK)   # 奶油纸板上→墨字（告急转朱红见 _update_timer_label）

	FontManager.apply($OppBand/OppName, 22)
	$OppBand/OppName.add_theme_color_override("font_color", Color("#e0938c"))   # 敌方暖红（暗底）
	FontManager.apply($OppBand/OppRank, 14)
	$OppBand/OppRank.add_theme_color_override("font_color", Color(WARM_IVORY_DIM, 0.8))
	FontManager.apply(opp_progress, 16)
	opp_progress.add_theme_color_override("font_color", OPP_INK)      # 敌方语义·奶油纸上→朱墨
	FontManager.apply($MyBand/MyName, 22)
	$MyBand/MyName.add_theme_color_override("font_color", Color("#9cc0e8"))     # 我方蓝（阵营功能色·勿改）
	FontManager.apply($MyBand/MyHint, 14)
	$MyBand/MyHint.add_theme_color_override("font_color", Color(WARM_IVORY_DIM, 0.8))

	# 席位槽底（对手 3 + 手牌 3）：格底 shader+暖骨像素框（黑方块+发丝线退役）·敌方槽框=赤陶
	for p in OPP_SLOTS:
		_make_slot_pit(opp_band, Rect2(p, OPP_SLOT_SIZE), "··", true)
	for p in HAND_SLOTS:
		_make_slot_pit(my_band, Rect2(p, HAND_SLOT_SIZE), "空", false)

	# 右上信息底板（2026-06-12 Eddy：裸文字格格不入）——深框奶油纸小板（悬停框同皮·
	# 战场悬浮件语言），与下方确认钮同列同宽（360 @ x1460）成上下呼应；文字 z 提到板上层。
	_make_paper_panel(opp_band, Rect2(1460, 50, 360, 90))
	opp_progress.z_index = 1
	timer_label.z_index = 1

	# 确认钮：导航钮皮+墨字（全游戏导航一语言·旧鎏金 jelly 退役）
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		confirm_btn.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	FontManager.apply_btn(confirm_btn, 26)
	confirm_btn.add_theme_color_override("font_color", INK)
	confirm_btn.add_theme_color_override("font_disabled_color", Color(INK, 0.55))   # ⚠ 禁用态走这个主题色·不覆盖=默认灰字洗白
	var plate := NinePatchRect.new()
	plate.name = "Plate"
	plate.texture = NAV_PLATE_TEX
	plate.patch_margin_left = NAV_PLATE_MARGIN_X
	plate.patch_margin_right = NAV_PLATE_MARGIN_X
	plate.patch_margin_top = NAV_PLATE_MARGIN_Y
	plate.patch_margin_bottom = NAV_PLATE_MARGIN_Y
	plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.show_behind_parent = true
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ⚠ 缺这行=吞点击
	confirm_btn.add_child(plate)
	confirm_btn.pressed.connect(_on_confirm)
	var bj := ButtonJuice.new()
	bj.name = "ButtonJuice"
	confirm_btn.add_child(bj)

	bp_timer.one_shot = false
	bp_timer.timeout.connect(_on_timer_tick)


## 牌库摊开：奶油纸桌面（深框浅芯·悬停框同皮）+ 24 卡六列四行（系徽/分隔线已撤·2026-06-11 Eddy）。
func _build_pool() -> void:
	_make_pool_paper(pool_area, POOL)
	_build_role_legend(pool_area)
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
			card.ink_name = true   # 池卡摆在奶油纸桌面→墨字名（组件 opt-in·手牌/仪式卡在暗带保持白字）
			card.team_role = h.team_role       # 组队三分类框（进攻红/防守蓝/经济金·2026-07-18）
			card.dim_when_picked = true        # 已入手留印=头像压灰（框色让给类型后的新留印语言）
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
	title.text = tr("禁 用 阶 段") if is_ban else "出 战 阶 段"
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
	sub.text = tr("禁用 3 名英雄") if is_ban else "选择 3 名英雄"
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
	hc.team_role = h.team_role   # 手牌同框：一眼看队伍三色配比
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
	confirm_btn.text = tr("确认选择  %d/3") % my_sel.size()
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
		confirm_btn.modulate = Color(0.78, 0.76, 0.72)   # 禁用=轻暖压暗（0.55 深灰把导航皮压成泥·换皮后调档）


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
	opp_progress.text = tr("敌方已选 %d/3") % _opp_covered


func _update_timer_label() -> void:
	timer_label.text = tr("剩余 %ds") % maxi(timer_seconds, 0)
	timer_label.add_theme_color_override("font_color",
		BAN_RED if timer_seconds <= 5 else INK)   # 奶油纸板上：墨字·告急转朱红


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


## AI 盲选（2026-07-03·任务#5 接入 DraftAI·取代纯随机）：
## BAN=偏高血耐久威胁（带温度）；PICK=按坦克/灵活/脆皮血量曲线组均衡队（排除 banned·允许镜像·温度保覆盖）。
## 与 sim（run_sim --draft 1）同一套选人 AI → 试玩对手与平衡数据同源。
func _ai_choose(n: int, exclude: Array[int]) -> Array[int]:
	var picks: Array = _draft_ai.choose_bans(all_heroes, n) if step == Step.BAN \
			else _draft_ai.choose_picks(all_heroes, exclude, n)
	var out: Array[int] = []
	for i in picks:
		out.append(int(i))
	# 兜底（池异常小等极端情况凑不满 n）：随机补足，保证下游 3 张牌背演出不缺位。
	while out.size() < n and out.size() < all_heroes.size():
		var r := randi() % all_heroes.size()
		if not r in out and not r in exclude:
			out.append(r)
	return out


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
		confirm_btn.text = tr("开始战斗")
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
	var note := tr("双方同禁「%s」") % tr(all_heroes[collide[0]].hero_name) \
		if collide.size() == 1 else tr("双方同禁 %d 名") % collide.size()
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
	c.team_role = h.team_role   # 仪式卡同框（归属靠左右列位+名字色·框色留给类型）
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
	TransitionManager.transition_to("res://src/ui/battle_screen1.tscn")


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

## 牌库桌面（2026-07-16 家族换装）：深框奶油纸大板（ui_tooltip 9-slice·战场悬浮件语言）
## + 贴形投影（牌匾同手法·压在波流上给纵深）。旧霜玻璃灰蓝平板退役。
func _make_pool_paper(parent: Control, r: Rect2) -> void:
	var shadow := _tooltip_patch()
	shadow.position = r.position + Vector2(6, 8)
	shadow.size = r.size
	shadow.modulate = SHADOW_TINT
	parent.add_child(shadow)
	var panel := _tooltip_patch()
	panel.position = r.position
	panel.size = r.size
	parent.add_child(panel)


## 三分类图例（2026-07-18 组队标签线）：池面左空带竖排三条=框色小样+墨字类型名，
## 教玩家「框色=英雄类型」（战斗四色版同源：攻红/防蓝/攒金）。
## ⚠「进攻/防守/经济」为占位命名（Eddy 后续定稿）——改名动这里 + hero_card.TYPE_FRAME_PATH 键 + .tres 值。
func _build_role_legend(parent: Control) -> void:
	var entries: Array = [
		["进攻", "res://assets/ui/hero_avatar_frame_atk.png"],
		["防守", "res://assets/ui/hero_avatar_frame_def.png"],
		["经济", "res://assets/ui/hero_avatar_frame_econ.png"],
	]
	for i in entries.size():
		var y := 448.0 + i * 64.0   # 三条竖排（448-616）≈ 池面(210-874)垂直居中
		var icon := TextureRect.new()
		icon.texture = load(entries[i][1])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.position = Vector2(352, y)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(icon)
		var lbl := Label.new()
		lbl.text = tr(entries[i][0])
		FontManager.apply(lbl, 16)
		lbl.add_theme_color_override("font_color", INK)
		lbl.position = Vector2(404, y + 10.0)
		lbl.size = Vector2(120, 22)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(lbl)


## 深框奶油纸小板（右上信息板用·悬停框同皮同边距）。
func _make_paper_panel(parent: Control, r: Rect2) -> void:
	var panel := _tooltip_patch()
	panel.position = r.position
	panel.size = r.size
	parent.add_child(panel)


func _tooltip_patch() -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = TOOLTIP_TEX
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.patch_margin_left = TOOLTIP_MARGIN
	p.patch_margin_right = TOOLTIP_MARGIN
	p.patch_margin_top = TOOLTIP_MARGIN
	p.patch_margin_bottom = TOOLTIP_MARGIN
	p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE   # 中段平铺防颗粒拉伸
	p.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 席位槽（2026-07-16 家族换装）：格底 shader（图鉴/资料同配方·暖深两档）+ 暖骨像素框
## （§2.1 通用配方·敌方槽框转赤陶=阵营语义）。旧纯黑方块+发丝线退役。
func _make_slot_pit(parent: Control, r: Rect2, hint: String, is_opp: bool) -> void:
	var cell := ColorRect.new()
	cell.color = Color.WHITE
	cell.position = r.position
	cell.size = r.size
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = CELL_BG_SHADER
	cm.set_shader_parameter("fill_color", CELL_FILL)
	cm.set_shader_parameter("inner_color", CELL_CENTER)
	cm.set_shader_parameter("center_glow", 1.0)
	cm.set_shader_parameter("corner_radius", 0.14)
	cm.set_shader_parameter("pixel_grid", r.size.x / 6.0)
	cm.set_shader_parameter("cloud_on", 0.0)
	cell.material = cm
	parent.add_child(cell)
	var frame := ColorRect.new()
	frame.color = Color.WHITE
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = FRAME_SHADER
	fm.set_shader_parameter("edge_outer", EDGE_OUTER)
	fm.set_shader_parameter("edge_mid", OPP_FRAME_TINT if is_opp else EDGE_MID)   # 敌赤陶/我暖骨
	fm.set_shader_parameter("edge_inner", Color(OPP_FRAME_TINT, 1.0).darkened(0.5) if is_opp else EDGE_INNER)
	fm.set_shader_parameter("pixel_grid", 24.0)
	fm.set_shader_parameter("border_px", 2.0)
	fm.set_shader_parameter("noise_amt", 0.05)
	fm.set_shader_parameter("light_amount", 0.13)
	fm.set_shader_parameter("aspect", r.size.x / maxf(r.size.y, 1.0))   # ⚠ 长矩形必设 aspect
	fm.set_shader_parameter("corner_radius", 0.14)
	frame.material = fm
	parent.add_child(frame)
	if hint != "":
		var lbl := Label.new()
		lbl.text = tr(hint)
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
