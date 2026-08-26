extends SceneTree

## UI 配色方案 demo（点 2 重审 + 点 3 绿结束 + 点 4 道具栏重设计）：
##   godot --path . -s tools/ui_palette_demo.gd
## 在【中性灰底】孤立呈现提案（不连场景）：
##   ① 动作按钮按【功能语义】分色（攻红/防蓝/攒金/技紫/结束绿），复用 jelly 外形
##   ② 道具栏从锐角→【圆角芯片】+ 状态/维度分色（与按钮同语言）
##   ③ 场景无关性自检：同一组按钮叠在 浅底 / 深底 上，证明 UI 自带对比、不靠场景
## 输出：D:/Game/BoBoZan/_probe_output/ui_palette_demo.png（仓库外）

const OUT_PATH := "D:/Game/BoBoZan/_probe_output/ui_palette_demo.png"
const JELLY := preload("res://assets/shaders/canvas_button_jelly.gdshader")

const EDGE_OUTER := Color(0.10, 0.09, 0.11)   # 统一暗轮廓（中性·任何色相都干净）

## 语义色板（复用游戏「维度色」=已有语言）：[名, fill_top, fill_bottom, edge_inner]
const ACTIONS := [
	["攒", Color("e0b54a"), Color("a8801c"), Color("ffd97a")],   # 能量=金
	["波", Color("c85540"), Color("93331f"), Color("e88a60")],   # 进攻=红
	["大波", Color("d8492e"), Color("8a2718"), Color("ff9060")], # 进攻·重=亮红
	["防", Color("5184c2"), Color("2d5590"), Color("84b0e6")],   # 防御=蓝
	["大防", Color("3f72c4"), Color("224a86"), Color("6fa4ee")], # 防御·重=深蓝
	["技能", Color("8772c6"), Color("534093"), Color("ad99e2")], # 干扰/特殊=紫
	["结束", Color("5cb863"), Color("387c3f"), Color("92e398")], # 确认/GO=绿（Eddy 点3）
]

## 道具槽态：[标, fill_top, fill_bottom, edge_inner, 升角标]
const SLOTS := [
	["锁", Color("4e4e56"), Color("33333a"), Color("5e5e66"), false],   # SEALED 未到解锁回合
	["可开", Color("57524a"), Color("3a352e"), Color("d8b85a"), false], # SEALED 可开（金边提示）
	["可抽", Color("57524a"), Color("3a352e"), Color("d8b85a"), false], # OPENED 可抽
	["飞镖", Color("c05038"), Color("8a2e1f"), Color("ffd86a"), true],  # 进攻就绪（红+金边+升）
	["护甲", Color("4a7ab8"), Color("2c5288"), Color("ffd86a"), true],  # 防御就绪（蓝+金边+升）
	["可补", Color("242329"), Color("17171c"), Color("3a3a42"), false], # EMPTY 空格
]


func _make_jelly(ft: Color, fb: Color, ei: Color, corner: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY
	m.set_shader_parameter("fill_top", ft)
	m.set_shader_parameter("fill_bottom", fb)
	m.set_shader_parameter("edge_inner", ei)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 38.0)
	m.set_shader_parameter("corner", corner)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("noise_amt", 0.07)
	m.set_shader_parameter("wear", 0.22)
	return m


## 造一个 jelly 方块（带文字 + 可选金角标），返回容器。
func _chip(pos: Vector2, sz: float, spec: Array, font: int, up := false) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(sz, sz)
	var bg := ColorRect.new()
	bg.color = Color.WHITE   # shader 乘 COLOR
	bg.size = Vector2(sz, sz)
	bg.material = _make_jelly(spec[1], spec[2], spec[3], 0.22)
	c.add_child(bg)
	var lbl := Label.new()
	lbl.text = spec[0]
	lbl.size = Vector2(sz, sz)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font)
	lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	c.add_child(lbl)
	if up:
		var b := ColorRect.new()
		b.color = Color.WHITE
		b.size = Vector2(20, 18)
		b.position = Vector2(sz - 21, 1)
		b.material = _make_jelly(Color("ffd86a"), Color("c89a30"), Color("fff0b0"), 0.18)
		c.add_child(b)
		var ul := Label.new()
		ul.text = "升"
		ul.size = Vector2(20, 18)
		ul.position = Vector2(sz - 21, 0)
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ul.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ul.add_theme_font_size_override("font_size", 11)
		ul.add_theme_color_override("font_color", Color(0.25, 0.16, 0.04))
		c.add_child(ul)
	return c


func _text(t: String, pos: Vector2, sz := 22, col := Color(0.95, 0.93, 0.86)) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _button_row(parent: Node, y: float, btn_sz: float, label_font: int) -> void:
	var x := 70.0
	for spec in ACTIONS:
		parent.add_child(_chip(Vector2(x, y), btn_sz, spec, label_font))
		x += btn_sz + 22.0


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#3a3f47")   # 中性中灰底（孤立·非场景色）
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	root.add_child(_text("UI 配色方案 demo（中性灰底·孤立评估·不连场景）", Vector2(70, 24), 26, Color(1, 1, 1)))

	# ── A. 动作按钮·按功能语义分色 ──
	root.add_child(_text("A. 动作按钮：攒=金 / 波·大波=红 / 防·大防=蓝 / 技能=紫 / 结束=绿", Vector2(70, 86), 20))
	_button_row(root, 124.0, 120.0, 34)

	# ── B. 道具栏：圆角芯片 + 状态/维度分色（与按钮同语言）──
	root.add_child(_text("B. 道具栏（重设计）：圆角芯片·安静默认/就绪点亮·维度=红蓝/状态=灰金", Vector2(70, 300), 20))
	var x := 70.0
	for spec in SLOTS:
		root.add_child(_chip(Vector2(x, 340.0), 58.0, spec, 13, spec[4]))
		x += 58.0 + 12.0

	# ── C. 场景无关性：同组按钮叠浅底 / 深底 ──
	root.add_child(_text("C. 场景无关性自检：同一套色在 浅底 / 深底 上都成立（UI 自带对比·不靠场景）", Vector2(70, 470), 20))
	var light := ColorRect.new()
	light.color = Color("#cdc4b2")   # 浅暖底（模拟亮场景）
	light.position = Vector2(70, 516)
	light.size = Vector2(1010, 150)
	root.add_child(light)
	_button_row(root, 538.0, 110.0, 30)
	var dark := ColorRect.new()
	dark.color = Color("#10131a")   # 深冷底（模拟暗场景）
	dark.position = Vector2(70, 690)
	dark.size = Vector2(1010, 150)
	root.add_child(dark)
	_button_row(root, 712.0, 110.0, 30)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_PATH)
	print("saved: ", OUT_PATH)
	quit()
