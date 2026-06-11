extends Node

## BP「双席牌局」效果图 demo（第二轮重构方案·第一人称对坐牌局·不动真实场景）：
##   godot --path . res://tools/bp_duel_demo.tscn
## 纵深三层：对手席(顶·实时盖牌) / 牌库摊开(中·生肖|塔罗|星座三牌系分区) / 我的手牌(底)。
## 四张：ban(对手已盖2·手牌2/3) / banreveal(禁用揭晓·撞车合并) / pick(被禁封印·手牌2/3)
##       / reveal(3v3 对扣翻开对峙)。输出 D:/Game/BoBoZan/bp2_demo_*.png

const FRAME_SHADER := "res://assets/shaders/canvas_ui_pixel_frame.gdshader"
const JELLY_SHADER := "res://assets/shaders/canvas_button_jelly.gdshader"
const HERO_CARD := "res://src/ui/components/hero_card.tscn"

const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const EDGE_MID := Color(0.65, 0.67, 0.71)
const EDGE_INNER := Color(0.34, 0.36, 0.39)
const GOLD_MID := Color(0.79, 0.65, 0.29)
const GOLD_INNER := Color(0.45, 0.35, 0.15)
const GOLD_TEXT := Color("#f4c84b")
const BAN_RED := Color("#d24a44")
const P1_BLUE := Color("#3f86c8")
const TIN := Color("#c9d2dc")
const TIN_DIM := Color("#aab4c4")

const TIER_GOLD := {
	"fill_top": Color(0.64, 0.46, 0.17), "fill_bottom": Color(0.33, 0.21, 0.07),
	"edge_inner": Color(0.98, 0.82, 0.42), "edge_outer": Color(0.12, 0.08, 0.03),
}

# 牌库网格：4 行（生肖12 / 塔罗11+11 / 星座12），卡缩放 0.846 → 110×134，全池一屏。
const POOL := Rect2(200, 222, 1520, 612)
const CARD_SCALE := 0.846
const STEP_X := 121.0
const ROW_H := 146.0
const ROW_X12 := 270.0
const ROW_X11 := 330.0
const ROW_Y0 := 240.0

var heroes: Array[HeroData] = []


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	add_child((load("res://src/ui/scenes/menu_background.tscn") as PackedScene).instantiate())
	heroes = HeroData.create_pool_heroes()

	for state in ["ban", "banreveal", "pick", "reveal"]:
		var layer := _build_state(state)
		add_child(layer)
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var path := "D:/Game/BoBoZan/bp2_demo_%s.png" % state
		get_viewport().get_texture().get_image().save_png(path)
		print("saved: ", path)
		layer.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _build_state(state: String) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	var banned: Array[int] = [2, 7, 14, 20, 26, 32]
	var my_hand: Array[int] = [5, 21]              # 手牌已入 2 张
	var ceremony := state == "banreveal" or state == "reveal"

	# ── 中层：牌库摊开（三牌系分区）──
	var pool_layer := Control.new()
	layer.add_child(pool_layer)
	_frosted(pool_layer, POOL)
	_section_tag(pool_layer, "生肖", Vector2(214, ROW_Y0 + 30))
	_section_tag(pool_layer, "塔罗", Vector2(214, ROW_Y0 + ROW_H * 1.5 + 10))
	_section_tag(pool_layer, "星座", Vector2(214, ROW_Y0 + ROW_H * 3.0 + 30))
	for ln_y in [ROW_Y0 + ROW_H - 8.0, ROW_Y0 + ROW_H * 3.0 - 8.0]:
		var ln := ColorRect.new()
		ln.color = Color(0.30, 0.55, 0.85, 0.18)
		ln.position = Vector2(214, ln_y)
		ln.size = Vector2(1492, 1)
		pool_layer.add_child(ln)

	var rows: Array = [
		[0, 12, ROW_X12], [12, 11, ROW_X11], [23, 11, ROW_X11], [34, 12, ROW_X12],
	]
	for r in rows.size():
		var start: int = rows[r][0]
		var count: int = rows[r][1]
		var x0: float = rows[r][2]
		for c in count:
			var i: int = start + c
			var card := (load(HERO_CARD) as PackedScene).instantiate() as HeroCard
			card.hero_id = heroes[i].hero_id
			card.hero_name = heroes[i].hero_name
			card.max_hp = heroes[i].max_hp
			card.portrait_path = heroes[i].portrait_path
			card.scale = Vector2(CARD_SCALE, CARD_SCALE)
			card.position = Vector2(x0 + c * STEP_X, ROW_Y0 + r * ROW_H)
			if state != "ban" and banned.has(i):
				card.card_state = HeroCard.CardState.BANNED
			elif not ceremony and my_hand.has(i):
				card.card_state = HeroCard.CardState.PICKED_P1   # 已入手 → 池中留蓝印
			pool_layer.add_child(card)
	if ceremony:
		# 仪式时刻：牌库上盖暗幕（不用 modulate——会把霜玻璃衬底也压黑、反而让亮波透出）
		var dimmer := ColorRect.new()
		dimmer.color = Color(0.015, 0.025, 0.05, 0.78)
		dimmer.position = POOL.position
		dimmer.size = POOL.size
		layer.add_child(dimmer)

	# ── 阶段条（牌库上缘·紧凑）──
	match state:
		"ban":
			_seal_glyph(layer, Rect2(204, 168, 38, 38), "禁", BAN_RED)
			_text(layer, "禁用阶段 · 盲选 3 名", 24, Color("#e8edf4"), Vector2(256, 172), 400)
			_dots(layer, Vector2(530, 180), 2, BAN_RED)
			_text(layer, "剩余 29s", 22, GOLD_TEXT, Vector2(1560, 174), 150, HORIZONTAL_ALIGNMENT_RIGHT)
		"banreveal":
			_seal_glyph(layer, Rect2(204, 168, 38, 38), "禁", BAN_RED)
			_text(layer, "禁用揭晓 · 双方同时翻开", 24, GOLD_TEXT, Vector2(256, 172), 460)
		"pick":
			_seal_glyph(layer, Rect2(204, 168, 38, 38), "选", GOLD_TEXT)
			_text(layer, "出战阶段 · 盲选 3 名 · 允许镜像", 24, Color("#e8edf4"), Vector2(256, 172), 520)
			_dots(layer, Vector2(650, 180), 2, GOLD_TEXT)
			_text(layer, "剩余 17s", 22, GOLD_TEXT, Vector2(1560, 174), 150, HORIZONTAL_ALIGNMENT_RIGHT)
		"reveal":
			_text(layer, "阵容亮相", 24, GOLD_TEXT, Vector2(256, 172), 300)

	# ── 顶层：对手席 ──
	var top_band := ColorRect.new()
	top_band.color = Color(0.01, 0.02, 0.05, 0.55)
	top_band.size = Vector2(1920, 150)
	layer.add_child(top_band)
	var top_edge := ColorRect.new()
	top_edge.color = Color(0.30, 0.55, 0.85, 0.30)
	top_edge.position = Vector2(0, 148)
	top_edge.size = Vector2(1920, 2)
	layer.add_child(top_edge)
	_pixel_frame(layer, Rect2(600, 36, 76, 76), 19.0)
	_portrait(layer, heroes[8].portrait_path, Rect2(607, 43, 62, 62))
	_text(layer, "对手", 22, Color("#e8a09c"), Vector2(694, 48), 200)
	_text(layer, "段位 · 未定级", 14, Color(TIN_DIM, 0.7), Vector2(694, 82), 200)
	# 对手三牌位：实时盖牌（啪、啪——第三张还没盖）
	var opp_covered := 2
	if state == "pick":
		opp_covered = 1
	for s in 3:
		var r := Rect2(980 + s * 120.0, 16, 92, 116)
		if ceremony:
			_empty_slot(layer, r, "")
		elif s < opp_covered:
			_card_back(layer, r)
		else:
			_empty_slot(layer, r, "··")
	if not ceremony:
		_text(layer, "对手已盖 %d/3" % opp_covered, 16, Color("#e8a09c"),
			Vector2(1380, 60), 220)

	# ── 底层：我的席位（手牌+确认）──
	var bot_band := ColorRect.new()
	bot_band.color = Color(0.01, 0.02, 0.05, 0.55)
	bot_band.position = Vector2(0, 850)
	bot_band.size = Vector2(1920, 230)
	layer.add_child(bot_band)
	var bot_edge := ColorRect.new()
	bot_edge.color = Color(0.30, 0.55, 0.85, 0.30)
	bot_edge.position = Vector2(0, 850)
	bot_edge.size = Vector2(1920, 2)
	layer.add_child(bot_edge)
	_pixel_frame(layer, Rect2(240, 884, 76, 76), 19.0)
	_portrait(layer, heroes[0].portrait_path, Rect2(247, 891, 62, 62))
	_text(layer, "Eddy", 22, Color("#9cc0e8"), Vector2(334, 896), 200)
	_text(layer, "我的手牌", 14, Color(TIN_DIM, 0.7), Vector2(334, 930), 200)

	if not ceremony:
		# 手牌三槽：已入 2 张大牌 + 1 空槽
		for s in 3:
			var hr := Rect2(760 + s * 180.0, 866, 150, 182)
			if s < my_hand.size():
				var card := (load(HERO_CARD) as PackedScene).instantiate() as HeroCard
				var h := heroes[my_hand[s]]
				card.hero_id = h.hero_id
				card.hero_name = h.hero_name
				card.max_hp = h.max_hp
				card.portrait_path = h.portrait_path
				card.card_state = HeroCard.CardState.SELECTED
				card.scale = Vector2(150.0 / 130.0, 150.0 / 130.0)
				card.position = hr.position
				layer.add_child(card)
			else:
				_empty_slot(layer, hr, "空")
		# 确认钮（盖牌语义：选满才点亮）
		var btn := Rect2(1460, 900, 360, 84)
		var plate := _plate(layer, btn, TIER_GOLD)
		plate.modulate = Color(0.55, 0.55, 0.55)
		var btn_text := "确认盖牌  2/3" if state == "ban" else "确认出战  2/3"
		_text(layer, btn_text, 26, Color("#d8cba8"), Vector2(btn.position.x, btn.position.y + 26), btn.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# ── 仪式层 ──
	if state == "banreveal":
		_build_ban_reveal(layer)
	elif state == "reveal":
		_build_final_reveal(layer)

	return layer


## 禁用揭晓：双方 3 张推到中央同时翻开；中间一对撞车 → 白闪相撞合并。
func _build_ban_reveal(layer: Control) -> void:
	var opp: Array[int] = [2, 7, 14]    # 对手禁用（7 与我撞车）
	var mine: Array[int] = [20, 7, 26]
	# 上排：对手翻开（红）；下排：我方翻开（蓝）；撞车对（index1）向中线合拢
	for s in 3:
		var ox := 700.0 + s * 200.0
		var my_y := 600.0
		var op_y := 320.0
		if s == 1:
			op_y = 430.0
			my_y = 470.0   # 相向合拢中
		_ceremony_card(layer, heroes[opp[s]], Vector2(ox, op_y), false)
		_ceremony_card(layer, heroes[mine[s]], Vector2(ox + (14.0 if s == 1 else 0.0), my_y), true)
	# 撞车白闪 + 说明
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.30)
	flash.position = Vector2(820, 410)
	flash.size = Vector2(300, 260)
	layer.add_child(flash)
	var flash2 := ColorRect.new()
	flash2.color = Color(1, 0.95, 0.75, 0.45)
	flash2.position = Vector2(872, 462)
	flash2.size = Vector2(196, 156)
	layer.add_child(flash2)
	_text(layer, "双方同禁「%s」· 并集合一" % heroes[7].hero_name, 24, GOLD_TEXT,
		Vector2(660, 700), 600, HORIZONTAL_ALIGNMENT_CENTER)


## 出战亮相：3v3 对扣翻开对峙（上红下蓝），中央王冠，开战钮点亮。
func _build_final_reveal(layer: Control) -> void:
	var opp: Array[int] = [6, 12, 28]
	var mine: Array[int] = [0, 9, 17]
	for s in 3:
		var ox := 700.0 + s * 200.0
		_ceremony_card(layer, heroes[opp[s]], Vector2(ox, 290.0), false)
		_ceremony_card(layer, heroes[mine[s]], Vector2(ox, 590.0), true)
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_SCALE
	crown.size = Vector2(crown.texture.get_size()) * 3.0
	crown.position = Vector2(960 - crown.size.x * 0.5, 505)
	layer.add_child(crown)
	var btn := Rect2(750, 940, 420, 84)
	var plate := _plate(layer, btn, TIER_GOLD)
	plate.modulate = Color(1.12, 1.06, 0.92)
	_text(layer, "开始战斗", 30, Color("#fff3d0"), Vector2(btn.position.x, btn.position.y + 24), btn.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _ceremony_card(layer: Control, h: HeroData, pos: Vector2, mine: bool) -> void:
	var card := (load(HERO_CARD) as PackedScene).instantiate() as HeroCard
	card.hero_id = h.hero_id
	card.hero_name = h.hero_name
	card.max_hp = h.max_hp
	card.portrait_path = h.portrait_path
	card.card_state = HeroCard.CardState.PICKED_P1 if mine else HeroCard.CardState.PICKED_P2
	card.position = pos
	layer.add_child(card)


# ── 部件（bp_tarot_demo 同源）──

func _section_tag(layer: Control, txt: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = txt.substr(0, 1) + "\n" + txt.substr(1, 1)
	FontManager.apply(lbl, 20)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 0.88, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	lbl.position = pos
	lbl.size = Vector2(40, 80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(lbl)


func _frosted(layer: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = Color(0.30, 0.55, 0.85, 0.35)
	border.position = r.position
	border.size = r.size
	layer.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(0.01, 0.02, 0.05, 0.45)
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	layer.add_child(fill)


func _seal_glyph(layer: Control, r: Rect2, ch: String, col: Color) -> void:
	var backing := ColorRect.new()
	backing.color = Color(col, 0.18)
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	for line_r: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 2)),
			Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)),
			Rect2(r.position, Vector2(2, r.size.y)),
			Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(col, 0.8)
		ln.position = line_r.position
		ln.size = line_r.size
		layer.add_child(ln)
	_text(layer, ch, 24, col, r.position + Vector2(0, 7), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _dots(layer: Control, pos: Vector2, filled: int, col: Color) -> void:
	for i in 3:
		var backing := ColorRect.new()
		backing.color = EDGE_OUTER
		backing.position = pos + Vector2(i * 28.0, 0)
		backing.size = Vector2(16, 16)
		layer.add_child(backing)
		var dot := ColorRect.new()
		dot.color = col if i < filled else Color(0.22, 0.25, 0.30)
		dot.position = backing.position + Vector2(2, 2)
		dot.size = Vector2(12, 12)
		layer.add_child(dot)


func _empty_slot(layer: Control, r: Rect2, hint: String) -> void:
	var backing := ColorRect.new()
	backing.color = Color(0.03, 0.04, 0.06, 0.85)
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	for line_r: Rect2 in [
			Rect2(r.position, Vector2(r.size.x, 2)),
			Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)),
			Rect2(r.position, Vector2(2, r.size.y)),
			Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y))]:
		var ln := ColorRect.new()
		ln.color = Color(EDGE_INNER, 0.6)
		ln.position = line_r.position
		ln.size = line_r.size
		layer.add_child(ln)
	if hint != "":
		_text(layer, hint, 16, Color(TIN_DIM, 0.5),
			r.position + Vector2(0, r.size.y * 0.5 - 12), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _card_back(layer: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(0.065, 0.075, 0.10, 0.97)
	fill.position = r.position + Vector2(3, 3)
	fill.size = r.size - Vector2(6, 6)
	layer.add_child(fill)
	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", 23.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.position = r.position
	f.size = r.size
	layer.add_child(f)
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_SCALE
	crown.size = Vector2(crown.texture.get_size()) * 2.0
	crown.position = r.position + (r.size - crown.size) * 0.5
	crown.modulate = Color(1, 1, 1, 0.85)
	layer.add_child(crown)


func _pixel_frame(layer: Control, r: Rect2, grid: float) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("pixel_grid", grid)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.position = r.position
	f.size = r.size
	layer.add_child(f)


func _portrait(layer: Control, path: String, r: Rect2) -> void:
	var pt := TextureRect.new()
	pt.texture = load(path)
	pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pt.stretch_mode = TextureRect.STRETCH_SCALE
	pt.position = r.position
	pt.size = r.size
	layer.add_child(pt)


func _plate(layer: Control, r: Rect2, tier: Dictionary) -> ColorRect:
	var bg := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(JELLY_SHADER)
	mat.set_shader_parameter("fill_top", tier["fill_top"])
	mat.set_shader_parameter("fill_bottom", tier["fill_bottom"])
	mat.set_shader_parameter("edge_inner", tier["edge_inner"])
	mat.set_shader_parameter("edge_outer", tier["edge_outer"])
	mat.set_shader_parameter("corner", 0.2)
	mat.set_shader_parameter("edge_px", 2.0)
	mat.set_shader_parameter("noise_amt", 0.05)
	mat.set_shader_parameter("wear", 0.18)
	mat.set_shader_parameter("pixel_grid", 38.0)
	mat.set_shader_parameter("fill_alpha", 0.95)
	mat.set_shader_parameter("aspect", r.size.x / maxf(r.size.y, 1.0))
	bg.material = mat
	bg.position = r.position
	bg.size = r.size
	layer.add_child(bg)
	return bg


func _text(layer: Control, s: String, size: int, col: Color, pos: Vector2,
		w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text = s
	FontManager.apply(lbl, size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.9))
	lbl.position = pos
	lbl.size = Vector2(w, size * 1.6)
	lbl.horizontal_alignment = align
	layer.add_child(lbl)
