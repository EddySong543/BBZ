class_name ConstellationOverlay
extends Control

## 星座连线层（呼应星座/生肖/塔罗主题）：程序化生成数个星座，缓慢淡入淡出。
## 每个星座 = 几颗较亮的"主星"(小方块) + 链式细连线。位置随机分布在天空中上部、避开月亮。
## 全 _draw() 绘制，无贴图。由 battle_stage 在 _ready 程序化创建并插在 Stars 之上（不改 scene1.tscn）。

@export var count: int = 3                                       # 星座数量
@export var line_color: Color = Color(0.6, 0.74, 1.0, 1.0)      # 连线色
@export var star_color: Color = Color(0.92, 0.96, 1.0, 1.0)    # 主星色
@export var line_alpha: float = 0.45                            # 连线相对透明(比主星淡)
@export var line_width: float = 1.0
@export var star_px: float = 3.0                                # 主星方块边长(像素)
@export var fade_min: float = 7.0                               # 单座淡入淡出周期(秒)
@export var fade_max: float = 16.0
@export var sky_top: float = 0.08                               # 星座中心可分布的天区(UV.y)
@export var sky_bottom: float = 0.42
@export var moon_pos: Vector2 = Vector2(0.774, 0.385)
@export var moon_avoid: float = 0.16                            # 避开月亮半径

var _consts: Array = []      # 每项: {points: PackedVector2Array(UV), edges: Array, period, phase}
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generate()


func _generate() -> void:
	_consts.clear()
	for i in count:
		_consts.append(_make_one())


func _make_one() -> Dictionary:
	var center := Vector2(randf_range(0.1, 0.9), randf_range(sky_top, sky_bottom))
	for _attempt in 6:
		if center.distance_to(moon_pos) > moon_avoid:
			break
		center = Vector2(randf_range(0.1, 0.9), randf_range(sky_top, sky_bottom))
	var n := randi_range(3, 5)
	var pts := PackedVector2Array()
	for _j in n:
		pts.append(center + Vector2(randf_range(-0.07, 0.07), randf_range(-0.055, 0.055)))
	var edges: Array = []
	for j in n - 1:
		edges.append(Vector2i(j, j + 1))   # 链式连线
	return {
		"points": pts,
		"edges": edges,
		"period": randf_range(fade_min, fade_max),
		"phase": randf() * fade_max,
	}


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	for con in _consts:
		var period: float = con["period"]
		var pp: float = fmod(_time + float(con["phase"]), period) / period
		var a: float = 1.0 - absf(pp * 2.0 - 1.0)     # 三角波
		a = smoothstep(0.0, 1.0, a)
		if a <= 0.02:
			continue
		var pts: PackedVector2Array = con["points"]
		# 连线(淡)
		var lc := Color(line_color.r, line_color.g, line_color.b, line_color.a * a * line_alpha)
		for e in con["edges"]:
			draw_line(pts[e.x] * sz, pts[e.y] * sz, lc, line_width)
		# 主星(小方块)
		var pc := Color(star_color.r, star_color.g, star_color.b, star_color.a * a)
		var half := star_px * 0.5
		for p in pts:
			var sp: Vector2 = p * sz
			draw_rect(Rect2(sp - Vector2(half, half), Vector2(star_px, star_px)), pc)
