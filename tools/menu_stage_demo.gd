extends SceneTree

## 主菜单「中央舞台板」纯预览 demo（F 方案 E 部分·不动任何真实场景文件）：
##   godot --path . -s tools/menu_stage_demo.gd
## 全屏波流背景（现状）+ 舞台板（battle screen 框语言：深描边/浅锡灰主边/深板岩填充/
## 蓝红四角宝石）+ 三段分区 + 王冠水印。截图后退出。
## 输出：D:/Game/BoBoZan/menu_stage_demo.png

const OUT_PATH := "D:/Game/BoBoZan/menu_stage_demo.png"
const FRAME_SHADER := "res://assets/shaders/canvas_ui_pixel_frame.gdshader"

# 板位（a-A 正中偏大·按钮未来进板）：x 460-1460，y 150-860
const PANEL := Rect2(460, 150, 1000, 710)
const STRIP_TOP := 80.0     # 顶部窄条（未来公告/赛季）
const STRIP_BOTTOM := 90.0  # 底部窄条（未来活动/战令）

# battle screen 框语言（hero_frame.gd 同源色板）
const EDGE_OUTER := Color(0.05, 0.05, 0.06)
const EDGE_MID := Color(0.65, 0.67, 0.71)
const EDGE_INNER := Color(0.34, 0.36, 0.39)
const FILL := Color(0.08, 0.09, 0.11, 0.84)     # d-A 实面板（0.7 试后内部波纹太抢 → 0.84）
const GEM_BLUE := Color(0.30, 0.60, 1.00)
const GEM_RED := Color(0.95, 0.32, 0.22)


func _initialize() -> void:
	var fm := (load("res://src/core/font_manager.gd") as GDScript).new() as Node
	fm.name = "FontManager"
	root.add_child(fm)
	# 背景 = 现状全屏波流（过渡链锚点，原样）
	var bg := (load("res://src/ui/scenes/menu_background.tscn") as PackedScene).instantiate()
	root.add_child(bg)
	_build_panel()
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()


func _build_panel() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)

	# 衬底（深板岩半透）
	var fill := ColorRect.new()
	fill.color = FILL
	fill.position = PANEL.position + Vector2(4, 4)
	fill.size = PANEL.size - Vector2(8, 8)
	layer.add_child(fill)

	# 像素框（battle 同款 shader + 色板）
	var frame := ColorRect.new()
	frame.color = Color(1, 1, 1, 1)
	var m := ShaderMaterial.new()
	m.shader = load(FRAME_SHADER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("edge_mid", EDGE_MID)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	# 大板上保持细边：grid 100 → 1 格 = 10px，border 1.5 格 = 15px（HeroFrame 比例感）
	m.set_shader_parameter("pixel_grid", 100.0)
	m.set_shader_parameter("border_px", 1.5)
	m.set_shader_parameter("noise_amt", 0.06)
	frame.material = m
	frame.position = PANEL.position
	frame.size = PANEL.size
	layer.add_child(frame)

	# 三段分区线（中灰内线色，低调）
	for y in [PANEL.position.y + STRIP_TOP, PANEL.end.y - STRIP_BOTTOM]:
		var sep := ColorRect.new()
		sep.color = Color(EDGE_INNER, 0.55)
		sep.position = Vector2(PANEL.position.x + 26, y)
		sep.size = Vector2(PANEL.size.x - 52, 2)
		layer.add_child(sep)

	# 四角阵营宝石：左蓝右红（呼应对波/王冠）——深色衬块 + 彩色宝石两层，压住框角
	var gs := 18.0
	var pad := 2.0
	for corner_v in [
			[Vector2(pad, pad), GEM_BLUE],
			[Vector2(pad, PANEL.size.y - pad - gs - 4), GEM_BLUE],
			[Vector2(PANEL.size.x - pad - gs - 4, pad), GEM_RED],
			[Vector2(PANEL.size.x - pad - gs - 4, PANEL.size.y - pad - gs - 4), GEM_RED]]:
		var corner: Array = corner_v
		var backing := ColorRect.new()
		backing.color = EDGE_OUTER
		backing.position = PANEL.position + (corner[0] as Vector2)
		backing.size = Vector2(gs + 4, gs + 4)
		layer.add_child(backing)
		var gem := ColorRect.new()
		gem.color = corner[1]
		gem.position = backing.position + Vector2(2, 2)
		gem.size = Vector2(gs, gs)
		layer.add_child(gem)

	# 水印（c-A）：王冠 + 标题小字，金色 alpha 0.25，居中于中部大区
	var crown := TextureRect.new()
	crown.texture = PixelGlyphs.crown_texture()
	crown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crown.stretch_mode = TextureRect.STRETCH_SCALE
	crown.size = Vector2(crown.texture.get_size()) * 4
	var mid_cy := PANEL.position.y + STRIP_TOP + (PANEL.size.y - STRIP_TOP - STRIP_BOTTOM) * 0.5
	crown.position = Vector2(PANEL.position.x + (PANEL.size.x - crown.size.x) * 0.5, mid_cy - 90)
	crown.modulate = Color(1, 1, 1, 0.25)
	layer.add_child(crown)
	var wm := Label.new()
	wm.text = "波波攒之王"
	root.get_node("FontManager").call("apply", wm, 48)
	wm.add_theme_color_override("font_color", Color("#f4c84b"))
	wm.modulate.a = 0.25
	wm.position = Vector2(PANEL.position.x, mid_cy + 10)
	wm.size = Vector2(PANEL.size.x, 60)
	wm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(wm)
