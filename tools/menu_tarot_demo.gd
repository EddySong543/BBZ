extends SceneTree

## 主菜单「三牌阵」完整效果图 demo（第七轮·Eddy 基本通过·不动任何真实场景文件）：
##   godot --path . -s tools/menu_tarot_demo.gd
## 概念：菜单=开局前的牌桌。三张命运牌摊在亮波流上：
##   左=故事模式(过去·银框) 中=匹配对战(现在·金框·最大) 右=爬塔模式(未来·银框)
## 牌面=像素纹章+名牌横带（塔罗牌面本就符号化，纹章+字即成品）。
## 边缘件：顶左身份带 / 顶右设置(icon锚位) / 右下今日一抽小牌 / 左下公告小卡 / 底坞(icon锚位+字)。
## 背景=现行亮波流原样（亮=顺眼；疲劳由覆盖率+动效平息治理，不降明度）。
## 输出：D:/Game/BoBoZan/menu_tarot_blue.png + menu_tarot_red.png

const OUT_BLUE := "D:/Game/BoBoZan/menu_tarot_blue.png"
const OUT_RED := "D:/Game/BoBoZan/menu_tarot_red.png"

const FRAME_SHADER := "res://assets/shaders/canvas_ui_pixel_frame.gdshader"
const JELLY_SHADER := "res://assets/shaders/canvas_button_jelly.gdshader"

# battle screen 框语言（hero_frame 同源）
const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const EDGE_MID := Color(0.65, 0.67, 0.71)
const EDGE_INNER := Color(0.34, 0.36, 0.39)
# 金框（主牌·匹配对战）
const GOLD_MID := Color(0.79, 0.65, 0.29)
const GOLD_INNER := Color(0.45, 0.35, 0.15)
const GOLD_TEXT := Color("#f4c84b")

const CARD_FILL := Color(0.065, 0.075, 0.10, 0.97)        # 牌面深板岩（实体牌，非霜玻璃）
const CARD_FILL_WARM := Color(0.095, 0.085, 0.07, 0.97)   # 主牌微暖
const TIN := Color("#c9d2dc")
const TIN_DIM := Color("#aab4c4")

const TIER_STEEL := {
	"fill_top": Color(0.24, 0.30, 0.44), "fill_bottom": Color(0.11, 0.14, 0.24),
	"edge_inner": Color(0.52, 0.64, 0.88), "edge_outer": Color(0.04, 0.05, 0.10),
}

# 三牌阵位（中牌大·两翼略小，垂直中线对齐）
const CARD_MAIN := Rect2(770, 210, 380, 560)
const CARD_STORY := Rect2(380, 255, 320, 470)
const CARD_TOWER := Rect2(1220, 255, 320, 470)

var _f12: FontFile
var _f16: FontFile
var _wave_mat: ShaderMaterial


func _initialize() -> void:
	_f12 = load("res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf")
	_f12.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_f16 = load("res://assets/font/ark-pixel-16px-proportional-zh_cn.ttf")
	_f16.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	# 背景 = 现行亮波流原样（不替换色带——亮主调恒定）
	var bg := (load("res://src/ui/scenes/menu_background.tscn") as PackedScene).instantiate()
	root.add_child(bg)
	_wave_mat = (bg.get_node("WaveFlow") as ColorRect).material as ShaderMaterial

	_build_ui()

	await create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_BLUE)
	print("saved: ", OUT_BLUE)

	_wave_mat.set_shader_parameter("use_blue", 0.0)
	_wave_mat.set_shader_parameter("drift_dir", -1.0)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_RED)
	print("saved: ", OUT_RED)
	quit()


func _build_ui() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)

	_build_identity(layer)
	_build_settings(layer)
	_build_spread(layer)        # 三牌阵
	_build_daily_draw(layer)    # 今日一抽小牌
	_build_announce(layer)      # 公告小卡
	_build_dock(layer)          # 收集坞（icon 锚位+字）


# ── 顶左：身份带 ──
func _build_identity(layer: Control) -> void:
	_pixel_frame(layer, Rect2(48, 32, 84, 84), 21.0, false)
	_portrait(layer, "res://assets/sprites/heroes/h01/h01_portrait.png", Rect2(56, 40, 68, 68))
	_text(layer, "Eddy", 26, Color("#e8edf4"), Vector2(150, 42), 300)
	_plate(layer, Rect2(150, 80, 168, 34))
	_text(layer, "段位 · 未定级", 16, TIN_DIM, Vector2(150, 87), 168, HORIZONTAL_ALIGNMENT_CENTER)


# ── 顶右：设置（icon 锚位 + 字）──
func _build_settings(layer: Control) -> void:
	_plate(layer, Rect2(1732, 36, 140, 54))
	_icon_slot(layer, Rect2(1748, 49, 28, 28))
	_text(layer, "设置", 22, TIN, Vector2(1788, 50), 80)


# ── 三牌阵 ──
func _build_spread(layer: Control) -> void:
	# 左牌·故事模式（过去）
	_card(layer, CARD_STORY, false, "过去", "卷", "故事模式", "英雄列传", 110)
	# 右牌·爬塔模式（未来）
	_card(layer, CARD_TOWER, false, "未来", "塔", "爬塔模式", "单人连胜挑战", 110)
	# 中牌·匹配对战（现在·金框·王冠纹章）
	_card(layer, CARD_MAIN, true, "现在", "", "匹配对战", "1v1 同时盲选对决", 130)
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_SCALE
	crown.size = Vector2(crown.texture.get_size()) * 6.0
	# 王冠居中于美术区（名牌横带以上的区域）垂直中点；王冠像素图自带蓝/红宝石=对波母题已在
	var art_h := CARD_MAIN.size.y - 130.0   # 130 = 主牌名牌横带高
	crown.position = CARD_MAIN.position + Vector2(
		(CARD_MAIN.size.x - crown.size.x) * 0.5, (art_h - crown.size.y) * 0.5)
	layer.add_child(crown)


# ── 右下：今日一抽（小牌·日换）──
func _build_daily_draw(layer: Control) -> void:
	var r := Rect2(1668, 730, 188, 270)
	_card_base(layer, r, false, 47.0)
	_text(layer, "今日一抽", 16, Color(TIN_DIM, 0.8), Vector2(r.position.x, r.position.y + 16), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_pixel_frame(layer, Rect2(r.position.x + 46, r.position.y + 48, 96, 96), 24.0, false)
	var h: Resource = load("res://assets/data/heroes/h01.tres")
	_portrait(layer, h.portrait_path, Rect2(r.position.x + 55, r.position.y + 57, 78, 78))
	_text(layer, h.hero_name, 24, Color("#f0f4f8"), Vector2(r.position.x, r.position.y + 158), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(layer, "「%s」" % h.skill_description, 18, GOLD_TEXT, Vector2(r.position.x, r.position.y + 194), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(layer, "偷取对手 1 点能量", 14, TIN_DIM, Vector2(r.position.x, r.position.y + 228), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ── 左下：公告小卡 ──
func _build_announce(layer: Control) -> void:
	var r := Rect2(64, 800, 400, 150)
	var border := ColorRect.new()
	border.color = Color(0.30, 0.55, 0.85, 0.40)
	border.position = r.position
	border.size = r.size
	layer.add_child(border)
	var fill := ColorRect.new()
	fill.color = Color(0.012, 0.022, 0.045, 0.78)
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	layer.add_child(fill)
	_text(layer, "公告", 20, Color("#dde6f0"), Vector2(88, 816), 200)
	_text(layer, "· 选人界面全面重做", 17, Color("#b9c6d6"), Vector2(88, 852), 352)
	_text(layer, "· 全局波幕转场上线", 17, Color("#b9c6d6"), Vector2(88, 880), 352)
	_text(layer, "v0.6 · 6 月 11 日", 14, Color("#7d8a9c"), Vector2(88, 916), 352, HORIZONTAL_ALIGNMENT_RIGHT)


# ── 底坞：英雄|小队|道具|商店（icon 锚位 + 字）──
func _build_dock(layer: Control) -> void:
	var bar := Rect2(64, 970, 640, 70)
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = bar.position
	backing.size = bar.size
	layer.add_child(backing)
	var fill := ColorRect.new()
	fill.color = Color(0.10, 0.115, 0.145, 0.92)
	fill.position = bar.position + Vector2(3, 3)
	fill.size = bar.size - Vector2(6, 6)
	layer.add_child(fill)
	var names: Array[String] = ["英雄", "小队", "道具", "商店"]
	for i in names.size():
		var seg_x := bar.position.x + i * 160.0
		_icon_slot(layer, Rect2(seg_x + 34, bar.position.y + 21, 28, 28))
		_text(layer, names[i], 24, TIN, Vector2(seg_x + 74, bar.position.y + 21), 80)
		if i > 0:
			var sp := ColorRect.new()
			sp.color = Color(0.40, 0.45, 0.52, 0.40)
			sp.position = Vector2(seg_x, bar.position.y + 16)
			sp.size = Vector2(2, 38)
			layer.add_child(sp)


# ── 组件辅助 ──

## 完整命运牌：底座 + 顶部小注（过去/现在/未来）+ 字纹章 + 名牌横带（名+副标）
func _card(layer: Control, r: Rect2, gold: bool, caption: String, emblem: String,
		card_name: String, subtitle: String, band_h: float) -> void:
	_card_base(layer, r, gold, r.size.x / 5.0)

	# 顶部小注（塔罗位语·低调）
	_text(layer, "· %s ·" % caption, 14, Color(TIN_DIM, 0.55), Vector2(r.position.x, r.position.y + 20), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# 字纹章（side 牌：单字大印；主牌用王冠纹理，emblem 传空跳过）
	if emblem != "":
		_text(layer, emblem, 96, Color(TIN_DIM, 0.85), Vector2(r.position.x, r.position.y + 130), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# 名牌横带
	var band_y := r.end.y - band_h
	var band := ColorRect.new()
	band.color = Color(0.0, 0.0, 0.0, 0.30)
	band.position = Vector2(r.position.x + 8, band_y)
	band.size = Vector2(r.size.x - 16, band_h - 10)
	layer.add_child(band)
	var sep := ColorRect.new()
	sep.color = Color(GOLD_MID if gold else EDGE_MID, 0.5)
	sep.position = Vector2(r.position.x + 24, band_y)
	sep.size = Vector2(r.size.x - 48, 2)
	layer.add_child(sep)
	var name_size := 40 if gold else 32
	_text(layer, card_name, name_size, GOLD_TEXT if gold else Color("#e4eaf2"),
		Vector2(r.position.x, band_y + 18), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(layer, subtitle, 16, Color(TIN_DIM, 0.9),
		Vector2(r.position.x, band_y + 18 + name_size + 14), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## 牌底座：深色衬底 + 像素框（银/金）+ 实体牌面填充 + 内细线框 + 四饰角
func _card_base(layer: Control, r: Rect2, gold: bool, grid: float) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)

	var fill := ColorRect.new()
	fill.color = CARD_FILL_WARM if gold else CARD_FILL
	fill.position = r.position + Vector2(4, 4)
	fill.size = r.size - Vector2(8, 8)
	layer.add_child(fill)

	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", GOLD_MID if gold else EDGE_MID)
	m.set_shader_parameter("edge_inner", GOLD_INNER if gold else EDGE_INNER)
	m.set_shader_parameter("pixel_grid", grid)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	f.material = m
	f.position = r.position
	f.size = r.size
	layer.add_child(f)

	# 内细线框（牌面内衬）
	var inset := 18.0
	var line_col := Color(GOLD_MID if gold else EDGE_MID, 0.30)
	for line_r: Rect2 in [
			Rect2(r.position.x + inset, r.position.y + inset, r.size.x - inset * 2.0, 1),
			Rect2(r.position.x + inset, r.end.y - inset, r.size.x - inset * 2.0, 1),
			Rect2(r.position.x + inset, r.position.y + inset, 1, r.size.y - inset * 2.0),
			Rect2(r.end.x - inset, r.position.y + inset, 1, r.size.y - inset * 2.0)]:
		var ln := ColorRect.new()
		ln.color = line_col
		ln.position = line_r.position
		ln.size = line_r.size
		layer.add_child(ln)

	# 四饰角（L 形小角花）
	var arm := 16.0
	var th := 3.0
	var c_col := Color(GOLD_MID if gold else EDGE_MID, 0.65)
	var pad := inset + 6.0
	for c in [
			[Vector2(pad, pad), Vector2(1, 1)],
			[Vector2(r.size.x - pad, pad), Vector2(-1, 1)],
			[Vector2(pad, r.size.y - pad), Vector2(1, -1)],
			[Vector2(r.size.x - pad, r.size.y - pad), Vector2(-1, -1)]]:
		var origin: Vector2 = r.position + (c[0] as Vector2)
		var dir: Vector2 = c[1] as Vector2
		var hbar := ColorRect.new()
		hbar.color = c_col
		hbar.position = origin if dir.x > 0 else origin - Vector2(arm, 0)
		hbar.position.y = origin.y if dir.y > 0 else origin.y - th
		hbar.size = Vector2(arm, th)
		layer.add_child(hbar)
		var vbar := ColorRect.new()
		vbar.color = c_col
		vbar.position.x = origin.x if dir.x > 0 else origin.x - th
		vbar.position.y = origin.y if dir.y > 0 else origin.y - arm
		vbar.size = Vector2(th, arm)
		layer.add_child(vbar)


## battle 框语言像素框（头像等小框用）
func _pixel_frame(layer: Control, r: Rect2, grid: float, gold: bool) -> void:
	var backing := ColorRect.new()
	backing.color = EDGE_OUTER
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var f := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", GOLD_MID if gold else EDGE_MID)
	m.set_shader_parameter("edge_inner", GOLD_INNER if gold else EDGE_INNER)
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


## icon 锚位占位：28px 空像素方格（素材到位后原位替换）
func _icon_slot(layer: Control, r: Rect2) -> void:
	var backing := ColorRect.new()
	backing.color = Color(EDGE_OUTER, 0.8)
	backing.position = r.position
	backing.size = r.size
	layer.add_child(backing)
	var inner := ColorRect.new()
	inner.color = Color(0.22, 0.25, 0.30, 0.9)
	inner.position = r.position + Vector2(2, 2)
	inner.size = r.size - Vector2(4, 4)
	layer.add_child(inner)


## jelly 像素底板（钢蓝档·小件用）
func _plate(layer: Control, r: Rect2) -> void:
	var bg := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(JELLY_SHADER)
	mat.set_shader_parameter("fill_top", TIER_STEEL["fill_top"])
	mat.set_shader_parameter("fill_bottom", TIER_STEEL["fill_bottom"])
	mat.set_shader_parameter("edge_inner", TIER_STEEL["edge_inner"])
	mat.set_shader_parameter("edge_outer", TIER_STEEL["edge_outer"])
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


func _text(layer: Control, s: String, size: int, col: Color, pos: Vector2,
		w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text = s
	lbl.add_theme_font_override("font", _f16 if (size % 16 == 0 and size % 12 != 0) else _f12)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = pos
	lbl.size = Vector2(w, size * 1.6)
	lbl.horizontal_alignment = align
	layer.add_child(lbl)
