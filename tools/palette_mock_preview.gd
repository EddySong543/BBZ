extends SceneTree

## 底部按钮排裁色概念稿（2026-07-17 配色讨论·三版并排）：
##   godot --path . -s tools/palette_mock_preview.gd   （⚠须带窗口）
## 行1=现行 9 色相 / 行2=四色版（攻红防蓝各两档+攒金+结束绿·紫裁=技能墨金·情报/图鉴中性纸）
## / 行3=三色版（再裁绿·结束=纸身朱墨）。仅概念稿·不动战斗屏任何文件。
## 输出：D:/Game/BoBoZan/_probe_output/palette_mock.png

const OUT := "D:/Game/BoBoZan/_probe_output/palette_mock.png"
const JELLY := preload("res://assets/shaders/canvas_button_jelly.gdshader")
const FONT_PATH := "res://assets/font/ark-pixel-12px-proportional-zh_cn.ttf"
const BTN := 108.0
const GAP := 24.0
const PAPER_TOP := Color(0.92, 0.87, 0.70)
const PAPER_BOTTOM := Color(0.76, 0.68, 0.50)
const PAPER_EDGE := Color(1.0, 0.95, 0.80)
const INK_TOP := Color(0.29, 0.25, 0.21)
const INK_BOTTOM := Color(0.20, 0.17, 0.14)

# 每钮 = [标签, fill_top, edge_inner覆盖(null=自动提亮)]；fill_bottom 自动=top 压暗。
# ── 行1 现行（近似还原 §2.5 + 情报双钮） ──
var row_current: Array = [
	["己技", Color(0.30, 0.45, 0.66), null],
	["敌技", Color(0.62, 0.34, 0.28), null],
	["攒", Color("e0b54a"), null],
	["波", Color("c85540"), null],
	["大波", Color("d8492e"), null],
	["防", Color("5184c2"), null],
	["大防", Color("3f72c4"), null],
	["技能", Color("8772c6"), null],
	["图鉴", PAPER_TOP, PAPER_EDGE],
	["结束", Color("5cb863"), null],
]
# ── 行2 四色版：红/蓝各两档同色相·攒金·结束绿·技能=墨身金边·情报/图鉴=纸身（情报带阵营细边）──
var row_four: Array = [
	["己技", PAPER_TOP, Color(0.43, 0.63, 0.88)],
	["敌技", PAPER_TOP, Color(0.88, 0.52, 0.42)],
	["攒", Color("d9ae4b"), null],
	["波", Color("c4523e"), null],
	["大波", Color("9c3527"), null],
	["防", Color("4a7db8"), null],
	["大防", Color("34608f"), null],
	["技能", INK_TOP, Color("e8c670")],
	["图鉴", PAPER_TOP, PAPER_EDGE],
	["结束", Color("55a25e"), null],
]
# ── 行3 三色版：再裁绿·结束=纸身朱墨边 ──
var row_three: Array = [
	["己技", PAPER_TOP, Color(0.43, 0.63, 0.88)],
	["敌技", PAPER_TOP, Color(0.88, 0.52, 0.42)],
	["攒", Color("d9ae4b"), null],
	["波", Color("c4523e"), null],
	["大波", Color("9c3527"), null],
	["防", Color("4a7db8"), null],
	["大防", Color("34608f"), null],
	["技能", INK_TOP, Color("e8c670")],
	["图鉴", PAPER_TOP, PAPER_EDGE],
	["结束", PAPER_TOP, Color("b4432e")],
]


func _initialize() -> void:
	var bg := ColorRect.new()
	bg.color = Color("10151f")   # 战斗夜景近似底
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	await process_frame
	bg.size = root.get_visible_rect().size
	var font := load(FONT_PATH) as FontFile
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	var rows: Array = [
		["现行（9 色相）", row_current],
		["四色版：攻红/防蓝各两档·攒金·结束绿·技能墨金·情报图鉴纸", row_four],
		["三色版：再裁绿——结束=纸身朱墨（故事屏开战 CTA 同源）", row_three],
	]
	var total_w := BTN * 10.0 + GAP * 9.0
	var x0 := (bg.size.x - total_w) * 0.5
	var y := 90.0
	for r: Array in rows:
		var cap := Label.new()
		cap.text = str(r[0])
		cap.position = Vector2(x0, y - 40.0)
		cap.add_theme_font_override("font", font)
		cap.add_theme_font_size_override("font_size", 24)
		cap.add_theme_color_override("font_color", Color(0.92, 0.89, 0.80))
		root.add_child(cap)
		var x := x0
		for b: Array in r[1]:
			var chip := ColorRect.new()
			chip.color = Color.WHITE
			chip.position = Vector2(x, y)
			chip.size = Vector2(BTN, BTN)
			chip.material = _jelly(b[1], b[2])
			root.add_child(chip)
			var lb := Label.new()
			lb.text = str(b[0])
			lb.position = Vector2(x, y + BTN + 8.0)
			lb.size = Vector2(BTN, 28.0)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_font_override("font", font)
			lb.add_theme_font_size_override("font_size", 24)
			lb.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
			root.add_child(lb)
			x += BTN + GAP
		y += 300.0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	quit()


func _jelly(top: Color, edge_override: Variant) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = JELLY
	var bottom := top.darkened(0.28)
	if top == PAPER_TOP:
		bottom = PAPER_BOTTOM
	elif top == INK_TOP:
		bottom = INK_BOTTOM
	var edge: Color = top.lightened(0.35) if edge_override == null else edge_override
	m.set_shader_parameter("fill_top", top)
	m.set_shader_parameter("fill_bottom", bottom)
	m.set_shader_parameter("edge_inner", edge)
	m.set_shader_parameter("edge_outer", Color(0.1, 0.09, 0.11))
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 38.0)
	m.set_shader_parameter("corner", 0.22)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", 1.0)
	m.set_shader_parameter("noise_amt", 0.08)
	m.set_shader_parameter("wear", 0.24)
	m.set_shader_parameter("solid_rim", true)
	m.set_shader_parameter("rim_px", 1.5)
	return m
