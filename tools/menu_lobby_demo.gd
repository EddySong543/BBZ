extends SceneTree

## 主菜单「PvP 大厅四区」完整效果图 demo（第五轮方案·不动任何真实场景文件）：
##   godot --path . -s tools/menu_lobby_demo.gd
## 四区：顶栏身份带 / 左轨内容卡×2（公告+今日英雄·真文案） / 右下对战区
## （爬塔·故事各一行 + 匹配对战金钮） / 底栏收集坞。
## 背景 = 波流 + 玄夜场域档色带（降疲劳·demo 内字符串替换 ramp，不改真 shader）。
## 输出：D:/Game/BoBoZan/_probe_output/menu_lobby_blue.png + menu_lobby_red.png

const OUT_BLUE := "D:/Game/BoBoZan/_probe_output/menu_lobby_blue.png"
const OUT_RED := "D:/Game/BoBoZan/_probe_output/menu_lobby_red.png"

const WAVE_SHADER_PATH := "res://assets/shaders/canvas_env_wave_flow.gdshader"
const FRAME_SHADER := "res://assets/shaders/canvas_ui_pixel_frame.gdshader"
const JELLY_SHADER := "res://assets/shaders/canvas_button_jelly.gdshader"

# ── 场域档色带（玄夜黛蓝 / 玄夜绛红·顶端明度-35% 饱和-25%·浪尖去纯白）──
const BLUE_RAMP_OLD := """	vec3 c1 = vec3(0.08, 0.20, 0.42);
	vec3 c2 = vec3(0.16, 0.36, 0.74);
	vec3 c3 = vec3(0.30, 0.60, 1.00);
	vec3 c4 = vec3(0.70, 0.88, 1.00);
	vec3 cW = vec3(1.00, 1.00, 1.00);"""
const BLUE_RAMP_CALM := """	vec3 c1 = vec3(0.071, 0.169, 0.302);
	vec3 c2 = vec3(0.122, 0.267, 0.439);
	vec3 c3 = vec3(0.200, 0.400, 0.600);
	vec3 c4 = vec3(0.435, 0.612, 0.769);
	vec3 cW = vec3(0.722, 0.831, 0.910);"""
const RED_RAMP_OLD := """	vec3 c1 = vec3(0.32, 0.10, 0.06);
	vec3 c2 = vec3(0.62, 0.18, 0.12);
	vec3 c3 = vec3(0.95, 0.32, 0.22);
	vec3 c4 = vec3(1.00, 0.65, 0.45);
	vec3 cW = vec3(1.00, 1.00, 1.00);"""
const RED_RAMP_CALM := """	vec3 c1 = vec3(0.239, 0.082, 0.063);
	vec3 c2 = vec3(0.380, 0.133, 0.102);
	vec3 c3 = vec3(0.561, 0.227, 0.173);
	vec3 c4 = vec3(0.722, 0.447, 0.341);
	vec3 cW = vec3(0.890, 0.753, 0.682);"""

# battle screen 框语言（hero_frame 同源）
const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const EDGE_MID := Color(0.65, 0.67, 0.71)
const EDGE_INNER := Color(0.34, 0.36, 0.39)

# 霜玻璃内容卡（ui-brief §5：深蓝半透 + 月光青细描边）
const CARD_BORDER := Color(0.30, 0.55, 0.85, 0.45)
const CARD_FILL := Color(0.012, 0.022, 0.045, 0.78)

# jelly 按钮三档（main_menu.gd PLATE_TIERS 同源）
const TIER_GOLD := {
	"fill_top": Color(0.64, 0.46, 0.17), "fill_bottom": Color(0.33, 0.21, 0.07),
	"edge_inner": Color(0.98, 0.82, 0.42), "edge_outer": Color(0.12, 0.08, 0.03),
}
const TIER_STEEL := {
	"fill_top": Color(0.24, 0.30, 0.44), "fill_bottom": Color(0.11, 0.14, 0.24),
	"edge_inner": Color(0.52, 0.64, 0.88), "edge_outer": Color(0.04, 0.05, 0.10),
}

var _f12: Font
var _f16: Font
var _wave_mat: ShaderMaterial


func _initialize() -> void:
	# 脚本模式下 _ready 不会在 _initialize 期间触发 → 不走 FontManager，直接加载字体
	_f12 = load("res://assets/font/zlabs_pixel_ui.tres")
	_f16 = _f12

	_build_background()
	_build_ui()

	await create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_BLUE)
	print("saved: ", OUT_BLUE)

	# 切红胜：色带由 use_blue 选择，方向反向
	_wave_mat.set_shader_parameter("use_blue", 0.0)
	_wave_mat.set_shader_parameter("drift_dir", -1.0)
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_RED)
	print("saved: ", OUT_RED)
	quit()


## 波流背景 + 场域档 ramp（运行时字符串替换 shader 源码，真文件不动）
func _build_background() -> void:
	var bg := (load("res://src/ui/scenes/menu_background.tscn") as PackedScene).instantiate()
	root.add_child(bg)
	var wave := bg.get_node("WaveFlow") as ColorRect
	var src := (load(WAVE_SHADER_PATH) as Shader).code
	src = src.replace(BLUE_RAMP_OLD, BLUE_RAMP_CALM).replace(RED_RAMP_OLD, RED_RAMP_CALM)
	var calm_shader := Shader.new()
	calm_shader.code = src
	_wave_mat = (wave.material as ShaderMaterial).duplicate() as ShaderMaterial
	_wave_mat.shader = calm_shader
	wave.material = _wave_mat


func _build_ui() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)

	_build_identity(layer)    # ① 顶栏身份带
	_build_cards(layer)       # ② 左轨内容卡
	_build_battle_zone(layer) # ③ 右下对战区
	_build_dock(layer)        # ④ 底栏收集坞


# ── ① 顶栏：头像框 + 名字 + 段位占位（左）/ 设置（右）──
func _build_identity(layer: Control) -> void:
	_pixel_frame(layer, Rect2(48, 32, 84, 84), 21.0)
	var pt := TextureRect.new()
	pt.texture = load("res://assets/sprites/heroes/h01/h01_portrait.png")
	pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pt.stretch_mode = TextureRect.STRETCH_SCALE
	pt.position = Vector2(56, 40)
	pt.size = Vector2(68, 68)
	layer.add_child(pt)

	_text(layer, "Eddy", 26, Color("#e8edf4"), Vector2(150, 42), 300)
	var rank := _plate(layer, Rect2(150, 80, 168, 34), TIER_STEEL)
	rank.modulate.a = 0.9
	_text(layer, "段位 · 未定级", 16, Color("#aab4c4"), Vector2(150, 87), 168, HORIZONTAL_ALIGNMENT_CENTER)

	_plate(layer, Rect2(1756, 36, 116, 54), TIER_STEEL)
	_text(layer, "设置", 22, Color("#cdd6e2"), Vector2(1756, 50), 116, HORIZONTAL_ALIGNMENT_CENTER)


# ── ② 左轨内容卡：公告 + 今日英雄（霜玻璃半透）──
func _build_cards(layer: Control) -> void:
	# 公告卡
	_card(layer, Rect2(64, 240, 460, 230))
	_text(layer, "公告", 26, Color("#dde6f0"), Vector2(92, 260), 200)
	_sep(layer, Rect2(92, 300, 404, 2))
	_text(layer, "· 选人界面全面重做", 19, Color("#b9c6d6"), Vector2(92, 318), 404)
	_text(layer, "· 46 位英雄美术全部就位", 19, Color("#b9c6d6"), Vector2(92, 350), 404)
	_text(layer, "· 全局波幕转场上线", 19, Color("#b9c6d6"), Vector2(92, 382), 404)
	_text(layer, "v0.6 · 6 月 11 日", 15, Color("#7d8a9c"), Vector2(92, 432), 404, HORIZONTAL_ALIGNMENT_RIGHT)

	# 今日英雄卡（h01 真数据）
	var h: Resource = load("res://assets/data/heroes/h01.tres")
	_card(layer, Rect2(64, 500, 460, 200))
	_text(layer, "今日英雄", 26, Color("#dde6f0"), Vector2(92, 520), 200)
	_sep(layer, Rect2(92, 560, 404, 2))
	_pixel_frame(layer, Rect2(92, 578, 96, 96), 24.0)
	var pt := TextureRect.new()
	pt.texture = load(h.portrait_path)
	pt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pt.stretch_mode = TextureRect.STRETCH_SCALE
	pt.position = Vector2(101, 587)
	pt.size = Vector2(78, 78)
	layer.add_child(pt)
	_text(layer, h.hero_name, 28, Color("#f0f4f8"), Vector2(212, 584), 280)
	_text(layer, "「%s」" % h.skill_description, 20, Color("#f4c84b"), Vector2(212, 622), 280)
	_text(layer, "偷取对手 1 点能量", 17, Color("#aab8c8"), Vector2(212, 654), 280)


# ── ③ 右下对战区：爬塔 / 故事 各一行 + 匹配对战大钮 ──
func _build_battle_zone(layer: Control) -> void:
	_plate(layer, Rect2(1496, 736, 360, 76), TIER_STEEL)
	_text(layer, "爬塔模式", 28, Color("#d4dce8"), Vector2(1496, 756), 360, HORIZONTAL_ALIGNMENT_CENTER)
	_plate(layer, Rect2(1496, 828, 360, 76), TIER_STEEL)
	_text(layer, "故事模式", 28, Color("#d4dce8"), Vector2(1496, 848), 360, HORIZONTAL_ALIGNMENT_CENTER)
	var cta := _plate(layer, Rect2(1396, 920, 460, 120), TIER_GOLD)
	cta.modulate = Color(1.12, 1.06, 0.92)   # 主 CTA 呼吸光中间帧
	_text(layer, "匹配对战", 44, Color("#fff3d0"), Vector2(1396, 952), 460, HORIZONTAL_ALIGNMENT_CENTER)


# ── ④ 底栏收集坞：英雄|小队|道具|商店 一根坞条 ──
func _build_dock(layer: Control) -> void:
	var bar := Rect2(64, 970, 560, 70)
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
		_text(layer, names[i], 24, Color("#c9d2dc"),
			bar.position + Vector2(i * 140.0, 21), 140, HORIZONTAL_ALIGNMENT_CENTER)
		if i > 0:
			var sp := ColorRect.new()
			sp.color = Color(0.40, 0.45, 0.52, 0.40)
			sp.position = bar.position + Vector2(i * 140.0, 16)
			sp.size = Vector2(2, 38)
			layer.add_child(sp)


# ── 组件辅助 ──

## battle 框语言像素框（深描边/锡灰/板岩）+ 深色衬底
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


## 霜玻璃内容卡：月光青 2px 细描边 + 深蓝半透填充
func _card(layer: Control, r: Rect2) -> void:
	var border := ColorRect.new()
	border.color = CARD_BORDER
	border.position = r.position
	border.size = r.size
	layer.add_child(border)
	var fill := ColorRect.new()
	fill.color = CARD_FILL
	fill.position = r.position + Vector2(2, 2)
	fill.size = r.size - Vector2(4, 4)
	layer.add_child(fill)


## jelly 像素底板（main_menu._apply_plate 同参）
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


func _sep(layer: Control, r: Rect2) -> void:
	var sep := ColorRect.new()
	sep.color = Color(0.45, 0.60, 0.80, 0.35)
	sep.position = r.position
	sep.size = r.size
	layer.add_child(sep)


func _text(layer: Control, s: String, size: int, col: Color, pos: Vector2,
		w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lbl := Label.new()
	lbl.text = s
	# FontManager._best_font 同逻辑：16 整倍数→f16，其余→f12
	lbl.add_theme_font_override("font", _f16 if (size % 16 == 0 and size % 12 != 0) else _f12)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.position = pos
	lbl.size = Vector2(w, size * 1.5)
	lbl.horizontal_alignment = align
	layer.add_child(lbl)
