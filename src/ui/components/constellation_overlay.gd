class_name ConstellationOverlay
extends Control

## 星座连线层(生长动画版)：星座的星用像素十字星画(和背景散星同风格 → 看起来就是几颗现有的星)，
## 动态"生长"：一颗星闪亮 → 一根线延伸到下一颗 → 下一颗亮 → … → 连成星座 → 停留 → 淡出 → 重生(换位)。
## 由 battle_stage 程序化创建并插在 Stars 之上(不改 scene1.tscn)。全 _draw 绘制，无贴图。

@export var count: int = 3                                  # 同时存在的星座数
@export var line_color: Color = Color(0.62, 0.76, 1.0, 1.0)
@export var star_color: Color = Color(0.92, 0.96, 1.0, 1.0)
@export var line_alpha: float = 0.5                         # 连线相对透明(比主星淡)
@export var line_width: float = 1.0
@export var star_px: float = 5.0                           # 主星像素十字星核心边长
@export var period_min: float = 13.0                       # 单座完整周期(生长+停留+淡出+空白)
@export var period_max: float = 22.0
@export var sky_top: float = 0.08                          # 星座中心可分布天区(UV.y)
@export var sky_bottom: float = 0.42
@export var moon_pos: Vector2 = Vector2(0.774, 0.385)
@export var moon_avoid: float = 0.16

# 周期内各阶段分界(归一时间 0..1)：0..GROW 生长 / GROW..HOLD 停留 / HOLD..FADE 淡出 / FADE..1 空白
const GROW := 0.45
const HOLD := 0.65
const FADE := 0.85

var _consts: Array = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		_consts.append(_make_one())


func _make_one() -> Dictionary:
	var center := Vector2(randf_range(0.1, 0.9), randf_range(sky_top, sky_bottom))
	for _a in 6:
		if center.distance_to(moon_pos) > moon_avoid:
			break
		center = Vector2(randf_range(0.1, 0.9), randf_range(sky_top, sky_bottom))
	var n := randi_range(3, 5)
	var pts := PackedVector2Array()
	for _j in n:
		pts.append(center + Vector2(randf_range(-0.07, 0.07), randf_range(-0.055, 0.055)))
	return {
		"points": pts,
		"period": randf_range(period_min, period_max),
		"phase": randf() * period_max,
	}


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	for con in _consts:
		var period: float = con["period"]
		var t: float = fmod(_time + float(con["phase"]), period) / period

		# 整体淡出 alpha：停留后渐隐，空白期不画
		var alpha := 1.0
		if t >= FADE:
			alpha = 0.0
		elif t >= HOLD:
			alpha = 1.0 - (t - HOLD) / (FADE - HOLD)
		if alpha <= 0.01:
			continue

		var pts: PackedVector2Array = con["points"]
		var n := pts.size()
		var grow_t := clampf(t / GROW, 0.0, 1.0)
		var steps := float(2 * n - 1)     # 子步序列：星0,边0,星1,边1,…,星(n-1)
		var pos := grow_t * steps         # 当前生长到第几子步

		# 连线：边 k 在子步 2k+1 从星 k 向星 k+1 动态延伸
		for k in n - 1:
			var ea := clampf(pos - float(2 * k + 1), 0.0, 1.0)
			if ea <= 0.0:
				continue
			var p1: Vector2 = pts[k] * sz
			var p2: Vector2 = pts[k + 1] * sz
			var pe := p1.lerp(p2, ea)
			var lc := Color(line_color.r, line_color.g, line_color.b, line_color.a * alpha * line_alpha)
			draw_line(p1, pe, lc, line_width)

		# 主星：星 k 在子步 2k 淡入出现；亮后轻微闪烁(融入背景散星)
		for k in n:
			var sa := clampf(pos - float(2 * k), 0.0, 1.0)
			if sa <= 0.0:
				continue
			var sb := sa
			if sa >= 1.0:
				sb = 0.72 + 0.28 * sin(_time * 3.0 + float(k) * 1.7)
			_draw_pixel_star(pts[k] * sz, Color(star_color.r, star_color.g, star_color.b, star_color.a * sb * alpha))


## 画一颗像素十字星(核心方块 + 四向短臂)，匹配背景散星样式。
func _draw_pixel_star(c: Vector2, col: Color) -> void:
	var k := star_px
	var aw := maxf(1.0, floor(k * 0.45))
	var al := k * 0.9
	var hk := k * 0.5
	draw_rect(Rect2(c - Vector2(hk, hk), Vector2(k, k)), col)            # 核心方块
	draw_rect(Rect2(c.x - aw * 0.5, c.y - hk - al, aw, al), col)         # 上臂
	draw_rect(Rect2(c.x - aw * 0.5, c.y + hk, aw, al), col)              # 下臂
	draw_rect(Rect2(c.x - hk - al, c.y - aw * 0.5, al, aw), col)         # 左臂
	draw_rect(Rect2(c.x + hk, c.y - aw * 0.5, al, aw), col)              # 右臂
