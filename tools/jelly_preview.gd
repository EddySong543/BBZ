extends Node

## 按钮底纹「离散 vs 连续」对比预览（带窗口跑→截图自检）：
##   godot --path . res://tools/jelly_preview.tscn
## 5 块同色(大波红)瓦片，只换 texture_feel：原离散 hash + 4 档连续 fbm。
## 输出单张对比 PNG 到 scratchpad，供裁剪比对。

const SHADER := "res://assets/shaders/canvas_button_jelly.gdshader"
const OUT := "D:/Game/BoBoZan/jelly_compare.png"

# 大波红配色（取自 JellyDaBo）
const FILL_TOP := Color(0.8471, 0.2863, 0.1804, 1)
const FILL_BOTTOM := Color(0.5412, 0.1529, 0.0941, 1)
const EDGE_INNER := Color(1, 0.5647, 0.3765, 1)
const EDGE_OUTER := Color(0.1, 0.09, 0.11, 1)

# [标题, solid_rim, rim_px]
const VARIANTS := [
	["现状·磨损灰点(离散)", false, 1.5],
	["连续深边 rim1.0", true, 1.0],
	["连续深边 rim1.5", true, 1.5],
	["连续深边 rim2.0", true, 2.0],
]


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.065, 0.06)
	root.add_child(bg)

	var tile_w := 320.0
	var tile_h := 300.0
	var gap := 40.0
	var n := VARIANTS.size()
	var total := n * tile_w + (n - 1) * gap
	var x0 := (1920.0 - total) * 0.5
	var y0 := 320.0

	for i in n:
		var v: Array = VARIANTS[i]
		var x := x0 + i * (tile_w + gap)

		var rect := ColorRect.new()
		rect.position = Vector2(x, y0)
		rect.size = Vector2(tile_w, tile_h)
		rect.material = _make_mat(v[1], v[2], tile_w / tile_h)
		root.add_child(rect)

		var lbl := Label.new()
		lbl.text = String(v[0])
		lbl.position = Vector2(x, y0 - 44.0)
		lbl.size = Vector2(tile_w, 40.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
		lbl.add_theme_font_size_override("font_size", 22)
		root.add_child(lbl)

	for _i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT)
	print("saved: ", OUT)
	get_tree().quit()


func _make_mat(solid_rim: bool, rim_px: float, aspect: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.set_shader_parameter("fill_top", FILL_TOP)
	m.set_shader_parameter("fill_bottom", FILL_BOTTOM)
	m.set_shader_parameter("edge_inner", EDGE_INNER)
	m.set_shader_parameter("edge_outer", EDGE_OUTER)
	m.set_shader_parameter("fill_alpha", 1.0)
	m.set_shader_parameter("pixel_grid", 38.0)
	m.set_shader_parameter("corner", 0.22)
	m.set_shader_parameter("edge_px", 2.0)
	m.set_shader_parameter("aspect", aspect)
	m.set_shader_parameter("noise_amt", 0.08)
	m.set_shader_parameter("wear", 0.24)
	m.set_shader_parameter("solid_rim", solid_rim)
	m.set_shader_parameter("rim_px", rim_px)
	return m
