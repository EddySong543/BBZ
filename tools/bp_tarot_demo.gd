extends Node

## BP 重构「布阵席」三阶段效果图 demo（A1 全池一屏 / B2 霜玻璃浅衬 / 牌桌语言·不动真实场景）：
##   godot --path . res://tools/bp_tarot_demo.tscn
## 完整引擎模式跑（HeroCard/FontManager 需 autoload）。输出 BAN/PICK/REVEAL 三张：
##   D:/Game/BoBoZan/bp_demo_ban.png / bp_demo_pick.png / bp_demo_reveal.png

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
const TIN := Color("#c9d2dc")
const TIN_DIM := Color("#aab4c4")

# 卡池网格（A1：10 列 × 5 行 = 46 全池一屏，130×158 原尺寸卡不缩）
const POOL := Rect2(200, 134, 1520, 844)
const CARD_W := 130.0
const CARD_H := 158.0
const GAP_X := 20.0
const GAP_Y := 10.0
const X0 := 220.0
const Y0 := 142.0

const TIER_GOLD := {
	"fill_top": Color(0.64, 0.46, 0.17), "fill_bottom": Color(0.33, 0.21, 0.07),
	"edge_inner": Color(0.98, 0.82, 0.42), "edge_outer": Color(0.12, 0.08, 0.03),
}

var heroes: Array[HeroData] = []


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)   # 截图分辨率固定（窗口偶尔不按工程设置开）
	get_window().position = Vector2i(0, 0)
	await get_tree().process_frame
	add_child((load("res://src/ui/scenes/menu_background.tscn") as PackedScene).instantiate())
	heroes = HeroData.create_pool_heroes()
	print("pool size: ", heroes.size())

	for state in ["ban", "pick", "reveal"]:
		var layer := _build_state(state)
		add_child(layer)
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var path := "D:/Game/BoBoZan/bp_demo_%s.png" % state
		get_viewport().get_texture().get_image().save_png(path)
		print("saved: ", path)
		layer.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## 三阶段共用骨架：顶横幅 + 卡池(霜玻璃衬) + 双柱 + 底部金钮，按 state 填不同内容。
func _build_state(state: String) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 演示用状态数据
	var banned: Array[int] = [2, 7, 14, 20, 26, 32]      # PICK/REVEAL：六禁用
	var my_sel: Array[int] = [4]                          # 当前步已勾选
	if state == "ban":
		my_sel = [5, 21]
	var my_picked: Array[int] = [0, 9]                   # PICK：已飞入阵容柱的两个
	var my_final: Array[int] = [0, 9, 17]                # REVEAL：我方三人
	var foe_final: Array[int] = [6, 12, 28]              # REVEAL：对手三人

	# ── 卡池（先建：让横幅/柱盖在其上）──
	var pool_layer := Control.new()
	layer.add_child(pool_layer)
	_frosted(pool_layer, POOL)
	for i in heroes.size():
		var row := i / 10
		var col := i % 10
		var n_in_row := 6 if row == 4 else 10
		var x0 := X0 + ((10 - n_in_row) * (CARD_W + GAP_X)) * 0.5   # 末行 6 张居中
		var card := (load(HERO_CARD) as PackedScene).instantiate() as HeroCard
		card.hero_id = heroes[i].hero_id
		card.hero_name = heroes[i].hero_name
		card.max_hp = heroes[i].max_hp
		card.portrait_path = heroes[i].portrait_path
		card.position = Vector2(x0 + col * (CARD_W + GAP_X), Y0 + row * (CARD_H + GAP_Y))
		if state != "ban" and banned.has(i):
			card.card_state = HeroCard.CardState.BANNED
		elif state == "pick" and my_picked.has(i):
			card.card_state = HeroCard.CardState.PICKED_P1
		elif state != "reveal" and my_sel.has(i):
			card.card_state = HeroCard.CardState.SELECTED
		elif state == "reveal":
			if my_final.has(i):
				card.card_state = HeroCard.CardState.PICKED_P1
			elif foe_final.has(i):
				card.card_state = HeroCard.CardState.PICKED_P2
		pool_layer.add_child(card)
	if state == "reveal":
		pool_layer.modulate = Color(0.45, 0.45, 0.5)   # 亮相时刻：牌池退后，焦点交给双柱

	# ── 顶部阶段横幅 ──
	var banner := Rect2(510, 24, 900, 88)
	_pixel_panel(layer, banner, state != "ban")
	match state:
		"ban":
			_seal_glyph(layer, Rect2(banner.position.x + 28, banner.position.y + 22, 44, 44), "禁", BAN_RED)
			_text(layer, "禁用阶段", 32, Color("#e8edf4"), banner.position + Vector2(92, 24), 300)
			_text(layer, "盲选 3 名禁用 · 与对手同时", 14, TIN_DIM, banner.position + Vector2(92, 60), 400)
			_dots(layer, banner.position + Vector2(610, 36), 2, BAN_RED)
			_text(layer, "剩余 29s", 24, GOLD_TEXT, banner.position + Vector2(740, 30), 140)
		"pick":
			_seal_glyph(layer, Rect2(banner.position.x + 28, banner.position.y + 22, 44, 44), "选", GOLD_TEXT)
			_text(layer, "出战阶段", 32, Color("#e8edf4"), banner.position + Vector2(92, 24), 300)
			_text(layer, "盲选 3 名出战 · 允许镜像", 14, TIN_DIM, banner.position + Vector2(92, 60), 400)
			_dots(layer, banner.position + Vector2(610, 36), 2, GOLD_TEXT)
			_text(layer, "剩余 17s", 24, GOLD_TEXT, banner.position + Vector2(740, 30), 140)
		"reveal":
			var crown := TextureRect.new()
			crown.texture = PixelGlyphs.crown_texture()
			crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			crown.stretch_mode = TextureRect.STRETCH_SCALE
			crown.size = Vector2(crown.texture.get_size()) * 2.0
			crown.position = banner.position + Vector2(34, 28)
			layer.add_child(crown)
			_text(layer, "阵容亮相", 32, GOLD_TEXT, banner.position + Vector2(100, 24), 300)
			_text(layer, "双方阵容已揭晓 · 准备开战", 14, TIN_DIM, banner.position + Vector2(100, 60), 400)

	# ── 双柱：我方（左）/ 对手（右）──
	_text(layer, "你的阵容", 18, Color("#9cc0e8"), Vector2(36, 146), 156, HORIZONTAL_ALIGNMENT_CENTER)
	_text(layer, "对手阵容", 18, Color("#e8a09c"), Vector2(1728, 146), 156, HORIZONTAL_ALIGNMENT_CENTER)
	for s in 3:
		var ly := 196.0 + s * 168.0
		var lrect := Rect2(59, ly, 110, 110)
		var rrect := Rect2(1751, ly, 110, 110)
		match state:
			"ban":
				_ban_slot(layer, lrect, s < 2)        # 已勾 2 禁用 → 前两格亮红✕
				_card_back(layer, rrect)              # 对手盖牌
			"pick":
				if s < 2:
					_mini_hero(layer, lrect, heroes[my_picked[s]], false)
				else:
					_empty_slot(layer, lrect, "空位")
				_card_back(layer, rrect)
			"reveal":
				_mini_hero(layer, lrect, heroes[my_final[s]], false)
				_mini_hero(layer, rrect, heroes[foe_final[s]], true)

	# ── 底部主钮（金·与主菜单匹配钮同级）──
	var btn := Rect2(750, 992, 420, 72)
	var plate := _plate(layer, btn, TIER_GOLD)
	match state:
		"ban":
			plate.modulate = Color(0.55, 0.55, 0.55)   # 未选满=熄灭
			_text(layer, "确认禁用", 30, Color("#d8cba8"), Vector2(btn.position.x, btn.position.y + 18), btn.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		"pick":
			plate.modulate = Color(0.55, 0.55, 0.55)
			_text(layer, "确认出战", 30, Color("#d8cba8"), Vector2(btn.position.x, btn.position.y + 18), btn.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		"reveal":
			plate.modulate = Color(1.12, 1.06, 0.92)   # 点亮+呼吸光中间帧
			_text(layer, "开始战斗", 30, Color("#fff3d0"), Vector2(btn.position.x, btn.position.y + 18), btn.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	return layer


# ── 部件 ──

## 霜玻璃浅衬（B2）：月光青细边 + 极浅暗底，提高头像可读性，波流仍透出。
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


## 像素框横幅板（battle 框语言；gold=出战/亮相阶段描金）。
func _pixel_panel(layer: Control, r: Rect2, gold: bool) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(0.065, 0.075, 0.10, 0.96)
	fill.position = r.position + Vector2(4, 4)
	fill.size = r.size - Vector2(8, 8)
	layer.add_child(fill)
	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", GOLD_MID if gold else EDGE_MID)
	m.set_shader_parameter("edge_inner", GOLD_INNER if gold else EDGE_INNER)
	m.set_shader_parameter("pixel_grid", r.size.x / 4.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.position = r.position
	f.size = r.size
	layer.add_child(f)


## 阶段图记：方印底 + 单字（禁=红 / 选=金）。
func _seal_glyph(layer: Control, r: Rect2, ch: String, col: Color) -> void:
	var backing := ColorRect.new()
	backing.color = Color(col, 0.18)
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var ring := ColorRect.new()   # 细边
	ring.color = Color(col, 0.0)
	layer.add_child(ring)
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
	_text(layer, ch, 28, col, r.position + Vector2(0, 8), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## 进度方点 ■■□（像素风·取代灰字 0/3）。
func _dots(layer: Control, pos: Vector2, filled: int, col: Color) -> void:
	for i in 3:
		var backing := ColorRect.new()
		backing.color = EDGE_OUTER
		backing.position = pos + Vector2(i * 30.0, 0)
		backing.size = Vector2(18, 18)
		layer.add_child(backing)
		var dot := ColorRect.new()
		dot.color = col if i < filled else Color(0.22, 0.25, 0.30)
		dot.position = backing.position + Vector2(2, 2)
		dot.size = Vector2(14, 14)
		layer.add_child(dot)


## 禁用碑位：暗井 + 红✕（两根交叉粗线的像素近似：横竖各一根）。
func _ban_slot(layer: Control, r: Rect2, lit: bool) -> void:
	_slot_pit(layer, r)
	var col := Color(BAN_RED, 0.95 if lit else 0.30)
	_text(layer, "✕" if _has_glyph() else "X", 44, col,
		r.position + Vector2(0, r.size.y * 0.5 - 30), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _has_glyph() -> bool:
	return true   # Ark Pixel 含 ✕（U+2715）；若 F6 发现缺字回退 "X"


func _empty_slot(layer: Control, r: Rect2, hint: String) -> void:
	_slot_pit(layer, r)
	_text(layer, hint, 14, Color(TIN_DIM, 0.5), r.position + Vector2(0, r.size.y * 0.5 - 10), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _slot_pit(layer: Control, r: Rect2) -> void:
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


## 对手盖牌（主菜单牌背同语言：像素框 + 小王冠呼吸位）。
func _card_back(layer: Control, r: Rect2) -> void:
	_mini_frame(layer, r, false)
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_SCALE
	crown.size = Vector2(crown.texture.get_size()) * 2.0
	crown.position = r.position + (r.size - crown.size) * 0.5
	crown.modulate = Color(1, 1, 1, 0.85)
	layer.add_child(crown)


## 阵容柱迷你英雄牌：像素框 + 头像 + 名字（foe=对手红名）。
func _mini_hero(layer: Control, r: Rect2, h: HeroData, foe: bool) -> void:
	_mini_frame(layer, r, not foe)
	var pt := TextureRect.new()
	pt.texture = load(h.portrait_path)
	pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pt.stretch_mode = TextureRect.STRETCH_SCALE
	pt.position = r.position + Vector2(9, 9)
	pt.size = r.size - Vector2(18, 18)
	layer.add_child(pt)
	_text(layer, h.hero_name, 14, Color("#e8a09c") if foe else Color("#9cc0e8"),
		r.position + Vector2(-20, r.size.y + 6), r.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)


func _mini_frame(layer: Control, r: Rect2, _mine: bool) -> void:
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
	m.set_shader_parameter("pixel_grid", 27.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.position = r.position
	f.size = r.size
	layer.add_child(f)


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
